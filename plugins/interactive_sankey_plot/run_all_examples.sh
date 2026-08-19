#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-$(pwd)}"; P="$ROOT/plugins/interactive_sankey_plot"; mkdir -p "$P/all_examples_gallery"
for spec in basic interactive custom_layout; do
  out="/tmp/interactive_sankey_plot_${spec}_out"; rm -rf "$out"
  nodes=(); if [[ "$spec" == custom_layout ]]; then nodes=(--nodes "$P/example_nodes.csv"); fi
  if ((${#nodes[@]})); then Rscript "$P/plot.R" --input "$P/example_input.csv" --params "$P/example_${spec}_params.json" --output "$out" "${nodes[@]}"; else Rscript "$P/plot.R" --input "$P/example_input.csv" --params "$P/example_${spec}_params.json" --output "$out"; fi
  for f in result.svg result.pdf result.png result.html figure.json run.log nodes_used.csv edges_used.csv; do test -s "$out/$f"; done
  cp "$out/result.png" "$P/all_examples_gallery/${spec}.png"
  bundle="$P/examples/$spec"; mkdir -p "$bundle/input" "$bundle/expected"
  cp "$P/example_${spec}_params.json" "$bundle/params.json"; cp "$P/example_input.csv" "$bundle/input/example_input.csv"; [[ "$spec" == custom_layout ]] && cp "$P/example_nodes.csv" "$bundle/input/example_nodes.csv"
  cp "$out/result.png" "$bundle/expected/result.png"
  if [[ "$spec" == custom_layout ]]; then
    printf '{"id":"%s","label":"%s","plugin_id":"interactive_sankey_plot","plot_type":"sankey","mode":"custom_layout","params":"params.json","inputs":{"input":"input/example_input.csv","nodes":"input/example_nodes.csv"},"expected":"expected/result.png","reproduce":{"command":"Rscript plugins/interactive_sankey_plot/plot.R --input plugins/interactive_sankey_plot/examples/%s/input/example_input.csv --nodes plugins/interactive_sankey_plot/examples/%s/input/example_nodes.csv --params plugins/interactive_sankey_plot/examples/%s/params.json --output /tmp/interactive_sankey_plot_%s_out"}}\n' "$spec" "$spec" "$spec" "$spec" "$spec" > "$bundle/manifest.json"
  else
    printf '{"id":"%s","label":"%s","plugin_id":"interactive_sankey_plot","plot_type":"sankey","mode":"%s","params":"params.json","inputs":{"input":"input/example_input.csv"},"expected":"expected/result.png","reproduce":{"command":"Rscript plugins/interactive_sankey_plot/plot.R --input plugins/interactive_sankey_plot/examples/%s/input/example_input.csv --params plugins/interactive_sankey_plot/examples/%s/params.json --output /tmp/interactive_sankey_plot_%s_out"}}\n' "$spec" "$spec" "$spec" "$spec" "$spec" "$spec" > "$bundle/manifest.json"
  fi
done
printf '["basic","interactive","custom_layout"]\n' > "$P/examples/index.json"
cp "$P/example_input.csv" "$P/all_examples_gallery/"; cp "$P/example_nodes.csv" "$P/all_examples_gallery/"
echo "interactive_sankey_plot examples passed"
