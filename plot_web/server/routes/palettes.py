"""Color palette catalog endpoints."""
from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException, Request

from plot_web import palettes as palette_catalog

router = APIRouter()


@router.get("/api/palettes")
def api_list_palettes(
    domain: str | None = None,
    tag: str | None = None,
    q: str | None = None,
    catalog: str | None = None,
    family: str | None = None,
    journal: str | None = None,
    min_colors: int | None = None,
    max_colors: int | None = None,
    limit: int = 100,
) -> dict[str, Any]:
    items = palette_catalog.list_palettes(
        domain=domain,
        tag=tag,
        q=q,
        catalog=catalog,
        family=family,
        journal=journal,
        min_colors=min_colors,
        max_colors=max_colors,
        limit=limit,
    )
    meta = palette_catalog.catalog_meta()
    return {
        "meta": meta,
        "sources": meta.get("sources"),
        "count": len(items),
        "total": meta.get("count"),
        "palettes": items,
    }


@router.get("/api/palettes/meta")
def api_palette_meta() -> dict[str, Any]:
    return palette_catalog.catalog_meta()


@router.get("/api/palettes/journals")
def api_palette_journals() -> dict[str, Any]:
    return {"journals": palette_catalog.list_journals()}


@router.get("/api/palettes/themes")
def api_palette_themes() -> dict[str, Any]:
    return {"themes": palette_catalog.list_themes()}


@router.get("/api/palettes/{palette_id}")
def api_get_palette(palette_id: str) -> dict[str, Any]:
    p = palette_catalog.get_palette(palette_id)
    if not p:
        raise HTTPException(status_code=404, detail="Palette not found")
    return {"palette": p, "plugin_params": palette_catalog.palette_as_plugin_params(p)}


@router.post("/api/palettes/recommend")
async def api_recommend_palettes(request: Request) -> dict[str, Any]:
    """Recommend palettes from research goal / target journal / style / n_groups."""
    try:
        body = await request.json()
    except Exception:
        body = {}
    if not isinstance(body, dict):
        body = {}
    goal = str(body.get("goal") or body.get("research") or body.get("query") or "")
    style = str(body.get("style") or "")
    journal = str(body.get("journal") or body.get("target_journal") or "")
    n_groups = body.get("n_groups") or body.get("n_categories")
    try:
        n_groups_i = int(n_groups) if n_groups is not None else None
    except (TypeError, ValueError):
        n_groups_i = None
    limit = int(body.get("limit") or 8)
    recs = palette_catalog.recommend_palettes(
        research_goal=goal,
        n_groups=n_groups_i,
        style=style,
        journal=journal,
        limit=max(1, min(24, limit)),
    )
    return {
        "goal": goal,
        "style": style,
        "journal": journal,
        "n_groups": n_groups_i,
        "recommendations": recs,
        "meta": palette_catalog.catalog_meta(),
    }
