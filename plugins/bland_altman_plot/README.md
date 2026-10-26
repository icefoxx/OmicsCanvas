# Bland–Altman Agreement

Compare paired measurements using mean differences and limits of agreement.

## Input

Paired finite numeric measurements in the same units, one independent pair per row, with optional group. Percent differences require nonzero pair means.

## Main parameters

- `x_column`: X column.
- `y_column`: Y column.
- `group_column`: Group column.
- `difference_mode`: Difference mode.
- `loa_multiplier`: Loa multiplier. Bias ± multiplier × sample SD; these are agreement limits, not bias confidence intervals.
- `trend_show`: Trend show.
- `label_show`: Label show.
- `label_size`: Label size.
- `title`: Title.
- `subtitle`: Subtitle. Empty uses the automatic description.
- `caption`: Caption.
- `title_size`: Title size. Only when a nonempty title is supplied.
- `point_alpha`: Point alpha.
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

- Agreement limits assume independent, approximately normal differences; repeated measurements require a different model.
- The difference direction is method A minus method B. Percent differences use the mean of the pair as denominator.

## Run

```bash
Rscript plugins/bland_altman_plot/plot.R \
  --input plugins/bland_altman_plot/examples/basic/input/data.csv \
  --params plugins/bland_altman_plot/examples/basic/params.json \
  --output /tmp/bland_altman_plot_out
```

Optional uploads are listed in `config.yaml`; each uses its input ID as a CLI flag.
The example manifests include input mappings and parameters and input mappings.

Outputs: SVG/PDF/PNG, figure metadata, run log, data used and documented diagnostic
CSV tables. The 3D embedding engine additionally writes an interactive HTML scene.
Errors write `error.json` and remove partial figure files.

## Examples

- `basic`: Paired measurement agreement.
- `percent`: Relative measurement agreement.

All examples are independently generated synthetic data. Installed dependencies are
ggplot2, jsonlite, optparse, ragg and svglite; mode-specific rendering uses existing
survival, patchwork, ggrepel, plotly/htmlwidgets and png packages. No package is
installed automatically.
