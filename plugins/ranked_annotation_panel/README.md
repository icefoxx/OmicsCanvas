# Ranked Annotation Panel

This plugin draws a ranked dot/value panel on the left and a user-selected annotation heatmap panel on the right.

It is useful for plots where rows are genes, metabolites, peaks, pathways, or features; the left panel shows one selected numeric score; and the right panel shows several selected metadata/annotation columns.

## Run

```bash
Rscript plugins/ranked_annotation_panel/plot.R \
  --input plugins/ranked_annotation_panel/example_input.csv \
  --params plugins/ranked_annotation_panel/example_params.json \
  --output /tmp/ranked_annotation_panel_out
```

## Main Params

- `row_label_column`: row labels shown on the plot.
- `left_value_column`: numeric value shown in the left panel.
- `annotation_columns`: columns shown in the right annotation panel.
- `rows_include` / `rows_exclude`: table-driven row selection, default all rows.
- `annotation_settings`: per-column continuous/discrete settings.

Example annotation settings:

```json
{
  "annotation_settings": {
    "L13": {
      "type": "continuous",
      "colors": ["#008B5A", "#FFFFBF", "#B2182B"],
      "low_label": "Low",
      "high_label": "High"
    },
    "Group": {
      "type": "discrete",
      "colors": {
        "A": "#1B9E77",
        "B": "#D95F02",
        "C": "#7570B3"
      }
    }
  }
}
```

Successful runs write `result.svg`, `result.pdf`, `result.png`, `figure.json`, `selected_rows.csv`, and `run.log`.
## Reproducible examples

Bundles are in `plugins/ranked_annotation_panel/examples/<id>/`. Each contains `params.json`, copied command inputs under `input/`, and `expected/result.png`. `manifest.json` is the machine-readable entry point and records how to rerun the example.

