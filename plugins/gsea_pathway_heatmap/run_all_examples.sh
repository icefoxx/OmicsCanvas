#!/usr/bin/env bash
source "$(dirname "$0")/../example_gallery_helpers.sh"
run_plugin_examples gsea_pathway_heatmap "${1:-$(pwd)}"
