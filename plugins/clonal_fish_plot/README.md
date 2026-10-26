# Clonal Evolution

Show supplied nested clone fractions across time.

## Input

Long table of clone, parent (0 for virtual root), time and inclusive clone fraction. Child fractions may not exceed their parent; root fractions may not sum above one.

## Main parameters

- `group_column`: Group column.
- `parent_column`: Parent column.
- `x_column`: X column.
- `value_column`: Value column.
- `fraction_unit`: Fraction unit.
- `timepoint_show`: Timepoint show.
- `fill_alpha`: Fill alpha.
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

- Parent fractions include descendants. Do not sum nested parents and children as independent populations.
- Parent relationships are supplied, not inferred; linear interpolation between time points does not establish clone dynamics.

## Run

```bash
Rscript plugins/clonal_fish_plot/plot.R \
  --input plugins/clonal_fish_plot/examples/basic/input/data.csv \
  --params plugins/clonal_fish_plot/examples/basic/params.json \
  --output /tmp/clonal_fish_plot_out
```

Optional uploads are listed in `config.yaml`; each uses its input ID as a CLI flag.
The example manifests include input mappings and parameters and input mappings.

Outputs: SVG/PDF/PNG, figure metadata, run log, data used and documented diagnostic
CSV tables. The 3D embedding engine additionally writes an interactive HTML scene.
Errors write `error.json` and remove partial figure files.

## Examples

- `basic`: Nested clone fractions.
- `percent`: Clone fractions in percent.

All examples are independently generated synthetic data. Installed dependencies are
ggplot2, jsonlite, optparse, ragg and svglite; mode-specific rendering uses existing
survival, patchwork, ggrepel, plotly/htmlwidgets and png packages. No package is
installed automatically.
