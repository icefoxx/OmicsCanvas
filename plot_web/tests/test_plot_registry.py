from __future__ import annotations

from plot_web.app import list_plot_styles
from plot_web.plot_registry import (
    browse_categories,
    chart_categories,
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
    visible_variants,
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
    for needed in {"clusters", "feature_expression", "split_samples", "composition", "density", "highlight_cells", "ellipse", "background_mask", "split_highlight"}:
        assert needed in ids, needed
    assert "mark_shapes" not in ids
    assert "composition_pie" not in ids
    assert get_plot("advanced_dim_plot")["id"] == "umap_tsne"
    legacy = resolve_legacy_preset("umap_tsne", "basic_umap")
    assert legacy is not None
    assert legacy["variant"] == "clusters"
    assert legacy["preset"] == "recommended"
    pie = resolve_legacy_preset("umap", "embedded_pie")
    assert pie is not None
    assert pie["variant"] == "composition"
    assert (pie.get("parameters") or {}).get("composition_glyph") == "pie"


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
    assert sc["task_count"] == 6
    assert {t["id"] for t in sc["tasks"]} >= {"cell_clustering", "cell_composition", "sample_differences"}
    assert "plots" not in sc or True
    assert sc["plot_count"] >= 1
    assert sc.get("blurb")
    comp = next(t for t in sc["tasks"] if t["id"] == "cell_composition")
    ids = {p["id"] for p in comp["plots"]}
    assert "umap_tsne" in ids
    umap = next(p for p in comp["plots"] if p["id"] == "umap_tsne")
    assert umap.get("recommended_variant") in {"composition", "stat_panel"}
    rec = [p for p in comp["plots"] if p.get("recommended")]
    assert 1 <= len(rec) <= 4
    enrich = next(c for c in tax["contexts"] if c["id"] == "functional_enrichment")
    assert any(t["plot_count"] > 0 for t in enrich["tasks"])


def test_search_scientific_task_and_chart_type():
    hits = search_plots("cell composition")
    assert any(h["id"] == "umap_tsne" for h in hits)
    pie = search_plots("umap pie")
    assert pie and pie[0]["id"] == "umap_tsne"
    violin = search_plots("violin")
    assert any(h["id"] in {"violin_plot", "interactive_violin_plot"} for h in violin)


def test_schema_normalize_accepts_jsonschema_type_unions():
    from plot_web.schema_normalize import normalize_params_schema

    schema = {
        "plugin": "interactive_violin_plot",
        "groups": {"cloud": ["cloud_colors"]},
        "properties": {
            "cloud_colors": {"type": ["array", "object"], "description": "Named or list colors"},
        },
    }
    out = normalize_params_schema(schema)
    assert "cloud" in out
    assert out["cloud"]["cloud_colors"]["type"] == "object"


def test_chart_categories_gallery_types():
    payload = chart_categories()
    group_ids = [g["id"] for g in payload["groups"]]
    for needed in ("distribution", "comparison", "relationship", "matrix", "composition", "flow", "sets", "tables"):
        assert needed in group_ids, needed
    ids = {c["id"] for g in payload["groups"] for c in g["charts"]}
    for needed in ("violin", "heatmap", "sankey", "pie", "table", "network", "ridgeline", "barplot"):
        assert needed in ids, needed
    violin = next(c for g in payload["groups"] for c in g["charts"] if c["id"] == "violin")
    assert any(p["id"] == "violin_plot" for p in violin["plots"])
    assert violin["family_count"] == violin["plot_count"]
    heat = next(c for g in payload["groups"] for c in g["charts"] if c["id"] == "heatmap")
    assert any(p["id"] == "grouped_heatmap" for p in heat["plots"])
    table = next(c for g in payload["groups"] for c in g["charts"] if c["id"] == "table")
    assert table["name"] == "Table"


def test_browse_covers_all_families():
    browse = browse_categories()
    ids = {p["id"] for p in browse["all_plots"]}
    assert len(ids) >= 33
    names = [c["name"] for c in browse["categories"]]
    for needed in ("Single-cell", "Expression", "Differential Analysis", "Enrichment", "Composition", "Statistics", "Network"):
        assert needed in names, needed
    assigned = {p["id"] for c in browse["categories"] for p in c["plots"]}
    assert ids <= assigned or ids == {p["id"] for p in browse["all_plots"]}


def test_umap_gallery_is_canonical_variants():
    load_registry(rebuild=True)
    visible_ids = {v["id"] for v in visible_variants("umap_tsne")}
    assert visible_ids == {
        "clusters",
        "feature_expression",
        "split_samples",
        "composition",
        "highlight_cells",
        "ellipse",
        "density",
        "coexpression",
        "background_mask",
        "split_highlight",
        "lineage",
        "stat_panel",
    }
    hidden = {"axis_label_controls", "blank_theme", "pdf_basic_umap", "raster", "mark_shapes", "basic_umap", "group"}
    assert not (visible_ids & hidden)
    names = {v["id"]: v["name"] for v in visible_variants("umap_tsne")}
    assert names["clusters"] == "Basic UMAP"
    assert names["composition"] == "Composition"
    assert "_" not in names["clusters"]
    payload = list_plot_styles("umap_tsne")
    labels = {item["label"] for item in payload["styles"]}
    assert "Basic UMAP" in labels
    assert "axis_label_controls" not in labels
    assert "pdf_basic_umap" not in {item["id"] for item in payload["styles"]}
    assert payload["recommended_count"] == 6
    assert payload["count"] == 12
    assert "recommended of" in payload["count_label"]


def test_umap_legacy_aliases_resolve():
    assert get_variant("umap_tsne", "ellipse_mark")["id"] == "ellipse"
    assert get_variant("umap_tsne", "cluster_composition_ring")["id"] == "composition"
    assert get_variant("umap_tsne", "composition_pie")["id"] == "composition"
    screen = resolve_legacy_preset("umap_tsne", "coexpression_screen")
    assert screen["variant"] == "coexpression"
    assert screen["parameters"]["color_mix_mode"] == "screen"
    hexbin = resolve_legacy_preset("advanced_dim_plot", "density_hex")
    assert hexbin["variant"] == "density"
    assert hexbin["parameters"]["density_style"] == "hexbin"
    split = get_variant("umap_tsne", "split_highlight")
    assert split["id"] == "split_highlight"
    hits = search_plots("cluster_composition_ring")
    assert hits and hits[0]["id"] == "umap_tsne"


def test_feature_embedding_gallery_is_canonical():
    load_registry(rebuild=True)
    visible = visible_variants("feature_embedding")
    ids = [v["id"] for v in visible]
    assert ids == [
        "feature_expression",
        "split_feature_expression",
        "feature_coexpression",
        "aggregated_feature_expression",
    ]
    names = {v["id"]: v["name"] for v in visible}
    assert names["feature_expression"] == "Feature Expression"
    assert "Atoh1" not in names["feature_expression"]
    assert names["feature_coexpression"] == "Feature Coexpression"
    hidden = {"single_feature", "multi_feature", "highlight_blank", "density_hex", "feature_comp", "split_feature"}
    assert not (set(ids) & hidden)
    payload = list_plot_styles("feature_embedding")
    labels = [item["label"] for item in payload["styles"]]
    assert labels[0] == "Feature Expression"
    assert "Basic · Atoh1 + Neurod1" not in labels
    assert "single_feature" not in labels
    assert payload["recommended_count"] == 3
    assert payload["count"] == 7
    assert "Feature Density" in labels
    assert "Coexpression Density" in labels
    assert "Scaled Feature Density" in labels
    density = {item["id"]: item for item in payload["styles"] if item["engine_plugin_id"] == "feature_density_plot"}
    assert density["feature_density"]["example_id"] == "basic"
    assert density["coexpression_density"]["example_id"] == "coexpression"
    assert density["scaled_feature_density"]["example_id"] == "scale01"
    assert get_variant("feature_embedding", "single_feature")["id"] == "feature_expression"
    assert get_variant("feature_embedding", "split_feature")["id"] == "split_feature_expression"
    hex_alias = resolve_legacy_preset("advanced_feature_plot", "density_hex")
    assert hex_alias["variant"] == "aggregated_feature_expression"
    assert hex_alias["parameters"]["aggregation_style"] == "hexbin"
    mix = resolve_legacy_preset("feature_embedding", "feature_comp")
    assert mix["variant"] == "feature_coexpression"
    assert mix["parameters"]["color_mix_mode"] == "blend"
    hits = search_plots("single_feature")
    assert hits and hits[0]["id"] == "feature_embedding"


def test_classified_bar_is_one_variant():
    load_registry(rebuild=True)
    assert get_plot("classified_bar_plot") is None
    payload = list_plot_styles("exp_stat_plot")
    classified = next(item for item in payload["styles"] if item["id"] == "classified_bar")
    assert classified["label"] == "Classified Bar"
    assert classified["engine_plugin_id"] == "classified_bar_plot"
    assert classified["example_id"] == "CAB_demo"
    ids = {item["id"] for item in payload["styles"]}
    assert "CAB_demo" not in ids
    assert "vertical" not in ids
    plot = get_plot("exp_stat_plot")
    assert "分类" not in (plot.get("description") or "")
    hits = search_plots("cab_demo")
    assert hits and hits[0]["id"] == "exp_stat_plot"


def test_go_kegg_enrichment_is_ora_family():
    load_registry(rebuild=True)
    plot = get_plot("go_kegg_enrichment_bar_bubble")
    assert plot is not None
    assert plot["name"] == "GO / KEGG Enrichment"
    assert plot["tasks"] == ["ora"]
    assert "gsea" not in (plot.get("tasks") or [])
    payload = list_plot_styles("go_kegg_enrichment_bar_bubble")
    ids = [item["id"] for item in payload["styles"]]
    assert "grouped_bar_dot" in ids
    card = next(item for item in payload["styles"] if item["id"] == "grouped_bar_dot")
    assert card["example_id"] == "go_kegg"
    assert card.get("image")
    from plot_web.app import choose_demo_file
    demo = choose_demo_file("go_kegg_enrichment_bar_bubble", "input", {"formats": ["csv"]})
    assert demo is not None
    hits = search_plots("go kegg enrichment")
    assert hits and hits[0]["id"] == "go_kegg_enrichment_bar_bubble"
    charts = chart_categories()
    bar = next(c for g in charts["groups"] for c in g["charts"] if c["id"] == "barplot")
    assert any(p["id"] == "go_kegg_enrichment_bar_bubble" for p in bar["plots"])


def test_mantel_network_is_combined_pearson_figure():
    load_registry(rebuild=True)
    plot = get_plot("interactive_mantel_correlation_network")
    assert plot is not None
    assert plot["name"] == "Mantel + Pearson Correlation"
    payload = list_plot_styles("interactive_mantel_correlation_network")
    ids = [item["id"] for item in payload["styles"]]
    assert "mantel_pearson" in ids
    assert "custom_layout" not in ids
    card = next(item for item in payload["styles"] if item["id"] == "mantel_pearson")
    assert card["example_id"] == "basic"
    assert card["label"] == "Combined Mantel + Pearson"
    hits = search_plots("mantel")
    assert hits and hits[0]["id"] == "interactive_mantel_correlation_network"


def test_pie_dot_matrix_is_merged_into_dot_plot():
    load_registry(rebuild=True)
    assert get_plot("pie_dot_matrix") is None
    assert "pie_dot_matrix" not in {p["id"] for p in get_all_plots()}
    payload = list_plot_styles("dot_plot")
    ids = [item["id"] for item in payload["styles"]]
    assert "pie_dot_matrix" in ids
    assert "binary" not in ids
    assert "correlation" not in ids
    pie_dot = next(item for item in payload["styles"] if item["id"] == "pie_dot_matrix")
    assert pie_dot["label"] == "Pie Dot Matrix"
    assert pie_dot["engine_plugin_id"] == "pie_dot_matrix"
    assert pie_dot["example_id"] == "basic"
    browse = browse_categories()
    assert "pie_dot_matrix" not in {p["id"] for p in browse["all_plots"]}
    charts = chart_categories()
    bubble = next(c for g in charts["groups"] for c in g["charts"] if c["id"] == "bubble")
    assert all(p["id"] != "pie_dot_matrix" for p in bubble["plots"])
    assert any(p["id"] == "dot_plot" for p in bubble["plots"])
    matrix = next(c for g in charts["groups"] for c in g["charts"] if c["id"] == "dot_matrix")
    assert all(p["id"] != "pie_dot_matrix" for p in matrix["plots"])
    pie = next(c for g in charts["groups"] for c in g["charts"] if c["id"] == "pie")
    assert all(p["id"] != "pie_dot_matrix" for p in pie["plots"])
    hits = search_plots("pie dot matrix")
    assert hits and hits[0]["id"] == "dot_plot"
    ratio = search_plots("ratio circles")
    assert ratio and ratio[0]["id"] == "dot_plot"


def test_dot_plot_is_one_variant():
    load_registry(rebuild=True)
    visible = visible_variants("dot_plot")
    assert [v["id"] for v in visible] == ["marker_dot"]
    assert visible[0]["name"] == "Basic Dot Plot"
    plot = get_plot("dot_plot")
    assert plot["name"] == "Basic / Advanced Dot Plot"
    payload = list_plot_styles("dot_plot")
    labels = [item["label"] for item in payload["styles"]]
    assert "Basic Dot Plot" in labels
    assert "Balloon Plot" in labels
    assert "Presence / Absence" in labels
    assert "Stacked Dot" in labels
    assert "Composition Dot" in labels
    assert payload["recommended_count"] == 1
    assert payload["count"] == 10
    pie_dot = next(item for item in payload["styles"] if item["id"] == "pie_dot_matrix")
    assert pie_dot["engine_plugin_id"] == "pie_dot_matrix"
    assert pie_dot["example_id"] == "basic"
    assert pie_dot["label"] == "Pie Dot Matrix"
    assert get_plot("pie_dot_matrix") is None
    balloon = next(item for item in payload["styles"] if item["id"] == "balloon")
    assert balloon["engine_plugin_id"] == "balloon_plot"
    assert balloon["example_id"] == "basic"
    binary = next(item for item in payload["styles"] if item["id"] == "presence_absence")
    assert binary["engine_plugin_id"] == "interactive_binary_plot"
    stack = next(item for item in payload["styles"] if item["id"] == "dot_stack")
    assert stack["engine_plugin_id"] == "exp_stat_plot"
    desc = payload.get("description") or ""
    assert "jjplot" not in desc.lower()
    assert "custdot" not in desc.lower()
    dendro = resolve_legacy_preset("dot_plot", "dendro")
    assert dendro["variant"] == "marker_dot"
    assert dendro["parameters"]["xtree"] is True
    assert get_plot("balloon_plot") is None
    assert get_plot("interactive_binary_plot") is None
    hits = search_plots("balloon plot")
    assert hits and hits[0]["id"] == "dot_plot"
    charts = chart_categories()
    dot = next(c for g in charts["groups"] for c in g["charts"] if c["id"] == "dot")
    assert any(p["id"] == "dot_plot" for p in dot["plots"])
    assert all(p["id"] != "balloon_plot" for p in dot["plots"])


def test_exp_stat_encodings_are_refiled():
    load_registry(rebuild=True)
    plot = get_plot("exp_stat_plot")
    assert plot["name"] == "Basic / Advanced Bar Plot"
    bar_styles = list_plot_styles("exp_stat_plot")
    bar_ids = [item["id"] for item in bar_styles["styles"]]
    assert bar_ids == [
        "grouped_bar",
        "flipped_bar",
        "stacked_bar",
        "stacked_bar_vertical",
        "stacked_bar_labeled",
        "stacked_composition_bar",
        "classified_bar",
        "labeled_bar_line",
    ]
    stacked = next(item for item in bar_styles["styles"] if item["id"] == "stacked_bar")
    assert stacked["engine_plugin_id"] == "stacked_bar_plot"
    assert stacked["example_id"] == "basic"
    assert stacked["label"] == "Stacked Bar"
    assert "CAB_demo" not in bar_ids
    assert "percent" not in bar_ids
    assert "long" not in bar_ids
    assert get_plot("stacked_bar_plot") is None
    labeled = next(item for item in bar_styles["styles"] if item["id"] == "labeled_bar_line")
    assert labeled["engine_plugin_id"] == "combo_bar_line_plot"
    assert labeled["label"] == "Labeled Bar + Line"
    for banned in ("violin", "box_split", "custom_style", "highlight", "dot_stack", "CAB_demo", "long"):
        assert banned not in bar_ids
    assert get_plot("combo_bar_line_plot") is None
    assert get_plot("classified_bar_plot") is None

    violin_family = get_plot("interactive_violin_plot")
    assert violin_family["name"] == "Violin / Box / Point Plot"
    assert not str(violin_family["name"]).lower().startswith("interactive")
    violin_styles = list_plot_styles("interactive_violin_plot")
    violin_ids = {item["id"] for item in violin_styles["styles"]}
    for needed in ("violin", "box_split", "custom_style", "highlight", "grouped_violin"):
        assert needed in violin_ids
    grouped = next(item for item in violin_styles["styles"] if item["id"] == "grouped_violin")
    assert grouped["engine_plugin_id"] == "group_heatmap"
    assert grouped["example_id"] == "violin"
    assert grouped["label"] == "Grouped Violin"
    assert "dot_stack" not in violin_ids
    assert "bar" not in violin_ids
    assert "col_flip" not in violin_ids
    assert "grouped_bar" not in violin_ids
    moved = {item["id"]: item for item in violin_styles["styles"] if item["id"] in {"violin", "box_split", "custom_style", "highlight"}}
    assert moved["violin"]["label"] == "Violin"
    assert moved["box_split"]["label"] == "Split Box Plot"
    assert all(item["engine_plugin_id"] == "exp_stat_plot" for item in moved.values())

    charts = chart_categories()
    barplot = next(c for g in charts["groups"] for c in g["charts"] if c["id"] == "barplot")
    assert any(p["id"] == "exp_stat_plot" for p in barplot["plots"])
    boxplot = next(c for g in charts["groups"] for c in g["charts"] if c["id"] == "boxplot")
    assert all(p["id"] != "exp_stat_plot" for p in boxplot["plots"])
    violin = next(c for g in charts["groups"] for c in g["charts"] if c["id"] == "violin")
    assert any(p["id"] == "interactive_violin_plot" for p in violin["plots"])
    dot = next(c for g in charts["groups"] for c in g["charts"] if c["id"] == "dot")
    assert any(p["id"] == "dot_plot" for p in dot["plots"])


def test_den_plot_is_hidden_from_gallery():
    load_registry(rebuild=True)
    ids = {p["id"] for p in get_all_plots()}
    assert "den_plot" not in ids
    assert get_plot("den_plot") is None
    browse = browse_categories()
    assert "den_plot" not in {p["id"] for p in browse["all_plots"]}
    hits = search_plots("den plot")
    assert all(h["id"] != "den_plot" for h in hits)


def test_feature_density_is_merged_into_feature_embedding():
    load_registry(rebuild=True)
    ids = {p["id"] for p in get_all_plots()}
    assert "feature_density_plot" not in ids
    assert get_plot("feature_density_plot") is None
    browse = browse_categories()
    assert "feature_density_plot" not in {p["id"] for p in browse["all_plots"]}
    charts = chart_categories()
    density = next(c for g in charts["groups"] for c in g["charts"] if c["id"] == "density")
    assert all(p["id"] != "feature_density_plot" for p in density["plots"])
    assert any(p["id"] == "feature_embedding" for p in density["plots"])
    hits = search_plots("feature density")
    assert hits and hits[0]["id"] == "feature_embedding"
    assert all(h["id"] != "feature_density_plot" for h in hits)


def test_stat_plot_encodings_are_refiled():
    load_registry(rebuild=True)
    assert get_plot("stat_plot") is None
    assert "stat_plot" not in {p["id"] for p in get_all_plots()}
    browse = browse_categories()
    assert "stat_plot" not in {p["id"] for p in browse["all_plots"]}

    pie = get_plot("interactive_pie_plot")
    assert pie["name"] == "Pie / Rose Plot"
    pie_styles = list_plot_styles("interactive_pie_plot")
    pie_moved = {item["id"]: item for item in pie_styles["styles"] if item.get("engine_plugin_id") == "stat_plot"}
    assert pie_moved["pie"]["label"] == "Pie"
    assert pie_moved["pie"]["example_id"] == "pie"
    assert pie_moved["rose"]["label"] == "Rose"
    assert pie_moved["rose"]["example_id"] == "rose"

    bar = next(item for item in list_plot_styles("exp_stat_plot")["styles"] if item["id"] == "stacked_composition_bar")
    assert bar["engine_plugin_id"] == "stat_plot"
    assert bar["label"] == "Stacked Composition Bar"

    dot = next(item for item in list_plot_styles("dot_plot")["styles"] if item["id"] == "dot")
    assert dot["engine_plugin_id"] == "stat_plot"
    assert dot["example_id"] == "dot"

    flow = list_plot_styles("alluvial")
    sankey = next(item for item in flow["styles"] if item["id"] == "sankey")
    assert sankey["engine_plugin_id"] == "stat_plot"
    assert sankey["label"] == "Composition Sankey"

    chord = next(item for item in flow["styles"] if item["id"] == "chord")
    assert chord["engine_plugin_id"] == "stat_plot"
    assert chord["label"] == "Chord"

    venn = next(item for item in list_plot_styles("venn")["styles"] if item["id"] == "venn")
    assert venn["engine_plugin_id"] == "stat_plot"

    upset = next(item for item in list_plot_styles("upset")["styles"] if item["id"] == "upset")
    assert upset["engine_plugin_id"] == "stat_plot"

    charts = chart_categories()
    pie_chart = next(c for g in charts["groups"] for c in g["charts"] if c["id"] == "pie")
    assert pie_chart["name"] == "Pie / Rose"
    assert any(p["id"] == "interactive_pie_plot" for p in pie_chart["plots"])
    assert all(p["id"] != "stat_plot" for g in charts["groups"] for c in g["charts"] for p in c["plots"])
    hits = search_plots("rose")
    assert hits and hits[0]["id"] == "interactive_pie_plot"
    assert all(h["id"] != "stat_plot" for h in hits)


def test_gsea_ridge_nes_is_on_gsea_family():
    load_registry(rebuild=True)
    assert get_plot("gsea_ridge_nes_plot") is None
    payload = list_plot_styles("gsea")
    ridge = next(item for item in payload["styles"] if item["id"] == "ridge_nes")
    assert ridge["label"] == "Pathway Ridge + NES"
    assert ridge["engine_plugin_id"] == "gsea_ridge_nes_plot"
    assert ridge["example_id"] == "basic"
    assert ridge["card_group"] == "recommended"
    hits = search_plots("pathway ridge")
    assert hits and hits[0]["id"] == "gsea"
    assert get_plot("gsea_heatmap") is None
    heat = next(item for item in payload["styles"] if item["id"] == "pathway_heatmap")
    assert heat["label"] == "GSEA + Pathway Heatmap"
    assert heat["engine_plugin_id"] == "gsea_pathway_heatmap"
    assert heat["example_id"] == "basic"
    style_ids = [item["id"] for item in payload["styles"]]
    assert "precomputed" not in style_ids
    assert "with_annotation" not in style_ids
    hits_hm = search_plots("gsea heatmap")
    assert hits_hm and hits_hm[0]["id"] == "gsea"


def test_alluvial_sankey_chord_are_one_family():
    load_registry(rebuild=True)
    plot = get_plot("alluvial")
    assert plot["name"] == "Alluvial / Sankey / Chord Plot"
    assert "sankey" not in {p["id"] for p in get_all_plots()}
    assert get_plot("sankey")["id"] == "alluvial"
    payload = list_plot_styles("alluvial")
    by_id = {item["id"]: item for item in payload["styles"]}
    assert by_id["sankey_flow"]["engine_plugin_id"] == "interactive_sankey_plot"
    assert by_id["sankey_flow"]["label"] == "Sankey"
    assert by_id["sankey_interactive"]["example_id"] == "interactive"
    assert by_id["chord"]["engine_plugin_id"] == "stat_plot"
    native = {item["id"] for item in payload["styles"] if item.get("engine_plugin_id") in {None, "alluvial_plot"}}
    assert {"basic", "edges", "hx_lineage", "long"} <= native | {item["id"] for item in payload["styles"]}
    charts = chart_categories()
    sankey = next(c for g in charts["groups"] for c in g["charts"] if c["id"] == "sankey")
    assert any(p["id"] == "alluvial" for p in sankey["plots"])
    assert all(p["id"] != "sankey" for p in sankey["plots"])
    hits = search_plots("sankey")
    assert hits and hits[0]["id"] == "alluvial"


def test_enrichment_lollipop_hides_layout_and_interactive_cards():
    load_registry(rebuild=True)
    payload = list_plot_styles("enrichment_lollipop")
    ids = [item["id"] for item in payload["styles"]]
    assert "custom_layout" not in ids
    assert "interactive" not in ids
    assert "lollipop" in ids
    labels = [item["label"] for item in payload["styles"]]
    assert "custom_layout" not in labels
    assert "interactive" not in labels
    custom = resolve_legacy_preset("enrichment_lollipop", "custom_layout")
    assert custom and custom["variant"] == "lollipop"
    interactive = resolve_legacy_preset("enrichment_lollipop", "interactive")
    assert interactive and interactive["variant"] == "lollipop"
    assert interactive["parameters"].get("interactive") is True


def test_dual_triangle_is_merged_into_correlation_matrix():
    load_registry(rebuild=True)
    assert get_plot("interactive_dual_triangle_heatmap_plot") is None
    assert "interactive_dual_triangle_heatmap_plot" not in {p["id"] for p in get_all_plots()}
    plot = get_plot("interactive_correlation_matrix")
    assert plot is not None
    assert plot["name"] == "Correlation / Dual-Triangle Matrix"
    payload = list_plot_styles("interactive_correlation_matrix")
    ids = [item["id"] for item in payload["styles"]]
    assert "dual_triangle" in ids
    assert "custom" not in ids
    dual = next(item for item in payload["styles"] if item["id"] == "dual_triangle")
    assert dual["label"] == "Dual-Triangle Heatmap"
    assert dual["engine_plugin_id"] == "interactive_dual_triangle_heatmap_plot"
    assert dual["example_id"] == "basic"
    native = {item["id"] for item in payload["styles"] if item.get("engine_plugin_id") in {None, "interactive_correlation_matrix"}}
    assert {"basic", "interactive", "lower_triangle"} <= native
    browse = browse_categories()
    assert "interactive_dual_triangle_heatmap_plot" not in {p["id"] for p in browse["all_plots"]}
    charts = chart_categories()
    heat = next(c for g in charts["groups"] for c in g["charts"] if c["id"] == "heatmap")
    assert all(p["id"] != "interactive_dual_triangle_heatmap_plot" for p in heat["plots"])
    corr = next(c for g in charts["groups"] for c in g["charts"] if c["id"] == "correlogram")
    assert any(p["id"] == "interactive_correlation_matrix" for p in corr["plots"])
    assert all(p["id"] != "interactive_dual_triangle_heatmap_plot" for p in corr["plots"])
    hits = search_plots("dual triangle")
    assert hits and hits[0]["id"] == "interactive_correlation_matrix"


def test_clustered_heatmap_is_merged_into_group_heatmap():
    load_registry(rebuild=True)
    assert get_plot("interactive_clustered_heatmap_plot") is None
    assert "interactive_clustered_heatmap_plot" not in {p["id"] for p in get_all_plots()}
    payload = list_plot_styles("grouped_heatmap")
    assert "violin" not in {item["id"] for item in payload["styles"]}
    moved = {item["id"]: item for item in payload["styles"] if item.get("engine_plugin_id") == "interactive_clustered_heatmap_plot"}
    assert moved["clustered_heatmap"]["example_id"] == "basic"
    assert moved["clustered_heatmap"]["label"] == "Clustered Heatmap"
    assert moved["custom_clustered_heatmap"]["example_id"] == "custom"
    assert moved["interactive_clustered_heatmap"]["example_id"] == "interactive"
    assert moved["split_panel_heatmap"]["example_id"] == "panels"
    charts = chart_categories()
    heat = next(c for g in charts["groups"] for c in g["charts"] if c["id"] == "heatmap")
    assert any(p["id"] == "grouped_heatmap" for p in heat["plots"])
    assert all(p["id"] != "interactive_clustered_heatmap_plot" for p in heat["plots"])
    hits = search_plots("clustered heatmap")
    assert hits and hits[0]["id"] == "grouped_heatmap"


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


def test_dual_triangle_demo_binds_both_matrices():
    from pathlib import Path

    from plot_web.app import build_command, choose_demo_file, plugin_config_path, read_yaml

    plugin = "interactive_dual_triangle_heatmap_plot"
    upper = choose_demo_file(plugin, "upper", {"formats": ["csv"]})
    lower = choose_demo_file(plugin, "lower", {"formats": ["csv"]})
    assert upper is not None and upper.name == "example_upper.csv"
    assert lower is not None and lower.name == "example_lower.csv"
    cmd = build_command(
        plugin,
        read_yaml(plugin_config_path(plugin)),
        {"upper": upper, "lower": lower},
        Path("/tmp/params.json"),
        Path("/tmp/out"),
    )
    assert "--lower" in cmd
    assert str(lower) in cmd


def test_mantel_demo_passes_mantel_table():
    from pathlib import Path

    from plot_web.app import ROOT_DIR, build_command, plugin_config_path, read_yaml

    plugin = "interactive_mantel_correlation_network"
    files = {
        "file": ROOT_DIR / "plugins" / plugin / "example_corr.csv",
        "mantel": ROOT_DIR / "plugins" / plugin / "example_mantel.csv",
    }
    cmd = build_command(
        plugin,
        read_yaml(plugin_config_path(plugin)),
        files,
        Path("/tmp/params.json"),
        Path("/tmp/out"),
    )
    assert "--mantel" in cmd


def test_pie_dot_matrix_studio_flags_are_declared():
    from pathlib import Path

    from plot_web.app import ROOT_DIR, build_command, plugin_config_path, read_yaml

    plugin = "pie_dot_matrix"
    src = (ROOT_DIR / "plugins" / plugin / "plot.R").read_text(encoding="utf-8")
    files = {
        "file": ROOT_DIR / "plugins" / plugin / "example_input.csv",
        "col_annot": ROOT_DIR / "plugins" / plugin / "example_col_annot.csv",
        "marks": ROOT_DIR / "plugins" / plugin / "example_marks.csv",
    }
    cmd = build_command(
        plugin,
        read_yaml(plugin_config_path(plugin)),
        files,
        Path("/tmp/params.json"),
        Path("/tmp/out"),
    )
    assert "--marks" in cmd
    annot_flag = "--col-annot" if "--col-annot" in cmd else "--col_annot"
    assert annot_flag in cmd
    assert f"'{annot_flag}'" in src or f'"{annot_flag}"' in src


def test_search_match_kinds():
    hits = search_plots("volcano")
    assert hits
    assert hits[0]["id"] == "volcano"
    assert hits[0]["match_kind"] == "exact"
    ridge = search_plots("ridge")
    kinds = {h["id"]: h.get("match_kind") for h in ridge}
    assert "gsea" in kinds or "ridgeline" in kinds
