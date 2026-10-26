---
name: omicscanvas-enrichment
description: Choose scientific plots for differential effects and pathway enrichment in OmicsCanvas, checking required data roles and interpretation limits.
metadata:
  role: plot_workflow
  layer: scenario
---

# Differential effects and pathway enrichment

This is an agent-neutral scenario skill. Use it after `omicscanvas-router` identifies this question. It does not call a model provider or launch other agents.

Choose a volcano for supplied signed fold changes and p-values; distinguish raw from adjusted p-values and preserve their actual meaning. Choose enrichment bars/dots/lollipops for supplied term-level results. Use running enrichment curves only with the ranked list and gene-set information required by that engine; a table of term p-values cannot reconstruct a running curve.

A zero-centered TF/regulon comparison uses `interactive_enrichment_lollipop`; read `skills/diverging-tf-lollipop/SKILL.md` for the direction, color and significance-size conventions. If both sign and significance are available, encode them separately; do not use negative-log p-value as a signed effect.

Use `gsea_pathway_heatmap` for a pathway-expression composite, `gsea_ridge_nes_plot` for supported enrichment distributions and `forest_plot` for supplied effect estimates with bounds. Check ranking direction, gene identifiers, enrichment-score normalization, multiple-testing correction and any top-N selection. The CLI must not fabricate statistical tests or retrieve substitute gene sets automatically.

## Available engines

`sca_volcano_plot`, `interactive_enrichment_lollipop`, `fgsea_enrichment_plot`, `go_kegg_enrichment_bar_bubble`, `gsea_pathway_heatmap`, `gsea_ridge_nes_plot`, `highlight_effect_plot`, `forest_plot`.

Use `python -m omicscanvas catalog --workflow differential-enrichment` for the current compact list. Read `python -m omicscanvas describe ENGINE` for the chosen contract, schema and Plot Guide; do not load every plugin skill. Then follow `skills/omicscanvas-render/SKILL.md` to plan, validate and render. From another working directory, use an absolute path to `scripts/omicscanvas.py` with the project's Python environment.

If the scientific question or required role remains ambiguous, report the missing information and keep the candidate set open. Do not substitute synthetic data, infer unavailable analyses, or rank visual attractiveness above scientific suitability.
