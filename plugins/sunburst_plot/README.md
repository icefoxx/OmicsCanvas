# Sunburst Plot

Hierarchical category shares as concentric rings. The inner ring is the parent category; outer rings split each parent.

## Input

A table with `level1_column`, `level2_column` (optional `level3_column`) and `value_column`. Values must be non-negative.

## Main parameters

| Group | Parameters |
|---|---|
| Data | `level1_column`, `level2_column`, `level3_column`, `value_column` |
| Marks | `inner_radius`, `label_show`, `label_min_share`, `border_width` |
| Colours | `palette` |
| Export | `width`, `height`, `dpi` |

## Run

```bash
Rscript plugins/sunburst_plot/plot.R \
  --input plugins/sunburst_plot/examples/basic/input/example_input.csv \
  --params plugins/sunburst_plot/examples/basic/params.json \
  --output /tmp/sunburst_plot_out
```
