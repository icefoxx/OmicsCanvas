---
name: omics-plot-plugins
description: Create, modify, fix, classify, document and test OmicsCanvas plot plugins (plugins/<id>/plot.R + params_schema.json + config.yaml + examples). Use for any task that adds a new plot or chart type, adds or changes plot parameters, fixes a rendering or layout bug, updates examples, baselines or gallery images, or changes plot categories/registry entries. Enforces docs/standards.
---

# OmicsCanvas plot plugins

Agent-agnostic. Every rule lives in `docs/standards/` — this file tells you what to read and do,
in order. Do not finish a plot task without the gates in step 6.

## 0. Read first

1. `docs/standards/README.md` — the MUST list and the workflow (5 minutes).
2. For the task at hand: 01 contract, 02 schema, 03 R rules + layout rules, 04 classification,
   05 examples, 06 gates.
3. The closest existing plugin (table in `docs/standards/04_classification.md#current-assignments`):
   its `params_schema.json`, `README.md`, one example. Match its names and defaults.

## 1. Decide: new plugin or extend an existing one

Same data roles and same visual grammar as an existing plugin → extend it (new parameters, new
example, new registry variant). Only a new visual grammar or incompatible data model justifies a
new plugin. State the decision and the reason in your report.

## 2. New plugin: scaffold, never copy a legacy plugin

```bash
python scripts/new_plugin.py <plugin_id> --name "<Name>" --description "<what it shows>" \
    --category <Studio category> --subcategory <Sub>
```

The template (`templates/plugin/`) already satisfies the contract: CLI, `error.json`,
`figure.json`, `run.log`, ragg/cairo devices, `params[['key']]`, theme helper, example bundle.
Replace the drawing code; keep the structure.

## 3. Implement

- Every schema parameter: typed, read by `plot.R`, visibly effective; defaults identical in schema
  and code; `""` means automatic. Use the shared names in 02 — search before inventing a name.
- R: `params[['key']]` only; never reuse the params variable; no `set.seed(<n>)`; no absolute
  paths; `grDevices::cairo_pdf`; `ragg::agg_png`; shared code from `R/sca/` and
  `R/runtime/omicscanvas_theme.R` (never copy it into the plugin).
- Layout: legends fit, text inside the canvas, no reserved space for undrawn parts — see the ten
  layout rules in 03; they come from real bugs.
- Changing `R/sca/` or `R/runtime/` affects many plugins: run the full regression in step 6.

## 4. Classify (all four layers, 04)

`config.yaml` category/subcategory · `plot_web/registry/overrides.yaml` family (contexts, tasks,
roles from `vocab.yaml`, variants) · `CHART_CATEGORY_TAXONOMY` in `plot_web/plot_registry.py` ·
`vnext/migrate/rules.yaml` family. Create a new category/chart type/context only through the
procedure in 04, never for one plugin.

```bash
python -m plot_web.plot_registry build && python -m vnext.cli migrate
```

## 5. Examples, baselines, gallery (05)

At least `basic` plus one example per major mode. No third-party product names or placeholder
text; demos of external reference figures are titled `CAB_demo`.

```bash
python scripts/smoke_plugins.py <id> --update-baseline   # only after viewing the new images
python scripts/sync_gallery.py <id>
```

Open every `examples/*/expected/result.png` and run the visual checklist in 06.

## 6. Gates — all must pass, report their output

```bash
python scripts/check_plugin_standards.py <id>        # 0 new violation(s)
python scripts/param_sensitivity.py <id>             # no crash; no unexplained "no effect"
python scripts/smoke_plugins.py <id> --compare       # full suite if shared code changed
python -m plot_web.plot_registry validate            # valid, 0 errors
pytest -q plot_web/tests vnext/tests
```

Never add a plugin to `scripts/plugin_standards_baseline.json`. If a gate cannot pass, say which
and why — do not report the task as done.

## Fixing a bug in an existing plugin

Reproduce with the example (or a minimal params file) → fix in the plugin or the shared helper →
re-render and look at the image → `smoke_plugins.py --compare` for every plugin that uses the
changed code → update only the baselines that changed intentionally → `sync_gallery.py` → gates.
Record user-visible fixes in `docs/qa/` when doing an audit.

## Reference

`references/plugin-guide.md` holds older, plugin-specific parameter notes (volcano, correlation,
threshold matrix, ranked panel, quadrant scatter, Venn, fgsea, advanced dim plot). Where it
disagrees with a plugin's `params_schema.json`, the schema wins.
