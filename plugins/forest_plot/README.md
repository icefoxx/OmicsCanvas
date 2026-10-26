# Forest Plot

Compare supplied effect estimates and confidence intervals.

## Input

One row per effect: unique label, estimate, lower/upper interval bounds and optional group. Log axes require positive estimates/bounds and a positive null value.

## Main parameters

- `label_column`: Label column.
- `effect_column`: Effect column.
- `lower_column`: Lower column.
- `upper_column`: Upper column.
- `group_column`: Group column.
- `x_scale`: X scale. Log10 requires positive effects, bounds and null value.
- `null_value`: Null value. Reference value: 1 for ratios, 0 for signed differences.
- `estimate_show`: Estimate show.
- `label_size`: Label size.
- `title`: Title.
- `subtitle`: Subtitle. Empty uses the automatic description.
- `caption`: Caption.
- `title_size`: Title size. Only when a nonempty title is supplied.
- `point_size`: Point size.
- `line_width`: Line width.
- `palette`: Palette.
- `group_colors`: Named colors. Named categorical colors override the palette.
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

- Confidence intervals and effect units are supplied, not estimated. Ratio estimates and signed differences use different reference values.
- A forest display does not fit a random-effects meta-analysis or establish subgroup interactions.

## Run

```bash
Rscript plugins/forest_plot/plot.R \
  --input plugins/forest_plot/examples/basic/input/data.csv \
  --params plugins/forest_plot/examples/basic/params.json \
  --output /tmp/forest_plot_out
```

Optional uploads are listed in `config.yaml`; each uses its input ID as a CLI flag.
The example manifests include input mappings and parameters and input mappings.

Outputs: SVG/PDF/PNG, figure metadata, run log, data used and documented diagnostic
CSV tables. The 3D embedding engine additionally writes an interactive HTML scene.
Errors write `error.json` and remove partial figure files.

## Examples

- `basic`: Effect estimates and confidence intervals.
- `log_ratio`: Ratios on a logarithmic axis.
- `signed_effects`: Signed differences.

All examples are independently generated synthetic data. Installed dependencies are
ggplot2, jsonlite, optparse, ragg and svglite; mode-specific rendering uses existing
survival, patchwork, ggrepel, plotly/htmlwidgets and png packages. No package is
installed automatically.
