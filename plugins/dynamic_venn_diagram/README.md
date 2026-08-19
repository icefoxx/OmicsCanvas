# Dynamic Venn Diagram

This plugin draws highly customizable Venn diagrams from either element-list files or abundance matrices.

For 1-5 selected groups, it uses a standard Venn layout. For 6 or more groups, `plot_mode: "auto"` switches to a flower Venn layout.

## Run

Element-list input:

```bash
Rscript plugins/dynamic_venn_diagram/plot.R \
  --input plugins/dynamic_venn_diagram/example_element_input.csv \
  --params plugins/dynamic_venn_diagram/example_params.json \
  --output /tmp/dynamic_venn_element_out
```

Abundance-matrix input:

```bash
Rscript plugins/dynamic_venn_diagram/plot.R \
  --input plugins/dynamic_venn_diagram/example_abundance_input.csv \
  --params plugins/dynamic_venn_diagram/example_abundance_params.json \
  --output /tmp/dynamic_venn_flower_out
```

## Input Modes

Element-list file:

- Each selected column is one group.
- Each non-empty cell is one element.
- Group columns can have different numbers of elements.

Abundance-matrix file:

- The first column, or `element_id_column`, contains element IDs.
- Selected numeric columns are groups or samples.
- Elements enter a group when the value passes `abundance_operator` and `abundance_threshold`.
- Per-group thresholds can be set with `group_thresholds`.
- Flower petals use radial geometry. Use `flower_inner_gap`, `petal_length`, and `petal_width` to tune whether petals touch, slightly overlap, or leave space around the center.

## Main Params

```json
{
  "input_type": "auto",
  "groups_include": ["YF", "YC", "ZF"],
  "groups_exclude": [],
  "group_order": ["YF", "YC", "ZF"],
  "plot_mode": "auto",
  "title": "Dynamic Venn diagram",
  "palette_scheme": "bold",
  "set_colors": {
    "YF": "#69A4F9",
    "YC": "#BFE046",
    "ZF": "#EDAC2E"
  },
  "fill_alpha": 0.7,
  "border_color": "#FFFFFF",
  "border_width": 2.5,
  "border_lty": "solid",
  "show_counts": true,
  "show_percent": true,
  "show_group_names": true,
  "show_bar_chart": true,
  "flower_inner_gap": -0.04,
  "petal_length": 0.94,
  "petal_width": 0.38
}
```

## Abundance Filtering

```json
{
  "input_type": "abundance",
  "element_id_column": "OTU",
  "abundance_operator": ">",
  "abundance_threshold": 0,
  "group_thresholds": {
    "YF": 5,
    "YC": 10
  },
  "group_operators": {
    "YF": ">",
    "YC": ">="
  }
}
```

## Outputs

Successful runs write:

- `result.svg`
- `result.pdf`
- `result.png`
- `figure.json`
- `subsets.csv`
- `subset_elements_long.csv`
- `set_sizes.csv`
- `run.log`

`subsets.csv` is designed for interactive region details. A UI can map a clicked Venn region to `subset_id` and then display or download its elements from `subset_elements_long.csv`.
## Reproducible examples

Bundles are in `plugins/dynamic_venn_diagram/examples/<id>/`. Each contains `params.json`, copied command inputs under `input/`, and `expected/result.png`. `manifest.json` is the machine-readable entry point and records how to rerun the example.

