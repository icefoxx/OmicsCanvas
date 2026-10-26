# Risk Stratification Panel

Align supplied risk ranks, event follow-up and selected numeric features.

## Input

One row per unique subject with supplied risk_score, nonnegative follow-up time, event 0/1 and optional group. Optional numeric feature_columns form the aligned heatmap.

## Main parameters

- `id_column`: Id column.
- `value_column`: Value column.
- `time_column`: Time column.
- `event_column`: Event column.
- `group_column`: Group column.
- `feature_columns`: Feature columns.
- `sort_by`: Sort by.
- `heatmap_show`: Heatmap show. Only when feature_columns are selected.
- `scale_features`: Scale features. Only for selected features in the visible heatmap.
- `subject_label_show`: Subject label show.
- `title`: Title.
- `subtitle`: Subtitle. Empty uses the automatic description.
- `caption`: Caption.
- `title_size`: Title size. Only when a nonempty title is supplied.
- `point_alpha`: Point alpha.
- `point_size`: Point size.
- `low_color`: Low color. Selected-feature heatmap only.
- `high_color`: High color. Selected-feature heatmap only.
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

- Risk scores and groups are supplied. No survival model, optimal cutoff or group assignment is inferred.
- Displayed follow-up points are not survival estimates. Per-feature Z-scores are a display transform, not a differential-expression test.

## Run

```bash
Rscript plugins/risk_stratification_panel/plot.R --input plugins/risk_stratification_panel/examples/basic/input/data.csv --params plugins/risk_stratification_panel/examples/basic/params.json --output /tmp/risk_stratification_panel_out
```

Outputs: SVG/PDF/PNG, figure metadata, run log, drawn data and diagnostic CSV tables.
Errors write error.json and remove partial figure files. The examples are independently
generated synthetic measurements. Existing ggplot2/patchwork packages are used; no
dependency is installed automatically.
