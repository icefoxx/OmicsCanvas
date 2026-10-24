"""Paths, environment settings and shared locks for the plot_web server."""
from __future__ import annotations

import os
import threading
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[2]


PLUGIN_DIR = ROOT_DIR / "plugins"


WEB_DIR = ROOT_DIR / "plot_web"


STATIC_DIR = WEB_DIR / "static"


STORAGE_DIR = WEB_DIR / "storage"


JOBS_DIR = STORAGE_DIR / "jobs"


UPLOADS_DIR = STORAGE_DIR / "uploads"


RESULTS_DIR = STORAGE_DIR / "results"


PREVIEWS_DIR = STORAGE_DIR / "previews"


DATASETS_DIR = STORAGE_DIR / "datasets"


STATE_DIR = STORAGE_DIR / "state"


REPORTS_DIR = STORAGE_DIR / "reports"


CURRENT_STATE_PATH = STATE_DIR / "current_state.json"


DEFAULT_DISPATCH_MODE = os.environ.get("PLOT_DISPATCH_MODE", "local")


MAX_LOCAL_SECONDS = int(os.environ.get("PLOT_LOCAL_TIMEOUT_SECONDS", "900"))


# Retention for plot_web/storage (0 disables): jobs older than this many days
# and runs beyond the newest N are removed by cleanup_storage().
STORAGE_RETENTION_DAYS = float(os.environ.get("PLOT_STORAGE_RETENTION_DAYS", "30"))


STORAGE_MAX_JOBS = int(os.environ.get("PLOT_STORAGE_MAX_JOBS", "500"))


STORAGE_CLEANUP_ON_STARTUP = os.environ.get("PLOT_STORAGE_CLEANUP_ON_STARTUP", "0").lower() in {"1", "true", "yes"}


# Plot runs kept in the data map of current_state.json.
MAX_STATE_RUNS = int(os.environ.get("PLOT_STATE_MAX_RUNS", "300"))


FIGURE_INDEX_PATH = STORAGE_DIR / "figure_index.json"


STATE_LOCK = threading.RLock()


FIGURE_INDEX_LOCK = threading.RLock()
