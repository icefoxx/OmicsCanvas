# Lollipop Plot

Zero-centered lollipops for signed pathway or transcription-factor effects.
Version 1.2 adds a diverging reference style to this existing plugin.

## Input

One CSV/TSV table, with one row per item:

| category | effect | pvalue |
|---|---:|---:|
| ATF3(+) | 0.40 | 0.00001 |
| CTCF(+) | -0.40 | 0.0000000001 |

Map `category_column`, `value_column`, and `pvalue_column` in the editor. Optional
`group_column` supplies categorical colors; `size_column` supplies sizes in the
original identity mode. Input effect signs must already encode your comparison;
this plugin does not calculate differential expression or regulon enrichment.

The `CAB_demo` reference-style example contains **synthetic illustrative values**,
not measurements recovered from the publication in the supplied screenshot.
Replace the example data with your own effect and p-value table for scientific use.

## Main parameters

| Control | Parameters |
|---|---|
| Signed gradient on heads and stems | `color_mode: value`, `color_low`, `color_mid`, `color_high` |
| Significance-sized heads | `size_transform: neg_log10_pvalue`, `pvalue_column`, `size_switch` |
| Labels opposite the stems at zero | `category_label_position: zero_opposite`, `label_gap`, `label_size`, `label_color`, `label_face` |
| Direction arrows below the axis | `direction_labels_show`, `negative_label`, `positive_label` |
| Sorting and number of rows | `sort_by: value`, `sort: descending`, `top_n` |
| Legend placement | `legend_position`, including `inside` for the reference layout |
| Original grouped colors | `color_mode: group`, `group_colors` / legacy `type_colors` |
| Head size and shape | `point_size_min`, `point_size_max`, `point_shape`, `point_alpha`, `point_stroke`, `point_border_color` |
| Canvas and export | `width`, `height` in inches, `dpi`, `font_family`, `base_size` |

The gradient midpoint is zero. P-value sizing uses `-log10(p)` and requires finite
probabilities in [0,1]. Numerical zeros are floored to the smallest positive double
and logged. Raw and adjusted p-values should be identified explicitly in
`size_legend_title` (empty uses the mapped column name). `selected_rows.csv` records
the original probability and transformed size, and `figure.json` records mappings
and transforms. No statistical test or multiple-testing correction is performed.

Central labels and arrows apply to horizontal plots. Vertical orientation falls
back to category-axis labels and omits the arrows, with a run-log entry. Use enough
height for the number of category labels; the example uses 10.5 inches for 40 rows.
Inside legends suit the empty positive-effect region below the positive rows;
choose an outside legend for other data distributions. Keep `x_limits` spanning
zero when using central labels, and enough room for the names on both sides.

Mode-gated controls are described in schema help. Fixed radius `r` only applies
with size mapping off; `min_radius`/`max_radius` are superseded by explicit
`point_size_min`/`point_size_max`; dodge/padding need multiple groups; zero-line
colors need the zero line enabled; numeric-label offsets/repulsion need `label_show`;
grid color needs the grid enabled. Empty axis titles draw nothing even when enabled.
Explicit `x_limits` override legacy `x_min`/`x_max`. Input order can coincide with
value order for an already sorted table.

## Run

```bash
Rscript plugins/interactive_enrichment_lollipop/plot.R \
  --input plugins/interactive_enrichment_lollipop/examples/CAB_demo/input/example_input.csv \
  --params plugins/interactive_enrichment_lollipop/examples/CAB_demo/params.json \
  --output /tmp/lollipop_CAB_demo
```

In Studio: **Lollipop → Enrichment lollipop → Diverging TF Lollipop**, or select
**Diverging transcription factor lollipop** in the editor's Presets menu.

Open **Plot Guide → Examples** for the Grm1/Grm2 published use case and its
synthetic Try Example preset. **Literature** contains the citation and article
link: Hao et al., Molecular Cancer 25:24 (2026), Figure 6L,
DOI 10.1186/s12943-025-02548-8. The project skill is
[`diverging-tf-lollipop`](../../skills/diverging-tf-lollipop/SKILL.md); AI Studio
can match it to TF/regulon lollipop requests and map a supplied comparison table.

## Outputs

`result.svg`, `result.pdf`, `result.png`, `result.html`, `figure.json`, `run.log`,
`selected_rows.csv`. Optional Plotly HTML uses the same data and plotting layers.
If the installed Plotly converter cannot handle a layout, HTML contains a labelled,
self-contained static preview and the reason is logged; PNG/PDF/SVG are preserved.
`figure.json` records whether interactive conversion succeeded. PNG/PDF/SVG are
the reference exports for the printed layout.
