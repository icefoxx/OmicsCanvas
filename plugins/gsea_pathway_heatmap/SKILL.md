# GSEA Pathway Heatmap Skill

Use `gsea_pathway_heatmap` when the figure must combine:

- GSEA running enrichment for selected terms
- Gene-level expression heatmaps of those same terms

## Required tables

1. Ranked genes (`gene_col`, `stat_col`)
2. Gene sets (GMT)
3. Expression matrix overlapping the ranked genes

Precomputed enrichment is optional. It supplies NES/p/padj/leading-edge labels without recomputing FGSEA, but ranks + GMT are still required for the running curves.

## Typical params

```json
{
  "selected_terms": ["Cardiac_Chamber_Morphogenesis", "Heart_Morphogenesis"],
  "heatmap_gene_mode": "leading_edge",
  "heatmap_max_genes": 24,
  "scale": "row"
}
```

`heatmap_gene_mode: all_members` plots all overlapping gene-set members (capped). `leading_edge` prefers FGSEA core genes.

## Not this plugin

- Running curves only → `fgsea_enrichment_plot`
- Clustered heatmap + GO bars (ClusterGVis style) → not implemented here
