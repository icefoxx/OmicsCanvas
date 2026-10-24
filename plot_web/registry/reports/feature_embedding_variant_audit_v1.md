# Feature Embedding variant audit (v1.0)

Inspected `plugins/advanced_feature_plot` params, `plot.R`, and
`reference_sca_helpers/advFeaPlot.R` before registry changes.

| legacy ID | card title | backend | transform | features | layout | split | highlight | aggregation | quantity encoded | canonical | class | reason | mapping |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| pdf_repro_basic_two_features | Basic · Atoh1 + Neurod1 | advFeaPlot | none | 2 | side by side | no | no | none | cell-level feature color per panel | feature_expression | KEEP/demo | gene names are demo data | layout=side_by_side |
| pdf_repro_multi_feature_scaled | Multi · 4 genes scaled | advFeaPlot | scale.by=feature, quantile 0–0.95 | 4 | 2-col grid | no | no | none | per-feature scaled expression | feature_expression | MERGE/demo | count + scaling, not a new view | layout=grid, scale_by=feature |
| single_feature | single_feature | advFeaPlot | keep.0=false | 1 | single | no | no | none | one feature map | feature_expression | LEGACY_ALIAS | single is a mode | layout=single |
| multi_feature | multi_feature | advFeaPlot | scale.by=feature | 4 | grid | no | no | none | separate feature maps | feature_expression | LEGACY_ALIAS | multi is a mode | layout=grid |
| pdf_repro_highlight_cells | Highlight cells | advFeaPlot | highlight_rows | 2 | grid | no | subset | none | same maps + subset emphasis | feature_expression | MERGE | highlight capability | highlight_enabled |
| highlight_blank | highlight_blank | advFeaPlot | themeBlank + highlight_levels | 1 | single | no | cluster subset | none | feature map + highlight, blank theme | feature_expression | PRESET/PARAMETER | not a new encoding; closest is highlight + blank theme | preset=blank |
| pdf_repro_split_by_sample | Split by sample | advFeaPlot | global.split=true | 1 | split | orig.ident | no | none | feature across groups | split_feature_expression | KEEP/demo | split view | global_split=true |
| pdf_repro_split_global_blank | Split · shared coords | advFeaPlot | global.split + themeBlank | 1 | split | orig.ident | no | none | same split, shared axes, blank | split_feature_expression | PRESET | coordinate/theme only | preset=blank, global_split=true |
| split_feature | split_feature | advFeaPlot | global.split | 2 | split | sample | no | none | split feature maps | split_feature_expression | LEGACY_ALIAS | generic split | global_split=true |
| pdf_repro_feature_comp_multiply | Composite multiply | advFeaPlot feature.comp | color.mix.mode=multiply | 2 | one panel | no | no | none | **color mix**, not Atoh1×Neurod1 product | feature_coexpression | KEEP as coexpression | multiply is a blend mode of mixed colors | feature_comp + multiply |
| feature_comp | feature_comp | advFeaPlot feature.comp | color.mix.mode=blend | 3 | one panel | no | no | none | blended per-cell colors from 3 features | feature_coexpression | KEEP/REVIEW→KEEP | joint color encoding, not separate panels | feature_comp + blend |
| pdf_repro_hexbin | Hexbin features | stat_summary_hex | default mean(z) | 2 | 2 panels | no | no | hex mean | **mean feature per hex bin** | aggregated_feature_expression | KEEP | spatial aggregation of feature | aggregation_style=hexbin |
| density_hex | density_hex | hex + add.density | mean feature + KDE contours | 1 | single | no | no | hex + density overlay | mean feature in bins + cell-density contours | aggregated_feature_expression | MERGE | Outcome A: hex aggregation + density layer | hexbin + show_density |

## REVIEW outcomes

### Composite multiply / feature_comp

`feature.comp=TRUE` rescales each feature, maps each to a color, then
`blendcolors(..., mode=color.mix.mode)` with
`blend | average | screen | multiply`. Displayed quantity is mixed
**color**, plus layering by summed normalized signal. It does **not**
compute a numeric product of expression. Therefore it is **Feature
Coexpression**, not a separate “Feature Combination / product” variant.
Mix method stays a parameter. Separate multi-panel maps stay Feature
Expression.

### Hexbin features

`stat_summary_hex(z=value)` with ggplot2 default `mean`. Color is mean
feature per hexagonal bin. Scientifically distinct from cell-level
points → **Aggregated Feature Expression**.

### density_hex

Same hex mean of a feature **plus** `add.density` contours of cell
positions. Contours are a layer, not a different statistic. Merge into
Aggregated Feature Expression with `show_density=true`.

## Scaling actually implemented

`scale.by` accepts only `feature` (per feature) and `all` (shared).
No raw/z-score transform is exposed; those were not added.
