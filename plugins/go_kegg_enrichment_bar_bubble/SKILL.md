# GO + KEGG Enrichment Bar-Bubble Skill

Use this plugin for grouped GO and KEGG enrichment result tables when the requested figure is a horizontal enrichment bar plot, not a conventional dotplot.

## Input

The renderer autodetects or accepts explicit mappings for term/description, ontology/category, raw p-value, adjusted p-value, and gene count columns. Category values are normalized from `BP`, `CC`, `MF`, `GO:BP`, and full ontology names; values containing `KEGG` become `KEGG Pathway`.

`significance_column` accepts `auto`, `pvalue`, or `adjusted`. Significance is `-log10(selected p-value)`. `top_n` selects the most significant terms within each category and defaults to 5.

## Visual Standard

- Category order is Biological Process, Cellular Component, Molecular Function, then KEGG Pathway.
- Each ontology receives a pastel strip and matching enrichment bars.
- Count bubbles appear before bars, with exact counts printed inside.
- Category and Count legends are shown independently on the right.
- The x-axis starts at zero and is labeled for the selected significance metric.
- Figure height expands with the number of displayed terms.

## Runtime

```bash
Rscript plugins/go_kegg_enrichment_bar_bubble/plot.R \
  --input plugins/go_kegg_enrichment_bar_bubble/examples/go_kegg/input/example_enrichment.csv \
  --params plugins/go_kegg_enrichment_bar_bubble/examples/go_kegg/params.json \
  --output /tmp/go_kegg_enrichment_bar_bubble
```

Outputs include `result.svg`, `result.pdf`, `result.png`, `result.html`, `figure.json`, `selected_rows.csv`, and `run.log`.
