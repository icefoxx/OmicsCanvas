"""Bounded background renders and progressive, complete-file preview discovery."""
from __future__ import annotations

import copy
import os
import threading
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any, Callable

from plot_web.server.storage import save_job, utc_now

_EXECUTOR = ThreadPoolExecutor(max_workers=max(1, int(os.environ.get("PLOT_RENDER_WORKERS", "2"))), thread_name_prefix="plot-render")
_PENDING: dict[str, tuple[Any, dict[str, Any]]] = {}
_PENDING_LOCK = threading.RLock()


def submit_render(job: dict[str, Any], command: list[str], plugin_dir: Path, output_dir: Path,
                  renderer: Callable) -> dict[str, Any]:
    # Isolate the response snapshot from the background worker's state mutations.
    background_job = copy.deepcopy(job)

    def execute():
        try:
            renderer(background_job, command, plugin_dir, output_dir)
        except Exception as exc:
            background_job.update(status="failed", finished_at=utc_now(),
                                  error={"error": "Could not complete rendering", "detail": str(exc),
                                         "suggestion": "Check the run logs and try again."})
            save_job(background_job)

    channel = str(job.get("render_channel") or "")
    with _PENDING_LOCK:
        previous = _PENDING.get(channel) if channel else None
        if previous and previous[0].cancel():
            previous[1].update(status="cancelled", finished_at=utc_now(), message="Replaced by newer settings before rendering started.")
            save_job(previous[1])
        future = _EXECUTOR.submit(execute)
        if channel:
            _PENDING[channel] = (future, background_job)

            def forget(done):
                with _PENDING_LOCK:
                    if _PENDING.get(channel, (None,))[0] is done:
                        _PENDING.pop(channel, None)

            future.add_done_callback(forget)
    return {**job, "poll_url": f"/api/jobs/{job['job_id']}"}


def ready_preview(output_dir: Path, kind: str | None = None) -> Path | None:
    """Never expose a PNG or SVG still being written by an R device."""
    for ext in ([kind] if kind in {"png", "svg"} else ["png", "svg"]):
        path = output_dir / f"result.{ext}"
        try:
            if ext == "png":
                with path.open("rb") as handle:
                    if handle.read(8) != b"\x89PNG\r\n\x1a\n":
                        continue
                    handle.seek(-12, 2)
                    if handle.read() != b"\x00\x00\x00\x00IEND\xaeB`\x82":
                        continue
            else:
                if ET.parse(path).getroot().tag.split("}")[-1] != "svg":
                    continue
            return path
        except (OSError, ValueError, ET.ParseError):
            continue
    return None
