# OmicsCanvas R Function Layout

This folder organizes plotting-software functions copied from `/Users/qzhang10/workstation/development/SCA`.

## Directory Tree

```text
R/
├── data_format_validation/
│   ├── plotdata.prep.seu.R
│   ├── util.ck.R
│   ├── util.ck.seu.R
│   ├── util.fun.sc.R
│   ├── util.mat.R
│   └── util.scf.R
├── basic_plots/
│   ├── DotPlot.R
│   ├── GsDenPlot.R
│   ├── VocalnoPlot.R
│   ├── add.on.layers.4.dimplot.R
│   ├── common.plots.R
│   ├── graphical.funs.R
│   ├── statPlot.R
│   ├── util.plot.R
│   └── violinPlot.R
├── advanced_plots/
│   ├── GroupHeatmap.R
│   ├── advDimPlot.R
│   ├── advFeaPlot.R
│   ├── expStatPlot.R
│   └── lineagePlot.R
└── load_plot_functions.R
```

## Categories

- `data_format_validation`: data extraction, matrix conversion, Seurat object checks, feature validation, package/path checks, and plot-ready data preparation.
- `basic_plots`: reusable themes, palettes, legends, low-level grob helpers, dot plots, volcano plots, density plots, violin plots, and other direct plot builders.
- `advanced_plots`: higher-level plotting interfaces that compose data preparation, plot layers, annotations, facets, legends, heatmaps, and multi-panel outputs.

## Source Map

| Local file | Original source |
| --- | --- |
| `R/data_format_validation/util.ck.R` | `/Users/qzhang10/workstation/development/SCA/R/utils/util.ck.R` |
| `R/data_format_validation/util.ck.seu.R` | `/Users/qzhang10/workstation/development/SCA/R/utils/util.ck.seu.R` |
| `R/data_format_validation/util.scf.R` | `/Users/qzhang10/workstation/development/SCA/R/utils/util.scf.R` |
| `R/data_format_validation/util.fun.sc.R` | `/Users/qzhang10/workstation/development/SCA/R/utils/util.fun.sc.R` |
| `R/data_format_validation/util.mat.R` | `/Users/qzhang10/workstation/development/SCA/R/utils/util.mat.R` |
| `R/data_format_validation/plotdata.prep.seu.R` | `/Users/qzhang10/workstation/development/SCA/R/funs/plotdata.prep.seu.R` |
| `R/basic_plots/util.plot.R` | `/Users/qzhang10/workstation/development/SCA/R/utils/util.plot.R` |
| `R/basic_plots/common.plots.R` | `/Users/qzhang10/workstation/development/SCA/R/plots/common.plots.R` |
| `R/basic_plots/statPlot.R` | `/Users/qzhang10/workstation/development/SCA/R/plots/statPlot.R` |
| `R/basic_plots/DotPlot.R` | `/Users/qzhang10/workstation/development/SCA/R/DotPlot.R` |
| `R/basic_plots/VocalnoPlot.R` | `/Users/qzhang10/workstation/development/SCA/R/plots/VocalnoPlot.R` |
| `R/basic_plots/violinPlot.R` | `/Users/qzhang10/workstation/development/SCA/R/plots/violinPlot.R` |
| `R/basic_plots/GsDenPlot.R` | `/Users/qzhang10/workstation/development/SCA/R/plots/GsDenPlot.R` |
| `R/basic_plots/graphical.funs.R` | `/Users/qzhang10/workstation/development/SCA/R/plots/graphical.funs.R` |
| `R/basic_plots/add.on.layers.4.dimplot.R` | `/Users/qzhang10/workstation/development/SCA/R/add.on.layers.4.dimplot.R` |
| `R/advanced_plots/advDimPlot.R` | `/Users/qzhang10/workstation/development/SCA/R/plots/advDimPlot.R` |
| `R/advanced_plots/advFeaPlot.R` | `/Users/qzhang10/workstation/development/SCA/R/plots/advFeaPlot.R` |
| `R/advanced_plots/GroupHeatmap.R` | `/Users/qzhang10/workstation/development/SCA/R/plots/GroupHeatmap.R` |
| `R/advanced_plots/expStatPlot.R` | `/Users/qzhang10/workstation/development/SCA/R/plots/expStatPlot.R` |
| `R/advanced_plots/lineagePlot.R` | `/Users/qzhang10/workstation/development/SCA/R/plots/lineagePlot.R` |

## Recommended Loading Order

Use `source("R/load_plot_functions.R")` from the project root. It loads helper and validation functions first, then basic plotting functions, then advanced plotting functions.

