# Violin Plot

This plugin standardizes the SCA `violinPlot.R::classicVlnPlot()` visual style for CLI use.

The original `classicVlnPlot` is Seurat-centric (it uses `ckFeas`, which reads `seu@assays`), so it cannot be called directly on CSV inputs. This plugin REIMPLEMENTS the same ggplot2 layers and SCA visual style (right-side y axis with the SCA label trick, blank panel with black border, bold strip text, optional boxplot/median/dot overlays, optional annotation tile strip via patchwork) operating directly on a long-format data frame. The original SCA source is preserved in `R/sca/violinPlot.R` for reference only.

## Runtime

```bash
Rscript plugins/violin_plot/plot.R \
  --input plugins/violin_plot/example_long.csv \
  --params plugins/violin_plot/example_basic_params.json \
  --output /tmp/violin_plot_basic_out
```

For `wide_matrix` / `wide_cells` modes, also pass `--annot`:

```bash
Rscript plugins/violin_plot/plot.R \
  --input plugins/violin_plot/example_matrix.csv \
  --annot plugins/violin_plot/example_annotation.csv \
  --params plugins/violin_plot/example_anno_params.json \
  --output /tmp/violin_plot_anno_out
```

Every successful run writes:

- `result.svg`
- `result.pdf`
- `result.png`
- `figure.json`
- `selected_rows.csv`
- `run.log`

On failure it writes `error.json` with `{error, detail, suggestion}`.

## Input formats

### `long` (default)

A long-format table with columns `cell, gene, value, cluster` (column names configurable via `cell_id_column`, `feature_column`, `value_column`, `group_column`). An optional `annotation_column` provides per-feature annotation for the annotation strip.

```text
cell,gene,value,cluster
C001,CD3D,3.62,T_CD4
C002,CD3D,2.46,T_CD4
```

### `wide_matrix`

A features x cells expression matrix (first column is the feature id) plus an annotation file (`--annot`) with a cell id column and a group column.

```text
feature,C001,C002,...
CD3D,3.41,3.34,...
```

### `wide_cells`

A cells x features expression table (first column is the cell id) plus an annotation file (`--annot`) with a cell id column and a group column.

## Main parameters (grouped)

### data
`input_mode` (long/wide_matrix/wide_cells), `cell_id_column`, `feature_column`, `value_column`, `group_column` (required), `annotation_column`, `rows_include`, `rows_exclude`, `features_include`, `features_exclude`.

### plot_mode
`add_dot` (bool), `add_stat` (boxplot/median/none), `add_anno` (bool).

### labels
`title`, `xlab`, `ylab`, `title_show`, `xlab_show`, `ylab_show`, `y_anno_label`.

### typography
`font_family`, `font_size`, `base_size`, `title_size`, `axis_label_size`, `x_axis_text_size`, `x_axis_text_angle` (default 45), `y_axis_text_size`, `strip_text_size`.

### colors
`group_colors` (named vector for violin fills), `point_color`, `point_size` (psize, default 0.5), `anno_colors` (named for annotation strip).

### layers
`violin_scale` (default "width"), `violin_adjust` (default 1), `violin_trim` (bool, default TRUE), `violin_alpha`, `boxplot_width` (default 0.1), `boxplot_outlier_size`, `median_point_size`, `dot_size` (default 0.1), `rotate_x` (bool, default FALSE).

### legends
`legend_show` (default FALSE — original has `legend.position="none"`), `legend_position`.

### output
`width`, `height`, `dpi`.

### selectors
`highlight_features`, `highlight_color`.

## SCA compatibility notes

- Preserves the SCA right-side y axis with the label trick (`scale_y_continuous(position="right", labels=...)`).
- Preserves `geom_violin(scale="width", adjust=1, trim=TRUE)`.
- Optional `geom_boxplot(width=0.1, position=position_dodge(0.9))` or `stat_summary` median point.
- Optional `geom_quasirandom(dodge.width=0.9, varwidth=TRUE, size=0.1)`.
- `facet_grid(rows=vars(group), scales="free")`.
- Theme: `legend.position="none"`, `panel.background=element_rect(fill=NA, color="black")`, `strip.background=element_rect(fill="white")`, `strip.text=element_text(face="bold")`, `strip.text.y.right=element_text(angle=0)`, `axis.text.x=element_text(angle=45, hjust=1, vjust=1, color="black")`.
- Optional annotation tile strip combined via patchwork `plot_layout(heights=c(20,1))`; x-axis text removed from the main plot when the annotation strip is shown.

## Examples

Run all examples:

```bash
plugins/violin_plot/run_all_examples.sh <repo-root>
```

This writes `/tmp/violin_plot_*_out` and updates:

```text
plugins/violin_plot/all_examples_gallery/violin_plot_gallery.png
```
## Reproducible examples

Bundles are in `plugins/violin_plot/examples/<id>/`. Each contains `params.json`, copied command inputs under `input/`, and `expected/result.png`. `manifest.json` is the machine-readable entry point and records how to rerun the example.

