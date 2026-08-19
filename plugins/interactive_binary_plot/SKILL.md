# Interactive Binary Plot Skill

Use this plugin for binary presence/absence matrices. Supply a wide table with one row identifier followed by 0/1, TRUE/FALSE, or numeric columns. Numeric values are converted using `value_threshold`; explicit `true_values`, `false_values`, and `missing_values` override parsing.

Use `rows_include`, `rows_exclude`, `column_include`, `column_exclude`, explicit order arrays, reversal, sorting, and `transpose` to control matrix layout. Use `group_column` and `true_colors` for row-group colors. `highlight_rows`, `highlight_columns`, and `highlight_cells` produce visible rings and `selected_cells.csv`.

Examples are run through `example_gallery_helpers.sh`; each successful example has an individual PNG, manifest, copied input, and parameter file under `examples/`, plus a gallery index.
