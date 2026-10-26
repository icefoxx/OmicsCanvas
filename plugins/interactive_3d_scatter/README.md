# 3D Embedding

View supplied three-dimensional coordinates with an interactive scene and vector projection.

## Input

Three finite numeric coordinate columns and optional categorical group; up to 50,000 observations. Coordinates are consumed as supplied, without fitting PCA.

## Main parameters

- `x_column`: X column.
- `y_column`: Y column.
- `z_column`: Z column.
- `group_column`: Group column.
- `azimuth`: Azimuth.
- `elevation`: Elevation.
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

- A projection can conceal overlap; rotate the HTML view and compare complementary quantitative analyses.
- The static export uses an orthographic projection; PCA/t-SNE/UMAP fitting is performed upstream.

## Run

```bash
Rscript plugins/interactive_3d_scatter/plot.R \
  --input plugins/interactive_3d_scatter/examples/basic/input/data.csv \
  --params plugins/interactive_3d_scatter/examples/basic/params.json \
  --output /tmp/interactive_3d_scatter_out
```

Optional uploads are listed in `config.yaml`; each uses its input ID as a CLI flag.
The example manifests include input mappings and parameters and input mappings.

Outputs: SVG/PDF/PNG, figure metadata, run log, data used and documented diagnostic
CSV tables. The 3D embedding engine additionally writes an interactive HTML scene.
Errors write `error.json` and remove partial figure files.

## Examples

- `basic`: Three-dimensional sample coordinates.
- `alternate_view`: Alternate viewing angle.

All examples are independently generated synthetic data. Installed dependencies are
ggplot2, jsonlite, optparse, ragg and svglite; mode-specific rendering uses existing
survival, patchwork, ggrepel, plotly/htmlwidgets and png packages. No package is
installed automatically.
