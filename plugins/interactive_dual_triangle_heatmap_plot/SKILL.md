# Interactive Dual-Triangle Heatmap

Use this plugin when two independent square matrices must occupy one matrix
layout. The upper triangle always comes from `upper.csv` and the lower triangle
always comes from `lower.csv`; their limits, palettes, legends, metrics, and
hover metadata remain independent. Never average or merge the input matrices.

Inputs have an ID column followed by square numeric columns. IDs must match all
row and column labels. Set `allow_reorder` to true when matching labels are in
different orders. Annotation files have an ID column followed by categorical
dataset/group columns.
