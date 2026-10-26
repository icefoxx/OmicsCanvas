---
name: omicscanvas-single-cell
description: Choose scientific plots for single-cell embeddings and annotation in OmicsCanvas, checking required data roles and interpretation limits.
metadata:
  role: plot_workflow
  layer: scenario
---

# Single-cell embeddings and annotation

This is an agent-neutral scenario skill. Use it after `omicscanvas-router` identifies this question. It does not call a model provider or launch other agents.

Use supplied embedding coordinates for cell maps; do not recompute an embedding merely to improve appearance. Choose `advanced_dim_plot` for categorical cluster maps, `advanced_feature_plot` or `feature_density_plot` for quantitative overlays, and `interactive_3d_scatter` only when a third coordinate actually exists.

Use `dot_plot` or `hierarchical_marker_panel` for marker summaries, `group_heatmap` for expression patterns and `interactive_violin_plot` for distributions. Validate whether the input is per-cell expression, supplied summaries or a numeric matrix; these are not interchangeable.

For a hierarchy around an embedding, read `skills/circular-tree-embedding/SKILL.md` after selecting `circular_tree_embedding`. Confirm class/subclass/leaf relationships, coordinate columns and the desired annotation level for colors. Topology inferred from expression similarity is different from a supplied annotation hierarchy.

`lineage_plot` displays trajectories; `embedding_vector_plot` displays supplied vectors. Neither should be described as inferred biological lineage or RNA velocity without upstream evidence. Keep group colors and identifiers consistent across panels; avoid treating cells from one donor as independent biological replicates in comparisons.

## Available engines

`advanced_dim_plot`, `advanced_feature_plot`, `feature_density_plot`, `hierarchical_marker_panel`, `circular_tree_embedding`, `lineage_plot`, `interactive_3d_scatter`, `radviz_plot`, `embedding_vector_plot`, `dot_plot`, `group_heatmap`, `interactive_violin_plot`.

Use `python -m omicscanvas catalog --workflow single-cell` for the current compact list. Read `python -m omicscanvas describe ENGINE` for the chosen contract, schema and Plot Guide; do not load every plugin skill. Then follow `skills/omicscanvas-render/SKILL.md` to plan, validate and render. From another working directory, use an absolute path to `scripts/omicscanvas.py` with the project's Python environment.

If the scientific question or required role remains ambiguous, report the missing information and keep the candidate set open. Do not substitute synthetic data, infer unavailable analyses, or rank visual attractiveness above scientific suitability.
