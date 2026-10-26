"""Plugin metadata: config, schemas, example bundles, style cards and demo inputs."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from fastapi import HTTPException

from plot_web.plot_registry import (
    get_plot,
    load_overrides,
    visible_variants,
)
from plot_web.server.settings import PLUGIN_DIR, ROOT_DIR
from plot_web.server.storage import safe_id
from plot_web.server.tables import preview_table
from plot_web.yaml_cache import load_yaml_cached


def read_yaml(path: Path) -> dict[str, Any]:
    try:
        if not path.is_file():
            raise FileNotFoundError("file not found")
        data = load_yaml_cached(path) or {}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Cannot read yaml: {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise HTTPException(status_code=500, detail=f"Invalid yaml object: {path}")
    return data


def plugin_path(plugin_id: str) -> Path:
    plugin_id = safe_id(plugin_id)
    path = PLUGIN_DIR / plugin_id
    if not path.is_dir():
        raise HTTPException(status_code=404, detail="Plugin not found")
    return path


def plugin_config_path(plugin_id: str) -> Path:
    path = plugin_path(plugin_id) / "config.yaml"
    if not path.exists():
        raise HTTPException(status_code=404, detail="Plugin config not found")
    return path


def plugin_summary(plugin_id: str, config: dict[str, Any]) -> dict[str, Any]:
    category = normalized_category(plugin_id, config.get("category"))
    examples = list_example_params(plugin_id)
    gallery = PLUGIN_DIR / plugin_id / "all_examples_gallery"
    preview = None
    # Prefer a single example image to a montage.  list_example_params() is
    # sorted and only returns images which can be served by the gallery route.
    for example in examples:
        image = example.get("image")
        if image:
            preview = image
            break
    if preview is None and gallery.exists():
        first = next(iter(sorted(gallery.glob("*.png"))), None)
        if first:
            preview = f"/api/plugins/{plugin_id}/gallery/{first.name}"
    return {
        "id": plugin_id,
        "name": config.get("display_name") or config.get("name") or plugin_id,
        "version": config.get("version", "1.0.0"),
        "category": category,
        "subcategory": config.get("subcategory", default_subcategory(category, plugin_id)),
        "description": config.get("description", ""),
        "language": config.get("language", infer_language(config)),
        "status": config.get("status", "stable"),
        "inputs": config.get("inputs", []),
        "has_schema": (PLUGIN_DIR / plugin_id / "params_schema.json").exists(),
        "has_examples": bool(examples),
        "preview": preview,
        "registry_family": (get_plot(plugin_id) or {}).get("id"),
    }


def normalized_category(plugin_id: str, category: Any) -> str:
    """Category comes from plugins/<id>/config.yaml; ``Set``/``Enrichment`` share one bucket."""
    explicit = str(category or "").strip()
    if explicit in {"Set", "Enrichment"}:
        return "Set / Enrichment"
    return explicit or "Plot"


def default_subcategory(category: str, plugin_id: str) -> str:
    return "General"


def infer_language(config: dict[str, Any]) -> str:
    runtime = config.get("runtime") or {}
    if isinstance(runtime, dict):
        command = str(runtime.get("command", ""))
    else:
        command = str(runtime)
    entrypoint = str(config.get("entrypoint", "plot.R"))
    if command.startswith("python") or entrypoint.endswith(".py"):
        return "Python"
    return "R"


def read_params_schema(plugin_id: str) -> dict[str, Any] | None:
    path = PLUGIN_DIR / plugin_id / "params_schema.json"
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None


def effective_params_schema(plugin_id: str, config: dict[str, Any]) -> dict[str, Any] | None:
    """Return UI-ready sectioned schema (normalizes JSON-Schema / groups wrappers)."""
    from plot_web.schema_normalize import normalize_params_schema

    schema = read_params_schema(plugin_id)
    if schema:
        try:
            return normalize_params_schema(schema) or schema
        except Exception:
            return schema
    parameters = config.get("parameters")
    if isinstance(parameters, dict) and parameters:
        return normalize_params_schema({"Parameters": parameters}) or {"Parameters": parameters}
    return None


EXAMPLE_FILE_EXTENSIONS = {".json", ".csv", ".tsv", ".txt", ".xlsx", ".xlsm", ".xls", ".gmt", ".png", ".rds", ".h5ad", ".h5"}


def example_bundle(plugin_id: str, example_id: str) -> Path:
    """Resolve an example directory without allowing ids to escape examples/."""
    root = plugin_path(plugin_id) / "examples"
    example_id = safe_id(example_id)
    bundle = (root / example_id).resolve()
    try:
        bundle.relative_to(root.resolve())
    except ValueError as exc:
        raise HTTPException(status_code=404, detail="Example not found") from exc
    if not bundle.is_dir() or not (bundle / "manifest.json").is_file():
        raise HTTPException(status_code=404, detail="Example not found")
    return bundle


def example_file(bundle: Path, relative_name: str, *, check_extension: bool = True) -> Path:
    if not relative_name or Path(relative_name).is_absolute():
        raise HTTPException(status_code=400, detail="Invalid example file")
    path = (bundle / relative_name).resolve()
    try:
        path.relative_to(bundle.resolve())
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Invalid example file") from exc
    if check_extension and path.suffix.lower() not in EXAMPLE_FILE_EXTENSIONS:
        raise HTTPException(status_code=400, detail="Unsupported example file type")
    if not path.is_file():
        raise HTTPException(status_code=404, detail="Example file not found")
    return path


def read_example_manifest(bundle: Path) -> dict[str, Any]:
    try:
        value = json.loads((bundle / "manifest.json").read_text(encoding="utf-8"))
    except Exception as exc:
        raise HTTPException(status_code=500, detail="Invalid example manifest") from exc
    if not isinstance(value, dict):
        raise HTTPException(status_code=500, detail="Invalid example manifest")
    return value


def example_url(plugin_id: str, example_id: str, suffix: str = "") -> str:
    base = f"/api/plugins/{plugin_id}/examples/{example_id}"
    return base + suffix


def example_record(plugin_id: str, bundle: Path, manifest: dict[str, Any], index_entry: dict[str, Any] | None = None) -> dict[str, Any]:
    example_id = safe_id(str(manifest.get("id") or (index_entry or {}).get("id") or bundle.name))
    params_name = str(manifest.get("params", "params.json"))
    params_path = example_file(bundle, params_name)
    try:
        params = json.loads(params_path.read_text(encoding="utf-8"))
    except Exception:
        params = {}
    params = params if isinstance(params, dict) else {}
    inputs: dict[str, Any] = {}
    for field, relative in (manifest.get("inputs") or {}).items():
        if not isinstance(relative, str):
            continue
        try:
            path = example_file(bundle, relative)
        except HTTPException:
            continue
        rel = path.relative_to(bundle).as_posix()
        inputs[str(field)] = {"path": rel, "filename": path.name, "url": example_url(plugin_id, example_id, "/files/" + rel)}
    expected = manifest.get("expected")
    expected_url = None
    if isinstance(expected, str):
        try:
            expected_path = example_file(bundle, expected)
            expected_url = example_url(plugin_id, example_id, "/files/" + expected_path.relative_to(bundle).as_posix())
        except HTTPException:
            expected_url = None
    # Prefer a gallery thumbnail when declared so each demo has its own frame box.
    gallery_png = None
    for key in ("gallery_png", "image", "preview"):
        raw = manifest.get(key) or (index_entry or {}).get(key)
        if isinstance(raw, str) and raw.strip():
            name = Path(raw).name
            if (PLUGIN_DIR / plugin_id / "all_examples_gallery" / name).is_file():
                gallery_png = f"/api/plugins/{plugin_id}/gallery/{name}"
                break
    image_url = gallery_png or expected_url
    label = str(
        (index_entry or {}).get("label")
        or manifest.get("label")
        or example_id
    )
    blurb = str(
        (index_entry or {}).get("blurb")
        or manifest.get("blurb")
        or manifest.get("description")
        or ""
    )
    howto = str(
        (index_entry or {}).get("howto")
        or manifest.get("howto")
        or ""
    )
    card_group = str(
        (index_entry or {}).get("card_group")
        or manifest.get("card_group")
        or ("pdf_styles" if str(example_id).startswith("pdf_repro_") else "more")
    )
    return {
        "id": example_id,
        "bundle": example_url(plugin_id, example_id),
        "params": params,
        "params_url": example_url(plugin_id, example_id, "/files/" + params_path.relative_to(bundle).as_posix()),
        "manifest_url": example_url(plugin_id, example_id, "/files/manifest.json"),
        "inputs": inputs,
        "expected": expected_url,
        "plot_type": manifest.get("plot_type"),
        "mode": manifest.get("mode"),
        "name": label,
        "path": str(bundle.relative_to(ROOT_DIR)),
        "label": label,
        "blurb": blurb,
        "howto": howto,
        "card_group": card_group,
        "params_file": params_path.name,
        "image": image_url,
        "galleries": [gallery_png] if gallery_png else [],
        "manifest": manifest,
        "demo_frame": True,
    }


def list_example_params(plugin_id: str) -> list[dict[str, Any]]:
    plugin_dir = plugin_path(plugin_id)
    gallery_dir = plugin_dir / "all_examples_gallery"
    params_paths = {path.name: path for path in plugin_dir.glob("example_*_params.json")}

    def read_params(path: Path | None) -> dict[str, Any]:
        if path is None:
            return {}
        try:
            value = json.loads(path.read_text(encoding="utf-8"))
            return value if isinstance(value, dict) else {}
        except Exception:
            return {}

    def image_name(value: Any) -> str | None:
        if not isinstance(value, str) or not value.strip():
            return None
        # Metadata is allowed to use either a basename or a gallery-relative
        # path, but never gets to select a file outside all_examples_gallery.
        name = Path(value).name
        if Path(name).suffix.lower() != ".png":
            return None
        image = gallery_dir / name
        return name if image.is_file() else None

    def record_for(params_file: str | None, metadata: dict[str, Any] | None = None) -> dict[str, Any]:
        metadata = metadata or {}
        path = params_paths.get(Path(params_file).name) if params_file else None
        params = read_params(path)
        if not params and isinstance(metadata.get("params"), dict):
            params = metadata["params"]
        type_value = params.get("plot_type", params.get("plot_kind"))
        if type_value is None:
            type_value = metadata.get("plot_type")
        mode_value = params.get("input_mode", params.get("plot_mode"))
        if mode_value is None:
            mode_value = metadata.get("mode", metadata.get("input_mode", metadata.get("plot_mode")))
        image = image_name(metadata.get("image"))
        if image is None and path is not None:
            derived_stem = path.stem.removesuffix("_params").removeprefix("example_")
            derived = derived_stem + ".png"
            image = image_name(derived)
        name = path.name if path else (Path(params_file).name if params_file else "")
        label = metadata.get("label") or (path.stem.removesuffix("_params").removeprefix("example_") if path else name)
        result: dict[str, Any] = {
            # name/path remain part of the old API consumed by app.js.
            "name": name,
            "path": str(path.relative_to(ROOT_DIR)) if path else (str((plugin_dir / name).relative_to(ROOT_DIR)) if name else ""),
            "label": label,
            "params_file": name or params_file,
            "image": f"/api/plugins/{plugin_id}/gallery/{image}" if image else None,
            "params": params,
        }
        legacy_id = (path.stem.removesuffix("_params").removeprefix("example_") if path else name)
        result.update({"id": legacy_id, "bundle": None, "inputs": {}, "expected": result["image"]})
        if type_value is not None:
            result["plot_type"] = type_value
        if mode_value is not None:
            result["mode"] = mode_value
        return result

    bundle_records = []
    examples_dir = plugin_dir / "examples"
    if examples_dir.is_dir():
        index_path = examples_dir / "index.json"
        indexed: Any = None
        if index_path.is_file():
            try:
                indexed = json.loads(index_path.read_text(encoding="utf-8"))
            except Exception:
                indexed = None
        entries = indexed.get("examples") if isinstance(indexed, dict) else indexed
        if not isinstance(entries, list):
            entries = [{"id": p.name} for p in sorted(examples_dir.iterdir()) if p.is_dir()]
        for entry in entries:
            if not isinstance(entry, dict) or not entry.get("id"):
                continue
            try:
                bundle = example_bundle(plugin_id, str(entry["id"]))
                manifest = read_example_manifest(bundle)
            except HTTPException:
                continue
            bundle_records.append(example_record(plugin_id, bundle, manifest, entry))
    if bundle_records:
        return bundle_records

    metadata_path = plugin_dir / "example_gallery.json"
    if metadata_path.is_file():
        try:
            metadata_value = json.loads(metadata_path.read_text(encoding="utf-8"))
            metadata_records = metadata_value.get("examples") if isinstance(metadata_value, dict) else metadata_value
            if isinstance(metadata_records, list):
                return [record_for(item.get("params_file"), item) for item in metadata_records if isinstance(item, dict)]
        except Exception:
            pass

    return [record_for(path.name) for path in sorted(params_paths.values(), key=lambda item: item.name)]


def public_style_card(example: dict[str, Any]) -> dict[str, Any]:
    """Gallery-safe preset card (no params payload)."""
    group = str(example.get("card_group") or "")
    example_id = str(example.get("id") or "")
    if not group:
        group = "pdf_styles" if example_id.startswith("pdf_repro_") else "more"
    return {
        "id": example.get("id"),
        "example_id": example.get("id"),
        "label": example.get("label") or example.get("name") or example.get("id"),
        "blurb": example.get("blurb") or "",
        "howto": example.get("howto") or "",
        "card_group": group,
        "image": example.get("image") or example.get("expected"),
        "plot_type": example.get("plot_type"),
        "mode": example.get("mode"),
        "engine_plugin_id": example.get("plugin_id") or example.get("engine_plugin_id"),
    }


def _variant_gallery_image(engine: str, variant: dict[str, Any], example_id: str | None) -> str | None:
    asset = variant.get("preview_asset")
    if asset:
        return f"/api/plugins/{engine}/gallery/{Path(str(asset)).name}"
    if example_id:
        gallery = PLUGIN_DIR / engine / "all_examples_gallery"
        for name in (f"{example_id}.png", f"{example_id}_1.png"):
            if (gallery / name).is_file():
                return f"/api/plugins/{engine}/gallery/{name}"
    return None


def _extra_gallery_styles(plot: dict[str, Any], engine: str) -> list[dict[str, Any]]:
    styles: list[dict[str, Any]] = []
    for item in plot.get("extra_gallery") or []:
        if not isinstance(item, dict):
            continue
        gallery = item.get("gallery") if isinstance(item.get("gallery"), dict) else {}
        if gallery.get("visible") is False:
            continue
        example_id = item.get("example_id") or item.get("id")
        extra_engine = str(item.get("engine_plugin_id") or engine)
        section = str(gallery.get("section") or "more")
        styles.append(
            {
                "id": item.get("id") or example_id,
                "variant_id": item.get("variant_id") or item.get("id") or example_id,
                "example_id": example_id,
                "engine_plugin_id": extra_engine,
                "label": item.get("name") or item.get("label") or example_id,
                "blurb": item.get("short_description") or item.get("description") or "",
                "howto": "",
                "card_group": "recommended" if section == "recommended" else "more",
                "image": _variant_gallery_image(extra_engine, item, str(example_id) if example_id else None),
                "legacy_ids": item.get("legacy_ids") or [],
            }
        )
    return styles


def _merge_style_lists(base: list[dict[str, Any]], extra: list[dict[str, Any]]) -> list[dict[str, Any]]:
    seen = {str(item.get("id") or item.get("example_id") or "") for item in base}
    out = list(base)
    for item in extra:
        key = str(item.get("id") or item.get("example_id") or "")
        if key and key in seen:
            continue
        if key:
            seen.add(key)
        out.append(item)
    return out


def _style_payload(plot: dict[str, Any], plot_id: str, engine: str, styles: list[dict[str, Any]]) -> dict[str, Any]:
    recommended_count = sum(1 for item in styles if item.get("card_group") == "recommended")
    n = len(styles)
    if recommended_count:
        count_label = f"{recommended_count} recommended of {n} variants"
    elif n == 1:
        count_label = "1 visualization variant"
    else:
        count_label = f"{n} visualization variants"
    return {
        "plot_id": plot.get("id") or plot_id,
        "name": plot.get("name"),
        "description": plot.get("description") or "",
        "engine_plugin_id": engine,
        "variant_count": n,
        "recommended_count": recommended_count,
        "count": n,
        "count_label": count_label,
        "styles": styles,
    }


def list_plot_styles(plot_id: str) -> dict[str, Any]:
    plot = get_plot(plot_id)
    if not plot:
        raise HTTPException(status_code=404, detail="Plot family not found")
    engine = str(plot.get("engine_plugin_id") or plot_id)
    extras = _extra_gallery_styles(plot, engine)
    variants = visible_variants(plot)
    curated = any(isinstance((v or {}).get("gallery"), dict) for v in (plot.get("variants") or []))
    if curated and variants:
        demos = list(plot.get("demos") or [])
        styles: list[dict[str, Any]] = []
        for variant in variants:
            section = str((variant.get("gallery") or {}).get("section") or "more")
            example_id = variant.get("representative_example")
            if not example_id:
                hit = next((d for d in demos if d.get("variant") == variant.get("id")), None)
                example_id = (hit or {}).get("example_id") or (hit or {}).get("id")
            styles.append(
                {
                    "id": variant.get("id"),
                    "variant_id": variant.get("id"),
                    "example_id": example_id,
                    "engine_plugin_id": engine,
                    "label": variant.get("name") or variant.get("id"),
                    "blurb": variant.get("short_description") or variant.get("description") or "",
                    "howto": "",
                    "card_group": "recommended" if section == "recommended" else "more",
                    "image": _variant_gallery_image(engine, variant, str(example_id) if example_id else None),
                    "legacy_ids": variant.get("legacy_ids") or [],
                }
            )
        return _style_payload(plot, plot_id, engine, _merge_style_lists(styles, extras))
    examples = list_example_params(engine)
    styles = [public_style_card(item) for item in examples]
    for item in styles:
        item.setdefault("engine_plugin_id", engine)
        item.setdefault("example_id", item.get("id"))
    styles.sort(key=lambda item: 0 if item.get("card_group") == "pdf_styles" else 1)
    return _style_payload(plot, plot_id, engine, _merge_style_lists(styles, extras))


def gallery_files(plugin_id: str) -> list[Path]:
    gallery = PLUGIN_DIR / plugin_id / "all_examples_gallery"
    return sorted(path for path in gallery.glob("*.png") if path.is_file()) if gallery.is_dir() else []


def choose_demo_params(plugin_id: str) -> dict[str, Any] | None:
    plugin_dir = PLUGIN_DIR / plugin_id
    preferred = [
        "example_basic_params.json",
        "example_params.json",
        "example_heatmap_params.json",
        "example_summary_params.json",
        "example_group_params.json",
        "example_single_params.json",
    ]
    # Dimension / Feature plots: prefer PDF-matched real-data demos.
    if plugin_id == "advanced_dim_plot":
        preferred = [
            "example_basic_params.json",
            "example_pdf_basic_umap_params.json",
            "example_group_params.json",
        ] + [p for p in preferred if p not in {
            "example_basic_params.json", "example_group_params.json"
        }]
    if plugin_id == "advanced_feature_plot":
        preferred = [
            "example_basic_params.json",
            "example_multi_feature_params.json",
            "example_single_feature_params.json",
        ] + [p for p in preferred if p not in {
            "example_basic_params.json", "example_multi_feature_params.json",
            "example_single_feature_params.json",
        }]
    paths = [plugin_dir / name for name in preferred]
    paths.extend(sorted(plugin_dir.glob("example_*_params.json")))
    for path in paths:
        if not path.exists():
            continue
        try:
            params = json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            continue
        if isinstance(params, dict):
            return {"name": path.name, "path": str(path.relative_to(ROOT_DIR)), "params": params}
    return None


def choose_demo_file(plugin_id: str, field: str, input_info: dict[str, Any]) -> Path | None:
    plugin_dir = PLUGIN_DIR / plugin_id
    field = fieldForBackend(field)
    plugin_overrides = {
        ("violin_plot", "file"): ["example_long.csv", "example_matrix.csv"],
        # Prefer real all_p8_p7 embedding table for Advanced Dimension Plot demos.
        ("advanced_dim_plot", "file"): [
            "testdata/all_p8_p7_advdim_input.csv",
            "example_input.csv",
        ],
        ("advanced_dim_plot", "input"): [
            "testdata/all_p8_p7_advdim_input.csv",
            "example_input.csv",
        ],
        ("advanced_feature_plot", "file"): [
            "testdata/all_p8_p7_advfea_input.csv",
            "example_input.csv",
        ],
        ("advanced_feature_plot", "input"): [
            "testdata/all_p8_p7_advfea_input.csv",
            "example_input.csv",
        ],
        ("gsea_pathway_heatmap", "file"): ["example_ranks.csv", "example_input.csv"],
        ("gsea_pathway_heatmap", "input"): ["example_ranks.csv", "example_input.csv"],
        ("gsea_pathway_heatmap", "genesets"): ["example_pathways.gmt"],
        ("gsea_pathway_heatmap", "expr"): ["example_expression.csv"],
        ("gsea_pathway_heatmap", "enrichment"): ["example_enrichment.csv"],
        ("gsea_pathway_heatmap", "col_annot"): ["example_col_annot.csv"],
        ("gsea_ridge_nes_plot", "file"): ["example_ranks.csv"],
        ("gsea_ridge_nes_plot", "input"): ["example_ranks.csv"],
        ("gsea_ridge_nes_plot", "enrichment"): ["example_enrichment.csv"],
        ("gsea_ridge_nes_plot", "genesets"): ["example_pathways.gmt"],
        ("sca_volcano_plot", "regions"): ["example_regions.csv"],
        ("interactive_dual_triangle_heatmap_plot", "upper"): ["example_upper.csv"],
        ("interactive_dual_triangle_heatmap_plot", "lower"): ["example_lower.csv"],
        ("interactive_dual_triangle_heatmap_plot", "file"): ["example_upper.csv"],
        ("interactive_dual_triangle_heatmap_plot", "input"): ["example_upper.csv"],
        ("interactive_dual_triangle_heatmap_plot", "annotation"): ["example_annotation.csv"],
        ("interactive_dual_triangle_heatmap_plot", "annot"): ["example_annotation.csv"],
        ("interactive_mantel_correlation_network", "file"): ["example_env.csv", "example_corr.csv", "example_input.csv"],
        ("interactive_mantel_correlation_network", "input"): ["example_env.csv", "example_corr.csv", "example_input.csv"],
        ("interactive_mantel_correlation_network", "input2"): ["example_community.csv"],
        ("interactive_mantel_correlation_network", "mantel"): ["example_mantel.csv"],
        ("go_kegg_enrichment_bar_bubble", "file"): ["example_input.csv", "example_enrichment.csv"],
        ("go_kegg_enrichment_bar_bubble", "input"): ["example_input.csv", "example_enrichment.csv"],
    }
    override_names = plugin_overrides.get((plugin_id, field), [])
    candidates_by_field = {
        "file": [
            "example_input.csv",
            "example_matrix.csv",
            "example_markers.csv",
            "example_metadata.csv",
            "example_expression.csv",
            "example_fgsea_results.csv",
            "example_element_input.csv",
            "example_long.csv",
            "example_embedding.csv",
            "example_ranks.csv",
        ],
        "input": [
            "example_input.csv",
            "example_matrix.csv",
            "example_markers.csv",
            "example_metadata.csv",
            "example_expression.csv",
            "example_fgsea_results.csv",
            "example_element_input.csv",
            "example_long.csv",
            "example_embedding.csv",
            "example_ranks.csv",
        ],
        "input2": ["example_input2.csv", "example_matrix2.csv", "example_abundance_input.csv", "example_community.csv"],
        "mantel": ["example_mantel.csv"],
        "annot": ["example_annotation.csv", "example_annot.csv"],
        "annotation": ["example_annotation.csv", "example_annot.csv"],
        "expr": ["example_expression.csv", "example_matrix.csv"],
        "expression": ["example_expression.csv", "example_matrix.csv"],
        "genesets": ["example_pathways.gmt", "example_genesets.gmt", "example_pathways.csv", "example_pathways.tsv"],
        "embed": ["example_embedding.csv", "example_embed.csv"],
        "embedding": ["example_embedding.csv", "example_embed.csv"],
        "lineages": ["example_lineages.csv", "example_lineage.csv"],
        "lineage": ["example_lineages.csv", "example_lineage.csv"],
        "col_annot": ["example_col_annot.csv", "example_column_annotation.csv"],
        "row_annot": ["example_row_annot.csv", "example_row_annotation.csv"],
        "marks": ["example_marks.csv", "example_mark.csv"],
        "nodes": ["example_nodes.csv"],
        "matrix": ["example_matrix.csv", "example_dot_matrix.csv"],
        "comparisons": ["example_comparisons.csv", "example_pvalues.csv"],
        "enrichment": ["example_enrichment.csv", "example_fgsea_results.csv"],
        "regions": ["example_regions.csv"],
        "upper": ["example_upper.csv", "example_matrix.csv"],
        "lower": ["example_lower.csv", "example_matrix2.csv", "example_input2.csv"],
    }
    candidates = [plugin_dir / name for name in override_names]
    candidates.extend(plugin_dir / name for name in candidates_by_field.get(field, []))
    formats = input_info.get("formats") if isinstance(input_info, dict) else None
    # Only the main table field may fall back to a broad example_* glob.
    # Optional side tables (annot, marks, …) must match their preferred names
    # so they never silently bind to the wrong CSV.
    main_fields = {"file", "input"}
    if field in main_fields:
        if formats:
            for ext in formats:
                candidates.extend(sorted(plugin_dir.glob(f"example_*.{ext}")))
        candidates.extend(sorted(plugin_dir.glob("example_*.csv")))
        candidates.extend(sorted(plugin_dir.glob("example_*.tsv")))
        candidates.extend(sorted(plugin_dir.glob("example_*.txt")))
        candidates.extend(sorted(plugin_dir.glob("example_*.gmt")))
    for path in candidates:
        if path.exists() and path.is_file() and "params" not in path.name:
            return path
    return None


def fieldForBackend(field: str) -> str:
    return "file" if field == "input" else field


def demo_payload(plugin_id: str, config: dict[str, Any], example_id: str | None = None) -> dict[str, Any]:
    """Resolve canonical bundles first when selected, retaining legacy root-file support."""
    bundles = sorted((PLUGIN_DIR / plugin_id / 'examples').glob('*/manifest.json'))
    if example_id is not None or (bundles and not list((PLUGIN_DIR / plugin_id).glob('example_*.csv'))):
        if not bundles:
            if example_id:
                raise HTTPException(status_code=404, detail='This plot has no canonical example bundle.')
        else:
            selected = example_id or ('basic' if any(p.parent.name == 'basic' for p in bundles) else bundles[0].parent.name)
            bundle = example_bundle(plugin_id, selected)
            manifest = read_example_manifest(bundle)
            paths = {key: example_file(bundle, value) for key, value in (manifest.get('inputs') or {}).items()}
            required = [item.get('id') or item.get('name') or 'input' for item in config.get('inputs') or [] if item.get('required')]
            missing = [key for key in required if key not in paths and not (key == 'input' and 'file' in paths)]
            if missing:
                raise HTTPException(status_code=400, detail='Example is missing required inputs: ' + ', '.join(missing))
            params_path = example_file(bundle, manifest.get('params') or 'params.json')
            params = json.loads(params_path.read_text(encoding='utf-8'))
            files = {}
            for key, path in paths.items():
                record = {'filename': path.name, 'path': str(path.relative_to(ROOT_DIR)), 'field': key}
                if path.suffix.lower() in {'.csv', '.tsv', '.txt', '.xlsx', '.xlsm', '.xls'}:
                    record['preview'] = preview_table(path)
                files[key] = record
            return {'plugin_id': plugin_id, 'example_id': selected, 'params': params,
                    'files': files, '_file_paths': paths, 'examples': list_example_params(plugin_id),
                    'galleries': [str(path.relative_to(ROOT_DIR)) for path in gallery_files(plugin_id)]}

    inputs = config.get("inputs") if isinstance(config.get("inputs"), list) else []
    if not inputs:
        inputs = [{"name": "input", "id": "input", "type": "table", "required": True}]
    files: dict[str, dict[str, Any]] = {}
    file_paths: dict[str, Path] = {}
    for index, input_info in enumerate(inputs):
        raw_field = input_info.get("name") or input_info.get("id") or "input"
        field = "file" if raw_field == "input" and index == 0 else raw_field
        path = choose_demo_file(plugin_id, field, input_info)
        if not path:
            continue
        file_paths[field] = path
        record = {
            "filename": path.name,
            "path": str(path.relative_to(ROOT_DIR)),
            "field": field,
        }
        try:
            if path.suffix.lower() in {".csv", ".tsv", ".txt", ".xlsx", ".xlsm", ".xls"}:
                record["preview"] = preview_table(path)
        except Exception as exc:
            record["error"] = str(exc)
        files[field] = record
    params = choose_demo_params(plugin_id)
    examples = list_example_params(plugin_id)
    galleries = [str(path.relative_to(ROOT_DIR)) for path in gallery_files(plugin_id)]
    return {
        "plugin_id": plugin_id,
        "params": params,
        "files": files,
        "examples": examples,
        "galleries": galleries,
        "_file_paths": file_paths,
    }


def _hidden_plugin_ids() -> set[str]:
    return {str(x).lower() for x in (load_overrides().get("hidden_families") or [])}
