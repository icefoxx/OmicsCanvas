# 04 — Classification

Every plugin is placed in **four layers**. Each layer answers a different user question; all four
are required (rules P002, G001–G004).

| Layer | Answers | Where | Drives |
|---|---|---|---|
| 1. Studio category | "Which shelf is it on?" | `config.yaml` `category` / `subcategory` | Studio sidebar tree |
| 2. Registry family | "Which analysis question does it answer, with what data?" | `plot_web/registry/overrides.yaml` | Scenario navigation, search, recommendations, variants |
| 3. Chart type | "What does it look like?" | `CHART_CATEGORY_TAXONOMY` in `plot_web/plot_registry.py` | Browse by chart type |
| 4. vNext family | "Which scientific checks apply?" | `families` in `vnext/migrate/rules.yaml` | Guardrails, PlotSpec metadata |

## Decision procedure

1. **Is it a variant of an existing plugin?** Compare data roles and visual grammar with the table
   at the end (see also README → "First decision"). If yes, add parameters/examples there and add a
   variant to that family in `overrides.yaml` — stop here.
2. **Chart type** (layer 3) from the marks the figure is made of: points on two continuous axes →
   `scatter`; filled distribution shape → `violin`/`density`/`ridgeline`; cells of a grid →
   `heatmap`/`dot_matrix`; … A plot may sit under several chart types (a dot plot is `dot` and
   `dot_matrix`).
3. **Analysis contexts and tasks** (layer 2) from the question the figure answers, using only the
   values in `plot_web/registry/vocab.yaml` (`contexts`, `tasks`, `data_roles`).
4. **Studio category** (layer 1): the shelf where a user would look first — usually the chart
   grammar (`Heatmap`, `Scatter`), except for domain shelves where users browse by analysis
   (`Set / Enrichment`, `Dimension`, `Genomics`).
5. **vNext family** (layer 4) from the kind of statistics shown; this selects the guardrails, so
   pick by what can go scientifically wrong, not by looks.

## Layer 1 — Studio categories

Allowed values (also `STUDIO_CATEGORIES` in `scripts/check_plugin_standards.py`):

| Category | For | Example subcategories |
|---|---|---|
| Dimension | cell/sample embeddings, trajectories | Embedding, Trajectory |
| Feature | feature values mapped on embeddings | Expression map, Density |
| Expression / Statistics | expression summaries per group, SCA statistics | Statistics, Bar, Combo, Dendrogram, Composition |
| Distribution | distributions of one variable | General |
| Comparison | group vs group effects, ranked differences | Effect, Combo, General, Polar, Line |
| Composition | parts of a whole, flows between categories | Flow, General, Hierarchical |
| Correlation | association between features/samples | General |
| Scatter | x–y plots with statistics | Volcano, Regression, Correlation, Ternary |
| Heatmap | matrices of values | Matrix, Grouped, Binary, General, Circular |
| Network | graphs, arcs, sankey-style networks | Arc, General |
| Set / Enrichment | set overlap and functional enrichment | Set, UpSet, Enrichment, GSEA, Lollipop |
| Genomics | coordinate-based tracks | General |
| Motif | sequence logos | General |
| Multi-panel | composite figures with linked panels | Annotation |
| Benchmark | method-comparison score tables | General |

`subcategory` is short and reuses an existing value of the same category when one fits.

## Layer 2 — Registry family (`plot_web/registry/overrides.yaml`)

`python -m plot_web.plot_registry build` scans `plugins/*` and creates one family per plugin;
`overrides.yaml` adds the curated metadata. For a new plugin add:

```yaml
family_id_map:
  my_plot: my_family            # only if the public id should differ from the plugin id
families:
  my_family:
    name: My Plot
    short_name: My Plot
    description: One sentence for the card.
    aliases: [synonyms users search for]
    categories: [single_cell]                    # contexts it belongs to
    analysis_contexts: [single_cell, gene_expression]   # vocab.yaml → contexts
    tasks: [feature_expression]                  # vocab.yaml → tasks
    data_requirements:
      required_roles: [x, y]                     # vocab.yaml → data_roles
      optional_roles: [group]
      accepted_types: {x: numeric, y: numeric, group: categorical}
    variants:
      - id: basic
        name: Basic
        short_description: …
        representative_example: basic            # an example id from examples/index.json
```

`hidden_families` removes a family from discovery (kept for direct links). A hidden family needs no
chart type; give it one when un-hiding it.

## Layer 3 — Chart types (`CHART_CATEGORY_TAXONOMY`)

| Group | Chart types |
|---|---|
| distribution | violin, density, histogram, boxplot, ridgeline, beeswarm |
| comparison | barplot, dot, lollipop, radar, parallel |
| relationship | scatter, bubble, connected_scatter, density_2d |
| matrix | heatmap, correlogram, dot_matrix |
| composition | pie, doughnut, stacked_bar, treemap, sunburst |
| flow | sankey, alluvial, network, chord, arc |
| sets | venn, upset |
| tables | table, summary_table |
| specialized | genomic_track, motif, dendrogram, ternary, spatial_map |

Add the family id to every matching chart's `family_ids`. A visual grammar that fits none of these
is a new chart type (below).

## Layer 4 — vNext families (`vnext/migrate/rules.yaml`)

| Family | Guardrails (`vnext/validate/scientific.py`) |
|---|---|
| enrichment | MISSING_CATEGORY, MISSING_SIGNED_EFFECT, EFFECT_NOT_BIDIRECTIONAL |
| differential_expression | FOLD_CHANGE_NOT_LOG, EFFECT_NOT_BIDIRECTIONAL |
| embedding | NON_NUMERIC_COORDINATES, DUPLICATE_IDS, TOO_MANY_GROUPS |
| composition | NEGATIVE_COMPOSITION |
| group_comparison | STAT_METHOD_UNSPECIFIED, SMALL_GROUPS |
| network | NEGATIVE_WEIGHT, SELF_LOOPS |
| matrix, correlation, set_overlap, genomic_track, multi_panel | global guardrails only |

Add the plugin to one family list. If its column parameters are not detected correctly, or it
exposes a statistical method, add a `skills.<plugin_id>` entry (roles, statistics) — see the
existing entries in `rules.yaml` — then run `python -m vnext.cli migrate` and review
`plugins/<id>/vnext/metadata.yaml`.

## Adding a new category, chart type, context or family

Only when no existing value describes the plot truthfully — never to give a single plugin its own
shelf. In the same change:

| New | Edit |
|---|---|
| Studio category | `STUDIO_CATEGORIES` in `scripts/check_plugin_standards.py`; the table above |
| Chart type / group | `CHART_CATEGORY_TAXONOMY` in `plot_web/plot_registry.py`; the table above |
| Context or task | `plot_web/registry/vocab.yaml`; `ANALYSIS_TAXONOMY` (scenario pages) and `BROWSE_CATEGORIES` in `plot_web/plot_registry.py` |
| vNext family | `families` in `vnext/migrate/rules.yaml`; a rule function in `FAMILY_RULES` (`vnext/validate/scientific.py`) when the family has its own checks; the table above |

Then rebuild (`python -m plot_web.plot_registry build`), validate
(`python -m plot_web.plot_registry validate`), run `pytest -q plot_web/tests vnext/tests`, and
regenerate the table below.

## Current assignments

Generated from the configs, registry, taxonomy and rules on 2026-10-23.

| Plugin | Studio category / subcategory | Registry family | Chart type(s) | vNext family |
|---|---|---|---|---|
| `advanced_dim_plot` | Dimension / Embedding | umap_tsne | density_2d, pie, scatter | embedding |
| `advanced_feature_plot` | Feature / Expression map | feature_embedding | density, density_2d, scatter | embedding |
| `alluvial_plot` | Composition / Flow | alluvial | alluvial, chord, sankey | composition |
| `balloon_plot` | Heatmap / Matrix | balloon_plot (hidden) | — | matrix |
| `classified_bar_plot` | Expression / Statistics / Bar | classified_bar_plot (hidden) | — | composition |
| `circular_bar_plot` | Comparison / Polar | circular_bar_plot | barplot | group_comparison |
| `circular_heatmap` | Heatmap / Circular | circular_heatmap | heatmap | matrix |
| `cluster_dendrogram_plot` | Expression / Statistics / Dendrogram | cluster_dendrogram_plot | dendrogram | matrix |
| `combo_bar_dot_matrix` | Comparison / Combo | combo_bar_dot_matrix | barplot, dot, dot_matrix | group_comparison |
| `combo_bar_line_plot` | Expression / Statistics / Combo | combo_bar_line_plot (hidden) | — | group_comparison |
| `den_plot` | Expression / Statistics / Dendrogram | den_plot (hidden) | density | matrix |
| `dot_plot` | Expression / Statistics / Expression | dot_plot | bubble, dot, dot_matrix | matrix |
| `dynamic_venn_diagram` | Set / Enrichment / Set | venn | venn | set_overlap |
| `exp_stat_plot` | Expression / Statistics / Statistics | exp_stat_plot | barplot, stacked_bar | group_comparison |
| `feature_density_plot` | Feature / Density | feature_density_plot (hidden) | — | embedding |
| `fgsea_enrichment_plot` | Set / Enrichment / Enrichment | gsea | ridgeline, sankey | enrichment |
| `go_kegg_enrichment_bar_bubble` | Set / Enrichment / Enrichment | go_kegg_enrichment_bar_bubble | barplot | enrichment |
| `group_heatmap` | Heatmap / Grouped | grouped_heatmap | heatmap | matrix |
| `gsea_pathway_heatmap` | Set / Enrichment / GSEA + Heatmap | gsea_heatmap (hidden) | — | enrichment |
| `gsea_ridge_nes_plot` | Set / Enrichment / GSEA | gsea_ridge_nes_plot (hidden) | — | enrichment |
| `highlight_effect_plot` | Comparison / Effect | highlight_effect_plot | beeswarm | group_comparison |
| `interactive_arc_network_plot` | Network / Arc | interactive_arc_network_plot | arc | network |
| `interactive_binary_plot` | Heatmap / Binary | interactive_binary_plot (hidden) | — | matrix |
| `interactive_bubble_score_matrix` | Benchmark / General | interactive_bubble_score_matrix | bubble | matrix |
| `interactive_clustered_heatmap_plot` | Heatmap / General | interactive_clustered_heatmap_plot (hidden) | — | matrix |
| `interactive_correlation_matrix` | Correlation / General | interactive_correlation_matrix | correlogram | correlation |
| `interactive_dual_triangle_heatmap_plot` | Heatmap / General | interactive_dual_triangle_heatmap_plot (hidden) | — | matrix |
| `interactive_dumbbell_plot` | Comparison / General | interactive_dumbbell_plot | connected_scatter, lollipop | group_comparison |
| `interactive_enrichment_lollipop` | Set / Enrichment / Lollipop | enrichment_lollipop | lollipop | enrichment |
| `interactive_genomic_signal_track_plot` | Genomics / General | interactive_genomic_signal_track_plot | genomic_track | genomic_track |
| `interactive_histogram_plot` | Distribution / General | interactive_histogram_plot | histogram | group_comparison |
| `interactive_mantel_correlation_network` | Correlation / General | interactive_mantel_correlation_network | network | correlation |
| `interactive_motif_logo_plot` | Motif / General | interactive_motif_logo_plot | motif | genomic_track |
| `interactive_network_plot` | Network / General | interactive_network_plot | network | network |
| `interactive_pie_plot` | Composition / General | interactive_pie_plot | doughnut, pie | composition |
| `interactive_radar_plot` | Comparison / General | interactive_radar_plot | radar | group_comparison |
| `interactive_ridgeline_plot` | Distribution / General | ridgeline | ridgeline | group_comparison |
| `interactive_sankey_plot` | Network / General | sankey (hidden) | — | network |
| `interactive_upset_plot` | Set / Enrichment / UpSet | upset | upset | set_overlap |
| `interactive_violin_plot` | Distribution / General | interactive_violin_plot | beeswarm, boxplot, violin | group_comparison |
| `line_plot` | Comparison / Line | line_plot | connected_scatter | group_comparison |
| `lineage_plot` | Dimension / Trajectory | trajectory | scatter | embedding |
| `pie_dot_matrix` | Heatmap / Matrix | pie_dot_matrix (hidden) | — | matrix |
| `quadrant_correlation_scatter` | Scatter / Correlation | quadrant_correlation_scatter | scatter | correlation |
| `raincloud_plot` | Distribution / General | raincloud_plot | beeswarm, boxplot, violin | group_comparison |
| `ranked_annotation_panel` | Multi-panel / Annotation | ranked_annotation_panel | lollipop, parallel, summary_table | multi_panel |
| `regression_scatter_plot` | Scatter / Regression | regression_scatter_plot | scatter | correlation |
| `sca_volcano_plot` | Scatter / Volcano | volcano | scatter | differential_expression |
| `stacked_bar_plot` | Expression / Statistics / Composition | stacked_bar_plot (hidden) | — | composition |
| `sunburst_plot` | Composition / Hierarchical | sunburst_plot | doughnut, sunburst | composition |
| `stat_plot` | Expression / Statistics / Statistics | stat_plot (hidden) | — | group_comparison |
| `ternary_plot` | Scatter / Ternary | ternary_plot | ternary | composition |
| `threshold_matrix_heatmap` | Heatmap / Matrix | threshold_matrix_heatmap | heatmap | matrix |
| `treemap_plot` | Composition / Hierarchical | treemap_plot | treemap | composition |
| `violin_plot` | Expression / Statistics / Distribution | violin_plot | beeswarm, boxplot, violin | group_comparison |
| `waterfall_plot` | Comparison / General | waterfall_plot | barplot | group_comparison |

| `circular_tree_embedding` | Dimension / Embedding | circular_tree_embedding | scatter, dendrogram | embedding |

## Specialty plot additions

`spatial_map` describes filled anatomical/tissue-region polygons, a grammar not covered by the existing chart types. It uses the existing Feature category and matrix guardrails.

| Plugin | Studio category / subcategory | Registry family | Chart type(s) | vNext family |
|---|---|---|---|---|
| `survival_plot` | Comparison / Survival | survival_plot | connected_scatter | group_comparison |
| `binary_evaluation_plot` | Benchmark / General | binary_evaluation_plot | connected_scatter | group_comparison |
| `forest_plot` | Comparison / Effect | forest_plot | lollipop | group_comparison |
| `oncoprint_plot` | Heatmap / Matrix | oncoprint_plot | heatmap | matrix |
| `manhattan_qq_plot` | Genomics / General | manhattan_qq_plot | scatter, genomic_track | genomic_track |
| `bland_altman_plot` | Scatter / Comparison | bland_altman_plot | scatter | correlation |
| `swimmer_plot` | Comparison / General | swimmer_plot | barplot | group_comparison |
| `protein_variant_plot` | Genomics / General | protein_variant_plot | lollipop, genomic_track | genomic_track |
| `clonal_fish_plot` | Composition / Flow | clonal_fish_plot | alluvial | composition |
| `sequence_alignment_plot` | Genomics / General | sequence_alignment_plot | heatmap, genomic_track | genomic_track |
| `circular_genomic_plot` | Genomics / General | circular_genomic_plot | genomic_track, heatmap | genomic_track |
| `nomogram_plot` | Multi-panel / Annotation | nomogram_plot | parallel, summary_table | multi_panel |
| `interactive_3d_scatter` | Dimension / Embedding | interactive_3d_scatter | scatter | embedding |
| `bar3d_plot` | Comparison / General | bar3d_plot | barplot | matrix |
| `radviz_plot` | Dimension / Embedding | radviz_plot | scatter | embedding |
| `ecdf_plot` | Distribution / General | ecdf_plot | connected_scatter | group_comparison |
| `spatial_region_plot` | Feature / Expression map | spatial_region_plot | spatial_map | matrix |
| `annotated_tree_plot` | Expression / Statistics / Dendrogram | annotated_tree_plot | dendrogram | matrix |
| `circular_distribution_plot` | Distribution / General | circular_distribution_plot | scatter | group_comparison |
| `embedding_vector_plot` | Dimension / Trajectory | embedding_vector_plot | scatter, connected_scatter | embedding |


| `linked_matrix_network_plot` | Multi-panel / Annotation | linked_matrix_network_plot | heatmap, network | multi_panel |
| `risk_stratification_panel` | Multi-panel / Annotation | risk_stratification_panel | scatter, heatmap | multi_panel |

The `z` data role records an independent third numeric coordinate. It is added to registry vocabulary and canonical vNext roles; embedding guardrails validate Z whenever mapped. Other data roles retain their existing meanings.

Existing `line_plot` also supports supplied interval bands; `circular_heatmap` supports categorical annotation rings; `spatial_region_plot` supports measured spots. These remain within their existing category, chart type and vNext family.
