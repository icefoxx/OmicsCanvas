# Plot Discovery and UI Entry Redesign Specification v1.0

## 1. Objective

Redesign the plotting website so users can discover plots through **two complementary entry modes**:

1. **Explore by Analysis**
   - For users who know their scientific context or question but do not know the plot name.

2. **Browse / Search by Plot**
   - For users who already know they want a UMAP, volcano plot, heatmap, Sankey, ridge plot, etc.

Both routes must converge on the same underlying plot registry and the same Plot Studio.

This task depends on the centralized plot registry created in Phase 1.

---

## 2. Design Principle

The website should support two user mental models:

### Goal-oriented user

> “I have single-cell data and want to compare composition.”

### Plot-oriented user

> “I want a UMAP pie plot.”

Both should reach the same visualization implementation.

Do not create separate plotting systems for the two routes.

---

## 3. Main Navigation

Add two primary entry modes near the top of the gallery/home page:

```text
Explore by Analysis
Browse All Plots
```

Also retain a global search bar.

Suggested top-level structure:

```text
Scientific Plot Studio

[ Search plots or describe what you need... ]

[ Explore by Analysis ]    [ Browse All Plots ]

Recently Used
Recommended for Your Data
```

---

## 4. Explore by Analysis

Create a task-oriented scientific hierarchy.

Initial categories:

### Single-cell

- Cell clustering
- Gene expression
- Cell composition
- Marker genes
- Trajectory
- Cell-cell relationships

### Bulk Expression

- Expression overview
- Differential expression
- Sample comparison
- Expression patterns
- Gene clustering

### Functional Enrichment

- ORA
- GSEA
- Pathway comparison
- Gene-pathway relationships

### Epigenomics

- Peak signal
- Genomic profiles
- Differential accessibility
- Motif analysis
- Genomic annotation

### Trajectory & Dynamics

- Pseudotime
- Lineage
- Temporal trends

### General Statistics

- Distribution
- Correlation
- Group comparison
- Composition

### Relationships & Overlap

- Venn / UpSet
- Correlation
- Sankey / Alluvial
- Network relationships

These categories should come from registry metadata whenever possible.

---

## 5. Analysis Task Page

When the user selects a task, show recommended plot families rather than immediately opening a plotting tool.

Example:

```text
Single-cell
→ Cell composition

Recommended

[ UMAP Composition ]  Recommended
[ Stacked Bar ]
[ Cluster Composition Dot Plot ]

Other useful views

[ Split UMAP ]
[ Alluvial ]
```

Each card should display:

- Thumbnail
- Plot name
- One-sentence purpose
- Compatibility indicator
- Recommended badge when applicable

---

## 6. Browse All Plots

Retain the existing gallery concept but simplify the category system.

Suggested browse categories:

- Dimension Reduction
- Heatmaps
- Expression
- Differential Analysis
- Enrichment
- Composition
- Distribution
- Relationships
- Trajectory
- General Statistics

Do not force scientific workflows into only one category; use tags from the registry.

---

## 7. Search

Search must support:

- exact plot names
- aliases
- common abbreviations
- scientific tasks
- contexts
- variant names

Examples:

```text
"volcano"
→ Volcano Plot

"ridge"
→ Enrichment Ridge Plot
→ Density Ridge Plot

"sample composition"
→ UMAP Composition
→ Stacked Composition Bar
→ Alluvial Plot

"gene expression across clusters"
→ Dot Plot
→ Violin Plot
→ Feature Plot
→ Heatmap
```

Search results should distinguish:

- exact matches
- recommended matches
- related matches

---

## 8. Natural-language Search

Allow simple intent-like searches using registry metadata.

Do not require a full LLM implementation in this phase.

A deterministic keyword/alias approach is acceptable.

Example:

```text
compare expression between clusters
```

Return plots tagged with:

- single_cell
- gene_expression
- group_comparison

Potential results:

- Violin Plot
- Dot Plot
- Box Plot
- Heatmap

---

## 9. Recommended for Your Data

When data is loaded, inspect its available roles and show compatible recommendations.

Example detected fields:

```text
UMAP_1
UMAP_2
cluster
sample
condition
CD3D
MS4A1
```

Possible UI:

```text
Recommended for your data

Explore clusters
UMAP colored by cluster

Compare samples
Split UMAP by sample

Check composition
Cluster composition by sample

Explore expression
Feature expression on embedding
```

Recommendation logic should use registry rules rather than hard-coded UI conditions.

---

## 10. Plot Cards

A plot-family card should represent a meaningful visualization family, not every minor configuration.

Example:

```text
UMAP / t-SNE
Explore clusters, expression, composition, and annotations
on low-dimensional embeddings.

[ Open Studio ]
[ Quick Demo ]
```

Do not create separate top-level cards for:

- basic UMAP
- ellipse UMAP
- background UMAP
- every density mode

Those belong to variants inside the Studio.

---

## 11. Studio Entry Context

When opening a plot from a scientific task, pass the originating intent to the Studio.

Example:

```text
source_context = single_cell
source_task = cell_composition
plot = umap_tsne
recommended_variant = composition_pie
```

When opening by direct search:

```text
source_context = browse
plot = umap_tsne
variant = composition_pie
```

Both should resolve to the same Studio route.

---

## 12. Preserve Current Navigation Where Useful

The existing left sidebar can remain, but it should no longer be the only discovery mechanism.

Potential redesign:

```text
All Plots
Explore by Analysis
Favorites
Recent

Categories
Dimension Reduction
Expression
Enrichment
Composition
Trajectory
Relationships
```

Avoid a long list of overlapping taxonomy labels.

---

## 13. Favorites and Recently Used

Keep or add:

- Recently used plot families
- Favorite plot families
- Favorite variants

These improve repeat workflows for experienced users.

---

## 14. URL / Routing Model

Recommended route model:

```text
/plots
/analysis/:context
/analysis/:context/:task
/plot/:plotId
/plot/:plotId/:variantId
```

Existing routes should continue to work through redirects or compatibility handlers.

---

## 15. Mobile / Narrow Layout

On narrow screens:

- Stack the two entry buttons vertically.
- Search remains at the top.
- Use 1-column or 2-column cards.
- Sidebar may collapse.
- Do not hide scientific context navigation entirely.

---

## 16. Deliverables

Produce:

1. Updated home/gallery layout
2. Explore by Analysis entry
3. Browse All Plots entry
4. Registry-driven scientific category pages
5. Registry-driven plot gallery
6. Global search
7. Alias-aware search
8. Recommended-for-data section
9. Shared Studio routing
10. Favorites/recent integration if already supported
11. Responsive layout
12. UI screenshots or test snapshots for key states

---

## 17. Acceptance Criteria

The task is complete when:

- Users can enter through both analysis context and plot name.
- Both routes resolve to the same plot registry objects.
- Plot cards represent plot families rather than every preset.
- Search resolves aliases and task terms.
- Single-cell → Cell composition can recommend UMAP composition plots.
- Functional enrichment has its own discoverable category.
- Existing 40+ plotting capabilities remain accessible.
- No plotting feature becomes inaccessible due to the UI simplification.
- The website remains usable for expert users who prefer direct plot search.
- Data-aware recommendations are generated from registry metadata.
- No plotting logic is duplicated between discovery routes.

---

## 18. Explicit Non-goals

Do not yet convert all variants into visual cards inside Plot Studio; that is Phase 3.

Do not delete the existing preset system until migration is complete.

Do not build a full conversational AI assistant in this phase.

Do not change the scientific plotting calculations.
