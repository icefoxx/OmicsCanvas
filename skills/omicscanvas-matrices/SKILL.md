---
name: omicscanvas-matrices
description: Choose scientific plots for expression matrices and annotated heatmaps in OmicsCanvas, checking required data roles and interpretation limits.
metadata:
  role: plot_workflow
  layer: scenario
---

# Expression matrices and annotated heatmaps

This is an agent-neutral scenario skill. Use it after `omicscanvas-router` identifies this question. It does not call a model provider or launch other agents.

First identify the table orientation: observations by features, genes by samples, or a long summary table. Read the selected engine contract before transposing, aggregating or scaling. Record every transformation; keep a raw copy and use a derived input file when a transformation is needed.

Use ordinary/circular heatmaps for continuous matrices, binary matrices for presence/absence, and dot/balloon/pie matrices only when their size/color/fraction roles are available. Dual-triangle views require compatible, aligned metrics and an explicit explanation of each half.

Keep categorical annotation strips discrete with named colors. State whether clustering uses raw values, standardized rows, supplied profiles or a precomputed tree. Do not confuse a supplied average-expression matrix with individual cells. Auxiliary sample, row and column annotation tables must match their declared IDs, not their row order by assumption. Review long labels, legends and matrix alignment in the exported figure.

## Available engines

`group_heatmap`, `circular_heatmap`, `dot_plot`, `balloon_plot`, `pie_dot_matrix`, `interactive_binary_plot`, `interactive_clustered_heatmap_plot`, `interactive_dual_triangle_heatmap_plot`, `ranked_annotation_panel`, `threshold_matrix_heatmap`, `den_plot`, `cluster_dendrogram_plot`, `exp_stat_plot`.

Use `python -m omicscanvas catalog --workflow expression-matrices` for the current compact list. Read `python -m omicscanvas describe ENGINE` for the chosen contract, schema and Plot Guide; do not load every plugin skill. Then follow `skills/omicscanvas-render/SKILL.md` to plan, validate and render. From another working directory, use an absolute path to `scripts/omicscanvas.py` with the project's Python environment.

If the scientific question or required role remains ambiguous, report the missing information and keep the candidate set open. Do not substitute synthetic data, infer unavailable analyses, or rank visual attractiveness above scientific suitability.
