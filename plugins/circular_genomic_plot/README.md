# Circular Genome Tracks

Arrange supplied genomic intervals, values and optional links on a circular genome.

## Input

Intervals: chromosome, start, end, value and optional track. Coordinates are 0-based, half-open. Optional chromosome/length and source_chr/source_pos/target_chr/target_pos link tables.

## Main parameters

- `chromosome_column`: Chromosome column.
- `start_column`: Start column.
- `end_column`: End column.
- `value_column`: Value column.
- `group_column`: Group column.
- `layout`: Layout.
- `track_type`: Track type. Circular layout only; linear layout uses interval rectangles.
- `gap_angle`: Gap angle. Circular layout only; total chromosome gaps must remain below 180 degrees.
- `link_show`: Link show.
- `link_alpha`: Link alpha. Only with a supplied links table and link_show enabled.
- `point_size`: Point size. Circular point track only.
- `line_width`: Line width. Only for supplied links.
- `link_color`: Link color. Only when links are drawn.
- `low_color`: Low color.
- `high_color`: High color.
- `palette`: Palette.
- `group_colors`: Named colors. Named categorical colors override the palette.
- `legend_title`: Legend title.
- `legend_show`: Legend show.
- `legend_position`: Legend position.
- `legend_text_size`: Legend text size.
- `label_size`: Label size. Circular chromosome labels only.
- `title`: Title.
- `subtitle`: Subtitle. Empty uses the automatic description.
- `caption`: Caption.
- `title_size`: Title size. Only when a nonempty title is supplied.
- `font_family`: Font family.
- `base_size`: Base size.
- `plot_background`: Plot background.
- `grid_show`: Grid show.
- `width`: Width. Inches.
- `height`: Height. Inches.
- `dpi`: Dpi.

## Interpretation

- Use chromosome lengths from the correct genome assembly. Inferred maximum interval ends are not a complete genome.
- Assembly conversion, peak calling and BigWig extraction are upstream operations. Track heights use within-track numeric ranges.

## Run

```bash
Rscript plugins/circular_genomic_plot/plot.R \
  --input plugins/circular_genomic_plot/examples/basic/input/data.csv \
  --params plugins/circular_genomic_plot/examples/basic/params.json \
  --output /tmp/circular_genomic_plot_out
```

Optional uploads are listed in `config.yaml`; each uses its input ID as a CLI flag.
The example manifests include input mappings and parameters and input mappings.

Outputs: SVG/PDF/PNG, figure metadata, run log, data used and documented diagnostic
CSV tables. The 3D embedding engine additionally writes an interactive HTML scene.
Errors write `error.json` and remove partial figure files.

## Examples

- `basic`: Circular interval heatmap.
- `bars`: Circular interval magnitudes.
- `points`: Circular interval points.
- `linear`: Linear chromosome overview.

All examples are independently generated synthetic data. Installed dependencies are
ggplot2, jsonlite, optparse, ragg and svglite; mode-specific rendering uses existing
survival, patchwork, ggrepel, plotly/htmlwidgets and png packages. No package is
installed automatically.
