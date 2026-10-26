# Survival Curve

Kaplan–Meier curves with censor marks, confidence bands and numbers at risk.

## Input

One row per independent observation: numeric nonnegative follow-up time, event 0/1 and optional group. Only right censoring is supported.

## Main parameters

- `time_column`: Follow-up time.
- `event_column`: Event indicator. 0 = right-censored; 1 = event.
- `group_column`: Group column.
- `curve_type`: Curve type.
- `stat_method`: Stat method.
- `landmark_time`: Landmark time. Condition on remaining observed beyond this time; uses original time coordinates.
- `confidence_level`: Confidence level.
- `confidence_show`: Confidence show.
- `confidence_alpha`: Confidence alpha. Only when confidence_show is enabled.
- `censor_show`: Censor show.
- `point_size`: Point size.
- `line_width`: Line width.
- `risk_table_show`: Risk table show.
- `risk_time_count`: Risk time count. Only when risk_table_show is enabled.
- `risk_text_size`: Risk text size. Only when risk_table_show is enabled.
- `title`: Title.
- `subtitle`: Subtitle. Empty uses the automatic description.
- `caption`: Caption.
- `title_size`: Title size. Only when a nonempty title is supplied.
- `palette`: Palette.
- `group_colors`: Named colors. Named categorical colors override the palette.
- `legend_show`: Legend show.
- `legend_position`: Legend position.
- `legend_text_size`: Legend text size.
- `font_family`: Font family.
- `base_size`: Base size.
- `plot_background`: Plot background.
- `grid_show`: Grid show.
- `width`: Width. Inches.
- `height`: Height. Inches.
- `dpi`: Dpi.

## Interpretation

- Competing risks, left censoring and interval censoring require other analyses. 1 − KM is not a competing-risk cumulative incidence estimator.
- Log-rank comparisons do not adjust for confounders. Landmark conditioning changes the eligible observations.

## Run

```bash
Rscript plugins/survival_plot/plot.R \
  --input plugins/survival_plot/examples/basic/input/data.csv \
  --params plugins/survival_plot/examples/basic/params.json \
  --output /tmp/survival_plot_out
```

Optional uploads are listed in `config.yaml`; each uses its input ID as a CLI flag.
The example manifests include input mappings and parameters and input mappings.

Outputs: SVG/PDF/PNG, figure metadata, run log, data used and documented diagnostic
CSV tables. The 3D embedding engine additionally writes an interactive HTML scene.
Errors write `error.json` and remove partial figure files.

## Examples

- `basic`: Survival by cohort.
- `conditional`: Conditional survival.
- `event_probability`: Event probability.

All examples are independently generated synthetic data. Installed dependencies are
ggplot2, jsonlite, optparse, ragg and svglite; mode-specific rendering uses existing
survival, patchwork, ggrepel, plotly/htmlwidgets and png packages. No package is
installed automatically.
