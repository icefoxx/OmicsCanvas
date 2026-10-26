# R code shared by OmicsCanvas plugins

```text
R/
├── sca/            canonical SCA helper library, sourced by plugins (single copy)
├── runtime/        omicscanvas.Rprofile: seeds the RNG for every plugin run;
│                   also wraps htmlwidgets::saveWidget so missing pandoc does not fail the job
└── upstream_sca/   unmodified snapshot of the upstream SCA sources (reference only;
                    no plugin loads it)
```

## `R/sca/`

Plugins source the files they need into `.GlobalEnv`:

```r
helper_dir <- file.path(dirname(normalizePath(script_path, mustWork = FALSE)), '..', '..', 'R', 'sca')
if (!dir.exists(helper_dir)) helper_dir <- file.path('R', 'sca')
source(file.path(helper_dir, 'util.plot.R'), local = .GlobalEnv)
```

Sourcing into `.GlobalEnv` (rather than an R package namespace) is deliberate:
plugins install shims such as `paletteCustomize`, `ckPacsR`, `melt` and
`theme_scp` with `<<-`, and the helpers must resolve those through global lookup.

These files were consolidated from per-plugin `reference_sca_helpers/` copies.
Where copies had diverged, the bug-fixed superset was kept (`expStatPlot.R` from
exp_stat_plot, `statPlot.R` from stat_plot); all 88 examples of the 12 affected
plugins rendered pixel-identically before and after.

**Changing a file here affects every plugin that sources it.** Run the image
regression suite before committing:

```bash
python scripts/smoke_plugins.py --compare --jobs 6
```

| File | Used by |
| --- | --- |
| `GroupHeatmap.R` | group_heatmap |
| `GsDenPlot.R` | feature_density_plot |
| `Seuclu2Denplot.R` | cluster_dendrogram_plot |
| `VocalnoPlot.R` | sca_volcano_plot |
| `add.on.layers.4.dimplot.R` | advanced_dim_plot, advanced_feature_plot |
| `advDimPlot.R` | advanced_dim_plot |
| `advFeaPlot.R` | advanced_feature_plot |
| `common.plots.R` | den_plot |
| `expStatPlot.R` | advanced_dim_plot, advanced_feature_plot, exp_stat_plot, stat_plot |
| `jjplot2.R` | dot_plot |
| `lineagePlot.R` | lineage_plot |
| `statPlot.R` | advanced_dim_plot, advanced_feature_plot, stat_plot |
| `util.ck.R` | stat_plot |
| `util.ck_helpers.R` | sca_volcano_plot |
| `util.com.R` | stat_plot |
| `util.mat.R` | stat_plot |
| `util.plot.R` | advanced_dim_plot, advanced_feature_plot, exp_stat_plot, group_heatmap, lineage_plot, sca_volcano_plot, stat_plot |
| `util.scf_helpers.R` | sca_volcano_plot |
| `violinPlot.R` | (reference only) |
