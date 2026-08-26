# Advanced Feature Plot — all_p8_p7 test data

## Source

Original file (RDS saved with `.tsv` extension):
`plotdata.prep.seu_all_p8_p7_Neurod1_Atoh1_Alpl_Runx2_orig.ident.tsv`

Converted table: `all_p8_p7_advfea_input.csv` (34,033 cells)

Columns: `cell`, `dim1`/`dim2` (from x/y), `orig.ident`, features `Neurod1`, `Atoh1`, `Alpl`, `Runx2`, plus joined `cluster`/`mito`.

Reference PDF: `/Users/qzhang10/Documents/advFeaPlot.pdf`

## PDF-matched outputs (`pdf_repro/`)

| Card | PDF scenario |
|------|----------------|
| Basic · Atoh1 + Neurod1 | Basic two-feature maps |
| Multi · 4 genes scaled | Neurod1/Atoh1/Alpl/Runx2 + quantile/bg cutoff |
| Split by sample | Atoh1 faceted by orig.ident |
| Composite multiply | feature_comp + multiply |
| Highlight cells | first 500 cells |
| Split · shared coords | global_split + themeBlank |
| Hexbin features | hex bins = 60 |

## Re-run

```bash
INPUT=plugins/advanced_feature_plot/testdata/all_p8_p7_advfea_input.csv
for p in plugins/advanced_feature_plot/testdata/pdf_repro/params/*.json; do
  n=$(basename "$p" .json)
  Rscript plugins/advanced_feature_plot/plot.R --input "$INPUT" --params "$p" \
    --output "plugins/advanced_feature_plot/testdata/pdf_repro/$n"
done
```
