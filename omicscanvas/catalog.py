"""Small, live capability catalog; full contracts are loaded only on demand."""
from __future__ import annotations
import json
import re
from pathlib import Path
import yaml
from plot_web.schema_normalize import normalize_params_schema

ROOT = Path(__file__).resolve().parents[1]
PLUGINS = ROOT / 'plugins'
WORKFLOWS = ROOT / 'skills/omicscanvas-router/workflows.yaml'


def workflows() -> list[dict]:
    return yaml.safe_load(WORKFLOWS.read_text(encoding='utf-8'))['workflows']


def registry() -> list[dict]:
    # Read only: never rebuild generated project metadata during discovery.
    return json.loads((ROOT/'plot_web/registry/registry.json').read_text())['plots']


def resolve_plugin(value: str) -> str:
    if not re.fullmatch(r'[a-zA-Z0-9_-]+', value):
        raise ValueError('Use a plugin ID or a registry family ID, not a path.')
    if (PLUGINS/value/'config.yaml').is_file():
        return value
    exact = [p['engine_plugin_id'] for p in registry() if value == p['id']]
    aliases = {p['engine_plugin_id'] for p in registry() if value.lower() in [str(a).lower() for a in p.get('aliases', [])]}
    matches = set(exact) or aliases
    if len(matches) == 1:
        return matches.pop()
    raise ValueError(f'Unknown or ambiguous plot {value!r}. Run catalog to find its engine ID.')


def config(plugin: str) -> dict:
    return yaml.safe_load((PLUGINS/resolve_plugin(plugin)/'config.yaml').read_text())


def fields(plugin: str) -> dict:
    schema = json.loads((PLUGINS/resolve_plugin(plugin)/'params_schema.json').read_text())
    norm = normalize_params_schema(schema) or {}
    result = {k:v for section in norm.values() if isinstance(section,dict) for k,v in section.items() if isinstance(v,dict)}
    # UI normalization historically turns every JSON array into string_array.
    # Keep the authored array semantics for CLI validation, including numeric arrays.
    def walk(node):
        if not isinstance(node,dict): return
        for key,value in node.items():
            if not isinstance(value,dict): continue
            if 'type' in value:
                if key in result and (value['type'] == 'array' or (value['type'] == 'object' and isinstance(value.get('default'),list))):
                    result[key] = {**result[key],'type':'array'}
                    if 'items' in value: result[key]['items'] = value['items']
                    if value['type'] == 'object': result[key]['compatibility_note'] = 'Legacy object field has an array default and array-valued renderer contract.'
            else: walk(value)
    walk(schema)
    return result


def catalog(query: str = '', workflow: str | None = None) -> list[dict]:
    flows = workflows()
    if workflow and workflow not in {w['id'] for w in flows}:
        raise ValueError(f'Unknown workflow {workflow!r}. Run workflows to list them.')
    families = registry()
    result = []
    for path in sorted(PLUGINS.glob('*/config.yaml')):
        cfg = yaml.safe_load(path.read_text()) or {}
        pid = path.parent.name
        related = [p for p in families if p['engine_plugin_id'] == pid]
        matches = [w for w in flows if pid in w['plugins']]
        if workflow and not any(w['id'] == workflow for w in matches):
            continue
        item = {'plugin_id':pid,'name':cfg.get('name',pid),'description':cfg.get('description',''),
                'language':cfg.get('language'),'workflows':[w['id'] for w in matches],
                'family_ids':[p['id'] for p in related],
                'contexts':sorted({x for p in related for x in p.get('analysis_contexts',[])}),
                'tasks':sorted({x for p in related for x in p.get('tasks',[])}),
                'input_fields':[i.get('id') or i.get('name') for i in cfg.get('inputs',[])],
                'contract_command':f'python -m omicscanvas describe {pid}'}
        aliases = [a for p in related for a in p.get('aliases',[])]
        text = json.dumps([item,aliases],ensure_ascii=False).lower()
        tokens = query.lower().split()
        if tokens and not all(token in text for token in tokens):
            continue
        result.append(item)
    return result


def describe(plugin: str) -> dict:
    pid = resolve_plugin(plugin)
    cfg = config(pid)
    matches = [p for p in registry() if p['engine_plugin_id'] == pid]
    examples = []
    for path in sorted((PLUGINS/pid/'examples').glob('*/manifest.json')):
        manifest = json.loads(path.read_text())
        examples.append({'id':path.parent.name,'label':manifest.get('label',path.parent.name),
                         'inputs':list((manifest.get('inputs') or {}).keys())})
    from plot_web.server.runner import input_flags
    return {'plugin_id':pid,'name':cfg.get('name',pid),'config':cfg,'parameters':fields(pid),
            'input_flags':input_flags(cfg),'examples':examples,
            'workflows':[w['id'] for w in workflows() if pid in w['plugins']],
            'guides':[p.get('guide') for p in matches if p.get('guide')],
            'references':{'readme':str(PLUGINS/pid/'README.md'),'schema':str(PLUGINS/pid/'params_schema.json'),
                          'execution_skill':str(ROOT/'skills/omicscanvas-render/SKILL.md')}}
