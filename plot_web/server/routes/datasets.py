"""Storage maintenance, provenance state and dataset endpoints."""
from __future__ import annotations

import json
import uuid
from datetime import datetime
from typing import Any

from fastapi import APIRouter, HTTPException, Request
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import JSONResponse

from plot_web.server.settings import DATASETS_DIR, JOBS_DIR, RESULTS_DIR, UPLOADS_DIR
from plot_web.server.storage import (
    cleanup_storage,
    ensure_storage,
    load_state,
    safe_id,
    save_state,
    save_uploads,
    state_transaction,
    upsert_edge,
    upsert_node,
    utc_now,
)
from plot_web.server.tables import preview_table

router = APIRouter()


@router.get("/api/storage/usage")
def storage_usage() -> dict[str, Any]:
    ensure_storage()
    usage = {}
    for name, directory in (("jobs", JOBS_DIR), ("results", RESULTS_DIR), ("uploads", UPLOADS_DIR), ("datasets", DATASETS_DIR)):
        usage[name] = sum(f.stat().st_size for f in directory.rglob("*") if f.is_file())
    return {"bytes": usage, "job_count": sum(1 for d in JOBS_DIR.iterdir() if d.is_dir())}


@router.post("/api/storage/cleanup")
async def storage_cleanup(request: Request) -> dict[str, Any]:
    """Body: {"retention_days"?: float, "max_jobs"?: int, "dry_run"?: bool (default true)}."""
    try:
        body = await request.json()
    except Exception:
        body = {}
    body = body if isinstance(body, dict) else {}
    return await run_in_threadpool(
        cleanup_storage,
        retention_days=float(body["retention_days"]) if "retention_days" in body else None,
        max_jobs=int(body["max_jobs"]) if "max_jobs" in body else None,
        dry_run=bool(body.get("dry_run", True)),
    )


@router.get("/api/state")
def get_state() -> dict[str, Any]:
    return load_state()


@router.post("/api/state/save")
async def post_state_save(request: Request) -> dict[str, Any]:
    data = await request.json()
    if not isinstance(data, dict):
        raise HTTPException(status_code=400, detail="State must be an object")
    return save_state(data)


@router.post("/api/state/load")
def post_state_load() -> dict[str, Any]:
    return load_state()


@router.get("/api/datasets")
def list_datasets() -> dict[str, Any]:
    ensure_storage()
    datasets = []
    for path in sorted(DATASETS_DIR.glob("*/dataset.json"), reverse=True):
        try:
            datasets.append(json.loads(path.read_text(encoding="utf-8")))
        except Exception:
            continue
    return {"datasets": datasets}


@router.get("/api/datasets/{dataset_id}")
def get_dataset(dataset_id: str) -> dict[str, Any]:
    path = DATASETS_DIR / safe_id(dataset_id) / "dataset.json"
    if not path.exists():
        raise HTTPException(status_code=404, detail="Dataset not found")
    return json.loads(path.read_text(encoding="utf-8"))


@router.post("/api/datasets/upload")
async def upload_dataset(request: Request) -> JSONResponse:
    ensure_storage()
    form = await request.form()
    dataset_name = str(form.get("dataset_name") or "Uploaded dataset")
    role = str(form.get("role") or "primary_table")
    notes = str(form.get("notes") or "")
    dataset_id = "dataset_" + datetime.now().strftime("%Y%m%d_%H%M%S_") + uuid.uuid4().hex[:8]
    dataset_dir = DATASETS_DIR / dataset_id
    saved_files, _ = await save_uploads(request, dataset_dir)
    roles = {}
    for field, path in saved_files.items():
      file_role = role if field in {"file", "input"} else field
      record = {"path": str(path), "filename": path.name}
      try:
          if path.suffix.lower() in {".csv", ".tsv", ".txt", ".xlsx", ".xlsm", ".xls"}:
              record.update(preview_table(path))
      except Exception as exc:
          record["error"] = str(exc)
      roles[file_role] = record
    dataset = {"dataset_id": dataset_id, "name": dataset_name, "roles": roles, "notes": notes, "created_at": utc_now()}
    (dataset_dir / "dataset.json").write_text(json.dumps(dataset, indent=2, ensure_ascii=False), encoding="utf-8")
    with state_transaction() as state:
        state["active_dataset_id"] = dataset_id
        upsert_node(state, {"id": dataset_id, "type": "dataset", "label": dataset_name, "created_at": dataset["created_at"], "roles": list(roles)})
    return JSONResponse(dataset)


@router.post("/api/datasets/{dataset_id}/derive")
async def derive_dataset(dataset_id: str, request: Request) -> dict[str, Any]:
    parent = get_dataset(dataset_id)
    data = await request.json()
    derived_id = "dataset_" + datetime.now().strftime("%Y%m%d_%H%M%S_") + uuid.uuid4().hex[:8]
    derived = {**parent, "dataset_id": derived_id, "name": data.get("name") or f"{parent.get('name')} subset", "parent_dataset_id": dataset_id, "notes": data.get("notes", ""), "created_at": utc_now()}
    derived_dir = DATASETS_DIR / derived_id
    derived_dir.mkdir(parents=True, exist_ok=True)
    (derived_dir / "dataset.json").write_text(json.dumps(derived, indent=2, ensure_ascii=False), encoding="utf-8")
    with state_transaction() as state:
        upsert_node(state, {"id": derived_id, "type": "dataset", "label": derived["name"], "created_at": derived["created_at"]})
        upsert_edge(state, {"source": dataset_id, "target": derived_id, "type": "derive", "label": "derive"})
    return derived
