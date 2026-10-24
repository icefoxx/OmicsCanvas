"""Scientific validation: global + family + skill guardrails.

Rules reason about *semantic roles* (PlotSpec.mapping), resolved against the
input tables via the skill metadata (plugins/<id>/vnext/metadata.yaml):
explicit mappings first, then the plugin's own autodetect candidates, so a
figure is checked against the columns the renderer will actually use.

Every issue is {code, field, message, severity}; severity is error | warning | info.
Validators report — they never repair data or the spec.
"""
from __future__ import annotations

import csv
import math
import re
import statistics as pystats
from pathlib import Path
from typing import Any, Callable

Severity = str  # error | warning | info

MAX_ROWS = 20000
# Bound memory for wide inputs (e.g. gene x cell matrices): rows read = MAX_CELLS / n_columns.
MAX_CELLS = 2_000_000
TABLE_SUFFIXES = {".csv", ".tsv", ".txt"}
RAW_P_NAME = re.compile(r"(^|[_.\s])(p|pval|p_val|pvalue|p_value|p\.value)($|[_.\s])", re.I)
ADJ_P_NAME = re.compile(r"adj|fdr|padj|q_?val|qvalue|bonf|holm|bh", re.I)
NUMERIC_ROLES = {"x", "y", "signed_effect", "value", "pvalue", "adjusted_pvalue", "size", "weight",
                 "se", "ci_low", "ci_high", "correlation", "effect", "fold_change", "expression", "count", "score"}
TOO_MANY_GROUPS = 40


def _issue(code: str, field: str, message: str, severity: Severity = "error") -> dict[str, str]:
    return {"code": code, "field": field, "message": message, "severity": severity}


MISSING_TOKENS = {"", "na", "nan", "null", "none", "n/a", "#n/a", "-"}


def _missing(v: Any) -> bool:
    """R/pandas/Excel spellings of a missing value."""
    return v is None or str(v).strip().lower() in MISSING_TOKENS


def _is_number(v: Any) -> bool:
    try:
        float(v)
        return True
    except (TypeError, ValueError):
        return False


def _finite(v: Any) -> bool:
    try:
        return math.isfinite(float(v))
    except (TypeError, ValueError):
        return False


# ---------------------------------------------------------------------------
# Tables
# ---------------------------------------------------------------------------

def read_table_preview(path: Path, max_rows: int = MAX_ROWS) -> tuple[list[str], list[dict[str, str]]]:
    path = Path(path)
    if path.suffix.lower() not in TABLE_SUFFIXES:
        return [], []
    with path.open(encoding="utf-8", errors="replace", newline="") as handle:
        first = handle.readline()
        handle.seek(0)
        delim = "\t" if first.count("\t") > first.count(",") else ","
        reader = csv.DictReader(handle, delimiter=delim)
        cols = [c for c in (reader.fieldnames or []) if c is not None]
        max_rows = max(1, min(max_rows, MAX_CELLS // max(1, len(cols))))
        rows: list[dict[str, str]] = []
        for i, row in enumerate(reader):
            if i >= max_rows:
                break
            rows.append({k: (row.get(k) or "") for k in cols})
    return cols, rows


class TableSet:
    """All input tables of a figure; columns are looked up main-table first."""

    def __init__(self, tables: dict[str, tuple[list[str], list[dict[str, str]]]], main: str | None = None):
        self.tables = tables
        self.main = main if main in tables else next(iter(tables), None)

    @classmethod
    def from_paths(cls, paths: dict[str, Path]) -> "TableSet":
        loaded = {field: read_table_preview(Path(p)) for field, p in paths.items()}
        loaded = {k: v for k, v in loaded.items() if v[0]}
        main = "input" if "input" in loaded else ("file" if "file" in loaded else None)
        return cls(loaded, main)

    @property
    def main_rows(self) -> list[dict[str, str]]:
        return self.tables[self.main][1] if self.main else []

    @property
    def columns(self) -> set[str]:
        return {c for cols, _ in self.tables.values() for c in cols}

    def values(self, column: str) -> list[str]:
        """Non-missing values of a column (main table first)."""
        order = [self.main] + [k for k in self.tables if k != self.main] if self.main else list(self.tables)
        for field in order:
            cols, rows = self.tables[field]
            if column in cols:
                return [r.get(column, "") for r in rows if not _missing(r.get(column))]
        return []

    def rows_with(self, *columns: str) -> list[dict[str, str]]:
        """Rows of the first table that has all the given columns (main table first)."""
        order = [self.main] + [k for k in self.tables if k != self.main] if self.main else list(self.tables)
        for field in order:
            cols, rows = self.tables[field]
            if all(c in cols for c in columns):
                return rows
        return []

    def numbers(self, column: str) -> list[float]:
        return [float(v) for v in self.values(column) if _finite(v)]


# ---------------------------------------------------------------------------
# Role resolution
# ---------------------------------------------------------------------------

def resolve_roles(spec: dict[str, Any], meta: dict[str, Any] | None, tables: TableSet) -> tuple[dict[str, Any], dict[str, str]]:
    """Return ({role: column or [columns]}, {role: "mapped"|"autodetect"})."""
    mapping = {k: v for k, v in (spec.get("mapping") or {}).items() if v not in (None, "", [])}
    aliases = (meta or {}).get("role_aliases") or {}
    resolved: dict[str, Any] = {}
    how: dict[str, str] = {}
    for role, col in mapping.items():
        role = aliases.get(role, role)
        resolved[role] = col
        how[role] = "mapped"
    # Plugins match autodetect candidates case-insensitively.
    by_lower = {c.lower(): c for c in tables.columns}
    for role, entry in ((meta or {}).get("roles") or {}).items():
        if role in resolved:
            continue
        for candidate in entry.get("autodetect") or []:
            if str(candidate).lower() in by_lower:
                resolved[role] = by_lower[str(candidate).lower()]
                how[role] = "autodetect"
                break
    return resolved, how


def _single(col: Any) -> str | None:
    return col if isinstance(col, str) else None


def _as_list(col: Any) -> list[str]:
    return [c for c in (col if isinstance(col, list) else [col]) if isinstance(c, str) and c]


# ---------------------------------------------------------------------------
# Global rules
# ---------------------------------------------------------------------------

def global_guardrails(spec: dict[str, Any], meta: dict[str, Any] | None, tables: TableSet,
                      roles: dict[str, Any], how: dict[str, str]) -> list[dict[str, str]]:
    issues: list[dict[str, str]] = []
    meta = meta or {}
    columns = tables.columns
    if tables.main is not None and not tables.main_rows:
        issues.append(_issue("EMPTY_DATA", "input", "Input table has no rows to plot.", "error"))

    known = set((meta.get("roles") or {})) | set((meta.get("role_aliases") or {}))
    for role, col in (spec.get("mapping") or {}).items():
        if col in (None, "", []):
            continue
        if meta.get("roles") and role not in known:
            issues.append(_issue("UNSUPPORTED_ROLE", f"mapping.{role}",
                                 f"Skill '{meta.get('id')}' has no parameter for role '{role}'; the mapping would be ignored.", "error"))
        if columns:
            required = role in (meta.get("required_roles") or [])
            for c in _as_list(col):
                if c not in columns:
                    issues.append(_issue("MISSING_MAPPED_COLUMN", f"mapping.{role}",
                                         f"Column '{c}' not in the input table(s)"
                                         + ("." if required else "; the renderer will ignore this mapping or fall back to a default."),
                                         "error" if required else "warning"))

    if columns:
        for role in meta.get("required_roles") or []:
            if role not in roles and role != "signed_effect":  # signed effect has a dedicated enrichment code
                issues.append(_issue("REQUIRED_ROLE_MISSING", f"mapping.{role}",
                                     f"Role '{role}' is required by this skill but is neither mapped nor auto-detectable.", "error"))

    for role, col in roles.items():
        if how.get(role) == "autodetect":
            issues.append(_issue("AUTODETECTED_COLUMN", f"mapping.{role}",
                                 f"Role '{role}' resolved to column '{col}' by the plugin's autodetect rule; map it explicitly to record intent.", "info"))

    role_entries = meta.get("roles") or {}
    for role, col in roles.items():
        kind = (role_entries.get(role) or {}).get("kind") or ("numeric" if role in NUMERIC_ROLES else "any")
        if kind != "numeric":
            continue
        for c in _as_list(col):
            values = tables.values(c)
            if not values:
                continue
            numeric = sum(1 for v in values if _is_number(v))
            if numeric < 0.8 * len(values):
                issues.append(_issue("NON_NUMERIC_VALUES", f"mapping.{role}",
                                     f"Role '{role}' expects numbers but column '{c}' is mostly non-numeric.", "error"))
                continue
            bad = sum(1 for v in values if _is_number(v) and not _finite(v))
            if bad:
                issues.append(_issue("NON_FINITE_VALUES", f"mapping.{role}", f"{bad} non-finite values in column '{c}'.",
                                     "error" if bad > len(values) * 0.2 else "warning"))

    for role in ("pvalue", "adjusted_pvalue"):
        col = _single(roles.get(role))
        if col:
            nums = tables.numbers(col)
            out = sum(1 for x in nums if x < 0 or x > 1)
            if out:
                issues.append(_issue("PVALUE_OUT_OF_RANGE", f"mapping.{role}",
                                     f"{out} values in '{col}' fall outside [0, 1]; this column is not a probability "
                                     "(already -log10 transformed?).", "error"))

    pcol = _single(roles.get("pvalue"))
    if pcol and how.get("pvalue") == "autodetect" and ADJ_P_NAME.search(pcol):
        issues.append(_issue("ADJUSTED_P_AS_PVALUE", "mapping.pvalue",
                             f"The p-value role auto-selected '{pcol}', which looks adjusted; label the figure as FDR/adjusted "
                             "or map the p-value column explicitly.", "info"))

    adj = _single(roles.get("adjusted_pvalue"))
    if adj and RAW_P_NAME.search(adj) and not ADJ_P_NAME.search(adj):
        issues.append(_issue("RAW_P_USED_AS_ADJUSTED", "mapping.adjusted_pvalue",
                             f"Column '{adj}' looks like raw p-values but is used as the adjusted p-value"
                             f"{' (selected by autodetect)' if how.get('adjusted_pvalue') == 'autodetect' else ''}.", "error"))

    raw = _single(roles.get("pvalue"))
    if raw and adj and raw != adj:
        pairs = [(r.get(raw), r.get(adj)) for r in tables.rows_with(raw, adj)]
        below = sum(1 for p, q in pairs if _finite(p) and _finite(q) and float(q) < float(p) * (1 - 1e-9))
        if below:
            issues.append(_issue("ADJUSTED_BELOW_RAW", "mapping.adjusted_pvalue",
                                 f"{below} rows have adjusted p < raw p; adjusted p-values cannot be smaller than raw ones. "
                                 "Check that the columns are not swapped.", "warning"))

    visual = spec.get("visual") or {}
    legacy = spec.get("legacy_params") or {}
    label_text = " ".join(str(x) for x in (visual.get("legend_title"), visual.get("title"), legacy.get("legend_title"),
                                            legacy.get("size_legend_title"), legacy.get("color_legend_title")) if x).lower()
    if raw and not adj and RAW_P_NAME.search(raw) and not ADJ_P_NAME.search(raw):
        if "fdr" in label_text or "adjusted" in label_text or "q-value" in label_text:
            issues.append(_issue("RAW_P_LABELED_AS_FDR", "mapping",
                                 f"Column '{raw}' looks like raw p-values but labels mention FDR/adjusted.", "error"))
        else:
            issues.append(_issue("RAW_P_USED", "mapping.pvalue",
                                 "Raw p-values appear to be used. Adjusted p-values are recommended when multiple tests apply.", "warning"))

    corr = _single(roles.get("correlation"))
    if corr:
        out = sum(1 for x in tables.numbers(corr) if x < -1 - 1e-9 or x > 1 + 1e-9)
        if out:
            issues.append(_issue("CORRELATION_OUT_OF_RANGE", "mapping.correlation",
                                 f"{out} correlation values in '{corr}' fall outside [-1, 1].", "error"))

    size = _single(roles.get("size"))
    if size and any(x < 0 for x in tables.numbers(size)):
        issues.append(_issue("NEGATIVE_SIZE", "mapping.size", "Size/gene_count contains negative values.", "error"))

    stats = spec.get("statistics") or {}
    if stats.get("multiple_testing") in {"fdr", "bh", "BH", "bonferroni"} and not (roles.get("adjusted_pvalue") or roles.get("significance")):
        issues.append(_issue("MULTIPLE_TESTING_WITHOUT_COLUMN", "statistics.multiple_testing",
                             "multiple_testing is set but no adjusted_pvalue/significance mapping is provided.", "warning"))
    return issues


# ---------------------------------------------------------------------------
# Family rules
# ---------------------------------------------------------------------------

def _signs(values: list[float]) -> tuple[bool, bool]:
    return any(v > 0 for v in values), any(v < 0 for v in values)


def enrichment_family_guardrails(spec, meta, tables, roles, how) -> list[dict[str, str]]:
    issues: list[dict[str, str]] = []
    meta = meta or {}
    needs_signed = "signed_effect" in (meta.get("required_roles") or []) or "require_signed_metric" in (meta.get("guardrails") or [])
    if not roles.get("category") and "category" in (meta.get("required_roles") or []):
        issues.append(_issue("MISSING_CATEGORY", "mapping.category", "Enrichment plots require a category/term mapping.", "error"))
    effect = _single(roles.get("signed_effect"))
    if not effect:
        if needs_signed:
            issues.append(_issue("MISSING_SIGNED_EFFECT", "mapping.effect",
                                 "A bidirectional enrichment lollipop requires a signed effect metric.", "error"))
        return issues
    pos, neg = _signs(tables.numbers(effect))
    if (pos or neg) and not (pos and neg):
        issues.append(_issue("EFFECT_NOT_BIDIRECTIONAL", "mapping.effect",
                             "Effect values do not span both signs; zero-centered lollipop may be misleading.", "warning"))
    return issues


def differential_expression_guardrails(spec, meta, tables, roles, how) -> list[dict[str, str]]:
    issues: list[dict[str, str]] = []
    effect = _single(roles.get("signed_effect"))
    if not effect:
        return issues
    values = tables.numbers(effect)
    if not values:
        return issues
    pos, neg = _signs(values)
    if pos and not neg:
        median = pystats.median(values)
        if 0.25 <= median <= 4 and min(values) > 0:
            issues.append(_issue("FOLD_CHANGE_NOT_LOG", "mapping.signed_effect",
                                 f"All values in '{effect}' are positive (median {median:.2f}); this looks like a raw fold change, "
                                 "but volcano plots expect log2 fold change centred on 0.", "warning"))
        else:
            issues.append(_issue("EFFECT_NOT_BIDIRECTIONAL", "mapping.signed_effect",
                                 "Effect values are all positive; down-regulated features are absent or the sign was lost.", "warning"))
    elif neg and not pos:
        issues.append(_issue("EFFECT_NOT_BIDIRECTIONAL", "mapping.signed_effect",
                             "Effect values are all negative; up-regulated features are absent or the sign was flipped.", "warning"))
    return issues


def embedding_guardrails(spec, meta, tables, roles, how) -> list[dict[str, str]]:
    issues: list[dict[str, str]] = []
    for axis in ("x", "y"):
        col = _single(roles.get(axis))
        values = tables.values(col) if col else []
        if values and sum(1 for v in values if _finite(v)) < 0.95 * len(values):
            issues.append(_issue("NON_NUMERIC_COORDINATES", f"mapping.{axis}",
                                 f"Embedding coordinate '{col}' must be numeric.", "error"))
    id_col = _single(roles.get("id"))
    if id_col:
        ids = tables.values(id_col)
        dup = len(ids) - len(set(ids))
        if dup:
            issues.append(_issue("DUPLICATE_IDS", "mapping.id", f"{dup} duplicated ids in '{id_col}'; cells may be drawn twice.", "warning"))
    group = _single(roles.get("group"))
    if group:
        levels = set(tables.values(group))
        if len(levels) > TOO_MANY_GROUPS:
            issues.append(_issue("TOO_MANY_GROUPS", "mapping.group",
                                 f"'{group}' has {len(levels)} levels; colours cannot be distinguished beyond ~{TOO_MANY_GROUPS}.", "warning"))
    return issues


def composition_guardrails(spec, meta, tables, roles, how) -> list[dict[str, str]]:
    issues: list[dict[str, str]] = []
    for role in ("value", "weight"):
        for col in _as_list(roles.get(role)):
            neg = sum(1 for x in tables.numbers(col) if x < 0)
            if neg:
                issues.append(_issue("NEGATIVE_COMPOSITION", f"mapping.{role}",
                                     f"{neg} negative values in '{col}'; composition parts must be non-negative.", "error"))
    return issues


def group_comparison_guardrails(spec, meta, tables, roles, how) -> list[dict[str, str]]:
    issues: list[dict[str, str]] = []
    stats = spec.get("statistics") or {}
    if stats.get("comparisons") and not stats.get("method"):
        issues.append(_issue("STAT_METHOD_UNSPECIFIED", "statistics.method",
                             "Comparisons are drawn but no test is recorded; the plugin default test will be used and "
                             "should be reported in the methods.", "warning"))
    group = _single(roles.get("group"))
    method = str(stats.get("method") or "").lower()
    if group and method and method not in {"none", "supplied"}:
        counts: dict[str, int] = {}
        for v in tables.values(group):
            counts[v] = counts.get(v, 0) + 1
        small = sorted(k for k, n in counts.items() if n < 3)
        if small:
            issues.append(_issue("SMALL_GROUPS", "mapping.group",
                                 f"Groups with fewer than 3 observations cannot support '{method}': {', '.join(small[:5])}.", "warning"))
    return issues


def network_guardrails(spec, meta, tables, roles, how) -> list[dict[str, str]]:
    issues: list[dict[str, str]] = []
    weight = _single(roles.get("weight"))
    if weight and any(x < 0 for x in tables.numbers(weight)):
        issues.append(_issue("NEGATIVE_WEIGHT", "mapping.weight",
                             "Negative edge weights cannot be drawn as widths; use a signed colour scale instead.", "warning"))
    src, tgt = _single(roles.get("source")), _single(roles.get("target"))
    if src and tgt:
        loops = sum(1 for r in tables.rows_with(src, tgt) if r.get(src) and r.get(src) == r.get(tgt))
        if loops:
            issues.append(_issue("SELF_LOOPS", "mapping.source", f"{loops} edges connect a node to itself.", "info"))
    return issues


def enrichment_lollipop_guardrails(spec, meta, tables, roles, how) -> list[dict[str, str]]:
    issues: list[dict[str, str]] = []
    visual = spec.get("visual") or {}
    legacy = spec.get("legacy_params") or {}
    if visual.get("stem_to_zero") is False or legacy.get("stem_show") is False:
        issues.append(_issue("STEM_DISABLED", "visual.stem_to_zero",
                             "Stem-to-zero is disabled; Cleveland/lollipop convention usually requires stems to zero.", "warning"))
    return issues


Rule = Callable[..., list[dict[str, str]]]
FAMILY_RULES: dict[str, Rule] = {
    "enrichment": enrichment_family_guardrails,
    "differential_expression": differential_expression_guardrails,
    "embedding": embedding_guardrails,
    "composition": composition_guardrails,
    "group_comparison": group_comparison_guardrails,
    "network": network_guardrails,
}
SKILL_RULES: dict[str, Rule] = {
    "interactive_enrichment_lollipop": enrichment_lollipop_guardrails,
}


def validate_scientific(
    spec: dict[str, Any],
    *,
    table_path: Path | None = None,
    tables: dict[str, Path] | None = None,
    columns: list[str] | None = None,
    rows: list[dict[str, str]] | None = None,
    family: str | None = None,
    meta: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Run global + family + skill scientific validators. Does not silently repair."""
    from vnext.adapters.legacy_r import load_skill_metadata

    skill_id = ((spec.get("skill") or {}).get("id")) or ""
    meta = meta if meta is not None else load_skill_metadata(skill_id)
    if columns is not None and rows is not None:
        table_set = TableSet({"input": (list(columns), list(rows))}, "input")
    else:
        paths = dict(tables or {})
        if table_path:
            paths.setdefault("input", Path(table_path))
        table_set = TableSet.from_paths(paths)

    roles, how = resolve_roles(spec, meta, table_set)
    fam = (family or (meta or {}).get("family") or "").lower()
    if not fam and "enrichment" in skill_id:
        fam = "enrichment"

    issues = global_guardrails(spec, meta, table_set, roles, how)
    if fam in FAMILY_RULES:
        issues.extend(FAMILY_RULES[fam](spec, meta, table_set, roles, how))
    if skill_id in SKILL_RULES:
        issues.extend(SKILL_RULES[skill_id](spec, meta, table_set, roles, how))

    errors = [i for i in issues if i.get("severity") == "error"]
    return {
        "valid": not errors,
        "errors": errors,
        "warnings": [i for i in issues if i.get("severity") == "warning"],
        "infos": [i for i in issues if i.get("severity") == "info"],
        "resolved_roles": roles,
        "family": fam or None,
    }
