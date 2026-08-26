# vNext Phase 3 — Scientific Validation Framework

## Layers

1. **Global** (`vnext/validate/scientific.py`): empty data, missing mapped columns, non-finite values, raw-p vs FDR labeling.
2. **Family — enrichment**: require `category` + signed effect; warn if effect is not bidirectional.
3. **Skill — interactive_enrichment_lollipop**: stem-to-zero recommendation; reject negative size/gene_count.

## Severity

- `error`: blocks render (`valid=false`)
- `warning`: recorded, does not silently repair
- `info`: reserved

## Orchestration

`vnext/validate/pipeline.py` combines schema + registry + scientific checks.

## Tests

- `test_scientific_validator_requires_signed_effect` asserts `MISSING_SIGNED_EFFECT` on invalid mapping.
- OCT4 canonical spec passes full pipeline validation.
