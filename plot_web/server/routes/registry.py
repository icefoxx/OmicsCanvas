"""Plot registry / discovery endpoints."""
from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException, Request

from plot_web.plot_guide import build_caption, compose_guide
from plot_web.plot_registry import (
    browse_categories,
    chart_categories,
    discovery_taxonomy,
    get_all_plots,
    get_compatible_plots,
    get_plot,
    get_plots_by_context,
    get_plots_by_task,
    get_recommended_plots,
    get_variant,
    get_variants,
    resolve_legacy_preset,
    search_plots,
    validate_registry,
)
from plot_web.server.plugins import list_plot_styles

router = APIRouter()


@router.get("/api/registry/plots")
def registry_list_plots() -> dict[str, Any]:
    plots = get_all_plots()
    return {"plots": plots, "count": len(plots)}


@router.get("/api/registry/plots/{plot_id}")
def registry_get_plot(plot_id: str) -> dict[str, Any]:
    plot = get_plot(plot_id)
    if not plot:
        raise HTTPException(status_code=404, detail="Plot family not found")
    return plot


@router.get("/api/registry/plots/{plot_id}/guide")
def registry_get_guide(
    plot_id: str,
    variant: str | None = None,
    example: str | None = None,
) -> dict[str, Any]:
    payload = compose_guide(plot_id, variant_id=variant, example_id=example)
    if payload.get("reason") == "Plot family not found":
        raise HTTPException(status_code=404, detail="Plot family not found")
    return payload


@router.post("/api/registry/plots/{plot_id}/caption")
async def registry_caption(plot_id: str, request: Request) -> dict[str, Any]:
    plot = get_plot(plot_id)
    if not plot:
        raise HTTPException(status_code=404, detail="Plot family not found")
    body: dict[str, Any] = {}
    try:
        value = await request.json()
        if isinstance(value, dict):
            body = value
    except Exception:
        body = {}
    payload = compose_guide(
        plot_id,
        variant_id=body.get("variant") or body.get("variant_id"),
        example_id=body.get("example") or body.get("example_id"),
        params=body.get("params") if isinstance(body.get("params"), dict) else {},
    )
    caption = payload.get("caption") or build_caption(plot, None, body.get("params") if isinstance(body.get("params"), dict) else {})
    return {"plot_id": payload.get("plot_id"), "caption": caption, "current": payload.get("current")}


@router.get("/api/registry/plots/{plot_id}/styles")
def registry_get_styles(plot_id: str) -> dict[str, Any]:
    return list_plot_styles(plot_id)


@router.get("/api/registry/plots/{plot_id}/variants")
def registry_get_variants(plot_id: str) -> dict[str, Any]:
    if not get_plot(plot_id):
        raise HTTPException(status_code=404, detail="Plot family not found")
    return {"plot_id": plot_id, "variants": get_variants(plot_id)}


@router.get("/api/registry/plots/{plot_id}/variants/{variant_id}")
def registry_get_variant(plot_id: str, variant_id: str) -> dict[str, Any]:
    variant = get_variant(plot_id, variant_id)
    if not variant:
        raise HTTPException(status_code=404, detail="Variant not found")
    return variant


@router.get("/api/registry/search")
def registry_search(q: str = "") -> dict[str, Any]:
    hits = search_plots(q)
    return {"query": q, "results": hits, "count": len(hits)}


@router.get("/api/registry/context/{context}")
def registry_by_context(context: str) -> dict[str, Any]:
    return {"context": context, "plots": get_plots_by_context(context)}


@router.get("/api/registry/task/{task}")
def registry_by_task(task: str) -> dict[str, Any]:
    return {"task": task, "plots": get_plots_by_task(task)}


@router.post("/api/registry/compatible")
async def registry_compatible(request: Request) -> dict[str, Any]:
    body = {}
    try:
        value = await request.json()
        if isinstance(value, dict):
            body = value
    except Exception:
        body = {}
    schema = body.get("dataSchema") or body.get("schema") or body
    return {"plots": get_compatible_plots(schema if isinstance(schema, dict) else {})}


@router.post("/api/registry/recommend")
async def registry_recommend(request: Request) -> dict[str, Any]:
    body: dict[str, Any] = {}
    try:
        value = await request.json()
        if isinstance(value, dict):
            body = value
    except Exception:
        body = {}
    schema = body.get("dataSchema") or body.get("schema") or {}
    context = body.get("context")
    return {"recommendations": get_recommended_plots(schema if isinstance(schema, dict) else {}, context)}


@router.get("/api/registry/legacy/{plot_id}/{legacy_preset_id}")
def registry_legacy(plot_id: str, legacy_preset_id: str) -> dict[str, Any]:
    resolved = resolve_legacy_preset(plot_id, legacy_preset_id)
    if not resolved:
        raise HTTPException(status_code=404, detail="Legacy preset not found")
    return resolved


@router.get("/api/registry/validate")
def registry_validate() -> dict[str, Any]:
    return validate_registry()


@router.get("/api/registry/discovery")
def registry_discovery() -> dict[str, Any]:
    return {
        "taxonomy": discovery_taxonomy(),
        "browse": browse_categories(),
        "chart_categories": chart_categories(),
    }


@router.get("/api/registry/discovery/taxonomy")
def registry_taxonomy() -> dict[str, Any]:
    return discovery_taxonomy()


@router.get("/api/registry/discovery/browse")
def registry_browse() -> dict[str, Any]:
    return browse_categories()


@router.get("/api/registry/discovery/categories")
def registry_chart_categories() -> dict[str, Any]:
    return chart_categories()
