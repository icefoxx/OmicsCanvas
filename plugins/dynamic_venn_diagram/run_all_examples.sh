#!/usr/bin/env bash
source "$(dirname "$0")/../example_gallery_helpers.sh"
run_plugin_examples dynamic_venn_diagram "${1:-$(pwd)}"
