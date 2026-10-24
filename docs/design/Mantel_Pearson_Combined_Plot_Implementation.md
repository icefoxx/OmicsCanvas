# Implement a Combined Mantel Test + Pearson Correlation Plot

## Objective

Implement a publication-quality visualization that combines:

1. **Pearson correlation matrix** among environmental / metadata variables.
2. **Mantel test relationships** between one or more biological/community distance matrices and the environmental variables.

The target visual style should reproduce the structure of the provided reference figure:

- upper-right triangular Pearson correlation matrix
- diagonal variable labels
- Mantel-test network extending toward the lower-left
- Mantel edge **color = statistical significance**
- Mantel edge **width = Mantel's r strength**

The implementation should be reusable and should accept arbitrary user-supplied variables rather than hard-coding the example variable names.

---

# 1. Conceptual Structure

The figure combines two related but statistically distinct analyses.

## 1.1 Pearson correlation matrix

For environmental variables:

\[
X_1, X_2, ..., X_p
\]

calculate pairwise Pearson correlations:

\[
r_{ij} = cor(X_i, X_j)
\]

The matrix should display only one triangle, preferably the **upper triangle**, while the diagonal contains the variable names.

### Visual encoding

Use:

- **Blue** = positive Pearson correlation
- **Red** = negative Pearson correlation
- **White / near-white** = correlation near zero

Correlation range:

```text
-1 <= Pearson's r <= 1
```

The magnitude of the correlation should also be encoded by square size.

Recommended:

```text
square size ∝ abs(r)
square color = r
```

Therefore:

- large dark-blue square = strong positive correlation
- large dark-red square = strong negative correlation
- small pale square = weak correlation

The diagonal should not display correlation squares. Instead, display the variable names.

Example conceptual structure:

```text
             X1   X2   X3   X4   X5
X1           X1   □    □    □    □
X2                X2   □    □    □
X3                     X3   □    □
X4                          X4   □
X5                               X5
```

---

# 2. Mantel Test Layer

The lower-left portion of the plot represents Mantel tests.

A Mantel test evaluates the association between two distance matrices.

For example:

```text
biological/community distance matrix
                vs
environmental-variable distance matrix
```

For each environmental variable \(X_j\), construct or provide the corresponding distance matrix and calculate:

```text
Mantel's r
P value
```

There may be multiple biological/community matrices.

For example:

```text
Surface
Deep
```

These should appear as separate anchor nodes to the lower-left of the correlation matrix.

Each anchor node is connected to the corresponding environmental variable node.

Conceptually:

```text
             X1
            /
Surface --- X2
   \       /
    \---- X3
     \
      ----X4

Deep ------X1
   \-------X2
    \------X3
```

---

# 3. Mantel Edge Encoding

Mantel relationships should encode **two independent statistics**.

## 3.1 Edge width = Mantel's r

Use line width to indicate Mantel effect size.

Default categories:

```text
Mantel's r < 0.25
0.25 <= Mantel's r < 0.50
Mantel's r >= 0.50
```

Recommended approximate line widths:

```text
r < 0.25       -> 0.5–0.8
0.25–0.50      -> 1.5–2.5
>= 0.50        -> 4–6
```

Make these thresholds configurable.

IMPORTANT:

Mantel's r and P value must remain separate visual dimensions.

Do NOT make thicker lines simply because they are statistically significant.

---

## 3.2 Edge color = Mantel P value

Default significance categories:

```text
P < 0.001
P < 0.01
P < 0.05
P >= 0.05
```

Use a discrete color palette.

Suggested conceptual mapping:

```text
P < 0.001    -> orange
P < 0.01     -> green
P < 0.05     -> purple
P >= 0.05    -> light gray
```

The exact colors may be adjusted for publication quality and accessibility.

IMPORTANT:

The P-value legend should clearly indicate that edge color represents statistical significance.

---

# 4. Layout

The final plot should approximately follow this structure:

```text
                         Pearson correlation matrix
                    ┌───────────────────────────────┐
                    │ X1 X2 X3 X4 X5 X6 ...        │
                    │    X2 □  □  □  □             │
                    │       X3 □  □  □             │
                    │          X4 □  □             │
                    │             X5 □             │
                    └───────────────────────────────┘
                         ↑
                        /
                       /
                Mantel network

          Surface ●
             ╲  ╲ ╲────────────
              ╲  ╲─────────────
               ╲───────────────

          Deep    ●
             ╲  ╲ ╲────────────
              ╲  ╲─────────────
               ╲───────────────
```

The Mantel anchor nodes should be placed below and to the left of the correlation matrix.

Environmental-variable connection points should align with the corresponding diagonal variable positions.

---

# 5. Required Input

The plotting function should support two possible workflows.

## Workflow A: raw data

Input:

```text
environmental dataframe
biological/community abundance dataframe(s)
```

Example:

```python
env_df
community_surface
community_deep
```

The function calculates:

1. Pearson correlations among `env_df` columns.
2. Environmental distance matrices.
3. Community distance matrices.
4. Mantel tests.

---

## Workflow B: precomputed statistics

Allow direct input of:

### Pearson table

```text
var1
var2
pearson_r
pearson_p
```

and Mantel table:

```text
group
variable
mantel_r
mantel_p
```

Example:

```text
Surface MAT   0.12  0.31
Surface CEC   0.63  0.021
Surface ELE   0.71  0.034
Deep    Clay  0.58  0.006
Deep    Fe2O3 0.67  0.042
```

This mode is important because statistical analysis and visualization should be separable.

---

# 6. Statistical Requirements

## Pearson correlation

Default:

```python
scipy.stats.pearsonr
```

or equivalent.

Handle missing values using pairwise complete observations.

Do not silently replace missing correlations with zero.

---

## Mantel test

If Python is used, use a validated Mantel-test implementation.

Possible approaches:

```text
scikit-bio
```

or a clearly implemented permutation-based Mantel test.

The number of permutations should be configurable.

Default:

```text
9999 permutations
```

Set a reproducible random seed.

Example:

```python
random_state = 123
```

Report:

```text
Mantel r
permutation P value
number of permutations
distance metric
```

Do not infer significance from Mantel r alone.

---

# 7. Distance Metrics

The biological/community distance metric must be configurable.

Possible defaults:

```text
Bray-Curtis
Euclidean
Jaccard
```

For ecological/community abundance data, default to:

```text
Bray-Curtis
```

For a single continuous environmental variable, Euclidean distance is appropriate:

\[
D_{ij} = |X_i-X_j|
\]

Do not automatically use Bray-Curtis for arbitrary continuous environmental variables.

---

# 8. Multiple Testing

Provide an optional multiple-testing correction for Mantel tests.

Support at least:

```text
none
BH / FDR
Bonferroni
```

Recommended default:

```text
BH / FDR
```

If adjusted P values are used for edge colors, explicitly label the legend:

```text
Mantel FDR
```

rather than:

```text
P value
```

Keep both raw P and adjusted P in the output table.

---

# 9. Pearson Matrix Appearance

Each upper-triangle cell should contain a centered square.

Square size:

```python
size = f(abs(r))
```

Recommended approximately proportional to:

```python
abs(r)
```

or

```python
sqrt(abs(r))
```

depending on visual balance.

Square fill:

```text
r = +1 -> dark blue
r =  0 -> white
r = -1 -> dark red
```

Use a diverging color scale centered exactly at zero.

The color bar should show:

```text
1
0.5
0
-0.5
-1
```

and be labeled:

```text
Pearson's r
```

---

# 10. Diagonal Labels

Variable names should be displayed along the diagonal.

Example:

```text
MAT
N:P
C:N
C:P
CEC
Litter
MAP
BD
TEB
ELE
Clay
SOC
Al2O3
SA
Root
Fe2O3
pH
```

The implementation must support arbitrary column names.

Do not hard-code these names.

---

# 11. Top Labels

Optionally display variable names again above the correlation matrix, rotated approximately:

```text
90 degrees
```

This should be controlled by:

```python
show_top_labels=True
```

---

# 12. Mantel Anchor Nodes

Each biological/community matrix should have a clearly labeled anchor.

For example:

```text
Surface
Deep
```

Render:

```text
Surface ●
Deep    ●
```

The number of groups must be arbitrary.

Do NOT assume exactly two groups.

Example possible input:

```text
Surface
Middle
Deep
```

should automatically generate three anchor nodes.

---

# 13. Connection Geometry

Connections should preferably be slightly curved rather than perfectly straight when many lines overlap.

Requirements:

- start at group anchor
- terminate at the environmental variable's diagonal node
- use consistent curve geometry
- avoid covering variable labels
- render nonsignificant lines underneath significant lines

Recommended drawing order:

```text
1. P >= 0.05
2. P < 0.05
3. P < 0.01
4. P < 0.001
```

so the strongest evidence remains visible.

---

# 14. Legends

The plot requires THREE independent legends.

## Legend A — Pearson correlation

Continuous color bar:

```text
Pearson's r

+1
+0.5
0
-0.5
-1
```

---

## Legend B — Mantel effect size

Example:

```text
Mantel's r

< 0.25
0.25–0.50
>= 0.50
```

represented using increasing line width.

---

## Legend C — Mantel significance

Example:

```text
Mantel P value

< 0.001
< 0.01
< 0.05
>= 0.05
```

represented using line colors.

If FDR correction is enabled, rename this:

```text
Mantel FDR
```

---

# 15. Output

Generate:

```text
mantel_pearson_combined.pdf
mantel_pearson_combined.png
mantel_pearson_combined.svg
```

PNG:

```text
>= 300 dpi
```

PDF/SVG should remain vector-based wherever possible.

Also save the underlying statistics:

```text
pearson_correlations.csv
mantel_results.csv
```

---

# 16. Recommended API

Implement something conceptually similar to:

```python
plot_mantel_pearson(
    env_df=None,
    community_data=None,
    pearson_results=None,
    mantel_results=None,
    community_metric="braycurtis",
    mantel_permutations=9999,
    p_adjust="BH",
    random_state=123,
    show_top_labels=True,
    figsize=(12, 10),
    output_prefix="mantel_pearson_combined"
)
```

Allow either:

```text
raw data
```

or

```text
precomputed statistics
```

but not require both.

---

# 17. Important Statistical Interpretation

The implementation/documentation must clearly distinguish the two analyses.

### Pearson matrix

Answers:

> How strongly are two environmental variables linearly associated across samples?

### Mantel test

Answers:

> Is the pairwise dissimilarity structure of a biological/community dataset associated with the pairwise distance structure of an environmental variable?

These are NOT the same statistic.

Do not describe a Mantel edge as a Pearson correlation.

Do not interpret either analysis as establishing causality.

---

# 18. Figure Caption Template

Generate a caption similar to:

> **Combined Mantel test and Pearson correlation analysis.** The upper triangular matrix shows pairwise Pearson correlations among environmental variables. Square color indicates the direction of Pearson's correlation coefficient (blue, positive; red, negative), while square size represents the absolute magnitude of the correlation. Network edges connect biological/community distance matrices to individual environmental variables based on Mantel tests. Edge width represents the magnitude of Mantel's r, whereas edge color indicates Mantel-test significance. Gray edges denote nonsignificant associations. Mantel-test P values may optionally be adjusted for multiple testing using the Benjamini–Hochberg procedure.

Do not claim that a statistically significant Mantel association implies a causal environmental effect.

---

# 19. Quality-Control Checks

Before saving the final figure, automatically verify:

1. Pearson correlation values are within [-1, 1].
2. Mantel r values are within the expected correlation range.
3. P values are within [0, 1].
4. Environmental variable names match between Pearson and Mantel inputs.
5. Missing values are explicitly handled.
6. Number/order of diagonal nodes matches the correlation matrix.
7. Mantel edges terminate at the correct environmental variable.
8. Color scale is centered at Pearson r = 0.
9. Edge width is determined ONLY by Mantel r.
10. Edge color is determined ONLY by Mantel P/FDR.
11. Legends accurately describe the visual encodings.
12. Results are reproducible given the same random seed.

---

# 20. Deliverables

The agent should provide:

```text
1. Complete implementation
2. Example input dataset
3. Example execution command/script
4. Pearson statistics CSV
5. Mantel statistics CSV
6. PDF figure
7. PNG figure
8. SVG figure
9. Short README explaining input/output
```

The final plot should closely reproduce the visual grammar of the supplied reference image while remaining a general-purpose implementation rather than a hard-coded recreation.
