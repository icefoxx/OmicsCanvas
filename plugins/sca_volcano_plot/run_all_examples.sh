#!/usr/bin/env bash
source "$(dirname "$0")/../example_gallery_helpers.sh"
run_plugin_examples sca_volcano_plot "${1:-$(pwd)}"
cp "$(dirname "$0")/example_regions.csv" "$(dirname "$0")/examples/regions/example_regions.csv"
