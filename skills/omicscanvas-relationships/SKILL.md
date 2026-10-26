---
name: omicscanvas-relationships
description: Choose scientific plots for relationships, overlap and networks in OmicsCanvas, checking required data roles and interpretation limits.
metadata:
  role: plot_workflow
  layer: scenario
---

# Relationships, overlap and networks

This is an agent-neutral scenario skill. Use it after `omicscanvas-router` identifies this question. It does not call a model provider or launch other agents.

Distinguish edge lists, set memberships, transition counts and numeric matrices before selecting a grammar. A follow-up time column is not a multistage transition table.

Use Venn for a small number of sets and UpSet for larger intersection structures; verify the element universe and duplicate handling. Use Sankey/alluvial for supplied transitions or stage memberships, not causal claims. Use network/arc renderers for supplied source/target relationships, preserving edge direction and weight interpretation.

A correlation matrix requires numerical features and a stated method. A Mantel network requires the corresponding distance/test inputs; do not relabel a Pearson coefficient as a Mantel statistic. Linked matrix/network views need both the matrix and links table. Run `describe` and pass every required auxiliary table explicitly; never mix real primary input with synthetic links. Visual proximity in a graph is not evidence of association strength unless the layout and encoding justify it.

## Available engines

`alluvial_plot`, `interactive_sankey_plot`, `interactive_network_plot`, `interactive_arc_network_plot`, `dynamic_venn_diagram`, `interactive_upset_plot`, `interactive_correlation_matrix`, `interactive_mantel_correlation_network`, `linked_matrix_network_plot`.

Use `python -m omicscanvas catalog --workflow relationships` for the current compact list. Read `python -m omicscanvas describe ENGINE` for the chosen contract, schema and Plot Guide; do not load every plugin skill. Then follow `skills/omicscanvas-render/SKILL.md` to plan, validate and render. From another working directory, use an absolute path to `scripts/omicscanvas.py` with the project's Python environment.

If the scientific question or required role remains ambiguous, report the missing information and keep the candidate set open. Do not substitute synthetic data, infer unavailable analyses, or rank visual attractiveness above scientific suitability.
