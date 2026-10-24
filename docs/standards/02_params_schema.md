# 02 — Parameter schema (`params_schema.json`)

The schema drives the Studio editor, the vNext adapter and the parameter checks. It must describe
exactly what `plot.R` reads — no more, no less.

## Format

Sectioned map: `{section: {param_key: field}}`. Section names come from the registry vocabulary
(`plot_web/registry/vocab.yaml` → `parameter_groups`): `data_mapping`, `marks`, `colors`, `labels`,
`legend`, `axes`, `theme`, `layout`, `statistics`, `highlight`, `split`, `background`, `density`,
`annotation`, `export`. Order sections from data to export; order fields by importance.

```json
{
  "data_mapping": {
    "x_column": {"type": "column", "label": "X column", "default": "x", "help": "Numeric column for the x axis."}
  },
  "marks": {
    "point_size": {"type": "number", "label": "Point size", "default": 2, "min": 0.1, "max": 10, "step": 0.1}
  }
}
```

Field keys: `type` (required), `label` (required, sentence case, no trailing colon), `default`
(required, the value `plot.R` uses when the key is absent), `help` (one line: unit, meaning of
empty, interaction with other parameters), `options` (select), `min`/`max`/`step` (numbers).
Older plugins use `{"groups": …, "properties": …}`; new plugins use the sectioned map.

## Control types

| `type` | Editor control | Use for |
|---|---|---|
| `column` | column picker | one input column (`*_column`) — rule S006 |
| `columns` | multi column picker | several input columns (`*_columns`) |
| `number` / `integer` | number input | sizes, widths, thresholds, counts |
| `boolean` | switch | `*_show` toggles, modes that are on/off |
| `select` | dropdown | closed sets; `options` required, `default` must be one of them — S004 |
| `color` | colour picker | any single colour — S005 (never `string`: free text crashes R) |
| `string` | text field | titles, labels, free text |
| `textarea` | multi-line text | long text, rule lists |
| `string_array`, `number_array`, `color_array` | list editors | levels to include/exclude, orders, breaks, colour lists |
| `object` | JSON editor | named maps such as `{"group": "#hex"}` |
| `file` | upload | secondary files referenced by params |

Every parameter has a `type` (S002); union types such as `string|integer` are not allowed (S003).

## Rules

1. **No dead controls.** Every key is read by `plot.R` and changes the figure in at least one
   documented mode. `scripts/param_sensitivity.py` must report no crash; any "no effect" must be
   explained by a mode (say so in `help`, e.g. "Only for plot_type = dot_summary").
2. **Defaults match the code.** The schema default and the `plot.R` fallback are the same value.
3. **Empty means automatic.** For text with an automatic value (axis titles, legend titles) the
   default is `""` and `plot.R` treats `""` like a missing key. The UI sends defaults explicitly.
4. **No placeholder or branded defaults** ("Hello world", tool or paper names). Titles default to
   `""`; legend titles default to the mapped column name.
5. **Units are fixed:** `width`/`height` in inches; font sizes in pt; `*_size` of points/lines in
   ggplot units; angles in degrees; alpha/opacity in 0–1; margins in pt.
6. **Closed sets are `select`**, including font faces (`plain`, `bold`, `italic`, `bold.italic`),
   positions and methods. Methods must be ones the code implements.
7. **Statistical choices are parameters**, never hidden constants: test, correction method,
   thresholds, minimum group size (and are declared to vNext, see 04).
8. **Aliases** (old names still read by the code) are not listed in the schema.

## Shared parameter names

Use these names whenever the concept exists in your plot. The count is the number of plugins
already using the name; synonyms in the last column are legacy and must not be used in new code.

| Concept | Name | Plugins | Do not use |
|---|---|---|---|
| Size of the canvas | `width`, `height` (in), `dpi` | 48 | `plot_width`, `fig_width` |
| Title / subtitle / caption | `title`, `subtitle`, `caption`, `title_show`, `title_size`, `title_color`, `title_face`, `title_hjust` | 33 | `show_title`, `main` |
| Axis titles | `xlab`, `ylab`, `xlab_show`, `ylab_show`, `axis_label_size` | 30 | `x_title`, `x_label` |
| Axis text | `x_axis_text_size`, `y_axis_text_size`, `x_axis_text_angle` | 14 | `x_text_angle`, `x_rotate` |
| Axis ranges | `x_limits`, `y_limits` (2-number arrays), `x_breaks`, `y_breaks` | — | `x_min`/`x_max` in new code |
| Legend | `legend_show`, `legend_position`, `legend_direction`, `legend_title`, `legend_title_size`, `legend_text_size`, `legend_key_size`, `legend_nrow`, `legend_ncol` | 41 | `show_legend`, `legend_name` |
| Fonts | `font_family`, `base_size` | 34 | `font`, `font_size` |
| Panel and grid | `panel_background`, `plot_background`, `panel_border_show`, `panel_border_color`, `panel_border_width`, `grid_show`, `grid_color`, `grid_width` | 19 | `show_grid`, `border_show` |
| Margins | `margin_top`, `margin_right`, `margin_bottom`, `margin_left` (pt) | 9 | |
| Colours | `palette` (catalogue id), `group_colors` (`{level: colour}`), `highlight_color`, `na_color` | 16 | `colors`, `color_map`, `group_palette` |
| Points | `point_size`, `point_alpha`, `point_shape`, `point_stroke`, `point_stroke_color` | 13 | `dot_size`, `size` |
| Labels | `label_show`, `label_size`, `label_color`, `selected_labels` | 11 | |
| Column mapping | `id_column`, `x_column`, `y_column`, `group_column`, `value_column`, `split_column`, `feature_columns` | 20 | `group_col`, `group_by` |
| Filtering and order | `rows_include`, `rows_exclude` (row ids), `groups_include`, `groups_exclude`, `group_order`, `features_include`, `features_exclude`, `feature_order`, `top_n` | 22 | `include_groups` |
| Input shape | `input_mode` (`auto`, `wide`, `long`, …) | 19 | |
| Interactivity (HTML only) | `interactive`, `zoom`, `selectable`, `lasso_select`, `tooltip_columns` | 15 | |
| Reproducibility | `seed` (read by the runtime, not by the plugin) | — | `random_seed` |

Before adding a parameter that is not in this table, search for an existing name:
`grep -l '"<candidate>"' plugins/*/params_schema.json`.

### Generic appearance keys handled by the shared theme helper

`R/runtime/omicscanvas_theme.R` maps these keys onto `ggplot2::theme()`: `font_family`,
`base_size`, `title_size|color|face|hjust`, `subtitle_size|color|face|hjust`, `axis_label_size`,
`x|y_axis_title_size|color|margin`, `x|y_axis_text_size`, `x_axis_text_angle`,
`facet_text_x|y_size`, `show_x_axis`, `show_y_axis`, `x|y_axis_ticks_show`, `axis_line_show|color|width`,
`legend_text_size`, `legend_title_size`, `legend_key_size`, `legend_position`, `legend_direction`,
`legend_show`, `panel_background`, `plot_background`, `panel_border_show|color|width`,
`grid_show|color|linetype|minor_color`, `grid_major_x|y_color`, `panel_spacing`, `margin*`,
`aspect_ratio`. If a ggplot plugin exposes one of these and does not implement it itself, apply the
helper with `only = c(...)` listing those keys (03). Same name → same behaviour across plugins.
