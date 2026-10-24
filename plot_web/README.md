# OmicsCanvas Plot Web

Local-first FastAPI website for running BioFigureAI plot plugins with a
category sidebar, upload preview, schema-driven controls, advanced JSON
inspection, plot preview, logs, and result downloads.

## Start Locally

```bash
cd /Users/qzhang10/Documents/OmicsCanvas
chmod +x plot_web/run_local.sh
plot_web/run_local.sh
```

Open:

```text
http://127.0.0.1:8000
```

The script creates `plot_web/.venv` if needed, installs the FastAPI
dependencies, and starts the API with `PLOT_DISPATCH_MODE=local`.

## AI Studio (in-web AI)

Open **✦ AI Studio** in the top nav (`http://127.0.0.1:8000` → AI Studio):

1. Upload a CSV/TSV  
2. Optionally describe the goal (e.g. differential expression / composition)  
3. Click **Analyze & Recommend** → ranked plugins  
4. Click **Generate demo** → subsampled run + preview  
5. Open **Editor** to fine-tune  

Default engine is a local rule recommender (no API key).  
Optional SpaceXAI refinement when the server has:

```bash
export XAI_API_KEY=...          # https://console.x.ai
export XAI_MODEL=grok-4.5       # optional
```

API:

```text
GET  /api/ai/status
POST /api/ai/recommend     # multipart: file, goal, top_k
POST /api/ai/build-demo    # JSON: session_id, plugin_id, prefer_builtin_demo?
POST /api/ai/chat          # JSON: message, session_id?
```

## Local-First Job Dispatch

Default dispatch mode is local subprocess execution:

```text
POST /api/plugins/{plugin_id}/run
```

The backend:

1. Reads `plugins/{plugin_id}/config.yaml`.
2. Saves uploaded files under `plot_web/storage/uploads/{job_id}/`.
3. Saves params under `plot_web/storage/jobs/{job_id}/params.json`.
4. Runs `Rscript plugins/{plugin_id}/plot.R --input ... --params ... --output ...`.
5. Stores results under `plot_web/storage/results/{job_id}/`.

Extra upload fields are mapped to CLI flags from the plugin's `config.yaml`
(`inputs[].flag` if set, otherwise a legacy alias below, otherwise `--<id>`):

```yaml
inputs:
  - {id: signal, type: table, required: true}        # first required input -> --input
  - {id: expression, type: table, flag: --expression}
  - {id: features, type: table}                      # -> --features
```

Legacy aliases:

```text
file or input  -> --input
input2         -> --input2
annot          -> --annot
expr           -> --expr
genesets       -> --genesets
embed          -> --embed
lineages       -> --lineages
```

## API

```text
GET  /api/health
GET  /api/plugins
GET  /api/plugins/tree
GET  /api/plugins/{plugin_id}
POST /api/plugins/{plugin_id}/preview-input
POST /api/plugins/{plugin_id}/run
GET  /api/jobs/{job_id}
GET  /api/jobs/{job_id}/logs
GET  /api/figures/{figure_id}
GET  /api/figures/{figure_id}/download/{file_type}
GET  /api/figures/{figure_id}/preview
```

Supported downloads:

```text
svg
pdf
png
json
log
selected_rows
selected_points
selected_features
subset_elements
subsets
subset_elements_long
set_sizes
matrix_used
annotation_used
enrichment_results
```

## Storage retention

Jobs, uploads and results accumulate under `plot_web/storage/`. Nothing is
deleted automatically unless you opt in:

```bash
export PLOT_STORAGE_CLEANUP_ON_STARTUP=1   # run cleanup when the server starts
export PLOT_STORAGE_RETENTION_DAYS=30      # remove jobs older than N days (0 = off)
export PLOT_STORAGE_MAX_JOBS=500           # keep at most N newest jobs (0 = off)
export PLOT_STATE_MAX_RUNS=300             # plot runs kept in the provenance map
```

```text
GET  /api/storage/usage
POST /api/storage/cleanup   # JSON: retention_days?, max_jobs?, dry_run? (default true)
```

## Code layout

```text
plot_web/app.py             FastAPI app: middleware, static mount, router wiring
plot_web/server/settings.py paths, env settings, locks
plot_web/server/storage.py  jobs, figure index, provenance state, uploads, retention
plot_web/server/plugins.py  plugin config, schemas, example bundles, demo inputs
plot_web/server/runner.py   CLI flag mapping + local subprocess execution
plot_web/server/tables.py   table preview helpers
plot_web/server/routes/     one APIRouter per area (plugins, registry, jobs, ai, ...)
```

Plugin runs, LLM calls and AI demos execute in FastAPI's thread pool, so a long
R render no longer blocks other requests.

## Smoke-testing plugins

```bash
python scripts/smoke_plugins.py --max-examples 1            # every plugin
python scripts/smoke_plugins.py dot_plot sca_volcano_plot    # selected plugins
```

## PlotSpec, scientific validation and reproduction bundles

Every job (run, run-demo, rerun, AI demos) is lifted into a vNext PlotSpec and
checked by the scientific guardrails before the plugin runs. The job response
carries the result under `vnext` (`valid`, `errors`, `warnings`, `infos`,
`plotspec_hash`), and Studio / the workspace show it under the figure.

```bash
export PLOT_VALIDATION_MODE=warn      # default: render anyway, report issues
export PLOT_VALIDATION_MODE=enforce   # do not render when there are scientific errors
export PLOT_VALIDATION_MODE=off       # skip PlotSpec + validation
```

Every R run is seeded (`params.seed`, default 42) through
`R/runtime/omicscanvas.Rprofile`, so jitter, label placement and permutation
statistics are identical for identical inputs.

```text
GET  /api/figures/{figure_id}/download/plotspec   # plotspec.json
GET  /api/figures/{figure_id}/download/validation # validation.json
GET  /api/figures/{figure_id}/bundle              # zip: plotspec, inputs, params, figures,
                                                  #      methods.txt, runtime.json, sha256 manifest
POST /api/vnext/plotspec/from-params              # {plugin_id, params} -> {plotspec}
POST /api/vnext/plotspec/to-params                # {plotspec} -> {plugin_id, params}
```

A downloaded bundle reproduces without the web app:
`python -m vnext.cli reproduce --bundle-dir reproduction_bundle --output /tmp/r --compare`.
