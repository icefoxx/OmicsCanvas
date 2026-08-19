# Interactive Mantel correlation network skill

Use `input_mode: precomputed` when exact reproduction matters. The primary input is a square correlation table with feature names in its first column; Mantel links use `env`, `spec`, `r`, and `p` aliases, with optional `q` and `group`. Environmental and species point tables accept `id` or `label` plus optional `x`, `y`, `group`, `color`, and `size`.

Use `input_mode: compute` with `--input` environmental observations and `--input2` species observations. Pearson, Spearman, and Kendall correlations are supported; the Mantel-like result is a deterministic distance-vector correlation suitable for exploratory figures, while precomputed mode preserves exact supplied results.

The renderer emits static ggplot2 files and a Plotly HTML with hover, zoom/pan, selection, and lasso controls. `feature_order` and explicit point coordinates make layouts reproducible.
