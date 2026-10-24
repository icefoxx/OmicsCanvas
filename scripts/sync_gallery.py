#!/usr/bin/env python3
"""Refresh gallery images from the example baselines (docs/standards/05_examples_and_gallery.md).

For each plugin: copies examples/<id>/expected/result.png to all_examples_gallery/<id>.png and
rebuilds all_examples_gallery/<plugin>_gallery.png when it exists or --montage is given (examples in
index.json order, side by side, 12 px white gaps, top-aligned). The UI shows the per-example images;
the montage is only a fallback preview. Run after `smoke_plugins.py --update-baseline`.

usage: python scripts/sync_gallery.py [plugin_id ...] [--montage]
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
GAP = 12


def example_ids(plugin_dir: Path) -> list[str]:
    idx = json.loads((plugin_dir / "examples" / "index.json").read_text(encoding="utf-8"))
    entries = idx.get("examples", []) if isinstance(idx, dict) else idx
    return [str(e["id"] if isinstance(e, dict) else e) for e in entries]


def sync(plugin_id: str, create_montage: bool = False) -> str:
    d = ROOT / "plugins" / plugin_id
    if not (d / "examples" / "index.json").is_file():
        return f"{plugin_id}: no examples/index.json"
    gallery = d / "all_examples_gallery"
    gallery.mkdir(exist_ok=True)
    ids = example_ids(d)
    copied = 0
    for eid in ids:
        src = d / "examples" / eid / "expected" / "result.png"
        if src.is_file():
            shutil.copyfile(src, gallery / f"{eid}.png")
            copied += 1
    images = [Image.open(gallery / f"{eid}.png").convert("RGB") for eid in ids if (gallery / f"{eid}.png").is_file()]
    montage_path = gallery / f"{plugin_id}_gallery.png"
    if images and (create_montage or montage_path.is_file()):
        width = sum(i.width for i in images) + GAP * (len(images) - 1)
        montage = Image.new("RGB", (width, max(i.height for i in images)), "white")
        x = 0
        for im in images:
            montage.paste(im, (x, 0))
            x += im.width + GAP
        montage.save(montage_path)
    return f"{plugin_id}: {copied} example image(s)" + (", montage rebuilt" if montage_path.is_file() else "")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("plugins", nargs="*")
    ap.add_argument("--montage", action="store_true", help="create the montage if it does not exist yet")
    args = ap.parse_args(argv)
    ids = args.plugins or sorted(p.parent.name for p in (ROOT / "plugins").glob("*/config.yaml"))
    for pid in ids:
        print(sync(pid, args.montage))
    return 0


if __name__ == "__main__":
    sys.exit(main())
