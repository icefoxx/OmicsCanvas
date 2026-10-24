# vNext Phase 6 — Skill Migration Status

## Fully migrated (vNext architecture)

| Skill | Family | Notes |
|-------|--------|-------|
| `interactive_enrichment_lollipop` | enrichment | metadata, defaults, schema, validator rules, adapter, bundle, tests |

## Registry-listed (legacy-compatible, not fully migrated)

All other plugins with `config.yaml` (~44) appear in `vnext/registry/registry.yaml` with `capabilities.vnext_migrated: false` (except the reference skill).

They still run via the existing `plot_web` → `params.json` → `Rscript` path.

## Suggested next migrations

1. enrichment: `fgsea_enrichment_plot`
2. scatter / volcano: `sca_volcano_plot`
3. expression / statistics: `exp_stat_plot`, `stat_plot`
4. heatmaps: `group_heatmap`, `threshold_matrix_heatmap`
5. dim reduction: `advanced_dim_plot`
6. overlap / flow: `dynamic_venn_diagram`, `alluvial_plot`

Do not force enrichment PlotSpec mapping onto unrelated families.
