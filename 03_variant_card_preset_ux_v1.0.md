# Plot Variant Card and Preset UX Specification v1.0

## 1. Objective

Replace the current long preset dropdown with a visual, structured selection system based on:

1. **Variant cards**
2. **Recommended variants**
3. **More variants**
4. **Appearance presets**
5. **Context-sensitive parameter groups**

The goal is to let users choose how a plot should look by seeing visual examples rather than interpreting internal preset names.

This task depends on the normalized plot registry and the redesigned discovery UI.

---

## 2. Terminology

Use the following user-facing concepts:

### Variant

A scientifically or visually distinct representation.

Examples for UMAP:

- Clusters
- Feature Expression
- Split by Sample
- Composition Pie
- Composition Ring
- Density
- Highlight Cells
- Ellipse

### Preset

A configuration bundle for appearance or output style.

Examples:

- Recommended
- Publication
- Minimal
- Presentation
- Large Dataset

Do not call every historical configuration a “preset” in the UI.

---

## 3. Replace Long Dropdown

Current behavior resembles:

```text
Preset ▼
  Basic UMAP
  Ellipse marks
  Split by sample
  Composition rings
  Highlight cells
  Background by mito cutoff
  density_filled
  density_hex
  embedded_pie
  ...
```

Replace this with a visual selector.

Example:

```text
Choose a visualization

Recommended
┌────────────┐ ┌────────────┐ ┌────────────┐
│ thumbnail  │ │ thumbnail  │ │ thumbnail  │
│ Clusters   │ │ Expression │ │ Split      │
└────────────┘ └────────────┘ └────────────┘

┌────────────┐ ┌────────────┐
│ thumbnail  │ │ thumbnail  │
│ Composition│ │ Density    │
└────────────┘ └────────────┘

More styles ▾
```

---

## 4. Variant Card Requirements

Each card should contain:

- Preview thumbnail
- Variant name
- Optional short description
- Selected state
- Recommended badge where applicable
- Compatibility warning where needed

Example:

```text
┌─────────────────────┐
│ [preview image]     │
│ Composition Pie     │
│ Sample fractions    │
│ shown per cluster   │
│ Recommended         │
└─────────────────────┘
```

Do not overload cards with parameters.

---

## 5. Recommended Section

Show only a limited number of variants initially.

Default target:

- 4–6 recommended cards

Recommendation can depend on:

- scientific context
- originating task
- detected data columns
- data size
- previously selected mappings

Example:

```text
Single-cell → Cell Composition

Recommended
- Composition Pie
- Composition Ring
- Split by Sample
- Stacked Composition
```

When entering UMAP directly from search:

```text
Recommended
- Clusters
- Feature Expression
- Split by Sample
- Composition
```

---

## 6. More Section

Less commonly used variants should be collapsed initially.

Example:

```text
More styles (8) ▾
```

Expanded:

- Ellipse
- Hex Density
- Filled Density
- Highlight Ring
- Background Mask
- Specialized annotation variants

The More state should persist during the current session where practical.

---

## 7. Preview Thumbnail Strategy

Every variant should have a representative preview.

Preferred order:

1. Pre-rendered curated preview asset
2. Generated demo preview
3. Generic placeholder only if preview cannot be produced

Preview requirements:

- Same aspect ratio across cards
- Lightweight image
- No unreadable tiny labels
- Visually emphasize the difference between variants
- Use representative demo data
- Avoid screenshots containing the full application chrome

---

## 8. Demo Interaction

Cards should support a lightweight demo action.

Possible interactions:

### Default

Click card:
- selects variant
- updates current plot using current data

### Optional secondary action

```text
Try Demo
```

This loads registry-defined demo data/config.

Do not replace the user's current data without an explicit action.

---

## 9. Selected State

The selected card must be obvious.

Suggested state cues:

- Border
- Check icon
- “Selected” label
- Slightly stronger card emphasis

Avoid relying on color alone.

---

## 10. Card Grouping

Group variants by semantic purpose when there are many.

Example for UMAP:

```text
Basic
- Clusters
- Expression

Compare
- Split by Sample
- Highlight Cells

Composition
- Pie
- Ring

Density
- Filled Density
- Hex Density

Annotation
- Ellipse
- Labels
```

The top Recommended section may mix categories.

---

## 11. Appearance Preset Control

After a variant is selected, provide a separate preset control.

Example:

```text
Style preset
[ Recommended ▼ ]

Recommended
Publication
Minimal
Presentation
Large Dataset
Custom
```

Selecting a preset updates parameter defaults but does not switch the variant.

---

## 12. Parameter Panel Refactor

Show parameter groups relevant to the selected variant only.

Suggested structure:

```text
DATA
▾ Data mapping
  X embedding
  Y embedding
  Group
  Feature
  Split

VISUALIZATION
▾ Marks
▾ Colors
▾ Labels

VARIANT-SPECIFIC
▾ Composition
or
▾ Density
or
▾ Highlighting

LAYOUT
▸ Axes
▸ Legend
▸ Title
▸ Theme

OUTPUT
▸ Canvas
▸ Export
```

Examples:

### Cluster variant

Do not show composition controls.

### Composition Pie

Show:

- composition variable
- cluster variable
- pie placement method
- pie size
- border
- labels

### Feature Expression

Show:

- feature
- scale
- min cutoff
- max cutoff
- transform
- color map

---

## 13. Guided vs Advanced Mode

Add optional complexity control.

Example:

```text
Mode
● Guided
○ Advanced
```

### Guided

Show:

- data mapping
- main visual controls
- color
- labels
- basic theme

### Advanced

Additionally show:

- rasterization
- density bandwidth
- centroid method
- clipping
- scale transformations
- legend overrides
- implementation-specific controls

Do not remove advanced functionality.

---

## 14. UMAP Reference Implementation

Use UMAP/t-SNE as the first complete migration.

Initial recommended variants:

- Clusters
- Feature Expression
- Split by Sample
- Composition Pie
- Composition Ring
- Density
- Highlight
- Ellipse

Historical UMAP presets should map to these variants.

Example:

```text
basic_umap
→ Clusters

embedded_pie
→ Composition Pie

composition_ring
→ Composition Ring

split_samples
→ Split by Sample

density_hex
→ Density / Hex layout

density_filled
→ Density / Filled layout

ellipse_mark
→ Ellipse

highlight_cells
→ Highlight
```

Items that are parameters rather than variants must not receive cards.

---

## 15. State Model

Recommended state fields:

```ts
plotId
variantId
presetId
variantOptions
dataMappings
parameterValues
advancedMode
moreExpanded
```

Switching variants should:

- preserve compatible data mappings
- preserve common parameters where sensible
- reset only incompatible variant-specific parameters

Example:

Switching from Cluster to Composition Pie should keep:

- x
- y
- cluster
- current theme

but may initialize:

- composition variable
- pie size

---

## 16. Compatibility States

Cards may be disabled when required data is missing.

Example:

```text
Composition Pie
Requires:
- cluster
- sample/group
```

Disabled cards should explain what is missing.

Prefer:

```text
Add a categorical sample column to use this view.
```

Do not silently hide every incompatible variant, because the card can teach users what is possible.

---

## 17. More / Recommended Ranking Logic

Suggested ranking priority:

1. Originating scientific task
2. Data compatibility
3. Registry priority
4. User recent usage
5. General popularity

Do not let popularity override scientific incompatibility.

---

## 18. Responsive Behavior

Desktop:

- 3–5 cards per row depending on width

Tablet:

- 2–3 cards per row

Mobile:

- 1–2 cards per row

The More section should remain collapsible.

---

## 19. Accessibility

Cards must support:

- keyboard selection
- focus states
- screen-reader labels
- non-color selected state
- tooltip or text for disabled state

---

## 20. Deliverables

Produce:

1. Generic VariantCard component
2. VariantGallery component
3. Recommended section
4. More section
5. Selected state
6. Disabled/incompatible state
7. Preview thumbnail support
8. Separate appearance preset selector
9. Context-sensitive parameter panel
10. Guided / Advanced mode
11. Complete UMAP/t-SNE migration
12. Legacy preset mapping support
13. Demo loading behavior
14. Responsive layout
15. Tests and snapshots

---

## 21. Acceptance Criteria

The task is complete when:

- The old UMAP preset dropdown is no longer the primary variant selector.
- Scientifically distinct UMAP outputs appear as visual cards.
- Parameter-only configurations do not appear as cards.
- 4–6 recommended variants are shown by default.
- Additional variants are available under More.
- Every card has a usable preview.
- Selecting a variant updates the plot without opening a second plotting system.
- Appearance presets are independent of variants.
- Variant-specific parameters appear only when relevant.
- Advanced controls remain accessible.
- Legacy saved presets still load.
- The system can render cards from registry metadata rather than hard-coded UMAP UI definitions.

---

## 22. Non-goals

Do not redesign plotting algorithms.

Do not create one top-level plot card per historical preset.

Do not remove expert controls.

Do not duplicate parameter schemas between cards and Studio.

Do not hard-code UMAP behavior in a way that prevents reuse for other plot families.

The final component system must be reusable for heatmaps, enrichment plots, volcano plots, Sankey plots, and other families.
