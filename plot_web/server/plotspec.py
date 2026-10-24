"""PlotSpec + scientific validation for every plot_web job, and reproduction bundles.

Before a plugin runs, its flat params.json is lifted into a PlotSpec (vnext
adapter), validated against the uploaded tables, and written next to the
results as plotspec.json / validation.json. PLOT_VALIDATION_MODE controls what
a failed validation does:

  warn     (default) render anyway; issues are returned with the job
  enforce  do not render when there are scientific errors
  off      skip PlotSpec/validation entirely

Any failure inside this layer is recorded on the job and never blocks rendering.
"""
from __future__ import annotations

import json
import os
import shutil
from pathlib import Path
from typing import Any

from plot_web.server.settings import JOBS_DIR

VALIDATION_MODE = os.environ.get("PLOT_VALIDATION_MODE", "warn").lower()
MAX_ISSUES = 20


def _summary(validation: dict[str, Any], spec_hash: str) -> dict[str, Any]:
    def trim(items: list[dict[str, Any]]) -> list[dict[str, Any]]:
        return [{k: i.get(k) for k in ("code", "field", "message", "severity")} for i in items[:MAX_ISSUES]]

    return {
        "plotspec_hash": spec_hash,
        "valid": bool(validation.get("valid")),
        "mode": VALIDATION_MODE,
        "errors": trim(validation.get("errors") or []),
        "warnings": trim(validation.get("warnings") or []),
        "infos": trim(validation.get("infos") or []),
    }


def prepare_job_plotspec(job: dict[str, Any], params: dict[str, Any], output_dir: Path, seed: int) -> dict[str, Any] | None:
    """Build + validate the job's PlotSpec; write plotspec.json/validation.json. Returns the job summary."""
    if VALIDATION_MODE == "off":
        return None
    try:
        from vnext.adapters.legacy_r import legacy_params_to_plotspec, load_skill_metadata
        from vnext.provenance.bundle import describe_inputs, plotspec_hash
        from vnext.validate.pipeline import validate_plotspec

        plugin_id = str(job.get("plugin_id") or "")
        meta = load_skill_metadata(plugin_id)
        if not meta:
            return None
        inputs = {k: Path(v) for k, v in (job.get("uploaded_files") or {}).items()}
        spec = legacy_params_to_plotspec(plugin_id, params, meta=meta, inputs=describe_inputs(inputs), seed=seed)
        spec["provenance"]["engine"] = "legacy_r"
        validation = validate_plotspec(spec, tables=inputs)
        spec_hash = plotspec_hash(spec)
        spec["provenance"]["plotspec_hash"] = spec_hash
        output_dir.mkdir(parents=True, exist_ok=True)
        (output_dir / "plotspec.json").write_text(json.dumps(spec, indent=2, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")
        (output_dir / "validation.json").write_text(json.dumps(validation, indent=2, ensure_ascii=False, default=str) + "\n", encoding="utf-8")
        summary = _summary(validation, spec_hash)
    except Exception as exc:  # never block rendering on the provenance layer
        summary = {"valid": None, "mode": VALIDATION_MODE, "error": f"{type(exc).__name__}: {exc}"}
    job["vnext"] = summary
    return summary


def blocks_render(summary: dict[str, Any] | None) -> bool:
    return VALIDATION_MODE == "enforce" and bool(summary) and summary.get("valid") is False


def build_bundle_zip(job: dict[str, Any]) -> Path:
    """Reproduction bundle for a finished job, zipped (cached next to the job)."""
    from vnext.provenance.bundle import write_reproduction_bundle

    output_dir = Path(job["output_dir"])
    spec_path = output_dir / "plotspec.json"
    if not spec_path.exists():
        raise FileNotFoundError("This figure has no PlotSpec (skill not migrated or validation disabled).")
    job_dir = JOBS_DIR / job["job_id"]
    zip_path = job_dir / "reproduction_bundle.zip"
    if zip_path.exists() and zip_path.stat().st_mtime >= spec_path.stat().st_mtime:
        return zip_path

    staging = job_dir / "reproduction_bundle"
    shutil.rmtree(staging, ignore_errors=True)
    params_path = Path(str(job.get("params_path") or ""))
    validation_path = output_dir / "validation.json"
    figures = {k: output_dir / name for k, name in (("svg", "result.svg"), ("pdf", "result.pdf"), ("png", "result.png"),
                                                     ("html", "result.html"), ("figure_json", "figure.json"), ("log", "run.log"))}
    write_reproduction_bundle(
        bundle_dir=staging,
        spec=json.loads(spec_path.read_text(encoding="utf-8")),
        inputs={k: Path(v) for k, v in (job.get("uploaded_files") or {}).items()},
        params=json.loads(params_path.read_text(encoding="utf-8")) if params_path.exists() else None,
        figure_files={k: p for k, p in figures.items() if p.exists()},
        validation=json.loads(validation_path.read_text(encoding="utf-8")) if validation_path.exists() else None,
    )
    archive = shutil.make_archive(str(zip_path.with_suffix("")), "zip", root_dir=staging.parent, base_dir=staging.name)
    shutil.rmtree(staging, ignore_errors=True)
    return Path(archive)
