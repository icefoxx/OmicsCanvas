from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CJK = re.compile(r"[\u3400-\u4DBF\u4E00-\u9FFF]")

# Application-owned UI metadata. Do not scan user datasets or palette catalogs.
SCAN_GLOBS = [
    "plugins/*/config.yaml",
    "plugins/*/params_schema.json",
    "plugins/*/examples/index.json",
    "plot_web/registry/overrides.yaml",
    "plot_web/registry/vocab.yaml",
    "plot_web/static/*.js",
    "plot_web/static/*.html",
]


def test_user_facing_metadata_has_no_cjk():
    hits: list[str] = []
    for glob in SCAN_GLOBS:
        for path in ROOT.glob(glob):
            text = path.read_text(encoding="utf-8")
            for i, line in enumerate(text.splitlines(), 1):
                if CJK.search(line):
                    hits.append(f"{path.relative_to(ROOT)}:{i}:{line.strip()[:120]}")
    assert hits == [], "CJK in user-facing UI metadata:\n" + "\n".join(hits)
