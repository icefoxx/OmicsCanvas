# Balloon Plot

This plugin is a **rewritten, robust, and highly customizable** version of the SCA `statBalloonplot.R` function. It plots a tile/balloon matrix where each cell is sized by its value, with optional row/column summary statistics on the margins.

The original SCA function had bugs (e.g. `scale_fill_identity()` with no fill aesthetic, and the gradient not wired to an aesthetic). This rewrite fixes those issues and exposes a full set of styling parameters.

## Runtime

```bash
Rscript plugins/balloon_plot/plot.R \
  --input plugins/balloon_plot/example_matrix.csv \
  --params plugins/balloon_plot/example_basic_params.json \
  --output /tmp/balloon_plot_basic_out
```

Every successful run writes:

- `result.svg`
- `result.pdf`
- `result.png`
- `figure.json`
- `run.log`
- `selected_rows.csv` (when row filtering or `highlight_rows` is applied)

On failure, an `error.json` with `{error, detail, suggestion}` is written instead, and stale `error.json` is removed on success.

## Input

A CSV/TSV/TXT matrix. The first column is the row id by default; remaining columns are sample/column numeric values.

```text
gene,S01,S02,S03,S04,S05,S06
TP53,3.2,4.1,2.8,3.9,4.5,3.1
BRCA1,2.1,1.8,2.5,2.9,1.4,2.2
EGFR,5.4,5.1,4.8,5.9,5.2,4.7
```

## Key Parameters (grouped)

### data
- `row_id_column` — column used as row id (default: first column).
- `rows_include`, `rows_exclude` — keep/remove row ids.
- `columns_include`, `columns_exclude` — keep/remove column/sample names.

### plot_mode
- `show_value` — show numeric value text inside each cell.
- `show_row_stats`, `show_col_stats` — show row/column summary on the margins.
- `stat_function` — `sum`, `mean`, `median`, `max`, `min`, `sd`, `var`.
- `use_gradient` — map tile fill to value via a gradient/colorbar.

### labels
- `title`, `subtitle`, `xlab`, `ylab`, and `*_show` toggles.

### typography
- `font_family`, `font_size`, `title_size`, `axis_label_size`, `x_axis_text_size`, `y_axis_text_size`, `x_axis_text_angle`, `value_text_size`, `stat_text_size`, `stat_text_color`.

### colors
- `fill_color` (tile background when not gradient), `border_color`, `balloon_color`, `text_color`, `stat_color`, `gradient_low`, `gradient_high`, `palette` (named RColorBrewer palette for the gradient).

### layers
- `balloon_alpha`, `balloon_min_size`, `balloon_max_size`, `tile_border_show`, `tile_border_color`, `tile_border_width`.

### annotations (selectors)
- `highlight_rows`, `highlight_columns`, `highlight_color`.

### legends
- `legend_show`, `legend_position`, `legend_name`, `legend_title_size`, `legend_text_size`, `legend_key_size`, `colorbar_width`, `colorbar_height`.

### output
- `width`, `height`, `dpi`.

## SCA Compatibility Note

This plugin **rewrites** `statBalloonplot.R` from the upstream SCA library (`R/plots/statBalloonplot.R`). The core visual concept (tile + balloon cells sized by value, with row/column summary stats on the margins) is preserved, but the implementation is rebuilt on ggplot2 with proper aesthetics:

- The gradient is correctly wired to the tile `fill` aesthetic via `scale_fill_gradient` / `scale_fill_distiller`.
- The buggy `scale_fill_identity()` (with no fill aesthetic) is removed.
- Row/column stats are placed at dedicated marginal factor levels so they align cleanly with the grid.
- Highlight rings, tile borders, value text, and full legend/typography controls are exposed.

The original SCA file is **not modified**.

## Examples

Run all examples:

```bash
plugins/balloon_plot/run_all_examples.sh <repo-root>
```

This writes `/tmp/balloon_plot_*_out` and updates:

```text
plugins/balloon_plot/all_examples_gallery/balloon_plot_gallery.png
```

Available example params:

- `example_basic_params.json` — fixed tile fill, value labels, row/col sum stats, highlighted rows.
- `example_gradient_params.json` — gradient tile fill, mean stats, highlighted column.
- `example_no_stats_params.json` — no value labels, no margin stats, row subset, bottom legend.
## Reproducible examples

Bundles are in `plugins/balloon_plot/examples/<id>/`. Each contains `params.json`, copied command inputs under `input/`, and `expected/result.png`. `manifest.json` is the machine-readable entry point and records how to rerun the example.

