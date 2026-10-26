# Circular Bar Plot

Radial or polar bars for ranked categories. Stacks optional groups around a polar axis.

## Input

One table. Map `category_column`, `value_column`, and optional `group_column`.

## Main parameters

| Group | Parameters |
|---|---|
| Data | `category_column`, `value_column`, `group_column`, `category_order`, `group_order` |
| Marks | `plot_type` (stacked / single), `inner_radius`, `bar_width`, `label_show` |
| Colours | `palette`, `group_colors` |
| Export | `width`, `height`, `dpi` |

## Run

```bash
Rscript plugins/circular_bar_plot/plot.R \
  --input plugins/circular_bar_plot/examples/basic/input/example_input.csv \
  --params plugins/circular_bar_plot/examples/basic/params.json \
  --output /tmp/circular_bar_plot_out
```
