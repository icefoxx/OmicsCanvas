#!/usr/bin/env python3
"""Fetch discrete palettes from https://github.com/lcpmgh/colors into local JSON.

Source CSV: https://raw.githubusercontent.com/lcpmgh/colors/main/@palettes.csv
License: MIT (lcpmgh/colors). Stored for offline Theme picker + journal recommend.
"""
from __future__ import annotations

import csv
import json
import re
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_URL = "https://raw.githubusercontent.com/lcpmgh/colors/main/@palettes.csv"
OUTS = [
    ROOT / "assets" / "palettes" / "lcpmgh_color_palettes.json",
    ROOT / "plot_web" / "data" / "lcpmgh_color_palettes.json",
]

# Map ggsci / well-known names → journal / family labels for recommend
JOURNAL_HINTS = {
    "pal_npg": ("Nature", "NPG"),
    "pal_lancet": ("Lancet", "Lancet"),
    "pal_nejm": ("NEJM", "NEJM"),
    "pal_jama": ("JAMA", "JAMA"),
    "pal_jco": ("JCO", "JCO"),
    "pal_aaas": ("Science", "AAAS"),
    "pal_bmj": ("BMJ", "BMJ"),
    "pal_frontiers": ("Frontiers", "Frontiers"),
    "pal_cosmic": ("COSMIC", "COSMIC"),
    "pal_locuszoom": ("LocusZoom", "LocusZoom"),
    "pal_uchicago": ("UChicago", "UChicago"),
    "pal_igv": ("IGV", "IGV"),
    "pal_d3": ("D3", "D3"),
    "pal_gsea": ("GSEA", "GSEA"),
    "Okabe-Ito": ("Okabe-Ito", "colorblind"),
}

HEX_RE = re.compile(r"^#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{3})$")


def parse_colors(raw: str) -> list[str]:
    parts = [p.strip() for p in (raw or "").replace('"', "").split(",")]
    out: list[str] = []
    for p in parts:
        if not p:
            continue
        c = p.upper() if p.startswith("#") else p
        # drop OCR garbage like #T3ABCF
        if c.startswith("#") and not HEX_RE.match(c):
            continue
        if c.startswith("#"):
            out.append(c)
    return out


def family_from_source(source: str) -> str:
    s = (source or "").strip()
    if "ggsci" in s:
        return "ggsci"
    if "RColorBrewer" in s:
        return "RColorBrewer"
    if "grDevices" in s:
        return "grDevices"
    if "zhihu" in s.lower():
        return "journal_case"
    return "other"


def classic_key(name: str, family: str) -> str | None:
    n = (name or "").strip()
    if family == "ggsci" and n.startswith("pal_"):
        return n.replace("pal_", "").lower()
    if family == "RColorBrewer":
        return n
    if family == "grDevices":
        return n.replace(" ", "_")
    return None


def build_palette(row: dict[str, str]) -> dict | None:
    try:
        sid = int(row.get("id") or 0)
    except ValueError:
        return None
    source = (row.get("p_sour") or "").strip()
    name = (row.get("p_name") or "nameless").strip()
    colors = parse_colors(row.get("colors") or "")
    if len(colors) < 2:
        return None
    family = family_from_source(source)
    ck = classic_key(name, family)
    journal = ""
    display = name
    if name in JOURNAL_HINTS:
        journal, display = JOURNAL_HINTS[name]
    elif ck and f"pal_{ck}" in JOURNAL_HINTS:
        journal, display = JOURNAL_HINTS[f"pal_{ck}"]
    elif family == "ggsci" and name.startswith("pal_"):
        display = name.replace("pal_", "").upper()
        journal = display
    elif family == "journal_case":
        display = f"Case {sid}"
        journal = "Journal figures (curated)"
    else:
        display = name

    domains = ["categorical", "publication"]
    if family == "ggsci":
        domains += ["sci_journal", "biomedical"]
    if family == "RColorBrewer":
        domains += ["general", "multi_group"]
    if family == "journal_case":
        domains += ["sci_journal", "journal_case"]
    if "okabe" in display.lower() or "ito" in display.lower():
        domains += ["colorblind", "accessible"]

    tags = [family, f"n{len(colors)}"]
    if journal:
        tags.append(journal)
    if ck:
        tags.append(ck)

    return {
        "id": f"lcpmgh-{sid}",
        "source_id": sid,
        "name": display if name == "nameless" else (display if family == "ggsci" else name),
        "raw_name": name,
        "colors": colors,
        "n_colors": len(colors),
        "family": family,
        "classic_key": ck,
        "journal": journal,
        "tags": tags,
        "domains": domains,
        "likes": 50 if family == "ggsci" else (20 if family == "RColorBrewer" else 5),
        "source": "lcpmgh/colors",
        "source_url": "https://github.com/lcpmgh/colors",
        "catalog": "lcpmgh",
    }


def main() -> None:
    req = urllib.request.Request(
        CSV_URL,
        headers={"User-Agent": "OmicsCanvas-PaletteFetch/1.0", "Accept": "text/csv"},
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        text = resp.read().decode("utf-8", errors="replace")

    reader = csv.DictReader(text.splitlines())
    palettes = []
    for row in reader:
        p = build_palette(row)
        if p:
            palettes.append(p)

    payload = {
        "version": "1.0.0",
        "source": {
            "name": "lcpmgh/colors (scientific discrete palettes)",
            "url": "https://github.com/lcpmgh/colors",
            "csv": CSV_URL,
            "license": "MIT",
            "attribution": "Palettes curated in lcpmgh/colors (ggsci, RColorBrewer, journal cases).",
            "fetched_at": datetime.now(timezone.utc).isoformat(),
        },
        "count": len(palettes),
        "palettes": palettes,
    }

    for out in OUTS:
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"Wrote {out} ({len(palettes)} palettes)")


if __name__ == "__main__":
    main()
