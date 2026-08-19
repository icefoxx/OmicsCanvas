# Interactive Histogram Plot

Grouped overlay histograms with shared, explicitly precomputed bins. Bars are narrow, translucent, and dark outlined so static ggplot2 output and Plotly HTML use the same counts. This is an overlay histogram, not a violin or ridgeline plot.

Wide input is `sample,Oct4,Oct4_3A_Oct4_5A`; the first column is an optional id when non-numeric and remaining numeric columns are groups. Long input uses `value_column` and `group_column`, with optional `id_column`, for example `sample,value,group`. `input_mode: auto` detects long data from configured or conventional value/group columns.

Defaults are 40 fixed shared bins, `stat: count`, `position: identity`, alpha 0.55, dark outlines, count y-axis, bottom legend, light grid, 10 x 6 inch canvas, 300 dpi, and interactive Plotly HTML enabled. Binning, group filtering/order, colors, axes, legend, and Plotly controls are documented in `params_schema.json`.

```bash
Rscript plugins/interactive_histogram_plot/plot.R --input plugins/interactive_histogram_plot/example_input.csv --params plugins/interactive_histogram_plot/example_basic_params.json --output /tmp/histogram_out
plugins/interactive_histogram_plot/run_all_examples.sh /Users/qzhang10/Documents/OmicsCanvas
```

Outputs are `result.svg`, `result.pdf`, `result.png`, `result.html`, `figure.json`, `run.log`, `histogram_data_used.csv`, and `selected_rows.csv`. Missing and non-numeric values are dropped and logged. Failures remove stale outputs and write `error.json`.
