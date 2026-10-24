# Feature Density Plot

This plugin standardizes the SCA `GsDenPlot.R` density utilities (`GsDenPlot`, `plotFeatureDen`, `densityPlot`, `calDensity`). It computes a KNN-smoothed weighted kernel density estimate (KDE) of feature expression over a 2D reduction embedding and draws a viridis-colored scatter.

The original SCA function is Seurat-centric. For CLI use, this plugin adapts to CSV inputs: an expression matrix (features x cells) plus a cell embedding matrix (cells x 2 dims). Density is computed the same way (ks::hpi bandwidth, Matrix sparse weighted cross-product, dnorm kernels) and plotted with the same visual style (viridis density, blank panel, axis lines, strip fill `#ffe5cc`).

## Runtime

```bash
Rscript plugins/feature_density_plot/plot.R \
  --input plugins/feature_density_plot/example_expression.csv \
  --embed plugins/feature_density_plot/example_embedding.csv \
  --params plugins/feature_density_plot/example_basic_params.json \
  --output /tmp/feature_density_plot_basic_out
```

Every successful run writes:

- `result.svg`
- `result.pdf`
- `result.png`
- `figure.json`
- `selected_features.csv`
- `run.log`

On failure, an `error.json` with `{error, detail, suggestion}` is written instead.

## Inputs

Expression matrix (`--input`):

```text
feature,Cell001,Cell002,Cell003
GeneA,2.5,0.2,2.6
GeneB,0.3,2.4,0.2
```

Embedding (`--embed`):

```text
cell,UMAP_1,UMAP_2
Cell001,-3.1,-2.0
Cell002,3.0,2.1
Cell003,-2.9,-1.8
```

Cell ids in the embedding first column must match the expression column names.

## Key Parameters

- Data: `feature_id_column`, `cell_id_column`, `dim1_column`, `dim2_column`, `features` (REQUIRED), `cells_include`, `cells_exclude`, `features_include`, `features_exclude`
- Plot mode: `scale01`, `coexpression`, `raster`, `bias`, `cells_knn`
- Labels: `title`, `xlab`, `ylab`, `title_show`, `xlab_show`, `ylab_show`, `legend_name`
- Typography: `font_family`, `font_size`, `base_size`, `title_size`, `axis_label_size`, `x_axis_text_size`, `y_axis_text_size`
- Colors: `palette` (turbo/viridis/plasma/magma/inferno/cividis), `point_color`, `strip_fill`
- Layers: `point_size`, `point_shape`, `point_alpha`, `axis_line_size`
- Legends: `legend_show`, `legend_position`, `legend_title_size`, `legend_text_size`, `colorbar_width`, `colorbar_height`
- Output: `width`, `height`, `dpi`
- Selectors: `highlight_cells`, `highlight_color`, `highlight_size`, `highlight_shape`, `highlight_alpha`

## Co-expression

When more than one feature is supplied, densities are multiplied across features to produce a co-expression density. Set `coexpression: false` to disable, or `scale01: true` to normalize the resulting density to 0-1.

## SCA Compatibility

The SCA helper functions are copied verbatim into `R/sca/GsDenPlot.R` and sourced locally. The original SCA files in the upstream SCA library (snapshot in `R/upstream_sca/`) are not modified. The Seurat-specific `GsDenPlot()` wrapper is not used by the CLI; only `plotFeatureDen`, `densityPlot`, `calDensity`, and `scale01` are invoked.

## Examples

Run all examples:

```bash
plugins/feature_density_plot/run_all_examples.sh <repo-root>
```

This writes `/tmp/feature_density_plot_*_out` and updates:

```text
plugins/feature_density_plot/all_examples_gallery/feature_density_plot_gallery.png
```
## Reproducible examples

Bundles are in `plugins/feature_density_plot/examples/<id>/`. Each contains `params.json`, copied command inputs under `input/`, and `expected/result.png`. `manifest.json` is the machine-readable entry point and records how to rerun the example.

