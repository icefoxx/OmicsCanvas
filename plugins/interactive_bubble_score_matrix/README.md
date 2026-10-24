# Interactive Bubble Score Matrix

Run `Rscript plugins/interactive_bubble_score_matrix/plot.R --input matrix.csv --params params.json --output output_dir`.

The wide input format uses a `method` column, numeric metric columns, and one or more score columns. `score_columns` is preferred for multiple right panels; `score_column` remains the one-score shorthand. Use `score_titles`, `score_geoms`, `score_color_sets`, `score_limits`, `score_panel_widths`, and the other per-score arrays or name-keyed objects to customize each panel. Long input with `row_column`, `metric_column`, and `value_column` is also accepted. Metadata columns can remain in the input and are available to filtering/order logic without being plotted.

Static output uses labeled circles, a dotted row grid, a divider, compact adjacent score panels, and independent metric/score scales. Plotly HTML includes row, metric, value, score column, and score in hover text and supports the interaction flags in `params_schema.json`.

Examples are deterministic and can be rendered with `plugins/interactive_bubble_score_matrix/run_all_examples.sh <repo-root>`. Each successful example is copied into a portable `examples/` bundle by the shared gallery helper.
