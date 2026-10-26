"""Regression coverage for real editor data and example previews (no R required)."""
from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from plot_web.app import app
from plot_web.server.routes import plugins

ROOT = Path(__file__).resolve().parents[2]
DATA = b"gene,avg_log2FC,p_val_adj\nTEST_A,3.5,0.00001\nTEST_B,-3,0.0001\n"


@pytest.fixture()
def editor_client(tmp_path, monkeypatch):
    for name in ("PREVIEWS_DIR", "UPLOADS_DIR", "RESULTS_DIR", "JOBS_DIR"):
        monkeypatch.setattr(plugins, name, tmp_path / name.lower())
    monkeypatch.setattr(plugins, "ensure_storage", lambda: None)
    monkeypatch.setattr(plugins, "save_job", lambda job: None)
    return TestClient(app)


def test_uploaded_table_preview_uses_its_actual_columns_and_rows(editor_client):
    response = editor_client.post("/api/plugins/sca_volcano_plot/preview-input", files={"input": ("mine.csv", DATA, "text/csv")})
    assert response.status_code == 200
    table = response.json()["files"]["input"]
    assert table["columns"] == ["gene", "avg_log2FC", "p_val_adj"]
    assert table["row_count_estimate"] == 2
    assert table["preview_rows"][0]["gene"] == "TEST_A"


def test_real_run_uses_uploaded_bytes_and_parameters(editor_client, monkeypatch):
    captured = {}

    def render(job, command, plugin_dir, output_dir):
        captured["input"] = Path(command[command.index("--input") + 1]).read_bytes()
        captured["params"] = Path(job["params_path"]).read_text()
        return {**job, "status": "completed", "outputs": {}}

    monkeypatch.setattr(plugins, "run_local_job", render)
    response = editor_client.post("/api/plugins/sca_volcano_plot/run", files={"input": ("mine.csv", DATA, "text/csv")}, data={"params": '{"title":"My experiment"}'})
    assert response.status_code == 200
    assert response.json()["status"] == "completed"
    assert captured["input"] == DATA
    assert '"title": "My experiment"' in captured["params"]
    assert "dataset_demo" not in response.text


def test_background_render_is_opt_in_and_returns_poll_url(editor_client, monkeypatch):
    captured = []
    def submit(job, *args):
        captured.append(job)
        return {**job, "poll_url": f"/api/jobs/{job['job_id']}"}
    monkeypatch.setattr(plugins, "submit_render", submit)
    response = editor_client.post("/api/plugins/sca_volcano_plot/run", files={"input": ("mine.csv", DATA)},
                                  data={"params": "{}", "background": "1", "render_channel": "editor-one"})
    assert response.status_code == 202
    assert response.json()["poll_url"].startswith("/api/jobs/")
    assert captured[0]["render_channel"] == "editor-one"
    response = editor_client.post("/api/plugins/sca_volcano_plot/run-demo", json={"background": True})
    assert response.status_code == 202
    assert len(captured) == 2


def test_example_preview_matches_the_selected_bundle(editor_client):
    response = editor_client.get("/api/plugins/group_heatmap/examples/cell_heatmap")
    assert response.status_code == 200
    body = response.json()
    table = body["input_preview"]["files"]["input"]
    assert table["filename"] == body["inputs"]["input"]["filename"]
    assert "cell" in table["columns"] and "CD3D" in table["columns"]
    assert table["row_count_estimate"] > 0


def test_invalid_workbook_is_reported_as_upload_failure(editor_client):
    response = editor_client.post("/api/plugins/sca_volcano_plot/preview-input", files={"input": ("bad.xlsx", b"not a workbook")})
    assert response.status_code == 400
    assert "Failed to read Excel" in response.json()["detail"]


def test_frontend_editor_regressions():
    node = shutil.which("node")
    if not node:
        pytest.skip("Node.js is needed for editor runtime regression tests")
    result = subprocess.run([node, "--test", str(ROOT / "plot_web/tests/frontend/editor_runtime.test.cjs")], capture_output=True, text=True, timeout=30)
    assert result.returncode == 0, result.stdout + result.stderr
