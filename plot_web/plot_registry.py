"""Central plot registry: scan plugins, overlay curated metadata, query, validate.

This is the metadata layer from docs/design/01_plot_registry_refactor_v1.0.md.
It does not change plotting engines.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

import yaml

from plot_web.yaml_cache import load_yaml_cached

ROOT = Path(__file__).resolve().parents[1]
PLUGIN_DIR = ROOT / "plugins"
REG_DIR = Path(__file__).resolve().parent / "registry"
VOCAB_PATH = REG_DIR / "vocab.yaml"
OVERRIDES_PATH = REG_DIR / "overrides.yaml"
GENERATED_PATH = REG_DIR / "registry.json"
REPORT_DIR = REG_DIR / "reports"

DEFAULT_PRESETS = [
    {"id": "recommended", "name": "Recommended"},
    {"id": "publication", "name": "Publication"},
    {"id": "minimal", "name": "Minimal"},
    {"id": "blank", "name": "Blank"},
    {"id": "large_dataset", "name": "Large dataset"},
]

DEFAULT_PARAMETER_GROUPS = [
    "data_mapping",
    "marks",
    "colors",
    "labels",
    "legend",
    "axes",
    "theme",
    "layout",
    "statistics",
    "export",
]


def _read_yaml(path: Path) -> dict[str, Any]:
    data = load_yaml_cached(path) or {}
    return data if isinstance(data, dict) else {}


def load_vocab() -> dict[str, Any]:
    return _read_yaml(VOCAB_PATH)


def load_overrides() -> dict[str, Any]:
    return _read_yaml(OVERRIDES_PATH)


def _plugin_config(plugin_dir: Path) -> dict[str, Any]:
    cfg_path = plugin_dir / "config.yaml"
    if not cfg_path.exists():
        return {}
    try:
        data = yaml.safe_load(cfg_path.read_text(encoding="utf-8")) or {}
    except Exception:
        return {}
    return data if isinstance(data, dict) else {}


def _example_records(plugin_dir: Path) -> list[dict[str, Any]]:
    idx = plugin_dir / "examples" / "index.json"
    records: list[dict[str, Any]] = []
    if idx.exists():
        try:
            raw = json.loads(idx.read_text(encoding="utf-8"))
        except Exception:
            raw = None
        examples = raw.get("examples", raw) if isinstance(raw, dict) else raw
        if isinstance(examples, list):
            for item in examples:
                if isinstance(item, dict) and item.get("id"):
                    records.append(item)
    if records:
        return records
    examples_root = plugin_dir / "examples"
    if not examples_root.is_dir():
        return []
    for bundle in sorted(examples_root.iterdir()):
        if bundle.is_dir() and (bundle / "params.json").exists():
            records.append({"id": bundle.name, "label": bundle.name})
    return records


def _gallery_png(plugin_id: str, example_id: str) -> str | None:
    gallery = PLUGIN_DIR / plugin_id / "all_examples_gallery"
    for name in (f"{example_id}.png", f"{example_id}_1.png"):
        path = gallery / name
        if path.is_file():
            return f"plugins/{plugin_id}/all_examples_gallery/{name}"
    return None


def _heuristic_class(example_id: str) -> dict[str, Any]:
    eid = example_id.lower()
    if eid.startswith("pdf_repro_"):
        return {"class": "demo"}
    if eid.startswith("pdf_"):
        return {"class": "export"}
    if eid in {"raster"}:
        return {"class": "rendering"}
    if any(tok in eid for tok in ("blank", "theme", "minimal", "publication")):
        return {"class": "preset"}
    if any(tok in eid for tok in ("axis", "label", "legend", "font", "margin")):
        return {"class": "parameter", "parameter_group": "labels"}
    if any(tok in eid for tok in ("bg_", "background", "cutoff")):
        return {"class": "parameter", "parameter_group": "background"}
    if any(tok in eid for tok in ("layout", "custom_layout")):
        return {"class": "parameter", "parameter_group": "layout"}
    if eid in {"basic", "params", "group"}:
        return {"class": "demo"}
    return {"class": "variant"}


def _variant_id_from_example(example_id: str, class_info: dict[str, Any]) -> str:
    mapped = (class_info.get("maps_to") or {}).get("variant")
    if mapped:
        return str(mapped)
    eid = example_id.lower()
    eid = re.sub(r"^pdf_repro_", "", eid)
    eid = re.sub(r"^pdf_", "", eid)
    return eid or example_id


def _aliases_from_name(name: str, plugin_id: str) -> list[str]:
    stop = {
        "plot",
        "the",
        "and",
        "for",
        "with",
        "from",
        "advanced",
        "interactive",
        "basic",
        "new",
    }
    bits = re.split(r"[\s/_-]+", (name or "").lower())
    out = [plugin_id.replace("_", " "), (name or "").lower()]
    out.extend(b for b in bits if len(b) > 2 and b not in stop)
    seen: set[str] = set()
    uniq: list[str] = []
    for a in out:
        a = a.strip()
        if a and a not in seen and a not in stop:
            seen.add(a)
            uniq.append(a)
    return uniq


def _family_defaults(plugin_id: str, cfg: dict[str, Any]) -> dict[str, Any]:
    name = str(cfg.get("display_name") or cfg.get("name") or plugin_id)
    category = str(cfg.get("category") or "")
    return {
        "id": plugin_id,
        "engine_plugin_id": plugin_id,
        "name": name,
        "short_name": name,
        "description": str(cfg.get("description") or ""),
        "aliases": _aliases_from_name(name, plugin_id),
        "categories": [c for c in [category] if c],
        "analysis_contexts": [],
        "tasks": [],
        "data_requirements": {
            "required_roles": [],
            "optional_roles": [],
            "accepted_types": {},
        },
        "parameter_groups": list(DEFAULT_PARAMETER_GROUPS),
        "presets": [dict(p) for p in DEFAULT_PRESETS],
        "variants": [],
        "demos": [],
        "legacy_presets": {},
        "recommendation_rules": [],
        "entrypoint": cfg.get("entrypoint") or "plot.R",
        "language": cfg.get("language") or "R",
        "status": cfg.get("status") or "unknown",
        "version": str(cfg.get("version") or "1.0.0"),
    }


def _context_guess(plugin_id: str, category: str) -> tuple[list[str], list[str]]:
    text = f"{plugin_id} {category}".lower()
    contexts: list[str] = []
    tasks: list[str] = []
    if any(k in text for k in ("dim", "umap", "feature", "lineage", "density")):
        contexts.append("single_cell")
    if "volcano" in text or "differential" in text:
        contexts.append("differential_expression")
        tasks.append("differential_expression")
    if any(k in text for k in ("gsea", "enrich", "fgsea", "lollipop")):
        contexts.append("functional_enrichment")
        tasks.extend(["gsea", "ora"])
    if any(k in text for k in ("heatmap", "dot_plot", "dotplot")):
        tasks.append("heatmap")
        contexts.append("gene_expression")
    if any(k in text for k in ("venn", "upset")):
        contexts.append("relationships_overlap")
        tasks.append("overlap")
    if "network" in text or "sankey" in text or "alluvial" in text:
        contexts.append("relationships_overlap")
        tasks.append("network")
    if "violin" in text or "histogram" in text or "ridge" in text:
        contexts.append("general_statistics")
        tasks.append("distribution")
    if "volcano" in text:
        contexts.append("differential_expression")
    if not contexts:
        contexts.append("general_statistics")
    if not tasks:
        tasks.append("group_comparison")
    return list(dict.fromkeys(contexts)), list(dict.fromkeys(tasks))


def build_registry(plugin_dir: Path | None = None) -> dict[str, Any]:
    plugin_dir = plugin_dir or PLUGIN_DIR
    vocab = load_vocab()
    overrides = load_overrides()
    family_id_map: dict[str, str] = dict(overrides.get("family_id_map") or {})
    family_over: dict[str, Any] = dict(overrides.get("families") or {})

    families: dict[str, dict[str, Any]] = {}
    classifications: list[dict[str, Any]] = []

    for path in sorted(plugin_dir.iterdir()):
        if not path.is_dir() or path.name.startswith("."):
            continue
        if not (path / "config.yaml").exists():
            continue
        plugin_id = path.name
        cfg = _plugin_config(path)
        family_id = family_id_map.get(plugin_id, plugin_id)
        family = families.get(family_id) or _family_defaults(plugin_id, cfg)
        family["id"] = family_id
        family["engine_plugin_id"] = plugin_id
        overlay = family_over.get(family_id) or {}
        for key in (
            "name",
            "short_name",
            "description",
            "aliases",
            "categories",
            "analysis_contexts",
            "tasks",
            "data_requirements",
            "recommendation_rules",
            "legacy_presets",
            "gallery",
            "status",
            "extra_gallery",
        ):
            if overlay.get(key) not in (None, [], {}):
                family[key] = overlay[key]
        if not family.get("analysis_contexts"):
            ctx, tasks = _context_guess(plugin_id, str(cfg.get("category") or ""))
            family["analysis_contexts"] = ctx
            if not family.get("tasks"):
                family["tasks"] = tasks
        if overlay.get("aliases"):
            merged = list(family.get("aliases") or [])
            for a in overlay["aliases"]:
                if a not in merged:
                    merged.append(a)
            family["aliases"] = merged

        example_class = dict(overlay.get("example_classifications") or {})
        curated_variants = {v["id"]: v for v in overlay.get("variants") or [] if v.get("id")}
        variants: dict[str, dict[str, Any]] = dict(curated_variants)
        demos: list[dict[str, Any]] = []

        for rec in _example_records(path):
            eid = str(rec.get("id"))
            info = dict(example_class.get(eid) or _heuristic_class(eid))
            kind = str(info.get("class") or "uncertain")
            variant_id = _variant_id_from_example(eid, info)
            preview = _gallery_png(plugin_id, eid)
            classifications.append(
                {
                    "plugin_id": plugin_id,
                    "family_id": family_id,
                    "example_id": eid,
                    "label": rec.get("label") or eid,
                    "plot_type": rec.get("plot_type"),
                    "classification": kind,
                    "maps_to": info.get("maps_to")
                    or (
                        {"variant": variant_id, "preset": "recommended"}
                        if kind in {"variant", "demo", "export_template", "preset"}
                        else None
                    ),
                    "parameter_group": info.get("parameter_group"),
                    "preview_asset": preview,
                }
            )
            maps = info.get("maps_to") if isinstance(info.get("maps_to"), dict) else None
            dest_variant = (maps or {}).get("variant") or variant_id
            if dest_variant in variants:
                variants[dest_variant].setdefault("legacy_ids", [])
                if eid not in variants[dest_variant]["legacy_ids"]:
                    variants[dest_variant]["legacy_ids"].append(eid)
                if preview and not variants[dest_variant].get("preview_asset"):
                    variants[dest_variant]["preview_asset"] = preview
            elif kind == "variant":
                variants[dest_variant] = {
                    "id": dest_variant,
                    "name": str(rec.get("label") or dest_variant).replace("_", " ").title(),
                    "description": rec.get("blurb") or rec.get("description") or "",
                    "preview_asset": preview,
                    "recommended_for": [],
                    "parameter_groups": list(DEFAULT_PARAMETER_GROUPS),
                    "legacy_ids": [eid],
                }
            if maps or kind in {"demo", "variant", "export_template", "export", "legacy_alias", "preset", "rendering"}:
                demos.append(
                    {
                        "id": eid,
                        "name": rec.get("label") or eid,
                        "variant": dest_variant,
                        "preset": (maps or {}).get("preset") or "recommended",
                        "example_id": eid,
                        "plugin_id": plugin_id,
                        "preview_asset": preview,
                        "parameters": (maps or {}).get("parameters") or {},
                        "gallery_visible": kind in {"demo", "variant"},
                    }
                )
            if maps and kind in {"preset", "export_template", "export", "rendering", "legacy_alias", "parameter"}:
                family.setdefault("legacy_presets", {})
                family["legacy_presets"].setdefault(eid, maps)

        if overlay.get("legacy_presets"):
            family.setdefault("legacy_presets", {})
            family["legacy_presets"].update(overlay["legacy_presets"])

        for variant in variants.values():
            example_id = str(variant.get("representative_example") or "")
            if example_id and not variant.get("preview_asset"):
                variant["preview_asset"] = _gallery_png(plugin_id, example_id)
            variant.setdefault("legacy_ids", [])

        family["variants"] = list(variants.values())
        family["demos"] = demos
        families[family_id] = family

    return {
        "registry_version": "1.0",
        "spec": "01_plot_registry_refactor_v1.0",
        "plots": list(families.values()),
        "classifications": classifications,
        "vocab": {
            "contexts": vocab.get("contexts") or [],
            "tasks": vocab.get("tasks") or [],
            "parameter_groups": vocab.get("parameter_groups") or [],
            "data_roles": vocab.get("data_roles") or [],
        },
    }


def load_registry(rebuild: bool = False) -> dict[str, Any]:
    if rebuild or not GENERATED_PATH.exists():
        reg = build_registry()
        GENERATED_PATH.parent.mkdir(parents=True, exist_ok=True)
        GENERATED_PATH.write_text(json.dumps(reg, indent=2), encoding="utf-8")
    else:
        reg = json.loads(GENERATED_PATH.read_text(encoding="utf-8"))
    from plot_web.plot_guide import attach_guides

    return attach_guides(reg)


def plot_is_listed(plot: dict[str, Any] | None, hidden_ids: set[str] | None = None) -> bool:
    if not plot:
        return False
    if str(plot.get("status") or "").lower() in {"hidden", "retired", "deleted"}:
        return False
    gallery = plot.get("gallery") if isinstance(plot.get("gallery"), dict) else {}
    if gallery.get("visible") is False:
        return False
    hid = hidden_ids if hidden_ids is not None else {str(x).lower() for x in (load_overrides().get("hidden_families") or [])}
    pid = str(plot.get("id") or "").lower()
    engine = str(plot.get("engine_plugin_id") or "").lower()
    return pid not in hid and engine not in hid


def get_all_plots(registry: dict[str, Any] | None = None, *, include_hidden: bool = False) -> list[dict[str, Any]]:
    plots = list((registry or load_registry()).get("plots") or [])
    if include_hidden:
        return plots
    hidden = {str(x).lower() for x in (load_overrides().get("hidden_families") or [])}
    return [p for p in plots if plot_is_listed(p, hidden)]


def get_plot(plot_id: str, registry: dict[str, Any] | None = None) -> dict[str, Any] | None:
    pid = (plot_id or "").strip().lower()
    for plot in get_all_plots(registry):
        if str(plot.get("id")).lower() == pid:
            return plot
        if str(plot.get("engine_plugin_id")).lower() == pid:
            return plot
        aliases = [str(a).lower() for a in plot.get("aliases") or []]
        if pid in aliases:
            return plot
    return None


def get_variants(plot_id: str, registry: dict[str, Any] | None = None) -> list[dict[str, Any]]:
    plot = get_plot(plot_id, registry)
    return list((plot or {}).get("variants") or [])


def variant_is_gallery_visible(variant: dict[str, Any] | None) -> bool:
    if not variant:
        return False
    gallery = variant.get("gallery")
    if not isinstance(gallery, dict):
        return False
    return bool(gallery.get("visible", True))


def visible_variants(plot: dict[str, Any] | str, registry: dict[str, Any] | None = None) -> list[dict[str, Any]]:
    record = plot if isinstance(plot, dict) else get_plot(str(plot), registry)
    variants = list((record or {}).get("variants") or [])
    visible = [v for v in variants if variant_is_gallery_visible(v)]

    def _section_rank(item: dict[str, Any]) -> tuple[int, int, str]:
        gallery = item.get("gallery") or {}
        section = str(gallery.get("section") or "more")
        try:
            order = int(gallery.get("order") or 99)
        except (TypeError, ValueError):
            order = 99
        return (0 if section == "recommended" else 1, order, str(item.get("name") or item.get("id") or ""))

    return sorted(visible, key=_section_rank)


def get_variant(plot_id: str, variant_id: str, registry: dict[str, Any] | None = None) -> dict[str, Any] | None:
    vid = (variant_id or "").strip().lower()
    plot = get_plot(plot_id, registry)
    for variant in get_variants(plot_id, registry):
        if str(variant.get("id")).lower() == vid:
            return variant
        legacy = [str(x).lower() for x in variant.get("legacy_ids") or []]
        if vid in legacy:
            return variant
    mapping = ((plot or {}).get("legacy_presets") or {}).get(variant_id) or ((plot or {}).get("legacy_presets") or {}).get(vid)
    if isinstance(mapping, dict) and mapping.get("variant"):
        dest = str(mapping.get("variant")).lower()
        if dest != vid:
            return get_variant(plot_id, dest, registry)
    return None


def _blob(plot: dict[str, Any]) -> str:
    parts = [
        plot.get("id"),
        plot.get("name"),
        plot.get("short_name"),
        plot.get("description"),
        plot.get("engine_plugin_id"),
        " ".join(plot.get("aliases") or []),
        " ".join(plot.get("analysis_contexts") or []),
        " ".join(plot.get("tasks") or []),
        " ".join(v.get("id", "") + " " + v.get("name", "") + " " + " ".join(v.get("legacy_ids") or []) for v in plot.get("variants") or []),
        " ".join((plot.get("legacy_presets") or {}).keys()),
    ]
    return " ".join(str(p or "") for p in parts).lower()


def search_plots(query: str, registry: dict[str, Any] | None = None) -> list[dict[str, Any]]:
    raw = (query or "").strip().lower()
    tokens = [t for t in re.split(r"\s+", raw) if t]
    if not tokens:
        return get_all_plots(registry)
    phrase = re.sub(r"[_\-]+", " ", raw)
    hits: list[dict[str, Any]] = []
    for plot in get_all_plots(registry):
        blob = _blob(plot)
        aliases = [str(a).lower() for a in plot.get("aliases") or []]
        names = {
            str(plot.get("id") or "").lower(),
            str(plot.get("engine_plugin_id") or "").lower(),
            str(plot.get("name") or "").lower(),
            str(plot.get("short_name") or "").lower(),
            *aliases,
        }
        variant_names = {str(v.get("id") or "").lower() for v in plot.get("variants") or []}
        variant_names.update(str(v.get("name") or "").lower() for v in plot.get("variants") or [])
        for variant in plot.get("variants") or []:
            variant_names.update(str(x).lower() for x in variant.get("legacy_ids") or [])
        variant_names.update(str(k).lower() for k in (plot.get("legacy_presets") or {}).keys())
        variant_names.update(re.sub(r"[_\-]+", " ", n) for n in list(variant_names))
        score = 0
        exact = False
        task_hit = False
        if raw in names or raw in variant_names or phrase in names or phrase in variant_names:
            exact = True
            score += 20
        for tok in tokens:
            if tok in names or tok in variant_names:
                exact = True
                score += 8
            elif tok in [str(t).lower() for t in (plot.get("tasks") or []) + (plot.get("analysis_contexts") or [])]:
                task_hit = True
                score += 5
            elif tok in blob:
                score += 2
        for ctx in ANALYSIS_TAXONOMY:
            for task in ctx["tasks"]:
                labels = {str(task.get("id") or "").replace("_", " "), str(task.get("name") or "").lower()}
                if any(label and label in phrase for label in labels):
                    if _plot_matches_task_spec(plot, task):
                        task_hit = True
                        score += 10
        for group in CHART_CATEGORY_TAXONOMY:
            for chart in group["charts"]:
                labels = {str(chart.get("id") or "").replace("_", " "), str(chart.get("name") or "").lower()}
                if any(label and label in phrase for label in labels):
                    if _plot_matches_chart(plot, chart):
                        score += 8
                        task_hit = True
        if score:
            kind = "exact" if exact else ("recommended" if task_hit else "related")
            hits.append({**plot, "_score": score, "match_kind": kind, "variant_count": len(visible_variants(plot))})
    hits.sort(key=lambda x: ({"exact": 0, "recommended": 1, "related": 2}[x["match_kind"]], -x["_score"], x.get("name") or ""))
    return hits


def get_plots_by_context(context: str, registry: dict[str, Any] | None = None) -> list[dict[str, Any]]:
    ctx = (context or "").strip().lower()
    return [
        p
        for p in get_all_plots(registry)
        if ctx in [str(c).lower() for c in p.get("analysis_contexts") or []]
        or ctx in [str(c).lower() for c in p.get("categories") or []]
    ]


def get_plots_by_task(task: str, registry: dict[str, Any] | None = None) -> list[dict[str, Any]]:
    t = (task or "").strip().lower()
    out = []
    for plot in get_all_plots(registry):
        family_hit = t in [str(x).lower() for x in plot.get("tasks") or []]
        variant_hit = any(t in [str(x).lower() for x in v.get("recommended_for") or []] for v in plot.get("variants") or [])
        if family_hit or variant_hit:
            out.append(plot)
    return out


def _schema_flags(data_schema: dict[str, Any] | None) -> dict[str, bool]:
    schema = data_schema or {}
    roles = {str(r).lower() for r in schema.get("roles") or schema.get("columns") or schema.keys() if r not in {"roles", "columns", "types"}}
    types = {str(k).lower(): str(v).lower() for k, v in (schema.get("types") or {}).items()}
    has = lambda *names: any(n in roles or n in types for n in names)
    return {
        "has_embedding_xy": has("x_embedding", "x", "umap_1", "dim1") and has("y_embedding", "y", "umap_2", "dim2"),
        "has_cluster": has("cluster", "group", "seurat_clusters"),
        "has_sample": has("sample", "orig.ident", "orig_ident"),
        "has_feature": has("feature", "gene", "expression"),
        "has_effect": has("effect", "log2fc", "avg_log2fc", "stat"),
        "has_pvalue": has("pvalue", "p_val", "padj", "fdr"),
        "has_rank": has("rank", "stat", "avg_log2fc"),
        "roles": sorted(roles),
    }


def get_compatible_plots(data_schema: dict[str, Any] | None, registry: dict[str, Any] | None = None) -> list[dict[str, Any]]:
    flags = _schema_flags(data_schema)
    roles = set(flags["roles"])
    compatible = []
    for plot in get_all_plots(registry):
        req = set(str(r).lower() for r in (plot.get("data_requirements") or {}).get("required_roles") or [])
        if not req:
            compatible.append({**plot, "_missing_roles": []})
            continue
        # Map embedding roles loosely
        expanded = set(roles)
        if flags["has_embedding_xy"]:
            expanded.update({"x_embedding", "y_embedding", "x", "y"})
        missing = [r for r in req if r not in expanded]
        if not missing:
            compatible.append({**plot, "_missing_roles": []})
    return compatible


def get_recommended_plots(
    data_schema: dict[str, Any] | None,
    context: str | None = None,
    registry: dict[str, Any] | None = None,
) -> list[dict[str, Any]]:
    flags = _schema_flags(data_schema)
    recs: list[dict[str, Any]] = []
    for plot in get_all_plots(registry):
        if context:
            ctxs = [str(c).lower() for c in plot.get("analysis_contexts") or []]
            if context.lower() not in ctxs and context.lower() not in [str(c).lower() for c in plot.get("categories") or []]:
                continue
        for rule in plot.get("recommendation_rules") or []:
            when = rule.get("when") or {}
            if all(bool(flags.get(k)) == bool(v) for k, v in when.items() if k.startswith("has_")):
                recs.append(
                    {
                        "plot_id": plot.get("id"),
                        "name": plot.get("name"),
                        "variant": (rule.get("recommend") or {}).get("variant"),
                        "priority": int((rule.get("recommend") or {}).get("priority") or 0),
                        "engine_plugin_id": plot.get("engine_plugin_id"),
                    }
                )
    recs.sort(key=lambda x: -x["priority"])
    return recs


def resolve_legacy_preset(plot_id: str, legacy_preset_id: str, registry: dict[str, Any] | None = None) -> dict[str, Any] | None:
    plot = get_plot(plot_id, registry)
    if not plot:
        return None
    key = (legacy_preset_id or "").strip()
    mapping = (plot.get("legacy_presets") or {}).get(key) or (plot.get("legacy_presets") or {}).get(key.lower())
    variant = get_variant(plot_id, key, registry)
    if mapping or variant:
        dest_id = (mapping or {}).get("variant") if mapping else variant.get("id")
        dest = get_variant(plot_id, str(dest_id or ""), registry) or variant
        return {
            "legacy_id": key,
            "plot_id": plot.get("id"),
            "variant": (dest or {}).get("id") or dest_id,
            "preset": (mapping or {}).get("preset") or "recommended",
            "parameters": (mapping or {}).get("parameters") or {},
            "export_format": (mapping or {}).get("export_format"),
            "example_id": (mapping or {}).get("example_id") or (dest or {}).get("representative_example"),
            "deprecated": bool(mapping) and key != str((dest or {}).get("id") or ""),
        }
    return None


def validate_registry(registry: dict[str, Any] | None = None) -> dict[str, Any]:
    reg = registry or load_registry()
    vocab = load_vocab()
    errors: list[dict[str, str]] = []
    warnings: list[dict[str, str]] = []
    contexts = {str(x) for x in vocab.get("contexts") or []}
    tasks = {str(x) for x in vocab.get("tasks") or []}
    groups = {str(x) for x in vocab.get("parameter_groups") or []}
    roles = {str(x) for x in vocab.get("data_roles") or []}
    seen_ids: set[str] = set()
    alias_owner: dict[str, str] = {}

    plots = reg.get("plots")
    if not isinstance(plots, list) or not plots:
        errors.append({"code": "NO_PLOTS", "field": "plots", "message": "plots must be a non-empty list"})
        return {"valid": False, "errors": errors, "warnings": warnings}

    plugin_ids = {p.name for p in PLUGIN_DIR.iterdir() if p.is_dir() and (p / "config.yaml").exists()}
    engine_ids = {str(p.get("engine_plugin_id")) for p in plots}

    for i, plot in enumerate(plots):
        field = f"plots[{i}]"
        if not isinstance(plot, dict):
            errors.append({"code": "BAD_PLOT", "field": field, "message": "plot must be an object"})
            continue
        pid = str(plot.get("id") or "")
        if not pid:
            errors.append({"code": "MISSING_ID", "field": field, "message": "id required"})
            continue
        if pid in seen_ids:
            errors.append({"code": "DUPLICATE_ID", "field": field, "message": f"duplicate id {pid}"})
        seen_ids.add(pid)
        if not plot.get("name"):
            errors.append({"code": "MISSING_NAME", "field": f"{field}.name", "message": "name required"})
        for ctx in plot.get("analysis_contexts") or []:
            if contexts and str(ctx) not in contexts:
                warnings.append({"code": "UNKNOWN_CONTEXT", "field": f"{field}.analysis_contexts", "message": str(ctx)})
        for task in plot.get("tasks") or []:
            if tasks and str(task) not in tasks:
                warnings.append({"code": "UNKNOWN_TASK", "field": f"{field}.tasks", "message": str(task)})
        req = (plot.get("data_requirements") or {}).get("required_roles") or []
        opt = (plot.get("data_requirements") or {}).get("optional_roles") or []
        for role in list(req) + list(opt):
            if roles and str(role) not in roles:
                warnings.append({"code": "UNKNOWN_ROLE", "field": f"{field}.data_requirements", "message": str(role)})
        v_ids: set[str] = set()
        for j, variant in enumerate(plot.get("variants") or []):
            vid = str((variant or {}).get("id") or "")
            if not vid:
                errors.append({"code": "MISSING_VARIANT_ID", "field": f"{field}.variants[{j}]", "message": "variant id required"})
                continue
            if vid in v_ids:
                errors.append({"code": "DUPLICATE_VARIANT", "field": f"{field}.variants[{j}]", "message": vid})
            v_ids.add(vid)
            preview = variant.get("preview_asset")
            if preview and not (ROOT / str(preview)).is_file():
                warnings.append({"code": "PREVIEW_MISSING", "field": f"{field}.variants[{j}].preview_asset", "message": str(preview)})
            for g in variant.get("parameter_groups") or []:
                if groups and str(g) not in groups:
                    warnings.append({"code": "UNKNOWN_PARAM_GROUP", "field": f"{field}.variants[{j}]", "message": str(g)})
        visible = visible_variants(plot)
        if pid == "umap_tsne":
            if not visible:
                errors.append({"code": "NO_VISIBLE_VARIANTS", "field": f"{field}.variants", "message": "UMAP gallery needs visible variants"})
            hidden_ids = {str(v.get("id")) for v in (plot.get("variants") or []) if not variant_is_gallery_visible(v)}
            for banned in ("axis_label_controls", "blank_theme", "pdf_basic_umap", "raster", "mark_shapes"):
                if any(str(v.get("id")) == banned and variant_is_gallery_visible(v) for v in plot.get("variants") or []):
                    errors.append({"code": "LEGACY_VISIBLE", "field": f"{field}.variants", "message": banned})
            for variant in visible:
                if not variant.get("name") or str(variant.get("name")).find("_") >= 0 and str(variant.get("name")) == str(variant.get("id")):
                    warnings.append({"code": "INTERNAL_ID_TITLE", "field": f"{field}.variants", "message": str(variant.get("id"))})
                if not (variant.get("short_description") or variant.get("description")):
                    warnings.append({"code": "MISSING_VARIANT_COPY", "field": f"{field}.variants", "message": str(variant.get("id"))})
        seen_legacy: set[str] = set()
        for variant in plot.get("variants") or []:
            for lid in variant.get("legacy_ids") or []:
                low = str(lid).lower()
                if low in seen_legacy:
                    warnings.append({"code": "DUPLICATE_LEGACY_ID", "field": f"{field}.variants", "message": lid})
                seen_legacy.add(low)
        preset_ids = {str(p.get("id")) for p in plot.get("presets") or []}
        for legacy_id, mapping in (plot.get("legacy_presets") or {}).items():
            if not isinstance(mapping, dict):
                errors.append({"code": "BAD_LEGACY", "field": f"{field}.legacy_presets.{legacy_id}", "message": "must be object"})
                continue
            dest = mapping.get("variant")
            if dest and dest not in v_ids and v_ids:
                hops = 0
                seen_chain = {str(legacy_id), str(dest)}
                cursor = dest
                while cursor and cursor not in v_ids and hops < 20:
                    nxt = (plot.get("legacy_presets") or {}).get(cursor) or {}
                    cursor = nxt.get("variant") if isinstance(nxt, dict) else None
                    hops += 1
                    if cursor and cursor in seen_chain:
                        errors.append({"code": "ALIAS_CYCLE", "field": f"{field}.legacy_presets.{legacy_id}", "message": str(dest)})
                        break
                    if cursor:
                        seen_chain.add(str(cursor))
                if cursor not in v_ids:
                    warnings.append({"code": "ORPHAN_LEGACY_VARIANT", "field": f"{field}.legacy_presets.{legacy_id}", "message": str(mapping.get("variant"))})
            if mapping.get("preset") and mapping["preset"] not in preset_ids and preset_ids:
                errors.append({"code": "ORPHAN_PRESET", "field": f"{field}.legacy_presets.{legacy_id}", "message": str(mapping.get("preset"))})
        for alias in plot.get("aliases") or []:
            a = str(alias).strip().lower()
            if not a:
                continue
            if a in alias_owner and alias_owner[a] != pid:
                warnings.append({"code": "ALIAS_COLLISION", "field": f"{field}.aliases", "message": f"'{alias}' also used by {alias_owner[a]}"})
            alias_owner[a] = pid

    missing_plugins = sorted(plugin_ids - engine_ids)
    if missing_plugins:
        errors.append({"code": "PLUGIN_NOT_IN_REGISTRY", "field": "plots", "message": ", ".join(missing_plugins)})

    return {
        "valid": len(errors) == 0,
        "errors": errors,
        "warnings": warnings,
        "n_plots": len(seen_ids),
        "n_plugins": len(plugin_ids),
    }


def write_reports(registry: dict[str, Any] | None = None) -> None:
    reg = registry or load_registry(rebuild=True)
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    plots = get_all_plots(reg)
    lines = ["# Plot family inventory\n", f"Families: {len(plots)}\n"]
    for plot in plots:
        lines.append(
            f"- `{plot.get('id')}` — {plot.get('name')} (engine `{plot.get('engine_plugin_id')}`, "
            f"{len(plot.get('variants') or [])} variants, {len(plot.get('demos') or [])} demos)"
        )
    (REPORT_DIR / "inventory_plots.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

    class_lines = ["# Classification report\n", "| plugin | example | class | maps_to | notes |", "|---|---|---|---|---|"]
    counts: dict[str, int] = {}
    for row in reg.get("classifications") or []:
        kind = str(row.get("classification"))
        counts[kind] = counts.get(kind, 0) + 1
        maps = row.get("maps_to") or {}
        maps_s = f"{maps.get('variant')}/{maps.get('preset')}" if maps else (row.get("parameter_group") or "")
        class_lines.append(
            f"| `{row.get('plugin_id')}` | `{row.get('example_id')}` | {kind} | {maps_s} | {row.get('label') or ''} |"
        )
    class_lines.insert(1, "Counts: " + ", ".join(f"{k}={v}" for k, v in sorted(counts.items())) + "\n")
    (REPORT_DIR / "classification_report.md").write_text("\n".join(class_lines) + "\n", encoding="utf-8")

    preset_lines = ["# Appearance presets\n"]
    for plot in plots:
        preset_lines.append(f"## {plot.get('id')}")
        for preset in plot.get("presets") or []:
            preset_lines.append(f"- `{preset.get('id')}` — {preset.get('name')}")
        if plot.get("legacy_presets"):
            preset_lines.append("Legacy:")
            for lid, mapping in plot["legacy_presets"].items():
                preset_lines.append(f"- `{lid}` → variant `{mapping.get('variant')}` preset `{mapping.get('preset')}`")
    (REPORT_DIR / "inventory_presets.md").write_text("\n".join(preset_lines) + "\n", encoding="utf-8")

    uncertain = [r for r in (reg.get("classifications") or []) if r.get("classification") in {"uncertain", "deprecated"}]
    unres = ["# Unresolved / ambiguous items\n"]
    if not uncertain:
        unres.append("No `uncertain` or `deprecated` example classifications remain after heuristic + override mapping.")
        unres.append("\nOpen questions:")
        unres.append("- `stat_plot` encodings are filed on pie/rose, stacked bar, dot, sankey, chord, venn, and upset families.")
        unres.append("- `interactive_sankey_plot` examples/index.json was empty at scan time; variants come from folder names if present.")
        unres.append("- PDF repro examples are classified as `demo` (and export-like when `pdf_*` without `repro`).")
    else:
        for row in uncertain:
            unres.append(f"- `{row.get('plugin_id')}/{row.get('example_id')}` ({row.get('classification')})")
    (REPORT_DIR / "unresolved.md").write_text("\n".join(unres) + "\n", encoding="utf-8")

    mig = """# Migration notes

The plot registry is a metadata layer. Plotting engines (`plugins/*/plot.R`) are unchanged.

## Identifiers

- Plot **family** ids may differ from plugin directory names. Example: `advanced_dim_plot` → `umap_tsne`.
- `engine_plugin_id` is always the existing plugin id used by `/api/plugins/{id}` and Rscripts.
- Legacy example/preset ids resolve through `legacy_presets` and variant `legacy_ids`.

## Compatibility

- Saved configs still use plugin ids and example ids.
- `resolve_legacy_preset(plotId, legacyPresetId)` maps old names to `{variant, preset}`.
- Do not delete example bundles; they are demos in the registry.

## Next phases (not in this task)

- UI card gallery driven by `variants[].preview_asset`
- Parameter panel visibility from `parameter_groups`
- Automatic data-role binding from `data_requirements`
"""
    (REPORT_DIR / "migration_notes.md").write_text(mig, encoding="utf-8")


ANALYSIS_TAXONOMY = [
    {
        "id": "single_cell",
        "name": "Single-cell",
        "context": "single_cell",
        "blurb": "Explore clusters, gene expression, composition, markers and trajectories.",
        "tasks": [
            {"id": "cell_clustering", "name": "Cell clustering", "blurb": "Explore clusters and annotations.", "match_tasks": ["cell_clustering", "clustering"]},
            {"id": "gene_expression", "name": "Gene expression", "blurb": "Visualize feature expression across cells or groups.", "match_tasks": ["gene_expression", "feature_expression", "marker_visualization"]},
            {"id": "cell_composition", "name": "Cell composition", "blurb": "Compare proportions across clusters, samples or conditions.", "match_tasks": ["cell_composition", "composition"]},
            {"id": "marker_genes", "name": "Marker genes", "blurb": "Inspect and compare marker patterns.", "match_tasks": ["marker_visualization", "differential_expression"]},
            {"id": "sample_differences", "name": "Sample differences", "blurb": "Compare conditions, samples or batches.", "match_tasks": ["sample_comparison", "group_comparison"], "family_ids": ["umap_tsne", "feature_embedding", "exp_stat_plot"]},
            {"id": "trajectory", "name": "Trajectory", "blurb": "Explore pseudotime, lineage and dynamic changes.", "match_tasks": ["trajectory"]},
        ],
    },
    {
        "id": "bulk_expression",
        "name": "Bulk Expression",
        "context": "bulk_expression",
        "blurb": "Overview, differential tests, sample comparison and expression patterns.",
        "tasks": [
            {"id": "expression_overview", "name": "Expression overview", "blurb": "See expression across genes and samples.", "match_tasks": ["gene_expression", "heatmap", "expression_pattern"]},
            {"id": "differential_expression", "name": "Differential expression", "blurb": "Rank and highlight changing genes.", "match_tasks": ["differential_expression"]},
            {"id": "sample_comparison", "name": "Sample comparison", "blurb": "Compare groups, batches or conditions.", "match_tasks": ["sample_comparison", "group_comparison"]},
            {"id": "expression_patterns", "name": "Expression patterns", "blurb": "Find coordinated expression modules.", "match_tasks": ["expression_pattern", "heatmap"]},
            {"id": "gene_clustering", "name": "Gene clustering", "blurb": "Group genes by similar profiles.", "match_tasks": ["gene_clustering", "heatmap"]},
        ],
    },
    {
        "id": "functional_enrichment",
        "name": "Functional Enrichment",
        "context": "functional_enrichment",
        "blurb": "ORA, GSEA, pathway comparison and gene–pathway links.",
        "tasks": [
            {"id": "ora", "name": "ORA", "blurb": "Over-representation of gene sets.", "match_tasks": ["ora"]},
            {"id": "gsea", "name": "GSEA", "blurb": "Ranked-list enrichment and running scores.", "match_tasks": ["gsea"]},
            {"id": "pathway_comparison", "name": "Pathway comparison", "blurb": "Compare enrichment across groups or terms.", "match_tasks": ["pathway_comparison"]},
            {"id": "gene_pathway_relationship", "name": "Gene-pathway relationships", "blurb": "Connect leading genes to pathways.", "match_tasks": ["gene_pathway_relationship"]},
        ],
    },
    {
        "id": "epigenomics",
        "name": "Epigenomics",
        "context": "epigenomics",
        "blurb": "Peak signal, genomic profiles, accessibility and motifs.",
        "tasks": [
            {"id": "peak_signal", "name": "Peak signal", "blurb": "Inspect peak intensity along the genome.", "match_tasks": ["ranking"], "family_ids": ["interactive_genomic_signal_track_plot"]},
            {"id": "genomic_profiles", "name": "Genomic profiles", "blurb": "Compare coverage tracks across samples.", "match_tasks": ["ranking"], "family_ids": ["interactive_genomic_signal_track_plot"]},
            {"id": "differential_accessibility", "name": "Differential accessibility", "blurb": "Highlight changing peaks or regions.", "match_tasks": ["differential_expression"]},
            {"id": "motif_analysis", "name": "Motif analysis", "blurb": "Visualize motif enrichment logos.", "match_tasks": ["ranking"], "family_ids": ["interactive_motif_logo_plot"]},
            {"id": "genomic_annotation", "name": "Genomic annotation", "blurb": "Annotate genomic intervals.", "match_tasks": ["ranking"]},
        ],
    },
    {
        "id": "trajectory",
        "name": "Trajectory & Dynamics",
        "context": "trajectory",
        "blurb": "Pseudotime, lineage, temporal trends and dynamic expression.",
        "tasks": [
            {"id": "pseudotime", "name": "Pseudotime", "blurb": "Order cells along a continuum.", "match_tasks": ["trajectory"]},
            {"id": "lineage", "name": "Lineage", "blurb": "Compare branching fates.", "match_tasks": ["trajectory"]},
            {"id": "temporal_trends", "name": "Temporal trends", "blurb": "Follow changes across time or stages.", "match_tasks": ["trajectory", "group_comparison"]},
            {"id": "dynamic_expression", "name": "Dynamic expression", "blurb": "See how features change along a trajectory.", "match_tasks": ["trajectory", "gene_expression", "feature_expression"]},
        ],
    },
    {
        "id": "general_statistics",
        "name": "General Statistics",
        "context": "general_statistics",
        "blurb": "Distributions, correlations, group tests, ranking and summaries.",
        "tasks": [
            {"id": "distribution", "name": "Distribution", "blurb": "Shape of a numeric variable.", "match_tasks": ["distribution"]},
            {"id": "correlation", "name": "Correlation", "blurb": "Association between features.", "match_tasks": ["correlation"]},
            {"id": "group_comparison", "name": "Group comparison", "blurb": "Compare values across categories.", "match_tasks": ["group_comparison"]},
            {"id": "ranking", "name": "Ranking", "blurb": "Order items by a score or statistic.", "match_tasks": ["ranking"]},
            {"id": "summary", "name": "Summary", "blurb": "Compact statistical overviews.", "match_tasks": ["group_comparison"], "family_ids": ["stat_plot", "exp_stat_plot", "ranked_annotation_panel"]},
        ],
    },
    {
        "id": "relationships_overlap",
        "name": "Relationships & Overlap",
        "context": "relationships_overlap",
        "blurb": "Set overlap, feature links, flow and networks.",
        "tasks": [
            {"id": "set_overlap", "name": "Set overlap", "blurb": "Shared and unique members of sets.", "match_tasks": ["overlap"]},
            {"id": "feature_relationships", "name": "Feature relationships", "blurb": "Links between features or samples.", "match_tasks": ["correlation"]},
            {"id": "flow_relationships", "name": "Flow relationships", "blurb": "Movement between categories.", "match_tasks": ["network", "composition"], "family_ids": ["alluvial", "gsea"]},
            {"id": "network", "name": "Network relationships", "blurb": "Graph structure among entities.", "match_tasks": ["network"]},
            {"id": "correlation", "name": "Correlation", "blurb": "Pairwise association matrices.", "match_tasks": ["correlation"]},
        ],
    },
]

BROWSE_CATEGORIES = [
    {"id": "single_cell", "name": "Single-cell", "contexts": ["single_cell"]},
    {"id": "expression", "name": "Expression", "tasks": ["gene_expression", "feature_expression", "expression_pattern"]},
    {"id": "differential_analysis", "name": "Differential Analysis", "contexts": ["differential_expression"], "tasks": ["differential_expression"]},
    {"id": "enrichment", "name": "Enrichment", "contexts": ["functional_enrichment"]},
    {"id": "composition", "name": "Composition", "tasks": ["composition", "cell_composition"]},
    {"id": "statistics", "name": "Statistics", "contexts": ["general_statistics"], "tasks": ["distribution", "group_comparison", "correlation"]},
    {"id": "network", "name": "Network", "tasks": ["network"]},
]

# Visual-grammar catalog for Browse by Chart Type.
CHART_CATEGORY_TAXONOMY = [
    {
        "id": "distribution",
        "name": "Distribution",
        "charts": [
            {"id": "violin", "name": "Violin", "family_ids": ["violin_plot", "interactive_violin_plot"]},
            {"id": "density", "name": "Density", "family_ids": ["den_plot", "feature_embedding"]},
            {"id": "histogram", "name": "Histogram", "family_ids": ["interactive_histogram_plot"]},
            {"id": "boxplot", "name": "Boxplot", "family_ids": ["interactive_violin_plot", "violin_plot"]},
            {"id": "ridgeline", "name": "Ridgeline", "family_ids": ["ridgeline", "gsea"]},
            {"id": "beeswarm", "name": "Beeswarm", "family_ids": ["interactive_violin_plot", "violin_plot", "highlight_effect_plot"]},
        ],
    },
    {
        "id": "comparison",
        "name": "Comparison",
        "charts": [
            {"id": "barplot", "name": "Barplot", "family_ids": ["combo_bar_dot_matrix", "exp_stat_plot", "go_kegg_enrichment_bar_bubble", "hierarchical_marker_panel"]},
            {"id": "dot", "name": "Dot plot", "family_ids": ["dot_plot", "combo_bar_dot_matrix", "hierarchical_marker_panel"]},
            {"id": "lollipop", "name": "Lollipop", "family_ids": ["enrichment_lollipop", "ranked_annotation_panel", "interactive_dumbbell_plot"]},
            {"id": "radar", "name": "Radar / Spider", "family_ids": ["interactive_radar_plot"]},
            {"id": "parallel", "name": "Parallel coordinates", "family_ids": ["ranked_annotation_panel"]},
        ],
    },
    {
        "id": "relationship",
        "name": "Relationship",
        "charts": [
            {"id": "scatter", "name": "Scatter", "family_ids": ["regression_scatter_plot", "quadrant_correlation_scatter", "volcano", "umap_tsne", "feature_embedding", "trajectory"]},
            {"id": "bubble", "name": "Bubble", "family_ids": ["dot_plot", "interactive_bubble_score_matrix"]},
            {"id": "connected_scatter", "name": "Connected scatter", "family_ids": ["interactive_dumbbell_plot"]},
            {"id": "density_2d", "name": "2D density", "family_ids": ["feature_embedding", "umap_tsne"]},
        ],
    },
    {
        "id": "matrix",
        "name": "Matrix",
        "charts": [
            {"id": "heatmap", "name": "Heatmap", "family_ids": ["grouped_heatmap", "threshold_matrix_heatmap"]},
            {"id": "correlogram", "name": "Correlogram", "family_ids": ["interactive_correlation_matrix"]},
            {"id": "dot_matrix", "name": "Dot / Balloon matrix", "family_ids": ["dot_plot", "combo_bar_dot_matrix", "hierarchical_marker_panel"]},
        ],
    },
    {
        "id": "composition",
        "name": "Composition",
        "charts": [
            {"id": "pie", "name": "Pie / Rose", "family_ids": ["interactive_pie_plot", "umap_tsne"]},
            {"id": "doughnut", "name": "Donut", "family_ids": ["interactive_pie_plot"]},
            {"id": "stacked_bar", "name": "Stacked bar", "family_ids": ["exp_stat_plot"]},
            {"id": "treemap", "name": "Treemap", "family_ids": []},
        ],
    },
    {
        "id": "flow",
        "name": "Flow & Network",
        "charts": [
            {"id": "sankey", "name": "Sankey", "family_ids": ["alluvial", "gsea"]},
            {"id": "alluvial", "name": "Alluvial", "family_ids": ["alluvial"]},
            {"id": "network", "name": "Network", "family_ids": ["interactive_network_plot", "interactive_mantel_correlation_network"]},
            {"id": "chord", "name": "Chord", "family_ids": ["alluvial"]},
            {"id": "arc", "name": "Arc diagram", "family_ids": ["interactive_arc_network_plot"]},
        ],
    },
    {
        "id": "sets",
        "name": "Sets",
        "charts": [
            {"id": "venn", "name": "Venn", "family_ids": ["venn"]},
            {"id": "upset", "name": "UpSet", "family_ids": ["upset"]},
        ],
    },
    {
        "id": "tables",
        "name": "Tables",
        "charts": [
            {"id": "table", "name": "Table", "family_ids": []},
            {"id": "summary_table", "name": "Summary table", "family_ids": ["ranked_annotation_panel"]},
        ],
    },
    {
        "id": "specialized",
        "name": "Specialized",
        "charts": [
            {"id": "genomic_track", "name": "Genomic track", "family_ids": ["interactive_genomic_signal_track_plot"]},
            {"id": "motif", "name": "Motif logo", "family_ids": ["interactive_motif_logo_plot"]},
            {"id": "dendrogram", "name": "Dendrogram", "family_ids": ["cluster_dendrogram_plot", "hierarchical_marker_panel"]},
        ],
    },
]


def _plot_matches_task(plot: dict[str, Any], match_tasks: list[str]) -> bool:
    wanted = {t.lower() for t in match_tasks}
    have = {str(t).lower() for t in plot.get("tasks") or []}
    if wanted & have:
        return True
    for variant in plot.get("variants") or []:
        rec = {str(t).lower() for t in variant.get("recommended_for") or []}
        if wanted & rec:
            return True
    return False


def _plot_matches_task_spec(plot: dict[str, Any], task: dict[str, Any]) -> bool:
    if _plot_matches_task(plot, list(task.get("match_tasks") or [])):
        return True
    wanted = {str(i).lower() for i in task.get("family_ids") or []}
    if not wanted:
        return False
    return str(plot.get("id") or "").lower() in wanted or str(plot.get("engine_plugin_id") or "").lower() in wanted


def _recommendation_priority(plot: dict[str, Any], task: dict[str, Any], rec_variant: str | None, context: str) -> int:
    pri = 0
    if rec_variant:
        pri += 100
    if _plot_matches_task(plot, list(task.get("match_tasks") or [])):
        pri += 40
    contexts = {str(c).lower() for c in plot.get("analysis_contexts") or []}
    if context in contexts:
        pri += 20
    raw = plot.get("recommendation_priority") or {}
    if isinstance(raw, dict):
        for key in [task.get("id"), *(task.get("match_tasks") or [])]:
            if key and key in raw:
                try:
                    pri += int(raw[key])
                except (TypeError, ValueError):
                    pass
    return pri


def _recommended_variant_for_task(plot: dict[str, Any], match_tasks: list[str]) -> str | None:
    wanted = {t.lower() for t in match_tasks}
    for variant in plot.get("variants") or []:
        rec = {str(t).lower() for t in variant.get("recommended_for") or []}
        if wanted & rec:
            return str(variant.get("id"))
    return None


def _card_payload(plot: dict[str, Any], extra: dict[str, Any] | None = None) -> dict[str, Any]:
    preview = None
    for variant in plot.get("variants") or []:
        if variant.get("preview_asset"):
            preview = variant["preview_asset"]
            break
    for demo in plot.get("demos") or []:
        if demo.get("preview_asset"):
            preview = preview or demo["preview_asset"]
            break
    card = {
        "id": plot.get("id"),
        "name": plot.get("name"),
        "short_name": plot.get("short_name") or plot.get("name"),
        "description": plot.get("description") or "",
        "engine_plugin_id": plot.get("engine_plugin_id"),
        "aliases": plot.get("aliases") or [],
        "analysis_contexts": plot.get("analysis_contexts") or [],
        "tasks": plot.get("tasks") or [],
        "preview_asset": preview,
        "variant_count": len(visible_variants(plot)),
        "studio_path": f"/plot/{plot.get('id')}",
    }
    if extra:
        card.update(extra)
    return card


def discovery_taxonomy(registry: dict[str, Any] | None = None) -> dict[str, Any]:
    reg = registry or load_registry()
    plots = get_all_plots(reg)
    contexts = []
    for ctx in ANALYSIS_TAXONOMY:
        tasks = []
        for task in ctx["tasks"]:
            matched = [p for p in plots if _plot_matches_task_spec(p, task)]
            cards = []
            for plot in matched:
                rec_variant = _recommended_variant_for_task(plot, list(task.get("match_tasks") or []))
                pri = _recommendation_priority(plot, task, rec_variant, ctx["context"])
                cards.append(
                    _card_payload(
                        plot,
                        {
                            "recommended": False,
                            "recommended_variant": rec_variant,
                            "priority": pri,
                            "why": task.get("blurb") or "",
                        },
                    )
                )
            cards.sort(key=lambda item: (-int(item.get("priority") or 0), str(item.get("name") or "")))
            rec_limit = 4
            tagged = 0
            for card in cards:
                strong = bool(card.get("recommended_variant")) or int(card.get("priority") or 0) >= 40
                if strong and tagged < rec_limit:
                    card["recommended"] = True
                    tagged += 1
            if tagged < 2:
                for card in cards[:2]:
                    card["recommended"] = True
            tasks.append(
                {
                    "id": task["id"],
                    "name": task["name"],
                    "blurb": task.get("blurb") or "",
                    "path": f"/scenario/{ctx['id']}/{task['id']}",
                    "plot_count": len(cards),
                    "plots": cards,
                }
            )
        unique_ids = {p["id"] for t in tasks for p in t["plots"]}
        contexts.append(
            {
                "id": ctx["id"],
                "name": ctx["name"],
                "context": ctx["context"],
                "blurb": ctx.get("blurb") or "",
                "path": f"/scenario/{ctx['id']}",
                "task_count": len(tasks),
                "plot_count": len(unique_ids),
                "tasks": tasks,
            }
        )
    return {"contexts": contexts}


def browse_categories(registry: dict[str, Any] | None = None) -> dict[str, Any]:
    reg = registry or load_registry()
    plots = get_all_plots(reg)
    assigned: set[str] = set()
    categories = []
    for spec in BROWSE_CATEGORIES:
        family_ids = set(spec.get("family_ids") or [])
        contexts = {c.lower() for c in spec.get("contexts") or []}
        tasks = {t.lower() for t in spec.get("tasks") or []}
        matched = []
        for plot in plots:
            pid = str(plot.get("id"))
            hit = pid in family_ids
            if contexts and contexts & {str(c).lower() for c in plot.get("analysis_contexts") or []}:
                hit = True
            if tasks and _plot_matches_task(plot, list(tasks)):
                hit = True
            if hit:
                matched.append(_card_payload(plot))
                assigned.add(pid)
        categories.append(
            {
                "id": spec["id"],
                "name": spec["name"],
                "path": f"/plots?category={spec['id']}",
                "plots": matched,
                "plot_count": len(matched),
            }
        )
    leftover = [_card_payload(p) for p in plots if str(p.get("id")) not in assigned]
    if leftover:
        categories.append(
            {
                "id": "other",
                "name": "Other",
                "path": "/plots?category=other",
                "plots": leftover,
                "plot_count": len(leftover),
            }
        )
    return {"categories": categories, "all_plots": [_card_payload(p) for p in plots]}


def _plot_matches_chart(plot: dict[str, Any], chart: dict[str, Any]) -> bool:
    wanted = {str(i).lower() for i in chart.get("family_ids") or []}
    pid = str(plot.get("id") or "").lower()
    engine = str(plot.get("engine_plugin_id") or "").lower()
    if pid in wanted or engine in wanted:
        return True
    keys = [k.lower() for k in chart.get("keywords") or [] if k]
    if not keys:
        return False
    blob = " ".join(
        [
            pid.replace("_", " "),
            engine.replace("_", " "),
            str(plot.get("name") or "").lower(),
            *[str(a).lower().replace("_", " ") for a in plot.get("aliases") or []],
        ]
    )
    return any(re.search(rf"(^|\\s){re.escape(k)}(\\s|$)", blob) for k in keys)


def chart_categories(registry: dict[str, Any] | None = None) -> dict[str, Any]:
    plots = get_all_plots(registry or load_registry())
    groups = []
    for spec in CHART_CATEGORY_TAXONOMY:
        charts = []
        for chart in spec["charts"]:
            matched = [_card_payload(p) for p in plots if _plot_matches_chart(p, chart)]
            charts.append(
                {
                    "id": chart["id"],
                    "name": chart["name"],
                    "icon": chart.get("icon") or chart["id"],
                    "path": f"/category/{chart['id']}",
                    "plot_count": len(matched),
                    "family_count": len(matched),
                    "plots": matched,
                }
            )
        groups.append(
            {
                "id": spec["id"],
                "name": spec["name"],
                "charts": charts,
                "chart_count": len(charts),
                "plot_count": sum(c["plot_count"] for c in charts),
            }
        )
    return {"groups": groups}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Build/validate the plot registry")
    parser.add_argument("command", choices=["build", "validate", "search"], nargs="?", default="build")
    parser.add_argument("query", nargs="?")
    args = parser.parse_args(argv)
    if args.command == "search":
        hits = search_plots(args.query or "")
        for hit in hits[:20]:
            print(f"{hit.get('_score', 0):3} {hit.get('id')}  {hit.get('name')}")
        return 0
    reg = load_registry(rebuild=True)
    write_reports(reg)
    result = validate_registry(reg)
    print(json.dumps({"n_plots": result.get("n_plots"), "valid": result["valid"], "errors": result["errors"], "warnings_n": len(result["warnings"])}, indent=2))
    if args.command == "validate" and not result["valid"]:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
