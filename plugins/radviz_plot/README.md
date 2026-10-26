# Wheel / RadViz

Project nonnegative feature weights toward labeled vertices of a wheel.

## Input

3–12 numeric feature columns in desired vertex order, plus optional group. Row-sum mode requires nonnegative weights. Zero-total rows are reported and omitted.

## Main parameters

- `feature_columns`: Feature columns. 3–12 numeric features, in wheel vertex order.
- `group_column`: Group column.
- `normalization`: Normalization.
- `spoke_show`: Spoke show.
- `point_alpha`: Point alpha.
- `point_size`: Point size.
- `line_width`: Line width.
- `label_size`: Label size.
- `title`: Title.
- `subtitle`: Subtitle. Empty uses the automatic description.
- `caption`: Caption.
- `title_size`: Title size. Only when a nonempty title is supplied.
- `palette`: Palette.
- `group_colors`: Named colors. Named categorical colors override the palette.
- `legend_show`: Legend show.
- `legend_position`: Legend position.
- `legend_text_size`: Legend text size.
- `font_family`: Font family.
- `base_size`: Base size.
- `plot_background`: Plot background.
- `width`: Width. Inches.
- `height`: Height. Inches.
- `dpi`: Dpi.

## Interpretation

- Vertex order and normalization affect the projection; record both. Nearby observations need not have identical profiles.
- Negative feature values require explicit feature-minmax normalization; no trajectory is inferred.

## Run

```bash
Rscript plugins/radviz_plot/plot.R \
  --input plugins/radviz_plot/examples/basic/input/data.csv \
  --params plugins/radviz_plot/examples/basic/params.json \
  --output /tmp/radviz_plot_out
```

Optional uploads are listed in `config.yaml`; each uses its input ID as a CLI flag.
The example manifests include input mappings and parameters and input mappings.

Outputs: SVG/PDF/PNG, figure metadata, run log, data used and documented diagnostic
CSV tables. The 3D embedding engine additionally writes an interactive HTML scene.
Errors write `error.json` and remove partial figure files.

## Examples

- `basic`: Feature-weight wheel.
- `minmax`: Feature-scaled wheel.

All examples are independently generated synthetic data. Installed dependencies are
ggplot2, jsonlite, optparse, ragg and svglite; mode-specific rendering uses existing
survival, patchwork, ggrepel, plotly/htmlwidgets and png packages. No package is
installed automatically.
