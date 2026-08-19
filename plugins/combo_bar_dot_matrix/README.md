# Combo Bar + Dot Matrix

Two-panel figure with a **shared x-axis**:

1. **Top — bars**  
   Metric ± error, group colors, optional pairwise **p-value brackets**,  
   and highly customizable **horizontal reference line(s)** (position, text, color, size, linetype, arrow).

2. **Bottom — dot matrix**  
   Binary (filled/empty) or continuous (heatmap-colored) dots for feature  
   presence / strength under each bar category (DNase, ATAC, Hi-C, …).

Matches method-benchmark panels (e.g. AUPRC bars + feature encoding matrix).

## Inputs

| File | Role |
|------|------|
| `--input` | Bars: `model, auprc, se, group` |
| `--matrix` | Dots: wide `feature × x` or long `feature,x,value` |
| `--comparisons` | Optional brackets: `x1,x2,pvalue[,label]` |

Annotation text may also come from an **`annotation` column** on the bar table.

## Horizontal reference lines

Single convenience fields:

```json
"hline_y": 0.42,
"hline_label": "Distance to TSS",
"hline_color": "#666666",
"hline_linewidth": 0.55,
"hline_linetype": "solid",
"hline_label_x": 9.6,
"hline_label_y": 0.55,
"hline_label_size": 3.3,
"hline_label_color": "#444444",
"hline_show_arrow": true
```

Or multiple fully specified lines:

```json
"hlines": [
  {
    "y": 0.42,
    "label": "Distance to TSS",
    "color": "#666666",
    "linewidth": 0.55,
    "linetype": "solid",
    "label_x": 9.6,
    "label_y": 0.55,
    "label_size": 3.3,
    "label_color": "#444444",
    "label_face": "plain",
    "label_angle": 0,
    "show_arrow": true,
    "arrow_x": 9.15
  }
]
```

## Dot matrix modes

- `matrix_value_mode: "binary"` — filled vs hollow (default)  
- `matrix_value_mode: "continuous"` — color scale by value  

## Run

```bash
Rscript plugins/combo_bar_dot_matrix/plot.R \
  --input plugins/combo_bar_dot_matrix/example_input.csv \
  --params plugins/combo_bar_dot_matrix/example_basic_params.json \
  --output /tmp/combo_bar_dot_out \
  --matrix plugins/combo_bar_dot_matrix/example_matrix.csv \
  --comparisons plugins/combo_bar_dot_matrix/example_comparisons.csv
```

## Editor

`http://127.0.0.1:8000/static/editor.html?plugin=combo_bar_dot_matrix`
