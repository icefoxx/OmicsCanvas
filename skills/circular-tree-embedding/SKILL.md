---
name: circular-tree-embedding
description: Draw a radial cell-type hierarchy around supplied UMAP or t-SNE coordinates in OmicsCanvas, with matched class/subclass/subtype colors or clustering of subtype feature means.
metadata:
  role: plot_workflow
---

# Circular tree + embedding

Use the engine in `plugins/circular_tree_embedding/plot.R` for a combined circular
dendrogram and central embedding. Read its `params_schema.json` for current controls
and `README.md` for input and output details.

Map numeric embedding X/Y, a leaf subtype, ordered broad-to-fine hierarchy columns,
and one of those annotations for center colors. Each child label must identify a
unique parent path; resolve ambiguous labels before plotting. The plugin consumes
existing coordinates; it does not compute UMAP or t-SNE.

Choose `tree_mode: annotation` for supplied taxonomy. Branch lengths then show depth,
not distance. Choose `similarity` only when measured numeric `feature_columns` are
available: it clusters per-leaf feature means, optionally standardized, using
Euclidean distance and the selected linkage. Never infer biological relationships
from embedding distances or silently use embedding axes as feature columns.

Use `group_column` to switch class/subclass/subtype colors. Override colors using
`column:value` keys in `group_colors` so ring and center colors agree. In similarity
order, disjoint annotation arcs remain separate. Uniform angular slots do not encode
cell counts. Convex hulls are descriptive envelopes, not uncertainty estimates.

Start with `basic`, `similarity` or `CAB_demo` in the engine's `examples/` directory.
These are synthetic demonstration cells. The verified reference is Lee et al., Nature 657, 988–1002 (2026), Figure 2a,
DOI: 10.1038/s41586-025-09573-z. Link the original figure through the Guide;
do not claim a paper-data reproduction. The English Plot Guide source is
`plot_web/registry/guides/circular_tree_embedding.yaml`.
