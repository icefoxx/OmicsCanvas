# Embedding Vector Field

Overlay supplied displacement vectors on an embedding without inferring velocities.

## Input

Finite numeric x/y coordinates, supplied vx/vy vectors in compatible coordinate units, and optional group.

## Main parameters

- `x_column`: X column.
- `y_column`: Y column.
- `vx_column`: Vx column.
- `vy_column`: Vy column.
- `group_column`: Group column.
- `vector_scale`: Vector scale.
- `arrow_stride`: Arrow stride.
- `arrow_alpha`: Arrow alpha.
- `arrow_length`: Arrow length.
- `point_alpha`: Point alpha.
- `point_size`: Point size.
- `line_width`: Line width.
- `palette`: Palette.
- `group_colors`: Named colors. Named categorical colors override the palette.
- `title`: Title.
- `subtitle`: Subtitle. Empty uses the automatic description.
- `caption`: Caption.
- `title_size`: Title size. Only when a nonempty title is supplied.
- `legend_show`: Legend show.
- `legend_position`: Legend position.
- `legend_text_size`: Legend text size.
- `font_family`: Font family.
- `base_size`: Base size.
- `plot_background`: Plot background.
- `grid_show`: Grid show.
- `width`: Width. Inches.
- `height`: Height. Inches.
- `dpi`: Dpi.

## Interpretation

- The plugin does not compute RNA velocity or a kinetic model. Supply vector coordinates compatible with the embedding.
- Arrow thinning uses a deterministic row stride and does not estimate a spatial average or streamline.

## Run

```bash
Rscript plugins/embedding_vector_plot/plot.R \
  --input plugins/embedding_vector_plot/examples/basic/input/data.csv \
  --params plugins/embedding_vector_plot/examples/basic/params.json \
  --output /tmp/embedding_vector_plot_out
```

Optional uploads are listed in `config.yaml`; each uses its input ID as a CLI flag.
The example manifests include input mappings and parameters and input mappings.

Outputs: SVG/PDF/PNG, figure metadata, run log, data used and documented diagnostic
CSV tables. The 3D embedding engine additionally writes an interactive HTML scene.
Errors write `error.json` and remove partial figure files.

## Examples

- `basic`: Supplied vector field.
- `radial`: Supplied outward displacement field.

All examples are independently generated synthetic data. Installed dependencies are
ggplot2, jsonlite, optparse, ragg and svglite; mode-specific rendering uses existing
survival, patchwork, ggrepel, plotly/htmlwidgets and png packages. No package is
installed automatically.
