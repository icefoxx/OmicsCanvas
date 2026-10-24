"""vNext PlotSpec API (additive; does not replace legacy params.json jobs)."""
from __future__ import annotations

import json
import shutil
import uuid
from pathlib import Path
from typing import Any

from fastapi import APIRouter, HTTPException, Request
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import JSONResponse

from plot_web.server.settings import UPLOADS_DIR
from plot_web.server.storage import ensure_storage

router = APIRouter()


# vNext PlotSpec API (additive; does not replace legacy params.json jobs)


@router.get("/api/vnext/status")
def vnext_status() -> dict[str, Any]:
    try:
        from vnext import __version__ as vnext_version
        from vnext.registry.loader import load_registry, validate_registry

        reg = load_registry()
        val = validate_registry(reg)
        migrated = [
            s.get("id")
            for s in (reg.get("skills") or [])
            if (s.get("capabilities") or {}).get("vnext_migrated")
        ]
        return {
            "ok": True,
            "framework_version": vnext_version,
            "registry_valid": val.get("valid"),
            "n_skills": val.get("n_skills"),
            "migrated_skills": migrated,
        }
    except Exception as exc:
        return {"ok": False, "error": str(exc)}


@router.post("/api/vnext/validate")
async def vnext_validate(request: Request) -> JSONResponse:
    """Validate a PlotSpec JSON body; optional multipart with file for scientific checks."""
    try:
        from vnext.validate.pipeline import validate_plotspec
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"vnext unavailable: {exc}") from exc

    content_type = (request.headers.get("content-type") or "").lower()
    table_path: Path | None = None
    spec: dict[str, Any] | None = None

    if "multipart/form-data" in content_type:
        form = await request.form()
        raw = form.get("spec") or form.get("plotspec")
        if isinstance(raw, str):
            try:
                spec = json.loads(raw)
            except json.JSONDecodeError as exc:
                raise HTTPException(status_code=400, detail=f"Invalid PlotSpec JSON: {exc}") from exc
        upload = form.get("file") or form.get("input")
        filename = getattr(upload, "filename", None)
        if filename:
            ensure_storage()
            tmp = UPLOADS_DIR / ("vnext_" + uuid.uuid4().hex[:10])
            tmp.mkdir(parents=True, exist_ok=True)
            table_path = tmp / Path(filename).name
            with table_path.open("wb") as handle:
                shutil.copyfileobj(upload.file, handle)
    else:
        try:
            body = await request.json()
        except Exception:
            body = {}
        if not isinstance(body, dict):
            body = {}
        spec = body.get("spec") if isinstance(body.get("spec"), dict) else body

    if not isinstance(spec, dict):
        raise HTTPException(status_code=400, detail="PlotSpec object required")
    result = validate_plotspec(spec, table_path=table_path)
    return JSONResponse(result)


@router.get("/api/figures/{figure_id}/bundle")
async def download_bundle(figure_id: str):
    """Zip of plotspec.json, inputs, params, figures, methods, runtime, validation + checksums."""
    from fastapi.responses import FileResponse

    from plot_web.server.plotspec import build_bundle_zip
    from plot_web.server.storage import figure_to_job

    job = figure_to_job(figure_id)
    try:
        path = await run_in_threadpool(build_bundle_zip, job)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return FileResponse(path, media_type="application/zip", filename=f"{job['plugin_id']}_{figure_id}_bundle.zip")


async def _json_body(request: Request) -> dict[str, Any]:
    try:
        body = await request.json()
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Invalid JSON body: {exc}") from exc
    if not isinstance(body, dict):
        raise HTTPException(status_code=400, detail="Body must be a JSON object")
    return body


@router.post("/api/vnext/plotspec/from-params")
async def plotspec_from_params(request: Request) -> dict[str, Any]:
    """Body: {plugin_id, params} -> {plotspec, schema} (export the Studio state as a PlotSpec)."""
    from vnext.adapters.legacy_r import legacy_params_to_plotspec, load_skill_metadata
    from vnext.plotspec.model import validate_schema

    body = await _json_body(request)
    plugin_id = str(body.get("plugin_id") or "")
    params = body.get("params") if isinstance(body.get("params"), dict) else {}
    meta = load_skill_metadata(plugin_id)
    if not meta:
        raise HTTPException(status_code=404, detail=f"No vNext metadata for plugin '{plugin_id}'")
    spec = legacy_params_to_plotspec(plugin_id, params, meta=meta, seed=params.get("seed", 42))
    spec["provenance"]["user_modified"] = bool(body.get("user_modified", True))
    return {"plotspec": spec, "schema": validate_schema(spec)}


@router.post("/api/vnext/plotspec/to-params")
async def plotspec_to_params(request: Request) -> dict[str, Any]:
    """Body: {plotspec} -> {plugin_id, params, schema, unsupported_roles} (import a PlotSpec into Studio)."""
    from vnext.adapters.legacy_r import load_skill_metadata, plotspec_to_legacy_params, unsupported_roles
    from vnext.plotspec.model import validate_schema

    body = await _json_body(request)
    spec = body.get("plotspec") if isinstance(body.get("plotspec"), dict) else body
    schema = validate_schema(spec)
    if not schema.get("valid"):
        raise HTTPException(status_code=422, detail={"message": "Not a valid PlotSpec", "errors": schema["errors"][:10]})
    plugin_id = str((spec.get("skill") or {}).get("id") or "")
    meta = load_skill_metadata(plugin_id)
    if not meta:
        raise HTTPException(status_code=404, detail=f"No vNext metadata for skill '{plugin_id}'")
    params = plotspec_to_legacy_params(spec, meta)
    params.pop("plugin_id", None)
    seed = (spec.get("provenance") or {}).get("seed")
    if seed is not None and seed != 42:
        params["seed"] = seed
    return {"plugin_id": plugin_id, "params": params, "schema": schema, "unsupported_roles": unsupported_roles(spec, meta)}
