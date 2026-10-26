"""Content-addressed, bounded cache of completed render artifacts.

Provenance/validation are regenerated for each job, even on a hit. Entries are
published atomically and contain checksums; corrupt/missing entries are misses.
"""
from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import threading
from contextlib import contextmanager
from functools import lru_cache
from pathlib import Path
from typing import Any

from plot_web.server import settings
from plot_web.server.storage import atomic_write_text

CACHE_VERSION = 1
SKIP_OUTPUTS = {"plotspec.json", "validation.json", "subprocess.stdout.log", "subprocess.stderr.log"}
_FILE_DIGESTS: dict[str, tuple[tuple[int, int, int], str]] = {}
_DIGEST_LOCK = threading.Lock()
_KEY_LOCKS: dict[str, tuple[threading.Lock, int]] = {}
_KEY_GUARD = threading.Lock()


def file_digest(path: Path) -> str:
    stat = path.stat()
    stamp = (stat.st_mtime_ns, stat.st_ctime_ns, stat.st_size)
    key = str(path.resolve())
    with _DIGEST_LOCK:
        previous = _FILE_DIGESTS.get(key)
        if previous and previous[0] == stamp:
            return previous[1]
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    value = digest.hexdigest()
    with _DIGEST_LOCK:
        if len(_FILE_DIGESTS) > 8192:
            _FILE_DIGESTS.clear()
        _FILE_DIGESTS[key] = (stamp, value)
    return value


def _tree(root: Path, exclude: set[str] | None = None) -> list[tuple[str, str]]:
    if not root.is_dir():
        return []
    exclude = (exclude or set()) | {"__pycache__", ".git"}
    return [(str(path.relative_to(root)), file_digest(path)) for path in sorted(root.rglob("*"))
            if path.is_file() and not any(part in exclude for part in path.relative_to(root).parts)
            and path.suffix not in {".pyc", ".pyo"}]


@lru_cache(maxsize=4)
def _r_environment(executable: str, binary_stamp: str, profile_stamp: str, environment_stamp: str) -> dict[str, Any]:
    # One small probe per R binary/version per server process, never per render.
    from plot_web.server.runner import plugin_env

    code = 'cat("OMICSCANVAS_CACHE_R\\n"); cat(R.version.string, "\\n"); cat(.libPaths(), sep="\\n")'
    result = subprocess.run([executable, "-e", code], capture_output=True, text=True, timeout=30, env=plugin_env())
    if result.returncode:
        raise RuntimeError("Cannot identify the R environment for render caching")
    lines = result.stdout.split("OMICSCANVAS_CACHE_R\n", 1)[-1].strip().splitlines()
    if not lines:
        raise RuntimeError("Empty R environment fingerprint")
    return {"version": lines[0], "libraries": [Path(line.strip()) for line in lines[1:] if line.strip()]}


def runtime_fingerprint(command: list[str]) -> dict[str, Any]:
    executable = Path(shutil.which(command[0]) or command[0]).resolve()
    binary = file_digest(executable)
    environment = {key: os.environ.get(key, "") for key in (
        "R_LIBS", "R_LIBS_USER", "R_LIBS_SITE", "R_PROFILE_USER", "OMICSCANVAS_USER_RPROFILE",
        "LANG", "LC_ALL", "LC_CTYPE", "TZ", "FONTCONFIG_FILE", "FONTCONFIG_PATH",
    )}
    signature: dict[str, Any] = {"executable": str(executable), "binary": binary, "environment": environment}
    if Path(command[0]).name.lower().startswith("rscript"):
        profile = Path(os.environ.get("OMICSCANVAS_USER_RPROFILE") or os.environ.get("R_PROFILE_USER") or Path.home() / ".Rprofile")
        profile_stamp = file_digest(profile) if profile.is_file() else ""
        info = _r_environment(str(executable), binary, profile_stamp, json.dumps(environment, sort_keys=True))
        signature["version"] = info["version"]
        signature["packages"] = [(str(path), file_digest(path))
                                 for root in info["libraries"] for path in sorted(root.glob("*/DESCRIPTION"))]
        signature["user_profile"] = profile_stamp
    return signature


def cache_key(job: dict[str, Any], command: list[str], plugin_dir: Path, params: dict[str, Any]) -> str | None:
    if os.environ.get("PLOT_RENDER_CACHE", "1").lower() in {"0", "false", "off"}:
        return None
    if Path(command[0]).name.lower() != "rscript":
        # Do not cache other runtimes until their package versions are fingerprinted.
        return None
    try:
        inputs = {key: Path(value) for key, value in job.get("uploaded_files", {}).items()}
        replacements = {str(path): f"<input:{field}:{path.suffix.lower()}>" for field, path in inputs.items()}
        replacements.update({str(job.get("params_path")): "<params>", str(job.get("output_dir")): "<output>"})
        root = settings.ROOT_DIR
        # Some legacy parameters reference auxiliary files outside uploaded_files.
        def referenced_files(value):
            if isinstance(value, dict):
                return [item for child in value.values() for item in referenced_files(child)]
            if isinstance(value, list):
                return [item for child in value for item in referenced_files(child)]
            if isinstance(value, str) and value:
                path = Path(value).expanduser()
                path = path if path.is_absolute() else root / path
                if path.is_file():
                    return [(str(path), file_digest(path))]
            return []
        signature = {
            "version": CACHE_VERSION,
            "plugin": job["plugin_id"], "params": params, "seed": job.get("seed", 42),
            "parameter_files": referenced_files(params),
            "command": [replacements.get(item, item) for item in command],
            "inputs": {field: {"sha256": file_digest(path), "suffix": path.suffix.lower()} for field, path in inputs.items()},
            "plugin_files": _tree(plugin_dir, {"examples", "all_examples_gallery", "vnext"}),
            "shared_r": {name: _tree(root / "R" / name) for name in ("sca", "runtime", "plots")},
            "server": _tree(root / "plot_web" / "server"),
            "vnext": _tree(root / "vnext", {"tests"}),
            "runtime": runtime_fingerprint(command),
        }
        return hashlib.sha256(json.dumps(signature, sort_keys=True, separators=(",", ":"), default=str).encode()).hexdigest()
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError):
        # Caching is an optimization, never a reason to fail a valid render.
        return None


@contextmanager
def render_lock(key: str | None):
    if key is None:
        yield
        return
    with _KEY_GUARD:
        lock, count = _KEY_LOCKS.get(key, (threading.Lock(), 0))
        _KEY_LOCKS[key] = (lock, count + 1)
    try:
        with lock:
            yield
    finally:
        with _KEY_GUARD:
            _, count = _KEY_LOCKS[key]
            if count == 1:
                del _KEY_LOCKS[key]
            else:
                _KEY_LOCKS[key] = (lock, count - 1)


def cache_dir() -> Path:
    return settings.STORAGE_DIR / "render_cache"


def restore(key: str | None, output_dir: Path) -> str | None:
    if key is None:
        return None
    entry = cache_dir() / key
    try:
        metadata = json.loads((entry / "manifest.json").read_text())
        files = metadata["files"]
        if not {"result.png", "result.svg", "result.pdf", "figure.json"}.issubset(files):
            return None
        with tempfile.TemporaryDirectory(prefix=".cache_restore_", dir=output_dir.parent) as temp:
            staging = Path(temp)
            for name, checksum in files.items():
                relative = Path(name)
                if relative.is_absolute() or ".." in relative.parts:
                    return None
                source = entry / "files" / relative
                if file_digest(source) != checksum:
                    return None
                target = staging / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)
            shutil.copytree(staging, output_dir, dirs_exist_ok=True)
        os.utime(entry / "manifest.json", None)
        return str(metadata["source_job_id"])
    except (OSError, ValueError, KeyError, TypeError):
        return None


def store(key: str | None, output_dir: Path, job_id: str) -> None:
    if key is None or not all((output_dir / name).is_file() for name in ("result.png", "result.svg", "result.pdf", "figure.json")):
        return
    root = cache_dir()
    temp = None
    try:
        root.mkdir(parents=True, exist_ok=True)
        temp = Path(tempfile.mkdtemp(prefix=".publish_", dir=root))
        files = {}
        for source in sorted(output_dir.rglob("*")):
            if not source.is_file() or source.name in SKIP_OUTPUTS or source.is_symlink():
                continue
            relative = source.relative_to(output_dir)
            target = temp / "files" / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
            files[relative.as_posix()] = file_digest(target)
        atomic_write_text(temp / "manifest.json", json.dumps({"source_job_id": job_id, "files": files}))
        destination = root / key
        if destination.exists():
            # A corrupt entry may be replaced after a successful fresh render.
            shutil.rmtree(destination)
        temp.rename(destination)
        limit = max(1, int(os.environ.get("PLOT_RENDER_CACHE_MAX_ENTRIES", "128")))
        entries = sorted((path for path in root.iterdir() if not path.name.startswith(".") and (path / "manifest.json").is_file()),
                         key=lambda path: (path / "manifest.json").stat().st_mtime, reverse=True)
        for old in entries[limit:]:
            if old != destination:
                shutil.rmtree(old, ignore_errors=True)
    except (OSError, ValueError):
        pass
    finally:
        if temp is not None and temp.exists():
            shutil.rmtree(temp, ignore_errors=True)
