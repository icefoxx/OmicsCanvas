# Raincloud Plot

Half-violin, box, and jittered points for group distributions of a numeric value.

## Input

One table (CSV/TSV/TXT). Map columns with `value_column` and `group_column`;
unmapped columns fall back to `value` and `group`. Non-numeric value rows are dropped and logged.

## Main parameters

| Group | Parameters |
|---|---|
| Data | `value_column`, `group_column`, `groups_include`, `groups_exclude`, `group_order` |
| Marks | `orientation`, `violin_show`, `box_show`, `point_show`, `violin_width`, `box_width`, `point_size` |
| Colours | `palette`, `group_colors` |
| Labels / legend | `title`, `subtitle`, `xlab`, `ylab`, `legend_*` |
| Export | `width`, `height` (inches), `dpi` |

Full list with defaults: `params_schema.json`.

## Run

```bash
Rscript plugins/raincloud_plot/plot.R \
  --input plugins/raincloud_plot/examples/basic/input/example_input.csv \
  --params plugins/raincloud_plot/examples/basic/params.json \
  --output /tmp/raincloud_plot_out
```

Outputs: `result.svg`, `result.pdf`, `result.png`, `figure.json`, `run.log`, `data_used.csv`;
`error.json` on failure.
