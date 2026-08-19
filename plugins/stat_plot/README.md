# Stat Plot

This plugin standardizes the SCA `statPlot.R::statPlot()` engine. It takes a metadata table, computes counts or percentages of `stat_by` levels within `group_by` groups (optionally split by `split_by`, with an optional background grouping `bg_by`), and produces a wide range of plot types:

`bar`, `rose`, `ring`, `pie`, `trend`, `area`, `dot`, `sankey`, `chord`, `venn`, `upset`.

It preserves the SCA visual style (`themeDefault`, `paletteCustomize`).

## Runtime

```bash
Rscript plugins/stat_plot/plot.R \
  --input plugins/stat_plot/example_metadata.csv \
  --params plugins/stat_plot/example_bar_params.json \
  --output /tmp/stat_plot_bar_out
```

Every successful run writes:

- `result.svg`
- `result.pdf`
- `result.png`
- `figure.json`
- `selected_rows.csv`
- `run.log`

On failure an `error.json` with `error`, `detail`, `suggestion` is written instead, and stale `error.json` is removed on success.

## Input

Metadata input (CSV/TSV/TXT). Rows are cells/samples; columns are categorical/numeric variables. The first column is used as the row id by default (override with `id_column`).

```text
cell_id,cluster,sample,condition,phase,lineage
C0001,NK,S3,Healthy,G1,Lymphoid
C0002,T,S1,Healthy,G2M,Lymphoid
C0003,T,S3,Disease,G2M,Lymphoid
```

## Key Parameters (grouped)

### data
- `stat_by` (REQUIRED): one or more metadata columns whose level counts/percentages are plotted.
- `group_by`: primary grouping column. If omitted, all rows form a single group.
- `split_by`: optional facet/split column (one panel per level).
- `bg_by`: optional background grouping column.
- `id_column`, `rows_include`, `rows_exclude`, `stat_level` (venn/upset), `keep_na`, `keep_empty`, `each`, `force`.

### plot_mode
- `plot_type`: bar/rose/ring/pie/trend/area/dot/sankey/chord/venn/upset.
- `stat_type`: percent or count.
- `position`: stack or dodge.
- `flip`, `combine`, `nrow`, `ncol`, `byrow`.

### labels
- `title`, `subtitle`, `xlab`, `ylab`, `title_show`, `subtitle_show`, `xlab_show`, `ylab_show`, `legend_name`, `show_label`.

### typography
- `font_family`, `font_size`, `base_size`, `title_size`, `axis_label_size`, `x_axis_text_size`, `x_axis_text_angle`, `y_axis_text_size`, `label_size`, `label_fg`, `label_bg`, `label_bg_r`.

### colors
- `palette`, `palcolor`, `color_na`, `palette_bg`, `palcolor_bg`, `alpha`, `alpha_bg`, `panel_fill`, `plot_fill`.

### layers
- `aspect_ratio` (auto-set to 1 for rose/ring/pie).

### legends
- `legend_position`, `legend_direction`, `legend_title_size`, `legend_text_size`, `legend_key_size`.

### output
- `width`, `height`, `dpi`, `seed`.

## Examples

Run all examples:

```bash
plugins/stat_plot/run_all_examples.sh /Users/qzhang10/Documents/OmicsCanvas
```

This writes `/tmp/stat_plot_*_out` and updates:

```text
plugins/stat_plot/all_examples_gallery/stat_plot_gallery.png
```

## SCA Compatibility Notes

- Wraps `statPlot.R::statPlot()` plus SCA helpers `formatDF4statPlot`, `paletteCustomize`, `themeDefault`, `blendcolors`, `toUpperX`, `get_legend.local`, `add_grob.local`, `ckPacsR` (copied locally under `reference_sca_helpers/`).
- `paletteCustomize` is patched to read `assets/palettes.rds` by default.
- `ckPacsR` is overridden with a non-installing stub so CLI runs never trigger interactive package installation.
- `force` is always `TRUE` in CLI mode to avoid the interactive `>100 levels` prompt.
- `chord` uses base graphics via `recordPlot()`; the wrapper replays the recorded plot onto each output device (svg/pdf/png).
- One local compatibility patch was applied to the copied `statPlot.R`: a dead, erroring line in the sankey legend block (`legend <- do.call(cbind, .legend.sankey)` after `rbind`, where the `legend` variable is never used downstream) was removed so sankey renders standalone. The original SCA files under `/Users/qzhang10/workstation/development/SCA/` are not modified.
## Reproducible examples

Bundles are in `plugins/stat_plot/examples/<id>/`. Each contains `params.json`, copied command inputs under `input/`, and `expected/result.png`. `manifest.json` is the machine-readable entry point and records how to rerun the example.

