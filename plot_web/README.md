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

Optional file fields are supported when a plugin needs them:

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
