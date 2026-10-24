"""Fault-injection benchmark for the scientific guardrails.

For every example bundle, each applicable fault is injected into a copy of the
input table and/or the PlotSpec, then:
  * the vNext validator runs — did it report the expected issue code?
  * optionally (--render) the legacy plugin renders the corrupted case exactly
    as plot_web would — did it fail, or silently produce a figure?

Clean (un-corrupted) examples are validated too, giving the false-positive rate.

    python -m vnext.cli benchmark --render --jobs 6 --out docs/vnext/benchmark_guardrails.json
"""
from __future__ import annotations

import copy
import csv
import json
import math
import shutil
import subprocess
import tempfile
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable

from vnext.adapters.legacy_r import legacy_params_to_plotspec, load_skill_metadata, plotspec_to_legacy_params
from vnext.validate.pipeline import validate_plotspec
from vnext.validate.scientific import TableSet, _finite, resolve_roles

ROOT = Path(__file__).resolve().parents[2]
PLUGIN_DIR = ROOT / "plugins"


@dataclass
class Case:
    plugin_id: str
    example_id: str
    params: dict[str, Any]
    inputs: dict[str, Path]
    meta: dict[str, Any]


@dataclass
class Injected:
    fault: str
    expected: set[str]
    spec: dict[str, Any]
    tables: dict[str, list[dict[str, str]]] = field(default_factory=dict)  # field -> replaced rows


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

def load_cases(plugin_ids: list[str] | None = None) -> list[Case]:
    cases = []
    for manifest_path in sorted(PLUGIN_DIR.glob("*/examples/*/manifest.json")):
        plugin_id = manifest_path.parts[-4]
        if plugin_ids and plugin_id not in plugin_ids:
            continue
        meta = load_skill_metadata(plugin_id)
        if not meta:
            continue
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        bundle = manifest_path.parent
        params = json.loads((bundle / str(manifest.get("params") or "params.json")).read_text(encoding="utf-8"))
        inputs = {k: bundle / v for k, v in (manifest.get("inputs") or {}).items() if isinstance(v, str)}
        cases.append(Case(plugin_id, str(manifest.get("id") or bundle.name), params, inputs, meta))
    return cases


def _read(path: Path) -> tuple[list[str], list[dict[str, str]], str]:
    with path.open(encoding="utf-8", errors="replace", newline="") as handle:
        first = handle.readline()
        handle.seek(0)
        delim = "\t" if first.count("\t") > first.count(",") else ","
        reader = csv.DictReader(handle, delimiter=delim)
        cols = list(reader.fieldnames or [])
        return cols, [dict(r) for r in reader], delim


def _table_of(case: Case, column: str) -> str | None:
    for fld, path in case.inputs.items():
        if path.suffix.lower() in {".csv", ".tsv", ".txt"} and column in _read(path)[0]:
            return fld
    return None


def _modify_column(case: Case, column: str, fn: Callable[[str], str]) -> dict[str, list[dict[str, str]]] | None:
    fld = _table_of(case, column)
    if not fld:
        return None
    _, rows, _ = _read(case.inputs[fld])
    for r in rows:
        r[column] = fn(r.get(column, ""))
    return {fld: rows}


def _rename_column(case: Case, column: str, new: str) -> dict[str, list[dict[str, str]]] | None:
    fld = _table_of(case, column)
    if not fld:
        return None
    _, rows, _ = _read(case.inputs[fld])
    return {fld: [{(new if k == column else k): v for k, v in r.items()} for r in rows]}


def _num(fn: Callable[[float], float]) -> Callable[[str], str]:
    def apply(v: str) -> str:
        return repr(fn(float(v))) if _finite(v) else v
    return apply


def _single(v: Any) -> str | None:
    return v if isinstance(v, str) else None


# ---------------------------------------------------------------------------
# faults: (case, spec, roles) -> Injected | None
# ---------------------------------------------------------------------------

def f_pvalue_log10(case, spec, roles):
    for role in ("adjusted_pvalue", "pvalue"):
        col = _single(roles.get(role))
        if col:
            t = _modify_column(case, col, _num(lambda x: -math.log10(x) if x > 0 else 300.0))
            if t:
                return Injected("pvalue_already_-log10", {"PVALUE_OUT_OF_RANGE"}, spec, t)
    return None


def f_raw_p_as_adjusted(case, spec, roles):
    col = _single(roles.get("adjusted_pvalue"))
    if not col:
        return None
    t = _rename_column(case, col, "p_val")
    if not t:
        return None
    s = copy.deepcopy(spec)
    s["mapping"]["adjusted_pvalue"] = "p_val"
    return Injected("raw_p_used_as_adjusted", {"RAW_P_USED_AS_ADJUSTED"}, s, t)


def f_swap_p_columns(case, spec, roles):
    raw, adj = _single(roles.get("pvalue")), _single(roles.get("adjusted_pvalue"))
    if not raw or not adj or raw == adj or _table_of(case, raw) != _table_of(case, adj):
        return None
    fld = _table_of(case, raw)
    _, rows, _ = _read(case.inputs[fld])
    if not any(_finite(r.get(raw)) and _finite(r.get(adj)) and float(r[adj]) > float(r[raw]) for r in rows):
        return None
    for r in rows:
        r[raw], r[adj] = r.get(adj, ""), r.get(raw, "")
    return Injected("raw_and_adjusted_swapped", {"ADJUSTED_BELOW_RAW"}, spec, {fld: rows})


def f_sign_lost(case, spec, roles):
    col = _single(roles.get("signed_effect"))
    if not col or case.meta.get("family") not in {"enrichment", "differential_expression"}:
        return None
    vals = TableSet.from_paths(case.inputs).numbers(col)
    if not (any(v > 0 for v in vals) and any(v < 0 for v in vals)):
        return None
    t = _modify_column(case, col, _num(abs))
    return Injected("effect_sign_lost", {"EFFECT_NOT_BIDIRECTIONAL", "FOLD_CHANGE_NOT_LOG"}, spec, t) if t else None


def f_unlogged_fc(case, spec, roles):
    col = _single(roles.get("signed_effect"))
    if not col or case.meta.get("family") != "differential_expression":
        return None
    t = _modify_column(case, col, _num(lambda x: 2 ** x))
    return Injected("fold_change_not_log2", {"FOLD_CHANGE_NOT_LOG"}, spec, t) if t else None


def f_text_in_numeric(case, spec, roles):
    entries = case.meta.get("roles") or {}
    for role in ("signed_effect", "value", "size", "pvalue", "adjusted_pvalue", "weight", "correlation", "x", "y"):
        col = _single(roles.get(role))
        kind = (entries.get(role) or {}).get("kind")
        embedding_axis = role in {"x", "y"} and case.meta.get("family") == "embedding"
        if col and (kind == "numeric" or embedding_axis):
            counter = iter(range(10**9))
            t = _modify_column(case, col, lambda v: f"item_{next(counter)}")
            if t:
                return Injected("text_in_numeric_role", {"NON_NUMERIC_VALUES", "NON_NUMERIC_COORDINATES"}, spec, t)
    return None


def f_missing_column(case, spec, roles):
    required = case.meta.get("required_roles") or []
    role = next((r for r in required if r in (case.meta.get("roles") or {})), None)
    if not role:
        return None
    s = copy.deepcopy(spec)
    s["mapping"][role] = "column_that_does_not_exist"
    return Injected("required_column_missing", {"MISSING_MAPPED_COLUMN"}, s)


def f_negative_size(case, spec, roles):
    col = _single(roles.get("size"))
    t = _modify_column(case, col, _num(lambda x: -abs(x) - 1)) if col else None
    return Injected("negative_size", {"NEGATIVE_SIZE"}, spec, t) if t else None


def f_negative_composition(case, spec, roles):
    if case.meta.get("family") != "composition":
        return None
    col = _single(roles.get("value"))
    t = _modify_column(case, col, _num(lambda x: -abs(x) - 1)) if col else None
    return Injected("negative_composition", {"NEGATIVE_COMPOSITION"}, spec, t) if t else None


def f_correlation_range(case, spec, roles):
    col = _single(roles.get("correlation"))
    t = _modify_column(case, col, _num(lambda x: x * 3 + (2 if x >= 0 else -2))) if col else None
    return Injected("correlation_out_of_range", {"CORRELATION_OUT_OF_RANGE"}, spec, t) if t else None


def f_duplicate_ids(case, spec, roles):
    col = _single(roles.get("id"))
    if not col or case.meta.get("family") != "embedding":
        return None
    fld = _table_of(case, col)
    if not fld:
        return None
    _, rows, _ = _read(case.inputs[fld])
    if len(rows) < 4:
        return None
    for i in range(1, min(len(rows), 20)):
        rows[i][col] = rows[0][col]
    return Injected("duplicate_cell_ids", {"DUPLICATE_IDS"}, spec, {fld: rows})


def f_raw_p_labeled_fdr(case, spec, roles):
    col = _single(roles.get("pvalue"))
    if not col or roles.get("adjusted_pvalue"):
        return None
    t = _rename_column(case, col, "pvalue")
    if not t:
        return None
    s = copy.deepcopy(spec)
    s["mapping"]["pvalue"] = "pvalue"
    s.setdefault("visual", {})["legend_title"] = "FDR"
    return Injected("raw_p_labelled_as_fdr", {"RAW_P_LABELED_AS_FDR"}, s, t)


def f_unsupported_role(case, spec, roles):
    if "adjusted_pvalue" in (case.meta.get("roles") or {}) or not roles.get("pvalue"):
        return None
    s = copy.deepcopy(spec)
    s["mapping"]["adjusted_pvalue"] = _single(roles.get("pvalue"))
    return Injected("role_not_supported_by_renderer", {"UNSUPPORTED_ROLE"}, s)


FAULTS = [f_pvalue_log10, f_raw_p_as_adjusted, f_swap_p_columns, f_sign_lost, f_unlogged_fc, f_text_in_numeric,
          f_missing_column, f_negative_size, f_negative_composition, f_correlation_range, f_duplicate_ids,
          f_raw_p_labeled_fdr, f_unsupported_role]


# ---------------------------------------------------------------------------
# runner
# ---------------------------------------------------------------------------

def _materialise(case: Case, inj: Injected, workdir: Path) -> dict[str, Path]:
    paths = dict(case.inputs)
    for fld, rows in inj.tables.items():
        cols, _, delim = _read(case.inputs[fld])
        cols = list(rows[0].keys()) if rows else cols
        dest = workdir / f"{fld}__{case.inputs[fld].name}"
        with dest.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=cols, delimiter=delim, extrasaction="ignore")
            writer.writeheader()
            writer.writerows(rows)
        paths[fld] = dest
    return paths


def _render(case: Case, spec: dict[str, Any], inputs: dict[str, Path], workdir: Path) -> str:
    """Legacy outcome: 'rendered' (figure produced) or 'failed'."""
    from plot_web.app import read_yaml
    from plot_web.server.runner import build_command, plugin_env

    params = plotspec_to_legacy_params(spec, case.meta)
    params_path = workdir / "params.json"
    params_path.write_text(json.dumps(params), encoding="utf-8")
    out = workdir / "out"
    out.mkdir(exist_ok=True)
    config = read_yaml(PLUGIN_DIR / case.plugin_id / "config.yaml")
    cmd = build_command(case.plugin_id, config, inputs, params_path, out)
    try:
        proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=300, env=plugin_env())
    except subprocess.TimeoutExpired:
        return "failed"
    ok = proc.returncode == 0 and any((out / n).is_file() and (out / n).stat().st_size > 0 for n in ("result.png", "result.svg"))
    return "rendered" if ok else "failed"


def run_one(case: Case, inj: Injected | None, render: bool) -> dict[str, Any]:
    workdir = Path(tempfile.mkdtemp(prefix="vnext_bench_"))
    try:
        spec = inj.spec if inj else legacy_params_to_plotspec(case.plugin_id, case.params, meta=case.meta)
        inputs = _materialise(case, inj, workdir) if inj else dict(case.inputs)
        result = validate_plotspec(spec, tables=inputs)
        codes = {i["code"]: i["severity"] for i in result["errors"] + result["warnings"] + result["infos"]}
        row = {
            "plugin_id": case.plugin_id, "example_id": case.example_id, "family": case.meta.get("family"),
            "fault": inj.fault if inj else "clean",
            "expected": sorted(inj.expected) if inj else [],
            "valid": result["valid"],
            "codes": codes,
        }
        if inj:
            hit = [codes[c] for c in inj.expected if c in codes]
            row["detected"] = bool(hit)
            row["detected_as_error"] = "error" in hit
        if render:
            row["legacy"] = _render(case, spec, inputs, workdir)
        return row
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


def run_benchmark(render: bool = False, jobs: int = 4, plugin_ids: list[str] | None = None) -> dict[str, Any]:
    work: list[tuple[Case, Injected | None]] = []
    for case in load_cases(plugin_ids):
        spec = legacy_params_to_plotspec(case.plugin_id, case.params, meta=case.meta)
        roles, _ = resolve_roles(spec, case.meta, TableSet.from_paths(case.inputs))
        work.append((case, None))
        for fault in FAULTS:
            inj = fault(case, spec, roles)
            if inj:
                work.append((case, inj))
    with ThreadPoolExecutor(max_workers=max(1, jobs)) as pool:
        rows = list(pool.map(lambda w: run_one(w[0], w[1], render), work))
    return {"rows": rows, "summary": summarise(rows)}


def summarise(rows: list[dict[str, Any]]) -> dict[str, Any]:
    clean = [r for r in rows if r["fault"] == "clean"]
    out: dict[str, Any] = {
        "clean": {
            "n": len(clean),
            "false_positive_errors": sum(1 for r in clean if not r["valid"]),
            "legacy_rendered": sum(1 for r in clean if r.get("legacy") == "rendered") if clean and "legacy" in clean[0] else None,
        },
        "faults": {},
    }
    for fault in sorted({r["fault"] for r in rows} - {"clean"}):
        group = [r for r in rows if r["fault"] == fault]
        entry = {
            "n": len(group),
            "plugins": len({r["plugin_id"] for r in group}),
            "detected": sum(r["detected"] for r in group),
            "detected_as_error": sum(r["detected_as_error"] for r in group),
        }
        if "legacy" in group[0]:
            entry["legacy_rendered_silently"] = sum(1 for r in group if r["legacy"] == "rendered")
        out["faults"][fault] = entry
    faults = [r for r in rows if r["fault"] != "clean"]
    out["total"] = {
        "n": len(faults),
        "detected": sum(r["detected"] for r in faults),
        "detected_as_error": sum(r["detected_as_error"] for r in faults),
    }
    if faults and "legacy" in faults[0]:
        silent = [r for r in faults if r["legacy"] == "rendered"]
        out["total"]["legacy_rendered_silently"] = len(silent)
        out["total"]["silent_but_detected"] = sum(r["detected"] for r in silent)
    return out


def summary_markdown(summary: dict[str, Any]) -> str:
    has_legacy = "legacy_rendered_silently" in summary["total"]
    head = "| Fault | Cases | Plugins | Detected | Detected as error |" + (" Legacy rendered silently |" if has_legacy else "")
    sep = "|---|---:|---:|---:|---:|" + ("---:|" if has_legacy else "")
    lines = [head, sep]
    for fault, e in summary["faults"].items():
        row = f"| {fault} | {e['n']} | {e['plugins']} | {e['detected']} | {e['detected_as_error']} |"
        if has_legacy:
            row += f" {e['legacy_rendered_silently']} |"
        lines.append(row)
    t = summary["total"]
    row = f"| **Total** | **{t['n']}** | | **{t['detected']}** | **{t['detected_as_error']}** |"
    if has_legacy:
        row += f" **{t['legacy_rendered_silently']}** |"
    lines.append(row)
    c = summary["clean"]
    lines.append("")
    lines.append(f"Clean examples: {c['n']}, false-positive errors: {c['false_positive_errors']}"
                 + (f", legacy rendered: {c['legacy_rendered']}" if c.get("legacy_rendered") is not None else "") + ".")
    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------
# Reproduction: every example re-rendered from its PlotSpec alone
# ---------------------------------------------------------------------------

def reproduce_one(case: Case) -> dict[str, Any]:
    """PlotSpec (from the example params) -> params -> render; compare with expected/result.png."""
    from vnext.adapters.legacy_r import run_legacy_plugin
    from vnext.provenance.compare import DEFAULT_TOLERANCE, image_diff

    spec = json.loads(json.dumps(legacy_params_to_plotspec(case.plugin_id, case.params, meta=case.meta, seed=42)))
    params = plotspec_to_legacy_params(spec, case.meta)
    workdir = Path(tempfile.mkdtemp(prefix="vnext_repro_"))
    try:
        result = run_legacy_plugin(skill_id=case.plugin_id, params=params, output_dir=workdir, inputs=case.inputs, seed=42)
        expected = PLUGIN_DIR / case.plugin_id / "examples" / case.example_id / "expected" / "result.png"
        png = workdir / "result.png"
        changed = image_diff(png, expected)[0] if result["ok"] and png.exists() and expected.exists() else None
        if changed is not None and changed > DEFAULT_TOLERANCE:
            keep = Path(tempfile.gettempdir()) / "vnext_repro_diffs" / case.plugin_id / case.example_id
            keep.mkdir(parents=True, exist_ok=True)
            for name in ("result.png", "run.log", "params.json"):
                if (workdir / name).exists():
                    shutil.copy2(workdir / name, keep / name)
        return {"plugin_id": case.plugin_id, "example_id": case.example_id, "rendered": bool(result["ok"]),
                "changed_fraction": changed, "identical": changed is not None and changed <= DEFAULT_TOLERANCE}
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


def run_reproduction(jobs: int = 4, plugin_ids: list[str] | None = None) -> dict[str, Any]:
    cases = load_cases(plugin_ids)
    with ThreadPoolExecutor(max_workers=max(1, jobs)) as pool:
        rows = list(pool.map(reproduce_one, cases))
    return {"rows": rows, "summary": {"n": len(rows), "rendered": sum(r["rendered"] for r in rows),
                                      "pixel_identical": sum(r["identical"] for r in rows),
                                      "plugins": len({r["plugin_id"] for r in rows})}}
