# Cluster Dendrogram Plot

This plugin standardizes the SCA `Seuclu2Denplot.R` workflow (`Seuclu2Denplot` + `plot.den.cols`) for CSV/CLI inputs (no Seurat object required).

It computes per-sample average expression per cluster from an expression matrix + cell metadata, joins those profiles across samples, then draws a sample-cluster dendrogram with a group color bar and sample labels underneath.

## Runtime

```bash
Rscript plugins/cluster_dendrogram_plot/plot.R \
  --input plugins/cluster_dendrogram_plot/example_expression.csv \
  --annot plugins/cluster_dendrogram_plot/example_annotation.csv \
  --params plugins/cluster_dendrogram_plot/example_basic_params.json \
  --output /tmp/cluster_dendrogram_plot_basic_out
```

Every successful run writes:

- `result.svg`
- `result.pdf`
- `result.png`
- `figure.json`
- `matrix_used.csv` (the per-sample-cluster average expression matrix used for clustering)
- `annotation_used.csv` (the sample-cluster annotation: `Sample_Group`, `cellCluster`, `Sample`)
- `run.log`

On failure, an `error.json` with `error`, `detail`, `suggestion` is written instead.

## Input

Expression matrix (`--input`): first column is the feature/gene id, remaining columns are cells.

```text
feature,S1_C0_1,S1_C0_2,...
Gene01,2.3,2.1,...
Gene02,0.1,0.2,...
```

Cell metadata (`--annot`): first column is the cell id; must contain a sample column and a cluster column.

```text
cell_id,sample,cluster
S1_C0_1,S1,0
S1_C0_2,S1,0
```

## Main Params

```json
{
  "sample_column": "sample",
  "cluster_column": "cluster",
  "distance_method": "euclidean",
  "cluster_method": "average",
  "title": "Dendrogram for clusters in samples"
}
```

## Customization

Sample/cluster/feature selection:

```json
{
  "samples_include": ["S1", "S2"],
  "samples_exclude": ["S3"],
  "clusters_include": ["0", "1"],
  "clusters_exclude": ["3"],
  "features_include": ["Gene01", "Gene02"],
  "features_exclude": ["Gene15"]
}
```

Tree, color bar, and labels:

```json
{
  "title": "Sample-cluster clustering",
  "tile_height_ratio": 0.08,
  "point_size": 5,
  "label_size": 8,
  "x_text_angle": 45,
  "x_text_hjust": 1,
  "x_text_vjust": 1,
  "legend_title": "sample",
  "legend_size": 10,
  "legend_position": "right"
}
```

Group and sample-label colors:

```json
{
  "group_colors": { "S1": "#4DBBD5", "S2": "#E64B35", "S3": "#00A087" },
  "x_text_color_by": "cluster",
  "x_text_colors": { "0": "#F0E442", "1": "#0072B2", "2": "#D55E00", "3": "#CC79A7" },
  "x_text_legend_title": "cluster",
  "show_x_text_legend": true
}
```

Output:

```json
{
  "width": 9,
  "height": 6,
  "dpi": 300
}
```

## SCA Compatibility

This plugin wraps the SCA `Seuclu2Denplot.R` helpers (`Seuclu2Denplot`, `plot.den.cols`). The original `Seuclu2Denplot` is Seurat-centric (uses `Seurat::AverageExpression`); this plugin reimplements the per-sample cluster averaging workflow using CSV inputs (`rowMeans` of expression sub-matrices) and then calls `plot.den.cols` directly. The local copy of `plot.den.cols` under `reference_sca_helpers/` is patched to accept an optional `group_colors` argument (the SCA original auto-assigns colors via RColorBrewer/rainbow). The SCA original is not modified.

## Examples

Run all examples:

```bash
plugins/cluster_dendrogram_plot/run_all_examples.sh /Users/qzhang10/Documents/OmicsCanvas
```

This writes `/tmp/cluster_dendrogram_plot_*_out` and updates:

```text
plugins/cluster_dendrogram_plot/all_examples_gallery/cluster_dendrogram_plot_gallery.png
```
## Reproducible examples

Bundles are in `plugins/cluster_dendrogram_plot/examples/<id>/`. Each contains `params.json`, copied command inputs under `input/`, and `expected/result.png`. `manifest.json` is the machine-readable entry point and records how to rerun the example.

