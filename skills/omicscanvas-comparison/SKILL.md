---
name: omicscanvas-comparison
description: Choose scientific plots for distributions, comparisons and summary charts in OmicsCanvas, checking required data roles and interpretation limits.
metadata:
  role: plot_workflow
  layer: scenario
---

# Distributions, comparisons and summary charts

This is an agent-neutral scenario skill. Use it after `omicscanvas-router` identifies this question. It does not call a model provider or launch other agents.

Use individual-value distributions (ECDF, violin, histogram, raincloud or ridgeline) for repeated observations. Use supplied bars, intervals, dumbbells or a forest plot when the input contains analyzed summaries. An arbitrary second numeric column is not a standard error or confidence bound.

For paired changes, keep the pairing identifier; for independent groups, establish the biological replicate unit. Set test/correction options only when their assumptions and requested analysis support them. Do not invent significance from appearance.

A regression scatter is not causal evidence. A line requires a meaningful order or time coordinate; uncertainty bands require supplied or explicitly computed bounds. Radar axes must have comparable directions/scales. Three-dimensional bars and circular score distributions may emphasize geometry over precision; offer a simpler alternative when accurate comparison is the main goal. In ECDFs, preserve all observations and ties. Review clipping, negative axes, long labels and point overlap before final delivery.

## Available engines

`classified_bar_plot`, `bar3d_plot`, `combo_bar_dot_matrix`, `combo_bar_line_plot`, `circular_distribution_plot`, `ecdf_plot`, `exp_stat_plot`, `highlight_effect_plot`, `interactive_bubble_score_matrix`, `interactive_dumbbell_plot`, `interactive_histogram_plot`, `interactive_radar_plot`, `interactive_ridgeline_plot`, `interactive_violin_plot`, `line_plot`, `quadrant_correlation_scatter`, `raincloud_plot`, `regression_scatter_plot`, `stat_plot`, `violin_plot`, `forest_plot`, `bland_altman_plot`.

Use `python -m omicscanvas catalog --workflow distribution-comparison` for the current compact list. Read `python -m omicscanvas describe ENGINE` for the chosen contract, schema and Plot Guide; do not load every plugin skill. Then follow `skills/omicscanvas-render/SKILL.md` to plan, validate and render. From another working directory, use an absolute path to `scripts/omicscanvas.py` with the project's Python environment.

If the scientific question or required role remains ambiguous, report the missing information and keep the candidate set open. Do not substitute synthetic data, infer unavailable analyses, or rank visual attractiveness above scientific suitability.
