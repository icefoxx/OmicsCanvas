"""Cached YAML loading for registry metadata files.

Registry/guide YAML is read on nearly every API request; parsing it each time
dominated request latency. Entries are keyed by (mtime, size) so edits on disk
are picked up without a restart, and callers get a deep copy so they may
mutate the result freely.
"""
from __future__ import annotations

import copy
import threading
from pathlib import Path
from typing import Any

import yaml

try:
    _Loader = yaml.CSafeLoader
except AttributeError:  # libyaml not available
    _Loader = yaml.SafeLoader

_CACHE: dict[Path, tuple[tuple[int, int], Any]] = {}
_LOCK = threading.Lock()


def load_yaml_cached(path: Path) -> Any:
    """Parse ``path`` as YAML, or return None when it is missing. Parse errors propagate."""
    path = Path(path)
    try:
        st = path.stat()
    except OSError:
        return None
    if not path.is_file():
        return None
    key = (st.st_mtime_ns, st.st_size)
    with _LOCK:
        hit = _CACHE.get(path)
    if hit is None or hit[0] != key:
        data = yaml.load(path.read_text(encoding="utf-8"), Loader=_Loader)
        with _LOCK:
            _CACHE[path] = (key, data)
    else:
        data = hit[1]
    return copy.deepcopy(data)


def clear_yaml_cache() -> None:
    with _LOCK:
        _CACHE.clear()
