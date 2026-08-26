"""Scientific validation: global + family + skill guardrails."""
from __future__ import annotations

import math
import re
from pathlib import Path
from typing import Any, Callable

import csv


Severity = str  # error | warning | info


def _issue(code: str, field: str, message: str, severity: Severity = "error") -> dict[str, str]:
    return {"code": code, "field": field, "message": message, "severity": severity}


def _is_number(v: Any) -> bool:
    try:
        float(v)
        return True
    except (TypeError, ValueError):
        return False


def _finite(v: Any) -> bool:
    try:
        x = float(v)
        return math.isfinite(x)
    except (TypeError, ValueError):
        return False


def read_table_preview(path: Path, max_rows: int = 500) -> tuple[list[str], list[dict[str, str]]]:
    text = path.read_text(encoding="utf-8", errors="replace")
    delim = "\t" if path.suffix.lower() in {".tsv", ".txt"} and text.count("\t") > text.count(",") else ","
    reader = csv.DictReader(text.splitlines(), delimiter=delim)
    cols = list(reader.fieldnames or [])
    rows: list[dict[str, str]] = []
    for i, row in enumerate(reader):
        if i >= max_rows:
            break
        rows.append({k: (row.get(k) or "") for k in cols})
    return cols, rows


def global_guardrails(spec: dict[str, Any], columns: list[str], rows: list[dict[str, str]]) -> list[dict[str, str]]:
    issues: list[dict[str, str]] = []
    mapping = spec.get("mapping") or {}

    # empty post-mapping dataset
    if not rows:
        issues.append(_issue("EMPTY_DATA", "input", "Input table has no rows to plot.", "error"))

    # non-finite values in mapped numeric-ish roles
    numeric_roles = {
        "effect",
        "signed_effect",
        "pvalue",
        "adjusted_pvalue",
        "fold_change",
        "expression",
        "count",
        "score",
        "size",
        "x_coordinate",
        "y_coordinate",
    }
    for role, col in mapping.items():
        if not col or role not in numeric_roles:
            continue
        if col not in columns:
            issues.append(_issue("MISSING_MAPPED_COLUMN", f"mapping.{role}", f"Column '{col}' not in table.", "error"))
            continue
        bad = 0
        for r in rows:
            v = r.get(col, "")
            if str(v).strip() == "":
                continue
            if not _finite(v):
                bad += 1
        if bad:
            issues.append(
                _issue(
                    "NON_FINITE_VALUES",
                    f"mapping.{role}",
                    f"{bad} non-finite values in column '{col}'.",
                    "error" if bad > len(rows) * 0.2 else "warning",
                )
            )

    # p vs FDR confusion: if significance mapped column looks like raw p but labeled FDR in visual
    sig_col = mapping.get("adjusted_pvalue") or mapping.get("pvalue") or mapping.get("significance")
    visual = spec.get("visual") or {}
    legend = str(visual.get("legend_title") or visual.get("title") or "").lower()
    if sig_col and sig_col in columns:
        name = sig_col.lower()
        if re.search(r"(^|_)(p|pval|p_value|pvalue)($|_)", name) and "adj" not in name and "fdr" not in name and "padj" not in name:
            if "fdr" in legend or "adjusted" in legend:
                issues.append(
                    _issue(
                        "RAW_P_LABELED_AS_FDR",
                        f"mapping",
                        f"Column '{sig_col}' looks like raw p-values but labels mention FDR/adjusted.",
                        "error",
                    )
                )
            else:
                issues.append(
                    _issue(
                        "RAW_P_USED",
                        f"mapping.pvalue",
                        "Raw p-values appear to be used. Adjusted p-values are recommended when multiple tests apply.",
                        "warning",
                    )
                )

    stats = spec.get("statistics") or {}
    if stats.get("multiple_testing") in {"fdr", "bh", "bonferroni"} and not (
        mapping.get("adjusted_pvalue") or mapping.get("significance")
    ):
        issues.append(
            _issue(
                "MULTIPLE_TESTING_WITHOUT_COLUMN",
                "statistics.multiple_testing",
                "multiple_testing is set but no adjusted_pvalue/significance mapping is provided.",
                "warning",
            )
        )

    return issues


def enrichment_family_guardrails(spec: dict[str, Any], columns: list[str], rows: list[dict[str, str]]) -> list[dict[str, str]]:
    issues: list[dict[str, str]] = []
    mapping = spec.get("mapping") or {}
    cat = mapping.get("category") or mapping.get("term")
    effect = mapping.get("signed_effect") or mapping.get("effect")
    if not cat:
        issues.append(_issue("MISSING_CATEGORY", "mapping.category", "Enrichment plots require a category/term mapping.", "error"))
    elif cat not in columns:
        issues.append(_issue("MISSING_CATEGORY_COL", "mapping.category", f"Category column '{cat}' not found.", "error"))
    if not effect:
        issues.append(
            _issue(
                "MISSING_SIGNED_EFFECT",
                "mapping.effect",
                "A bidirectional enrichment lollipop requires a signed effect metric.",
                "error",
            )
        )
    elif effect not in columns:
        issues.append(_issue("MISSING_EFFECT_COL", "mapping.effect", f"Effect column '{effect}' not found.", "error"))
    else:
        # check signedness: both positive and negative preferred for bi-directional
        vals = []
        for r in rows:
            if _is_number(r.get(effect)):
                vals.append(float(r[effect]))
        if vals and (min(vals) >= 0 or max(vals) <= 0):
            issues.append(
                _issue(
                    "EFFECT_NOT_BIDIRECTIONAL",
                    "mapping.effect",
                    "Effect values do not span both signs; zero-centered lollipop may be misleading.",
                    "warning",
                )
            )
    return issues


def enrichment_lollipop_guardrails(spec: dict[str, Any], columns: list[str], rows: list[dict[str, str]]) -> list[dict[str, str]]:
    issues: list[dict[str, str]] = []
    mapping = spec.get("mapping") or {}
    visual = spec.get("visual") or {}
    # stem_to_zero / zero_line recommended
    if visual.get("stem_to_zero") is False:
        issues.append(
            _issue(
                "STEM_DISABLED",
                "visual.stem_to_zero",
                "Stem-to-zero is disabled; Cleveland/lollipop convention usually requires stems to zero.",
                "warning",
            )
        )
    size_col = mapping.get("size") or mapping.get("gene_count")
    if size_col and size_col in columns:
        negs = sum(1 for r in rows if _is_number(r.get(size_col)) and float(r[size_col]) < 0)
        if negs:
            issues.append(
                _issue("NEGATIVE_SIZE", "mapping.size", "Size/gene_count contains negative values.", "error")
            )
    return issues


FAMILY_RULES: dict[str, Callable[..., list[dict[str, str]]]] = {
    "enrichment": enrichment_family_guardrails,
}

SKILL_RULES: dict[str, Callable[..., list[dict[str, str]]]] = {
    "interactive_enrichment_lollipop": enrichment_lollipop_guardrails,
}


def validate_scientific(
    spec: dict[str, Any],
    *,
    table_path: Path | None = None,
    columns: list[str] | None = None,
    rows: list[dict[str, str]] | None = None,
    family: str | None = None,
) -> dict[str, Any]:
    """Run global + family + skill scientific validators. Does not silently repair."""
    if table_path and (columns is None or rows is None):
        columns, rows = read_table_preview(Path(table_path))
    columns = columns or []
    rows = rows or []

    issues: list[dict[str, str]] = []
    issues.extend(global_guardrails(spec, columns, rows))

    skill_id = ((spec.get("skill") or {}).get("id")) or ""
    fam = (family or "").lower()
    if not fam and "enrichment" in skill_id:
        fam = "enrichment"
    if fam in FAMILY_RULES:
        issues.extend(FAMILY_RULES[fam](spec, columns, rows))
    if skill_id in SKILL_RULES:
        issues.extend(SKILL_RULES[skill_id](spec, columns, rows))

    errors = [i for i in issues if i.get("severity") == "error"]
    warnings = [i for i in issues if i.get("severity") == "warning"]
    infos = [i for i in issues if i.get("severity") == "info"]
    return {
        "valid": len(errors) == 0,
        "errors": errors,
        "warnings": warnings,
        "infos": infos,
    }
