# Studio usability fixes — 2026-10-24

## Scope and decision

This change repairs the existing shared web editor and discovery pages. No new plugin,
parameter name, chart category, R drawing code, example data, generated registry, or image
baseline was introduced or edited by this work. The checkout already contained substantial
uncommitted plugin, registry and runtime changes; those changes were preserved.

Workflow: [omics-plot-plugins](../../skills/omics-plot-plugins/SKILL.md),
[quality gates](../standards/06_quality_gates.md). Registry build/migration is not applicable
because classification and plugin schemas were not changed. This is **not** a declaration
that the entire plugin catalogue passes the release gates below.

## User-visible repairs

- The standalone editor retains the actual selected File objects, parses them through
  `preview-input`, and sends their bytes and current parameters through `/run` as multipart
  data. `/run-demo` is reserved for example data. All declared input fields are available;
  required secondary inputs cannot silently fall back to example files.
- Failed/empty table uploads leave the previous dataset selected and show an error. Opaque
  secondary files (e.g. gene sets) can still be uploaded without a table preview.
- Dataset source, original filenames and row/column counts are visible. Replacing data
  clears old row/group selections and invalid column mappings, including plugin-specific
  mappings such as `gene_column`.
- Parameter edits carry a revision. A render in progress coalesces subsequent requests into
  the latest state. Stale responses cannot publish downloads as if they were current.
- Dirty, uploading, rendering, or invalid states disable both primary and secondary
  downloads. The previous successful image remains visible with a notice; old scientific
  validation is hidden when settings change.
- Numeric schemas retain integer types and explicit bounds. Invalid numeric input gets a
  field error, retains the last valid parameter, and blocks rendering. JSON configuration
  also receives numeric checks before rendering. Negative label angles remain available.
- Lists/objects use typed structured editors instead of stringifying arrays or objects.
  Invalid structured data and invalid advanced JSON block rendering and show errors.
- Presets load their exact parameters and matching input preview, including direct example
  URLs and plugins without root demo files. Choosing a style preserves explicitly uploaded
  user data. Explicitly loading an example from the guide switches to example data.
- Static figure preview is the default, avoiding automatic display of fallback HTML pages
  containing no interactive plot. Interactive view remains optional. Empty guides collapse.
- Settings search spans all parameter groups. Full-width parameter panels replace the narrow
  vertical navigation/field split. Navigation labels and dataset role labels are clearer.
- The homepage exposes common plots and a direct upload entry, removes empty recommendation
  and recent sections, shortens implementation-oriented card descriptions for common plots,
  and puts session actions in a menu. A loading state replaces the initially blank gallery.
- Header controls wrap rather than clip. At 822px the editor retains a usable two-column
  layout; at small phone widths it stacks. Temporary browser viewport overrides were reset.

## Verification

### Automated

| Check | Actual result |
|---|---|
| `node --test plot_web/tests/frontend/editor_runtime.test.cjs` | 17 passed |
| `python -m pytest -q plot_web/tests vnext/tests` | 83 passed, 1 Starlette/httpx deprecation warning |
| JS syntax checks and `git diff --check` | Passed |
| `python scripts/check_plugin_standards.py group_heatmap` | 1 plugin checked, 0 new violations; 92 baselined violations remain |
| `python scripts/param_sensitivity.py group_heatmap --jobs 4` | 8 parameters scanned, 0 crash, 1 no effect |
| `python -m plot_web.plot_registry validate` | valid=true, 57 plots, 0 errors, 33 warnings |
| `python scripts/smoke_plugins.py --compare --jobs 6` | **74/235 passed; 137 DIFF; 24 FAIL** |

The sensitivity no-effect is `show_column_names` in `cell_heatmap`: the existing cell-mode
branch of `R/sca/GroupHeatmap.R` forces `show_column_names = FALSE`. It is an existing
mode limitation, not a passing sensitivity gate. No plugin schema help text was changed.
Sensitivity was representative (Group Heatmap), not exhaustive across every plugin.

The group heatmap image regression results were: cell_heatmap 0%, clustered_dotplot 0%,
dotplot 1.182% (DIFF), heatmap 0.187% (within tolerance), violin 0.006% (within tolerance).
The full catalogue therefore does **not** have passing image regression. R/plotting files
were not changed in this work, so these results must not be represented as proof of newly
introduced rendering changes or as issues fixed by the web changes.

### Actual browser workflow

On an isolated local server (`127.0.0.1:8010`):

1. Uploaded a synthetic six-row CSV with visibly different values from the built-in data.
   Source label, preview and filter count changed from 151 to 6 rows.
2. Ran the plot. Job `job_20261024_185256_90285204` completed with the uploaded CSV under
   `uploaded_files.input`; actual input bytes were also verified by the API regression test.
3. Searched globally for `base_size`; entered -1 and observed an inline validation error and
   disabled export. Entered 14 and reran successfully. Job
   `job_20261024_185452_08472409` records `base_size=14`, the same user file, and generated
   PNG/SVG/PDF, PlotSpec and validation outputs.
4. Opened `group_heatmap&example=cell_heatmap`; confirmed that the preset selector, input
   preview (260 rows x 15 columns), rendered image and synced status agree.
5. Reviewed desktop, 822px split layout and 375px homepage. Measured document width equal
   to viewport width in the split editor (822) and phone homepage (375).

Browser screenshots:

- [Homepage](assets/studio-home-2026-10-24.jpg)
- [User-data figure and parameter search](assets/studio-editor-2026-10-24.jpg)
- [822px editor](assets/studio-editor-split-2026-10-24.jpg)

Viewed all five existing Group Heatmap example PNG baselines. Existing visual issues remain:
cell-heatmap linker labels cross the dendrogram, the dotplot's long color-bar title reaches
past the right edge, and clustered-dotplot has substantial whitespace. No baseline was
updated. Full manual visual review of all 235 examples and PDF layout equivalence was not
completed; this report does not claim either.

## Remaining catalogue failures

24 render failures in the full run:

| Examples | Count | Reported failure |
|---|---:|---|
| alluvial_plot (4), stat_plot/sankey (1) | 5 | Missing ggsankey |
| interactive_binary_plot (3), interactive_bubble_score_matrix (4), interactive_correlation_matrix (3), interactive_sankey_plot (3) | 13 | selfcontained HTML requires Pandoc |
| interactive_motif_logo_plot | 3 | Missing universalmotif |
| sca_volcano_plot/percent | 1 | Missing see |
| stat_plot/upset | 1 | Missing ggupset |
| stat_plot/venn | 1 | `$ operator not defined for this S4 class` |

137 image differences remain unapproved. Investigate fonts/devices, current uncommitted R
changes and each difference before updating any baseline. Dependencies, the S4 Venn error,
existing plot layout issues, registry warnings and the cell-mode parameter limitation need
separate plugin/runtime work with their own visual and regression verification.
