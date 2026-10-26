# Protein Variant Map

Place variant counts and annotated domains on a protein coordinate.

## Input

Protein residue position (1-based), supplied count, optional variant label/group. Optional domains CSV has start, end and domain.

## Main parameters

- `position_column`: Position column.
- `value_column`: Value column.
- `label_column`: Label column.
- `group_column`: Group column.
- `protein_length`: Protein length. 0 = automatic extent from variants and domain endpoints.
- `domain_show`: Domain show. Only when a domains table is supplied.
- `point_size`: Point size.
- `line_width`: Line width.
- `label_show`: Label show.
- `label_size`: Label size.
- `title`: Title.
- `subtitle`: Subtitle. Empty uses the automatic description.
- `caption`: Caption.
- `title_size`: Title size. Only when a nonempty title is supplied.
- `palette`: Palette.
- `group_colors`: Named colors. Named categorical colors override the palette.
- `legend_show`: Legend show.
- `legend_position`: Legend position.
- `legend_text_size`: Legend text size.
- `font_family`: Font family.
- `base_size`: Base size.
- `plot_background`: Plot background.
- `grid_show`: Grid show.
- `width`: Width. Inches.
- `height`: Height. Inches.
- `dpi`: Dpi.

## Interpretation

- Protein coordinates are 1-based residue coordinates, not genomic base-pair positions.
- The plugin does not annotate variants or infer pathogenicity. Domain positions and protein length are supplied.

## Run

```bash
Rscript plugins/protein_variant_plot/plot.R \
  --input plugins/protein_variant_plot/examples/basic/input/data.csv \
  --params plugins/protein_variant_plot/examples/basic/params.json \
  --output /tmp/protein_variant_plot_out
```

Optional uploads are listed in `config.yaml`; each uses its input ID as a CLI flag.
The example manifests include input mappings and parameters and input mappings.

Outputs: SVG/PDF/PNG, figure metadata, run log, data used and documented diagnostic
CSV tables. The 3D embedding engine additionally writes an interactive HTML scene.
Errors write `error.json` and remove partial figure files.

## Examples

- `basic`: Protein variants and domains.
- `variants_only`: Variant count profile.

All examples are independently generated synthetic data. Installed dependencies are
ggplot2, jsonlite, optparse, ragg and svglite; mode-specific rendering uses existing
survival, patchwork, ggrepel, plotly/htmlwidgets and png packages. No package is
installed automatically.
