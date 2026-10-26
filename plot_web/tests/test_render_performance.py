"""Cache correctness and partial-file safety, without requiring an R runtime."""
import json
import threading
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from types import SimpleNamespace

import pytest

from plot_web.server import render_cache as cache, runner, render_tasks, settings


@pytest.fixture
def render_env(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "ROOT_DIR", tmp_path)
    monkeypatch.setattr(settings, "STORAGE_DIR", tmp_path / "storage")
    monkeypatch.setattr(cache, "runtime_fingerprint", lambda cmd: {"version": "test"})
    monkeypatch.setattr(runner, "save_job", lambda job: None)
    monkeypatch.setattr(runner, "record_job_in_state", lambda *args: None)
    def validate(job, params, output, seed):
        (output / "plotspec.json").write_text(job["job_id"])
        return {"errors": [], "mode": "warn"}
    monkeypatch.setattr(runner, "prepare_job_plotspec", validate)
    plugin = tmp_path / "plugins/test"
    plugin.mkdir(parents=True)
    (plugin / "plot.R").write_text("original")
    calls = []
    def execute(cmd, **kwargs):
        calls.append(cmd)
        output = Path(cmd[cmd.index("--output") + 1])
        for name in ("result.png", "result.svg", "result.pdf", "figure.json"):
            (output / name).write_text("test artifact")
        (output / "assets").mkdir()
        (output / "assets/widget.js").write_text("widget")
        return SimpleNamespace(returncode=0, stdout="ok", stderr="")
    monkeypatch.setattr(runner.subprocess, "run", execute)
    def make(name, data="x\n1", params=None):
        directory = tmp_path / name
        directory.mkdir()
        source = directory / "input.csv"
        source.write_text(data)
        parameters = directory / "params.json"
        parameters.write_text(json.dumps(params or {}))
        output = directory / "out"
        job = dict(job_id=name, figure_id=name, plugin_id="test", uploaded_files={"input": str(source)},
                   params_path=str(parameters), output_dir=str(output), seed=42)
        cmd = ["Rscript", str(plugin / "plot.R"), "--input", str(source), "--params", str(parameters), "--output", str(output)]
        return job, cmd, plugin, output
    return make, calls, plugin


def test_identical_inputs_reuse_artifacts_with_fresh_provenance(render_env):
    make, calls, _ = render_env
    first = runner.run_local_job(*make("first"))
    second_args = make("second")
    second = runner.run_local_job(*second_args)
    assert first["cache"]["hit"] is False
    assert second["cache"] == {"enabled": True, "hit": True, "source_job_id": "first"}
    assert len(calls) == 1
    assert (second_args[-1] / "plotspec.json").read_text() == "second"
    assert (second_args[-1] / "assets/widget.js").read_text() == "widget"
    assert "second" in second["outputs"]["preview"]


@pytest.mark.parametrize("change", ["data", "params", "seed", "plugin", "shared", "external"])
def test_changed_render_dependencies_invalidate_cache(render_env, change, tmp_path):
    make, calls, plugin = render_env
    external = tmp_path / "aux.csv"
    external.write_text("old")
    params = {"aux": str(external)} if change == "external" else {}
    runner.run_local_job(*make("first", params=params))
    if change == "plugin":
        (plugin / "plot.R").write_text("changed")
    if change == "shared":
        shared = tmp_path / "R/sca"
        shared.mkdir(parents=True)
        (shared / "draw.R").write_text("changed")
    if change == "external":
        external.write_text("new")
    if change in {"params", "seed"}:
        params = {"title": "new"} if change == "params" else {"seed": 7}
    result = runner.run_local_job(*make("second", data="x\n2" if change == "data" else "x\n1", params=params))
    assert result["cache"]["hit"] is False
    assert len(calls) == 2


def test_corrupt_cache_renders_again(render_env):
    make, calls, _ = render_env
    runner.run_local_job(*make("first"))
    next(cache.cache_dir().glob("*/files/result.png")).write_text("corrupt")
    assert runner.run_local_job(*make("second"))["cache"]["hit"] is False
    assert len(calls) == 2


def test_validation_is_enforced_before_cache_lookup(render_env, monkeypatch):
    make, calls, _ = render_env
    runner.run_local_job(*make("first"))
    monkeypatch.setattr(runner, "prepare_job_plotspec", lambda *args: {"errors": [{"code": "BAD", "message": "invalid"}]})
    monkeypatch.setattr(runner, "blocks_render", lambda summary: True)
    assert runner.run_local_job(*make("second"))["status"] == "failed"
    assert len(calls) == 1


def test_same_key_parallel_requests_only_render_once(render_env):
    make, calls, _ = render_env
    jobs = [make("first"), make("second")]
    with ThreadPoolExecutor(2) as pool:
        results = list(pool.map(lambda args: runner.run_local_job(*args), jobs))
    assert sum(result["cache"]["hit"] for result in results) == 1
    assert len(calls) == 1


def test_partial_images_are_not_served(tmp_path):
    png = tmp_path / "result.png"
    png.write_bytes(b"\x89PNG\r\n\x1a\npartial")
    assert render_tasks.ready_preview(tmp_path) is None
    svg = tmp_path / "result.svg"
    svg.write_text('<svg xmlns="http://www.w3.org/2000/svg"><g>')
    assert render_tasks.ready_preview(tmp_path) is None
    svg.write_text('<svg xmlns="http://www.w3.org/2000/svg"><g/></svg>')
    assert render_tasks.ready_preview(tmp_path) == svg
    png.write_bytes(b"\x89PNG\r\n\x1a\n" + b"\x00\x00\x00\x00IEND\xaeB`\x82")
    assert render_tasks.ready_preview(tmp_path) == png


def test_job_api_exposes_only_complete_previews_before_exports(tmp_path, monkeypatch):
    from fastapi.testclient import TestClient
    from plot_web.app import app
    from plot_web.server.routes import jobs
    monkeypatch.setattr(jobs, "load_job", lambda job_id: {"job_id": job_id, "status": "running", "output_dir": str(tmp_path)})
    client = TestClient(app)
    svg = tmp_path / "result.svg"
    svg.write_text("<svg>")
    assert "live_preview" not in client.get("/api/jobs/test").json()
    assert client.get("/api/jobs/test/preview").status_code == 404
    svg.write_text('<svg xmlns="http://www.w3.org/2000/svg"/>')
    job = client.get("/api/jobs/test").json()
    assert job["phase"] == "exporting"
    assert "outputs" not in job
    response = client.get(job["live_preview"])
    assert response.status_code == 200
    assert response.headers["content-type"].startswith("image/svg+xml")


def test_background_submission_returns_independent_snapshot(tmp_path, monkeypatch):
    entered, finish = threading.Event(), threading.Event()
    monkeypatch.setattr(render_tasks, "save_job", lambda job: None)
    job = {"job_id": "test", "status": "queued"}
    def render(background, *args):
        background["status"] = "running"
        entered.set()
        finish.wait(5)
    try:
        response = render_tasks.submit_render(job, [], tmp_path, tmp_path, render)
        assert entered.wait(2)
        assert response["status"] == job["status"] == "queued"
        assert response["poll_url"] == "/api/jobs/test"
    finally:
        finish.set()


def test_cache_can_be_disabled_and_is_bounded(render_env, monkeypatch):
    make, calls, _ = render_env
    monkeypatch.setenv("PLOT_RENDER_CACHE_MAX_ENTRIES", "2")
    for index in range(3):
        runner.run_local_job(*make(str(index), params={"title": str(index)}))
    assert len(list(cache.cache_dir().glob("*/manifest.json"))) == 2
    monkeypatch.setenv("PLOT_RENDER_CACHE", "0")
    result = runner.run_local_job(*make("disabled", params={"title": "2"}))
    assert result["cache"] == {"enabled": False, "hit": False}
    assert len(calls) == 4


def test_runtime_fingerprint_tracks_package_updates(tmp_path, monkeypatch):
    binary = tmp_path / "Rscript"
    binary.write_text("binary")
    library = tmp_path / "library"
    package = library / "example/DESCRIPTION"
    package.parent.mkdir(parents=True)
    package.write_text("Version: 1")
    monkeypatch.setattr(cache, "_r_environment", lambda *args: {"version": "R test", "libraries": [library]})
    before = cache.runtime_fingerprint([str(binary)])
    package.write_text("Version: 2")
    assert cache.runtime_fingerprint([str(binary)]) != before


def test_new_settings_replace_queued_work_in_same_editor(tmp_path, monkeypatch):
    entered, finish = threading.Event(), threading.Event()
    saved, rendered = [], []
    def render(job, *args):
        rendered.append(job["job_id"])
        if job["job_id"] == "running":
            entered.set()
            finish.wait(5)
    monkeypatch.setattr(render_tasks, "save_job", lambda job: saved.append(dict(job)))
    with ThreadPoolExecutor(1) as executor:
        monkeypatch.setattr(render_tasks, "_EXECUTOR", executor)
        monkeypatch.setattr(render_tasks, "_PENDING", {})
        try:
            for name in ["running", "old", "latest"]:
                render_tasks.submit_render({"job_id": name, "status": "queued", "render_channel": "same"}, [], tmp_path, tmp_path, render)
                if name == "running":
                    assert entered.wait(2)
        finally:
            finish.set()
    assert rendered == ["running", "latest"]
    assert any(job["job_id"] == "old" and job["status"] == "cancelled" for job in saved)


def test_new_shared_plot_helpers_invalidate_cached_renders(render_env, tmp_path):
    make, calls, _ = render_env
    helper = tmp_path / 'R/plots/extension_helpers.R'
    helper.parent.mkdir(parents=True)
    helper.write_text('first implementation')
    runner.run_local_job(*make('before_shared_change'))
    helper.write_text('corrected implementation')
    runner.run_local_job(*make('after_shared_change'))
    assert len(calls) == 2
