# UMAP / t-SNE variant audit (v1.0)

Inspected `plugins/advanced_dim_plot` examples, params, and gallery
previews before changing the registry. REVIEW items were not classified
from names alone.

| legacy ID | current title | implementation | current parameters | demo | visual signature | canonical variant | classification | reason | mapping |
|---|---|---|---|---|---|---|---|---|---|
| pdf_repro_basic_umap | Basic UMAP (clusters) | group coloring + labels | plot_mode=group | yes | cluster colors | clusters (Basic UMAP) | KEEP / demo | primary cluster view | variant=clusters |
| basic_umap | basic_umap | same group view | group labels | yes | cluster colors | clusters | LEGACY_ALIAS | duplicate of Basic UMAP | variant=clusters |
| group | group | same group view | group labels | yes | cluster colors | clusters | LEGACY_ALIAS | duplicate of Basic UMAP | variant=clusters |
| axis_label_controls | axis_label_controls | axis title/tick styling | axis_* | yes | same encoding, different axes | clusters | PARAMETER | Studio → Axes | variant=clusters |
| blank_theme | blank_theme | theme_use=blank + arrows | theme | yes | blank theme | clusters | PRESET | Studio → Theme Blank | preset=blank |
| pdf_basic_umap | pdf_basic_umap | publication export | width/height/pdf | yes | PDF of Basic UMAP | clusters | EXPORT | Export → PDF | preset=publication |
| raster | raster | raster=true | raster | yes | rasterized points | clusters | RENDERING | Studio rendering_mode | rendering_mode=raster |
| pdf_repro_ellipse_mark | Ellipse marks | show_mark + ellipse | mark_type=ellipse | yes | group ellipses | ellipse | KEEP / demo | group region marks | variant=ellipse |
| ellipse_mark | ellipse_mark | same | mark_type=ellipse | yes | ellipses | ellipse | LEGACY_ALIAS | duplicate | variant=ellipse |
| mark_shapes | mark_shapes | mark_type still ellipse/hull/rect/circle | mark_type | yes | mark style, not point shapes | ellipse | PARAMETER/PRESET | Ellipse Marks → mark style | mark_type=ellipse |
| pdf_ellipse_mark | pdf_ellipse_mark | PDF of ellipses | export | yes | PDF | ellipse | EXPORT | Export → PDF | preset=publication |
| pdf_repro_split_samples | Split by sample | split_column + facet | facet_split | yes | faceted samples | split_samples | KEEP / demo | sample panels | variant=split_samples |
| split_samples | split_samples | same | facet | yes | faceted samples | split_samples | LEGACY_ALIAS | duplicate | variant=split_samples |
| split_highlight | split_highlight | facet AND highlight_rows | split + highlight | yes | panels + subset | split_highlight | KEEP | faceting plus subset highlight is a distinct scientific view | variant=split_highlight |
| pdf_repro_composition_ring | Composition rings | show_stat_embedded pies/rings | stat_plot_column | yes | composition glyphs | composition | KEEP / demo | composition encoding | composition_glyph=ring |
| cluster_composition_ring | cluster_composition_ring | embedded composition | stat_plot_column | yes | rings | composition | LEGACY_ALIAS | same encoding | composition_glyph=ring |
| embedded_pie | embedded_pie | embedded pies | show_stat_embedded | yes | pies | composition | MERGE | same data semantics as ring, display style only | composition_glyph=pie |
| pdf_repro_highlight_cells | Highlight cells | highlight_rows + fade | highlight_* | yes | subset emphasis | highlight_cells | KEEP / demo | subset encoding | variant=highlight_cells |
| highlight_cells | highlight_cells | same | highlight | yes | subset | highlight_cells | LEGACY_ALIAS | duplicate | variant=highlight_cells |
| highlight_ring | highlight_ring | highlight_ring_show | ring overlay | yes | ring mark on highlights | highlight_cells | MERGE | mark style, not a new encoding | highlight_style=ring |
| pdf_repro_bg_cutoff_mito | Background by mito cutoff | background_column + cutoff | mito>5 | yes | numeric mask | background_mask | MERGE / demo | example of cutoff mode | background_mode=cutoff |
| pdf_repro_bg_condition | Background by samples | background_levels | category mask | yes | category mask | background_mask | MERGE / demo | example of category mode | background_mode=category |
| background_mask | background_mask | numeric cutoff mask | cutoff | yes | mask | background_mask | KEEP / alias | canonical Background / Mask | background_mode=cutoff |
| bg_cutoff | bg_cutoff | mito cutoff | cutoff=5 | yes | cutoff mask | background_mask | LEGACY_ALIAS | same as mito example | background_mode=cutoff |
| bg_condition | bg_condition | sample levels | category | yes | category mask | background_mask | LEGACY_ALIAS | same as samples example | background_mode=category |
| density_filled | density_filled | show_density + density_filled | KDE fill | yes | filled contours | density | MERGE | density style | density_style=filled |
| density_hex | density_hex | hex=true (+ optional contours) | hex aggregation | yes | hexbin counts | density | MERGE | distinct aggregation, kept as style of Density | density_style=hexbin |
| feature | feature | plot_mode=feature | feature_columns | yes | expression gradient | feature_expression | KEEP | feature encoding | variant=feature_expression |
| coexpression | coexpression | plot_mode=coexpression mix=blend | mix blend | yes | mixed color | coexpression | KEEP | mixed-expression map | color_mix_mode=blend |
| coexpression_screen | coexpression_screen | same mode, mix=screen | mix screen | yes | mixed color | coexpression | MERGE | not a threshold screen; only mix mode | color_mix_mode=screen |
| lineage | lineage | lineages overlay | path coords | yes | trajectory paths | lineage | KEEP | trajectory encoding | variant=lineage |
| stat_panel | stat_panel | show_stat_panel bar below | composition bar | yes | embedding + stats | stat_panel | KEEP | quantitative panel is a distinct view | variant=stat_panel |

## REVIEW outcomes

- **split_highlight**: KEEP. Combines faceting with a cell subset.
- **embedded_pie vs ring**: MERGE into Composition (glyph style).
- **highlight_ring**: MERGE into Highlight Cells (ring style).
- **density_hex**: MERGE into Density as hexbin style (aggregation preserved in backend).
- **coexpression_screen**: MERGE into Coexpression Map. Params only change `color_mix_mode`.
- **stat_panel**: KEEP as Embedding + Statistical Panel.
- **mark_shapes**: NOT point-shape encoding; params set `mark_type` hull/ellipse/rect/circle. PARAMETER of Ellipse Marks.
