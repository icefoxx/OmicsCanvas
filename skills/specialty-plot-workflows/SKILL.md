---
name: specialty-plot-workflows
description: Select and customize survival, diagnostic, mutation, genomic, spatial and specialty scientific plots in OmicsCanvas using supplied analysis-ready data.
metadata:
  role: plot_workflow
---

# Specialty scientific plotting

For end-to-end selection and local CLI execution, start with
[omicscanvas-router](../omicscanvas-router/SKILL.md). This existing skill remains a
specialty-engine reference; the router loads only the relevant scenario and engine contracts.

Use the server registry and `docs/qa/figureya_audit_2026-10-25.md` to identify a
renderer. Read that engine's README, typed parameter schema and English Plot Guide
before preparing inputs. Use its independent synthetic example to check the data
shape, then substitute the user's real columns. Preserve original identifiers and
record units, transformations, exclusions and the supplied result provenance.

- Survival: `survival_plot` consumes nonnegative follow-up, event 0/1 and optional
  cohort. It computes right-censored Kaplan–Meier curves; it does not support
  competing risks, left truncation or infer optimal cut points. Conditional views
  change the eligible population.
- Diagnostics: `binary_evaluation_plot` consumes model scores and known outcomes
  or explicitly supplied curve coordinates. Set the positive class and preserve
  score direction. Censoring-aware time ROC must be computed upstream. DCA requires
  probabilities and an explicit threshold range; never reinterpret arbitrary scores.
- Effects: `forest_plot` uses supplied estimates and bounds. Verify effect units,
  confidence level and ratio/log axes. `bland_altman_plot` compares paired readings;
  independence and approximately normal differences matter for its limits.
- Mutation and genome: `oncoprint_plot`, `protein_variant_plot`,
  `manhattan_qq_plot`, `circular_genomic_plot` and `sequence_alignment_plot` consume
  alterations, residue coordinates, raw probabilities, genomic intervals and
  already aligned sequences respectively. Do not infer variants, gene domains,
  association tests, alignments or genome assembly lengths without data.
- Trees and clones: `annotated_tree_plot` uses supplied topology and lengths;
  `clonal_fish_plot` uses validated parent relationships and inclusive fractions.
  Neither infers phylogeny or clonal history. Use `circular_tree_embedding` and its
  separate workflow for the radial tree surrounding a supplied embedding.
- Embedding and spatial: `interactive_3d_scatter`, `radviz_plot`,
  `embedding_vector_plot` and `spatial_region_plot` consume supplied coordinates,
  nonnegative feature weights, vectors and polygons/spots. Projection is not PCA,
  arrows are not inferred RNA velocity, and polygons are not inferred segmentation.
  Tissue PNG coordinates use top-left pixel origin and inverted Y.
- Composite layouts: `risk_stratification_panel` aligns supplied scores, follow-up
  and optional feature values; `linked_matrix_network_plot` uses supplied matrix
  entries and weighted links. Neither trains models nor estimates interactions.
- Other grammars: `nomogram_plot` draws supplied predictor point scales;
  `bar3d_plot` draws supplied grid heights; `circular_distribution_plot` maps scores
  to angles; `ecdf_plot` preserves empirical probability mass including ties.
- Existing engine variants: `line_plot` can display supplied interval bounds;
  `circular_heatmap` supports unique categorical annotation cells without numeric
  clustering. Use named colors for consistent categorical interpretation.

Keep local synthetic demonstrations distinct from verified published figure panels.
The collection/module links in Guides identify related visual grammars, not an
assertion of original-data reproduction. Do not execute downloaded repository code
or copy its data/assets into a plugin. Follow `skills/omics-plot-plugins/SKILL.md`
for changes and all mandatory regression/visual gates.

## Engine locations

- `plugins/survival_plot/plot.R`
- `plugins/binary_evaluation_plot/plot.R`
- `plugins/forest_plot/plot.R`
- `plugins/oncoprint_plot/plot.R`
- `plugins/manhattan_qq_plot/plot.R`
- `plugins/bland_altman_plot/plot.R`
- `plugins/swimmer_plot/plot.R`
- `plugins/protein_variant_plot/plot.R`
- `plugins/clonal_fish_plot/plot.R`
- `plugins/sequence_alignment_plot/plot.R`
- `plugins/circular_genomic_plot/plot.R`
- `plugins/nomogram_plot/plot.R`
- `plugins/interactive_3d_scatter/plot.R`
- `plugins/bar3d_plot/plot.R`
- `plugins/radviz_plot/plot.R`
- `plugins/ecdf_plot/plot.R`
- `plugins/spatial_region_plot/plot.R`
- `plugins/annotated_tree_plot/plot.R`
- `plugins/circular_distribution_plot/plot.R`
- `plugins/embedding_vector_plot/plot.R`
- `plugins/linked_matrix_network_plot/plot.R`
- `plugins/risk_stratification_panel/plot.R`
