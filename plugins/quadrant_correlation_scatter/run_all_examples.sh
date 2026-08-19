#!/usr/bin/env bash
source "$(dirname "$0")/../example_gallery_helpers.sh"
run_plugin_examples quadrant_correlation_scatter "${1:-$(pwd)}"
