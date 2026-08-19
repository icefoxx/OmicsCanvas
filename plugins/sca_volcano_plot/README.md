# SCA Volcano Plot

This plugin wraps the SCA `VocalnoPlot.R` functions (`volcanoPlot`, `avgVolcano`, `percentVocalno`) into a standardized OmicsCanvas plot plugin with a stable table/JSON interface.

It preserves the original SCA visual style (`themeDefault`, gradient color, `ggrepel` labels) while exposing all major controls through `params.json`.

## Runtime

```bash
Rscript plugins/sca_volcano_plot/plot.R \
  --input plugins/sca_volcano_plot/example_markers.csv \
  --params plugins/sca_volcano_plot/example_basic_params.json \
  --output /tmp/sca_volcano_plot_basic_out
```

Every successful run writes:

- `result.svg`
- `result.pdf`
- `result.png`
- `figure.json`
- `run.log`
- `result.html` (static metadata link, when emitted by the current plugin contract)
- `selected_points.csv` (when `selected_genes` / `features_label` are provided)

On failure an `error.json` with `error`, `detail`, `suggestion` is written instead.

## Input

A marker/differential table (CSV/TSV/TXT). Required columns (aliases autodetected):

```text
gene, avg_log2FC, p_val_adj, pct.1, pct.2
```

Optional columns:

```text
cluster   -> used by avg_volcano / percent_volcano (cluster.key)
split.by  -> used by volcano mode for facetting
```

Example header:

```text
gene,cluster,avg_log2FC,p_val_adj,pct.1,pct.2
GENE001,Naive CD4 T,1.23,0.001,0.45,0.10
```

## plot_kind

| plot_kind        | SCA function     | Description                                                       |
|------------------|------------------|-------------------------------------------------------------------|
| `volcano`        | `volcanoPlot`    | Gradient volcano with DE highlight and top-N repel labels.       |
| `avg_volcano`    | `avgVolcano`     | Per-cluster average volcano with jittered points and tiles.      |
| `percent_volcano`| `percentVocalno` | Facetted volcano with pct.1-pct.2 on x and dashed log2FC hlines. |

## Key parameters (grouped)

**data**: `gene_column`, `log2fc_column`, `pval_column`, `pct1_column`, `pct2_column`, `cluster_column`, `split_column`, `rows_include`, `rows_exclude`, `features_include`, `features_exclude`.

**plot_mode**: `plot_kind`, `de_expr`, `x2y`, `keep_all`, `threshold`, `qval_threshold`, `highlight_n`, `rank_by`, `cluster_order`.

**labels**: `title`, `subtitle`, `xlab`, `ylab`, `title_show`.

**typography**: `base_size`, `font_family`, `font_size`, `title_size`, `axis_label_size`, `x_axis_text_size`, `x_axis_text_angle`, `label_size`.

**colors**: `de_colors` (named: sigDown, sigUp, Nonsig), `palette`, `palcolor`, `facet_color`, `facet_fill`, `label_fg`, `label_bg`, `highlight_color`, `cols_highlight`, `sizes_highlight`.

**layers**: `pt_size`, `pt_alpha`, `stroke_highlight`, `alpha_highlight`, `hline_size`, `hline_color`, `pforce`, `nforce`, `nudge_x`, `pnudge_y`, `nnudge_y`.

**annotations**: `features_label`, `selected_genes`, `selected_points`.

For `plot_kind: volcano`, `region_annotations` accepts a JSON array of region objects, or use `region_annotations_file` for CSV/TSV. Region boundaries support numeric values and `-threshold`, `threshold`, `x_min`, `x_max`, `y_min`, `y_max`, `-Inf`, `Inf`, and `threshold_y`. Use `default_volcano_regions` plus `default_region_labels`, `default_region_fills`, `default_region_alpha`, and `default_region_label_positions` for optional four-region backgrounds. `point_groups` accepts gene/feature lists and overrides ordinary point colors; `features_label` remains supported.

The reproducible customization example is `example_regions_params.json` with `example_regions.csv`. Region rectangles are ordered by `z_order`; labels are rendered after points. `figure.json` records resolved regions, point groups, axis limits, and precedence.

**legends**: `legend_position`, `legend_direction`, `legend_title_size`, `legend_text_size`, `colorbar_width`.

**output**: `width`, `height`, `dpi`, `nrow`, `ncol`, `byrow`, `aspect_ratio`.

## SCA compatibility notes

- `VocalnoPlot.R` is copied verbatim into `reference_sca_helpers/`.
- `topMarkers.seu` (from `util.scf.R`) and `ckCols` (from `util.ck.R`) are copied locally; `topMarkers.seu` uses `group_by(.data[[selection]], .data[['UpDown']])` instead of the original `c(...)` form to work with current dplyr.
- `paletteCustomize` / `themeDefault` are copied from `util.plot.R`; `paletteCustomize` is patched at runtime to read `assets/palettes.rds` from the OmicsCanvas root.
- `palette_scp` is not defined in SCA source, so a local fallback maps common palette names (RdBu, Spectral, viridis options) via `RColorBrewer` / `viridisLite`.
- `scale01` is defined locally (used by `volcanoPlot`).

## Examples

Run all examples:

```bash
plugins/sca_volcano_plot/run_all_examples.sh /Users/qzhang10/Documents/OmicsCanvas
```

This writes `/tmp/sca_volcano_plot_*_out` and updates:

```text
plugins/sca_volcano_plot/all_examples_gallery/sca_volcano_plot_gallery.png
```
## Reproducible examples

Bundles are in `plugins/sca_volcano_plot/examples/<id>/`. Each contains `params.json`, copied command inputs under `input/`, and `expected/result.png`. `manifest.json` is the machine-readable entry point and records how to rerun the example.
