"""Generate plugins/<id>/vnext/metadata.yaml for every plugin.

Mechanical detection (no science is invented here):
  * column parameters: schema ``type: column(s)``, ``*_column(s)``/``*_col`` names,
    or ``*_by`` / other parameters whose example values are input column names;
  * autodetect candidates from schema defaults and "(default autodetect: a, b)" help text;
  * input fields from config.yaml.
Curated knowledge (roles for ambiguous parameters, families, statistics
parameters, required roles, guardrails) comes from vnext/migrate/rules.yaml.
"""
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

import yaml

ROOT = Path(__file__).resolve().parents[2]
PLUGIN_DIR = ROOT / "plugins"
RULES_PATH = Path(__file__).with_name("rules.yaml")
GENERATOR_VERSION = "1.0"

COLUMN_NAME = re.compile(r"_(columns?|cols?)$")
STEM = re.compile(r"_(columns?|cols?|by)$")
AUTODETECT = re.compile(r"autodetect:\s*([^)]+)\)", re.I)
# Parameters that hold labels/titles even when their text equals a column name.
NEVER_ROLE = {"title", "subtitle", "xlab", "ylab", "legend_title", "legend_name", "plugin_id", "dispatch_mode"}
# With only example-value evidence, these names are labels/options/selections, not mappings.
NOT_MAPPING_NAME = re.compile(r"(_label|_title|_name|lab|_mode|_method|_order|_include|_exclude|_levels)$")


def load_rules(path: Path | None = None) -> dict[str, Any]:
    return yaml.safe_load((path or RULES_PATH).read_text(encoding="utf-8")) or {}


def _schema_fields(plugin_dir: Path) -> dict[str, dict[str, Any]]:
    from plot_web.schema_normalize import normalize_params_schema

    path = plugin_dir / "params_schema.json"
    if not path.is_file():
        return {}
    norm = normalize_params_schema(json.loads(path.read_text(encoding="utf-8"))) or {}
    return {k: v for sec in norm.values() if isinstance(sec, dict) for k, v in sec.items() if isinstance(v, dict)}


def _header(path: Path) -> set[str]:
    if path.suffix.lower() not in {".csv", ".tsv", ".txt"} or not path.is_file():
        return set()
    with path.open(encoding="utf-8", errors="ignore") as handle:
        line = handle.readline().rstrip("\r\n")
    delim = "\t" if line.count("\t") > line.count(",") else ","
    return {c.strip().strip('"') for c in line.split(delim)}


def _example_observations(plugin_dir: Path) -> list[tuple[dict[str, Any], set[str]]]:
    """(params, union of input column names) for every example bundle."""
    out = []
    for manifest_path in sorted((plugin_dir / "examples").glob("*/manifest.json")):
        bundle = manifest_path.parent
        try:
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            params = json.loads((bundle / str(manifest.get("params") or "params.json")).read_text(encoding="utf-8"))
        except Exception:
            continue
        columns: set[str] = set()
        for rel in (manifest.get("inputs") or {}).values():
            if isinstance(rel, str):
                columns |= _header(bundle / rel)
        if isinstance(params, dict):
            out.append((params, columns))
    return out


def _is_column_value(value: Any, columns: set[str]) -> bool:
    values = value if isinstance(value, list) else [value]
    return bool(values) and all(isinstance(v, str) for v in values) and any(v in columns for v in values)


def detect_column_params(fields: dict[str, dict[str, Any]], observations: list[tuple[dict[str, Any], set[str]]]) -> dict[str, dict[str, Any]]:
    """Return {param: {"multiple": bool, "evidence": [...]}} for column-mapping parameters."""
    found: dict[str, dict[str, Any]] = {}

    def add(param: str, evidence: str, multiple: bool | None = None) -> None:
        entry = found.setdefault(param, {"multiple": False, "evidence": []})
        if evidence not in entry["evidence"]:
            entry["evidence"].append(evidence)
        if multiple:
            entry["multiple"] = True

    enumerated = {k for k, v in fields.items() if v.get("type") == "select" or v.get("options") or v.get("enum")}
    for key, field in fields.items():
        if key in NEVER_ROLE or "tooltip" in key:  # tooltips may name fields computed by the plugin
            continue
        if field.get("type") in {"column", "columns"}:
            add(key, "schema_type", field.get("type") == "columns")
        elif COLUMN_NAME.search(key) and key not in enumerated:
            add(key, "name")

    observed: dict[str, list[bool]] = {}
    for params, columns in observations:
        for key, value in params.items():
            if key in NEVER_ROLE or "tooltip" in key or value in (None, "", []):
                continue
            observed.setdefault(key, []).append(_is_column_value(value, columns))

    list_valued = {k for params, _ in observations for k, v in params.items() if isinstance(v, list)}
    for key, hits in observed.items():
        if key in enumerated:
            continue
        if all(hits):
            named = key in found or key.endswith("_by")
            if not named and (NOT_MAPPING_NAME.search(key) or key in list_valued):
                continue  # e.g. axis_arrow_x_label="dim1", group_order=[...]: coincidental matches
            # Every example value names an input column (covers *_by and unsuffixed keys).
            add(key, "example_values")
        elif key in found and not any(hits) and "schema_type" not in found[key]["evidence"]:
            # Named like a column but every example value is not a column (e.g. a colour vector).
            found.pop(key)
    for params, columns in observations:
        for key, value in params.items():
            if key in found and isinstance(value, list):
                found[key]["multiple"] = True
    return found


def _stem(param: str) -> str:
    return STEM.sub("", param)


def assign_role(param: str, rules: dict[str, Any], family: str | None, taken: set[str]) -> tuple[str, bool]:
    """Map a parameter to a canonical role, falling back to a plugin-local role name."""
    stem = _stem(param).lower()
    overrides = (rules.get("family_role_overrides") or {}).get(family or "", {})
    for role, spec in (rules.get("roles") or {}).items():
        if stem in [a.lower() for a in spec.get("aliases") or []]:
            role = overrides.get(role, role)
            if role not in taken:
                return role, True
            break
    # Plugin-local role: unique, never collides with a canonical name.
    local = stem if stem not in (rules.get("roles") or {}) else param
    while local in taken:
        local = f"{local}_2"
    return local, False


def _autodetect(field: dict[str, Any]) -> list[str]:
    out: list[str] = []
    default = field.get("default")
    if isinstance(default, str) and default:
        out.append(default)
    match = AUTODETECT.search(str(field.get("help") or ""))
    if match:
        out.extend(x.strip() for x in match.group(1).split(",") if x.strip())
    return list(dict.fromkeys(out))


def family_of(plugin_id: str, rules: dict[str, Any]) -> str:
    for family, members in (rules.get("families") or {}).items():
        if plugin_id in (members or []):
            return family
    return "other"


def generate_metadata(plugin_dir: Path, rules: dict[str, Any] | None = None) -> dict[str, Any]:
    from plot_web.server.runner import declared_inputs

    rules = rules or load_rules()
    plugin_id = plugin_dir.name
    config = yaml.safe_load((plugin_dir / "config.yaml").read_text(encoding="utf-8")) or {}
    fields = _schema_fields(plugin_dir)
    observations = _example_observations(plugin_dir)
    family = family_of(plugin_id, rules)
    curated = (rules.get("skills") or {}).get(plugin_id) or {}

    detected = detect_column_params(fields, observations)
    for param in curated.get("not_roles") or []:
        detected.pop(param, None)
    curated_roles = curated.get("roles") or {}
    for param in curated_roles.values():
        detected.setdefault(param, {"multiple": False, "evidence": []})
        if "curated" not in detected[param]["evidence"]:
            detected[param]["evidence"].append("curated")

    known_params = set(fields) | {k for params, _ in observations for k in params}
    warnings = [f"curated parameter '{p}' not found in schema or examples" for p in curated_roles.values() if p not in known_params]

    roles: dict[str, dict[str, Any]] = {}
    taken: set[str] = set()
    param_to_role = {param: role for role, param in curated_roles.items()}
    for role in curated_roles:
        taken.add(role)
    canonical_names = set(rules.get("roles") or {})
    # Curated first, then parameters whose stem *is* a role name (group_column before cluster_column).
    for param in sorted(detected, key=lambda p: (p not in param_to_role, _stem(p).lower() not in canonical_names, p)):
        info = detected[param]
        if param in param_to_role:
            role, canonical = param_to_role[param], param_to_role[param] in (rules.get("roles") or {})
        else:
            role, canonical = assign_role(param, rules, family, taken)
            taken.add(role)
        role_spec = (rules.get("roles") or {}).get(role, {}) if canonical else {}
        entry: dict[str, Any] = {
            "param": param,
            "canonical": canonical,
            "kind": role_spec.get("kind", "any"),
            "multiple": bool(info.get("multiple")),
            "evidence": sorted(info["evidence"]),
        }
        candidates = _autodetect(fields.get(param, {})) + list((curated.get("autodetect") or {}).get(role) or [])
        candidates = list(dict.fromkeys(candidates))
        if candidates:
            entry["autodetect"] = candidates
        roles[role] = entry

    statistics = {k: v for k, v in (curated.get("statistics") or {}).items() if v in known_params}
    warnings += [f"statistics parameter '{v}' not found" for v in (curated.get("statistics") or {}).values() if v not in known_params]

    existing = {}
    meta_path = plugin_dir / "vnext" / "metadata.yaml"
    if meta_path.is_file():
        existing = yaml.safe_load(meta_path.read_text(encoding="utf-8")) or {}

    return {
        "id": plugin_id,
        "version": str(existing.get("version") or config.get("version") or "1.0.0"),
        "family": family,
        "name": config.get("display_name") or config.get("name") or plugin_id,
        "aliases": existing.get("aliases") or [],
        "accepts": existing.get("accepts") or ["table"],
        "inputs": [
            {"id": str(i["id"]), "required": bool(i.get("required", False))} for i in declared_inputs(config)
        ] or [{"id": "input", "required": True}],
        "roles": roles,
        "role_aliases": curated.get("role_aliases") or {},
        "required_roles": curated.get("required_roles") or [],
        "statistics": statistics,
        "visual": curated.get("visual") or {},
        "transform_hook": curated.get("transform_hook"),
        "guardrails": curated.get("guardrails") or existing.get("guardrails") or [],
        "capabilities": {
            **(existing.get("capabilities") or {}),
            "interactive": "interactive" in plugin_id or bool((existing.get("capabilities") or {}).get("interactive")),
            "vnext_migrated": True,
        },
        "legacy": {"entrypoint": config.get("entrypoint") or "plot.R", "language": config.get("language") or "R",
                   "params_schema": "params_schema.json"},
        "generated": {
            "by": "vnext.migrate",
            "generator_version": GENERATOR_VERSION,
            "curated": bool(curated) and curated.get("curated", True) is not False,
            "n_examples_scanned": len(observations),
            "warnings": warnings,
        },
    }


def write_metadata(meta: dict[str, Any], plugin_dir: Path) -> Path:
    path = plugin_dir / "vnext" / "metadata.yaml"
    path.parent.mkdir(parents=True, exist_ok=True)
    header = (
        "# Generated by `python -m vnext.cli migrate`; edit vnext/migrate/rules.yaml\n"
        "# (not this file) to change roles, families or statistics mappings.\n"
    )
    path.write_text(header + yaml.safe_dump(meta, sort_keys=False, allow_unicode=True), encoding="utf-8")
    return path


def migrate(plugin_ids: list[str] | None = None) -> list[dict[str, Any]]:
    rules = load_rules()
    dirs = [PLUGIN_DIR / pid for pid in plugin_ids] if plugin_ids else sorted(p.parent for p in PLUGIN_DIR.glob("*/config.yaml"))
    results = []
    for plugin_dir in dirs:
        meta = generate_metadata(plugin_dir, rules)
        write_metadata(meta, plugin_dir)
        results.append(meta)
    return results
