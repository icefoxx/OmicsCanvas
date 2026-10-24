# Plot bug audit — 2026-10-23

Method:
1. **Visual review** of all 208 example renders (contact sheets).
2. **Parameter-sensitivity scan** (`scripts/param_sensitivity.py`): every schema parameter
   perturbed one at a time; the figure must change (strict pixel equality) and must not crash.
   Parameters without effect were re-tested on every example of the plugin and with their
   on/off switch enabled (`legend_show`, `background_show`, …) to separate gated options from bugs.
3. **Static checks**: schema parameters never read by `plot.R`; R `$` partial matching; device
   calls; config/schema conformance (`scripts/check_plugin_standards.py`, see `docs/standards/`).

Every fix was re-rendered and inspected; image baselines and gallery thumbnails were refreshed
(`scripts/smoke_plugins.py --compare`: 208/208).

## Fixed — rendering bugs

| Plugin | Bug | Cause |
|---|---|---|
| interactive_enrichment_lollipop | Point size ignored the size column (legend 20–60, dots all equal) | min/max size converted with different heuristics → range 3–4 |
| interactive_enrichment_lollipop | subtitle, caption, backgrounds, p-value labels silently ignored | params variable `p` reassigned to the ggplot object |
| interactive_enrichment_lollipop | `xlab`/`ylab` set but not drawn; legend order ignored `group_colors` | extra `*_title_show` gate; data order used |
| lollipop, go_kegg, gsea_ridge, histogram, regression, venn, fgsea, both triangle/clustered heatmaps | Unknown `font_family` crashed the figure | `pdf()` device; now `cairo_pdf` (font fallback) |
| interactive_clustered_heatmap_plot, interactive_dual_triangle_heatmap_plot | PNG not layout-deterministic | cairo `png()`; now `ragg::agg_png` |
| interactive_genomic_signal_track_plot | Title cut off, overlapping text, giant fonts; signal filled over lower tracks; feature labels over subtitle | cm vs inch sizing; unscaled peak height; fixed y positions |
| interactive_network_plot | Static figure: invisible white nodes, no labels, colourless legend | non-fillable shapes + `theme_void`; labels never drawn |
| violin_plot | Violins ran into neighbouring facet rows | zero y expansion |
| exp_stat_plot | A mean marker per cell in column mode; title repeated on stacked panels | `add.stat` not disabled; inverted condition (R/sca/expStatPlot.R) |
| quadrant_correlation_scatter | "p-value: 0" printed | now scientific / "< 2.2e-16" |
| interactive_pie_plot | Stray radius line in the donut hole; hole label off-centre | outline of a full-circle bar; label at radius/2 |
| interactive_dual_triangle_heatmap_plot | Colour bars inverted; annotation strip empty; stray "TRUE" | bar drawn high→low; sign error; `$` partial match |
| cluster_dendrogram_plot, den_plot | First leaf/tile and rotated labels cut at the left edge | zero expansion and margin (R/sca) |
| stat_plot (venn) | Set labels clipped | labels outside the data range |
| advanced_dim_plot | Background cells labelled "NA" in the legend | NA key; now "Background" |
| advanced_dim_plot | Embedded pies drawn as dots | each pie grob kept its title (`theme_void` still draws titles) |
| advanced_dim_plot | `legend_name` / `stat_legend_name` ignored with embedded pies | composed grob; explicit scale name beats `labs()` — titles now passed to `advDimPlot` |
| advanced_dim_plot | Long sample names made the legend wider than the plot | labels wrapped at `_ . -` (`legend_label_wrap`); legends stacked on the free side |
| advanced_dim_plot | `legend_nrow=1` with many groups: "Viewport has zero dimension(s)" | row count raised until the legend fits; logged |
| advanced_dim_plot split_highlight | One full legend per facet squeezed the panels | example layout (2 rows); per-facet legends are inherent (cluster numbering per split) |
| fgsea_enrichment_plot dot_summary | Suppressed-facet labels over the activated panel; in-panel labels duplicated the axis and overflowed | facets stacked vertically (`facet_grid`, free space); labels replace axis text and widen the x range |
| interactive_bubble_score_matrix | Rotated column headers ran into the matrix | top-axis text anchored with `hjust = 1` |
| interactive_clustered_heatmap_plot | Small heatmap; dendrogram never drawn; colour-bar title over a tick; `panel_titles` ignored | space reserved for undrawn tracks; dendrogram added; title above bar |
| interactive_arc_network_plot | Arcs flattened at the maximum height; weight mode drew tall narrow loops | scale applied before the cap; weight now modulates a distance-based height |
| interactive_ridgeline_plot | Whiskers beyond `x_limits` | box/whisker clamped to the limits |
| regression_scatter_plot | "R² = 3.087e-06" | R² printed with fixed decimals / "< 0.001" |
| SCA palette helper (all SCA plugins) | Unknown palette name aborted the figure | falls back to a default palette with a warning |
| den_plot | Every `plot_kind` option offered in the UI was unsupported | schema options ≠ code |
| classified_bar, regression_scatter, stacked_bar, lollipop | Placeholder text ("Hello world", "xiaoshi", an external tool name) as code/schema defaults | defaults now empty title / column name |
| Examples derived from an external reference gallery | Titles, legends and example ids carried the external tool's name | renamed to **CAB_demo** (ids, files, gallery cards, registry alias, docs, images) |

## Fixed — parameters that did nothing

| Change | Scope |
|---|---|
| Removed dead controls (never read, or no effect in any mode, verified dynamically) | 485 parameters in 30+ schemas |
| Shared theme helper `R/runtime/omicscanvas_theme.R` makes generic appearance parameters (fonts, title, axis, legend, panel, grid, margins) work | 19 plugins |
| `stratum_alpha`, `stratum_border_width` | alluvial_plot |
| `closed` (bin side was inverted) | interactive_histogram_plot |
| `expression_geom` violin / density / box / rug / diamond | interactive_genomic_signal_track_plot |
| `stroke` / `point_stroke_color` with `stroke_as_fill = false` | regression_scatter_plot |
| `cloud_stat = count` | interactive_ridgeline_plot |
| `min_value_show` | pie_dot_matrix |
| `bar_text_anchor` | stacked_bar_plot |
| `panel_titles`, `show_row_dendrogram`, `dendrogram_color` | interactive_clustered_heatmap_plot |

## Fixed — schema / config conformance

- 50 colour parameters typed `string` → `color` (free text crashed with "invalid colour");
  the editor's colour picker now accepts names such as `white`.
- 6 `*_face` parameters → `select` (plain / bold / italic / bold.italic).
- 31 column-mapping parameters → `column` / `columns` (column picker instead of free text).
- 3 union types (`string|integer`, `array|object`) → editor-supported types.
- 48 `config.yaml` files normalised (`id`, `name`, `version`, `language`, `entrypoint`, `status`;
  inputs declared with `id` — inputs declared with `name` were ignored by the runner).
- Studio categories unified (`Set intersections` → `Set / Enrichment`, `Matrix` → `Heatmap`,
  missing category for the arc network); every visible family has a chart type.
- `params$x` reads (partial matching) in classified_bar, combo_bar_line, stacked_bar.
- Absolute paths removed from 26 plugin READMEs/SKILL files; README added for go_kegg.

## Remaining (documented, not bugs)

- **Mode-gated parameters**: about 380 of 1354 perturbed parameters do not change the first
  example. Spot checks show options that only act in another mode, need a second switch, or need
  data the example lacks (ties on bin edges, unequal group sizes, `top_n` larger than the data).
  Rerun `scripts/param_sensitivity.py <plugin>` per plugin when touching it.
- **1571 untyped legacy parameters** in 26 schemas: the editor infers their control from the name.
  They are recorded in `scripts/plugin_standards_baseline.json`; new parameters must be typed.
- Clustered heatmap annotation tracks are drawn in the interactive HTML only.
- Data-dependent errors with clear messages (e.g. no pathway passes `min_match_fraction = 1`,
  missing membership columns) are intended.
