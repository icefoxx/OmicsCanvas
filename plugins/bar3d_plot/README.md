# 3D Bar / Lego

Display a supplied two-dimensional grid of counts as projected three-dimensional bars.

## Input

One nonnegative count per X/Y/group grid cell. X and Y are supplied categorical grid positions. Limit each axis to 15 positions.

## Main parameters

- `x_column`: X column.
- `y_column`: Y column.
- `value_column`: Value column.
- `group_column`: Group column.
- `azimuth`: Azimuth.
- `elevation`: Elevation.
- `z_scale`: Z scale.
- `ncol`: Ncol.
- `bar_width`: Bar width.
- `line_width`: Line width.
- `label_size`: Label size.
- `title`: Title.
- `subtitle`: Subtitle. Empty uses the automatic description.
- `caption`: Caption.
- `title_size`: Title size. Only when a nonempty title is supplied.
- `palette`: Palette.
- `group_colors`: Named colors. Named categorical colors override the palette.
- `font_family`: Font family.
- `base_size`: Base size.
- `plot_background`: Plot background.
- `width`: Width. Inches.
- `height`: Height. Inches.
- `dpi`: Dpi.

## Interpretation

- Perspective obscures some bars. A heatmap or ordinary bar plot may support more accurate comparisons.
- Free panel height scaling is explicit and prevents direct height comparisons between panels.

## Run

```bash
Rscript plugins/bar3d_plot/plot.R \
  --input plugins/bar3d_plot/examples/basic/input/data.csv \
  --params plugins/bar3d_plot/examples/basic/params.json \
  --output /tmp/bar3d_plot_out
```

Optional uploads are listed in `config.yaml`; each uses its input ID as a CLI flag.
The example manifests include input mappings and parameters and input mappings.

Outputs: SVG/PDF/PNG, figure metadata, run log, data used and documented diagnostic
CSV tables. The 3D embedding engine additionally writes an interactive HTML scene.
Errors write `error.json` and remove partial figure files.

## Examples

- `basic`: Mutation-context count grid.
- `free_scale`: Grid heights with independent panel scales.

All examples are independently generated synthetic data. Installed dependencies are
ggplot2, jsonlite, optparse, ragg and svglite; mode-specific rendering uses existing
survival, patchwork, ggrepel, plotly/htmlwidgets and png packages. No package is
installed automatically.
