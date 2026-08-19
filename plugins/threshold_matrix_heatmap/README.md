# Threshold Matrix Heatmap

This plugin draws a table-based heatmap like a GO/enrichment significance matrix. Users can choose which rows and columns to show, which column supplies row labels, and how each value column maps values to cell colors.

## Run

```bash
Rscript plugins/threshold_matrix_heatmap/plot.R \
  --input plugins/threshold_matrix_heatmap/example_input.csv \
  --params plugins/threshold_matrix_heatmap/example_params.json \
  --output /tmp/threshold_matrix_heatmap_out
```

## Important Params

- `row_label_column`: column used as row labels.
- `value_columns`: columns shown in the heatmap. Defaults to all numeric columns except the row label column.
- `rows_include` / `rows_exclude`: table-driven row selection. Defaults to all rows.
- `columns_exclude`: hide selected columns.
- `default_rules`: semicolon-separated cutoff rules used for all value columns.
- `column_rules_string`: per-column rule overrides.
- `cell_shape`: `tile`, `circle`, `diamond`, or `triangle`.

Rule syntax:

```text
<0.01=#F97316|strong sig;<0.05=#C6FF1A|sig;else=#C9C9C9|non-sig;missing=#FFFFFF|none
```

Per-column rules:

```text
CK-vs-M1:<0.01=#F97316|strong,<0.05=#C6FF1A|sig,else=#C9C9C9|non-sig;M1-vs-M2:<0.05=#00A087|sig,else=#C9C9C9|non-sig
```

Successful runs write `result.svg`, `result.pdf`, `result.png`, `figure.json`, `selected_rows.csv`, and `run.log`.
## Reproducible examples

Bundles are in `plugins/threshold_matrix_heatmap/examples/<id>/`. Each contains `params.json`, copied command inputs under `input/`, and `expected/result.png`. `manifest.json` is the machine-readable entry point and records how to rerun the example.

