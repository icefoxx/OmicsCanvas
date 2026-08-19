#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../example_gallery_helpers.sh"
run_plugin_examples interactive_enrichment_lollipop "${1:-$(pwd)}"
