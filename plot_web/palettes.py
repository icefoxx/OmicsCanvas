"""Unified scientific color palette catalog + Theme / journal recommend helpers.

Sources (merged into unified_color_palettes.json):
  - builtin classic (NPG, Lancet, NEJM, …)
  - AMFE Color (https://color.amfe.space)
  - lcpmgh/colors (https://github.com/lcpmgh/colors, MIT)
"""
from __future__ import annotations

import json
import re
from functools import lru_cache
from pathlib import Path
from typing import Any

DATA_CANDIDATES = [
    Path(__file__).resolve().parent / "data" / "unified_color_palettes.json",
    Path(__file__).resolve().parents[1] / "assets" / "palettes" / "unified_color_palettes.json",
    # fallbacks if unified not built yet
    Path(__file__).resolve().parent / "data" / "amfe_color_palettes.json",
    Path(__file__).resolve().parents[1] / "assets" / "palettes" / "amfe_color_palettes.json",
]


@lru_cache(maxsize=1)
def load_catalog() -> dict[str, Any]:
    for path in DATA_CANDIDATES:
        if path.is_file():
            data = json.loads(path.read_text(encoding="utf-8"))
            data["_path"] = str(path)
            # normalize missing fields for older amfe-only files
            data.setdefault("journals", [])
            data.setdefault("journal_groups", {})
            data.setdefault("sources", data.get("source") or {})
            data.setdefault("classic_aliases", {})
            data.setdefault("themes", {})
            for p in data.get("palettes") or []:
                p.setdefault("catalog", "amfe" if str(p.get("id", "")).startswith("amfe") else "unknown")
                p.setdefault("family", p.get("catalog"))
                p.setdefault("n_colors", len(p.get("colors") or []))
            return data
    return {
        "version": "0",
        "sources": {},
        "count": 0,
        "themes": {},
        "classic_aliases": {},
        "journals": [],
        "journal_groups": {},
        "palettes": [],
        "_path": None,
    }


def reload_catalog() -> dict[str, Any]:
    load_catalog.cache_clear()
    return load_catalog()


def _public_palette(p: dict[str, Any]) -> dict[str, Any]:
    """Drop internal/localized fields so the web API never exposes Chinese labels."""
    skip = {"name_zh", "tags_zh", "keywords_match_extra"}
    return {k: v for k, v in p.items() if k not in skip}


def list_palettes(
    *,
    domain: str | None = None,
    tag: str | None = None,
    q: str | None = None,
    catalog: str | None = None,
    family: str | None = None,
    journal: str | None = None,
    min_colors: int | None = None,
    max_colors: int | None = None,
    limit: int = 100,
) -> list[dict[str, Any]]:
    cat = load_catalog()
    items = list(cat.get("palettes") or [])
    if catalog:
        c = catalog.lower()
        items = [p for p in items if (p.get("catalog") or "").lower() == c]
    if family:
        f = family.lower()
        items = [
            p
            for p in items
            if f in (p.get("family") or "").lower()
            or f in [x.lower() for x in (p.get("tags") or [])]
        ]
    if journal:
        j = journal.lower()
        items = [
            p
            for p in items
            if j in (p.get("journal") or "").lower()
            or j in (p.get("name") or "").lower()
            or j in [x.lower() for x in (p.get("tags") or [])]
        ]
    if domain:
        d = domain.lower()
        items = [p for p in items if d in [x.lower() for x in (p.get("domains") or [])]]
    if tag:
        t = tag.lower()
        items = [p for p in items if t in [x.lower() for x in (p.get("tags") or [])]]
    if q:
        ql = q.lower()
        items = [
            p
            for p in items
            if ql in (p.get("name") or "").lower()
            or ql in " ".join(p.get("tags") or []).lower()
            or ql in " ".join(p.get("domains") or []).lower()
            or ql in (p.get("journal") or "").lower()
            or ql in (p.get("classic_key") or "").lower()
            or ql in (p.get("id") or "").lower()
            or ql in (p.get("family") or "").lower()
        ]
    if min_colors is not None:
        items = [p for p in items if int(p.get("n_colors") or 0) >= min_colors]
    if max_colors is not None:
        items = [p for p in items if int(p.get("n_colors") or 0) <= max_colors]
    # prefer higher likes when no other sort
    items.sort(key=lambda p: (-int(p.get("likes") or 0), p.get("id") or ""))
    return [_public_palette(p) for p in items[: max(1, min(limit, 400))]]


def get_palette(palette_id: str) -> dict[str, Any] | None:
    cat = load_catalog()
    aliases = cat.get("classic_aliases") or {}
    key = palette_id
    if key in aliases:
        key = aliases[key]
    elif key.lower() in aliases:
        key = aliases[key.lower()]
    for p in cat.get("palettes") or []:
        if p.get("id") == key or str(p.get("source_id")) == str(palette_id):
            return _public_palette(p)
        if (p.get("classic_key") or "").lower() == palette_id.lower():
            return _public_palette(p)
    return None


def list_journals() -> list[dict[str, Any]]:
    cat = load_catalog()
    groups = cat.get("journal_groups") or {}
    by_id = {p["id"]: p for p in cat.get("palettes") or []}
    out = []
    for name in cat.get("journals") or sorted(groups.keys()):
        ids = groups.get(name) or []
        sample = []
        for pid in ids[:3]:
            p = by_id.get(pid)
            if p:
                sample.append({"id": p["id"], "name": p["name"], "colors": p["colors"][:8]})
        out.append({"journal": name, "count": len(ids), "sample": sample})
    out.sort(key=lambda x: (-x["count"], x["journal"].lower()))
    return out


def list_themes() -> dict[str, Any]:
    cat = load_catalog()
    themes = cat.get("themes") or {}
    by_id = {p["id"]: p for p in cat.get("palettes") or []}
    out = {}
    for key, meta in themes.items():
        ids = meta.get("recommend_ids") or []
        pals = []
        for pid in ids:
            p = by_id.get(pid)
            if not p:
                continue
            pals.append(
                {
                    "id": p["id"],
                    "name": p["name"],
                    "colors": p["colors"],
                    "n_colors": p["n_colors"],
                    "tags": p.get("tags"),
                    "likes": p.get("likes"),
                    "journal": p.get("journal"),
                    "catalog": p.get("catalog"),
                    "source_url": p.get("source_url"),
                }
            )
        out[key] = {
            "id": key,
            "label": meta.get("label") or key,
            "keywords": meta.get("keywords") or [],
            "palettes": pals,
        }
    return out


def catalog_meta() -> dict[str, Any]:
    cat = load_catalog()
    families: dict[str, int] = {}
    catalogs: dict[str, int] = {}
    for p in cat.get("palettes") or []:
        f = p.get("family") or "other"
        c = p.get("catalog") or "other"
        families[f] = families.get(f, 0) + 1
        catalogs[c] = catalogs.get(c, 0) + 1
    return {
        "count": cat.get("count") or len(cat.get("palettes") or []),
        "sources": cat.get("sources") or cat.get("source") or {},
        "journals": cat.get("journals") or [],
        "families": families,
        "catalogs": catalogs,
        "path": cat.get("_path"),
        "version": cat.get("version"),
    }


def recommend_palettes(
    *,
    research_goal: str = "",
    n_groups: int | None = None,
    style: str | None = None,
    journal: str | None = None,
    limit: int = 5,
) -> list[dict[str, Any]]:
    """Recommend palettes for a research goal / target journal / plot need."""
    cat = load_catalog()
    goal = (research_goal or "").lower()
    style_l = (style or "").lower()
    journal_l = (journal or "").lower().strip()
    themes = cat.get("themes") or {}
    by_id = {p["id"]: p for p in cat.get("palettes") or []}
    journal_groups = cat.get("journal_groups") or {}

    scores: dict[str, float] = {}
    reasons: dict[str, str] = {}

    # explicit journal match (highest priority)
    if journal_l:
        for jname, ids in journal_groups.items():
            if journal_l in jname.lower() or jname.lower() in journal_l:
                for pid in ids:
                    scores[pid] = scores.get(pid, 0) + 12.0
                    reasons[pid] = f"Target journal: {jname}"
        for p in cat.get("palettes") or []:
            j = (p.get("journal") or "").lower()
            name = (p.get("name") or "").lower()
            tags = " ".join(p.get("tags") or []).lower()
            if journal_l in j or journal_l in name or journal_l in tags:
                scores[p["id"]] = scores.get(p["id"], 0) + 10.0
                reasons.setdefault(p["id"], f"Matches journal “{p.get('journal') or p.get('name')}”")

    # journal name also in free-text goal
    if not journal_l and goal:
        for jname, ids in journal_groups.items():
            if jname.lower() in goal:
                for pid in ids[:8]:
                    scores[pid] = scores.get(pid, 0) + 8.0
                    reasons[pid] = f"Goal mentions journal {jname}"

    # theme keyword hits
    for theme_id, meta in themes.items():
        hit = 0.0
        kws = list(meta.get("keywords") or []) + list(meta.get("keywords_match_extra") or [])
        for kw in kws:
            token = kw.lower().strip()
            if token and re.search(r'(?<![a-z0-9])' + re.escape(token) + r'(?![a-z0-9])', goal):
                hit += 3.0
        label = (meta.get("label") or "").lower()
        if any(re.search(r"(?<![a-z0-9])" + re.escape(tok) + r"(?![a-z0-9])", goal) for tok in re.split(r"[\s/、,]+", label) if len(tok) > 1):
            hit += 2.0
        if hit <= 0:
            continue
        for pid in meta.get("recommend_ids") or []:
            scores[pid] = scores.get(pid, 0) + hit
            reasons.setdefault(pid, f"Matches research theme “{meta.get('label') or theme_id}”")

    # style hints
    style_map = {
        "soft": ["soft", "pastel"],
        "high_contrast": ["categorical", "high_contrast"],
        "grayscale": ["grayscale", "minimal"],
        "journal": ["sci_journal", "publication", "biomedical"],
        "dark": ["dark_mode", "cyber"],
        "nature": ["ecology", "environment", "plant"],
        "medical": ["medical", "clinical"],
        "ml": ["ml_cs", "computer_vision"],
        "colorblind": ["colorblind", "accessible"],
    }
    for style_key, domains in style_map.items():
        if style_key in goal or style_key in style_l or any(s in goal for s in domains):
            for p in cat.get("palettes") or []:
                if set(domains) & set(p.get("domains") or []):
                    scores[p["id"]] = scores.get(p["id"], 0) + 2.5
                    reasons.setdefault(p["id"], f"Style preference: {style_key}")

    # n_groups: prefer palettes with enough colors
    if n_groups:
        for p in cat.get("palettes") or []:
            n = int(p.get("n_colors") or 0)
            if n >= n_groups:
                scores[p["id"]] = scores.get(p["id"], 0) + 1.5 + min(2.0, (n - n_groups) * 0.1)
            elif n >= max(2, n_groups - 1):
                scores[p["id"]] = scores.get(p["id"], 0) + 0.5

    # boost classic built-ins slightly for empty goals
    for p in cat.get("palettes") or []:
        scores[p["id"]] = scores.get(p["id"], 0) + min(2.0, (p.get("likes") or 0) / 250.0)
        if p.get("catalog") == "builtin":
            scores[p["id"]] = scores.get(p["id"], 0) + 0.8

    if not scores:
        ranked = sorted(cat.get("palettes") or [], key=lambda x: -int(x.get("likes") or 0))[:limit]
        return [
            {
                **_public_palette(p),
                "score": round(min(2.0, (p.get("likes") or 0) / 250.0), 2),
                "reason": "Popular scientific palette (general recommendation)",
            }
            for p in ranked
        ]

    ranked_ids = sorted(scores.items(), key=lambda kv: (-kv[1], kv[0]))
    out = []
    for pid, sc in ranked_ids:
        p = by_id.get(pid)
        if not p:
            continue
        if n_groups and int(p.get("n_colors") or 0) < max(2, n_groups - 2):
            continue
        item = _public_palette(p)
        item["score"] = round(sc, 2)
        item["reason"] = reasons.get(pid) or "Overall match"
        out.append(item)
        if len(out) >= limit:
            break
    return out


def palette_as_plugin_params(palette: dict[str, Any]) -> dict[str, Any]:
    """Map a palette into common plugin param fields."""
    colors = list(palette.get("colors") or [])
    classic = palette.get("classic_key")
    # Prefer a short named key for R packages when available
    palette_name = classic or palette.get("name") or palette.get("id")
    return {
        "theme_palette_id": palette.get("id"),
        "palette_id": palette.get("id"),
        "palette_name": palette.get("name"),
        "palette_colors": colors,
        "custom_colors": colors,
        "palcolor": colors,
        "colors": colors,
        "palette": classic if classic and not str(classic).startswith("#") else palette_name,
        "group_colors": {f"g{i+1}": c for i, c in enumerate(colors)},
        "source": palette.get("source_url") or palette.get("source"),
        "journal": palette.get("journal"),
        "catalog": palette.get("catalog"),
    }
