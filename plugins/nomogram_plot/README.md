# Nomogram Scales

Display supplied predictor point scales and total-point outcome mappings.

## Input

Supplied scale name, normalized tick position in [0,1] and display label. Predictor-to-point and outcome mappings must be derived upstream from a fitted model.

## Main parameters

- `group_column`: Group column.
- `position_column`: Position column. Normalized position from 0 to 1 on the supplied scale.
- `label_column`: Label column.
- `line_color`: Line color.
- `label_show`: Label show.
- `label_size`: Label size.
- `title`: Title.
- `subtitle`: Subtitle. Empty uses the automatic description.
- `caption`: Caption.
- `title_size`: Title size. Only when a nonempty title is supplied.
- `line_width`: Line width.
- `font_family`: Font family.
- `base_size`: Base size.
- `plot_background`: Plot background.
- `width`: Width. Inches.
- `height`: Height. Inches.
- `dpi`: Dpi.

## Interpretation

- The plugin draws supplied scales and does not fit, validate or calibrate a prediction model.
- Normalized positions are layout coordinates. Patient risk cannot be calculated from an arbitrary scale drawing.

## Run

```bash
Rscript plugins/nomogram_plot/plot.R \
  --input plugins/nomogram_plot/examples/basic/input/data.csv \
  --params plugins/nomogram_plot/examples/basic/params.json \
  --output /tmp/nomogram_plot_out
```

Optional uploads are listed in `config.yaml`; each uses its input ID as a CLI flag.
The example manifests include input mappings and parameters and input mappings.

Outputs: SVG/PDF/PNG, figure metadata, run log, data used and documented diagnostic
CSV tables. The 3D embedding engine additionally writes an interactive HTML scene.
Errors write `error.json` and remove partial figure files.

## Examples

- `basic`: Supplied predictor point scales.
- `compact`: Supplied total-point outcome mapping.

All examples are independently generated synthetic data. Installed dependencies are
ggplot2, jsonlite, optparse, ragg and svglite; mode-specific rendering uses existing
survival, patchwork, ggrepel, plotly/htmlwidgets and png packages. No package is
installed automatically.
