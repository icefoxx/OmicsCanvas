# Circular Heatmap

Matrix values drawn as tiles around a polar axis. Rows become concentric rings; columns sit around the circle.

## Input

One long table. Map `row_column` (features / rings), `column_column` (samples / angle), and `value_column`. Duplicate row–column pairs are averaged.

## Main parameters

| Group | Parameters |
|---|---|
| Data | `row_column`, `column_column`, `value_column`, `row_order`, `column_order` |
| Marks | `cluster_rows`, `cluster_columns`, `inner_radius`, `border_width`, `label_show` |
| Colours | `palette`, `na_color` |
| Labels / legend | `title`, `subtitle`, `legend_*` |
| Export | `width`, `height` (inches), `dpi` |

Full list with defaults: `params_schema.json`.

## Run

```bash
Rscript plugins/circular_heatmap/plot.R \
  --input plugins/circular_heatmap/examples/basic/input/example_input.csv \
  --params plugins/circular_heatmap/examples/basic/params.json \
  --output /tmp/circular_heatmap_out
```

Outputs: `result.svg`, `result.pdf`, `result.png`, `figure.json`, `run.log`, `data_used.csv`;
`error.json` on failure.


Choose categorical values for concentric sample annotation rings. Categorical cells must be unique; numeric clustering is unavailable. Named category colors apply only to categorical mode.
