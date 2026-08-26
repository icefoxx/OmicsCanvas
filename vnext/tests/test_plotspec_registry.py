from __future__ import annotations

import json
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]


def test_plotspec_roundtrip_lossless():
    from vnext.plotspec.model import load, round_trip, validate_schema

    spec_path = (
        ROOT
        / "plugins/interactive_enrichment_lollipop/vnext/examples/oct4_expected_spec.json"
    )
    spec = load(spec_path)
    rt = round_trip(spec)
    assert json.dumps(rt, sort_keys=True) == json.dumps(spec, sort_keys=True)
    res = validate_schema(rt)
    assert res["valid"], res


def test_registry_loads_and_validates():
    from vnext.registry.loader import (
        build_registry_from_plugins,
        get_skill,
        validate_registry,
        write_registry,
    )

    reg = build_registry_from_plugins()
    write_registry(reg)
    res = validate_registry(reg)
    assert res["valid"], res
    assert res["n_skills"] >= 40
    skill = get_skill("interactive_enrichment_lollipop", reg)
    assert skill is not None
    assert "category" in skill.get("required_semantics", [])


def test_scientific_validator_requires_signed_effect():
    from vnext.plotspec.model import load
    from vnext.validate.scientific import validate_scientific

    spec = load(
        ROOT
        / "plugins/interactive_enrichment_lollipop/vnext/examples/oct4_expected_spec.json"
    )
    bad = json.loads(json.dumps(spec))
    bad["mapping"].pop("signed_effect", None)
    table = (
        ROOT
        / "plugins/interactive_enrichment_lollipop/examples/oct4_enrichment/input/example_input.csv"
    )
    res = validate_scientific(bad, table_path=table, family="enrichment")
    assert not res["valid"]
    codes = {e["code"] for e in res["errors"]}
    assert "MISSING_SIGNED_EFFECT" in codes


def test_pipeline_accepts_oct4_spec():
    from vnext.plotspec.model import load
    from vnext.validate.pipeline import validate_plotspec

    spec = load(
        ROOT
        / "plugins/interactive_enrichment_lollipop/vnext/examples/oct4_expected_spec.json"
    )
    table = (
        ROOT
        / "plugins/interactive_enrichment_lollipop/examples/oct4_enrichment/input/example_input.csv"
    )
    res = validate_plotspec(spec, table_path=table)
    assert res["valid"], res
