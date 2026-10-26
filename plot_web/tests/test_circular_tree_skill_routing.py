from pathlib import Path
import pytest
from plot_web import ai_assistant

ROOT = Path(__file__).resolve().parents[2]
PROFILE = dict(columns=['UMAP_1','UMAP_2','class','subclass','subtype'], numeric_columns=['UMAP_1','UMAP_2'], categorical_columns=['class','subclass','subtype'], tags=['embedding'])

@pytest.mark.parametrize('goal', ['Draw a circular tree + embedding', '树状图+降维'])
def test_combined_chart_routes_to_engine_and_workflow(goal):
    recs = ai_assistant.recommend_plugins(PROFILE, ROOT/'plugins', goal=goal)
    assert recs[0]['plugin_id'] == 'circular_tree_embedding'
    assert 'example=basic' in recs[0]['editor_url']
    skills = ai_assistant.match_skills(PROFILE, recs, ROOT/'skills', goal=goal)
    assert any(s['skill_id']=='circular-tree-embedding' and s['role']=='plot_workflow' for s in skills)
    params = ai_assistant.build_params_for_plugin('circular_tree_embedding', PROFILE)
    assert params['hierarchy_columns'] == ['class','subclass']
    assert params['cluster_column'] == 'subtype' and params['tree_mode']=='annotation'
    assert params['feature_columns'] == []


def test_regular_embedding_request_keeps_the_existing_engine():
    recs = ai_assistant.recommend_plugins(PROFILE, ROOT/'plugins', goal='Draw UMAP')
    assert recs[0]['plugin_id'] == 'advanced_dim_plot'


def test_adapter_does_not_invent_a_taxonomy_or_embedding():
    with pytest.raises(ValueError, match='supplied embedding'):
        ai_assistant.build_params_for_plugin('circular_tree_embedding', {'columns':['Gene_A','Gene_B','class'], 'numeric_columns':['Gene_A','Gene_B']})
