"""CLI for OmicsCanvas vNext deterministic pipeline.

Examples:
  python3 -m vnext.cli registry build
  python3 -m vnext.cli validate --spec path/plotspec.json --input data.csv
  python3 -m vnext.cli render --spec path/plotspec.json --input data.csv --output /tmp/out
  python3 -m vnext.cli reproduce --spec ... --input ... --output ...
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# Allow `python3 -m vnext.cli` from repo root
ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


def cmd_registry_build(_args: argparse.Namespace) -> int:
    from vnext.registry.loader import build_registry_from_plugins, validate_registry, write_registry

    reg = build_registry_from_plugins()
    path = write_registry(reg)
    res = validate_registry(reg)
    print(json.dumps({"wrote": str(path), "validation": res}, indent=2))
    return 0 if res.get("valid") else 1


def cmd_registry_validate(_args: argparse.Namespace) -> int:
    from vnext.registry.loader import load_registry, validate_registry

    res = validate_registry(load_registry())
    print(json.dumps(res, indent=2))
    return 0 if res.get("valid") else 1


def cmd_validate(args: argparse.Namespace) -> int:
    from vnext.plotspec.model import load
    from vnext.validate.pipeline import validate_plotspec

    spec = load(args.spec)
    inputs = _parse_inputs(args.input)
    res = validate_plotspec(spec, tables=inputs or None, skip_scientific=not inputs)
    print(json.dumps(res, indent=2))
    return 0 if res.get("valid") else 2


def _parse_inputs(values: list[str] | None) -> dict[str, Path]:
    """--input path (main input) or --input field=path, repeatable."""
    out: dict[str, Path] = {}
    for raw in values or []:
        field, sep, path = raw.partition("=")
        if sep and field and not Path(raw).exists():
            out[field] = Path(path)
        else:
            out.setdefault("input", Path(raw))
    return out


def cmd_render(args: argparse.Namespace) -> int:
    from vnext.adapters.legacy_r import plotspec_to_legacy_params, run_legacy_plugin
    from vnext.plotspec.model import load, merge_defaults
    from vnext.provenance.bundle import describe_inputs, plotspec_hash, write_reproduction_bundle
    from vnext.validate.pipeline import validate_plotspec

    spec = load(args.spec)
    inputs = _parse_inputs(args.input)
    skill_id = (spec.get("skill") or {}).get("id")
    defaults_path = ROOT / "plugins" / str(skill_id) / "vnext" / "defaults.yaml"
    if defaults_path.exists():
        import yaml

        defaults = yaml.safe_load(defaults_path.read_text(encoding="utf-8")) or {}
        spec = merge_defaults(spec, defaults)
    from plot_web.server.runner import DEFAULT_SEED

    # Always record the seed actually used, so the spec fully determines the render.
    seed = args.seed if args.seed is not None else (spec.get("provenance") or {}).get("seed", DEFAULT_SEED)
    spec.setdefault("provenance", {})["seed"] = int(seed)
    spec["inputs"] = describe_inputs(inputs)

    validation = validate_plotspec(spec, tables=inputs)
    if not validation.get("valid"):
        print(json.dumps({"error": "validation_failed", "validation": validation}, indent=2, default=str))
        return 2

    # Deterministic boundary crossed — no LLM beyond this point
    params = plotspec_to_legacy_params(spec)
    out = Path(args.output)
    result = run_legacy_plugin(skill_id=str(skill_id), inputs=inputs, params=params, output_dir=out, seed=seed)
    bundle_meta = None
    if args.bundle and result.get("ok"):
        bundle_meta = write_reproduction_bundle(
            bundle_dir=out / "reproduction_bundle",
            spec=spec,
            inputs=inputs,
            params=params,
            figure_files=result.get("figure_paths") or {},
            validation=validation,
        )
    print(
        json.dumps(
            {
                "ok": result.get("ok"),
                "plotspec_hash": plotspec_hash(spec),
                "render": {k: v for k, v in result.items() if k != "figure_paths"},
                "bundle": bundle_meta,
                "validation_warnings": validation.get("warnings"),
            },
            indent=2,
            default=str,
        )
    )
    return 0 if result.get("ok") else 3


def cmd_reproduce(args: argparse.Namespace) -> int:
    """Re-render from a bundle's plotspec.json + input/ only; optionally compare figures."""
    if not args.bundle_dir:
        args.bundle = True
        return cmd_render(args)

    from vnext.adapters.legacy_r import plotspec_to_legacy_params, run_legacy_plugin
    from vnext.plotspec.model import load
    from vnext.provenance.bundle import describe_inputs, plotspec_hash
    from vnext.provenance.compare import DEFAULT_TOLERANCE, image_diff

    bundle = Path(args.bundle_dir)
    manifest = json.loads((bundle / "manifest.json").read_text(encoding="utf-8"))
    spec = load(bundle / "plotspec.json")
    inputs = {field: bundle / rel for field, rel in (manifest.get("inputs") or {}).items()}
    if not inputs and manifest.get("input"):
        inputs = {"input": bundle / manifest["input"]}

    report: dict[str, object] = {"bundle": str(bundle)}
    current = describe_inputs(inputs)
    recorded = spec.get("inputs") or {}
    report["inputs_match"] = all((recorded.get(f) or {}).get("checksum") == d["checksum"] for f, d in current.items())
    report["plotspec_hash_match"] = plotspec_hash(spec) == manifest.get("plotspec_hash")

    params = plotspec_to_legacy_params(spec)
    if (bundle / "params.json").exists():
        from vnext.adapters.legacy_r import RUN_CONTROL_KEYS

        def semantic(p: dict) -> dict:
            return {k: v for k, v in p.items() if k not in RUN_CONTROL_KEYS}

        recorded_params = json.loads((bundle / "params.json").read_text(encoding="utf-8"))
        report["params_match"] = semantic(params) == semantic(recorded_params)
    seed = (spec.get("provenance") or {}).get("seed")
    result = run_legacy_plugin(skill_id=spec["skill"]["id"], inputs=inputs, params=params, output_dir=Path(args.output), seed=seed)
    report["rendered"] = result.get("ok")
    ok = bool(result.get("ok")) and report["inputs_match"] and report["plotspec_hash_match"] and report.get("params_match", True)
    if args.compare:
        original = bundle / (manifest.get("figures") or {}).get("png", "figures/result.png")
        new_png = Path(args.output) / "result.png"
        if original.exists() and new_png.exists():
            changed, note = image_diff(new_png, original)
            report["figure_identical"] = changed <= DEFAULT_TOLERANCE
            report["figure_diff"] = note
            ok = ok and report["figure_identical"]
        else:
            report["figure_identical"] = None
    report["ok"] = ok
    print(json.dumps(report, indent=2))
    return 0 if ok else 4


def cmd_roundtrip(args: argparse.Namespace) -> int:
    from vnext.plotspec.model import load, round_trip, validate_schema

    spec = load(args.spec)
    rt = round_trip(spec)
    ok = rt == json.loads(json.dumps(spec, sort_keys=True))
    # compare without key order sensitivity
    ok = json.dumps(rt, sort_keys=True) == json.dumps(spec, sort_keys=True)
    res = validate_schema(rt)
    print(json.dumps({"lossless": ok, "schema": res}, indent=2))
    return 0 if ok and res.get("valid") else 1


def cmd_migrate(args: argparse.Namespace) -> int:
    from vnext.migrate.generator import migrate
    from vnext.registry.loader import build_registry_from_plugins, validate_registry, write_registry

    results = migrate(args.plugins or None)
    reg = build_registry_from_plugins()
    write_registry(reg)
    warnings = {m["id"]: m["generated"]["warnings"] for m in results if m["generated"]["warnings"]}
    print(json.dumps({"migrated": len(results), "curated": sum(m["generated"]["curated"] for m in results),
                      "warnings": warnings, "registry": validate_registry(reg)}, indent=2))
    return 0


def cmd_benchmark(args: argparse.Namespace) -> int:
    from vnext.benchmark.guardrails import run_benchmark, run_reproduction, summary_markdown

    if args.reproduce:
        result = run_reproduction(jobs=args.jobs)
        if args.out:
            Path(args.out).write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(result["summary"], indent=2))
        return 0 if result["summary"]["pixel_identical"] == result["summary"]["n"] else 1
    result = run_benchmark(render=args.render, jobs=args.jobs)
    if args.out:
        out = Path(args.out)
        out.write_text(json.dumps(result, indent=2, default=str) + "\n", encoding="utf-8")
        out.with_suffix(".md").write_text(summary_markdown(result["summary"]), encoding="utf-8")
    print(summary_markdown(result["summary"]))
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="vnext", description="OmicsCanvas vNext CLI")
    sub = p.add_subparsers(dest="cmd", required=True)

    b = sub.add_parser("registry", help="Registry operations")
    b_sub = b.add_subparsers(dest="registry_cmd", required=True)
    b_build = b_sub.add_parser("build")
    b_build.set_defaults(func=cmd_registry_build)
    b_val = b_sub.add_parser("validate")
    b_val.set_defaults(func=cmd_registry_validate)

    v = sub.add_parser("validate")
    v.add_argument("--spec", required=True)
    v.add_argument("--input", default=None, action="append", help="path, or field=path (repeatable)")
    v.set_defaults(func=cmd_validate)

    r = sub.add_parser("render")
    r.add_argument("--spec", required=True)
    r.add_argument("--input", required=True, action="append", help="path, or field=path for extra inputs (repeatable)")
    r.add_argument("--output", required=True)
    r.add_argument("--seed", type=int, default=None)
    r.add_argument("--bundle", action="store_true")
    r.set_defaults(func=cmd_render)

    rep = sub.add_parser("reproduce")
    rep.add_argument("--spec")
    rep.add_argument("--input", action="append")
    rep.add_argument("--output", required=True)
    rep.add_argument("--seed", type=int, default=None)
    rep.add_argument("--bundle-dir", dest="bundle_dir", default=None)
    rep.add_argument("--compare", action="store_true", help="pixel-compare the new figure with the bundled one")
    rep.add_argument("--bundle", action="store_true", default=True)
    rep.set_defaults(func=cmd_reproduce)

    mg = sub.add_parser("migrate", help="Generate plugins/*/vnext/metadata.yaml + rebuild the registry")
    mg.add_argument("plugins", nargs="*")
    mg.set_defaults(func=cmd_migrate)

    bm = sub.add_parser("benchmark", help="Fault-injection benchmark of the scientific guardrails")
    bm.add_argument("--render", action="store_true", help="also render each corrupted case with the legacy plugin")
    bm.add_argument("--reproduce", action="store_true", help="re-render every example from its PlotSpec and pixel-compare")
    bm.add_argument("--jobs", type=int, default=4)
    bm.add_argument("--out", default=None, help="write JSON (+ .md summary) here")
    bm.set_defaults(func=cmd_benchmark)

    rt = sub.add_parser("roundtrip")
    rt.add_argument("--spec", required=True)
    rt.set_defaults(func=cmd_roundtrip)
    return p


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
