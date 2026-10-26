# Portable scientific plotting skills and CLI

OmicsCanvas provides a provider-neutral Markdown workflow and a local Python CLI. The CLI uses existing R renderers and vNext validation/reproduction; it does not start FastAPI, call an LLM, require model credentials or require MCP. Use an existing project Python environment with the project dependencies and an R installation with the selected plugin's packages.

## Quick start: executable synthetic example

Run from the repository root:

```bash
plot_web/.venv/bin/python -m omicscanvas doctor
plot_web/.venv/bin/python -m omicscanvas catalog --workflow clinical-outcomes
plot_web/.venv/bin/python -m omicscanvas describe survival_plot
plot_web/.venv/bin/python -m omicscanvas plan --plugin survival_plot \
  --example basic --output /tmp/survival-plan.json
plot_web/.venv/bin/python -m omicscanvas validate --plan /tmp/survival-plan.json
plot_web/.venv/bin/python -m omicscanvas render --plan /tmp/survival-plan.json \
  --output /tmp/survival-figure
```

Use a new/empty output directory. `/tmp/survival-figure` contains PNG, SVG, PDF, resolved parameters, PlotSpec, validation, logs, direct engine commands and a reproduction bundle. Rendering an existing figure does not edit a plugin or its baselines.

The shortcut also works:

```bash
plot_web/.venv/bin/python -m omicscanvas render --plugin binary_evaluation_plot \
  --example calibration --output /tmp/calibration-figure
```

`--example` explicitly chooses synthetic data. It cannot be mixed with `--input` and never serves as an automatic fallback after user-data failure. Choose an example matching the requested mode; its parameters/title belong to that example.

## Real data and customization

This command uses the repository's small renamed-column fixture; replace its path with your own CSV/TSV after checking its scientific suitability.

```bash
plot_web/.venv/bin/python -m omicscanvas profile docs/qa/fixtures/ai_survival_named_columns.csv
plot_web/.venv/bin/python -m omicscanvas plan --plugin survival_plot \
  --input input=docs/qa/fixtures/ai_survival_named_columns.csv \
  --set time_column=followup_months \
  --set event_column=event_status \
  --set group_column=cohort \
  --set curve_type=survival \
  --set width=9 --set height=6 \
  --set 'group_colors={"Cohort A":"#0072B2","Cohort B":"#E69F00"}' \
  --output /tmp/my-survival-plan.json
plot_web/.venv/bin/python -m omicscanvas render --plan /tmp/my-survival-plan.json \
  --output /tmp/my-survival-figure
```

`--params FILE` reads a flat JSON object. Repeated `--set` values override the file; numbers/booleans/lists/maps use JSON, while plain strings are accepted. The selected engine's schema defines the keys. `--goal TEXT` records provenance; it does not interpret a mode request. To draw calibration, pass `plot_type=calibration`, or select its matching synthetic bundle.

Input files are never subsampled or modified by the CLI. A renderer may aggregate, filter or draw derived curve coordinates according to the plan parameters; therefore `data_used.csv` need not have one row per input observation. Check `figure.json` and engine-specific count exports. Statistical assumptions and study design still require scientific review.

## Multiple input tables

Discover the exact fields with `describe`. For example:

```bash
plot_web/.venv/bin/python -m omicscanvas plan --plugin linked_matrix_network_plot \
  --input input=plugins/linked_matrix_network_plot/examples/basic/input/data.csv \
  --input links=plugins/linked_matrix_network_plot/examples/basic/input/links.csv \
  --params plugins/linked_matrix_network_plot/examples/basic/params.json \
  --output /tmp/linked-plan.json
plot_web/.venv/bin/python -m omicscanvas render --plan /tmp/linked-plan.json \
  --output /tmp/linked-figure
```

The last example supplies synthetic files through the ordinary file interface for demonstrating multiple inputs; it is not a real biological analysis. Missing auxiliary inputs stop the CLI. Parameter values naming columns are checked against supplied table headers. More detailed field/table relationships and engine-specific checks remain part of vNext and the renderer.

## Layered skills, shared by assistants

| Layer | Entrypoint | Responsibility |
|---|---|---|
| L0 | `skills/omicscanvas-router/SKILL.md` | Research question, compact retrieval, scenario/engine selection and review |
| L1 | Nine scenario skills listed by `workflows` | Clinical, single-cell, enrichment, matrices, relationships, genomics, spatial, composition/hierarchy and general comparisons |
| L2 | `skills/omicscanvas-render/SKILL.md` + `describe ENGINE` | Live typed contract, concrete parameters, validated execution and output inspection |

The compact curated membership index is `skills/omicscanvas-router/workflows.yaml`; schemas and examples remain in the plugins. A plot can belong to multiple scenarios. All current engines have scenario membership. No per-engine contract is copied into another registry or dozens of new skill bodies.

For Claude, Grok, OpenCode, Codex or another assistant with local file-reading and shell tools, use the same prompt, replacing `REPOSITORY` with the actual checkout path:

```text
Read REPOSITORY/skills/omicscanvas-router/SKILL.md and use that workflow.
My data is REPOSITORY/docs/qa/fixtures/ai_survival_named_columns.csv.
Draw a Kaplan-Meier survival curve: followup_months is follow-up time,
event_status is 0/1 event status, and cohort is the group.
Use all 12 observations, map Cohort A to blue and Cohort B to orange,
and export PNG/SVG/PDF to a new output directory.
Read only relevant scenario/engine contracts. Create and validate a plan,
render locally, inspect the figure, and report counts and limitations.
Do not change application code or send the data to an external service.
```

The names above identify possible host assistants, not tested native integrations. Their file/shell tools and workspace permissions determine what they can execute. A chat-only interface can return commands/plans but cannot directly access local data or render. This implementation does not install skills globally, modify host configurations or depend on slash commands, `$skill` syntax or provider-specific APIs. Native discovery can be configured separately in the chosen host; the explicit file-path workflow already works without it.

From another working directory, invoke the absolute paths to the Python interpreter and `scripts/omicscanvas.py`. That launcher locates the repository itself. Input paths remain relative to the caller's working directory, not silently relative to the script.

## Retrieval is not scientific approval

```bash
plot_web/.venv/bin/python -m omicscanvas skills
plot_web/.venv/bin/python -m omicscanvas workflows
plot_web/.venv/bin/python -m omicscanvas recommend \
  --goal 'calibration curve, do not draw ROC' \
  --input plugins/binary_evaluation_plot/examples/basic/input/data.csv
```

Recommendation uses local rules; it calls no model. Candidates carry workflow paths, draft mappings and a contract command. Review scientific appropriateness before creating an executable plan. Read only the relevant scenario skills and selected contracts rather than every skill body. A leader skill coordinates the current assistant; it does not automatically spawn subagents.

## Reproduction and direct R integration

```bash
plot_web/.venv/bin/python -m omicscanvas reproduce \
  --bundle-dir /tmp/my-survival-figure/reproduction_bundle \
  --output /tmp/my-survival-reproduced --compare
```

The plan binds input checksums and rerendering revalidates them. Changed data requires a new plan. Rendering uses full-file snapshots, with resolved params and checksums recorded in the output. The reproduction bundle includes inputs, figures, validation, runtime versions and methods; protect it as you would the source data.

For direct R use, inspect `direct_command.json` after a CLI run. Use its companion `direct_environment.json` to preserve the RNG seed and shared R runtime. Its argument array comes from the same command builder as the web server, including per-engine auxiliary flags. A simple survival invocation is:

```bash
Rscript plugins/survival_plot/plot.R \
  --input docs/qa/fixtures/ai_survival_named_columns.csv \
  --params /tmp/my-survival-figure/params.json \
  --output /tmp/my-survival-direct
```

Run direct commands from the repository root and use a new output directory. Direct R bypasses the CLI preflight and reproduction package; the Python CLI is the preferred normal execution path. The current engines are R; invoking them through Python does not create a separate Python plotting implementation.

## Output and failures

Successful commands and handled input/runtime errors emit JSON to stdout. Help and argument-syntax errors use normal argparse output; reproduction emits the existing vNext JSON report. Exit codes: 0 success; 2 CLI/input/parameter/validation error; 3 renderer failure; reproduction may return 4 for a mismatch. Dependency failures are reported, not repaired through automatic installation. `--no-bundle` skips reproduction packaging only.

A successful process is not by itself evidence of a correct scientific interpretation or a readable final layout. Verify counts, units, color mappings, requested modes and exported graphics. Report visual review as pending if the host cannot inspect images. Plugin development remains governed by `AGENTS.md`, `skills/omics-plot-plugins/SKILL.md` and `docs/standards/`.
