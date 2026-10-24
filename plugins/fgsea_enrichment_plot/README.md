# FGSEA Enrichment Plot

Standard OmicsCanvas FGSEA/GSEA plugin with `summary`, classic/gradient running curves, `running_multi_panel`, `dot_summary` (also `summary_dot` and `lollipop_summary`), and `composite` publication layouts. It preserves the older `upper_curve_style`, `gradient_x_title`, and related parameter names.

## Reference GSEA Styles

Three reproducible examples cover the supplied GSEA figure styles:

- `examples/running/`: faceted per-term running enrichment panels with hit marks.
- `examples/image_like/`: gradient-colored multi-term running curves with term legend and rank strip.
- `examples/multiterm/`: annotated multi-term running curves with statistics table and selected genes.

Each bundle contains its own `params.json`, input files, expected PNG, and `manifest.json` command.

## Inputs and commands

`compute` requires a ranked table and GMT (or term/gene CSV/TSV):

```bash
Rscript plugins/fgsea_enrichment_plot/plot.R --input plugins/fgsea_enrichment_plot/example_ranks.csv --genesets plugins/fgsea_enrichment_plot/example_pathways.gmt --params plugins/fgsea_enrichment_plot/example_image_like_params.json --output /tmp/fgsea_image_like_out
```

`precomputed` requires an FGSEA result table for `summary`. A running curve still requires ranks and gene-set membership; a result table alone cannot reconstruct it.

```bash
Rscript plugins/fgsea_enrichment_plot/plot.R --input plugins/fgsea_enrichment_plot/example_fgsea_results.csv --params plugins/fgsea_enrichment_plot/example_summary_params.json --output /tmp/fgsea_summary_out
```

## Main parameter groups

- **Data/selection:** `input_mode`, `plot_type`, `running_style`, `genesets_file`, column mappings, `selected_terms`, `selected_genes`, `top_n_terms`.
- **Curve:** `curve_style`, `curve_color(s)`, `term_colors`, `gradient_colors`, line/point/summit controls.
- **Rug/rank:** `rug_show`, `rug_mode`, `rug_width`, `rug_alpha`, and classic rank-panel controls.
- **Annotations:** label/highlight/leading-edge controls, including arrow color, width, and nudges.
- **Axes/theme:** x/y aliases (`xlab`, `ylab`), limits/breaks, grid, zero line, borders, typography, backgrounds.
- **Titles/legend/output:** title/subtitle/caption, legend layout and colors, `width`, `height`, `dpi`, `export_formats`.
- **Statistics:** `stats_show`, `stats_columns`, `stats_labels`, and table styling add NES/PValue/Adjusted PValue blocks to running panels.
- **Dot summary:** `dot_summary_split`, mapping controls, independent color/size legends, lollipop stems, facets, and labels.
- **Composite:** `composite_layout` supports `2x2`, `vertical`, and `horizontal`; `composite_export_panels` writes `panel_1.png` and companions. Missing rank/pathway inputs produce an informative placeholder and are recorded in `figure.json` instead of failing the whole composite.

All groups and machine-readable descriptions are in `params_schema.json`. Named colors use JSON objects, for example `{"UP_PATHWAY":"#D84A3A","DOWN_PATHWAY":"#3264A5"}`.

## Examples and bundles

Run all examples with `plugins/fgsea_enrichment_plot/run_all_examples.sh <repo-root>`. Bundles in `examples/<id>/` contain `params.json`, copied inputs, `expected/result.png`, and `manifest.json`; each manifest records the reproducible command. The gallery is `all_examples_gallery/fgsea_enrichment_plot_gallery.png`.

The root examples `example_dot_summary_params.json`, `example_multiterm_params.json`, and `example_composite_params.json` use the deterministic example data. Every render also writes `result.html`; it is a Plotly widget when Plotly/htmlwidgets are installed and an informative static-output fallback otherwise. This plugin keeps the existing FGSEA computation and is compatible with the SCA-style ranked statistic and leading-edge conventions.
