# vNext Phase 2 — Reference Skill Migration

## Skill

`interactive_enrichment_lollipop` (family: enrichment)

## Added under `plugins/interactive_enrichment_lollipop/vnext/`

| File | Role |
|------|------|
| `metadata.yaml` | registry semantics, guardrails, capabilities |
| `defaults.yaml` | scientific/visual/export defaults (null science not auto-filled) |
| `schema.json` | skill-level mapping constraints |
| `examples/oct4_expected_spec.json` | canonical PlotSpec |

## Pipeline

```text
PlotSpec → schema validate → registry lookup → scientific validate
        → legacy adapter (params.json) → Rscript plot.R
        → figures + reproduction_bundle
```

LLM is not invoked after validation (deterministic boundary).

## Evidence

```bash
python3 -m vnext.cli render \
  --spec plugins/interactive_enrichment_lollipop/vnext/examples/oct4_expected_spec.json \
  --input plugins/interactive_enrichment_lollipop/examples/oct4_enrichment/input/example_input.csv \
  --output /tmp/vnext_oct4 --bundle
# → result.svg/pdf/png + reproduction_bundle/
```

## Adapter

`vnext/adapters/legacy_r.py` maps semantic roles → existing column params (`category_column`, `value_column`, …) and preserves `legacy_params`.
