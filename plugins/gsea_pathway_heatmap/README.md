# GSEA Pathway Heatmap

Publication-style composite of **GSEA running enrichment** and **pathway gene expression heatmaps**.

## Layout

1. Multi-term running enrichment score curves
2. Hit rugs (gene-set membership along the ranked list)
3. Rank / score color strip
4. One expression heatmap per selected pathway

## Inputs

- `--input` ranked gene table (`gene`, statistic such as `avg_log2FC`)
- `--genesets` GMT or term–gene table
- `--expr` gene × sample expression matrix
- `--enrichment` optional precomputed FGSEA table (`pathway`, `NES`, `pval`, `padj`, `leadingEdge`)
- `--col-annot` optional sample annotation

## Run

```bash
Rscript plugins/gsea_pathway_heatmap/plot.R \
  --input plugins/gsea_pathway_heatmap/example_ranks.csv \
  --genesets plugins/gsea_pathway_heatmap/example_pathways.gmt \
  --expr plugins/gsea_pathway_heatmap/example_expression.csv \
  --params plugins/gsea_pathway_heatmap/example_basic_params.json \
  --output /tmp/gsea_pathway_heatmap_out
```

Use this plugin when you want pathway **expression evidence** next to GSEA statistics. For curves-only GSEA, use `fgsea_enrichment_plot`. For clustered heatmaps without GSEA tracks, use `group_heatmap` or `interactive_clustered_heatmap_plot`.
