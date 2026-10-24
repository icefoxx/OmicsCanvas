# GSEA Pathway Ridge + NES

Publication-style pathway enrichment figure using the same file flags as other GSEA plugins:

- `--input` ranked gene / log2FC table (`gene`, `log2FC` or `stat`)
- `--enrichment` precomputed GSEA table (`pathway`/`term`, `NES`, p-value)
- `--genesets` optional GMT or term–gene table

If `--genesets` is omitted, leading-edge / `core_enrichment` genes in the GSEA table are used.

## CLI

```sh
Rscript plugins/gsea_ridge_nes_plot/plot.R \
  --input plugins/gsea_ridge_nes_plot/example_ranks.csv \
  --enrichment plugins/gsea_ridge_nes_plot/example_enrichment.csv \
  --genesets plugins/gsea_ridge_nes_plot/example_pathways.gmt \
  --params plugins/gsea_ridge_nes_plot/example_basic_params.json \
  --output /tmp/gsea_ridge_nes_out
```

Column params follow the FGSEA skill names: `gene_col`, `stat_col`, `term_col`, `nes_col`, `fdr_col`, `leading_genes_col`, `selected_terms`, `top_n_terms`.
