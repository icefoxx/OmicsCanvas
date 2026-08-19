# Interactive Violin / Box / Point Plot

A highly-customizable vertical distribution plot combining a filled violin "cloud",
a box / quartile summary, and jittered raw points — exported as static SVG/PDF/PNG
plus an interactive Plotly HTML widget with the same data and ordering.

## Run

```bash
Rscript plugins/interactive_violin_plot/plot.R \
  --input  plugins/interactive_violin_plot/example_input.csv \
  --params plugins/interactive_violin_plot/example_basic_params.json \
  --output /tmp/violin_basic_out
```

## Input format

**Wide** (default): first column is the row id, remaining columns are numeric features
(one violin per feature). A `group_column` may add group membership per row.

```csv
sample,Feature A,Feature B,Feature C,Feature D
S001,-2.35,-1.10,0.20,1.85
S002,-2.10,-0.95,0.35,1.62
```

**Long**: a feature/category column, a value column, and optional id and group columns.
Use `input_mode: "long"` plus `feature_column` / `value_column` (aliases `feature`,
`variable`, `value`, `score`, etc. are auto-detected).

```csv
sample,feature,value,group
S001,Feature A,-2.35,Treated
S001,Feature B,-1.10,Control
```

`input_mode` may be `auto` (default: a table is treated as long when both a feature and a
value column are detectable in the header, else wide), `wide`, or `long`. TSV/TXT are
supported by extension. Rows with non-finite values are dropped with a note in `run.log`.

A long-format showcase file is provided as `example_input_long.csv`.

## Parameters

Every parameter is optional. Grouped by purpose (see `params_schema.json` for the full
list with types/defaults):

| Group | Key parameters (default) |
| --- | --- |
| **data** | `input_mode` (auto), `id_column`, `feature_column`, `value_column`, `group_column`, `group_mode` (facet/grouped), `facet_scales` (free_y), `features_include`, `features_exclude`, `rows_include`, `rows_exclude`, `feature_order`, `reverse_features`, `top_n`, `sort_features` (false), `sort_by` (variance) |
| **canvas/layout** | `width` (10), `height` (6), `aspect_ratio`, `dpi` (300), `flip` (false, horizontal orientation) |
| **cloud** | `cloud_show` (true), `cloud_stat` (density/count), `cloud_bandwidth`, `cloud_adjust` (1), `cloud_trim`, `cloud_fill_mode` (feature/group), `cloud_color`, `cloud_colors`, `cloud_alpha` (0.7), `cloud_width` (0.9), `cloud_stroke`, `cloud_stroke_width`, `cloud_outline_show` (true) |
| **box** | `box_show` (true), `box_width` (0.22), `box_fill` (#FFFFFF), `box_alpha` (0.8), `box_stroke`, `box_stroke_width`, `box_outlier_show` (false), `box_outlier_size/alpha/color` |
| **median/quantile** | `median_show` (true), `median_color` (#111111), `median_width` (0.3), `median_linetype`; `quantile_show` (false), `quantile_width` (0.8), `quantile_color`, `quantile_linetype` (dashed), `quantile_alpha` |
| **points** | `point_show` (true), `point_data` (all/density_sample), `point_density_sample` (100), `point_color` (#333333), `point_colors`, `point_size` (1.2), `point_alpha` (0.6), `point_shape` (16), `point_stroke`, `point_jitter_width` (0.35), `point_jitter_seed` (42), `point_position` (within/split) |
| **axes** | `xlab` (Feature), `ylab` (Value), `title`, `subtitle`, `caption`, `title_show`, `title_size/color/face/hjust`, `subtitle_size/color/face`, `x_axis_show`, `x_axis_text_size/color/angle`, `y_axis_show`, `y_axis_text_size/color`, `y_limits`, `y_breaks`, `x_limits`, `x_breaks`, `axis_line_show/color/width`, `tick_show/color/width`, `grid_show`, `grid_minor_show`, `grid_color/width/linetype`, `panel_border_show/color/width` |
| **labels/highlights** | `feature_label_show` (true), `feature_label_size/color/face/angle`, `highlight_features`, `highlight_color` (#FFD166), `highlight_alpha` (0.15) |
| **legend/theme** | `legend_show` (true), `legend_position` (right), `legend_title`, `legend_text_size`, `legend_title_size`, `legend_key_size`, `legend_ncol`, `palette`, `font_family` (sans), `base_size` (11), `panel_background` (#FFFFFF), `plot_background` (#FFFFFF) |
| **interaction** | `interactive` (true), `tooltip_columns`, `hover_template`, `selectable`, `lasso_select`, `zoom`, `pan`, `reset_view` |
| **output** | `export_formats` (svg/pdf/png/html) |

`sort_by` ranks features descending (variance/mean/median) or ascending (alphabetical).
`top_n` keeps the top-N features by variance. `feature_order` overrides all sorting.

## Output files

- `result.svg`, `result.pdf`, `result.png` — static renders.
- `result.html` — interactive Plotly widget (self-contained; falls back to a
  non-self-contained copy with dependencies alongside if inlining fails).
- `figure.json` — summary: features, groups, layer flags, `n_points_plotted`,
  `n_rows_filtered`, and per-feature mean/median/sd/iqr.
- `distribution_data_used.csv` — long melted data actually plotted (id, feature, group, value).
- `selected_rows.csv` — input rows after include/exclude filters (original format).
- `run.log` — step log. Failures write `error.json` (with detail + traceback) and exit non-zero.

## Customization tips

- **Classic violin**: `cloud_show=true, box_show=true, point_show=true`.
- **Cloud only**: `box_show=false, point_show=false`.
- **Grouped across groups**: long input + `group_column` + `group_mode:"grouped"` and
  `point_position:"split"`; **faceted by group**: `group_mode:"facet"` (default).
- **Horizontal**: set `flip: true`.
- **Per-feature emphasis**: `highlight_features` adds a full-height band behind a feature.
- **Lighter HTML**: `interactive:false` writes a placeholder instead of requiring Plotly.

To reproduce all bundled examples and build the gallery:

```bash
plugins/interactive_violin_plot/run_all_examples.sh /Users/qzhang10/Documents/OmicsCanvas
```
