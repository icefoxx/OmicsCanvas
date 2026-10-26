# Empirical CDF

Compare cumulative distributions with optional distribution-free confidence bands.

## Input

One finite numeric value per independent observation and optional group. Two-sample tests require exactly two groups; pairing is not inferred.

## Main parameters

- `value_column`: Value column.
- `group_column`: Group column.
- `confidence_show`: Confidence show.
- `confidence_alpha`: Confidence alpha. Only when confidence_show is enabled.
- `line_width`: Line width.
- `confidence_level`: Confidence level. DKW confidence bands only; confidence_show must be enabled.
- `stat_method`: Stat method. Tests require exactly two independent groups; no paired or repeated-measure test is inferred.
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

- DKW bands assume independent observations and are simultaneous within each group, without adjustment across groups.
- Wilcoxon and KS answer different questions. Neither is a paired or repeated-measure test here.

## Run

```bash
Rscript plugins/ecdf_plot/plot.R \
  --input plugins/ecdf_plot/examples/basic/input/data.csv \
  --params plugins/ecdf_plot/examples/basic/params.json \
  --output /tmp/ecdf_plot_out
```

Optional uploads are listed in `config.yaml`; each uses its input ID as a CLI flag.
The example manifests include input mappings and parameters and input mappings.

Outputs: SVG/PDF/PNG, figure metadata, run log, data used and documented diagnostic
CSV tables. The 3D embedding engine additionally writes an interactive HTML scene.
Errors write `error.json` and remove partial figure files.

## Examples

- `basic`: Cumulative score distributions.
- `steps`: Empirical distribution steps.

All examples are independently generated synthetic data. Installed dependencies are
ggplot2, jsonlite, optparse, ragg and svglite; mode-specific rendering uses existing
survival, patchwork, ggrepel, plotly/htmlwidgets and png packages. No package is
installed automatically.
