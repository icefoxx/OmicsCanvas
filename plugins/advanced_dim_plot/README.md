# Advanced Dimension Plot

This plugin wraps the original SCA `advDimPlot` plotting engine into a portable OmicsCanvas/BioFigureAI plot plugin.

For `plot_mode: "group"` and other standard dim-plot views, the default `plot_engine` is `sca_advdim`, so the plot is drawn by the copied SCA `advDimPlot()` function and keeps the old layer order, `themeDefault/themeBlank`, mark layers, highlight behavior, embedded `statPlot` summaries, density/hex/raster branches, and legend assembly. The plugin adds only the standard command-line contract, parameter translation, safer package checks, palette-path handling, and standard outputs.

Set `"plot_engine": "native"` only when you intentionally want the lightweight plugin-native fallback/extension layers.

It accepts a flat embedding table with one row/cell ID column, two numeric embedding columns such as `dim1` and `dim2`, and optional group, split, feature, score, or label columns.

## Run Examples

Run the full advDimPlot-like gallery:

```bash
plugins/advanced_dim_plot/run_all_examples.sh <repo-root>
```

This writes one output directory per figure family under `/tmp/advanced_dim_*_out`.

The seven legacy PDF compatibility examples (`old_advdim_compat`, `pdf_bg_condition`,
`pdf_bg_cutoff`, `pdf_cluster_composition_ring`, `pdf_highlight_cells`,
`pdf_old_style_single_panel`, and `pdf_split_samples`) are recorded in
`all_examples_gallery/example_failures.txt`. Their supplied parameter files require
an `orig.ident` column, which is not present in the supplied `example_input.csv`;
they are therefore not represented by fabricated PNGs.

Run the examples that specifically mirror the figures shown in `advDimPlot.pdf`:

```bash
plugins/advanced_dim_plot/run_pdf_matched_examples.sh <repo-root>
```

These use `example_pdf_like_input.csv` and write `/tmp/advanced_dim_pdf_*_out`.
The rendered PDF reference pages are stored in `pdf_reference_pages/`, and a compact generated-output contact sheet is stored at `pdf_matched_gallery/pdf_matched_gallery.png`.

PDF-matched parameter files:

- `example_pdf_basic_umap_params.json`
- `example_pdf_ellipse_mark_params.json`
- `example_pdf_split_samples_params.json`
- `example_pdf_cluster_composition_ring_params.json`
- `example_pdf_highlight_cells_params.json`
- `example_pdf_bg_cutoff_params.json`
- `example_pdf_bg_condition_params.json`

The original SCA source/helper files used as implementation reference are copied under the shared `R/sca/` library.

Run a direct old-argument compatibility example. This params file intentionally uses SCA-style names such as `group.by`, `split.by`, `pt.size`, `theme.use`, `show.mark`, `stat.plot.by`, and `cells.highlight`; the plugin translates them to the standardized BioFigureAI controls at runtime.

```bash
Rscript plugins/advanced_dim_plot/plot.R \
  --input plugins/advanced_dim_plot/example_pdf_like_input.csv \
  --params plugins/advanced_dim_plot/example_old_advdim_compat_params.json \
  --output /tmp/advanced_dim_old_compat_out
```

Group colors, cluster labels, and hull marks:

```bash
Rscript plugins/advanced_dim_plot/plot.R \
  --input plugins/advanced_dim_plot/example_input.csv \
  --params plugins/advanced_dim_plot/example_group_params.json \
  --output /tmp/advanced_dim_group_out
```

Feature/expression gradients:

```bash
Rscript plugins/advanced_dim_plot/plot.R \
  --input plugins/advanced_dim_plot/example_input.csv \
  --params plugins/advanced_dim_plot/example_feature_params.json \
  --output /tmp/advanced_dim_feature_out
```

Split panels with selected highlighted/labelled cells:

```bash
Rscript plugins/advanced_dim_plot/plot.R \
  --input plugins/advanced_dim_plot/example_input.csv \
  --params plugins/advanced_dim_plot/example_split_highlight_params.json \
  --output /tmp/advanced_dim_split_out
```

Hexbin and density style:

```bash
Rscript plugins/advanced_dim_plot/plot.R \
  --input plugins/advanced_dim_plot/example_input.csv \
  --params plugins/advanced_dim_plot/example_density_hex_params.json \
  --output /tmp/advanced_dim_hex_out
```

Coexpression color mixing:

```bash
Rscript plugins/advanced_dim_plot/plot.R \
  --input plugins/advanced_dim_plot/example_input.csv \
  --params plugins/advanced_dim_plot/example_coexpression_params.json \
  --output /tmp/advanced_dim_coexpression_out
```

Lineage/path overlays:

```bash
Rscript plugins/advanced_dim_plot/plot.R \
  --input plugins/advanced_dim_plot/example_input.csv \
  --params plugins/advanced_dim_plot/example_lineage_params.json \
  --output /tmp/advanced_dim_lineage_out
```

Additional style examples:

```bash
# Axis labels, font family, font face, tick labels, and label-to-axis distance
Rscript plugins/advanced_dim_plot/plot.R --input plugins/advanced_dim_plot/example_input.csv --params plugins/advanced_dim_plot/example_axis_label_controls_params.json --output /tmp/advanced_dim_axis_label_controls_out

# Selected cell highlight rings plus embedded cluster-composition rings
Rscript plugins/advanced_dim_plot/plot.R --input plugins/advanced_dim_plot/example_input.csv --params plugins/advanced_dim_plot/example_highlight_ring_params.json --output /tmp/advanced_dim_highlight_ring_out

# Embedded stat.plot.by-style pies at cluster centers
Rscript plugins/advanced_dim_plot/plot.R --input plugins/advanced_dim_plot/example_input.csv --params plugins/advanced_dim_plot/example_embedded_pie_params.json --output /tmp/advanced_dim_embedded_pie_out

# Composition/statistics bar panel below the embedding
Rscript plugins/advanced_dim_plot/plot.R --input plugins/advanced_dim_plot/example_input.csv --params plugins/advanced_dim_plot/example_stat_panel_params.json --output /tmp/advanced_dim_stat_panel_out

# Alternative mark shapes: hull, ellipse, rect, circle
Rscript plugins/advanced_dim_plot/plot.R --input plugins/advanced_dim_plot/example_input.csv --params plugins/advanced_dim_plot/example_mark_shapes_params.json --output /tmp/advanced_dim_mark_shapes_out

# Filled density overlay
Rscript plugins/advanced_dim_plot/plot.R --input plugins/advanced_dim_plot/example_input.csv --params plugins/advanced_dim_plot/example_density_filled_params.json --output /tmp/advanced_dim_density_filled_out

# Blank theme / label-forward style
Rscript plugins/advanced_dim_plot/plot.R --input plugins/advanced_dim_plot/example_input.csv --params plugins/advanced_dim_plot/example_blank_theme_params.json --output /tmp/advanced_dim_blank_theme_out

# Alternative coexpression color mixing
Rscript plugins/advanced_dim_plot/plot.R --input plugins/advanced_dim_plot/example_input.csv --params plugins/advanced_dim_plot/example_coexpression_screen_params.json --output /tmp/advanced_dim_coexpression_screen_out

# Background mask by score/cutoff
Rscript plugins/advanced_dim_plot/plot.R --input plugins/advanced_dim_plot/example_input.csv --params plugins/advanced_dim_plot/example_background_mask_params.json --output /tmp/advanced_dim_background_mask_out

# scattermore-backed raster rendering
Rscript plugins/advanced_dim_plot/plot.R --input plugins/advanced_dim_plot/example_input.csv --params plugins/advanced_dim_plot/example_raster_params.json --output /tmp/advanced_dim_raster_out
```

## Core Params

```json
{
  "plot_mode": "group",
  "x_column": "dim1",
  "y_column": "dim2",
  "id_column": "cell",
  "group_column": "cluster",
  "split_column": "sample",
  "facet_split": true
}
```

Supported `plot_mode` values:

```text
group, feature, expression, gradient, coexpression, blend, feature_mix
```

## Highly Customizable Controls

Selection and click-included/click-excluded style:

```json
{
  "rows_include": ["Cell001", "Cell002"],
  "rows_exclude": ["Cell099"],
  "groups_include": ["B cell", "Myeloid"],
  "groups_exclude": ["Cycling"]
}
```

Title, axes, limits, legend, and theme:

```json
{
  "title": "Custom title",
  "subtitle": "Custom subtitle",
  "xlab": "UMAP 1",
  "ylab": "UMAP 2",
  "xlim": [-6, 6],
  "ylim": [-5, 5],
  "legend_name": "Cell type",
  "legend_position": "bottom",
  "legend_direction": "horizontal",
  "theme_use": "classic",
  "font_family": "Arial",
  "show_grid": false,
  "panel_border_show": true
}
```

Axis label distance and text details:

```json
{
  "xlab_show": true,
  "ylab_show": true,
  "xlab": "Custom Dim 1",
  "ylab": "Custom Dim 2",
  "axis_title_size": 15,
  "axis_title_font_family": "Arial",
  "axis_title_fontface": "bold",
  "x_axis_title_margin_top": 18,
  "y_axis_title_margin_right": 20,
  "x_axis_text_size": 10,
  "y_axis_text_size": 10,
  "x_axis_text_angle": 25,
  "axis_arrow_show": true,
  "axis_arrow_x_label_dx_npc": 0.02,
  "axis_arrow_x_label_dy_npc": -0.03,
  "axis_arrow_y_label_dx_npc": -0.03,
  "axis_arrow_y_label_dy_npc": 0.02
}
```

Point and group color styles:

```json
{
  "point_size": 0.9,
  "point_alpha": 0.85,
  "point_shape": 16,
  "group_palette": "Set2",
  "group_color_map": {
    "T cell": "#4E79A7",
    "B cell": "#F28E2B"
  }
}
```

Feature gradient styles:

```json
{
  "plot_mode": "feature",
  "feature_columns": ["CD3D", "MS4A1"],
  "feature_bg_cutoff": 0.05,
  "feature_colors": ["#F2F2F2", "#8BD3DD", "#4878D0", "#B40426"],
  "feature_lower_quantile": 0.02,
  "feature_upper_quantile": 0.98,
  "legend_bar_height_cm": 2.4
}
```

Labels, highlights, hulls, density, and hex:

```json
{
  "selected_labels": ["Cell012", "Cell090"],
  "label_top_n": 5,
  "label_groups": true,
  "label_size": 3.2,
  "label_line_color": "#555555",
  "highlight_rows": ["Cell012", "Cell090"],
  "highlight_fill": "#FFE45C",
  "highlight_border_color": "#111111",
  "highlight_ring_show": true,
  "highlight_ring_color": "#D7191C",
  "highlight_ring_size": 5.2,
  "highlight_ring_stroke": 1.1,
  "show_mark": true,
  "mark_type": "hull",
  "mark_alpha": 0.12,
  "show_density": true,
  "hex": false
}
```

Embedded statistics and lower stat panel:

```json
{
  "stat_plot_column": "sample",
  "show_stat_embedded": true,
  "stat_embedded_size": 0.045,
  "stat_embedded_ring_show": true,
  "stat_embedded_ring_color": "#111111",
  "stat_embedded_ring_size": 6.2,
  "stat_color_map": {"CK": "#4E79A7", "DrugA": "#F28E2B", "DrugB": "#59A14F"},
  "show_stat_panel": true,
  "stat_plot_source": "percent",
  "stat_plot_position": "stack"
}
```

Background masking and raster rendering:

```json
{
  "background_column": "module_score",
  "background_cutoff": 0.2,
  "background_color": "#D6D6D6",
  "background_alpha": 0.28,
  "raster": true,
  "raster_dpi": [1200, 1200],
  "raster_point_size": 1
}
```

Lineage/path overlays:

```json
{
  "lineages": [
    {"name": "trajectory A", "x": [-4, -2, 0, 2], "y": [2, 0, -1, 1]}
  ],
  "lineage_color_map": {"trajectory A": "#111111"},
  "lineage_line_width": 1.4,
  "lineage_arrow": true
}
```

Successful runs write `result.svg`, `result.pdf`, `result.png`, `figure.json`, `selected_rows.csv`, and `run.log`.
## Reproducible examples

Bundles are in `plugins/advanced_dim_plot/examples/<id>/`. Each contains `params.json`, copied command inputs under `input/`, and `expected/result.png`. `manifest.json` is the machine-readable entry point and records how to rerun the example.
Legacy PDF cases that cannot render with the default input remain documented in `example_failures.txt`; only real renders are bundled.

