# Lollipop Plot (Interactive Enrichment Lollipop)

ChiPlot-style **zero-centered lollipop / Cleveland plot**: category labels on Y, signed values on X, stems to zero, group colors, optional size-mapped heads.

## Check first

This plugin **already** covers general lollipop charts (including pathway enrichment style). Do **not** add a second lollipop plugin — extend this one.

Related but different:

- `interactive_dumbbell_plot` — two-ended dumbbells
- `classified_bar_plot` — solid bars by class (no stems)
- `interactive_enrichment_lollipop` — **this** lollipop

## Input

| category | effect | group | size |
|----------|--------|-------|------|
| Transcription | 1.5 | type-A | 8 |
| Amino acid metabolism | -18 | type-C | 90 |

Columns autodetect or set via `category_column`, `value_column`, `group_column`, `size_column`.

## ChiPlot-style controls

| UI section | Params |
|------------|--------|
| Color set | `type_colors` / `group_colors` |
| Lollipop size | `size_switch`, `min_radius`, `max_radius`, `r` |
| Line style | `stem_color`, `stem_width`, `stem_alpha`, `stem_linetype` |
| Head style | `point_alpha`, `point_stroke`, `point_border_color`, `point_shape` |
| Lollipop text | `label_show`, `label_size`, `label_color`, `value_format` |
| Axes / title / legend / export | full surface in `params_schema.json` |

## Run

```bash
# ChiPlot-style example
Rscript plugins/interactive_enrichment_lollipop/plot.R \
  --input plugins/interactive_enrichment_lollipop/example_chiplot_input.csv \
  --params plugins/interactive_enrichment_lollipop/example_chiplot_params.json \
  --output /tmp/lollipop_chiplot_out

# Basic enrichment example
Rscript plugins/interactive_enrichment_lollipop/plot.R \
  --input plugins/interactive_enrichment_lollipop/example_input.csv \
  --params plugins/interactive_enrichment_lollipop/example_basic_params.json \
  --output /tmp/enrichment_lollipop

# OCT4 signed NES enrichment example
Rscript plugins/interactive_enrichment_lollipop/plot.R \
  --input plugins/interactive_enrichment_lollipop/examples/oct4_enrichment/input/example_input.csv \
  --params plugins/interactive_enrichment_lollipop/examples/oct4_enrichment/params.json \
  --output /tmp/oct4_enrichment
```

## Outputs

`result.svg`, `result.pdf`, `result.png`, `result.html`, `figure.json`, `run.log`, `selected_rows.csv`
