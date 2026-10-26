"""Build and revalidate complete-input plans, without invoking an AI provider."""
from __future__ import annotations
import json
import math
from pathlib import Path
from .catalog import PLUGINS, config, fields, resolve_plugin, workflows
from vnext.adapters.legacy_r import legacy_params_to_plotspec, plotspec_to_legacy_params
from vnext.provenance.bundle import describe_inputs
from vnext.validate.pipeline import validate_plotspec
from vnext.plotspec.model import validate_schema


class PlanError(ValueError):
    def __init__(self, message: str, details=None):
        super().__init__(message)
        self.details = details


def parse_inputs(values: list[str]) -> dict[str, Path]:
    result = {}
    for raw in values:
        # Existing filenames may themselves contain '='.
        if Path(raw).is_file():
            key,path = 'input',raw
        elif '=' in raw:
            key,path = raw.split('=',1)
        else:
            key,path = 'input',raw
        if not key or key in result:
            raise PlanError(f'Input field {key!r} is empty or repeated.')
        file = Path(path).expanduser().resolve()
        if not file.is_file():
            raise PlanError(f'Input file does not exist: {file}')
        result[key] = file
    return result


def parse_sets(values: list[str]) -> dict:
    result = {}
    for raw in values:
        key,sep,value = raw.partition('=')
        if not sep or not key:
            raise PlanError('Each --set must be key=value; arrays and maps use JSON.')
        if key in result:
            raise PlanError(f'Parameter {key!r} is repeated.')
        try:
            parsed = json.loads(value)
        except json.JSONDecodeError:
            parsed = value
        result[key] = parsed
    return result


def input_errors(pid: str, files: dict[str, Path]) -> list[dict]:
    declared = config(pid).get('inputs') or [{'id':'input','required':True}]
    allowed = {i.get('id') or i.get('name') or 'input':i for i in declared}
    errors = []
    for field in files:
        if field not in allowed:
            errors.append({'field':field,'message':'Unknown input field. Declared fields: '+', '.join(allowed)})
    for field,definition in allowed.items():
        if definition.get('required') and field not in files:
            errors.append({'field':field,'message':'Required input file missing; no example data will be substituted.'})
        if field in files:
            formats = definition.get('formats') or []
            if formats and files[field].suffix.lower().lstrip('.') not in formats:
                errors.append({'field':field,'message':f'Expected one of {formats}; convert the table explicitly before planning.'})
    return errors


def parameter_errors(pid: str, params: dict, explicit_keys=()) -> list[dict]:
    schema = fields(pid)
    errors = []
    for key in explicit_keys:
        if key not in schema:
            errors.append({'field':key,'message':'Unknown parameter; inspect describe output.'})
    for key,value in params.items():
        if key not in schema:
            continue  # Preserve canonical legacy example aliases; never accept new ones as overrides.
        field = schema[key]
        kind = field.get('type')
        if value is None and field.get('default') is None:
            continue
        valid = True
        if kind in ('number','integer'):
            valid = isinstance(value,(int,float)) and not isinstance(value,bool) and math.isfinite(value)
            if valid and kind == 'integer': valid = float(value).is_integer()
            if valid and field.get('min') is not None: valid = value >= field['min']
            if valid and field.get('max') is not None: valid = value <= field['max']
        elif kind == 'boolean': valid = isinstance(value,bool)
        elif kind == 'select':
            options = [o.get('value') if isinstance(o,dict) else o for o in field.get('options',[])]
            valid = value in options
        elif kind == 'object': valid = isinstance(value,dict)
        elif kind == 'array':
            valid = isinstance(value,list)
            if valid and field.get('items'):
                from jsonschema import Draft202012Validator
                valid = not any(Draft202012Validator({'type':'array','items':field['items']}).iter_errors(value))
        elif kind in ('columns','string_array','color_array'):
            valid = isinstance(value,list) and all(isinstance(v,str) for v in value)
        elif kind == 'number_array':
            valid = isinstance(value,list) and all(isinstance(v,(float,int)) and not isinstance(v,bool) and math.isfinite(v) for v in value)
        elif kind in ('column','string','textarea','color','file'): valid = isinstance(value,str)
        if not valid:
            errors.append({'field':key,'message':f'Invalid {kind} value: {value!r}. See parameter type/options/range in describe.'})
    return errors


def column_errors(pid: str, files: dict[str, Path], params: dict) -> list[dict]:
    from plot_web.table_io import read_table_as_dicts
    headers = set()
    for file in files.values():
        if file.suffix.lower() in {'.csv','.tsv','.txt','.xlsx','.xlsm'}:
            columns, _, _ = read_table_as_dicts(file,max_rows=1)
            headers.update(columns)
    if not headers: return []
    result = []
    for key,field in fields(pid).items():
        value = params.get(key)
        if field.get('type') in ('column','columns') and value not in (None,'',[]):
            values = value if isinstance(value,list) else [value]
            missing = [v for v in values if v not in headers]
            if missing: result.append({'field':key,'message':f'Columns not found: {missing}. Available: {sorted(headers)}'})
    return result


def _bundle(pid: str, example: str) -> tuple[dict,dict,list]:
    root = (PLUGINS/pid/'examples').resolve()
    bundle = (root/example).resolve()
    if not bundle.is_relative_to(root) or bundle == root:
        raise PlanError('Invalid example ID.')
    manifest_path = bundle/'manifest.json'
    if not manifest_path.is_file():
        raise PlanError(f'No canonical example {example!r} for {pid}; use describe to list examples.')
    manifest = json.loads(manifest_path.read_text())
    def local(value):
        path = (bundle/value).resolve()
        if not path.is_relative_to(bundle) or not path.is_file():
            raise PlanError('Example manifest points outside its bundle or to a missing file.')
        return path
    inputs = {key:local(value) for key,value in manifest.get('inputs',{}).items()}
    params = json.loads(local(manifest.get('params','params.json')).read_text())
    declared = config(pid).get('inputs') or []
    names = [i.get('id') or i.get('name') for i in declared]
    required = [i.get('id') or i.get('name') for i in declared if i.get('required')]
    notes = []
    if 'input' in inputs and 'input' not in names and required:
        target = required[0]
        if target in inputs and inputs[target] != inputs['input']:
            raise PlanError('Canonical main-input alias conflicts with its declared field.')
        inputs[target] = inputs.pop('input')
        notes.append({'code':'LEGACY_INPUT_ALIAS','field':target,'message':f'Canonical input alias input resolves to declared primary field {target}.'})
    if 'annot' in inputs and 'annot' not in names and 'annotation' in names:
        if 'annotation' not in inputs: inputs['annotation'] = inputs['annot']
        inputs.pop('annot')
        notes.append({'code':'LEGACY_INPUT_ALIAS','field':'annotation','message':'Canonical annot alias resolves to annotation; an explicit annotation field takes precedence, matching the shared command builder.'})
    return inputs,params,notes


def validate_plan(plan: dict) -> dict:
    if plan.get('plan_version') != '1.0':
        raise PlanError('Unsupported or missing plan_version.')
    spec = plan.get('plotspec')
    if not isinstance(spec,dict): raise PlanError('Plan must contain a PlotSpec.')
    schema = validate_schema(spec)
    if not schema['valid']: return schema
    pid = resolve_plugin((spec.get('skill') or {}).get('id',''))
    records = plan.get('inputs')
    if not isinstance(records,dict) or not records: raise PlanError('Plan has no input files.')
    paths = {key:Path(value['path']).expanduser().resolve() for key,value in records.items()}
    errors = []
    for key,path in paths.items():
        if not path.is_file(): errors.append({'field':key,'message':f'Missing input: {path}'})
    if errors: return {'valid':False,'errors':errors,'warnings':[]}
    current = describe_inputs(paths)
    for key,value in current.items():
        if value['checksum'] != records[key].get('checksum') or value['checksum'] != (spec.get('inputs',{}).get(key) or {}).get('checksum'):
            errors.append({'field':key,'message':'Input bytes changed since planning. Create a new plan.'})
    params = plotspec_to_legacy_params(spec)
    errors.extend(input_errors(pid,paths))
    legacy_keys = set()
    if plan.get('example_id'):
        _,original,_ = _bundle(pid,plan['example_id'])
        legacy_keys = set(original)
    errors.extend(parameter_errors(pid,params,set(params)-legacy_keys-{'plugin_id'}))
    errors.extend(column_errors(pid,paths,params))
    scientific = validate_plotspec(spec,tables=paths)
    errors.extend(scientific.get('errors') or [])
    return {'valid':not errors,'errors':errors,'warnings':(scientific.get('warnings') or []) + plan.get('compatibility_notes',[]),'scientific':scientific}


def build_plan(plugin: str, inputs: dict[str,Path], params: dict, *, example: str | None = None,
               goal: str = '', seed: int | None = None) -> dict:
    pid = resolve_plugin(plugin)
    if seed is None:
        from plot_web.server.runner import DEFAULT_SEED
        seed = DEFAULT_SEED
    base = {}
    notes = []
    if example:
        if inputs: raise PlanError('--example and --input are exclusive. Real inputs are never mixed with synthetic auxiliary tables.')
        inputs,base,notes = _bundle(pid,example)
    if not inputs: raise PlanError('Supply --input field=path, or choose --example explicitly.')
    if not isinstance(params,dict): raise PlanError('Parameters must be a JSON object.')
    errors = input_errors(pid,inputs) + parameter_errors(pid,params,params.keys())
    if errors: raise PlanError('Input or parameter contract failed.',errors)
    merged = {**base,**params}
    errors = column_errors(pid,inputs,merged)
    if errors: raise PlanError('Column mapping failed.',errors)
    if pid in {'survival_plot','binary_evaluation_plot','interactive_3d_scatter'}:
        from plot_web.ai_plot_draft import complete_params
        from plot_web.table_io import read_table_as_dicts
        primary = inputs.get('input') or next(iter(inputs.values()))
        columns,_,_ = read_table_as_dicts(primary,max_rows=1)
        merged = complete_params(pid,{'columns':columns},merged)
    descriptions = describe_inputs(inputs)
    spec = legacy_params_to_plotspec(pid,merged,inputs=descriptions,seed=seed)
    if goal: spec['provenance']['intent_text'] = goal
    plan = {'plan_version':'1.0','data_source':'builtin_example' if example else 'user_files',
            'example_id':example,'compatibility_notes':notes,'goal':goal,'data_scope':'all_supplied_rows; renderer filters and aggregations are explicit parameters',
            'workflow_ids':[w['id'] for w in workflows() if pid in w['plugins']],
            'inputs':{key:{**descriptions[key],'path':str(path.resolve())} for key,path in inputs.items()},
            'plotspec':spec}
    plan['validation'] = validate_plan(plan)
    return plan
