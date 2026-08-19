# Interactive Sankey Plot

Run:

```bash
Rscript plugins/interactive_sankey_plot/plot.R --input flows.csv --params params.json --output output_dir --nodes nodes.csv
```

The flow input is CSV, TSV, or TXT with `source`, `target`, and numeric `value`; `stage`, `source_stage`, `target_stage`, `group`, `color`, and `label` are optional. A node table may provide `id`, `label`, `stage`, `order`, `color`, `x`, `y`, and `highlight`. Static SVG/PDF/PNG uses deterministic Bezier ribbons and rectangular nodes. HTML uses Plotly Sankey with draggable nodes, zoom/pan, hover, and selection support. See `params_schema.json` for all customization groups.

Examples are run with `run_all_examples.sh`.
