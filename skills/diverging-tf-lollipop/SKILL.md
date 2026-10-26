---
name: diverging-tf-lollipop
description: Use OmicsCanvas's diverging lollipop to visualize an existing two-state TF or regulon comparison table with signed effects and optional p-values. Use for transcription-factor lollipop requests; not for inferring regulatory networks or running differential tests on count matrices.
metadata:
  role: plot_workflow
---

# Diverging TF lollipop

Route requests such as “compare regulons”, “transcription factor lollipop”, or
“比较两组转录因子，画双向棒棒糖图” to the existing engine
`plugins/interactive_enrichment_lollipop`, variant `diverging_tf`. Do not create
a second plugin for this grammar.

Read `plugins/interactive_enrichment_lollipop/params_schema.json` for current
controls. The style preset is
`plugins/interactive_enrichment_lollipop/examples/CAB_demo/params.json`.

## Use a research table

Use one row per TF/regulon with a name, signed effect and optional raw/adjusted
probability. Map `category_column`, `value_column`, and `pvalue_column` explicitly;
do not accidentally map p-values onto the effect axis. Preserve the supplied sign
and confirm the contrast before assigning biological direction labels.

- Set `color_mode: value` and `category_label_position: zero_opposite`.
- If probabilities are supplied, set `size_transform: neg_log10_pvalue` and
  `size_switch: true`. Supply probabilities in [0,1], not pretransformed scores.
  Prefer an existing adjusted-probability column where appropriate, and identify
  it in `size_legend_title`; never invent or silently adjust p-values.
- Without probabilities, use `size_switch: false` and `show_size_legend: false`.
- Sort by value if appropriate; choose a readable height for the row count.
  Keep `x_limits` spanning zero and enough room for central labels. Use an
  outside legend if the empty area in the reference layout is occupied.
- Enable `direction_labels_show` only with the intended comparison labels.
  Replace the preset's Grm1/Grm2 labels for another study. Do not transfer its
  fixed axis limits or significance breaks blindly to new data.

When data are missing, request the comparison table/mappings or offer the
explicitly labelled synthetic demo. Do not infer TF activity or statistical
significance from a screenshot or a raw count matrix.

## Published use case and runnable example

Hao et al., *Molecular Cancer* 25:24 (2026), Figure 6L compares TF signatures of
Grm1/Grm2 gut-resident gamma-delta T-cell states:
https://doi.org/10.1186/s12943-025-02548-8

The case is documented in
`plot_web/registry/guides/enrichment_lollipop.yaml` and the citation in
`plot_web/registry/literature.yaml` (`hao_dnt_2026`). `CAB_demo` uses synthetic
illustrative values, not the paper's original measurements. Keep that provenance
visible when presenting a demo; publication context is not validation of new data.

```bash
Rscript plugins/interactive_enrichment_lollipop/plot.R \
  --input plugins/interactive_enrichment_lollipop/examples/CAB_demo/input/example_input.csv \
  --params plugins/interactive_enrichment_lollipop/examples/CAB_demo/params.json \
  --output /tmp/diverging_tf_demo
```

For actual data, pass that table via `--input` and its mapped parameters via
`--params`. Inspect `error.json`/`run.log` and `selected_rows.csv`; the latter
records original probabilities and transformed sizes. Verify SVG/PDF/PNG before
delivery. HTML may fall back to a labelled static preview when the installed
Plotly converter cannot handle the layout (`interactive_html: false`).

Editor route: `/plot/interactive_enrichment_lollipop?example=CAB_demo&variant=diverging_tf`.
For renderer/schema/example changes, follow `skills/omics-plot-plugins/SKILL.md`.
