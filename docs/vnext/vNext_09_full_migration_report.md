# vNext 09 — Full Migration Report

**Date:** 2026-10-23
**Framework version:** 0.2.0 (supersedes the 0.1.0 acceptance report, `vNext_08_acceptance_report.md`)

## Conclusion

```text
A. ARCHITECTURE READY, MIGRATION COMPLETE (48/48 skills), CURATION PARTIAL (22/48)
```

Every plot_web figure is now backed by a machine-readable PlotSpec, validated
by executable scientific guardrails before rendering, rendered with a seeded R
runtime, and exportable as a self-verifying reproduction bundle.

## 1. What changed since 0.1.0

| Area | 0.1.0 | 0.2.0 |
| --- | --- | --- |
| Skills with PlotSpec support | 1 (hand-written adapter) | 48 (one metadata-driven adapter) |
| Skill metadata | hand-written for 1 skill | generated for all plugins from `params_schema.json` + example data + curated `vnext/migrate/rules.yaml` |
| Adapter direction | PlotSpec → params | PlotSpec ⇄ params, lossless |
| Inputs | single table | all plugin inputs (multi-table skills), SHA-256 per input |
| Scientific rules | global + enrichment + lollipop | global + 6 family rule sets + skill rules; roles resolved against the real input tables incl. the plugins' own autodetect |
| Randomness | unseeded | every R run seeded via `R/runtime/omicscanvas.Rprofile`; seed recorded in the PlotSpec |
| plot_web | flat params only | every job writes `plotspec.json` + `validation.json`; Studio shows validation, exports/imports PlotSpecs, downloads bundles |
| Bundles | spec + one input + figures | + params, all inputs, R package versions, sha256 manifest of every file, `reproduce --compare` |
| CI | vnext unit tests only | plot_web + vNext tests (incl. 208-example round trip), R smoke renders, bundle reproduction on Linux |

## 2. Migration status by family

Families select the scientific rule set. "Curated" = the skill has a hand-written
entry in `vnext/migrate/rules.yaml` (roles for ambiguous parameters, statistics
parameters, required roles, autodetect candidates); the remainder use generated
metadata only.

| Family | Skills | Curated | Family-specific rules |
| --- | ---: | ---: | --- |
| enrichment | 5 | 5 | missing signed effect, effect not bidirectional |
| differential_expression | 1 | 1 | effect not bidirectional, fold change not log-scaled |
| embedding | 4 | 2 | non-numeric coordinates, duplicate ids, too many groups |
| composition | 4 | 0 | negative parts |
| group_comparison | 11 | 5 | comparisons without a recorded test, groups with n < 3 |
| matrix | 11 | 5 | — (global rules) |
| correlation | 4 | 4 | — (global rule: correlation outside [-1, 1]) |
| network | 3 | 0 | negative weights, self loops |
| set_overlap | 2 | 0 | — |
| genomic_track | 2 | 0 | — |
| multi_panel | 1 | 0 | — |
| **Total** | **48** | **22** | |

Global rules (all skills): mapped column missing (error for required roles,
warning otherwise), role unsupported by the renderer, required role unresolved,
non-numeric / non-finite values in numeric roles, p-values outside [0, 1], raw
p-values used as adjusted, adjusted p < raw p, raw p used / labelled as FDR,
correlation outside [-1, 1], negative sizes, multiple-testing flag without an
adjusted column, columns chosen by autodetection (info).

## 3. Evidence

All numbers below are reproducible with the commands shown (data files are in this directory).

### E1 — PlotSpec round trip is lossless

`params.json → PlotSpec → JSON text → params.json` reproduced the original
parameters exactly for **208/208 example bundles across 48 plugins**, and every
generated PlotSpec passed the JSON Schema (`pytest vnext/tests`). The generic
adapter produces the same parameters as the original hand-written lollipop
adapter for the reference OCT4 spec.

### E2 — No false-positive errors on clean data

Validating all 208 clean examples: **0 scientific errors**. Warnings raised are
genuine: 9 examples plot raw p-values (`RAW_P_USED`), 1 maps an optional column
that the input lacks (renderer ignores it).

### E3 — Fault injection

`python -m vnext.cli benchmark --render --jobs 6 --out docs/vnext/benchmark_guardrails.json`

13 fault types were injected into copies of the example inputs/specs wherever
applicable (266 corrupted cases from 208 examples). Each case was validated and
also rendered by the unmodified legacy pipeline.

| Fault | Cases | Plugins | Detected | Detected as error | Legacy rendered silently |
|---|---:|---:|---:|---:|---:|
| correlation_out_of_range | 3 | 1 | 3 | 3 | 0 |
| duplicate_cell_ids | 48 | 3 | 48 | 0 | 35 |
| effect_sign_lost | 11 | 4 | 11 | 0 | 9 |
| fold_change_not_log2 | 4 | 1 | 4 | 0 | 2 |
| negative_composition | 9 | 4 | 9 | 9 | 6 |
| negative_size | 5 | 2 | 5 | 5 | 5 |
| pvalue_already_-log10 | 17 | 7 | 17 | 17 | 14 |
| raw_and_adjusted_swapped | 2 | 2 | 2 | 0 | 2 |
| raw_p_labelled_as_fdr | 9 | 3 | 9 | 9 | 9 |
| raw_p_used_as_adjusted | 8 | 4 | 8 | 8 | 8 |
| required_column_missing | 54 | 5 | 54 | 54 | 5 |
| role_not_supported_by_renderer | 9 | 3 | 9 | 9 | 9 |
| text_in_numeric_role | 87 | 19 | 87 | 87 | 11 |
| **Total** | **266** | | **266** | **201** | **115** |

* **115/266 (43%) corrupted inputs were rendered by the legacy pipeline without
  any error** — a figure was produced that misrepresents the data. All 115 were
  flagged by vNext; 67 of them as errors (the rest are judgement calls reported as
  warnings, e.g. duplicated cell ids or a lost effect sign).
* The most dangerous faults are silent 100% of the time in the legacy pipeline:
  raw p-values used as adjusted (8/8), raw p labelled as FDR (9/9), roles the
  renderer silently drops (9/9), negative sizes (5/5).
* Faults that break R anyway (text in numeric columns, missing required columns)
  are detected earlier and with a specific message instead of an R traceback.

### E4 — Reproduction from the PlotSpec alone

`python -m vnext.cli benchmark --reproduce --jobs 1 --out docs/vnext/benchmark_reproduction.json`

Every example was converted to a PlotSpec, converted back to parameters and
re-rendered; the PNG was compared with the example's stored baseline
(changed pixels > 0.2% counts as different). Result: **208/208 examples (48 plugins) pixel-identical**, both rendering
sequentially and with six concurrent R processes.

A bundle downloaded from the web app reproduces outside it
(`vnext.cli reproduce --bundle-dir … --compare`): input checksums, PlotSpec hash and
parameters match, and the figure is pixel-identical. CI repeats this on Linux.

### E5 — Determinism

Two independent sources of non-determinism were found and removed:

1. **Unseeded randomness.** Three plugins rendered differently on consecutive runs
   with identical inputs (pixels changed: sankey 1.8%, sca_volcano 4.0%, fgsea 0.3%;
   ggrepel placement, jitter, permutation p-values). Fixed by seeding every R run.
2. **The cairo PNG device.** 22 plugins wrote PNGs with `png(type = 'cairo')`, whose
   text-metric layout is not stable on the reference machine: 10 identical renders of
   `combo_bar_line_plot/basic` produced 2 distinct files (7/3), shifting the panel by a
   few pixels. `ragg::agg_png` produced 10/10 byte-identical files. All 22 plugins now
   use ragg (falling back to cairo only when ragg is not installed); the change is
   visually equivalent (≤ 5.8% anti-aliasing pixels, no layout or size change) and the
   baselines were refreshed after visual review.

After both fixes, the 208-example image regression passes on repeated runs.

### E6 — Defects found by the migration (case studies)

Building metadata mechanically from schemas and example data surfaced defects
that the legacy pipeline hid:

1. `sca_volcano_plot` documents `pval_column` as the *adjusted* p-value, but its
   autodetect list falls back to the raw `p_val` — a table without `p_val_adj`
   yields a volcano plot whose "adjusted" significance is raw. Now `RAW_P_USED_AS_ADJUSTED`.
2. The 0.1.0 lollipop adapter mapped `adjusted_pvalue` to `padj_column`, a
   parameter the renderer does not have — adjusted p-values in a PlotSpec were
   silently dropped. Now `UNSUPPORTED_ROLE`.
3. `interactive_enrichment_lollipop` autodetects its "p-value" from a list that
   mixes raw (`pvalue`) and adjusted (`fdr`, `padj`, `qvalue`) names. Reported
   as `ADJUSTED_P_AS_PVALUE` when it picks an adjusted column.
4. Six `advanced_dim_plot` example bundles referenced columns from an older
   synthetic dataset and failed in the gallery; repaired against the current data.
5. Extra inputs `features`/`annotations` (genomic tracks) and `scores` (bubble
   matrix) were never passed to R by the web runner; inputs are now mapped from `config.yaml`.
6. `stat_plot` read its palette from a hard-coded absolute path of one developer's machine.

## 4. Answers to the acceptance questions (cf. vNext_08)

| # | Question | 0.2.0 answer |
|---|---|---|
| 1 | Every generated figure backed by a machine-readable PlotSpec? | **Yes** for all plot_web jobs (`plotspec.json` per job); `PLOT_VALIDATION_MODE=off` disables it. |
| 2 | Same PlotSpec reproducible without an LLM? | **Yes** — E4. |
| 3 | Scientific validation executable? | **Yes** — global + 6 family + skill rule sets (`vnext/validate/scientific.py`). |
| 4 | Warnings/errors machine-testable? | **Yes** — structured codes; 19 vNext tests incl. a fault-injection subset. |
| 5 | Exact skill and version recorded? | **Yes** — PlotSpec `skill`, bundle manifest, methods text. |
| 6 | Input checksums recorded? | **Yes** — SHA-256 per input in PlotSpec `inputs` and for every bundle file. |
| 7 | Session restore reconstructs plot semantics? | **Partly** — Studio exports/imports PlotSpecs (settings); the dataset must be reloaded unless it is the demo data. |
| 8 | User can export a reproduction bundle? | **Yes** — Studio export menu / `GET /api/figures/{id}/bundle`. |
| 9 | Skills fully migrated? | **48/48** generated and validated; **22/48** curated. |
| 10 | Canonical tests? | 74 pytest cases (55 plot_web + 19 vNext), 208-example image regression, fault-injection and reproduction benchmarks. |
| 11 | Pass rate? | 100% of pytest; 208/208 image regression; E3/E4 above. |
| 12 | Guardrails implemented? | See §2. |
| 13 | Justified reproducibility claims? | Deterministic re-rendering of all 208 examples from PlotSpecs on the reference machine; bundle self-verification (checksums, hash, params, pixels). |
| 14 | Claims not yet justified? | See §5. |
| 15 | Ready for benchmark vs direct LLM plotting? | **Yes, system-wide** — every skill accepts a validated PlotSpec. The benchmark itself is not run yet. |
| 16 | Remaining before manuscript? | See §6. |

## 5. Limitations and threats to validity

* **In-sample fault benchmark.** The fault types and the rules were written by the
  same authors; E3 shows the rules detect the faults they were designed for and do
  not fire on clean examples. It does not estimate recall on real-world errors. A
  blinded fault set (faults specified by someone who has not seen the rules) and a
  corpus of documented figure errors from the literature are needed.
* **Curation is partial.** 26/48 skills rely on generated metadata. Column
  detection is mechanical (schema type/name + example values) and was checked
  against all 208 examples, but semantic roles of those skills are less specific,
  so fewer family rules apply to them.
* **Visual semantics are not modelled.** Aesthetic parameters live in
  `legacy_params`; only roles, statistics and export are semantic.
* **Platform dependence.** Pixel baselines are specific to the machine that made
  them (fonts, graphics devices). Cross-platform claims rest on the in-job bundle
  reproduction in CI, not on comparison with the macOS baselines.
* **Graphics-device dependence.** Determinism relies on ragg being installed; on a
  machine without it the cairo fallback can shift layouts by a few pixels (E5).
* **Session restore** does not yet carry the dataset itself.

## 6. Next steps for the manuscript

1. LLM benchmark: the same analysis requests answered by (a) an LLM writing plotting
   code directly and (b) an LLM filling a PlotSpec that vNext validates and renders;
   score scientific correctness, reproducibility and failure modes.
2. Blinded fault set + literature error corpus to estimate guardrail recall.
3. Curate the remaining families (composition, network, set overlap, genomic tracks).
4. Pin the R runtime (renv lockfile / container image) so bundles reproduce across machines.
5. Bundle import in Studio (settings + data) for complete session restore.
