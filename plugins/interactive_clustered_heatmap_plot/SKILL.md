# Interactive Clustered Heatmap Plugin

Use `plot.R` for wide numeric matrix CSVs. The first matrix column is the row
ID by default and all following columns are numeric; explicit
`row_id_column`/`matrix_start_column` are recommended for production input.
`--row-annot` and `--col-annot` are preferred for annotation tables. Their
first columns must match the displayed row and column IDs. Numeric annotation
columns receive continuous blue strips, while categorical columns receive
discrete colors and legends.

Defaults: no scaling, impute missing values with zero, cluster rows and
columns with Euclidean distance and complete linkage, show both dendrograms,
viridis palette, white cell borders, and interactive HTML enabled when Plotly
is installed. `interactive:false` still writes an HTML explanatory fallback.

Grouped panels accept `panel_groups`, `panel_group_column`, or the CLI
`--panel-groups` two-column mapping. Panels share the scale by default;
`panel_scales: per_panel` and `panel_palettes` enable independent scales.
Static output draws bordered panel rectangles with headers and rotated labels;
HTML uses one Plotly heatmap trace per panel with panel-aware hover text.

Required outputs are `result.svg`, `result.pdf`, `result.png`, `result.html`,
`figure.json`, `run.log`, `matrix_data_used.csv`, `row_order.csv`, and
`column_order.csv`; errors are reported in `error.json`.
