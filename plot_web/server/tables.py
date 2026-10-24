"""Lightweight delimited-table preview helpers."""
from __future__ import annotations

from pathlib import Path
from typing import Any


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


def preview_table(path: Path, max_rows: int = 120) -> dict[str, Any]:
    """Preview CSV/TSV/TXT or Excel (.xlsx) tables with column typing."""
    from plot_web.dataset_columns import profile_rows, suggest_mappings
    from plot_web.table_io import is_table_file, read_table_as_dicts

    if not is_table_file(path):
        raise ValueError(f"Unsupported table type: {path.suffix}")
    profile_limit = max(max_rows, 4000)
    columns, rows, meta = read_table_as_dicts(path, max_rows=profile_limit)
    preview = rows[:max_rows]
    profile = profile_rows(columns, rows)
    numeric_columns = profile["numeric_columns"] or [
        col
        for col in columns
        if preview and sum(1 for row in preview if is_number(row.get(col))) >= max(1, int(len(preview) * 0.7))
    ]
    out = {
        "filename": path.name,
        "delimiter": meta.get("delimiter") or ",",
        "columns": columns,
        "numeric_columns": numeric_columns,
        "categorical_columns": profile.get("categorical_columns") or [],
        "id_columns": profile.get("id_columns") or [],
        "column_meta": profile.get("column_meta") or [],
        "levels": profile.get("levels") or {},
        "suggested_mappings": suggest_mappings(columns),
        "preview_rows": preview,
        "row_count_estimate": int(meta.get("row_count_estimate") or len(rows)),
        "column_count": len(columns),
        "format": meta.get("format"),
    }
    if meta.get("excel"):
        out["excel"] = True
        out["sheet"] = meta.get("sheet", 0)
    return out
