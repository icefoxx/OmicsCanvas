# Plot registry (v1.0)

Implements `01_plot_registry_refactor_v1.0.md`. Metadata only — plotting engines are unchanged.

## Layout

| Path | Role |
|---|---|
| `vocab.yaml` | Approved contexts, tasks, roles, parameter groups |
| `overrides.yaml` | Curated family metadata, UMAP reference variants, example classifications |
| `schema.json` | JSON schema for the generated registry |
| `registry.json` | Generated catalog (rebuild with the CLI) |
| `reports/` | Inventory, classification, migration notes |

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
