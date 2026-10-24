# Den Plot

This plugin standardizes the SCA `common.plots.R` dendrogram utility. The current implemented slot is `column_dendrogram`, wrapping `plot.den.cols()`.

It plots a sample/column clustering dendrogram from a numeric matrix and draws a group annotation color bar plus sample labels underneath.

## Runtime

```bash
Rscript plugins/den_plot/plot.R \
  --input plugins/den_plot/example_matrix.csv \
  --annot plugins/den_plot/example_annotation.csv \
  --params plugins/den_plot/example_basic_params.json \
  --output /tmp/den_plot_basic_out
```

Every successful run writes:

- `result.svg`
- `result.pdf`
- `result.png`
- `figure.json`
- `matrix_used.csv`
- `annotation_used.csv`
- `run.log`

## Input

Matrix input:

```text
feature,S1,S2,S3,S4
GeneA,1.2,1.3,4.1,4.2
GeneB,0.5,0.6,2.4,2.2
```

Annotation input:

```text
sample,celltype,batch,condition
S1,T,B1,Control
S2,T,B1,Control
S3,B,B2,Treated
S4,B,B2,Treated
```

If `--annot` is omitted, all samples are assigned to `All`, or groups can be supplied through `group_assignments` in params.

## Main Params

```json
{
  "plot_kind": "column_dendrogram",
  "row_id_column": "feature",
  "sample_col": "sample",
  "group_col": "celltype",
  "distance_method": "euclidean",
  "cluster_method": "average"
}
```

## Customization

Sample/feature selection:

```json
{
  "sample_columns": ["S1", "S2", "S3", "S4"],
  "columns_exclude": ["S5"],
  "rows_include": ["GeneA", "GeneB"],
  "rows_exclude": ["GeneZ"]
}
```

Tree, color bar, and labels:

```json
{
  "title": "Sample clustering",
  "tile_height_ratio": 0.08,
  "point_size": 5,
  "label_size": 8,
  "x_text_angle": 45,
  "x_text_hjust": 1,
  "x_text_vjust": 1,
  "legend_title": "Cell type",
  "legend_size": 10,
  "legend_position": "right"
}
```

Group and sample-label colors:

```json
{
  "group_colors": {
    "T": "#4DBBD5",
    "B": "#E64B35",
    "Myeloid": "#00A087"
  },
  "x_text_color_col": "condition",
  "x_text_colors": {
    "Control": "#333333",
    "Treated": "#C1272D"
  },
  "show_x_text_legend": true,
  "x_text_legend_title": "Condition"
}
```

Output:

```json
{
  "width": 9,
  "height": 5.8,
  "dpi": 300
}
```

## Examples

Run all examples:

```bash
plugins/den_plot/run_all_examples.sh <repo-root>
```

This writes `/tmp/den_plot_*_out` and updates:

```text
plugins/den_plot/all_examples_gallery/all_den_plot_gallery.png
```
## Reproducible examples

Bundles are in `plugins/den_plot/examples/<id>/`. Each contains `params.json`, copied command inputs under `input/`, and `expected/result.png`. `manifest.json` is the machine-readable entry point and records how to rerun the example.

