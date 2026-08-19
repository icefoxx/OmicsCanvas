# Highlight Effect Plot

Nature-style **focus + other-cloud** strip plot:

| Layer | Treatment |
|-------|-----------|
| **Highlighted terms** | Own y-row, large colored point, horizontal error bar (mean ± CI), optional `***` stars |
| **Non-highlighted terms** | Collapsed into **one** lane (`Other biosamples`) as a **jittered gray point cloud** — each term stays as an individual point, not summarized |

This is the key design of the reference figure: background biosamples remain visible as scatter, without competing for y-axis rows.

## Inputs

### Points mode (default)
```
category,value,sample_id,pvalue
Normoblasts,13.5,NB1,0.0002
B cells,5.2,O1,0.4
...
```

### Summary mode
```
category,mean,ci_low,ci_high,pvalue,highlight
Normoblasts,13.45,12.1,14.9,0.0002,TRUE
```

## Key parameters

- `highlight_terms` — which categories get the large CI points  
- `collapse_others: true` — pack the rest into one Other lane (default)  
- `other_label`, `other_color`, `jitter_width/height`  
- `highlight_colors` — per-term colors  
- `stars_show`, `star_thresholds`, `stars_map`  
- Full axis / canvas / CI controls  

## Run

```bash
Rscript plugins/highlight_effect_plot/plot.R \
  --input plugins/highlight_effect_plot/example_input.csv \
  --params plugins/highlight_effect_plot/example_basic_params.json \
  --output /tmp/highlight_effect_out
```

## Editor

`http://127.0.0.1:8000/static/editor.html?plugin=highlight_effect_plot`
