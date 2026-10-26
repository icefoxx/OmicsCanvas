"""Plugin catalog, examples, input preview and run endpoints."""
from __future__ import annotations

import json
import shutil
import uuid
from datetime import datetime
from pathlib import Path
from typing import Any

from fastapi import APIRouter, HTTPException, Request
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import FileResponse, JSONResponse

from plot_web.plot_registry import (
    get_plot,
    plot_is_listed,
)
from plot_web.server.plugins import (
    _hidden_plugin_ids,
    demo_payload,
    effective_params_schema,
    example_bundle,
    example_file,
    example_record,
    gallery_files,
    infer_language,
    list_example_params,
    plugin_config_path,
    plugin_path,
    plugin_summary,
    read_example_manifest,
    read_yaml,
)
from plot_web.server.runner import build_command, run_local_job
from plot_web.server.render_tasks import submit_render
from plot_web.server.settings import (
    DEFAULT_DISPATCH_MODE,
    JOBS_DIR,
    PLUGIN_DIR,
    PREVIEWS_DIR,
    RESULTS_DIR,
    ROOT_DIR,
    UPLOADS_DIR,
)
from plot_web.server.storage import (
    ensure_storage,
    parse_params,
    safe_id,
    save_job,
    save_uploads,
    state_transaction,
    upsert_node,
    utc_now,
)
from plot_web.server.tables import preview_table

router = APIRouter()


@router.get("/api/plugins")
def list_plugins() -> dict[str, Any]:
    hidden = _hidden_plugin_ids()
    plugins = []
    for config_path in sorted(PLUGIN_DIR.glob("*/config.yaml")):
        plugin_id = config_path.parent.name
        if plugin_id.lower() in hidden:
            continue
        summary = plugin_summary(plugin_id, read_yaml(config_path))
        if not plot_is_listed(get_plot(plugin_id) or {"id": plugin_id, "engine_plugin_id": plugin_id}, hidden):
            continue
        plugins.append(summary)
    return {"plugins": plugins}


@router.get("/api/plugins/tree")
def plugin_tree() -> dict[str, Any]:
    category_map: dict[str, dict[str, Any]] = {}
    hidden = _hidden_plugin_ids()
    for config_path in sorted(PLUGIN_DIR.glob("*/config.yaml")):
        plugin_id = config_path.parent.name
        if plugin_id.lower() in hidden:
            continue
        summary = plugin_summary(plugin_id, read_yaml(config_path))
        category = summary.get("category") or "Plot"
        subcategory = summary.get("subcategory") or "General"
        category_node = category_map.setdefault(category, {"name": category, "subcategories": {}})
        sub_node = category_node["subcategories"].setdefault(subcategory, {"name": subcategory, "plugins": []})
        sub_node["plugins"].append(summary)

    preferred = [
        "Dimension",
        "Feature",
        "Heatmap",
        "Scatter",
        "Expression / Statistics",
        "Set / Enrichment",
        "Network",
        "Multi-panel",
        "Plot",
    ]
    categories = []
    for name in preferred + sorted(k for k in category_map if k not in preferred):
        if name not in category_map:
            continue
        node = category_map[name]
        node["subcategories"] = [
            node["subcategories"][key]
            for key in sorted(node["subcategories"])
        ]
        categories.append(node)
    return {"categories": categories}


@router.get("/api/plugins/{plugin_id}")
def get_plugin(plugin_id: str) -> dict[str, Any]:
    config = read_yaml(plugin_config_path(plugin_id))
    config.setdefault("id", plugin_id)
    config.setdefault("entrypoint", "plot.R")
    config.setdefault("language", infer_language(config))
    config.setdefault("category", plugin_summary(plugin_id, config)["category"])
    config.setdefault("subcategory", plugin_summary(plugin_id, config)["subcategory"])
    config["params_schema"] = effective_params_schema(plugin_id, config)
    config["examples"] = list_example_params(plugin_id)
    config["galleries"] = [str(path.relative_to(ROOT_DIR)) for path in gallery_files(plugin_id)]
    demo = demo_payload(plugin_id, config)
    demo.pop("_file_paths", None)
    config["demo"] = demo
    family = get_plot(plugin_id)
    if family:
        config["registry"] = {
            "family_id": family.get("id"),
            "variants": [v.get("id") for v in family.get("variants") or []],
            "presets": [p.get("id") for p in family.get("presets") or []],
        }
    return config


@router.get("/api/plugins/{plugin_id}/demo")
def get_plugin_demo(plugin_id: str) -> dict[str, Any]:
    config = read_yaml(plugin_config_path(plugin_id))
    demo = demo_payload(plugin_id, config)
    demo.pop("_file_paths", None)
    return demo


@router.get("/api/plugins/{plugin_id}/examples/{example_id}")
def get_plugin_example(plugin_id: str, example_id: str) -> dict[str, Any]:
    bundle = example_bundle(plugin_id, example_id)
    manifest = read_example_manifest(bundle)
    record = example_record(plugin_id, bundle, manifest)
    reproduce = manifest.get("reproduce")
    command = reproduce.get("command") if isinstance(reproduce, dict) else None
    command = command or f"curl -X POST /api/plugins/{plugin_id}/run-demo -H 'Content-Type: application/json' -d '{{\"example_id\":\"{record['id']}\"}}'"
    previews = {}
    for field, info in record["inputs"].items():
        try:
            previews[field] = preview_table(example_file(bundle, info["path"]))
        except Exception as exc:
            previews[field] = {"filename": info["filename"], "error": str(exc), "columns": [], "preview_rows": []}
    return {
        "id": record["id"],
        "manifest": manifest,
        "params": record["params"],
        "params_url": record["params_url"],
        "inputs": record["inputs"],
        "input_preview": {"plugin_id": plugin_id, "files": previews},
        "expected": record["expected"],
        "plot_type": manifest.get("plot_type"),
        "mode": manifest.get("mode"),
        "reproducibility_command": command,
    }


@router.get("/api/plugins/{plugin_id}/examples/{example_id}/files/{filename:path}")
def get_plugin_example_file(plugin_id: str, example_id: str, filename: str) -> FileResponse:
    bundle = example_bundle(plugin_id, example_id)
    manifest = read_example_manifest(bundle)
    allowed_names = {"manifest.json", str(manifest.get("params", "params.json")), str(manifest.get("expected", ""))}
    allowed_names.update(str(value) for value in (manifest.get("inputs") or {}).values() if isinstance(value, str))
    requested = Path(filename).as_posix()
    if requested not in allowed_names:
        raise HTTPException(status_code=404, detail="Example file not found")
    path = example_file(bundle, filename)
    media_type = {
        ".json": "application/json",
        ".png": "image/png",
        ".csv": "text/csv",
        ".tsv": "text/tab-separated-values",
        ".txt": "text/plain",
        ".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        ".xls": "application/vnd.ms-excel",
    }.get(path.suffix.lower(), "application/octet-stream")
    return FileResponse(path, media_type=media_type, filename=path.name)


@router.get("/api/plugins/{plugin_id}/gallery/{filename}")
def plugin_gallery_image(plugin_id: str, filename: str) -> FileResponse:
    safe_id(plugin_id)
    safe_name = Path(filename).name
    path = PLUGIN_DIR / plugin_id / "all_examples_gallery" / safe_name
    if not path.is_file() or path.suffix.lower() != ".png":
        raise HTTPException(status_code=404, detail="Gallery image not found")
    return FileResponse(path, media_type="image/png")


@router.post("/api/plugins/{plugin_id}/preview-input")
async def preview_input(plugin_id: str, request: Request) -> JSONResponse:
    ensure_storage()
    plugin_path(plugin_id)
    preview_id = "preview_" + datetime.now().strftime("%Y%m%d_%H%M%S_") + uuid.uuid4().hex[:8]
    upload_dir = PREVIEWS_DIR / preview_id
    saved_files, _ = await save_uploads(request, upload_dir)
    files = {}
    for field, path in saved_files.items():
        try:
            files[field] = preview_table(path)
        except Exception as exc:
            files[field] = {"filename": path.name, "error": str(exc), "columns": [], "preview_rows": []}
    return JSONResponse({"preview_id": preview_id, "plugin_id": plugin_id, "files": files})


@router.post("/api/plugins/{plugin_id}/run-demo")
async def run_plugin_demo(plugin_id: str, request: Request) -> JSONResponse:
    ensure_storage()
    config = read_yaml(plugin_config_path(plugin_id))
    payload: dict[str, Any] = {}
    try:
        value = await request.json()
        if isinstance(value, dict):
            payload = value
    except Exception:
        pass

    example_id = payload.get("example_id")
    bundle_manifest = None
    if example_id is not None:
        bundle = example_bundle(plugin_id, str(example_id))
        bundle_manifest = read_example_manifest(bundle)
        record = example_record(plugin_id, bundle, bundle_manifest)
        demo = dict(record)
        saved_files: dict[str, Path] = {}
        upload_dir = UPLOADS_DIR / ("demo_" + uuid.uuid4().hex)
        upload_dir.mkdir(parents=True, exist_ok=True)
        for field, info in record["inputs"].items():
            source = example_file(bundle, str(info["path"]))
            target = upload_dir / source.name
            shutil.copy2(source, target)
            saved_files[field] = target
        params = dict(record["params"])
    else:
        demo = demo_payload(plugin_id, config)
        saved_files = demo.pop("_file_paths", {})
        if not saved_files:
            raise HTTPException(status_code=404, detail="No demo input files found for this plugin")
        demo_params = demo.get("params") or {"params": {}}
        params = dict(demo_params.get("params") or {})

    custom_params = payload.get("params")
    if isinstance(custom_params, dict):
        params.update(custom_params)

    params["plugin_id"] = plugin_id
    params.setdefault("dispatch_mode", DEFAULT_DISPATCH_MODE)

    job_id = "job_demo_" + datetime.now().strftime("%Y%m%d_%H%M%S_") + uuid.uuid4().hex[:8]
    figure_id = "fig_" + uuid.uuid4().hex[:12]
    output_dir = RESULTS_DIR / job_id
    job_dir = JOBS_DIR / job_id
    output_dir.mkdir(parents=True, exist_ok=True)
    job_dir.mkdir(parents=True, exist_ok=True)
    params_path = job_dir / "params.json"
    params_path.write_text(json.dumps(params, indent=2, ensure_ascii=False), encoding="utf-8")

    job = {
        "job_id": job_id,
        "figure_id": figure_id,
        "plugin_id": plugin_id,
        "dataset_id": f"dataset_demo_{plugin_id}",
        "status": "queued",
        "message": "Demo job accepted for local execution.",
        "created_at": utc_now(),
        "dispatch_mode": params.get("dispatch_mode", DEFAULT_DISPATCH_MODE),
        "upload_dir": str(PLUGIN_DIR / plugin_id),
        "output_dir": str(output_dir),
        "params_path": str(params_path),
        "uploaded_files": {k: str(v) for k, v in saved_files.items()},
        "demo": demo,
    }
    if example_id is not None:
        job["example_id"] = str(example_id)
        job["bundle_manifest"] = bundle_manifest
    if payload.get("render_channel"):
        job["render_channel"] = str(payload["render_channel"])[:160]
    with state_transaction() as state:
        upsert_node(state, {"id": job["dataset_id"], "type": "dataset", "label": f"{plugin_id} demo", "created_at": job["created_at"], "demo": True})
    save_job(job)

    if job["dispatch_mode"] != "local":
        job.update({"status": "queued", "message": "Non-local dispatch is reserved for future workers; local is the active default."})
        save_job(job)
        return JSONResponse(job)

    cmd = build_command(plugin_id, config, saved_files, params_path, output_dir)
    if payload.get("background") is True:
        return JSONResponse(submit_render(job, cmd, plugin_path(plugin_id), output_dir, run_local_job), status_code=202)
    completed = await run_in_threadpool(run_local_job, job, cmd, plugin_path(plugin_id), output_dir)
    completed["demo"] = demo
    save_job(completed)
    return JSONResponse(completed)


@router.post("/api/plugins/{plugin_id}/run")
async def run_plugin(plugin_id: str, request: Request) -> JSONResponse:
    ensure_storage()
    config = read_yaml(plugin_config_path(plugin_id))
    job_id = "job_" + datetime.now().strftime("%Y%m%d_%H%M%S_") + uuid.uuid4().hex[:8]
    figure_id = "fig_" + uuid.uuid4().hex[:12]
    upload_dir = UPLOADS_DIR / job_id
    output_dir = RESULTS_DIR / job_id
    job_dir = JOBS_DIR / job_id
    output_dir.mkdir(parents=True, exist_ok=True)
    job_dir.mkdir(parents=True, exist_ok=True)

    saved_files, text_fields = await save_uploads(request, upload_dir)
    params = parse_params(text_fields, plugin_id)
    params_path = job_dir / "params.json"
    params_path.write_text(json.dumps(params, indent=2, ensure_ascii=False), encoding="utf-8")

    job = {
        "job_id": job_id,
        "figure_id": figure_id,
        "plugin_id": plugin_id,
        "dataset_id": params.get("dataset_id") or text_fields.get("dataset_id"),
        "status": "queued",
        "message": "Job accepted for local execution.",
        "created_at": utc_now(),
        "dispatch_mode": params.get("dispatch_mode", DEFAULT_DISPATCH_MODE),
        "upload_dir": str(upload_dir),
        "output_dir": str(output_dir),
        "params_path": str(params_path),
        "uploaded_files": {k: str(v) for k, v in saved_files.items()},
    }
    if text_fields.get("render_channel"):
        job["render_channel"] = text_fields["render_channel"][:160]
    save_job(job)

    if job["dispatch_mode"] != "local":
        job.update({"status": "queued", "message": "Non-local dispatch is reserved for future workers; local is the active default."})
        save_job(job)
        return JSONResponse(job)

    cmd = build_command(plugin_id, config, saved_files, params_path, output_dir)
    if text_fields.get("background") == "1":
        return JSONResponse(submit_render(job, cmd, plugin_path(plugin_id), output_dir, run_local_job), status_code=202)
    completed = await run_in_threadpool(run_local_job, job, cmd, plugin_path(plugin_id), output_dir)
    return JSONResponse(completed)
