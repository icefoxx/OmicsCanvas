# GO / KEGG Enrichment

Grouped horizontal enrichment bars for GO (BP / CC / MF) and KEGG result tables. Each ontology
gets a coloured strip and matching bars; a bubble before each bar prints the gene count. Bar length
is `-log10(p)` of the selected significance column.

## Input

One table (CSV/TSV/TXT), one row per enriched term, e.g. a clusterProfiler result:

```text
Description,Ontology,pvalue,p.adjust,GeneCount
defense response to virus,BP,0.00001,0.0003,31
```

| Parameter | Meaning |
|---|---|
| `term_column` | Term / description shown on the y axis |
| `category_column` | Ontology; `BP`, `CC`, `MF`, `GO:BP`, full names and anything containing `KEGG` are normalised |
| `pvalue_column`, `adjusted_pvalue_column` | Raw and adjusted p-values |
| `significance_column` | `auto`, `pvalue` or `adjusted`: which p-value sets the bar length |
| `count_column` | Gene count printed in the bubble |
| `top_n` | Most significant terms kept per category (default 5) |

Columns are autodetected when not mapped.

## Style

`category_colors` (named map), `bubble_size_range`, `row_height`, `category_gap`,
`term_label_size`, `count_label_size`, `title`, `width`, `height`, `dpi`, `font_family`,
`legend_position`. Figure height grows with the number of terms shown.

## Run

```bash
Rscript plugins/go_kegg_enrichment_bar_bubble/plot.R \
  --input plugins/go_kegg_enrichment_bar_bubble/examples/go_kegg/input/example_enrichment.csv \
  --params plugins/go_kegg_enrichment_bar_bubble/examples/go_kegg/params.json \
  --output /tmp/go_kegg_out
```

Outputs: `result.svg`, `result.pdf`, `result.png`, `result.html`, `figure.json`,
`selected_rows.csv`, `run.log`; `error.json` on failure.
