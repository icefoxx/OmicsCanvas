"""Provider-neutral plotting CLI. No web server, model SDK or credentials required."""
from __future__ import annotations
import argparse
import copy
import json
import shlex
import shutil
import sys
import subprocess
import tempfile
from pathlib import Path
from . import __version__
from .catalog import ROOT, PLUGINS, catalog, config, describe, resolve_plugin, workflows
from .planning import PlanError, build_plan, parse_inputs, parse_sets, validate_plan


def emit(value):
    print(json.dumps(value,indent=2,ensure_ascii=False,default=str,allow_nan=False))


def _read_params(args):
    params = json.loads(Path(args.params).read_text()) if args.params else {}
    if not isinstance(params,dict): raise PlanError('--params must contain a flat JSON object.')
    return {**params,**parse_sets(args.set)}


def _make(args):
    from plot_web.server.runner import DEFAULT_SEED
    return build_plan(args.plugin,parse_inputs(args.input),_read_params(args),example=args.example,
                      goal=args.goal,seed=args.seed if args.seed is not None else DEFAULT_SEED)


def _load(path):
    value = json.loads(Path(path).read_text())
    if not isinstance(value,dict): raise PlanError('A plan must be a JSON object.')
    return value


def _write(path,value):
    path = Path(path).expanduser().resolve()
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,indent=2,ensure_ascii=False,allow_nan=False)+'\n')
    return path


def render(plan: dict, output: Path, *, bundle=True) -> dict:
    from vnext.adapters.legacy_r import plotspec_to_legacy_params, run_legacy_plugin
    from vnext.provenance.bundle import describe_inputs, write_reproduction_bundle
    from plot_web.server.runner import build_command, plugin_env, DEFAULT_SEED
    validation = validate_plan(plan)
    if not validation['valid']: raise PlanError('Plan validation failed; rendering was not started.',validation)
    output = output.expanduser().resolve()
    if output.exists() and (not output.is_dir() or any(output.iterdir())):
        raise PlanError('Output must be a new or empty directory. Existing results are never silently overwritten.')
    spec = copy.deepcopy(plan['plotspec'])
    pid = spec['skill']['id']
    params = plotspec_to_legacy_params(spec)
    paths = {k:Path(v['path']) for k,v in plan['inputs'].items()}
    output.mkdir(parents=True,exist_ok=True)
    _write(output/'plan.json',plan)
    _write(output/'validation.json',validation)
    _write(output/'plotspec.json',spec)
    # Render an immutable snapshot; never overwrite or filter source data in place.
    with tempfile.TemporaryDirectory(prefix='omicscanvas_inputs_') as temp:
        snapshots = {}
        for key,path in paths.items():
            dest = Path(temp)/key/path.name
            dest.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(path,dest)
            snapshots[key] = dest
        current = describe_inputs(snapshots)
        if any(current[k]['checksum'] != plan['inputs'][k]['checksum'] for k in snapshots):
            raise PlanError('Input changed while taking a snapshot. Create a new plan.')
        result = run_legacy_plugin(skill_id=pid,params=params,inputs=snapshots,output_dir=output,
                                   seed=spec.get('provenance',{}).get('seed'))
        bundle_meta = None
        if bundle and result['ok']:
            bundle_meta = write_reproduction_bundle(bundle_dir=output/'reproduction_bundle',spec=spec,
                inputs=snapshots,params=params,figure_files=result['figure_paths'],validation=validation)
    # This is the reusable direct engine command; the executed command used temporary snapshots.
    direct = build_command(pid,config(pid),paths,output/'params.json',output)
    runtime_env = plugin_env(spec.get('provenance',{}).get('seed',DEFAULT_SEED))
    direct_env = {key:runtime_env[key] for key in ('R_PROFILE_USER','OMICSCANVAS_SEED','OMICSCANVAS_USER_RPROFILE') if key in runtime_env}
    _write(output/'direct_command.json',direct)
    _write(output/'direct_environment.json',direct_env)
    (output/'direct_command.sh').write_text('# POSIX shell: run from the repository root. Reuses saved parameters and seed.\n'+shlex.join(['env',*[f'{key}={value}' for key,value in direct_env.items()],*direct])+'\n')
    payload = {'ok':result['ok'],'plugin_id':pid,'data_source':plan['data_source'],
               'output':str(output),'figures':result['figures'],'bundle':bundle_meta,
               'direct_command':direct,'direct_environment':direct_env,'validation_warnings':validation.get('warnings',[])}
    if not result['ok']:
        error = output/'error.json'
        payload['error'] = json.loads(error.read_text()) if error.is_file() else {'message':'Renderer failed. Inspect adapter_stderr.log.'}
        payload['returncode'] = result['returncode']
    _write(output/'cli_result.json',payload)
    return payload


def recommend(args):
    from plot_web import ai_assistant
    files = parse_inputs(args.input)
    profile = ai_assistant.profile_table(next(iter(files.values()))) if files else {'columns':[],'numeric_columns':[],'categorical_columns':[],'tags':[]}
    allowed = {x['plugin_id'] for x in catalog(workflow=args.workflow)}
    # Rules only: this command never calls chat_completion or another network service.
    ranked = ai_assistant.recommend_plugins(profile,PLUGINS,args.goal,top_k=80)
    candidates = []
    for rec in ranked:
        pid = rec['plugin_id']
        if pid not in allowed: continue
        draft = rec.get('draft') or {}
        candidates.append({'plugin_id':pid,'name':rec['name'],'score':rec['score'],'reason':rec['reason'],
            'draft':draft,'workflow_skills':[str(ROOT/w['skill']) for w in workflows() if pid in w['plugins']],
            'contract_command':f'python -m omicscanvas describe {pid}',
            'status':'mapping_needed' if draft.get('error') else 'review_required'})
        if len(candidates) >= args.top_k: break
    return {'engine':'local_rules','goal':args.goal,'data_profile':{k:v for k,v in profile.items() if k not in ('preview_rows','path','converted_csv')},
            'candidates':candidates,'selection_status':'Review scientific suitability and mappings; no plot has been rendered.'}


def main(argv=None):
    parser = argparse.ArgumentParser(prog='omicscanvas',description=__doc__)
    parser.add_argument('--version',action='version',version=__version__)
    sub = parser.add_subparsers(dest='command',required=True)
    p = sub.add_parser('catalog',help='Search the live compact engine catalog')
    p.add_argument('--query',default=''); p.add_argument('--workflow')
    p = sub.add_parser('workflows',help='List L1 workflows and their skill paths')
    p = sub.add_parser('skills',help='List L0 router, L1 workflows and the L2 execution skill')
    p = sub.add_parser('describe',help='Read one engine schema, input contract, examples and Plot Guide')
    p.add_argument('plugin')
    p = sub.add_parser('profile',help='Inspect table columns and complete row count; does not render')
    p.add_argument('file')
    p = sub.add_parser('recommend',help='Retrieve candidate workflows/engines using local rules')
    p.add_argument('--goal',required=True); p.add_argument('--input',action='append',default=[])
    p.add_argument('--workflow'); p.add_argument('--top-k',type=int,choices=range(1,7),default=3)
    def options(p):
        p.add_argument('--plugin',required=True)
        group = p.add_mutually_exclusive_group(required=True)
        group.add_argument('--input',action='append',default=[],help='path or field=path, repeat for auxiliary inputs')
        group.add_argument('--example',help='Explicit canonical synthetic bundle ID')
        p.add_argument('--params',help='Flat parameter JSON file')
        p.add_argument('--set',action='append',default=[],metavar='KEY=VALUE',help='JSON value or a plain string; repeatable')
        p.add_argument('--goal',default='',help='Provenance text only; select actual modes with --set')
        p.add_argument('--seed',type=int)
    p = sub.add_parser('plan',help='Create a validated, checksum-bound plan without rendering')
    options(p); p.add_argument('--output',required=True,help='Plan JSON file')
    p = sub.add_parser('validate',help='Revalidate a saved plan and input checksums')
    p.add_argument('--plan',required=True)
    p = sub.add_parser('render',help='Execute a reviewed plan, or explicit engine inputs/parameters')
    p.add_argument('--plan'); p.add_argument('--plugin'); p.add_argument('--input',action='append',default=[])
    p.add_argument('--example'); p.add_argument('--params'); p.add_argument('--set',action='append',default=[])
    p.add_argument('--goal',default=''); p.add_argument('--seed',type=int)
    p.add_argument('--output',required=True); p.add_argument('--no-bundle',action='store_true')
    p = sub.add_parser('reproduce',help='Reproduce a saved bundle with the existing vNext pipeline')
    p.add_argument('--bundle-dir',required=True); p.add_argument('--output',required=True)
    p.add_argument('--compare',action='store_true')
    p = sub.add_parser('doctor',help='Report runtime availability without installing anything')
    args = parser.parse_args(argv)
    try:
        cmd = args.command
        if cmd == 'catalog': emit({'engines':catalog(args.query,args.workflow)})
        elif cmd == 'workflows': emit({'workflows':workflows()})
        elif cmd == 'skills': emit({'router':str(ROOT/'skills/omicscanvas-router/SKILL.md'),
            'workflows':[{**w,'skill':str(ROOT/w['skill'])} for w in workflows()],
            'execution':str(ROOT/'skills/omicscanvas-render/SKILL.md')})
        elif cmd == 'describe': emit(describe(args.plugin))
        elif cmd == 'profile':
            from plot_web.ai_assistant import profile_table
            emit(profile_table(Path(args.file).expanduser().resolve()))
        elif cmd == 'recommend': emit(recommend(args))
        elif cmd == 'plan':
            plan = _make(args); path = _write(args.output,plan)
            emit({'plan':str(path),'valid':plan['validation']['valid'],'validation':plan['validation']})
            return 0 if plan['validation']['valid'] else 2
        elif cmd == 'validate':
            result = validate_plan(_load(args.plan)); emit(result); return 0 if result['valid'] else 2
        elif cmd == 'render':
            if args.plan:
                if args.plugin or args.input or args.example or args.params or args.set or args.goal or args.seed is not None:
                    raise PlanError('--plan cannot be mixed with new inputs or parameters. Create a new plan to change them.')
                plan = _load(args.plan)
            else:
                if not args.plugin: raise PlanError('Specify --plan, or --plugin with --input/--example.')
                plan = _make(args)
            result = render(plan,Path(args.output),bundle=not args.no_bundle); emit(result)
            return 0 if result['ok'] else 3
        elif cmd == 'reproduce':
            from vnext.cli import cmd_reproduce
            target=Path(args.output)
            if target.exists() and (not target.is_dir() or any(target.iterdir())):
                raise PlanError('Reproduction output must be new or empty.')
            return cmd_reproduce(argparse.Namespace(bundle_dir=args.bundle_dir,output=args.output,compare=args.compare))
        elif cmd == 'doctor':
            emit({'python':sys.executable,'Rscript':shutil.which('Rscript'),'server_required':False,
                  'model_api_required':False,'engines':len(catalog()),'workflow_count':len(workflows()),
                  'note':'R package availability is checked by each selected renderer; doctor does not install dependencies.'})
        return 0
    except (ValueError,TypeError,KeyError,OSError,subprocess.SubprocessError) as exc:
        emit({'ok':False,'error':str(exc),'details':getattr(exc,'details',None)})
        return 2


if __name__ == '__main__': raise SystemExit(main())
