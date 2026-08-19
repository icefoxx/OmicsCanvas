# Interactive Clustered Heatmap

Standalone annotated matrix heatmap. It does not use SCA or ComplexHeatmap.
Static SVG, PDF, and PNG output is drawn with base R/grid; when `plotly` and
`htmlwidgets` are installed, the HTML output is a Plotly heatmap using the
same filtered and ordered matrix.

## CLI

```sh
Rscript plugins/interactive_clustered_heatmap_plot/plot.R \
  --input matrix.csv --params params.json --output output_dir \
  --row-annot row_annotation.csv --col-annot column_annotation.csv
```

The matrix CSV has a row identifier column followed by numeric columns. Set
`row_id_column` and `matrix_start_column` when they are not the first and
second columns. Row annotations have the matching row ID in the first column;
column annotations have the matching sample/feature ID in the first column.
Annotation values may be categorical or numeric. Annotation files can instead
be named by `row_annotation_file` and `column_annotation_file` in params.

The three example params files demonstrate a basic, custom, and interactive
configuration. The screenshot-style layout has an optional left row tree,
top column tree, annotation strips, central rectangular cells, and a value
colorbar. Filtering, scaling, clustering, ordering, palettes, labels, layout,
cell values, legends, and Plotly interaction are controlled by `params.json`.

## Panels

Use `panel_groups` (labels aligned to matrix columns or a panel-to-column
object), `panel_group_column` in the column annotation table, or the CLI
`--panel-groups` two-column mapping. `panel_order`, `panel_titles`, header,
gap, label, border, and `panel_scales`/`panel_palettes` controls customize the
grouped layout. The default is one shared continuous scale; column clustering
still runs on the full matrix before panels are displayed.

## Outputs

`result.svg`, `result.pdf`, `result.png`, `result.html`, `figure.json`, and
`run.log` are always written on success. `matrix_data_used.csv`,
`row_order.csv`, and `column_order.csv` record the exact data used for every
renderer. Failures produce `error.json`, and a successful rerun removes stale
error state.
