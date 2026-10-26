# Circular Tree + Embedding

A radial tree with concentric annotation rings surrounding a cell embedding.
New composite grammar: a shared leaf hierarchy and cell coordinates in one table.
The embedding is supplied by the user; this plugin does not compute UMAP or t-SNE.

## Input

CSV/TSV, one row per cell:

```csv
cell_id,UMAP_1,UMAP_2,class,subclass,subtype,Gene_A,Gene_B
c1,1.2,-0.4,Neuronal,Excitatory,L2 IT,2.1,0.3
c2,-0.6,1.1,Glial,Astroglia,Astro,0.1,3.2
```

Map `x_column`, `y_column`, `cluster_column` (leaf subtype), `hierarchy_columns`
(broad to fine, excluding or including the leaf) and `group_column` (center color).
The color annotation must be part of the hierarchy, making ring/color correspondence
explicit. Each leaf and child category must have one unique parent path. Rename
ambiguous child names. Missing coordinates or hierarchy values are dropped and logged.
Supports 2–150 leaf groups and up to five hierarchy levels, including the leaf.

## Main parameters

- `tree_mode = annotation`: supplied taxonomy, equal radial depth per level.
  Branch lengths are **not distances**, lineage or inferred relationships.
- `tree_mode = similarity`: Euclidean distance on per-leaf mean `feature_columns`;
  optionally z-score across leaves, then hierarchical clustering with
  `cluster_method` (average, complete, single, ward.D2). Features must be finite.
  Constant features contribute zero. Embedding axes cannot be similarity features.
  Similarity ordering may split annotation rings into multiple runs; these are kept
  separate, never silently joined. No phylogenetic interpretation is implied.
- `group_column`: change center colors/labels between class, subclass and subtype.
- `group_colors`: named colors by `column:value`, or category name. Broad class hues
  are inherited with lighter child shades; explicit overrides apply to matching
  annotations in both embedding and rings.
- `embedding_radius`, `ring_width`, `gap_angle`, `rotation`: composite geometry.
- `point_size`, `point_alpha`, `hull_show`, `hull_alpha`: central appearance.
  Convex hulls are descriptive envelopes, not density contours or uncertainty.
- `label_show`, `leaf_label_show`, `ring_label_show` and respective sizes.
  Long/dense outer labels auto-fit; narrow ring labels are omitted. Center labels
  repel within the embedding bounds; extremely dense labels may be omitted.
- `width`, `height` in inches, `dpi`; font, background and title/subtitle/caption.

The embedding is centered and scaled isotropically to fit inside the tree: the
relative coordinate aspect ratio is preserved. Circular slots are uniform per leaf,
not proportional to cell counts. Labels and colors provide the correspondence;
angular position is not projected from UMAP coordinates.

## Run

```bash
Rscript plugins/circular_tree_embedding/plot.R \
  --input plugins/circular_tree_embedding/examples/basic/input/cells.csv \
  --params plugins/circular_tree_embedding/examples/basic/params.json \
  --output /tmp/circular_tree_embedding_out
```

Outputs: SVG/PDF/PNG, `figure.json`, `run.log`, `data_used.csv` (drawn coordinates
and colors), `annotation_used.csv` (leaf order/angles), `tree_edges_used.csv`
(topology/radii), and `profiles_used.csv` in similarity mode. Errors produce
`error.json` and no partial image files. Installed dependencies: ggplot2, ggrepel,
jsonlite, optparse, ragg and svglite; no new packages required.

## Examples

`basic`: subclass coloring with annotation tree. `similarity`: feature means with
subtype colors and no hulls. `CAB_demo`: reference-inspired atlas arrangement with
broad class colors. All three contain independently generated synthetic cells;
none use the original reference image or paper data.
