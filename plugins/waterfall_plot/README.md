# Waterfall Plot

Cumulative signed bars that show how sequential contributions add to a total.

## Input

One table with a step label column (`category_column`) and a signed numeric value column (`value_column`). Positive values increase the running total; negative values decrease it.

## Main parameters

| Group | Parameters |
|---|---|
| Data | `category_column`, `value_column`, `category_order` |
| Marks | `total_show`, `connector_show`, `bar_width`, `label_show`, `total_label` |
| Colours | `increase_color`, `decrease_color`, `total_color` |
| Export | `width`, `height`, `dpi` |

## Run

```bash
Rscript plugins/waterfall_plot/plot.R \
  --input plugins/waterfall_plot/examples/basic/input/example_input.csv \
  --params plugins/waterfall_plot/examples/basic/params.json \
  --output /tmp/waterfall_plot_out
```
