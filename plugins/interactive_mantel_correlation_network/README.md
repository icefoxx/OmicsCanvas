# Interactive Mantel Correlation Network

This plugin combines a triangular diverging correlation matrix with environmental/species point groups and curved Mantel-test links. It supports CSV, TSV, and TXT inputs, grouped or flat JSON parameters, deterministic fallback positions/colors, and static SVG/PDF/PNG plus interactive Plotly HTML.

## Precomputed mode

```bash
Rscript plugins/interactive_mantel_correlation_network/plot.R --input plugins/interactive_mantel_correlation_network/example_corr.csv --params plugins/interactive_mantel_correlation_network/example_basic_params.json --output /tmp/mantel_network --mantel plugins/interactive_mantel_correlation_network/example_mantel.csv --envpoints plugins/interactive_mantel_correlation_network/example_env_points.csv --specpoints plugins/interactive_mantel_correlation_network/example_spec_points.csv
```

The correlation table is square with feature names in the first column. Mantel tables accept aliases for environment, species, r, p, and q. Point tables accept `id`/`label` and optional coordinates and styling columns. Supplied coordinates are honored; missing coordinates receive deterministic positions.

## Compute mode

```bash
Rscript plugins/interactive_mantel_correlation_network/plot.R --input env_table.csv --input2 spec_table.csv --params compute_params.json --output /tmp/mantel_compute
```

Compute mode calculates the requested Pearson, Spearman, or Kendall feature correlation matrix and deterministic Mantel-like distance correlations. Use precomputed mode for exact reproduction of an external Mantel implementation.

All requested controls are documented in `params_schema.json`. Outputs include static files, Plotly HTML, metadata, logs, and all used/selected tables. Run all three reproducible examples with `plugins/interactive_mantel_correlation_network/run_all_examples.sh /Users/qzhang10/Documents/OmicsCanvas`.
