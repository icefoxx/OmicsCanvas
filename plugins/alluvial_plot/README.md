# Alluvial / Multi-Stage Flow Plot

Publication-style **alluvial / Sankey-flow** chart with vertical strata bars and
flowing ribbons between sequential stages — matching clone-lineage and
state-transition figures (e.g. `HX_001 → HX_002 → HX_003 → …`).

## Why this plugin

| Plugin | Style |
|--------|--------|
| `interactive_sankey_plot` | Node–edge Sankey (small nodes, free layout) |
| `stat_plot` (`plot_type=sankey`) | Metadata level counts via SCA ggsankey |
| **`alluvial_plot`** | **Multi-stage alluvial with tall strata + ribbons** (this image style) |

## Input modes

1. **wide** (default for demos): one row per entity/path  
   `id, stage1, stage2, stage3, … [, weight]`
2. **long**: `id, stage, node [, weight]`
3. **edges**: `source, target, value [, source_stage, target_stage]`

## Run

```bash
Rscript plugins/alluvial_plot/plot.R \
  --input plugins/alluvial_plot/example_input.csv \
  --params plugins/alluvial_plot/example_hx_lineage_params.json \
  --output /tmp/alluvial_out
```

## Outputs

- `result.svg` / `result.pdf` / `result.png`
- `figure.json`, `run.log`
- `alluvia_used.csv`, `nodes_used.csv`

## Key parameters

- **Stages**: `stage_columns`, `stage_order`, `stage_labels`
- **Flows**: `flow_alpha`, `flow_smooth`, `flow_type` (`sankey`|`alluvial`), `palette`, `node_colors`
- **Strata**: `stratum_width`, `stratum_border_color`, `stratum_border_width`
- **Labels**: `label_show`, `label_size`, `label_color`, `label_fill`
- **Canvas**: `width`, `height`, `dpi`, `title`, `legend_show`
