"""On-disk storage: jobs, figure index, provenance state, uploads and retention."""
from __future__ import annotations

import json
import os
import re
import shutil
import time
import uuid
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from fastapi import HTTPException, Request

from plot_web.server.settings import (
    CURRENT_STATE_PATH,
    DATASETS_DIR,
    DEFAULT_DISPATCH_MODE,
    FIGURE_INDEX_LOCK,
    FIGURE_INDEX_PATH,
    JOBS_DIR,
    MAX_STATE_RUNS,
    PREVIEWS_DIR,
    REPORTS_DIR,
    RESULTS_DIR,
    STATE_DIR,
    STATE_LOCK,
    STORAGE_MAX_JOBS,
    STORAGE_RETENTION_DAYS,
    UPLOADS_DIR,
)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def ensure_storage() -> None:
    for directory in (JOBS_DIR, UPLOADS_DIR, RESULTS_DIR, PREVIEWS_DIR, DATASETS_DIR, STATE_DIR, REPORTS_DIR):
        directory.mkdir(parents=True, exist_ok=True)


def safe_id(value: str) -> str:
    if not re.match(r"^[A-Za-z0-9_.-]+$", value):
        raise HTTPException(status_code=400, detail="Invalid id")
    return value


def job_file(job_id: str) -> Path:
    return JOBS_DIR / safe_id(job_id) / "job.json"


def atomic_write_text(path: Path, text: str) -> None:
    """Write via a temp file + rename so readers never see a half-written file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f".{path.name}.{uuid.uuid4().hex[:8]}.tmp")
    tmp.write_text(text, encoding="utf-8")
    os.replace(tmp, path)


def save_job(job: dict[str, Any]) -> None:
    path = job_file(job["job_id"])
    atomic_write_text(path, json.dumps(job, indent=2, ensure_ascii=False))
    if job.get("figure_id"):
        index_figure(job["figure_id"], job["job_id"])


def _read_figure_index() -> dict[str, str]:
    try:
        data = json.loads(FIGURE_INDEX_PATH.read_text(encoding="utf-8"))
    except Exception:
        return {}
    return data if isinstance(data, dict) else {}


def index_figure(figure_id: str, job_id: str) -> None:
    with FIGURE_INDEX_LOCK:
        index = _read_figure_index()
        if index.get(figure_id) == job_id:
            return
        index[figure_id] = job_id
        atomic_write_text(FIGURE_INDEX_PATH, json.dumps(index))


def rebuild_figure_index() -> dict[str, str]:
    index: dict[str, str] = {}
    for path in JOBS_DIR.glob("*/job.json"):
        try:
            job = json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            continue
        if job.get("figure_id") and job.get("job_id"):
            index[job["figure_id"]] = job["job_id"]
    with FIGURE_INDEX_LOCK:
        atomic_write_text(FIGURE_INDEX_PATH, json.dumps(index))
    return index


def list_jobs() -> list[dict[str, Any]]:
    ensure_storage()
    jobs = []
    for path in sorted(JOBS_DIR.glob("*/job.json"), reverse=True):
        try:
            jobs.append(json.loads(path.read_text(encoding="utf-8")))
        except Exception:
            continue
    return jobs


def load_job(job_id: str) -> dict[str, Any]:
    path = job_file(job_id)
    if not path.exists():
        raise HTTPException(status_code=404, detail="Job not found")
    return json.loads(path.read_text(encoding="utf-8"))


def figure_to_job(figure_id: str) -> dict[str, Any]:
    figure_id = safe_id(figure_id)
    with FIGURE_INDEX_LOCK:
        job_id = _read_figure_index().get(figure_id)
    if job_id is None:
        # Index missing or stale (e.g. jobs written by an older version).
        job_id = rebuild_figure_index().get(figure_id)
    if job_id is not None:
        try:
            job = load_job(job_id)
        except HTTPException:
            job = None
        if job and job.get("figure_id") == figure_id:
            return job
    raise HTTPException(status_code=404, detail="Figure not found")


def _job_created_ts(job_dir: Path) -> float:
    try:
        return (job_dir / "job.json").stat().st_mtime
    except OSError:
        return job_dir.stat().st_mtime


def cleanup_storage(
    retention_days: float | None = None,
    max_jobs: int | None = None,
    dry_run: bool = False,
) -> dict[str, Any]:
    """Delete old job/result/upload dirs by age and count. Returns a summary."""
    ensure_storage()
    retention_days = STORAGE_RETENTION_DAYS if retention_days is None else retention_days
    max_jobs = STORAGE_MAX_JOBS if max_jobs is None else max_jobs
    job_dirs = sorted((d for d in JOBS_DIR.iterdir() if d.is_dir()), key=_job_created_ts, reverse=True)
    cutoff = time.time() - retention_days * 86400 if retention_days > 0 else None
    doomed: list[Path] = []
    for rank, job_dir in enumerate(job_dirs):
        too_many = max_jobs > 0 and rank >= max_jobs
        too_old = cutoff is not None and _job_created_ts(job_dir) < cutoff
        if too_many or too_old:
            doomed.append(job_dir)

    removed: list[str] = []
    freed = 0
    for job_dir in doomed:
        job_id = job_dir.name
        targets = [job_dir, RESULTS_DIR / job_id, UPLOADS_DIR / job_id]
        try:
            job = json.loads((job_dir / "job.json").read_text(encoding="utf-8"))
            upload = Path(str(job.get("upload_dir") or ""))
            # Only remove upload dirs we own (demo runs point at plugin dirs).
            if upload.is_dir() and upload.parent == UPLOADS_DIR:
                targets.append(upload)
        except Exception:
            pass
        for target in targets:
            if not target.exists():
                continue
            freed += sum(f.stat().st_size for f in target.rglob("*") if f.is_file())
            if not dry_run:
                shutil.rmtree(target, ignore_errors=True)
        removed.append(job_id)

    if removed and not dry_run:
        rebuild_figure_index()
        removed_set = set(removed)
        with state_transaction() as state:
            state["recent_jobs"] = [j for j in state.get("recent_jobs", []) if j.get("job_id") not in removed_set]
            prune_state(state, drop_job_ids=removed_set)
    return {"removed_jobs": len(removed), "freed_bytes": freed, "dry_run": dry_run, "kept_jobs": len(job_dirs) - len(removed)}


def output_urls(figure_id: str) -> dict[str, str]:
    return {
        "svg": f"/api/figures/{figure_id}/download/svg",
        "pdf": f"/api/figures/{figure_id}/download/pdf",
        "png": f"/api/figures/{figure_id}/download/png",
        "json": f"/api/figures/{figure_id}/download/json",
        "log": f"/api/figures/{figure_id}/download/log",
        "preview": f"/api/figures/{figure_id}/preview",
    }


def output_urls_for_dir(figure_id: str, result_dir: Path | None = None) -> dict[str, str]:
    urls = output_urls(figure_id)
    if not result_dir or not result_dir.exists():
        return urls
    names = {
        "result.svg": "svg",
        "result.pdf": "pdf",
        "result.png": "png",
        "figure.json": "json",
        "run.log": "log",
        "selected_rows.csv": "selected_rows",
        "selected_points.csv": "selected_points",
        "selected_features.csv": "selected_features",
        "subset_elements.csv": "subset_elements",
        "subsets.csv": "subsets",
        "subset_elements_long.csv": "subset_elements_long",
        "set_sizes.csv": "set_sizes",
        "matrix_used.csv": "matrix_used",
        "annotation_used.csv": "annotation_used",
        "enrichment_results.csv": "enrichment_results",
        "plotspec.json": "plotspec",
        "validation.json": "validation",
        "result.html": "html",
    }
    for filename, key in names.items():
        if (result_dir / filename).exists():
            urls[key] = f"/api/figures/{figure_id}/download/{key}"
    if (result_dir / "result.html").exists():
        # View URL keeps relative result_files/ next to the widget.
        urls["html"] = f"/api/figures/{figure_id}/view/result.html"
    if (result_dir / "plotspec.json").exists():
        urls["bundle"] = f"/api/figures/{figure_id}/bundle"
    return urls


def figure_view_file(output_dir: Path, rel_path: str) -> Path:
    """Resolve a file under a job output dir for the interactive HTML view."""
    root = Path(output_dir).resolve()
    target = (root / rel_path).resolve()
    try:
        target.relative_to(root)
    except ValueError as exc:
        raise HTTPException(status_code=403, detail="Invalid path") from exc
    if not target.is_file():
        raise HTTPException(status_code=404, detail="Not found")
    return target


def output_file_for_type(result_dir: Path, file_type: str) -> Path:
    file_map = {
        "svg": "result.svg",
        "pdf": "result.pdf",
        "png": "result.png",
        "json": "figure.json",
        "figure_json": "figure.json",
        "log": "run.log",
        "html": "result.html",
        "selected_rows": "selected_rows.csv",
        "selected_points": "selected_points.csv",
        "selected_features": "selected_features.csv",
        "subset_elements": "subset_elements.csv",
        "subsets": "subsets.csv",
        "subset_elements_long": "subset_elements_long.csv",
        "set_sizes": "set_sizes.csv",
        "matrix_used": "matrix_used.csv",
        "annotation_used": "annotation_used.csv",
        "enrichment_results": "enrichment_results.csv",
        "plotspec": "plotspec.json",
        "validation": "validation.json",
    }
    if file_type in file_map:
        return result_dir / file_map[file_type]
    safe = safe_id(file_type)
    for ext in (".csv", ".tsv", ".txt", ".json", ".png", ".svg", ".pdf", ".log"):
        candidate = result_dir / f"{safe}{ext}"
        if candidate.exists():
            return candidate
    raise HTTPException(status_code=400, detail="Unsupported file type")


def default_state() -> dict[str, Any]:
    return {
        "active_dataset_id": None,
        "active_plugin_id": None,
        "data_map": {"nodes": [], "edges": []},
        "recent_jobs": [],
        "ui": {"selected_mode": "workspace"},
    }


def load_state() -> dict[str, Any]:
    ensure_storage()
    if not CURRENT_STATE_PATH.exists():
        return default_state()
    try:
        data = json.loads(CURRENT_STATE_PATH.read_text(encoding="utf-8"))
    except Exception:
        return default_state()
    base = default_state()
    base.update(data if isinstance(data, dict) else {})
    base.setdefault("data_map", {"nodes": [], "edges": []})
    base.setdefault("recent_jobs", [])
    base.setdefault("ui", {"selected_mode": "workspace"})
    return base


def save_state(data: dict[str, Any]) -> dict[str, Any]:
    ensure_storage()
    with STATE_LOCK:
        atomic_write_text(CURRENT_STATE_PATH, json.dumps(data, indent=2, ensure_ascii=False))
    return data


@contextmanager
def state_transaction():
    """Serialize read-modify-write of current_state.json across threads."""
    with STATE_LOCK:
        state = load_state()
        yield state
        save_state(state)


def prune_state(state: dict[str, Any], drop_job_ids: set[str] | None = None) -> None:
    """Keep only the newest MAX_STATE_RUNS plot runs (and their results/edges) in the data map."""
    data_map = state.setdefault("data_map", {"nodes": [], "edges": []})
    nodes = data_map.setdefault("nodes", [])
    edges = data_map.setdefault("edges", [])
    runs = [n for n in nodes if n.get("type") == "plot_run"]
    runs.sort(key=lambda n: str(n.get("created_at") or ""), reverse=True)
    drop = set(drop_job_ids or ())
    if MAX_STATE_RUNS > 0:
        drop.update(str(n.get("id")) for n in runs[MAX_STATE_RUNS:])
    if not drop:
        return
    drop_ids = drop | {f"result_{job_id}" for job_id in drop}
    data_map["nodes"] = [n for n in nodes if n.get("id") not in drop_ids]
    data_map["edges"] = [e for e in edges if e.get("source") not in drop_ids and e.get("target") not in drop_ids]


def upsert_node(state: dict[str, Any], node: dict[str, Any]) -> None:
    nodes = state.setdefault("data_map", {}).setdefault("nodes", [])
    for idx, existing in enumerate(nodes):
        if existing.get("id") == node.get("id"):
            nodes[idx] = {**existing, **node}
            return
    nodes.append(node)


def upsert_edge(state: dict[str, Any], edge: dict[str, Any]) -> None:
    edges = state.setdefault("data_map", {}).setdefault("edges", [])
    edge_id = edge.get("id") or f"{edge.get('source')}->{edge.get('target')}"
    edge["id"] = edge_id
    for idx, existing in enumerate(edges):
        if existing.get("id") == edge_id:
            edges[idx] = {**existing, **edge}
            return
    edges.append(edge)


def record_job_in_state(job: dict[str, Any], source_dataset_id: str | None = None) -> None:
    with state_transaction() as state:
        _record_job(state, job, source_dataset_id)


def _record_job(state: dict[str, Any], job: dict[str, Any], source_dataset_id: str | None) -> None:
    plugin_id = job.get("plugin_id")
    job_id = job.get("job_id")
    result_id = f"result_{job_id}"
    if source_dataset_id:
        upsert_node(state, {"id": source_dataset_id, "type": "dataset", "label": source_dataset_id, "created_at": job.get("created_at")})
    upsert_node(
        state,
        {
            "id": job_id,
            "type": "plot_run",
            "label": plugin_id,
            "plugin_id": plugin_id,
            "status": job.get("status"),
            "created_at": job.get("created_at"),
            "output_dir": job.get("output_dir"),
        },
    )
    upsert_node(
        state,
        {
            "id": result_id,
            "type": "result",
            "label": f"{plugin_id} result",
            "job_id": job_id,
            "figure_id": job.get("figure_id"),
            "outputs": job.get("outputs", {}),
            "created_at": job.get("finished_at") or job.get("created_at"),
        },
    )
    if source_dataset_id:
        upsert_edge(state, {"source": source_dataset_id, "target": job_id, "type": "plot_run", "label": plugin_id})
    upsert_edge(state, {"source": job_id, "target": result_id, "type": "produced", "label": "produced"})
    recent = [item for item in state.setdefault("recent_jobs", []) if item.get("job_id") != job_id]
    recent.insert(0, {"job_id": job_id, "plugin_id": plugin_id, "status": job.get("status"), "created_at": job.get("created_at"), "output_dir": job.get("output_dir")})
    state["recent_jobs"] = recent[:50]
    state["active_plugin_id"] = plugin_id
    prune_state(state)


async def save_uploads(request: Request, upload_dir: Path) -> tuple[dict[str, Path], dict[str, str]]:
    """Save multipart uploads. Excel (.xlsx) tables are converted to CSV for plugins."""
    from plot_web.table_io import ensure_tabular_csv, is_excel_file

    form = await request.form()
    saved_files: dict[str, Path] = {}
    text_fields: dict[str, str] = {}
    upload_dir.mkdir(parents=True, exist_ok=True)
    sheet = form.get("sheet")
    for key, value in form.multi_items():
        filename = getattr(value, "filename", None)
        if filename:
            safe_name = Path(filename).name
            target = upload_dir / f"{key}__{safe_name}"
            with target.open("wb") as handle:
                shutil.copyfileobj(value.file, handle)
            if is_excel_file(target):
                try:
                    from plot_web.table_io import sanitize_sheet_name

                    csv_path = ensure_tabular_csv(
                        target,
                        sheet=sanitize_sheet_name(str(sheet) if sheet is not None else None),
                        out=target.with_suffix(".csv"),
                    )
                    saved_files[key] = csv_path
                    # keep original workbook path for reference
                    text_fields[f"{key}__original_excel"] = str(target)
                except Exception as exc:
                    raise HTTPException(
                        status_code=400,
                        detail=f"Failed to read Excel file {safe_name}: {exc}",
                    ) from exc
            else:
                saved_files[key] = target
        else:
            text_fields[key] = str(value)
    return saved_files, text_fields


def parse_params(text_fields: dict[str, str], plugin_id: str) -> dict[str, Any]:
    params_raw = text_fields.get("params", "{}")
    try:
        params = json.loads(params_raw) if params_raw.strip() else {}
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=400, detail=f"Invalid params JSON: {exc}") from exc
    if not isinstance(params, dict):
        raise HTTPException(status_code=400, detail="params must be a JSON object")
    params["plugin_id"] = plugin_id
    params.setdefault("dispatch_mode", DEFAULT_DISPATCH_MODE)
    return params
