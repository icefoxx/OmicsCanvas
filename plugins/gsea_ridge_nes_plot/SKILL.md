# GSEA Pathway Ridge + NES Skill

Use `gsea_ridge_nes_plot` for a pathway ridgeline of gene-level log2FC with a left NES bubble.

File flags match `gsea_pathway_heatmap` and `fgsea_enrichment_plot`:

- `--input` ranked gene table
- `--enrichment` precomputed GSEA results
- `--genesets` optional GMT / term-gene table

```bash
Rscript plugins/gsea_ridge_nes_plot/plot.R \
  --input plugins/gsea_ridge_nes_plot/example_ranks.csv \
  --enrichment plugins/gsea_ridge_nes_plot/example_enrichment.csv \
  --genesets plugins/gsea_ridge_nes_plot/example_pathways.gmt \
  --params plugins/gsea_ridge_nes_plot/example_basic_params.json \
  --output /tmp/gsea_ridge_nes_out
```

Canonical params: `gene_col`, `stat_col`, `term_col`, `nes_col`, `fdr_col`, `leading_genes_col`, `selected_terms`, `top_n_terms`, `gene_scope`.
