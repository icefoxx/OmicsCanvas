"""Observable integration checks for portable skills and the local plotting CLI."""
import copy
import csv
import json
import subprocess
import sys
from pathlib import Path
import pytest
from omicscanvas.catalog import ROOT, PLUGINS, catalog, describe, workflows
from omicscanvas.cli import main, render
from omicscanvas.planning import PlanError, build_plan, parse_inputs, parse_sets, validate_plan


def test_catalog_covers_every_engine_and_workflows_have_real_skill_files():
    entries=catalog(); ids={x['plugin_id'] for x in entries}
    assert ids == {p.parent.name for p in PLUGINS.glob('*/config.yaml')}
    assert all(e['workflows'] for e in entries)
    for flow in workflows():
        assert set(flow['plugins']) <= ids
        assert (ROOT/flow['skill']).is_file()
    assert describe('volcano')['plugin_id'] == 'sca_volcano_plot'
    assert describe('survival_plot')['parameters']['time_column']['type'] == 'column'


def test_absolute_launcher_works_without_server_from_other_directory(tmp_path):
    result=subprocess.run([sys.executable,str(ROOT/'scripts/omicscanvas.py'),'catalog','--workflow','clinical-outcomes'],cwd=tmp_path,capture_output=True,text=True)
    assert result.returncode == 0, result.stderr
    assert 'survival_plot' in {x['plugin_id'] for x in json.loads(result.stdout)['engines']}


def test_inputs_are_unambiguous_and_json_settings_preserve_types(tmp_path):
    path=tmp_path/'a=b.csv';path.write_text('time,event\n1,1\n')
    assert parse_inputs([str(path)]) == {'input':path.resolve()}
    with pytest.raises(PlanError,match='repeated'): parse_inputs([str(path),str(path)])
    assert parse_sets(['width=8','risk_table_show=false','group_colors={"A":"#0072B2"}']) == {'width':8,'risk_table_show':False,'group_colors':{'A':'#0072B2'}}


@pytest.mark.parametrize('params', [{'width':-1},{'risk_table_show':'false'},{'curve_type':'calibraton'},{'unknown_setting':3}])
def test_bad_parameters_fail_before_render(params):
    with pytest.raises(PlanError): build_plan('survival_plot',{},params,example='basic')


def test_required_columns_do_not_silently_fall_back(tmp_path):
    path=tmp_path/'mine.csv';path.write_text('time,event,group\n2,1,A\n3,0,B\n')
    with pytest.raises(PlanError,match='Column mapping'):
        build_plan('survival_plot',{'input':path},{'time_column':'missing'})
    with pytest.raises(PlanError,match='exclusive'):
        build_plan('survival_plot',{'input':path},{},example='basic')
    with pytest.raises(PlanError,match='contract'):
        build_plan('linked_matrix_network_plot',{'input':path},{})


def test_changed_input_and_invalid_plan_do_not_start_renderer(tmp_path):
    path=tmp_path/'mine.csv';path.write_text('time,event,group\n2,1,A\n3,0,B\n')
    plan=build_plan('survival_plot',{'input':path},{})
    assert plan['validation']['valid']
    path.write_text(path.read_text()+'4,1,A\n')
    assert not validate_plan(plan)['valid']
    with pytest.raises(PlanError,match='validation failed'):
        render(plan,tmp_path/'should-not-exist')
    assert not (tmp_path/'should-not-exist').exists()
    bad=copy.deepcopy(plan);bad['plotspec']['mapping']='broken'
    assert not validate_plan(bad)['valid']


def test_rules_retrieval_never_calls_llm(monkeypatch,capsys):
    from plot_web import ai_assistant
    def forbidden(*args,**kwargs): raise AssertionError('Network/model call during local retrieval')
    monkeypatch.setattr(ai_assistant,'chat_completion',forbidden)
    source=ROOT/'plugins/binary_evaluation_plot/examples/basic/input/data.csv'
    assert main(['recommend','--goal','calibration curve, do not draw ROC','--input',str(source)]) == 0
    result=json.loads(capsys.readouterr().out)
    assert result['candidates'][0]['plugin_id'] == 'binary_evaluation_plot'
    assert result['candidates'][0]['draft']['mode'] == 'calibration'
    assert result['candidates'][0]['workflow_skills']


@pytest.mark.parametrize('pid,example,expected', [('survival_plot','basic',130),('binary_evaluation_plot','calibration',160),('interactive_3d_scatter','basic',225),('linked_matrix_network_plot','basic',None)])
def test_real_r_render_and_complete_inputs(pid,example,expected,tmp_path):
    plan=build_plan(pid,{}, {},example=example)
    assert plan['validation']['valid'],plan['validation']['errors']
    out=tmp_path/pid
    result=render(plan,out,bundle=False)
    assert result['ok'],result
    assert all((out/f'result.{kind}').is_file() for kind in ('png','svg','pdf'))
    figure=json.loads((out/'figure.json').read_text())
    if expected: assert figure['data']['input_rows'] == expected
    if pid == 'binary_evaluation_plot': assert figure['statistics']['mode'] == 'calibration'
    if pid == 'linked_matrix_network_plot': assert '--links' in result['direct_command']
    assert (out/'params.json').is_file() and (out/'validation.json').is_file()
    with pytest.raises(PlanError,match='empty directory'): render(plan,out,bundle=False)


def test_named_data_plan_file_cli_and_reproduction(tmp_path,capsys):
    source=ROOT/'docs/qa/fixtures/ai_survival_named_columns.csv'
    before=source.read_bytes()
    plan_path=tmp_path/'plan.json'
    assert main(['plan','--plugin','survival_plot','--input',str(source),
        '--set','time_column=followup_months','--set','event_column=event_status','--set','group_column=cohort',
        '--output',str(plan_path)]) == 0
    capsys.readouterr()
    output=tmp_path/'output'
    assert main(['render','--plan',str(plan_path),'--output',str(output)]) == 0
    result=json.loads(capsys.readouterr().out)
    assert result['data_source'] == 'user_files'
    with (output/'group_counts_used.csv').open() as f:
        assert [int(row['n']) for row in csv.DictReader(f)] == [6,6]
    assert source.read_bytes() == before
    bundle=output/'reproduction_bundle'
    assert (bundle/'manifest.json').is_file()
    assert main(['reproduce','--bundle-dir',str(bundle),'--output',str(tmp_path/'reproduced'),'--compare']) == 0
    assert json.loads(capsys.readouterr().out)['figure_identical']


def test_cli_errors_are_json_and_no_plan_overrides(tmp_path,capsys):
    plan=build_plan('survival_plot',{}, {},example='basic')
    path=tmp_path/'plan.json';path.write_text(json.dumps(plan))
    assert main(['render','--plan',str(path),'--set','width=10','--output',str(tmp_path/'out')]) == 2
    assert json.loads(capsys.readouterr().out)['ok'] is False


@pytest.mark.parametrize('pid', ['combo_bar_dot_matrix','interactive_dual_triangle_heatmap_plot','interactive_genomic_signal_track_plot','interactive_mantel_correlation_network','interactive_radar_plot'])
def test_canonical_legacy_arrays_and_input_aliases_remain_valid(pid):
    plan=build_plan(pid,{}, {},example='basic')
    assert plan['validation']['valid'],plan['validation']['errors']
    if pid == 'interactive_genomic_signal_track_plot':
        assert 'signal' in plan['inputs'] and 'input' not in plan['inputs']
        assert plan['compatibility_notes']
    if pid == 'interactive_dual_triangle_heatmap_plot':
        assert 'upper' in plan['inputs'] and 'annot' not in plan['inputs']
    if pid == 'interactive_radar_plot':
        assert describe(pid)['parameters']['radial_limits']['type'] == 'array'



def test_renderer_scientific_failure_stays_failed_without_example_fallback(tmp_path,capsys):
    source=tmp_path/'one-class.csv'
    data='outcome,score,group\n0,0.1,A\n0,0.3,A\n0,0.7,A\n'
    source.write_text(data)
    output=tmp_path/'invalid-out'
    assert main(['render','--plugin','binary_evaluation_plot','--input',str(source),'--set','plot_type=calibration','--output',str(output),'--no-bundle']) == 3
    result=json.loads(capsys.readouterr().out)
    assert not result['ok'] and result['data_source'] == 'user_files'
    assert result['error'] and not (output/'result.png').exists()
    assert source.read_text() == data
