"""Scientific and export regression tests for the diverging lollipop mode."""
import csv
import json
import math
import shutil
import subprocess
from pathlib import Path

import pytest

from plot_web.server.runner import plugin_env

ROOT = Path(__file__).resolve().parents[2]
PLUGIN = ROOT / "plugins/interactive_enrichment_lollipop"
pytestmark = pytest.mark.skipif(not shutil.which("Rscript"), reason="Rscript required for plot integration tests")


def render(tmp_path, table, **overrides):
    source = tmp_path / "input.csv"
    source.write_text(table)
    params = {"category_column": "category", "value_column": "effect", "pvalue_column": "pvalue",
              "color_mode": "value", "size_transform": "neg_log10_pvalue",
              "category_label_position": "zero_opposite", "sort_by": "value", "sort": "descending",
              "width": 6, "height": 5, "dpi": 72, "legend_position": "right", **overrides}
    parameters = tmp_path / "params.json"
    parameters.write_text(json.dumps(params))
    output = tmp_path / "out"
    result = subprocess.run(["Rscript", str(PLUGIN / "plot.R"), "--input", str(source), "--params", str(parameters),
                             "--output", str(output)], cwd=ROOT, env=plugin_env(), capture_output=True, text=True, timeout=60)
    return result, output


def test_probabilities_are_transformed_once_and_ordered_by_signed_effect(tmp_path):
    result, out = render(tmp_path, "category,effect,pvalue\nB,-0.2,1e-10\nA,0.4,1e-5\nC,0,1\nD,-0.1,0\n",
                         point_shape=21, point_stroke=0.5, direction_labels_show=True, interactive=True)
    assert result.returncode == 0, result.stderr
    with (out / "selected_rows.csv").open() as handle:
        rows = list(csv.DictReader(handle))
    assert [row["category"] for row in rows] == ["A", "C", "D", "B"]
    sizes = {row["category"]: float(row["size"]) for row in rows}
    assert sizes["A"] == 5 and sizes["B"] == 10 and sizes["C"] == 0
    assert math.isfinite(sizes["D"]) and sizes["D"] > 300
    assert "Zero p-values were floored" in (out / "run.log").read_text()
    assert json.loads((out / "figure.json").read_text())["transforms"]["size"] == "neg_log10_pvalue"
    for extension in ["png", "svg", "pdf"]:
        assert (out / f"result.{extension}").stat().st_size > 100
    assert (out / "result.html").stat().st_size > 100


@pytest.mark.parametrize("probability", ["-0.1", "1.2", "NA"])
def test_invalid_probabilities_do_not_produce_partial_figures(tmp_path, probability):
    result, out = render(tmp_path, f"category,effect,pvalue\nA,0.4,{probability}\nB,-0.3,0.01\n")
    assert result.returncode != 0
    assert json.loads((out / "error.json").read_text())["error"] == "Invalid p-values"
    assert not list(out.glob("result.*"))


def test_probability_size_mode_requires_a_probability_column(tmp_path):
    result, out = render(tmp_path, "category,effect\nA,0.4\nB,-0.3\n")
    assert result.returncode != 0
    assert json.loads((out / "error.json").read_text())["error"] == "P-value column required"
