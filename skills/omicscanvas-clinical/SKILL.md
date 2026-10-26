---
name: omicscanvas-clinical
description: Choose scientific plots for clinical outcomes and model evaluation in OmicsCanvas, checking required data roles and interpretation limits.
metadata:
  role: plot_workflow
  layer: scenario
---

# Clinical outcomes and model evaluation

This is an agent-neutral scenario skill. Use it after `omicscanvas-router` identifies this question. It does not call a model provider or launch other agents.

| Question | Engine / choice | Check before plotting |
|---|---|---|
| Survival with right censoring | `survival_plot`; `curve_type=survival` | Nonnegative follow-up, event 0/1, cohort; independent observations. |
| Predicted probabilities match outcomes? | `binary_evaluation_plot`; `plot_type=calibration` | Known binary outcomes, positive class and actual probabilities. |
| Rank discrimination? | Same engine; ROC or precision–recall | Select the intended mode explicitly; preserve score direction. |
| Clinical net benefit? | Same engine; decision curve | Probabilities, clinically meaningful threshold range and comparison baselines. |
| Supplied effects and confidence limits? | `forest_plot` | Units, confidence level and log/ratio scale; no model fitting. |
| Paired method agreement? | `bland_altman_plot` | Pairing, independence and assumptions of limits of agreement. |
| Subject intervals / supplied risk panels / point scales? | Swimmer / risk stratification / nomogram | Supply the analyzed results; these renderers do not train or validate a model. |

A survival curve is not a competing-risk cumulative incidence curve. Censoring-aware time ROC requires upstream analysis. Never choose an optimal cutoff from these demonstrations. If both calibration and ROC are requested, make two explicit plans; do not let one mode replace the other.

## Available engines

`survival_plot`, `binary_evaluation_plot`, `forest_plot`, `bland_altman_plot`, `swimmer_plot`, `nomogram_plot`, `risk_stratification_panel`.

Use `python -m omicscanvas catalog --workflow clinical-outcomes` for the current compact list. Read `python -m omicscanvas describe ENGINE` for the chosen contract, schema and Plot Guide; do not load every plugin skill. Then follow `skills/omicscanvas-render/SKILL.md` to plan, validate and render. From another working directory, use an absolute path to `scripts/omicscanvas.py` with the project's Python environment.

If the scientific question or required role remains ambiguous, report the missing information and keep the candidate set open. Do not substitute synthetic data, infer unavailable analyses, or rank visual attractiveness above scientific suitability.
