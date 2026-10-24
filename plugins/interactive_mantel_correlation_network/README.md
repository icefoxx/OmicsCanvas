# Combined Mantel + Pearson correlation

Publication-style figure that **combines two different statistics**:

1. **Pearson’s r** among environmental / metadata variables (upper triangle).
2. **Mantel tests** of community/biological distance vs each environmental variable’s distance (network on the lower left).

These are not the same statistic. A Mantel edge is **not** a Pearson correlation, and neither result implies causality.

## Visual grammar

| Encoding | Meaning |
| --- | --- |
| Square color | Pearson’s r (blue = positive, red = negative, white ≈ 0) |
| Square size | \|Pearson’s r\| |
| Diagonal text | Environmental variable names (any user columns) |
| Edge color | Mantel P or FDR (`< 0.001`, `< 0.01`, `< 0.05`, `≥ 0.05`) |
| Edge width | \|Mantel’s r\| (`< 0.25`, `0.25–0.50`, `≥ 0.50`) |

## Workflow A — raw data

Environmental table (`sample` + numeric env columns) and community table (`sample` + taxon columns). Optional `community_groups` maps names such as `Surface` / `Deep` to column lists.

```bash
Rscript plugins/interactive_mantel_correlation_network/plot.R \
  --input plugins/interactive_mantel_correlation_network/example_env.csv \
  --input2 plugins/interactive_mantel_correlation_network/example_community.csv \
  --params plugins/interactive_mantel_correlation_network/example_basic_params.json \
  --output /tmp/mantel_pearson_out
```

Set `"input_mode": "compute"` and `community_groups` in params. Community distance defaults to Bray–Curtis; each env variable uses Euclidean distance. Mantel permutations default to 9999 with `random_state: 123`. Mantel P values are BH/FDR-adjusted unless `p_adjust` is `none`.

## Workflow B — precomputed statistics (demo)

Square Pearson matrix (`feature` + variable columns) and Mantel table (`spec`/`group`, `env`/`variable`, `r`, `p`):

```bash
Rscript plugins/interactive_mantel_correlation_network/plot.R \
  --input plugins/interactive_mantel_correlation_network/example_corr.csv \
  --mantel plugins/interactive_mantel_correlation_network/example_mantel.csv \
  --params plugins/interactive_mantel_correlation_network/example_basic_params.json \
  --output /tmp/mantel_pearson_out
```

Long Pearson tables (`var1`, `var2`, `pearson_r`, optional `pearson_p`) are also accepted.

## Outputs

- `mantel_pearson_combined.pdf` / `.png` (≥300 dpi) / `.svg` (and `result.*` for Plot Studio)
- `pearson_correlations.csv` — pairwise Pearson r and P
- `mantel_results.csv` — Mantel r, raw P, adjusted P, permutations, distance metrics
- `caption.txt` — figure caption
- `qc.json` — automatic quality checks
