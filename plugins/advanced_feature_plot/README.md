# Advanced Feature Plot

This plugin wraps the original SCA `advFeaPlot()` function with the standard OmicsCanvas/BioFigureAI runtime:

```bash
Rscript plugins/advanced_feature_plot/plot.R \
  --input plugins/advanced_feature_plot/example_input.csv \
  --params plugins/advanced_feature_plot/example_single_feature_params.json \
  --output /tmp/advanced_feature_single_out
```

It accepts a flat table with:

- one cell/id column
- two embedding columns such as `dim1` and `dim2`
- optional `group_column` and `split_column`
- one or more numeric feature columns

The original SCA implementation and helper files are copied under `reference_sca_helpers/`. The wrapper keeps the old plotting engine and adds standard input/output files, safer package checks, feature-column selection, row selection, and JSON parameter names.

## Examples

Run all examples:

```bash
plugins/advanced_feature_plot/run_all_examples.sh /Users/qzhang10/Documents/OmicsCanvas
```

This writes `/tmp/advanced_feature_*_out` and a contact sheet at:

```text
plugins/advanced_feature_plot/all_examples_gallery/all_feature_plot_gallery.png
```

## Core Params

```json
{
  "x_column": "dim1",
  "y_column": "dim2",
  "id_column": "cell",
  "group_column": "cluster",
  "split_column": "sample",
  "feature_columns": ["CD3D", "MS4A1"]
}
```

## Old Argument Compatibility

SCA-style names are accepted where practical:

```json
{
  "group.by": "cluster",
  "split.by": "sample",
  "cell.column.nm": "cell",
  "features": ["CD3D", "MS4A1"],
  "pt.size": 0.4,
  "theme.use": "themeBlank"
}
```

## Customization

Feature and color scale:

```json
{
  "feature_columns": ["CD3D", "MS4A1", "LST1"],
  "palette": "Spectral",
  "feature_colors": ["#F2F2F2", "#67A9CF", "#2166AC"],
  "scale_by": "feature",
  "quantile_cutoff": [0, 0.95],
  "value_cutoff": [0, 3],
  "value_scale_range": [0, 1],
  "value_scale_breaks": [0, 0.5, 1],
  "feature_low_alpha": 0.15,
  "keep_zero": false,
  "background_cutoff": 0,
  "background_color": "grey85"
}
```

Composition/coexpression color mixing:

```json
{
  "feature_columns": ["CD3D", "MS4A1", "LST1"],
  "feature_comp": true,
  "color_mix_mode": "blend",
  "feature_palette": "Set1",
  "legend_title": {
    "CD3D": "T-cell score",
    "MS4A1": "B-cell score",
    "LST1": "Myeloid score"
  }
}
```

Labels and highlights:

```json
{
  "highlight_rows": ["Cell001", "Cell120"],
  "highlight_column": "cluster",
  "highlight_levels": ["Naive T"],
  "highlight_border_color": "black",
  "highlight_size": 2.5,
  "highlight_stroke": 0.6,
  "group_label_show": true,
  "group_label_size": 4,
  "label_show": true,
  "label_repel": true,
  "legend_label": true
}
```

Theme, axes, split, and rendering:

```json
{
  "title": "Feature expression",
  "subtitle": "Custom subtitle",
  "xlab": "dim1",
  "ylab": "dim2",
  "theme_use": "themeBlank",
  "theme_args": {
    "xlab": "dim1",
    "ylab": "dim2",
    "lab.size": 13,
    "xlen.npc": 0.16,
    "ylen.npc": 0.16
  },
  "legend_position": "right",
  "legend_direction": "vertical",
  "show_density": true,
  "hex": false,
  "raster": false,
  "facet_nrow": 1,
  "facet_ncol": 3
}
```
## Reproducible examples

Bundles are in `plugins/advanced_feature_plot/examples/<id>/`. Each contains `params.json`, copied command inputs under `input/`, and `expected/result.png`. `manifest.json` is the machine-readable entry point and records how to rerun the example.

