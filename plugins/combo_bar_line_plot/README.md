# Combo Bar + Line Plot

Dual-axis combination chart: multi-colored categorical bars on the **primary Y** axis with an optional connected **line + points** on a **secondary Y** axis (CAB_demo-style).

## Check before adding similar plots

This plugin already covers:

- vertical bar chart (single series, multi-color)
- bar + line dual-axis overlay
- bar only / line only toggles

Do **not** add a separate plugin for “bar with secondary line” — extend this one.

## Input

### Wide (recommended)

| sample | bar_value | line_value |
|--------|-----------|------------|
| PT30_11 | 1.4 | 88 |

### Long

| sample | metric | value |
|--------|--------|-------|
| PT30_11 | count | 1.4 |
| PT30_11 | percent | 88 |

Set `input_mode: "long"`, `metric_column`, `bar_metric`, `line_metric`.

## Key parameters

| Param | Meaning |
|-------|---------|
| `bar_column` / `line_column` | Primary / secondary numeric series |
| `dual_axis` | Map line onto secondary Y (`sec_axis`) |
| `bar_color_mode` | `by_sample` (default), `single`, `by_group` |
| `bar_colors` / `category_colors` | Named sample → hex map |
| `line_color`, `line_width`, `line_type` | Line style |
| `show_line_points`, `line_point_size` | Point markers on the line |
| `y_min` / `y_max` | Primary axis limits |
| `y2_min` / `y2_max` | Secondary axis limits |
| Full axis / title / legend / export | Same CAB_demo-style surface as other plugins |

See `params_schema.json` for the complete control list.

## Run

```bash
Rscript plugins/combo_bar_line_plot/plot.R \
  --input plugins/combo_bar_line_plot/example_input.csv \
  --params plugins/combo_bar_line_plot/example_CAB_demo_params.json \
  --output /tmp/combo_bar_line_out
```

## Outputs

`result.svg`, `result.pdf`, `result.png`, `figure.json`, `run.log`, `selected_rows.csv`, `matrix_used.csv`
