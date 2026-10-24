from __future__ import annotations

from plot_web.dataset_columns import (
    apply_group_filters,
    effective_rows,
    infer_column_meta,
    profile_rows,
    suggest_mappings,
)


def test_infer_numeric_vs_categorical_vs_id():
    numeric = infer_column_meta("dim1", ["-1.2", "0.3", "4.1", "2"])
    assert numeric["kind"] == "numeric"
    embedding = infer_column_meta("dim1", [str(i + 0.13) for i in range(120)])
    assert embedding["kind"] == "numeric"
    cat = infer_column_meta("sample", ["WT", "KO", "WT", "Control", "KO"])
    assert cat["kind"] == "categorical"
    assert set(cat["levels"]) == {"WT", "KO", "Control"}
    cluster = infer_column_meta("cluster", [str(i % 8) for i in range(80)])
    assert cluster["kind"] == "categorical"
    ids = infer_column_meta("cell", [f"c{i}" for i in range(40)])
    assert ids["kind"] == "id"


def test_suggest_common_embedding_mappings():
    cols = ["cell", "dim1", "dim2", "cluster", "sample", "CD3D"]
    sug = suggest_mappings(cols)
    assert sug["x_column"] == "dim1"
    assert sug["y_column"] == "dim2"
    assert sug["id_column"] == "cell"
    assert sug["group_column"] == "cluster"


def test_group_include_exclude_exclude_wins():
    rows = [{"sample": "WT"}, {"sample": "KO"}, {"sample": "Control"}]
    only = apply_group_filters(rows, "sample", ["WT", "Control"], [])
    assert [r["sample"] for r in only] == ["WT", "Control"]
    dropped = apply_group_filters(rows, "sample", ["WT", "Control"], ["Control"])
    assert [r["sample"] for r in dropped] == ["WT"]
    none = apply_group_filters(rows, "sample", [], [])
    assert len(none) == 3


def test_effective_filter_order():
    rows = [
        {"cell": "a", "sample": "WT"},
        {"cell": "b", "sample": "KO"},
        {"cell": "c", "sample": "WT"},
    ]
    out = effective_rows(
        rows,
        filter_column="sample",
        included_levels=["WT", "KO"],
        excluded_levels=["KO"],
        id_column="cell",
        selected_rows=["a"],
        row_mode="include",
    )
    assert [r["cell"] for r in out] == ["a"]


def test_profile_rows_lists_kinds():
    rows = [{"dim1": "1", "cluster": "A"}, {"dim1": "2", "cluster": "B"}]
    profile = profile_rows(["dim1", "cluster"], rows)
    assert "dim1" in profile["numeric_columns"]
    assert "cluster" in profile["categorical_columns"]
