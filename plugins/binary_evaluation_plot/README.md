# Binary Model Evaluation

ROC, precision–recall, calibration and decision curves from supplied predictions.

## Input

Predictions mode: binary outcome, numeric score and optional model/group. Calibration and decision curves require probabilities in [0,1]. Curve mode: supplied numeric x/y and optional group.

## Main parameters

- `outcome_column`: Outcome column.
- `score_column`: Score column.
- `group_column`: Group column.
- `x_column`: X column. X/Y are used only for input_mode = curve.
- `y_column`: Y column. X/Y are used only for input_mode = curve.
- `input_mode`: Input mode. Supplied curve coordinates support upstream time-dependent analyses without fitting censoring models here.
- `plot_type`: Plot type.
- `positive_class`: Positive class. Empty uses the observed label 1; otherwise enter the positive outcome label. Predictions mode only.
- `calibration_bins`: Calibration bins. Equal-width probability bins; calibration predictions mode only.
- `threshold_min`: Threshold min. Decision-curve predictions mode only; min must remain below max.
- `threshold_max`: Threshold max. Decision-curve predictions mode only; min must remain below max.
- `point_size`: Point size. Only for calibration plots.
- `line_width`: Line width.
- `palette`: Palette.
- `group_colors`: Named colors. Named categorical colors override the palette.
- `title`: Title.
- `subtitle`: Subtitle. Empty uses the automatic description.
- `caption`: Caption.
- `title_size`: Title size. Only when a nonempty title is supplied.
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

- No model training, optimism correction or clinical threshold selection is performed. Evaluate held-out predictions where appropriate.
- Ordinary binary evaluation does not handle censored outcomes. Upload externally computed curves for time-dependent ROC.

## Run

```bash
Rscript plugins/binary_evaluation_plot/plot.R \
  --input plugins/binary_evaluation_plot/examples/basic/input/data.csv \
  --params plugins/binary_evaluation_plot/examples/basic/params.json \
  --output /tmp/binary_evaluation_plot_out
```

Optional uploads are listed in `config.yaml`; each uses its input ID as a CLI flag.
The example manifests include input mappings and parameters and input mappings.

Outputs: SVG/PDF/PNG, figure metadata, run log, data used and documented diagnostic
CSV tables. The 3D embedding engine additionally writes an interactive HTML scene.
Errors write `error.json` and remove partial figure files.

## Examples

- `basic`: Receiver operating characteristic.
- `precision_recall`: Precision and recall.
- `calibration`: Probability calibration.
- `decision_curve`: Net benefit by threshold.
- `supplied_curve`: Supplied evaluation curves.

All examples are independently generated synthetic data. Installed dependencies are
ggplot2, jsonlite, optparse, ragg and svglite; mode-specific rendering uses existing
survival, patchwork, ggrepel, plotly/htmlwidgets and png packages. No package is
installed automatically.
