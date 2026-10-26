# AI Plot Studio — fixes and acceptance checks

Date: 2026-10-25. Local application: http://127.0.0.1:8010/.

This follows the [original audit](ai_plot_studio_audit_2026-10-25.md). Existing scientific renderers and canonical example bundles are reused; no new chart engine or baseline was introduced by this repair.

## Implemented repairs

| Audited issue | Resulting behavior |
|---|---|
| Diagnostic intent ignored | A schema-bound render draft carries the requested ROC, precision–recall, calibration or decision-curve mode into the actual R parameters. Negated ROC does not override calibration. Conflicting modes ask the user to choose. |
| Statistical inputs reduced to 60 rows | Statistical rendering reads the complete upload. The old row-limit argument cannot silently sample survival, model predictions or coordinates. The draft shows the observation count. |
| New canonical examples unreachable | The loader resolves the selected manifest, parameters and every declared input together. Mode requests choose the matching bundle, so a built-in calibration figure retains a calibration title. Legacy root examples remain supported. All 22 new engines resolve successfully. |
| Named columns discarded | Schema roles use actual headers, known aliases and explicit `header as role` / `role_column=header` requests. Required survival, prediction and 3D roles are checked before R. Invalid mapping errors name the role and available columns. |
| Failed uploads silently replaced | Adaptation/render failures remain failures using the supplied data. Built-in synthetic data is only used through the separate explicit action, with a visible provenance note and its own row count. |
| Editor loses data and settings | Generated figures hand off a saved job ID. The editor loads its exact saved input bytes and params, displays the saved preview, and rerenders that data. Saved-file access is restricted to declared inputs within the project. |
| Stale results after input changes | File/goal changes clear recommendations, figures, downloads and session identity. Revision checks ignore responses belonging to an earlier input. Rendering controls are disabled while busy; invalid drafts remain disabled afterward. |
| Generic plots outrank explicit requests | Explicit specialty intent takes priority, including after optional LLM reranking. Real-profile first-choice routing improves from 20/22 to 22/22. A follow-up time column no longer implies a multistage flow table. |
| Rules chat only repeats recommendations | Chat can explain the matched workflow, confirm full-data scope and prepare schema-supported mode/group-color edits. It names the proposed colors and requires Apply & render; it never claims an unexecuted edit succeeded. |
| Relevant skill hidden | Matched engine IDs appear before unrelated engines, workflow and authoring roles are distinguished, and View workflow opens the actual local skill text. |
| Failed-job explanation misleading | Failed renders explain that no figure was produced and suggest mapping/input recovery. |
| Unrelated column treated as SE | Combo drafts only infer standard errors from explicit SE/SEM names, never an arbitrary second numeric measurement. |
| Long page and developer copy | Workflow references and palettes are collapsible; mode/mappings/data scope remain visible next to plot actions. User-facing figure names lead the result cards. Result cards use a 420px minimum width when space permits and one column on narrow screens, keeping plot labels readable. Developer environment variable names were removed from the introductory copy. |
| Cached editor logic / navigation reset | Script versions invalidate stale assets. Late initialization preserves the selected navigation mode. |

## Actual browser verification

Synthetic examples only; no private research data was uploaded and no LLM credentials were added or changed.

- Survival: 130 input observations, 65 per cohort; exported group counts confirm 65/65.
- Chat color change: blue/orange group colors are proposed explicitly; Apply & render produces a new full-data figure.
- Renamed survival: all 12 observations render with `followup_months`, `event_status`, `cohort`; group counts are 6/6. Open Editor restores these mappings and 12/12 rows. Run Plot completes and keeps that dataset.
- Calibration: an explicit request ending with “do not draw ROC” produces `statistics.mode=calibration`, 80 observations per model and Brier scores 0.115342 / 0.202808.
- Built-in calibration: selecting Built-in demo under a calibration goal loads its calibration bundle, renders successfully and shows “Probability calibration”; its own synthetic data and Brier values are kept separate from the upload.
- 3D: first recommendation is 3D Embedding and the output contains all 225 supplied coordinates. The separate Built-in demo action also completes and is clearly labeled synthetic.
- Full Run top 3 & explain pipeline: **3/3 completed** on the 160-row prediction table; the leading figure is calibration and secondary plots are clearly separate alternatives.
- Dataset replacement immediately changes the figure-card count from 1 to 0.

[Saved browser job evidence](ai_studio_browser_after_fixes_2026-10-25.json), [22-engine routing and bundle evidence](ai_studio_routing_after_fixes_2026-10-25.json).

Screenshots: [built-in calibration with matching title](screenshots/ai-studio-fixed-builtin-calibration-2026-10-25.png), [final readable result layout](screenshots/ai-studio-fixed-final-layout-2026-10-25.png), [calibration](screenshots/ai-studio-fixed-calibration-2026-10-25.png), [color edit](screenshots/ai-studio-fixed-survival-colors-2026-10-25.png), [editor handoff and rerender](screenshots/ai-studio-fixed-editor-named-data-2026-10-25.png), [full 3D data](screenshots/ai-studio-fixed-3d-2026-10-25.png).

## Gates

- Standards: 80 plugins checked; **0 new violations**, 1,571 previously baselined violations.
- Full Python suite: `pytest -q plot_web/tests vnext/tests`: **192 passed** in the complete-suite rerun; **43 focused AI integration checks passed**, including the final supplied-curve role validation check. One existing Starlette/httpx deprecation warning remains.
- JavaScript: `node --check` passes for both application and editor scripts; `git diff --check` passes.
- Parameter sensitivity: survival, binary evaluation, 3D scatter and circular distribution; **80 scalar perturbations, 0 crashes**. Five initially unchanged images are conditional controls: calibration bins/point size require calibration mode, threshold limits require decision-curve mode, and changing three facet columns to six cannot rearrange only three facets. Mode-aware checks and a one-column layout confirm all five visibly change the output; [results](ai_studio_mode_sensitivity_2026-10-25.json). These paired renders were visually reviewed.
- Full image regression: **137/294 passed, 133 DIFF, 24 FAIL**. The failing and differing example IDs exactly match the prior recorded set: **0 new failures and 0 new image differences**. This is not a fully green historical suite. Existing baselines were not updated. [Regression details](ai_studio_regression_2026-10-25.json).
- Actual full-data survival, calibration, renamed-column and 3D outputs were visually checked; mode-aware sensitivity pairs were also reviewed.

## Limits and remaining work

Optional external LLM behavior was not exercised; rules mode and deterministic structured editing were tested. Free-form chat is not a general arbitrary-edit interpreter; unsupported operations point to editor controls. Users should review inferred mappings and scientific suitability before running alternative recommendations. The existing 24 renderer/environment failures and 133 historical image differences remain a separate library-wide backlog, documented in the regression details above. No claims of complete library-wide rendering correctness are made.
