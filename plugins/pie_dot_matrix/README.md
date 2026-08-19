# Pie Dot Matrix

Matrix of **pie-filled circles** (比例圆点矩阵):

- **Filled portion** of each circle = continuous value in that cell  
  (gene ratio, correlation |r|, prevalence, score, …)
- **Color** = row category (habitat / class / group)
- **Hollow circle** when value is 0 / missing
- **Center mark** optional: star ★, plus, cross, diamond, or custom text
- **Column band** annotation on top; **row stripe** tinting

## Inputs

| Mode | Format |
|------|--------|
| **wide** | `category, K001, K002, …` numeric values 0–1 (or any scale with `value_mode`) |
| **long** | `row, column, value [, mark]` |

Optional:

- `--col_annot` : `column, group, color` for top bands  
- `--marks` : `category, column, mark` for center signs  

## Value modes (`value_mode`)

| Mode | Mapping |
|------|---------|
| `fraction` | clamp value to [0,1] as pie fill |
| `binary` | value > 0 → full circle |
| `abs_correlation` | \|value\| clamped to [0,1] |
| `rescale` | min–max normalize |
| `percent` | value / 100 |

## Run

```bash
Rscript plugins/pie_dot_matrix/plot.R \
  --input plugins/pie_dot_matrix/example_input.csv \
  --params plugins/pie_dot_matrix/example_basic_params.json \
  --output /tmp/pie_dot_out \
  --col_annot plugins/pie_dot_matrix/example_col_annot.csv \
  --marks plugins/pie_dot_matrix/example_marks.csv
```

## Editor

`http://127.0.0.1:8000/static/editor.html?plugin=pie_dot_matrix`
