"""Job status, results, reports and figure download endpoints."""
from __future__ import annotations

import json
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import FileResponse, JSONResponse

from plot_web.server.plugins import plugin_config_path, plugin_path, read_yaml
from plot_web.server.runner import build_command, run_local_job
from plot_web.server.render_tasks import ready_preview
from plot_web.server.settings import JOBS_DIR, REPORTS_DIR, RESULTS_DIR, ROOT_DIR
from plot_web.server.storage import (
    ensure_storage,
    figure_to_job,
    figure_view_file,
    list_jobs,
    load_job,
    output_file_for_type,
    output_urls,
    safe_id,
    save_job,
    utc_now,
)

router = APIRouter()


@router.get("/api/jobs/{job_id}")
def get_job(job_id: str) -> dict[str, Any]:
    job = load_job(job_id)
    if job.get("status") == "running":
        preview = ready_preview(Path(job["output_dir"]))
        if preview:
            job["live_preview"] = f"/api/jobs/{job_id}/preview?kind={preview.suffix[1:]}"
            job["phase"] = "exporting"
    return job


@router.get("/api/jobs/{job_id}/preview")
def job_preview(job_id: str, kind: str | None = None) -> FileResponse:
    job = load_job(job_id)
    if job.get("status") not in {"running", "completed"}:
        raise HTTPException(status_code=404, detail="Preview is not ready")
    path = ready_preview(Path(job["output_dir"]), kind)
    if path is None:
        raise HTTPException(status_code=404, detail="Preview is not ready")
    return FileResponse(path, media_type="image/png" if path.suffix == ".png" else "image/svg+xml")


@router.get("/api/results")
def get_results() -> dict[str, Any]:
    jobs = list_jobs()
    return {"results": jobs}


@router.get("/api/results/{job_id}")
def get_result(job_id: str) -> dict[str, Any]:
    return load_job(job_id)


@router.post("/api/results/{job_id}/rerun")
def rerun_result(job_id: str) -> JSONResponse:
    old = load_job(job_id)
    plugin_id = old["plugin_id"]
    config = read_yaml(plugin_config_path(plugin_id))
    saved_files = {k: Path(v) for k, v in old.get("uploaded_files", {}).items() if Path(v).exists()}
    if not saved_files:
        raise HTTPException(status_code=404, detail="Original input files not found")
    new_job_id = "job_rerun_" + datetime.now().strftime("%Y%m%d_%H%M%S_") + uuid.uuid4().hex[:8]
    figure_id = "fig_" + uuid.uuid4().hex[:12]
    output_dir = RESULTS_DIR / new_job_id
    job_dir = JOBS_DIR / new_job_id
    output_dir.mkdir(parents=True, exist_ok=True)
    job_dir.mkdir(parents=True, exist_ok=True)
    old_params_path = Path(old.get("params_path", ""))
    params = json.loads(old_params_path.read_text(encoding="utf-8")) if old_params_path.exists() else {}
    params_path = job_dir / "params.json"
    params_path.write_text(json.dumps(params, indent=2, ensure_ascii=False), encoding="utf-8")
    job = {**old, "job_id": new_job_id, "figure_id": figure_id, "status": "queued", "message": "Rerun accepted.", "created_at": utc_now(), "output_dir": str(output_dir), "params_path": str(params_path)}
    save_job(job)
    cmd = build_command(plugin_id, config, saved_files, params_path, output_dir)
    return JSONResponse(run_local_job(job, cmd, plugin_path(plugin_id), output_dir))


@router.get("/api/jobs/{job_id}/logs")
def get_job_logs(job_id: str) -> dict[str, Any]:
    job = load_job(job_id)
    result_dir = Path(job["output_dir"])
    logs: list[str] = []
    for name in ("run.log", "subprocess.stdout.log", "subprocess.stderr.log"):
        path = result_dir / name
        if path.exists():
            content = path.read_text(encoding="utf-8", errors="replace")
            if content.strip():
                logs.extend([f"--- {name} ---", *content.splitlines()])
    return {"job_id": job_id, "logs": logs}


@router.get("/api/reports")
def list_reports() -> dict[str, Any]:
    ensure_storage()
    reports = []
    for path in sorted(REPORTS_DIR.glob("*.md"), reverse=True):
        reports.append({"report_id": path.stem, "filename": path.name, "path": str(path), "created_at": datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat()})
    return {"reports": reports}


@router.post("/api/reports/create")
async def create_report(request: Request) -> dict[str, Any]:
    ensure_storage()
    payload = await request.json()
    job_ids = payload.get("job_ids") or [job.get("job_id") for job in list_jobs()[:3]]
    report_id = "report_" + datetime.now().strftime("%Y%m%d_%H%M%S_") + uuid.uuid4().hex[:6]
    path = REPORTS_DIR / f"{report_id}.md"
    lines = ["# OmicsCanvas Plot Studio Report", "", f"Created: {utc_now()}", ""]
    for job_id in job_ids:
        try:
            job = load_job(job_id)
        except HTTPException:
            continue
        lines.extend([
            f"## {job.get('plugin_id')} ({job_id})",
            "",
            f"- Status: {job.get('status')}",
            f"- Output directory: `{job.get('output_dir')}`",
            f"- Params: `{job.get('params_path')}`",
            "",
        ])
        if job.get("outputs", {}).get("png"):
            lines.append(f"![{job.get('plugin_id')}]({Path(job.get('output_dir')) / 'result.png'})")
            lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")
    return {"report_id": report_id, "path": str(path), "download": f"/api/reports/{report_id}/download"}


@router.get("/api/reports/{report_id}/download")
def download_report(report_id: str) -> FileResponse:
    path = REPORTS_DIR / f"{safe_id(report_id)}.md"
    if not path.exists():
        raise HTTPException(status_code=404, detail="Report not found")
    return FileResponse(path, media_type="text/markdown", filename=path.name)


@router.get("/api/figures/{figure_id}")
def get_figure(figure_id: str) -> dict[str, Any]:
    job = figure_to_job(figure_id)
    return {
        "figure_id": figure_id,
        "job_id": job["job_id"],
        "plugin_id": job["plugin_id"],
        "status": "available" if job.get("status") == "completed" else job.get("status"),
        "outputs": output_urls(figure_id),
    }


@router.get("/api/figures/{figure_id}/preview")
def preview_figure(figure_id: str) -> FileResponse:
    job = figure_to_job(figure_id)
    path = Path(job["output_dir"]) / "result.png"
    if not path.exists():
        raise HTTPException(status_code=404, detail="Preview not found")
    return FileResponse(path, media_type="image/png")


@router.get("/api/figures/{figure_id}/view/{rel_path:path}")
def view_figure_asset(figure_id: str, rel_path: str) -> FileResponse:
    """Serve result.html and its result_files/ so the visNetwork widget can load."""
    job = figure_to_job(figure_id)
    path = figure_view_file(Path(job["output_dir"]), rel_path)
    media = {
        ".html": "text/html",
        ".js": "text/javascript",
        ".css": "text/css",
        ".json": "application/json",
        ".png": "image/png",
        ".svg": "image/svg+xml",
        ".woff": "font/woff",
        ".woff2": "font/woff2",
    }.get(path.suffix.lower())
    # Inline: filename= would set Content-Disposition: attachment and the browser
    # downloads the widget instead of rendering it in the canvas iframe.
    return FileResponse(path, media_type=media, content_disposition_type="inline")


@router.get("/api/figures/{figure_id}/download/{file_type}")
def download_figure(figure_id: str, file_type: str) -> FileResponse:
    job = figure_to_job(figure_id)
    path = output_file_for_type(Path(job["output_dir"]), file_type)
    if not path.exists():
        raise HTTPException(status_code=404, detail="Output file not found")
    media_type = {
        "svg": "image/svg+xml",
        "png": "image/png",
        "pdf": "application/pdf",
        "json": "application/json",
        "figure_json": "application/json",
        "plotspec": "application/json",
        "validation": "application/json",
        "log": "text/plain",
        "html": "text/html",
    }.get(file_type, "text/csv")
    return FileResponse(path, media_type=media_type, filename=path.name)


def _editor_inputs(job: dict[str, Any]) -> dict[str, Path]:
    config = read_yaml(plugin_config_path(job['plugin_id']))
    saved = job.get('uploaded_files') or {}
    paths = {}
    for definition in config.get('inputs') or []:
        field = definition.get('id') or definition.get('name') or 'input'
        value = saved.get(field) or (saved.get('file') if field == 'input' else None)
        if not value:
            continue
        path = Path(value).resolve()
        if not path.is_relative_to(ROOT_DIR.resolve()) or not path.is_file():
            raise HTTPException(status_code=404, detail='Saved input is unavailable')
        paths[field] = path
    return paths


@router.get('/api/jobs/{job_id}/editor')
def editor_handoff(job_id: str) -> dict[str, Any]:
    from plot_web.server.tables import preview_table
    from urllib.parse import quote
    job = load_job(job_id)
    files = _editor_inputs(job)
    previews = {}
    for field, path in files.items():
        record = {'filename': path.name}
        if path.suffix.lower() in {'.csv', '.tsv', '.txt', '.xlsx', '.xlsm', '.xls'}:
            record.update(preview_table(path))
        previews[field] = record
    params = json.loads(Path(job['params_path']).read_text(encoding='utf-8'))
    return {'job_id': job_id, 'plugin_id': job['plugin_id'], 'status': job.get('status'),
            'params': params, 'ai': job.get('ai'), 'vnext': job.get('vnext'),
            'outputs': job.get('outputs') or {},
            'input_preview': {'plugin_id': job['plugin_id'], 'files': previews},
            'inputs': {field: {'filename': path.name, 'url': f'/api/jobs/{quote(job_id)}/inputs/{quote(field)}'}
                       for field, path in files.items()}}


@router.get('/api/jobs/{job_id}/inputs/{field}')
def editor_input_file(job_id: str, field: str) -> FileResponse:
    files = _editor_inputs(load_job(job_id))
    if field not in files:
        raise HTTPException(status_code=404, detail='Saved input not found')
    return FileResponse(files[field], filename=files[field].name)
