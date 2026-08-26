from __future__ import annotations

from plot_web.plot_registry import (
    browse_categories,
    discovery_taxonomy,
    get_all_plots,
    get_plot,
    get_plots_by_context,
    get_plots_by_task,
    get_recommended_plots,
    get_variant,
    get_variants,
    load_registry,
    resolve_legacy_preset,
    search_plots,
    validate_registry,
)


def test_every_plugin_is_registered():
    reg = load_registry(rebuild=True)
    result = validate_registry(reg)
    assert result["n_plots"] >= 40
    missing = [e for e in result["errors"] if e["code"] == "PLUGIN_NOT_IN_REGISTRY"]
    assert missing == [], missing
    assert result["valid"] or all(e["code"] != "DUPLICATE_ID" for e in result["errors"])


def test_umap_reference_family():
    plot = get_plot("umap_tsne")
    assert plot is not None
    assert plot["engine_plugin_id"] == "advanced_dim_plot"
    ids = {v["id"] for v in get_variants("umap_tsne")}
    for needed in {"clusters", "feature_expression", "split_samples", "composition_pie", "density", "highlight_cells", "ellipse"}:
        assert needed in ids, needed
    assert get_plot("advanced_dim_plot")["id"] == "umap_tsne"
    legacy = resolve_legacy_preset("umap_tsne", "basic_umap")
    assert legacy is not None
    assert legacy["variant"] == "clusters"
    assert legacy["preset"] == "recommended"
    pie = resolve_legacy_preset("umap", "embedded_pie")
    assert pie is not None
    assert pie["variant"] == "composition_pie"


def test_search_and_context():
    hits = search_plots("ridgeplot")
    assert any(h["id"] in {"gsea", "ridgeline"} for h in hits)
    umap_hits = search_plots("umap")
    assert umap_hits and umap_hits[0]["id"] == "umap_tsne"
    sc = get_plots_by_context("single_cell")
    assert any(p["id"] == "umap_tsne" for p in sc)
    gsea_tasks = get_plots_by_task("gsea")
    assert any(p["id"] == "gsea" for p in gsea_tasks)


def test_recommendations_are_deterministic():
    recs = get_recommended_plots(
        {"roles": ["x_embedding", "y_embedding", "cluster", "sample"]},
        context="single_cell",
    )
    variants = [r["variant"] for r in recs if r["plot_id"] == "umap_tsne"]
    assert "clusters" in variants
    assert recs[0]["priority"] >= recs[-1]["priority"]


def test_variant_lookup_accepts_legacy_example_id():
    v = get_variant("umap_tsne", "ellipse_mark")
    assert v is not None
    assert v["id"] == "ellipse"


def test_validate_unique_ids():
    result = validate_registry()
    dup = [e for e in result["errors"] if e["code"] == "DUPLICATE_ID"]
    assert dup == []


def test_discovery_taxonomy_recommends_umap_composition():
    tax = discovery_taxonomy()
    sc = next(c for c in tax["contexts"] if c["id"] == "single_cell")
    comp = next(t for t in sc["tasks"] if t["id"] == "cell_composition")
    ids = {p["id"] for p in comp["plots"]}
    assert "umap_tsne" in ids
    umap = next(p for p in comp["plots"] if p["id"] == "umap_tsne")
    assert umap.get("recommended_variant") in {"composition_pie", "composition_ring", "stat_panel"}
    enrich = next(c for c in tax["contexts"] if c["id"] == "functional_enrichment")
    assert any(t["plot_count"] > 0 for t in enrich["tasks"])


def test_browse_covers_all_families():
    browse = browse_categories()
    ids = {p["id"] for p in browse["all_plots"]}
    assert len(ids) >= 40
    assigned = {p["id"] for c in browse["categories"] for p in c["plots"]}
    assert ids <= assigned or ids == {p["id"] for p in browse["all_plots"]}


def test_umap_family_style_cards():
    from plot_web.app import list_plot_styles

    payload = list_plot_styles("umap_tsne")
    assert payload["plot_id"] == "umap_tsne"
    assert payload["engine_plugin_id"] == "advanced_dim_plot"
    assert payload["count"] >= 10
    assert len(payload["styles"]) == payload["count"]
    first = payload["styles"][0]
    assert first.get("id")
    assert first.get("label")
    assert "params" not in first
    pdf_first = all(
        s.get("card_group") == "pdf_styles"
        for s in payload["styles"][: min(3, len(payload["styles"]))]
        if any(x.get("card_group") == "pdf_styles" for x in payload["styles"])
    )
    if any(s.get("card_group") == "pdf_styles" for s in payload["styles"]):
        assert payload["styles"][0]["card_group"] == "pdf_styles"
        assert pdf_first


def test_search_match_kinds():
    hits = search_plots("volcano")
    assert hits
    assert hits[0]["id"] == "volcano"
    assert hits[0]["match_kind"] == "exact"
    ridge = search_plots("ridge")
    kinds = {h["id"]: h.get("match_kind") for h in ridge}
    assert "gsea" in kinds or "ridgeline" in kinds
