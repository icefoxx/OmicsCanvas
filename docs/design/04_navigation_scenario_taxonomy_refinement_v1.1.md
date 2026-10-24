# OmicsCanvas Navigation & Discovery Refinement v1.1

## Goal

Refine the current OmicsCanvas discovery UI without rebuilding the
plotting system.

Preserve three complementary entry modes:

1.  **Explore by Scenario** --- start from a scientific question/domain.
2.  **Browse by Chart Type** --- start from a known visual form.
3.  **All Plots** --- directly search/browse plot families.

All routes must converge on the same plot registry and Plot Studio.

This iteration focuses on four changes:

-   remove duplicated navigation;
-   add a **Scientific Task** level under Scenario;
-   clean up the Chart Type taxonomy;
-   enforce `Plot Family → Variant → Preset → Parameters` terminology.

Do not change scientific plotting calculations.

------------------------------------------------------------------------

## 1. Target Information Architecture

``` text
OmicsCanvas
├── Home
├── Explore by Scenario
│   ├── Single-cell
│   │   ├── Cell clustering
│   │   ├── Gene expression
│   │   ├── Cell composition
│   │   ├── Marker genes
│   │   ├── Sample differences
│   │   └── Trajectory
│   │        ↓
│   │     Recommended Plot Families
│   ├── Bulk Expression
│   ├── Functional Enrichment
│   ├── Epigenomics
│   ├── Trajectory & Dynamics
│   ├── General Statistics
│   └── Relationships & Overlap
├── Browse by Chart Type
│   ├── Distribution
│   ├── Comparison
│   ├── Relationship
│   ├── Matrix
│   ├── Composition
│   ├── Flow & Network
│   ├── Sets
│   └── Tables
├── All Plots
│   └── Search + Filters
└── Favorites
```

------------------------------------------------------------------------

## 2. Simplify the Global Sidebar

### Current problem

The sidebar contains the primary navigation plus separate `CATEGORY` and
`BROWSE` sections with overlapping concepts such as `Distribution`.

### Required change

Persistent sidebar:

``` text
DISCOVER

Home
All Plots
Explore by Scenario
Browse by Chart Type
Favorites
```

Optional:

``` text
Recent
```

Remove persistent `CATEGORY` and `BROWSE` subsections. Task/chart-type
navigation belongs inside its corresponding page.

------------------------------------------------------------------------

## 3. Remove Redundant Three-Way Buttons

The sidebar already provides the three discovery routes. Do not repeat
all three buttons inside every page header.

### Scenario

``` text
Explore by Scenario
Start from your scientific question and find suitable visualizations.
```

Then immediately show scenario cards.

### Chart Type

``` text
Browse by Chart Type
Start from the visual form you want to create.
```

Then immediately show chart-type groups.

### All Plots

``` text
Browse All Plots
Search visualization families directly.

[ Search plots... ]
```

Then show filters and plot-family cards.

------------------------------------------------------------------------

## 4. Scenario Must Be Two-Level

Current domain cards such as `Single-cell — 20 plots` are not
sufficient. They describe domains rather than actual scientific tasks.

Required flow:

``` text
Analysis Domain
      ↓
Scientific Task
      ↓
Recommended Plot Families
      ↓
Variant
      ↓
Plot Studio
```

Do not send users from `Single-cell` directly to all 20 plots.

------------------------------------------------------------------------

## 5. Improve Scenario Cards

Instead of:

``` text
Single-cell
20 plots
```

use:

``` text
Single-cell

Explore clusters, gene expression,
composition, markers and trajectories.

6 analysis tasks · 20 plots
```

Counts must be registry-derived.

------------------------------------------------------------------------

## 6. Scientific Tasks

### Single-cell

-   **Cell clustering** --- Explore clusters and annotations.
-   **Gene expression** --- Visualize feature expression across
    cells/groups.
-   **Cell composition** --- Compare proportions across clusters,
    samples or conditions.
-   **Marker genes** --- Inspect and compare marker patterns.
-   **Sample differences** --- Compare conditions, samples or batches.
-   **Trajectory** --- Explore pseudotime, lineage and dynamic changes.

Optional future task: Cell relationships.

### Bulk Expression

-   Expression overview
-   Differential expression
-   Sample comparison
-   Expression patterns
-   Gene clustering

### Functional Enrichment

-   ORA
-   GSEA
-   Pathway comparison
-   Gene--pathway relationships

### Epigenomics

-   Peak signal
-   Genomic profiles
-   Differential accessibility
-   Motif analysis
-   Genomic annotation

### Trajectory & Dynamics

-   Pseudotime
-   Lineage
-   Temporal trends
-   Dynamic expression

### General Statistics

-   Distribution
-   Correlation
-   Group comparison
-   Ranking
-   Summary

### Relationships & Overlap

-   Set overlap
-   Feature relationships
-   Flow relationships
-   Network relationships
-   Correlation

Use registry metadata rather than independent hard-coded plot lists.

------------------------------------------------------------------------

## 7. Recommended Plots After Task Selection

Example:

``` text
Single-cell / Cell composition

Recommended

★ UMAP Composition
  Best for preserving spatial context while showing composition.

★ Stacked Composition Bar
  Best for quantitative comparison across groups.

  Alluvial
  Useful for visualizing changes between categories.

More compatible plots ▾
```

Default to 2--4 recommendations before `More`.

Recommendation priority:

1.  scientific-task match;
2.  data compatibility;
3.  registry recommendation priority;
4.  scenario match;
5.  optional usage/popularity.

Never allow popularity to override scientific/data incompatibility.

------------------------------------------------------------------------

## 8. Rename Category Entry

Rename user-facing:

`Browse by Category`

to:

`Browse by Chart Type`

Internal IDs can remain temporarily for compatibility.

------------------------------------------------------------------------

## 9. Chart-Type Taxonomy

Replace mixed analytical/visual categories with stable chart grammar.

### Distribution

Violin, Density, Histogram, Boxplot, Ridgeline, Beeswarm

### Comparison

Barplot, Dot plot, Lollipop, Radar/Spider, Parallel coordinates

### Relationship

Scatter, Bubble, Connected scatter, 2D density

### Matrix

Heatmap, Correlogram, Dot/Balloon matrix

### Composition

Pie, Donut, Stacked bar, Treemap, composition-specific charts

### Flow & Network

Sankey, Alluvial, Network, Chord

### Sets

Venn, UpSet, set-overlap plots

### Tables

Table, Summary table

Only add `Specialized` for plots that genuinely cannot fit a stable
visual grammar.

------------------------------------------------------------------------

## 10. Chart-Type Cards

Preserve the current icon-card design.

Example:

``` text
[icon]

Violin

2 plot families
```

Clicking a chart type should show matching **plot families**, not
historical presets.

------------------------------------------------------------------------

## 11. All Plots Page

Keep one card per visualization family.

Example:

``` text
UMAP / t-SNE

Dimensionality reduction plots for cell embeddings.

12 variants

[ Explore styles ] [ Quick Demo ]
```

Remove confusing text such as:

`12 variants · Preset cards`

Use one consistent user-facing term: preferably `variants` or
`visualization styles`.

------------------------------------------------------------------------

## 12. All Plots Filters

Treat the chips explicitly as filters:

``` text
Search plots...

Filter:
[ All ]
[ Single-cell ]
[ Expression ]
[ Differential Analysis ]
[ Enrichment ]
[ Composition ]
[ Statistics ]
[ Network ]
```

Conceptual distinction:

-   **Browse by Chart Type** = deliberate exploration by visual grammar.
-   **All Plots filters** = narrowing the master family list.

------------------------------------------------------------------------

## 13. Terminology Contract

Use consistently:

``` text
Plot Family
    ↓
Variant
    ↓
Preset
    ↓
Parameters
```

### Plot Family

Major visualization implementation: UMAP/t-SNE, Heatmap, Volcano, GSEA,
Sankey.

### Variant

Scientifically/visually distinct representation: Clusters, Feature
Expression, Composition Pie, Density, etc.

### Preset

Appearance/default configuration: Recommended, Publication, Minimal,
Presentation, Large Dataset.

### Parameters

Individual controls: point size, alpha, palette, cutoff, label size,
legend position.

Do not call a Variant a Preset in user-facing UI.

------------------------------------------------------------------------

## 14. Preserve Variant Card Architecture

Target:

``` text
Plot Family
    ↓
Variant Gallery
    ├── Recommended
    └── More
    ↓
Plot Studio
    ↓
Preset + Parameters
```

Scenario context may change recommendation order.

Example:

``` text
Single-cell
→ Cell composition
→ UMAP / t-SNE
→ Composition Pie ranked first
```

Direct search:

``` text
Search "UMAP"
→ UMAP / t-SNE
→ generic recommended variants
```

Both must use the same family and Studio implementation.

------------------------------------------------------------------------

## 15. Breadcrumbs

Use breadcrumbs on deeper pages:

``` text
Explore by Scenario / Single-cell / Cell composition
```

``` text
Browse by Chart Type / Distribution / Violin
```

Do not add breadcrumbs to top-level discovery pages.

------------------------------------------------------------------------

## 16. Search

Global search should resolve:

-   family names;
-   aliases;
-   variants;
-   chart types;
-   scientific tasks.

Examples:

-   `UMAP pie` → UMAP/t-SNE → Composition Pie
-   `ridge` → relevant ridgeline families
-   `cell composition` → scientific task + compatible families
-   `GSEA` → GSEA and related enrichment families

Never expose internal registry IDs.

------------------------------------------------------------------------

## 17. Registry Metadata

Extend registry only where required:

``` yaml
analysis_contexts:
  - single_cell

scientific_tasks:
  - cell_composition

chart_types:
  - composition
  - pie

aliases:
  - umap pie
  - cluster composition

recommendation_priority:
  cell_composition: 100
```

Do not duplicate these mappings independently in UI components.

------------------------------------------------------------------------

## 18. Correct Counts

All counts must describe the correct entity.

Examples:

-   `Single-cell — 6 analysis tasks · 20 plots`
-   `Violin — 2 plot families`
-   `UMAP / t-SNE — 12 variants`

Do not count variants and label them as plot families.

------------------------------------------------------------------------

## 19. Migration Order

### Phase A --- Navigation cleanup

-   simplify sidebar;
-   remove repeated page buttons;
-   rename Browse by Category.

### Phase B --- Scenario depth

-   add Scientific Task layer;
-   add registry task metadata;
-   implement recommended families.

### Phase C --- Chart taxonomy

-   migrate chart-type groups;
-   resolve ambiguous assignments;
-   preserve compatibility aliases if needed.

### Phase D --- Terminology audit

Search UI/code for `preset`, `style`, `plot`, `tool`, `category`,
`family`, `variant` and correct user-facing terminology.

Do not blindly rename internal IDs if saved sessions depend on them.

------------------------------------------------------------------------

## 20. Backward Compatibility

Preserve:

-   existing plot IDs;
-   legacy preset resolution;
-   saved sessions;
-   favorites;
-   Quick Demo;
-   direct plot URLs where possible.

Use redirects/mappings when routes change.

------------------------------------------------------------------------

## 21. Testing

Test at minimum:

### Navigation

-   Scenario, Chart Type and All Plots open correctly.
-   Sidebar active state is correct.

### Scenario

`Single-cell → Cell composition → recommended families`

### Chart Type

`Distribution → Violin → matching families`

### Search

-   canonical name;
-   alias;
-   scientific task;
-   variant name.

### Registry

-   counts correct;
-   no orphan tasks/chart types;
-   recommendations resolve;
-   variant links resolve.

### Compatibility

-   representative legacy preset/session still loads.

------------------------------------------------------------------------

## 22. Acceptance Criteria

Complete when:

-   sidebar contains only primary discovery destinations;
-   duplicate CATEGORY/BROWSE sidebar sections are gone;
-   top-level pages do not repeat the same three navigation buttons;
-   Scenario follows `Domain → Scientific Task → Recommended Plot`;
-   Single-cell no longer immediately dumps all 20 plots;
-   Browse by Category is renamed Browse by Chart Type;
-   chart types use coherent visual grammar;
-   All Plots remains the complete searchable family gallery;
-   All Plots chips function as filters;
-   `Family → Variant → Preset → Parameters` terminology is consistent;
-   registry-derived counts use the correct entity type;
-   all existing plotting capabilities remain reachable;
-   legacy sessions/presets remain functional;
-   scientific plotting calculations remain unchanged.

------------------------------------------------------------------------

## 23. Constraints

Do **not** redesign the plotting engine.

Do **not** create separate plot implementations for Scenario, Chart Type
and All Plots.

Do **not** maintain independent hard-coded plot lists for each discovery
page.

Do **not** delete advanced/uncommon plots merely to simplify navigation.

Do **not** convert every historical preset into a plot family.

The purpose of this iteration is to simplify **discovery and information
architecture while preserving plotting capability**.
