# FGSEA enrichment plot skill

Use `compute` with a ranked table (`gene_col`, `stat_col`) and `--genesets` for running curves. Use `precomputed` with an FGSEA result table for `summary`; precomputed results do not contain enough information for a running curve unless ranks and memberships are also supplied.

Modes: `summary`, `running`, `gradient_curve`/`gradient_only`, `running_multi_panel`, `dot_summary`, and `composite`. For image-like GSEA choose `running_multi_panel` or `gradient_curve` with `curve_style: multi_term`, explicit `selected_terms`, named `term_colors`, `rug_show: true`, `xlab: CD4Tn-vs-CD4Tex`, `ylab: Enrichment Score`, dotted `grid_show`, and a right legend. Use `dot_summary` for NES/count/p.adjust lollipop summaries and `composite` for the four-panel publication overview.

```bash
Rscript plugins/fgsea_enrichment_plot/plot.R --input plugins/fgsea_enrichment_plot/example_ranks.csv --genesets plugins/fgsea_enrichment_plot/example_pathways.gmt --params plugins/fgsea_enrichment_plot/example_image_like_params.json --output /tmp/fgsea_image_like_out
```

To reproduce a bundle, use its `examples/<id>/manifest.json` command or the equivalent command with `examples/<id>/input/` and `params.json`.
