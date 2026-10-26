# Linked Heatmap + Network

Link a numeric feature matrix to supplied weighted relationships.

## Input

Long feature/condition/value matrix plus a required links CSV with source, target, weight and optional group. Every link source must match a matrix feature.

## Main parameters

- `row_column`: Row column.
- `column_column`: Column column.
- `value_column`: Value column.
- `edge_group_column`: Edge group column.
- `matrix_mark`: Matrix mark.
- `node_gap`: Node gap.
- `dot_size`: Dot size. Only for matrix_mark = dot.
- `curvature`: Curvature.
- `edge_alpha`: Edge alpha.
- `point_size`: Point size.
- `line_width`: Line width.
- `low_color`: Low color.
- `high_color`: High color.
- `palette`: Palette.
- `group_colors`: Named colors. Named categorical colors override the palette.
- `label_size`: Label size.
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

- Edges are supplied relationships; the engine does not infer interactions, causal links or drug responses.
- Edge width represents absolute weight; edge class colors are supplied separately and must be described.

## Run

```bash
Rscript plugins/linked_matrix_network_plot/plot.R --input plugins/linked_matrix_network_plot/examples/basic/input/data.csv --params plugins/linked_matrix_network_plot/examples/basic/params.json --output /tmp/linked_matrix_network_plot_out --links plugins/linked_matrix_network_plot/examples/basic/input/links.csv
```

Outputs: SVG/PDF/PNG, figure metadata, run log, drawn data and diagnostic CSV tables.
Errors write error.json and remove partial figure files. The examples are independently
generated synthetic measurements. Existing ggplot2/patchwork packages are used; no
dependency is installed automatically.
