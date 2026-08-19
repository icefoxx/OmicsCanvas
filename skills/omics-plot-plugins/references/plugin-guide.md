# OmicsCanvas Plot Plugin Guide

Use this reference after reading `../SKILL.md`.

## Correlation Heatmap Plugin

Path:

```text
plugins/intragroup_correlation/plot.R
```

Single matrix:

```bash
Rscript plugins/intragroup_correlation/plot.R \
  --input /tmp/intragroup_corr_input.csv \
  --params /tmp/intragroup_corr_params.json \
  --output /tmp/intragroup_corr_out
```

Two matrices:

```bash
Rscript plugins/intragroup_correlation/plot.R \
  --input /tmp/matrix1.csv \
  --input2 /tmp/matrix2.csv \
  --params /tmp/cross_corr_params.json \
  --output /tmp/cross_corr_out
```

If an execution backend can only pass `--input`, `--params`, and `--output`, put the second file path in params:

```json
{
  "input2_file": "/tmp/matrix2.csv"
}
```

### Correlation Core Params

```json
{
  "row_name_column": "feature",
  "analysis_type": "pearson",
  "compute_by": "column",
  "plot_shape": "circle",
  "cluster_rows": true,
  "cluster_columns": true,
  "show_value": true,
  "show_p_mark": true,
  "palette_scheme": "genedenovo4"
}
```

Supported `analysis_type` values:

```text
pearson, spearman, kendall, jaccard, jarrad, cosine, cos, raw
```

Use `raw` for gene/sample heatmaps. Use correlation/similarity methods for sample/sample, feature/feature, or matrix1/matrix2 similarity.

### Two-Matrix Include/Exclude Selectors

Default behavior uses the first column as row IDs/features and all remaining numeric columns. UI click selectors should map to include/exclude arrays:

```json
{
  "matrix1_columns_include": ["A_1", "A_2", "A_3", "B_1"],
  "matrix1_columns_exclude": ["B_1"],
  "matrix2_columns_include": ["X_1", "X_2", "Y_1", "Y_2"],
  "matrix2_columns_exclude": ["Y_2"],
  "matrix1_rows_include": ["Gene1", "Gene2"],
  "matrix2_rows_exclude": ["Gene9"]
}
```

For `compute_by: "column"`, the script aligns shared row IDs/features between the two matrices, then calculates correlations between selected columns of matrix 1 and selected columns of matrix 2.

### Heatmap WYSIWYG Controls

```json
{
  "title_show": true,
  "title_size": 21,
  "title_color": "#000000",
  "x_title": "Custom column axis",
  "y_title": "Custom row axis",
  "axis_title_show": true,
  "show_x_axis": true,
  "show_y_axis": true,
  "axis_title_size": 11,
  "axis_title_color": "#005BBB",
  "axis_line_show": true,
  "axis_line_color": "#005BBB",
  "axis_line_width": 0.7,
  "axis_tick_show": true,
  "axis_tick_color": "#005BBB",
  "font_family": "Arial",
  "text_color": "#000000",
  "legend_size": 14,
  "legend_name": "Custom correlation legend",
  "legend_position": "bottom",
  "legend_bar_width": 3.2,
  "legend_bar_height": 0.35,
  "legend_frame_color": "#111111",
  "legend_tick_color": "#111111",
  "cell_width": 25,
  "cell_height": 25,
  "cell_alpha": 1,
  "label_angle": 45,
  "row_name_size": 14,
  "column_name_size": 12,
  "cell_text_size": 3,
  "show_grid_border": false,
  "border_color": "#f0f0f0",
  "border_width": 0.25
}
```

For heatmaps, `xlim`/`ylim` are categorical row/column selections rather than numeric limits. Use `columns_keep`, `columns_hide`, `rows_keep`, and `rows_hide` for the user-facing equivalent.

### Dendrograms, Groups, and Label Colors

Visible dendrograms use `ComplexHeatmap`:

```json
{
  "show_row_dendrogram": true,
  "show_column_dendrogram": true,
  "row_tree_color": "#7B1FA2",
  "column_tree_color": "#00695C",
  "tree_line_width": 2,
  "row_dendrogram_width_mm": 22,
  "column_dendrogram_height_mm": 20
}
```

Group annotation tracks:

```json
{
  "row_groups": {
    "A_1": "Group A",
    "A_2": "Group A",
    "B_1": "Group B"
  },
  "column_groups": {
    "A_1": "Group A",
    "A_2": "Group A",
    "B_1": "Group B"
  },
  "row_group_colors": {
    "Group A": "#F8766D",
    "Group B": "#00A087"
  },
  "column_group_colors": {
    "Group A": "#F8766D",
    "Group B": "#00A087"
  },
  "row_group_name": "Row group",
  "column_group_name": "Column group"
}
```

Specific label colors:

```json
{
  "highlight_rows": ["A_1", "A_2"],
  "highlight_columns": ["A_1", "A_2"],
  "highlight_color": "#E31A1C",
  "sample_label_colors": {
    "A_1": "#E31A1C",
    "A_2": "#E31A1C",
    "A_3": "#1F78B4"
  },
  "gene_label_colors": {
    "AOAH": "#7B1FA2",
    "DUSP6": "#E31A1C"
  }
}
```

## Threshold Matrix Heatmap Plugin

Path:

```text
plugins/threshold_matrix_heatmap/plot.R
```

Run:

```bash
Rscript plugins/threshold_matrix_heatmap/plot.R \
  --input plugins/threshold_matrix_heatmap/example_input.csv \
  --params plugins/threshold_matrix_heatmap/example_params.json \
  --output /tmp/threshold_matrix_heatmap_out
```

This plugin is for table-driven matrix plots such as GO/enrichment significance matrices. It does not calculate correlation. Users choose the row label column, displayed value columns, and displayed rows through params; by default all rows and all numeric value columns are shown.

### Core Params

```json
{
  "row_label_column": "term",
  "value_columns": ["CK-vs-M1", "CK-vs-M2", "CK-vs-M3", "M1-vs-M2"],
  "rows_include": ["aminoglycan metabolic process", "vitamin binding"],
  "rows_exclude": ["unwanted term"],
  "columns_exclude": ["hidden comparison"],
  "cell_shape": "tile"
}
```

Supported `cell_shape` values:

```text
tile, circle, diamond, triangle
```

The plugin writes `selected_rows.csv`, which should feed the table under the figure. Frontend table selections should map back to `rows_include` or `rows_exclude`.

### Cutoff Coloring Rules

One rule set for all columns:

```json
{
  "default_rules": "<0.01=#F97316|strong sig;<0.05=#C6FF1A|sig;else=#C9C9C9|non-sig;missing=#FFFFFF|none"
}
```

Per-column overrides:

```json
{
  "column_rules_string": "M1-vs-M2:<0.001=#D94801|very strong,<0.01=#F97316|strong sig,<0.05=#C6FF1A|sig,else=#C9C9C9|non-sig;M2-vs-M3:<0.01=#C6FF1A|sig,else=#C9C9C9|non-sig"
}
```

Rule syntax:

```text
operator cutoff = color | legend label
```

Examples:

```text
<0.05=#C6FF1A|sig
<=0.01=#F97316|strong sig
>2=#D01C8B|high
else=#C9C9C9|non-sig
missing=#FFFFFF|none
```

### WYSIWYG Controls

```json
{
  "title_show": false,
  "title": "GO significance matrix",
  "row_label_position": "right",
  "column_label_position": "bottom",
  "row_name_size": 9,
  "column_name_size": 9,
  "column_name_angle": 90,
  "row_name_italic": false,
  "column_name_italic": false,
  "highlight_rows": ["vitamin binding"],
  "highlight_columns": ["CK-vs-M2"],
  "highlight_color": "#7B1FA2",
  "row_label_colors": {
    "vitamin binding": "#7B1FA2"
  },
  "column_label_colors": {
    "CK-vs-M2": "#D73027"
  },
  "cell_width": 0.95,
  "cell_height": 0.95,
  "cell_size": 8,
  "cell_alpha": 1,
  "show_cell_border": true,
  "cell_border_color": "#FFFFFF",
  "cell_border_width": 0.35,
  "show_value": false,
  "legend_name": "status",
  "legend_position": "right",
  "legend_levels": ["sig", "non-sig", "none", "strong sig"],
  "legend_title_size": 11,
  "legend_text_size": 10,
  "legend_key_size": 0.42,
  "legend_ncol": 1,
  "legend_reverse": false,
  "plot_background": "#FFFFFF",
  "panel_background": "#FFFFFF"
}
```

## Volcano Plot Plugin

Path:

```text
plugins/volcano_plot/plot.R
```

Run:

```bash
Rscript plugins/volcano_plot/plot.R \
  --input /tmp/volcano_input.csv \
  --params /tmp/volcano_params.json \
  --output /tmp/volcano_out
```

### Volcano Core Params

```json
{
  "gene_column": "gene",
  "log2fc_column": "log2FC",
  "padj_column": "padj",
  "x_column": "log2FC",
  "y_column": "padj",
  "x_transform": "none",
  "y_transform": "neglog10",
  "fc_cutoff": 1,
  "p_cutoff": 0.05,
  "title": "Volcano plot",
  "x_title": "Log2FC",
  "y_title": "-Log10(Pvalue)"
}
```

The script autodetects common names such as `gene`, `log2FoldChange`, `log2FC`, `avg_log2FC`, `pvalue`, `padj`, `p_val_adj`, `FDR`, and `qvalue`.

Use `x_column` and `y_column` when the UI allows users to choose any table column for the horizontal and vertical axes. Supported transforms are `none`, `neglog10`, `log10`, and `log2`. If `y_column` is the active p-value/FDR column, `y_transform` defaults to `neglog10`.

Threshold lines are also axis-aware:

```json
{
  "x_thresholds": [-1, 1],
  "y_thresholds": [1.30103],
  "show_threshold_lines": true
}
```

If custom x/y columns are not the log2FC/p-value pair, set `x_thresholds` and `y_thresholds` explicitly or use empty arrays to hide them.

### Category Color Mode

```json
{
  "color_mode": "category",
  "palette_scheme": "category",
  "up_color": "#F35A5A",
  "nodiff_color": "#58C7E6",
  "down_color": "#E6A23C",
  "point_size": 1.1,
  "point_alpha": 0.72
}
```

### Gradient, Size Legend, and Selected Labels

```json
{
  "color_mode": "gradient",
  "gradient_by": "log2FC",
  "gradient_scheme": "orange_red",
  "size_mode": "mapped",
  "size_by": "neglog10p",
  "size_legend_title": "-log10(Padjust)",
  "min_point_size": 0.4,
  "max_point_size": 4.5,
  "selected_genes": ["Csf3", "Clec4e"],
  "selected_point_color": "#D01C8B",
  "selected_point_size": 4.2,
  "selected_point_border_color": "#212121",
  "label_show": true,
  "label_size": 4.2,
  "label_color": "#1E40FF",
  "gene_label_colors": {
    "Csf3": "#1E40FF",
    "Clec4e": "#1E40FF"
  },
  "label_line_color": "#7B1FA2",
  "label_line_width": 0.5,
  "label_force": 16
}
```

### Arbitrary Region Styles

Use `regions` when users define rule-based areas such as `x > 1, y > 1` or rectangular ranges. Later rules override earlier rules for points that match multiple regions.

```json
{
  "x_column": "log2FC",
  "y_column": "padj",
  "y_transform": "neglog10",
  "region_legend_name": "User regions",
  "show_region_legend": true,
  "region_legend_order": 2,
  "region_legend_ncol": 1,
  "region_legend_title_position": "top",
  "region_legend_direction": "vertical",
  "region_legend_point_size": 4.5,
  "regions": [
    {
      "id": "strong_up",
      "label": "x > 1, y > 1",
      "condition": "x > 1 & y > 1",
      "fill": "#D01C8B",
      "outline_color": "#212121",
      "size": 3.5,
      "shape": 21,
      "stroke": 0.7,
      "alpha": 0.9
    },
    {
      "id": "mid_low",
      "label": "1 < x < 2, y < 2",
      "xmin": 1,
      "xmax": 2,
      "ymax": 2,
      "fill": "#00A087",
      "outline_color": "#004D40",
      "size": 2.8,
      "shape": 24,
      "stroke": 0.8,
      "alpha": 0.95
    }
  ]
}
```

For `condition`, `x` and `y` refer to the plotted axis values after transforms. Input columns are also available in the expression when their names are valid R identifiers. For click-drawn rectangular regions, prefer `xmin`, `xmax`, `ymin`, and `ymax`.

Useful ggplot point shapes:

```text
16 solid circle, 17 solid triangle, 21 filled circle with outline, 22 filled square with outline, 23 diamond, 24 triangle with outline, 25 inverted triangle with outline
```

### Brush Selection, Row Table, and Draggable Labels

For interactive UIs, brush/lasso state should be passed through params instead of changing the uploaded file. Rectangular brush selections map to `selection_regions`; the plugin writes matching rows to `selected_rows.csv` so the table below the plot can load them directly.

```json
{
  "selection_regions": [
    {
      "id": "table_brush_1",
      "label": "User brushed area",
      "xmin": -2.5,
      "xmax": -1,
      "ymin": 1.5,
      "ymax": 4
    }
  ]
}
```

When the user clicks rows in that table, pass those IDs through `selected_ids`. To style selected rows, use `selected_point_styles`. Specific ID records are applied after broad region records, so point/row choices override region defaults.

```json
{
  "selected_ids": ["Gene1", "Gene2"],
  "selected_point_styles": [
    {
      "region_id": "table_brush_1",
      "fill": "#06D6A0",
      "outline_color": "#004D40",
      "size": 3.2,
      "shape": 24,
      "stroke": 0.8,
      "alpha": 0.9,
      "label_show": false
    },
    {
      "id": "Gene1",
      "fill": "#FFD166",
      "outline_color": "#111111",
      "size": 5.2,
      "shape": 23,
      "stroke": 1,
      "label_show": true,
      "label_x": 5.7,
      "label_y": 6.5,
      "label_color": "#7B1FA2",
      "indicator_color": "#7B1FA2",
      "indicator_type": "solid",
      "indicator_width": 0.75
    },
    {
      "id": "Gene2",
      "fill": "#118AB2",
      "outline_color": "#073B4C",
      "size": 4.8,
      "shape": 22,
      "stroke": 1,
      "label_show": true,
      "label_x": -4.8,
      "label_y": 4.7,
      "label_color": "#073B4C",
      "indicator_color": "#073B4C",
      "indicator_type": "dashed",
      "indicator_width": 0.75
    }
  ]
}
```

`label_x` and `label_y` are plotted-axis coordinates after x/y transforms. A frontend can implement draggable labels by updating those two values after drag end and re-running the plugin. When no manual label coordinates are supplied, the script uses `ggrepel` when available.

Successful volcano runs also export:

```text
selected_rows.csv
```

The exported table keeps the original input columns and appends `plot_x`, `plot_y`, `de_group`, `style_region`, `brush_region`, and `is_selected`.

## Ranked Annotation Panel Plugin

Path:

```text
plugins/ranked_annotation_panel/plot.R
```

Run:

```bash
Rscript plugins/ranked_annotation_panel/plot.R \
  --input plugins/ranked_annotation_panel/example_input.csv \
  --params plugins/ranked_annotation_panel/example_params.json \
  --output /tmp/ranked_annotation_panel_out
```

This plugin draws a ranked numeric point panel on the left and a selected annotation heatmap panel on the right. It uses one input matrix/table. Users choose rows from that table, choose the row label column, choose one numeric left-panel value column, and choose right-panel annotation columns.

### Core Params

```json
{
  "row_label_column": "feature",
  "left_value_column": "score",
  "annotation_columns": ["L13", "L18", "L6"],
  "rows_include": ["Ga_Per2", "Actn4", "RQ"],
  "rows_exclude": ["unwanted row"],
  "sort_rows_by_left_value": true,
  "sort_decreasing": true
}
```

`rows_include` and `rows_exclude` should be driven by the table under the figure. By default all rows are shown.

### Right Panel Colors

Continuous annotation column:

```json
{
  "annotation_settings": {
    "L13": {
      "type": "continuous",
      "colors": ["#008B5A", "#FFFFBF", "#B2182B"],
      "limits": [0, 1],
      "low_label": "Low",
      "high_label": "High"
    }
  }
}
```

Discrete annotation column:

```json
{
  "annotation_settings": {
    "L18": {
      "type": "discrete",
      "colors": {
        "Low": "#008B5A",
        "Mid": "#FFFFBF",
        "High": "#B2182B"
      }
    }
  }
}
```

If `type` is omitted, numeric-like columns are treated as continuous and character/factor columns are treated as discrete.

### WYSIWYG Controls

```json
{
  "title_show": false,
  "title": "Ranked annotation panel",
  "x_title": "Score",
  "x_min": 30,
  "x_max": 50,
  "point_color": "#001FBC",
  "point_fill": "#001FBC",
  "point_size": 2.5,
  "point_shape": 21,
  "point_alpha": 1,
  "point_stroke": 0.25,
  "show_grid": true,
  "grid_color": "#E6E6E6",
  "grid_line_type": "dotted",
  "panel_border": true,
  "panel_border_color": "#555555",
  "row_name_size": 7,
  "x_axis_text_size": 8,
  "annotation_cell_width": 0.8,
  "annotation_cell_height": 0.86,
  "annotation_label_size": 7,
  "annotation_label_angle": 45,
  "annotation_border_color": "#222222",
  "annotation_border_width": 0.25,
  "show_legend": true,
  "legend_title_size": 8,
  "legend_text_size": 7,
  "left_panel_width": 5.4,
  "annotation_panel_width": 0.9,
  "legend_panel_width": 1.3,
  "width": 7.2,
  "height": 6
}
```

Successful runs also export `selected_rows.csv`, keeping original input columns plus `plot_row_label`, `left_value`, and `is_selected`.

## Quadrant Correlation Scatter Plugin

Path:

```text
plugins/quadrant_correlation_scatter/plot.R
```

Run:

```bash
Rscript plugins/quadrant_correlation_scatter/plot.R \
  --input plugins/quadrant_correlation_scatter/example_input.csv \
  --params plugins/quadrant_correlation_scatter/example_params.json \
  --output /tmp/quadrant_correlation_scatter_out
```

This plugin draws a highly customizable x/y scatter plot like a 4- or 9-quadrant correlation plot. Users choose x/y columns, row label column, visible rows, threshold lines, colors, selected dot labels, and legend details.

### Core Params

```json
{
  "label_column": "gene",
  "x_column": "x_ratio",
  "y_column": "y_ratio",
  "quadrant_mode": "nine",
  "x_thresholds": [-1, 1],
  "y_thresholds": [-1, 1],
  "rows_include": ["Gene_0001", "Gene_0100"],
  "rows_exclude": ["Gene_0099"]
}
```

Supported `quadrant_mode` values:

```text
nine, four, custom
```

### Quadrant Colors And Legends

```json
{
  "quadrant_colors": {
    "quadrant 1": "#F2B134",
    "quadrant 2": "#62BDEB",
    "quadrant 3": "#D63B42",
    "quadrant 4": "#3BAA68",
    "quadrant 5": "#F9E729",
    "quadrant 6": "#9C1C8A",
    "quadrant 7": "#00A99D",
    "quadrant 8": "#F08A45",
    "quadrant 9": "#6D52C1"
  },
  "legend_name": "",
  "legend_position": "right",
  "legend_title_size": 10,
  "legend_text_size": 9,
  "legend_point_size": 3,
  "legend_key_size": 0.45
}
```

Custom regions can override quadrant assignment:

```json
{
  "regions": [
    {
      "id": "special",
      "label": "special region",
      "condition": "x > 2 & y > 2",
      "color": "#D01C8B"
    }
  ]
}
```

### Selected Labels

```json
{
  "selected_ids": ["Gene_0001", "Gene_0100"],
  "selected_point_fill": "#FFD166",
  "selected_point_color": "#212121",
  "selected_point_size": 2.6,
  "label_show": true,
  "label_size": 3.1,
  "label_color": "#212121",
  "label_line_color": "#555555",
  "label_line_width": 0.35,
  "selected_point_styles": [
    {
      "id": "Gene_0001",
      "label_x": 2.6,
      "label_y": 5.2,
      "label_color": "#7B1FA2",
      "indicator_color": "#7B1FA2",
      "indicator_type": "solid",
      "indicator_width": 0.55
    }
  ]
}
```

`label_x` and `label_y` are plotted-axis coordinates. Frontends can implement draggable labels by updating those coordinates and rerunning the plugin.

### Correlation And Axis Controls

```json
{
  "show_correlation": true,
  "cor_method": "pearson",
  "cor_label_position": "title",
  "cor_label_size": 4.2,
  "cor_label_color": "#222222",
  "x_title": "log2 ratio of transcript 0.1 uM vs control",
  "y_title": "log2 ratio of transcript 0.05 uM vs control",
  "x_min": -3,
  "x_max": 3,
  "y_min": -6,
  "y_max": 6,
  "threshold_line_color": "#888888",
  "threshold_line_type": "dashed",
  "zero_line_type": "dotted",
  "point_size": 0.75,
  "point_alpha": 0.85,
  "show_grid": true,
  "grid_color": "#E6E6E6",
  "panel_border_color": "#222222"
}
```

Successful runs export `selected_rows.csv` with original selected rows plus `plot_x`, `plot_y`, `quadrant`, and `is_selected`.

### Volcano WYSIWYG Controls

```json
{
  "title_show": true,
  "title_size": 18,
  "title_bold": true,
  "axis_title_show": true,
  "x_title": "Custom Log2FC",
  "y_title": "Custom -log10 adjusted P",
  "show_x_axis": true,
  "show_y_axis": true,
  "axis_title_size": 16,
  "axis_text_size": 12,
  "axis_line_color": "#005BBB",
  "axis_line_width": 0.8,
  "axis_tick_show": true,
  "axis_tick_color": "#005BBB",
  "x_axis_text_angle": 30,
  "legend_position": "right",
  "legend_name": "DE status",
  "color_legend_name": "Custom log2FC legend",
  "size_legend_title": "-log10(Padjust)",
  "legend_title_size": 11,
  "legend_text_size": 10,
  "legend_bar_width": 0.35,
  "legend_bar_height": 2.4,
  "legend_key_size": 0.45,
  "legend_frame_color": "#111111",
  "legend_tick_color": "#111111",
  "show_threshold_lines": true,
  "threshold_line_color": "#333333",
  "threshold_line_type": "dashed",
  "threshold_line_width": 0.4,
  "show_zero_line": false,
  "show_grid": true,
  "panel_border": true,
  "x_min": -10,
  "x_max": 10,
  "y_min": 0,
  "y_max": 40
}
```

## Dynamic Venn Diagram Plugin

Path:

```text
plugins/dynamic_venn_diagram/plot.R
```

Run element-list mode:

```bash
Rscript plugins/dynamic_venn_diagram/plot.R \
  --input plugins/dynamic_venn_diagram/example_element_input.csv \
  --params plugins/dynamic_venn_diagram/example_params.json \
  --output /tmp/dynamic_venn_element_out
```

Run abundance-matrix mode:

```bash
Rscript plugins/dynamic_venn_diagram/plot.R \
  --input plugins/dynamic_venn_diagram/example_abundance_input.csv \
  --params plugins/dynamic_venn_diagram/example_abundance_params.json \
  --output /tmp/dynamic_venn_flower_out
```

Element-list input treats every selected column as a group and every non-empty cell as an element. If `groups_include` is omitted in `input_type: "element"` mode, all columns are used.

Abundance-matrix input treats `element_id_column`, default first column, as element IDs and selected numeric columns as groups. If `groups_include` is omitted in `input_type: "abundance"` mode, all columns except the ID column are used.

### Venn Core Params

```json
{
  "input_type": "auto",
  "groups_include": ["YF", "YC", "ZF"],
  "groups_exclude": [],
  "group_order": ["YF", "YC", "ZF"],
  "plot_mode": "auto",
  "element_id_column": "OTU",
  "abundance_operator": ">",
  "abundance_threshold": 0,
  "group_thresholds": {
    "YF": 5,
    "YC": 10
  },
  "group_operators": {
    "YF": ">",
    "YC": ">="
  }
}
```

`plot_mode: "auto"` draws a standard Venn for 1-5 selected groups and a flower Venn for 6 or more selected groups.

### Venn WYSIWYG Controls

```json
{
  "title": "Dynamic Venn diagram",
  "title_show": true,
  "title_size": 18,
  "palette_scheme": "bold",
  "set_colors": {
    "YF": "#69A4F9",
    "YC": "#BFE046",
    "ZF": "#EDAC2E"
  },
  "fill_alpha": 0.72,
  "border_color": "#FFFFFF",
  "border_width": 2.8,
  "border_lty": "solid",
  "show_counts": true,
  "show_percent": true,
  "count_size": 1.2,
  "group_name_size": 1.25,
  "group_name_color": "#222222",
  "show_group_names": true,
  "show_bar_chart": true,
  "bar_width": 0.55,
  "bar_height_ratio": 0.23,
  "flower_inner_gap": -0.04,
  "petal_length": 0.94,
  "petal_width": 0.38,
  "flower_count_mode": "set_size",
  "center_show": true,
  "center_fill": "#FFFFFF",
  "center_border_color": "#444444"
}
```

Successful runs also export `subsets.csv`, `subset_elements_long.csv`, and `set_sizes.csv`. Frontends can use these files for clicked-region details, subset downloads, and the bar chart below the Venn.

## FGSEA Enrichment Plot Plugin

Path:

```text
plugins/fgsea_enrichment_plot/plot.R
```

Run precomputed summary-table mode:

```bash
Rscript plugins/fgsea_enrichment_plot/plot.R \
  --input plugins/fgsea_enrichment_plot/example_fgsea_results.csv \
  --params plugins/fgsea_enrichment_plot/example_summary_params.json \
  --output /tmp/fgsea_summary_out
```

Run computed fgsea/running-curve mode:

```bash
Rscript plugins/fgsea_enrichment_plot/plot.R \
  --input plugins/fgsea_enrichment_plot/example_ranks.csv \
  --genesets plugins/fgsea_enrichment_plot/example_pathways.gmt \
  --params plugins/fgsea_enrichment_plot/example_running_params.json \
  --output /tmp/fgsea_running_out
```

Run the combined GSEA layout with a gradient-colored upper curve:

```bash
Rscript plugins/fgsea_enrichment_plot/plot.R \
  --input plugins/fgsea_enrichment_plot/example_ranks.csv \
  --genesets plugins/fgsea_enrichment_plot/example_pathways.gmt \
  --params plugins/fgsea_enrichment_plot/example_gradient_curve_params.json \
  --output /tmp/fgsea_combined_gradient_out
```

### FGSEA Input Modes

Precomputed mode accepts a table like an fgsea/GSEA report:

```json
{
  "input_mode": "precomputed",
  "plot_type": "summary",
  "term_col": "term",
  "nes_col": "NES",
  "fdr_col": "FDR q-val",
  "leading_genes_col": "Leading edge genes"
}
```

Compute mode accepts a marker/rank table and a GMT or term/gene file:

```json
{
  "input_mode": "compute",
  "plot_type": "running",
  "genesets_file": "pathways.gmt",
  "gene_col": "gene",
  "stat_col": "avg_log2FC",
  "comparison_col": "comparison",
  "selected_comparison": "Mut_vs_WT",
  "minSize": 10,
  "maxSize": 500,
  "nperm": 1000
}
```

### FGSEA Label And Style Controls

```json
{
  "selected_terms": ["UP_PATHWAY"],
  "top_n_terms": 20,
  "selected_genes": ["Gene001", "Gene021"],
  "label_top_x_genes": 3,
  "show_leading_gene_labels": true,
  "label_top_n_terms": 8,
  "leading_gene_label_n": 4,
  "label_placement": "side",
  "label_side": "right",
  "label_wrap_width": 26,
  "curve_color": "#63B33E",
  "curve_start_at_zero": true,
  "show_peak_marker": true,
  "show_peak_guides": true,
  "peak_marker_size": 3.4,
  "peak_guide_type": "dashed",
  "show_zero_cross": true,
  "zero_cross_label_prefix": "Zero cross at ",
  "show_correlation_labels": true,
  "show_hit_side_label": true,
  "hit_side_label": "MYC_samples_MSigDB",
  "rank_band_positive_color": "#C90000",
  "rank_band_negative_color": "#2D1693",
  "upper_curve_style": "gradient_curve",
  "gradient_colors": ["#7B00FF", "#55D6FF", "#70FF62", "#D3C800", "#FF0000"],
  "gradient_legend_title": "Rank Score",
  "show_gradient_curve_points": true,
  "label_all_hits": false,
  "label_arrow": true,
  "show_peak_label": true,
  "max_log10_value": 10,
  "x_column": "NES",
  "color_legend_name": "Direction",
  "size_legend_title": "-log10(FDR)",
  "curve_line_width": 1.1,
  "hit_line_width": 0.42,
  "legend_position": "bottom"
}
```

For the stacked running plot, use `upper_curve_style: "normal"` for the classic top curve or `upper_curve_style: "gradient_curve"` for the colored top curve while keeping the barcode and ranked-metric lower panels. Reserve `plot_type: "gradient_curve"` or `running_style: "gradient_only"` for the standalone one-panel curve.

Successful runs export `enrichment_results.csv`, `selected_terms.csv`, and `selected_genes.csv` for the table under the figure and selected-gene/term interactions.

## Advanced Dimension Plot Plugin

Path:

```text
plugins/advanced_dim_plot/plot.R
```

Run the main style examples:

```bash
Rscript plugins/advanced_dim_plot/plot.R \
  --input plugins/advanced_dim_plot/example_input.csv \
  --params plugins/advanced_dim_plot/example_group_params.json \
  --output /tmp/advanced_dim_group_out

Rscript plugins/advanced_dim_plot/plot.R \
  --input plugins/advanced_dim_plot/example_input.csv \
  --params plugins/advanced_dim_plot/example_feature_params.json \
  --output /tmp/advanced_dim_feature_out

Rscript plugins/advanced_dim_plot/plot.R \
  --input plugins/advanced_dim_plot/example_input.csv \
  --params plugins/advanced_dim_plot/example_split_highlight_params.json \
  --output /tmp/advanced_dim_split_out

Rscript plugins/advanced_dim_plot/plot.R \
  --input plugins/advanced_dim_plot/example_input.csv \
  --params plugins/advanced_dim_plot/example_density_hex_params.json \
  --output /tmp/advanced_dim_hex_out

Rscript plugins/advanced_dim_plot/plot.R \
  --input plugins/advanced_dim_plot/example_input.csv \
  --params plugins/advanced_dim_plot/example_coexpression_params.json \
  --output /tmp/advanced_dim_coexpression_out

Rscript plugins/advanced_dim_plot/plot.R \
  --input plugins/advanced_dim_plot/example_input.csv \
  --params plugins/advanced_dim_plot/example_lineage_params.json \
  --output /tmp/advanced_dim_lineage_out

plugins/advanced_dim_plot/run_all_examples.sh /Users/qzhang10/Documents/OmicsCanvas
plugins/advanced_dim_plot/run_pdf_matched_examples.sh /Users/qzhang10/Documents/OmicsCanvas
```

### Advanced Dim Core Params

```json
{
  "plot_mode": "group",
  "x_column": "dim1",
  "y_column": "dim2",
  "id_column": "cell",
  "group_column": "cluster",
  "split_column": "sample",
  "facet_split": true,
  "rows_include": ["Cell001", "Cell002"],
  "rows_exclude": ["Cell099"],
  "groups_include": ["B cell", "Myeloid"],
  "groups_exclude": ["Cycling"]
}
```

Supported `plot_mode` values are `group`, `feature`, `expression`, `gradient`, `coexpression`, `blend`, and `feature_mix`.

### Advanced Dim Style Controls

```json
{
  "title": "Custom embedding title",
  "subtitle": "Custom subtitle",
  "xlab": "UMAP 1",
  "ylab": "UMAP 2",
  "xlim": [-6, 6],
  "ylim": [-5, 5],
  "point_size": 0.9,
  "point_alpha": 0.85,
  "point_shape": 16,
  "group_palette": "Set2",
  "group_color_map": {"T cell": "#4E79A7", "B cell": "#F28E2B"},
  "feature_columns": ["CD3D", "MS4A1"],
  "feature_bg_cutoff": 0.05,
  "feature_colors": ["#F2F2F2", "#8BD3DD", "#4878D0", "#B40426"],
  "coexpression_colors": ["#E41A1C", "#377EB8", "#4DAF4A"],
  "color_mix_mode": "blend",
  "selected_labels": ["Cell012", "Cell090"],
  "highlight_rows": ["Cell012", "Cell090"],
  "highlight_fill": "#FFE45C",
  "show_mark": true,
  "mark_type": "hull",
  "show_density": true,
  "hex": false,
  "stat_plot_column": "sample",
  "show_stat_embedded": true,
  "show_stat_panel": false,
  "background_column": "module_score",
  "background_cutoff": 0.2,
  "raster": false,
  "raster_dpi": [1200, 1200],
  "legend_name": "Cell type",
  "legend_position": "bottom",
  "theme_use": "classic",
  "panel_border_show": true
}
```

Lineage/path overlays are passed as coordinate lists in params:

```json
{
  "lineages": [
    {"name": "trajectory A", "x": [-4, -2, 0, 2], "y": [2, 0, -1, 1]}
  ],
  "lineage_color_map": {"trajectory A": "#111111"},
  "lineage_line_width": 1.4,
  "lineage_arrow": true
}
```

Successful runs export `selected_rows.csv` for the table under the figure and click-selected/filtered rows.

## Smoke Test Expectations

After any plugin runs successfully, expect:

```text
result.svg
result.pdf
result.png
figure.json
run.log
```

Open or render `result.png` to confirm the requested visual change is present.
