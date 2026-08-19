#!/usr/bin/env bash
set -uo pipefail
ROOT="${1:-$(pwd)}"
source "$ROOT/plugins/example_gallery_helpers.sh"
run_plugin_examples interactive_dual_triangle_heatmap_plot "$ROOT"
