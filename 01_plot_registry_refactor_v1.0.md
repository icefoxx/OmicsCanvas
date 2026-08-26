# Plot Registry Refactor Specification v1.0

## 1. Objective

Refactor the plotting website so that every plot, variant, preset, demo, style, parameter group, and export template is described through a centralized **plot registry** rather than being scattered across UI code and plotting implementations.

The registry must become the single source of truth for:

- Plot discovery
- Search
- Analysis-context routing
- Plot-family grouping
- Variant selection
- Preset selection
- Demo/example loading
- Parameter visibility
- Data requirements
- Recommended visualizations
- UI card generation
- Backward compatibility with current preset identifiers

This task should **not change plotting behavior unless necessary**. The primary goal is to normalize metadata and make later UI refactoring possible.

---

## 2. Core Design Principle

Separate the following concepts explicitly:

1. **Plot Family**
   - Example: `umap_tsne`, `heatmap`, `volcano`, `gsea`

2. **Variant**
   - A visually or scientifically distinct representation of the same plot family.
   - Examples for UMAP:
     - `clusters`
     - `feature_expression`
     - `split_samples`
     - `composition_pie`
     - `composition_ring`
     - `density`
     - `highlight_cells`
     - `ellipse`

3. **Preset**
   - A reusable configuration bundle that changes appearance or parameter defaults without redefining the scientific visualization.
   - Examples:
     - `recommended`
     - `publication`
     - `minimal`
     - `large_dataset`

4. **Parameter**
   - User-adjustable configuration.
   - Examples:
     - point size
     - alpha
     - color palette
     - legend position
     - cutoff
     - label visibility

5. **Demo**
   - Example input/data/config used to demonstrate a plot.

6. **Export Template**
   - Output-related configuration only.
   - Examples:
     - PDF sizing
     - SVG sizing
     - raster resolution

Current objects named “preset” must be reclassified into the correct category.

---

## 3. Required Registry Schema

Implement a registry format that can be stored as JSON, YAML, TypeScript, or equivalent structured metadata.

Recommended schema:

```yaml
id: umap_tsne
name: UMAP / t-SNE
short_name: UMAP
description: Dimensionality reduction plots for cell embeddings.

aliases:
  - umap
  - tsne
  - embedding
  - dimensional reduction
  - cell map

categories:
  - single_cell
  - dimension_reduction

analysis_contexts:
  - single_cell
  - cell_clustering
  - gene_expression
  - cell_composition

tasks:
  - clustering
  - feature_expression
  - composition
  - density
  - highlighting

data_requirements:
  required:
    - x_embedding
    - y_embedding
  optional:
    - cluster
    - sample
    - condition
    - feature
    - metadata

variants:
  - id: clusters
    name: Clusters
    description: Color cells by cluster or annotation.
    preview_asset: previews/umap_clusters.png
    recommended_for:
      - cell_clustering
    parameter_groups:
      - data_mapping
      - marks
      - colors
      - labels
      - legend
      - axes
      - export

  - id: feature_expression
    name: Feature Expression
    description: Map numeric feature expression onto the embedding.
    preview_asset: previews/umap_feature.png
    recommended_for:
      - gene_expression

  - id: composition_pie
    name: Composition Pie
    description: Show group composition as pies positioned on clusters.
    preview_asset: previews/umap_composition_pie.png
    recommended_for:
      - cell_composition

presets:
  - id: recommended
    name: Recommended
  - id: publication
    name: Publication
  - id: minimal
    name: Minimal

legacy_presets:
  basic_umap:
    maps_to:
      variant: clusters
      preset: recommended

  embedded_pie:
    maps_to:
      variant: composition_pie
      preset: recommended
```

---

## 4. Registry Audit of Existing System

Create an automated or semi-automated inventory of all currently implemented plots and presets.

For every existing preset or plot configuration, classify it into exactly one of:

- `variant`
- `preset`
- `parameter`
- `demo`
- `export_template`
- `deprecated`
- `uncertain`

Examples from the current UMAP implementation:

| Existing item | New classification |
|---|---|
| `basic_umap` | variant / legacy alias |
| `ellipse_mark` | variant |
| `split_samples` | variant |
| `composition_ring` | variant |
| `embedded_pie` | variant |
| `density_filled` | variant |
| `density_hex` | variant |
| `highlight_cells` | variant |
| `axis_label_controls` | parameter group |
| `background_mask` | parameter |
| `bg_cutoff` | parameter |
| `blank_theme` | preset/theme |
| `pdf_basic_umap` | export template |
| demo configurations | demo |

Do not assume names are semantically correct. Inspect implementation behavior.

---

## 5. Scientific Context Metadata

Each plot must receive metadata supporting discovery by scientific task.

At minimum support:

### Analysis contexts

- `single_cell`
- `bulk_expression`
- `differential_expression`
- `functional_enrichment`
- `epigenomics`
- `trajectory`
- `composition`
- `general_statistics`
- `relationships_overlap`

### Tasks

Examples:

- `cell_clustering`
- `gene_expression`
- `marker_visualization`
- `cell_composition`
- `sample_comparison`
- `differential_expression`
- `expression_pattern`
- `gene_clustering`
- `gsea`
- `ora`
- `pathway_comparison`
- `gene_pathway_relationship`
- `trajectory`
- `correlation`
- `distribution`
- `group_comparison`

A plot may belong to multiple contexts and tasks.

---

## 6. Search Metadata

Every plot family and variant should support search aliases.

Example:

```yaml
aliases:
  - ridge
  - ridgeplot
  - joyplot
  - density ridge
  - gsea ridge
  - pathway density
```

Search should match:

- canonical name
- aliases
- context
- task
- description
- variant names

Avoid relying on exact strings only.

---

## 7. Data Compatibility Metadata

Registry entries should state data requirements.

Example:

```yaml
data_requirements:
  required_roles:
    - x
    - y

  optional_roles:
    - group
    - feature
    - split

  accepted_types:
    x: numeric
    y: numeric
    group: categorical
    feature: numeric
```

This metadata will later allow automatic recommendations.

---

## 8. Recommendation Metadata

Support lightweight deterministic recommendations without requiring an LLM.

Example:

```yaml
recommendation_rules:
  - when:
      has_embedding_xy: true
      has_cluster: true
    recommend:
      variant: clusters
      priority: 100

  - when:
      has_embedding_xy: true
      has_sample: true
    recommend:
      variant: split_samples
      priority: 80

  - when:
      has_embedding_xy: true
      has_cluster: true
      has_sample: true
    recommend:
      variant: composition_pie
      priority: 90
```

Do not yet build a complex AI recommender.

---

## 9. Backward Compatibility

Existing URLs, saved configurations, and preset IDs should continue to work.

Implement a translation layer:

```text
legacy preset ID
    ↓
registry lookup
    ↓
variant + preset + parameters
```

A legacy identifier should not silently change visual output.

Log deprecated identifiers in development mode.

---

## 10. Registry API

Provide functions equivalent to:

```ts
getAllPlots()
getPlot(plotId)
getVariants(plotId)
getVariant(plotId, variantId)
searchPlots(query)
getPlotsByContext(context)
getPlotsByTask(task)
getCompatiblePlots(dataSchema)
getRecommendedPlots(dataSchema, context?)
resolveLegacyPreset(plotId, legacyPresetId)
```

The implementation language may differ, but the capabilities should exist.

---

## 11. Validation

Add automated validation for registry entries.

Check:

- IDs are unique
- Names are present
- Variant IDs are unique within a family
- Preview paths resolve
- Parameter groups exist
- Legacy aliases resolve
- Context values use approved vocabulary
- Data role names are valid
- No orphan preset references
- No duplicate aliases that create ambiguous routing unless explicitly allowed

Validation failure should be visible during development/build.

---

## 12. Deliverables

Produce:

1. Central plot registry
2. Registry schema/types
3. Inventory of all current plots
4. Inventory of all current presets
5. Classification report:
   - variant
   - preset
   - parameter
   - demo
   - export
   - deprecated
   - uncertain
6. Legacy preset mapping
7. Registry query/search functions
8. Validation tests
9. Migration notes
10. Short report listing unresolved ambiguous items

---

## 13. Acceptance Criteria

The task is complete when:

- Every current plot appears in the registry.
- Every current preset is classified.
- UMAP/t-SNE is fully migrated as a reference implementation.
- Existing plotting outputs remain reproducible.
- Existing saved configurations remain loadable.
- Search can find plots by canonical name and aliases.
- Plots can be queried by scientific context and task.
- Variants are separated from appearance presets.
- Parameter-only presets are no longer represented as visualization variants.
- Registry validation passes.
- No duplicate plotting engine is introduced.

---

## 14. Do Not Do Yet

Do not perform the major UI redesign in this task.

Do not create the card gallery yet.

Do not remove legacy preset support.

Do not rewrite plotting algorithms unless required for registry normalization.

The registry must first provide a stable metadata layer for the next two phases.
