#!/usr/bin/env bash
source "$(dirname "$0")/../example_gallery_helpers.sh"
run_plugin_examples feature_density_plot "${1:-$(pwd)}"
