#!/usr/bin/env python3
"""Render plugin example bundles and check that each produces a figure.

Runs ``reproduce.command`` from ``plugins/<id>/examples/index.json`` with the
output redirected to a temp dir, then requires a non-empty result.png/svg.
Bundles without a reproduce command are run through plot_web's own
``build_command`` using their ``manifest.json`` inputs (same path as the UI).

With ``--compare`` each render is also diffed against the bundle's
``expected/result.png`` (image regression test); ``--update-baseline``
overwrites those baselines with the new renders after a deliberate change.

Baselines are machine-specific (fonts, R graphics devices); use ``--compare``
on the machine that produced them, and plain smoke mode on CI.

usage: python scripts/smoke_plugins.py [plugin_id ...] [--max-examples N] [--jobs N]
                                       [--compare [--tolerance F]] [--update-baseline]
       (no plugin ids = every plugin with an examples/index.json)
"""
from __future__ import annotations

import argparse
import json
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLUGIN_DIR = ROOT / "plugins"


def manifest_commands(plugin_id: str, skip: set[str]) -> list[tuple[str, list[str]]]:
    sys.path.insert(0, str(ROOT))
    from plot_web.app import build_command, read_yaml

    config = read_yaml(PLUGIN_DIR / plugin_id / "config.yaml")
    out = []
    for manifest_path in sorted((PLUGIN_DIR / plugin_id / "examples").glob("*/manifest.json")):
        bundle = manifest_path.parent
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        example_id = str(manifest.get("id") or bundle.name)
        inputs = {k: bundle / v for k, v in (manifest.get("inputs") or {}).items() if isinstance(v, str)}
        if example_id in skip or not inputs:
            continue
        params = bundle / str(manifest.get("params") or "params.json")
        # build_command fills --output; with_output() replaces it per run.
        out.append((example_id, build_command(plugin_id, config, inputs, params, Path("OUTPUT"))))
    return out


def example_commands(plugin_id: str) -> list[tuple[str, list[str]]]:
    index = PLUGIN_DIR / plugin_id / "examples" / "index.json"
    if not index.is_file():
        return []
    data = json.loads(index.read_text(encoding="utf-8"))
    out = []
    examples = data if isinstance(data, list) else data.get("examples") or []
    for example in examples:
        if not isinstance(example, dict):
            continue
        command = (example.get("reproduce") or {}).get("command")
        if command:
            out.append((str(example.get("id")), shlex.split(command)))
    return out + manifest_commands(plugin_id, {example_id for example_id, _ in out})


def run_env() -> dict[str, str]:
    """Same seeded R environment as plot_web jobs, so renders are reproducible."""
    sys.path.insert(0, str(ROOT))
    from plot_web.server.runner import plugin_env

    return plugin_env()


def with_output(cmd: list[str], output_dir: Path) -> list[str]:
    cmd = list(cmd)
    if "--output" in cmd:
        cmd[cmd.index("--output") + 1] = str(output_dir)
    else:
        cmd += ["--output", str(output_dir)]
    return cmd


def image_diff(rendered: Path, expected: Path) -> tuple[float, str]:
    sys.path.insert(0, str(ROOT))
    from vnext.provenance.compare import image_diff as _diff

    return _diff(rendered, expected)


def run_example(plugin_id: str, example_id: str, cmd: list[str], args: argparse.Namespace) -> tuple[str, str, str | None]:
    """Returns (status, report line, failure detail or None)."""
    expected = PLUGIN_DIR / plugin_id / "examples" / example_id / "expected" / "result.png"
    with tempfile.TemporaryDirectory(prefix=f"smoke_{plugin_id}_") as tmp:
        out = Path(tmp)
        started = time.time()
        try:
            proc = subprocess.run(with_output(cmd, out), cwd=ROOT, capture_output=True, text=True, timeout=args.timeout, env=run_env())
            code, stderr = proc.returncode, proc.stderr
        except subprocess.TimeoutExpired:
            code, stderr = -1, "timeout"
        elapsed = f"{time.time() - started:.1f}s"
        figures = [p for p in (out / "result.png", out / "result.svg") if p.is_file() and p.stat().st_size > 0]
        if code != 0 or not figures:
            error = out / "error.json"
            detail = error.read_text(encoding="utf-8") if error.is_file() else stderr.strip()[-800:]
            return "FAIL", f"FAIL {plugin_id}/{example_id} ({elapsed})", f"{plugin_id}/{example_id}: exit={code}\n{detail}"
        png = out / "result.png"
        if args.update_baseline and png.is_file():
            # Only rewrite baselines that actually changed, to keep diffs reviewable.
            if expected.is_file() and image_diff(png, expected)[0] <= args.tolerance:
                return "ok", f"ok   {plugin_id}/{example_id} ({elapsed}) unchanged", None
            expected.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(png, expected)
            return "UPD", f"UPD  {plugin_id}/{example_id} ({elapsed})", None
        if args.compare:
            if not expected.is_file() or not png.is_file():
                return "NOBASE", f"NOBASE {plugin_id}/{example_id} ({elapsed})", None
            changed, note = image_diff(png, expected)
            if changed > args.tolerance:
                keep = Path(args.diff_dir) / plugin_id / example_id
                keep.mkdir(parents=True, exist_ok=True)
                shutil.copy2(png, keep / "rendered.png")
                shutil.copy2(expected, keep / "expected.png")
                return "DIFF", f"DIFF {plugin_id}/{example_id} ({elapsed}) {note}", f"{plugin_id}/{example_id}: {note} -> {keep}"
            return "ok", f"ok   {plugin_id}/{example_id} ({elapsed}) {note}", None
        return "ok", f"ok   {plugin_id}/{example_id} ({elapsed})", None


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("plugins", nargs="*")
    parser.add_argument("--max-examples", type=int, default=0, help="per plugin; 0 = all")
    parser.add_argument("--timeout", type=int, default=600)
    parser.add_argument("--jobs", type=int, default=1, help="examples rendered in parallel")
    parser.add_argument("--compare", action="store_true", help="diff against expected/result.png")
    parser.add_argument("--tolerance", type=float, default=0.002, help="max fraction of changed pixels")
    parser.add_argument("--diff-dir", default=str(Path(tempfile.gettempdir()) / "omicscanvas_image_diffs"))
    parser.add_argument("--update-baseline", action="store_true", help="overwrite expected/result.png")
    args = parser.parse_args(argv)

    plugin_ids = args.plugins or sorted(p.parent.parent.name for p in PLUGIN_DIR.glob("*/examples/index.json"))
    failures: list[str] = []
    work: list[tuple[str, str, list[str]]] = []
    for plugin_id in plugin_ids:
        commands = example_commands(plugin_id)
        if not commands:
            failures.append(f"{plugin_id}: no runnable examples")
            continue
        if args.max_examples:
            commands = commands[: args.max_examples]
        work.extend((plugin_id, example_id, cmd) for example_id, cmd in commands)

    counts: dict[str, int] = {}
    with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as pool:
        for status, line, failure in pool.map(lambda w: run_example(*w, args), work):
            print(line, flush=True)
            counts[status] = counts.get(status, 0) + 1
            if failure:
                failures.append(failure)

    summary = ", ".join(f"{k}={v}" for k, v in sorted(counts.items()))
    print(f"\n{counts.get('ok', 0) + counts.get('UPD', 0)}/{len(work)} examples passed ({summary})")
    for failure in failures:
        print(f"\n--- {failure}", file=sys.stderr)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
