"""PlotSpec load/dump/validate helpers (JSON Schema draft 2020-12)."""
from __future__ import annotations

import copy
import json
from pathlib import Path
from typing import Any

from vnext import __version__

SCHEMA_PATH = Path(__file__).with_name("schema.json")


def load_schema() -> dict[str, Any]:
    return json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))


def dumps(spec: dict[str, Any], *, indent: int = 2) -> str:
    return json.dumps(spec, indent=indent, ensure_ascii=False, sort_keys=True) + "\n"


def dump(spec: dict[str, Any], path: Path | str, *, indent: int = 2) -> None:
    Path(path).write_text(dumps(spec, indent=indent), encoding="utf-8")


def loads(text: str) -> dict[str, Any]:
    data = json.loads(text)
    if not isinstance(data, dict):
        raise TypeError("PlotSpec must be a JSON object")
    return data


def load(path: Path | str) -> dict[str, Any]:
    return loads(Path(path).read_text(encoding="utf-8"))


def round_trip(spec: dict[str, Any]) -> dict[str, Any]:
    """Serialize then deserialize; used for lossless round-trip tests."""
    return loads(dumps(spec))


def validate_schema(spec: dict[str, Any]) -> dict[str, Any]:
    """Validate against common PlotSpec JSON Schema.

    Returns structured result: {valid, errors:[{code,field,message}], warnings:[]}
    Prefer jsonschema if installed; otherwise a lightweight required-field check.
    """
    errors: list[dict[str, str]] = []
    warnings: list[dict[str, str]] = []
    schema = load_schema()

    try:
        import jsonschema
        from jsonschema import Draft202012Validator

        validator = Draft202012Validator(schema)
        for err in sorted(validator.iter_errors(spec), key=lambda e: list(e.path)):
            field = ".".join(str(p) for p in err.path) or "(root)"
            errors.append(
                {
                    "code": "SCHEMA_VALIDATION",
                    "field": field,
                    "message": err.message,
                }
            )
    except ImportError:
        warnings.append(
            {
                "code": "JSONSCHEMA_MISSING",
                "field": "",
                "message": "jsonschema not installed; using lightweight validation only.",
            }
        )
        for req in schema.get("required") or []:
            if req not in spec:
                errors.append(
                    {
                        "code": "MISSING_REQUIRED",
                        "field": req,
                        "message": f"Missing required field '{req}'",
                    }
                )
        if spec.get("spec_version") != "1.0":
            errors.append(
                {
                    "code": "BAD_SPEC_VERSION",
                    "field": "spec_version",
                    "message": "spec_version must be '1.0'",
                }
            )
        skill = spec.get("skill")
        if not isinstance(skill, dict) or not skill.get("id") or not skill.get("version"):
            errors.append(
                {
                    "code": "BAD_SKILL",
                    "field": "skill",
                    "message": "skill.id and skill.version are required",
                }
            )
        if not isinstance(spec.get("mapping"), dict):
            errors.append(
                {
                    "code": "BAD_MAPPING",
                    "field": "mapping",
                    "message": "mapping must be an object",
                }
            )
        export = spec.get("export")
        if not isinstance(export, dict) or not export.get("format"):
            errors.append(
                {
                    "code": "BAD_EXPORT",
                    "field": "export",
                    "message": "export.format is required",
                }
            )

    # Soft guard: no executable code blobs
    transform = spec.get("transform") or {}
    if isinstance(transform, dict) and "code" in transform:
        errors.append(
            {
                "code": "EXECUTABLE_TRANSFORM_FORBIDDEN",
                "field": "transform.code",
                "message": "Arbitrary transform.code is forbidden; use declarative filters.",
            }
        )

    return {"valid": len(errors) == 0, "errors": errors, "warnings": warnings}


def empty_spec(skill_id: str, skill_version: str = "1.0.0") -> dict[str, Any]:
    return {
        "spec_version": "1.0",
        "skill": {"id": skill_id, "version": skill_version},
        "input": {},
        "mapping": {},
        "transform": {},
        "statistics": {"method": None, "multiple_testing": None},
        "visual": {},
        "export": {"format": "svg", "formats": ["svg", "pdf", "png"], "dpi": 300},
        "legacy_params": {},
        "provenance": {
            "generated_by_ai": False,
            "user_modified": False,
            "framework_version": __version__,
        },
    }


def merge_defaults(spec: dict[str, Any], defaults: dict[str, Any]) -> dict[str, Any]:
    """Shallow-merge defaults under visual/export/statistics without inventing science."""
    out = copy.deepcopy(spec)
    for section in ("visual", "export", "statistics", "transform"):
        base = defaults.get(section) or defaults.get(f"{section}_defaults") or {}
        if not isinstance(base, dict):
            continue
        cur = out.setdefault(section, {})
        if not isinstance(cur, dict):
            continue
        for k, v in base.items():
            if k not in cur or cur[k] is None:
                cur[k] = copy.deepcopy(v)
    # scientific_defaults must not silently fill consequential fields
    sci = defaults.get("scientific_defaults") or {}
    if isinstance(sci, dict):
        stats = out.setdefault("statistics", {})
        for k, v in sci.items():
            if v is None:
                continue  # null means "must be explicit"
            if k not in stats or stats[k] is None:
                stats[k] = copy.deepcopy(v)
    return out
