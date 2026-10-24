"""Pixel comparison of rendered figures (reproduction checks, image regression)."""
from __future__ import annotations

from pathlib import Path

# A pixel counts as changed when any RGB channel moves by more than this.
PIXEL_THRESHOLD = 40
DEFAULT_TOLERANCE = 0.002  # max fraction of changed pixels


def image_diff(rendered: Path, expected: Path) -> tuple[float, str]:
    """Return (fraction of changed pixels, note). 1.0 means incomparable."""
    import numpy as np
    from PIL import Image

    def load(path: Path):
        img = Image.open(path).convert("RGBA")
        background = Image.new("RGBA", img.size, (255, 255, 255, 255))
        return np.asarray(Image.alpha_composite(background, img).convert("RGB"), dtype=np.int16)

    a, b = load(rendered), load(expected)
    if a.shape != b.shape:
        return 1.0, f"size {a.shape[1]}x{a.shape[0]} != baseline {b.shape[1]}x{b.shape[0]}"
    changed = float((np.abs(a - b).max(axis=2) > PIXEL_THRESHOLD).mean())
    return changed, f"{changed * 100:.3f}% pixels changed"
