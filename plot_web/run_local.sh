#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -x plot_web/.venv/bin/uvicorn ]; then
  python3 -m venv plot_web/.venv
  plot_web/.venv/bin/pip install -r plot_web/requirements.txt
fi

# Load local secrets (plot_web/.env is gitignored)
if [ -f plot_web/.env ]; then
  set -a
  # shellcheck disable=SC1091
  source plot_web/.env
  set +a
fi

export PLOT_DISPATCH_MODE="${PLOT_DISPATCH_MODE:-local}"
exec plot_web/.venv/bin/uvicorn plot_web.app:app --host "${HOST:-127.0.0.1}" --port "${PORT:-8000}"
