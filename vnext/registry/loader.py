"""Skill registry loader + validator."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import yaml

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_REGISTRY = Path(__file__).with_name("registry.yaml")
PLUGIN_DIR = ROOT / "plugins"


def _read_yaml(path: Path) -> dict[str, Any]:
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(data, dict):
        raise ValueError(f"Registry must be a mapping: {path}")
    return data


def load_registry(path: Path | None = None) -> dict[str, Any]:
    path = path or DEFAULT_REGISTRY
    if not path.exists():
        return {"registry_version": "1.0", "skills": []}
    return _read_yaml(path)


def skills_by_id(registry: dict[str, Any] | None = None) -> dict[str, dict[str, Any]]:
    reg = registry or load_registry()
    out: dict[str, dict[str, Any]] = {}
    for skill in reg.get("skills") or []:
        if not isinstance(skill, dict):
            continue
        sid = skill.get("id")
        if not sid:
            continue
        if sid in out:
            raise ValueError(f"Duplicate skill id in registry: {sid}")
        out[sid] = skill
    return out


def get_skill(skill_id: str, registry: dict[str, Any] | None = None) -> dict[str, Any] | None:
    return skills_by_id(registry).get(skill_id)


def validate_registry(registry: dict[str, Any] | None = None) -> dict[str, Any]:
    reg = registry or load_registry()
    errors: list[dict[str, str]] = []
    warnings: list[dict[str, str]] = []
    seen: set[str] = set()
    alias_seen: dict[str, str] = {}

    skills = reg.get("skills")
    if not isinstance(skills, list):
        return {
            "valid": False,
            "errors": [{"code": "NO_SKILLS", "field": "skills", "message": "skills must be a list"}],
            "warnings": [],
        }

    for i, skill in enumerate(skills):
        field = f"skills[{i}]"
        if not isinstance(skill, dict):
            errors.append({"code": "BAD_SKILL_ENTRY", "field": field, "message": "skill must be object"})
            continue
        sid = skill.get("id")
        if not sid:
            errors.append({"code": "MISSING_ID", "field": field, "message": "skill.id required"})
            continue
        if sid in seen:
            errors.append({"code": "DUPLICATE_ID", "field": field, "message": f"duplicate id {sid}"})
        seen.add(sid)
        if not skill.get("version"):
            errors.append({"code": "MISSING_VERSION", "field": f"{field}.version", "message": "version required"})
        plugin_path = PLUGIN_DIR / str(sid)
        if not plugin_path.is_dir():
            warnings.append(
                {
                    "code": "PLUGIN_DIR_MISSING",
                    "field": f"{field}.id",
                    "message": f"plugins/{sid} directory not found",
                }
            )
        for alias in skill.get("aliases") or []:
            a = str(alias).strip().lower()
            if not a:
                continue
            if a in alias_seen and alias_seen[a] != sid:
                errors.append(
                    {
                        "code": "ALIAS_COLLISION",
                        "field": f"{field}.aliases",
                        "message": f"alias '{alias}' also used by {alias_seen[a]}",
                    }
                )
            alias_seen[a] = sid

    return {"valid": len(errors) == 0, "errors": errors, "warnings": warnings, "n_skills": len(seen)}


def build_registry_from_plugins(plugin_dir: Path | None = None) -> dict[str, Any]:
    """Generate registry entries from plugins/*/config.yaml (incremental migration helper)."""
    plugin_dir = plugin_dir or PLUGIN_DIR
    skills: list[dict[str, Any]] = []
    for path in sorted(plugin_dir.iterdir()):
        if not path.is_dir() or path.name.startswith("."):
            continue
        cfg_path = path / "config.yaml"
        if not cfg_path.exists():
            continue
        try:
            cfg = yaml.safe_load(cfg_path.read_text(encoding="utf-8")) or {}
        except Exception:
            continue
        if not isinstance(cfg, dict):
            continue
        sid = str(cfg.get("id") or path.name)
        family = str(cfg.get("category") or cfg.get("family") or "miscellaneous").lower()
        entry = {
            "id": sid,
            "version": str(cfg.get("version") or "1.0.0"),
            "family": family,
            "name": cfg.get("display_name") or cfg.get("name") or sid,
            "aliases": [],
            "accepts": ["table"],
            "required_semantics": [],
            "optional_semantics": [],
            "capabilities": {
                "interactive": "interactive" in sid,
                "statistics": False,
                "export_svg": True,
                "export_pdf": True,
                "export_png": True,
                "legacy_params": True,
                "vnext_migrated": (path / "vnext" / "metadata.yaml").exists(),
            },
            "guardrails": [],
            "entrypoint": cfg.get("entrypoint") or "plot.R",
            "language": cfg.get("language") or "R",
            "status": cfg.get("status") or "unknown",
        }
        # Enrich known reference skill
        if sid == "interactive_enrichment_lollipop":
            entry["aliases"] = [
                "enrichment lollipop",
                "signed enrichment plot",
                "Cleveland enrichment plot",
                "pathway lollipop",
            ]
            entry["accepts"] = ["enrichment_table"]
            entry["required_semantics"] = ["category", "signed_effect"]
            entry["optional_semantics"] = ["adjusted_pvalue", "pvalue", "gene_count", "group", "size"]
            entry["guardrails"] = ["require_signed_metric", "distinguish_raw_p_and_fdr"]
            entry["capabilities"]["vnext_migrated"] = True
        skills.append(entry)

    return {
        "registry_version": "1.0",
        "framework": "omicscanvas-vnext",
        "generated_from": "plugins/*/config.yaml",
        "skills": skills,
    }


def write_registry(registry: dict[str, Any], path: Path | None = None) -> Path:
    path = path or DEFAULT_REGISTRY
    path.write_text(
        yaml.safe_dump(registry, sort_keys=False, allow_unicode=True),
        encoding="utf-8",
    )
    return path


def find_by_alias(query: str, registry: dict[str, Any] | None = None) -> list[dict[str, Any]]:
    q = (query or "").strip().lower()
    if not q:
        return []
    hits = []
    for skill in (registry or load_registry()).get("skills") or []:
        sid = str(skill.get("id") or "").lower()
        name = str(skill.get("name") or "").lower()
        aliases = [str(a).lower() for a in (skill.get("aliases") or [])]
        score = 0
        if q == sid or q in sid:
            score += 5
        if q in name:
            score += 3
        if any(q in a or a in q for a in aliases):
            score += 4
        if score:
            hits.append({**skill, "_score": score})
    hits.sort(key=lambda x: -x["_score"])
    return hits
