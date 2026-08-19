# Group Heatmap

Standardized BioFigureAI wrapper for the original SCA `GroupHeatmap()` function.

## Run

```bash
Rscript plugins/group_heatmap/plot.R \
  --input plugins/group_heatmap/example_input.csv \
  --params plugins/group_heatmap/example_heatmap_params.json \
  --output /tmp/group_heatmap_heatmap_out
```

Every successful run writes `result.svg`, `result.pdf`, `result.png`, `figure.json`, `run.log`, and `selected_rows.csv`.

## Input

Use a wide table where each row is a cell/sample. Metadata columns can be used for `group_column` and `cell_annotation`; numeric feature columns are plotted.

## Key Parameters

- Data selection: `id_column`, `rows_include`, `rows_exclude`, `features`, `features_include`, `features_exclude`
- Grouping: `group_column`, `group_columns`, `group_order`, `group_sep`
- Annotation: `cell_annotation`, `top_annotation_labels`, `annotation_colors`, `annotation_palette`
- Feature groups: `feature_groups`, `feature_split`, `feature_order`, `feature_group_side`, `highlight_features`
- Plot modes: `plot_type` = `heatmap`, `dotplot`, `violin`, or `clustered_dotplot`
- Heatmap modes: `heatmap_mode` = `group` or `cell`
- Summary: `summary` = `mean`, `zscore`, or `log1p`
- Layout: `orientation`, `style`, `cluster_rows`, `cluster_columns`, `border`, `width`, `height`, `padding`
- Row/column text: `show_row_names`, `row_name_size`, `row_names_method`, `row_names_layers`, `show_column_names`, `column_name_size`
- Annotation labels: `show_top_annotation_name`, `top_annotation_name_angle`, `annotation_label_size`, `annotation_label_angle`
- Dot layers: `add_dot`, `add_reticle`, `dot_range`, `clustered_dotplot_row_mm`, `clustered_dotplot_col_mm`
- Legends: `legend_position`, `annotation_legend_position`, `merge_legends`, `legend_title_size`, `legend_text_size`, `legend_key_size`
- Palettes/colors: `heatmap_palette`, `heatmap_colors`, `group_palette`, `group_colors`, `annotation_colors`

Both original SCA names such as `group.by` and frontend-friendly names such as `group_column` are accepted.
## Reproducible examples

Bundles are in `plugins/group_heatmap/examples/<id>/`. Each contains `params.json`, copied command inputs under `input/`, and `expected/result.png`. `manifest.json` is the machine-readable entry point and records how to rerun the example.

