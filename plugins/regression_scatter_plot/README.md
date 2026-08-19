# Regression Scatter Plot

Multi-group scatter with per-group **linear** or **loess** regression, confidence band, and ChiPlot-style **formula / R² / P** annotations.

## Check first

- Simple correlation / quadrant scatter → `quadrant_correlation_scatter`
- This plugin → multi-group regression lines + stats text (image style)

## Input

| id | x | y | group |
|----|---|---|-------|
| A1 | 1.2 | 2.3 | A |
| B1 | 3.4 | 1.8 | B |

## Key params

| Param | Meaning |
|-------|---------|
| `regression_method` | `lm` or `loess` |
| `ci_show` | confidence band |
| `formula_show` / `r2_show` / `p_show` | annotation toggles |
| `group_colors` | named group → hex |
| `point_size` | ChiPlot-style size (~40) |
| `stroke_as_fill` | no point outline |

## Run

```bash
Rscript plugins/regression_scatter_plot/plot.R \
  --input plugins/regression_scatter_plot/example_input.csv \
  --params plugins/regression_scatter_plot/example_chiplot_params.json \
  --output /tmp/regression_scatter_out
```

## Outputs

`result.svg/pdf/png`, `figure.json`, `run.log`, `selected_rows.csv`, `regression_stats.csv`
