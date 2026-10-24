# Agent instructions — OmicsCanvas

OmicsCanvas is a local-first figure studio: FastAPI web app (`plot_web/`), R plot plugins
(`plugins/<id>/plot.R`), shared R code (`R/sca/`, `R/runtime/`), and the vNext PlotSpec layer
(`vnext/`).

## Plot work follows the standards — no exceptions

Any task that adds a plot, changes plot parameters, fixes a rendering/layout bug, edits examples
or gallery images, or changes plot categories **must** follow `docs/standards/` and the workflow in
`skills/omics-plot-plugins/SKILL.md` (also available as a Claude Code skill). In short:

- New plugin → `python scripts/new_plugin.py …` from `templates/plugin/`; never copy a legacy plugin.
- Classify in all four layers (`docs/standards/04_classification.md`).
- Before reporting done: `python scripts/check_plugin_standards.py <id>` (0 new violations),
  `python scripts/param_sensitivity.py <id>`, `python scripts/smoke_plugins.py <id> --compare`,
  `pytest -q plot_web/tests vnext/tests`, and a visual review of every example image.

## General

- Report gate output faithfully; never update image baselines without looking at the new images.
- No third-party product names or placeholder text in plugins, examples or images.
- Do not edit generated files by hand: `plugins/*/vnext/metadata.yaml`
  (`python -m vnext.cli migrate`), `plot_web/registry/registry.json`
  (`python -m plot_web.plot_registry build`).
- `R/upstream_sca/` is an archived snapshot; the live shared code is `R/sca/`.
