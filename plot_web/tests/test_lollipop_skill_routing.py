from pathlib import Path

import pytest

from plot_web import ai_assistant

ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.parametrize("goal", ["Compare transcription factors with a lollipop", "比较两组转录因子，画双向棒棒糖图"])
def test_tf_request_recommends_engine_style_and_discoverable_skill(goal):
    profile = {"columns": ["TF", "logFC", "FDR"], "numeric_columns": ["logFC", "FDR"],
               "categorical_columns": ["TF"], "tags": ["de_stats"], "row_count_estimate": 40}
    recommendations = ai_assistant.recommend_plugins(profile, ROOT / "plugins", goal=goal)
    assert recommendations[0]["plugin_id"] == "interactive_enrichment_lollipop"
    assert recommendations[0]["variant_id"] == "diverging_tf"
    assert "example=CAB_demo" in recommendations[0]["editor_url"]
    skills = ai_assistant.match_skills(profile, recommendations, ROOT / "skills", goal=goal)
    assert skills[0]["skill_id"] == "diverging-tf-lollipop"
    assert skills[0]["related_plugins"] == ["interactive_enrichment_lollipop"]
    assert skills[0]["role"] == "plot_workflow"


def test_tf_adapter_preserves_supplied_effect_and_probability_columns():
    profile = {"columns": ["TF", "FDR", "logFC", "pvalue"], "row_count_estimate": 40}
    params = ai_assistant.build_params_for_plugin("interactive_enrichment_lollipop", profile)
    assert params["category_column"] == "TF" and params["value_column"] == "logFC"
    assert params["pvalue_column"] == "FDR" and params["size_transform"] == "neg_log10_pvalue"
    assert params["size_legend_title"] == "-log10(FDR)"
    assert params["direction_labels_show"] is False


def test_tf_adapter_does_not_fabricate_probabilities_or_effects():
    params = ai_assistant.build_params_for_plugin("interactive_enrichment_lollipop", {"columns": ["TF", "effect"]})
    assert "pvalue_column" not in params and params["size_switch"] is False
    with pytest.raises(ValueError, match="signed effect"):
        ai_assistant.build_params_for_plugin("interactive_enrichment_lollipop", {"columns": ["TF", "pvalue"]})


def test_tf_skill_is_not_selected_for_an_unrelated_generic_plot_request():
    matches = ai_assistant.match_skills({}, [{"plugin_id": "group_heatmap"}], ROOT / "skills", goal="plot a heatmap")
    assert not any(item["skill_id"] == "diverging-tf-lollipop" for item in matches)


def test_ai_studio_api_exposes_the_tf_workflow_skill(tmp_path, monkeypatch):
    from fastapi.testclient import TestClient
    from plot_web.app import app
    from plot_web.server.routes import ai
    monkeypatch.setattr(ai, "UPLOADS_DIR", tmp_path)
    monkeypatch.setattr(ai_assistant, "refine_with_spacexai", lambda *args, **kwargs: None)
    monkeypatch.setattr(ai_assistant, "summarize_intent", lambda *args, **kwargs: {"summary": "TF lollipop"})
    response = TestClient(app).post("/api/ai/recommend", data={"goal": "regulon lollipop"},
                                  files={"file": ("tf.csv", b"TF,logFC,FDR\nATF3,0.4,0.001\nCTCF,-0.4,0.002\n")})
    assert response.status_code == 200
    body = response.json()
    rec = next(item for item in body["recommendations"] if item["plugin_id"] == "interactive_enrichment_lollipop")
    assert rec["variant_id"] == "diverging_tf"
    assert any(item["skill_id"] == "diverging-tf-lollipop" and item["role"] == "plot_workflow" for item in body["skills"])
