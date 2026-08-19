#!/usr/bin/env bash
source "$(dirname "$0")/../example_gallery_helpers.sh"
run_plugin_examples fgsea_enrichment_plot "${1:-$(pwd)}"
