# Dot Plot

This plugin standardizes the SCA `jjplot2.R` dot plot utilities (`custDotplot` and `jjDotPlot1`).

It produces a customizable dot plot where point size maps to one column (e.g. percent expressed) and point fill maps to another column (e.g. scaled average expression) using a gradient or gradient2 color scale, with optional dendrograms on the x and/or y axes.

## Runtime

```bash
Rscript plugins/dot_plot/plot.R \
  --input plugins/dot_plot/example_input.csv \
  --params plugins/dot_plot/example_basic_params.json \
  --output /tmp/dot_plot_basic_out
```

Aggregate mode (expression matrix + annotation):

```bash
Rscript plugins/dot_plot/plot.R \
  --input plugins/dot_plot/example_matrix.csv \
  --annot plugins/dot_plot/example_annotation.csv \
  --params plugins/dot_plot/example_aggregate_params.json \
  --output /tmp/dot_plot_aggregate_out
```

Every successful run writes:

- `result.svg`
- `result.pdf`
- `result.png`
- `figure.json`
- `run.log`
- `selected_rows.csv` (when row/feature filtering is applied)

On failure an `error.json` is written with `error`, `detail`, and `suggestion` fields.

## Input formats

### precomputed (default)

A long/tidy data frame with x, y, size.by, and fill.by columns:

```text
cluster,gene,avg.exp.scaled,pct.exp
Naive CD4 T,CD3D,2.30,88.79
Naive CD4 T,CD3E,1.94,84.13
```

This is fed directly to `custDotplot`.

### aggregate

An expression matrix (genes x cells, first column is the gene id) plus an annotation file with a cell id column and a cluster column:

```text
gene,Cell001,Cell002,...
CD3D,16.45,0,...
CD3E,2.68,0,...
```

```text
cell,cluster,batch
Cell001,CD8 T,B2
Cell002,B,B2
```

The plugin computes per-cluster `avg.exp` (mean of `expm1`), `pct.exp` (`Seurat::PercentAbove > 0 * 100`), scales per gene (z-score then `Seurat::MinMax` or `scales::rescale`), and builds a tidy data frame with columns `cluster`, `gene`, `avg.exp.scaled`, `pct.exp` before calling `custDotplot`.

## Main params

```json
{
  "input_mode": "precomputed",
  "x_column": "gene",
  "y_column": "cluster",
  "size_by": "pct.exp",
  "fill_by": "avg.exp.scaled",
  "dot_col": ["#2b6cb0", "white", "#c53030"],
  "midpoint": 0,
  "dot_min": 1,
  "dot_max": 8
}
```

## Customization

Dendrograms:

```json
{
  "ytree": true,
  "xtree": true,
  "tree_pos": ["right", "top"],
  "same_pos_label": false,
  "cluster_method": "average",
  "distance_method": "euclidean"
}
```

Labels, typography, legends:

```json
{
  "title": "Marker expression by cluster",
  "xlab": "Gene",
  "ylab": "Cluster",
  "base_size": 14,
  "x_text_angle": 45,
  "y_text_size": 11,
  "title_size": 16,
  "legend_position": "right",
  "legend_direction": "vertical",
  "fill_legend_title": "Avg expression (scaled)",
  "size_legend_title": "Percent expressed (%)",
  "colorbar_width": 1.5
}
```

Selectors:

```json
{
  "top_n": 10,
  "top_by": "avg.exp.scaled",
  "top_abs": true,
  "highlight_features": ["CD3D", "CD8A"],
  "highlight_color": "#E64B35"
}
```

Output:

```json
{
  "width": 9,
  "height": 5.5,
  "dpi": 300
}
```

## SCA compatibility

The plugin copies `jjplot2.R` into `reference_sca_helpers/` and sources it locally. `custDotplot` is used for plotting; `jjDotPlot1`'s aggregation logic is reproduced in the plugin for matrix-plus-annotation input. The SCA visual style (theme_bw, black axis text, gradient fill, size legend) is preserved.

## Examples

Run all examples:

```bash
plugins/dot_plot/run_all_examples.sh /Users/qzhang10/Documents/OmicsCanvas
```

This writes `/tmp/dot_plot_*_out` and updates:

```text
plugins/dot_plot/all_examples_gallery/dot_plot_gallery.png
```
## Reproducible examples

Bundles are in `plugins/dot_plot/examples/<id>/`. Each contains `params.json`, copied command inputs under `input/`, and `expected/result.png`. `manifest.json` is the machine-readable entry point and records how to rerun the example.

