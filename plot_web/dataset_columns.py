"""Dataset column typing, mapping suggestions, and include/exclude filters."""
from __future__ import annotations

import re
from typing import Any

LEVEL_CAP = 80
ID_UNIQUE_RATIO = 0.95
NUMERIC_RATIO = 0.7

XY_PAIRS = [
    ("dim1", "dim2"),
    ("umap_1", "umap_2"),
    ("umap1", "umap2"),
    ("tsne_1", "tsne_2"),
    ("tsne1", "tsne2"),
    ("pc1", "pc2"),
    ("pca_1", "pca_2"),
]
ID_NAMES = {"cell", "cell_id", "barcode", "id", "cellid", "row_id", "rownames"}
GROUP_NAMES = {"cluster", "seurat_clusters", "cell_type", "celltype", "group", "ident", "annotation"}


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


def _norm(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", str(name or "").lower())


def infer_column_meta(name: str, values: list[Any], *, max_levels: int = LEVEL_CAP) -> dict[str, Any]:
    cleaned = [str(v).strip() for v in values if v is not None and str(v).strip() != ""]
    n = len(cleaned)
    uniques = list(dict.fromkeys(cleaned))
    n_unique = len(uniques)
    numeric_hits = sum(1 for v in cleaned if is_number(v))
    is_num = n > 0 and numeric_hits >= max(1, int(n * NUMERIC_RATIO))
    unique_ratio = n_unique / n if n else 0
    id_like = _norm(name) in ID_NAMES or str(name).lower() in {"index"}
    if is_num:
        if n_unique <= max_levels and unique_ratio < 0.5:
            kind = "categorical"
        elif id_like:
            kind = "id"
        else:
            kind = "numeric"
    elif n_unique <= max_levels and not (unique_ratio >= ID_UNIQUE_RATIO and n_unique > 25):
        kind = "categorical"
    elif unique_ratio >= ID_UNIQUE_RATIO:
        kind = "id"
    else:
        kind = "text"
    levels = uniques[:max_levels] if kind == "categorical" and n_unique <= max_levels else None
    return {
        "name": name,
        "kind": kind,
        "n_unique": n_unique,
        "unique_ratio": unique_ratio,
        "high_cardinality": n_unique > max_levels,
        "levels": levels,
    }


def profile_rows(columns: list[str], rows: list[dict[str, Any]], *, max_levels: int = LEVEL_CAP) -> dict[str, Any]:
    meta = [infer_column_meta(col, [row.get(col) for row in rows], max_levels=max_levels) for col in columns]
    by_kind = {"numeric": [], "categorical": [], "id": [], "text": []}
    for item in meta:
        by_kind.setdefault(item["kind"], []).append(item["name"])
    return {
        "columns": columns,
        "column_meta": meta,
        "numeric_columns": by_kind["numeric"],
        "categorical_columns": by_kind["categorical"],
        "id_columns": by_kind["id"],
        "levels": {item["name"]: item["levels"] for item in meta if item.get("levels") is not None},
    }


def suggest_mappings(columns: list[str]) -> dict[str, str]:
    lookup = {_norm(c): c for c in columns}
    out: dict[str, str] = {}
    for x_name, y_name in XY_PAIRS:
        if x_name in lookup and y_name in lookup:
            out["x_column"] = lookup[x_name]
            out["y_column"] = lookup[y_name]
            break
    for key in ID_NAMES:
        if key in lookup:
            out["id_column"] = lookup[key]
            break
    for key in GROUP_NAMES:
        if key in lookup:
            out["group_column"] = lookup[key]
            break
    if "sample" in lookup:
        out.setdefault("split_column", lookup["sample"])
        out.setdefault("filter_column", lookup["sample"])
    return out


def apply_group_filters(
    rows: list[dict[str, Any]],
    column: str | None,
    include: list[str] | None,
    exclude: list[str] | None,
) -> list[dict[str, Any]]:
    include_set = {str(v) for v in (include or []) if v not in (None, "")}
    exclude_set = {str(v) for v in (exclude or []) if v not in (None, "")}
    if not column:
        return list(rows)
    out = []
    for row in rows:
        value = str(row.get(column, ""))
        if include_set and value not in include_set:
            continue
        if value in exclude_set:
            continue
        out.append(row)
    return out


def apply_row_filters(
    rows: list[dict[str, Any]],
    id_column: str | None,
    selected: list[str] | None,
    mode: str = "include",
) -> list[dict[str, Any]]:
    selected_set = {str(v) for v in (selected or []) if v not in (None, "")}
    if not selected_set or not id_column:
        return list(rows)
    if mode == "exclude":
        return [row for row in rows if str(row.get(id_column, "")) not in selected_set]
    return [row for row in rows if str(row.get(id_column, "")) in selected_set]


def effective_rows(
    rows: list[dict[str, Any]],
    *,
    filter_column: str | None = None,
    included_levels: list[str] | None = None,
    excluded_levels: list[str] | None = None,
    id_column: str | None = None,
    selected_rows: list[str] | None = None,
    row_mode: str = "include",
) -> list[dict[str, Any]]:
    """Original → group include → group exclude (exclude wins) → row selection."""
    filtered = apply_group_filters(rows, filter_column, included_levels, excluded_levels)
    return apply_row_filters(filtered, id_column, selected_rows, row_mode)
