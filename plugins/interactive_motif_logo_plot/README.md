# Interactive Motif Enrichment Logo

This plugin draws one colored DNA sequence-logo row per motif. `A`, `C`, `G`, and `T` are green, blue, orange, and red respectively. Letter height is the normalized probability multiplied by information content by default.

Accepted input layouts:

- Long: `motif,position,A,C,G,T`, with aliases `motif_name`, `motif_id`, `name`, `pos`, and `index`. Column names can be overridden with `motif_column`, `position_column`, and `base_columns`.
- Wide grouped: one motif column and repeated columns such as `A1,C1,G1,T1,A2,C2,G2,T2` or `A_1,C_1,G_1,T_1`. `input_mode: auto` detects either layout.

The default `input_scale` is `weight`, `normalize` is `probability`, `information_content` is true, background frequencies are 0.25, and interactive Plotly HTML is enabled. The CLI is:

```bash
Rscript plugins/interactive_motif_logo_plot/plot.R --input input.csv --params params.json --output output_dir
```

It always writes `result.svg`, `result.pdf`, `result.png`, `result.html`, `figure.json`, `run.log`, `motif_data_used.csv`, and `selected_rows.csv`; failures write `error.json`. `figure.json` and the used-data CSV contain the computed probability, information, height, and stack intervals.

Examples use the shared `example_input.csv` and can be rendered with:

```bash
bash plugins/interactive_motif_logo_plot/run_all_examples.sh /Users/qzhang10/Documents/OmicsCanvas
```
