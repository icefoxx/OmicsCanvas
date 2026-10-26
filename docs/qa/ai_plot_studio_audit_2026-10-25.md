# AI Plot Studio: end-to-end test report

**Follow-up:** See the [repair and verification report](ai_plot_studio_fixes_2026-10-25.md) for implemented fixes. The findings below preserve the original pre-fix evidence.

Test date: 2026-10-25. Local server: `http://127.0.0.1:8010/`, AI Studio tab.

**Result: skills are discoverable, but the complete plotting workflow does not pass acceptance.** Existing routing/unit tests cover matching; this browser audit found missing integration between intent, input mapping, demo resolution, statistical data scope and the editor. Application implementation was not changed during this audit. The deliverables are this report, synthetic fixtures and machine-readable results.

## Scope and environment

- Actual browser interactions: upload, recommendation, single-demo rendering, full top-three pipeline, chat, switching datasets, built-in demo, and opening the generated result in the editor.
- Four synthetic datasets: standard survival (130 rows), supplied 3D coordinates (225 rows), renamed-column survival (12 rows, two cohorts), and model predictions (160 rows). No private research dataset was used.
- Rules engine was active. No LLM credentials were added or changed. Free-text LLM refinement and LLM explanations were not tested.
- A separate backend check used the actual basic example profiles for all 22 new engines. This is not a claim that all 22 were rendered through the browser.
- The initial upload automation timed out on a hidden file input; clicking its visible label succeeded. An earlier automatic-review usage-limit interruption was external to the product. Neither is counted as a product upload failure.

## Measured results

| Check | Result |
|---|---|
| Workflow matching on 22 actual example profiles | 22/22 matched the specialty plotting workflow |
| Correct first-ranked renderer | 20/22; 3D embedding and circular score distribution were outranked by generic plots |
| AI built-in input resolution for 22 new engines | 0/22; manifests exist, but the legacy loader searches root-level example files |
| Existing scoped routing unit tests | 8 passed; these did not exercise the failing end-to-end paths |
| Standard survival: recommend + Generate demo | First choice and workflow correct; rendering succeeded, but only 60/130 rows were used |
| Standard survival: Run top 3 & explain | 2/3 succeeded; irrelevant alluvial recommendation failed because an optional package was missing |
| 3D: Generate demo | Rendered 60/225 rows; workflow matched, but 2D embedding ranked first |
| 3D: Open Editor from the generated figure | Opened the built-in 225-row example instead of the generated 60-row result |
| Explicit named survival columns | Failed with an unhelpful “time” message despite explicit requested mappings |
| Built-in survival demo button | Failed with “No demo files for survival_plot” |
| Requested calibration curve | Selected the right engine, rendered ROC, and reported success |
| Browser console errors | None observed in the checked tab; the failures are logic/integration issues |

## Findings and concrete fixes

### P1 — Requested diagnostic mode is ignored

Upload `plugins/binary_evaluation_plot/examples/basic/input/data.csv`. Ask: “Draw a calibration curve for each model using score as predicted probability and outcome as observed event; do not draw ROC.” Click Recommend only, then Generate demo.

Observed: `binary_evaluation_plot` is first, but `figure.json` reports `statistics.mode: roc`. The generated params contain only generic title/export settings; `plot_type: calibration` is absent. The page marks the job successful and supplies ROC downloads.

Cause: `build_params_for_plugin(plugin_id, profile)` receives no goal or selected mode. Choosing an engine does not choose the correct parameterized chart.

Fix: produce an explicit structured draft containing engine, variant, mappings, statistical options and data scope; validate it against the schema and show those choices before rendering. For this request, the draft must contain `plot_type: calibration`. Do not label a render as fulfilling the request merely because R exits successfully.

Evidence: [full page with request and output](screenshots/ai-studio-calibration-full-page-2026-10-25.png), [output viewport](screenshots/ai-studio-calibration-produces-roc-2026-10-25.png).

### P1 — Statistical inputs are automatically subsampled

The standard survival upload contains 65 observations in each cohort. Generate demo computes a Kaplan–Meier curve from 33 and 27 observations respectively: 60 of 130 total. The 160-row model dataset is reduced to 60 observations, using 40 rows for Model A and 20 for Model B. AUC and prevalence then describe a different population.

The sampling note is visible, but there is no full-data option or prominent statistical warning. `_subsample_rows` uses a deterministic stride followed by truncation, not a random or stratified sample.

Fix: retain all observations for survival, ROC/calibration, statistical tests, empirical distributions, frequencies and uncertainty estimates. If large point clouds need display sampling, distinguish plotted marks from observations used in calculations. Make any demonstration subset explicit and opt-in.

### P1 — New built-in examples are not connected to the AI loader

The survival Built-in demo button returns “No demo files for survival_plot”. A separate `demo_payload` check confirms no input files resolve for any of the 22 new engines, although all have valid `examples/basic/manifest.json` bundles.

Cause: the AI path uses a legacy root-level `example_*` lookup, whereas the gallery/editor use manifest-based bundles.

Fix: reuse the manifest resolver, preserving the selected example ID, its params and all required side inputs. Do not copy or rename canonical files merely to satisfy a legacy lookup. Validate primary and auxiliary inputs before accepting the job.

Evidence: [per-engine resolution results](ai_studio_builtin_resolution_2026-10-25.json).

### P1 — Explicit user column mappings are discarded

Upload [the 12-row renamed-column fixture](fixtures/ai_survival_named_columns.csv). Ask: “Draw a Kaplan-Meier survival curve. Use followup_months as time, event_status as event (0/1), and cohort as group. Use all 12 observations.” Recommend only correctly chooses survival and its workflow. Generate demo fails with “time”.

Cause: the generic adapter has no survival-specific mapping branch and does not consume the explicit mapping in the goal. Defaults still expect `time`/`event`/`group`.

Fix: map and validate required roles before launching R, with an editable column-mapping step. An ambiguous or missing mapping should produce a precise prompt naming the required role and candidate columns. Never replace a failed real-data analysis with an unrelated built-in figure without an explicit user choice.

Evidence: [failure page](screenshots/ai-studio-column-mapping-failure-2026-10-25.png).

### P1 — Opening the editor loses the generated result

Generate the 3D figure, then click Open Editor on its figure card. The URL contains only `plugin=interactive_3d_scatter`. The editor loads “Example data: basic · data.csv · 225 rows × 4 columns”, rather than the generated 60-row data/params.

Fix: hand off the figure/job/dataset identity and actual saved params. The editor should show the generated result, data provenance and exact row count; further changes should apply to that same dataset. A separate “Open built-in example” action can retain the present demo behavior.

### P1 — New datasets retain old figures and downloads

After rendering survival, upload the 3D dataset and click Recommend only. The profile and recommended plots become 3D, but the survival curve, error cards and old download links remain under the current results section. The same issue appears when switching from 3D to the 12-row survival fixture.

Cause: upload `onchange` only updates the file label/state; `applyAiSessionResult(..., withFigures=false)` never clears prior figures.

Fix: invalidate the session, recommendations, explanations and figure cards on input/goal changes. If previous runs remain visible, place them in an explicitly labeled history section with immutable dataset/run identifiers.

Evidence: [mixed-dataset page](screenshots/ai-studio-mixed-datasets-2026-10-25.png).

### P2 — Generic structure scores override explicit specialty intent

Actual-profile routing results: a 3D request ranks `advanced_dim_plot` at 17.2 above `interactive_3d_scatter` at 15.0. Circular score distribution ranks `highlight_effect_plot` at 15.2 above its requested engine at 15.0. The existing unit test uses a minimal generic profile and therefore misses the 3D failure.

Additionally, one numeric follow-up column adds the `stages` tag, causing an irrelevant alluvial recommendation for ordinary right-censored survival data. A hidden legacy statistical wrapper was also recommended for the renamed-column dataset.

Fix: combine explicit requested grammar with required-role compatibility before generic numeric/categorical scoring; require actual stage structure before recommending alluvial. Prefer listed/current families. Test with real example profiles, not only a one-column mock.

Evidence: [all 22 routing outcomes](ai_studio_real_profile_routing_2026-10-25.json).

### P2 — Skill discovery is presented more strongly than execution support

The correct specialty workflow appears, but it is a matched document, not an executed data-preparation policy. The rendering path does not consume the matched workflow when choosing mappings, full-data requirements or statistical modes. The card also truncates an alphabetically sorted list of all mentioned engines, so a survival request shows unrelated tree/3D/binary tags while omitting survival from the visible tags.

Fix: show matched/relevant engine tags first, distinguish user workflows from authoring guides, and provide a read-only View workflow action. Enforce scientific input/data-scope checks in structured runtime validation rather than relying on a Markdown skill merely being present.

### P2 — Rules chat cannot apply requested edits

Asked which skill was used, requested all 130 observations and blue/orange cohort colors. The reply repeated the existing recommendation list and did not answer the skill question or alter data/params.

This is a capability limitation of the tested rules mode, not evidence about an untested LLM provider. Fix: support specific safe commands or explicitly explain that editing is unavailable in this mode and link to the relevant editor controls. Do not imply an edit was applied.

### P3 — Explanation and layout clarity

- Failed render cards still use a generic paragraph telling the user to interpret the figure. Explain the failure and recovery action instead.
- Palette explanations mentioned differential expression during a survival request. Match the actual plotting task and data roles.
- The upper page exposes API environment-variable names and plugin implementation IDs prominently. Put developer configuration in settings/help and lead with user-facing names.
- Recommendation, skill and palette cards make the page very long, while chat occupies a persistent side column. Put the selected plot, mapping and render state near the input; collapse secondary alternatives and palettes.
- Lack of an input file is handled without a crash, but the error says CSV/TSV despite XLSX support. Associate validation with the upload control.

## Recommended repair order

1. Prevent wrong-mode and unintended-subset statistical results; display and validate an explicit plot draft.
2. Connect canonical example manifests and required input mappings.
3. Preserve figure/data/params when opening the editor; invalidate stale session output.
4. Correct explicit-intent routing and use real-profile regression fixtures.
5. Make workflow roles, chat limitations and error recovery clear in the UI.

## Acceptance cases for the repaired page

- A 130-row survival analysis retains 65 observations per cohort unless the user explicitly requests a subset.
- A calibration request produces `statistics.mode: calibration` and matching axes, not ROC.
- The 12-row named-column fixture maps all three roles explicitly and renders 12 observations.
- All 22 canonical built-in bundles resolve all required inputs and their selected params.
- A generated figure opens in the editor with the same data, params and provenance.
- Changing dataset or goal cannot leave old figures under a current-results heading.
- Explicit 3D and circular-distribution requests rank their compatible engines first on actual fixtures.
- A displayed workflow has a clear role and is linked to the actual draft/validation choices.

## Source locations

- [Heuristic profiling, ranking, sampling, mapping and skill matching](../../plot_web/ai_assistant.py).
- [AI render/pipeline and chat endpoints](../../plot_web/server/routes/ai.py).
- [Legacy demo file lookup](../../plot_web/server/plugins.py).
- [AI page state and cards](../../plot_web/static/app.js).

## Changes made during this audit

Only QA artifacts and the synthetic named-column fixture were added. No application, rendering engine, baseline, credentials or package installation was changed. The findings above remain open.
