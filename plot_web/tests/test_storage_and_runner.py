from __future__ import annotations

import json
import os
import threading
import time

import pytest

from plot_web.server import settings, storage
from plot_web.server.runner import build_command, input_flags
from plot_web.yaml_cache import clear_yaml_cache, load_yaml_cached


@pytest.fixture()
def tmp_storage(tmp_path, monkeypatch):
    """Point every storage path at a throwaway directory."""
    root = tmp_path / "storage"
    paths = {
        "STORAGE_DIR": root,
        "JOBS_DIR": root / "jobs",
        "UPLOADS_DIR": root / "uploads",
        "RESULTS_DIR": root / "results",
        "PREVIEWS_DIR": root / "previews",
        "DATASETS_DIR": root / "datasets",
        "STATE_DIR": root / "state",
        "REPORTS_DIR": root / "reports",
        "CURRENT_STATE_PATH": root / "state" / "current_state.json",
        "FIGURE_INDEX_PATH": root / "figure_index.json",
    }
    for name, value in paths.items():
        monkeypatch.setattr(settings, name, value)
        if hasattr(storage, name):
            monkeypatch.setattr(storage, name, value)
    storage.ensure_storage()
    return root


def _make_job(job_id: str, figure_id: str, age_days: float = 0.0) -> dict:
    job = {"job_id": job_id, "figure_id": figure_id, "plugin_id": "dot_plot", "status": "completed",
           "created_at": f"2026-01-01T00:00:{len(job_id) % 60:02d}+00:00"}
    storage.save_job(job)
    (settings.RESULTS_DIR / job_id).mkdir(parents=True, exist_ok=True)
    (settings.RESULTS_DIR / job_id / "result.png").write_bytes(b"x" * 10)
    if age_days:
        ts = time.time() - age_days * 86400
        os.utime(settings.JOBS_DIR / job_id / "job.json", (ts, ts))
    return job


def test_input_flags_prefer_declared_flag_then_legacy_then_id():
    config = {"inputs": [
        {"id": "input"},
        {"id": "expression", "flag": "--expression"},
        {"id": "scores"},
        {"id": "annot"},
    ]}
    flags = input_flags(config)
    assert flags["expression"] == "--expression"  # explicit beats legacy --expr
    assert flags["scores"] == "--scores"  # undeclared in legacy map -> --<id>
    assert flags["annot"] == "--annot"  # legacy alias kept
    assert "input" not in flags  # main input is always passed as --input separately


def test_build_command_uses_first_required_declared_input_as_main(tmp_path):
    config = {"inputs": [{"id": "signal", "required": True}, {"id": "features"}]}
    files = {"features": tmp_path / "f.csv", "signal": tmp_path / "s.csv"}
    cmd = build_command("interactive_genomic_signal_track_plot", config, files, tmp_path / "p.json", tmp_path / "out")
    assert cmd[cmd.index("--input") + 1] == str(tmp_path / "s.csv")
    assert cmd[cmd.index("--features") + 1] == str(tmp_path / "f.csv")


def test_yaml_cache_returns_copies_and_sees_edits(tmp_path):
    path = tmp_path / "x.yaml"
    path.write_text("a: [1, 2]\n", encoding="utf-8")
    clear_yaml_cache()
    first = load_yaml_cached(path)
    first["a"].append(3)
    assert load_yaml_cached(path) == {"a": [1, 2]}
    path.write_text("a: [9]\nb: 1\n", encoding="utf-8")
    assert load_yaml_cached(path) == {"a": [9], "b": 1}
    assert load_yaml_cached(tmp_path / "missing.yaml") is None


def test_figure_index_lookup_and_rebuild(tmp_storage):
    _make_job("job_a", "fig_a")
    assert storage.figure_to_job("fig_a")["job_id"] == "job_a"
    settings.FIGURE_INDEX_PATH.unlink()  # stale/missing index falls back to a rebuild
    assert storage.figure_to_job("fig_a")["job_id"] == "job_a"
    with pytest.raises(Exception):
        storage.figure_to_job("fig_missing")


def test_record_job_is_safe_under_concurrency(tmp_storage):
    def worker(i: int) -> None:
        storage.record_job_in_state({"job_id": f"job_{i}", "plugin_id": "p", "status": "completed",
                                     "created_at": f"2026-01-01T00:00:{i:02d}"})

    threads = [threading.Thread(target=worker, args=(i,)) for i in range(20)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    state = json.loads(settings.CURRENT_STATE_PATH.read_text(encoding="utf-8"))
    runs = {n["id"] for n in state["data_map"]["nodes"] if n["type"] == "plot_run"}
    assert runs == {f"job_{i}" for i in range(20)}


def test_prune_state_caps_runs_and_drops_their_edges(monkeypatch):
    monkeypatch.setattr(storage, "MAX_STATE_RUNS", 2)
    state = storage.default_state()
    for i in range(4):
        storage._record_job(state, {"job_id": f"job_{i}", "plugin_id": "p", "created_at": f"2026-01-0{i + 1}"}, None)
    storage.prune_state(state)
    ids = {n["id"] for n in state["data_map"]["nodes"]}
    assert ids == {"job_2", "job_3", "result_job_2", "result_job_3"}
    assert all(e["source"] in ids and e["target"] in ids for e in state["data_map"]["edges"])


def test_cleanup_storage_by_count_and_age(tmp_storage):
    _make_job("job_old", "fig_old", age_days=40)
    _make_job("job_mid", "fig_mid", age_days=2)
    _make_job("job_new", "fig_new")

    dry = storage.cleanup_storage(retention_days=30, max_jobs=0, dry_run=True)
    assert dry["removed_jobs"] == 1 and (settings.JOBS_DIR / "job_old").exists()

    result = storage.cleanup_storage(retention_days=30, max_jobs=1)
    assert result["removed_jobs"] == 2
    assert not (settings.RESULTS_DIR / "job_old").exists()
    assert not (settings.JOBS_DIR / "job_mid").exists()
    assert (settings.JOBS_DIR / "job_new").exists()
    assert storage.figure_to_job("fig_new")["job_id"] == "job_new"


def test_atomic_write_leaves_no_temp_files(tmp_path):
    target = tmp_path / "a.json"
    storage.atomic_write_text(target, "{}")
    storage.atomic_write_text(target, '{"x": 1}')
    assert json.loads(target.read_text()) == {"x": 1}
    assert [p.name for p in tmp_path.iterdir()] == ["a.json"]
