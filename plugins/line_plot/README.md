# Line Plot

Multi-series lines with optional points, error bars, a loess smooth, and a second y axis.

## Input

One table. Map `x_column`, `y_column`, optional `group_column`, `se_column`, and `y2_column`. X may be numeric or an ordered category.

## Main parameters

| Group | Parameters |
|---|---|
| Data | `x_column`, `y_column`, `group_column`, `se_column`, `y2_column` |
| Marks | `line_width`, `point_show`, `point_size`, `error_show`, `smooth_show` |
| Export | `width`, `height`, `dpi` |

`error_show` draws bars only when `se_column` is numeric. `smooth_show` fits loess only when x is numeric. Empty `y2_column` turns the secondary axis off.

## Run

```bash
Rscript plugins/line_plot/plot.R \
  --input plugins/line_plot/examples/basic/input/example_input.csv \
  --params plugins/line_plot/examples/basic/params.json \
  --output /tmp/line_plot_out
```


Enable the supplied interval band to display numeric lower and upper bounds containing each y value. Intervals are supplied by the analysis; no confidence or credible interval is inferred. Band opacity and bound-column mappings apply only when the band is enabled.


Enable the supplied interval band to display numeric lower and upper bounds containing each y value. Intervals are supplied by the analysis; no confidence or credible interval is inferred. Band opacity and bound-column mappings apply only when the band is enabled.
