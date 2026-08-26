# Migration notes

The plot registry is a metadata layer. Plotting engines (`plugins/*/plot.R`) are unchanged.

## Identifiers

- Plot **family** ids may differ from plugin directory names. Example: `advanced_dim_plot` → `umap_tsne`.
- `engine_plugin_id` is always the existing plugin id used by `/api/plugins/{id}` and Rscripts.
- Legacy example/preset ids resolve through `legacy_presets` and variant `legacy_ids`.

## Compatibility

- Saved configs still use plugin ids and example ids.
- `resolve_legacy_preset(plotId, legacyPresetId)` maps old names to `{variant, preset}`.
- Do not delete example bundles; they are demos in the registry.

## Next phases (not in this task)

- UI card gallery driven by `variants[].preview_asset`
- Parameter panel visibility from `parameter_groups`
- Automatic data-role binding from `data_requirements`
