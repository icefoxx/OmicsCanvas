---
name: omics-plot-plugins
description: Build, modify, parameterize, document, and test OmicsCanvas BioFigureAI R plot plugins for interactive biomedical visualizations. Use for the intragroup/cross-matrix correlation heatmap plugin and the highly customized volcano plot plugin, including params.json design, WYSIWYG controls, dendrograms, group annotation tracks, selected labels, color palettes, and standard plugin outputs.
---

# Omics Plot Plugins

This is an agent-agnostic skill. Any coding agent can use it by reading this file, then loading `references/plugin-guide.md` when exact parameters or examples are needed.

## Supported Plugins

- `plugins/intragroup_correlation/plot.R`
- `plugins/volcano_plot/plot.R`
- `plugins/threshold_matrix_heatmap/plot.R`
- `plugins/ranked_annotation_panel/plot.R`
- `plugins/quadrant_correlation_scatter/plot.R`
- `plugins/dynamic_venn_diagram/plot.R`
- `plugins/fgsea_enrichment_plot/plot.R`
- `plugins/advanced_dim_plot/plot.R`

Both plugins follow the BioFigureAI runtime contract:

```bash
Rscript plot.R --input input.csv --params params.json --output output_dir
```

The correlation plugin also supports two input matrices:

```bash
Rscript plugins/intragroup_correlation/plot.R \
  --input matrix1.csv \
  --input2 matrix2.csv \
  --params params.json \
  --output output_dir
```

Every successful run should create:

```text
result.svg
result.pdf
result.png
figure.json
run.log
```

Failures should create:

```text
error.json
```

## Agent Workflow

1. Work from the repository root.
2. Inspect the target plugin before editing.
3. Keep user-adjustable behavior in `params.json`; do not hard-code visual settings.
4. Preserve CSV/TSV/TXT support, column mapping, and the output contract.
5. For UI click selectors, map selections to include/exclude arrays instead of changing uploaded data.
6. After edits, run at least one smoke test and inspect `result.png` for visual changes.
7. Keep `figure.json` updated with meaningful `analysis`, `style`, `data`, `layers`, and `export` metadata.

## When To Read The Reference

Read `references/plugin-guide.md` for:

- exact parameter names
- example `params.json` blocks
- one-matrix and two-matrix correlation examples
- dendrogram/tree customization
- row/column group color tracks
- sample/gene label coloring
- volcano category/gradient color modes
- volcano arbitrary `x_column`/`y_column` mappings and x/y transforms
- volcano region-specific rules for color, size, shape, outline, alpha, and region legends
- volcano brush/selection regions, selected row tables, draggable label coordinates, and label indicator styling
- volcano selected labels and connector lines
- threshold matrix heatmap row/column selection, row-label column mapping, semicolon cutoff rules, per-column colors, and shape/legend controls
- ranked annotation panel left-value selection, right-panel annotation columns, mixed continuous/discrete palettes, row selection, and multi-legend controls
- quadrant correlation scatter x/y selection, 4/9/custom regions, threshold lines, correlation labels, selected dot labels, and legend controls
- dynamic Venn diagram element-list and abundance-matrix input modes, group include/exclude selectors, 2-5 set Venns, 6+ flower Venns, counts, percentages, bar charts, colors, borders, and subset element exports
- fgsea enrichment plot precomputed result-table mode, rank-table compute mode, GMT/term-gene inputs, running-score curves, top/selected gene labels, leading-edge labels, and summary dot/lollipop controls
- advanced dimension plot dim1/dim2 embeddings, group colors, feature gradients, split panels, selected labels, highlights, density/hex modes, hull/ellipse marks, coexpression color mixing, and lineage paths
- smoke test commands

## Parameter Naming Conventions

Prefer stable UI-bindable names:

- Visibility: `title_show`, `show_value`, `show_p_mark`, `show_row_dendrogram`
- Sizes: `row_name_size`, `column_name_size`, `cell_text_size`, `point_size`, `label_size`
- Colors: `up_color`, `down_color`, `row_tree_color`, `sample_label_colors`
- Labels: `title`, `x_title`, `y_title`, `legend_name`, `color_legend_name`, `size_legend_title`
- Axes: `x_min`, `x_max`, `y_min`, `y_max`, `show_x_axis`, `show_y_axis`, `axis_line_color`
- Legends: `legend_position`, `legend_bar_width`, `legend_bar_height`, `legend_frame_color`, `legend_tick_color`
- Selection: `*_include`, `*_exclude`, `selected_genes`, `highlight_rows`, `highlight_columns`
- Threshold matrix: `row_label_column`, `value_columns`, `default_rules`, `column_rules_string`, `cell_shape`
- Ranked annotation panel: `left_value_column`, `annotation_columns`, `annotation_settings`, `left_panel_width`, `annotation_panel_width`
- Quadrant scatter: `x_column`, `y_column`, `quadrant_mode`, `x_thresholds`, `y_thresholds`, `quadrant_colors`
- Dynamic Venn: `input_type`, `groups_include`, `groups_exclude`, `element_id_column`, `abundance_threshold`, `plot_mode`, `set_colors`, `show_percent`, `show_bar_chart`
- FGSEA: `input_mode`, `plot_type`, `term_col`, `nes_col`, `fdr_col`, `leading_genes_col`, `genesets_file`, `gene_col`, `stat_col`, `selected_terms`, `selected_genes`, `label_top_x_genes`
- Advanced dimension plot: `plot_mode`, `x_column`, `y_column`, `id_column`, `group_column`, `split_column`, `feature_columns`, `selected_labels`, `highlight_rows`, `show_mark`, `hex`
- Volcano regions: `regions`, `condition`, `xmin`, `xmax`, `ymin`, `ymax`, `fill`, `outline_color`, `shape`, `size`
- Volcano row selection: `selection_regions`, `selected_ids`, `selected_point_styles`, `label_x`, `label_y`, `indicator_color`
- Layout: `width`, `height`, `label_angle`, `legend_position`

Use aliases only for compatibility; document the canonical param in `references/plugin-guide.md`.

## Validation Checklist

Before reporting completion:

- Confirm the R command exits with status 0.
- Confirm `result.svg`, `result.pdf`, `result.png`, `figure.json`, and `run.log` exist.
- Open or render `result.png`.
- Check `figure.json` reflects the requested analysis and styling controls.
- If editing dendrogram behavior, test `show_row_dendrogram` and `show_column_dendrogram`.
- If editing two-matrix correlation, test `--input2` or `input2_file`.
