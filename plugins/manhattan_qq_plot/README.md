# Manhattan / QQ

Display genomic association probabilities and their expected-quantile comparison.

## Input

Raw probabilities in (0,1], plus chromosome and nonnegative genomic position for Manhattan views. Optional nonempty labels identify selected loci.

## Main parameters

- `pvalue_column`: Pvalue column.
- `chromosome_column`: Chromosome column.
- `position_column`: Position column.
- `label_column`: Label column.
- `plot_type`: Plot type.
- `pvalue_threshold`: Pvalue threshold. Raw probability; applies to Manhattan panel only.
- `threshold_color`: Threshold color. Only for Manhattan panel.
- `qq_color`: Qq color. Only for QQ panel.
- `palette`: Palette.
- `group_colors`: Named colors. Named categorical colors override the palette.
- `label_show`: Label show.
- `label_size`: Label size.
- `title`: Title.
- `subtitle`: Subtitle. Empty uses the automatic description.
- `caption`: Caption.
- `title_size`: Title size. Only when a nonempty title is supplied.
- `point_alpha`: Point alpha.
- `point_size`: Point size.
- `line_width`: Line width.
- `font_family`: Font family.
- `base_size`: Base size.
- `plot_background`: Plot background.
- `grid_show`: Grid show.
- `width`: Width. Inches.
- `height`: Height. Inches.
- `dpi`: Dpi.

## Interpretation

- Rounded zero probabilities are rejected rather than silently floored. Select a justified detection bound upstream.
- A QQ deviation alone does not identify population structure or establish biological significance.

## Run

```bash
Rscript plugins/manhattan_qq_plot/plot.R \
  --input plugins/manhattan_qq_plot/examples/basic/input/data.csv \
  --params plugins/manhattan_qq_plot/examples/basic/params.json \
  --output /tmp/manhattan_qq_plot_out
```

Optional uploads are listed in `config.yaml`; each uses its input ID as a CLI flag.
The example manifests include input mappings and parameters and input mappings.

Outputs: SVG/PDF/PNG, figure metadata, run log, data used and documented diagnostic
CSV tables. The 3D embedding engine additionally writes an interactive HTML scene.
Errors write `error.json` and remove partial figure files.

## Examples

- `basic`: Association overview.
- `manhattan`: Genomic association signals.
- `qq`: Expected and observed probabilities.

All examples are independently generated synthetic data. Installed dependencies are
ggplot2, jsonlite, optparse, ragg and svglite; mode-specific rendering uses existing
survival, patchwork, ggrepel, plotly/htmlwidgets and png packages. No package is
installed automatically.
