# Interactive Dual-Triangle Heatmap

This plugin combines two square matrices in one plot: the upper triangle is
drawn from the upper input (Jaccard similarity by default), while the lower
triangle is drawn from the lower input (Pearson correlation by default). The
two matrices are validated and retained separately, so they do not share a
scale or values accidentally.

## CLI

```sh
Rscript plugins/interactive_dual_triangle_heatmap_plot/plot.R \
  --upper upper.csv --lower lower.csv --params params.json --output output_dir
```

`--input` is accepted as an alias for upper and `lower_input` can be supplied
in params. Add `--annotation annotation.csv` or `annotation_file` for an ID
column plus categorical dataset/group columns. `allow_reorder` permits matching
feature labels in different orders.

The three top-level example parameter files demonstrate basic, screenshot-like
custom, and interactive configurations. Each example bundle contains both
matrices and its annotation input.

Outputs include static SVG/PDF/PNG, Plotly HTML, `figure.json`, run log, both
matrix snapshots, and row/column order files. Failures produce `error.json`.
