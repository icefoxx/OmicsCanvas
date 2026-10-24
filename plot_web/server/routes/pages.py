"""HTML entry pages and health check."""
from __future__ import annotations

from fastapi import APIRouter
from fastapi.responses import HTMLResponse, RedirectResponse

from plot_web.plot_registry import (
    get_plot,
)
from plot_web.server.settings import DEFAULT_DISPATCH_MODE, STATIC_DIR

router = APIRouter()


@router.get("/", response_class=HTMLResponse)
@router.get("/plots", response_class=HTMLResponse)
@router.get("/analysis", response_class=HTMLResponse)
@router.get("/analysis/{context}", response_class=HTMLResponse)
@router.get("/analysis/{context}/{task}", response_class=HTMLResponse)
@router.get("/scenario", response_class=HTMLResponse)
@router.get("/scenario/{context}", response_class=HTMLResponse)
@router.get("/scenario/{context}/{task}", response_class=HTMLResponse)
@router.get("/category", response_class=HTMLResponse)
@router.get("/category/{chart_id}", response_class=HTMLResponse)
@router.get("/chart-type", response_class=HTMLResponse)
@router.get("/chart-type/{chart_id}", response_class=HTMLResponse)
@router.get("/family/{plot_id}", response_class=HTMLResponse)
def index(
    context: str | None = None,
    task: str | None = None,
    plot_id: str | None = None,
    chart_id: str | None = None,
) -> str:
    return (STATIC_DIR / "index.html").read_text(encoding="utf-8")


@router.get("/plot/{plot_id}")
@router.get("/plot/{plot_id}/{variant_id}")
def plot_studio_entry(
    plot_id: str,
    variant_id: str | None = None,
    source_context: str | None = None,
    source_task: str | None = None,
    example: str | None = None,
) -> RedirectResponse:
    plot = get_plot(plot_id)
    engine = str((plot or {}).get("engine_plugin_id") or plot_id)
    family = str((plot or {}).get("id") or plot_id)
    params = [f"plugin={engine}", f"plot={family}"]
    if variant_id:
        params.append(f"variant={variant_id}")
    if example:
        params.append(f"example={example}")
    if source_context:
        params.append(f"source_context={source_context}")
    if source_task:
        params.append(f"source_task={source_task}")
    return RedirectResponse("/static/editor.html?" + "&".join(params))


@router.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "biofigureai-backend", "dispatch_mode": DEFAULT_DISPATCH_MODE}
