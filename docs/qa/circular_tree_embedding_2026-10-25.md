# Circular tree + embedding — 2026-10-25

## Implementation

New plugin `circular_tree_embedding` combines an existing embedding with a radial
tree and nested annotation rings. This is a new composite grammar and data model,
so it was scaffolded with `scripts/new_plugin.py` rather than copied from a legacy
plugin. Classified as Dimension / Embedding, with scatter and dendrogram chart
memberships, single-cell/clustering contexts and vNext embedding guardrails.

The center can be colored by any level of the hierarchy. Colors remain stable
across tree modes; overrides are shared between center and rings. Annotation trees
encode topology, not distances. Similarity trees use per-leaf feature means,
optional standardization and Euclidean hierarchical clustering, never embedding
coordinates. Branch ordering and disjoint ring runs are retained. Coordinates
are scaled isotropically. Convex hulls are descriptive, not density or uncertainty.
Ring names identify levels at the opening. SVG, PDF, PNG and drawn-data exports
are available. Three independently simulated examples include 2,180 cells each.

English Guide, reference panel, workflow skill, AI recommendation routing and
vNext skill metadata are included. The verified reference is [Lee et al., Nature
657, 988–1002 (2026), Figure 2a](https://www.nature.com/articles/s41586-025-09573-z#Fig2).
The article describes eight classes, 27 subclasses and 65 subtypes; demos use 17
synthetic leaves and do not reproduce the original atlas or its iterative analysis.

## Validation

- Standards: one plugin checked, zero new violations and zero baselined.
- Sensitivity: 26 parameters, zero crashes, two explained no-effect results:
  linkage and feature standardization only affect similarity mode. Both controls
  document this condition. Mapping/object/list fields are outside the scanner;
  integration tests cover color consistency, isotropic scaling, feature-based
  clustering and invalid hierarchy/features with stale-output removal.
- Three new baselines were created after reviewing each render. Final baseline
  updates used zero tolerance to include small ring-label changes. Two subsequent
  zero-tolerance compare runs passed 3/3 with 0.000% pixel changes each.
- Reviewed all three PNGs and a rendered PDF. No previous-plugin baseline changed.
- Full regression: 82/239 pass, 133 DIFF, 24 FAIL. The three new examples passed;
  other results retain the preceding 79/236 distribution. Existing failures are
  listed in [the prior validation](plot_guide_validation_2026-10-25.md).
- Full test run before final metadata refresh: 128 passed, one failed because
  example mapping updates required regenerated metadata. Metadata was regenerated
  using the CLI and the failing freshness check then passed. Full-suite validation
  will be repeated with the following catalog additions.
- Registry: 58 plots, valid, zero errors, 33 existing warnings. vNext migration:
  58 migrated; no plugin warnings; valid registry.
- Workflow skill validation passed. Four routing tests passed, including bilingual
  combined-chart requests and preserving the ordinary UMAP recommendation.

## Web verification

Loaded the built-in preview without R execution, rendered from the editor, switched
center color from subclass to subtype, then switched to similarity mode. Rendering
succeeded and scientific checks passed. Explicit mappings were added to the example
presets so the editor displays the leaf, hierarchy and feature selections.

## Reproduce

```bash
plot_web/.venv/bin/python scripts/check_plugin_standards.py circular_tree_embedding
plot_web/.venv/bin/python scripts/param_sensitivity.py circular_tree_embedding --jobs 2
plot_web/.venv/bin/python scripts/smoke_plugins.py circular_tree_embedding --compare --tolerance 0
plot_web/.venv/bin/python -m plot_web.plot_registry build
plot_web/.venv/bin/python -m vnext.cli migrate
plot_web/.venv/bin/python -m pytest -q plot_web/tests vnext/tests
```
