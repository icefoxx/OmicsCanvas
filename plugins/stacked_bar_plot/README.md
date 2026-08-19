# Stacked Bar Plot

ChiPlot-style highly customizable stacked (or dodged) composition bar chart for multi-sample / multi-group abundance tables.

## Description

Draws horizontal or vertical stacked bars with:

- Sample bars clustered by group (ChiPlot multi-replicate look)
- Absolute counts, percent, or proportion stacking
- Per-category colors, optional color gradient / named palette
- Full axis styling (tick stroke/length/orientation, text rotate/size/weight, removePath/removeTick, min/max)
- Grid, title, title background strip, plot background
- Bar style (outer/inner padding, stroke, opacity) and optional bar text
- Legend title / square / layout (columns, spacing)

## Input

### Wide matrix (default)

| sample | group | Corynebacteria | Microbacteria | ... |
|--------|-------|----------------|---------------|-----|
| sn_r1  | sn    | 45             | 52            | ... |

- `sample_column` (default first column)
- `group_column` (optional; enables group-centered y labels)
- remaining numeric columns become stack categories (`value_columns` can subset)

### Long table

| sample | group | taxon | abundance |
|--------|-------|-------|-----------|

Set `input_mode: "long"` with `stack_column` and `value_column`.

## Key parameters

See `params_schema.json` for the full ChiPlot-style control surface.

| Param | Meaning |
|-------|---------|
| `orientation` | `horizontal` (default) or `vertical` |
| `position` | `stack`, `dodge`, or `fill` |
| `value_mode` | `absolute`, `percent`, `proportion` |
| `y_label_mode` | `group` (ChiPlot), `sample`, or `both` |
| `outerPadding` / `innerPadding` | bar spacing |
| `category_colors` | named map of category → hex color |
| `x_axis_text_angle` | tick label rotate (default -45 for horizontal) |
| `x_min` / `x_max` | numeric axis limits (`min-value` / `max-value`) |
| `legend_title` | legend header (default `ChiPlot`) |

## Output

- `result.svg` / `result.pdf` / `result.png`
- `figure.json`
- `run.log`
- `selected_rows.csv`
- `matrix_used.csv`

## Run

```bash
Rscript plugins/stacked_bar_plot/plot.R \
  --input plugins/stacked_bar_plot/example_input.csv \
  --params plugins/stacked_bar_plot/example_chiplot_params.json \
  --output /tmp/stacked_bar_out
```

## Examples

- `example_basic_params.json` — minimal stacked horizontal bars
- `example_chiplot_params.json` — multi-replicate horizontal composition (group labels)
- `example_normal_params.json` + `example_normal_input.csv` — classic vertical stacked bars (Sample-1..N)
- `example_percent_params.json` — relative abundance with grid + title
- `example_long_params.json` — long-format input
- `example_vertical_labels_params.json` — vertical bars with in-bar labels

## Orientation quick switch

```json
{ "orientation": "horizontal" }
{ "orientation": "vertical" }
```

Same plugin covers both layouts; do not add a separate plugin for vertical stacked bars.
