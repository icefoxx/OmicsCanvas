# 03 — R implementation

Start from `templates/plugin/plot.R`: it already follows every rule below. Write readable,
multi-line R (one statement per line); the long one-liner style of some legacy plugins is not to
be copied.

## Code rules (checked by `scripts/check_plugin_standards.py`)

| Rule | Do | Why |
|---|---|---|
| R001 | Read parameters with `params[['key']]` or a helper (`param()`, `num()`, `flag()`, `chr()`) | `params$key` partially matches: `params$rotate` returns `rotate_labels` when `rotate` is absent |
| — | Never reuse the params variable for something else (`p <- ggplot(...)` when params is `p`) | every later read silently returns the default |
| R002 | Resolve repository files from the script path (`script_dir`, `repo_root`) | absolute paths break on every other machine |
| R003 | No `set.seed(<number>)` | the runtime seeds from `params.seed`; a literal makes `seed` dead |
| R004 | PNG via `ragg::agg_png` (`ggsave(..., device = ragg::agg_png)`) | cairo PNG is not layout-deterministic → image regression flaps |
| R005 | PDF via `grDevices::cairo_pdf` | `pdf()` aborts on fonts it does not know |
| R006/R007 | Write `error.json` on failure and `figure.json` on success | 01 |

Further rules:

- Wrap the body in `main()` and call `tryCatch(main(), error = function(e) fail(...))`.
- Validate inputs early with actionable messages; never let R's own error be the message users see
  when you can name the column or parameter.
- Dropped rows (non-numeric, NA, filtered) are counted and logged, never silently discarded.
- Column mapping: use the mapped column, else a list of conventional names, else fail listing the
  available columns (template `find_column`).
- Numeric parameters: coerce with fallback (`num('x', default)`); booleans accept
  `true/false/"yes"/1` (`flag()`).
- Treat `""` as "automatic" for text with an automatic value (02, rule 3).
- Keep data preparation separate from drawing; write the drawn data to `*_used.csv`.
- Packages: use what is already installed for other plugins (`ggplot2`, `ggrepel`, `patchwork`,
  `plotly`, `htmlwidgets`, `ragg`, `svglite`, `jsonlite`, `optparse`). A new dependency must be
  justified in the README and fail with a clear `error.json` when missing.

## Shared code

- **Theme helper** `R/runtime/omicscanvas_theme.R` — for ggplot plugins, apply the generic
  appearance keys (02) after the plot is final and before saving:

  ```r
  source(file.path(repo_root, 'R', 'runtime', 'omicscanvas_theme.R'), local = TRUE)
  p <- omicscanvas_apply_theme(p, params, only = c('title_size', 'legend_text_size'))
  ```

  `only` lists the keys this plugin does not implement itself, so behaviour is never applied twice.
  Works for patchwork (`&`). Do not use it when the plugin reads the same keys with different
  units or builds names dynamically (`paste0(prefix, '_size')`).
- **SCA helpers** `R/sca/` — the single copy of the single-cell plotting library (`advDimPlot`,
  `statPlot`, `expStatPlot`, …). Source them into `.GlobalEnv` from `<repo>/R/sca`, then
  `omicscanvas_shims.R` (see `load_sca_advdim_reference()` in `plugins/advanced_dim_plot/plot.R`). Never copy
  them into a plugin. A change in `R/sca/` affects every plugin that sources the file: run the full
  image regression. `R/upstream_sca/` is an archived snapshot — do not source or edit it.
- **Palettes**: `palette` takes an id from the palette catalogue (`plot_web/palettes.py`); unknown
  ids fall back to a default with a warning, never an error.

## Layout rules

Each rule comes from a bug found in the 2026-10-23 audit (`docs/qa/plot_bug_audit_2026-10-23.md`).

1. **Legends fit the figure.** Wrap long legend labels; if a requested `legend_nrow`/`ncol` cannot
   fit, raise it and log it. Several legends stack along the free side (one above another when the
   legend is on the right).
2. **Text stays inside the canvas.** Use `clip = 'off'` only when you also bound what can leave the
   panel; clamp boxes/whiskers to user `x_limits`; extend axis expansion so first/last labels and
   rotated ticks are not cut.
3. **No space for elements that are not drawn** (dendrograms, annotation tracks, empty legends).
4. **Rotated top-axis labels** anchor at their start (`hjust = 0, vjust = 0`); bottom-axis rotated
   labels at their end (`hjust = 1`).
5. **Facets with long category labels**: stack facets vertically (`facet_grid(rows = …,
   scales = 'free_y', space = 'free_y')`) so each keeps its own axis.
6. **Plots embedded as grobs** (`annotation_custom`, `as_grob`): remove titles, subtitles, legends
   and margins first — `theme_void()` still draws titles.
7. **Scale names beat `labs()`**: when a scale already has `name = …`, rename the scale, not the label.
8. **Colour bars**: low value at the bottom/left, title above the bar, ticks readable.
9. **Units**: compute every size in inches (`width`, `height`) and pt; never mix cm and inches
   between devices — SVG, PDF and PNG must show the same layout.
10. **Long text labels on points** use `ggrepel` with a bounded `max.overlaps`, or are limited to
    selected/top items; never draw hundreds of overlapping labels by default.

## Scientific correctness

- Never print a p-value as 0: `< 2.2e-16` or scientific notation; proportions (R², fractions)
  with fixed decimals, never scientific.
- Label raw p and adjusted p (FDR) distinctly; legends say which one is mapped.
- Signed effects (log2FC, NES) on a diverging scale centred at 0; magnitudes on a sequential scale.
- Statistical tests and corrections are parameters (02, rule 7) and are recorded in `figure.json`.
- vNext guardrails (`vnext/validate/scientific.py`, family rules) apply to every plugin of the
  family chosen in 04 — read the rules of that family before designing defaults.
