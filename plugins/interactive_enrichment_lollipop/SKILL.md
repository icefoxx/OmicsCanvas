# Interactive Enrichment Lollipop Skill

Use `interactive_enrichment_lollipop` for publication-style signed pathway or category enrichment plots. It produces a horizontal, zero-centered lollipop/Cleveland plot with pathway terms on the Y axis, signed effect or NES values on the X axis, stems to zero, point-size mapping, and categorical significance colors.

## Diverging TF / regulon comparisons

For two-state transcription-factor comparisons, use variant `diverging_tf` and
the `CAB_demo` style preset. Follow the project-discoverable skill at
[diverging-tf-lollipop](../../skills/diverging-tf-lollipop/SKILL.md) for column
mapping, sign conventions, probability transforms and provenance.

The Plot Guide's Examples and Literature tabs link Hao et al., Molecular Cancer
25:24 (2026), Figure 6L, DOI 10.1186/s12943-025-02548-8. This compares TF signatures
of Grm1/Grm2 gut-resident gamma-delta T-cell states. The bundled demo is synthetic,
not the publication's measured data. Its continuous green-to-pink effects and
probability-sized heads are a separate mode from the categorical OCT4 example.

## OCT4 Enrichment Pattern

Use the `oct4_enrichment` example as the visual standard for this plot style:

- `category`: pathway label, including the enriched count and universe count when available
- `effect`: signed normalized enrichment score (NES)
- `group`: significance class such as `FDR<0.05`, `FDR<0.25`, or `P.VAL<0.05`
- `size`: GeneRatio as a numeric proportion
- Keep the input order when reproducing a supplied figure
- Reverse the horizontal category axis so the first input term is displayed at the top
- Use a gray stem and zero line, colored outlined circles, and separate Group and GeneRatio legends

## Parameters

Prefer explicit column mappings when input names are ambiguous:

```json
{
  "category_column": "category",
  "value_column": "effect",
  "group_column": "group",
  "size_column": "size"
}
```

Use `type_colors` or `group_colors` for significance colors. Use `size_legend_title` and `size_legend_breaks` to label and control the GeneRatio legend. Keep all visual settings in `params.json`; do not hard-code dataset-specific values in the renderer.

## Runtime And Outputs

Run from the repository root:

```bash
Rscript plugins/interactive_enrichment_lollipop/plot.R \
  --input plugins/interactive_enrichment_lollipop/examples/oct4_enrichment/input/example_input.csv \
  --params plugins/interactive_enrichment_lollipop/examples/oct4_enrichment/params.json \
  --output /tmp/oct4_enrichment
```

Successful runs emit `result.svg`, `result.pdf`, `result.png`, `result.html`, `figure.json`, `run.log`, and `selected_rows.csv`. The complete plotted table is preserved in `selected_rows.csv`. Optional HTML can fall back to a labelled static preview when conversion is unsupported; check `figure.json.interactive_html` before claiming interactivity.
