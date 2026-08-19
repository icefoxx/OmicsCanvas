# Interactive Arc Network Plot

Run `Rscript plugins/interactive_arc_network_plot/plot.R --input edges.csv --params params.json --output output_dir --nodes nodes.csv`.

The edge table requires `source` and `target`; `weight`, `group`, `direction`, `color`, and `label` are optional. An explicit node table and `node_order` preserve a stable left-to-right baseline. Static SVG/PDF/PNG and a Plotly HTML use the same sampled quadratic Bezier geometry. See `params_schema.json` for the full customization surface.

Limitations: HTML hover is implemented for nodes and edges; selection/zoom are Plotly view controls and do not rewrite the saved static geometry. `edge_bundling` and advanced label wrapping are schema-level options reserved for future geometry extensions.
