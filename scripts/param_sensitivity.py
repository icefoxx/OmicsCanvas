#!/usr/bin/env python3
"""Parameter-sensitivity scan: find parameters that have no effect, or crash the plugin.

For one example per plugin, every schema parameter is perturbed in turn
(number x2 / +1, boolean flipped, colour -> magenta, select -> another option,
text -> marker string), the plugin re-renders, and result.png is compared with
the unperturbed render.

  no_effect  the figure did not change -> dead parameter, or only active in
             another mode (triage by hand)
  crash      the plugin failed with a perturbed but valid value

usage: python scripts/param_sensitivity.py [plugin_id ...] [--jobs N] [--out report.json]
"""
from __future__ import annotations

import argparse
import copy
import json
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from plot_web.app import build_command, read_yaml  # noqa: E402
from plot_web.schema_normalize import normalize_params_schema  # noqa: E402
from plot_web.server.runner import plugin_env  # noqa: E402

PLUGIN_DIR = ROOT / "plugins"
# Parameters that only affect the interactive HTML widget or file outputs, not result.png.
HTML_ONLY = ("tooltip", "hover", "zoom", "pan", "lasso", "selectable", "interactive", "brush", "drag",
             "html", "widget", "export", "dpi", "download", "click", "animation")
SKIP_TYPES = {"column", "columns", "object", "array", "string_array", "number_array", "color_array", "textarea"}


def schema_fields(plugin_dir: Path) -> dict[str, dict]:
    path = plugin_dir / "params_schema.json"
    if not path.is_file():
        return {}
    norm = normalize_params_schema(json.loads(path.read_text(encoding="utf-8"))) or {}
    return {k: v for sec in norm.values() if isinstance(sec, dict) for k, v in sec.items() if isinstance(v, dict)}


def first_example(plugin_dir: Path):
    for manifest in sorted((plugin_dir / "examples").glob("*/manifest.json")):
        m = json.loads(manifest.read_text(encoding="utf-8"))
        params = json.loads((manifest.parent / (m.get("params") or "params.json")).read_text(encoding="utf-8"))
        inputs = {k: manifest.parent / v for k, v in (m.get("inputs") or {}).items() if isinstance(v, str)}
        if inputs:
            return manifest.parent.name, params, inputs
    return None


def perturb(key: str, field: dict, current):
    """Return a different but valid value, or None if no sensible perturbation exists."""
    ftype = str(field.get("type") or "")
    value = current if current is not None else field.get("default")
    options = field.get("options") or field.get("enum") or []
    options = [o.get("value", o) if isinstance(o, dict) else o for o in options]
    if ftype == "boolean" or isinstance(value, bool):
        return not bool(value)
    if ftype == "select" or options:
        others = [o for o in options if o != value]
        return others[0] if others else None
    if ftype == "color":
        return "#FF00FF" if str(value).upper() != "#FF00FF" else "#00FF00"
    if ftype in {"number", "integer"} or isinstance(value, (int, float)):
        try:
            v = float(value)
        except (TypeError, ValueError):
            v = 0.0
        new = v * 2 if v not in (0.0,) else 1.0
        if 0 < v <= 1 and ("alpha" in key or "opacity" in key):
            new = v / 2
        # The scanner must not manufacture invalid confidence levels, dimensions,
        # angles, etc. outside the same schema bounds enforced by the editor.
        lower, upper = field.get("min"), field.get("max")
        if isinstance(lower, (int, float)):
            new = max(float(lower), new)
        if isinstance(upper, (int, float)):
            new = min(float(upper), new)
        if new == v:
            step = float(field.get("step") or (1 if ftype == "integer" else max(abs(v) / 2, 0.1)))
            alternatives = [v - step, v + step]
            new = next((x for x in alternatives
                        if (lower is None or x >= lower) and (upper is None or x <= upper) and x != v), v)
        if new == v:
            return None
        return int(new) if ftype == "integer" or (isinstance(value, int) and float(new).is_integer()) else new
    if "font_family" in key or key in {"font", "family"}:
        return "serif" if str(value).lower() != "serif" else "mono"  # an unknown font would silently fall back
    if ftype == "string" and not value:
        return None  # empty text fields often mean "auto"; nothing to compare against
    if ftype == "string":
        return "ZZ_SENSITIVITY_TEST"
    return None


def identical(a: Path, b: Path) -> bool:
    """Strict pixel equality (any channel difference counts as an effect)."""
    import numpy as np
    from PIL import Image

    x, y = Image.open(a).convert("RGB"), Image.open(b).convert("RGB")
    return x.size == y.size and not np.any(np.asarray(x) != np.asarray(y))


def render(plugin_id: str, config: dict, params: dict, inputs: dict, workdir: Path) -> Path | None:
    workdir.mkdir(parents=True, exist_ok=True)
    params_path = workdir / "params.json"
    params_path.write_text(json.dumps(params), encoding="utf-8")
    out = workdir / "out"
    out.mkdir(parents=True, exist_ok=True)
    cmd = build_command(plugin_id, config, inputs, params_path, out)
    try:
        proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=300, env=plugin_env())
    except subprocess.TimeoutExpired:
        return None
    png = out / "result.png"
    return png if proc.returncode == 0 and png.exists() else None


def scan_plugin(plugin_id: str, jobs: int) -> dict:
    plugin_dir = PLUGIN_DIR / plugin_id
    example = first_example(plugin_dir)
    if not example:
        return {"plugin_id": plugin_id, "skipped": "no example"}
    example_id, base_params, inputs = example
    config = read_yaml(plugin_dir / "config.yaml")
    fields = schema_fields(plugin_dir)
    tmp = Path(tempfile.mkdtemp(prefix=f"sens_{plugin_id}_"))
    try:
        base = render(plugin_id, config, base_params, inputs, tmp / "base")
        if not base:
            return {"plugin_id": plugin_id, "example": example_id, "skipped": "base render failed"}

        tasks = []
        for key, field in fields.items():
            if str(field.get("type")) in SKIP_TYPES or any(t in key for t in HTML_ONLY):
                continue
            new = perturb(key, field, base_params.get(key))
            if new is None or new == base_params.get(key):
                continue
            tasks.append((key, base_params.get(key, field.get("default")), new))

        def run(task):
            key, old, new = task
            params = copy.deepcopy(base_params)
            params[key] = new
            work = tmp / f"p_{key}"
            png = render(plugin_id, config, params, inputs, work)
            if png is None:
                status = "crash"
                log = work / "out" / "error.json"
                detail = log.read_text(encoding="utf-8")[:300] if log.exists() else ""
            else:
                status = "no_effect" if identical(png, base) else "ok"
                detail = ""
            shutil.rmtree(work, ignore_errors=True)
            return {"param": key, "from": old, "to": new, "status": status, "detail": detail}

        with ThreadPoolExecutor(max_workers=jobs) as pool:
            results = list(pool.map(run, tasks))
        return {"plugin_id": plugin_id, "example": example_id, "n_params": len(results), "results": results}
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("plugins", nargs="*")
    parser.add_argument("--jobs", type=int, default=6)
    parser.add_argument("--out", default=None)
    args = parser.parse_args(argv)
    plugin_ids = args.plugins or sorted(p.parent.name for p in PLUGIN_DIR.glob("*/config.yaml"))
    report = []
    for pid in plugin_ids:
        r = scan_plugin(pid, args.jobs)
        report.append(r)
        res = r.get("results") or []
        crashes = [x["param"] for x in res if x["status"] == "crash"]
        dead = [x["param"] for x in res if x["status"] == "no_effect"]
        print(f"{pid}: {r.get('skipped') or f'{len(res)} params, {len(crashes)} crash, {len(dead)} no effect'}", flush=True)
    if args.out:
        Path(args.out).write_text(json.dumps(report, indent=2, default=str), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
