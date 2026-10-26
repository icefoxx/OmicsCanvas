# Annotated Tree

Draw a supplied weighted tree with leaf metadata or a linked feature heatmap.

## Input

Connected acyclic rooted edge table with parent, child and nonnegative length. Optional size/group fields and a node-keyed annotation table of numeric feature columns.

## Main parameters

- `parent_column`: Parent column.
- `child_column`: Child column.
- `length_column`: Length column.
- `group_column`: Group column.
- `size_column`: Size column.
- `feature_columns`: Feature columns. Numeric annotation features for the rectangular heatmap; empty = every non-node annotation column.
- `layout`: Layout.
- `gap_angle`: Gap angle. Circular layout only.
- `heatmap_show`: Heatmap show. Rectangular layout with an annotation table only.
- `label_show`: Label show.
- `label_size`: Label size.
- `title`: Title.
- `subtitle`: Subtitle. Empty uses the automatic description.
- `caption`: Caption.
- `title_size`: Title size. Only when a nonempty title is supplied.
- `tree_color`: Tree color.
- `palette`: Palette.
- `group_colors`: Named colors. Named categorical colors override the palette.
- `point_size`: Point size.
- `line_width`: Line width.
- `legend_show`: Legend show.
- `legend_position`: Legend position.
- `legend_text_size`: Legend text size.
- `font_family`: Font family.
- `base_size`: Base size.
- `plot_background`: Plot background.
- `width`: Width. Inches.
- `height`: Height. Inches.
- `dpi`: Dpi.

## Interpretation

- The tree and branch lengths are supplied. No phylogenetic reconstruction or cluster similarity is inferred.
- Heatmap rows must match terminal leaves. A circular layout does not imply circular evolutionary distances.

## Run

```bash
Rscript plugins/annotated_tree_plot/plot.R \
  --input plugins/annotated_tree_plot/examples/basic/input/data.csv \
  --params plugins/annotated_tree_plot/examples/basic/params.json \
  --output /tmp/annotated_tree_plot_out
```

Optional uploads are listed in `config.yaml`; each uses its input ID as a CLI flag.
The example manifests include input mappings and parameters and input mappings.

Outputs: SVG/PDF/PNG, figure metadata, run log, data used and documented diagnostic
CSV tables. The 3D embedding engine additionally writes an interactive HTML scene.
Errors write `error.json` and remove partial figure files.

## Examples

- `basic`: Supplied tree and feature heatmap.
- `circular`: Circular tree with weighted nodes.

All examples are independently generated synthetic data. Installed dependencies are
ggplot2, jsonlite, optparse, ragg and svglite; mode-specific rendering uses existing
survival, patchwork, ggrepel, plotly/htmlwidgets and png packages. No package is
installed automatically.
