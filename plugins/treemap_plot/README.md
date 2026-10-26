# Treemap Plot

Hierarchical category shares as nested rectangles (slice-and-dice layout). Parent tiles split into children when `level2_column` is mapped.

## Input

A table with `level1_column`, optional `level2_column`, and `value_column`. Values must be non-negative.

## Main parameters

| Group | Parameters |
|---|---|
| Data | `level1_column`, `level2_column`, `value_column` |
| Marks | `label_show`, `border_width`, `parent_border_width` |
| Colours | `palette`, `border_color` |
| Export | `width`, `height`, `dpi` |

## Run

```bash
Rscript plugins/treemap_plot/plot.R \
  --input plugins/treemap_plot/examples/basic/input/example_input.csv \
  --params plugins/treemap_plot/examples/basic/params.json \
  --output /tmp/treemap_plot_out
```
