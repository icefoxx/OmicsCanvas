# Expression Statistic Plot

Standardized BioFigureAI wrapper for the original SCA `expStatPlot()` function.

## Run

```bash
Rscript plugins/exp_stat_plot/plot.R \
  --input plugins/exp_stat_plot/example_metadata.csv \
  --expr plugins/exp_stat_plot/example_expression.csv \
  --params plugins/exp_stat_plot/example_violin_params.json \
  --output /tmp/exp_stat_violin_out
```

Every successful run writes `result.svg`, `result.pdf`, `result.png`, `figure.json`, `run.log`, and `selected_rows.csv`.

## Inputs

- `--input`: metadata table. The first column is used as cell/sample id unless `id_column` is set.
- `--expr`: optional expression matrix. The first column is gene/feature id unless `feature_id_column` is set.
- `stat_columns`/`features` may name either metadata numeric columns or expression matrix rows.

## Key Parameters

- Data selection: `rows_include`, `rows_exclude`, `stat_columns`, `group_column`, `split_column`, `background_column`
- Plot mode: `plot_type` = `violin`, `box`, `bar`, `dot`, or `col`
- Color mode: `fill_by` = `group`, `feature`, or `expression`
- Layout: `stack`, `flip`, `seperate_group`, `same_y_lims`, `width`, `height`
- Details: `add_box`, `add_dot`, `add_trend`, `add_stat`, `comparisons`, `sig_label`, `horizontal_lines`, `vertical_lines`
- Labels/theme: `title`, `subtitle`, `xlab`, `ylab`, `legend_position`, `legend_direction`, `theme_args`, `base_size`
- Colors: `palette`, `palcolor`, `group_colors`, `feature_colors`, `background_colors`, `highlight_color`
- High-detail styling: `font_family`, `font_size`, `title_size`, `title_color`, `title_face`, `subtitle_size`, `x_axis_title_size`, `x_axis_title_margin`, `y_axis_title_margin`, `x_axis_text_size`, `x_axis_text_angle`, `y_axis_text_size`, `legend_name`, `legend_title_size`, `legend_text_size`, `legend_key_size`, `colorbar_width`, `colorbar_height`, `panel_fill`, `plot_fill`, `panel_border_color`, `grid_show`, `grid_major_y_color`, `facet_text_x_size`, `facet_background_fill`, `plot_margin`
- Layer details: `violin_scale`, `violin_trim`, `violin_color`, `violin_linewidth`, `boxplot_width`, `boxplot_color`, `boxplot_fill`, `boxplot_linewidth`, `median_point_size`, `median_point_shape`, `bar_width`, `bar_color`, `errorbar_width`, `zero_line_show`, `dot_shape`, `dot_count_shape`, `dot_count_max_size`, `dot_count_legend_title`, `col_width`, `col_color`, `col_group_border_show`, `highlight_shape`

Both original SCA names such as `group.by` and frontend-friendly names such as `group_column` are accepted.

## Highly Customized Example

```bash
Rscript plugins/exp_stat_plot/plot.R \
  --input plugins/exp_stat_plot/example_metadata.csv \
  --expr plugins/exp_stat_plot/example_expression.csv \
  --params plugins/exp_stat_plot/example_custom_style_params.json \
  --output /tmp/exp_stat_custom_style_out
```
## Reproducible examples

Bundles are in `plugins/exp_stat_plot/examples/<id>/`. Each contains `params.json`, copied command inputs under `input/`, and `expected/result.png`. `manifest.json` is the machine-readable entry point and records how to rerun the example.

