# FGSEA Enrichment Plot Skill

Use `fgsea_enrichment_plot` for ranked-gene-set enrichment figures. Running curves require a ranked table (`gene_col`, `stat_col`) and a GMT/term-gene file. Precomputed FGSEA results support summary and dot-summary plots, but cannot reconstruct a running curve without ranks and memberships.

## Three GSEA Reference Styles

The three supplied reference pictures correspond to these reproducible examples:

1. **Faceted term panels**: `examples/running/`. Use `plot_type: faceted_running` with several selected terms. It produces one compact running-score panel per term with pathway strips and hit marks.
2. **Grouped gradient curves**: `examples/image_like/`. Use `plot_type: grouped_curves`, `curve_style: multi_term`, and explicit `selected_terms`. It overlays several term curves and shows their colored hit tracks.
3. **Classic tracked plot**: `examples/multiterm/`. Use `plot_type: classic_tracks`, `curve_style: multi_term`, and `stats_table_show: true`. It combines the running curves, hit/rank tracks, ranked-list metric, and NES/PValue/Adjusted PValue block.
4. **Multi-group overlay**: `examples/multigroup/`. Use `plot_type: multi_group` with a long rank table (`gene`, `group`, `stat`) and **one** selected pathway. Each group is ranked independently and gets its own ES curve and hit track. This is not recolored copies of a single GSEA run.
5. **Enrichment ridge plot**: `examples/ridge/`. Use `plot_type: ridge`. Each selected term is a density of member-gene log2FC values, colored by −log10(p), with rug ticks for individual genes. Ridges shifted right = upregulated members; left = downregulated.
6. **Gene–pathway Sankey + bubble**: `examples/gene_sankey/`. Use `plot_type: gene_sankey`. Genes on the left link to enriched terms in the center; the right panel is a bubble plot of −log10(p) (x), term_ratio (size), and gene_ratio (color). Pathway order is shared. Cap crowding with `sankey_max_terms` and `sankey_max_genes`.

Choose `composite` when all supported views are needed in one publication overview. Use `dot_summary` for NES/count/p.adjust lollipop summaries, not for a running enrichment curve.

```bash
Rscript plugins/fgsea_enrichment_plot/plot.R --input plugins/fgsea_enrichment_plot/example_ranks.csv --genesets plugins/fgsea_enrichment_plot/example_pathways.gmt --params plugins/fgsea_enrichment_plot/example_image_like_params.json --output /tmp/fgsea_image_like_out
```

To reproduce any of the three reference styles, use its `examples/<id>/manifest.json` command. Every successful run emits `result.svg`, `result.pdf`, `result.png`, `result.html`, `figure.json`, `run.log`, and the selected/enrichment tables.
