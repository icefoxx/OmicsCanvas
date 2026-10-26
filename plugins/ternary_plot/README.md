# Ternary Plot

Three-part compositions on a simplex, with optional grouping and size mapping.

Rows are rescaled so A + B + C = 1. Negative values are clipped to 0; zero-sum rows are dropped.

## Input

Map `a_column`, `b_column`, `c_column`, optional `group_column` and `size_column`.

## Main parameters

| Group | Parameters |
|---|---|
| Data | `a_column`, `b_column`, `c_column`, `group_column`, `size_column` |
| Marks | `point_size`, `point_alpha`, `grid_show`, `vertex_label_size` |
| Labels | `a_label`, `b_label`, `c_label` |
| Export | `width`, `height`, `dpi` |

## Run

```bash
Rscript plugins/ternary_plot/plot.R \
  --input plugins/ternary_plot/examples/basic/input/example_input.csv \
  --params plugins/ternary_plot/examples/basic/params.json \
  --output /tmp/ternary_plot_out
```
