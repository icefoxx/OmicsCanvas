# Quadrant Correlation Scatter

This plugin draws a highly customizable x/y scatter plot with quadrant or region colors, correlation text, threshold lines, selected point labels, and editable legends.

## Run

```bash
Rscript plugins/quadrant_correlation_scatter/plot.R \
  --input plugins/quadrant_correlation_scatter/example_input.csv \
  --params plugins/quadrant_correlation_scatter/example_params.json \
  --output /tmp/quadrant_correlation_scatter_out
```

## Key Params

- `x_column`, `y_column`: numeric columns for the scatter plot.
- `label_column`: ID/gene column used for selected labels.
- `quadrant_mode`: `nine`, `four`, or `custom`.
- `x_thresholds`, `y_thresholds`: threshold lines used to build 9 quadrants.
- `quadrant_colors`: named colors for quadrant groups.
- `selected_ids`: rows/dots to highlight and label.
- `selected_point_styles`: per-selected-point label position and indicator style.
- `regions`: optional custom region definitions with conditions or rectangular bounds.

Manual label example:

```json
{
  "selected_ids": ["Gene_001"],
  "selected_point_styles": [
    {
      "id": "Gene_001",
      "label_x": 2.5,
      "label_y": 4,
      "label_color": "#7B1FA2",
      "indicator_color": "#7B1FA2",
      "indicator_type": "dashed",
      "indicator_width": 0.6
    }
  ]
}
```
## Reproducible examples

Bundles are in `plugins/quadrant_correlation_scatter/examples/<id>/`. Each contains `params.json`, copied command inputs under `input/`, and `expected/result.png`. `manifest.json` is the machine-readable entry point and records how to rerun the example.

