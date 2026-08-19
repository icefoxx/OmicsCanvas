#!/usr/bin/env bash
source "$(dirname "$0")/../example_gallery_helpers.sh"
run_plugin_examples ranked_annotation_panel "${1:-$(pwd)}"
