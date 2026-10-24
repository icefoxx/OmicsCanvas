from __future__ import annotations

import json
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parents[2]


def _examples():
    for manifest in sorted((ROOT / "plugins").glob("*/examples/*/manifest.json")):
        m = json.loads(manifest.read_text(encoding="utf-8"))
        params = json.loads((manifest.parent / (m.get("params") or "params.json")).read_text(encoding="utf-8"))
        tables = {k: manifest.parent / v for k, v in (m.get("inputs") or {}).items() if isinstance(v, str)}
        yield manifest.parts[-4], manifest.parent.name, params, tables


EXAMPLES = list(_examples())


def test_every_plugin_has_current_metadata():
    """metadata.yaml must match what `vnext.cli migrate` generates from rules.yaml."""
    from vnext.migrate.generator import generate_metadata, load_rules

    rules = load_rules()
    stale = []
    for cfg in sorted((ROOT / "plugins").glob("*/config.yaml")):
        path = cfg.parent / "vnext" / "metadata.yaml"
        on_disk = yaml.safe_load(path.read_text(encoding="utf-8")) if path.exists() else None
        if on_disk != generate_metadata(cfg.parent, rules):
            stale.append(cfg.parent.name)
    assert not stale, f"run `python -m vnext.cli migrate`; stale: {stale}"


def test_registry_lists_every_plugin_as_migrated():
    from vnext.registry.loader import build_registry_from_plugins, validate_registry

    reg = build_registry_from_plugins()
    assert validate_registry(reg)["valid"]
    skills = reg["skills"]
    assert len(skills) == len(list((ROOT / "plugins").glob("*/config.yaml")))
    assert all(s["capabilities"]["vnext_migrated"] for s in skills)


def test_params_plotspec_roundtrip_is_lossless_for_all_examples():
    from vnext.adapters.legacy_r import legacy_params_to_plotspec, plotspec_to_legacy_params
    from vnext.plotspec.model import round_trip, validate_schema

    failures = []
    for plugin_id, example_id, params, _ in EXAMPLES:
        spec = round_trip(legacy_params_to_plotspec(plugin_id, params))
        assert validate_schema(spec)["valid"], (plugin_id, example_id)
        expected = {**{k: v for k, v in params.items() if k != "dispatch_mode"}, "plugin_id": plugin_id}
        if plotspec_to_legacy_params(spec) != expected:
            failures.append(f"{plugin_id}/{example_id}")
    assert not failures


def test_clean_examples_have_no_scientific_errors():
    from vnext.adapters.legacy_r import legacy_params_to_plotspec
    from vnext.validate.pipeline import validate_plotspec

    bad = []
    for plugin_id, example_id, params, tables in EXAMPLES:
        res = validate_plotspec(legacy_params_to_plotspec(plugin_id, params), tables=tables)
        if not res["valid"]:
            bad.append((plugin_id, example_id, [e["code"] for e in res["errors"]]))
    assert not bad


def test_generic_adapter_matches_reference_lollipop_adapter():
    """The metadata-driven adapter reproduces the hand-written lollipop mapping."""
    from vnext.adapters.legacy_r import plotspec_to_legacy_params
    from vnext.plotspec.model import load

    spec = load(ROOT / "plugins/interactive_enrichment_lollipop/vnext/examples/oct4_expected_spec.json")
    params = plotspec_to_legacy_params(spec)
    assert params["category_column"] == "category"
    assert params["value_column"] == "effect"
    assert params["zero_line_show"] is True and params["stem_show"] is True
    assert params["sort"] == "none"  # transform.preserve_order
    assert "orientation" not in params  # recorded in the spec, not forwarded


# ---------------------------------------------------------------------------
# Guardrail unit tests on synthetic tables
# ---------------------------------------------------------------------------

def _validate(skill, mapping, columns, rows, **spec_extra):
    from vnext.plotspec.model import empty_spec
    from vnext.validate.scientific import validate_scientific

    spec = empty_spec(skill)
    spec["mapping"] = mapping
    spec.update(spec_extra)
    res = validate_scientific(spec, columns=columns, rows=rows)
    return {i["code"]: i["severity"] for i in res["errors"] + res["warnings"] + res["infos"]}


def test_pvalue_out_of_range_is_an_error():
    rows = [{"term": "a", "nes": "1.2", "p": "3.5"}, {"term": "b", "nes": "-1", "p": "0.01"}]
    codes = _validate("fgsea_enrichment_plot", {"category": "term", "signed_effect": "nes", "adjusted_pvalue": "p"},
                      ["term", "nes", "p"], rows)
    assert codes.get("PVALUE_OUT_OF_RANGE") == "error"


def test_raw_p_column_as_adjusted_is_an_error():
    rows = [{"gene": "A", "avg_log2FC": "1", "p_val": "0.01"}, {"gene": "B", "avg_log2FC": "-1", "p_val": "0.2"}]
    codes = _validate("sca_volcano_plot", {"feature": "gene", "signed_effect": "avg_log2FC", "adjusted_pvalue": "p_val"},
                      ["gene", "avg_log2FC", "p_val"], rows)
    assert codes.get("RAW_P_USED_AS_ADJUSTED") == "error"


def test_unlogged_fold_change_is_flagged():
    rows = [{"gene": g, "fc": str(v), "padj": "0.01"} for g, v in zip("ABCDE", [0.5, 0.9, 1.4, 2.0, 3.1])]
    codes = _validate("sca_volcano_plot", {"feature": "gene", "signed_effect": "fc", "adjusted_pvalue": "padj"},
                      ["gene", "fc", "padj"], rows)
    assert "FOLD_CHANGE_NOT_LOG" in codes


def test_adjusted_below_raw_is_flagged():
    rows = [{"term": "a", "pvalue": "0.04", "p.adjust": "0.01"}]
    codes = _validate("go_kegg_enrichment_bar_bubble", {"category": "term", "pvalue": "pvalue", "adjusted_pvalue": "p.adjust"},
                      ["term", "pvalue", "p.adjust"], rows)
    assert codes.get("ADJUSTED_BELOW_RAW") == "warning"


def test_negative_composition_and_size():
    rows = [{"sample": "s1", "group": "a", "value": "-3"}, {"sample": "s2", "group": "b", "value": "4"}]
    codes = _validate("stacked_bar_plot", {"sample": "sample", "group": "group", "value": "value"},
                      ["sample", "group", "value"], rows)
    assert codes.get("NEGATIVE_COMPOSITION") == "error"


def test_correlation_out_of_range():
    rows = [{"spec": "x", "env": "pH", "r": "1.7", "p": "0.01"}]
    codes = _validate("interactive_mantel_correlation_network", {"correlation": "r", "pvalue": "p"},
                      ["spec", "env", "r", "p"], rows)
    assert codes.get("CORRELATION_OUT_OF_RANGE") == "error"


def test_na_tokens_are_missing_not_text():
    rows = [{"term": "a", "x": "NA"}, {"term": "b", "x": "0.5"}, {"term": "c", "x": "1.5"}]
    codes = _validate("threshold_matrix_heatmap", {"label": "term", "value": ["x"]}, ["term", "x"], rows)
    assert "NON_NUMERIC_VALUES" not in codes


def test_role_without_renderer_parameter_is_unsupported():
    rows = [{"category": "a", "effect": "1", "padj": "0.01"}, {"category": "b", "effect": "-1", "padj": "0.2"}]
    codes = _validate("interactive_enrichment_lollipop",
                      {"category": "category", "signed_effect": "effect", "adjusted_pvalue": "padj"},
                      ["category", "effect", "padj"], rows)
    assert codes.get("UNSUPPORTED_ROLE") == "error"


@pytest.mark.parametrize("plugin_ids", [["sca_volcano_plot", "go_kegg_enrichment_bar_bubble", "stacked_bar_plot",
                                         "interactive_mantel_correlation_network"]])
def test_fault_injection_subset_detected_without_false_positives(plugin_ids):
    from vnext.benchmark.guardrails import run_benchmark

    summary = run_benchmark(render=False, jobs=2, plugin_ids=plugin_ids)["summary"]
    assert summary["clean"]["false_positive_errors"] == 0
    assert summary["total"]["n"] > 0
    assert summary["total"]["detected"] == summary["total"]["n"]
