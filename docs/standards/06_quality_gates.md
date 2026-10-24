# 06 — Quality gates

A plugin change is complete when all gates pass. Report the actual output of each command; a gate
that was skipped is reported as skipped, not as passed.

## Automatic gates

| # | Command | Pass criterion |
|---|---|---|
| 1 | `python scripts/check_plugin_standards.py <id>` | `0 new violation(s)` |
| 2 | `python scripts/param_sensitivity.py <id>` | no `crash`; every `no effect` explained by a mode and noted in the parameter's `help` |
| 3 | `python scripts/smoke_plugins.py <id> --compare` | all examples pass; then the full suite `python scripts/smoke_plugins.py --compare --jobs 6` when shared code (`R/sca`, `R/runtime`, `plot_web`) changed |
| 4 | `python -m plot_web.plot_registry build && python -m plot_web.plot_registry validate` | `"valid": true`, 0 errors |
| 5 | `python -m vnext.cli migrate` | no warnings for the plugin; `vnext/metadata.yaml` reviewed |
| 6 | `pytest -q plot_web/tests vnext/tests` | all pass |

The standards baseline (`scripts/plugin_standards_baseline.json`) records violations of legacy
plugins. Never add a new plugin to it. When you fix a baselined violation, run
`python scripts/check_plugin_standards.py --update-baseline` so it cannot come back.

## Visual review (every example image, at full size)

- [ ] Title, subtitle, axis titles, tick labels, legend titles and labels are complete — nothing
      clipped at the canvas edge or hidden behind another element.
- [ ] No overlapping text; no legend wider or taller than the figure; long labels wrapped.
- [ ] Colours in the plot match the legend; legend order matches the data order the user asked for.
- [ ] Colour bars run low → high in the reading direction and their titles do not cover ticks.
- [ ] Marks are visible (no white-on-white, no zero-size points, no transparent background in PNG
      unless requested).
- [ ] Numbers are formatted sensibly (no "p = 0", no scientific R², consistent decimals).
- [ ] No empty reserved space (missing dendrogram/annotation, blank facet).
- [ ] Facets, panels and composite figures align; repeated titles are not repeated per panel.
- [ ] SVG, PDF and PNG show the same layout (open at least one PDF).
- [ ] Defaults alone (the `basic` example) give a publication-ready figure.

## Consistency review (against existing plugins)

- [ ] Parameter names follow the shared names (02); no new synonym.
- [ ] Defaults look like siblings in the same category: font family `sans`, `base_size` 11, white
      background, classic theme, legend on the right, title left-aligned.
- [ ] Classification in all four layers (04) matches similar plugins.
- [ ] README follows the template sections (Input, Main parameters, Run, outputs).

## Reporting

In the final report or PR description: what changed, the output summary line of gates 1–3 and 6,
examples whose baselines were updated and why, and any parameter left mode-gated.
