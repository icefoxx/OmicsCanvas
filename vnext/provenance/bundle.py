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

from vnext import __version__
from vnext.plotspec.model import dump, dumps

# R packages whose versions are recorded in runtime.json (most plugins use these).
R_PACKAGES = ["ggplot2", "ggrepel", "patchwork", "cowplot", "plotly", "htmlwidgets", "svglite", "ragg",
              "jsonlite", "optparse", "dplyr", "tidyr", "data.table", "fgsea", "vegan", "ComplexHeatmap"]


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with Path(path).open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def plotspec_hash(spec: dict[str, Any]) -> str:
    """Hash of the figure semantics: canonical JSON without volatile provenance fields."""
    payload = json.loads(dumps(spec))
    prov = payload.get("provenance") or {}
    if isinstance(prov, dict):
        for key in ("plotspec_hash", "created_at", "generated_by_ai", "user_modified", "intent_text"):
            prov.pop(key, None)
        payload["provenance"] = prov
    return sha256_text(json.dumps(payload, sort_keys=True, ensure_ascii=False))


def input_format(path: Path) -> str:
    suffix = Path(path).suffix.lower().lstrip(".")
    return suffix if suffix in {"csv", "tsv", "txt", "xlsx", "gmt", "json"} else "unknown"


def describe_inputs(inputs: dict[str, Path]) -> dict[str, dict[str, Any]]:
    """{field: {source_file, checksum, format}} for PlotSpec.inputs."""
    return {
        field: {"source_file": Path(path).name, "checksum": sha256_file(Path(path)), "format": input_format(Path(path))}
        for field, path in inputs.items()
        if Path(path).is_file()
    }


def capture_runtime_versions(r_packages: list[str] | None = None) -> dict[str, Any]:
    versions: dict[str, Any] = {
        "python": sys.version.split()[0],
        "platform": platform.platform(),
        "framework": "omicscanvas-vnext",
        "framework_version": __version__,
        "captured_at": datetime.now(timezone.utc).isoformat(),
    }
    try:
        out = subprocess.check_output(["Rscript", "--version"], stderr=subprocess.STDOUT, text=True, timeout=30)
        versions["R"] = out.strip().splitlines()[0]
    except Exception as exc:
        versions["R"] = f"unavailable: {exc}"
        return versions
    pkgs = r_packages if r_packages is not None else R_PACKAGES
    if pkgs:
        expr = (
            "for (p in c(" + ",".join(json.dumps(p) for p in pkgs) + ")) "
            "cat(p, if (requireNamespace(p, quietly = TRUE)) as.character(utils::packageVersion(p)) else 'not installed', '\\n')"
        )
        try:
            out = subprocess.check_output(["Rscript", "--vanilla", "-e", expr], stderr=subprocess.DEVNULL, text=True, timeout=60)
            versions["R_packages"] = dict(line.split(" ", 1) for line in (l.strip() for l in out.splitlines()) if " " in line)
        except Exception as exc:
            versions["R_packages"] = f"unavailable: {exc}"
    return versions


def methods_text_from_spec(spec: dict[str, Any], validation: dict[str, Any] | None = None) -> str:
    skill = spec.get("skill") or {}
    mapping = {k: v for k, v in (spec.get("mapping") or {}).items() if v not in (None, "", [])}
    transform = spec.get("transform") or {}
    stats = spec.get("statistics") or {}
    visual = spec.get("visual") or {}
    prov = spec.get("provenance") or {}
    lines = [
        f"Figure generated with OmicsCanvas skill `{skill.get('id')}` (version {skill.get('version')}; "
        f"framework {prov.get('framework_version') or __version__}).",
        "Rendering was driven by a validated PlotSpec; no large-language model was invoked after specification validation.",
    ]
    if mapping:
        mapped = ", ".join(f"{k}←{', '.join(v) if isinstance(v, list) else v}" for k, v in mapping.items())
        lines.append(f"Column mapping: {mapped}.")
    resolved = ((validation or {}).get("layers") or {}).get("scientific") or {}
    auto = [i for i in resolved.get("infos") or [] if i.get("code") == "AUTODETECTED_COLUMN"]
    if auto:
        lines.append("Columns selected by the renderer's autodetection: "
                     + "; ".join(i["message"].split(" by the plugin")[0].replace("Role ", "") for i in auto) + ".")
    filters = transform.get("filters") or []
    if filters:
        lines.append("Filters applied: " + "; ".join(f"{f.get('field')} {f.get('op')} {f.get('value')}" for f in filters) + ".")
    if transform.get("top_n"):
        lines.append(f"Top N terms retained: {transform.get('top_n')}.")
    labels = {"method": "Statistical method", "multiple_testing": "Multiple-testing procedure",
              "correlation_method": "Correlation method", "clustering_method": "Hierarchical clustering linkage",
              "distance_method": "Distance metric", "comparisons": "Comparisons"}
    for field, label in labels.items():
        value = stats.get(field)
        if value not in (None, "", []):
            lines.append(f"{label}: {', '.join(map(str, value)) if isinstance(value, list) else value}.")
    if mapping.get("pvalue") and not mapping.get("adjusted_pvalue") and not stats.get("multiple_testing"):
        lines.append("Raw p-values were plotted; adjusted p-values were not mapped.")
    if visual.get("zero_line"):
        lines.append("A reference line at effect = 0 was displayed.")
    if visual.get("stem_to_zero"):
        lines.append("Lollipop stems were drawn to zero.")
    if prov.get("seed") is not None:
        lines.append(f"Random number generator seed: {prov['seed']} (label placement, jitter and permutations are reproducible).")
    return "\n".join(lines) + "\n"


def write_reproduction_bundle(
    *,
    bundle_dir: Path,
    spec: dict[str, Any],
    input_file: Path | None = None,
    inputs: dict[str, Path] | None = None,
    params: dict[str, Any] | None = None,
    figure_files: dict[str, Path] | None = None,
    validation: dict[str, Any] | None = None,
    runtime: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Create an auditable reproduction bundle directory.

    Layout: plotspec.json, params.json, input/<field>__<file>, figures/, methods.txt,
    runtime.json, validation.json, manifest.json (sha256 of every file), REPRODUCE.md.
    """
    bundle_dir = Path(bundle_dir)
    (bundle_dir / "figures").mkdir(parents=True, exist_ok=True)
    (bundle_dir / "input").mkdir(exist_ok=True)

    files = {k: Path(v) for k, v in (inputs or {}).items()}
    if input_file is not None:
        files.setdefault("input", Path(input_file))

    spec = json.loads(json.dumps(spec))
    described = describe_inputs(files)
    spec["inputs"] = described
    main_field = "input" if "input" in described else next(iter(described), None)
    if main_field:
        spec["input"] = dict(described[main_field])
    prov = dict(spec.get("provenance") or {})
    prov["framework_version"] = __version__
    spec["provenance"] = prov
    p_hash = plotspec_hash(spec)
    prov.update({"plotspec_hash": p_hash, "created_at": datetime.now(timezone.utc).isoformat()})

    dump(spec, bundle_dir / "plotspec.json")
    if params is not None:
        (bundle_dir / "params.json").write_text(json.dumps(params, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    copied_inputs = {}
    for field, path in files.items():
        if path.is_file():
            dest = bundle_dir / "input" / f"{field}__{path.name}"
            shutil.copy2(path, dest)
            copied_inputs[field] = str(dest.relative_to(bundle_dir))
    (bundle_dir / "methods.txt").write_text(methods_text_from_spec(spec, validation), encoding="utf-8")
    (bundle_dir / "runtime.json").write_text(json.dumps(runtime or capture_runtime_versions(), indent=2) + "\n", encoding="utf-8")
    if validation is not None:
        (bundle_dir / "validation.json").write_text(json.dumps(validation, indent=2, default=str) + "\n", encoding="utf-8")

    copied_figs = {}
    for label, fpath in (figure_files or {}).items():
        if fpath and Path(fpath).exists():
            dest = bundle_dir / "figures" / Path(fpath).name
            shutil.copy2(fpath, dest)
            copied_figs[label] = str(dest.relative_to(bundle_dir))

    (bundle_dir / "REPRODUCE.md").write_text(
        "# Reproduce this figure\n\n"
        "From the OmicsCanvas repository root:\n\n"
        "```bash\n"
        f"python3 -m vnext.cli reproduce --bundle-dir {bundle_dir.name} --output /tmp/omics_repro --compare\n"
        "```\n\n"
        "`--compare` re-renders from `plotspec.json` + `input/` only and checks the new figure against `figures/`.\n\n"
        f"PlotSpec hash: `{p_hash}`\n\n"
        + "".join(f"Input `{f}` SHA256: `{d['checksum']}`\n\n" for f, d in described.items()),
        encoding="utf-8",
    )

    checksums = {
        str(p.relative_to(bundle_dir)): sha256_file(p)
        for p in sorted(bundle_dir.rglob("*"))
        if p.is_file() and p.name != "manifest.json"
    }
    manifest = {
        "bundle_version": "2",
        "plotspec": "plotspec.json",
        "plotspec_hash": p_hash,
        "params": "params.json" if params is not None else None,
        "inputs": copied_inputs,
        "input": copied_inputs.get(main_field) if main_field else None,
        "input_checksum": described[main_field]["checksum"] if main_field else None,
        "methods": "methods.txt",
        "runtime": "runtime.json",
        "validation": "validation.json" if validation is not None else None,
        "figures": copied_figs,
        "sha256": checksums,
    }
    (bundle_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest
