"""Provenance hashing + reproduction bundle."""
from __future__ import annotations

import hashlib
import json
import platform
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from vnext.plotspec.model import dump, dumps


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def plotspec_hash(spec: dict[str, Any]) -> str:
    # Hash canonical JSON without volatile provenance.hash field
    payload = json.loads(dumps(spec))
    prov = payload.get("provenance") or {}
    if isinstance(prov, dict):
        prov.pop("plotspec_hash", None)
        prov.pop("created_at", None)
        payload["provenance"] = prov
    return sha256_text(json.dumps(payload, sort_keys=True, ensure_ascii=False))


def capture_runtime_versions() -> dict[str, Any]:
    versions: dict[str, Any] = {
        "python": sys.version.split()[0],
        "platform": platform.platform(),
        "framework": "omicscanvas-vnext",
        "framework_version": "0.1.0",
        "captured_at": datetime.now(timezone.utc).isoformat(),
    }
    try:
        out = subprocess.check_output(["Rscript", "--version"], stderr=subprocess.STDOUT, text=True)
        versions["R"] = out.strip().splitlines()[0]
    except Exception as exc:
        versions["R"] = f"unavailable: {exc}"
    return versions


def methods_text_from_spec(spec: dict[str, Any]) -> str:
    skill = spec.get("skill") or {}
    mapping = spec.get("mapping") or {}
    transform = spec.get("transform") or {}
    stats = spec.get("statistics") or {}
    visual = spec.get("visual") or {}
    lines = [
        f"Figure generated with OmicsCanvas skill `{skill.get('id')}` (version {skill.get('version')}).",
        "Rendering was driven by a validated PlotSpec; no large-language model was invoked after specification validation.",
    ]
    if mapping:
        mapped = ", ".join(f"{k}←{v}" for k, v in mapping.items() if v)
        lines.append(f"Column mapping: {mapped}.")
    filters = transform.get("filters") or []
    if filters:
        desc = "; ".join(f"{f.get('field')} {f.get('op')} {f.get('value')}" for f in filters)
        lines.append(f"Filters applied: {desc}.")
    if transform.get("top_n"):
        lines.append(f"Top N terms retained: {transform.get('top_n')}.")
    if stats.get("multiple_testing"):
        lines.append(f"Multiple-testing procedure recorded as: {stats.get('multiple_testing')}.")
    elif mapping.get("pvalue") and not mapping.get("adjusted_pvalue"):
        lines.append("Raw p-values were plotted; adjusted p-values were not mapped.")
    if visual.get("zero_line"):
        lines.append("A reference line at effect = 0 was displayed.")
    if visual.get("stem_to_zero"):
        lines.append("Lollipop stems were drawn to zero.")
    return "\n".join(lines) + "\n"


def write_reproduction_bundle(
    *,
    bundle_dir: Path,
    spec: dict[str, Any],
    input_file: Path,
    figure_files: dict[str, Path] | None = None,
    validation: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Create an auditable reproduction bundle directory."""
    bundle_dir = Path(bundle_dir)
    bundle_dir.mkdir(parents=True, exist_ok=True)
    (bundle_dir / "figures").mkdir(exist_ok=True)
    (bundle_dir / "input").mkdir(exist_ok=True)

    spec = dict(spec)
    prov = dict(spec.get("provenance") or {})
    checksum = sha256_file(input_file)
    p_hash = plotspec_hash(spec)
    prov.update(
        {
            "plotspec_hash": p_hash,
            "created_at": datetime.now(timezone.utc).isoformat(),
            "framework_version": "0.1.0",
        }
    )
    spec["provenance"] = prov
    inp = dict(spec.get("input") or {})
    inp["source_file"] = input_file.name
    inp["checksum"] = checksum
    spec["input"] = inp

    dump(spec, bundle_dir / "plotspec.json")
    shutil.copy2(input_file, bundle_dir / "input" / input_file.name)
    (bundle_dir / "methods.txt").write_text(methods_text_from_spec(spec), encoding="utf-8")
    runtime = capture_runtime_versions()
    (bundle_dir / "runtime.json").write_text(json.dumps(runtime, indent=2) + "\n", encoding="utf-8")
    if validation is not None:
        (bundle_dir / "validation.json").write_text(json.dumps(validation, indent=2) + "\n", encoding="utf-8")

    copied_figs = {}
    for label, fpath in (figure_files or {}).items():
        if fpath and Path(fpath).exists():
            dest = bundle_dir / "figures" / Path(fpath).name
            shutil.copy2(fpath, dest)
            copied_figs[label] = str(dest.relative_to(bundle_dir))

    reproduce_sh = f"""#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")"/../.. && pwd)"
python3 -m vnext.cli reproduce --bundle "$(cd "$(dirname "$0")" && pwd)" --repo "$ROOT"
"""
    # Prefer calling adapter from repo root; also write a self-contained note
    (bundle_dir / "REPRODUCE.md").write_text(
        "# Reproduce this figure\n\n"
        "From the OmicsCanvas repository root:\n\n"
        "```bash\n"
        f"python3 -m vnext.cli reproduce --spec {bundle_dir.name}/plotspec.json "
        f"--input {bundle_dir.name}/input/{input_file.name} --output /tmp/omics_repro\n"
        "```\n\n"
        f"PlotSpec hash: `{p_hash}`\n"
        f"Input SHA256: `{checksum}`\n",
        encoding="utf-8",
    )

    manifest = {
        "plotspec": "plotspec.json",
        "plotspec_hash": p_hash,
        "input_checksum": checksum,
        "input": f"input/{input_file.name}",
        "methods": "methods.txt",
        "runtime": "runtime.json",
        "validation": "validation.json" if validation is not None else None,
        "figures": copied_figs,
    }
    (bundle_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest
