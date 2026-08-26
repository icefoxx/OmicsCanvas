# Advanced Dimension Plot — all_p8_p7 test data

## Source

- `all_p8_p7.meta.data.tsv` — copied from  
  `/Users/qzhang10/workstation/development/SCA/all_p8_p7.meta.data.tsv`  
  (includes `cell.barcodes.selected`, **`x`**, **`y`**, clusters, samples, mito, …)
- Built plot table: `all_p8_p7_advdim_input.csv` (**34,033 cells**)  
  - `dim1`/`dim2` ← `x`/`y`  
  - `cluster` ← `HarmonyUMAP2D_SNN_res.0.3`  
  - `cell`, `orig.ident`, `mito`, …

Also mirrored under repo `testdata/`.

Reference PDF: `/Users/qzhang10/Documents/advDimPlot.pdf`

## PDF-matched outputs (`pdf_repro/`)

| Output | PDF panel |
|--------|-----------|
| `01_basic_umap` | Basic UMAP by cluster |
| `02_ellipse_mark` | Cluster ellipses |
| `03_split_samples` | Facet by sample (`orig.ident`) |
| `04_composition_ring` | Embedded sample-composition pies |
| `05_highlight_cells` | First 1000 cells highlighted |
| `06_bg_cutoff_mito` | Background by mito &gt; 5% |
| `07_bg_condition_samples` | Background: `p8` + `3238527_NSP53null_MycAID_OSTIR1` |

Each panel has `params/*.json`, `result.png/svg/pdf`, and a top-level `NN_*.png` copy.

## Re-run

```bash
cd /Users/qzhang10/Documents/OmicsCanvas
INPUT=plugins/advanced_dim_plot/testdata/all_p8_p7_advdim_input.csv
for p in plugins/advanced_dim_plot/testdata/pdf_repro/params/*.json; do
  n=$(basename "$p" .json)
  Rscript plugins/advanced_dim_plot/plot.R \
    --input "$INPUT" --params "$p" \
    --output "plugins/advanced_dim_plot/testdata/pdf_repro/$n"
done
```
