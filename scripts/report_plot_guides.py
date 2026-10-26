#!/usr/bin/env python3
"""Validate curated guides and emit a reproducible English coverage inventory.

Run with the project's Python environment from any directory. This checks content
and local example references; it does not assert that R rendering succeeded.
"""
from __future__ import annotations
import argparse
import json
import sys
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from plot_web.plot_guide import load_family_guide, load_literature, public_literature, published_figure_examples
from plot_web.plot_registry import load_registry, plot_is_listed
from plot_web.schema_normalize import normalize_params_schema
from plot_web.server.plugins import example_bundle, example_file, read_example_manifest


def inventory():
    rows, errors = [], []
    literature = load_literature()
    registry = load_registry()
    ids = {plot['id'] for plot in registry['plots']}
    seen_figures = set()
    for lid, paper in literature.items():
        for figure in paper.get('figure_examples', []):
            fid = figure.get('id')
            if not fid or fid in seen_figures:
                errors.append(f'{lid}: missing or duplicate figure id {fid}')
            seen_figures.add(fid)
            for field in ('figure', 'title', 'description', 'adaptation', 'verified_on', 'verification'):
                if not figure.get(field):
                    errors.append(f'{lid}/{fid}: missing {field}')
            for field in ('figure_url', 'evidence_url'):
                parsed = urlparse(figure.get(field, ''))
                if parsed.scheme != 'https' or not parsed.netloc:
                    errors.append(f'{lid}/{fid}: invalid {field}')
            if figure.get('match_type') not in {'same_grammar', 'related_layout'}:
                errors.append(f'{lid}/{fid}: invalid match type')
            if not figure.get('plot_families'):
                errors.append(f'{lid}/{fid}: no family association')
            for family in figure.get('plot_families', []):
                if family not in ids or lid not in load_family_guide(family).get('literature_ids', []):
                    errors.append(f'{lid}/{fid}: unlinked family {family}')
    for plot in registry['plots']:
        pid, engine = plot['id'], plot['engine_plugin_id']
        guide = load_family_guide(pid)
        examples = guide.get('examples', [])
        schema = normalize_params_schema(json.loads((ROOT/'plugins'/engine/'params_schema.json').read_text())) or {}
        fields = {key for section in schema.values() if isinstance(section, dict) for key in section}
        demos = set()
        for example in examples:
            demo = example.get('demo_id')
            demos.add(demo)
            try:
                bundle = example_bundle(engine, demo)
                manifest = read_example_manifest(bundle)
                example_file(bundle, manifest.get('params', 'params.json'))
                for relative in manifest.get('inputs', {}).values():
                    example_file(bundle, relative)
                example_file(bundle, manifest['expected'])
                if example.get('preview_asset'):
                    asset = (ROOT/example['preview_asset']).resolve()
                    asset.relative_to((ROOT/'plugins'/engine/'all_examples_gallery').resolve())
                    assert asset.is_file(), 'missing preview'
            except Exception as exc:
                errors.append(f'{pid}/{demo}: {getattr(exc, "detail", str(exc))}')
            if example.get('literature_id') and example['literature_id'] not in guide.get('literature_ids', []):
                errors.append(f'{pid}/{demo}: literature_id is not linked by the guide')
        for item in guide.get('customization', []):
            if item['parameter'] not in fields:
                errors.append(f'{pid}: unknown customization parameter {item["parameter"]}')
        for lid in guide.get('literature_ids', []):
            if lid not in literature:
                errors.append(f'{pid}: missing literature {lid}')
        if guide:
            for key in ('summary', 'best_for', 'input_requirements', 'interpretation', 'cautions', 'examples'):
                if not guide.get(key):
                    errors.append(f'{pid}: missing {key}')
        rows.append(dict(plot=plot, guide=guide, demos=demos, listed=plot_is_listed(plot)))
    return rows, errors


def figures_for_row(row, literature):
    guide = row['guide']
    public = [public_literature(literature[lid], row['plot']['id'])
              for lid in guide.get('literature_ids', []) if lid in literature]
    return published_figure_examples({'literature': public})


def render_report(rows, errors):
    lit = load_literature()
    visible = [r for r in rows if r['listed']]
    covered = [r for r in rows if r['guide']]
    gaps = [r for r in rows if len(r['demos']) < 2]
    missing = [r for r in rows if not r['guide']]
    figures = {r['plot']['id']: figures_for_row(r, lit) for r in rows}
    records = {(f['literature_id'], f['id']) for fs in figures.values() for f in fs}
    direct = [r for r in visible if any(f['match_type'] == 'same_grammar' for f in figures[r['plot']['id']])]
    matched = [r for r in visible if figures[r['plot']['id']]]
    two_papers = [r for r in visible if len({f['literature_id'] for f in figures[r['plot']['id']]}) >= 2]
    lines = ['# Plot Guide coverage, published figures and examples', '',
        'Generated from registry entries, curated Guide YAML, verified references and local example bundles.', '',
        f'- Visible plots: **{len(visible)}**; Guides available: **{sum(bool(r["guide"]) for r in visible)}**.',
        f'- All registry entries: **{len(rows)}**; Guide source files: **{len(covered)}**; missing Guides: **{len(missing)}**.',
        f'- Entries with at least two independent local demos: **{len(rows)-len(gaps)}**; fewer than two: **{len(gaps)}**.',
        f'- Local demo bundles linked: **{sum(len(r["demos"]) for r in rows)}**.',
        f'- Curated references: **{len(lit)}**; unique verified figure records: **{len(records)}**.',
        f'- Visible plots with a verified figure association: **{len(matched)}/{len(visible)}**; with at least one same-grammar match: **{len(direct)}/{len(visible)}**.',
        f'- Visible plots with figure examples from at least two distinct references: **{len(two_papers)}/{len(visible)}**.',
        f'- Local reference-validation errors: **{len(errors)}**.', '',
        '**Scope:** visible Guides are available in the editor. Hidden legacy entries have documentation source files only; this work does not enable their old entry points.', '',
        '**Published figures:** every listed example has a checked figure/panel label, source link, short description and adaptation note. Same plot grammar does not mean an exact reproduction. Related layouts are explicitly labelled and are not counted as direct matches. Preprints are identified. A figure range such as 4A–D is one figure record, not four independent papers.', '',
        '**Links and images:** links open the publisher figure page where verified and available, otherwise the captioned article or PDF. Locate the named panel in that source. Original publication images are not copied or presented as local demos.', '',
        '**Local examples:** demos use existing independent bundles; they are not the original data of cited papers. Loading an existing preview does not prove that the R engine can regenerate it in the current environment.', '',
        'Runtime and interface results are recorded in the [validation notes](plot_guide_validation_2026-10-25.md). Existing full-image regression failures remain separate from Guide coverage.', '',
        '## Overview', '',
        '| Plot / ID | Editor status | Guide | Local demos | Verified figure matches | Distinct figure references |',
        '|---|---|---|---:|---:|---:|']
    for r in rows:
        p,g=r['plot'],r['guide']; fs=figures[p['id']]
        status='Visible' if r['listed'] else 'Hidden; source only'
        lines.append(f'| {p["name"]} / `{p["id"]}` | {status} | {"Yes" if g else "No"} | {len(r["demos"])} | {len(fs)} | {len({f["literature_id"] for f in fs})} |')
    lines += ['', '## Entries without a Guide', '', ', '.join(r['plot']['id'] for r in missing) or 'None. Every registry entry has a Guide source file.', '', '## Fewer than two independent local demos', '']
    for r in gaps:
        lines.append(f'- `{r["plot"]["id"]}`: {len(r["demos"])} bundle ({", ".join(sorted(r["demos"]))}); add a distinct input or mode-specific bundle.')
    lines += ['', '## Literature gaps', '',
        'The target of 2–3 distinct references with suitable figure examples per plot has not been met universally. These visible plots have fewer than two distinct figure references:', '']
    for r in visible:
        pid=r['plot']['id']; fs=figures[pid]; n=len({f['literature_id'] for f in fs})
        if n<2: lines.append(f'- `{pid}`: {n} figure reference(s), {len(fs)} verified figure record(s).')
    related_only=[r['plot']['id'] for r in visible if figures[r['plot']['id']] and not any(f['match_type']=='same_grammar' for f in figures[r['plot']['id']])]
    lines += ['', 'Visible plots currently supported only by related-layout examples: '+(', '.join(f'`{pid}`' for pid in related_only) or 'none')+'.', '',
        'Entries with no verified figure association, including hidden legacy entries: '+(', '.join(f'`{r["plot"]["id"]}`' for r in rows if not figures[r['plot']['id']]) or 'none')+'.', '',
        'Method-only references without a checked figure are useful reading, but are not counted as figure examples.', '', '## Plot-by-plot details', '']
    for r in rows:
        p,g=r['plot'],r['guide']; pid=p['id']; engine=p['engine_plugin_id']
        lines += [f'### {p["name"]} · `{pid}`', '',
            f'- Guide: [source](../../plot_web/registry/guides/{pid}.yaml); engine: `{engine}`.',
            f'- Status: {"visible in the editor" if r["listed"] else "hidden; documentation source only"}.',
            f'- Purpose: {g.get("summary", "Not documented")}',
            f'- Input: {g.get("input_requirements", "Not documented")}',
            '- Scenarios: '+'; '.join(g.get('best_for', [])),
            '- Reading: '+'; '.join(i['text'] for i in g.get('interpretation', [])),
            '- Cautions: '+'; '.join(i['text'] for i in g.get('cautions', [])), '',
            'Published figure examples:', '']
        for f in figures[pid]:
            kind='Same plot grammar' if f['match_type']=='same_grammar' else 'Related layout; adaptation required'
            preprint=' [PREPRINT; not peer reviewed]' if f['publication_status']=='preprint' else ''
            lines += [f'- **{f["figure"]}: {f["title"]}** — {kind}.{preprint}',
                f'  {f["authors"]} ({f["year"]}), *{f["journal"]}*. [{f["paper_title"]}]({f["paper_url"]}).',
                f'  Source: [figure/caption]({f["figure_url"]}); DOI `{f["doi"]}`; checked {f["verified_on"]}.',
                f'  Shown in the paper: {f["description"]}', f'  Apply it: {f["adaptation"]}']
        if not figures[pid]: lines.append('No figure-panel association has been verified yet.')
        lines += ['', 'Local runnable demos:', '']
        for e in g.get('examples', []):
            demo=e['demo_id']; base=f'../../plugins/{engine}/examples/{demo}'
            lines += [f'- **{e["title"]}** · `{demo}`: {e["description"]}',
                      f'  [Parameters]({base}/params.json) · [Inputs and reproduction]({base}/manifest.json)']
            if e.get('preview_asset'): lines[-1]+=f' · [Preview](../../{e["preview_asset"]})'
            if e.get('mappings'): lines.append('  Mappings: '+', '.join(f'`{k}={json.dumps(v,ensure_ascii=False)}`' for k,v in e['mappings'].items()))
            if e.get('data_note'): lines.append('  Data provenance: '+e['data_note'])
        lines += ['', 'Customization controls (checked against the schema): '+', '.join(f'`{i["parameter"]}`' for i in g.get('customization', []))+'.', '']
        figure_refs={f['literature_id'] for f in figures[pid]}
        for lid in g.get('literature_ids', []):
            if lid in figure_refs: continue
            paper=lit[lid]; kind='Method reference' if paper.get('reference_type')=='method_reference' else 'Further reference'
            lines += [f'- {kind}: [{paper["title"]}]({paper["url"]}) ({paper["year"]}).', f'  Relevance: {paper.get("relevance", "")}']
        if not g.get('literature_ids'): lines.append('- No curated literature reference yet.')
        lines += ['']
    lines += ['## Reference validation', '', *(f'- {e}' for e in errors)]
    if not errors: lines.append('Passed: linked local manifests, parameters, inputs, baselines and declared previews exist; customization parameters match the schema. Figure records have source URLs, panel labels and adaptation notes. This check does not execute R or independently re-fetch sources.')
    return '\n'.join(lines)+'\n'


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT/'docs/qa/plot_guide_coverage_2026-10-25.md')
    args=parser.parse_args();rows,errors=inventory()
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(render_report(rows,errors),encoding='utf-8')
    print(f'{len(rows)} entries; {sum(r["listed"] for r in rows)} visible; {sum(bool(r["guide"]) for r in rows)} guides; {len(errors)} reference errors')
    for error in errors: print(error)
    return bool(errors)

if __name__=='__main__':sys.exit(main())
