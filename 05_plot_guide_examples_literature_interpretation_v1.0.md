# OmicsCanvas Plot Guide Panel Specification v1.0

## 1. Objective

Add a **collapsible Plot Guide panel** to the left side of Plot Studio.

The Plot Studio should have three clearly separated responsibilities:

``` text
Learn / Interpret        Current Visualization        Configure / Draw
      ↓                           ↓                           ↓
 Plot Guide                 Plot Canvas                  Parameters
```

The new guide should help users answer:

-   What does this plot show?
-   When should I use it?
-   How should I interpret it?
-   What should I **not** conclude from it?
-   What do specific variants/marks mean?
-   What does a good example look like?
-   How has this type of plot been used in published work?
-   How can I describe/report the plot in a figure legend or manuscript?

The guide must be **registry-driven** and reusable across plot families.

Do not hard-code UMAP-specific guide content into the UI component.

------------------------------------------------------------------------

# 2. Target Studio Layout

Desktop:

``` text
┌──────────────────┬──────────────────────────────┬──────────────────────┐
│                  │                              │                      │
│    Plot Guide    │                              │    Parameters &      │
│                  │         Plot Canvas          │       Config         │
│  About           │                              │                      │
│  Examples        │                              │  Data                │
│  Literature      │                              │  Plot                │
│  Interpret       │                              │  Theme               │
│                  │                              │  Axes                │
│                  │                              │  Legend              │
│                  │                              │  Export              │
│                  │                              │                      │
└──────────────────┴──────────────────────────────┴──────────────────────┘
```

Conceptually:

``` text
LEFT                    CENTER                  RIGHT

What does it mean?      What does my           How do I
How do I read it?       plot look like?         configure it?
```

The Plot Guide must be independently collapsible.

When collapsed, the canvas should expand into the available space.

------------------------------------------------------------------------

# 3. Plot Guide Navigation

Use a compact tab or section navigation inside the left panel.

Recommended sections:

``` text
About
Examples
Literature
Interpret
```

Optional later:

``` text
Report
Learn More
```

Do not display all guide content simultaneously if it makes the panel
excessively long.

------------------------------------------------------------------------

# 4. About Section

The About section explains the visualization family.

Example structure:

``` text
UMAP / t-SNE

Visualizes high-dimensional observations in a
two-dimensional embedding while approximately
preserving aspects of neighborhood structure.

BEST FOR

• Cell clusters
• Cell states
• Feature-expression patterns
• Sample mixing
• Annotation overview

COMMON USES

• Visualize cell populations
• Compare annotations
• Overlay expression
• Explore composition
```

Keep the initial summary concise.

Allow optional expansion:

``` text
Learn more ▾
```

------------------------------------------------------------------------

# 5. Add "Be Careful" / Limitations

Every scientific plot family should support explicit interpretation
cautions.

Example for UMAP:

``` text
BE CAREFUL

⚠ Global distances

Distances between widely separated regions of a
UMAP should not automatically be interpreted as
quantitative biological distances.

⚠ Cluster area

The visual area occupied by a cluster is not
necessarily proportional to biological abundance.

⚠ Statistical inference

Visual separation alone does not establish
statistical significance.
```

This is scientifically important and should be treated as a first-class
guide component.

Avoid overclaiming.

Guide text should distinguish:

-   what the plot directly shows;
-   what is a reasonable interpretation;
-   what requires additional analysis/evidence.

------------------------------------------------------------------------

# 6. Evidence / Interpretation Semantics

Where useful, guide entries may use semantic types:

``` yaml
type: direct
type: interpretation
type: caution
```

Meaning:

### direct

The graphical element directly represents the stated quantity.

### interpretation

A scientifically reasonable interpretation, but not directly proven by
the plot.

### caution

A common overinterpretation, limitation, or confounder.

The UI may render these differently, but must not rely on color alone.

------------------------------------------------------------------------

# 7. Examples Section

Add visual example cards using OmicsCanvas demo data.

Example:

``` text
EXAMPLES

┌──────────────────────────┐
│ [preview]                │
│                          │
│ Basic clusters           │
│                          │
│ Color cells by cluster   │
│ or cell type.            │
│                          │
│ [Try Example]            │
└──────────────────────────┘

┌──────────────────────────┐
│ [preview]                │
│                          │
│ Sample composition       │
│                          │
│ Compare group fractions  │
│ within clusters.         │
│                          │
│ [Try Example]            │
└──────────────────────────┘
```

Examples should preferably map to existing:

-   plot family;
-   variant;
-   demo dataset;
-   preset;
-   parameter configuration.

------------------------------------------------------------------------

# 8. Example Interaction

`Try Example` should:

1.  clearly indicate that demo data/config will be loaded;
2.  load the registry-defined demo;
3.  select the correct variant;
4.  apply the example configuration;
5.  update the plot.

Do not silently overwrite user data/configuration.

If the user currently has custom data loaded, use one of:

-   confirmation;
-   temporary demo mode;
-   preserve/restore current session state.

Prefer a reversible demo experience.

------------------------------------------------------------------------

# 9. Literature Section

Support curated published examples of the visualization.

Example:

``` text
PUBLISHED EXAMPLES

Author et al., Nature Methods, 2025
Single-cell UMAP used to visualize ...
Fig. 2B

[View Paper]
```

Optional when reuse is permitted:

``` text
[licensed thumbnail]

Source:
Author et al.
Journal, Year
Figure 2B
License: CC BY 4.0
```

------------------------------------------------------------------------

# 10. Literature Copyright Requirements

Do not automatically copy arbitrary published figures into OmicsCanvas.

For every displayed literature thumbnail, store:

``` yaml
citation:
doi:
url:
figure:
license:
thumbnail_reuse_allowed:
```

Only show the original figure/thumbnail when reuse rights are known to
permit it.

If reuse permission is unknown or restrictive:

-   show citation metadata;
-   show a short textual description;
-   link to the source;
-   optionally use an original OmicsCanvas schematic/demo inspired by
    the visualization concept.

Do not present a recreated figure as the original publication figure.

------------------------------------------------------------------------

# 11. Literature Is Curated Evidence, Not Decoration

Each literature example should explain why it is relevant.

Example:

``` text
Why this example?

Demonstrates how UMAP can be used to show
cell-type structure across treatment conditions.
```

Possible metadata:

``` yaml
use_case:
  - cell_clustering
  - condition_comparison

relevance:
  - demonstrates split embedding
  - shows cell annotation
```

------------------------------------------------------------------------

# 12. Interpret Section

The Interpret section should teach the user how to read the plot.

Example:

``` text
HOW TO INTERPRET

✓ Cluster structure

Dense or separated regions may indicate groups of
observations with similar profiles.

✓ Local neighborhood

Nearby cells often have more similar high-dimensional
profiles than distant cells.

⚠ Distant clusters

Do not interpret the distance between remote clusters
as a precise quantitative measure.

⚠ Abundance

Cluster geometry does not automatically represent
population abundance.
```

Keep statements scientifically conservative.

------------------------------------------------------------------------

# 13. Family Guide vs Variant Guide

Guide content must support two levels.

## Family Guide

Explains the general visualization.

Example:

``` text
UMAP / t-SNE

What is an embedding?
What does proximity mean?
What are common limitations?
When is this family useful?
```

## Variant Guide

Explains the currently selected representation.

Example:

``` text
UMAP
→ Composition Pie

What does each pie represent?
How is its position calculated?
What determines pie size?
What does each slice mean?
When is this representation useful?
What are its limitations?
```

Variant guide content should appear below or alongside the family-level
explanation.

------------------------------------------------------------------------

# 14. Dynamic Variant Guide

When the user changes variants:

``` text
Clusters
→ Composition Pie
```

the guide should update automatically.

Example:

``` text
CURRENT VIEW
Composition Pie

Each pie summarizes the composition of a cluster
according to the selected categorical variable.

Slices:
sample

Position:
cluster centroid

Size:
fixed
```

Where possible, populate these statements from the current parameter
state.

------------------------------------------------------------------------

# 15. Current Plot Semantics

The guide should be capable of explaining the **actual configured
plot**, not only a generic plot family.

Example current configuration:

``` text
variant = composition_pie
cluster_column = celltype
composition_column = sample
pie_size_mode = cell_count
```

Generated explanation:

``` text
Each pie represents one cell type.

Pie slices show the relative contribution of each
sample within that cell type.

Pie size is proportional to the number of cells.
```

Prefer deterministic template generation from state.

Do not require an LLM for basic semantics.

------------------------------------------------------------------------

# 16. "How to Report" Section

Add a reusable scientific reporting/caption helper.

Example:

``` text
HOW TO REPORT

UMAP visualization of single-cell profiles.
Each point represents one cell and cells are colored
according to cluster assignment.

[Copy Caption]
```

The text should adapt to current settings.

Example:

``` text
group = cell_type
```

produces:

``` text
Cells are colored according to annotated cell type.
```

Example:

``` text
split = treatment
```

adds:

``` text
Embeddings are shown separately by treatment condition.
```

------------------------------------------------------------------------

# 17. Reporting Templates Must Be Conservative

Generated reporting text should describe:

-   what is plotted;
-   mappings;
-   grouping;
-   transformations;
-   relevant visual encoding.

It should **not automatically generate biological conclusions**.

Good:

``` text
Cells are colored by treatment group.
```

Avoid automatic claims such as:

``` text
Treatment causes a distinct cellular state.
```

unless such interpretation comes from a separate validated analysis.

------------------------------------------------------------------------

# 18. Caption Template Architecture

Support registry templates:

``` yaml
reporting:
  base_template: >
    {family_name} visualization of {observation_type}.

  mappings:
    group: >
      Points are colored according to {group_column}.

    split: >
      Panels are separated by {split_column}.

    feature: >
      Color intensity represents {feature_column}.

    composition: >
      Pie slices represent the relative composition of
      {composition_column}.
```

The template engine should omit clauses when the corresponding mapping
is absent.

------------------------------------------------------------------------

# 19. Copy Caption

Provide:

``` text
[Copy Caption]
```

Optional:

``` text
[Short]
[Detailed]
```

Initial implementation may provide only one concise caption.

If implementing multiple levels:

### Short

Suitable for a figure legend sentence.

### Detailed

Includes mappings and relevant visualization settings.

------------------------------------------------------------------------

# 20. Registry Schema Extension

Extend `plot_registry` with optional guide metadata.

Example:

``` yaml
id: umap_tsne
name: UMAP / t-SNE

guide:
  summary: >
    Visualizes high-dimensional observations in a
    two-dimensional embedding.

  best_for:
    - Cell clustering
    - Cell states
    - Feature-expression patterns
    - Sample mixing

  common_uses:
    - Visualize cell populations
    - Compare annotations
    - Overlay feature expression

  interpretation:
    - id: local_structure
      type: interpretation
      title: Local neighborhood
      text: >
        Nearby observations often have more similar
        high-dimensional profiles.

  cautions:
    - id: global_distance
      title: Global distance
      text: >
        Distance between widely separated regions
        should not automatically be interpreted as a
        quantitative biological distance.

    - id: statistical_inference
      title: Statistical inference
      text: >
        Visual separation alone does not establish
        statistical significance.

  examples:
    - id: basic_clusters
      title: Basic clusters
      description: Color cells by cluster.
      preview_asset: guides/umap/basic_clusters.png
      demo_id: umap_basic
      variant_id: clusters

  literature:
    - id: paper_example_1
      citation: "..."
      doi: "..."
      url: "..."
      figure: "Fig. 2B"
      license: "CC BY 4.0"
      thumbnail_reuse_allowed: true
      thumbnail_asset: "..."
      description: "..."
      use_case:
        - cell_clustering

  reporting:
    base_template: >
      UMAP visualization of {observation_type}.
```

All fields should be optional so plots can migrate incrementally.

------------------------------------------------------------------------

# 21. Variant Registry Extension

Variants may contain their own guide:

``` yaml
variants:
  - id: composition_pie
    name: Composition Pie

    guide:
      summary: >
        Displays categorical composition within
        embedding-defined groups using pie charts.

      best_for:
        - Comparing sample composition across clusters

      interpretation:
        - title: Pie slices
          type: direct
          text: >
            Slice proportions represent the selected
            composition variable within each group.

      cautions:
        - title: Pie size
          text: >
            Pie area should only be interpreted as
            abundance when size is explicitly mapped
            to an abundance metric.

      reporting:
        template: >
          Pie slices represent the relative composition
          of {composition_column} within each
          {cluster_column}.
```

------------------------------------------------------------------------

# 22. Guide Content Resolution

Recommended resolution order:

``` text
Family guide
      +
Variant guide
      +
Current plot state
      ↓
Rendered Plot Guide
```

Do not duplicate family content inside every variant.

------------------------------------------------------------------------

# 23. Guide UI Component Architecture

Suggested reusable components:

``` text
PlotGuidePanel
├── GuideHeader
├── GuideTabs
├── AboutGuide
├── BestForList
├── CautionList
├── ExampleGallery
│   └── ExampleCard
├── LiteratureGallery
│   └── LiteratureCard
├── InterpretationGuide
├── CurrentViewExplanation
└── ReportingHelper
```

Components must consume registry/state data.

Avoid plot-specific conditional UI such as:

``` js
if (plotId === "umap") ...
```

unless required by a truly unique behavior.

------------------------------------------------------------------------

# 24. Collapsible Behavior

Desktop:

``` text
[‹] Plot Guide
```

Collapsed:

``` text
[›]
```

Requirements:

-   remember open/closed state during the session;
-   expanding/collapsing must resize the canvas correctly;
-   right Parameters panel remains independently controllable;
-   avoid forcing horizontal scrolling.

------------------------------------------------------------------------

# 25. Responsive Behavior

Desktop: - three-column layout.

Medium width: - Plot Guide can become narrower or overlay/drawer.

Mobile: - do not force three columns; - expose Plot Guide through a
drawer/tab/button; - plot canvas remains primary.

------------------------------------------------------------------------

# 26. Empty Guide State

Not all 46+ families will initially have complete documentation.

For missing guide content:

``` text
Guide content is not available for this plot yet.
```

Still show any available sections.

Do not fabricate interpretation or literature examples.

------------------------------------------------------------------------

# 27. Content Quality Rules

Guide content must be scientifically defensible.

### Required

-   distinguish graphical encoding from biological interpretation;
-   state important limitations;
-   avoid causal language unless the visualization directly supports it;
-   avoid claiming significance from visual separation alone;
-   explain transformations where they affect interpretation.

### Do not

-   invent literature references;
-   invent DOI values;
-   invent licenses;
-   automatically claim biological mechanisms;
-   describe arbitrary visual patterns as statistically significant.

------------------------------------------------------------------------

# 28. Literature Data Model

Store literature separately if preferable:

``` text
plot_registry
     ↓
literature_reference_ids
     ↓
literature_registry
```

Suggested literature entry:

``` yaml
id: umap_literature_001
title:
authors:
journal:
year:
doi:
url:
figure:
license:
thumbnail_reuse_allowed:
thumbnail_asset:
description:
use_cases:
plot_families:
variants:
```

This avoids duplicating one publication across multiple plot entries.

------------------------------------------------------------------------

# 29. Initial Reference Implementation

Implement the complete Guide experience first for:

``` text
UMAP / t-SNE
```

At minimum include:

### Family

-   summary;
-   best for;
-   common uses;
-   interpretation;
-   limitations/cautions;
-   reporting template.

### Variants

Implement guide content for at least:

-   Clusters
-   Feature Expression
-   Split by Sample
-   Composition Pie
-   Composition Ring
-   Density
-   Highlight
-   Ellipse

### Examples

At least 3 interactive examples:

-   Basic clusters
-   Feature expression
-   Composition

Literature examples may be added only when real references and reuse
status are verified.

------------------------------------------------------------------------

# 30. Future Families

The architecture must be reusable for:

-   Heatmap
-   Volcano
-   Violin
-   Dot Plot
-   GSEA
-   Enrichment Ridge
-   Sankey / Alluvial
-   Gene--Pathway Network
-   Venn / UpSet
-   PCA
-   Trajectory plots

Do not make assumptions that only apply to embeddings.

------------------------------------------------------------------------

# 31. Optional Future AI Layer

Do not require AI for v1.

The deterministic registry should handle:

-   basic explanation;
-   cautions;
-   current mapping explanation;
-   reporting template;
-   example selection.

A future AI layer may optionally answer questions such as:

``` text
Why does my UMAP look fragmented?
Which variant is best for comparing samples?
How should I describe this pattern?
```

Any future AI interpretation must distinguish observation from
inference.

------------------------------------------------------------------------

# 32. Testing

Add tests for:

### Panel behavior

-   opens;
-   collapses;
-   canvas resizes;
-   state persists during navigation where appropriate.

### Registry rendering

-   family summary renders;
-   cautions render;
-   examples render;
-   missing fields do not break UI.

### Variant changes

-   guide updates when variant changes.

### Current-state explanation

-   group mapping reflected;
-   split mapping reflected;
-   composition mapping reflected.

### Reporting

-   caption omits absent mappings;
-   caption includes active mappings;
-   Copy Caption works.

### Demo

-   Try Example loads correct variant/config;
-   current user state is not silently lost.

### Literature

-   no thumbnail shown when reuse is not permitted;
-   source metadata renders correctly.

------------------------------------------------------------------------

# 33. Acceptance Criteria

The implementation is complete when:

-   Plot Studio supports a collapsible left Plot Guide panel.
-   The center remains the active plot canvas.
-   The right side remains configuration-focused.
-   Guide content comes from the plot registry.
-   Family and Variant guides are separate but composable.
-   UMAP/t-SNE has a complete reference guide.
-   At least three UMAP examples are interactive.
-   Important interpretation cautions are displayed.
-   The guide can explain the current variant.
-   The guide can explain active mappings when supported.
-   A conservative caption/reporting helper is available.
-   Literature references support citation/license metadata.
-   Unverified literature figures are not copied into the application.
-   Missing guide content never causes fabricated text.
-   The component architecture is reusable for other plot families.
-   Existing plotting behavior remains unchanged.

------------------------------------------------------------------------

# 34. Non-goals

Do not rewrite plotting algorithms.

Do not move plot configuration controls into the Guide.

Do not turn the Guide into a general chatbot in v1.

Do not automatically interpret biological mechanisms from visual
appearance.

Do not automatically scrape/copy publication figures.

Do not require every plot family to have complete guide content before
releasing the framework.

The core objective is:

> **Left: understand and interpret.\
> Center: visualize.\
> Right: configure and draw.**
