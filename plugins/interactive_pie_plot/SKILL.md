# Interactive pie plot skill

Use this plugin for compositional category data when a solid pie or a hollow donut is needed. Prefer explicit `category_column` and `value_column` names for automation. `inner_radius` controls the hole from 0 to less than 1; `hollow_size` is its alias and the effective clamped value is recorded in `figure.json`.

Use data controls for aggregation/filtering/order, pie and colors for geometry, labels/legend for publication styling, and interaction for Plotly behavior. The runtime emits static SVG/PDF/PNG, interactive HTML, metadata, logs, and the used data table; filtered runs also emit `selected_rows.csv`.
