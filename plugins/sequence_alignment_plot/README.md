# Sequence Alignment

Display aligned DNA or protein sequences with consensus conservation.

## Input

Unique sequence IDs and equal-length pre-aligned DNA/protein strings, including dash gaps. Alignment is not computed.

## Main parameters

- `id_column`: Id column.
- `sequence_column`: Sequence column.
- `alphabet`: Alphabet.
- `residue_show`: Residue show. Characters automatically omitted above 80 aligned positions.
- `conservation_show`: Conservation show.
- `conservation_color`: Conservation color. Only when conservation_show is enabled.
- `palette`: Palette.
- `group_colors`: Named colors. Named categorical colors override the palette.
- `label_size`: Label size.
- `title`: Title.
- `subtitle`: Subtitle. Empty uses the automatic description.
- `caption`: Caption.
- `title_size`: Title size. Only when a nonempty title is supplied.
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

- The plugin displays an existing alignment and does not choose an alignment algorithm.
- Consensus is the most frequent nongap residue count divided by sequence count, not entropy or a phylogenetic test.

## Run

```bash
Rscript plugins/sequence_alignment_plot/plot.R \
  --input plugins/sequence_alignment_plot/examples/basic/input/data.csv \
  --params plugins/sequence_alignment_plot/examples/basic/params.json \
  --output /tmp/sequence_alignment_plot_out
```

Optional uploads are listed in `config.yaml`; each uses its input ID as a CLI flag.
The example manifests include input mappings and parameters and input mappings.

Outputs: SVG/PDF/PNG, figure metadata, run log, data used and documented diagnostic
CSV tables. The 3D embedding engine additionally writes an interactive HTML scene.
Errors write `error.json` and remove partial figure files.

## Examples

- `basic`: Aligned nucleotide sequences.
- `protein`: Aligned protein sequences.

All examples are independently generated synthetic data. Installed dependencies are
ggplot2, jsonlite, optparse, ragg and svglite; mode-specific rendering uses existing
survival, patchwork, ggrepel, plotly/htmlwidgets and png packages. No package is
installed automatically.
