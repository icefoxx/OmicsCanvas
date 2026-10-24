# Plot plugin standards

Binding rules for **adding or changing a plot** in OmicsCanvas. They apply to people and to coding
agents alike. A plugin is done only when it meets every MUST below and passes the quality gates in
[06](06_quality_gates.md).

| Document | Covers |
|---|---|
| [01 Plugin contract](01_plugin_contract.md) | Directory layout, CLI, `config.yaml`, outputs, `error.json`, `figure.json` |
| [02 Parameter schema](02_params_schema.md) | `params_schema.json` format, control types, shared parameter names |
| [03 R implementation](03_r_implementation.md) | Code rules, devices, shared helpers, layout rules |
| [04 Classification](04_classification.md) | Studio category, registry family, chart type, vNext family; when to add a category |
| [05 Examples and gallery](05_examples_and_gallery.md) | Example bundles, baselines, gallery images, naming |
| [06 Quality gates](06_quality_gates.md) | Commands that must pass, visual review checklist |

Tooling: `templates/plugin/` (working skeleton), `scripts/new_plugin.py` (scaffold),
`scripts/check_plugin_standards.py` (automatic rule check; rule ids such as `S005` refer to these
documents), `scripts/param_sensitivity.py`, `scripts/smoke_plugins.py`, `scripts/sync_gallery.py`.
Agent entry point: `skills/omics-plot-plugins/SKILL.md`.

## First decision: new plugin, or a variant of an existing one?

Before creating anything, search the existing plugins (table in [04](04_classification.md#current-assignments)).

- **Same data roles and same visual grammar** as an existing plugin (e.g. another style of UMAP,
  another volcano colouring) → extend that plugin: new parameters and a new example. Do not fork.
- **Same visual grammar, different data/analysis** (e.g. a lollipop for a new statistic) → prefer
  extending the plugin if the parameters stay coherent; otherwise a new plugin in the same category.
- **New visual grammar** → new plugin.

## Workflow for a new plugin

```bash
python scripts/new_plugin.py my_plot --name "My Plot" --description "What it shows." \
    --category Scatter --subcategory General          # 1. scaffold from the template
# 2. implement plot.R + params_schema.json (01–03)
# 3. classify: overrides.yaml, CHART_CATEGORY_TAXONOMY, vnext rules.yaml (04)
python -m plot_web.plot_registry build && python -m vnext.cli migrate
python scripts/smoke_plugins.py my_plot --update-baseline   # 4. examples + baselines (05)
python scripts/sync_gallery.py my_plot
python scripts/check_plugin_standards.py my_plot           # 5. gates (06)
python scripts/param_sensitivity.py my_plot
python scripts/smoke_plugins.py --compare
pytest -q plot_web/tests vnext/tests
```

## The MUST list (summary)

1. **Contract**: `Rscript plot.R --input … --params … --output …`; writes `result.svg`, `result.pdf`,
   `result.png`, `figure.json`, `run.log`; on failure `error.json` and a non-zero exit. (01)
2. **config.yaml** complete: `id` = directory name, `name`, `version`, `description`, `language`,
   `entrypoint`, `category` from the allowed list, `subcategory`, `status`, `inputs` with `id`/`type`. (01, 04)
3. **Every schema parameter is typed, read by the code, and visibly changes the figure** in at least
   one documented mode. No dead controls, no placeholder defaults. (02)
4. **Shared names**: reuse the parameter names in [02](02_params_schema.md#shared-parameter-names);
   do not invent a synonym for an existing concept. (02)
5. **R rules**: `params[['key']]` (never `params$key`); `cairo_pdf` and `ragg::agg_png`; no
   `set.seed(<number>)`; no absolute paths; shared helpers from `R/sca/` and `R/runtime/`. (03)
6. **Layout**: nothing clipped or overlapping in any example — legends fit, labels inside the
   canvas, no space reserved for elements that are not drawn. (03, 06)
7. **Classified** in all four layers; a new category only through the procedure in 04. (04)
8. **Examples**: at least one bundle per major mode with `expected/result.png`; no third-party tool
   names or placeholder text; demos derived from external reference figures are titled `CAB_demo`. (05)
9. **Gates pass**: standards check (no new violations), parameter sensitivity (no crash, no
   unexplained no-effect), image regression, tests, and a visual review of every example. (06)
