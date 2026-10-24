# OmicsCanvas vNext — Skill-Constrained Reproducible Visualization Framework
## Agent Implementation Specification

**Document purpose:**  
Upgrade the existing OmicsCanvas plot-skill system from descriptive Markdown instructions into an executable, validated, reproducible scientific visualization framework suitable for rigorous software evaluation and eventual SCI publication.

**Current assumption:**  
OmicsCanvas already contains plot plugins, and each plot has a `SKILL.md` describing usage, input schema expectations, visual standards, and reproduction instructions. This task must preserve the existing working plotting system and incrementally add a machine-readable specification, validation, provenance, testing, and deterministic execution layer.

---

# 1. Primary Objective

Refactor the current architecture toward:

```text
User Request
    ↓
AI Intent Parser
    ↓
Skill Registry
    ↓
Typed PlotSpec
    ↓
Schema Validation
    ↓
Scientific Validation
    ↓
Deterministic Renderer
    ↓
Figure + PlotSpec + Provenance + Methods + Reproduction Bundle
```

The central rule is:

> The LLM may interpret scientific intent and populate a constrained PlotSpec, but it must not be the final authority on rendering logic, statistical validity, or reproducibility.

After PlotSpec generation, the workflow must cross a deterministic boundary.

---

# 2. Non-Goals

Do **not** prioritize the following in this phase:

- adding large numbers of new plot types;
- redesigning the current visual UI unless required for the new architecture;
- replacing all existing renderers;
- introducing unnecessary framework dependencies;
- using an LLM to directly generate arbitrary plotting code at runtime;
- breaking backward compatibility without documented migration;
- claiming scientific validity merely because a plot renders successfully.

The current plot library is considered sufficiently broad for framework validation.

---

# 3. Required Architectural Components

Implement the following layers.

## 3.1 Plot Skill

Each existing plot remains a plugin skill.

Expected directory pattern:

```text
plugins/
└── <plot_skill_id>/
    ├── SKILL.md
    ├── schema.json
    ├── defaults.yaml
    ├── validator.*
    ├── renderer.*
    ├── metadata.yaml
    ├── examples/
    │   ├── minimal.*
    │   ├── realistic.*
    │   ├── expected_spec.yaml
    │   └── expected_outputs/
    └── tests/
```

Do not force exact file extensions for validator/renderer if the repository already uses another language or plugin structure.

The implementation must adapt to the existing codebase.

---

# 4. Separation of Responsibilities

The responsibilities must be explicit.

## 4.1 `SKILL.md`

Purpose:

- human-readable instructions;
- LLM-facing scientific interpretation;
- plot-selection guidance;
- required biological/statistical semantics;
- description of visual conventions;
- user-facing explanations;
- known limitations.

`SKILL.md` must **not** be the sole source of executable validation rules.

---

## 4.2 `schema.json`

Purpose:

- machine-readable PlotSpec constraints;
- required and optional fields;
- types;
- enums;
- ranges;
- nested structures;
- default compatibility;
- explicit rejection of invalid fields where appropriate.

The schema must support validation without an LLM.

---

## 4.3 `defaults.yaml`

Purpose:

- deterministic defaults;
- no hidden defaults inside prompts;
- no undocumented parameter guessing.

Defaults must distinguish:

```yaml
scientific_defaults:
visual_defaults:
export_defaults:
```

If a scientific choice should not be silently assumed, it must not be supplied as an automatic default.

Example:

```yaml
scientific_defaults:
  multiple_testing_correction: null

visual_defaults:
  show_zero_line: true
  point_alpha: 0.8

export_defaults:
  format: svg
  width_mm: 120
  height_mm: 90
```

---

## 4.4 `validator`

Purpose:

- schema-level validation;
- plot-specific semantic validation;
- scientific/statistical guardrails;
- compatibility checks;
- warnings and errors.

Validator output must be structured.

Example:

```json
{
  "valid": false,
  "errors": [
    {
      "code": "MISSING_SIGNED_EFFECT",
      "field": "mapping.effect",
      "message": "A bidirectional enrichment lollipop requires a signed effect metric."
    }
  ],
  "warnings": [
    {
      "code": "RAW_P_USED",
      "field": "mapping.significance",
      "message": "Raw p-values are being used. Adjusted p-values are recommended for pathway-level multiple testing."
    }
  ]
}
```

The validator must not silently repair scientifically consequential errors.

---

## 4.5 `renderer`

Purpose:

- deterministic rendering from a valid PlotSpec;
- no new scientific inference;
- no LLM calls;
- no hidden variable remapping;
- no undocumented transformation.

Rendering must depend only on:

```text
input data
+
validated PlotSpec
+
declared software/runtime versions
```

---

# 5. Standard PlotSpec

Create a common PlotSpec contract shared by all plot plugins.

Recommended minimum structure:

```yaml
spec_version: "1.0"

skill:
  id: interactive_enrichment_lollipop
  version: "1.0.0"

input:
  dataset_id: optional
  source_file: gsea_results.csv
  checksum: optional

mapping:
  term: pathway
  effect: NES
  significance: padj
  size: gene_count

transform:
  filters:
    - field: padj
      op: "<="
      value: 0.05
  top_n: 20
  ranking:
    field: NES
    method: abs_desc

statistics:
  method: null
  multiple_testing: null

visual:
  orientation: horizontal
  zero_line: true
  stem_to_zero: true

export:
  format: svg
  width_mm: 120
  height_mm: 90

provenance:
  generated_by_ai: true
  user_modified: false
```

Not every skill must use every field.

Use composition/inheritance if appropriate.

---

# 6. PlotSpec Design Requirements

The common schema must support:

- input dataset reference;
- explicit column mapping;
- transformations;
- filtering;
- ranking;
- aggregation;
- statistics;
- uncertainty representation;
- aesthetics;
- labels;
- annotations;
- export settings;
- provenance metadata.

Avoid embedding arbitrary executable code.

Bad:

```yaml
transform:
  code: "df[df.padj < 0.05]"
```

Preferred:

```yaml
transform:
  filters:
    - field: padj
      op: "<"
      value: 0.05
```

The specification must be serializable and portable.

---

# 7. Skill Registry

Create a central registry containing all available plotting skills.

Recommended structure:

```yaml
skills:
  - id: interactive_enrichment_lollipop
    version: "1.0.0"
    family: enrichment
    aliases:
      - enrichment lollipop
      - signed enrichment plot
      - Cleveland enrichment plot

    accepts:
      - enrichment_table

    required_semantics:
      - category
      - signed_effect

    optional_semantics:
      - adjusted_pvalue
      - gene_count

    capabilities:
      interactive: true
      statistics: false
      export_svg: true
      export_pdf: true
      export_png: true

    guardrails:
      - require_signed_metric
      - distinguish_raw_p_and_fdr
```

The registry must be machine readable.

Expected uses:

1. AI plot selection;
2. search/filter in Plot Studio;
3. automated tests;
4. documentation generation;
5. compatibility checks;
6. publication benchmark metadata.

---

# 8. Semantic Data Roles

Do not depend only on physical column names.

Introduce semantic roles such as:

```text
gene
feature
sample
condition
replicate
subject
cell
cluster
category
effect
signed_effect
pvalue
adjusted_pvalue
fold_change
expression
count
score
time
x_coordinate
y_coordinate
group
batch
```

A skill should declare the semantic roles it requires.

Example:

```yaml
required_semantics:
  - category
  - signed_effect
```

AI or user mapping may resolve:

```text
NES → signed_effect
Description → category
```

The resolved mapping must be stored in PlotSpec.

---

# 9. Scientific Validation Layer

This is a mandatory component.

Implement scientific guardrails at three levels.

## 9.1 Global Guardrails

Examples:

- distinguish biological replicate from technical observation;
- detect possible pseudoreplication where metadata permits;
- distinguish raw p-value from adjusted p-value;
- prevent invalid use of FDR labels;
- detect duplicate sample IDs;
- detect non-finite values;
- warn for insufficient group sizes;
- require explicit definition of SD / SEM / CI;
- detect suspicious double-log transformations where inferable;
- ensure transformed axes are compatible with values;
- reject impossible confidence intervals;
- detect empty post-filter datasets.

---

## 9.2 Family-Level Guardrails

Examples:

### Differential expression

- fold-change threshold must reference the correct effect field;
- adjusted p-value and raw p-value must not be interchanged;
- volcano significance classification must be reproducible.

### Heatmap

- scaling mode must be explicit;
- clustering distance/linkage must be recorded;
- row/column ordering must be reproducible;
- constant rows should be handled explicitly.

### Correlation

- report sample size;
- distinguish Pearson/Spearman;
- warn for very small n;
- handle missing values explicitly.

### Box/violin/group plots

- biological replicate structure should be respected;
- statistical unit must be explicit;
- error-bar meaning must be explicit.

### Single-cell plots

- warn against cell-level inference when biological replicate is the experimental unit;
- record aggregation mode;
- distinguish fraction-positive from mean expression.

### Enrichment plots

- distinguish NES/effect from significance;
- detect missing sign when using bidirectional layouts;
- do not treat raw p-value as FDR;
- document ranking method.

---

## 9.3 Skill-Level Guardrails

Each plugin may define additional rules.

For example, `interactive_enrichment_lollipop`:

```text
ERROR if effect is unsigned but negative/positive direction is requested.
ERROR if required pathway/category column is absent.
WARNING if only raw p-values are available.
WARNING if top-N ranking method is ambiguous.
ERROR if no rows remain after filtering.
```

---

# 10. Error Severity

Use at least:

```text
INFO
WARNING
ERROR
BLOCKING_ERROR
```

Behavior:

- INFO: no interruption;
- WARNING: render allowed;
- ERROR: render blocked unless explicitly resolved;
- BLOCKING_ERROR: cannot bypass in normal UI.

Do not allow the LLM to suppress scientific errors by rewriting them.

---

# 11. Deterministic Boundary

Explicitly implement and document:

```text
Natural Language
       ↓
LLM / Intent Resolver
       ↓
PlotSpec candidate
       ↓
==============================
   DETERMINISTIC BOUNDARY
==============================
       ↓
Schema validation
       ↓
Scientific validation
       ↓
Renderer
       ↓
Export
```

After the boundary:

- no LLM-generated plotting code;
- no hidden reasoning-based parameter substitution;
- no autonomous statistical method replacement;
- no unrecorded defaults.

---

# 12. AI Studio Integration

Refactor AI Studio so that a user request follows:

```text
request
→ intent extraction
→ skill selection
→ semantic column mapping
→ PlotSpec generation
→ validation
→ user-visible corrections/warnings
→ render
```

The AI should return structured output internally.

Example:

```json
{
  "selected_skill": "interactive_enrichment_lollipop",
  "confidence": 0.94,
  "mapping": {
    "category": "pathway",
    "signed_effect": "NES",
    "adjusted_pvalue": "padj"
  },
  "plot_spec": {}
}
```

If plot selection confidence is low, AI must expose uncertainty.

Example:

```text
Candidate plots:
1. enrichment_lollipop — 0.61
2. enrichment_bar — 0.33
```

Do not fabricate confidence values unless the implementation has an actual calibrated or explicitly heuristic scoring system.

---

# 13. Ambiguity Handling

The system must distinguish:

1. resolvable ambiguity;
2. scientifically consequential ambiguity.

Resolvable:

```text
"gene_name" likely maps to gene
```

Consequential:

```text
"p" could be raw p-value or FDR
```

Consequential ambiguity must trigger either:

- explicit user selection; or
- a visible warning with no misleading relabeling.

---

# 14. Provenance

Every generated figure must create a provenance record.

Minimum:

```json
{
  "figure_id": "OC-...",
  "timestamp": "...",
  "omicscanvas_version": "...",
  "spec_version": "1.0",
  "skill_id": "...",
  "skill_version": "...",
  "renderer_version": "...",
  "input_files": [
    {
      "name": "gsea_results.csv",
      "sha256": "..."
    }
  ],
  "plot_spec_hash": "...",
  "generated_by_ai": true,
  "ai_model": "...",
  "user_modifications": [],
  "warnings": []
}
```

Where practical, record:

- OS/runtime;
- R/Python version;
- important package versions;
- browser/export backend;
- locale;
- seed.

Do not store sensitive raw user data in provenance unless necessary.

---

# 15. Reproduction Bundle

Every figure should be exportable as:

```text
figure_bundle/
├── figure.svg
├── figure.pdf
├── plot_spec.yaml
├── provenance.json
├── methods.txt
├── reproduce.sh
└── README.md
```

Optional:

```text
data/
```

Only bundle source data if the user explicitly chooses to include it.

---

# 16. Reproduction Command

Implement a CLI or equivalent deterministic command.

Target UX:

```bash
omicscanvas reproduce plot_spec.yaml
```

or:

```bash
omicscanvas render \
  --spec plot_spec.yaml \
  --input gsea_results.csv \
  --out figure.svg
```

Requirements:

- non-interactive;
- reproducible;
- returns non-zero exit code on validation failure;
- logs warnings/errors;
- supports batch execution.

---

# 17. Methods Text Generation

Generate deterministic or template-based methods text from PlotSpec.

Example:

```text
Pathway enrichment results were visualized using the OmicsCanvas
interactive enrichment lollipop skill (v1.0.0). Pathways were filtered
at adjusted P ≤ 0.05 and ranked by absolute normalized enrichment score.
The top 20 pathways were displayed using a horizontal zero-centered
lollipop representation.
```

Methods text must derive only from recorded parameters.

Do not let the LLM invent methods not present in PlotSpec.

AI-assisted stylistic rewriting may be optional, but the canonical method description must remain machine-derived.

---

# 18. Testing Strategy

Testing is mandatory.

## 18.1 Per-Skill Minimum Test Set

For every skill, create at least:

1. minimal valid case;
2. realistic case;
3. edge/error case.

If there are 45 skills:

```text
45 × 3 = at least 135 canonical test cases
```

This is a minimum target, not a hard maximum.

---

# 19. Test Types

Implement:

## 19.1 Schema Tests

Validate:

- required fields;
- invalid enums;
- wrong types;
- unknown fields;
- missing mappings.

## 19.2 Scientific Validator Tests

Test known scientific failure modes.

## 19.3 Renderer Tests

Ensure:

- valid inputs render;
- invalid inputs do not render;
- warnings are surfaced.

## 19.4 Regression Tests

Prefer structural tests.

For SVG:

- SVG parses;
- expected number/type of graphical elements;
- axis labels;
- data-point count;
- zero line presence;
- key text labels;
- deterministic DOM-relevant properties where feasible.

Avoid relying exclusively on pixel-perfect comparisons.

Raster screenshots may be used as a secondary regression layer.

---

# 20. Golden Reference Artifacts

Each skill should provide canonical expected outputs.

Example:

```text
examples/
└── expected_outputs/
    ├── minimal.svg
    ├── realistic.svg
    └── expected_validation.json
```

If visual snapshots are platform-sensitive, use tolerant or structural comparison.

Document the comparison policy.

---

# 21. Continuous Integration

Add CI checks covering:

```text
registry validation
schema validation
all canonical examples
scientific validator tests
renderer smoke tests
reproduction CLI
bundle creation
```

Target:

```text
all registered skills must pass the canonical smoke test
```

A newly added skill must not enter the registry unless tests pass.

---

# 22. Skill Versioning

Each skill must have a version.

Use semantic versioning or a documented equivalent.

Example:

```text
1.0.0
```

Version changes should reflect:

- MAJOR: incompatible PlotSpec behavior;
- MINOR: new backward-compatible features;
- PATCH: rendering/bug fixes without semantic change.

Provenance must record the version.

---

# 23. PlotSpec Versioning

PlotSpec schema itself must have a version independent of skill versions.

Example:

```yaml
spec_version: "1.0"
```

Implement migration hooks for future schema evolution.

Do not silently reinterpret old PlotSpecs.

---

# 24. Skill Registry Validation

Automated checks should ensure:

- unique skill IDs;
- valid versions;
- referenced schema exists;
- referenced renderer exists;
- aliases do not create uncontrolled ambiguity;
- required semantic roles are declared;
- capabilities are valid;
- canonical examples exist.

---

# 25. Backward Compatibility

Existing plotting UI must continue to work.

Preferred migration strategy:

```text
legacy UI settings
→ adapter
→ PlotSpec
→ new renderer pipeline
```

Avoid rewriting all UI panels before the new layer is validated.

If an existing plot cannot yet be fully migrated, mark it explicitly:

```yaml
migration_status: partial
```

---

# 26. Migration Audit

Produce a migration table:

| Skill | SKILL.md | Schema | Validator | Renderer Adapter | Tests | Provenance | Status |
|---|---|---|---|---|---|---|---|
| volcano | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | complete |
| heatmap | ✓ | ✓ | partial | ✓ | ✓ | ✓ | partial |
| ... | | | | | | | |

Do not claim completion without this inventory.

---

# 27. Scientific Rule Documentation

Create central documentation:

```text
docs/
└── scientific_guardrails/
    ├── README.md
    ├── statistical_units.md
    ├── multiple_testing.md
    ├── transformations.md
    ├── uncertainty.md
    ├── single_cell.md
    ├── enrichment.md
    └── correlation.md
```

Each rule should distinguish:

```text
Rule
Rationale
Severity
Applies to
Detectability
False-positive risk
User override policy
Test cases
```

---

# 28. Guardrail Philosophy

Rules must be evidence-based and conservative.

Do not block a user merely because a heuristic suspects an issue.

Classification:

```text
Certain invalidity        → ERROR/BLOCKING_ERROR
Strongly suspicious       → WARNING
Weak heuristic            → INFO
Unknown                   → no unsupported claim
```

Example:

If a table contains thousands of single cells but no sample metadata, do not assert pseudoreplication as fact.

Use:

```text
"Potential pseudoreplication cannot be excluded because biological
replicate identifiers are unavailable."
```

---

# 29. Reproducibility Definition

For the manuscript and implementation, define reproducibility precisely.

Target reproducibility means:

- same input values;
- same explicit mappings;
- same transformations;
- same statistics;
- same plot geometry;
- same plot parameters;
- same semantic output.

Do not promise byte-identical PDF/PNG across operating systems unless actually tested.

Allow documented differences due to:

- font rendering;
- antialiasing;
- graphics backend;
- platform libraries.

---

# 30. Export Requirements

At minimum, preserve or support:

- SVG;
- PDF;
- PNG.

Where practical:

- TIFF.

For publication-oriented exports record:

- dimensions;
- DPI where raster applies;
- font settings;
- transparency;
- vector/raster mode.

---

# 31. User Interface Changes

Add a compact panel for:

```text
Scientific checks
Reproducibility
Plot specification
Provenance
```

Suggested status:

```text
✓ Schema valid
✓ Scientific checks passed
⚠ 1 warning
✓ Reproducible specification saved
```

Do not overwhelm normal users with implementation detail.

Provide expandable advanced sections.

---

# 32. PlotSpec Viewer

Every generated figure should allow:

```text
View PlotSpec
Download PlotSpec
Copy PlotSpec
```

Optional:

```text
Edit PlotSpec
```

If edited, revalidate before rendering.

---

# 33. Provenance Viewer

Add:

```text
Figure ID
Skill
Skill version
Input checksum
Created time
AI-assisted: yes/no
Warnings
```

Advanced:

```text
runtime/package versions
PlotSpec hash
```

---

# 34. Session Integration

Existing Save Session / Load Session must store the PlotSpec, not only UI state.

A restored session should reconstruct:

```text
data reference
mapping
transformations
statistics
visual settings
selected skill
warnings
```

If the original input file is unavailable, clearly report the limitation.

---

# 35. Report Integration

Reports should reference figure provenance.

Each report figure may include a hidden or expandable block:

```text
Figure ID
PlotSpec hash
Skill version
Methods text
```

---

# 36. API / Internal Interfaces

Define stable internal interfaces.

Suggested conceptual API:

```text
list_skills()
get_skill(id)
validate_spec(spec)
validate_science(spec, data)
render(spec, data)
build_provenance(spec, data)
build_bundle(spec, data)
reproduce(spec)
```

Actual language/framework may differ.

---

# 37. Benchmark Preparation

Do not perform the full scientific benchmark until the architecture is stable, but make the framework benchmark-ready.

Create:

```text
benchmark/
├── prompts/
├── datasets/
├── expected_skill/
├── expected_mapping/
├── expected_spec/
├── scoring/
└── results/
```

---

# 38. Future Benchmark Design

Prepare support for comparison:

```text
A. Direct LLM plotting
B. OmicsCanvas constrained plotting
```

Potential metrics:

- skill-selection accuracy;
- column-mapping accuracy;
- schema-valid rate;
- successful render rate;
- scientific-rule violation rate;
- unsupported assumption rate;
- deterministic reproduction rate;
- number of required user corrections;
- time to valid output.

Do not fabricate benchmark results.

---

# 39. Benchmark Ground Truth

Every benchmark prompt must have expert-reviewed expected behavior.

Store:

```yaml
prompt_id:
valid_skills:
required_mapping:
allowed_alternatives:
scientific_constraints:
expected_warnings:
```

Some prompts may have more than one scientifically valid visualization.

Do not score such prompts as if only one answer were correct.

---

# 40. Example Migration: Enrichment Lollipop

For the existing skill shown in the current implementation:

```text
interactive_enrichment_lollipop
```

Implement a complete reference migration first.

Required semantics:

```text
category
signed_effect
```

Optional:

```text
adjusted_pvalue
raw_pvalue
gene_count
group
```

Guardrails:

```text
1. signed effect required for bidirectional plot;
2. raw P must not be relabeled FDR;
3. filter result cannot be empty;
4. size values must be non-negative;
5. category labels must be defined;
6. ranking rule must be explicit;
7. duplicate categories must be handled deterministically.
```

This skill should become the reference implementation for migration of the remaining plugins.

---

# 41. Reference Acceptance Test

Given a valid enrichment table:

```text
Pathway    NES    padj    GeneCount
A          2.1    0.001   40
B         -1.8    0.010   25
C          0.9    0.200   12
```

and specification:

```yaml
mapping:
  category: Pathway
  signed_effect: NES
  adjusted_pvalue: padj
  size: GeneCount

transform:
  filters:
    - field: padj
      op: "<="
      value: 0.05
```

Expected:

- A and B retained;
- C excluded;
- zero-centered orientation;
- A positive;
- B negative;
- size mapping preserved;
- validation passes;
- generated PlotSpec saved;
- provenance saved;
- reproduction command succeeds.

---

# 42. Invalid Reference Test

Input:

```text
Pathway    P
A          0.01
B          0.03
```

Request:

```text
"Plot positive and negative pathway enrichment using NES."
```

Expected:

```text
BLOCK render.
```

Reason:

```text
NES/signed effect is absent.
```

The agent must not fabricate NES values.

---

# 43. Raw P vs FDR Test

Input:

```text
Pathway    NES    pvalue
A          2.1    0.01
```

If user labels significance as:

```text
FDR < 0.05
```

Expected:

```text
ERROR or explicit correction request.
```

The software must not automatically rename `pvalue` to `FDR`.

---

# 44. Deliverables

The agent must produce all of the following.

## Architecture

- architecture document;
- component diagram;
- deterministic boundary description;
- data flow description.

## Schemas

- common PlotSpec schema;
- versioning strategy;
- at least one complete plot-specific schema.

## Registry

- machine-readable skill registry;
- registry validation.

## Validators

- global validator framework;
- enrichment reference validator;
- severity system.

## Reproduction

- provenance builder;
- reproduction bundle builder;
- deterministic CLI or equivalent.

## Tests

- unit tests;
- schema tests;
- scientific validation tests;
- renderer smoke tests;
- regression test framework.

## Migration

- one fully migrated reference skill;
- migration inventory for all existing skills;
- staged migration plan.

## Documentation

- developer documentation;
- scientific guardrail documentation;
- user-facing reproducibility explanation.

---

# 45. Required Reports

The agent must produce Markdown reports after each implementation stage.

Required files:

```text
reports/
├── vNext_01_architecture_audit.md
├── vNext_02_plotspec_and_registry.md
├── vNext_03_reference_skill_migration.md
├── vNext_04_scientific_validation.md
├── vNext_05_provenance_and_reproduction.md
├── vNext_06_testing_and_ci.md
├── vNext_07_full_skill_migration_status.md
└── vNext_FINAL_acceptance_report.md
```

Each report must include:

```text
Implemented
Not implemented
Changed files
Tests executed
Tests passed
Tests failed
Known limitations
Scientific risks
Backward compatibility status
Next recommended action
```

---

# 46. Implementation Phases

## Phase 0 — Repository Audit

Before changing architecture:

1. inspect existing plugin system;
2. inspect all `SKILL.md`;
3. identify rendering languages/frameworks;
4. identify existing schemas;
5. identify session representation;
6. identify AI Studio execution path;
7. identify export architecture;
8. identify existing tests;
9. identify duplicate skill conventions;
10. identify backward compatibility constraints.

Output:

```text
vNext_01_architecture_audit.md
```

No broad refactor before this audit.

---

## Phase 1 — PlotSpec + Registry

Implement:

- common PlotSpec;
- schema validation;
- registry;
- registry validation;
- serialization/deserialization.

Acceptance:

```text
PlotSpec round-trip is lossless for supported fields.
Registry loads without ambiguity/error.
```

Output:

```text
vNext_02_plotspec_and_registry.md
```

---

## Phase 2 — Reference Skill

Fully migrate:

```text
interactive_enrichment_lollipop
```

Implement:

- metadata;
- schema;
- defaults;
- validator;
- adapter/renderer;
- provenance;
- tests;
- reproduction.

Acceptance:

```text
reference skill renders through the new pipeline
without depending on LLM decisions after PlotSpec generation.
```

Output:

```text
vNext_03_reference_skill_migration.md
```

---

## Phase 3 — Scientific Validator Framework

Implement:

- severity classes;
- global rule interface;
- family rule interface;
- skill rule interface;
- structured errors/warnings;
- test suite.

Output:

```text
vNext_04_scientific_validation.md
```

---

## Phase 4 — Provenance + Reproduction

Implement:

- checksums;
- PlotSpec hashes;
- version capture;
- bundle creation;
- methods text;
- CLI/equivalent reproduce command.

Output:

```text
vNext_05_provenance_and_reproduction.md
```

---

## Phase 5 — Testing + CI

Implement:

- canonical examples;
- smoke-test harness;
- regression testing;
- CI gate.

Output:

```text
vNext_06_testing_and_ci.md
```

---

## Phase 6 — Remaining Skill Migration

Migrate skills incrementally by family.

Suggested order:

```text
1. enrichment
2. scatter / volcano
3. expression / statistics
4. heatmaps / clustering
5. dimension reduction / feature
6. single-cell
7. trajectory
8. overlap
9. compositional / flow / miscellaneous
```

Do not mechanically force one schema design onto scientifically different plot families.

Output:

```text
vNext_07_full_skill_migration_status.md
```

---

# 47. Acceptance Criteria

The project is accepted only if all critical criteria are met.

## Critical

- [ ] common PlotSpec exists;
- [ ] PlotSpec is machine validated;
- [ ] skill registry exists;
- [ ] at least one skill fully uses the new architecture;
- [ ] deterministic boundary is enforced;
- [ ] scientific validator exists;
- [ ] provenance is recorded;
- [ ] reproduction bundle is generated;
- [ ] CLI/equivalent reproduction works;
- [ ] automated tests exist;
- [ ] CI verifies canonical examples;
- [ ] existing UI remains functional;
- [ ] invalid scientific mappings are not silently repaired.

## Strongly Recommended

- [ ] all skills migrated;
- [ ] minimum 3 canonical tests per skill;
- [ ] methods text export;
- [ ] PlotSpec viewer;
- [ ] provenance viewer;
- [ ] session restore through PlotSpec;
- [ ] benchmark-ready dataset structure.

---

# 48. Failure Conditions

The implementation must be considered incomplete if any of the following occurs:

- `SKILL.md` remains the only validation layer;
- AI directly writes unrestricted runtime plotting code;
- renderer guesses missing scientific parameters;
- invalid `pvalue` is silently treated as `FDR`;
- plot settings cannot be reconstructed after session restore;
- exported figures lack a recoverable specification;
- provenance does not identify skill/version;
- tests verify only whether a file exists;
- regression suite does not detect semantic plot changes;
- migration breaks major existing plot workflows without documented fallback.

---

# 49. Scientific Acceptance Principles

The system must follow:

```text
data > explicit specification > deterministic validation
> scientific inference > heuristic warning > speculation
```

All uncertain scientific detections must be labeled as uncertain.

The framework should make invalid analysis harder, not merely make valid plots prettier.

---

# 50. Final Agent Instruction

Do not implement this as a cosmetic metadata layer.

The intended architecture is:

```text
SKILL.md
   ↓
intent understanding

schema + registry
   ↓
machine-constrained representation

scientific validator
   ↓
scientific admissibility

deterministic renderer
   ↓
reproducible figure

provenance + bundle
   ↓
auditable research artifact
```

The scientific value of this refactor depends on the guarantees enforced between these layers.

Before making large-scale changes, inspect the existing repository and adapt this specification to the actual implementation.

If any requested component conflicts with existing architecture, document:

```text
Current implementation
Conflict
Scientific consequence
Engineering consequence
Recommended resolution
Chosen resolution
```

Do not silently change project semantics.

---

# 51. Final Acceptance Report

The final report must answer explicitly:

1. Is every generated figure backed by a machine-readable PlotSpec?
2. Can the same PlotSpec be reproduced without an LLM?
3. Are scientific validation rules executable rather than only textual?
4. Are warnings/errors machine testable?
5. Is the exact skill and version recorded?
6. Are input checksums recorded?
7. Can session restore reconstruct the plot semantics?
8. Can a user export a reproduction bundle?
9. How many skills are fully migrated?
10. How many canonical tests exist?
11. What percentage pass?
12. What scientific guardrails are currently implemented?
13. What claims about reproducibility are justified by evidence?
14. What claims are not yet justified?
15. Is the system ready for a formal benchmark against direct LLM plotting?
16. What remains before SCI manuscript preparation?

The final conclusion must be one of:

```text
A. NOT READY
B. ARCHITECTURE READY, MIGRATION INCOMPLETE
C. FRAMEWORK READY FOR BENCHMARK
D. SCIENTIFIC BENCHMARK READY
```

The conclusion must be evidence-based.
