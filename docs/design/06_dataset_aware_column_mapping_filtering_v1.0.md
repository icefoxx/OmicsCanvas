# OmicsCanvas Dataset-Aware Column Mapping & Filtering UI v1.0

## Objective

Refactor the Plot Studio **Data / Column mapping & filters** interface
so users select values from the loaded dataset instead of manually
typing column names, row IDs, or group values.

The current controls visually behave like free-text inputs:

-   X embedding column
-   Y embedding column
-   Cell / row ID column
-   Group / cluster column
-   Split / facet column
-   Feature columns
-   Rows include / exclude
-   Groups include / exclude

This is error-prone and unnecessarily requires users to remember exact
column/value names.

The target behavior is:

> **Load dataset → detect columns/types → choose columns → dynamically
> choose values → optionally select rows in the dataset preview.**

Do not change the underlying plotting algorithms.

------------------------------------------------------------------------

# 1. Separate Mapping From Filtering

Replace the current combined section:

``` text
Column mapping & filters
```

with two conceptual sections:

``` text
Column Mapping
Filtering
```

They may remain in the same Data tab, but their purposes must be
visually distinct.

------------------------------------------------------------------------

# 2. Column Mapping

Target UI:

``` text
▼ Column Mapping

Plot mode
[ Group ▼ ]

X-axis column *
[ dim1 ▼ ]

Y-axis column *
[ dim2 ▼ ]

Row / cell ID column
[ cell ▼ ]

Group / cluster column
[ cluster ▼ ]

Split / facet column
[ None ▼ ]

Feature column(s)
[ Select features... ▼ ]
```

All column fields must be populated from the currently loaded dataset.

Except where explicitly required, users should not need to manually type
column names.

------------------------------------------------------------------------

# 3. English Labels

Use these user-facing labels:

  Current                             Replace with
  ----------------------------------- -----------------------------------
  X embedding column                  X-axis column
  Y embedding column                  Y-axis column
  Cell / row id column                Row / cell ID column
  Group / cluster column              Group / cluster column
  Split / facet column                Split / facet column
  Feature columns (expression mode)   Feature column(s)
  Rows include                        remove as free-text field
  Rows exclude                        remove as free-text field
  Groups include                      replace with group-level selector
  Groups exclude                      replace with group-level selector

Context/help text may clarify that X/Y usually correspond to embedding
coordinates for dimension-reduction plots.

------------------------------------------------------------------------

# 4. Dataset-Aware Column Selectors

After a dataset is loaded:

1.  inspect column names;
2.  infer basic data types;
3.  populate all applicable selectors;
4.  update selectors whenever the active dataset changes.

Example detected columns:

``` text
cell
dim1
dim2
cluster
sample
condition
CD3D
MS4A1
NKG7
...
```

The UI should present these as searchable dropdowns rather than
free-text inputs.

------------------------------------------------------------------------

# 5. Type-Aware Suggestions

Use data type/cardinality to **prioritize**, not unnecessarily prohibit,
choices.

### X-axis / Y-axis

Prefer:

``` text
numeric columns
```

Likely examples:

``` text
dim1
dim2
UMAP_1
UMAP_2
PC1
PC2
```

### Group / cluster

Prefer:

``` text
categorical
string
factor
low-cardinality integer
```

### Split / facet

Prefer:

``` text
categorical
string
factor
low-cardinality integer
```

### Feature columns

Prefer:

``` text
numeric columns
```

Support multi-select where the plot mode allows multiple features.

### Row / cell ID

Prefer:

``` text
unique or near-unique columns
```

Do not make type inference an absolute restriction unless the plotting
backend truly requires a type.

------------------------------------------------------------------------

# 6. Automatic Mapping Suggestions

Where confidence is high, automatically suggest common mappings.

Examples:

``` text
dim1 + dim2
UMAP_1 + UMAP_2
UMAP1 + UMAP2
tSNE_1 + tSNE_2
PC1 + PC2
```

Likewise:

``` text
cell
cell_id
barcode
```

may be suggested for Row / cell ID.

And:

``` text
cluster
seurat_clusters
cell_type
celltype
```

may be suggested for Group / cluster.

Automatic detection is a convenience only. Users must always be able to
override it.

------------------------------------------------------------------------

# 7. Plot Mode Controls Visibility

`Plot mode` should continue to determine which mappings are relevant.

Example:

### Group mode

Show:

``` text
X-axis
Y-axis
Row / cell ID
Group / cluster
Split / facet
```

Feature column(s) may be hidden or disabled.

### Feature mode

Show:

``` text
X-axis
Y-axis
Row / cell ID
Feature column(s)
Split / facet
```

### Composition mode

Show fields required for:

``` text
embedding coordinates
cluster/group
composition variable
size mapping if applicable
```

Do not show irrelevant mapping controls merely because they exist in the
backend schema.

------------------------------------------------------------------------

# 8. Filtering Section

Target:

``` text
▼ Filtering

Group column
[ sample ▼ ]

Include levels
[ WT × ] [ Control × ]

Exclude levels
[ Select... ▼ ]

Rows
12,495 / 12,495 included

[ Select rows in dataset preview ↓ ]
```

Filtering must be dataset-aware.

------------------------------------------------------------------------

# 9. Group Filtering Is a Two-Step Interaction

The current `Groups include` and `Groups exclude` free-text inputs
should be removed.

Replace them with:

### Step 1 --- select a column

``` text
Group column
[ sample ▼ ]
```

This selector should prioritize categorical/low-cardinality columns.

### Step 2 --- load available values

If `sample` contains:

``` text
WT
KO
Control
```

then dynamically populate:

``` text
Include levels
[ WT ] [ KO ] [ Control ]

Exclude levels
[ WT ] [ KO ] [ Control ]
```

Use searchable multi-select controls.

------------------------------------------------------------------------

# 10. Use "Levels" or "Values", Not "Factors"

Preferred UI terminology:

``` text
Include levels
Exclude levels
```

or, if the implementation must support arbitrary values:

``` text
Include values
Exclude values
```

Do not require the underlying column to be an R `factor`.

Internally, categorical/string/low-cardinality values can all
participate.

------------------------------------------------------------------------

# 11. Include / Exclude Semantics

Define behavior clearly.

Default:

``` text
Include levels = empty
Exclude levels = empty
```

means:

``` text
include all values
```

If Include levels contains values:

``` text
Include = WT, Control
```

only rows matching those values remain eligible.

If Exclude contains:

``` text
Exclude = Batch3
```

matching rows are removed.

If a value appears in both include and exclude, **exclude wins**.

Document this behavior in code/tests.

------------------------------------------------------------------------

# 12. Row Include / Exclude Must Move to Dataset Preview

Remove manual free-text fields:

``` text
Rows include
Rows exclude
```

from the main right-side mapping form.

Row-level selection should primarily happen in the restored dataset
preview.

The right panel should show only a summary:

``` text
Rows
12,320 / 12,495 included

[ Select rows in dataset preview ↓ ]
```

Clicking the button should scroll/open/focus the dataset preview.

------------------------------------------------------------------------

# 13. Restore "Loaded Dataset Preview & Row Filter"

The bottom panel currently exists as:

``` text
Loaded dataset preview & row filter
click to expand
```

but its actual dataframe/table is not visible.

Restore this functionality.

Expanded state:

``` text
Loaded Dataset
12,495 rows × 18 columns

[ Search rows... ]

Showing 12,320 / 12,495 rows

[ Select all ]
[ Clear selection ]
[ Reset filters ]

┌───┬─────────┬──────┬──────┬─────────┬───────────┐
│ ✓ │ cell    │ dim1 │ dim2 │ cluster │ sample    │
├───┼─────────┼──────┼──────┼─────────┼───────────┤
│ ✓ │ Cell001 │ -3.2 │  1.8 │ 3       │ WT        │
│ ✓ │ Cell002 │ -2.9 │  2.1 │ 3       │ WT        │
│   │ Cell003 │  4.1 │ -1.2 │ 8       │ KO        │
└───┴─────────┴──────┴──────┴─────────┴───────────┘
```

The exact table component may differ, but row selection must be
functional.

------------------------------------------------------------------------

# 14. Dataset Preview Responsibilities

The preview should support four related tasks:

``` text
Inspect data
      ↓
Inspect columns
      ↓
Select/filter rows
      ↓
See effective plotting dataset
```

It should not merely be a static preview.

------------------------------------------------------------------------

# 15. Row Selection Behavior

Support:

``` text
Select all
Clear selection
Individual row selection
Search/filter visible rows
Reset row filter
```

If feasible, support shift/range selection later.

For large datasets, do not render every row simultaneously. Use
virtualization/pagination.

Selection state must remain stable while scrolling/paging.

------------------------------------------------------------------------

# 16. Interaction Between Group and Row Filters

The effective dataset should be calculated deterministically.

Recommended order:

``` text
Original dataset
      ↓
Group include filter
      ↓
Group exclude filter
      ↓
Row-level selection/exclusion
      ↓
Other supported filters
      ↓
Effective plotting dataset
```

The UI should display:

``` text
12,320 / 12,495 rows included
```

after all active filters are applied.

------------------------------------------------------------------------

# 17. Auto Update

When `Auto Update` is enabled:

-   changing a column mapping should update the plot;
-   changing group filters should update the plot;
-   changing row selection should update the plot.

Debounce updates when needed.

For expensive plots, avoid rerendering on every transient interaction.

When Auto Update is disabled, preserve changes until `Run Plot`.

------------------------------------------------------------------------

# 18. Data Change / Reload

When the dataset changes:

1.  re-read columns;
2.  re-infer column types;
3.  invalidate mappings that no longer exist;
4.  preserve mappings that still exist;
5.  clear invalid group values;
6.  reset or reconcile row selections;
7.  update preview;
8.  clearly indicate required missing mappings.

Never silently keep references to nonexistent columns.

------------------------------------------------------------------------

# 19. Required Fields

Required mappings should remain clearly marked:

``` text
X-axis column *
Y-axis column *
```

If missing:

``` text
Select an X-axis column.
```

Do not show raw backend errors when a required mapping is absent.

------------------------------------------------------------------------

# 20. Searchable Dropdown UX

For datasets with many columns, selectors must support search.

Example:

``` text
Feature column(s)

Search columns...
----------------
CD3D
CD3E
CD8A
MS4A1
NKG7
...
```

Optional enhancement:

``` text
Suggested
Numeric
Categorical
All columns
```

Do not create an enormous unsearchable HTML select.

------------------------------------------------------------------------

# 21. Feature Multi-Select

`Feature column(s)` should support multi-selection when compatible.

Example:

``` text
Feature column(s)

[ CD3D × ] [ CD3E × ] [ MS4A1 × ]
```

If the active variant accepts only one feature, enforce single selection
and communicate that constraint.

------------------------------------------------------------------------

# 22. Group Filter Should Depend on Selected Column

Example:

``` text
Group column
sample
```

available levels:

``` text
WT
KO
Control
```

If changed to:

``` text
condition
```

the Include/Exclude selectors must immediately reload the unique values
from `condition`.

Previous values that are not valid for the new column must be cleared.

------------------------------------------------------------------------

# 23. Cardinality Safety

Some columns may contain millions of unique values.

Do not populate every unique value into a group-level selector when
cardinality is excessive.

Use a configurable threshold.

For high-cardinality columns:

-   warn that the column is not ideal for categorical filtering;
-   support server-side/search-based value lookup if available;
-   avoid freezing the browser.

Row/cell ID columns should normally not be recommended as group-filter
columns.

------------------------------------------------------------------------

# 24. UI Copy / Help Text

Suggested concise helper text:

### Column Mapping

``` text
Map columns from the loaded dataset to the visual encodings required by this plot.
```

### Filtering

``` text
Limit the data used for plotting by group values or row selection.
```

### Group column

``` text
Choose a categorical column to filter by its available levels.
```

### Row selection

``` text
Select individual rows in the dataset preview below.
```

------------------------------------------------------------------------

# 25. Suggested Final Right Panel

``` text
DATA

▼ Dataset
  filename.csv
  12,495 rows × 18 columns
  [Change dataset] [View data]

▼ Column Mapping

  Plot mode
  [ Group ▼ ]

  X-axis column *
  [ dim1 ▼ ]

  Y-axis column *
  [ dim2 ▼ ]

  Row / cell ID column
  [ cell ▼ ]

  Group / cluster column
  [ cluster ▼ ]

  Split / facet column
  [ None ▼ ]


▼ Filtering

  Group column
  [ sample ▼ ]

  Include levels
  [ WT × ] [ Control × ]

  Exclude levels
  [ Select... ▼ ]

  Rows
  12,320 / 12,495 included

  [ Select rows in dataset preview ↓ ]
```

In Feature mode:

``` text
Feature column(s)
[ CD3D × ] [ MS4A1 × ]
```

appears in the mapping section.

------------------------------------------------------------------------

# 26. Bottom Panel

Restore:

``` text
▼ Loaded Dataset Preview & Row Filter
```

Expanded:

``` text
Loaded Dataset
12,495 rows × 18 columns

Search: [________________]

Showing 12,320 / 12,495 rows

[Select all] [Clear selection] [Reset filters]

[dataframe / virtualized table]
```

Keep:

``` text
Logs & filtered outputs
```

as a separate technical/debug section.

Do not mix logs with the primary dataset preview.

------------------------------------------------------------------------

# 27. State Model

Maintain explicit state for:

``` text
dataset
datasetColumns
columnMetadata

plotMode

xColumn
yColumn
rowIdColumn
groupColumn
splitColumn
featureColumns

filterColumn
includedLevels
excludedLevels

selectedRows / excludedRows

effectiveRowCount
```

Avoid deriving these from arbitrary text inputs.

------------------------------------------------------------------------

# 28. Registry Integration

Where possible, plot families/variants should declare required roles
rather than implementing their own UI.

Example:

``` yaml
data_roles:
  x:
    label: X-axis column
    required: true
    preferred_types:
      - numeric

  y:
    label: Y-axis column
    required: true
    preferred_types:
      - numeric

  group:
    label: Group / cluster column
    required: false
    preferred_types:
      - categorical
      - string
      - low_cardinality_integer

  feature:
    label: Feature column(s)
    multiple: true
    preferred_types:
      - numeric
```

The Data UI should render selectors from these role definitions where
practical.

------------------------------------------------------------------------

# 29. Do Not Hard-Code UMAP Only

UMAP/t-SNE should be the reference implementation, but the
selector/filter system must be reusable for:

-   PCA;
-   scatter plots;
-   volcano plots;
-   heatmaps;
-   violin plots;
-   boxplots;
-   dot plots;
-   enrichment plots;
-   other dataset-driven plots.

Different plot families may expose different data roles.

------------------------------------------------------------------------

# 30. Performance

For large omics datasets:

-   virtualize the preview table;
-   do not recompute all unique values unnecessarily;
-   cache column metadata;
-   cache categorical levels when reasonable;
-   debounce filtering;
-   avoid copying the entire dataframe in the browser for every
    selection;
-   preserve current backend/server-side filtering mechanisms if already
    available.

Do not trade usability for an implementation that fails on realistic
single-cell datasets.

------------------------------------------------------------------------

# 31. Testing

Add tests for:

### Dataset loading

-   columns detected;
-   types inferred;
-   selectors populated.

### Mapping

-   numeric columns prioritized for X/Y;
-   categorical columns prioritized for Group/Split;
-   manual override works.

### Group filtering

-   selecting filter column loads correct levels;
-   changing filter column refreshes levels;
-   Include works;
-   Exclude works;
-   Exclude wins on conflict.

### Row filtering

-   preview expands;
-   dataframe is visible;
-   row selection works;
-   Select all works;
-   Clear selection works;
-   effective count updates.

### Dataset reload

-   valid mappings preserved;
-   invalid mappings cleared;
-   invalid levels cleared.

### Plot update

-   Auto Update reacts correctly;
-   Run Plot works when Auto Update is off.

### Large data

-   preview does not attempt to render all rows simultaneously;
-   high-cardinality group column does not freeze UI.

------------------------------------------------------------------------

# 32. Acceptance Criteria

Complete when:

-   column mapping fields are dataset-aware searchable selectors;
-   users normally do not type column names manually;
-   X/Y selectors prioritize numeric columns;
-   Group/Split selectors prioritize categorical columns;
-   Feature selector supports appropriate single/multi-selection;
-   Group filtering first selects a column and then dynamically exposes
    its levels;
-   Groups Include/Exclude free-text boxes are removed;
-   Rows Include/Exclude free-text boxes are removed from the main form;
-   row selection is performed through the restored dataset preview;
-   `Loaded Dataset Preview & Row Filter` displays a functional table
    again;
-   effective included-row count is visible;
-   filters update the plot correctly;
-   dataset reload safely reconciles mappings/filter state;
-   large datasets remain usable;
-   existing plotting calculations remain unchanged.

------------------------------------------------------------------------

# 33. Core UX Principle

The interface should never make users memorize information that
OmicsCanvas already knows.

If the dataset contains:

``` text
dim1
dim2
cluster
sample
condition
```

OmicsCanvas should **show those choices**.

If `sample` contains:

``` text
WT
KO
Control
```

OmicsCanvas should **show those levels**.

If users want to include/exclude individual rows, OmicsCanvas should let
them **select those rows directly from the dataset preview**.

The desired workflow is:

``` text
Load data
   ↓
Choose from detected columns
   ↓
Choose from detected categorical levels
   ↓
Optionally select rows visually
   ↓
Plot
```
