# Interactive Correlation Matrix

Run with `Rscript plugins/interactive_correlation_matrix/plot.R --input data.csv --params params.json --output output_dir`.

`input_mode: raw` accepts a wide table (an optional `id_column` followed by numeric features), calculates Pearson, Spearman, or Kendall correlations and pairwise p-values, and applies row/feature filters. `input_mode: matrix` accepts a square CSV/TSV/TXT whose first column contains row labels and whose remaining headers are matching column labels.

The default `triangle_mode: mixed` draws colored lower-triangle tiles and upper-triangle numbers. `both`, `lower`, and `upper` control visibility; `circle`, `tile`/`square`, and `number` are convenient full-cell modes. `diagonal_mode`, significance cutoffs/stars, palettes, borders, labels, clustering, typography, dimensions, and Plotly interaction are controlled by `params_schema.json`. HTML supports hover, zoom, pan, and Plotly selection/lasso controls; static SVG/PDF/PNG use the same ordered matrix.

Examples and portable bundles are reproduced with `plugins/interactive_correlation_matrix/run_all_examples.sh <repo-root>`.
