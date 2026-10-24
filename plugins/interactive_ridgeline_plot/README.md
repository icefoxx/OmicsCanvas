# Interactive Ridgeline Plot

Stacked density ridges (joyplot / CAB_demo ridge). **Do not add a second ridgeline plugin** — extend this one.

Run:

```bash
# CAB_demo-style ridges
Rscript plugins/interactive_ridgeline_plot/plot.R \
  --input plugins/interactive_ridgeline_plot/example_CAB_demo_input.csv \
  --params plugins/interactive_ridgeline_plot/example_CAB_demo_params.json \
  --output /tmp/ridgeline_CAB_demo_out

# Basic
Rscript plugins/interactive_ridgeline_plot/plot.R \
  --input plugins/interactive_ridgeline_plot/example_input.csv \
  --params plugins/interactive_ridgeline_plot/example_basic_params.json \
  --output /tmp/ridgeline_basic_out

# Grouped OSD/MS overlay with supplied statistics
Rscript plugins/interactive_ridgeline_plot/plot.R \
  --input plugins/interactive_ridgeline_plot/example_grouped_input.csv \
  --params plugins/interactive_ridgeline_plot/example_grouped_params.json \
  --output /tmp/ridgeline_grouped_out
```

CAB_demo aliases: `fill_opacity`, `stroke_as_fill`, `sample_count`, `point_switch` / `r`, quantile 50% via `quantile_line_show`.

The plugin accepts wide data (`sample,Feature A,Feature B,...`) and long data (`feature,value,group`, with optional `sample`). In auto mode, a long table is recognized from feature/value aliases. Explicit `input_mode` and column parameters are recommended for pipelines.

Grouped overlays default to `group_overlay=true`; use `fill_mode="group"` (or the legacy `cloud_fill_mode`) for one shared x scale and one fill per group. Group defaults are `group_alpha=0.75`, `group_outline_show=false`, `group_legend_show=true`, `group_legend_title="Group"`, and `group_legend_position="right"`. Baselines default to `baseline_show=true`, `baseline_color="#777777"`, `baseline_width=0.35`, and `baseline_linetype="solid"`; `row_spacing=1`, `ridge_height=0.82`, and `ridge_overlap=0.15` preserve the existing geometry defaults.

Statistics default to `statistic_show=false`, `statistic_method="none"`, `statistic_columns=["d","p"]`, `statistic_position="right"`, `statistic_size=3.5`, `statistic_color="#333333"`, and `statistic_digits=3`. `cohen_d`, `t_test`, and `wilcoxon` compare the first two groups with safe NA/single-group handling. For `supplied`, long input must contain one or more statistic columns per observation (for example `d,p`); `statistic_columns` may be an object such as `{ "d": "effect_size", "p": "p_value" }`, and values are taken from the first non-NA row for each feature. `statistic_labels` accepts matching label objects.

`cloud_*` controls the filled KDE cloud, bandwidth, trimming, overlap, baseline, outline, scale, alpha, and feature/group coloring. `point_*` controls raw points, deterministic jitter, sampling, shape, color, and placement. `box_*`, `median_*`, and `quantile_*` control summary overlays. Layout, axes, title, typography, backgrounds, labels, highlights, legend, and interaction controls are exposed in `params_schema.json`.

The computed `distribution_data_used.csv` is the exact normalized data used for the plot. If row or feature filtering is requested, `selected_rows.csv` is also written. `figure.json` describes the effective feature order and shared x limits. A successful run removes a stale `error.json`; failures write `{error, detail, suggestion}` to `error.json`.

To reproduce all supplied examples and create copied-input manifests:

```bash
plugins/interactive_ridgeline_plot/run_all_examples.sh <repo-root>
```
