from pathlib import Path
import pytest
from plot_web import ai_assistant

ROOT = Path(__file__).resolve().parents[2]

@pytest.mark.parametrize('goal,plugin', [('Draw a survival curve','survival_plot'), ('Draw an oncoprint','oncoprint_plot'), ('Draw a Bland-Altman plot','bland_altman_plot'), ('Draw 3D embedding','interactive_3d_scatter')])
def test_explicit_specialty_request_routes_to_engine_and_workflow(goal, plugin):
    profile = dict(columns=['value'], numeric_columns=['value'], tags=[])
    recs = ai_assistant.recommend_plugins(profile, ROOT/'plugins', goal=goal)
    assert recs[0]['plugin_id'] == plugin
    skills = ai_assistant.match_skills(profile, recs, ROOT/'skills', goal=goal)
    assert any(s['skill_id'] == 'specialty-plot-workflows' and s['role'] == 'plot_workflow' for s in skills)
