# Hierarchical Marker Panel

Show hierarchical cell-type labels, cell counts, and marker expression in one publication-style panel.

## Input

One tidy table (CSV/TSV/TXT), with one row per cell-type/marker pair. Required columns are
`cell_type`, `class`, `subclass`, `cell_number`, `gene`, `average_transcript`, and
`pct_expressed`; all can be remapped in `params.json`. For sample composition bars, add
`sample` and `sample_cell_number`, repeated consistently for each marker row.

## Main parameters

| Group | Parameters |
|---|---|
| Data | `*_column`, `cell_type_order`, `marker_order`, `sample_order` |
| Marks | `dot_min`, `dot_max`, `point_alpha`, `point_stroke`, `bar_width`, `bar_mode` |
| Colours | `class_colors`, `sample_colors`, `average_transcript_colors`, branch colors |
| Labels / legend | `title`, hierarchy label sizes, `count_label`, `legend_*` |
| Layout | automatic width/height, branch heights/lengths, label adaptation |
| Export | `width`, `height` (inches), `dpi` |

Full list with defaults: `params_schema.json`.

## Run

```bash
Rscript plugins/hierarchical_marker_panel/plot.R \
  --input plugins/hierarchical_marker_panel/examples/basic/input/example_input.csv \
  --params plugins/hierarchical_marker_panel/examples/basic/params.json \
  --output /tmp/hierarchical_marker_panel_out
```

Outputs: `result.svg`, `result.pdf`, `result.png`, `figure.json`, `run.log`, `data_used.csv`,
`visual_config_used.json`;
`error.json` on failure.

`bar_mode` can be `cell_number` (one bar per cell type), `sample_number` (stacked sample
counts), or `sample_percent` (100% stacked sample composition). Sample modes require both
sample columns and validate that each cell-type/sample count is consistent across marker rows.

The hierarchy, bars, and dot matrix use one shared x coordinate system and are aligned with
`cowplot::align_plots`. Legends are extracted into a separate right-side column so they cannot
change the main panel width. `auto_width` and `auto_height` are enabled by default; set them to
false to use fixed `width` and `height` values.

`default_config.json` is the complete structured configuration. Pass its contents as the
`visual_config` object in `params.json` to override hierarchy linker/text styles, summary bars,
pie/donut geometry, dot styling, and layout. The supported `summary_plot_type` values are
`bar`, `stacked_bar`, `stacked_bar_100`, `grouped_bar`, `pie`, and `donut`.
