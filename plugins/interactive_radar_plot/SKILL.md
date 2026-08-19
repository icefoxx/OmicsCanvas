# Interactive radar plot skill

Use this plugin for multi-group profiles across named metrics. Wide input has one metric column and one numeric column per group; long input repeats metric with `group` and `value`. Set `input_mode`, column mappings, `group_order`, and `metric_order` explicitly when reproducibility matters.

Use `normalize` with `normalization` (`minmax` or `zscore`) when metrics need a common scale. `radial_limits` and `radial_breaks` control the radial axis. Named `group_colors`, highlights, labels, title, legend, grid, and interaction parameters support publication and exploratory styling. Every successful run emits static files, Plotly HTML, metadata, selected rows, and a log.
