# Circular Score Distribution

Compare numeric score distributions and highlighted observations on concentric arcs.

## Input

Numeric score, metric name, group and optional observation ID. Highlight IDs select existing observations. Angle represents value, not frequency.

## Main parameters

- `value_column`: Value column.
- `feature_column`: Feature column.
- `group_column`: Group column.
- `id_column`: Id column.
- `highlight_ids`: Highlight ids.
- `highlight_color`: Highlight color. Only when highlight_ids matches input observations.
- `gap_angle`: Gap angle.
- `range_mode`: Range mode.
- `ncol`: Ncol.
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

- Angle encodes the supplied numeric score, not rank unless ranks were uploaded as values.
- Separate ring groups do not encode population size by ring area. Free metric ranges prevent direct angular comparison across panels.

## Run

```bash
Rscript plugins/circular_distribution_plot/plot.R \
  --input plugins/circular_distribution_plot/examples/basic/input/data.csv \
  --params plugins/circular_distribution_plot/examples/basic/params.json \
  --output /tmp/circular_distribution_plot_out
```

Optional uploads are listed in `config.yaml`; each uses its input ID as a CLI flag.
The example manifests include input mappings and parameters and input mappings.

Outputs: SVG/PDF/PNG, figure metadata, run log, data used and documented diagnostic
CSV tables. The 3D embedding engine additionally writes an interactive HTML scene.
Errors write `error.json` and remove partial figure files.

## Examples

- `basic`: Scores across reference groups.
- `shared_range`: Scores on a common scale.

All examples are independently generated synthetic data. Installed dependencies are
ggplot2, jsonlite, optparse, ragg and svglite; mode-specific rendering uses existing
survival, patchwork, ggrepel, plotly/htmlwidgets and png packages. No package is
installed automatically.
