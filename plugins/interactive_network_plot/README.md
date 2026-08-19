# Interactive Network Plot

Creates static SVG/PDF/PNG and a self-contained `visNetwork` HTML widget from an edge list or membership table.

```bash
Rscript plugins/interactive_network_plot/plot.R --input plugins/interactive_network_plot/example_input.csv --nodes plugins/interactive_network_plot/example_nodes.csv --params plugins/interactive_network_plot/example_network_params.json --output /tmp/network_out
```

Input modes: `edge_list` uses `source,target` with optional `weight`, `edge_group`, and `directed`; `membership` uses `group,element` and creates large group nodes connected to smaller member nodes. CSV, TSV, and TXT are accepted. An optional nodes table supports id, label, group/type, size, color, x/y, highlight, and tooltip.

`params_schema.json` documents the data, layout, nodes, edges, legend, canvas/theme, interaction, and output controls. Named color maps are accepted as JSON objects. Aliases include `source/from`, `target/to`, `group`, `element`, `node_size`, and `group_colors`.

The HTML widget supports dragging, zoom/pan, hover tooltips, nearest-neighbor highlighting, selection, and navigation buttons. Set `save_positions` to write `positions.csv` with the initial layout. Browser-dragged positions can be exported through the widget's position workflow and reused as an x/y nodes table.

Outputs always include `result.svg`, `result.pdf`, `result.png`, `result.html`, `figure.json`, `nodes_used.csv`, `edges_used.csv`, and `run.log`; highlighted runs also include `selected_nodes.csv`. Reproducible bundles are written under `examples/` by `run_all_examples.sh`.
