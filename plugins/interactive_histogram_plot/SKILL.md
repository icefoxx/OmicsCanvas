# Interactive histogram plot skill

Use this plugin for two or more groups overlaid on one numeric x scale. Wide input contains an optional id followed by numeric group columns. Long input contains `value_column`, `group_column`, and optionally `id_column`; explicit mappings are preferred.

The shared bin table is computed once and drives both ggplot2 and Plotly. `bins` or `binwidth`, `bin_method`, `boundary`, `center`, `closed`, `stat`, and `position` control the geometry. `alpha`, `fill_colors`, `outline_colors`, and `outline_width` provide screenshot-like translucent outlined bars. Hover text includes group, bin bounds, count, and values present in each bin.

Successful runs emit SVG, PDF, PNG, Plotly HTML, `figure.json`, logs, normalized values, and selected source rows. Run `run_all_examples.sh /Users/qzhang10/Documents/OmicsCanvas` for reproducible bundles.
