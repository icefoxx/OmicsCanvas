# Specialty renderer implementation QA

Date: 2026-10-25. This report covers the source-collection audit, 22 new engines, and extensions to existing line/circular-heatmap engines. The preceding radial tree + embedding work is documented [separately](circular_tree_embedding_2026-10-25.md).

## Result

- Registry: 80 entries, 66 visible families, 80 English Guides; registry validation has zero errors and 33 pre-existing warnings.
- 53 new-engine demo bundles plus two new variants in existing engines: **55 new runnable examples**. Spatial spots are included in the 53.
- Guide inventory: 203 local demos, 40 references, 77 verified published figure records, zero broken local references. 44 of 66 visible families have a verified published-figure association. All 22 new families currently have method/source links and local examples; additional verified publication panels remain to be curated.
- Repository source inventory: 318 modules at commit `8d7a02c7d00467c45471139b63620571afebbeba`. See the [audit](figureya_audit_2026-10-25.md) and [machine-readable mapping](figureya_module_inventory_2026-10-25.json). Module counts do not imply distinct chart counts or implemented upstream analyses.

## Gates

| Check | Result |
|---|---|
| Plugin standards, all 80 plugins | 0 new violations; 1,571 previously baselined violations remain |
| New-engine image baselines | All 53 visually reviewed before initial baseline creation; no old baselines replaced |
| Strict image comparison, first run | 53/53; every image 0.000% changed |
| Strict image comparison, second run | 53/53; every image 0.000% changed |
| New interval-band and categorical-ring variants | Two strict comparisons each; all four comparisons 0.000% changed |
| Final 3D HTML branding correction | Both static examples rechecked; 0.000% changed |
| Full Python tests | 150 passed; one existing Starlette/httpx deprecation warning. After restoring the four old examples, the affected Guide/standards/migration suite also passed 31/31 |
| Numeric reference tests | 11 passed: censoring, tied AUC/AP, Brier score, agreement limits, ECDF ties, multi-hit sample counts, alignment denominator, invalid inputs and stale auxiliary-table cleanup |
| Workflow routing | Explicit specialty requests select the engine and the scoped plotting workflow; generic embedding requests retain the existing engine |

## Global image regression: existing failures remain

The full 294-example run initially reported **133 passed, 137 image differences and 24 render failures**. Comparison with the earlier 239-example run identified four new differences in the old line/basic, line/smooth, circular-heatmap/basic and circular-heatmap/clustered examples. The cause was filling previously omitted example parameters with explicit schema defaults, which changed theme settings. Those four original parameter sets were restored without touching their image baselines.

A focused strict rerun verifies those four examples and both new variants. After applying those focused results, the verified combined state is **137 passed, 133 pre-existing image differences and 24 pre-existing render failures**. See the [machine-readable regression summary](figureya_regression_summary_2026-10-25.json) for exact remaining IDs. The global image gate therefore remains failing; it is not presented as a clean pass. New renderers introduce no remaining image failures or differences.

Existing failures include optional-package/runtime problems in legacy alluvial, binary-comparison, bubble-score, correlation, motif, Sankey and statistical wrappers. Their previous baselines were preserved for diagnosis. These are distinct from new-engine validation and from whether an English Guide exists.

## Parameter sensitivity

See [the machine-readable sensitivity results](figureya_parameter_sensitivity_2026-10-25.json). The scan covers 24 affected engines and 443 scalar controls with zero crashes. Column mappings, arrays, named-color objects and file outputs are excluded by the scanner; input/scientific reference tests and representative examples supplement it. A first-example scan does not prove every possible combination of controls.

| Control with no pixel change in the selected fixture | Reason |
|---|---|
| Binary calibration bins | Active only for calibration; fixture is ROC |
| Binary threshold minimum / maximum | Active only for decision curves |
| Binary point size | Active only for calibration markers |
| Circular-genome point size | Active only for point tracks |
| Spatial point size | Active only for spot geometry; fixture is polygon |
| Annotated-tree gap | Active only for circular layout |
| Circular-distribution panels per row | Three metrics with either three or six columns remain one row |
| Linked-matrix dot size | Active only for dot-matrix mode |
| Line-band opacity | Active only when the supplied band is enabled |

The separate demo set exercises ROC/PR/calibration/DCA/supplied curves, survival/conditional/event probability, linear/log forest axes, genomic heatmap/bar/point/linear tracks, DNA/protein alignments, circular/rectangular trees, feature scaling, spatial polygons/spots/backgrounds, and both composite-panel modes.

## Bugs and layout corrections

- Schema normalization preserves integer types, zero-valued bounds and numeric min/max/step. Sensitivity perturbations remain inside valid bounds.
- Render cache fingerprints include the new shared `R/plots` helpers.
- A mapped third embedding axis is checked for numeric coordinates. Explicit categorical circular rings bypass only their numeric-value check; numeric heatmaps still reject categories.
- Survival curves and risk tables use matching time limits and breaks; redundant legends are suppressed. Conditional population counts reflect eligible observations.
- Mutation frequencies count altered samples once despite multiple alterations. Horizontal marginal bars use an explicit orientation and share the matrix row extent.
- Alignment consensus bars and residue tiles share exact position limits.
- Genomic point tracks retain their markers and identify track order. Categorical rings name their inner-to-outer order.
- Multi-panel titles, subtitle wrapping and legend placement were checked visually. The live 3D legend honors its placement/font settings and avoids the floating canvas tools; library branding is hidden.
- Failed new-engine runs remove owned old figures and auxiliary tables. Invalid scientific input produces an actionable error instead of a stale preview.
- Source-module links in Literature are compact, with additional links in a disclosure. They are not mislabeled as verified publication panels.

## Visual and interface review

Every new PNG was reviewed in contact sheets, with full-resolution follow-up on corrected or dense examples. A survival PDF was rasterized and reviewed independently. Existing line and circular-heatmap examples were also inspected while preserving their original baselines.

The local server was restarted on port 8010. Browser checks confirmed gallery discovery of the two 3D types, immediate built-in previews, live survival rendering, switching to event probability, passing scientific checks, PDF export, and the live 3D scene with local widget dependencies. HTML may use a companion `result_files` directory when the runtime has no document converter; the served HTML view resolves those assets, and the reproduction bundle is the portable export.

Proof: [survival editor](screenshots/specialty-survival-editor-2026-10-25.png) and [3D editor after dragging to rotate](screenshots/specialty-3d-editor-2026-10-25.png).

## Reviewed examples

| Engine | Reviewed demos |
|---|---|
| `survival_plot` | `basic`, `conditional`, `event_probability` |
| `binary_evaluation_plot` | `basic`, `precision_recall`, `calibration`, `decision_curve`, `supplied_curve` |
| `forest_plot` | `basic`, `log_ratio`, `signed_effects` |
| `oncoprint_plot` | `basic`, `input_order` |
| `manhattan_qq_plot` | `basic`, `manhattan`, `qq` |
| `bland_altman_plot` | `basic`, `percent` |
| `swimmer_plot` | `basic`, `staggered` |
| `protein_variant_plot` | `basic`, `variants_only` |
| `clonal_fish_plot` | `basic`, `percent` |
| `sequence_alignment_plot` | `basic`, `protein` |
| `circular_genomic_plot` | `basic`, `bars`, `points`, `linear` |
| `nomogram_plot` | `basic`, `compact` |
| `interactive_3d_scatter` | `basic`, `alternate_view` |
| `bar3d_plot` | `basic`, `free_scale` |
| `radviz_plot` | `basic`, `minmax` |
| `ecdf_plot` | `basic`, `steps` |
| `spatial_region_plot` | `basic`, `tissue`, `spots` |
| `annotated_tree_plot` | `basic`, `circular` |
| `circular_distribution_plot` | `basic`, `shared_range` |
| `embedding_vector_plot` | `basic`, `radial` |
| `linked_matrix_network_plot` | `basic`, `dot_matrix` |
| `risk_stratification_panel` | `basic`, `scores_only` |
| `line_plot` | `basic`, `smooth`, `interval_band` |
| `circular_heatmap` | `basic`, `clustered`, `categorical` |

## Reproduce

```bash
plot_web/.venv/bin/python scripts/check_plugin_standards.py
plot_web/.venv/bin/python scripts/param_sensitivity.py <plugin_id>
plot_web/.venv/bin/python scripts/smoke_plugins.py <plugin_id> --compare --tolerance 0
plot_web/.venv/bin/python scripts/smoke_plugins.py --compare --jobs 3
plot_web/.venv/bin/python -m pytest -q plot_web/tests vnext/tests
plot_web/.venv/bin/python -m plot_web.plot_registry validate
plot_web/.venv/bin/python scripts/report_plot_guides.py
```
