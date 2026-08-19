# Interactive Bubble Score Matrix

Use this plugin for benchmark tables where each method has several numeric metrics and one or more score columns. Prefer explicit `metric_columns`, `score_columns`, `score_titles`, and `row_order` parameters. `score_column` is retained for one-score configurations. Every score panel is intentionally scaled independently from the left metrics and other scores; this is recorded per panel in `figure.json`.

Required outputs are `result.svg`, `result.pdf`, `result.png`, `result.html`, `figure.json`, `run.log`, `matrix_data_used.csv`, `score_data_used.csv`, and `row_order.csv`. Failed runs write `error.json` and remove stale successful artifacts before rendering.
