# Classified Bar Plot (分类柱状图)

One bar per category label, colored by a type/class column. Horizontal by default (ChiPlot-style classified bar chart).

## Check before adding similar plots

This plugin already covers:

- Horizontal / vertical single-series bars colored by class
- Pathway / GO / KEGG style ranked category bars with group colors

Do **not** add another plugin for “horizontal colored bars by type”.  
For **stacked** multi-series composition use `stacked_bar_plot`.  
For **bar + secondary line** use `combo_bar_line_plot`.

## Input

| category | type | value |
|----------|------|-------|
| Transcription | type-A | 1800 |
| Lipid metabolism | type-B | 9000 |

Columns are mappable via `category_column`, `type_column`, `value_column`.

## Key parameters

| Param | Meaning |
|-------|---------|
| `orientation` | `horizontal` (default) or `vertical` |
| `type_colors` | map `type-A` → hex |
| `sort_by` | `input`, `value`, `value_desc`, `category`, `type_value` |
| `legend_title` | e.g. `xiaoshi` |
| `x_min` / `x_max` | value axis limits |
| Full axis / title / legend / grid / export | see `params_schema.json` |

## Run

```bash
Rscript plugins/classified_bar_plot/plot.R \
  --input plugins/classified_bar_plot/example_input.csv \
  --params plugins/classified_bar_plot/example_chiplot_params.json \
  --output /tmp/classified_bar_out
```

## Outputs

`result.svg`, `result.pdf`, `result.png`, `figure.json`, `run.log`, `selected_rows.csv`, `matrix_used.csv`
