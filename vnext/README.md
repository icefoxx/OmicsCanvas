# OmicsCanvas vNext

Skill-constrained, reproducible visualization framework.

```text
User / AI intent  or  Studio params.json
    → PlotSpec (semantic roles, statistics, export, legacy_params)
    → schema + registry + scientific validation (global → family → skill rules)
    → deterministic adapter → R renderer (seeded)
    → figure + provenance bundle (inputs, checksums, methods, runtime, validation)
```

**Design rule:** an LLM may populate a PlotSpec. After validation it must not
control rendering logic or scientific repairs.

## Layout

| Path | Role |
| --- | --- |
| `plotspec/` | PlotSpec JSON Schema (`schema.json`) + load/dump/validate helpers |
| `migrate/rules.yaml` | Curated knowledge: canonical roles, families, per-skill roles/statistics/autodetect |
| `migrate/generator.py` | Generates `plugins/<id>/vnext/metadata.yaml` (column detection from schema + examples) |
| `adapters/legacy_r.py` | Metadata-driven PlotSpec ⇄ params.json adapter; renders through plot_web's runner |
| `validate/scientific.py` | Scientific guardrails (resolves roles against the input tables) |
| `validate/pipeline.py` | schema → registry → scientific validation boundary |
| `provenance/` | Hashing, reproduction bundles, pixel comparison |
| `benchmark/guardrails.py` | Fault-injection and reproduction benchmarks |
| `registry/registry.yaml` | Skill registry, built from every plugin's metadata |

## Commands

```bash
# Regenerate metadata for all plugins (after editing vnext/migrate/rules.yaml) + rebuild registry
python -m vnext.cli migrate

# Validate a PlotSpec against its input table(s)
python -m vnext.cli validate --spec plotspec.json --input data.csv [--input enrichment=enr.csv]

# Render with a reproduction bundle, then reproduce from the bundle alone
python -m vnext.cli render --spec plotspec.json --input data.csv --output /tmp/out --bundle
python -m vnext.cli reproduce --bundle-dir /tmp/out/reproduction_bundle --output /tmp/repro --compare

# Benchmarks (see docs/vnext/vNext_09_full_migration_report.md)
python -m vnext.cli benchmark --render --jobs 6 --out docs/vnext/benchmark_guardrails.json
python -m vnext.cli benchmark --reproduce --jobs 1 --out docs/vnext/benchmark_reproduction.json
```

## Adding a plugin

1. Add the plugin as usual (`config.yaml`, `params_schema.json`, examples).
2. `python -m vnext.cli migrate <plugin_id>` — review the generated `vnext/metadata.yaml`.
3. If a column parameter was missed or misread, or the plugin has statistics
   parameters, add an entry under `skills:` in `vnext/migrate/rules.yaml` and re-run migrate.
4. `pytest vnext/tests` checks that metadata is current, the example params
   round-trip losslessly, and clean examples raise no scientific errors.

## plot_web integration

Every plot_web job builds a PlotSpec and validates it before rendering
(`plot_web/server/plotspec.py`); `PLOT_VALIDATION_MODE=warn|enforce|off`
(default `warn`). Results expose `plotspec`, `validation` and `bundle` downloads,
and Studio can export/import PlotSpecs.

## Provider-neutral plotting CLI and skills

For compact discovery, layered research-scenario skills, schema parameter overrides and
checksum-bound plans, see [the portable CLI guide](../docs/cli/README.md).
`python -m omicscanvas` wraps this existing deterministic adapter and reproduction layer;
it does not require a running web server or a model provider. Start with
`skills/omicscanvas-router/SKILL.md` in any assistant with local file and shell tools.
