# Motif Logo Plugin Skill

Use `plot.R` with `--input`, `--params`, and `--output`. The input must be a long motif matrix (`motif`, `position`, `A`, `C`, `G`, `T`) or a wide matrix with repeated suffixed base columns (`A1` or `A_1`).

Defaults are `input_mode: auto`, `input_scale: weight`, `normalize: probability`, `information_content: true`, uniform background frequencies, title `Motif enrichment`, static dimensions derived from `width_per_position: 0.55` and `height_per_motif: 1.05`, 300 dpi, and `interactive: true`. Use `motifs_include`, `motifs_exclude`, or `motif_order` for deterministic selection and ordering. `reverse_positions` reverses the displayed columns.

Output includes all static formats, Plotly HTML, `figure.json`, `motif_data_used.csv`, `selected_rows.csv`, and `run.log`. Plotly and htmlwidgets are required only when `interactive` is true.
