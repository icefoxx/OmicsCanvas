# Swimmer Timeline

Show observation intervals and dated events for individual subjects.

## Input

One unique subject per start/end interval with end >= start. Optional events CSV has subject, time and event; events must fall within their subject interval.

## Main parameters

- `id_column`: Id column.
- `start_column`: Start column.
- `end_column`: End column.
- `group_column`: Group column.
- `sort_by`: Sort by.
- `bar_width`: Bar width.
- `end_marker_show`: End marker show.
- `event_size`: Event size. Only when an events table is supplied.
- `point_size`: Point size.
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

- An interval endpoint marker does not identify progression, death or censoring unless the event table explicitly encodes it.
- Intervals are supplied observations; no treatment effect or survival model is inferred.

## Run

```bash
Rscript plugins/swimmer_plot/plot.R \
  --input plugins/swimmer_plot/examples/basic/input/data.csv \
  --params plugins/swimmer_plot/examples/basic/params.json \
  --output /tmp/swimmer_plot_out
```

Optional uploads are listed in `config.yaml`; each uses its input ID as a CLI flag.
The example manifests include input mappings and parameters and input mappings.

Outputs: SVG/PDF/PNG, figure metadata, run log, data used and documented diagnostic
CSV tables. The 3D embedding engine additionally writes an interactive HTML scene.
Errors write `error.json` and remove partial figure files.

## Examples

- `basic`: Observation intervals and events.
- `staggered`: Staggered observation windows.

All examples are independently generated synthetic data. Installed dependencies are
ggplot2, jsonlite, optparse, ragg and svglite; mode-specific rendering uses existing
survival, patchwork, ggrepel, plotly/htmlwidgets and png packages. No package is
installed automatically.
