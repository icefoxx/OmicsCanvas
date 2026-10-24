# Interactive Binary Plot

Run with:

```bash
Rscript plot.R --input example_input.csv --params example_basic_params.json --output /tmp/binary_plot_out
```

The default input is a wide CSV/TSV/TXT table. The first column contains row or group labels and every remaining selected column is a binary feature. `0`, `FALSE`, `F`, `NO`, and `N` mean absence; `1`, `TRUE`, `T`, `YES`, and `Y` mean presence. Numeric values use `value_threshold` (default `0.5`). Missing values can be shown as grey circles. Long input is also supported with `input_mode: long`, `row_column`, `column_column`, and `value_column`.

`params_schema.json` documents the data filters, ordering, symbols, group palettes, labels, highlights, legends, interaction controls, and export dimensions. Parameters may be supplied flat or under their schema group. Common aliases such as `columns_include`, `columns_exclude`, `group_col`, and `row_id` are accepted.

Static output is written as SVG, PDF, and PNG. HTML uses Plotly when installed and includes hover metadata, zoom/pan, legend toggles, and selection tools. `binary_matrix_used.csv` is the normalized long matrix; highlighted cells are written to `selected_cells.csv`.

Reproduce all examples and portable bundles with:

```bash
plugins/interactive_binary_plot/run_all_examples.sh <repo-root>
```
