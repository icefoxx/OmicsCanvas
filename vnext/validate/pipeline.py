"""Deterministic validation boundary: schema → registry → scientific."""
from __future__ import annotations

from pathlib import Path
from typing import Any

from vnext.plotspec.model import validate_schema
from vnext.registry.loader import get_skill, load_registry, validate_registry
from vnext.validate.scientific import validate_scientific


def validate_plotspec(
    spec: dict[str, Any],
    *,
    table_path: Path | str | None = None,
    tables: dict[str, Path] | None = None,
    skip_scientific: bool = False,
) -> dict[str, Any]:
    """Full validation crossing the deterministic boundary.

    After this returns valid=True, rendering must not call an LLM.
    """
    schema_res = validate_schema(spec)
    reg = load_registry()
    reg_res = validate_registry(reg)

    skill_id = ((spec.get("skill") or {}).get("id")) or ""
    skill = get_skill(skill_id, reg)
    skill_errors: list[dict[str, str]] = []
    if not skill:
        skill_errors.append(
            {
                "code": "UNKNOWN_SKILL",
                "field": "skill.id",
                "message": f"Skill '{skill_id}' is not in the registry.",
                "severity": "error",
            }
        )
    elif skill.get("version") and spec.get("skill", {}).get("version") not in {skill.get("version"), "1.0.0"}:
        # soft: allow skill version drift as warning
        skill_errors.append(
            {
                "code": "SKILL_VERSION_MISMATCH",
                "field": "skill.version",
                "message": f"Spec version {spec.get('skill', {}).get('version')} differs from registry {skill.get('version')}.",
                "severity": "warning",
            }
        )

    sci_res: dict[str, Any] = {"valid": True, "errors": [], "warnings": [], "infos": []}
    has_tables = bool(table_path or tables)
    if not skip_scientific and has_tables:
        family = (skill or {}).get("family")
        sci_res = validate_scientific(spec, table_path=Path(table_path) if table_path else None, tables=tables, family=family)

    errors = list(schema_res.get("errors") or [])
    warnings = list(schema_res.get("warnings") or [])
    errors.extend([e for e in (reg_res.get("errors") or [])])
    warnings.extend(reg_res.get("warnings") or [])
    for e in skill_errors:
        if e.get("severity") == "error":
            errors.append(e)
        else:
            warnings.append(e)
    errors.extend(sci_res.get("errors") or [])
    warnings.extend(sci_res.get("warnings") or [])

    return {
        "valid": len(errors) == 0 and schema_res.get("valid", False) and (sci_res.get("valid", True) if has_tables else True) and not any(
            e.get("code") == "UNKNOWN_SKILL" for e in skill_errors
        ),
        "errors": errors,
        "warnings": warnings,
        "infos": sci_res.get("infos") or [],
        "layers": {
            "schema": schema_res,
            "registry": {"valid": reg_res.get("valid"), "n_skills": reg_res.get("n_skills")},
            "scientific": sci_res if has_tables else None,
            "skill": skill,
        },
    }
