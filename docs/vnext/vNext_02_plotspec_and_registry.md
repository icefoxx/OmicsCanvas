# vNext Phase 1 — PlotSpec + Registry

## Delivered

| Component | Path |
|-----------|------|
| Common PlotSpec JSON Schema | `vnext/plotspec/schema.json` |
| Load/dump/validate/round-trip | `vnext/plotspec/model.py` |
| Skill registry (45 skills) | `vnext/registry/registry.yaml` |
| Registry builder/validator | `vnext/registry/loader.py` |
| CLI | `python3 -m vnext.cli` |

## Acceptance

- [x] PlotSpec round-trip is lossless for supported fields (`vnext.cli roundtrip`)
- [x] Registry loads without ambiguity/error (`registry build` → `n_skills=45`, `valid=true`)
- [x] Duplicate skill IDs / alias collisions are rejected

## Notes

- PlotSpec `spec_version` is `"1.0"` and independent of skill versions.
- `legacy_params` allows adapters to pass through existing `params.json` fields without inventing science.
- Arbitrary `transform.code` is rejected by schema validation.
