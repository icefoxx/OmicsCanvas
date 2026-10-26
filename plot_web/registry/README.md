# Plot registry (v1.0)

Implements `docs/design/01_plot_registry_refactor_v1.0.md`. Metadata only — plotting engines are unchanged.

## Layout

| Path | Role |
|---|---|
| `vocab.yaml` | Approved contexts, tasks, roles, parameter groups |
| `overrides.yaml` | Curated family metadata, UMAP reference variants, example classifications |
| `schema.json` | JSON schema for the generated registry |
| `registry.json` | Generated catalog (rebuild with the CLI) |
| `reports/` | Inventory, classification, migration notes |
| `guides/<family_id>.yaml` | Curated Plot Guide text, local demo scenarios, inputs, cautions and customization controls |
| `literature.yaml` | Verified citations; method references are distinguished from published use cases |

## Plot Guide coverage

Edit guide YAML, not the generated registry. Each example must reference a bundle in
the family's own `engine_plugin_id`, with a valid manifest, input, parameters and
`expected/result.png`. Use different bundles for independent examples. Do not invent
extra demos or paper figures to reach a count; record gaps in `coverage_notes`.
Hidden families can have source documentation without becoming visible in the UI.

`input_requirements` describes required data roles; `customization` lists real schema
parameters with their labels, defaults and optional help. A local demo is not paper
data. Literature entries use `reference_type: method_reference` or
`published_use_case`; only add a figure number when it has been verified. Figure
reuse remains disabled unless rights have been established.

All curated Guide content and the generated report use English. Add verified panels
under a paper's `figure_examples`, with a stable `id`, `figure` label, `title`,
`description`, `plot_families`, HTTPS `figure_url` and `evidence_url`,
`verification: primary_source_caption`, `verified_on` date, `match_type` and an
`adaptation` note. Use `same_grammar` for the same chart grammar and
`related_layout` when transformation or a different layout is required. Describe
unsupported elements explicitly. Set `publication_status: preprint` for preprints.

Link the paper ID from each applicable Guide's `literature_ids`. The API filters
panels by family, so a paper's unrelated panels do not appear in every Guide.
The UI lists figure labels, citations, source links and adaptation instructions
before independent runnable demos. A source may be a verified publisher figure
page, captioned article or PDF; do not invent figure-page URLs. Keep image reuse
disabled unless rights are established. Count distinct references separately from
panel records, and retain literature gaps rather than padding them with weak matches.

Generate and validate the coverage inventory with:

```bash
python scripts/report_plot_guides.py
```

The report separates guide availability, independent local examples, literature
gaps and hidden entries. It validates local references, not R rendering.

## CLI

```bash
python3 -m plot_web.plot_registry build
python3 -m plot_web.plot_registry validate
python3 -m plot_web.plot_registry search umap
```

## Query API (plot_web)

- `GET /api/registry/plots`
- `GET /api/registry/plots/{id}`
- `GET /api/registry/plots/{id}/variants`
- `GET /api/registry/search?q=`
- `GET /api/registry/context/{context}`
- `GET /api/registry/task/{task}`
- `POST /api/registry/compatible`
- `POST /api/registry/recommend`
- `GET /api/registry/legacy/{plotId}/{legacyPresetId}`
- `GET /api/registry/validate`

Legacy plugin routes (`/api/plugins/...`) still work. `engine_plugin_id` is the R plugin directory.
