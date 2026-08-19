# Interactive Pie / Donut Plot

Run `Rscript plugins/interactive_pie_plot/plot.R --input input.csv --params params.json --output output_dir`.

CSV, TSV, and TXT tables are accepted. Set `category_column` and `value_column` explicitly, or the plugin detects a category and the first numeric column. Values are aggregated by category; an optional `group_column` makes category/group slices. Optional label and color columns are retained. Row and category include/exclude filters, sorting, and `top_n` are supported.

Set `mode: "pie"` for a solid pie or `mode: "donut"` and `hole_show: true` for a donut. `inner_radius` is the hollow radius as a fraction of the outer radius and is clamped to 0 through 0.99. `hollow_size` is an alias. Static output uses a real polar ring and disk; HTML uses Plotly's `hole` property. Hole fill, border, and center label are independently configurable.

The data, canvas, pie, colors, labels, legend, hole label, interaction, and output controls are documented in `params_schema.json`. HTML provides hover, legend toggling, zoom/reset controls, and Plotly selection/lasso controls.

Run all three reproducible examples with `plugins/interactive_pie_plot/run_all_examples.sh /Users/qzhang10/Documents/OmicsCanvas`. This creates independent outputs, bundles, manifests, and a gallery.
