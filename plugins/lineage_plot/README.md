# Lineage Plot

This plugin standardizes the SCA `lineagePlot.R::lineagePlot()` visual style for trajectory/pseudotime plots. It draws loess-fitted colored paths (with arrows) over a 2D embedding, one per lineage/pseudotime column, with an optional background stroke and optional whisker segments from fitted to raw points.

Because the original SCA function is Seurat-centric (it reads `seu@reductions` and `seu@meta.data`), this CLI plugin **reimplements** the core fitting/plotting algorithm (the `.curve.layer` block of `lineagePlot`) to operate on plain CSV inputs: an embedding matrix and a lineage/pseudotime table. The SCA visual style is preserved exactly: loess (degree=2, span) fitting, trim quantiles, `geom_path` background stroke, colored paths with arrows, `scale_color_manual` via `paletteCustomize`, and `themeDefault`/`themeBlank`.

The original SCA sources are copied under `reference_sca_helpers/` for fidelity (`util.plot.R` is sourced for `paletteCustomize`/`themeDefault`/`themeBlank`; `lineagePlot.R` is sourced for reference but not called).

## Runtime

```bash
Rscript plugins/lineage_plot/plot.R \
  --input plugins/lineage_plot/example_embedding.csv \
  --lineages plugins/lineage_plot/example_lineages.csv \
  --params plugins/lineage_plot/example_basic_params.json \
  --output /tmp/lineage_plot_basic_out
```

Every successful run writes:

- `result.svg`
- `result.pdf`
- `result.png`
- `figure.json`
- `selected_rows.csv`
- `run.log`

On failure it writes `error.json` with `error`, `detail`, and `suggestion` fields.

## Input format

Embedding (`--input`): first column = cell id, next two columns = dim1, dim2.

```text
cell,umap_1,umap_2
Cell1,0.16,-0.001
Cell2,-0.82,0.43
```

Lineage table (`--lineages`): first column = cell id, remaining columns = lineage/pseudotime values (column names = lineage names). Cells not on a lineage should have `NA`.

```text
cell,Lineage1,Lineage2,Lineage3
Cell1,0.07,0.05,0.09
Cell2,NA,NA,NA
```

Cell ids must match between the two files (matched by intersection).

## Main params

```json
{
  "title": "Lineage trajectories",
  "palette": "Dark2",
  "span": 0.75,
  "trim": [0.01, 0.99],
  "linewidth": 1,
  "line_bg": "white",
  "line_bg_stroke": 0.5,
  "whiskers": false,
  "lineages_arrow": true,
  "aspect_ratio": 1
}
```

## Customization

Lineage selection and cell filtering:

```json
{
  "lineages": ["Lineage1", "Lineage3"],
  "cells_include": ["Cell1", "Cell2"],
  "cells_exclude": ["Cell300"]
}
```

Colors per lineage:

```json
{
  "palette": "Dark2",
  "palcolor": {"Lineage1": "#E64B35", "Lineage2": "#4DBBD5", "Lineage3": "#00A087"}
}
```

Whiskers and stroke:

```json
{
  "whiskers": true,
  "whiskers_linewidth": 0.5,
  "whiskers_alpha": 0.5,
  "line_bg": "white",
  "line_bg_stroke": 0.5
}
```

Output:

```json
{
  "width": 7,
  "height": 6,
  "dpi": 300,
  "seed": 10086
}
```

## SCA compatibility notes

- Wraps `lineagePlot.R::lineagePlot` visual style (loess curves, colored paths with arrows, background stroke, `themeDefault`).
- `paletteCustomize` is patched to read `assets/palettes.rds` (same pattern as `exp_stat_plot`).
- The original `lineagePlot.R` has a dead/buggy first `fitted_list` lapply (references undefined `dat`/`axes`) and a buggy whiskers block (references `.df.ava[, "index"]` which does not exist). Only the `.curve.layer` logic is used; the whiskers block is fixed to use the raw embedding columns directly.
- Seurat-only arguments (`reduction`, `cells`, `theme.use`, `theme.args`) are not exposed; `theme.use` defaults to `themeDefault` (with `themeBlank` selectable).

## Examples

Run all examples:

```bash
plugins/lineage_plot/run_all_examples.sh /Users/qzhang10/Documents/OmicsCanvas
```

This writes `/tmp/lineage_plot_*_out` and updates:

```text
plugins/lineage_plot/all_examples_gallery/lineage_plot_gallery.png
```
## Reproducible examples

Bundles are in `plugins/lineage_plot/examples/<id>/`. Each contains `params.json`, copied command inputs under `input/`, and `expected/result.png`. `manifest.json` is the machine-readable entry point and records how to rerun the example.

