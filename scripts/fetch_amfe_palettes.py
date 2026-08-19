#!/usr/bin/env python3
"""Refresh scientific palettes from https://color.amfe.space into local catalog."""
from __future__ import annotations

import json
import re
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
API = "https://color.amfe.space/api/palettes"
OUTS = [
    ROOT / "assets" / "palettes" / "amfe_color_palettes.json",
    ROOT / "plot_web" / "data" / "amfe_color_palettes.json",
]

DOMAIN_RULES = [
    (r"Nature|Science|Cell|Lancet|BMJ|顶刊", ["sci_journal", "biomedical", "publication"]),
    (r"NeurIPS|IEEE|TPAMI|会议", ["ml_cs", "computer_vision", "publication"]),
    (r"医疗|医学", ["medical", "clinical"]),
    (r"海洋|深蓝|科技蓝|蓝色", ["oceanography", "bioinformatics", "tech"]),
    (r"绿色|森林|自然|生长", ["ecology", "plant", "environment"]),
    (r"灰|单色|工业|专业灰|现代灰", ["grayscale", "heatmap_bw", "minimal"]),
    (r"高对比|对比|多彩|多色|活力", ["categorical", "multi_group", "high_contrast"]),
    (r"柔和|莫兰迪|粉彩|淡雅", ["soft", "pastel", "continuous"]),
    (r"暖|橙|日落|秋|大地", ["warm", "earth", "autumn"]),
    (r"赛博|霓虹|暗夜", ["dark_mode", "cyber", "presentation"]),
    (r"北欧", ["nordic", "minimal", "soft"]),
    (r"数据可视化|企业|商务", ["business", "dashboard", "report"]),
]


def slugify(title: str, sid: int) -> str:
    s = re.sub(r"[^a-zA-Z0-9]+", "-", title).strip("-").lower()
    return f"amfe-{sid}" if not s or len(s) < 2 else f"amfe-{sid}-{s[:40]}"


def infer_domains(p: dict) -> list[str]:
    text = " ".join([p.get("title") or "", p.get("journal") or "", " ".join(p.get("tags") or [])])
    out: list[str] = []
    seen: set[str] = set()
    for pat, ds in DOMAIN_RULES:
        if re.search(pat, text, re.I):
            for d in ds:
                if d not in seen:
                    seen.add(d)
                    out.append(d)
    return out or ["general"]


def main() -> None:
    req = urllib.request.Request(API, headers={"User-Agent": "OmicsCanvas-PaletteFetch/1.0", "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        raw = json.loads(resp.read().decode("utf-8"))
    if not isinstance(raw, list):
        raise SystemExit(f"Unexpected API payload: {type(raw)}")

    palettes = []
    for p in raw:
        colors = [c.upper() if isinstance(c, str) and c.startswith("#") else c for c in (p.get("colors") or [])]
        domains = infer_domains(p)
        palettes.append(
            {
                "id": f"amfe-{p['id']}",
                "source_id": p["id"],
                "name": p.get("title") or f"Palette {p['id']}",
                "slug": slugify(p.get("title") or "", p["id"]),
                "colors": colors,
                "n_colors": len(colors),
                "tags": p.get("tags") or [],
                "likes": int(p.get("likes") or 0),
                "author": p.get("author") or "",
                "journal": p.get("journal") or p.get("title") or "",
                "venue": p.get("venue"),
                "doi": p.get("doi"),
                "paper_title": p.get("paperTitle"),
                "is_user_submitted": bool(p.get("isUserSubmitted")),
                "domains": domains,
                "research_uses": [],
                "source": "https://color.amfe.space",
                "source_url": f"https://color.amfe.space/palette/{p['id']}",
            }
        )
    palettes.sort(key=lambda e: (-(1 if "publication" in e["domains"] else 0), -e["likes"], e["source_id"]))

    # keep previous themes if present
    old_themes = {}
    for out in OUTS:
        if out.is_file():
            try:
                old = json.loads(out.read_text(encoding="utf-8"))
                old_themes = old.get("themes") or {}
                break
            except Exception:
                pass

    catalog = {
        "version": "1.0.0",
        "source": {
            "name": "AMFE Color (顶刊/科研配色)",
            "url": "https://color.amfe.space",
            "api": API,
            "attribution": "Palettes from color.amfe.space for local recommendation.",
            "fetched_at": datetime.now(timezone.utc).isoformat(),
        },
        "count": len(palettes),
        "themes": old_themes,
        "classic_aliases": {"npg": "amfe-110", "lancet": "amfe-106", "aaas": "amfe-101", "jco": "amfe-108"},
        "palettes": palettes,
    }
    text = json.dumps(catalog, ensure_ascii=False, indent=2)
    for out in OUTS:
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(text, encoding="utf-8")
        print("wrote", out, "n=", len(palettes))


if __name__ == "__main__":
    main()
