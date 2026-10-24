"""FastAPI entry point for the OmicsCanvas plot web (``uvicorn plot_web.app:app``).

Implementation lives in :mod:`plot_web.server`; helpers are re-exported here so
existing ``from plot_web.app import ...`` call sites keep working.
"""
from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.concurrency import run_in_threadpool
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from plot_web.server.routes import ai, datasets, jobs, pages, palettes, plugins, registry, vnext

from plot_web.server.settings import (  # noqa: F401  (re-exported)
    CURRENT_STATE_PATH,
    DATASETS_DIR,
    DEFAULT_DISPATCH_MODE,
    FIGURE_INDEX_LOCK,
    FIGURE_INDEX_PATH,
    JOBS_DIR,
    MAX_LOCAL_SECONDS,
    MAX_STATE_RUNS,
    PLUGIN_DIR,
    PREVIEWS_DIR,
    REPORTS_DIR,
    RESULTS_DIR,
    ROOT_DIR,
    STATE_DIR,
    STATE_LOCK,
    STATIC_DIR,
    STORAGE_CLEANUP_ON_STARTUP,
    STORAGE_DIR,
    STORAGE_MAX_JOBS,
    STORAGE_RETENTION_DAYS,
    UPLOADS_DIR,
    WEB_DIR,
)

from plot_web.server.storage import (  # noqa: F401  (re-exported)
    atomic_write_text,
    cleanup_storage,
    default_state,
    ensure_storage,
    figure_to_job,
    index_figure,
    job_file,
    list_jobs,
    load_job,
    load_state,
    output_file_for_type,
    output_urls,
    output_urls_for_dir,
    parse_params,
    prune_state,
    rebuild_figure_index,
    record_job_in_state,
    safe_id,
    save_job,
    save_state,
    save_uploads,
    state_transaction,
    upsert_edge,
    upsert_node,
    utc_now,
)

from plot_web.server.tables import (  # noqa: F401  (re-exported)
    guess_delimiter,
    is_number,
    preview_table,
)

from plot_web.server.plugins import (  # noqa: F401  (re-exported)
    EXAMPLE_FILE_EXTENSIONS,
    choose_demo_file,
    choose_demo_params,
    default_subcategory,
    demo_payload,
    effective_params_schema,
    example_bundle,
    example_file,
    example_record,
    example_url,
    fieldForBackend,
    gallery_files,
    infer_language,
    list_example_params,
    list_plot_styles,
    normalized_category,
    plugin_config_path,
    plugin_path,
    plugin_summary,
    public_style_card,
    read_example_manifest,
    read_params_schema,
    read_yaml,
)

from plot_web.server.runner import (  # noqa: F401  (re-exported)
    LEGACY_INPUT_FLAGS,
    MAIN_INPUT_FIELDS,
    build_command,
    choose_main_input,
    declared_inputs,
    input_flags,
    run_local_job,
)



@asynccontextmanager
async def lifespan(_app: FastAPI):
    if STORAGE_CLEANUP_ON_STARTUP:
        await run_in_threadpool(cleanup_storage)
    yield


app = FastAPI(title="BioFigureAI Plot Plugin Local API", version="1.0.0", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://127.0.0.1:8000", "http://localhost:8000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")

# Order matters: within each router, static paths precede parameterized ones.
for _module in (pages, datasets, plugins, registry, jobs, palettes, ai, vnext):
    app.include_router(_module.router)
