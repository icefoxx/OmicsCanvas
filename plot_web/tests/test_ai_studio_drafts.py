"""Regression coverage for scientific intent, complete inputs and saved editor runs."""
import csv
import json
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from plot_web import ai_assistant as ai
from plot_web.ai_plot_draft import intent_params, chat_draft
from plot_web.app import app
from plot_web.server.plugins import demo_payload, plugin_config_path, read_yaml

ROOT = Path(__file__).resolve().parents[2]
CASES = json.loads((ROOT/'docs/qa/ai_studio_real_profile_routing_2026-10-25.json').read_text())

@pytest.mark.parametrize('case', CASES, ids=lambda c: c['plugin'])
def test_real_profile_explicit_goal_and_canonical_example(case):
    pid = case['plugin']
    demo = demo_payload(pid, read_yaml(plugin_config_path(pid)), example_id='basic')
    paths = demo['_file_paths']
    assert paths and all(p.is_file() for p in paths.values())
    source = paths.get('input') or paths.get('file') or next(iter(paths.values()))
    profile = ai.profile_table(source)
    recs = ai.recommend_plugins(profile, ROOT/'plugins', goal=case['goal'])
    assert recs[0]['plugin_id'] == pid
    skills = ai.match_skills(profile, recs, ROOT/'skills', goal=case['goal'])
    assert skills[0]['role'] == 'plot_workflow'

@pytest.mark.parametrize('pid,expected', [('survival_plot',130),('binary_evaluation_plot',160),('interactive_3d_scatter',225)])
def test_statistics_keep_complete_upload_even_legacy_row_limit(pid, expected, tmp_path):
    path = ROOT/'plugins'/pid/'examples/basic/input/data.csv'
    files, params, note = ai.prepare_demo_files(pid, path, ai.profile_table(path), tmp_path, max_rows=60)
    with files['input'].open() as f:
        assert len(list(csv.DictReader(f))) == expected
    assert f'all {expected} rows' in note

@pytest.mark.parametrize('goal,mode', [('calibration curve, do not draw ROC','calibration'),('precision-recall curve','precision_recall'),('decision curve analysis','decision_curve'),('ROC curve','roc')])
def test_requested_diagnostic_mode(goal, mode):
    assert intent_params('binary_evaluation_plot', goal) == {'plot_type':mode}

def test_ambiguous_modes_require_choice():
    with pytest.raises(ValueError, match='Choose one'):
        intent_params('binary_evaluation_plot','ROC and calibration')

def test_named_survival_mapping_and_unknown_assignment():
    path = ROOT/'docs/qa/fixtures/ai_survival_named_columns.csv'
    profile = ai.profile_table(path)
    params = ai.build_params_for_plugin('survival_plot', profile, 'Survival: followup_months as time, event_status as event, cohort as group')
    assert [params[k] for k in ('time_column','event_column','group_column')] == ['followup_months','event_status','cohort']
    with pytest.raises(ValueError, match='not found'):
        ai.build_params_for_plugin('survival_plot',profile,'time_column=missing')

def test_chat_proposes_colors_without_executing():
    path = ROOT/'plugins/survival_plot/examples/basic/input/data.csv'
    context = {'file':str(path),'profile':ai.profile_table(path),'goal':'survival curve','recommendations':[{'plugin_id':'survival_plot'}]}
    result = chat_draft(context,'Use all rows and change group colors to blue and orange')
    assert 'No figure has been changed yet' in result['reply']
    colors = result['render_action']['params']['group_colors']
    assert len(colors) == 2 and set(colors.values()) == {'#0072B2','#E69F00'}

def test_build_failure_does_not_replace_upload(monkeypatch, tmp_path):
    from plot_web.server.routes import ai as routes
    from plot_web.server import storage
    monkeypatch.setattr(routes, 'UPLOADS_DIR', tmp_path/'uploads')
    monkeypatch.setattr(routes, 'JOBS_DIR', tmp_path/'jobs')
    monkeypatch.setattr(routes, 'RESULTS_DIR', tmp_path/'results')
    session = tmp_path/'uploads/session'
    session.mkdir(parents=True)
    path = session/'bad.csv'
    path.write_text('name,value\na,1\nb,2\n')
    (session/'session.json').write_text(json.dumps({'file':str(path),'goal':'survival time_column=absent'}))
    def forbidden(*args, **kwargs):
        pytest.fail('An invalid upload must never invoke the built-in data resolver')
    monkeypatch.setattr(routes,'demo_payload',forbidden)
    with TestClient(app) as client:
        result = client.post('/api/ai/build-demo',json={'session_id':'session','plugin_id':'survival_plot'}).json()
    assert result['status'] == 'failed'
    assert 'not replaced' in result['ai']['note']

@pytest.mark.parametrize('pid,goal,expected_rows,mode', [
    ('survival_plot','Kaplan-Meier survival curve',130,'survival'),
    ('binary_evaluation_plot','calibration curve, do not draw ROC',160,'calibration'),
])
def test_real_ai_run_editor_handoff_and_input_bytes(pid, goal, expected_rows, mode, tmp_path, monkeypatch):
    from plot_web.server.routes import ai as routes, jobs
    saved = {}
    monkeypatch.setattr(routes, 'save_job', lambda job: saved.update({job['job_id']:dict(job)}))
    monkeypatch.setattr(jobs, 'load_job', lambda job_id: saved[job_id])
    monkeypatch.setattr(jobs, 'ROOT_DIR', tmp_path)
    for key in ('UPLOADS_DIR','JOBS_DIR','RESULTS_DIR'):
        monkeypatch.setattr(routes,key,tmp_path/key.lower())
    monkeypatch.setattr(ai,'chat_completion',lambda *args,**kwargs:None)
    path = ROOT/'plugins'/pid/'examples/basic/input/data.csv'
    with TestClient(app) as client:
        rec = client.post('/api/ai/recommend',files={'file':('data.csv',path.read_bytes(),'text/csv')},data={'goal':goal}).json()
        result = client.post('/api/ai/build-demo',json={'session_id':rec['session_id'],'plugin_id':pid}).json()
        assert result['status'] == 'completed', result.get('error')
        assert result['draft']['mode'] == mode
        assert result['draft']['data_scope'] == 'all_rows'
        assert 'job='+result['job_id'] in result['editor_url']
        handoff = client.get('/api/jobs/'+result['job_id']+'/editor').json()
        assert handoff['params'] == result['params_used']
        assert handoff['input_preview']['files']['input']['row_count_estimate'] == expected_rows
        downloaded = client.get(handoff['inputs']['input']['url'])
        assert len(list(csv.DictReader(downloaded.text.splitlines()))) == expected_rows
        meta = json.loads((Path(result['output_dir'])/'figure.json').read_text())
        if pid == 'binary_evaluation_plot':
            assert meta['statistics']['mode'] == 'calibration'
        else:
            with (Path(result['output_dir'])/'group_counts_used.csv').open() as f:
                counts = list(csv.DictReader(f))
            assert len(counts) == 2


def test_editor_handoff_rejects_files_outside_project(tmp_path):
    from fastapi import HTTPException
    from plot_web.server.routes.jobs import _editor_inputs
    path = tmp_path/'outside.csv'
    path.write_text('value\n1\n')
    with pytest.raises(HTTPException):
        _editor_inputs({'plugin_id':'survival_plot','uploaded_files':{'input':str(path)}})


def test_palette_keywords_do_not_match_inside_survival():
    from plot_web.palettes import recommend_palettes
    recs = recommend_palettes(research_goal='Kaplan-Meier survival curve',n_groups=2,limit=4)
    assert all('Pattern Analysis' not in p['reason'] for p in recs)


def test_missing_roles_report_candidates_and_custom_mapping_can_resolve(tmp_path):
    profile = {'columns':['months','censored_flag'], 'numeric_columns':['months','censored_flag']}
    with pytest.raises(ValueError, match='time_column: map a column'):
        ai.build_params_for_plugin('survival_plot',profile)
    params = ai.build_params_for_plugin('survival_plot',profile,custom_params={'time_column':'months','event_column':'censored_flag'})
    assert params['time_column'] == 'months'

@pytest.mark.parametrize('pid', ['survival_plot','linked_matrix_network_plot','binary_evaluation_plot'])
def test_builtin_run_uses_complete_bundle_and_its_own_profile(pid, tmp_path, monkeypatch):
    from plot_web.server.routes import ai as routes
    monkeypatch.setattr(routes,'save_job',lambda job:None)
    for key in ('UPLOADS_DIR','JOBS_DIR','RESULTS_DIR'):
        monkeypatch.setattr(routes,key,tmp_path/key.lower())
    source = tmp_path/'unrelated.csv'
    source.write_text('name,value\na,1\nb,2\n')
    result = routes._execute_ai_demo(session_id='builtin_test',session={'file':str(source),'goal':'calibration curve' if pid == 'binary_evaluation_plot' else ''},plugin_id=pid,prefer_builtin=True)
    assert result['status'] == 'completed', result.get('error')
    assert result['ai']['mode'] == 'builtin_demo'
    assert result['draft']['data_scope'] == 'builtin_example'
    if pid == 'survival_plot':
        assert result['draft']['rows'] == 130
    elif pid == 'binary_evaluation_plot':
        assert result['draft']['rows'] == 160
        assert result['params_used']['plot_type'] == 'calibration'
        assert result['params_used']['title'] == 'Probability calibration'
    else:
        assert len(result['uploaded_files']) >= 2


def test_unrelated_measurement_is_not_mapped_as_standard_error():
    profile = {'columns':['model','outcome','score'],'numeric_columns':['outcome','score'],'categorical_columns':['model']}
    params = ai.build_params_for_plugin('combo_bar_dot_matrix',profile)
    assert params['se_column'] == ''


def test_supplied_diagnostic_curve_requires_coordinates_instead_of_raw_predictions():
    profile = {'columns':['x','y'],'numeric_columns':['x','y']}
    params = ai.build_params_for_plugin('binary_evaluation_plot',profile,'ROC curve',custom_params={'input_mode':'curve'})
    assert params['input_mode'] == 'curve' and params['x_column'] == 'x' and params['y_column'] == 'y'
