"""Build plugin command lines and run them as local subprocess jobs."""
from __future__ import annotations

import json
import os
import subprocess
import time
from pathlib import Path
from typing import Any

from fastapi import HTTPException

from plot_web.server import render_cache
from plot_web.server.plotspec import blocks_render, prepare_job_plotspec
from plot_web.server.plugins import infer_language, plugin_path
from plot_web.server.settings import MAX_LOCAL_SECONDS, ROOT_DIR
from plot_web.server.storage import (
    output_urls_for_dir,
    record_job_in_state,
    save_job,
    utc_now,
)


def declared_inputs(config: dict[str, Any]) -> list[dict[str, Any]]:
    inputs = config.get("inputs")
    return [item for item in inputs if isinstance(item, dict) and item.get("id")] if isinstance(inputs, list) else []


def choose_main_input(saved_files: dict[str, Path], config: dict[str, Any] | None = None) -> Path:
    for key in ("file", "input", "upper"):
        if key in saved_files:
            return saved_files[key]
    # The first required input declared in config.yaml (e.g. ``signal``).
    for item in declared_inputs(config or {}):
        if item.get("required") and str(item["id"]) in saved_files:
            return saved_files[str(item["id"])]
    # Prefer ranked-gene tables over expression matrices when the main
    # field was not bound (common for multi-input GSEA plugins).
    for path in saved_files.values():
        name = path.name.lower()
        if "rank" in name or name in {"example_input.csv", "example_markers.csv"}:
            return path
    if saved_files:
        return next(iter(saved_files.values()))
    raise HTTPException(status_code=400, detail="No input file uploaded")


# Legacy field -> CLI flag aliases for plugins whose config.yaml does not
# declare ``inputs[].flag``. New plugins should declare the flag instead.
LEGACY_INPUT_FLAGS = {
    "input2": "--input2",
    "annot": "--annot",
    "annotation": "--annot",
    "expr": "--expr",
    "expression": "--expr",
    "genesets": "--genesets",
    "embed": "--embed",
    "embedding": "--embed",
    "lineages": "--lineages",
    "lineage": "--lineages",
    "col_annot": "--col-annot",
    "row_annot": "--row-annot",
    "col-annot": "--col-annot",
    "row-annot": "--row-annot",
    "panel-groups": "--panel-groups",
    "panel_groups": "--panel-groups",
    "marks": "--marks",
    "nodes": "--nodes",
    "matrix": "--matrix",
    "comparisons": "--comparisons",
    "enrichment": "--enrichment",
    "regions": "--regions",
    "upper": "--upper",
    "lower": "--lower",
    "mantel": "--mantel",
    "community": "--input2",
    "envpoints": "--envpoints",
    "specpoints": "--specpoints",
}


MAIN_INPUT_FIELDS = {"file", "input"}


def input_flags(config: dict[str, Any]) -> dict[str, str]:
    """Upload field -> CLI flag. Precedence: inputs[].flag > legacy alias > ``--<id>``."""
    flags = dict(LEGACY_INPUT_FLAGS)
    for item in declared_inputs(config):
        field = str(item["id"])
        if field in MAIN_INPUT_FIELDS:
            continue
        flag = item.get("flag")
        if flag:
            flags[field] = str(flag)
        elif field not in flags:
            flags[field] = f"--{field}"
    return flags


def build_command(plugin_id: str, config: dict[str, Any], saved_files: dict[str, Path], params_path: Path, output_dir: Path) -> list[str]:
    path = plugin_path(plugin_id)
    entrypoint = config.get("entrypoint") or "plot.R"
    language = infer_language(config)
    if language.lower() == "python":
        cmd = ["python3", str(path / entrypoint)]
    else:
        cmd = ["Rscript", str(path / entrypoint)]

    cmd.extend(["--input", str(choose_main_input(saved_files, config)), "--params", str(params_path), "--output", str(output_dir)])
    for key, flag in input_flags(config).items():
        if key in saved_files:
            cmd.extend([flag, str(saved_files[key])])
    return cmd


DEFAULT_SEED = 42
RPROFILE_PATH = ROOT_DIR / "R" / "runtime" / "omicscanvas.Rprofile"


def run_seed(params: dict[str, Any] | None) -> int:
    try:
        return int((params or {}).get("seed", DEFAULT_SEED))
    except (TypeError, ValueError):
        return DEFAULT_SEED


def plugin_env(seed: int = DEFAULT_SEED) -> dict[str, str]:
    """Subprocess environment: seeded RNG via the shared Rprofile, user profile preserved."""
    env = dict(os.environ)
    if "OMICSCANVAS_USER_RPROFILE" not in env and env.get("R_PROFILE_USER"):
        env["OMICSCANVAS_USER_RPROFILE"] = env["R_PROFILE_USER"]
    env["R_PROFILE_USER"] = str(RPROFILE_PATH)
    env["OMICSCANVAS_SEED"] = str(seed)
    return env


def _job_params(job: dict[str, Any]) -> dict[str, Any]:
    try:
        data = json.loads(Path(str(job.get("params_path") or "")).read_text(encoding="utf-8"))
    except Exception:
        return {}
    return data if isinstance(data, dict) else {}


def run_local_job(job: dict[str, Any], cmd: list[str], plugin_dir: Path, output_dir: Path) -> dict[str, Any]:
    started = time.perf_counter()
    output_dir.mkdir(parents=True, exist_ok=True)
    job["status"] = "running"
    job["message"] = "Plugin is running locally."
    job["started_at"] = utc_now()
    job["command"] = cmd
    params = _job_params(job)
    job["seed"] = run_seed(params)
    summary = prepare_job_plotspec(job, params, output_dir, job["seed"])
    if blocks_render(summary):
        error = {
            "error": "Scientific validation failed",
            "detail": "; ".join(f"{e['code']}: {e['message']}" for e in summary["errors"]),
            "suggestion": "Fix the mapped columns/statistics, or run with PLOT_VALIDATION_MODE=warn.",
        }
        job.update({"status": "failed", "finished_at": utc_now(), "error": error})
        save_job(job)
        record_job_in_state(job, job.get("dataset_id"))
        return job
    validated = time.perf_counter()
    key = render_cache.cache_key(job, cmd, plugin_dir, params)
    fingerprinted = time.perf_counter()
    job["cache"] = {"enabled": key is not None, "hit": False}
    save_job(job)
    with render_cache.render_lock(key):
        source_job = render_cache.restore(key, output_dir)
        if source_job:
            job.update({"status": "completed", "message": "Reused a completed figure with identical data and settings.",
                        "finished_at": utc_now(), "returncode": 0,
                        "outputs": output_urls_for_dir(job["figure_id"], output_dir)})
            job["cache"] = {"enabled": True, "hit": True, "source_job_id": source_job}
            (output_dir / "subprocess.stdout.log").write_text(f"Render cache hit; original render: {source_job}\n", encoding="utf-8")
            (output_dir / "subprocess.stderr.log").write_text("", encoding="utf-8")
            save_job(job)
            record_job_in_state(job, job.get("dataset_id"))
            completed = job
        else:
            completed = _execute_render(job, cmd, output_dir)
            if completed.get("status") == "completed":
                render_cache.store(key, output_dir, job["job_id"])
    completed["timings"] = {"validation_seconds": round(validated - started, 4),
                            "fingerprint_seconds": round(fingerprinted - validated, 4),
                            "total_seconds": round(time.perf_counter() - started, 4)}
    save_job(completed)
    return completed


def _execute_render(job: dict[str, Any], cmd: list[str], output_dir: Path) -> dict[str, Any]:
    try:
        result = subprocess.run(
            cmd,
            cwd=str(ROOT_DIR),
            capture_output=True,
            text=True,
            timeout=MAX_LOCAL_SECONDS,
            env=plugin_env(job["seed"]),
        )
    except subprocess.TimeoutExpired as exc:
        error = {"error": "Plugin timed out", "detail": str(exc), "suggestion": "Increase timeout or reduce input size."}
        job.update({"status": "failed", "finished_at": utc_now(), "error": error})
        save_job(job)
        record_job_in_state(job, job.get("dataset_id"))
        return job

    (output_dir / "subprocess.stdout.log").write_text(result.stdout or "", encoding="utf-8")
    (output_dir / "subprocess.stderr.log").write_text(result.stderr or "", encoding="utf-8")
    if result.returncode != 0:
        error_path = output_dir / "error.json"
        if error_path.exists():
            try:
                error = json.loads(error_path.read_text(encoding="utf-8"))
            except Exception:
                error = {"error": "Plugin failed", "detail": error_path.read_text(encoding="utf-8"), "suggestion": "Inspect run.log."}
        else:
            error = {"error": "Plugin failed", "detail": result.stderr or result.stdout, "suggestion": "Inspect params and input columns."}
        job.update({"status": "failed", "finished_at": utc_now(), "returncode": result.returncode, "error": error})
        save_job(job)
        record_job_in_state(job, job.get("dataset_id"))
        return job

    figure_id = job["figure_id"]
    job.update(
        {
            "status": "completed",
            "message": "Plugin completed locally.",
            "finished_at": utc_now(),
            "returncode": result.returncode,
            "outputs": output_urls_for_dir(figure_id, output_dir),
        }
    )
    save_job(job)
    record_job_in_state(job, job.get("dataset_id"))
    return job
