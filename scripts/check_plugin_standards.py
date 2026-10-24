#!/usr/bin/env python3
"""Check plugins against the plot-plugin standards (docs/standards/).

Every rule below is described in docs/standards; the rule id is printed with each
violation so it can be looked up there.

Existing plugins predate the standards, so their current violations are recorded
in scripts/plugin_standards_baseline.json. The check fails on any violation that
is not in the baseline: a new plugin must be clean, and an existing plugin may not
get worse. Fixing a baselined violation is always welcome; rerun with
--update-baseline afterwards so it cannot come back.

usage:
  python scripts/check_plugin_standards.py                 # all plugins, fail on new violations
  python scripts/check_plugin_standards.py my_plugin       # one plugin
  python scripts/check_plugin_standards.py --all-violations # also list baselined ones
  python scripts/check_plugin_standards.py --update-baseline
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from plot_web.schema_normalize import normalize_params_schema  # noqa: E402

PLUGIN_DIR = ROOT / "plugins"
BASELINE = ROOT / "scripts" / "plugin_standards_baseline.json"

# docs/standards/04_classification.md — Studio sidebar categories.
STUDIO_CATEGORIES = {
    "Dimension", "Feature", "Expression / Statistics", "Distribution", "Comparison", "Composition",
    "Correlation", "Scatter", "Heatmap", "Network", "Set / Enrichment", "Genomics", "Motif",
    "Multi-panel", "Benchmark",
}
STATUSES = {"stable", "beta", "experimental", "deprecated"}
REQUIRED_OUTPUTS = {"result.svg", "result.pdf", "result.png", "figure.json", "run.log"}
# docs/standards/02_params_schema.md — control types the Studio editor renders.
PARAM_TYPES = {"string", "textarea", "number", "integer", "boolean", "select", "color", "column", "columns",
               "string_array", "number_array", "color_array", "object", "file"}
COLOR_KEY = re.compile(r"(^|_)(colou?r|fill|stroke|background|bg)$|_colou?r_|^colou?r_")
# Third-party tool names and placeholder text must not appear in plugins or examples.
FORBIDDEN_TEXT = re.compile(r"chi[\s_-]?plot|hello world|xiaoshi|lorem ipsum", re.IGNORECASE)
ABS_PATH = re.compile(r"(/Users/[A-Za-z]|/home/[a-z]|[A-Z]:\\\\)")


def violation(rule: str, detail: str) -> dict:
    return {"rule": rule, "detail": detail}


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        return exc


def check_config(pid: str, d: Path) -> list[dict]:
    out = []
    path = d / "config.yaml"
    if not path.is_file():
        return [violation("P001", "config.yaml missing")]
    cfg = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if cfg.get("id") != pid:
        out.append(violation("P001", f"config id {cfg.get('id')!r} != directory name"))
    for key in ("name", "version", "description", "language", "entrypoint"):
        if not cfg.get(key):
            out.append(violation("P001", f"config.yaml: missing {key}"))
    if cfg.get("version") and not re.fullmatch(r"\d+\.\d+\.\d+", str(cfg["version"])):
        out.append(violation("P001", f"version {cfg['version']!r} is not MAJOR.MINOR.PATCH"))
    if cfg.get("entrypoint") and not (d / str(cfg["entrypoint"])).is_file():
        out.append(violation("P001", f"entrypoint {cfg['entrypoint']} not found"))
    if str(cfg.get("status") or "") not in STATUSES:
        out.append(violation("P001", f"status {cfg.get('status')!r} not in {sorted(STATUSES)}"))
    inputs = cfg.get("inputs")
    if not isinstance(inputs, list) or not inputs:
        out.append(violation("P001", "inputs must be a non-empty list"))
    else:
        for item in inputs:
            if not isinstance(item, dict) or not item.get("id") or not item.get("type"):
                out.append(violation("P001", f"input entry needs id and type: {item!r}"))
    outputs = {str(o) for o in cfg.get("outputs") or []}
    missing = REQUIRED_OUTPUTS - outputs
    if missing:
        out.append(violation("P001", f"outputs missing {sorted(missing)}"))
    if cfg.get("category") not in STUDIO_CATEGORIES:
        out.append(violation("P002", f"category {cfg.get('category')!r} not in the Studio category list"))
    if not cfg.get("subcategory"):
        out.append(violation("P002", "subcategory missing"))
    return out


def schema_fields(d: Path):
    raw = load_json(d / "params_schema.json")
    if isinstance(raw, Exception):
        return None, raw
    norm = normalize_params_schema(raw) or {}
    fields = {}
    for sec in norm.values():
        if isinstance(sec, dict):
            for k, v in sec.items():
                if isinstance(v, dict):
                    fields[k] = v
    return fields, None


def check_schema(d: Path) -> list[dict]:
    if not (d / "params_schema.json").is_file():
        return [violation("S001", "params_schema.json missing")]
    fields, err = schema_fields(d)
    if err is not None:
        return [violation("S001", f"params_schema.json does not parse: {err}")]
    if not fields:
        return [violation("S001", "params_schema.json has no parameters")]
    out = []
    for key, f in sorted(fields.items()):
        t = f.get("type")
        if not t:
            out.append(violation("S002", f"{key}: no type"))
            continue
        if t not in PARAM_TYPES:
            out.append(violation("S003", f"{key}: type {t!r} not allowed"))
        if t == "select":
            opts = [o.get("value", o) if isinstance(o, dict) else o for o in f.get("options") or []]
            if not opts:
                out.append(violation("S004", f"{key}: select without options"))
            elif "default" in f and f["default"] not in opts and f["default"] not in (None, ""):
                out.append(violation("S004", f"{key}: default {f['default']!r} not in options"))
        if t == "string" and COLOR_KEY.search(key) and "options" not in f:
            out.append(violation("S005", f"{key}: colour parameter typed string (use color)"))
        if t in ("string", "string_array") and re.search(r"_(column|col|columns|cols)$", key) and "options" not in f:
            out.append(violation("S006", f"{key}: column mapping typed {t} (use column / columns)"))
    return out


def params_var_names(code: str) -> set[str]:
    names = set(re.findall(r"(\w+)\s*(?:<-|=)\s*(?:jsonlite::)?(?:fromJSON|read_json)\s*\(", code))
    return names or {"params"}


def strip_comments(code: str) -> str:
    """Drop string literals and comments so rules only see code."""
    code = re.sub(r"'(?:[^'\\\n]|\\.)*'|\"(?:[^\"\\\n]|\\.)*\"", "''", code)
    return "\n".join(re.sub(r"(^|\s)#.*$", r"\1", line) for line in code.splitlines())


def check_r(d: Path) -> list[dict]:
    path = d / "plot.R"
    if not path.is_file():
        return []
    raw = path.read_text(encoding="utf-8", errors="replace")
    code = strip_comments(raw)
    out = []
    for var in sorted(params_var_names(code)):
        # Reads only: `params$x <- v` assigns and cannot partial-match.
        hits = sorted(set(re.findall(rf"(?<![\w.$]){re.escape(var)}\$(\w+)(?!\w*\s*(?:<-|=[^=]))", code)))
        if hits:
            out.append(violation("R001", f"{var}$… partial-matching access: {', '.join(hits[:8])}"))
    if ABS_PATH.search(raw):
        out.append(violation("R002", "hard-coded absolute path"))
    if re.search(r"set\.seed\(\s*\d+\s*\)", code):
        out.append(violation("R003", "set.seed(<literal>) overrides the run seed"))
    if re.search(r"(?<![\w:.])png\s*\(", code) and "agg_png" not in raw:
        out.append(violation("R004", "PNG written without ragg::agg_png"))
    if re.search(r"(?<![\w:.])pdf\s*\(", code) and "cairo_pdf" not in raw:
        out.append(violation("R005", "PDF written with pdf() instead of cairo_pdf()"))
    if "error.json" not in raw:
        out.append(violation("R006", "does not write error.json on failure"))
    if "figure.json" not in raw:
        out.append(violation("R007", "does not write figure.json"))
    return out


def check_examples(d: Path) -> list[dict]:
    idx = d / "examples" / "index.json"
    if not idx.is_file():
        return [violation("E001", "examples/index.json missing")]
    data = load_json(idx)
    entries = data.get("examples") if isinstance(data, dict) else data
    if not entries:
        return [violation("E001", "examples/index.json lists no examples")]
    out = []
    for entry in entries:
        eid = entry.get("id") if isinstance(entry, dict) else str(entry)
        ex = d / "examples" / str(eid)
        man = load_json(ex / "manifest.json") if (ex / "manifest.json").is_file() else None
        if not isinstance(man, dict):
            out.append(violation("E002", f"{eid}: manifest.json missing or invalid"))
            continue
        if not (ex / str(man.get("params") or "params.json")).is_file():
            out.append(violation("E002", f"{eid}: params file missing"))
        for key, rel in (man.get("inputs") or {}).items():
            if isinstance(rel, str) and not (ex / rel).is_file():
                out.append(violation("E002", f"{eid}: input {key} → {rel} missing"))
        if not (ex / "expected" / "result.png").is_file():
            out.append(violation("E002", f"{eid}: expected/result.png missing (run smoke_plugins --update-baseline)"))
    return out


def check_text(d: Path) -> list[dict]:
    out = []
    files = [d / n for n in ("plot.R", "README.md", "SKILL.md", "config.yaml", "params_schema.json")]
    files += list((d / "examples").glob("*/params.json")) + list((d / "examples").glob("*/manifest.json"))
    for f in files:
        if not f.is_file():
            continue
        text = f.read_text(encoding="utf-8", errors="replace")
        m = FORBIDDEN_TEXT.search(text)
        if m:
            out.append(violation("E003", f"{f.relative_to(d)}: forbidden text {m.group(0)!r}"))
        if f.suffix == ".md" and ABS_PATH.search(text):
            out.append(violation("D002", f"{f.name}: absolute path"))
    if not (d / "README.md").is_file():
        out.append(violation("D001", "README.md missing"))
    return out


def check_registry(pid: str, d: Path, registry: list[dict], all_plots: list[dict], chart_taxonomy, rules: dict) -> list[dict]:
    """`registry`: listed families; `all_plots`: including hidden ones (hidden families need no chart type)."""
    from plot_web.plot_registry import _plot_matches_chart

    out = []
    fams = [p for p in registry if p.get("engine_plugin_id") == pid or p.get("id") == pid]
    if not fams and not any(p.get("engine_plugin_id") == pid or p.get("id") == pid for p in all_plots):
        out.append(violation("G001", "not in plot_web/registry/registry.json (run python -m plot_web.plot_registry build)"))
    for fam in fams:
        if not any(_plot_matches_chart(fam, c) for g in chart_taxonomy for c in g["charts"]):
            out.append(violation("G002", f"family {fam['id']} has no chart type in CHART_CATEGORY_TAXONOMY"))
        if not fam.get("analysis_contexts") or not fam.get("tasks"):
            out.append(violation("G004", f"family {fam['id']} lacks analysis_contexts/tasks (overrides.yaml)"))
    families = {p for v in (rules.get("families") or {}).values() for p in v}
    if pid not in families:
        out.append(violation("G003", "no vNext family in vnext/migrate/rules.yaml"))
    if not (d / "vnext" / "metadata.yaml").is_file():
        out.append(violation("G003", "vnext/metadata.yaml missing (python -m vnext.cli migrate)"))
    return out


def check_plugin(pid: str, registry, all_plots, chart_taxonomy, rules) -> list[dict]:
    d = PLUGIN_DIR / pid
    return (check_config(pid, d) + check_schema(d) + check_r(d) + check_examples(d) + check_text(d)
            + check_registry(pid, d, registry, all_plots, chart_taxonomy, rules))


def key(v: dict) -> str:
    return f"{v['rule']}|{v['detail']}"


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("plugins", nargs="*")
    ap.add_argument("--update-baseline", action="store_true")
    ap.add_argument("--all-violations", action="store_true", help="also print baselined violations")
    args = ap.parse_args(argv)

    from plot_web.plot_registry import CHART_CATEGORY_TAXONOMY, get_all_plots, load_registry

    reg = load_registry()
    registry = get_all_plots(reg)
    all_plots = get_all_plots(reg, include_hidden=True)
    rules = yaml.safe_load((ROOT / "vnext" / "migrate" / "rules.yaml").read_text(encoding="utf-8")) or {}
    ids = args.plugins or sorted(p.parent.name for p in PLUGIN_DIR.glob("*/config.yaml"))
    baseline = json.loads(BASELINE.read_text(encoding="utf-8")) if BASELINE.is_file() else {}

    result = {pid: check_plugin(pid, registry, all_plots, CHART_CATEGORY_TAXONOMY, rules) for pid in ids}

    if args.update_baseline:
        if args.plugins:
            merged = dict(baseline)
            merged.update({pid: sorted(key(v) for v in vs) for pid, vs in result.items()})
        else:
            merged = {pid: sorted(key(v) for v in vs) for pid, vs in result.items()}
        merged = {k: v for k, v in sorted(merged.items()) if v}
        BASELINE.write_text(json.dumps(merged, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"baseline written: {sum(len(v) for v in merged.values())} violations in {len(merged)} plugins")
        return 0

    new_total = 0
    for pid, vs in result.items():
        known = set(baseline.get(pid, []))
        new = [v for v in vs if key(v) not in known]
        old = [v for v in vs if key(v) in known]
        new_total += len(new)
        for v in new:
            print(f"NEW  {pid}: [{v['rule']}] {v['detail']}")
        if args.all_violations:
            for v in old:
                print(f"     {pid}: [{v['rule']}] {v['detail']}")
    fixed = sum(len(set(baseline.get(pid, [])) - {key(v) for v in vs}) for pid, vs in result.items())
    print(f"{len(ids)} plugins checked: {new_total} new violation(s), "
          f"{sum(len(v) for v in result.values()) - new_total} baselined, {fixed} baselined fixed")
    if fixed:
        print("Baselined violations were fixed: run with --update-baseline to lock that in.")
    return 1 if new_total else 0


if __name__ == "__main__":
    sys.exit(main())
