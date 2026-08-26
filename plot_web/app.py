from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import uuid
import csv
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yaml
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, HTMLResponse, JSONResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles

from plot_web.plot_registry import (
    browse_categories,
    discovery_taxonomy,
    get_all_plots,
    get_compatible_plots,
    get_plot,
    get_plots_by_context,
    get_plots_by_task,
    get_recommended_plots,
    get_variant,
    get_variants,
    resolve_legacy_preset,
    search_plots,
    validate_registry,
)


ROOT_DIR = Path(__file__).resolve().parents[1]
PLUGIN_DIR = ROOT_DIR / "plugins"
WEB_DIR = ROOT_DIR / "plot_web"
STATIC_DIR = WEB_DIR / "static"
STORAGE_DIR = WEB_DIR / "storage"
JOBS_DIR = STORAGE_DIR / "jobs"
UPLOADS_DIR = STORAGE_DIR / "uploads"
RESULTS_DIR = STORAGE_DIR / "results"
PREVIEWS_DIR = STORAGE_DIR / "previews"
DATASETS_DIR = STORAGE_DIR / "datasets"
STATE_DIR = STORAGE_DIR / "state"
REPORTS_DIR = STORAGE_DIR / "reports"
CURRENT_STATE_PATH = STATE_DIR / "current_state.json"

DEFAULT_DISPATCH_MODE = os.environ.get("PLOT_DISPATCH_MODE", "local")
MAX_LOCAL_SECONDS = int(os.environ.get("PLOT_LOCAL_TIMEOUT_SECONDS", "900"))

app = FastAPI(title="BioFigureAI Plot Plugin Local API", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://127.0.0.1:8000", "http://localhost:8000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def ensure_storage() -> None:
    for directory in (JOBS_DIR, UPLOADS_DIR, RESULTS_DIR, PREVIEWS_DIR, DATASETS_DIR, STATE_DIR, REPORTS_DIR):
        directory.mkdir(parents=True, exist_ok=True)


def safe_id(value: str) -> str:
    if not re.match(r"^[A-Za-z0-9_.-]+$", value):
        raise HTTPException(status_code=400, detail="Invalid id")
    return value


def read_yaml(path: Path) -> dict[str, Any]:
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
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
    explicit = str(category or "").strip()
    if explicit in {"Set", "Enrichment"}:
        return "Set / Enrichment"
    if explicit and explicit != "Plot":
        return explicit
    defaults = {
        "advanced_dim_plot": "Dimension",
        "lineage_plot": "Dimension",
        "advanced_feature_plot": "Feature",
        "feature_density_plot": "Feature",
        "quadrant_correlation_scatter": "Scatter",
        "sca_volcano_plot": "Scatter",
        "group_heatmap": "Heatmap",
        "threshold_matrix_heatmap": "Heatmap",
        "balloon_plot": "Heatmap",
        "den_plot": "Expression / Statistics",
        "dot_plot": "Expression / Statistics",
        "exp_stat_plot": "Expression / Statistics",
        "stacked_bar_plot": "Expression / Statistics",
        "combo_bar_line_plot": "Expression / Statistics",
        "classified_bar_plot": "Expression / Statistics",
        "regression_scatter_plot": "Scatter",
        "interactive_ridgeline_plot": "Expression / Statistics",
        "interactive_violin_plot": "Expression / Statistics",
        "interactive_pie_plot": "Expression / Statistics",
        "interactive_radar_plot": "Expression / Statistics",
        "interactive_dumbbell_plot": "Expression / Statistics",
        "interactive_binary_plot": "Heatmap",
        "interactive_correlation_matrix": "Heatmap",
        "interactive_network_plot": "Network",
        "interactive_sankey_plot": "Network",
        "interactive_mantel_correlation_network": "Network",
        "interactive_enrichment_lollipop": "Set / Enrichment",
        "cluster_dendrogram_plot": "Expression / Statistics",
        "stat_plot": "Expression / Statistics",
        "violin_plot": "Expression / Statistics",
        "dynamic_venn_diagram": "Set / Enrichment",
        "fgsea_enrichment_plot": "Set / Enrichment",
        "gsea_pathway_heatmap": "Set / Enrichment",
        "ranked_annotation_panel": "Multi-panel",
    }
    return defaults.get(plugin_id, "Plot")


def default_subcategory(category: str, plugin_id: str) -> str:
    mapping = {
        "Dimension": {
            "advanced_dim_plot": "Embedding",
            "lineage_plot": "Trajectory",
        },
        "Feature": {
            "advanced_feature_plot": "Expression map",
            "feature_density_plot": "Density",
        },
        "Heatmap": {
            "group_heatmap": "Grouped",
            "threshold_matrix_heatmap": "Matrix",
            "balloon_plot": "Matrix",
        },
        "Scatter": {
            "quadrant_correlation_scatter": "Correlation",
            "regression_scatter_plot": "Regression",
            "sca_volcano_plot": "Volcano",
        },
        "Expression / Statistics": {
            "exp_stat_plot": "Statistics",
            "dot_plot": "Expression",
            "den_plot": "Dendrogram",
            "stacked_bar_plot": "Composition",
            "combo_bar_line_plot": "Combo",
            "classified_bar_plot": "Bar",
            "interactive_ridgeline_plot": "Ridgeline",
        },
        "Set / Enrichment": {
            "dynamic_venn_diagram": "Set",
            "fgsea_enrichment_plot": "Enrichment",
            "gsea_pathway_heatmap": "GSEA + Heatmap",
            "interactive_enrichment_lollipop": "Enrichment",
        },
        "Multi-panel": {
            "ranked_annotation_panel": "Annotation",
        },
    }
    return mapping.get(category, {}).get(plugin_id, "General")


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
        return normalize_params_schema(schema) or schema
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
        "label": example.get("label") or example.get("name") or example.get("id"),
        "blurb": example.get("blurb") or "",
        "howto": example.get("howto") or "",
        "card_group": group,
        "image": example.get("image") or example.get("expected"),
        "plot_type": example.get("plot_type"),
        "mode": example.get("mode"),
    }


def list_plot_styles(plot_id: str) -> dict[str, Any]:
    plot = get_plot(plot_id)
    if not plot:
        raise HTTPException(status_code=404, detail="Plot family not found")
    engine = str(plot.get("engine_plugin_id") or plot_id)
    examples = list_example_params(engine)
    styles = [public_style_card(item) for item in examples]
    styles.sort(key=lambda item: 0 if item.get("card_group") == "pdf_styles" else 1)
    return {
        "plot_id": plot.get("id") or plot_id,
        "name": plot.get("name"),
        "description": plot.get("description") or "",
        "engine_plugin_id": engine,
        "variant_count": len(plot.get("variants") or []),
        "count": len(styles),
        "styles": styles,
    }


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
        "input2": ["example_input2.csv", "example_matrix2.csv", "example_abundance_input.csv"],
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


def demo_payload(plugin_id: str, config: dict[str, Any]) -> dict[str, Any]:
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


def job_file(job_id: str) -> Path:
    return JOBS_DIR / safe_id(job_id) / "job.json"


def save_job(job: dict[str, Any]) -> None:
    path = job_file(job["job_id"])
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(job, indent=2, ensure_ascii=False), encoding="utf-8")


def list_jobs() -> list[dict[str, Any]]:
    ensure_storage()
    jobs = []
    for path in sorted(JOBS_DIR.glob("*/job.json"), reverse=True):
        try:
            jobs.append(json.loads(path.read_text(encoding="utf-8")))
        except Exception:
            continue
    return jobs


def load_job(job_id: str) -> dict[str, Any]:
    path = job_file(job_id)
    if not path.exists():
        raise HTTPException(status_code=404, detail="Job not found")
    return json.loads(path.read_text(encoding="utf-8"))


def figure_to_job(figure_id: str) -> dict[str, Any]:
    figure_id = safe_id(figure_id)
    for path in JOBS_DIR.glob("*/job.json"):
        try:
            job = json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            continue
        if job.get("figure_id") == figure_id:
            return job
    raise HTTPException(status_code=404, detail="Figure not found")


def output_urls(figure_id: str) -> dict[str, str]:
    return {
        "svg": f"/api/figures/{figure_id}/download/svg",
        "pdf": f"/api/figures/{figure_id}/download/pdf",
        "png": f"/api/figures/{figure_id}/download/png",
        "json": f"/api/figures/{figure_id}/download/json",
        "log": f"/api/figures/{figure_id}/download/log",
        "preview": f"/api/figures/{figure_id}/preview",
    }


def output_urls_for_dir(figure_id: str, result_dir: Path | None = None) -> dict[str, str]:
    urls = output_urls(figure_id)
    if not result_dir or not result_dir.exists():
        return urls
    names = {
        "result.svg": "svg",
        "result.pdf": "pdf",
        "result.png": "png",
        "figure.json": "json",
        "run.log": "log",
        "selected_rows.csv": "selected_rows",
        "selected_points.csv": "selected_points",
        "selected_features.csv": "selected_features",
        "subset_elements.csv": "subset_elements",
        "subsets.csv": "subsets",
        "subset_elements_long.csv": "subset_elements_long",
        "set_sizes.csv": "set_sizes",
        "matrix_used.csv": "matrix_used",
        "annotation_used.csv": "annotation_used",
        "enrichment_results.csv": "enrichment_results",
    }
    for filename, key in names.items():
        if (result_dir / filename).exists():
            urls[key] = f"/api/figures/{figure_id}/download/{key}"
    return urls


def output_file_for_type(result_dir: Path, file_type: str) -> Path:
    file_map = {
        "svg": "result.svg",
        "pdf": "result.pdf",
        "png": "result.png",
        "json": "figure.json",
        "figure_json": "figure.json",
        "log": "run.log",
        "selected_rows": "selected_rows.csv",
        "selected_points": "selected_points.csv",
        "selected_features": "selected_features.csv",
        "subset_elements": "subset_elements.csv",
        "subsets": "subsets.csv",
        "subset_elements_long": "subset_elements_long.csv",
        "set_sizes": "set_sizes.csv",
        "matrix_used": "matrix_used.csv",
        "annotation_used": "annotation_used.csv",
        "enrichment_results": "enrichment_results.csv",
    }
    if file_type in file_map:
        return result_dir / file_map[file_type]
    safe = safe_id(file_type)
    for ext in (".csv", ".tsv", ".txt", ".json", ".png", ".svg", ".pdf", ".log"):
        candidate = result_dir / f"{safe}{ext}"
        if candidate.exists():
            return candidate
    raise HTTPException(status_code=400, detail="Unsupported file type")


def guess_delimiter(sample: str, filename: str) -> str:
    from plot_web.table_io import guess_delimiter as _guess

    return _guess(sample, filename)


def is_number(value: Any) -> bool:
    if value is None:
        return False
    text = str(value).strip()
    if text == "":
        return False
    try:
        float(text)
        return True
    except ValueError:
        return False


def preview_table(path: Path, max_rows: int = 80) -> dict[str, Any]:
    """Preview CSV/TSV/TXT or Excel (.xlsx) tables."""
    from plot_web.table_io import is_table_file, read_table_as_dicts

    if not is_table_file(path):
        raise ValueError(f"Unsupported table type: {path.suffix}")
    columns, rows, meta = read_table_as_dicts(path, max_rows=max_rows)
    numeric_columns = [
        col
        for col in columns
        if rows and sum(1 for row in rows if is_number(row.get(col))) >= max(1, int(len(rows) * 0.7))
    ]
    out = {
        "filename": path.name,
        "delimiter": meta.get("delimiter") or ",",
        "columns": columns,
        "numeric_columns": numeric_columns,
        "preview_rows": rows,
        "row_count_estimate": int(meta.get("row_count_estimate") or len(rows)),
        "column_count": len(columns),
        "format": meta.get("format"),
    }
    if meta.get("excel"):
        out["excel"] = True
        out["sheet"] = meta.get("sheet", 0)
    return out


def default_state() -> dict[str, Any]:
    return {
        "active_dataset_id": None,
        "active_plugin_id": None,
        "data_map": {"nodes": [], "edges": []},
        "recent_jobs": [],
        "ui": {"selected_mode": "workspace"},
    }


def load_state() -> dict[str, Any]:
    ensure_storage()
    if not CURRENT_STATE_PATH.exists():
        return default_state()
    try:
        data = json.loads(CURRENT_STATE_PATH.read_text(encoding="utf-8"))
    except Exception:
        return default_state()
    base = default_state()
    base.update(data if isinstance(data, dict) else {})
    base.setdefault("data_map", {"nodes": [], "edges": []})
    base.setdefault("recent_jobs", [])
    base.setdefault("ui", {"selected_mode": "workspace"})
    return base


def save_state(data: dict[str, Any]) -> dict[str, Any]:
    ensure_storage()
    CURRENT_STATE_PATH.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    return data


def upsert_node(state: dict[str, Any], node: dict[str, Any]) -> None:
    nodes = state.setdefault("data_map", {}).setdefault("nodes", [])
    for idx, existing in enumerate(nodes):
        if existing.get("id") == node.get("id"):
            nodes[idx] = {**existing, **node}
            return
    nodes.append(node)


def upsert_edge(state: dict[str, Any], edge: dict[str, Any]) -> None:
    edges = state.setdefault("data_map", {}).setdefault("edges", [])
    edge_id = edge.get("id") or f"{edge.get('source')}->{edge.get('target')}"
    edge["id"] = edge_id
    for idx, existing in enumerate(edges):
        if existing.get("id") == edge_id:
            edges[idx] = {**existing, **edge}
            return
    edges.append(edge)


def record_job_in_state(job: dict[str, Any], source_dataset_id: str | None = None) -> None:
    state = load_state()
    plugin_id = job.get("plugin_id")
    job_id = job.get("job_id")
    result_id = f"result_{job_id}"
    if source_dataset_id:
        upsert_node(state, {"id": source_dataset_id, "type": "dataset", "label": source_dataset_id, "created_at": job.get("created_at")})
    upsert_node(
        state,
        {
            "id": job_id,
            "type": "plot_run",
            "label": plugin_id,
            "plugin_id": plugin_id,
            "status": job.get("status"),
            "created_at": job.get("created_at"),
            "output_dir": job.get("output_dir"),
        },
    )
    upsert_node(
        state,
        {
            "id": result_id,
            "type": "result",
            "label": f"{plugin_id} result",
            "job_id": job_id,
            "figure_id": job.get("figure_id"),
            "outputs": job.get("outputs", {}),
            "created_at": job.get("finished_at") or job.get("created_at"),
        },
    )
    if source_dataset_id:
        upsert_edge(state, {"source": source_dataset_id, "target": job_id, "type": "plot_run", "label": plugin_id})
    upsert_edge(state, {"source": job_id, "target": result_id, "type": "produced", "label": "produced"})
    recent = [item for item in state.setdefault("recent_jobs", []) if item.get("job_id") != job_id]
    recent.insert(0, {"job_id": job_id, "plugin_id": plugin_id, "status": job.get("status"), "created_at": job.get("created_at"), "output_dir": job.get("output_dir")})
    state["recent_jobs"] = recent[:50]
    state["active_plugin_id"] = plugin_id
    save_state(state)


async def save_uploads(request: Request, upload_dir: Path) -> tuple[dict[str, Path], dict[str, str]]:
    """Save multipart uploads. Excel (.xlsx) tables are converted to CSV for plugins."""
    from plot_web.table_io import ensure_tabular_csv, is_excel_file

    form = await request.form()
    saved_files: dict[str, Path] = {}
    text_fields: dict[str, str] = {}
    upload_dir.mkdir(parents=True, exist_ok=True)
    sheet = form.get("sheet")
    for key, value in form.multi_items():
        filename = getattr(value, "filename", None)
        if filename:
            safe_name = Path(filename).name
            target = upload_dir / f"{key}__{safe_name}"
            with target.open("wb") as handle:
                shutil.copyfileobj(value.file, handle)
            if is_excel_file(target):
                try:
                    from plot_web.table_io import sanitize_sheet_name

                    csv_path = ensure_tabular_csv(
                        target,
                        sheet=sanitize_sheet_name(str(sheet) if sheet is not None else None),
                        out=target.with_suffix(".csv"),
                    )
                    saved_files[key] = csv_path
                    # keep original workbook path for reference
                    text_fields[f"{key}__original_excel"] = str(target)
                except Exception as exc:
                    raise HTTPException(
                        status_code=400,
                        detail=f"Failed to read Excel file {safe_name}: {exc}",
                    ) from exc
            else:
                saved_files[key] = target
        else:
            text_fields[key] = str(value)
    return saved_files, text_fields


def parse_params(text_fields: dict[str, str], plugin_id: str) -> dict[str, Any]:
    params_raw = text_fields.get("params", "{}")
    try:
        params = json.loads(params_raw) if params_raw.strip() else {}
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=400, detail=f"Invalid params JSON: {exc}") from exc
    if not isinstance(params, dict):
        raise HTTPException(status_code=400, detail="params must be a JSON object")
    params["plugin_id"] = plugin_id
    params.setdefault("dispatch_mode", DEFAULT_DISPATCH_MODE)
    return params


def choose_main_input(saved_files: dict[str, Path]) -> Path:
    for key in ("file", "input"):
        if key in saved_files:
            return saved_files[key]
    # Prefer ranked-gene tables over expression matrices when the main
    # field was not bound (common for multi-input GSEA plugins).
    for path in saved_files.values():
        name = path.name.lower()
        if "rank" in name or name in {"example_input.csv", "example_markers.csv"}:
            return path
    if saved_files:
        return next(iter(saved_files.values()))
    raise HTTPException(status_code=400, detail="No input file uploaded")


def build_command(plugin_id: str, config: dict[str, Any], saved_files: dict[str, Path], params_path: Path, output_dir: Path) -> list[str]:
    path = plugin_path(plugin_id)
    entrypoint = config.get("entrypoint") or "plot.R"
    language = infer_language(config)
    if language.lower() == "python":
        cmd = ["python3", str(path / entrypoint)]
    else:
        cmd = ["Rscript", str(path / entrypoint)]

    cmd.extend(["--input", str(choose_main_input(saved_files)), "--params", str(params_path), "--output", str(output_dir)])
    optional_flags = {
        "input2": "--input2",
        "annot": "--annot",
        "annotation": "--annot",
        "expr": "--expr",
        "expression": "--expr",
        "genesets": "--genesets",
        "embed": "--embed",
        "embedding": "--embed",
        "lineages": "--lineages",
        "lineage": "--lineages",
        "col_annot": "--col_annot",
        "row_annot": "--row_annot",
        "marks": "--marks",
        "nodes": "--nodes",
        "matrix": "--matrix",
        "comparisons": "--comparisons",
        "enrichment": "--enrichment",
        "col-annot": "--col-annot",
    }
    for key, flag in optional_flags.items():
        if key in saved_files:
            cmd.extend([flag, str(saved_files[key])])
    return cmd


def run_local_job(job: dict[str, Any], cmd: list[str], plugin_dir: Path, output_dir: Path) -> dict[str, Any]:
    job["status"] = "running"
    job["message"] = "Plugin is running locally."
    job["started_at"] = utc_now()
    job["command"] = cmd
    save_job(job)
    try:
        result = subprocess.run(
            cmd,
            cwd=str(ROOT_DIR),
            capture_output=True,
            text=True,
            timeout=MAX_LOCAL_SECONDS,
        )
    except subprocess.TimeoutExpired as exc:
        error = {"error": "Plugin timed out", "detail": str(exc), "suggestion": "Increase timeout or reduce input size."}
        job.update({"status": "failed", "finished_at": utc_now(), "error": error})
        save_job(job)
        record_job_in_state(job, job.get("dataset_id"))
        return job

    (output_dir / "subprocess.stdout.log").write_text(result.stdout or "", encoding="utf-8")
    (output_dir / "subprocess.stderr.log").write_text(result.stderr or "", encoding="utf-8")
    if result.returncode != 0:
        error_path = output_dir / "error.json"
        if error_path.exists():
            try:
                error = json.loads(error_path.read_text(encoding="utf-8"))
            except Exception:
                error = {"error": "Plugin failed", "detail": error_path.read_text(encoding="utf-8"), "suggestion": "Inspect run.log."}
        else:
            error = {"error": "Plugin failed", "detail": result.stderr or result.stdout, "suggestion": "Inspect params and input columns."}
        job.update({"status": "failed", "finished_at": utc_now(), "returncode": result.returncode, "error": error})
        save_job(job)
        record_job_in_state(job, job.get("dataset_id"))
        return job

    figure_id = job["figure_id"]
    job.update(
        {
            "status": "completed",
            "message": "Plugin completed locally.",
            "finished_at": utc_now(),
            "returncode": result.returncode,
            "outputs": output_urls_for_dir(figure_id, output_dir),
        }
    )
    save_job(job)
    record_job_in_state(job, job.get("dataset_id"))
    return job


@app.get("/", response_class=HTMLResponse)
@app.get("/plots", response_class=HTMLResponse)
@app.get("/analysis", response_class=HTMLResponse)
@app.get("/analysis/{context}", response_class=HTMLResponse)
@app.get("/analysis/{context}/{task}", response_class=HTMLResponse)
@app.get("/family/{plot_id}", response_class=HTMLResponse)
def index(context: str | None = None, task: str | None = None, plot_id: str | None = None) -> str:
    return (STATIC_DIR / "index.html").read_text(encoding="utf-8")


@app.get("/plot/{plot_id}")
@app.get("/plot/{plot_id}/{variant_id}")
def plot_studio_entry(
    plot_id: str,
    variant_id: str | None = None,
    source_context: str | None = None,
    source_task: str | None = None,
    example: str | None = None,
) -> RedirectResponse:
    plot = get_plot(plot_id)
    engine = str((plot or {}).get("engine_plugin_id") or plot_id)
    family = str((plot or {}).get("id") or plot_id)
    params = [f"plugin={engine}", f"plot={family}"]
    if variant_id:
        params.append(f"variant={variant_id}")
    if example:
        params.append(f"example={example}")
    if source_context:
        params.append(f"source_context={source_context}")
    if source_task:
        params.append(f"source_task={source_task}")
    return RedirectResponse("/static/editor.html?" + "&".join(params))


@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "biofigureai-backend", "dispatch_mode": DEFAULT_DISPATCH_MODE}


@app.get("/api/state")
def get_state() -> dict[str, Any]:
    return load_state()


@app.post("/api/state/save")
async def post_state_save(request: Request) -> dict[str, Any]:
    data = await request.json()
    if not isinstance(data, dict):
        raise HTTPException(status_code=400, detail="State must be an object")
    return save_state(data)


@app.post("/api/state/load")
def post_state_load() -> dict[str, Any]:
    return load_state()


@app.get("/api/datasets")
def list_datasets() -> dict[str, Any]:
    ensure_storage()
    datasets = []
    for path in sorted(DATASETS_DIR.glob("*/dataset.json"), reverse=True):
        try:
            datasets.append(json.loads(path.read_text(encoding="utf-8")))
        except Exception:
            continue
    return {"datasets": datasets}


@app.get("/api/datasets/{dataset_id}")
def get_dataset(dataset_id: str) -> dict[str, Any]:
    path = DATASETS_DIR / safe_id(dataset_id) / "dataset.json"
    if not path.exists():
        raise HTTPException(status_code=404, detail="Dataset not found")
    return json.loads(path.read_text(encoding="utf-8"))


@app.post("/api/datasets/upload")
async def upload_dataset(request: Request) -> JSONResponse:
    ensure_storage()
    form = await request.form()
    dataset_name = str(form.get("dataset_name") or "Uploaded dataset")
    role = str(form.get("role") or "primary_table")
    notes = str(form.get("notes") or "")
    dataset_id = "dataset_" + datetime.now().strftime("%Y%m%d_%H%M%S_") + uuid.uuid4().hex[:8]
    dataset_dir = DATASETS_DIR / dataset_id
    saved_files, _ = await save_uploads(request, dataset_dir)
    roles = {}
    for field, path in saved_files.items():
      file_role = role if field in {"file", "input"} else field
      record = {"path": str(path), "filename": path.name}
      try:
          if path.suffix.lower() in {".csv", ".tsv", ".txt", ".xlsx", ".xlsm", ".xls"}:
              record.update(preview_table(path))
      except Exception as exc:
          record["error"] = str(exc)
      roles[file_role] = record
    dataset = {"dataset_id": dataset_id, "name": dataset_name, "roles": roles, "notes": notes, "created_at": utc_now()}
    (dataset_dir / "dataset.json").write_text(json.dumps(dataset, indent=2, ensure_ascii=False), encoding="utf-8")
    state = load_state()
    state["active_dataset_id"] = dataset_id
    upsert_node(state, {"id": dataset_id, "type": "dataset", "label": dataset_name, "created_at": dataset["created_at"], "roles": list(roles)})
    save_state(state)
    return JSONResponse(dataset)


@app.post("/api/datasets/{dataset_id}/derive")
async def derive_dataset(dataset_id: str, request: Request) -> dict[str, Any]:
    parent = get_dataset(dataset_id)
    data = await request.json()
    derived_id = "dataset_" + datetime.now().strftime("%Y%m%d_%H%M%S_") + uuid.uuid4().hex[:8]
    derived = {**parent, "dataset_id": derived_id, "name": data.get("name") or f"{parent.get('name')} subset", "parent_dataset_id": dataset_id, "notes": data.get("notes", ""), "created_at": utc_now()}
    derived_dir = DATASETS_DIR / derived_id
    derived_dir.mkdir(parents=True, exist_ok=True)
    (derived_dir / "dataset.json").write_text(json.dumps(derived, indent=2, ensure_ascii=False), encoding="utf-8")
    state = load_state()
    upsert_node(state, {"id": derived_id, "type": "dataset", "label": derived["name"], "created_at": derived["created_at"]})
    upsert_edge(state, {"source": dataset_id, "target": derived_id, "type": "derive", "label": "derive"})
    save_state(state)
    return derived


@app.get("/api/plugins")
def list_plugins() -> dict[str, Any]:
    plugins = []
    for config_path in sorted(PLUGIN_DIR.glob("*/config.yaml")):
        plugin_id = config_path.parent.name
        plugins.append(plugin_summary(plugin_id, read_yaml(config_path)))
    return {"plugins": plugins}


@app.get("/api/plugins/tree")
def plugin_tree() -> dict[str, Any]:
    category_map: dict[str, dict[str, Any]] = {}
    for config_path in sorted(PLUGIN_DIR.glob("*/config.yaml")):
        plugin_id = config_path.parent.name
        summary = plugin_summary(plugin_id, read_yaml(config_path))
        category = summary.get("category") or "Plot"
        subcategory = summary.get("subcategory") or "General"
        category_node = category_map.setdefault(category, {"name": category, "subcategories": {}})
        sub_node = category_node["subcategories"].setdefault(subcategory, {"name": subcategory, "plugins": []})
        sub_node["plugins"].append(summary)

    preferred = [
        "Dimension",
        "Feature",
        "Heatmap",
        "Scatter",
        "Expression / Statistics",
        "Set / Enrichment",
        "Network",
        "Multi-panel",
        "Plot",
    ]
    categories = []
    for name in preferred + sorted(k for k in category_map if k not in preferred):
        if name not in category_map:
            continue
        node = category_map[name]
        node["subcategories"] = [
            node["subcategories"][key]
            for key in sorted(node["subcategories"])
        ]
        categories.append(node)
    return {"categories": categories}


@app.get("/api/plugins/{plugin_id}")
def get_plugin(plugin_id: str) -> dict[str, Any]:
    config = read_yaml(plugin_config_path(plugin_id))
    config.setdefault("id", plugin_id)
    config.setdefault("entrypoint", "plot.R")
    config.setdefault("language", infer_language(config))
    config.setdefault("category", plugin_summary(plugin_id, config)["category"])
    config.setdefault("subcategory", plugin_summary(plugin_id, config)["subcategory"])
    config["params_schema"] = effective_params_schema(plugin_id, config)
    config["examples"] = list_example_params(plugin_id)
    config["galleries"] = [str(path.relative_to(ROOT_DIR)) for path in gallery_files(plugin_id)]
    demo = demo_payload(plugin_id, config)
    demo.pop("_file_paths", None)
    config["demo"] = demo
    family = get_plot(plugin_id)
    if family:
        config["registry"] = {
            "family_id": family.get("id"),
            "variants": [v.get("id") for v in family.get("variants") or []],
            "presets": [p.get("id") for p in family.get("presets") or []],
        }
    return config


@app.get("/api/plugins/{plugin_id}/demo")
def get_plugin_demo(plugin_id: str) -> dict[str, Any]:
    config = read_yaml(plugin_config_path(plugin_id))
    demo = demo_payload(plugin_id, config)
    demo.pop("_file_paths", None)
    return demo


@app.get("/api/registry/plots")
def registry_list_plots() -> dict[str, Any]:
    plots = get_all_plots()
    return {"plots": plots, "count": len(plots)}


@app.get("/api/registry/plots/{plot_id}")
def registry_get_plot(plot_id: str) -> dict[str, Any]:
    plot = get_plot(plot_id)
    if not plot:
        raise HTTPException(status_code=404, detail="Plot family not found")
    return plot


@app.get("/api/registry/plots/{plot_id}/styles")
def registry_get_styles(plot_id: str) -> dict[str, Any]:
    return list_plot_styles(plot_id)


@app.get("/api/registry/plots/{plot_id}/variants")
def registry_get_variants(plot_id: str) -> dict[str, Any]:
    if not get_plot(plot_id):
        raise HTTPException(status_code=404, detail="Plot family not found")
    return {"plot_id": plot_id, "variants": get_variants(plot_id)}


@app.get("/api/registry/plots/{plot_id}/variants/{variant_id}")
def registry_get_variant(plot_id: str, variant_id: str) -> dict[str, Any]:
    variant = get_variant(plot_id, variant_id)
    if not variant:
        raise HTTPException(status_code=404, detail="Variant not found")
    return variant


@app.get("/api/registry/search")
def registry_search(q: str = "") -> dict[str, Any]:
    hits = search_plots(q)
    return {"query": q, "results": hits, "count": len(hits)}


@app.get("/api/registry/context/{context}")
def registry_by_context(context: str) -> dict[str, Any]:
    return {"context": context, "plots": get_plots_by_context(context)}


@app.get("/api/registry/task/{task}")
def registry_by_task(task: str) -> dict[str, Any]:
    return {"task": task, "plots": get_plots_by_task(task)}


@app.post("/api/registry/compatible")
async def registry_compatible(request: Request) -> dict[str, Any]:
    body = {}
    try:
        value = await request.json()
        if isinstance(value, dict):
            body = value
    except Exception:
        body = {}
    schema = body.get("dataSchema") or body.get("schema") or body
    return {"plots": get_compatible_plots(schema if isinstance(schema, dict) else {})}


@app.post("/api/registry/recommend")
async def registry_recommend(request: Request) -> dict[str, Any]:
    body: dict[str, Any] = {}
    try:
        value = await request.json()
        if isinstance(value, dict):
            body = value
    except Exception:
        body = {}
    schema = body.get("dataSchema") or body.get("schema") or {}
    context = body.get("context")
    return {"recommendations": get_recommended_plots(schema if isinstance(schema, dict) else {}, context)}


@app.get("/api/registry/legacy/{plot_id}/{legacy_preset_id}")
def registry_legacy(plot_id: str, legacy_preset_id: str) -> dict[str, Any]:
    resolved = resolve_legacy_preset(plot_id, legacy_preset_id)
    if not resolved:
        raise HTTPException(status_code=404, detail="Legacy preset not found")
    return resolved


@app.get("/api/registry/validate")
def registry_validate() -> dict[str, Any]:
    return validate_registry()


@app.get("/api/registry/discovery")
def registry_discovery() -> dict[str, Any]:
    return {
        "taxonomy": discovery_taxonomy(),
        "browse": browse_categories(),
    }


@app.get("/api/registry/discovery/taxonomy")
def registry_taxonomy() -> dict[str, Any]:
    return discovery_taxonomy()


@app.get("/api/registry/discovery/browse")
def registry_browse() -> dict[str, Any]:
    return browse_categories()


@app.get("/api/plugins/{plugin_id}/examples/{example_id}")
def get_plugin_example(plugin_id: str, example_id: str) -> dict[str, Any]:
    bundle = example_bundle(plugin_id, example_id)
    manifest = read_example_manifest(bundle)
    record = example_record(plugin_id, bundle, manifest)
    reproduce = manifest.get("reproduce")
    command = reproduce.get("command") if isinstance(reproduce, dict) else None
    command = command or f"curl -X POST /api/plugins/{plugin_id}/run-demo -H 'Content-Type: application/json' -d '{{\"example_id\":\"{record['id']}\"}}'"
    return {
        "id": record["id"],
        "manifest": manifest,
        "params": record["params"],
        "params_url": record["params_url"],
        "inputs": record["inputs"],
        "expected": record["expected"],
        "plot_type": manifest.get("plot_type"),
        "mode": manifest.get("mode"),
        "reproducibility_command": command,
    }


@app.get("/api/plugins/{plugin_id}/examples/{example_id}/files/{filename:path}")
def get_plugin_example_file(plugin_id: str, example_id: str, filename: str) -> FileResponse:
    bundle = example_bundle(plugin_id, example_id)
    manifest = read_example_manifest(bundle)
    allowed_names = {"manifest.json", str(manifest.get("params", "params.json")), str(manifest.get("expected", ""))}
    allowed_names.update(str(value) for value in (manifest.get("inputs") or {}).values() if isinstance(value, str))
    requested = Path(filename).as_posix()
    if requested not in allowed_names:
        raise HTTPException(status_code=404, detail="Example file not found")
    path = example_file(bundle, filename)
    media_type = {
        ".json": "application/json",
        ".png": "image/png",
        ".csv": "text/csv",
        ".tsv": "text/tab-separated-values",
        ".txt": "text/plain",
        ".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        ".xls": "application/vnd.ms-excel",
    }.get(path.suffix.lower(), "application/octet-stream")
    return FileResponse(path, media_type=media_type, filename=path.name)


@app.get("/api/plugins/{plugin_id}/gallery/{filename}")
def plugin_gallery_image(plugin_id: str, filename: str) -> FileResponse:
    safe_id(plugin_id)
    safe_name = Path(filename).name
    path = PLUGIN_DIR / plugin_id / "all_examples_gallery" / safe_name
    if not path.is_file() or path.suffix.lower() != ".png":
        raise HTTPException(status_code=404, detail="Gallery image not found")
    return FileResponse(path, media_type="image/png")


@app.post("/api/plugins/{plugin_id}/preview-input")
async def preview_input(plugin_id: str, request: Request) -> JSONResponse:
    ensure_storage()
    plugin_path(plugin_id)
    preview_id = "preview_" + datetime.now().strftime("%Y%m%d_%H%M%S_") + uuid.uuid4().hex[:8]
    upload_dir = PREVIEWS_DIR / preview_id
    saved_files, _ = await save_uploads(request, upload_dir)
    files = {}
    for field, path in saved_files.items():
        try:
            files[field] = preview_table(path)
        except Exception as exc:
            files[field] = {"filename": path.name, "error": str(exc), "columns": [], "preview_rows": []}
    return JSONResponse({"preview_id": preview_id, "plugin_id": plugin_id, "files": files})


@app.post("/api/plugins/{plugin_id}/run-demo")
async def run_plugin_demo(plugin_id: str, request: Request) -> JSONResponse:
    ensure_storage()
    config = read_yaml(plugin_config_path(plugin_id))
    payload: dict[str, Any] = {}
    try:
        value = await request.json()
        if isinstance(value, dict):
            payload = value
    except Exception:
        pass

    example_id = payload.get("example_id")
    bundle_manifest = None
    if example_id is not None:
        bundle = example_bundle(plugin_id, str(example_id))
        bundle_manifest = read_example_manifest(bundle)
        record = example_record(plugin_id, bundle, bundle_manifest)
        demo = dict(record)
        saved_files: dict[str, Path] = {}
        upload_dir = UPLOADS_DIR / ("demo_" + uuid.uuid4().hex)
        upload_dir.mkdir(parents=True, exist_ok=True)
        for field, info in record["inputs"].items():
            source = example_file(bundle, str(info["path"]))
            target = upload_dir / source.name
            shutil.copy2(source, target)
            saved_files[field] = target
        params = dict(record["params"])
    else:
        demo = demo_payload(plugin_id, config)
        saved_files = demo.pop("_file_paths", {})
        if not saved_files:
            raise HTTPException(status_code=404, detail="No demo input files found for this plugin")
        demo_params = demo.get("params") or {"params": {}}
        params = dict(demo_params.get("params") or {})

    custom_params = payload.get("params")
    if isinstance(custom_params, dict):
        params.update(custom_params)

    params["plugin_id"] = plugin_id
    params.setdefault("dispatch_mode", DEFAULT_DISPATCH_MODE)

    job_id = "job_demo_" + datetime.now().strftime("%Y%m%d_%H%M%S_") + uuid.uuid4().hex[:8]
    figure_id = "fig_" + uuid.uuid4().hex[:12]
    output_dir = RESULTS_DIR / job_id
    job_dir = JOBS_DIR / job_id
    output_dir.mkdir(parents=True, exist_ok=True)
    job_dir.mkdir(parents=True, exist_ok=True)
    params_path = job_dir / "params.json"
    params_path.write_text(json.dumps(params, indent=2, ensure_ascii=False), encoding="utf-8")

    job = {
        "job_id": job_id,
        "figure_id": figure_id,
        "plugin_id": plugin_id,
        "dataset_id": f"dataset_demo_{plugin_id}",
        "status": "queued",
        "message": "Demo job accepted for local execution.",
        "created_at": utc_now(),
        "dispatch_mode": params.get("dispatch_mode", DEFAULT_DISPATCH_MODE),
        "upload_dir": str(PLUGIN_DIR / plugin_id),
        "output_dir": str(output_dir),
        "params_path": str(params_path),
        "uploaded_files": {k: str(v) for k, v in saved_files.items()},
        "demo": demo,
    }
    if example_id is not None:
        job["example_id"] = str(example_id)
        job["bundle_manifest"] = bundle_manifest
    state = load_state()
    upsert_node(state, {"id": job["dataset_id"], "type": "dataset", "label": f"{plugin_id} demo", "created_at": job["created_at"], "demo": True})
    save_state(state)
    save_job(job)

    if job["dispatch_mode"] != "local":
        job.update({"status": "queued", "message": "Non-local dispatch is reserved for future workers; local is the active default."})
        save_job(job)
        return JSONResponse(job)

    cmd = build_command(plugin_id, config, saved_files, params_path, output_dir)
    completed = run_local_job(job, cmd, plugin_path(plugin_id), output_dir)
    completed["demo"] = demo
    save_job(completed)
    return JSONResponse(completed)


@app.post("/api/plugins/{plugin_id}/run")
async def run_plugin(plugin_id: str, request: Request) -> JSONResponse:
    ensure_storage()
    config = read_yaml(plugin_config_path(plugin_id))
    job_id = "job_" + datetime.now().strftime("%Y%m%d_%H%M%S_") + uuid.uuid4().hex[:8]
    figure_id = "fig_" + uuid.uuid4().hex[:12]
    upload_dir = UPLOADS_DIR / job_id
    output_dir = RESULTS_DIR / job_id
    job_dir = JOBS_DIR / job_id
    output_dir.mkdir(parents=True, exist_ok=True)
    job_dir.mkdir(parents=True, exist_ok=True)

    saved_files, text_fields = await save_uploads(request, upload_dir)
    params = parse_params(text_fields, plugin_id)
    params_path = job_dir / "params.json"
    params_path.write_text(json.dumps(params, indent=2, ensure_ascii=False), encoding="utf-8")

    job = {
        "job_id": job_id,
        "figure_id": figure_id,
        "plugin_id": plugin_id,
        "dataset_id": params.get("dataset_id") or text_fields.get("dataset_id"),
        "status": "queued",
        "message": "Job accepted for local execution.",
        "created_at": utc_now(),
        "dispatch_mode": params.get("dispatch_mode", DEFAULT_DISPATCH_MODE),
        "upload_dir": str(upload_dir),
        "output_dir": str(output_dir),
        "params_path": str(params_path),
        "uploaded_files": {k: str(v) for k, v in saved_files.items()},
    }
    save_job(job)

    if job["dispatch_mode"] != "local":
        job.update({"status": "queued", "message": "Non-local dispatch is reserved for future workers; local is the active default."})
        save_job(job)
        return JSONResponse(job)

    cmd = build_command(plugin_id, config, saved_files, params_path, output_dir)
    completed = run_local_job(job, cmd, plugin_path(plugin_id), output_dir)
    return JSONResponse(completed)


@app.get("/api/jobs/{job_id}")
def get_job(job_id: str) -> dict[str, Any]:
    return load_job(job_id)


@app.get("/api/results")
def get_results() -> dict[str, Any]:
    jobs = list_jobs()
    return {"results": jobs}


@app.get("/api/results/{job_id}")
def get_result(job_id: str) -> dict[str, Any]:
    return load_job(job_id)


@app.post("/api/results/{job_id}/rerun")
def rerun_result(job_id: str) -> JSONResponse:
    old = load_job(job_id)
    plugin_id = old["plugin_id"]
    config = read_yaml(plugin_config_path(plugin_id))
    saved_files = {k: Path(v) for k, v in old.get("uploaded_files", {}).items() if Path(v).exists()}
    if not saved_files:
        raise HTTPException(status_code=404, detail="Original input files not found")
    new_job_id = "job_rerun_" + datetime.now().strftime("%Y%m%d_%H%M%S_") + uuid.uuid4().hex[:8]
    figure_id = "fig_" + uuid.uuid4().hex[:12]
    output_dir = RESULTS_DIR / new_job_id
    job_dir = JOBS_DIR / new_job_id
    output_dir.mkdir(parents=True, exist_ok=True)
    job_dir.mkdir(parents=True, exist_ok=True)
    old_params_path = Path(old.get("params_path", ""))
    params = json.loads(old_params_path.read_text(encoding="utf-8")) if old_params_path.exists() else {}
    params_path = job_dir / "params.json"
    params_path.write_text(json.dumps(params, indent=2, ensure_ascii=False), encoding="utf-8")
    job = {**old, "job_id": new_job_id, "figure_id": figure_id, "status": "queued", "message": "Rerun accepted.", "created_at": utc_now(), "output_dir": str(output_dir), "params_path": str(params_path)}
    save_job(job)
    cmd = build_command(plugin_id, config, saved_files, params_path, output_dir)
    return JSONResponse(run_local_job(job, cmd, plugin_path(plugin_id), output_dir))


@app.get("/api/jobs/{job_id}/logs")
def get_job_logs(job_id: str) -> dict[str, Any]:
    job = load_job(job_id)
    result_dir = Path(job["output_dir"])
    logs: list[str] = []
    for name in ("run.log", "subprocess.stdout.log", "subprocess.stderr.log"):
        path = result_dir / name
        if path.exists():
            content = path.read_text(encoding="utf-8", errors="replace")
            if content.strip():
                logs.extend([f"--- {name} ---", *content.splitlines()])
    return {"job_id": job_id, "logs": logs}


@app.get("/api/reports")
def list_reports() -> dict[str, Any]:
    ensure_storage()
    reports = []
    for path in sorted(REPORTS_DIR.glob("*.md"), reverse=True):
        reports.append({"report_id": path.stem, "filename": path.name, "path": str(path), "created_at": datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat()})
    return {"reports": reports}


@app.post("/api/reports/create")
async def create_report(request: Request) -> dict[str, Any]:
    ensure_storage()
    payload = await request.json()
    job_ids = payload.get("job_ids") or [job.get("job_id") for job in list_jobs()[:3]]
    report_id = "report_" + datetime.now().strftime("%Y%m%d_%H%M%S_") + uuid.uuid4().hex[:6]
    path = REPORTS_DIR / f"{report_id}.md"
    lines = ["# OmicsCanvas Plot Studio Report", "", f"Created: {utc_now()}", ""]
    for job_id in job_ids:
        try:
            job = load_job(job_id)
        except HTTPException:
            continue
        lines.extend([
            f"## {job.get('plugin_id')} ({job_id})",
            "",
            f"- Status: {job.get('status')}",
            f"- Output directory: `{job.get('output_dir')}`",
            f"- Params: `{job.get('params_path')}`",
            "",
        ])
        if job.get("outputs", {}).get("png"):
            lines.append(f"![{job.get('plugin_id')}]({Path(job.get('output_dir')) / 'result.png'})")
            lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")
    return {"report_id": report_id, "path": str(path), "download": f"/api/reports/{report_id}/download"}


@app.get("/api/reports/{report_id}/download")
def download_report(report_id: str) -> FileResponse:
    path = REPORTS_DIR / f"{safe_id(report_id)}.md"
    if not path.exists():
        raise HTTPException(status_code=404, detail="Report not found")
    return FileResponse(path, media_type="text/markdown", filename=path.name)


@app.get("/api/figures/{figure_id}")
def get_figure(figure_id: str) -> dict[str, Any]:
    job = figure_to_job(figure_id)
    return {
        "figure_id": figure_id,
        "job_id": job["job_id"],
        "plugin_id": job["plugin_id"],
        "status": "available" if job.get("status") == "completed" else job.get("status"),
        "outputs": output_urls(figure_id),
    }


@app.get("/api/figures/{figure_id}/preview")
def preview_figure(figure_id: str) -> FileResponse:
    job = figure_to_job(figure_id)
    path = Path(job["output_dir"]) / "result.png"
    if not path.exists():
        raise HTTPException(status_code=404, detail="Preview not found")
    return FileResponse(path, media_type="image/png")


@app.get("/api/figures/{figure_id}/download/{file_type}")
def download_figure(figure_id: str, file_type: str) -> FileResponse:
    job = figure_to_job(figure_id)
    path = output_file_for_type(Path(job["output_dir"]), file_type)
    if not path.exists():
        raise HTTPException(status_code=404, detail="Output file not found")
    media_type = {
        "svg": "image/svg+xml",
        "png": "image/png",
        "pdf": "application/pdf",
        "json": "application/json",
        "figure_json": "application/json",
        "log": "text/plain",
    }.get(file_type, "text/csv")
    return FileResponse(path, media_type=media_type, filename=path.name)


# ---------------------------------------------------------------------------
# Color palettes (AMFE / journal science palettes)
# ---------------------------------------------------------------------------

from plot_web import palettes as palette_catalog  # noqa: E402
from plot_web import ai_assistant  # noqa: E402


@app.get("/api/palettes")
def api_list_palettes(
    domain: str | None = None,
    tag: str | None = None,
    q: str | None = None,
    catalog: str | None = None,
    family: str | None = None,
    journal: str | None = None,
    min_colors: int | None = None,
    max_colors: int | None = None,
    limit: int = 100,
) -> dict[str, Any]:
    items = palette_catalog.list_palettes(
        domain=domain,
        tag=tag,
        q=q,
        catalog=catalog,
        family=family,
        journal=journal,
        min_colors=min_colors,
        max_colors=max_colors,
        limit=limit,
    )
    meta = palette_catalog.catalog_meta()
    return {
        "meta": meta,
        "sources": meta.get("sources"),
        "count": len(items),
        "total": meta.get("count"),
        "palettes": items,
    }


@app.get("/api/palettes/meta")
def api_palette_meta() -> dict[str, Any]:
    return palette_catalog.catalog_meta()


@app.get("/api/palettes/journals")
def api_palette_journals() -> dict[str, Any]:
    return {"journals": palette_catalog.list_journals()}


@app.get("/api/palettes/themes")
def api_palette_themes() -> dict[str, Any]:
    return {"themes": palette_catalog.list_themes()}


@app.get("/api/palettes/{palette_id}")
def api_get_palette(palette_id: str) -> dict[str, Any]:
    p = palette_catalog.get_palette(palette_id)
    if not p:
        raise HTTPException(status_code=404, detail="Palette not found")
    return {"palette": p, "plugin_params": palette_catalog.palette_as_plugin_params(p)}


@app.post("/api/palettes/recommend")
async def api_recommend_palettes(request: Request) -> dict[str, Any]:
    """Recommend palettes from research goal / target journal / style / n_groups."""
    try:
        body = await request.json()
    except Exception:
        body = {}
    if not isinstance(body, dict):
        body = {}
    goal = str(body.get("goal") or body.get("research") or body.get("query") or "")
    style = str(body.get("style") or "")
    journal = str(body.get("journal") or body.get("target_journal") or "")
    n_groups = body.get("n_groups") or body.get("n_categories")
    try:
        n_groups_i = int(n_groups) if n_groups is not None else None
    except (TypeError, ValueError):
        n_groups_i = None
    limit = int(body.get("limit") or 8)
    recs = palette_catalog.recommend_palettes(
        research_goal=goal,
        n_groups=n_groups_i,
        style=style,
        journal=journal,
        limit=max(1, min(24, limit)),
    )
    return {
        "goal": goal,
        "style": style,
        "journal": journal,
        "n_groups": n_groups_i,
        "recommendations": recs,
        "meta": palette_catalog.catalog_meta(),
    }


# ---------------------------------------------------------------------------
# AI assistant: recommend plots + build/run small demos
# ---------------------------------------------------------------------------


@app.get("/api/ai/status")
def ai_assistant_status() -> dict[str, Any]:
    return ai_assistant.ai_status()


@app.post("/api/ai/recommend")
async def ai_recommend(request: Request) -> JSONResponse:
    """Upload a table + optional goal text → ranked plugin recommendations."""
    ensure_storage()
    form = await request.form()
    goal = str(form.get("goal") or form.get("question") or "").strip()
    top_k = int(form.get("top_k") or 3)
    top_k = max(1, min(6, top_k))

    upload = form.get("file") or form.get("input")
    filename = getattr(upload, "filename", None)
    if not filename:
        raise HTTPException(status_code=400, detail="Upload a CSV/TSV/XLSX table as field 'file'.")

    session_id = "ai_" + datetime.now().strftime("%Y%m%d_%H%M%S_") + uuid.uuid4().hex[:8]
    session_dir = UPLOADS_DIR / session_id
    session_dir.mkdir(parents=True, exist_ok=True)
    safe_name = Path(filename).name
    target = session_dir / safe_name
    with target.open("wb") as handle:
        shutil.copyfileobj(upload.file, handle)

    try:
        from plot_web.table_io import sanitize_sheet_name

        sheet = sanitize_sheet_name(str(form.get("sheet") or "") or None)
        profile = ai_assistant.profile_table(target, sheet=sheet)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Failed to read table: {exc}") from exc
    profile["session_id"] = session_id
    # Prefer converted CSV path for downstream demos/plugins
    session_file = Path(profile.get("path") or target)
    profile["path"] = str(session_file)

    candidates = ai_assistant.recommend_plugins(profile, PLUGIN_DIR, goal=goal, top_k=max(top_k, 5))
    engine = "rules"
    refined = ai_assistant.refine_with_spacexai(profile, candidates, goal=goal)
    if refined:
        recommendations = refined[:top_k]
        engine = "llm+rules"
    else:
        recommendations = candidates[:top_k]
        for rec in recommendations:
            rec.setdefault("source", "rules")

    intent = ai_assistant.summarize_intent(profile, goal=goal, recommendations=recommendations)
    skills = ai_assistant.match_skills(profile, recommendations, ROOT_DIR / "skills", goal=goal)

    meta = {
        "session_id": session_id,
        "goal": goal,
        "profile": {k: v for k, v in profile.items() if k != "preview_rows"},
        "preview_rows": profile.get("preview_rows"),
        "file": str(session_file),
        "original_file": str(target) if session_file.resolve() != target.resolve() else None,
        "recommendations": recommendations,
        "intent": intent,
        "skills": skills,
        "created_at": utc_now(),
    }
    (session_dir / "session.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")

    # Also recommend scientific palettes for the same research goal
    n_cat = len(profile.get("categorical_columns") or [])
    n_groups_guess = None
    if profile.get("categorical_cardinality"):
        try:
            n_groups_guess = max(profile["categorical_cardinality"].values())
        except Exception:
            n_groups_guess = n_cat or None
    palette_recs = palette_catalog.recommend_palettes(
        research_goal=goal or " ".join(profile.get("tags") or []),
        n_groups=n_groups_guess,
        limit=4,
    )

    return JSONResponse(
        {
            "session_id": session_id,
            "engine": engine,
            "goal": goal,
            "intent": intent,
            "skills": skills,
            "profile": {
                "filename": profile.get("filename"),
                "columns": profile.get("columns"),
                "numeric_columns": profile.get("numeric_columns"),
                "categorical_columns": profile.get("categorical_columns"),
                "row_count_estimate": profile.get("row_count_estimate"),
                "column_count": profile.get("column_count"),
                "tags": profile.get("tags"),
                "preview_rows": profile.get("preview_rows"),
                "format": profile.get("format"),
                "excel": profile.get("excel"),
            },
            "recommendations": recommendations,
            "palette_recommendations": palette_recs,
            "message": (
                "Intent summarized and plots ranked. Use “Run top 3 & explain” for demos + AI explanations, "
                "or generate a single demo from a card."
                + (" Excel sheet converted to CSV for plotting." if profile.get("excel") else "")
            ),
        }
    )


def _execute_ai_demo(
    *,
    session_id: str,
    plugin_id: str,
    session: dict[str, Any],
    prefer_builtin: bool = False,
    custom_params: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Shared runner used by /build-demo and /pipeline."""
    source = Path(session.get("file") or "")
    if not source.exists():
        raise HTTPException(status_code=404, detail="Uploaded file for this session is missing")

    config = read_yaml(plugin_config_path(plugin_id))
    profile = ai_assistant.profile_table(source)

    job_id = "job_ai_" + datetime.now().strftime("%Y%m%d_%H%M%S_") + uuid.uuid4().hex[:8]
    figure_id = "fig_" + uuid.uuid4().hex[:12]
    work_dir = UPLOADS_DIR / job_id
    output_dir = RESULTS_DIR / job_id
    job_dir = JOBS_DIR / job_id
    work_dir.mkdir(parents=True, exist_ok=True)
    output_dir.mkdir(parents=True, exist_ok=True)
    job_dir.mkdir(parents=True, exist_ok=True)

    mode_used = "adapted_user_data"
    note = ""
    saved_files: dict[str, Path] = {}
    params: dict[str, Any] = {}
    use_builtin = prefer_builtin

    if not use_builtin:
        try:
            saved_files, params, note = ai_assistant.prepare_demo_files(
                plugin_id, source, profile, work_dir
            )
        except Exception as exc:
            use_builtin = True
            note = f"Adapt failed ({exc}); falling back to plugin built-in demo."

    if use_builtin or not saved_files:
        demo = demo_payload(plugin_id, config)
        saved_files = demo.pop("_file_paths", {}) or {}
        demo_params = demo.get("params") or {}
        if isinstance(demo_params, dict) and isinstance(demo_params.get("params"), dict):
            params = dict(demo_params["params"])
        elif isinstance(demo_params, dict):
            params = dict(demo_params.get("params") or demo_params)
        else:
            params = {}
        for k in ("name", "path"):
            params.pop(k, None)
        mode_used = "builtin_demo"
        if not note:
            note = "Used plugin built-in demo data (safest path). Your upload informed the plugin choice."
        if not saved_files:
            return {
                "plugin_id": plugin_id,
                "status": "failed",
                "error": {"error": "No demo input", "detail": f"No demo files for {plugin_id}"},
                "ai": {"session_id": session_id, "mode": mode_used, "note": note, "goal": session.get("goal")},
                "editor_url": f"/static/editor.html?plugin={plugin_id}",
            }

    if isinstance(custom_params, dict):
        params.update(custom_params)
    params["plugin_id"] = plugin_id
    params.setdefault("dispatch_mode", DEFAULT_DISPATCH_MODE)

    params_path = job_dir / "params.json"
    params_path.write_text(json.dumps(params, indent=2, ensure_ascii=False), encoding="utf-8")

    job = {
        "job_id": job_id,
        "figure_id": figure_id,
        "plugin_id": plugin_id,
        "dataset_id": session_id,
        "status": "queued",
        "message": "AI demo job accepted.",
        "created_at": utc_now(),
        "dispatch_mode": params.get("dispatch_mode", DEFAULT_DISPATCH_MODE),
        "upload_dir": str(work_dir),
        "output_dir": str(output_dir),
        "params_path": str(params_path),
        "uploaded_files": {k: str(v) for k, v in saved_files.items()},
        "ai": {
            "session_id": session_id,
            "mode": mode_used,
            "note": note,
            "goal": session.get("goal"),
        },
    }
    save_job(job)

    if job["dispatch_mode"] != "local":
        job.update({"status": "queued", "message": "Non-local dispatch not configured."})
        save_job(job)
        return job

    cmd = build_command(plugin_id, config, saved_files, params_path, output_dir)
    completed = run_local_job(job, cmd, plugin_path(plugin_id), output_dir)

    if completed.get("status") != "completed" and mode_used == "adapted_user_data":
        demo = demo_payload(plugin_id, config)
        fb_files = demo.pop("_file_paths", {}) or {}
        demo_params = demo.get("params") or {}
        if isinstance(demo_params, dict) and isinstance(demo_params.get("params"), dict):
            fb_params = dict(demo_params["params"])
        elif isinstance(demo_params, dict):
            fb_params = dict(demo_params.get("params") or demo_params)
        else:
            fb_params = {}
        for k in ("name", "path"):
            fb_params.pop(k, None)
        if fb_files:
            fb_params["plugin_id"] = plugin_id
            fb_params.setdefault("dispatch_mode", DEFAULT_DISPATCH_MODE)
            params_path.write_text(json.dumps(fb_params, indent=2, ensure_ascii=False), encoding="utf-8")
            job["ai"] = {
                "session_id": session_id,
                "mode": "builtin_demo_fallback",
                "note": (
                    f"Adapted data failed ({(completed.get('error') or {}).get('detail') or completed.get('status')}); "
                    "retried with plugin built-in demo."
                ),
                "goal": session.get("goal"),
            }
            job["uploaded_files"] = {k: str(v) for k, v in fb_files.items()}
            job["status"] = "queued"
            save_job(job)
            cmd2 = build_command(plugin_id, config, fb_files, params_path, output_dir)
            completed = run_local_job(job, cmd2, plugin_path(plugin_id), output_dir)
            completed["ai"] = job["ai"]
            params = fb_params

    completed["ai"] = completed.get("ai") or job.get("ai")
    completed["editor_url"] = f"/static/editor.html?plugin={plugin_id}"
    completed["params_used"] = params
    completed["plugin_id"] = plugin_id
    # attach figure.json meta if present
    try:
        fj = Path(completed.get("output_dir") or output_dir) / "figure.json"
        if fj.exists():
            completed["figure_meta"] = json.loads(fj.read_text(encoding="utf-8"))
    except Exception:
        pass
    save_job(completed)
    return completed


@app.post("/api/ai/build-demo")
async def ai_build_demo(request: Request) -> JSONResponse:
    """Build a small demo from an AI session + plugin_id, run the plugin, return outputs."""
    ensure_storage()
    try:
        body = await request.json()
    except Exception:
        body = {}
    if not isinstance(body, dict):
        body = {}

    session_id = str(body.get("session_id") or "").strip()
    plugin_id = str(body.get("plugin_id") or "").strip()
    prefer_builtin = bool(body.get("prefer_builtin_demo") or False)
    if not session_id or not plugin_id:
        raise HTTPException(status_code=400, detail="session_id and plugin_id are required")

    session_dir = UPLOADS_DIR / safe_id(session_id)
    session_meta_path = session_dir / "session.json"
    if not session_meta_path.exists():
        raise HTTPException(status_code=404, detail="AI session not found — re-upload and recommend first")
    try:
        session = json.loads(session_meta_path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Corrupt session: {exc}") from exc

    custom = body.get("params") if isinstance(body.get("params"), dict) else None
    completed = _execute_ai_demo(
        session_id=session_id,
        plugin_id=plugin_id,
        session=session,
        prefer_builtin=prefer_builtin,
        custom_params=custom,
    )
    return JSONResponse(completed)


@app.post("/api/ai/explain")
async def ai_explain_figure(request: Request) -> JSONResponse:
    """Explain one generated (or recommended) figure in English."""
    try:
        body = await request.json()
    except Exception:
        body = {}
    if not isinstance(body, dict):
        body = {}
    session_id = str(body.get("session_id") or "").strip()
    plugin_id = str(body.get("plugin_id") or "").strip()
    if not plugin_id:
        raise HTTPException(status_code=400, detail="plugin_id is required")

    session: dict[str, Any] = {}
    if session_id:
        meta_path = UPLOADS_DIR / safe_id(session_id) / "session.json"
        if meta_path.exists():
            try:
                session = json.loads(meta_path.read_text(encoding="utf-8"))
            except Exception:
                session = {}

    recs = session.get("recommendations") or []
    reason = str(body.get("reason") or "")
    name = str(body.get("plugin_name") or plugin_id)
    for r in recs:
        if r.get("plugin_id") == plugin_id:
            reason = reason or str(r.get("reason") or "")
            name = str(r.get("name") or name)
            break

    profile = session.get("profile") or {}
    exp = ai_assistant.explain_figure(
        plugin_id=plugin_id,
        plugin_name=name,
        reason=reason,
        goal=str(session.get("goal") or body.get("goal") or ""),
        profile=profile,
        figure_meta=body.get("figure_meta") if isinstance(body.get("figure_meta"), dict) else {},
        run_status=str(body.get("status") or "recommended"),
        mode=str(body.get("mode") or ""),
    )
    return JSONResponse({"plugin_id": plugin_id, **exp})


@app.post("/api/ai/pipeline")
async def ai_pipeline(request: Request) -> JSONResponse:
    """Full flow: profile → intent → top-N plots + skills → render demos → explain each.

    Accepts multipart like /recommend (file + goal), or JSON with existing session_id.
    """
    ensure_storage()
    content_type = (request.headers.get("content-type") or "").lower()

    session_id = ""
    goal = ""
    top_k = 3
    prefer_builtin = False
    auto_render = True

    if "multipart/form-data" in content_type or "application/x-www-form-urlencoded" in content_type:
        form = await request.form()
        goal = str(form.get("goal") or "").strip()
        top_k = max(1, min(5, int(form.get("top_k") or 3)))
        prefer_builtin = str(form.get("prefer_builtin_demo") or "").lower() in {"1", "true", "yes"}
        auto_render = str(form.get("auto_render") or "true").lower() not in {"0", "false", "no"}
        session_id = str(form.get("session_id") or "").strip()
        upload = form.get("file") or form.get("input")
        filename = getattr(upload, "filename", None)
        if filename:
            session_id = "ai_" + datetime.now().strftime("%Y%m%d_%H%M%S_") + uuid.uuid4().hex[:8]
            session_dir = UPLOADS_DIR / session_id
            session_dir.mkdir(parents=True, exist_ok=True)
            target = session_dir / Path(filename).name
            with target.open("wb") as handle:
                shutil.copyfileobj(upload.file, handle)
            try:
                from plot_web.table_io import sanitize_sheet_name

                sheet = sanitize_sheet_name(str(form.get("sheet") or "") or None)
                profile = ai_assistant.profile_table(target, sheet=sheet)
            except Exception as exc:
                raise HTTPException(status_code=400, detail=f"Failed to read table: {exc}") from exc
            source_path = Path(profile.get("path") or target)
        elif session_id:
            session_dir = UPLOADS_DIR / safe_id(session_id)
            meta_path = session_dir / "session.json"
            if not meta_path.exists():
                raise HTTPException(status_code=404, detail="session not found")
            session = json.loads(meta_path.read_text(encoding="utf-8"))
            source_path = Path(session.get("file") or "")
            if not source_path.exists():
                raise HTTPException(status_code=404, detail="session file missing")
            profile = ai_assistant.profile_table(source_path)
            goal = goal or str(session.get("goal") or "")
        else:
            raise HTTPException(status_code=400, detail="Provide file upload or session_id")
    else:
        try:
            body = await request.json()
        except Exception:
            body = {}
        if not isinstance(body, dict):
            body = {}
        session_id = str(body.get("session_id") or "").strip()
        goal = str(body.get("goal") or "").strip()
        top_k = max(1, min(5, int(body.get("top_k") or 3)))
        prefer_builtin = bool(body.get("prefer_builtin_demo") or False)
        auto_render = body.get("auto_render", True) is not False
        if not session_id:
            raise HTTPException(status_code=400, detail="session_id required for JSON pipeline (or use multipart upload)")
        session_dir = UPLOADS_DIR / safe_id(session_id)
        meta_path = session_dir / "session.json"
        if not meta_path.exists():
            raise HTTPException(status_code=404, detail="session not found")
        session = json.loads(meta_path.read_text(encoding="utf-8"))
        source_path = Path(session.get("file") or "")
        if not source_path.exists():
            raise HTTPException(status_code=404, detail="session file missing")
        profile = ai_assistant.profile_table(source_path)
        goal = goal or str(session.get("goal") or "")

    # Recommend plots
    candidates = ai_assistant.recommend_plugins(profile, PLUGIN_DIR, goal=goal, top_k=max(top_k, 5))
    engine = "rules"
    refined = ai_assistant.refine_with_spacexai(profile, candidates, goal=goal)
    if refined:
        recommendations = refined[:top_k]
        engine = "llm+rules"
    else:
        recommendations = candidates[:top_k]
        for rec in recommendations:
            rec.setdefault("source", "rules")

    intent = ai_assistant.summarize_intent(profile, goal=goal, recommendations=recommendations)
    skills = ai_assistant.match_skills(
        profile,
        recommendations,
        ROOT_DIR / "skills",
        goal=goal,
    )
    n_groups_guess = None
    if profile.get("categorical_cardinality"):
        try:
            n_groups_guess = max(profile["categorical_cardinality"].values())
        except Exception:
            n_groups_guess = None
    palette_recs = palette_catalog.recommend_palettes(
        research_goal=goal or " ".join(profile.get("tags") or []),
        n_groups=n_groups_guess,
        limit=4,
    )

    # Persist session
    if not session_id:
        session_id = "ai_" + datetime.now().strftime("%Y%m%d_%H%M%S_") + uuid.uuid4().hex[:8]
    session_dir = UPLOADS_DIR / safe_id(session_id)
    session_dir.mkdir(parents=True, exist_ok=True)
    session_payload = {
        "session_id": session_id,
        "goal": goal,
        "profile": {k: v for k, v in profile.items() if k != "preview_rows"},
        "preview_rows": profile.get("preview_rows"),
        "file": str(source_path),
        "recommendations": recommendations,
        "intent": intent,
        "skills": skills,
        "created_at": utc_now(),
    }
    (session_dir / "session.json").write_text(
        json.dumps(session_payload, indent=2, ensure_ascii=False), encoding="utf-8"
    )

    figures: list[dict[str, Any]] = []
    if auto_render:
        for rec in recommendations[:top_k]:
            pid = rec.get("plugin_id")
            if not pid:
                continue
            try:
                run = _execute_ai_demo(
                    session_id=session_id,
                    plugin_id=pid,
                    session=session_payload,
                    prefer_builtin=prefer_builtin,
                )
            except Exception as exc:
                run = {
                    "plugin_id": pid,
                    "status": "failed",
                    "error": {"error": "pipeline_error", "detail": str(exc)},
                    "ai": {"mode": "error", "note": str(exc)},
                }
            exp = ai_assistant.explain_figure(
                plugin_id=pid,
                plugin_name=str(rec.get("name") or pid),
                reason=str(rec.get("reason") or ""),
                goal=goal,
                profile=profile,
                figure_meta=run.get("figure_meta") if isinstance(run.get("figure_meta"), dict) else {},
                run_status=str(run.get("status") or "unknown"),
                mode=str((run.get("ai") or {}).get("mode") or ""),
            )
            figures.append(
                {
                    "rank": len(figures) + 1,
                    "plugin_id": pid,
                    "name": rec.get("name") or pid,
                    "reason": rec.get("reason"),
                    "score": rec.get("score"),
                    "status": run.get("status"),
                    "outputs": run.get("outputs"),
                    "preview": (run.get("outputs") or {}).get("preview"),
                    "editor_url": run.get("editor_url") or f"/static/editor.html?plugin={pid}",
                    "ai": run.get("ai"),
                    "explanation": exp.get("explanation"),
                    "explanation_source": exp.get("source"),
                    "job_id": run.get("job_id"),
                    "error": run.get("error"),
                }
            )

    return JSONResponse(
        {
            "session_id": session_id,
            "engine": engine,
            "goal": goal,
            "intent": intent,
            "profile": {
                "filename": profile.get("filename"),
                "columns": profile.get("columns"),
                "numeric_columns": profile.get("numeric_columns"),
                "categorical_columns": profile.get("categorical_columns"),
                "row_count_estimate": profile.get("row_count_estimate"),
                "column_count": profile.get("column_count"),
                "tags": profile.get("tags"),
                "preview_rows": profile.get("preview_rows"),
            },
            "recommendations": recommendations,
            "skills": skills,
            "palette_recommendations": palette_recs,
            "figures": figures,
            "message": (
                "Pipeline complete: intent summarized, top plots ranked"
                + (", demos rendered and explained." if auto_render else ".")
            ),
        }
    )


@app.post("/api/ai/chat")
async def ai_chat(request: Request) -> JSONResponse:
    """Lightweight Q&A about recommendations (rules always; SpaceXAI if keyed)."""
    try:
        body = await request.json()
    except Exception:
        body = {}
    if not isinstance(body, dict):
        body = {}
    message = str(body.get("message") or body.get("question") or "").strip()
    session_id = str(body.get("session_id") or "").strip()
    if not message:
        raise HTTPException(status_code=400, detail="message is required")

    context: dict[str, Any] = {}
    if session_id:
        meta_path = UPLOADS_DIR / safe_id(session_id) / "session.json"
        if meta_path.exists():
            try:
                context = json.loads(meta_path.read_text(encoding="utf-8"))
            except Exception:
                context = {}

    recs = context.get("recommendations") or []
    system = (
        "You are OmicsCanvas Plot Studio AI assistant. Help users choose bioinformatics plots. "
        "Be concise. Always reply in English only (never use Chinese characters in the reply). "
        "If recommending plugins, use only existing plugin_ids from context."
    )
    user_payload = {
        "message": message,
        "goal": context.get("goal"),
        "profile": context.get("profile"),
        "recommendations": recs,
    }
    text = ai_assistant.chat_completion(
        [
            {"role": "system", "content": system},
            {"role": "user", "content": json.dumps(user_payload, ensure_ascii=False)},
        ],
        temperature=0.4,
        timeout=60,
    )
    if text:
        return JSONResponse({"reply": text, "engine": "llm"})
    fallback = ""
    if not ai_assistant._llm_config().get("api_key"):
        fallback = ""
    else:
        fallback = "(LLM call failed, using rules) "

    recs = context.get("recommendations") or []
    if recs:
        lines = [
            fallback + "Based on your uploaded table, recommendations:",
            *[f"• **{r.get('name')}** (`{r.get('plugin_id')}`) — {r.get('reason')}" for r in recs[:3]],
            "",
            "Click “Generate demo” on a card to render a small subsample (or the plugin’s built-in demo).",
            "You can also open the Editor to fine-tune parameters.",
        ]
        return JSONResponse({"reply": "\n".join(lines), "engine": "rules"})

    return JSONResponse(
        {
            "reply": fallback
            + "Please upload a table and click “Analyze & Recommend”. I will suggest plot types from column types and your goal, then generate a small demo.",
            "engine": "rules",
        }
    )


# ---------------------------------------------------------------------------
# vNext PlotSpec API (additive; does not replace legacy params.json jobs)
# ---------------------------------------------------------------------------


@app.get("/api/vnext/status")
def vnext_status() -> dict[str, Any]:
    try:
        from vnext import __version__ as vnext_version
        from vnext.registry.loader import load_registry, validate_registry

        reg = load_registry()
        val = validate_registry(reg)
        migrated = [
            s.get("id")
            for s in (reg.get("skills") or [])
            if (s.get("capabilities") or {}).get("vnext_migrated")
        ]
        return {
            "ok": True,
            "framework_version": vnext_version,
            "registry_valid": val.get("valid"),
            "n_skills": val.get("n_skills"),
            "migrated_skills": migrated,
        }
    except Exception as exc:
        return {"ok": False, "error": str(exc)}


@app.post("/api/vnext/validate")
async def vnext_validate(request: Request) -> JSONResponse:
    """Validate a PlotSpec JSON body; optional multipart with file for scientific checks."""
    try:
        from vnext.validate.pipeline import validate_plotspec
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"vnext unavailable: {exc}") from exc

    content_type = (request.headers.get("content-type") or "").lower()
    table_path: Path | None = None
    spec: dict[str, Any] | None = None

    if "multipart/form-data" in content_type:
        form = await request.form()
        raw = form.get("spec") or form.get("plotspec")
        if isinstance(raw, str):
            try:
                spec = json.loads(raw)
            except json.JSONDecodeError as exc:
                raise HTTPException(status_code=400, detail=f"Invalid PlotSpec JSON: {exc}") from exc
        upload = form.get("file") or form.get("input")
        filename = getattr(upload, "filename", None)
        if filename:
            ensure_storage()
            tmp = UPLOADS_DIR / ("vnext_" + uuid.uuid4().hex[:10])
            tmp.mkdir(parents=True, exist_ok=True)
            table_path = tmp / Path(filename).name
            with table_path.open("wb") as handle:
                shutil.copyfileobj(upload.file, handle)
    else:
        try:
            body = await request.json()
        except Exception:
            body = {}
        if not isinstance(body, dict):
            body = {}
        spec = body.get("spec") if isinstance(body.get("spec"), dict) else body

    if not isinstance(spec, dict):
        raise HTTPException(status_code=400, detail="PlotSpec object required")
    result = validate_plotspec(spec, table_path=table_path)
    return JSONResponse(result)
