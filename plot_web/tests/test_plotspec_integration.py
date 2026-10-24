from __future__ import annotations

import json
from pathlib import Path

import pytest

from plot_web.server import plotspec, runner, settings, storage

ROOT = Path(__file__).resolve().parents[2]
VOLCANO = ROOT / "plugins/sca_volcano_plot/examples/avg"


@pytest.fixture()
def tmp_storage(tmp_path, monkeypatch):
    for name, sub in {"JOBS_DIR": "jobs", "RESULTS_DIR": "results", "UPLOADS_DIR": "uploads", "STATE_DIR": "state",
                      "DATASETS_DIR": "datasets", "PREVIEWS_DIR": "previews", "REPORTS_DIR": "reports"}.items():
        monkeypatch.setattr(settings, name, tmp_path / sub)
        monkeypatch.setattr(storage, name, tmp_path / sub, raising=False)
    monkeypatch.setattr(storage, "CURRENT_STATE_PATH", tmp_path / "state" / "current_state.json")
    monkeypatch.setattr(storage, "FIGURE_INDEX_PATH", tmp_path / "figure_index.json")
    monkeypatch.setattr(plotspec, "JOBS_DIR", tmp_path / "jobs")
    storage.ensure_storage()
    return tmp_path


def _job(tmp_path: Path, input_file: Path, params: dict) -> tuple[dict, Path]:
    job_dir = tmp_path / "jobs" / "job_t"
    job_dir.mkdir(parents=True, exist_ok=True)
    params_path = job_dir / "params.json"
    params_path.write_text(json.dumps(params), encoding="utf-8")
    out = tmp_path / "results" / "job_t"
    job = {"job_id": "job_t", "figure_id": "fig_t", "plugin_id": "sca_volcano_plot", "params_path": str(params_path),
           "output_dir": str(out), "uploaded_files": {"file": str(input_file)}}
    return job, out


def test_job_gets_plotspec_and_validation(tmp_storage):
    params = json.loads((VOLCANO / "params.json").read_text())
    job, out = _job(tmp_storage, VOLCANO / "input/example_markers.csv", params)
    summary = plotspec.prepare_job_plotspec(job, params, out, seed=42)
    assert summary["valid"] is True and len(summary["plotspec_hash"]) == 64
    spec = json.loads((out / "plotspec.json").read_text())
    assert spec["skill"]["id"] == "sca_volcano_plot"
    assert spec["provenance"]["seed"] == 42
    assert spec["inputs"]["file"]["checksum"]
    assert (out / "validation.json").exists()
    assert "plotspec" in storage.output_urls_for_dir("fig_t", out)


def test_enforce_mode_blocks_scientifically_invalid_render(tmp_storage, tmp_path, monkeypatch):
    raw_p = tmp_path / "markers.csv"
    raw_p.write_text((VOLCANO / "input/example_markers.csv").read_text().replace("p_val_adj", "p_val", 1))
    params = json.loads((VOLCANO / "params.json").read_text())
    job, out = _job(tmp_storage, raw_p, params)
    monkeypatch.setattr(plotspec, "VALIDATION_MODE", "enforce")

    def no_render(*args, **kwargs):  # the plugin must not be started
        raise AssertionError("render should be blocked")

    monkeypatch.setattr(runner.subprocess, "run", no_render)
    result = runner.run_local_job(job, ["Rscript", "plot.R"], ROOT, out)
    assert result["status"] == "failed"
    assert "RAW_P_USED_AS_ADJUSTED" in result["error"]["detail"]


def test_plotspec_import_export_endpoints():
    from fastapi.testclient import TestClient

    from plot_web.app import app

    client = TestClient(app)
    params = json.loads((VOLCANO / "params.json").read_text())
    exported = client.post("/api/vnext/plotspec/from-params", json={"plugin_id": "sca_volcano_plot", "params": params})
    assert exported.status_code == 200 and exported.json()["schema"]["valid"]
    imported = client.post("/api/vnext/plotspec/to-params", json={"plotspec": exported.json()["plotspec"]})
    assert imported.status_code == 200
    body = imported.json()
    assert body["plugin_id"] == "sca_volcano_plot"
    assert body["params"] == {k: v for k, v in params.items() if k != "plugin_id"}
    assert client.post("/api/vnext/plotspec/to-params", json={"plotspec": {"not": "a spec"}}).status_code == 422
