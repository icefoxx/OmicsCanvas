# Interactive UpSet Plot

This plugin renders deterministic UpSet-style plots from a wide 0/1 membership table or a long item/set edge table. It uses native `ggplot2`, `grid`, and `patchwork` when available. `ComplexUpset` is optional and is not installed or required.

## Runtime

```bash
Rscript plugins/interactive_upset_plot/plot.R \
  --input plugins/interactive_upset_plot/example_input.csv \
  --params plugins/interactive_upset_plot/example_basic_params.json \
  --output /tmp/upset_out
```

Successful runs write SVG, PDF, PNG, Plotly HTML (or a fallback), `figure.json`, `run.log`, and the three deterministic data exports: `membership_matrix_used.csv`, `intersections_used.csv`, and `set_sizes_used.csv`. Failed runs write `error.json` and remove stale success artifacts.

## Subclasses

`basic` is the canonical intersection bars + matrix + set-size layout. `intersection_size`, `set_size`, `matrix_only`, `ratio`, `annotated_numeric`, `annotated_categorical`, `query_highlight`, `grouped`, and `all_intersections` select focused or extended variants through `plot_subclass`.

The implementation maps ComplexUpset concepts including the four region modes, observed/all intersections, cardinality/degree/ratio filters and sorting, annotation panels, query colors, matrix stripes/theme controls, and grouping. Native rendering currently treats `group_by=sets/custom`, panel ratios, stripes, per-query alpha/component targeting, and tooltip columns as exported/configured metadata or best-effort fallbacks; the core matrix, bars, filters, annotations, queries, grouping order, and all-intersection enumeration are rendered.

`result.html` uses Plotly when installed and includes intersection hover labels and optional set traces. Without Plotly it remains a useful HTML notice pointing to the static artifacts.
