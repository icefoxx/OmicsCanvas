#!/usr/bin/env python3
"""Create a new plot plugin from templates/plugin (docs/standards/README.md).

usage:
  python scripts/new_plugin.py my_new_plot --name "My New Plot" \
      --description "One sentence: what the figure shows." \
      --category Scatter --subcategory General

The copy is a working grouped scatter; replace its drawing code, keep the contract.
"""
from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from check_plugin_standards import STUDIO_CATEGORIES  # noqa: E402

TEMPLATE = ROOT / "templates" / "plugin"


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("plugin_id")
    ap.add_argument("--name", required=True)
    ap.add_argument("--description", required=True)
    ap.add_argument("--category", required=True, help=f"one of: {', '.join(sorted(STUDIO_CATEGORIES))}")
    ap.add_argument("--subcategory", default="General")
    args = ap.parse_args(argv)

    pid = args.plugin_id
    if not re.fullmatch(r"[a-z][a-z0-9]*(_[a-z0-9]+)*", pid):
        ap.error("plugin_id must be snake_case: lowercase letters, digits and single underscores")
    if args.category not in STUDIO_CATEGORIES:
        ap.error(f"--category must be one of {sorted(STUDIO_CATEGORIES)} "
                 "(a new category needs the step in docs/standards/04_classification.md)")
    dest = ROOT / "plugins" / pid
    if dest.exists():
        ap.error(f"{dest.relative_to(ROOT)} already exists")

    shutil.copytree(TEMPLATE, dest)
    subs = {"__PLUGIN_ID__": pid, "__PLUGIN_NAME__": args.name, "__DESCRIPTION__": args.description,
            "__CATEGORY__": args.category, "__SUBCATEGORY__": args.subcategory}
    for f in dest.rglob("*"):
        if f.is_file() and f.suffix in {".R", ".yaml", ".json", ".md"}:
            text = f.read_text(encoding="utf-8")
            for k, v in subs.items():
                text = text.replace(k, v)
            f.write_text(text, encoding="utf-8")

    print(f"Created plugins/{pid}/ from templates/plugin. Next (docs/standards/README.md):")
    print(f"""  1. Implement plot.R; keep params_schema.json in sync (every parameter typed and effective).
  2. Classify: plot_web/registry/overrides.yaml (family), CHART_CATEGORY_TAXONOMY in
     plot_web/plot_registry.py (chart type), vnext/migrate/rules.yaml (vNext family).
  3. python -m plot_web.plot_registry build && python -m vnext.cli migrate
  4. python scripts/smoke_plugins.py {pid} --update-baseline   # writes examples/*/expected/result.png
  5. python scripts/check_plugin_standards.py {pid}
     python scripts/param_sensitivity.py {pid}
     python scripts/smoke_plugins.py {pid} --compare
     pytest -q plot_web/tests vnext/tests""")
    return 0


if __name__ == "__main__":
    sys.exit(main())
