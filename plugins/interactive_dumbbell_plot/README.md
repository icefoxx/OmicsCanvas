# Interactive Dumbbell Plot

Run: `Rscript plugins/interactive_dumbbell_plot/plot.R --input input.csv --params params.json --output output_dir`.

The CSV may be wide (`category`, `group1_value`, `group2_value`, here `school,Women,Men`) or long (`category`, `group`, `value`). Select columns and group names in `params.json`; aliases such as `category_col`, `group_col`, and `value_col` are accepted. Filtering, top-N selection, stable category ordering, sorting, and optional labels are in the **data** group.

**layout** controls orientation/order, limits, breaks, expansion, and spacing. **stem** controls the connecting grey line. **points** controls shapes, sizes, alpha, borders, named `group_colors`, and highlights. **labels** controls title strip, axis text, labels, and typography. **legend** and **theme** control placement, grids, backgrounds, borders, fonts, and margins. **interaction** enables Plotly hover, zoom/pan, reset, box/lasso selection controls; static SVG/PDF/PNG are made with ggplot2. `selected_rows.csv` records the rows used after filtering.

Three runnable examples are supplied. Reproduce all examples and portable bundles with `plugins/interactive_dumbbell_plot/run_all_examples.sh <repo-root>`; bundles are written under `examples/` and the gallery under `all_examples_gallery/`.
