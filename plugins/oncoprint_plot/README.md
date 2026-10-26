# Mutation Matrix

Show multiple alteration types per gene and sample with marginal frequencies.

## Input

Long table of gene, sample and alteration type. Multiple rows per gene/sample represent distinct types. None/WT marks no supplied alteration; all evaluated samples must be present.

## Main parameters

- `feature_column`: Feature column.
- `sample_column`: Sample column.
- `group_column`: Group column.
- `row_order`: Row order.
- `frequency_show`: Frequency show.
- `sample_label_show`: Sample label show.
- `title`: Title.
- `subtitle`: Subtitle. Empty uses the automatic description.
- `caption`: Caption.
- `title_size`: Title size. Only when a nonempty title is supplied.
- `empty_color`: Empty color.
- `frequency_color`: Frequency color. Only when frequency_show is enabled.
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

- Missing input coverage is not evidence of wild type. Include every evaluated sample, including explicit no-alteration entries.
- Multiple alteration types share a cell; slice height does not encode allele fraction or variant count.

## Run

```bash
Rscript plugins/oncoprint_plot/plot.R \
  --input plugins/oncoprint_plot/examples/basic/input/data.csv \
  --params plugins/oncoprint_plot/examples/basic/params.json \
  --output /tmp/oncoprint_plot_out
```

Optional uploads are listed in `config.yaml`; each uses its input ID as a CLI flag.
The example manifests include input mappings and parameters and input mappings.

Outputs: SVG/PDF/PNG, figure metadata, run log, data used and documented diagnostic
CSV tables. The 3D embedding engine additionally writes an interactive HTML scene.
Errors write `error.json` and remove partial figure files.

## Examples

- `basic`: Multi-hit alteration matrix.
- `input_order`: Input-order alteration matrix.

All examples are independently generated synthetic data. Installed dependencies are
ggplot2, jsonlite, optparse, ragg and svglite; mode-specific rendering uses existing
survival, patchwork, ggrepel, plotly/htmlwidgets and png packages. No package is
installed automatically.
