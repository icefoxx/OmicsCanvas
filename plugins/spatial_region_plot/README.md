# Spatial Region Map

Color supplied anatomical or tissue-region polygons by numeric measurements.

## Input

Ordered x/y polygon vertices, region ID and one numeric value per region; optional part IDs for multipart polygons. PNG overlays require top-left-origin image pixel coordinates and invert_y.

## Main parameters

- `x_column`: X column.
- `y_column`: Y column.
- `group_column`: Group column.
- `value_column`: Value column.
- `part_column`: Part column.
- `invert_y`: Invert y. Required for PNG background pixel coordinates with origin at top left.
- `label_show`: Label show.
- `label_size`: Label size.
- `title`: Title.
- `subtitle`: Subtitle. Empty uses the automatic description.
- `caption`: Caption.
- `title_size`: Title size. Only when a nonempty title is supplied.
- `fill_alpha`: Fill alpha.
- `line_width`: Line width.
- `low_color`: Low color.
- `high_color`: High color.
- `border_color`: Border color.
- `legend_title`: Legend title.
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

- Geometry is supplied; the plugin does not segment tissue or provide a built-in anatomical atlas.
- PNG overlays require matched pixel coordinates. Polygon labels are approximate and should be visually checked for concave regions.

## Run

```bash
Rscript plugins/spatial_region_plot/plot.R \
  --input plugins/spatial_region_plot/examples/basic/input/data.csv \
  --params plugins/spatial_region_plot/examples/basic/params.json \
  --output /tmp/spatial_region_plot_out
```

Optional uploads are listed in `config.yaml`; each uses its input ID as a CLI flag.
The example manifests include input mappings and parameters and input mappings.

Outputs: SVG/PDF/PNG, figure metadata, run log, data used and documented diagnostic
CSV tables. The 3D embedding engine additionally writes an interactive HTML scene.
Errors write `error.json` and remove partial figure files.

## Examples

- `basic`: Measured tissue regions.
- `tissue`: Regions over a synthetic tissue background.

All examples are independently generated synthetic data. Installed dependencies are
ggplot2, jsonlite, optparse, ragg and svglite; mode-specific rendering uses existing
survival, patchwork, ggrepel, plotly/htmlwidgets and png packages. No package is
installed automatically.


Choose polygon geometry for ordered boundary vertices or spot geometry for independent measured coordinates. Spot size applies only to spots. Optional PNG backgrounds use pixel coordinates and require an inverted y axis.


Choose polygon geometry for ordered boundary vertices or spot geometry for independent measured coordinates. Spot size applies only to spots. Optional PNG backgrounds use pixel coordinates and require an inverted y axis.
