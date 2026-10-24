"""Deterministic plot-guide composition: family + variant + current params."""
from __future__ import annotations

import re
from pathlib import Path
from typing import Any

from plot_web.plot_registry import get_plot, get_variant, load_registry, resolve_legacy_preset
from plot_web.yaml_cache import load_yaml_cached

REG_DIR = Path(__file__).resolve().parent / "registry"
GUIDES_DIR = REG_DIR / "guides"
LITERATURE_PATH = REG_DIR / "literature.yaml"

PLACEHOLDER = re.compile(r"\{([a-zA-Z0-9_]+)\}")


def load_yaml(path: Path) -> Any:
    try:
        return load_yaml_cached(path)
    except Exception:
        return None


def load_literature() -> dict[str, dict[str, Any]]:
    raw = load_yaml(LITERATURE_PATH) or {}
    entries = raw.get("entries") if isinstance(raw, dict) else raw
    out: dict[str, dict[str, Any]] = {}
    if isinstance(entries, list):
        for item in entries:
            if isinstance(item, dict) and item.get("id"):
                out[str(item["id"])] = item
    elif isinstance(entries, dict):
        for key, item in entries.items():
            if isinstance(item, dict):
                item = {"id": key, **item}
                out[str(item["id"])] = item
    return out


def load_family_guide(plot_id: str) -> dict[str, Any]:
    data = load_yaml(GUIDES_DIR / f"{plot_id}.yaml")
    return data if isinstance(data, dict) else {}


def public_literature(entry: dict[str, Any]) -> dict[str, Any]:
    allowed = bool(entry.get("thumbnail_reuse_allowed"))
    thumb = entry.get("thumbnail_asset") if allowed else None
    return {
        "id": entry.get("id"),
        "title": entry.get("title") or "",
        "authors": entry.get("authors") or "",
        "citation": entry.get("citation") or "",
        "journal": entry.get("journal") or "",
        "year": entry.get("year"),
        "doi": entry.get("doi") or "",
        "url": entry.get("url") or "",
        "figure": entry.get("figure") or "",
        "license": entry.get("license") or "",
        "thumbnail_reuse_allowed": allowed,
        "thumbnail_asset": thumb,
        "description": entry.get("description") or "",
        "relevance": entry.get("relevance") or entry.get("why") or "",
        "use_case": entry.get("use_case") or entry.get("use_cases") or [],
    }


def attach_guides(registry: dict[str, Any]) -> dict[str, Any]:
    lit = load_literature()
    for plot in registry.get("plots") or []:
        pid = str(plot.get("id") or "")
        data = load_family_guide(pid)
        if not data:
            continue
        family_guide = {k: v for k, v in data.items() if k != "variants"}
        ids = list(family_guide.pop("literature_ids", []) or [])
        family_guide["literature"] = [public_literature(lit[i]) for i in ids if i in lit]
        plot["guide"] = family_guide
        vg = data.get("variants") if isinstance(data.get("variants"), dict) else {}
        for variant in plot.get("variants") or []:
            extra = vg.get(str(variant.get("id")))
            if not isinstance(extra, dict):
                for lid in variant.get("legacy_ids") or []:
                    extra = vg.get(str(lid))
                    if isinstance(extra, dict):
                        break
            if isinstance(extra, dict):
                variant["guide"] = extra
    return registry


def mapping_values(params: dict[str, Any] | None, family: dict[str, Any] | None = None) -> dict[str, str]:
    params = params if isinstance(params, dict) else {}
    family = family or {}
    def first(*keys: str) -> str:
        for key in keys:
            value = params.get(key)
            if value in (None, "", [], {}):
                continue
            if isinstance(value, list):
                return ", ".join(str(v) for v in value if v not in (None, ""))
            return str(value)
        return ""
    return {
        "family_name": str(family.get("name") or family.get("short_name") or family.get("id") or "Plot"),
        "observation_type": first("observation_type") or str((family.get("guide") or {}).get("observation_type") or "observations"),
        "group_column": first("group_column", "color_by", "cluster_column"),
        "split_column": first("split_column", "facet_column"),
        "feature_column": first("feature", "feature_column", "features"),
        "composition_column": first("stat_plot_column", "composition_column", "pie_column"),
        "cluster_column": first("group_column", "cluster_column"),
        "highlight_column": first("highlight_column", "highlight_rows"),
        "x_column": first("x_column", "dim1"),
        "y_column": first("y_column", "dim2"),
    }


def render_template(text: Any, values: dict[str, str]) -> str:
    if not isinstance(text, str) or not text.strip():
        return ""
    keys = PLACEHOLDER.findall(text)
    for key in keys:
        if not str(values.get(key) or "").strip():
            return ""
    filled = PLACEHOLDER.sub(lambda m: str(values.get(m.group(1)) or ""), text)
    return re.sub(r"\s+", " ", filled).strip()


def build_caption(family: dict[str, Any], variant: dict[str, Any] | None, params: dict[str, Any] | None) -> str:
    values = mapping_values(params, family)
    parts: list[str] = []
    reporting = (family.get("guide") or {}).get("reporting") or {}
    base = render_template(reporting.get("base_template"), values)
    if base:
        parts.append(base)
    variant_clause = ""
    if variant:
        vrep = (variant.get("guide") or {}).get("reporting") or {}
        tmpl = vrep.get("template") if isinstance(vrep, dict) else None
        variant_clause = render_template(tmpl, values)
    mappings = reporting.get("mappings") if isinstance(reporting.get("mappings"), dict) else {}
    used = set(PLACEHOLDER.findall(variant_clause))
    for tmpl in mappings.values():
        keys = set(PLACEHOLDER.findall(str(tmpl or "")))
        if keys and keys <= used:
            continue
        clause = render_template(tmpl, values)
        if clause:
            parts.append(clause)
            used.update(keys)
    if variant_clause:
        parts.append(variant_clause)
    return " ".join(parts)


def current_view_explanation(family: dict[str, Any], variant: dict[str, Any] | None, params: dict[str, Any] | None) -> dict[str, Any]:
    params = params if isinstance(params, dict) else {}
    values = mapping_values(params, family)
    vid = str((variant or {}).get("id") or "")
    statements: list[dict[str, str]] = []
    summary = ""
    if variant:
        summary = str((variant.get("guide") or {}).get("summary") or variant.get("description") or "")
    if not summary:
        summary = str((family.get("guide") or {}).get("summary") or family.get("description") or "")

    if values.get("group_column"):
        statements.append({
            "type": "direct",
            "title": "Group color",
            "text": f"Points or marks are colored according to {values['group_column']}.",
        })
    if values.get("feature_column"):
        statements.append({
            "type": "direct",
            "title": "Feature mapping",
            "text": f"Color intensity represents {values['feature_column']}.",
        })
    if values.get("split_column"):
        statements.append({
            "type": "direct",
            "title": "Split panels",
            "text": f"The embedding is shown separately by {values['split_column']}.",
        })
    if values.get("composition_column") and vid in {"composition", "composition_pie", "composition_ring", "stat_panel"}:
        group = values.get("cluster_column") or "each group"
        statements.append({
            "type": "direct",
            "title": "Composition slices",
            "text": f"Each pie or ring summarizes {values['composition_column']} within {group}.",
        })
        statements.append({
            "type": "caution",
            "title": "Pie size",
            "text": "Pie or ring area should be treated as a visual scale unless size is explicitly mapped to an abundance metric.",
        })
    if vid == "density":
        statements.append({
            "type": "interpretation",
            "title": "Density",
            "text": "Filled or hex regions summarize local observation density on the embedding.",
        })
    if vid == "ellipse":
        statements.append({
            "type": "interpretation",
            "title": "Ellipses",
            "text": "Ellipses summarize the spread of a group on the embedding; they are not a statistical test.",
        })
    if vid == "highlight_cells":
        statements.append({
            "type": "direct",
            "title": "Highlight",
            "text": "Highlighted observations are emphasized; other points are faded for contrast.",
        })
    return {
        "variant_id": vid or None,
        "variant_name": (variant or {}).get("name") or None,
        "summary": summary,
        "statements": statements,
    }


def resolve_variant(plot: dict[str, Any], variant_id: str | None, example_id: str | None) -> dict[str, Any] | None:
    if example_id:
        resolved = resolve_legacy_preset(str(plot.get("id")), example_id)
        if resolved and resolved.get("variant"):
            variant_id = resolved["variant"]
        else:
            for variant in plot.get("variants") or []:
                if example_id in (variant.get("legacy_ids") or []) or example_id == variant.get("id"):
                    return variant
    if not variant_id:
        return None
    return get_variant(str(plot.get("id")), variant_id) or next(
        (v for v in plot.get("variants") or [] if str(v.get("id")) == str(variant_id)),
        None,
    )


def gallery_url(asset: Any) -> str | None:
    if not isinstance(asset, str) or not asset.strip():
        return None
    if asset.startswith("/"):
        return asset
    parts = Path(asset).parts
    if len(parts) >= 2 and parts[0] == "plugins":
        plugin_id = parts[1]
        name = Path(asset).name
        return f"/api/plugins/{plugin_id}/gallery/{name}"
    if asset.endswith(".png"):
        return asset
    return None


def compose_guide(
    plot_id: str,
    variant_id: str | None = None,
    example_id: str | None = None,
    params: dict[str, Any] | None = None,
    registry: dict[str, Any] | None = None,
) -> dict[str, Any]:
    plot = get_plot(plot_id, registry)
    if not plot:
        return {"available": False, "reason": "Plot family not found"}
    if not plot.get("guide"):
        plot = get_plot(plot_id, load_registry()) or plot
    family_guide = plot.get("guide") if isinstance(plot.get("guide"), dict) else {}
    variant = resolve_variant(plot, variant_id, example_id)
    variant_guide = (variant or {}).get("guide") if isinstance((variant or {}).get("guide"), dict) else {}
    examples = []
    for item in family_guide.get("examples") or []:
        if not isinstance(item, dict):
            continue
        examples.append({
            **item,
            "preview_url": gallery_url(item.get("preview_asset")),
        })
    literature = [public_literature(item) if "thumbnail_reuse_allowed" in item else item for item in family_guide.get("literature") or []]
    caption = build_caption(plot, variant, params)
    current = current_view_explanation(plot, variant, params)
    available = bool(family_guide)
    return {
        "available": available,
        "plot_id": plot.get("id"),
        "name": plot.get("name"),
        "engine_plugin_id": plot.get("engine_plugin_id"),
        "family_guide": family_guide or None,
        "variant": {
            "id": variant.get("id"),
            "name": variant.get("name"),
            "guide": variant_guide or None,
        } if variant else None,
        "examples": examples,
        "literature": literature,
        "current": current,
        "caption": caption,
        "empty_message": None if available else "Guide content is not available for this plot yet.",
    }
