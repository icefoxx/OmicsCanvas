# Interactive Network Plot

Static SVG/PDF/PNG plus a `visNetwork` HTML widget from an edge list or a membership table.

```bash
Rscript plugins/interactive_network_plot/plot.R \
  --input plugins/interactive_network_plot/example_input.csv \
  --nodes plugins/interactive_network_plot/example_nodes.csv \
  --params plugins/interactive_network_plot/example_network_params.json \
  --output /tmp/network_out
```

## Input

- `edge_list`: `source,target` with optional `weight`, `edge_group`, and `directed`.
- `membership`: `group,element` (optional `weight`). Group nodes sit on the inside of a radial layout and members sit on the outer ring.

CSV, TSV, and TXT are accepted. An optional nodes table may include `id`, `label`, `group`, `type`, `size`, `color`, `x`, `y`, `highlight`, and `tooltip`.

## Layout presets

`layout_algorithm` chooses a starting arrangement. The HTML view keeps those coordinates (physics off by default) so nodes can be dragged into a custom arrangement. `save_positions` writes `positions.csv` (`id,x,y`) that can be reused as a nodes table with `layout_algorithm = manual`.

| Value | Arrangement |
|---|---|
| `fr` | Force-directed (Fruchterman–Reingold) |
| `kk` | Force-directed (Kamada–Kawai) |
| `circle` | Single ring; `layout_sort` orders nodes around the ring |
| `concentric` | One ring per group; `ring_gap` is the radius step; `group_order` sets inner-to-outer |
| `radial` | Group nodes inside, members outside in sectors (membership maps) |
| `stress` | Stress / MDS layout |
| `hierarchical` | Tree layout |
| `manual` | `x` and `y` columns on the nodes table |

Composition controls that combine with the presets: `layout_sort` (`none` / `degree` / `size` / `label`), `edge_weighted`, `edge_style` (`link` / `arc`), `node_size_by`, `node_color_mode` (`group` / `gradient`).

Drag, zoom, hover, neighbour highlighting, and navigation buttons are HTML-only (`drag_nodes`, `zoom_view`, `tooltip_show`, `highlight_neighborhood`, `navigation_buttons`). Turn `physics_enabled` on only when you want vis.js to ignore the preset and simulate forces.

Outputs always include `result.svg`, `result.pdf`, `result.png`, `result.html`, `figure.json`, `nodes_used.csv`, `edges_used.csv`, and `run.log`. Highlighted runs also write `selected_nodes.csv`.
