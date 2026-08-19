"""Normalize heterogeneous plugin params_schema formats into sectioned maps.

Editor and Gallery both expect: { section_name: { param_key: {type, label, ...} } }.
Some plugins ship JSON-Schema or groups wrappers — flatten them here.
"""
from __future__ import annotations

import re
from typing import Any


def _leaf_from_jsonschema(raw: Any, key: str) -> dict[str, Any]:
    if not isinstance(raw, dict):
        return {"help": str(raw), "label": key.replace("_", " ").title()}
    out: dict[str, Any] = {"label": key.replace("_", " ").title()}
    t = raw.get("type")
    if t == "array":
        out["type"] = "string_array"
    elif t == "integer":
        out["type"] = "number"
    elif t in {"boolean", "number", "string", "object", "color", "column", "columns", "textarea"}:
        out["type"] = t
    elif t:
        out["type"] = str(t)
    if "enum" in raw and isinstance(raw["enum"], list):
        out["type"] = "select"
        out["options"] = raw["enum"]
    if "options" in raw and isinstance(raw["options"], list):
        out["options"] = raw["options"]
        out.setdefault("type", "select")
    if "default" in raw:
        out["default"] = raw["default"]
    help_text = raw.get("help") or raw.get("description")
    if help_text:
        out["help"] = str(help_text)
    if raw.get("required") is not None:
        out["required"] = bool(raw["required"])
    if raw.get("label"):
        out["label"] = raw["label"]
    return out


def _leaf_from_loose(raw: Any, key: str) -> dict[str, Any]:
    if isinstance(raw, dict):
        return _leaf_from_jsonschema(raw, key)
    text = str(raw or "")
    m = re.match(r"select\((.*)\)$", text, re.I)
    if m:
        opts = [x.strip() for x in m.group(1).split(",") if x.strip()]
        return {"type": "select", "options": opts, "label": key.replace("_", " ").title()}
    type_map = {
        "column": "column",
        "columns": "columns",
        "string": "string",
        "number": "number",
        "integer": "number",
        "boolean": "boolean",
        "color": "color",
        "object": "object",
        "array": "string_array",
        "json": "json",
        "textarea": "textarea",
    }
    if text.lower() in type_map:
        return {"type": type_map[text.lower()], "label": key.replace("_", " ").title()}
    return {"help": text, "label": key.replace("_", " ").title()}


def normalize_params_schema(schema: dict[str, Any] | None) -> dict[str, Any] | None:
    """Return a sectioned param map, or None if empty."""
    if not isinstance(schema, dict) or not schema:
        return schema

    # groups wrapper (network-style)
    groups = schema.get("groups")
    if isinstance(groups, dict) and groups:
        props = schema.get("properties") if isinstance(schema.get("properties"), dict) else {}
        out: dict[str, Any] = {}
        for sec, keys in groups.items():
            leaf: dict[str, Any] = {}
            if isinstance(keys, list):
                for key in keys:
                    raw = props.get(key, key)
                    leaf[str(key)] = _leaf_from_loose(raw, str(key))
            elif isinstance(keys, dict):
                for key, raw in keys.items():
                    val = props.get(key, raw)
                    leaf[str(key)] = _leaf_from_loose(val, str(key))
            if leaf:
                out[str(sec)] = leaf
        if out:
            return out

    # nested JSON-Schema properties
    props = schema.get("properties")
    if isinstance(props, dict) and props:
        nested = any(isinstance(v, dict) and isinstance(v.get("properties"), dict) for v in props.values())
        if nested:
            out = {}
            for sec, defn in props.items():
                if isinstance(defn, dict) and isinstance(defn.get("properties"), dict):
                    leaf = {
                        str(k): _leaf_from_jsonschema(v, str(k))
                        for k, v in defn["properties"].items()
                    }
                    out[str(sec)] = leaf
                else:
                    out[str(sec)] = {str(sec): _leaf_from_jsonschema(defn, str(sec))}
            return out
        if schema.get("type") == "object" or schema.get("$schema"):
            return {
                "Parameters": {
                    str(k): _leaf_from_jsonschema(v, str(k)) for k, v in props.items()
                }
            }

    # already sectioned — light normalize of string leaves
    meta = {"plugin", "title", "type", "$schema", "groups", "properties", "description"}
    out = {}
    for sec, entries in schema.items():
        if sec in meta:
            continue
        if not isinstance(entries, dict):
            continue
        leaf = {}
        for key, raw in entries.items():
            leaf[str(key)] = _leaf_from_loose(raw, str(key))
        if leaf:
            out[str(sec)] = leaf
    return out or schema
