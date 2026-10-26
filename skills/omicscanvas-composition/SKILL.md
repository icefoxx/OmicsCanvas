---
name: omicscanvas-composition
description: Choose scientific plots for compositions, hierarchies and cumulative contributions in OmicsCanvas, checking required data roles and interpretation limits.
metadata:
  role: plot_workflow
  layer: scenario
---

# Compositions, hierarchies and cumulative contributions

This is an agent-neutral scenario skill. Use it after `omicscanvas-router` identifies this question. It does not call a model provider or launch other agents.

Identify whether values are counts, fractions, percentages, cumulative contributions or branch lengths. Do not normalize them silently. Stacked bars are suitable for comparing composition across groups; pie/donut views are most readable for a small number of parts. Ternary inputs must be valid three-part compositions.

Sunburst and treemap require a valid hierarchy and defined node weights. `annotated_tree_plot` uses supplied topology/lengths; use the separate single-cell workflow for a radial hierarchy around an embedding. A category hierarchy is not a phylogeny.

Waterfall bars represent ordered signed contributions to a running total, not independent category heights. Alluvial counts must refer to comparable populations across stages. Clonal fish fractions have parent/child containment semantics, unlike generic stacked proportions. Keep level order, color identity and denominator definitions consistent between panels.

## Available engines

`stacked_bar_plot`, `circular_bar_plot`, `interactive_pie_plot`, `sunburst_plot`, `treemap_plot`, `ternary_plot`, `waterfall_plot`, `annotated_tree_plot`, `alluvial_plot`, `clonal_fish_plot`.

Use `python -m omicscanvas catalog --workflow composition-hierarchy` for the current compact list. Read `python -m omicscanvas describe ENGINE` for the chosen contract, schema and Plot Guide; do not load every plugin skill. Then follow `skills/omicscanvas-render/SKILL.md` to plan, validate and render. From another working directory, use an absolute path to `scripts/omicscanvas.py` with the project's Python environment.

If the scientific question or required role remains ambiguous, report the missing information and keep the candidate set open. Do not substitute synthetic data, infer unavailable analyses, or rank visual attractiveness above scientific suitability.
