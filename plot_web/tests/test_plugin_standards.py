"""Every plugin conforms to docs/standards (legacy violations are baselined)."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

import check_plugin_standards  # noqa: E402


def test_no_new_standards_violations(capsys):
    code = check_plugin_standards.main([])
    out = capsys.readouterr().out
    assert code == 0, "New standards violations (see docs/standards):\n" + "\n".join(
        line for line in out.splitlines() if line.startswith("NEW")
    )


def test_template_uses_only_known_placeholders():
    """scripts/new_plugin.py replaces exactly these tokens; a new token must be added there."""
    known = {"__PLUGIN_ID__", "__PLUGIN_NAME__", "__DESCRIPTION__", "__CATEGORY__", "__SUBCATEGORY__"}
    template = ROOT / "templates" / "plugin"
    found = set()
    for f in template.rglob("*"):
        if f.suffix in {".R", ".yaml", ".json", ".md"}:
            found |= set(re.findall(r"__[A-Z]+(?:_[A-Z]+)*__", f.read_text(encoding="utf-8")))
    assert "__PLUGIN_ID__" in found
    assert found <= known, found - known
