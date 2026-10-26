---
name: omicscanvas-render
description: Execute an existing OmicsCanvas plotting engine with explicit data, schema parameters, validation, reproducible CLI output and optional direct R commands.
metadata:
  role: plot_workflow
  layer: execution
---

# Plan, validate and render

Use after selecting a scientifically suitable engine. All commands run locally with the repository's Python environment. This skill is plain Markdown and shell/JSON; it has no provider-specific SDK, hidden chat state or model settings.

## Inspect the actual contract

Run `python -m omicscanvas describe ENGINE` to read input field names, accepted formats, parameter types/options, canonical examples, input flag mappings and the English Plot Guide. Read the linked README for detailed semantics. An engine's typed schema and input contract govern its parameters. Use `profile PATH` to inspect headers and full row count; profiling previews do not limit rendering.

## Prepare a reviewable plan

For supplied data, repeat `--input field=path` for every required table. Use `--set key=value` repeatedly, or `--params params.json` for a flat JSON object. Strings can be plain text; booleans, numbers, lists and named colors should use JSON values. Do not map an unrelated numeric measurement to a statistical quantity such as SE, probability or p-value.

```bash
python -m omicscanvas plan --plugin survival_plot \
  --input input=data/survival.csv \
  --set time_column=followup_months --set event_column=event_status \
  --set group_column=cohort --set curve_type=survival \
  --set 'group_colors={"Cohort A":"#0072B2","Cohort B":"#E69F00"}' \
  --output plans/survival.json
```

`--goal` is provenance text, not a command to change modes. Set the actual parameter (`plot_type=calibration`, for example). Inspect the saved `plotspec`, input hashes, source mode and validation. Inference of known column aliases is recorded in the plan; verify it matches the user's intent. Keep every supplied row unless filtering/aggregation is explicitly requested and scientifically justified. Preserve identifiers and use derived files for deliberate transformations.

Synthetic demonstrations are explicit and separate:

```bash
python -m omicscanvas plan --plugin binary_evaluation_plot \
  --example calibration --output plans/calibration-demo.json
```

Do not combine `--example` with uploaded files. Every example's primary/auxiliary inputs and statistical settings come from the same manifest. If changing a major example mode, choose the matching example or explicitly update its title/settings as well.

## Cross the deterministic boundary

```bash
python -m omicscanvas validate --plan plans/survival.json
python -m omicscanvas render --plan plans/survival.json --output outputs/survival
```

The CLI checks input contracts, parameter types/ranges, source hashes and existing vNext scientific validation. R performs its additional engine-specific checks. Rendering uses a snapshot and does not alter source files. A failed render remains a failure; inspect `error.json` and logs instead of using a different dataset. Do not describe validation as proof of correct study design.

Use a new/empty output directory. To change data or parameters, create another plan; do not mix `render --plan` with new overrides. The output includes resolved `params.json`, PlotSpec, validation, result images, logs, a JSON result and (by default) a reproduction bundle. `--no-bundle` skips that optional package, not validation.

```bash
python -m omicscanvas reproduce \
  --bundle-dir outputs/survival/reproduction_bundle \
  --output outputs/survival-reproduced --compare
```

## Direct engine commands and delivery

Successful and failed renderer runs save `direct_command.json` (argument array), `direct_environment.json` (seed/runtime environment) and `direct_command.sh` for an equivalent invocation using the original inputs and resolved parameters. The current library uses R engines; the Python CLI passes their real CLI flags through the shared command builder, including auxiliary files. Direct execution bypasses the CLI plan/validation/bundle layer. Use the validated CLI for normal work, and the recorded argument array for debugging or integration; inspect commands before executing and preserve argument boundaries.

After a successful render, check source row counts versus plotted summaries, mode, colors, legend/axis labels, uncertainty and exported layout. Open PNG and at least one PDF/SVG when visual tools are available. Report actual output paths, validation warnings, exclusions and scientific limitations. If visual inspection was unavailable, explicitly leave that check pending rather than claiming publication readiness.
