# Plot Guide coverage, published figures and examples

Generated from registry entries, curated Guide YAML, verified references and local example bundles.

- Visible plots: **66**; Guides available: **66**.
- All registry entries: **80**; Guide source files: **80**; missing Guides: **0**.
- Entries with at least two independent local demos: **71**; fewer than two: **9**.
- Local demo bundles linked: **203**.
- Curated references: **40**; unique verified figure records: **77**.
- Visible plots with a verified figure association: **44/66**; with at least one same-grammar match: **36/66**.
- Visible plots with figure examples from at least two distinct references: **28/66**.
- Local reference-validation errors: **0**.

**Scope:** visible Guides are available in the editor. Hidden legacy entries have documentation source files only; this work does not enable their old entry points.

**Published figures:** every listed example has a checked figure/panel label, source link, short description and adaptation note. Same plot grammar does not mean an exact reproduction. Related layouts are explicitly labelled and are not counted as direct matches. Preprints are identified. A figure range such as 4A–D is one figure record, not four independent papers.

**Links and images:** links open the publisher figure page where verified and available, otherwise the captioned article or PDF. Locate the named panel in that source. Original publication images are not copied or presented as local demos.

**Local examples:** demos use existing independent bundles; they are not the original data of cited papers. Loading an existing preview does not prove that the R engine can regenerate it in the current environment.

Runtime and interface results are recorded in the [validation notes](plot_guide_validation_2026-10-25.md). Existing full-image regression failures remain separate from Guide coverage.

## Overview

| Plot / ID | Editor status | Guide | Local demos | Verified figure matches | Distinct figure references |
|---|---|---|---:|---:|---:|
| UMAP / t-SNE / `umap_tsne` | Visible | Yes | 3 | 3 | 3 |
| Feature embedding / `feature_embedding` | Visible | Yes | 3 | 2 | 2 |
| Alluvial / Sankey / Chord Plot / `alluvial` | Visible | Yes | 3 | 2 | 2 |
| Annotated Tree / `annotated_tree_plot` | Visible | Yes | 2 | 0 | 0 |
| Balloon Plot / `balloon_plot` | Hidden; source only | Yes | 3 | 1 | 1 |
| 3D Bar / Lego / `bar3d_plot` | Visible | Yes | 2 | 0 | 0 |
| Binary Model Evaluation / `binary_evaluation_plot` | Visible | Yes | 5 | 0 | 0 |
| Bland–Altman Agreement / `bland_altman_plot` | Visible | Yes | 2 | 0 | 0 |
| Circular Bar Plot / `circular_bar_plot` | Visible | Yes | 2 | 2 | 2 |
| Circular Score Distribution / `circular_distribution_plot` | Visible | Yes | 2 | 0 | 0 |
| Circular Genome Tracks / `circular_genomic_plot` | Visible | Yes | 4 | 0 | 0 |
| Circular Heatmap / `circular_heatmap` | Visible | Yes | 3 | 2 | 2 |
| Circular Tree + Embedding / `circular_tree_embedding` | Visible | Yes | 3 | 1 | 1 |
| Classified Bar Plot / `classified_bar_plot` | Hidden; source only | Yes | 3 | 3 | 3 |
| Clonal Evolution / `clonal_fish_plot` | Visible | Yes | 2 | 0 | 0 |
| Cluster Dendrogram Plot / `cluster_dendrogram_plot` | Visible | Yes | 3 | 2 | 2 |
| Combo Bar + Dot Matrix / `combo_bar_dot_matrix` | Visible | Yes | 3 | 1 | 1 |
| Combo Bar + Line Plot / `combo_bar_line_plot` | Hidden; source only | Yes | 3 | 0 | 0 |
| Den Plot / `den_plot` | Hidden; source only | Yes | 3 | 2 | 2 |
| Basic / Advanced Dot Plot / `dot_plot` | Visible | Yes | 3 | 3 | 3 |
| Venn / `venn` | Visible | Yes | 2 | 3 | 3 |
| Empirical CDF / `ecdf_plot` | Visible | Yes | 2 | 0 | 0 |
| Embedding Vector Field / `embedding_vector_plot` | Visible | Yes | 2 | 0 | 0 |
| Basic / Advanced Bar Plot / `exp_stat_plot` | Visible | Yes | 3 | 2 | 2 |
| Feature Density Plot / `feature_density_plot` | Hidden; source only | Yes | 3 | 0 | 0 |
| GSEA / enrichment running plots / `gsea` | Visible | Yes | 3 | 1 | 1 |
| Forest Plot / `forest_plot` | Visible | Yes | 3 | 0 | 0 |
| GO / KEGG Enrichment / `go_kegg_enrichment_bar_bubble` | Visible | Yes | 1 | 1 | 1 |
| Group heatmap / `grouped_heatmap` | Visible | Yes | 3 | 2 | 2 |
| GSEA Pathway Heatmap / `gsea_heatmap` | Hidden; source only | Yes | 3 | 0 | 0 |
| GSEA Pathway Ridge + NES / `gsea_ridge_nes_plot` | Hidden; source only | Yes | 1 | 0 | 0 |
| Hierarchical Marker Panel / `hierarchical_marker_panel` | Visible | Yes | 3 | 3 | 3 |
| Highlight Effect (Focus + Other Cloud) / `highlight_effect_plot` | Visible | Yes | 3 | 1 | 1 |
| 3D Embedding / `interactive_3d_scatter` | Visible | Yes | 2 | 0 | 0 |
| Interactive Arc Network Plot / `interactive_arc_network_plot` | Visible | Yes | 3 | 1 | 1 |
| Interactive Binary Presence/Absence Plot / `interactive_binary_plot` | Hidden; source only | Yes | 3 | 1 | 1 |
| Interactive Bubble Score Matrix / `interactive_bubble_score_matrix` | Visible | Yes | 3 | 1 | 1 |
| Interactive Clustered Heatmap / `interactive_clustered_heatmap_plot` | Hidden; source only | Yes | 3 | 1 | 1 |
| Correlation / Dual-Triangle Matrix / `interactive_correlation_matrix` | Visible | Yes | 3 | 2 | 2 |
| Interactive Dual-Triangle Heatmap / `interactive_dual_triangle_heatmap_plot` | Hidden; source only | Yes | 3 | 0 | 0 |
| Interactive Dumbbell Plot / `interactive_dumbbell_plot` | Visible | Yes | 3 | 1 | 1 |
| Enrichment lollipop / `enrichment_lollipop` | Visible | Yes | 3 | 2 | 2 |
| Interactive Genomic Signal Track Plot / `interactive_genomic_signal_track_plot` | Visible | Yes | 3 | 3 | 2 |
| Interactive Histogram Plot / `interactive_histogram_plot` | Visible | Yes | 3 | 2 | 2 |
| Mantel + Pearson Correlation / `interactive_mantel_correlation_network` | Visible | Yes | 1 | 2 | 2 |
| Interactive Motif Enrichment Logo / `interactive_motif_logo_plot` | Visible | Yes | 3 | 2 | 2 |
| Interactive Network / `interactive_network_plot` | Visible | Yes | 3 | 1 | 1 |
| Pie / Rose Plot / `interactive_pie_plot` | Visible | Yes | 3 | 1 | 1 |
| Interactive Radar Plot / `interactive_radar_plot` | Visible | Yes | 3 | 2 | 2 |
| Ridgeline / `ridgeline` | Visible | Yes | 3 | 2 | 2 |
| Interactive Sankey / Alluvial Flow / `sankey` | Hidden; source only | Yes | 1 | 2 | 2 |
| UpSet / `upset` | Visible | Yes | 3 | 2 | 2 |
| Violin / Box / Point Plot / `interactive_violin_plot` | Visible | Yes | 3 | 1 | 1 |
| Line Plot / `line_plot` | Visible | Yes | 3 | 2 | 2 |
| Lineage / trajectory / `trajectory` | Visible | Yes | 3 | 1 | 1 |
| Linked Heatmap + Network / `linked_matrix_network_plot` | Visible | Yes | 2 | 0 | 0 |
| Manhattan / QQ / `manhattan_qq_plot` | Visible | Yes | 3 | 0 | 0 |
| Nomogram Scales / `nomogram_plot` | Visible | Yes | 2 | 0 | 0 |
| Mutation Matrix / `oncoprint_plot` | Visible | Yes | 2 | 0 | 0 |
| Pie Dot Matrix (Ratio Circles) / `pie_dot_matrix` | Hidden; source only | Yes | 3 | 1 | 1 |
| Protein Variant Map / `protein_variant_plot` | Visible | Yes | 2 | 0 | 0 |
| Quadrant Correlation Scatter / `quadrant_correlation_scatter` | Visible | Yes | 1 | 1 | 1 |
| Wheel / RadViz / `radviz_plot` | Visible | Yes | 2 | 0 | 0 |
| Raincloud Plot / `raincloud_plot` | Visible | Yes | 2 | 2 | 2 |
| Ranked Annotation Panel / `ranked_annotation_panel` | Visible | Yes | 1 | 1 | 1 |
| Regression Scatter Plot / `regression_scatter_plot` | Visible | Yes | 2 | 3 | 3 |
| Risk Stratification Panel / `risk_stratification_panel` | Visible | Yes | 2 | 0 | 0 |
| Volcano / `volcano` | Visible | Yes | 3 | 2 | 2 |
| Sequence Alignment / `sequence_alignment_plot` | Visible | Yes | 2 | 0 | 0 |
| Spatial Region Map / `spatial_region_plot` | Visible | Yes | 3 | 0 | 0 |
| Stacked Bar Plot / `stacked_bar_plot` | Hidden; source only | Yes | 3 | 3 | 3 |
| Stat Plot / `stat_plot` | Hidden; source only | Yes | 3 | 2 | 2 |
| Sunburst Plot / `sunburst_plot` | Visible | Yes | 2 | 2 | 2 |
| Survival Curve / `survival_plot` | Visible | Yes | 3 | 0 | 0 |
| Swimmer Timeline / `swimmer_plot` | Visible | Yes | 2 | 0 | 0 |
| Ternary Plot / `ternary_plot` | Visible | Yes | 1 | 2 | 2 |
| Threshold Matrix Heatmap / `threshold_matrix_heatmap` | Visible | Yes | 1 | 1 | 1 |
| Treemap Plot / `treemap_plot` | Visible | Yes | 1 | 2 | 2 |
| Violin Plot / `violin_plot` | Visible | Yes | 3 | 1 | 1 |
| Waterfall Plot / `waterfall_plot` | Visible | Yes | 2 | 2 | 2 |

## Entries without a Guide

None. Every registry entry has a Guide source file.

## Fewer than two independent local demos

- `go_kegg_enrichment_bar_bubble`: 1 bundle (go_kegg); add a distinct input or mode-specific bundle.
- `gsea_ridge_nes_plot`: 1 bundle (basic); add a distinct input or mode-specific bundle.
- `interactive_mantel_correlation_network`: 1 bundle (basic); add a distinct input or mode-specific bundle.
- `sankey`: 1 bundle (basic); add a distinct input or mode-specific bundle.
- `quadrant_correlation_scatter`: 1 bundle (params); add a distinct input or mode-specific bundle.
- `ranked_annotation_panel`: 1 bundle (params); add a distinct input or mode-specific bundle.
- `ternary_plot`: 1 bundle (basic); add a distinct input or mode-specific bundle.
- `threshold_matrix_heatmap`: 1 bundle (params); add a distinct input or mode-specific bundle.
- `treemap_plot`: 1 bundle (basic); add a distinct input or mode-specific bundle.

## Literature gaps

The target of 2–3 distinct references with suitable figure examples per plot has not been met universally. These visible plots have fewer than two distinct figure references:

- `annotated_tree_plot`: 0 figure reference(s), 0 verified figure record(s).
- `bar3d_plot`: 0 figure reference(s), 0 verified figure record(s).
- `binary_evaluation_plot`: 0 figure reference(s), 0 verified figure record(s).
- `bland_altman_plot`: 0 figure reference(s), 0 verified figure record(s).
- `circular_distribution_plot`: 0 figure reference(s), 0 verified figure record(s).
- `circular_genomic_plot`: 0 figure reference(s), 0 verified figure record(s).
- `circular_tree_embedding`: 1 figure reference(s), 1 verified figure record(s).
- `clonal_fish_plot`: 0 figure reference(s), 0 verified figure record(s).
- `combo_bar_dot_matrix`: 1 figure reference(s), 1 verified figure record(s).
- `ecdf_plot`: 0 figure reference(s), 0 verified figure record(s).
- `embedding_vector_plot`: 0 figure reference(s), 0 verified figure record(s).
- `gsea`: 1 figure reference(s), 1 verified figure record(s).
- `forest_plot`: 0 figure reference(s), 0 verified figure record(s).
- `go_kegg_enrichment_bar_bubble`: 1 figure reference(s), 1 verified figure record(s).
- `highlight_effect_plot`: 1 figure reference(s), 1 verified figure record(s).
- `interactive_3d_scatter`: 0 figure reference(s), 0 verified figure record(s).
- `interactive_arc_network_plot`: 1 figure reference(s), 1 verified figure record(s).
- `interactive_bubble_score_matrix`: 1 figure reference(s), 1 verified figure record(s).
- `interactive_dumbbell_plot`: 1 figure reference(s), 1 verified figure record(s).
- `interactive_network_plot`: 1 figure reference(s), 1 verified figure record(s).
- `interactive_pie_plot`: 1 figure reference(s), 1 verified figure record(s).
- `interactive_violin_plot`: 1 figure reference(s), 1 verified figure record(s).
- `trajectory`: 1 figure reference(s), 1 verified figure record(s).
- `linked_matrix_network_plot`: 0 figure reference(s), 0 verified figure record(s).
- `manhattan_qq_plot`: 0 figure reference(s), 0 verified figure record(s).
- `nomogram_plot`: 0 figure reference(s), 0 verified figure record(s).
- `oncoprint_plot`: 0 figure reference(s), 0 verified figure record(s).
- `protein_variant_plot`: 0 figure reference(s), 0 verified figure record(s).
- `quadrant_correlation_scatter`: 1 figure reference(s), 1 verified figure record(s).
- `radviz_plot`: 0 figure reference(s), 0 verified figure record(s).
- `ranked_annotation_panel`: 1 figure reference(s), 1 verified figure record(s).
- `risk_stratification_panel`: 0 figure reference(s), 0 verified figure record(s).
- `sequence_alignment_plot`: 0 figure reference(s), 0 verified figure record(s).
- `spatial_region_plot`: 0 figure reference(s), 0 verified figure record(s).
- `survival_plot`: 0 figure reference(s), 0 verified figure record(s).
- `swimmer_plot`: 0 figure reference(s), 0 verified figure record(s).
- `threshold_matrix_heatmap`: 1 figure reference(s), 1 verified figure record(s).
- `violin_plot`: 1 figure reference(s), 1 verified figure record(s).

Visible plots currently supported only by related-layout examples: `combo_bar_dot_matrix`, `go_kegg_enrichment_bar_bubble`, `hierarchical_marker_panel`, `highlight_effect_plot`, `interactive_bubble_score_matrix`, `trajectory`, `ranked_annotation_panel`, `threshold_matrix_heatmap`.

Entries with no verified figure association, including hidden legacy entries: `annotated_tree_plot`, `bar3d_plot`, `binary_evaluation_plot`, `bland_altman_plot`, `circular_distribution_plot`, `circular_genomic_plot`, `clonal_fish_plot`, `combo_bar_line_plot`, `ecdf_plot`, `embedding_vector_plot`, `feature_density_plot`, `forest_plot`, `gsea_heatmap`, `gsea_ridge_nes_plot`, `interactive_3d_scatter`, `interactive_dual_triangle_heatmap_plot`, `linked_matrix_network_plot`, `manhattan_qq_plot`, `nomogram_plot`, `oncoprint_plot`, `protein_variant_plot`, `radviz_plot`, `risk_stratification_panel`, `sequence_alignment_plot`, `spatial_region_plot`, `survival_plot`, `swimmer_plot`.

Method-only references without a checked figure are useful reading, but are not counted as figure examples.

## Plot-by-plot details

### UMAP / t-SNE · `umap_tsne`

- Guide: [source](../../plot_web/registry/guides/umap_tsne.yaml); engine: `advanced_dim_plot`.
- Status: visible in the editor.
- Purpose: Visualizes high-dimensional observations in a two-dimensional embedding while approximately preserving aspects of neighborhood structure.

- Input: Observation IDs, two embedding coordinates and group annotations; numeric features for feature maps, and sample or condition labels for composition views.
- Scenarios: Cell clusters; Cell states; Feature-expression patterns; Sample mixing; Annotation overview
- Reading: Dense or separated regions may indicate groups of observations with similar profiles. This is a visual pattern, not a statistical test.
; Nearby observations often have more similar high-dimensional profiles than distant observations.

- Cautions: Distances between widely separated regions should not automatically be interpreted as quantitative biological distances.
; The visual area occupied by a cluster is not necessarily proportional to biological abundance.
; Visual separation alone does not establish statistical significance.


Published figure examples:

- **Figure 1B: Annotated T-cell embedding** — Same plot grammar.
  Hao Q, Zhou T, Yan H, et al. (2026), *Molecular Cancer*. [A pan-cancer single cell landscape reveals heterogeneity and functional diversity of double-negative T cells](https://link.springer.com/article/10.1186/s12943-025-02548-8).
  Source: [figure/caption](https://link.springer.com/article/10.1186/s12943-025-02548-8/figures/1); DOI `10.1186/s12943-025-02548-8`; checked 2026-10-25.
  Shown in the paper: Cell-type labels on UMAP.
  Apply it: Supply embedding coordinates and cell annotations; the renderer does not integrate datasets.
- **Figure 2B: Spatial-imaging cell annotations** — Same plot grammar.
  Tan Y, Kempchen TN, Becker M, et al. (2025), *Nature Communications*. [SPACEc: a streamlined, interactive Python workflow for multiplexed image processing and analysis](https://www.nature.com/articles/s41467-025-65658-3).
  Source: [figure/caption](https://www.nature.com/articles/s41467-025-65658-3#Fig2); DOI `10.1038/s41467-025-65658-3`; checked 2026-10-25.
  Shown in the paper: Annotated tonsil cells on UMAP.
  Apply it: Supply computed coordinates and labels; segmentation and annotation are upstream.
- **Figure 3B: Joint multimodal cell map** — Same plot grammar.
  Blair JD, Hartman A, Zenk F, et al. (2025), *Nature Communications*. [Phospho-seq: integrated, multi-modal profiling of intracellular protein dynamics in single cells](https://www.nature.com/articles/s41467-025-56590-7).
  Source: [figure/caption](https://www.nature.com/articles/s41467-025-56590-7#Fig3); DOI `10.1038/s41467-025-56590-7`; checked 2026-10-25.
  Shown in the paper: Joint multimodal UMAP with cell labels.
  Apply it: Provide existing integrated coordinates; this plot does not perform multimodal integration.

Local runnable demos:

- **Basic clusters** · `pdf_repro_basic_umap`: Color cells by cluster or cell type.
  [Parameters](../../plugins/advanced_dim_plot/examples/pdf_repro_basic_umap/params.json) · [Inputs and reproduction](../../plugins/advanced_dim_plot/examples/pdf_repro_basic_umap/manifest.json) · [Preview](../../plugins/advanced_dim_plot/all_examples_gallery/pdf_repro_basic_umap.png)
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Feature expression** · `feature`: Map a numeric feature onto the embedding.
  [Parameters](../../plugins/advanced_dim_plot/examples/feature/params.json) · [Inputs and reproduction](../../plugins/advanced_dim_plot/examples/feature/manifest.json) · [Preview](../../plugins/advanced_dim_plot/all_examples_gallery/feature.png)
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Sample composition** · `pdf_repro_composition_ring`: Compare group fractions within clusters using pies or rings.
  [Parameters](../../plugins/advanced_dim_plot/examples/pdf_repro_composition_ring/params.json) · [Inputs and reproduction](../../plugins/advanced_dim_plot/examples/pdf_repro_composition_ring/manifest.json) · [Preview](../../plugins/advanced_dim_plot/all_examples_gallery/pdf_repro_composition_ring.png)
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `group_column`, `feature_columns`, `x_column`, `y_column`, `label_show`, `width`, `height`.

- Method reference: [UMAP: Uniform Manifold Approximation and Projection for Dimension Reduction](https://arxiv.org/abs/1802.03426) (2018).
  Relevance: Primary method paper for the UMAP embedding shown by this plot family.
- Method reference: [Dimensionality reduction for visualizing single-cell data using UMAP](https://doi.org/10.1038/nbt.4314) (2019).
  Relevance: Published single-cell use of UMAP for cluster and cell-type overview, without copying journal figures.

### Feature embedding · `feature_embedding`

- Guide: [source](../../plot_web/registry/guides/feature_embedding.yaml); engine: `advanced_feature_plot`.
- Status: visible in the editor.
- Purpose: Display continuous features on an existing two-dimensional embedding, with faceting and multifeature color blending.
- Input: Observation IDs, two embedding coordinates and numeric features; optional sample and group columns.
- Scenarios: Locate cell-type markers; Compare feature patterns across conditions; Inspect feature colocalization
- Reading: Color encodes feature values; blended colors combine feature channels.
- Cautions: Colocalization does not establish regulation; Independently scaled panels cannot be compared by color intensity

Published figure examples:

- **Figure 1C: Marker expression on UMAP** — Same plot grammar.
  Hao Q, Zhou T, Yan H, et al. (2026), *Molecular Cancer*. [A pan-cancer single cell landscape reveals heterogeneity and functional diversity of double-negative T cells](https://link.springer.com/article/10.1186/s12943-025-02548-8).
  Source: [figure/caption](https://link.springer.com/article/10.1186/s12943-025-02548-8/figures/1); DOI `10.1186/s12943-025-02548-8`; checked 2026-10-25.
  Shown in the paper: Marker values on the embedding.
  Apply it: Use the same coordinates for feature maps; state expression transformations.
- **Extended Data Figure 6A: Gene activity on the cell embedding** — Same plot grammar.
  Li YE, Preissl S, Hou X, et al. (2021), *Nature*. [An atlas of gene regulatory elements in adult mouse cerebrum](https://www.nature.com/articles/s41586-021-03604-1).
  Source: [figure/caption](https://www.nature.com/articles/s41586-021-03604-1); DOI `10.1038/s41586-021-03604-1`; checked 2026-10-25.
  Shown in the paper: Marker activity on UMAP.
  Apply it: Map activity values to existing coordinates rather than treating activity as RNA expression.

Local runnable demos:

- **Two-feature marker maps** · `pdf_repro_basic_two_features`: Use case: Locate cell-type markers. This preset illustrates two-feature marker maps. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/advanced_feature_plot/examples/pdf_repro_basic_two_features/params.json) · [Inputs and reproduction](../../plugins/advanced_feature_plot/examples/pdf_repro_basic_two_features/manifest.json) · [Preview](../../plugins/advanced_feature_plot/all_examples_gallery/pdf_repro_basic_two_features.png)
  Mappings: `x_column="dim1"`, `y_column="dim2"`, `id_column="cell"`, `group_column="cluster"`, `feature_columns=["Atoh1", "Neurod1"]`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Feature maps split by sample** · `pdf_repro_split_by_sample`: Use case: Compare feature patterns across conditions. This preset illustrates feature maps split by sample. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/advanced_feature_plot/examples/pdf_repro_split_by_sample/params.json) · [Inputs and reproduction](../../plugins/advanced_feature_plot/examples/pdf_repro_split_by_sample/manifest.json) · [Preview](../../plugins/advanced_feature_plot/all_examples_gallery/pdf_repro_split_by_sample.png)
  Mappings: `x_column="dim1"`, `y_column="dim2"`, `id_column="cell"`, `group_column="cluster"`, `feature_columns=["Atoh1"]`, `split_column="orig.ident"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Multifeature colocalization** · `pdf_repro_feature_comp_multiply`: Use case: Inspect feature colocalization. This preset illustrates multifeature colocalization. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/advanced_feature_plot/examples/pdf_repro_feature_comp_multiply/params.json) · [Inputs and reproduction](../../plugins/advanced_feature_plot/examples/pdf_repro_feature_comp_multiply/manifest.json) · [Preview](../../plugins/advanced_feature_plot/all_examples_gallery/pdf_repro_feature_comp_multiply.png)
  Mappings: `x_column="dim1"`, `y_column="dim2"`, `id_column="cell"`, `group_column="cluster"`, `feature_columns=["Atoh1", "Neurod1"]`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `group_column`, `feature_columns`, `x_column`, `y_column`, `palette`, `label_show`, `width`, `height`.


### Alluvial / Sankey / Chord Plot · `alluvial`

- Guide: [source](../../plot_web/registry/guides/alluvial.yaml); engine: `alluvial_plot`.
- Status: visible in the editor.
- Purpose: Show weighted connections between categories across ordered stages.
- Input: Stage categories and flow weights, or a source-target edge table with consistent category names.
- Scenarios: Track clone states across time points; Compare annotation versions; Inspect before-and-after category flows
- Reading: Ribbon widths encode supplied flow weights; stage order follows the configuration.
- Cautions: Cross-sectional correspondence does not prove cell-state transitions; Filtering can change the total flow represented

Published figure examples:

- **Figure 3F: Cross-modality annotation transfer** — Same plot grammar.
  Blair JD, Hartman A, Zenk F, et al. (2025), *Nature Communications*. [Phospho-seq: integrated, multi-modal profiling of intracellular protein dynamics in single cells](https://www.nature.com/articles/s41467-025-56590-7).
  Source: [figure/caption](https://www.nature.com/articles/s41467-025-56590-7#Fig3); DOI `10.1038/s41467-025-56590-7`; checked 2026-10-25.
  Shown in the paper: ATAC labels linked to transferred labels.
  Apply it: Aggregate label-pair counts into source-target flows; label transfer is upstream.
- **Figure 4B-C: Isoform-class changes between tissues** — Same plot grammar.
  Dondi A, Lischetti U, Jacob F, et al. (2023), *Nature Communications*. [Detection of isoforms and genomic alterations by high-throughput full-length single-cell RNA sequencing in ovarian cancer](https://www.nature.com/articles/s41467-023-43387-9).
  Source: [figure/caption](https://www.nature.com/articles/s41467-023-43387-9#Fig4); DOI `10.1038/s41467-023-43387-9`; checked 2026-10-25.
  Shown in the paper: Isoform-biotype flows between tissue groups.
  Apply it: Aggregate paired biotypes into weighted edges; isoform calling and differential usage tests are upstream.

Local runnable demos:

- **Multistage category flows** · `basic`: Use case: Track clone states across time points. This preset illustrates multistage category flows. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/alluvial_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/alluvial_plot/examples/basic/manifest.json) · [Preview](../../plugins/alluvial_plot/all_examples_gallery/basic.png)
  Mappings: `id_column="id"`, `stage_columns=["stage1", "stage2", "stage3", "stage4", "stage5"]`, `weight_column="weight"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Flows from an edge table** · `edges`: Use case: Compare annotation versions. This preset illustrates flows from an edge table. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/alluvial_plot/examples/edges/params.json) · [Inputs and reproduction](../../plugins/alluvial_plot/examples/edges/manifest.json) · [Preview](../../plugins/alluvial_plot/all_examples_gallery/edges.png)
  Mappings: `source_column="source"`, `target_column="target"`, `value_column="value"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Clone lineages across stages** · `hx_lineage`: Use case: Inspect before-and-after category flows. This preset illustrates clone lineages across stages. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/alluvial_plot/examples/hx_lineage/params.json) · [Inputs and reproduction](../../plugins/alluvial_plot/examples/hx_lineage/manifest.json) · [Preview](../../plugins/alluvial_plot/all_examples_gallery/hx_lineage.png)
  Mappings: `id_column="id"`, `stage_columns=["stage1", "stage2", "stage3", "stage4", "stage5"]`, `weight_column="weight"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `input_mode`, `value_column`, `source_column`, `target_column`, `palette`, `label_show`, `base_size`, `width`, `height`.


### Annotated Tree · `annotated_tree_plot`

- Guide: [source](../../plot_web/registry/guides/annotated_tree_plot.yaml); engine: `annotated_tree_plot`.
- Status: visible in the editor.
- Purpose: Draw a supplied weighted tree with leaf metadata or a linked feature heatmap.
- Input: Connected acyclic rooted edge table with parent, child and nonnegative length. Optional size/group fields and a node-keyed annotation table of numeric feature columns.
- Scenarios: Inspect a supplied weighted tree; Link terminal leaves to numeric feature annotations; Show weighted nodes in a circular tree
- Reading: Draw a supplied weighted tree with leaf metadata or a linked feature heatmap. Connected acyclic rooted edge table with parent, child and nonnegative length. Optional size/group fields and a node-keyed annotation table of numeric feature columns.
- Cautions: The tree and branch lengths are supplied. No phylogenetic reconstruction or cluster similarity is inferred.; Heatmap rows must match terminal leaves. A circular layout does not imply circular evolutionary distances.

Published figure examples:

No figure-panel association has been verified yet.

Local runnable demos:

- **Supplied tree and feature heatmap** · `basic`: Inspect a supplied weighted tree
  [Parameters](../../plugins/annotated_tree_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/annotated_tree_plot/examples/basic/manifest.json) · [Preview](../../plugins/annotated_tree_plot/all_examples_gallery/basic.png)
  Mappings: `parent_column="parent"`, `child_column="child"`, `length_column="length"`, `group_column="group"`, `size_column="size"`
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Circular tree with weighted nodes** · `circular`: Link terminal leaves to numeric feature annotations
  [Parameters](../../plugins/annotated_tree_plot/examples/circular/params.json) · [Inputs and reproduction](../../plugins/annotated_tree_plot/examples/circular/manifest.json) · [Preview](../../plugins/annotated_tree_plot/all_examples_gallery/circular.png)
  Mappings: `parent_column="parent"`, `child_column="child"`, `length_column="length"`, `group_column="group"`, `size_column="size"`
  Data provenance: Independent synthetic demonstration, not original publication data.

Customization controls (checked against the schema): `parent_column`, `child_column`, `length_column`, `group_column`, `size_column`, `feature_columns`, `layout`, `gap_angle`, `heatmap_show`, `label_show`, `label_size`, `title`, `subtitle`, `caption`, `title_size`, `tree_color`, `palette`, `group_colors`, `point_size`, `line_width`, `legend_show`, `legend_position`, `legend_text_size`, `font_family`, `base_size`, `plot_background`, `width`, `height`, `dpi`.

- Method reference: [FigureYa: A Standardized Visualization Framework for Enhancing Biomedical Data Interpretation and Research Efficiency](https://github.com/ying-ge/FigureYa) (2025).
  Relevance: Compare the required input shape and intended visualization with the corresponding source module; upstream analyses are not automatically reproduced.

### Balloon Plot · `balloon_plot`

- Guide: [source](../../plot_web/registry/guides/balloon_plot.yaml); engine: `balloon_plot`.
- Status: hidden; documentation source only.
- Purpose: Summarize a numeric matrix with sized bubbles and optional marginal statistics.
- Input: A row identifier and numeric matrix, or supported long-format column mappings.
- Scenarios: Compare sample-feature intensities; Inspect cross-category counts; Check row and column summaries
- Reading: Bubble size encodes values; gradient mode also uses color for intensity.
- Cautions: Read the size legend rather than estimating ratios from diameters; Marginal statistics depend on the selected rows, columns and aggregation

Published figure examples:

- **Figure 2D: Population abundance across cancers** — Same plot grammar.
  Hao Q, Zhou T, Yan H, et al. (2026), *Molecular Cancer*. [A pan-cancer single cell landscape reveals heterogeneity and functional diversity of double-negative T cells](https://link.springer.com/article/10.1186/s12943-025-02548-8).
  Source: [figure/caption](https://link.springer.com/article/10.1186/s12943-025-02548-8/figures/2); DOI `10.1186/s12943-025-02548-8`; checked 2026-10-25.
  Shown in the paper: Population frequencies and cancer-type composition.
  Apply it: Select the pie or sized-matrix component; the local plugin does not assemble the entire original composite.

Local runnable demos:

- **Matrix and marginal summaries** · `basic`: Use case: Compare sample-feature intensities. This preset illustrates matrix and marginal summaries. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/balloon_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/balloon_plot/examples/basic/manifest.json) · [Preview](../../plugins/balloon_plot/all_examples_gallery/basic.png)
  Mappings: `row_id_column="gene"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Continuous color alongside size** · `gradient`: Use case: Inspect cross-category counts. This preset illustrates continuous color alongside size. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/balloon_plot/examples/gradient/params.json) · [Inputs and reproduction](../../plugins/balloon_plot/examples/gradient/manifest.json) · [Preview](../../plugins/balloon_plot/all_examples_gallery/gradient.png)
  Mappings: `row_id_column="gene"`, `highlight_columns=["S04"]`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Matrix without marginal summaries** · `no_stats`: Use case: Check row and column summaries. This preset illustrates matrix without marginal summaries. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/balloon_plot/examples/no_stats/params.json) · [Inputs and reproduction](../../plugins/balloon_plot/examples/no_stats/manifest.json) · [Preview](../../plugins/balloon_plot/all_examples_gallery/no_stats.png)
  Mappings: `row_id_column="gene"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): .


### 3D Bar / Lego · `bar3d_plot`

- Guide: [source](../../plot_web/registry/guides/bar3d_plot.yaml); engine: `bar3d_plot`.
- Status: visible in the editor.
- Purpose: Display a supplied two-dimensional grid of counts as projected three-dimensional bars.
- Input: One nonnegative count per X/Y/group grid cell. X and Y are supplied categorical grid positions. Limit each axis to 15 positions.
- Scenarios: Show two-way mutation-context count grids; Compare height profiles across panels; Inspect a precomputed grid using a fixed projection
- Reading: Display a supplied two-dimensional grid of counts as projected three-dimensional bars. One nonnegative count per X/Y/group grid cell. X and Y are supplied categorical grid positions. Limit each axis to 15 positions.
- Cautions: Perspective obscures some bars. A heatmap or ordinary bar plot may support more accurate comparisons.; Free panel height scaling is explicit and prevents direct height comparisons between panels.

Published figure examples:

No figure-panel association has been verified yet.

Local runnable demos:

- **Mutation-context count grid** · `basic`: Show two-way mutation-context count grids
  [Parameters](../../plugins/bar3d_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/bar3d_plot/examples/basic/manifest.json) · [Preview](../../plugins/bar3d_plot/all_examples_gallery/basic.png)
  Mappings: `x_column="x"`, `y_column="y"`, `value_column="count"`, `group_column="group"`
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Grid heights with independent panel scales** · `free_scale`: Compare height profiles across panels
  [Parameters](../../plugins/bar3d_plot/examples/free_scale/params.json) · [Inputs and reproduction](../../plugins/bar3d_plot/examples/free_scale/manifest.json) · [Preview](../../plugins/bar3d_plot/all_examples_gallery/free_scale.png)
  Mappings: `x_column="x"`, `y_column="y"`, `value_column="count"`, `group_column="group"`
  Data provenance: Independent synthetic demonstration, not original publication data.

Customization controls (checked against the schema): `x_column`, `y_column`, `value_column`, `group_column`, `azimuth`, `elevation`, `z_scale`, `ncol`, `bar_width`, `line_width`, `label_size`, `title`, `subtitle`, `caption`, `title_size`, `palette`, `group_colors`, `font_family`, `base_size`, `plot_background`, `width`, `height`, `dpi`.

- Method reference: [FigureYa: A Standardized Visualization Framework for Enhancing Biomedical Data Interpretation and Research Efficiency](https://github.com/ying-ge/FigureYa) (2025).
  Relevance: Compare the required input shape and intended visualization with the corresponding source module; upstream analyses are not automatically reproduced.

### Binary Model Evaluation · `binary_evaluation_plot`

- Guide: [source](../../plot_web/registry/guides/binary_evaluation_plot.yaml); engine: `binary_evaluation_plot`.
- Status: visible in the editor.
- Purpose: ROC, precision–recall, calibration and decision curves from supplied predictions.
- Input: Predictions mode: binary outcome, numeric score and optional model/group. Calibration and decision curves require probabilities in [0,1]. Curve mode: supplied numeric x/y and optional group.
- Scenarios: Compare supplied binary-model predictions; Inspect probability calibration; Compare net benefit over declared decision thresholds
- Reading: ROC, precision–recall, calibration and decision curves from supplied predictions. Predictions mode: binary outcome, numeric score and optional model/group. Calibration and decision curves require probabilities in [0,1]. Curve mode: supplied numeric x/y and optional group.
- Cautions: No model training, optimism correction or clinical threshold selection is performed. Evaluate held-out predictions where appropriate.; Ordinary binary evaluation does not handle censored outcomes. Upload externally computed curves for time-dependent ROC.

Published figure examples:

No figure-panel association has been verified yet.

Local runnable demos:

- **Receiver operating characteristic** · `basic`: Compare supplied binary-model predictions
  [Parameters](../../plugins/binary_evaluation_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/binary_evaluation_plot/examples/basic/manifest.json) · [Preview](../../plugins/binary_evaluation_plot/all_examples_gallery/basic.png)
  Mappings: `outcome_column="outcome"`, `score_column="score"`, `group_column="group"`, `x_column="x"`, `y_column="y"`
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Precision and recall** · `precision_recall`: Inspect probability calibration
  [Parameters](../../plugins/binary_evaluation_plot/examples/precision_recall/params.json) · [Inputs and reproduction](../../plugins/binary_evaluation_plot/examples/precision_recall/manifest.json) · [Preview](../../plugins/binary_evaluation_plot/all_examples_gallery/precision_recall.png)
  Mappings: `outcome_column="outcome"`, `score_column="score"`, `group_column="group"`, `x_column="x"`, `y_column="y"`
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Probability calibration** · `calibration`: Compare net benefit over declared decision thresholds
  [Parameters](../../plugins/binary_evaluation_plot/examples/calibration/params.json) · [Inputs and reproduction](../../plugins/binary_evaluation_plot/examples/calibration/manifest.json) · [Preview](../../plugins/binary_evaluation_plot/all_examples_gallery/calibration.png)
  Mappings: `outcome_column="outcome"`, `score_column="score"`, `group_column="group"`, `x_column="x"`, `y_column="y"`
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Net benefit by threshold** · `decision_curve`: Compare net benefit over declared decision thresholds
  [Parameters](../../plugins/binary_evaluation_plot/examples/decision_curve/params.json) · [Inputs and reproduction](../../plugins/binary_evaluation_plot/examples/decision_curve/manifest.json) · [Preview](../../plugins/binary_evaluation_plot/all_examples_gallery/decision_curve.png)
  Mappings: `outcome_column="outcome"`, `score_column="score"`, `group_column="group"`, `x_column="x"`, `y_column="y"`
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Supplied evaluation curves** · `supplied_curve`: Compare net benefit over declared decision thresholds
  [Parameters](../../plugins/binary_evaluation_plot/examples/supplied_curve/params.json) · [Inputs and reproduction](../../plugins/binary_evaluation_plot/examples/supplied_curve/manifest.json) · [Preview](../../plugins/binary_evaluation_plot/all_examples_gallery/supplied_curve.png)
  Mappings: `outcome_column="outcome"`, `score_column="score"`, `group_column="group"`, `x_column="x"`, `y_column="y"`
  Data provenance: Independent synthetic demonstration, not original publication data.

Customization controls (checked against the schema): `outcome_column`, `score_column`, `group_column`, `x_column`, `y_column`, `input_mode`, `plot_type`, `positive_class`, `calibration_bins`, `threshold_min`, `threshold_max`, `point_size`, `line_width`, `palette`, `group_colors`, `title`, `subtitle`, `caption`, `title_size`, `legend_show`, `legend_position`, `legend_text_size`, `metric_show`, `font_family`, `base_size`, `plot_background`, `grid_show`, `width`, `height`, `dpi`, `x_limits`, `y_limits`.

- Method reference: [FigureYa: A Standardized Visualization Framework for Enhancing Biomedical Data Interpretation and Research Efficiency](https://github.com/ying-ge/FigureYa) (2025).
  Relevance: Compare the required input shape and intended visualization with the corresponding source module; upstream analyses are not automatically reproduced.

### Bland–Altman Agreement · `bland_altman_plot`

- Guide: [source](../../plot_web/registry/guides/bland_altman_plot.yaml); engine: `bland_altman_plot`.
- Status: visible in the editor.
- Purpose: Compare paired measurements using mean differences and limits of agreement.
- Input: Paired finite numeric measurements in the same units, one independent pair per row, with optional group. Percent differences require nonzero pair means.
- Scenarios: Compare two measurement methods; Inspect systematic measurement bias; Inspect proportional differences across measurement ranges
- Reading: Compare paired measurements using mean differences and limits of agreement. Paired finite numeric measurements in the same units, one independent pair per row, with optional group. Percent differences require nonzero pair means.
- Cautions: Agreement limits assume independent, approximately normal differences; repeated measurements require a different model.; The difference direction is method A minus method B. Percent differences use the mean of the pair as denominator.

Published figure examples:

No figure-panel association has been verified yet.

Local runnable demos:

- **Paired measurement agreement** · `basic`: Compare two measurement methods
  [Parameters](../../plugins/bland_altman_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/bland_altman_plot/examples/basic/manifest.json) · [Preview](../../plugins/bland_altman_plot/all_examples_gallery/basic.png)
  Mappings: `x_column="method_a"`, `y_column="method_b"`, `group_column="group"`
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Relative measurement agreement** · `percent`: Inspect systematic measurement bias
  [Parameters](../../plugins/bland_altman_plot/examples/percent/params.json) · [Inputs and reproduction](../../plugins/bland_altman_plot/examples/percent/manifest.json) · [Preview](../../plugins/bland_altman_plot/all_examples_gallery/percent.png)
  Mappings: `x_column="method_a"`, `y_column="method_b"`, `group_column="group"`
  Data provenance: Independent synthetic demonstration, not original publication data.

Customization controls (checked against the schema): `x_column`, `y_column`, `group_column`, `difference_mode`, `loa_multiplier`, `trend_show`, `label_show`, `label_size`, `title`, `subtitle`, `caption`, `title_size`, `point_alpha`, `point_size`, `line_width`, `palette`, `group_colors`, `legend_show`, `legend_position`, `legend_text_size`, `font_family`, `base_size`, `plot_background`, `grid_show`, `width`, `height`, `dpi`.

- Method reference: [FigureYa: A Standardized Visualization Framework for Enhancing Biomedical Data Interpretation and Research Efficiency](https://github.com/ying-ge/FigureYa) (2025).
  Relevance: Compare the required input shape and intended visualization with the corresponding source module; upstream analyses are not automatically reproduced.

### Circular Bar Plot · `circular_bar_plot`

- Guide: [source](../../plot_web/registry/guides/circular_bar_plot.yaml); engine: `circular_bar_plot`.
- Status: visible in the editor.
- Purpose: Arrange category bars around a circle, with optional grouped stacks.
- Input: Category labels, nonnegative values and an optional group column.
- Scenarios: Survey many category counts; Compare components within categories; Create a compact category ranking
- Reading: Radial bar length encodes values; color can distinguish stacked groups.
- Cautions: The inner radius changes apparent area: compare lengths and ticks; Use Cartesian bars when long labels or precise comparisons dominate

Published figure examples:

- **Extended Data Figure 5: Variance-component profiles for proteins** — Same plot grammar.
  Zhernakova DV, Sinha T, Andreu-Sanchez S, et al. (2022), *Nature Cardiovascular Research*. [Age-dependent sex differences in cardiometabolic risk factors](https://www.nature.com/articles/s44161-022-00131-8).
  Source: [figure/caption](https://www.nature.com/articles/s44161-022-00131-8); DOI `10.1038/s44161-022-00131-8`; checked 2026-10-25.
  Shown in the paper: Circular stacked explained-variance bars.
  Apply it: Supply nonnegative variance fractions and component groups; the central dendrogram is not part of this plugin.
- **Figure 9A-C: Pathway significance on a circular axis** — Same plot grammar.
  Celik H, Bansal B, Gill JS, et al. (2026), *Scientific Reports*. [Age-stratified analysis of therapeutic, immune, and glycosylation gene expression in colorectal cancer using machine learning](https://www.nature.com/articles/s41598-025-31499-9).
  Source: [figure/caption](https://www.nature.com/articles/s41598-025-31499-9#Fig9); DOI `10.1038/s41598-025-31499-9`; checked 2026-10-25.
  Shown in the paper: Circular bars summarize pathway enrichment evidence.
  Apply it: Supply term labels and nonnegative -log10 probability values; the source's outer gene annotations are not automatically produced.

Local runnable demos:

- **Grouped category composition** · `basic`: Use case: Survey many category counts. This preset illustrates grouped category composition. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/circular_bar_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/circular_bar_plot/examples/basic/manifest.json) · [Preview](../../plugins/circular_bar_plot/all_examples_gallery/basic.png)
  Mappings: `category_column="category"`, `value_column="value"`, `group_column="group"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Single-series category ranking** · `single`: Use case: Compare components within categories. This preset illustrates single-series category ranking. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/circular_bar_plot/examples/single/params.json) · [Inputs and reproduction](../../plugins/circular_bar_plot/examples/single/manifest.json) · [Preview](../../plugins/circular_bar_plot/all_examples_gallery/single.png)
  Mappings: `category_column="category"`, `value_column="value"`, `group_column="group"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `plot_type`, `group_column`, `value_column`, `category_column`, `palette`, `group_colors`, `label_show`, `base_size`, `width`, `height`.


### Circular Score Distribution · `circular_distribution_plot`

- Guide: [source](../../plot_web/registry/guides/circular_distribution_plot.yaml); engine: `circular_distribution_plot`.
- Status: visible in the editor.
- Purpose: Compare numeric score distributions and highlighted observations on concentric arcs.
- Input: Numeric score, metric name, group and optional observation ID. Highlight IDs select existing observations. Angle represents value, not frequency.
- Scenarios: Compare a target score with reference distributions; Show cohort distributions on concentric arcs; Compare several numeric score metrics
- Reading: Compare numeric score distributions and highlighted observations on concentric arcs. Numeric score, metric name, group and optional observation ID. Highlight IDs select existing observations. Angle represents value, not frequency.
- Cautions: Angle encodes the supplied numeric score, not rank unless ranks were uploaded as values.; Separate ring groups do not encode population size by ring area. Free metric ranges prevent direct angular comparison across panels.

Published figure examples:

No figure-panel association has been verified yet.

Local runnable demos:

- **Scores across reference groups** · `basic`: Compare a target score with reference distributions
  [Parameters](../../plugins/circular_distribution_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/circular_distribution_plot/examples/basic/manifest.json) · [Preview](../../plugins/circular_distribution_plot/all_examples_gallery/basic.png)
  Mappings: `value_column="score"`, `feature_column="metric"`, `group_column="group"`, `id_column="id"`
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Scores on a common scale** · `shared_range`: Show cohort distributions on concentric arcs
  [Parameters](../../plugins/circular_distribution_plot/examples/shared_range/params.json) · [Inputs and reproduction](../../plugins/circular_distribution_plot/examples/shared_range/manifest.json) · [Preview](../../plugins/circular_distribution_plot/all_examples_gallery/shared_range.png)
  Mappings: `value_column="score"`, `feature_column="metric"`, `group_column="group"`, `id_column="id"`
  Data provenance: Independent synthetic demonstration, not original publication data.

Customization controls (checked against the schema): `value_column`, `feature_column`, `group_column`, `id_column`, `highlight_ids`, `highlight_color`, `gap_angle`, `range_mode`, `ncol`, `point_alpha`, `point_size`, `line_width`, `label_size`, `title`, `subtitle`, `caption`, `title_size`, `palette`, `group_colors`, `legend_show`, `legend_position`, `legend_text_size`, `font_family`, `base_size`, `plot_background`, `width`, `height`, `dpi`.

- Method reference: [FigureYa: A Standardized Visualization Framework for Enhancing Biomedical Data Interpretation and Research Efficiency](https://github.com/ying-ge/FigureYa) (2025).
  Relevance: Compare the required input shape and intended visualization with the corresponding source module; upstream analyses are not automatically reproduced.

### Circular Genome Tracks · `circular_genomic_plot`

- Guide: [source](../../plot_web/registry/guides/circular_genomic_plot.yaml); engine: `circular_genomic_plot`.
- Status: visible in the editor.
- Purpose: Arrange supplied genomic intervals, values and optional links on a circular genome.
- Input: Intervals: chromosome, start, end, value and optional track. Coordinates are 0-based, half-open. Optional chromosome/length and source_chr/source_pos/target_chr/target_pos link tables.
- Scenarios: Compare supplied genomic interval tracks; Show chromosome-spanning associations; Compare circular and linear coordinate layouts
- Reading: Arrange supplied genomic intervals, values and optional links on a circular genome. Intervals: chromosome, start, end, value and optional track. Coordinates are 0-based, half-open. Optional chromosome/length and source_chr/source_pos/target_chr/target_pos link tables.
- Cautions: Use chromosome lengths from the correct genome assembly. Inferred maximum interval ends are not a complete genome.; Assembly conversion, peak calling and BigWig extraction are upstream operations. Track heights use within-track numeric ranges.

Published figure examples:

No figure-panel association has been verified yet.

Local runnable demos:

- **Circular interval heatmap** · `basic`: Compare supplied genomic interval tracks
  [Parameters](../../plugins/circular_genomic_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/circular_genomic_plot/examples/basic/manifest.json) · [Preview](../../plugins/circular_genomic_plot/all_examples_gallery/basic.png)
  Mappings: `chromosome_column="chromosome"`, `start_column="start"`, `end_column="end"`, `value_column="value"`, `group_column="track"`
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Circular interval magnitudes** · `bars`: Show chromosome-spanning associations
  [Parameters](../../plugins/circular_genomic_plot/examples/bars/params.json) · [Inputs and reproduction](../../plugins/circular_genomic_plot/examples/bars/manifest.json) · [Preview](../../plugins/circular_genomic_plot/all_examples_gallery/bars.png)
  Mappings: `chromosome_column="chromosome"`, `start_column="start"`, `end_column="end"`, `value_column="value"`, `group_column="track"`
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Circular interval points** · `points`: Compare circular and linear coordinate layouts
  [Parameters](../../plugins/circular_genomic_plot/examples/points/params.json) · [Inputs and reproduction](../../plugins/circular_genomic_plot/examples/points/manifest.json) · [Preview](../../plugins/circular_genomic_plot/all_examples_gallery/points.png)
  Mappings: `chromosome_column="chromosome"`, `start_column="start"`, `end_column="end"`, `value_column="value"`, `group_column="track"`
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Linear chromosome overview** · `linear`: Compare circular and linear coordinate layouts
  [Parameters](../../plugins/circular_genomic_plot/examples/linear/params.json) · [Inputs and reproduction](../../plugins/circular_genomic_plot/examples/linear/manifest.json) · [Preview](../../plugins/circular_genomic_plot/all_examples_gallery/linear.png)
  Mappings: `chromosome_column="chromosome"`, `start_column="start"`, `end_column="end"`, `value_column="value"`, `group_column="track"`
  Data provenance: Independent synthetic demonstration, not original publication data.

Customization controls (checked against the schema): `chromosome_column`, `start_column`, `end_column`, `value_column`, `group_column`, `layout`, `track_type`, `gap_angle`, `link_show`, `link_alpha`, `point_size`, `line_width`, `link_color`, `low_color`, `high_color`, `palette`, `group_colors`, `legend_title`, `legend_show`, `legend_position`, `legend_text_size`, `label_size`, `title`, `subtitle`, `caption`, `title_size`, `font_family`, `base_size`, `plot_background`, `grid_show`, `width`, `height`, `dpi`.

- Method reference: [FigureYa: A Standardized Visualization Framework for Enhancing Biomedical Data Interpretation and Research Efficiency](https://github.com/ying-ge/FigureYa) (2025).
  Relevance: Compare the required input shape and intended visualization with the corresponding source module; upstream analyses are not automatically reproduced.

### Circular Heatmap · `circular_heatmap`

- Guide: [source](../../plot_web/registry/guides/circular_heatmap.yaml); engine: `circular_heatmap`.
- Status: visible in the editor.
- Purpose: Arrange matrix values in concentric rings and angular tiles, with optional clustering.
- Input: Long-format row, column and value fields; duplicate row-column pairs are averaged.
- Scenarios: Summarize sample-marker matrices; Find coordinated feature modules; Compare a prescribed sample order
- Reading: Rows form rings, columns occupy angular positions and color encodes values.
- Cautions: Different ring areas do not imply different feature totals; Clustering reflects the chosen distance and preprocessing; Choose categorical values for concentric sample annotation rings. Categorical cells must be unique; numeric clustering is unavailable. Named category colors apply only to categorical mode.

Published figure examples:

- **Figure 1B: Top differential genes in a circle** — Same plot grammar.
  Chen H, Liang Q, Geng L, Feng B (2025), *Scientific Reports*. [Transcriptomic exploration of key genes related to mitochondria and ferroptosis in inflammatory bowel disease and experimental validation](https://www.nature.com/articles/s41598-025-27002-z).
  Source: [figure/caption](https://www.nature.com/articles/s41598-025-27002-z#Fig1); DOI `10.1038/s41598-025-27002-z`; checked 2026-10-25.
  Shown in the paper: Circular expression heatmap.
  Apply it: Prepare a long sample-gene-value table and report scaling before clustering.
- **Extended Data Figure 4: Sleep-feature effects across body systems** — Same plot grammar.
  Kohn S, Diament A, Godneva A, et al. (2025), *Nature Medicine*. [Phenome-wide associations of sleep characteristics in the Human Phenotype Project](https://www.nature.com/articles/s41591-024-03481-x).
  Source: [figure/caption](https://www.nature.com/articles/s41591-024-03481-x); DOI `10.1038/s41591-024-03481-x`; checked 2026-10-25.
  Shown in the paper: Circular heatmap of direct effects.
  Apply it: Use supplied effect estimates and body-system labels; mediation analysis is upstream.

Local runnable demos:

- **Matrix in input order** · `basic`: Use case: Summarize sample-marker matrices. This preset illustrates matrix in input order. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/circular_heatmap/examples/basic/params.json) · [Inputs and reproduction](../../plugins/circular_heatmap/examples/basic/manifest.json) · [Preview](../../plugins/circular_heatmap/all_examples_gallery/basic.png)
  Mappings: `row_column="row"`, `column_column="column"`, `value_column="value"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Clustered feature modules** · `clustered`: Use case: Find coordinated feature modules. This preset illustrates clustered feature modules. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/circular_heatmap/examples/clustered/params.json) · [Inputs and reproduction](../../plugins/circular_heatmap/examples/clustered/manifest.json) · [Preview](../../plugins/circular_heatmap/all_examples_gallery/clustered.png)
  Mappings: `row_column="row"`, `column_column="column"`, `value_column="value"`, `cluster_columns=true`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Categorical annotation rings** · `categorical`: Categorical annotation rings
  [Parameters](../../plugins/circular_heatmap/examples/categorical/params.json) · [Inputs and reproduction](../../plugins/circular_heatmap/examples/categorical/manifest.json) · [Preview](../../plugins/circular_heatmap/all_examples_gallery/categorical.png)
  Data provenance: Independent synthetic data; upstream inference is not performed.

Customization controls (checked against the schema): `value_column`, `palette`, `cluster_rows`, `cluster_columns`, `label_show`, `base_size`, `width`, `height`.

- Method reference: [Cluster analysis and display of genome-wide expression patterns](https://www.cs.princeton.edu/courses/archive/fall03/cs597F/Articles/cluster_analysis_hier_eisen.pdf) (1998).
  Relevance: Background for expression heatmaps and clustering; circular layouts and extra panels are local adaptations.

### Circular Tree + Embedding · `circular_tree_embedding`

- Guide: [source](../../plot_web/registry/guides/circular_tree_embedding.yaml); engine: `circular_tree_embedding`.
- Status: visible in the editor.
- Purpose: Link a radial cell-type hierarchy to a central embedding with matching annotation colors.
- Input: One cell table with numeric embedding X/Y, a leaf subtype, and ordered categorical hierarchy columns. Similarity mode additionally requires at least two finite numeric feature columns.
- Scenarios: Summarize a cell atlas at multiple annotation levels; Compare known taxonomy with feature-based cluster similarity; Switch center colors between broad classes and fine subtypes
- Reading: Annotation mode shows supplied parent-child relationships with equal depth per level. Similarity mode uses Euclidean distances on mean feature profiles, optionally standardized across leaves.; The center color annotation must belong to the ring hierarchy. Select class, subclass or subtype and use the same named color overrides throughout.
- Cautions: No UMAP/t-SNE or lineage inference is performed. Do not interpret global embedding distances as calibrated similarity, or annotation branch lengths as biological distances.; Circular slots are equal per leaf, not proportional to cell abundance. Hulls are descriptive convex envelopes, not density contours or confidence intervals.; Each child label and leaf must have one unique parent path. Similarity order may split a category into multiple separate ring arcs.

Published figure examples:

- **Figure 2a: Hierarchical cell taxonomy with a central embedding** — Same plot grammar.
  Lee D, Koutrouli M, Masse NY, et al. (2026), *Nature*. [Single-cell atlas of transcriptomic vulnerability across brain disorders](https://www.nature.com/articles/s41586-025-09573-z).
  Source: [figure/caption](https://www.nature.com/articles/s41586-025-09573-z#Fig2); DOI `10.1038/s41586-025-09573-z`; checked 2026-10-25.
  Shown in the paper: Atlas overview with eight classes, 27 subclasses and 65 subtypes.
  Apply it: Supply cell coordinates and class/subclass/subtype labels. Use annotation mode for an existing taxonomy, or measured feature means for similarity clustering. The original iterative taxonomy inference and embedding are upstream analyses; this plugin does not reproduce them. Local demos contain 17 synthetic leaves, not the original atlas data.

Local runnable demos:

- **Known cell-type taxonomy** · `basic`: Summarize an annotated cell atlas
  [Parameters](../../plugins/circular_tree_embedding/examples/basic/params.json) · [Inputs and reproduction](../../plugins/circular_tree_embedding/examples/basic/manifest.json) · [Preview](../../plugins/circular_tree_embedding/all_examples_gallery/basic.png)
  Mappings: `x_column="UMAP_1"`, `y_column="UMAP_2"`, `cluster_column="subtype"`, `group_column="subclass"`
  Data provenance: Independent synthetic cell data, not the original reference image or paper data.
- **Feature-based relationships** · `similarity`: Compare subtype feature profiles independently of the embedding
  [Parameters](../../plugins/circular_tree_embedding/examples/similarity/params.json) · [Inputs and reproduction](../../plugins/circular_tree_embedding/examples/similarity/manifest.json) · [Preview](../../plugins/circular_tree_embedding/all_examples_gallery/similarity.png)
  Mappings: `x_column="UMAP_1"`, `y_column="UMAP_2"`, `cluster_column="subtype"`, `group_column="subtype"`
  Data provenance: Independent synthetic cell data, not the original reference image or paper data.
- **CAB_demo** · `CAB_demo`: Show broad class colors in a reference-inspired atlas arrangement
  [Parameters](../../plugins/circular_tree_embedding/examples/CAB_demo/params.json) · [Inputs and reproduction](../../plugins/circular_tree_embedding/examples/CAB_demo/manifest.json) · [Preview](../../plugins/circular_tree_embedding/all_examples_gallery/CAB_demo.png)
  Mappings: `x_column="UMAP_1"`, `y_column="UMAP_2"`, `cluster_column="subtype"`, `group_column="class"`
  Data provenance: Independent synthetic cell data, not the original reference image or paper data.

Customization controls (checked against the schema): `x_column`, `y_column`, `cluster_column`, `group_column`, `hierarchy_columns`, `feature_columns`, `tree_mode`, `cluster_method`, `scale_features`, `point_size`, `point_alpha`, `hull_alpha`, `tree_line_width`, `hull_show`, `palette`, `group_colors`, `tree_color`, `label_show`, `label_size`, `leaf_label_show`, `leaf_label_size`, `ring_label_show`, `ring_label_size`, `title`, `subtitle`, `caption`, `embedding_radius`, `gap_angle`, `rotation`, `ring_width`, `font_family`, `base_size`, `plot_background`, `width`, `height`, `dpi`.


### Classified Bar Plot · `classified_bar_plot`

- Guide: [source](../../plot_web/registry/guides/classified_bar_plot.yaml); engine: `classified_bar_plot`.
- Status: hidden; documentation source only.
- Purpose: Rank categories with one bar per item, colored by its class.
- Input: Category labels, numeric values and a class/type column.
- Scenarios: Rank enrichment terms by class; Compare feature scores; Highlight a functional category
- Reading: Bar length encodes the value and color identifies the class.
- Cautions: Classes are annotations rather than extra numeric series; Sorting and top-N filters change the displayed universe

Published figure examples:

- **Figure 2G: Ranked biological-process enrichment** — Related layout; adaptation required.
  Hao Q, Zhou T, Yan H, et al. (2026), *Molecular Cancer*. [A pan-cancer single cell landscape reveals heterogeneity and functional diversity of double-negative T cells](https://link.springer.com/article/10.1186/s12943-025-02548-8).
  Source: [figure/caption](https://link.springer.com/article/10.1186/s12943-025-02548-8/figures/2); DOI `10.1186/s12943-025-02548-8`; checked 2026-10-25.
  Shown in the paper: Bars summarize pathway enrichment evidence.
  Apply it: The source supplies enrichment bars; counts and extra bubble encodings require separate data and are not inferred.
- **Figure 2D: Rank treatment frequencies** — Same plot grammar.
  Liu T, Qiao H, Ren L, et al. (2025), *Communications Biology*. [Deciphering cancer therapy resistance via patient-level single-cell transcriptomics with CellResDB](https://www.nature.com/articles/s42003-025-08457-2).
  Source: [figure/caption](https://www.nature.com/articles/s42003-025-08457-2#Fig2); DOI `10.1038/s42003-025-08457-2`; checked 2026-10-25.
  Shown in the paper: Drug-use counts across datasets.
  Apply it: Use one row per treatment with a count and optional treatment-class annotation.
- **Figure 2A-B: Compare fertilizer emission metrics** — Same plot grammar.
  Sanchez-Mendez S, Orden L, Franco-Luesma S, et al. (2025), *Scientific Reports*. [Agronomic and environmental assessment of a new fertilization strategy using pelleted organo-mineral fertilizers for wheat production in mediterranean agricultural soils](https://www.nature.com/articles/s41598-025-20818-9).
  Source: [figure/caption](https://www.nature.com/articles/s41598-025-20818-9#Fig2); DOI `10.1038/s41598-025-20818-9`; checked 2026-10-25.
  Shown in the paper: Treatment bars with standard errors.
  Apply it: Prepare treatment-level means and errors; preserve units and do not infer significance from bar overlap.

Local runnable demos:

- **Category score overview** · `basic`: Use case: Rank enrichment terms by class. This preset illustrates category score overview. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/classified_bar_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/classified_bar_plot/examples/basic/manifest.json) · [Preview](../../plugins/classified_bar_plot/all_examples_gallery/basic.png)
  Mappings: `category_column="category"`, `type_column="type"`, `value_column="value"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Vertical category comparison** · `vertical`: Use case: Compare feature scores. This preset illustrates vertical category comparison. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/classified_bar_plot/examples/vertical/params.json) · [Inputs and reproduction](../../plugins/classified_bar_plot/examples/vertical/manifest.json) · [Preview](../../plugins/classified_bar_plot/all_examples_gallery/vertical.png)
  Mappings: `category_column="category"`, `type_column="type"`, `value_column="value"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Rankings with numeric labels** · `labeled`: Use case: Highlight a functional category. This preset illustrates rankings with numeric labels. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/classified_bar_plot/examples/labeled/params.json) · [Inputs and reproduction](../../plugins/classified_bar_plot/examples/labeled/manifest.json) · [Preview](../../plugins/classified_bar_plot/all_examples_gallery/labeled.png)
  Mappings: `category_column="category"`, `type_column="type"`, `value_column="value"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `value_column`, `category_column`, `sort_by`, `palette`, `width`, `height`.


### Clonal Evolution · `clonal_fish_plot`

- Guide: [source](../../plot_web/registry/guides/clonal_fish_plot.yaml); engine: `clonal_fish_plot`.
- Status: visible in the editor.
- Purpose: Show supplied nested clone fractions across time.
- Input: Long table of clone, parent (0 for virtual root), time and inclusive clone fraction. Child fractions may not exceed their parent; root fractions may not sum above one.
- Scenarios: Summarize nested clone fractions over time; Show expanding and disappearing subclones; Display supplied parent relationships without inferring ancestry
- Reading: Show supplied nested clone fractions across time. Long table of clone, parent (0 for virtual root), time and inclusive clone fraction. Child fractions may not exceed their parent; root fractions may not sum above one.
- Cautions: Parent fractions include descendants. Do not sum nested parents and children as independent populations.; Parent relationships are supplied, not inferred; linear interpolation between time points does not establish clone dynamics.

Published figure examples:

No figure-panel association has been verified yet.

Local runnable demos:

- **Nested clone fractions** · `basic`: Summarize nested clone fractions over time
  [Parameters](../../plugins/clonal_fish_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/clonal_fish_plot/examples/basic/manifest.json) · [Preview](../../plugins/clonal_fish_plot/all_examples_gallery/basic.png)
  Mappings: `group_column="clone"`, `parent_column="parent"`, `x_column="time"`, `value_column="fraction"`
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Clone fractions in percent** · `percent`: Show expanding and disappearing subclones
  [Parameters](../../plugins/clonal_fish_plot/examples/percent/params.json) · [Inputs and reproduction](../../plugins/clonal_fish_plot/examples/percent/manifest.json) · [Preview](../../plugins/clonal_fish_plot/all_examples_gallery/percent.png)
  Mappings: `group_column="clone"`, `parent_column="parent"`, `x_column="time"`, `value_column="fraction"`
  Data provenance: Independent synthetic demonstration, not original publication data.

Customization controls (checked against the schema): `group_column`, `parent_column`, `x_column`, `value_column`, `fraction_unit`, `timepoint_show`, `fill_alpha`, `line_width`, `palette`, `group_colors`, `title`, `subtitle`, `caption`, `title_size`, `legend_show`, `legend_position`, `legend_text_size`, `font_family`, `base_size`, `plot_background`, `grid_show`, `width`, `height`, `dpi`.

- Method reference: [FigureYa: A Standardized Visualization Framework for Enhancing Biomedical Data Interpretation and Research Efficiency](https://github.com/ying-ge/FigureYa) (2025).
  Relevance: Compare the required input shape and intended visualization with the corresponding source module; upstream analyses are not automatically reproduced.

### Cluster Dendrogram Plot · `cluster_dendrogram_plot`

- Guide: [source](../../plot_web/registry/guides/cluster_dendrogram_plot.yaml); engine: `cluster_dendrogram_plot`.
- Status: visible in the editor.
- Purpose: Compare sample-cluster mean-expression profiles using hierarchical clustering.
- Input: Expression matrix and cell annotations with matching IDs, sample labels and clusters.
- Scenarios: Compare corresponding populations across samples; Check annotation consistency; Inspect selected population relationships
- Reading: Branch heights reflect the selected distance and linkage; annotation strips identify groups.
- Cautions: This is not a phylogenetic or developmental tree; Mean profiles hide within-population heterogeneity

Published figure examples:

- **Extended Data Figure 9: Hierarchical cell-type relationships** — Same plot grammar.
  Li YE, Preissl S, Hou X, et al. (2021), *Nature*. [An atlas of gene regulatory elements in adult mouse cerebrum](https://www.nature.com/articles/s41586-021-03604-1).
  Source: [figure/caption](https://www.nature.com/articles/s41586-021-03604-1); DOI `10.1038/s41586-021-03604-1`; checked 2026-10-25.
  Shown in the paper: Chromatin-profile subclass dendrogram.
  Apply it: Use compatible profile data; bootstrap supports in the paper are not calculated by this renderer.
- **Figure 2D: Transcriptomic cluster hierarchy** — Same plot grammar.
  Yang L, Liu F, Hahm H, et al. (2025), *Nature Communications*. [Projection-TAGs enable multiplex projection tracing and multi-modal profiling of projection neurons](https://www.nature.com/articles/s41467-025-60360-w).
  Source: [figure/caption](https://www.nature.com/articles/s41467-025-60360-w#Fig2); DOI `10.1038/s41467-025-60360-w`; checked 2026-10-25.
  Shown in the paper: Hierarchical clustering with class annotations.
  Apply it: Use group-average marker profiles and matched annotations; keep aggregation choices explicit.

Local runnable demos:

- **Sample-population relationships** · `basic`: Use case: Compare corresponding populations across samples. This preset illustrates sample-population relationships. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/cluster_dendrogram_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/cluster_dendrogram_plot/examples/basic/manifest.json) · [Preview](../../plugins/cluster_dendrogram_plot/all_examples_gallery/basic.png)
  Mappings: `sample_column="sample"`, `cluster_column="cluster"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Group-colored labels** · `colored_labels`: Use case: Check annotation consistency. This preset illustrates group-colored labels. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/cluster_dendrogram_plot/examples/colored_labels/params.json) · [Inputs and reproduction](../../plugins/cluster_dendrogram_plot/examples/colored_labels/manifest.json) · [Preview](../../plugins/cluster_dendrogram_plot/all_examples_gallery/colored_labels.png)
  Mappings: `sample_column="sample"`, `cluster_column="cluster"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Clustering selected populations** · `subset`: Use case: Inspect selected population relationships. This preset illustrates clustering selected populations. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/cluster_dendrogram_plot/examples/subset/params.json) · [Inputs and reproduction](../../plugins/cluster_dendrogram_plot/examples/subset/manifest.json) · [Preview](../../plugins/cluster_dendrogram_plot/all_examples_gallery/subset.png)
  Mappings: `sample_column="sample"`, `cluster_column="cluster"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): .

- Method reference: [Cluster analysis and display of genome-wide expression patterns](https://www.cs.princeton.edu/courses/archive/fall03/cs597F/Articles/cluster_analysis_hier_eisen.pdf) (1998).
  Relevance: Background for expression heatmaps and clustering; circular layouts and extra panels are local adaptations.

### Combo Bar + Dot Matrix · `combo_bar_dot_matrix`

- Guide: [source](../../plot_web/registry/guides/combo_bar_dot_matrix.yaml); engine: `combo_bar_dot_matrix`.
- Status: visible in the editor.
- Purpose: Align a metric bar panel above a feature matrix on a shared category axis.
- Input: Categories, metric values and optional errors, plus binary or continuous feature columns.
- Scenarios: Compare benchmark performance and inputs; Align outcomes with assay capabilities; Show scores alongside evidence combinations
- Reading: Bars encode metrics; dot filling or color encodes the corresponding feature state or strength.
- Cautions: Identify error bars as SD, SE or CI; Feature presence does not establish its causal contribution to performance

Published figure examples:

- **Figure 2C: Treatment counts and combinations** — Related layout; adaptation required.
  Liu T, Qiao H, Ren L, et al. (2025), *Communications Biology*. [Deciphering cancer therapy resistance via patient-level single-cell transcriptomics with CellResDB](https://www.nature.com/articles/s42003-025-08457-2).
  Source: [figure/caption](https://www.nature.com/articles/s42003-025-08457-2#Fig2); DOI `10.1038/s42003-025-08457-2`; checked 2026-10-25.
  Shown in the paper: Therapy counts with dataset treatment indicators.
  Apply it: Related composite: derive aligned categories for the local bar-plus-matrix layout; do not relabel intersection bars as performance scores.

Local runnable demos:

- **Metrics and binary evidence** · `basic`: Use case: Compare benchmark performance and inputs. This preset illustrates metrics and binary evidence. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/combo_bar_dot_matrix/examples/basic/params.json) · [Inputs and reproduction](../../plugins/combo_bar_dot_matrix/examples/basic/manifest.json) · [Preview](../../plugins/combo_bar_dot_matrix/all_examples_gallery/basic.png)
  Mappings: `x_column="model"`, `y_column="auprc"`, `se_column="se"`, `group_column="group"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Continuous evidence matrix** · `heatmap_dots`: Use case: Align outcomes with assay capabilities. This preset illustrates continuous evidence matrix. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/combo_bar_dot_matrix/examples/heatmap_dots/params.json) · [Inputs and reproduction](../../plugins/combo_bar_dot_matrix/examples/heatmap_dots/manifest.json) · [Preview](../../plugins/combo_bar_dot_matrix/all_examples_gallery/heatmap_dots.png)
  Mappings: `x_column="model"`, `y_column="auprc"`, `se_column="se"`, `group_column="group"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Metric bars without the matrix** · `bar_only`: Use case: Show scores alongside evidence combinations. This preset illustrates metric bars without the matrix. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/combo_bar_dot_matrix/examples/bar_only/params.json) · [Inputs and reproduction](../../plugins/combo_bar_dot_matrix/examples/bar_only/manifest.json) · [Preview](../../plugins/combo_bar_dot_matrix/all_examples_gallery/bar_only.png)
  Mappings: `x_column="model"`, `y_column="auprc"`, `se_column="se"`, `group_column="group"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `group_column`, `x_column`, `y_column`, `group_colors`, `base_size`, `width`, `height`.


### Combo Bar + Line Plot · `combo_bar_line_plot`

- Guide: [source](../../plot_web/registry/guides/combo_bar_line_plot.yaml); engine: `combo_bar_line_plot`.
- Status: hidden; documentation source only.
- Purpose: Align bars and lines over the same categories, optionally with different units.
- Input: Categories, bar values and line values; supported long-format group mappings.
- Scenarios: Compare counts and proportions; Show output and efficiency together; Inspect sample quantity and quality metrics
- Reading: Read bars and lines against their respective legends and axes.
- Cautions: Dual-axis scaling can create apparent relationships; Connecting categories does not establish time or interpolation

Published figure examples:

No figure-panel association has been verified yet.

Local runnable demos:

- **Counts and a second metric** · `basic`: Use case: Compare counts and proportions. This preset illustrates counts and a second metric. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/combo_bar_line_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/combo_bar_line_plot/examples/basic/manifest.json) · [Preview](../../plugins/combo_bar_line_plot/all_examples_gallery/basic.png)
  Mappings: `sample_column="sample"`, `bar_column="bar_value"`, `line_column="line_value"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Series mapped from long-format data** · `long`: Use case: Show output and efficiency together. This preset illustrates series mapped from long-format data. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/combo_bar_line_plot/examples/long/params.json) · [Inputs and reproduction](../../plugins/combo_bar_line_plot/examples/long/manifest.json) · [Preview](../../plugins/combo_bar_line_plot/all_examples_gallery/long.png)
  Mappings: `sample_column="sample"`, `metric_column="metric"`, `long_value_column="value"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Numeric labels for dual-axis reading** · `labeled`: Use case: Inspect sample quantity and quality metrics. This preset illustrates numeric labels for dual-axis reading. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/combo_bar_line_plot/examples/labeled/params.json) · [Inputs and reproduction](../../plugins/combo_bar_line_plot/examples/labeled/manifest.json) · [Preview](../../plugins/combo_bar_line_plot/all_examples_gallery/labeled.png)
  Mappings: `sample_column="sample"`, `bar_column="bar_value"`, `line_column="line_value"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `input_mode`, `group_column`, `palette`, `width`, `height`.

- No curated literature reference yet.

### Den Plot · `den_plot`

- Guide: [source](../../plot_web/registry/guides/den_plot.yaml); engine: `den_plot`.
- Status: hidden; documentation source only.
- Purpose: Cluster matrix columns and display aligned sample annotations.
- Input: Numeric matrix with row IDs, plus annotations matched to column names.
- Scenarios: Check sample grouping; Inspect batch structure; Compare a selected sample subset
- Reading: Branches represent hierarchical relationships under the configured distance and linkage.
- Cautions: Scaling and distance affect the hierarchy; Branch lengths are not elapsed time or proof of biological classes

Published figure examples:

- **Extended Data Figure 9: Hierarchical cell-type relationships** — Same plot grammar.
  Li YE, Preissl S, Hou X, et al. (2021), *Nature*. [An atlas of gene regulatory elements in adult mouse cerebrum](https://www.nature.com/articles/s41586-021-03604-1).
  Source: [figure/caption](https://www.nature.com/articles/s41586-021-03604-1); DOI `10.1038/s41586-021-03604-1`; checked 2026-10-25.
  Shown in the paper: Chromatin-profile subclass dendrogram.
  Apply it: Use compatible profile data; bootstrap supports in the paper are not calculated by this renderer.
- **Figure 2D: Transcriptomic cluster hierarchy** — Same plot grammar.
  Yang L, Liu F, Hahm H, et al. (2025), *Nature Communications*. [Projection-TAGs enable multiplex projection tracing and multi-modal profiling of projection neurons](https://www.nature.com/articles/s41467-025-60360-w).
  Source: [figure/caption](https://www.nature.com/articles/s41467-025-60360-w#Fig2); DOI `10.1038/s41467-025-60360-w`; checked 2026-10-25.
  Shown in the paper: Hierarchical clustering with class annotations.
  Apply it: Use group-average marker profiles and matched annotations; keep aggregation choices explicit.

Local runnable demos:

- **Matrix-column hierarchy** · `basic`: Use case: Check sample grouping. This preset illustrates matrix-column hierarchy. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/den_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/den_plot/examples/basic/manifest.json) · [Preview](../../plugins/den_plot/all_examples_gallery/basic.png)
  Mappings: `row_id_column="feature"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Annotation-colored labels** · `colored_labels`: Use case: Inspect batch structure. This preset illustrates annotation-colored labels. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/den_plot/examples/colored_labels/params.json) · [Inputs and reproduction](../../plugins/den_plot/examples/colored_labels/manifest.json) · [Preview](../../plugins/den_plot/all_examples_gallery/colored_labels.png)
  Mappings: `row_id_column="feature"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Sample-subset clustering** · `subset`: Use case: Compare a selected sample subset. This preset illustrates sample-subset clustering. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/den_plot/examples/subset/params.json) · [Inputs and reproduction](../../plugins/den_plot/examples/subset/manifest.json) · [Preview](../../plugins/den_plot/all_examples_gallery/subset.png)
  Mappings: `row_id_column="feature"`, `sample_columns=["S01", "S02", "S03", "S04", "S07", "S08", "S09", "S10"]`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `group_colors`, `width`, `height`.

- Method reference: [Cluster analysis and display of genome-wide expression patterns](https://www.cs.princeton.edu/courses/archive/fall03/cs597F/Articles/cluster_analysis_hier_eisen.pdf) (1998).
  Relevance: Background for expression heatmaps and clustering; circular layouts and extra panels are local adaptations.

### Basic / Advanced Dot Plot · `dot_plot`

- Guide: [source](../../plot_web/registry/guides/dot_plot.yaml); engine: `dot_plot`.
- Status: visible in the editor.
- Purpose: Summarize feature expression across groups using both color and point size, optionally with a dendrogram.
- Input: Expression matrix and cell annotations, or feature/group means and detection fractions.
- Scenarios: Screen cell-type markers; Compare expression and detection rates; Inspect groups with similar marker profiles
- Reading: Color and size encode different statistics and require separate legends.
- Cautions: Feature-wise scaling prevents absolute comparisons between genes; Summary dots hide observation-level distributions

Published figure examples:

- **Figure 1D: Marker evidence across populations** — Same plot grammar.
  Hao Q, Zhou T, Yan H, et al. (2026), *Molecular Cancer*. [A pan-cancer single cell landscape reveals heterogeneity and functional diversity of double-negative T cells](https://link.springer.com/article/10.1186/s12943-025-02548-8).
  Source: [figure/caption](https://link.springer.com/article/10.1186/s12943-025-02548-8/figures/1); DOI `10.1186/s12943-025-02548-8`; checked 2026-10-25.
  Shown in the paper: Marker means and detection fractions.
  Apply it: Provide group-level means and fractions or a compatible expression matrix.
- **Figure 2G: Projection-positive fractions** — Related layout; adaptation required.
  Yang L, Liu F, Hahm H, et al. (2025), *Nature Communications*. [Projection-TAGs enable multiplex projection tracing and multi-modal profiling of projection neurons](https://www.nature.com/articles/s41467-025-60360-w).
  Source: [figure/caption](https://www.nature.com/articles/s41467-025-60360-w#Fig2); DOI `10.1038/s41467-025-60360-w`; checked 2026-10-25.
  Shown in the paper: Projection-positive fractions across transcriptional clusters.
  Apply it: Use fractions with explicit denominators. Ratio-circle mode is an alternative encoding rather than the paper's exact dot styling.
- **Figure 1C: Marker evidence alongside a cell hierarchy** — Related layout; adaptation required.
  Jing J, Hu M, Ngodup T, et al. (2025), *Nature Communications*. [Molecular logic for cellular specializations that initiate the auditory parallel processing pathways](https://www.nature.com/articles/s41467-024-55257-z).
  Source: [figure/caption](https://www.nature.com/articles/s41467-024-55257-z#Fig1); DOI `10.1038/s41467-024-55257-z`; checked 2026-10-25.
  Shown in the paper: Marker dots aligned with a cluster dendrogram.
  Apply it: The dot grammar matches. For the hierarchical panel, supply explicit hierarchy labels and any cell counts absent from the source panel.

Local runnable demos:

- **Aggregate an expression matrix** · `aggregate`: Use case: Screen cell-type markers. This preset illustrates aggregate an expression matrix. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/dot_plot/examples/aggregate/params.json) · [Inputs and reproduction](../../plugins/dot_plot/examples/aggregate/manifest.json) · [Preview](../../plugins/dot_plot/all_examples_gallery/aggregate.png)
  Mappings: `row_id_column="gene"`, `cluster_column="cluster"`, `cell_column="cell"`, `x_column="gene"`, `y_column="cluster"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Read a precomputed marker summary** · `basic`: Use case: Compare expression and detection rates. This preset illustrates read a precomputed marker summary. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/dot_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/dot_plot/examples/basic/manifest.json) · [Preview](../../plugins/dot_plot/all_examples_gallery/basic.png)
  Mappings: `x_column="gene"`, `y_column="cluster"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Cluster groups by marker profiles** · `dendro`: Use case: Inspect groups with similar marker profiles. This preset illustrates cluster groups by marker profiles. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/dot_plot/examples/dendro/params.json) · [Inputs and reproduction](../../plugins/dot_plot/examples/dendro/manifest.json) · [Preview](../../plugins/dot_plot/all_examples_gallery/dendro.png)
  Mappings: `x_column="gene"`, `y_column="cluster"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): .


### Venn · `venn`

- Guide: [source](../../plot_web/registry/guides/venn.yaml); engine: `dynamic_venn_diagram`.
- Status: visible in the editor.
- Purpose: Display overlaps among a small number of sets, including sets derived from abundance data.
- Input: Element IDs and set membership, or an abundance table in the supported layout.
- Scenarios: Compare differential-gene lists; Find shared and unique sample members; Inspect overlaps after thresholding
- Reading: Region labels give the counts for the corresponding set intersections.
- Cautions: Region area need not be proportional to the count; Use an intersection matrix when there are many sets

Published figure examples:

- **Figure 1C: Intersect candidate-gene sets** — Same plot grammar.
  Chen H, Liang Q, Geng L, Feng B (2025), *Scientific Reports*. [Transcriptomic exploration of key genes related to mitochondria and ferroptosis in inflammatory bowel disease and experimental validation](https://www.nature.com/articles/s41598-025-27002-z).
  Source: [figure/caption](https://www.nature.com/articles/s41598-025-27002-z#Fig1); DOI `10.1038/s41598-025-27002-z`; checked 2026-10-25.
  Shown in the paper: Overlap of three candidate gene sets.
  Apply it: Provide gene IDs for each set; use an explicit background only for upstream tests.
- **Figure 4B: Shared immune-receptor sequences** — Same plot grammar.
  Li Z, Jia J, Zhang Q, et al. (2025), *Scientific Data*. [A single-cell V(D)J sequencing dataset of peripheral blood cells in multibacillary leprosy](https://www.nature.com/articles/s41597-025-05616-2).
  Source: [figure/caption](https://www.nature.com/articles/s41597-025-05616-2#Fig4); DOI `10.1038/s41597-025-05616-2`; checked 2026-10-25.
  Shown in the paper: CDR3 sharing across individuals.
  Apply it: Build sets from unique sequence IDs and state which individuals define each set.
- **Figure 1B: Shared genetic-screen hits** — Same plot grammar.
  Giuliani V, Miller MA, Liu CY, et al. (2021), *Nature Communications*. [PRMT1-dependent regulation of RNA metabolism and DNA damage response sustains pancreatic ductal adenocarcinoma](https://www.nature.com/articles/s41467-021-24798-y).
  Source: [figure/caption](https://www.nature.com/articles/s41467-021-24798-y#Fig1); DOI `10.1038/s41467-021-24798-y`; checked 2026-10-25.
  Shown in the paper: Individual and shared screen-hit sets.
  Apply it: Provide the screened hit lists with the same filtering rules as the comparison.

Local runnable demos:

- **Sets from abundance data** · `abundance`: Use case: Compare differential-gene lists. This preset illustrates sets from abundance data. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/dynamic_venn_diagram/examples/abundance/params.json) · [Inputs and reproduction](../../plugins/dynamic_venn_diagram/examples/abundance/manifest.json) · [Preview](../../plugins/dynamic_venn_diagram/all_examples_gallery/abundance.png)
  Mappings: `element_id_column="OTU"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Explicit set definitions and overlaps** · `params`: Use case: Find shared and unique sample members. This preset illustrates explicit set definitions and overlaps. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/dynamic_venn_diagram/examples/params/params.json) · [Inputs and reproduction](../../plugins/dynamic_venn_diagram/examples/params/manifest.json) · [Preview](../../plugins/dynamic_venn_diagram/all_examples_gallery/params.png)
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `width`, `height`.


### Empirical CDF · `ecdf_plot`

- Guide: [source](../../plot_web/registry/guides/ecdf_plot.yaml); engine: `ecdf_plot`.
- Status: visible in the editor.
- Purpose: Compare cumulative distributions with optional distribution-free confidence bands.
- Input: One finite numeric value per independent observation and optional group. Two-sample tests require exactly two groups; pairing is not inferred.
- Scenarios: Compare continuous score distributions; Show cumulative fold-change patterns; Display empirical distributions with simultaneous DKW bands
- Reading: Compare cumulative distributions with optional distribution-free confidence bands. One finite numeric value per independent observation and optional group. Two-sample tests require exactly two groups; pairing is not inferred.
- Cautions: DKW bands assume independent observations and are simultaneous within each group, without adjustment across groups.; Wilcoxon and KS answer different questions. Neither is a paired or repeated-measure test here.

Published figure examples:

No figure-panel association has been verified yet.

Local runnable demos:

- **Cumulative score distributions** · `basic`: Compare continuous score distributions
  [Parameters](../../plugins/ecdf_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/ecdf_plot/examples/basic/manifest.json) · [Preview](../../plugins/ecdf_plot/all_examples_gallery/basic.png)
  Mappings: `value_column="value"`, `group_column="group"`
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Empirical distribution steps** · `steps`: Show cumulative fold-change patterns
  [Parameters](../../plugins/ecdf_plot/examples/steps/params.json) · [Inputs and reproduction](../../plugins/ecdf_plot/examples/steps/manifest.json) · [Preview](../../plugins/ecdf_plot/all_examples_gallery/steps.png)
  Mappings: `value_column="value"`, `group_column="group"`
  Data provenance: Independent synthetic demonstration, not original publication data.

Customization controls (checked against the schema): `value_column`, `group_column`, `confidence_show`, `confidence_alpha`, `line_width`, `confidence_level`, `stat_method`, `palette`, `group_colors`, `title`, `subtitle`, `caption`, `title_size`, `legend_show`, `legend_position`, `legend_text_size`, `font_family`, `base_size`, `plot_background`, `grid_show`, `width`, `height`, `dpi`.

- Method reference: [FigureYa: A Standardized Visualization Framework for Enhancing Biomedical Data Interpretation and Research Efficiency](https://github.com/ying-ge/FigureYa) (2025).
  Relevance: Compare the required input shape and intended visualization with the corresponding source module; upstream analyses are not automatically reproduced.

### Embedding Vector Field · `embedding_vector_plot`

- Guide: [source](../../plot_web/registry/guides/embedding_vector_plot.yaml); engine: `embedding_vector_plot`.
- Status: visible in the editor.
- Purpose: Overlay supplied displacement vectors on an embedding without inferring velocities.
- Input: Finite numeric x/y coordinates, supplied vx/vy vectors in compatible coordinate units, and optional group.
- Scenarios: Visualize supplied displacement vectors; Inspect directions on an existing embedding; Compare a vector field without running velocity inference
- Reading: Overlay supplied displacement vectors on an embedding without inferring velocities. Finite numeric x/y coordinates, supplied vx/vy vectors in compatible coordinate units, and optional group.
- Cautions: The plugin does not compute RNA velocity or a kinetic model. Supply vector coordinates compatible with the embedding.; Arrow thinning uses a deterministic row stride and does not estimate a spatial average or streamline.

Published figure examples:

No figure-panel association has been verified yet.

Local runnable demos:

- **Supplied vector field** · `basic`: Visualize supplied displacement vectors
  [Parameters](../../plugins/embedding_vector_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/embedding_vector_plot/examples/basic/manifest.json) · [Preview](../../plugins/embedding_vector_plot/all_examples_gallery/basic.png)
  Mappings: `x_column="x"`, `y_column="y"`, `vx_column="vx"`, `vy_column="vy"`, `group_column="group"`
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Supplied outward displacement field** · `radial`: Inspect directions on an existing embedding
  [Parameters](../../plugins/embedding_vector_plot/examples/radial/params.json) · [Inputs and reproduction](../../plugins/embedding_vector_plot/examples/radial/manifest.json) · [Preview](../../plugins/embedding_vector_plot/all_examples_gallery/radial.png)
  Mappings: `x_column="x"`, `y_column="y"`, `vx_column="vx"`, `vy_column="vy"`, `group_column="group"`
  Data provenance: Independent synthetic demonstration, not original publication data.

Customization controls (checked against the schema): `x_column`, `y_column`, `vx_column`, `vy_column`, `group_column`, `vector_scale`, `arrow_stride`, `arrow_alpha`, `arrow_length`, `point_alpha`, `point_size`, `line_width`, `palette`, `group_colors`, `title`, `subtitle`, `caption`, `title_size`, `legend_show`, `legend_position`, `legend_text_size`, `font_family`, `base_size`, `plot_background`, `grid_show`, `width`, `height`, `dpi`.

- Method reference: [FigureYa: A Standardized Visualization Framework for Enhancing Biomedical Data Interpretation and Research Efficiency](https://github.com/ying-ge/FigureYa) (2025).
  Relevance: Compare the required input shape and intended visualization with the corresponding source module; upstream analyses are not automatically reproduced.

### Basic / Advanced Bar Plot · `exp_stat_plot`

- Guide: [source](../../plot_web/registry/guides/exp_stat_plot.yaml); engine: `exp_stat_plot`.
- Status: visible in the editor.
- Purpose: Compare feature-expression summaries or distributions using bars, boxes, violins and related views.
- Input: Observation metadata and an expression matrix with aligned IDs.
- Scenarios: Compare within-group expression distributions; Split expression by condition; Emphasize a target feature or population
- Reading: Interpret the active geometry as a mean, quantiles or a distribution rather than reusing one reading for every mode.
- Cautions: Cells are not independent biological replicates; State the error definition and statistical test explicitly

Published figure examples:

- **Figure 6B: Immune-infiltration distributions** — Same plot grammar.
  Chen H, Liang Q, Geng L, Feng B (2025), *Scientific Reports*. [Transcriptomic exploration of key genes related to mitochondria and ferroptosis in inflammatory bowel disease and experimental validation](https://www.nature.com/articles/s41598-025-27002-z).
  Source: [figure/caption](https://www.nature.com/articles/s41598-025-27002-z#Fig6); DOI `10.1038/s41598-025-27002-z`; checked 2026-10-25.
  Shown in the paper: Groupwise infiltration-score violins.
  Apply it: Use sample-level scores and group labels; statistical testing remains a separate analysis.
- **Figure 2A-B: Compare fertilizer emission metrics** — Same plot grammar.
  Sanchez-Mendez S, Orden L, Franco-Luesma S, et al. (2025), *Scientific Reports*. [Agronomic and environmental assessment of a new fertilization strategy using pelleted organo-mineral fertilizers for wheat production in mediterranean agricultural soils](https://www.nature.com/articles/s41598-025-20818-9).
  Source: [figure/caption](https://www.nature.com/articles/s41598-025-20818-9#Fig2); DOI `10.1038/s41598-025-20818-9`; checked 2026-10-25.
  Shown in the paper: Treatment bars with standard errors.
  Apply it: Prepare treatment-level means and errors; preserve units and do not infer significance from bar overlap.

Local runnable demos:

- **Expression summary bars** · `bar`: Use case: Compare within-group expression distributions. This preset illustrates expression summary bars. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/exp_stat_plot/examples/bar/params.json) · [Inputs and reproduction](../../plugins/exp_stat_plot/examples/bar/manifest.json) · [Preview](../../plugins/exp_stat_plot/all_examples_gallery/bar.png)
  Mappings: `id_column="cell"`, `group_column="cluster"`, `split_column="condition"`, `stat_columns=["percent_top50"]`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Condition-split expression distributions** · `box_split`: Use case: Split expression by condition. This preset illustrates condition-split expression distributions. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/exp_stat_plot/examples/box_split/params.json) · [Inputs and reproduction](../../plugins/exp_stat_plot/examples/box_split/manifest.json) · [Preview](../../plugins/exp_stat_plot/all_examples_gallery/box_split.png)
  Mappings: `id_column="cell"`, `group_column="condition"`, `split_column="cluster"`, `stat_columns=["module_score", "mito_percent"]`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Expression-distribution shapes** · `violin`: Use case: Emphasize a target feature or population. This preset illustrates expression-distribution shapes. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/exp_stat_plot/examples/violin/params.json) · [Inputs and reproduction](../../plugins/exp_stat_plot/examples/violin/manifest.json) · [Preview](../../plugins/exp_stat_plot/all_examples_gallery/violin.png)
  Mappings: `id_column="cell"`, `group_column="cluster"`, `split_column="condition"`, `stat_columns=["CD3D", "MS4A1"]`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): .


### Feature Density Plot · `feature_density_plot`

- Guide: [source](../../plot_web/registry/guides/feature_density_plot.yaml); engine: `feature_density_plot`.
- Status: hidden; documentation source only.
- Purpose: Show expression-weighted feature density on existing embedding coordinates.
- Input: Expression values, observation IDs and their matching embedding coordinates.
- Scenarios: Locate marker-enriched regions; Reduce point overplotting; Compare multifeature enrichment patterns
- Reading: Color represents a density estimate or its rescaling, not an individual observation's raw expression.
- Cautions: Bandwidth changes the apparent hotspots; Density depends on sampling and the embedding layout

Published figure examples:

No figure-panel association has been verified yet.

Local runnable demos:

- **Single-feature density hotspots** · `basic`: Use case: Locate marker-enriched regions. This preset illustrates single-feature density hotspots. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/feature_density_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/feature_density_plot/examples/basic/manifest.json) · [Preview](../../plugins/feature_density_plot/all_examples_gallery/basic.png)
  Mappings: `dim1_column="UMAP_1"`, `dim2_column="UMAP_2"`, `cell_id_column="cell"`, `feature_id_column="feature"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Multifeature density colocalization** · `coexpression`: Use case: Reduce point overplotting. This preset illustrates multifeature density colocalization. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/feature_density_plot/examples/coexpression/params.json) · [Inputs and reproduction](../../plugins/feature_density_plot/examples/coexpression/manifest.json) · [Preview](../../plugins/feature_density_plot/all_examples_gallery/coexpression.png)
  Mappings: `dim1_column="UMAP_1"`, `dim2_column="UMAP_2"`, `cell_id_column="cell"`, `feature_id_column="feature"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Relative intensity on a common range** · `scale01`: Use case: Compare multifeature enrichment patterns. This preset illustrates relative intensity on a common range. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/feature_density_plot/examples/scale01/params.json) · [Inputs and reproduction](../../plugins/feature_density_plot/examples/scale01/manifest.json) · [Preview](../../plugins/feature_density_plot/all_examples_gallery/scale01.png)
  Mappings: `dim1_column="UMAP_1"`, `dim2_column="UMAP_2"`, `cell_id_column="cell"`, `feature_id_column="feature"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): .

- No curated literature reference yet.

### GSEA / enrichment running plots · `gsea`

- Guide: [source](../../plot_web/registry/guides/gsea.yaml); engine: `fgsea_enrichment_plot`.
- Status: visible in the editor.
- Purpose: Show gene-set enrichment along a ranked gene list, with hit positions and pathway summaries.
- Input: Gene IDs and signed ranking scores, plus GMT or term-gene sets.
- Scenarios: Inspect enrichment direction; Compare gene-set hit distributions; Summarize pathway effects and evidence
- Reading: The running curve tracks cumulative enrichment along the supplied ranking.
- Cautions: Use consistent gene identifiers and gene-set versions; ES, NES and adjusted probabilities are different quantities

Published figure examples:

- **Figure 4A-H: Gene-associated pathway enrichment** — Same plot grammar.
  Chen H, Liang Q, Geng L, Feng B (2025), *Scientific Reports*. [Transcriptomic exploration of key genes related to mitochondria and ferroptosis in inflammatory bowel disease and experimental validation](https://www.nature.com/articles/s41598-025-27002-z).
  Source: [figure/caption](https://www.nature.com/articles/s41598-025-27002-z#Fig4); DOI `10.1038/s41598-025-27002-z`; checked 2026-10-25.
  Shown in the paper: Running enrichment curves with gene-set hits.
  Apply it: Provide a signed gene ranking and matched gene sets; keep raw and adjusted probabilities distinct.

Local runnable demos:

- **Single-pathway running enrichment** · `running`: Use case: Inspect enrichment direction. This preset illustrates single-pathway running enrichment. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/fgsea_enrichment_plot/examples/running/params.json) · [Inputs and reproduction](../../plugins/fgsea_enrichment_plot/examples/running/manifest.json) · [Preview](../../plugins/fgsea_enrichment_plot/all_examples_gallery/running.png)
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Multiple-pathway hit comparison** · `multiterm`: Use case: Compare gene-set hit distributions. This preset illustrates multiple-pathway hit comparison. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/fgsea_enrichment_plot/examples/multiterm/params.json) · [Inputs and reproduction](../../plugins/fgsea_enrichment_plot/examples/multiterm/manifest.json) · [Preview](../../plugins/fgsea_enrichment_plot/all_examples_gallery/multiterm.png)
  Mappings: `stats_columns=["NES", "pvalue", "padj"]`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Pathway statistic summary** · `dot_summary`: Use case: Summarize pathway effects and evidence. This preset illustrates pathway statistic summary. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/fgsea_enrichment_plot/examples/dot_summary/params.json) · [Inputs and reproduction](../../plugins/fgsea_enrichment_plot/examples/dot_summary/manifest.json) · [Preview](../../plugins/fgsea_enrichment_plot/all_examples_gallery/dot_summary.png)
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): .

- Method reference: [Gene set enrichment analysis: A knowledge-based approach for interpreting genome-wide expression profiles](https://software.broadinstitute.org/gsea/doc/subramanian_tamayo_gsea_pnas.pdf) (2005).
  Relevance: Background for running enrichment curves, hit positions and enrichment statistics; local demos use independent data.

### Forest Plot · `forest_plot`

- Guide: [source](../../plot_web/registry/guides/forest_plot.yaml); engine: `forest_plot`.
- Status: visible in the editor.
- Purpose: Compare supplied effect estimates and confidence intervals.
- Input: One row per effect: unique label, estimate, lower/upper interval bounds and optional group. Log axes require positive estimates/bounds and a positive null value.
- Scenarios: Compare effect estimates across cohorts; Summarize subgroup confidence intervals; Display supplied ratio estimates on a logarithmic axis
- Reading: Compare supplied effect estimates and confidence intervals. One row per effect: unique label, estimate, lower/upper interval bounds and optional group. Log axes require positive estimates/bounds and a positive null value.
- Cautions: Confidence intervals and effect units are supplied, not estimated. Ratio estimates and signed differences use different reference values.; A forest display does not fit a random-effects meta-analysis or establish subgroup interactions.

Published figure examples:

No figure-panel association has been verified yet.

Local runnable demos:

- **Effect estimates and confidence intervals** · `basic`: Compare effect estimates across cohorts
  [Parameters](../../plugins/forest_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/forest_plot/examples/basic/manifest.json) · [Preview](../../plugins/forest_plot/all_examples_gallery/basic.png)
  Mappings: `label_column="label"`, `effect_column="effect"`, `lower_column="lower"`, `upper_column="upper"`, `group_column="group"`
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Ratios on a logarithmic axis** · `log_ratio`: Summarize subgroup confidence intervals
  [Parameters](../../plugins/forest_plot/examples/log_ratio/params.json) · [Inputs and reproduction](../../plugins/forest_plot/examples/log_ratio/manifest.json) · [Preview](../../plugins/forest_plot/all_examples_gallery/log_ratio.png)
  Mappings: `label_column="label"`, `effect_column="effect"`, `lower_column="lower"`, `upper_column="upper"`, `group_column="group"`
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Signed differences** · `signed_effects`: Display supplied ratio estimates on a logarithmic axis
  [Parameters](../../plugins/forest_plot/examples/signed_effects/params.json) · [Inputs and reproduction](../../plugins/forest_plot/examples/signed_effects/manifest.json) · [Preview](../../plugins/forest_plot/all_examples_gallery/signed_effects.png)
  Mappings: `label_column="label"`, `effect_column="effect"`, `lower_column="lower"`, `upper_column="upper"`, `group_column="group"`
  Data provenance: Independent synthetic demonstration, not original publication data.

Customization controls (checked against the schema): `label_column`, `effect_column`, `lower_column`, `upper_column`, `group_column`, `x_scale`, `null_value`, `estimate_show`, `label_size`, `title`, `subtitle`, `caption`, `title_size`, `point_size`, `line_width`, `palette`, `group_colors`, `legend_show`, `legend_position`, `legend_text_size`, `font_family`, `base_size`, `plot_background`, `grid_show`, `width`, `height`, `dpi`.

- Method reference: [FigureYa: A Standardized Visualization Framework for Enhancing Biomedical Data Interpretation and Research Efficiency](https://github.com/ying-ge/FigureYa) (2025).
  Relevance: Compare the required input shape and intended visualization with the corresponding source module; upstream analyses are not automatically reproduced.

### GO / KEGG Enrichment · `go_kegg_enrichment_bar_bubble`

- Guide: [source](../../plot_web/registry/guides/go_kegg_enrichment_bar_bubble.yaml); engine: `go_kegg_enrichment_bar_bubble`.
- Status: visible in the editor.
- Purpose: Combine ontology-grouped bars and bubbles to show enrichment evidence and gene counts.
- Input: Precomputed term names, ontology classes, enrichment statistics and gene counts.
- Scenarios: Summarize functional ontologies; Compare gene coverage of enriched terms; Show top terms within each ontology
- Reading: Read bar length, point size and color against their separate legends.
- Cautions: State the background gene universe and correction method; Top-N selection is a display filter rather than a statistical test

Published figure examples:

- **Figure 2G: Ranked biological-process enrichment** — Related layout; adaptation required.
  Hao Q, Zhou T, Yan H, et al. (2026), *Molecular Cancer*. [A pan-cancer single cell landscape reveals heterogeneity and functional diversity of double-negative T cells](https://link.springer.com/article/10.1186/s12943-025-02548-8).
  Source: [figure/caption](https://link.springer.com/article/10.1186/s12943-025-02548-8/figures/2); DOI `10.1186/s12943-025-02548-8`; checked 2026-10-25.
  Shown in the paper: Bars summarize pathway enrichment evidence.
  Apply it: The source supplies enrichment bars; counts and extra bubble encodings require separate data and are not inferred.

Local runnable demos:

- **Ontology enrichment and gene counts** · `go_kegg`: Use case: Summarize functional ontologies. This preset illustrates ontology enrichment and gene counts. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/go_kegg_enrichment_bar_bubble/examples/go_kegg/params.json) · [Inputs and reproduction](../../plugins/go_kegg_enrichment_bar_bubble/examples/go_kegg/manifest.json) · [Preview](../../plugins/go_kegg_enrichment_bar_bubble/all_examples_gallery/go_kegg.png)
  Mappings: `term_column="Description"`, `category_column="Ontology"`, `pvalue_column="pvalue"`, `adjusted_pvalue_column="p.adjust"`, `count_column="GeneCount"`, `significance_column="pvalue"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `category_column`, `top_n`, `width`, `height`.


### Group heatmap · `grouped_heatmap`

- Guide: [source](../../plot_web/registry/guides/grouped_heatmap.yaml); engine: `group_heatmap`.
- Status: visible in the editor.
- Purpose: Show multifeature expression patterns as group summaries, cell-level heatmaps or dot plots.
- Input: Wide data with group metadata and numeric feature columns.
- Scenarios: Compare population marker profiles; Inspect within-group heterogeneity; Compare expression modules across conditions
- Reading: Heatmap color encodes transformed values; dot views can additionally encode detection fractions.
- Cautions: Row scaling shows relative patterns rather than absolute expression; Group averages depend on sample composition

Published figure examples:

- **Figure 2E: Functional-activity heatmap** — Same plot grammar.
  Hao Q, Zhou T, Yan H, et al. (2026), *Molecular Cancer*. [A pan-cancer single cell landscape reveals heterogeneity and functional diversity of double-negative T cells](https://link.springer.com/article/10.1186/s12943-025-02548-8).
  Source: [figure/caption](https://link.springer.com/article/10.1186/s12943-025-02548-8/figures/2); DOI `10.1186/s12943-025-02548-8`; checked 2026-10-25.
  Shown in the paper: Cytokine activities across DNT subsets.
  Apply it: Use a precomputed population-by-activity matrix; activity inference is upstream.
- **Figure 2E: Cluster marker-expression heatmap** — Same plot grammar.
  Yang L, Liu F, Hahm H, et al. (2025), *Nature Communications*. [Projection-TAGs enable multiplex projection tracing and multi-modal profiling of projection neurons](https://www.nature.com/articles/s41467-025-60360-w).
  Source: [figure/caption](https://www.nature.com/articles/s41467-025-60360-w#Fig2); DOI `10.1038/s41467-025-60360-w`; checked 2026-10-25.
  Shown in the paper: Mean marker expression across clusters.
  Apply it: Map an appropriate expression summary and state whether values are scaled.

Local runnable demos:

- **Group-mean expression modules** · `heatmap`: Use case: Compare population marker profiles. This preset illustrates group-mean expression modules. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/group_heatmap/examples/heatmap/params.json) · [Inputs and reproduction](../../plugins/group_heatmap/examples/heatmap/manifest.json) · [Preview](../../plugins/group_heatmap/all_examples_gallery/heatmap.png)
  Mappings: `id_column="cell"`, `group_column="cluster"`, `cluster_columns=false`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Observation-level expression heterogeneity** · `cell_heatmap`: Use case: Inspect within-group heterogeneity. This preset illustrates observation-level expression heterogeneity. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/group_heatmap/examples/cell_heatmap/params.json) · [Inputs and reproduction](../../plugins/group_heatmap/examples/cell_heatmap/manifest.json) · [Preview](../../plugins/group_heatmap/all_examples_gallery/cell_heatmap.png)
  Mappings: `id_column="cell"`, `group_column="cluster"`, `cluster_columns=false`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Expression and detection fractions** · `dotplot`: Use case: Compare expression modules across conditions. This preset illustrates expression and detection fractions. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/group_heatmap/examples/dotplot/params.json) · [Inputs and reproduction](../../plugins/group_heatmap/examples/dotplot/manifest.json) · [Preview](../../plugins/group_heatmap/all_examples_gallery/dotplot.png)
  Mappings: `id_column="cell"`, `group_column="cluster"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): .

- Method reference: [Cluster analysis and display of genome-wide expression patterns](https://www.cs.princeton.edu/courses/archive/fall03/cs597F/Articles/cluster_analysis_hier_eisen.pdf) (1998).
  Relevance: Background for expression heatmaps and clustering; circular layouts and extra panels are local adaptations.

### GSEA Pathway Heatmap · `gsea_heatmap`

- Guide: [source](../../plot_web/registry/guides/gsea_heatmap.yaml); engine: `gsea_pathway_heatmap`.
- Status: hidden; documentation source only.
- Purpose: Align running enrichment curves and gene-set hits with pathway-gene expression heatmaps.
- Input: Ranked genes, gene sets and a gene-by-sample expression matrix; optional precomputed enrichment.
- Scenarios: Connect enrichment to expression evidence; Compare pathway member genes; Interpret expression using sample annotations
- Reading: The enrichment curve comes from the ranking and the heatmap from the expression matrix; their scales differ.
- Cautions: Shared genes can occur in several pathways; Precomputed statistics must match the supplied contrast and ranking

Published figure examples:

No figure-panel association has been verified yet.

Local runnable demos:

- **Enrichment linked to expression** · `basic`: Use case: Connect enrichment to expression evidence. This preset illustrates enrichment linked to expression. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/gsea_pathway_heatmap/examples/basic/params.json) · [Inputs and reproduction](../../plugins/gsea_pathway_heatmap/examples/basic/manifest.json) · [Preview](../../plugins/gsea_pathway_heatmap/all_examples_gallery/basic.png)
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Precomputed enrichment results** · `precomputed`: Use case: Compare pathway member genes. This preset illustrates precomputed enrichment results. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/gsea_pathway_heatmap/examples/precomputed/params.json) · [Inputs and reproduction](../../plugins/gsea_pathway_heatmap/examples/precomputed/manifest.json) · [Preview](../../plugins/gsea_pathway_heatmap/all_examples_gallery/precomputed.png)
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Heatmaps with sample annotations** · `with_annotation`: Use case: Interpret expression using sample annotations. This preset illustrates heatmaps with sample annotations. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/gsea_pathway_heatmap/examples/with_annotation/params.json) · [Inputs and reproduction](../../plugins/gsea_pathway_heatmap/examples/with_annotation/manifest.json) · [Preview](../../plugins/gsea_pathway_heatmap/all_examples_gallery/with_annotation.png)
  Mappings: `heatmap_column_annotation_columns=["Day"]`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): .

- Method reference: [Gene set enrichment analysis: A knowledge-based approach for interpreting genome-wide expression profiles](https://software.broadinstitute.org/gsea/doc/subramanian_tamayo_gsea_pnas.pdf) (2005).
  Relevance: Background for running enrichment curves, hit positions and enrichment statistics; local demos use independent data.

### GSEA Pathway Ridge + NES · `gsea_ridge_nes_plot`

- Guide: [source](../../plot_web/registry/guides/gsea_ridge_nes_plot.yaml); engine: `gsea_ridge_nes_plot`.
- Status: hidden; documentation source only.
- Purpose: Place pathway-member ranking distributions beside precomputed normalized enrichment scores.
- Input: Ranked genes and enrichment results with NES and probabilities; optional gene sets or leading-edge members.
- Scenarios: Compare pathway score distributions; Check agreement with NES direction; Inspect leading-edge support
- Reading: Ridges summarize member-score distributions while NES is the supplied enrichment statistic.
- Cautions: A density peak is not NES; Leading-edge-only distributions do not describe the full gene set

Published figure examples:

No figure-panel association has been verified yet.

Local runnable demos:

- **Pathway distributions alongside NES** · `basic`: Use case: Compare pathway score distributions. This preset illustrates pathway distributions alongside nes. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/gsea_ridge_nes_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/gsea_ridge_nes_plot/examples/basic/manifest.json) · [Preview](../../plugins/gsea_ridge_nes_plot/all_examples_gallery/basic.png)
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `base_size`, `width`, `height`.

- Method reference: [Gene set enrichment analysis: A knowledge-based approach for interpreting genome-wide expression profiles](https://software.broadinstitute.org/gsea/doc/subramanian_tamayo_gsea_pnas.pdf) (2005).
  Relevance: Background for running enrichment curves, hit positions and enrichment statistics; local demos use independent data.

### Hierarchical Marker Panel · `hierarchical_marker_panel`

- Guide: [source](../../plot_web/registry/guides/hierarchical_marker_panel.yaml); engine: `hierarchical_marker_panel`.
- Status: visible in the editor.
- Purpose: Align cell-type hierarchy labels, abundance and marker expression in one panel.
- Input: One row per cell-type/marker pair with hierarchy labels, counts, mean expression and detection fractions.
- Scenarios: Explain cell-annotation hierarchies; Check marker evidence alongside abundance; Compare population composition across samples
- Reading: Hierarchy labels describe annotations; color and point size follow their respective marker legends.
- Cautions: Do not sum duplicated cell counts across marker rows; Use consistent denominators for sample fractions and total counts

Published figure examples:

- **Figure 2B: Markers alongside population frequency** — Related layout; adaptation required.
  Hao Q, Zhou T, Yan H, et al. (2026), *Molecular Cancer*. [A pan-cancer single cell landscape reveals heterogeneity and functional diversity of double-negative T cells](https://link.springer.com/article/10.1186/s12943-025-02548-8).
  Source: [figure/caption](https://link.springer.com/article/10.1186/s12943-025-02548-8/figures/2); DOI `10.1186/s12943-025-02548-8`; checked 2026-10-25.
  Shown in the paper: Marker heatmap with frequency bars.
  Apply it: Related composite: the local panel adds explicit hierarchy labels and uses its own marker encodings.
- **Figure 1D: Cell hierarchy and abundance** — Related layout; adaptation required.
  Li YE, Preissl S, Hou X, et al. (2021), *Nature*. [An atlas of gene regulatory elements in adult mouse cerebrum](https://www.nature.com/articles/s41586-021-03604-1).
  Source: [figure/caption](https://www.nature.com/articles/s41586-021-03604-1#Fig1); DOI `10.1038/s41586-021-03604-1`; checked 2026-10-25.
  Shown in the paper: Class hierarchy with subclass counts.
  Apply it: Related composite: marker columns must be supplied separately; this is not an exact reconstruction of the original panel.
- **Figure 1C: Marker evidence alongside a cell hierarchy** — Related layout; adaptation required.
  Jing J, Hu M, Ngodup T, et al. (2025), *Nature Communications*. [Molecular logic for cellular specializations that initiate the auditory parallel processing pathways](https://www.nature.com/articles/s41467-024-55257-z).
  Source: [figure/caption](https://www.nature.com/articles/s41467-024-55257-z#Fig1); DOI `10.1038/s41467-024-55257-z`; checked 2026-10-25.
  Shown in the paper: Marker dots aligned with a cluster dendrogram.
  Apply it: The dot grammar matches. For the hierarchical panel, supply explicit hierarchy labels and any cell counts absent from the source panel.

Local runnable demos:

- **Hierarchy and marker evidence** · `basic`: Use case: Explain cell-annotation hierarchies. This preset illustrates hierarchy and marker evidence. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/hierarchical_marker_panel/examples/basic/params.json) · [Inputs and reproduction](../../plugins/hierarchical_marker_panel/examples/basic/manifest.json) · [Preview](../../plugins/hierarchical_marker_panel/all_examples_gallery/basic.png)
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Sample composition fractions** · `sample_percent`: Use case: Check marker evidence alongside abundance. This preset illustrates sample composition fractions. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/hierarchical_marker_panel/examples/sample_percent/params.json) · [Inputs and reproduction](../../plugins/hierarchical_marker_panel/examples/sample_percent/manifest.json) · [Preview](../../plugins/hierarchical_marker_panel/all_examples_gallery/sample_percent.png)
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Marker panel with count summaries** · `summary_bar`: Use case: Compare population composition across samples. This preset illustrates marker panel with count summaries. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/hierarchical_marker_panel/examples/summary_bar/params.json) · [Inputs and reproduction](../../plugins/hierarchical_marker_panel/examples/summary_bar/manifest.json) · [Preview](../../plugins/hierarchical_marker_panel/all_examples_gallery/summary_bar.png)
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `base_size`, `width`, `height`.


### Highlight Effect (Focus + Other Cloud) · `highlight_effect_plot`

- Guide: [source](../../plot_web/registry/guides/highlight_effect_plot.yaml); engine: `highlight_effect_plot`.
- Status: visible in the editor.
- Purpose: Emphasize selected effects and intervals while retaining other items as a background cloud.
- Input: Item IDs, effect values, optional intervals and a highlight rule.
- Scenarios: Compare target tissues with background; Emphasize candidate effects; Check distributions before collapsing background
- Reading: Highlighted items retain separate rows; each background point still represents an individual item.
- Cautions: Collapsing background rows is not statistical aggregation; Intervals and significance must come from an appropriate upstream model

Published figure examples:

- **Figure 1L: Effects and uncertainty across cohorts** — Related layout; adaptation required.
  Hao Q, Zhou T, Yan H, et al. (2026), *Molecular Cancer*. [A pan-cancer single cell landscape reveals heterogeneity and functional diversity of double-negative T cells](https://link.springer.com/article/10.1186/s12943-025-02548-8).
  Source: [figure/caption](https://link.springer.com/article/10.1186/s12943-025-02548-8); DOI `10.1186/s12943-025-02548-8`; checked 2026-10-25.
  Shown in the paper: Adjusted survival effects with confidence intervals.
  Apply it: Related layout: transform hazard ratios and interval limits to log scale for a zero-centered effect plot. Background-cloud collapsing is a local option absent from the source.

Local runnable demos:

- **Candidates against the background cloud** · `basic`: Use case: Compare target tissues with background. This preset illustrates candidates against the background cloud. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/highlight_effect_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/highlight_effect_plot/examples/basic/manifest.json) · [Preview](../../plugins/highlight_effect_plot/all_examples_gallery/basic.png)
  Mappings: `category_column="category"`, `value_column="value"`, `pvalue_column="pvalue"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Retain all item rows** · `no_collapse`: Use case: Emphasize candidate effects. This preset illustrates retain all item rows. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/highlight_effect_plot/examples/no_collapse/params.json) · [Inputs and reproduction](../../plugins/highlight_effect_plot/examples/no_collapse/manifest.json) · [Preview](../../plugins/highlight_effect_plot/all_examples_gallery/no_collapse.png)
  Mappings: `category_column="category"`, `value_column="value"`, `pvalue_column="pvalue"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Configured summary view** · `summary`: Use case: Check distributions before collapsing background. This preset illustrates configured summary view. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/highlight_effect_plot/examples/summary/params.json) · [Inputs and reproduction](../../plugins/highlight_effect_plot/examples/summary/manifest.json) · [Preview](../../plugins/highlight_effect_plot/all_examples_gallery/summary.png)
  Mappings: `category_column="category"`, `mean_column="mean"`, `ci_low_column="ci_low"`, `ci_high_column="ci_high"`, `pvalue_column="pvalue"`, `highlight_column="highlight"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `input_mode`, `value_column`, `category_column`, `base_size`, `width`, `height`.


### 3D Embedding · `interactive_3d_scatter`

- Guide: [source](../../plot_web/registry/guides/interactive_3d_scatter.yaml); engine: `interactive_3d_scatter`.
- Status: visible in the editor.
- Purpose: View supplied three-dimensional coordinates with an interactive scene and vector projection.
- Input: Three finite numeric coordinate columns and optional categorical group; up to 50,000 observations. Coordinates are consumed as supplied, without fitting PCA.
- Scenarios: Inspect supplied three-dimensional coordinates; Rotate a grouped sample embedding; Export a fixed vector projection of the same coordinates
- Reading: View supplied three-dimensional coordinates with an interactive scene and vector projection. Three finite numeric coordinate columns and optional categorical group; up to 50,000 observations. Coordinates are consumed as supplied, without fitting PCA.
- Cautions: A projection can conceal overlap; rotate the HTML view and compare complementary quantitative analyses.; The static export uses an orthographic projection; PCA/t-SNE/UMAP fitting is performed upstream.

Published figure examples:

No figure-panel association has been verified yet.

Local runnable demos:

- **Three-dimensional sample coordinates** · `basic`: Inspect supplied three-dimensional coordinates
  [Parameters](../../plugins/interactive_3d_scatter/examples/basic/params.json) · [Inputs and reproduction](../../plugins/interactive_3d_scatter/examples/basic/manifest.json) · [Preview](../../plugins/interactive_3d_scatter/all_examples_gallery/basic.png)
  Mappings: `x_column="PC1"`, `y_column="PC2"`, `z_column="PC3"`, `group_column="group"`
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Alternate viewing angle** · `alternate_view`: Rotate a grouped sample embedding
  [Parameters](../../plugins/interactive_3d_scatter/examples/alternate_view/params.json) · [Inputs and reproduction](../../plugins/interactive_3d_scatter/examples/alternate_view/manifest.json) · [Preview](../../plugins/interactive_3d_scatter/all_examples_gallery/alternate_view.png)
  Mappings: `x_column="PC1"`, `y_column="PC2"`, `z_column="PC3"`, `group_column="group"`
  Data provenance: Independent synthetic demonstration, not original publication data.

Customization controls (checked against the schema): `x_column`, `y_column`, `z_column`, `group_column`, `azimuth`, `elevation`, `point_alpha`, `point_size`, `line_width`, `label_size`, `title`, `subtitle`, `caption`, `title_size`, `palette`, `group_colors`, `legend_show`, `legend_position`, `legend_text_size`, `font_family`, `base_size`, `plot_background`, `width`, `height`, `dpi`.

- Method reference: [FigureYa: A Standardized Visualization Framework for Enhancing Biomedical Data Interpretation and Research Efficiency](https://github.com/ying-ge/FigureYa) (2025).
  Relevance: Compare the required input shape and intended visualization with the corresponding source module; upstream analyses are not automatically reproduced.

### Interactive Arc Network Plot · `interactive_arc_network_plot`

- Guide: [source](../../plot_web/registry/guides/interactive_arc_network_plot.yaml); engine: `interactive_arc_network_plot`.
- Status: visible in the editor.
- Purpose: Place nodes on a baseline and connect supplied relationships with arcs.
- Input: Source-target edges; optional weights, groups and an ordered node table.
- Scenarios: Inspect gene relationships; Order nodes by genomic position or pathway; Compare links across modules
- Reading: Arcs connect edge endpoints and their spans depend on node order.
- Cautions: Arc height is not interaction strength; Undirected input cannot establish regulatory direction

Published figure examples:

- **Figure 5A-B: Protein-complex membership links** — Same plot grammar.
  Dang TN, Murray P, Forbes AG (2015), *BMC Proceedings*. [PathwayMatrix: visualizing binary relationships between proteins in biological pathways](https://creativecoding.soe.ucsc.edu/pdfs/Dang_PathwayMatrix_BioVis2015.pdf).
  Source: [figure/caption](https://creativecoding.soe.ucsc.edu/pdfs/Dang_PathwayMatrix_BioVis2015.pdf); DOI `10.1186/1753-6561-9-S6-S3`; checked 2026-10-25.
  Shown in the paper: Arcs connect proteins and nested complexes.
  Apply it: Export memberships as edges with a fixed node order. The local horizontal layout omits the original linked matrix interaction.

Local runnable demos:

- **Baseline nodes and arc links** · `basic`: Use case: Inspect gene relationships. This preset illustrates baseline nodes and arc links. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_arc_network_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/interactive_arc_network_plot/examples/basic/manifest.json) · [Preview](../../plugins/interactive_arc_network_plot/all_examples_gallery/basic.png)
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Node order and arc styling** · `custom`: Use case: Order nodes by genomic position or pathway. This preset illustrates node order and arc styling. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_arc_network_plot/examples/custom/params.json) · [Inputs and reproduction](../../plugins/interactive_arc_network_plot/examples/custom/manifest.json) · [Preview](../../plugins/interactive_arc_network_plot/all_examples_gallery/custom.png)
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Inspect nodes and edges on hover** · `interactive`: Use case: Compare links across modules. This preset illustrates inspect nodes and edges on hover. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_arc_network_plot/examples/interactive/params.json) · [Inputs and reproduction](../../plugins/interactive_arc_network_plot/examples/interactive/manifest.json) · [Preview](../../plugins/interactive_arc_network_plot/all_examples_gallery/interactive.png)
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): .


### Interactive Binary Presence/Absence Plot · `interactive_binary_plot`

- Guide: [source](../../plot_web/registry/guides/interactive_binary_plot.yaml); engine: `interactive_binary_plot`.
- Status: hidden; documentation source only.
- Purpose: Display binary feature states while distinguishing absence from missingness.
- Input: Wide binary matrix or long-format states; numeric values use value_threshold.
- Scenarios: Compare evidence used by methods; Show mutation or detection states; Inspect missing records
- Reading: Filled and unfilled marks distinguish states; unknown values require a separate encoding.
- Cautions: Thresholds change binary classifications; Undetected does not mean biologically absent

Published figure examples:

- **Figure 2: Protein relationship adjacency matrix** — Related layout; adaptation required.
  Dang TN, Murray P, Forbes AG (2015), *BMC Proceedings*. [PathwayMatrix: visualizing binary relationships between proteins in biological pathways](https://creativecoding.soe.ucsc.edu/pdfs/Dang_PathwayMatrix_BioVis2015.pdf).
  Source: [figure/caption](https://creativecoding.soe.ucsc.edu/pdfs/Dang_PathwayMatrix_BioVis2015.pdf); DOI `10.1186/1753-6561-9-S6-S3`; checked 2026-10-25.
  Shown in the paper: Binary relationships in a pathway matrix.
  Apply it: Related layout: export binary relationships; original lensing and linked interaction are not implemented here. The original matrix also encodes relation types; binary conversion must use an explicit rule.

Local runnable demos:

- **Binary feature matrix** · `basic`: Use case: Compare evidence used by methods. This preset illustrates binary feature matrix. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_binary_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/interactive_binary_plot/examples/basic/manifest.json) · [Preview](../../plugins/interactive_binary_plot/all_examples_gallery/basic.png)
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Layout for dense state matrices** · `custom_layout`: Use case: Show mutation or detection states. This preset illustrates layout for dense state matrices. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_binary_plot/examples/custom_layout/params.json) · [Inputs and reproduction](../../plugins/interactive_binary_plot/examples/custom_layout/manifest.json) · [Preview](../../plugins/interactive_binary_plot/all_examples_gallery/custom_layout.png)
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Inspect individual states on hover** · `interactive`: Use case: Inspect missing records. This preset illustrates inspect individual states on hover. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_binary_plot/examples/interactive/params.json) · [Inputs and reproduction](../../plugins/interactive_binary_plot/examples/interactive/manifest.json) · [Preview](../../plugins/interactive_binary_plot/all_examples_gallery/interactive.png)
  Mappings: `row_id_column="Sample"`, `group_column="Group"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `input_mode`, `group_column`, `value_column`, `base_size`, `width`, `height`.


### Interactive Bubble Score Matrix · `interactive_bubble_score_matrix`

- Guide: [source](../../plot_web/registry/guides/interactive_bubble_score_matrix.yaml); engine: `interactive_bubble_score_matrix`.
- Status: visible in the editor.
- Purpose: Align a metric bubble matrix with one or more score panels.
- Input: Method names, numeric metric columns and score columns, or supported long-format data.
- Scenarios: Compare methods across metrics; Show component metrics and overall scores; Inspect ranking trade-offs
- Reading: The matrix and side panels may use different scales and must be read separately.
- Cautions: State whether higher or lower values are preferable; Composite scores depend on upstream weights, which the plot does not validate

Published figure examples:

- **Figure 6F: Benchmark spatial niche methods** — Related layout; adaptation required. [PREPRINT; not peer reviewed]
  Wang Y, Chen Y, Yang L, et al. (2026), *bioRxiv*. [Benchmarking niche identification via domain segmentation for spatial transcriptomics data](https://www.biorxiv.org/content/10.64898/2026.02.27.708202v1.full).
  Source: [figure/caption](https://www.biorxiv.org/content/10.64898/2026.02.27.708202v1.full#F6); DOI `10.64898/2026.02.27.708202`; checked 2026-10-25.
  Shown in the paper: Metric-color and rank-size bubble matrix.
  Apply it: Related layout: calculate metrics and ranks upstream; the plugin's side-score panels are additional local views. The source sizes bubbles by rank; verify the local size encoding rather than treating a score-sized preset as an exact reproduction.

Local runnable demos:

- **Metrics with one score panel** · `basic`: Use case: Compare methods across metrics. This preset illustrates metrics with one score panel. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_bubble_score_matrix/examples/basic/params.json) · [Inputs and reproduction](../../plugins/interactive_bubble_score_matrix/examples/basic/manifest.json) · [Preview](../../plugins/interactive_bubble_score_matrix/all_examples_gallery/basic.png)
  Mappings: `row_column="method"`, `metric_columns=["ARI", "NMI", "F1", "ASW", "V-Measure Homogeneity"]`, `score_column="Overall"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Multiple score panels** · `multi_score`: Use case: Show component metrics and overall scores. This preset illustrates multiple score panels. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_bubble_score_matrix/examples/multi_score/params.json) · [Inputs and reproduction](../../plugins/interactive_bubble_score_matrix/examples/multi_score/manifest.json) · [Preview](../../plugins/interactive_bubble_score_matrix/all_examples_gallery/multi_score.png)
  Mappings: `row_column="method"`, `metric_columns=["ARI", "NMI", "F1", "ASW", "V-Measure Homogeneity"]`, `score_columns=["Bio(CP)", "DBI", "Overall"]`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Customized matrix-panel alignment** · `custom`: Use case: Inspect ranking trade-offs. This preset illustrates customized matrix-panel alignment. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_bubble_score_matrix/examples/custom/params.json) · [Inputs and reproduction](../../plugins/interactive_bubble_score_matrix/examples/custom/manifest.json) · [Preview](../../plugins/interactive_bubble_score_matrix/all_examples_gallery/custom.png)
  Mappings: `row_column="method"`, `metric_columns=["ARI", "NMI", "F1", "ASW", "V-Measure Homogeneity"]`, `score_column="Overall"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `base_size`, `width`, `height`.


### Interactive Clustered Heatmap · `interactive_clustered_heatmap_plot`

- Guide: [source](../../plot_web/registry/guides/interactive_clustered_heatmap_plot.yaml); engine: `interactive_clustered_heatmap_plot`.
- Status: hidden; documentation source only.
- Purpose: Cluster a numeric matrix with aligned row/column annotations and optional side panels.
- Input: Wide numeric matrix with row IDs; optional matched row and column annotations.
- Scenarios: Find sample and feature modules; Check batch and biological groups; Compare aligned ancillary metrics
- Reading: Tiles show the configured values or scaling; trees describe the selected distances.
- Cautions: Missing-value handling and scaling affect clustering; Co-varying modules do not establish shared regulation

Published figure examples:

- **Figure 2E: Functional-activity heatmap** — Same plot grammar.
  Hao Q, Zhou T, Yan H, et al. (2026), *Molecular Cancer*. [A pan-cancer single cell landscape reveals heterogeneity and functional diversity of double-negative T cells](https://link.springer.com/article/10.1186/s12943-025-02548-8).
  Source: [figure/caption](https://link.springer.com/article/10.1186/s12943-025-02548-8/figures/2); DOI `10.1186/s12943-025-02548-8`; checked 2026-10-25.
  Shown in the paper: Cytokine activities across DNT subsets.
  Apply it: Use a precomputed population-by-activity matrix; activity inference is upstream.

Local runnable demos:

- **Clustered numeric matrix** · `basic`: Use case: Find sample and feature modules. This preset illustrates clustered numeric matrix. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_clustered_heatmap_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/interactive_clustered_heatmap_plot/examples/basic/manifest.json) · [Preview](../../plugins/interactive_clustered_heatmap_plot/all_examples_gallery/basic.png)
  Mappings: `row_id_column="Gene"`, `matrix_start_column=2`, `cluster_columns=true`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Color and annotation customization** · `custom`: Use case: Check batch and biological groups. This preset illustrates color and annotation customization. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_clustered_heatmap_plot/examples/custom/params.json) · [Inputs and reproduction](../../plugins/interactive_clustered_heatmap_plot/examples/custom/manifest.json) · [Preview](../../plugins/interactive_clustered_heatmap_plot/all_examples_gallery/custom.png)
  Mappings: `row_id_column="Gene"`, `matrix_start_column=2`, `cluster_columns=true`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Heatmap with additional panels** · `panels`: Use case: Compare aligned ancillary metrics. This preset illustrates heatmap with additional panels. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_clustered_heatmap_plot/examples/panels/params.json) · [Inputs and reproduction](../../plugins/interactive_clustered_heatmap_plot/examples/panels/manifest.json) · [Preview](../../plugins/interactive_clustered_heatmap_plot/all_examples_gallery/panels.png)
  Mappings: `row_id_column="Gene"`, `matrix_start_column=2`, `cluster_columns=true`, `panel_group_column="panel"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `palette`, `cluster_rows`, `cluster_columns`, `width`, `height`.

- Method reference: [Cluster analysis and display of genome-wide expression patterns](https://www.cs.princeton.edu/courses/archive/fall03/cs597F/Articles/cluster_analysis_hier_eisen.pdf) (1998).
  Relevance: Background for expression heatmaps and clustering; circular layouts and extra panels are local adaptations.

### Correlation / Dual-Triangle Matrix · `interactive_correlation_matrix`

- Guide: [source](../../plot_web/registry/guides/interactive_correlation_matrix.yaml); engine: `interactive_correlation_matrix`.
- Status: visible in the editor.
- Purpose: Compute or read a correlation matrix and show coefficients using color, numbers and triangular layouts.
- Input: Raw wide numeric observations, or a square matrix with matching row/column labels.
- Scenarios: Inspect metric redundancy; Explore covarying features; Review precomputed correlations
- Reading: Color and numbers represent the chosen correlation coefficient; probability annotations require valid tests or supplied results.
- Cautions: Correlation does not establish causation; Pairwise missingness can change effective sample sizes between cells

Published figure examples:

- **Figure 3: Soil properties and wheat performance** — Same plot grammar.
  Sanchez-Mendez S, Orden L, Franco-Luesma S, et al. (2025), *Scientific Reports*. [Agronomic and environmental assessment of a new fertilization strategy using pelleted organo-mineral fertilizers for wheat production in mediterranean agricultural soils](https://www.nature.com/articles/s41598-025-20818-9).
  Source: [figure/caption](https://www.nature.com/articles/s41598-025-20818-9#Fig3); DOI `10.1038/s41598-025-20818-9`; checked 2026-10-25.
  Shown in the paper: Mantel links alongside Pearson correlations.
  Apply it: Use separately computed coefficients and probabilities; the correlation-matrix plugin renders only the Pearson component.
- **Figure 3: Environmental relationships during freeze-thaw** — Same plot grammar.
  Li S, Zhou M, Guan S, et al. (2025), *Scientific Reports*. [Soil nitrogen-hydrolyzing enzyme activities respond differently to the freeze-thaw temperature and number of cycles](https://www.nature.com/articles/s41598-025-98879-z).
  Source: [figure/caption](https://www.nature.com/articles/s41598-025-98879-z#Fig3); DOI `10.1038/s41598-025-98879-z`; checked 2026-10-25.
  Shown in the paper: Mantel networks paired with a correlation triangle.
  Apply it: Keep distance-based and variable-based statistics separate; the matrix plugin covers the triangle only.

Local runnable demos:

- **Correlations from raw observations** · `basic`: Use case: Inspect metric redundancy. This preset illustrates correlations from raw observations. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_correlation_matrix/examples/basic/params.json) · [Inputs and reproduction](../../plugins/interactive_correlation_matrix/examples/basic/manifest.json) · [Preview](../../plugins/interactive_correlation_matrix/all_examples_gallery/basic.png)
  Mappings: `id_column="sample"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Nonredundant lower triangle** · `lower_triangle`: Use case: Explore covarying features. This preset illustrates nonredundant lower triangle. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_correlation_matrix/examples/lower_triangle/params.json) · [Inputs and reproduction](../../plugins/interactive_correlation_matrix/examples/lower_triangle/manifest.json) · [Preview](../../plugins/interactive_correlation_matrix/all_examples_gallery/lower_triangle.png)
  Mappings: `id_column="sample"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Inspect individual coefficients on hover** · `interactive`: Use case: Review precomputed correlations. This preset illustrates inspect individual coefficients on hover. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_correlation_matrix/examples/interactive/params.json) · [Inputs and reproduction](../../plugins/interactive_correlation_matrix/examples/interactive/manifest.json) · [Preview](../../plugins/interactive_correlation_matrix/all_examples_gallery/interactive.png)
  Mappings: `id_column="sample"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): .


### Interactive Dual-Triangle Heatmap · `interactive_dual_triangle_heatmap_plot`

- Guide: [source](../../plot_web/registry/guides/interactive_dual_triangle_heatmap_plot.yaml); engine: `interactive_dual_triangle_heatmap_plot`.
- Status: hidden; documentation source only.
- Purpose: Place two aligned square matrices in separate triangles with independent scales.
- Input: Two square matrices with matching labels, such as similarity and correlation.
- Scenarios: Compare similarity definitions; Contrast two conditions; Inspect set similarity alongside expression correlation
- Reading: Read the upper and lower triangles against their own legends.
- Cautions: Different scales cannot be compared by subtracting colors; Mismatched labels or ordering invalidate pairwise alignment

Published figure examples:

No figure-panel association has been verified yet.

Local runnable demos:

- **Compare two pairwise matrices** · `basic`: Use case: Compare similarity definitions. This preset illustrates compare two pairwise matrices. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_dual_triangle_heatmap_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/interactive_dual_triangle_heatmap_plot/examples/basic/manifest.json) · [Preview](../../plugins/interactive_dual_triangle_heatmap_plot/all_examples_gallery/basic.png)
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Independent scales and labels** · `custom`: Use case: Contrast two conditions. This preset illustrates independent scales and labels. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_dual_triangle_heatmap_plot/examples/custom/params.json) · [Inputs and reproduction](../../plugins/interactive_dual_triangle_heatmap_plot/examples/custom/manifest.json) · [Preview](../../plugins/interactive_dual_triangle_heatmap_plot/all_examples_gallery/custom.png)
  Mappings: `annotation_columns=["Dataset", "Group"]`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Inspect both triangles on hover** · `interactive`: Use case: Inspect set similarity alongside expression correlation. This preset illustrates inspect both triangles on hover. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_dual_triangle_heatmap_plot/examples/interactive/params.json) · [Inputs and reproduction](../../plugins/interactive_dual_triangle_heatmap_plot/examples/interactive/manifest.json) · [Preview](../../plugins/interactive_dual_triangle_heatmap_plot/all_examples_gallery/interactive.png)
  Mappings: `annotation_columns=["Dataset"]`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `width`, `height`.

- No curated literature reference yet.

### Interactive Dumbbell Plot · `interactive_dumbbell_plot`

- Guide: [source](../../plot_web/registry/guides/interactive_dumbbell_plot.yaml); engine: `interactive_dumbbell_plot`.
- Status: visible in the editor.
- Purpose: Connect two values per category to emphasize the difference between groups or conditions.
- Input: Category and two numeric columns, or category/group/value long data.
- Scenarios: Compare before and after; Compare two cohort metrics; Rank categories by their change
- Reading: Endpoint positions encode group values and line length encodes the absolute difference.
- Cautions: Without individual IDs, do not imply subject-level pairing; Connecting lines are not confidence intervals or significance tests

Published figure examples:

- **Figure 2B: Compare in-domain and transferred performance** — Same plot grammar.
  Guo A, Chen W, Zhang Y, et al. (2026), *Scientific Reports*. [The limits of debiased clinical language models for cross-hospital generalization](https://www.nature.com/articles/s41598-026-53043-z).
  Source: [figure/caption](https://www.nature.com/articles/s41598-026-53043-z#Fig2); DOI `10.1038/s41598-026-53043-z`; checked 2026-10-25.
  Shown in the paper: Endpoint pairs compare cross-hospital fairness metrics.
  Apply it: Use one row per method with the two endpoint values; no clinical prediction or fairness inference is computed here.

Local runnable demos:

- **Two-condition category differences** · `basic`: Use case: Compare before and after. This preset illustrates two-condition category differences. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_dumbbell_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/interactive_dumbbell_plot/examples/basic/manifest.json) · [Preview](../../plugins/interactive_dumbbell_plot/all_examples_gallery/basic.png)
  Mappings: `category_column="school"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Ordering and endpoint labels** · `custom_layout`: Use case: Compare two cohort metrics. This preset illustrates ordering and endpoint labels. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_dumbbell_plot/examples/custom_layout/params.json) · [Inputs and reproduction](../../plugins/interactive_dumbbell_plot/examples/custom_layout/manifest.json) · [Preview](../../plugins/interactive_dumbbell_plot/all_examples_gallery/custom_layout.png)
  Mappings: `category_column="school"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Inspect both values on hover** · `interactive`: Use case: Rank categories by their change. This preset illustrates inspect both values on hover. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_dumbbell_plot/examples/interactive/params.json) · [Inputs and reproduction](../../plugins/interactive_dumbbell_plot/examples/interactive/manifest.json) · [Preview](../../plugins/interactive_dumbbell_plot/all_examples_gallery/interactive.png)
  Mappings: `category_column="school"`, `tooltip_columns=["school", "Women", "Men"]`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `input_mode`, `group_column`, `value_column`, `category_column`, `group_colors`, `width`, `height`.


### Enrichment lollipop · `enrichment_lollipop`

- Guide: [source](../../plot_web/registry/guides/enrichment_lollipop.yaml); engine: `interactive_enrichment_lollipop`.
- Status: visible in the editor.
- Purpose: Compare named pathways or transcription factors using signed effects. Stems connect each effect to zero; point size can summarize a second statistic.

- Input: One row per pathway or TF, with a name, signed effect and optional p-value or FDR; specify the contrast direction.
- Scenarios: Comparing transcription-factor signatures between two cell states; Ranking signed pathway enrichment scores; Showing effect direction and significance together
- Reading: Left and right show negative and positive values in the supplied effect column.; The legend defines whether color denotes a group or effect, and whether size denotes a supplied value or transformed probability.
- Cautions: A differential regulon signature does not by itself establish causal transcription-factor regulation.; Distinguish raw p-values from adjusted p-values; the plot performs no multiple-testing correction.; CAB_demo uses synthetic illustrative effects and probabilities, not measurements recovered from the publication.

Published figure examples:

- **Figure 6L: Opposing TF signatures** — Same plot grammar.
  Hao Q, Zhou T, Yan H, et al. (2026), *Molecular Cancer*. [A pan-cancer single cell landscape reveals heterogeneity and functional diversity of double-negative T cells](https://link.springer.com/article/10.1186/s12943-025-02548-8).
  Source: [figure/caption](https://link.springer.com/article/10.1186/s12943-025-02548-8/figures/6); DOI `10.1186/s12943-025-02548-8`; checked 2026-10-25.
  Shown in the paper: Signed TF effects in Grm1 versus Grm2.
  Apply it: Use a signed contrast table with TF names and probabilities; the local starter is synthetic.
- **Figure 2A-B: Compare enriched synaptic pathways** — Same plot grammar.
  Puig S, Xue X, Salisbury R, et al. (2023), *Molecular Psychiatry*. [Circadian rhythm disruptions associated with opioid use disorder in synaptic proteomes of human dorsolateral prefrontal cortex and nucleus accumbens](https://www.nature.com/articles/s41380-023-02241-6).
  Source: [figure/caption](https://www.nature.com/articles/s41380-023-02241-6#Fig2); DOI `10.1038/s41380-023-02241-6`; checked 2026-10-25.
  Shown in the paper: Enrichment scores with adjusted probabilities and protein counts.
  Apply it: Use the supplied enrichment ratio as the x value and counts for size; these ratios are not signed differential effects. The source colors probabilities independently of the x score; the current value-color mode follows x, so an exact copy needs an appropriate separate color mapping.

Local runnable demos:

- **Published use case: Grm1 versus Grm2 transcription factors** · `CAB_demo`: Hao et al. compare transcription-factor signatures of two gut-resident gamma-delta T-cell states in Figure 6L. Use this layout when a two-state comparison supplies TF/regulon names, a signed effect and p-values. The demo colors effects green-to-pink, sizes points by -log10(p value), and places names opposite the stems around zero.

  [Parameters](../../plugins/interactive_enrichment_lollipop/examples/CAB_demo/params.json) · [Inputs and reproduction](../../plugins/interactive_enrichment_lollipop/examples/CAB_demo/manifest.json) · [Preview](../../plugins/interactive_enrichment_lollipop/all_examples_gallery/CAB_demo.png)
  Data provenance: Synthetic demonstration, not the paper's original data. Replace the input table for your own analysis.
- **Signed pathway enrichment** · `basic`: Compare pathway effect direction with group colors and a separately labelled size statistic.
  [Parameters](../../plugins/interactive_enrichment_lollipop/examples/basic/params.json) · [Inputs and reproduction](../../plugins/interactive_enrichment_lollipop/examples/basic/manifest.json) · [Preview](../../plugins/interactive_enrichment_lollipop/all_examples_gallery/basic.png)
- **Rank candidate enrichment effects** · `oct4_enrichment`: Compare signed scores for candidate items in one contrast. Confirm the supplied statistic before assigning colors and sizes.
  [Parameters](../../plugins/interactive_enrichment_lollipop/examples/oct4_enrichment/params.json) · [Inputs and reproduction](../../plugins/interactive_enrichment_lollipop/examples/oct4_enrichment/manifest.json) · [Preview](../../plugins/interactive_enrichment_lollipop/all_examples_gallery/oct4_enrichment.png)
  Data provenance: Local demonstration configuration, not original paper data.

Customization controls (checked against the schema): `group_column`, `value_column`, `category_column`, `sort_by`, `top_n`, `group_colors`, `color_low`, `color_high`, `label_show`, `base_size`, `width`, `height`.


### Interactive Genomic Signal Track Plot · `interactive_genomic_signal_track_plot`

- Guide: [source](../../plot_web/registry/guides/interactive_genomic_signal_track_plot.yaml); engine: `interactive_genomic_signal_track_plot`.
- Status: visible in the editor.
- Purpose: Stack signal tracks on a shared genomic axis with optional feature intervals and expression panels.
- Input: Track/position/value long data; optional chromosome, sample, interval and expression tables.
- Scenarios: Compare sequencing signals near a locus; Align peaks and gene annotations; Inspect signal alongside expression
- Reading: Horizontal position uses the supplied genomic coordinates; each track shows its input signal.
- Cautions: Check genome assembly and coordinate conventions; Independently scaled tracks cannot be compared by absolute height

Published figure examples:

- **Figure 1E: Cell-type chromatin-accessibility tracks** — Same plot grammar.
  Li YE, Preissl S, Hou X, et al. (2021), *Nature*. [An atlas of gene regulatory elements in adult mouse cerebrum](https://www.nature.com/articles/s41586-021-03604-1).
  Source: [figure/caption](https://www.nature.com/articles/s41586-021-03604-1#Fig1); DOI `10.1038/s41586-021-03604-1`; checked 2026-10-25.
  Shown in the paper: Aggregate accessibility at marker loci.
  Apply it: Export signal values on a common genomic axis; gene models and genome build must be specified.
- **Figure 3I: Candidate regulatory regions at a locus** — Same plot grammar.
  Li YE, Preissl S, Hou X, et al. (2021), *Nature*. [An atlas of gene regulatory elements in adult mouse cerebrum](https://www.nature.com/articles/s41586-021-03604-1).
  Source: [figure/caption](https://www.nature.com/articles/s41586-021-03604-1#Fig3); DOI `10.1038/s41586-021-03604-1`; checked 2026-10-25.
  Shown in the paper: Astrocyte accessibility near Olig2.
  Apply it: Prepare per-track position-value records and optional feature intervals; regulatory inference remains upstream.
- **Figure 2F: Accessibility grouped by projection-neuron type** — Same plot grammar.
  Yang L, Liu F, Hahm H, et al. (2025), *Nature Communications*. [Projection-TAGs enable multiplex projection tracing and multi-modal profiling of projection neurons](https://www.nature.com/articles/s41467-025-60360-w).
  Source: [figure/caption](https://www.nature.com/articles/s41467-025-60360-w#Fig2); DOI `10.1038/s41467-025-60360-w`; checked 2026-10-25.
  Shown in the paper: Binned accessibility coverage at marker loci.
  Apply it: Supply the binned signal values; the renderer does not perform fragment counting.

Local runnable demos:

- **Multiple tracks on shared coordinates** · `basic`: Use case: Compare sequencing signals near a locus. This preset illustrates multiple tracks on shared coordinates. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_genomic_signal_track_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/interactive_genomic_signal_track_plot/examples/basic/manifest.json) · [Preview](../../plugins/interactive_genomic_signal_track_plot/all_examples_gallery/basic.png)
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Track and annotation layout** · `custom_layout`: Use case: Align peaks and gene annotations. This preset illustrates track and annotation layout. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_genomic_signal_track_plot/examples/custom_layout/params.json) · [Inputs and reproduction](../../plugins/interactive_genomic_signal_track_plot/examples/custom_layout/manifest.json) · [Preview](../../plugins/interactive_genomic_signal_track_plot/all_examples_gallery/custom_layout.png)
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Inspect signals and intervals on hover** · `interactive`: Use case: Inspect signal alongside expression. This preset illustrates inspect signals and intervals on hover. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_genomic_signal_track_plot/examples/interactive/params.json) · [Inputs and reproduction](../../plugins/interactive_genomic_signal_track_plot/examples/interactive/manifest.json) · [Preview](../../plugins/interactive_genomic_signal_track_plot/all_examples_gallery/interactive.png)
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `value_column`, `width`, `height`.


### Interactive Histogram Plot · `interactive_histogram_plot`

- Guide: [source](../../plot_web/registry/guides/interactive_histogram_plot.yaml); engine: `interactive_histogram_plot`.
- Status: visible in the editor.
- Purpose: Compare continuous distributions using shared, explicitly computed bins.
- Input: Numeric wide data or value/group long data, with optional observation IDs.
- Scenarios: Inspect quality-metric distributions; Compare condition shifts; Find outliers and truncation
- Reading: Bar heights represent counts or the selected normalization, using common bins for comparisons.
- Cautions: Bin width and boundaries affect the impression; Counts reflect sample size as well as distribution shape

Published figure examples:

- **Figure 2E-F: Dataset size distributions** — Same plot grammar.
  Liu T, Qiao H, Ren L, et al. (2025), *Communications Biology*. [Deciphering cancer therapy resistance via patient-level single-cell transcriptomics with CellResDB](https://www.nature.com/articles/s42003-025-08457-2).
  Source: [figure/caption](https://www.nature.com/articles/s42003-025-08457-2#Fig2); DOI `10.1038/s42003-025-08457-2`; checked 2026-10-25.
  Shown in the paper: Binned cell-type and cell-count frequencies.
  Apply it: Start from dataset-level observations and use explicit bin boundaries; log-transform counts only when stated.
- **Figure 2D: Compare model-performance distributions** — Same plot grammar.
  Klughammer J, Romanovskaia D, Nemc A, et al. (2023), *Nature Communications*. [Comparative analysis of genome-scale, base-resolution DNA methylation profiles across 580 animal species](https://www.nature.com/articles/s41467-022-34828-y).
  Source: [figure/caption](https://www.nature.com/articles/s41467-022-34828-y#Fig2); DOI `10.1038/s41467-022-34828-y`; checked 2026-10-25.
  Shown in the paper: ROC-AUC distributions for vertebrate and invertebrate species.
  Apply it: Use species-level ROC-AUC values and a taxonomic group column with shared bin boundaries.

Local runnable demos:

- **Compare distributions with shared bins** · `basic`: Use case: Inspect quality-metric distributions. This preset illustrates compare distributions with shared bins. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_histogram_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/interactive_histogram_plot/examples/basic/manifest.json) · [Preview](../../plugins/interactive_histogram_plot/all_examples_gallery/basic.png)
  Mappings: `id_column="sample"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Bin width and transparency** · `custom_layout`: Use case: Compare condition shifts. This preset illustrates bin width and transparency. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_histogram_plot/examples/custom_layout/params.json) · [Inputs and reproduction](../../plugins/interactive_histogram_plot/examples/custom_layout/manifest.json) · [Preview](../../plugins/interactive_histogram_plot/all_examples_gallery/custom_layout.png)
  Mappings: `id_column="sample"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Inspect counts within each bin** · `interactive`: Use case: Find outliers and truncation. This preset illustrates inspect counts within each bin. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_histogram_plot/examples/interactive/params.json) · [Inputs and reproduction](../../plugins/interactive_histogram_plot/examples/interactive/manifest.json) · [Preview](../../plugins/interactive_histogram_plot/all_examples_gallery/interactive.png)
  Mappings: `id_column="sample"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `input_mode`, `base_size`, `width`, `height`.

- Method reference: [Raincloud plots: a multi-platform tool for robust data visualization](https://wellcomeopenresearch.org/articles/4-63) (2021).
  Relevance: Explains the roles of density, raw points and summary statistics. Other distribution plots are related reading, not identical layouts.

### Mantel + Pearson Correlation · `interactive_mantel_correlation_network`

- Guide: [source](../../plot_web/registry/guides/interactive_mantel_correlation_network.yaml); engine: `interactive_mantel_correlation_network`.
- Status: visible in the editor.
- Purpose: Distinguish Pearson correlations among variables from Mantel associations between distance matrices.
- Input: Precomputed correlation matrix and Mantel-result edges with matching variable names.
- Scenarios: Relate community differences to environmental gradients; Compare biological and phenotypic distances; Survey multivariable associations
- Reading: The triangle encodes Pearson r; network edge styles encode Mantel results according to their legend.
- Cautions: Mantel r and Pearson r are different statistics; Handle permutation design and nonindependence upstream

Published figure examples:

- **Figure 3: Soil properties and wheat performance** — Same plot grammar.
  Sanchez-Mendez S, Orden L, Franco-Luesma S, et al. (2025), *Scientific Reports*. [Agronomic and environmental assessment of a new fertilization strategy using pelleted organo-mineral fertilizers for wheat production in mediterranean agricultural soils](https://www.nature.com/articles/s41598-025-20818-9).
  Source: [figure/caption](https://www.nature.com/articles/s41598-025-20818-9#Fig3); DOI `10.1038/s41598-025-20818-9`; checked 2026-10-25.
  Shown in the paper: Mantel links alongside Pearson correlations.
  Apply it: Use separately computed coefficients and probabilities; the correlation-matrix plugin renders only the Pearson component.
- **Figure 3: Environmental relationships during freeze-thaw** — Same plot grammar.
  Li S, Zhou M, Guan S, et al. (2025), *Scientific Reports*. [Soil nitrogen-hydrolyzing enzyme activities respond differently to the freeze-thaw temperature and number of cycles](https://www.nature.com/articles/s41598-025-98879-z).
  Source: [figure/caption](https://www.nature.com/articles/s41598-025-98879-z#Fig3); DOI `10.1038/s41598-025-98879-z`; checked 2026-10-25.
  Shown in the paper: Mantel networks paired with a correlation triangle.
  Apply it: Keep distance-based and variable-based statistics separate; the matrix plugin covers the triangle only.

Local runnable demos:

- **Pearson matrix alongside Mantel links** · `basic`: Use case: Relate community differences to environmental gradients. This preset illustrates pearson matrix alongside mantel links. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_mantel_correlation_network/examples/basic/params.json) · [Inputs and reproduction](../../plugins/interactive_mantel_correlation_network/examples/basic/manifest.json) · [Preview](../../plugins/interactive_mantel_correlation_network/all_examples_gallery/basic.png)
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `input_mode`, `width`, `height`.


### Interactive Motif Enrichment Logo · `interactive_motif_logo_plot`

- Guide: [source](../../plot_web/registry/guides/interactive_motif_logo_plot.yaml); engine: `interactive_motif_logo_plot`.
- Status: visible in the editor.
- Purpose: Display DNA position-probability matrices as sequence logos with optional motif statistics.
- Input: Motif/position/A/C/G/T long data or a grouped wide probability matrix.
- Scenarios: Inspect enriched sequence preferences; Compare conservation across positions; Organize candidate binding motifs
- Reading: Relative letter heights encode base probabilities; total column height can reflect information content.
- Cautions: A motif match rarely identifies a unique transcription factor; A sequence logo alone does not establish enrichment significance

Published figure examples:

- **Figure 2A-E: Compare regulatory motifs across bacterial groups** — Same plot grammar.
  Rodionova IA, Gao Y, Sastry A, et al. (2021), *Communications Biology*. [Identification of a transcription factor, PunR, that regulates the purine and purine nucleoside transporter punC in E. coli](https://www.nature.com/articles/s42003-021-02516-0).
  Source: [figure/caption](https://www.nature.com/articles/s42003-021-02516-0#Fig2); DOI `10.1038/s42003-021-02516-0`; checked 2026-10-25.
  Shown in the paper: PunR binding-site sequence logos.
  Apply it: Supply DNA position-probability matrices; motif discovery and alignments are upstream.
- **Figure 2A: Inspect nuclease sequence preferences** — Same plot grammar.
  Harrington LB, Paez-Espino D, Staahl BT, et al. (2017), *Nature Communications*. [A thermostable Cas9 with increased lifetime in human plasma](https://www.nature.com/articles/s41467-017-01408-4).
  Source: [figure/caption](https://www.nature.com/articles/s41467-017-01408-4#Fig2); DOI `10.1038/s41467-017-01408-4`; checked 2026-10-25.
  Shown in the paper: PAM sequence logos for two Cas9 orthologs.
  Apply it: Supply base probabilities at each position; the local renderer does not infer PAMs or cleavage efficiency.

Local runnable demos:

- **Candidate sequence preferences** · `basic`: Use case: Inspect enriched sequence preferences. This preset illustrates candidate sequence preferences. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_motif_logo_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/interactive_motif_logo_plot/examples/basic/manifest.json) · [Preview](../../plugins/interactive_motif_logo_plot/all_examples_gallery/basic.png)
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Base colors and row layout** · `custom`: Use case: Compare conservation across positions. This preset illustrates base colors and row layout. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_motif_logo_plot/examples/custom/params.json) · [Inputs and reproduction](../../plugins/interactive_motif_logo_plot/examples/custom/manifest.json) · [Preview](../../plugins/interactive_motif_logo_plot/all_examples_gallery/custom.png)
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Inspect positions and bases on hover** · `interactive`: Use case: Organize candidate binding motifs. This preset illustrates inspect positions and bases on hover. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_motif_logo_plot/examples/interactive/params.json) · [Inputs and reproduction](../../plugins/interactive_motif_logo_plot/examples/interactive/manifest.json) · [Preview](../../plugins/interactive_motif_logo_plot/all_examples_gallery/interactive.png)
  Mappings: `tooltip_columns=["motif", "position", "base", "raw_weight", "probability", "height"]`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `input_mode`, `base_size`, `width`, `height`.

- Method reference: [Sequence logos: a new way to display consensus sequences](https://academic.oup.com/nar/article/18/20/6097/1141316) (1990).
  Relevance: Explains letter heights and conservation; the logo itself does not establish enrichment significance.

### Interactive Network · `interactive_network_plot`

- Guide: [source](../../plot_web/registry/guides/interactive_network_plot.yaml); engine: `interactive_network_plot`.
- Status: visible in the editor.
- Purpose: Draw relationships from edges or memberships using configurable or fixed node layouts.
- Input: Source-target edges with an optional node table, or group-element membership data.
- Scenarios: Show gene or protein associations; Compare shared members across functional sets; Organize relationships by module
- Reading: Edges encode supplied relationships; positions follow the selected layout or explicit coordinates.
- Cautions: Force-layout distance is not a calibrated biological distance; Membership-derived edges are not direct molecular interactions

Published figure examples:

- **Figure 2I: Condition-specific cellular interactions** — Same plot grammar.
  Tan Y, Kempchen TN, Becker M, et al. (2025), *Nature Communications*. [SPACEc: a streamlined, interactive Python workflow for multiplexed image processing and analysis](https://www.nature.com/articles/s41467-025-65658-3).
  Source: [figure/caption](https://www.nature.com/articles/s41467-025-65658-3#Fig2); DOI `10.1038/s41467-025-65658-3`; checked 2026-10-25.
  Shown in the paper: Distance-based cell interaction networks.
  Apply it: Use precomputed edges and effects; permutation tests are not performed by this renderer.

Local runnable demos:

- **Edge-list relationship network** · `network`: Use case: Show gene or protein associations. This preset illustrates edge-list relationship network. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_network_plot/examples/network/params.json) · [Inputs and reproduction](../../plugins/interactive_network_plot/examples/network/manifest.json) · [Preview](../../plugins/interactive_network_plot/all_examples_gallery/network.png)
  Mappings: `source_column="source"`, `target_column="target"`, `weight_column="weight"`, `edge_group_column="edge_group"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Set-membership network** · `membership`: Use case: Compare shared members across functional sets. This preset illustrates set-membership network. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_network_plot/examples/membership/params.json) · [Inputs and reproduction](../../plugins/interactive_network_plot/examples/membership/manifest.json) · [Preview](../../plugins/interactive_network_plot/all_examples_gallery/membership.png)
  Mappings: `group_column="group"`, `node_id_column="element"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Fixed coordinates for version comparisons** · `manual_layout`: Use case: Organize relationships by module. This preset illustrates fixed coordinates for version comparisons. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_network_plot/examples/manual_layout/params.json) · [Inputs and reproduction](../../plugins/interactive_network_plot/examples/manual_layout/manifest.json) · [Preview](../../plugins/interactive_network_plot/all_examples_gallery/manual_layout.png)
  Mappings: `source_column="source"`, `target_column="target"`, `weight_column="weight"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `input_mode`, `group_column`, `source_column`, `target_column`, `group_colors`, `label_show`, `base_size`, `width`, `height`.


### Pie / Rose Plot · `interactive_pie_plot`

- Guide: [source](../../plot_web/registry/guides/interactive_pie_plot.yaml); engine: `interactive_pie_plot`.
- Status: visible in the editor.
- Purpose: Show nonnegative category shares using pie or donut sectors.
- Input: Categories and nonnegative values, with optional groups, labels or colors.
- Scenarios: Summarize a few cell-type shares; Survey sample composition; Check category order and labels
- Reading: Sector angles encode shares of the displayed total.
- Cautions: Filtering and top-N selection can change the denominator; Use stacked bars for clearer comparisons across many samples

Published figure examples:

- **Figure 2D: Population abundance across cancers** — Same plot grammar.
  Hao Q, Zhou T, Yan H, et al. (2026), *Molecular Cancer*. [A pan-cancer single cell landscape reveals heterogeneity and functional diversity of double-negative T cells](https://link.springer.com/article/10.1186/s12943-025-02548-8).
  Source: [figure/caption](https://link.springer.com/article/10.1186/s12943-025-02548-8/figures/2); DOI `10.1186/s12943-025-02548-8`; checked 2026-10-25.
  Shown in the paper: Population frequencies and cancer-type composition.
  Apply it: Select the pie or sized-matrix component; the local plugin does not assemble the entire original composite.

Local runnable demos:

- **Composition of a few categories** · `basic`: Use case: Summarize a few cell-type shares. This preset illustrates composition of a few categories. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_pie_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/interactive_pie_plot/examples/basic/manifest.json) · [Preview](../../plugins/interactive_pie_plot/all_examples_gallery/basic.png)
  Mappings: `category_column="category"`, `value_column="value"`, `label_column="label"`, `color_column="color"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Donut composition view** · `donut`: Use case: Survey sample composition. This preset illustrates donut composition view. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_pie_plot/examples/donut/params.json) · [Inputs and reproduction](../../plugins/interactive_pie_plot/examples/donut/manifest.json) · [Preview](../../plugins/interactive_pie_plot/all_examples_gallery/donut.png)
  Mappings: `category_column="category"`, `value_column="value"`, `label_column="label"`, `color_column="color"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Label-layout customization** · `custom_layout`: Use case: Check category order and labels. This preset illustrates label-layout customization. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_pie_plot/examples/custom_layout/params.json) · [Inputs and reproduction](../../plugins/interactive_pie_plot/examples/custom_layout/manifest.json) · [Preview](../../plugins/interactive_pie_plot/all_examples_gallery/custom_layout.png)
  Mappings: `category_column="category"`, `value_column="value"`, `label_column="label"`, `color_column="color"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `width`, `height`.


### Interactive Radar Plot · `interactive_radar_plot`

- Guide: [source](../../plot_web/registry/guides/interactive_radar_plot.yaml); engine: `interactive_radar_plot`.
- Status: visible in the editor.
- Purpose: Compare multimetric profiles along radial axes, with optional normalization.
- Input: Metric/group/value long data or a wide metric-by-group table.
- Scenarios: Compare multidimensional method performance; Inspect sample score profiles; Identify trade-offs across metrics
- Reading: Each axis represents a metric with its own configured scale and normalization.
- Cautions: Polygon area depends on axis order and is not an overall score; Different units require a defensible normalization strategy

Published figure examples:

- **Figure 1H: Multifunctional cell-state profiles** — Same plot grammar.
  Hao Q, Zhou T, Yan H, et al. (2026), *Molecular Cancer*. [A pan-cancer single cell landscape reveals heterogeneity and functional diversity of double-negative T cells](https://link.springer.com/article/10.1186/s12943-025-02548-8).
  Source: [figure/caption](https://link.springer.com/article/10.1186/s12943-025-02548-8/figures/1); DOI `10.1186/s12943-025-02548-8`; checked 2026-10-25.
  Shown in the paper: Functions compared across cell types.
  Apply it: Provide comparable functional scores and explicitly set radial scaling.
- **Figure 5F: Compare spatial-proteomics trade-offs** — Same plot grammar.
  Nimo J, Fritzsche S, Valdes DS, et al. (2026), *Nature Methods*. [OpenDVP: an experimental and computational framework for community-empowered deep visual proteomics](https://www.nature.com/articles/s41592-026-03262-z).
  Source: [figure/caption](https://www.nature.com/articles/s41592-026-03262-z#Fig5); DOI `10.1038/s41592-026-03262-z`; checked 2026-10-25.
  Shown in the paper: Three strategies compared on five qualitative axes.
  Apply it: Use explicit ordinal values and label the scale; polygon area is not a quantitative overall performance score.

Local runnable demos:

- **Multigroup metric profiles** · `basic`: Use case: Compare multidimensional method performance. This preset illustrates multigroup metric profiles. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_radar_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/interactive_radar_plot/examples/basic/manifest.json) · [Preview](../../plugins/interactive_radar_plot/all_examples_gallery/basic.png)
  Mappings: `metric_column="metric"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Axis order and ranges** · `custom_layout`: Use case: Inspect sample score profiles. This preset illustrates axis order and ranges. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_radar_plot/examples/custom_layout/params.json) · [Inputs and reproduction](../../plugins/interactive_radar_plot/examples/custom_layout/manifest.json) · [Preview](../../plugins/interactive_radar_plot/all_examples_gallery/custom_layout.png)
  Mappings: `metric_column="metric"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Inspect metric values on hover** · `interactive`: Use case: Identify trade-offs across metrics. This preset illustrates inspect metric values on hover. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_radar_plot/examples/interactive/params.json) · [Inputs and reproduction](../../plugins/interactive_radar_plot/examples/interactive/manifest.json) · [Preview](../../plugins/interactive_radar_plot/all_examples_gallery/interactive.png)
  Mappings: `metric_column="metric"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `input_mode`, `group_column`, `value_column`, `group_colors`, `width`, `height`.


### Ridgeline · `ridgeline`

- Guide: [source](../../plot_web/registry/guides/ridgeline.yaml); engine: `interactive_ridgeline_plot`.
- Status: visible in the editor.
- Purpose: Stack continuous density distributions by category, optionally comparing conditions within rows.
- Input: Continuous values and categories, or one numeric column per group.
- Scenarios: Compare population score distributions; Inspect sample expression distributions; Compare conditions within categories
- Reading: Horizontal position represents values; ridge heights follow the configured density scaling.
- Cautions: Peak height need not represent sample size; Bandwidth, overlap and normalization affect appearance

Published figure examples:

- **Figure 4A: Immune-receptor length distributions** — Same plot grammar.
  Li Z, Jia J, Zhang Q, et al. (2025), *Scientific Data*. [A single-cell V(D)J sequencing dataset of peripheral blood cells in multibacillary leprosy](https://www.nature.com/articles/s41597-025-05616-2).
  Source: [figure/caption](https://www.nature.com/articles/s41597-025-05616-2#Fig4); DOI `10.1038/s41597-025-05616-2`; checked 2026-10-25.
  Shown in the paper: CDR3 length distributions by group.
  Apply it: Use per-sequence lengths and grouping labels; density estimation choices affect ridge appearance.
- **Figure 3B: Regulon-target score distributions** — Same plot grammar.
  Jia W, Lin K, Liu X, et al. (2026), *npj Precision Oncology*. [Single-cell analysis identifies dysregulated cell type-specific gene programs and intercellular crosstalk underlying colorectal cancer](https://www.nature.com/articles/s41698-026-01490-2).
  Source: [figure/caption](https://www.nature.com/articles/s41698-026-01490-2#Fig3); DOI `10.1038/s41698-026-01490-2`; checked 2026-10-25.
  Shown in the paper: Target-gene fold-change distributions for activated and repressed regulons.
  Apply it: Supply gene-level scores and regulon labels. Regulon discovery and differential testing must be done upstream.

Local runnable demos:

- **Continuous distributions across categories** · `basic`: Use case: Compare population score distributions. This preset illustrates continuous distributions across categories. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_ridgeline_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/interactive_ridgeline_plot/examples/basic/manifest.json) · [Preview](../../plugins/interactive_ridgeline_plot/all_examples_gallery/basic.png)
  Mappings: `id_column="sample"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Conditions within categories** · `grouped`: Use case: Inspect sample expression distributions. This preset illustrates conditions within categories. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_ridgeline_plot/examples/grouped/params.json) · [Inputs and reproduction](../../plugins/interactive_ridgeline_plot/examples/grouped/manifest.json) · [Preview](../../plugins/interactive_ridgeline_plot/all_examples_gallery/grouped.png)
  Mappings: `feature_column="feature"`, `value_column="value"`, `group_column="group"`, `id_column="sample"`, `statistic_columns={"d": "d", "p": "p"}`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Compact multiridge presentation** · `CAB_demo`: Use case: Compare conditions within categories. This preset illustrates compact multiridge presentation. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_ridgeline_plot/examples/CAB_demo/params.json) · [Inputs and reproduction](../../plugins/interactive_ridgeline_plot/examples/CAB_demo/manifest.json) · [Preview](../../plugins/interactive_ridgeline_plot/all_examples_gallery/CAB_demo.png)
  Mappings: `id_column="sample"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `input_mode`, `group_colors`, `width`, `height`.

- Method reference: [Raincloud plots: a multi-platform tool for robust data visualization](https://wellcomeopenresearch.org/articles/4-63) (2021).
  Relevance: Explains the roles of density, raw points and summary statistics. Other distribution plots are related reading, not identical layouts.

### Interactive Sankey / Alluvial Flow · `sankey`

- Guide: [source](../../plot_web/registry/guides/sankey.yaml); engine: `interactive_sankey_plot`.
- Status: hidden; documentation source only.
- Purpose: Show weighted source-to-target flows using nodes and variable-width links.
- Input: Source, target and nonnegative flow values.
- Scenarios: Inspect category flows; Track quantities between stages; Summarize origins and destinations
- Reading: Link width encodes the supplied flow, while node positions follow the layout.
- Cautions: Correspondence does not prove lineage; Explain filtering or external flows when totals are not conserved

Published figure examples:

- **Figure 3F: Cross-modality annotation transfer** — Same plot grammar.
  Blair JD, Hartman A, Zenk F, et al. (2025), *Nature Communications*. [Phospho-seq: integrated, multi-modal profiling of intracellular protein dynamics in single cells](https://www.nature.com/articles/s41467-025-56590-7).
  Source: [figure/caption](https://www.nature.com/articles/s41467-025-56590-7#Fig3); DOI `10.1038/s41467-025-56590-7`; checked 2026-10-25.
  Shown in the paper: ATAC labels linked to transferred labels.
  Apply it: Aggregate label-pair counts into source-target flows; label transfer is upstream.
- **Figure 4B-C: Isoform-class changes between tissues** — Same plot grammar.
  Dondi A, Lischetti U, Jacob F, et al. (2023), *Nature Communications*. [Detection of isoforms and genomic alterations by high-throughput full-length single-cell RNA sequencing in ovarian cancer](https://www.nature.com/articles/s41467-023-43387-9).
  Source: [figure/caption](https://www.nature.com/articles/s41467-023-43387-9#Fig4); DOI `10.1038/s41467-023-43387-9`; checked 2026-10-25.
  Shown in the paper: Isoform-biotype flows between tissue groups.
  Apply it: Aggregate paired biotypes into weighted edges; isoform calling and differential usage tests are upstream.

Local runnable demos:

- **Overview of origins and destinations** · `basic`: Use case: Inspect category flows. This preset illustrates overview of origins and destinations. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_sankey_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/interactive_sankey_plot/examples/basic/manifest.json) · [Preview](../../plugins/interactive_sankey_plot/all_examples_gallery/basic.png)
  Mappings: `source_stage_column="source_stage"`, `target_stage_column="target_stage"`, `group_column="group"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): .


### UpSet · `upset`

- Guide: [source](../../plot_web/registry/guides/upset.yaml); engine: `interactive_upset_plot`.
- Status: visible in the editor.
- Purpose: Display set intersections using a membership matrix and count bars, with optional attributes.
- Input: Element IDs with set memberships in the supported wide or long layout.
- Scenarios: Compare differential-gene lists; Find shared and unique members; Inspect attributes of chosen intersections
- Reading: The dot matrix defines a combination and the bar reports its size.
- Cautions: Exact intersections, inclusive intersections and unions differ; Minimum-size filters hide rare combinations

Published figure examples:

- **Figure 3D: Shared receptor clonotypes** — Same plot grammar.
  Hao Q, Zhou T, Yan H, et al. (2026), *Molecular Cancer*. [A pan-cancer single cell landscape reveals heterogeneity and functional diversity of double-negative T cells](https://link.springer.com/article/10.1186/s12943-025-02548-8).
  Source: [figure/caption](https://link.springer.com/article/10.1186/s12943-025-02548-8/figures/3); DOI `10.1186/s12943-025-02548-8`; checked 2026-10-25.
  Shown in the paper: TCR overlap across cell subsets.
  Apply it: Use clonotype IDs and subset memberships with an explicit intersection definition.
- **Figure 4A: Overlap of altered gene sets across methods** — Same plot grammar.
  Lauria A, Peirone S, Del Giudice M, et al. (2020), *Nucleic Acids Research*. [Identification of altered biological processes in heterogeneous RNA-sequencing data by discretization of expression profiles](https://academic.oup.com/nar/article/48/4/1730/5691219).
  Source: [figure/caption](https://academic.oup.com/nar/article/48/4/1730/5691219); DOI `10.1093/nar/gkz1208`; checked 2026-10-25.
  Shown in the paper: Method-specific gene-set overlap combinations.
  Apply it: Use gene-set IDs as elements and algorithms as sets; preserve exact-intersection semantics.

Local runnable demos:

- **Exact multiset intersections** · `basic`: Use case: Compare differential-gene lists. This preset illustrates exact multiset intersections. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_upset_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/interactive_upset_plot/examples/basic/manifest.json) · [Preview](../../plugins/interactive_upset_plot/all_examples_gallery/basic.png)
  Mappings: `item_column="item_id"`, `set_columns=["A", "B", "C", "D", "E", "F", "G"]`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Highlight target intersections** · `query_highlight`: Use case: Find shared and unique members. This preset illustrates highlight target intersections. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_upset_plot/examples/query_highlight/params.json) · [Inputs and reproduction](../../plugins/interactive_upset_plot/examples/query_highlight/manifest.json) · [Preview](../../plugins/interactive_upset_plot/all_examples_gallery/query_highlight.png)
  Mappings: `item_column="item_id"`, `set_columns=["A", "B", "C", "D", "E", "F", "G"]`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Intersections and numeric attributes** · `annotated_numeric`: Use case: Inspect attributes of chosen intersections. This preset illustrates intersections and numeric attributes. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_upset_plot/examples/annotated_numeric/params.json) · [Inputs and reproduction](../../plugins/interactive_upset_plot/examples/annotated_numeric/manifest.json) · [Preview](../../plugins/interactive_upset_plot/all_examples_gallery/annotated_numeric.png)
  Mappings: `item_column="item_id"`, `set_columns=["A", "B", "C", "D", "E", "F", "G"]`, `annotation_columns=["score"]`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): .

- Method reference: [UpSet: Visualization of Intersecting Sets](https://vdl.sci.utah.edu/publications/2014_infovis_upset/) (2014).
  Relevance: Background for exact intersections, intersection sizes and attribute queries.

### Violin / Box / Point Plot · `interactive_violin_plot`

- Guide: [source](../../plot_web/registry/guides/interactive_violin_plot.yaml); engine: `interactive_violin_plot`.
- Status: visible in the editor.
- Purpose: Show grouped continuous distributions as violins with optional points and boxes.
- Input: Numeric wide observations or group/value long data.
- Scenarios: Compare expression or score distributions; Inspect multimodality and tails; Arrange distributions by condition
- Reading: Violin width represents estimated density; boxes and points show quantiles and observations.
- Cautions: Bandwidth affects apparent multimodality; Treating cells as independent replicates inflates evidence

Published figure examples:

- **Figure 6B: Immune-infiltration distributions** — Same plot grammar.
  Chen H, Liang Q, Geng L, Feng B (2025), *Scientific Reports*. [Transcriptomic exploration of key genes related to mitochondria and ferroptosis in inflammatory bowel disease and experimental validation](https://www.nature.com/articles/s41598-025-27002-z).
  Source: [figure/caption](https://www.nature.com/articles/s41598-025-27002-z#Fig6); DOI `10.1038/s41598-025-27002-z`; checked 2026-10-25.
  Shown in the paper: Groupwise infiltration-score violins.
  Apply it: Use sample-level scores and group labels; statistical testing remains a separate analysis.

Local runnable demos:

- **Grouped continuous distributions** · `basic`: Use case: Compare expression or score distributions. This preset illustrates grouped continuous distributions. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_violin_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/interactive_violin_plot/examples/basic/manifest.json) · [Preview](../../plugins/interactive_violin_plot/all_examples_gallery/basic.png)
  Mappings: `id_column="sample"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Group-value mappings from long data** · `long`: Use case: Inspect multimodality and tails. This preset illustrates group-value mappings from long data. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_violin_plot/examples/long/params.json) · [Inputs and reproduction](../../plugins/interactive_violin_plot/examples/long/manifest.json) · [Preview](../../plugins/interactive_violin_plot/all_examples_gallery/long.png)
  Mappings: `id_column="sample"`, `feature_column="feature"`, `value_column="value"`, `group_column="group"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Readable point and density layers** · `custom_layout`: Use case: Arrange distributions by condition. This preset illustrates readable point and density layers. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/interactive_violin_plot/examples/custom_layout/params.json) · [Inputs and reproduction](../../plugins/interactive_violin_plot/examples/custom_layout/manifest.json) · [Preview](../../plugins/interactive_violin_plot/all_examples_gallery/custom_layout.png)
  Mappings: `id_column="sample"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `input_mode`, `sort_by`, `top_n`, `palette`, `width`, `height`.

- Method reference: [Raincloud plots: a multi-platform tool for robust data visualization](https://wellcomeopenresearch.org/articles/4-63) (2021).
  Relevance: Explains the roles of density, raw points and summary statistics. Other distribution plots are related reading, not identical layouts.

### Line Plot · `line_plot`

- Guide: [source](../../plot_web/registry/guides/line_plot.yaml); engine: `line_plot`.
- Status: visible in the editor.
- Purpose: Connect observations over a numeric or ordered x-axis, with optional errors or smoothing.
- Input: X and Y values with optional group and error columns.
- Scenarios: Compare changes over time; Show dose-response patterns; Explore continuous-covariate trends
- Reading: Lines join ordered observations; smoothing is an estimate rather than additional observed data.
- Cautions: Categories need a meaningful connecting order; Smoothing does not establish causality or a significant trend; Enable the supplied interval band to display numeric lower and upper bounds containing each y value. Intervals are supplied by the analysis; no confidence or credible interval is inferred. Band opacity and bound-column mappings apply only when the band is enabled.

Published figure examples:

- **Figure 3E-F: Marker changes along pseudotime** — Same plot grammar.
  Hao Q, Zhou T, Yan H, et al. (2026), *Molecular Cancer*. [A pan-cancer single cell landscape reveals heterogeneity and functional diversity of double-negative T cells](https://link.springer.com/article/10.1186/s12943-025-02548-8).
  Source: [figure/caption](https://link.springer.com/article/10.1186/s12943-025-02548-8/figures/3); DOI `10.1186/s12943-025-02548-8`; checked 2026-10-25.
  Shown in the paper: Expression trends along inferred trajectories.
  Apply it: Provide ordered values or upstream fits; confidence bands and trajectory inference are not automatically reproduced.
- **Extended Data Figure 6: Age-dependent protein profiles** — Same plot grammar.
  Zhernakova DV, Sinha T, Andreu-Sanchez S, et al. (2022), *Nature Cardiovascular Research*. [Age-dependent sex differences in cardiometabolic risk factors](https://www.nature.com/articles/s44161-022-00131-8).
  Source: [figure/caption](https://www.nature.com/articles/s44161-022-00131-8); DOI `10.1038/s44161-022-00131-8`; checked 2026-10-25.
  Shown in the paper: Protein observations and fitted age trends.
  Apply it: Provide observations or upstream model predictions; local smoothing does not reproduce the original GAM inference.

Local runnable demos:

- **Grouped trends with errors** · `basic`: Use case: Compare changes over time. This preset illustrates grouped trends with errors. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/line_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/line_plot/examples/basic/manifest.json) · [Preview](../../plugins/line_plot/all_examples_gallery/basic.png)
  Mappings: `x_column="x"`, `y_column="y"`, `group_column="group"`, `se_column="se"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Smoothed continuous trends** · `smooth`: Use case: Show dose-response patterns. This preset illustrates smoothed continuous trends. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/line_plot/examples/smooth/params.json) · [Inputs and reproduction](../../plugins/line_plot/examples/smooth/manifest.json) · [Preview](../../plugins/line_plot/all_examples_gallery/smooth.png)
  Mappings: `x_column="x"`, `y_column="y"`, `group_column="group"`, `se_column="se"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Supplied interval band** · `interval_band`: Supplied interval band
  [Parameters](../../plugins/line_plot/examples/interval_band/params.json) · [Inputs and reproduction](../../plugins/line_plot/examples/interval_band/manifest.json) · [Preview](../../plugins/line_plot/all_examples_gallery/interval_band.png)
  Data provenance: Independent synthetic data; upstream inference is not performed.

Customization controls (checked against the schema): `group_column`, `x_column`, `y_column`, `palette`, `group_colors`, `base_size`, `width`, `height`.


### Lineage / trajectory · `trajectory`

- Guide: [source](../../plot_web/registry/guides/trajectory.yaml); engine: `lineage_plot`.
- Status: visible in the editor.
- Purpose: Overlay externally supplied lineage paths on an existing embedding.
- Input: Embedding coordinates, observation annotations and a separate lineage/path table.
- Scenarios: Show previously inferred differentiation paths; Focus on one lineage; Inspect observation-to-path assignments
- Reading: Paths come from input or upstream inference rather than proof from point positions.
- Cautions: Pseudotime is not elapsed time; Biological direction and branching require independent validation

Published figure examples:

- **Figure 3A: Differentiation paths on an embedding** — Related layout; adaptation required.
  Hao Q, Zhou T, Yan H, et al. (2026), *Molecular Cancer*. [A pan-cancer single cell landscape reveals heterogeneity and functional diversity of double-negative T cells](https://link.springer.com/article/10.1186/s12943-025-02548-8).
  Source: [figure/caption](https://link.springer.com/article/10.1186/s12943-025-02548-8/figures/3); DOI `10.1186/s12943-025-02548-8`; checked 2026-10-25.
  Shown in the paper: RNA-velocity trajectories on UMAP.
  Apply it: Related layout: supply precomputed paths. This plugin does not compute velocity or reproduce velocity streamlines.

Local runnable demos:

- **Overview of branching paths** · `basic`: Use case: Show previously inferred differentiation paths. This preset illustrates overview of branching paths. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/lineage_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/lineage_plot/examples/basic/manifest.json) · [Preview](../../plugins/lineage_plot/all_examples_gallery/basic.png)
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Focus on one lineage** · `single`: Use case: Focus on one lineage. This preset illustrates focus on one lineage. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/lineage_plot/examples/single/params.json) · [Inputs and reproduction](../../plugins/lineage_plot/examples/single/manifest.json) · [Preview](../../plugins/lineage_plot/all_examples_gallery/single.png)
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Observation-to-path correspondence** · `whiskers`: Use case: Inspect observation-to-path assignments. This preset illustrates observation-to-path correspondence. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/lineage_plot/examples/whiskers/params.json) · [Inputs and reproduction](../../plugins/lineage_plot/examples/whiskers/manifest.json) · [Preview](../../plugins/lineage_plot/all_examples_gallery/whiskers.png)
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): .


### Linked Heatmap + Network · `linked_matrix_network_plot`

- Guide: [source](../../plot_web/registry/guides/linked_matrix_network_plot.yaml); engine: `linked_matrix_network_plot`.
- Status: visible in the editor.
- Purpose: Link a numeric feature matrix to supplied weighted relationships.
- Input: Long feature/condition/value matrix plus a required links CSV with source, target, weight and optional group. Every link source must match a matrix feature.
- Scenarios: Link molecular measurements to supplied relationships; Summarize feature-to-drug or feature-to-pathway links; Compare a matrix and network without recomputing interactions
- Reading: Link a numeric feature matrix to supplied weighted relationships.
- Cautions: Edges are supplied relationships; the engine does not infer interactions, causal links or drug responses.; Edge width represents absolute weight; edge class colors are supplied separately and must be described.

Published figure examples:

No figure-panel association has been verified yet.

Local runnable demos:

- **Linked matrix and relationships** · `basic`: Link molecular measurements to supplied relationships
  [Parameters](../../plugins/linked_matrix_network_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/linked_matrix_network_plot/examples/basic/manifest.json) · [Preview](../../plugins/linked_matrix_network_plot/all_examples_gallery/basic.png)
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Dot matrix and relationships** · `dot_matrix`: Summarize feature-to-drug or feature-to-pathway links
  [Parameters](../../plugins/linked_matrix_network_plot/examples/dot_matrix/params.json) · [Inputs and reproduction](../../plugins/linked_matrix_network_plot/examples/dot_matrix/manifest.json) · [Preview](../../plugins/linked_matrix_network_plot/all_examples_gallery/dot_matrix.png)
  Data provenance: Independent synthetic demonstration, not original publication data.

Customization controls (checked against the schema): `row_column`, `column_column`, `value_column`, `edge_group_column`, `matrix_mark`, `node_gap`, `dot_size`, `curvature`, `edge_alpha`, `point_size`, `line_width`, `low_color`, `high_color`, `palette`, `group_colors`, `label_size`, `title`, `subtitle`, `caption`, `title_size`, `legend_show`, `legend_position`, `legend_text_size`, `font_family`, `base_size`, `plot_background`, `grid_show`, `width`, `height`, `dpi`.

- Method reference: [FigureYa: A Standardized Visualization Framework for Enhancing Biomedical Data Interpretation and Research Efficiency](https://github.com/ying-ge/FigureYa) (2025).
  Relevance: Compare the required input shape and intended visualization with the corresponding source module; upstream analyses are not automatically reproduced.

### Manhattan / QQ · `manhattan_qq_plot`

- Guide: [source](../../plot_web/registry/guides/manhattan_qq_plot.yaml); engine: `manhattan_qq_plot`.
- Status: visible in the editor.
- Purpose: Display genomic association probabilities and their expected-quantile comparison.
- Input: Raw probabilities in (0,1], plus chromosome and nonnegative genomic position for Manhattan views. Optional nonempty labels identify selected loci.
- Scenarios: Locate genomic association signals; Check the distribution of supplied association probabilities; Label selected loci without changing significance thresholds
- Reading: Display genomic association probabilities and their expected-quantile comparison. Raw probabilities in (0,1], plus chromosome and nonnegative genomic position for Manhattan views. Optional nonempty labels identify selected loci.
- Cautions: Rounded zero probabilities are rejected rather than silently floored. Select a justified detection bound upstream.; A QQ deviation alone does not identify population structure or establish biological significance.

Published figure examples:

No figure-panel association has been verified yet.

Local runnable demos:

- **Association overview** · `basic`: Locate genomic association signals
  [Parameters](../../plugins/manhattan_qq_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/manhattan_qq_plot/examples/basic/manifest.json) · [Preview](../../plugins/manhattan_qq_plot/all_examples_gallery/basic.png)
  Mappings: `pvalue_column="pvalue"`, `chromosome_column="chromosome"`, `position_column="position"`, `label_column="label"`
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Genomic association signals** · `manhattan`: Check the distribution of supplied association probabilities
  [Parameters](../../plugins/manhattan_qq_plot/examples/manhattan/params.json) · [Inputs and reproduction](../../plugins/manhattan_qq_plot/examples/manhattan/manifest.json) · [Preview](../../plugins/manhattan_qq_plot/all_examples_gallery/manhattan.png)
  Mappings: `pvalue_column="pvalue"`, `chromosome_column="chromosome"`, `position_column="position"`, `label_column="label"`
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Expected and observed probabilities** · `qq`: Label selected loci without changing significance thresholds
  [Parameters](../../plugins/manhattan_qq_plot/examples/qq/params.json) · [Inputs and reproduction](../../plugins/manhattan_qq_plot/examples/qq/manifest.json) · [Preview](../../plugins/manhattan_qq_plot/all_examples_gallery/qq.png)
  Mappings: `pvalue_column="pvalue"`, `chromosome_column="chromosome"`, `position_column="position"`, `label_column="label"`
  Data provenance: Independent synthetic demonstration, not original publication data.

Customization controls (checked against the schema): `pvalue_column`, `chromosome_column`, `position_column`, `label_column`, `plot_type`, `pvalue_threshold`, `threshold_color`, `qq_color`, `palette`, `group_colors`, `label_show`, `label_size`, `title`, `subtitle`, `caption`, `title_size`, `point_alpha`, `point_size`, `line_width`, `font_family`, `base_size`, `plot_background`, `grid_show`, `width`, `height`, `dpi`.

- Method reference: [FigureYa: A Standardized Visualization Framework for Enhancing Biomedical Data Interpretation and Research Efficiency](https://github.com/ying-ge/FigureYa) (2025).
  Relevance: Compare the required input shape and intended visualization with the corresponding source module; upstream analyses are not automatically reproduced.

### Nomogram Scales · `nomogram_plot`

- Guide: [source](../../plot_web/registry/guides/nomogram_plot.yaml); engine: `nomogram_plot`.
- Status: visible in the editor.
- Purpose: Display supplied predictor point scales and total-point outcome mappings.
- Input: Supplied scale name, normalized tick position in [0,1] and display label. Predictor-to-point and outcome mappings must be derived upstream from a fitted model.
- Scenarios: Publish supplied predictor point scales; Display total-point to outcome mappings; Assemble a model-derived scale layout without refitting the model
- Reading: Display supplied predictor point scales and total-point outcome mappings. Supplied scale name, normalized tick position in [0,1] and display label. Predictor-to-point and outcome mappings must be derived upstream from a fitted model.
- Cautions: The plugin draws supplied scales and does not fit, validate or calibrate a prediction model.; Normalized positions are layout coordinates. Patient risk cannot be calculated from an arbitrary scale drawing.

Published figure examples:

No figure-panel association has been verified yet.

Local runnable demos:

- **Supplied predictor point scales** · `basic`: Publish supplied predictor point scales
  [Parameters](../../plugins/nomogram_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/nomogram_plot/examples/basic/manifest.json) · [Preview](../../plugins/nomogram_plot/all_examples_gallery/basic.png)
  Mappings: `group_column="scale"`, `position_column="position"`, `label_column="label"`
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Supplied total-point outcome mapping** · `compact`: Display total-point to outcome mappings
  [Parameters](../../plugins/nomogram_plot/examples/compact/params.json) · [Inputs and reproduction](../../plugins/nomogram_plot/examples/compact/manifest.json) · [Preview](../../plugins/nomogram_plot/all_examples_gallery/compact.png)
  Mappings: `group_column="scale"`, `position_column="position"`, `label_column="label"`
  Data provenance: Independent synthetic demonstration, not original publication data.

Customization controls (checked against the schema): `group_column`, `position_column`, `label_column`, `line_color`, `label_show`, `label_size`, `title`, `subtitle`, `caption`, `title_size`, `line_width`, `font_family`, `base_size`, `plot_background`, `width`, `height`, `dpi`.

- Method reference: [FigureYa: A Standardized Visualization Framework for Enhancing Biomedical Data Interpretation and Research Efficiency](https://github.com/ying-ge/FigureYa) (2025).
  Relevance: Compare the required input shape and intended visualization with the corresponding source module; upstream analyses are not automatically reproduced.

### Mutation Matrix · `oncoprint_plot`

- Guide: [source](../../plot_web/registry/guides/oncoprint_plot.yaml); engine: `oncoprint_plot`.
- Status: visible in the editor.
- Purpose: Show multiple alteration types per gene and sample with marginal frequencies.
- Input: Long table of gene, sample and alteration type. Multiple rows per gene/sample represent distinct types. None/WT marks no supplied alteration; all evaluated samples must be present.
- Scenarios: Summarize mutation and copy-number alterations; Identify samples with multiple alteration types; Compare altered-sample frequencies across genes
- Reading: Show multiple alteration types per gene and sample with marginal frequencies. Long table of gene, sample and alteration type. Multiple rows per gene/sample represent distinct types. None/WT marks no supplied alteration; all evaluated samples must be present.
- Cautions: Missing input coverage is not evidence of wild type. Include every evaluated sample, including explicit no-alteration entries.; Multiple alteration types share a cell; slice height does not encode allele fraction or variant count.

Published figure examples:

No figure-panel association has been verified yet.

Local runnable demos:

- **Multi-hit alteration matrix** · `basic`: Summarize mutation and copy-number alterations
  [Parameters](../../plugins/oncoprint_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/oncoprint_plot/examples/basic/manifest.json) · [Preview](../../plugins/oncoprint_plot/all_examples_gallery/basic.png)
  Mappings: `feature_column="gene"`, `sample_column="sample"`, `group_column="alteration"`
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Input-order alteration matrix** · `input_order`: Identify samples with multiple alteration types
  [Parameters](../../plugins/oncoprint_plot/examples/input_order/params.json) · [Inputs and reproduction](../../plugins/oncoprint_plot/examples/input_order/manifest.json) · [Preview](../../plugins/oncoprint_plot/all_examples_gallery/input_order.png)
  Mappings: `feature_column="gene"`, `sample_column="sample"`, `group_column="alteration"`
  Data provenance: Independent synthetic demonstration, not original publication data.

Customization controls (checked against the schema): `feature_column`, `sample_column`, `group_column`, `row_order`, `frequency_show`, `sample_label_show`, `title`, `subtitle`, `caption`, `title_size`, `empty_color`, `frequency_color`, `palette`, `group_colors`, `legend_show`, `legend_position`, `legend_text_size`, `font_family`, `base_size`, `plot_background`, `width`, `height`, `dpi`.

- Method reference: [FigureYa: A Standardized Visualization Framework for Enhancing Biomedical Data Interpretation and Research Efficiency](https://github.com/ying-ge/FigureYa) (2025).
  Relevance: Compare the required input shape and intended visualization with the corresponding source module; upstream analyses are not automatically reproduced.

### Pie Dot Matrix (Ratio Circles) · `pie_dot_matrix`

- Guide: [source](../../plot_web/registry/guides/pie_dot_matrix.yaml); engine: `pie_dot_matrix`.
- Status: hidden; documentation source only.
- Purpose: Use ratio or segmented circles in a matrix to show fractions, binary states or correlations.
- Input: Row/column identifiers and proportions, states or coefficients appropriate to the active mode.
- Scenarios: Compare detection fractions; Inspect binary feature states; Survey correlation direction and strength
- Reading: Read circle filling or segmentation using the active mode's legend.
- Cautions: Specify the denominator for proportions; Binary states and continuous correlations do not share the same interpretation

Published figure examples:

- **Figure 2G: Projection-positive fractions** — Related layout; adaptation required.
  Yang L, Liu F, Hahm H, et al. (2025), *Nature Communications*. [Projection-TAGs enable multiplex projection tracing and multi-modal profiling of projection neurons](https://www.nature.com/articles/s41467-025-60360-w).
  Source: [figure/caption](https://www.nature.com/articles/s41467-025-60360-w#Fig2); DOI `10.1038/s41467-025-60360-w`; checked 2026-10-25.
  Shown in the paper: Projection-positive fractions across transcriptional clusters.
  Apply it: Use fractions with explicit denominators. Ratio-circle mode is an alternative encoding rather than the paper's exact dot styling.

Local runnable demos:

- **Ratio-circle matrix** · `basic`: Use case: Compare detection fractions. This preset illustrates ratio-circle matrix. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/pie_dot_matrix/examples/basic/params.json) · [Inputs and reproduction](../../plugins/pie_dot_matrix/examples/basic/manifest.json) · [Preview](../../plugins/pie_dot_matrix/all_examples_gallery/basic.png)
  Mappings: `row_column="category"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Binary feature states** · `binary`: Use case: Inspect binary feature states. This preset illustrates binary feature states. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/pie_dot_matrix/examples/binary/params.json) · [Inputs and reproduction](../../plugins/pie_dot_matrix/examples/binary/manifest.json) · [Preview](../../plugins/pie_dot_matrix/all_examples_gallery/binary.png)
  Mappings: `row_column="category"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Correlation-strength matrix** · `correlation`: Use case: Survey correlation direction and strength. This preset illustrates correlation-strength matrix. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/pie_dot_matrix/examples/correlation/params.json) · [Inputs and reproduction](../../plugins/pie_dot_matrix/examples/correlation/manifest.json) · [Preview](../../plugins/pie_dot_matrix/all_examples_gallery/correlation.png)
  Mappings: `row_column="category"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `input_mode`, `value_column`, `palette`, `base_size`, `width`, `height`.


### Protein Variant Map · `protein_variant_plot`

- Guide: [source](../../plot_web/registry/guides/protein_variant_plot.yaml); engine: `protein_variant_plot`.
- Status: visible in the editor.
- Purpose: Place variant counts and annotated domains on a protein coordinate.
- Input: Protein residue position (1-based), supplied count, optional variant label/group. Optional domains CSV has start, end and domain.
- Scenarios: Locate recurrent variants along a protein; Relate variant positions to supplied domains; Compare supplied variant counts and classes
- Reading: Place variant counts and annotated domains on a protein coordinate. Protein residue position (1-based), supplied count, optional variant label/group. Optional domains CSV has start, end and domain.
- Cautions: Protein coordinates are 1-based residue coordinates, not genomic base-pair positions.; The plugin does not annotate variants or infer pathogenicity. Domain positions and protein length are supplied.

Published figure examples:

No figure-panel association has been verified yet.

Local runnable demos:

- **Protein variants and domains** · `basic`: Locate recurrent variants along a protein
  [Parameters](../../plugins/protein_variant_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/protein_variant_plot/examples/basic/manifest.json) · [Preview](../../plugins/protein_variant_plot/all_examples_gallery/basic.png)
  Mappings: `position_column="position"`, `value_column="count"`, `label_column="variant"`, `group_column="group"`
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Variant count profile** · `variants_only`: Relate variant positions to supplied domains
  [Parameters](../../plugins/protein_variant_plot/examples/variants_only/params.json) · [Inputs and reproduction](../../plugins/protein_variant_plot/examples/variants_only/manifest.json) · [Preview](../../plugins/protein_variant_plot/all_examples_gallery/variants_only.png)
  Mappings: `position_column="position"`, `value_column="count"`, `label_column="variant"`, `group_column="group"`
  Data provenance: Independent synthetic demonstration, not original publication data.

Customization controls (checked against the schema): `position_column`, `value_column`, `label_column`, `group_column`, `protein_length`, `domain_show`, `point_size`, `line_width`, `label_show`, `label_size`, `title`, `subtitle`, `caption`, `title_size`, `palette`, `group_colors`, `legend_show`, `legend_position`, `legend_text_size`, `font_family`, `base_size`, `plot_background`, `grid_show`, `width`, `height`, `dpi`.

- Method reference: [FigureYa: A Standardized Visualization Framework for Enhancing Biomedical Data Interpretation and Research Efficiency](https://github.com/ying-ge/FigureYa) (2025).
  Relevance: Compare the required input shape and intended visualization with the corresponding source module; upstream analyses are not automatically reproduced.

### Quadrant Correlation Scatter · `quadrant_correlation_scatter`

- Guide: [source](../../plot_web/registry/guides/quadrant_correlation_scatter.yaml); engine: `quadrant_correlation_scatter`.
- Status: visible in the editor.
- Purpose: Add threshold regions, correlation summaries and selected labels to a two-variable scatter plot.
- Input: Two numeric columns and optional item IDs; configure thresholds or custom regions.
- Scenarios: Compare directions of two effects; Find concordant and opposing changes; Locate selected candidates
- Reading: Coordinates encode the two input values; regions are defined by explicit thresholds.
- Cautions: Threshold regions are not significance tests; Overall correlation does not describe every region separately

Published figure examples:

- **Figure 4D: Compare two differential effects** — Same plot grammar.
  Hao Q, Zhou T, Yan H, et al. (2026), *Molecular Cancer*. [A pan-cancer single cell landscape reveals heterogeneity and functional diversity of double-negative T cells](https://link.springer.com/article/10.1186/s12943-025-02548-8).
  Source: [figure/caption](https://link.springer.com/article/10.1186/s12943-025-02548-8/figures/4); DOI `10.1186/s12943-025-02548-8`; checked 2026-10-25.
  Shown in the paper: Effects in two tissue contrasts.
  Apply it: Choose biologically justified thresholds; probability-driven mark encodings require compatible fields.

Local runnable demos:

- **Two-effect threshold regions and candidate labels** · `params`: Use case: Compare directions of two effects. This preset illustrates two-effect threshold regions and candidate labels. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/quadrant_correlation_scatter/examples/params/params.json) · [Inputs and reproduction](../../plugins/quadrant_correlation_scatter/examples/params/manifest.json) · [Preview](../../plugins/quadrant_correlation_scatter/all_examples_gallery/params.png)
  Mappings: `label_column="gene"`, `x_column="x_ratio"`, `y_column="y_ratio"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `x_column`, `y_column`, `label_show`, `width`, `height`.


### Wheel / RadViz · `radviz_plot`

- Guide: [source](../../plot_web/registry/guides/radviz_plot.yaml); engine: `radviz_plot`.
- Status: visible in the editor.
- Purpose: Project nonnegative feature weights toward labeled vertices of a wheel.
- Input: 3–12 numeric feature columns in desired vertex order, plus optional group. Row-sum mode requires nonnegative weights. Zero-total rows are reported and omitted.
- Scenarios: Summarize nonnegative program weights; Compare observations against multiple feature vertices; Inspect an explicitly chosen feature normalization
- Reading: Project nonnegative feature weights toward labeled vertices of a wheel. 3–12 numeric feature columns in desired vertex order, plus optional group. Row-sum mode requires nonnegative weights. Zero-total rows are reported and omitted.
- Cautions: Vertex order and normalization affect the projection; record both. Nearby observations need not have identical profiles.; Negative feature values require explicit feature-minmax normalization; no trajectory is inferred.

Published figure examples:

No figure-panel association has been verified yet.

Local runnable demos:

- **Feature-weight wheel** · `basic`: Summarize nonnegative program weights
  [Parameters](../../plugins/radviz_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/radviz_plot/examples/basic/manifest.json) · [Preview](../../plugins/radviz_plot/all_examples_gallery/basic.png)
  Mappings: `group_column="group"`
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Feature-scaled wheel** · `minmax`: Compare observations against multiple feature vertices
  [Parameters](../../plugins/radviz_plot/examples/minmax/params.json) · [Inputs and reproduction](../../plugins/radviz_plot/examples/minmax/manifest.json) · [Preview](../../plugins/radviz_plot/all_examples_gallery/minmax.png)
  Mappings: `group_column="group"`
  Data provenance: Independent synthetic demonstration, not original publication data.

Customization controls (checked against the schema): `feature_columns`, `group_column`, `normalization`, `spoke_show`, `point_alpha`, `point_size`, `line_width`, `label_size`, `title`, `subtitle`, `caption`, `title_size`, `palette`, `group_colors`, `legend_show`, `legend_position`, `legend_text_size`, `font_family`, `base_size`, `plot_background`, `width`, `height`, `dpi`.

- Method reference: [FigureYa: A Standardized Visualization Framework for Enhancing Biomedical Data Interpretation and Research Efficiency](https://github.com/ying-ge/FigureYa) (2025).
  Relevance: Compare the required input shape and intended visualization with the corresponding source module; upstream analyses are not automatically reproduced.

### Raincloud Plot · `raincloud_plot`

- Guide: [source](../../plot_web/registry/guides/raincloud_plot.yaml); engine: `raincloud_plot`.
- Status: visible in the editor.
- Purpose: Combine a half-violin, box and raw points to show distribution, quantiles and individual observations.
- Input: Group/value long data with optional sample or condition columns.
- Scenarios: Compare continuous phenotypes; Show raw small-sample observations; Inspect heterogeneity behind averages
- Reading: The cloud shows density, the box shows quantiles and the points show observations.
- Cautions: Jitter position has no extra numeric meaning; Density estimates can be unstable for very small samples

Published figure examples:

- **Figure 3: Anatomy of a raincloud plot** — Same plot grammar.
  Allen M, Poggiali D, Whitaker K, Marshall TR, Kievit RA (2021), *Wellcome Open Research*. [Raincloud plots: a multi-platform tool for robust data visualization](https://wellcomeopenresearch.org/articles/4-63).
  Source: [figure/caption](https://pmc.ncbi.nlm.nih.gov/articles/PMC6480976/); DOI `10.12688/wellcomeopenres.15191.2`; checked 2026-10-25.
  Shown in the paper: Density, observations and a box summary.
  Apply it: Use individual values and group labels; retain the distinct roles of density and observed points.
- **Figure 7: Participant-level outcome distributions** — Same plot grammar.
  Ari I, De Tommaso D, Wykowska A (2025), *Scientific Reports*. [Producing unexpected emotional expressions in others reduces one's own agency](https://www.nature.com/articles/s41598-025-25703-z).
  Source: [figure/caption](https://www.nature.com/articles/s41598-025-25703-z#Fig7); DOI `10.1038/s41598-025-25703-z`; checked 2026-10-25.
  Shown in the paper: Participant means, densities and box summaries.
  Apply it: Use participant-level observations; repeated-measures connectors and model-estimated means in the paper require additional analysis or annotations.

Local runnable demos:

- **Horizontal distributions with observations** · `basic`: Use case: Compare continuous phenotypes. This preset illustrates horizontal distributions with observations. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/raincloud_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/raincloud_plot/examples/basic/manifest.json) · [Preview](../../plugins/raincloud_plot/all_examples_gallery/basic.png)
  Mappings: `value_column="value"`, `group_column="group"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Vertical distribution comparison** · `vertical`: Use case: Show raw small-sample observations. This preset illustrates vertical distribution comparison. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/raincloud_plot/examples/vertical/params.json) · [Inputs and reproduction](../../plugins/raincloud_plot/examples/vertical/manifest.json) · [Preview](../../plugins/raincloud_plot/all_examples_gallery/vertical.png)
  Mappings: `value_column="value"`, `group_column="group"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `group_column`, `value_column`, `palette`, `group_colors`, `base_size`, `width`, `height`.


### Ranked Annotation Panel · `ranked_annotation_panel`

- Guide: [source](../../plot_web/registry/guides/ranked_annotation_panel.yaml); engine: `ranked_annotation_panel`.
- Status: visible in the editor.
- Purpose: Align a ranked numeric panel with multiple continuous or categorical annotations.
- Input: Item labels, ranking scores and annotation columns with configurable types.
- Scenarios: Link candidate rankings to annotations; Compare evidence for high-ranked items; Inspect sample or clinical attributes
- Reading: The left panel shows the selected value; each annotation column has its own color meaning.
- Cautions: Annotation columns may use different scales; A selected ranking does not represent the entire population

Published figure examples:

- **Figure 4B: Ranked pathways with evidence annotations** — Related layout; adaptation required.
  Lauria A, Peirone S, Del Giudice M, et al. (2020), *Nucleic Acids Research*. [Identification of altered biological processes in heterogeneous RNA-sequencing data by discretization of expression profiles](https://academic.oup.com/nar/article/48/4/1730/5691219).
  Source: [figure/caption](https://academic.oup.com/nar/article/48/4/1730/5691219); DOI `10.1093/nar/gkz1208`; checked 2026-10-25.
  Shown in the paper: Pathway ranks aligned with annotation columns.
  Apply it: Related layout: the paper displays a rank heatmap; choose one rank/score for the local left numeric panel and supply annotation columns separately.

Local runnable demos:

- **Candidate ranking with multiple annotations** · `params`: Use case: Link candidate rankings to annotations. This preset illustrates candidate ranking with multiple annotations. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/ranked_annotation_panel/examples/params/params.json) · [Inputs and reproduction](../../plugins/ranked_annotation_panel/examples/params/manifest.json) · [Preview](../../plugins/ranked_annotation_panel/all_examples_gallery/params.png)
  Mappings: `row_label_column="feature"`, `left_value_column="score"`, `annotation_columns=["L13", "L18", "L6"]`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `row_label_column`, `width`, `height`.


### Regression Scatter Plot · `regression_scatter_plot`

- Guide: [source](../../plot_web/registry/guides/regression_scatter_plot.yaml); engine: `regression_scatter_plot`.
- Status: visible in the editor.
- Purpose: Show the relationship between two numeric variables using scatter and fitted trends.
- Input: Two numeric columns with optional group and label fields.
- Scenarios: Explore dose-response relationships; Compare experimental metrics; Inspect model fit and outliers
- Reading: Points represent observations and the fit summarizes the chosen model.
- Cautions: Regression or correlation does not establish causation; Nonlinearity, outliers and dependent observations affect inference

Published figure examples:

- **Figure 6M: Compare cytokine enrichment contrasts** — Same plot grammar.
  Hao Q, Zhou T, Yan H, et al. (2026), *Molecular Cancer*. [A pan-cancer single cell landscape reveals heterogeneity and functional diversity of double-negative T cells](https://link.springer.com/article/10.1186/s12943-025-02548-8).
  Source: [figure/caption](https://link.springer.com/article/10.1186/s12943-025-02548-8/figures/6); DOI `10.1186/s12943-025-02548-8`; checked 2026-10-25.
  Shown in the paper: Cytokine scores compared across contrasts.
  Apply it: Provide the two score columns and report the chosen association statistic; no causal claim follows.
- **Extended Data Figure 12D: Reproducibility across biological replicates** — Same plot grammar.
  Li YE, Preissl S, Hou X, et al. (2021), *Nature*. [An atlas of gene regulatory elements in adult mouse cerebrum](https://www.nature.com/articles/s41586-021-03604-1).
  Source: [figure/caption](https://www.nature.com/articles/s41586-021-03604-1); DOI `10.1038/s41586-021-03604-1`; checked 2026-10-25.
  Shown in the paper: Regional-specificity scores between replicates.
  Apply it: Match corresponding population IDs and report the chosen correlation or fit.
- **Extended Data Figure 6: Age-dependent protein profiles** — Same plot grammar.
  Zhernakova DV, Sinha T, Andreu-Sanchez S, et al. (2022), *Nature Cardiovascular Research*. [Age-dependent sex differences in cardiometabolic risk factors](https://www.nature.com/articles/s44161-022-00131-8).
  Source: [figure/caption](https://www.nature.com/articles/s44161-022-00131-8); DOI `10.1038/s44161-022-00131-8`; checked 2026-10-25.
  Shown in the paper: Protein observations and fitted age trends.
  Apply it: Provide observations or upstream model predictions; local smoothing does not reproduce the original GAM inference.

Local runnable demos:

- **Two-variable scatter and fit** · `basic`: Use case: Explore dose-response relationships. This preset illustrates two-variable scatter and fit. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/regression_scatter_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/regression_scatter_plot/examples/basic/manifest.json) · [Preview](../../plugins/regression_scatter_plot/all_examples_gallery/basic.png)
  Mappings: `x_column="x"`, `y_column="y"`, `group_column="group"`, `id_column="id"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Reference-style regression presentation** · `CAB_demo`: Use case: Compare experimental metrics. This preset illustrates reference-style regression presentation. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/regression_scatter_plot/examples/CAB_demo/params.json) · [Inputs and reproduction](../../plugins/regression_scatter_plot/examples/CAB_demo/manifest.json) · [Preview](../../plugins/regression_scatter_plot/all_examples_gallery/CAB_demo.png)
  Mappings: `x_column="x"`, `y_column="y"`, `group_column="group"`, `id_column="id"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `group_column`, `x_column`, `y_column`, `group_colors`, `width`, `height`.


### Risk Stratification Panel · `risk_stratification_panel`

- Guide: [source](../../plot_web/registry/guides/risk_stratification_panel.yaml); engine: `risk_stratification_panel`.
- Status: visible in the editor.
- Purpose: Align supplied risk ranks, event follow-up and selected numeric features.
- Input: One row per unique subject with supplied risk_score, nonnegative follow-up time, event 0/1 and optional group. Optional numeric feature_columns form the aligned heatmap.
- Scenarios: Inspect supplied scores in risk order; Align event follow-up with subject scores; Compare selected feature profiles across the same ranked subjects
- Reading: Align supplied risk ranks, event follow-up and selected numeric features.
- Cautions: Risk scores and groups are supplied. No survival model, optimal cutoff or group assignment is inferred.; Displayed follow-up points are not survival estimates. Per-feature Z-scores are a display transform, not a differential-expression test.

Published figure examples:

No figure-panel association has been verified yet.

Local runnable demos:

- **Aligned risk and follow-up** · `basic`: Inspect supplied scores in risk order
  [Parameters](../../plugins/risk_stratification_panel/examples/basic/params.json) · [Inputs and reproduction](../../plugins/risk_stratification_panel/examples/basic/manifest.json) · [Preview](../../plugins/risk_stratification_panel/all_examples_gallery/basic.png)
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Scores and follow-up** · `scores_only`: Align event follow-up with subject scores
  [Parameters](../../plugins/risk_stratification_panel/examples/scores_only/params.json) · [Inputs and reproduction](../../plugins/risk_stratification_panel/examples/scores_only/manifest.json) · [Preview](../../plugins/risk_stratification_panel/all_examples_gallery/scores_only.png)
  Data provenance: Independent synthetic demonstration, not original publication data.

Customization controls (checked against the schema): `id_column`, `value_column`, `time_column`, `event_column`, `group_column`, `feature_columns`, `sort_by`, `heatmap_show`, `scale_features`, `subject_label_show`, `title`, `subtitle`, `caption`, `title_size`, `point_alpha`, `point_size`, `low_color`, `high_color`, `palette`, `group_colors`, `legend_show`, `legend_position`, `legend_text_size`, `font_family`, `base_size`, `plot_background`, `grid_show`, `width`, `height`, `dpi`.

- Method reference: [FigureYa: A Standardized Visualization Framework for Enhancing Biomedical Data Interpretation and Research Efficiency](https://github.com/ying-ge/FigureYa) (2025).
  Relevance: Compare the required input shape and intended visualization with the corresponding source module; upstream analyses are not automatically reproduced.

### Volcano · `volcano`

- Guide: [source](../../plot_web/registry/guides/volcano.yaml); engine: `sca_volcano_plot`.
- Status: visible in the editor.
- Purpose: Plot differential effects against statistical evidence, with configurable regions and highlights.
- Input: Upstream differential-analysis results containing features, effects and raw or adjusted probabilities.
- Scenarios: Find large well-supported changes; Compare upregulated and downregulated features; Explain differential-selection thresholds
- Reading: The x-axis shows an effect; the y-axis generally shows a negative-log probability, as labelled.
- Cautions: State the contrast direction and whether probabilities are adjusted; Display filters cannot replace an appropriate replicate design and model

Published figure examples:

- **Figure 1A: Differential expression in IBD** — Same plot grammar.
  Chen H, Liang Q, Geng L, Feng B (2025), *Scientific Reports*. [Transcriptomic exploration of key genes related to mitochondria and ferroptosis in inflammatory bowel disease and experimental validation](https://www.nature.com/articles/s41598-025-27002-z).
  Source: [figure/caption](https://www.nature.com/articles/s41598-025-27002-z#Fig1); DOI `10.1038/s41598-025-27002-z`; checked 2026-10-25.
  Shown in the paper: Effects versus differential-expression evidence.
  Apply it: Map effect and adjusted probability columns without recomputing statistics in the plot.
- **Figure 4F: Differential transcript-end usage** — Same plot grammar.
  Dondi A, Lischetti U, Jacob F, et al. (2023), *Nature Communications*. [Detection of isoforms and genomic alterations by high-throughput full-length single-cell RNA sequencing in ovarian cancer](https://www.nature.com/articles/s41467-023-43387-9).
  Source: [figure/caption](https://www.nature.com/articles/s41467-023-43387-9#Fig4); DOI `10.1038/s41467-023-43387-9`; checked 2026-10-25.
  Shown in the paper: Fraction changes versus adjusted probabilities.
  Apply it: Use the reported fraction-change statistic rather than silently relabelling it as log fold change.

Local runnable demos:

- **Average-expression differential effects** · `avg`: Use case: Find large well-supported changes. This preset illustrates average-expression differential effects. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/sca_volcano_plot/examples/avg/params.json) · [Inputs and reproduction](../../plugins/sca_volcano_plot/examples/avg/manifest.json) · [Preview](../../plugins/sca_volcano_plot/all_examples_gallery/avg.png)
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Detection-fraction differential view** · `percent`: Use case: Compare upregulated and downregulated features. This preset illustrates detection-fraction differential view. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/sca_volcano_plot/examples/percent/params.json) · [Inputs and reproduction](../../plugins/sca_volcano_plot/examples/percent/manifest.json) · [Preview](../../plugins/sca_volcano_plot/all_examples_gallery/percent.png)
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Threshold regions and candidate labels** · `regions`: Use case: Explain differential-selection thresholds. This preset illustrates threshold regions and candidate labels. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/sca_volcano_plot/examples/regions/params.json) · [Inputs and reproduction](../../plugins/sca_volcano_plot/examples/regions/manifest.json) · [Preview](../../plugins/sca_volcano_plot/all_examples_gallery/regions.png)
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): .


### Sequence Alignment · `sequence_alignment_plot`

- Guide: [source](../../plot_web/registry/guides/sequence_alignment_plot.yaml); engine: `sequence_alignment_plot`.
- Status: visible in the editor.
- Purpose: Display aligned DNA or protein sequences with consensus conservation.
- Input: Unique sequence IDs and equal-length pre-aligned DNA/protein strings, including dash gaps. Alignment is not computed.
- Scenarios: Inspect a pre-aligned sequence family; Compare residue substitutions and gaps; Summarize per-position consensus fractions
- Reading: Display aligned DNA or protein sequences with consensus conservation. Unique sequence IDs and equal-length pre-aligned DNA/protein strings, including dash gaps. Alignment is not computed.
- Cautions: The plugin displays an existing alignment and does not choose an alignment algorithm.; Consensus is the most frequent nongap residue count divided by sequence count, not entropy or a phylogenetic test.

Published figure examples:

No figure-panel association has been verified yet.

Local runnable demos:

- **Aligned nucleotide sequences** · `basic`: Inspect a pre-aligned sequence family
  [Parameters](../../plugins/sequence_alignment_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/sequence_alignment_plot/examples/basic/manifest.json) · [Preview](../../plugins/sequence_alignment_plot/all_examples_gallery/basic.png)
  Mappings: `id_column="sequence_id"`, `sequence_column="sequence"`
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Aligned protein sequences** · `protein`: Compare residue substitutions and gaps
  [Parameters](../../plugins/sequence_alignment_plot/examples/protein/params.json) · [Inputs and reproduction](../../plugins/sequence_alignment_plot/examples/protein/manifest.json) · [Preview](../../plugins/sequence_alignment_plot/all_examples_gallery/protein.png)
  Mappings: `id_column="sequence_id"`, `sequence_column="sequence"`
  Data provenance: Independent synthetic demonstration, not original publication data.

Customization controls (checked against the schema): `id_column`, `sequence_column`, `alphabet`, `residue_show`, `conservation_show`, `conservation_color`, `palette`, `group_colors`, `label_size`, `title`, `subtitle`, `caption`, `title_size`, `legend_show`, `legend_position`, `legend_text_size`, `font_family`, `base_size`, `plot_background`, `width`, `height`, `dpi`.

- Method reference: [FigureYa: A Standardized Visualization Framework for Enhancing Biomedical Data Interpretation and Research Efficiency](https://github.com/ying-ge/FigureYa) (2025).
  Relevance: Compare the required input shape and intended visualization with the corresponding source module; upstream analyses are not automatically reproduced.

### Spatial Region Map · `spatial_region_plot`

- Guide: [source](../../plot_web/registry/guides/spatial_region_plot.yaml); engine: `spatial_region_plot`.
- Status: visible in the editor.
- Purpose: Color supplied anatomical or tissue-region polygons by numeric measurements.
- Input: Ordered x/y polygon vertices, region ID and one numeric value per region; optional part IDs for multipart polygons. PNG overlays require top-left-origin image pixel coordinates and invert_y.
- Scenarios: Map region-level expression measurements; Color supplied anatomical polygons; Overlay supplied regions on a synthetic or uploaded PNG tissue image
- Reading: Color supplied anatomical or tissue-region polygons by numeric measurements. Ordered x/y polygon vertices, region ID and one numeric value per region; optional part IDs for multipart polygons. PNG overlays require top-left-origin image pixel coordinates and invert_y.
- Cautions: Geometry is supplied; the plugin does not segment tissue or provide a built-in anatomical atlas.; PNG overlays require matched pixel coordinates. Polygon labels are approximate and should be visually checked for concave regions.; Choose polygon geometry for ordered boundary vertices or spot geometry for independent measured coordinates. Spot size applies only to spots. Optional PNG backgrounds use pixel coordinates and require an inverted y axis.

Published figure examples:

No figure-panel association has been verified yet.

Local runnable demos:

- **Measured tissue regions** · `basic`: Map region-level expression measurements
  [Parameters](../../plugins/spatial_region_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/spatial_region_plot/examples/basic/manifest.json) · [Preview](../../plugins/spatial_region_plot/all_examples_gallery/basic.png)
  Mappings: `x_column="x"`, `y_column="y"`, `group_column="region"`, `value_column="value"`, `part_column="part"`
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Regions over a synthetic tissue background** · `tissue`: Color supplied anatomical polygons
  [Parameters](../../plugins/spatial_region_plot/examples/tissue/params.json) · [Inputs and reproduction](../../plugins/spatial_region_plot/examples/tissue/manifest.json) · [Preview](../../plugins/spatial_region_plot/all_examples_gallery/tissue.png)
  Mappings: `x_column="x"`, `y_column="y"`, `group_column="region"`, `value_column="value"`, `part_column="part"`
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Measured spatial spots** · `spots`: Measured spatial spots
  [Parameters](../../plugins/spatial_region_plot/examples/spots/params.json) · [Inputs and reproduction](../../plugins/spatial_region_plot/examples/spots/manifest.json) · [Preview](../../plugins/spatial_region_plot/all_examples_gallery/spots.png)
  Data provenance: Independent synthetic data; upstream inference is not performed.

Customization controls (checked against the schema): `x_column`, `y_column`, `group_column`, `value_column`, `part_column`, `invert_y`, `label_show`, `label_size`, `title`, `subtitle`, `caption`, `title_size`, `fill_alpha`, `line_width`, `low_color`, `high_color`, `border_color`, `legend_title`, `legend_show`, `legend_position`, `legend_text_size`, `font_family`, `base_size`, `plot_background`, `width`, `height`, `dpi`.

- Method reference: [FigureYa: A Standardized Visualization Framework for Enhancing Biomedical Data Interpretation and Research Efficiency](https://github.com/ying-ge/FigureYa) (2025).
  Relevance: Compare the required input shape and intended visualization with the corresponding source module; upstream analyses are not automatically reproduced.

### Stacked Bar Plot · `stacked_bar_plot`

- Guide: [source](../../plot_web/registry/guides/stacked_bar_plot.yaml); engine: `stacked_bar_plot`.
- Status: hidden; documentation source only.
- Purpose: Decompose category totals into components as absolute counts or normalized proportions.
- Input: Categories, components and nonnegative values in supported long or wide form.
- Scenarios: Compare sample cell compositions; Inspect functional components within categories; Distinguish abundance from relative shares
- Reading: Total stack height represents total quantity, or a fixed total in normalized mode.
- Cautions: Relative changes need not imply absolute abundance changes; Capture efficiency affects observed cell counts

Published figure examples:

- **Figure 1F: DNT composition across samples** — Same plot grammar.
  Hao Q, Zhou T, Yan H, et al. (2026), *Molecular Cancer*. [A pan-cancer single cell landscape reveals heterogeneity and functional diversity of double-negative T cells](https://link.springer.com/article/10.1186/s12943-025-02548-8).
  Source: [figure/caption](https://link.springer.com/article/10.1186/s12943-025-02548-8/figures/1); DOI `10.1186/s12943-025-02548-8`; checked 2026-10-25.
  Shown in the paper: Stacked cell-type proportions.
  Apply it: Specify the denominator and retain sample-level categories.
- **Figure 6A: Immune-composition comparison** — Same plot grammar.
  Chen H, Liang Q, Geng L, Feng B (2025), *Scientific Reports*. [Transcriptomic exploration of key genes related to mitochondria and ferroptosis in inflammatory bowel disease and experimental validation](https://www.nature.com/articles/s41598-025-27002-z).
  Source: [figure/caption](https://www.nature.com/articles/s41598-025-27002-z#Fig6); DOI `10.1038/s41598-025-27002-z`; checked 2026-10-25.
  Shown in the paper: Stacked immune-cell infiltration profiles.
  Apply it: Use consistent denominators; inferred infiltration scores need not be literal cell counts.
- **Figure 2, left: Receptor-chain composition** — Same plot grammar.
  Li Z, Jia J, Zhang Q, et al. (2025), *Scientific Data*. [A single-cell V(D)J sequencing dataset of peripheral blood cells in multibacillary leprosy](https://www.nature.com/articles/s41597-025-05616-2).
  Source: [figure/caption](https://www.nature.com/articles/s41597-025-05616-2#Fig2); DOI `10.1038/s41597-025-05616-2`; checked 2026-10-25.
  Shown in the paper: Chain proportions for individual samples.
  Apply it: Map each sample to a category and each receptor chain to a component.

Local runnable demos:

- **Absolute stacked quantities** · `normal`: Use case: Compare sample cell compositions. This preset illustrates absolute stacked quantities. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/stacked_bar_plot/examples/normal/params.json) · [Inputs and reproduction](../../plugins/stacked_bar_plot/examples/normal/manifest.json) · [Preview](../../plugins/stacked_bar_plot/all_examples_gallery/normal.png)
  Mappings: `sample_column="sample"`, `group_column="group"`, `legend_columns=1`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Normalized composition shares** · `percent`: Use case: Inspect functional components within categories. This preset illustrates normalized composition shares. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/stacked_bar_plot/examples/percent/params.json) · [Inputs and reproduction](../../plugins/stacked_bar_plot/examples/percent/manifest.json) · [Preview](../../plugins/stacked_bar_plot/all_examples_gallery/percent.png)
  Mappings: `sample_column="sample"`, `group_column="group"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Long-format categories and components** · `long`: Use case: Distinguish abundance from relative shares. This preset illustrates long-format categories and components. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/stacked_bar_plot/examples/long/params.json) · [Inputs and reproduction](../../plugins/stacked_bar_plot/examples/long/manifest.json) · [Preview](../../plugins/stacked_bar_plot/all_examples_gallery/long.png)
  Mappings: `sample_column="sample"`, `group_column="group"`, `stack_column="taxon"`, `value_column="abundance"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `input_mode`, `group_column`, `value_column`, `palette`, `width`, `height`.


### Stat Plot · `stat_plot`

- Guide: [source](../../plot_web/registry/guides/stat_plot.yaml); engine: `stat_plot`.
- Status: hidden; documentation source only.
- Purpose: Summarize metadata category counts and composition using bars, pies, flows or intersection views.
- Input: Observation-level metadata with category/group mappings and a selected plot mode.
- Scenarios: Survey population counts; Compare sample composition; Inspect category correspondences and overlaps
- Reading: Marks represent counts, shares or intersections depending on the active mode.
- Cautions: Different geometries need different interpretations; Filters change count universes and proportional denominators

Published figure examples:

- **Figure 1F: DNT composition across samples** — Same plot grammar.
  Hao Q, Zhou T, Yan H, et al. (2026), *Molecular Cancer*. [A pan-cancer single cell landscape reveals heterogeneity and functional diversity of double-negative T cells](https://link.springer.com/article/10.1186/s12943-025-02548-8).
  Source: [figure/caption](https://link.springer.com/article/10.1186/s12943-025-02548-8/figures/1); DOI `10.1186/s12943-025-02548-8`; checked 2026-10-25.
  Shown in the paper: Stacked cell-type proportions.
  Apply it: Specify the denominator and retain sample-level categories.
- **Figure 2, left: Receptor-chain composition** — Same plot grammar.
  Li Z, Jia J, Zhang Q, et al. (2025), *Scientific Data*. [A single-cell V(D)J sequencing dataset of peripheral blood cells in multibacillary leprosy](https://www.nature.com/articles/s41597-025-05616-2).
  Source: [figure/caption](https://www.nature.com/articles/s41597-025-05616-2#Fig2); DOI `10.1038/s41597-025-05616-2`; checked 2026-10-25.
  Shown in the paper: Chain proportions for individual samples.
  Apply it: Map each sample to a category and each receptor chain to a component.

Local runnable demos:

- **Category count overview** · `bar`: Use case: Survey population counts. This preset illustrates category count overview. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/stat_plot/examples/bar/params.json) · [Inputs and reproduction](../../plugins/stat_plot/examples/bar/manifest.json) · [Preview](../../plugins/stat_plot/all_examples_gallery/bar.png)
  Mappings: `id_column="cell_id"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Composition of a few categories** · `pie`: Use case: Compare sample composition. This preset illustrates composition of a few categories. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/stat_plot/examples/pie/params.json) · [Inputs and reproduction](../../plugins/stat_plot/examples/pie/manifest.json) · [Preview](../../plugins/stat_plot/all_examples_gallery/pie.png)
  Mappings: `id_column="cell_id"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Cross-category summaries** · `dot`: Use case: Inspect category correspondences and overlaps. This preset illustrates cross-category summaries. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/stat_plot/examples/dot/params.json) · [Inputs and reproduction](../../plugins/stat_plot/examples/dot/manifest.json) · [Preview](../../plugins/stat_plot/all_examples_gallery/dot.png)
  Mappings: `id_column="cell_id"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): .


### Sunburst Plot · `sunburst_plot`

- Guide: [source](../../plot_web/registry/guides/sunburst_plot.yaml); engine: `sunburst_plot`.
- Status: visible in the editor.
- Purpose: Show two- or three-level category composition using nested sectors.
- Input: Parent, child, optional third-level labels and nonnegative values.
- Scenarios: Summarize annotation hierarchy composition; Survey functional classifications; Inspect shares within parent categories
- Reading: Children nest inside parents and sector angles represent the corresponding values.
- Cautions: Preserve full paths when child labels repeat; Outer-ring area does not imply greater quantity

Published figure examples:

- **Figure 2B: Dataset composition by tissue and disease** — Same plot grammar.
  Liu T, Qiao H, Ren L, et al. (2025), *Communications Biology*. [Deciphering cancer therapy resistance via patient-level single-cell transcriptomics with CellResDB](https://www.nature.com/articles/s42003-025-08457-2).
  Source: [figure/caption](https://www.nature.com/articles/s42003-025-08457-2#Fig2); DOI `10.1038/s42003-025-08457-2`; checked 2026-10-25.
  Shown in the paper: Nested tissue and disease sectors.
  Apply it: Preserve parent-child paths and dataset counts; do not treat repeated labels as unique paths.
- **Figure 1I: Hierarchical screen-impact summary** — Same plot grammar.
  Giuliani V, Miller MA, Liu CY, et al. (2021), *Nature Communications*. [PRMT1-dependent regulation of RNA metabolism and DNA damage response sustains pancreatic ductal adenocarcinoma](https://www.nature.com/articles/s41467-021-24798-y).
  Source: [figure/caption](https://www.nature.com/articles/s41467-021-24798-y#Fig1); DOI `10.1038/s41467-021-24798-y`; checked 2026-10-25.
  Shown in the paper: PRMT-family impact across genetic screens.
  Apply it: Supply the nonnegative transformed screen weights and hierarchy; explain that sector weight is transformed evidence rather than cell abundance.

Local runnable demos:

- **Two-level category composition** · `basic`: Use case: Summarize annotation hierarchy composition. This preset illustrates two-level category composition. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/sunburst_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/sunburst_plot/examples/basic/manifest.json) · [Preview](../../plugins/sunburst_plot/all_examples_gallery/basic.png)
  Mappings: `level1_column="level1"`, `level2_column="level2"`, `value_column="value"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Three-level category hierarchy** · `three_level`: Use case: Survey functional classifications. This preset illustrates three-level category hierarchy. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/sunburst_plot/examples/three_level/params.json) · [Inputs and reproduction](../../plugins/sunburst_plot/examples/three_level/manifest.json) · [Preview](../../plugins/sunburst_plot/all_examples_gallery/three_level.png)
  Mappings: `level1_column="level1"`, `level2_column="level2"`, `level3_column="level3"`, `value_column="value"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `value_column`, `palette`, `label_show`, `base_size`, `width`, `height`.


### Survival Curve · `survival_plot`

- Guide: [source](../../plot_web/registry/guides/survival_plot.yaml); engine: `survival_plot`.
- Status: visible in the editor.
- Purpose: Kaplan–Meier curves with censor marks, confidence bands and numbers at risk.
- Input: One row per independent observation: numeric nonnegative follow-up time, event 0/1 and optional group. Only right censoring is supported.
- Scenarios: Compare survival between cohorts; Show right-censoring and follow-up coverage; Display conditional survival beyond a landmark
- Reading: Kaplan–Meier curves with censor marks, confidence bands and numbers at risk. One row per independent observation: numeric nonnegative follow-up time, event 0/1 and optional group. Only right censoring is supported.
- Cautions: Competing risks, left censoring and interval censoring require other analyses. 1 − KM is not a competing-risk cumulative incidence estimator.; Log-rank comparisons do not adjust for confounders. Landmark conditioning changes the eligible observations.

Published figure examples:

No figure-panel association has been verified yet.

Local runnable demos:

- **Survival by cohort** · `basic`: Compare survival between cohorts
  [Parameters](../../plugins/survival_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/survival_plot/examples/basic/manifest.json) · [Preview](../../plugins/survival_plot/all_examples_gallery/basic.png)
  Mappings: `time_column="time"`, `event_column="event"`, `group_column="group"`
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Conditional survival** · `conditional`: Show right-censoring and follow-up coverage
  [Parameters](../../plugins/survival_plot/examples/conditional/params.json) · [Inputs and reproduction](../../plugins/survival_plot/examples/conditional/manifest.json) · [Preview](../../plugins/survival_plot/all_examples_gallery/conditional.png)
  Mappings: `time_column="time"`, `event_column="event"`, `group_column="group"`
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Event probability** · `event_probability`: Display conditional survival beyond a landmark
  [Parameters](../../plugins/survival_plot/examples/event_probability/params.json) · [Inputs and reproduction](../../plugins/survival_plot/examples/event_probability/manifest.json) · [Preview](../../plugins/survival_plot/all_examples_gallery/event_probability.png)
  Mappings: `time_column="time"`, `event_column="event"`, `group_column="group"`
  Data provenance: Independent synthetic demonstration, not original publication data.

Customization controls (checked against the schema): `time_column`, `event_column`, `group_column`, `curve_type`, `stat_method`, `landmark_time`, `confidence_level`, `confidence_show`, `confidence_alpha`, `censor_show`, `point_size`, `line_width`, `risk_table_show`, `risk_time_count`, `risk_text_size`, `title`, `subtitle`, `caption`, `title_size`, `palette`, `group_colors`, `legend_show`, `legend_position`, `legend_text_size`, `font_family`, `base_size`, `plot_background`, `grid_show`, `width`, `height`, `dpi`.

- Method reference: [FigureYa: A Standardized Visualization Framework for Enhancing Biomedical Data Interpretation and Research Efficiency](https://github.com/ying-ge/FigureYa) (2025).
  Relevance: Compare the required input shape and intended visualization with the corresponding source module; upstream analyses are not automatically reproduced.

### Swimmer Timeline · `swimmer_plot`

- Guide: [source](../../plot_web/registry/guides/swimmer_plot.yaml); engine: `swimmer_plot`.
- Status: visible in the editor.
- Purpose: Show observation intervals and dated events for individual subjects.
- Input: One unique subject per start/end interval with end >= start. Optional events CSV has subject, time and event; events must fall within their subject interval.
- Scenarios: Summarize individual follow-up intervals; Overlay dated treatment or response events; Compare staggered observation windows
- Reading: Show observation intervals and dated events for individual subjects. One unique subject per start/end interval with end >= start. Optional events CSV has subject, time and event; events must fall within their subject interval.
- Cautions: An interval endpoint marker does not identify progression, death or censoring unless the event table explicitly encodes it.; Intervals are supplied observations; no treatment effect or survival model is inferred.

Published figure examples:

No figure-panel association has been verified yet.

Local runnable demos:

- **Observation intervals and events** · `basic`: Summarize individual follow-up intervals
  [Parameters](../../plugins/swimmer_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/swimmer_plot/examples/basic/manifest.json) · [Preview](../../plugins/swimmer_plot/all_examples_gallery/basic.png)
  Mappings: `id_column="subject"`, `start_column="start"`, `end_column="end"`, `group_column="group"`
  Data provenance: Independent synthetic demonstration, not original publication data.
- **Staggered observation windows** · `staggered`: Overlay dated treatment or response events
  [Parameters](../../plugins/swimmer_plot/examples/staggered/params.json) · [Inputs and reproduction](../../plugins/swimmer_plot/examples/staggered/manifest.json) · [Preview](../../plugins/swimmer_plot/all_examples_gallery/staggered.png)
  Mappings: `id_column="subject"`, `start_column="start"`, `end_column="end"`, `group_column="group"`
  Data provenance: Independent synthetic demonstration, not original publication data.

Customization controls (checked against the schema): `id_column`, `start_column`, `end_column`, `group_column`, `sort_by`, `bar_width`, `end_marker_show`, `event_size`, `point_size`, `palette`, `group_colors`, `title`, `subtitle`, `caption`, `title_size`, `legend_show`, `legend_position`, `legend_text_size`, `font_family`, `base_size`, `plot_background`, `grid_show`, `width`, `height`, `dpi`.

- Method reference: [FigureYa: A Standardized Visualization Framework for Enhancing Biomedical Data Interpretation and Research Efficiency](https://github.com/ying-ge/FigureYa) (2025).
  Relevance: Compare the required input shape and intended visualization with the corresponding source module; upstream analyses are not automatically reproduced.

### Ternary Plot · `ternary_plot`

- Guide: [source](../../plot_web/registry/guides/ternary_plot.yaml); engine: `ternary_plot`.
- Status: visible in the editor.
- Purpose: Map three nonnegative components onto a composition simplex.
- Input: Three nonnegative columns whose row totals are positive; optional groups.
- Scenarios: Compare three population fractions; Show three-state score composition; Find samples dominated by one component
- Reading: Proximity to a vertex indicates a higher relative share of that component.
- Cautions: Normalization removes total-quantity information; Components must have a defensible common compositional interpretation

Published figure examples:

- **Figure 2G: Three-neighborhood composition** — Same plot grammar.
  Tan Y, Kempchen TN, Becker M, et al. (2025), *Nature Communications*. [SPACEc: a streamlined, interactive Python workflow for multiplexed image processing and analysis](https://www.nature.com/articles/s41467-025-65658-3).
  Source: [figure/caption](https://www.nature.com/articles/s41467-025-65658-3#Fig2); DOI `10.1038/s41467-025-65658-3`; checked 2026-10-25.
  Shown in the paper: Barycentric neighborhood combinations.
  Apply it: Select exactly three nonnegative neighborhood fractions with a positive total.
- **Figure 4B: Three-component diagnostic evidence** — Same plot grammar.
  Kenn M, Karch R, Cacsire Castillo-Tong D, et al. (2022), *Journal of Personalized Medicine*. [Decision Theory versus Conventional Statistics for Personalized Therapy of Breast Cancer](https://www.mdpi.com/2075-4426/12/4/570).
  Source: [figure/caption](https://www.mdpi.com/2075-4426/12/4/570); DOI `10.3390/jpm12040570`; checked 2026-10-25.
  Shown in the paper: Evidence represented on a ternary plane.
  Apply it: Supply three nonnegative components summing to a common total; the renderer does not calculate clinical evidence or make decisions.

Local runnable demos:

- **Relative composition of three components** · `basic`: Use case: Compare three population fractions. This preset illustrates relative composition of three components. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/ternary_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/ternary_plot/examples/basic/manifest.json) · [Preview](../../plugins/ternary_plot/all_examples_gallery/basic.png)
  Mappings: `a_column="a"`, `b_column="b"`, `c_column="c"`, `group_column="group"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `group_column`, `palette`, `group_colors`, `base_size`, `width`, `height`.


### Threshold Matrix Heatmap · `threshold_matrix_heatmap`

- Guide: [source](../../plot_web/registry/guides/threshold_matrix_heatmap.yaml); engine: `threshold_matrix_heatmap`.
- Status: visible in the editor.
- Purpose: Color matrix cells using explicit threshold rules to summarize multiple comparisons.
- Input: Row labels and numeric comparison columns, with shared or per-column rules and missing-value colors.
- Scenarios: Compare enrichment evidence across conditions; Survey multiple differential contrasts; Check threshold-category consistency
- Reading: Colors identify rule-defined bins rather than necessarily representing continuous distances.
- Cautions: Use comparable probability definitions and corrections; Failing a threshold does not imply zero effect or no expression

Published figure examples:

- **Figure 2F: Pathway evidence across populations** — Related layout; adaptation required.
  Hao Q, Zhou T, Yan H, et al. (2026), *Molecular Cancer*. [A pan-cancer single cell landscape reveals heterogeneity and functional diversity of double-negative T cells](https://link.springer.com/article/10.1186/s12943-025-02548-8).
  Source: [figure/caption](https://link.springer.com/article/10.1186/s12943-025-02548-8/figures/2); DOI `10.1186/s12943-025-02548-8`; checked 2026-10-25.
  Shown in the paper: Adjusted probabilities for shared pathways.
  Apply it: Related encoding: choose explicit probability bins; the paper uses a continuous significance scale.

Local runnable demos:

- **Threshold categories across comparisons** · `params`: Use case: Compare enrichment evidence across conditions. This preset illustrates threshold categories across comparisons. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/threshold_matrix_heatmap/examples/params/params.json) · [Inputs and reproduction](../../plugins/threshold_matrix_heatmap/examples/params/manifest.json) · [Preview](../../plugins/threshold_matrix_heatmap/all_examples_gallery/params.png)
  Mappings: `row_label_column="term"`, `value_columns=["CK-vs-M1", "CK-vs-M2", "CK-vs-M3", "M1-vs-M2", "M1-vs-M3", "M2-vs-M3"]`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `row_label_column`, `width`, `height`.


### Treemap Plot · `treemap_plot`

- Guide: [source](../../plot_web/registry/guides/treemap_plot.yaml); engine: `treemap_plot`.
- Status: visible in the editor.
- Purpose: Use nested rectangle areas to encode nonnegative parent-child quantities.
- Input: Parent labels, child labels and nonnegative values.
- Scenarios: Survey functional-category totals; Show hierarchical composition; Locate dominant child categories
- Reading: Rectangle area represents values; position and aspect ratio follow the layout algorithm.
- Cautions: Aspect ratio has no biological meaning; Small tiles are unsuitable for precise label-based comparisons

Published figure examples:

- **Figure 1E: Enriched pathway summary** — Same plot grammar.
  Chen H, Liang Q, Geng L, Feng B (2025), *Scientific Reports*. [Transcriptomic exploration of key genes related to mitochondria and ferroptosis in inflammatory bowel disease and experimental validation](https://www.nature.com/articles/s41598-025-27002-z).
  Source: [figure/caption](https://www.nature.com/articles/s41598-025-27002-z#Fig1); DOI `10.1038/s41598-025-27002-z`; checked 2026-10-25.
  Shown in the paper: KEGG enrichment shown as a treemap.
  Apply it: Supply nonnegative area weights and parent classes; state any conversion of probabilities to weights.
- **Figure 1A-B: Summarize genetic pathway enrichment** — Same plot grammar.
  Schormair B, Zhao C, Bell S, et al. (2024), *Nature Genetics*. [Genome-wide meta-analyses of restless legs syndrome yield insights into genetic architecture, disease biology and risk prediction](https://www.nature.com/articles/s41588-024-01763-1).
  Source: [figure/caption](https://www.nature.com/articles/s41588-024-01763-1#Fig1); DOI `10.1038/s41588-024-01763-1`; checked 2026-10-25.
  Shown in the paper: Enriched pathways grouped into treemap clusters.
  Apply it: Supply nonnegative enrichment weights and pathway-cluster labels; automatic semantic grouping is upstream.

Local runnable demos:

- **Parent-child composition by area** · `basic`: Use case: Survey functional-category totals. This preset illustrates parent-child composition by area. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/treemap_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/treemap_plot/examples/basic/manifest.json) · [Preview](../../plugins/treemap_plot/all_examples_gallery/basic.png)
  Mappings: `level1_column="level1"`, `level2_column="level2"`, `value_column="value"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `value_column`, `palette`, `label_show`, `base_size`, `width`, `height`.


### Violin Plot · `violin_plot`

- Guide: [source](../../plot_web/registry/guides/violin_plot.yaml); engine: `violin_plot`.
- Status: visible in the editor.
- Purpose: Compare continuous feature distributions using grouped violins, annotations, points or matrix layouts.
- Input: Feature-expression or numeric data with population and optional sample annotations.
- Scenarios: Compare marker distributions within groups; Inspect heterogeneity behind group means; Interpret expression with annotations
- Reading: Violin width shows estimated density and overlaid points show observations.
- Cautions: Width normalization can obscure differences in sample size; Distinguish zeros from missing values

Published figure examples:

- **Figure 6B: Immune-infiltration distributions** — Same plot grammar.
  Chen H, Liang Q, Geng L, Feng B (2025), *Scientific Reports*. [Transcriptomic exploration of key genes related to mitochondria and ferroptosis in inflammatory bowel disease and experimental validation](https://www.nature.com/articles/s41598-025-27002-z).
  Source: [figure/caption](https://www.nature.com/articles/s41598-025-27002-z#Fig6); DOI `10.1038/s41598-025-27002-z`; checked 2026-10-25.
  Shown in the paper: Groupwise infiltration-score violins.
  Apply it: Use sample-level scores and group labels; statistical testing remains a separate analysis.

Local runnable demos:

- **Distributions with annotations** · `anno`: Use case: Compare marker distributions within groups. This preset illustrates distributions with annotations. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/violin_plot/examples/anno/params.json) · [Inputs and reproduction](../../plugins/violin_plot/examples/anno/manifest.json) · [Preview](../../plugins/violin_plot/all_examples_gallery/anno.png)
  Mappings: `cell_id_column="cell"`, `feature_column="gene"`, `value_column="value"`, `group_column="cluster"`, `annotation_column="category"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Distributions and raw points** · `dot`: Use case: Inspect heterogeneity behind group means. This preset illustrates distributions and raw points. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/violin_plot/examples/dot/params.json) · [Inputs and reproduction](../../plugins/violin_plot/examples/dot/manifest.json) · [Preview](../../plugins/violin_plot/all_examples_gallery/dot.png)
  Mappings: `cell_id_column="cell"`, `feature_column="gene"`, `value_column="value"`, `group_column="cluster"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Multifeature multigroup distribution matrix** · `matrix`: Use case: Interpret expression with annotations. This preset illustrates multifeature multigroup distribution matrix. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/violin_plot/examples/matrix/params.json) · [Inputs and reproduction](../../plugins/violin_plot/examples/matrix/manifest.json) · [Preview](../../plugins/violin_plot/all_examples_gallery/matrix.png)
  Mappings: `cell_id_column="cell"`, `feature_column="feature"`, `group_column="cluster"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): .

- Method reference: [Raincloud plots: a multi-platform tool for robust data visualization](https://wellcomeopenresearch.org/articles/4-63) (2021).
  Relevance: Explains the roles of density, raw points and summary statistics. Other distribution plots are related reading, not identical layouts.

### Waterfall Plot · `waterfall_plot`

- Guide: [source](../../plot_web/registry/guides/waterfall_plot.yaml); engine: `waterfall_plot`.
- Status: visible in the editor.
- Purpose: Show signed additive contributions as cumulative steps, optionally ending with a total.
- Input: Ordered category labels and signed increments.
- Scenarios: Explain sources of a net change; Show sequential gains and losses; Decompose a model score or quantity
- Reading: Each increment starts at the current cumulative value; an optional last bar gives the total.
- Cautions: This is an additive bridge chart, not a patient-response ranking; Ordering changes the intermediate path, not the sum

Published figure examples:

- **Figure 4A-D: Explain individual model predictions** — Same plot grammar.
  Prabhu H, Bhosale H, Sane A, et al. (2024), *Scientific Reports*. [Protein feature engineering framework for AMPylation site prediction](https://www.nature.com/articles/s41598-024-58450-8).
  Source: [figure/caption](https://www.nature.com/articles/s41598-024-58450-8#Fig4); DOI `10.1038/s41598-024-58450-8`; checked 2026-10-25.
  Shown in the paper: Signed SHAP contributions to predictions.
  Apply it: Supply precomputed contributions. The local chart uses cumulative bars and does not compute SHAP values; include the baseline in the contribution table if needed.
- **Figure 5: Explain individualized model risk** — Same plot grammar.
  Pieszko K, Shanbhag AD, Singh A, et al. (2023), *npj Digital Medicine*. [Time and event-specific deep learning for personalized risk assessment after cardiac perfusion imaging](https://www.nature.com/articles/s41746-023-00806-x).
  Source: [figure/caption](https://www.nature.com/articles/s41746-023-00806-x#Fig5); DOI `10.1038/s41746-023-00806-x`; checked 2026-10-25.
  Shown in the paper: Signed features contribute to an individual prediction.
  Apply it: Supply computed contributions and a baseline; the local cumulative bars do not train a model or make patient-specific risk assessments. Include a nonzero baseline as an explicit initial step when preparing the table.

Local runnable demos:

- **Signed contributions with a total** · `basic`: Use case: Explain sources of a net change. This preset illustrates signed contributions with a total. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/waterfall_plot/examples/basic/params.json) · [Inputs and reproduction](../../plugins/waterfall_plot/examples/basic/manifest.json) · [Preview](../../plugins/waterfall_plot/all_examples_gallery/basic.png)
  Mappings: `category_column="category"`, `value_column="value"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.
- **Contributions without the total bar** · `no_total`: Use case: Show sequential gains and losses. This preset illustrates contributions without the total bar. Replace its input with your data while retaining the appropriate view settings.
  [Parameters](../../plugins/waterfall_plot/examples/no_total/params.json) · [Inputs and reproduction](../../plugins/waterfall_plot/examples/no_total/manifest.json) · [Preview](../../plugins/waterfall_plot/all_examples_gallery/no_total.png)
  Mappings: `category_column="category"`, `value_column="value"`
  Data provenance: Local demonstration bundle, not the original data of a cited paper.

Customization controls (checked against the schema): `value_column`, `category_column`, `label_show`, `base_size`, `width`, `height`.


## Reference validation

Passed: linked local manifests, parameters, inputs, baselines and declared previews exist; customization parameters match the schema. Figure records have source URLs, panel labels and adaptation notes. This check does not execute R or independently re-fetch sources.
