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
    res = validate_plotspec(spec, table_path=args.input, skip_scientific=not args.input)
    print(json.dumps(res, indent=2))
    return 0 if res.get("valid") else 2


def cmd_render(args: argparse.Namespace) -> int:
    from vnext.adapters.legacy_r import plotspec_to_legacy_params, run_legacy_plugin
    from vnext.plotspec.model import load, merge_defaults
    from vnext.provenance.bundle import plotspec_hash, write_reproduction_bundle
    from vnext.validate.pipeline import validate_plotspec

    spec = load(args.spec)
    # optional skill defaults
    skill_id = (spec.get("skill") or {}).get("id")
    defaults_path = ROOT / "plugins" / str(skill_id) / "vnext" / "defaults.yaml"
    if defaults_path.exists():
        import yaml

        defaults = yaml.safe_load(defaults_path.read_text(encoding="utf-8")) or {}
        spec = merge_defaults(spec, defaults)

    validation = validate_plotspec(spec, table_path=args.input)
    if not validation.get("valid"):
        print(json.dumps({"error": "validation_failed", "validation": validation}, indent=2))
        return 2

    # Deterministic boundary crossed — no LLM beyond this point
    params = plotspec_to_legacy_params(spec)
    out = Path(args.output)
    result = run_legacy_plugin(
        skill_id=str(skill_id),
        input_path=Path(args.input),
        params=params,
        output_dir=out,
    )
    bundle_meta = None
    if args.bundle:
        bundle_dir = out / "reproduction_bundle"
        bundle_meta = write_reproduction_bundle(
            bundle_dir=bundle_dir,
            spec=spec,
            input_file=Path(args.input),
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
        )
    )
    return 0 if result.get("ok") else 3


def cmd_reproduce(args: argparse.Namespace) -> int:
    # Alias of render with bundle forced
    args.bundle = True
    if args.bundle_dir:
        # load from existing bundle
        b = Path(args.bundle_dir)
        args.spec = str(b / "plotspec.json")
        man = json.loads((b / "manifest.json").read_text(encoding="utf-8"))
        args.input = str(b / man["input"])
    return cmd_render(args)


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
    v.add_argument("--input", default=None)
    v.set_defaults(func=cmd_validate)

    r = sub.add_parser("render")
    r.add_argument("--spec", required=True)
    r.add_argument("--input", required=True)
    r.add_argument("--output", required=True)
    r.add_argument("--bundle", action="store_true")
    r.set_defaults(func=cmd_render)

    rep = sub.add_parser("reproduce")
    rep.add_argument("--spec")
    rep.add_argument("--input")
    rep.add_argument("--output", required=True)
    rep.add_argument("--bundle-dir", dest="bundle_dir", default=None)
    rep.add_argument("--bundle", action="store_true", default=True)
    rep.set_defaults(func=cmd_reproduce)

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
