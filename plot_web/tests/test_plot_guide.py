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


def test_missing_guide_is_empty_not_fabricated():
    payload = compose_guide("interactive_correlation_matrix")
    assert payload["available"] is False
    assert "not available" in (payload.get("empty_message") or "").lower()
    assert not payload.get("family_guide")
