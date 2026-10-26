from __future__ import annotations

from plot_web.plot_guide import build_caption, compose_guide
from plot_web.plot_registry import get_plot, get_variant, load_registry


def test_umap_family_guide_renders():
    load_registry(rebuild=True)
    plot = get_plot("umap_tsne")
    assert plot and plot.get("guide")
    guide = plot["guide"]
    assert "two-dimensional embedding" in (guide.get("summary") or "")
    assert guide.get("best_for")
    assert guide.get("cautions")
    assert len(guide.get("examples") or []) >= 3
    pie = get_variant("umap_tsne", "composition")
    assert pie and pie.get("guide")
    payload = compose_guide("umap_tsne", variant_id="clusters")
    assert payload["available"] is True
    assert payload["variant"]["id"] == "clusters"
    assert payload["family_guide"]["cautions"]


def test_caption_omits_absent_mappings_and_includes_active():
    plot = get_plot("umap_tsne")
    caption = build_caption(plot, get_variant("umap_tsne", "clusters"), {"group_column": "cell_type"})
    assert "UMAP" in caption
    assert "cell_type" in caption
    assert "separated by" not in caption
    split = build_caption(
        plot,
        get_variant("umap_tsne", "split_samples"),
        {"group_column": "cluster", "split_column": "treatment"},
    )
    assert "treatment" in split
    assert "cluster" in split


def test_composition_current_state_explanation():
    payload = compose_guide(
        "umap_tsne",
        variant_id="composition",
        params={"group_column": "celltype", "stat_plot_column": "sample"},
    )
    text = " ".join(s["text"] for s in payload["current"]["statements"])
    assert "sample" in text
    assert "celltype" in text
    assert any(s["type"] == "caution" for s in payload["current"]["statements"])


def test_literature_without_reuse_has_no_thumbnail():
    payload = compose_guide("umap_tsne")
    assert payload["literature"]
    for item in payload["literature"]:
        assert item.get("citation") or item.get("url")
        if not item.get("thumbnail_reuse_allowed"):
            assert not item.get("thumbnail_asset")
        assert item.get("doi") != "10.0000/fake"


def test_missing_guide_is_empty_not_fabricated(monkeypatch):
    import plot_web.plot_guide as module
    plot = {"id": "unwritten_guide", "name": "Test", "variants": []}
    monkeypatch.setattr(module, "get_plot", lambda *args: plot)
    payload = compose_guide("unwritten_guide")
    assert payload["available"] is False
    assert "not available" in (payload.get("empty_message") or "").lower()
    assert not payload.get("family_guide")


def test_tf_lollipop_published_example_links_its_demo_and_verified_paper():
    payload = compose_guide("enrichment_lollipop", example_id="CAB_demo")
    assert payload["available"] is True
    assert payload["variant"]["id"] == "diverging_tf"
    example = next(item for item in payload["examples"] if item["demo_id"] == "CAB_demo")
    paper = next(item for item in payload["literature"] if item["id"] == example["literature_id"])
    assert paper["doi"] == "10.1186/s12943-025-02548-8"
    assert paper["year"] == 2026 and paper["figure"] == "Figure 6L"
    assert paper["url"].startswith("https://link.springer.com/")
    assert example["variant_id"] == "diverging_tf"
    assert example["preview_url"].endswith("/gallery/CAB_demo.png")
    assert "Synthetic" in example["data_note"]
    assert not paper["thumbnail_asset"]


def test_tf_guide_explains_current_mapping_without_false_group_colors():
    params = {"category_column": "regulon", "value_column": "logFC", "pvalue_column": "FDR",
              "group_column": "cluster", "color_mode": "value", "size_transform": "neg_log10_pvalue"}
    payload = compose_guide("enrichment_lollipop", example_id="CAB_demo", params=params)
    text = " ".join(item["text"] for item in payload["current"]["statements"])
    assert "logFC" in text and "-log10(FDR)" in text
    assert not any(item["title"] == "Group color" for item in payload["current"]["statements"])
    assert "regulon" in payload["caption"] and "logFC" in payload["caption"]
    params["size_switch"] = False
    payload = compose_guide("enrichment_lollipop", example_id="CAB_demo", params=params)
    assert not any(item["title"] == "Probability-sized points" for item in payload["current"]["statements"])


def test_all_visible_guides_link_examples_for_their_own_engine():
    from fastapi.testclient import TestClient
    from plot_web.app import app
    from plot_web.plot_registry import get_all_plots
    client = TestClient(app)
    for plot in get_all_plots():
        response = client.get(f'/api/registry/plots/{plot["id"]}/guide')
        assert response.status_code == 200, plot['id']
        payload = response.json()
        assert payload['available'], plot['id']
        assert payload['family_guide']['input_requirements']
        assert payload['family_guide']['cautions']
        assert payload['examples']
        for example in payload['examples']:
            result = client.get(f'/api/plugins/{plot["engine_plugin_id"]}/examples/{example["demo_id"]}')
            assert result.status_code == 200, (plot['id'], example)
            assert result.json()['expected'], (plot['id'], example['demo_id'])
            if example.get('preview_url'):
                assert client.get(example['preview_url']).status_code == 200


def test_coverage_report_validates_references_and_exposes_real_gaps():
    from scripts.report_plot_guides import inventory, render_report
    rows, errors = inventory()
    assert not errors
    assert all(row['guide'] for row in rows)
    single = next(row for row in rows if row['plot']['id'] == 'ternary_plot')
    assert len(single['demos']) == 1
    report = render_report(rows, errors)
    assert 'Fewer than two independent local demos' in report
    assert 'Hidden; source only' in report
    assert 'not counted as figure examples' in report


def test_non_embedding_guide_does_not_invent_embedding_or_color_mappings():
    payload = compose_guide('line_plot', params={'split_column': 'condition', 'group_column': 'patient'})
    text = ' '.join(item['text'] for item in payload['current']['statements'])
    assert 'embedding' not in text
    assert 'condition' in text
    assert not any(item['title'] == 'Group color' for item in payload['current']['statements'])


def test_published_panels_are_filtered_by_family_and_keep_provenance():
    umap = compose_guide('umap_tsne')
    tf = compose_guide('enrichment_lollipop')
    assert any(item['figure'] == 'Figure 1B' and item['literature_id'] == 'hao_dnt_2026'
               for item in umap['published_examples'])
    assert not any(item['figure'] == 'Figure 6L' for item in umap['published_examples'])
    example = next(item for item in tf['published_examples'] if item['figure'] == 'Figure 6L')
    assert example['doi'] == '10.1186/s12943-025-02548-8'
    assert example['figure_url'].endswith('/figures/6')
    assert example['match_type'] == 'same_grammar'
    assert example['adaptation'] and example['verification'] == 'primary_source_caption'
    assert not example.get('thumbnail_asset')


def test_related_layouts_and_preprints_are_not_reported_as_direct_matches():
    payload = compose_guide('interactive_bubble_score_matrix')
    example = next(item for item in payload['published_examples'] if item['literature_id'] == 'wang_niche_preprint_2026')
    assert example['publication_status'] == 'preprint'
    assert example['match_type'] == 'related_layout'
    payload = compose_guide('threshold_matrix_heatmap')
    assert payload['published_examples']
    assert all(item['match_type'] == 'related_layout' for item in payload['published_examples'])


def test_curated_guides_and_generated_report_use_english():
    import re
    from pathlib import Path
    from scripts.report_plot_guides import inventory, render_report
    root = Path(__file__).resolve().parents[1] / 'registry'
    for path in [*root.joinpath('guides').glob('*.yaml'), root/'literature.yaml']:
        assert not re.search(r'[\u4e00-\u9fff]', path.read_text()), path
    rows, errors = inventory()
    report = render_report(rows, errors)
    assert not re.search(r'[\u4e00-\u9fff]', report)
    assert 'Same plot grammar' in report and 'Related layout; adaptation required' in report
    assert 'PREPRINT; not peer reviewed' in report
