#!/usr/bin/env python3
"""Merge builtin + AMFE + lcpmgh palettes into the unified Theme catalog used by plot_web."""
from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AMFE_PATHS = [
    ROOT / "plot_web" / "data" / "amfe_color_palettes.json",
    ROOT / "assets" / "palettes" / "amfe_color_palettes.json",
]
LCPMGH_PATHS = [
    ROOT / "plot_web" / "data" / "lcpmgh_color_palettes.json",
    ROOT / "assets" / "palettes" / "lcpmgh_color_palettes.json",
]
OUTS = [
    ROOT / "plot_web" / "data" / "unified_color_palettes.json",
    ROOT / "assets" / "palettes" / "unified_color_palettes.json",
]

# Classic ggsci-style built-ins (always available even offline / before fetch)
BUILTIN = [
    {
        "id": "builtin-npg",
        "name": "NPG",
        "classic_key": "npg",
        "colors": ["#E64B35", "#4DBBD5", "#00A087", "#3C5488", "#F39B7F", "#8491B4", "#91D1C2", "#DC0000", "#7E6148", "#B09C85"],
        "journal": "Nature",
        "family": "ggsci",
        "tags": ["classic", "npg", "Nature", "journal"],
        "domains": ["sci_journal", "biomedical", "publication", "categorical"],
        "likes": 500,
        "catalog": "builtin",
        "source": "builtin",
    },
    {
        "id": "builtin-aaas",
        "name": "AAAS / Science",
        "classic_key": "aaas",
        "colors": ["#3B4992", "#EE0000", "#008B45", "#631879", "#008280", "#BB0021", "#5F559B", "#A20056", "#808180", "#1B1919"],
        "journal": "Science",
        "family": "ggsci",
        "tags": ["classic", "aaas", "Science", "journal"],
        "domains": ["sci_journal", "biomedical", "publication", "categorical"],
        "likes": 480,
        "catalog": "builtin",
        "source": "builtin",
    },
    {
        "id": "builtin-nejm",
        "name": "NEJM",
        "classic_key": "nejm",
        "colors": ["#BC3C29", "#0072B5", "#E18727", "#20854E", "#7876B1", "#6F99AD", "#FFDC91", "#EE4C97"],
        "journal": "NEJM",
        "family": "ggsci",
        "tags": ["classic", "nejm", "NEJM", "journal", "medical"],
        "domains": ["sci_journal", "medical", "clinical", "publication", "categorical"],
        "likes": 470,
        "catalog": "builtin",
        "source": "builtin",
    },
    {
        "id": "builtin-lancet",
        "name": "Lancet",
        "classic_key": "lancet",
        "colors": ["#00468B", "#ED0000", "#42B540", "#0099B4", "#925E9F", "#FDAF91", "#AD002A", "#ADB6B6", "#1B1919"],
        "journal": "Lancet",
        "family": "ggsci",
        "tags": ["classic", "lancet", "Lancet", "journal", "medical"],
        "domains": ["sci_journal", "medical", "clinical", "publication", "categorical"],
        "likes": 460,
        "catalog": "builtin",
        "source": "builtin",
    },
    {
        "id": "builtin-jama",
        "name": "JAMA",
        "classic_key": "jama",
        "colors": ["#374E55", "#DF8F44", "#00A1D5", "#B24745", "#79AF97", "#6A6599", "#80796B"],
        "journal": "JAMA",
        "family": "ggsci",
        "tags": ["classic", "jama", "JAMA", "journal", "medical"],
        "domains": ["sci_journal", "medical", "clinical", "publication", "categorical"],
        "likes": 450,
        "catalog": "builtin",
        "source": "builtin",
    },
    {
        "id": "builtin-jco",
        "name": "JCO",
        "classic_key": "jco",
        "colors": ["#0073C2", "#EFC000", "#868686", "#CD534C", "#7AA6DC", "#003C67", "#8F7700", "#3B3B3B", "#A73030", "#4A6990"],
        "journal": "JCO",
        "family": "ggsci",
        "tags": ["classic", "jco", "JCO", "journal", "oncology"],
        "domains": ["sci_journal", "medical", "clinical", "publication", "categorical"],
        "likes": 440,
        "catalog": "builtin",
        "source": "builtin",
    },
    {
        "id": "builtin-okabe-ito",
        "name": "Okabe-Ito (colorblind-safe)",
        "classic_key": "Okabe-Ito",
        "colors": ["#000000", "#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7"],
        "journal": "Okabe-Ito",
        "family": "accessible",
        "tags": ["classic", "colorblind", "accessible", "Okabe-Ito"],
        "domains": ["colorblind", "accessible", "publication", "categorical"],
        "likes": 430,
        "catalog": "builtin",
        "source": "builtin",
    },
    {
        "id": "builtin-set2",
        "name": "Set2",
        "classic_key": "Set2",
        "colors": ["#66C2A5", "#FC8D62", "#8DA0CB", "#E78AC3", "#A6D854", "#FFD92F", "#E5C494", "#B3B3B3"],
        "journal": "",
        "family": "RColorBrewer",
        "tags": ["classic", "Set2", "soft"],
        "domains": ["soft", "pastel", "categorical", "general"],
        "likes": 200,
        "catalog": "builtin",
        "source": "builtin",
    },
    {
        "id": "builtin-paired",
        "name": "Paired",
        "classic_key": "Paired",
        "colors": ["#A6CEE3", "#1F78B4", "#B2DF8A", "#33A02C", "#FB9A99", "#E31A1C", "#FDBF6F", "#FF7F00", "#CAB2D6", "#6A3D9A", "#FFFF99", "#B15928"],
        "journal": "",
        "family": "RColorBrewer",
        "tags": ["classic", "Paired", "multi_group"],
        "domains": ["categorical", "multi_group", "high_contrast", "general"],
        "likes": 210,
        "catalog": "builtin",
        "source": "builtin",
    },
    {
        "id": "builtin-viridis",
        "name": "Viridis",
        "classic_key": "viridis",
        "colors": ["#440154", "#482677", "#3E4989", "#31688E", "#26828E", "#1F9E89", "#35B779", "#6ECE58", "#B5DE2B", "#FDE725"],
        "journal": "",
        "family": "continuous",
        "tags": ["classic", "viridis", "continuous", "gradient"],
        "domains": ["continuous", "heatmap", "gradient"],
        "likes": 400,
        "catalog": "builtin",
        "source": "builtin",
    },
    {
        "id": "builtin-plasma",
        "name": "Plasma",
        "classic_key": "plasma",
        "colors": ["#0D0887", "#46039F", "#7201A8", "#9C179E", "#BD3786", "#D8576B", "#ED7953", "#FB9F3A", "#FDCA26", "#F0F921"],
        "journal": "",
        "family": "continuous",
        "tags": ["classic", "plasma", "continuous", "gradient"],
        "domains": ["continuous", "heatmap", "gradient"],
        "likes": 380,
        "catalog": "builtin",
        "source": "builtin",
    },
    {
        "id": "builtin-spectral",
        "name": "Spectral",
        "classic_key": "Spectral",
        "colors": ["#9E0142", "#D53E4F", "#F46D43", "#FDAE61", "#FEE08B", "#E6F598", "#ABDDA4", "#66C2A5", "#3288BD", "#5E4FA2"],
        "journal": "",
        "family": "continuous",
        "tags": ["classic", "Spectral", "diverging"],
        "domains": ["continuous", "diverging", "heatmap"],
        "likes": 300,
        "catalog": "builtin",
        "source": "builtin",
    },
]


def load_json(paths: list[Path]) -> dict:
    for p in paths:
        if p.is_file():
            return json.loads(p.read_text(encoding="utf-8"))
    return {}


def normalize(p: dict, catalog: str) -> dict:
    colors = p.get("colors") or []
    out = {
        "id": p.get("id"),
        "name": p.get("name") or p.get("id"),
        "colors": colors,
        "n_colors": int(p.get("n_colors") or len(colors)),
        "family": p.get("family") or ("amfe" if catalog == "amfe" else catalog),
        "classic_key": p.get("classic_key"),
        "journal": p.get("journal") or "",
        "tags": list(p.get("tags") or []),
        "domains": list(p.get("domains") or []),
        "likes": int(p.get("likes") or 0),
        "catalog": catalog,
        "source": p.get("source") or catalog,
        "source_url": p.get("source_url"),
        "raw_name": p.get("raw_name") or p.get("name"),
    }
    if p.get("research_uses"):
        out["research_uses"] = p["research_uses"]
    return out


def main() -> None:
    amfe = load_json(AMFE_PATHS)
    lcpmgh = load_json(LCPMGH_PATHS)

    merged: list[dict] = []
    seen: set[str] = set()

    for p in BUILTIN:
        item = normalize(p, "builtin")
        item["n_colors"] = len(item["colors"])
        merged.append(item)
        seen.add(item["id"])

    for p in amfe.get("palettes") or []:
        item = normalize(p, "amfe")
        if not item["id"] or item["id"] in seen:
            continue
        if not item["colors"]:
            continue
        # AMFE often has journal in name
        if not item["journal"] and p.get("journal"):
            item["journal"] = p["journal"]
        merged.append(item)
        seen.add(item["id"])

    for p in lcpmgh.get("palettes") or []:
        item = normalize(p, "lcpmgh")
        if not item["id"] or item["id"] in seen:
            continue
        # skip exact classic_key duplicates of builtin ggsci
        ck = (item.get("classic_key") or "").lower()
        if item.get("family") == "ggsci" and ck in {
            "npg", "aaas", "nejm", "lancet", "jama", "jco"
        }:
            # keep as lcpmgh variant only if different id — still useful under ggsci filter
            pass
        if not item["colors"]:
            continue
        merged.append(item)
        seen.add(item["id"])

    # Themes: keep AMFE themes + journal shortcuts
    themes = dict(amfe.get("themes") or {})
    classic_aliases = dict(amfe.get("classic_aliases") or {})
    for p in BUILTIN:
        if p.get("classic_key"):
            classic_aliases[str(p["classic_key"]).lower()] = p["id"]

    # Journal recommend groups
    journal_groups: dict[str, list[str]] = {}
    for p in merged:
        j = (p.get("journal") or "").strip()
        if not j:
            continue
        journal_groups.setdefault(j, []).append(p["id"])

    # Seed journal themes for top journals
    for jname, ids in journal_groups.items():
        key = re_slug(jname)
        if key in themes:
            # prepend journal ids
            existing = themes[key].get("recommend_ids") or []
            themes[key]["recommend_ids"] = list(dict.fromkeys(ids[:8] + existing))[:12]
            continue
        themes[key] = {
            "label": f"{jname} journal palette",
            "keywords": [jname.lower(), key.replace("_", " ")],
            "recommend_ids": ids[:10],
            "keywords_match_extra": [],
        }

    payload = {
        "version": "2.0.0",
        "built_at": datetime.now(timezone.utc).isoformat(),
        "sources": {
            "builtin": {"count": sum(1 for p in merged if p["catalog"] == "builtin")},
            "amfe": {
                "count": sum(1 for p in merged if p["catalog"] == "amfe"),
                "url": "https://color.amfe.space",
            },
            "lcpmgh": {
                "count": sum(1 for p in merged if p["catalog"] == "lcpmgh"),
                "url": "https://github.com/lcpmgh/colors",
                "license": "MIT",
            },
        },
        "count": len(merged),
        "themes": themes,
        "classic_aliases": classic_aliases,
        "journals": sorted(journal_groups.keys(), key=str.lower),
        "journal_groups": journal_groups,
        "palettes": merged,
    }

    for out in OUTS:
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"Wrote {out} ({len(merged)} palettes, {len(journal_groups)} journals)")


def re_slug(s: str) -> str:
    import re

    return re.sub(r"[^a-z0-9]+", "_", s.lower()).strip("_") or "journal"


if __name__ == "__main__":
    main()
