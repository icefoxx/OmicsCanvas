"""Adapter: validated PlotSpec → existing R plugin params.json + Rscript run."""
from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
PLUGIN_DIR = ROOT / "plugins"

# Semantic role → common legacy param keys for enrichment lollipop
ENRICHMENT_LOLLIPOP_MAP = {
    "category": "category_column",
    "term": "category_column",
    "signed_effect": "value_column",
    "effect": "value_column",
    "group": "group_column",
    "size": "size_column",
    "gene_count": "size_column",
    "pvalue": "pvalue_column",
    "adjusted_pvalue": "padj_column",
    "significance": "group_column",
}


def plotspec_to_legacy_params(spec: dict[str, Any]) -> dict[str, Any]:
    """Convert PlotSpec into flat params.json for current R plugins.

    Does not invent scientific choices: only maps explicit fields + legacy_params.
    """
    params: dict[str, Any] = {}
    legacy = spec.get("legacy_params") or {}
    if isinstance(legacy, dict):
        params.update(legacy)

    skill_id = (spec.get("skill") or {}).get("id") or ""
    mapping = spec.get("mapping") or {}
    visual = spec.get("visual") or {}
    export = spec.get("export") or {}
    transform = spec.get("transform") or {}

    if skill_id == "interactive_enrichment_lollipop":
        for role, col in mapping.items():
            if not col:
                continue
            key = ENRICHMENT_LOLLIPOP_MAP.get(role)
            if key:
                params[key] = col
        if visual.get("title") is not None:
            params["title"] = visual.get("title")
        if visual.get("subtitle") is not None:
            params["subtitle"] = visual.get("subtitle")
        if visual.get("xlab") is not None:
            params["xlab"] = visual.get("xlab")
        if visual.get("ylab") is not None:
            params["ylab"] = visual.get("ylab")
        if "zero_line" in visual:
            params["zero_line_show"] = bool(visual["zero_line"])
        if "stem_to_zero" in visual:
            params["stem_show"] = bool(visual["stem_to_zero"])
        if "legend_show" in visual:
            params["legend_show"] = bool(visual["legend_show"])
        if "interactive" in visual:
            params["interactive"] = bool(visual["interactive"])
        if "palette_id" in visual and visual["palette_id"]:
            params["palette"] = visual["palette_id"]
        ranking = transform.get("ranking") or {}
        if ranking.get("field"):
            # map ranking field name if it matches value semantics
            params.setdefault("sort_by", "value")
            method = ranking.get("method") or "desc"
            params["sort"] = "ascending" if method in {"asc", "abs_asc"} else "descending"
        if transform.get("top_n"):
            params["top_n"] = transform["top_n"]
        if transform.get("preserve_order"):
            params["sort"] = "none"

    # export geometry: prefer inches if provided else convert mm
    if export.get("width_in") is not None:
        params["width"] = export["width_in"]
    elif export.get("width_mm") is not None:
        params["width"] = float(export["width_mm"]) / 25.4
    if export.get("height_in") is not None:
        params["height"] = export["height_in"]
    elif export.get("height_mm") is not None:
        params["height"] = float(export["height_mm"]) / 25.4
    if export.get("dpi") is not None:
        params["dpi"] = export["dpi"]

    params["plugin_id"] = skill_id
    return params


def run_legacy_plugin(
    *,
    skill_id: str,
    input_path: Path,
    params: dict[str, Any],
    output_dir: Path,
    timeout: int = 600,
) -> dict[str, Any]:
    plugin = PLUGIN_DIR / skill_id
    entry = plugin / "plot.R"
    if not entry.exists():
        raise FileNotFoundError(f"Missing renderer: {entry}")
    output_dir = Path(output_dir).resolve()
    input_path = Path(input_path).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    params_path = output_dir / "params.json"
    params_path.write_text(json.dumps(params, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    # copy input next to output for provenance convenience
    input_copy = output_dir / input_path.name
    if input_path != input_copy:
        shutil.copy2(input_path, input_copy)

    cmd = [
        "Rscript",
        str(entry.resolve()),
        "--input",
        str(input_path),
        "--params",
        str(params_path),
        "--output",
        str(output_dir),
    ]
    proc = subprocess.run(
        cmd,
        cwd=str(ROOT),  # repo root so relative paths in specs also resolve if needed
        capture_output=True,
        text=True,
        timeout=timeout,
    )
    (output_dir / "adapter_stdout.log").write_text(proc.stdout or "", encoding="utf-8")
    (output_dir / "adapter_stderr.log").write_text(proc.stderr or "", encoding="utf-8")
    figures = {}
    for name, key in [
        ("result.svg", "svg"),
        ("result.pdf", "pdf"),
        ("result.png", "png"),
        ("result.html", "html"),
        ("figure.json", "figure_json"),
        ("run.log", "log"),
    ]:
        p = output_dir / name
        if p.exists():
            figures[key] = p
    return {
        "returncode": proc.returncode,
        "ok": proc.returncode == 0 and "svg" in figures,
        "command": cmd,
        "figures": {k: str(v) for k, v in figures.items()},
        "figure_paths": figures,
        "params_path": str(params_path),
    }
