# __PLUGIN_NAME__

__DESCRIPTION__

## Input

One table (CSV/TSV/TXT). Map columns with `x_column`, `y_column` and `group_column`;
unmapped columns fall back to `x`, `y`, `group`. Non-numeric x/y rows are dropped and logged.

## Main parameters

| Group | Parameters |
|---|---|
| Data | `x_column`, `y_column`, `group_column`, `groups_include`, `groups_exclude`, `group_order` |
| Marks | `point_size`, `point_alpha`, `trend_show` |
| Colours | `palette`, `group_colors` |
| Labels / legend | `title`, `subtitle`, `xlab`, `ylab`, `legend_*` |
| Export | `width`, `height` (inches), `dpi` |

Full list with defaults: `params_schema.json`.

## Run

```bash
Rscript plugins/__PLUGIN_ID__/plot.R \
  --input plugins/__PLUGIN_ID__/examples/basic/input/example_input.csv \
  --params plugins/__PLUGIN_ID__/examples/basic/params.json \
  --output /tmp/__PLUGIN_ID___out
```

Outputs: `result.svg`, `result.pdf`, `result.png`, `figure.json`, `run.log`, `data_used.csv`;
`error.json` on failure.
