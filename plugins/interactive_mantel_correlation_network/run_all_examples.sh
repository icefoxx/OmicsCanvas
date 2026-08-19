#!/usr/bin/env bash
set -uo pipefail
ROOT="${1:-$(pwd)}"
PLUGIN="$ROOT/plugins/interactive_mantel_correlation_network"
source "$ROOT/plugins/example_gallery_helpers.sh"
mkdir -p "$PLUGIN/examples" "$PLUGIN/all_examples_gallery"
# Use the shared gallery renderer for independent PNG generation; the loop
# below augments its bundles with the three auxiliary input tables.
run_plugin_examples interactive_mantel_correlation_network "$ROOT"
for label in basic interactive custom_layout; do
  case "$label" in
    basic) params="$PLUGIN/example_basic_params.json";;
    interactive) params="$PLUGIN/example_interactive_params.json";;
    custom_layout) params="$PLUGIN/example_custom_layout_params.json";;
  esac
  out="/tmp/interactive_mantel_correlation_network_${label}_out"
  rm -rf "$out"
  Rscript "$PLUGIN/plot.R" --input "$PLUGIN/example_corr.csv" --params "$params" --output "$out" --mantel "$PLUGIN/example_mantel.csv" --envpoints "$PLUGIN/example_env_points.csv" --specpoints "$PLUGIN/example_spec_points.csv" || exit 1
  test -s "$out/result.png" || exit 1
  bundle="$PLUGIN/examples/$label"; rm -rf "$bundle"; mkdir -p "$bundle/input" "$bundle/expected"
  cp "$params" "$bundle/params.json"; cp "$out/result.png" "$bundle/expected/result.png"
  cp "$PLUGIN/example_corr.csv" "$bundle/input/"; cp "$PLUGIN/example_mantel.csv" "$bundle/input/"; cp "$PLUGIN/example_env_points.csv" "$bundle/input/"; cp "$PLUGIN/example_spec_points.csv" "$bundle/input/"
  LABEL="$label" PLUGIN_DIR="$PLUGIN" BUNDLE="$bundle" python3 - <<'PY'
import json, os
label, plugin, bundle = os.environ['LABEL'], os.environ['PLUGIN_DIR'], os.environ['BUNDLE']
inputs = {k: 'input/' + v for k, v in [('input','example_corr.csv'),('mantel','example_mantel.csv'),('envpoints','example_env_points.csv'),('specpoints','example_spec_points.csv')]}
manifest = {'id': label, 'label': label, 'plugin_id': 'interactive_mantel_correlation_network', 'plot_type': 'precomputed', 'params': 'params.json', 'inputs': inputs, 'expected': 'expected/result.png', 'reproduce': {'command': 'Rscript plugins/interactive_mantel_correlation_network/examples/%s/../plot.R --input plugins/interactive_mantel_correlation_network/examples/%s/input/example_corr.csv --params plugins/interactive_mantel_correlation_network/examples/%s/params.json --output /tmp/mantel_%s --mantel plugins/interactive_mantel_correlation_network/examples/%s/input/example_mantel.csv --envpoints plugins/interactive_mantel_correlation_network/examples/%s/input/example_env_points.csv --specpoints plugins/interactive_mantel_correlation_network/examples/%s/input/example_spec_points.csv' % (label,label,label,label,label,label,label)}}
json.dump(manifest, open(os.path.join(bundle,'manifest.json'),'w'), indent=2)
PY
  cp "$out/result.png" "$PLUGIN/all_examples_gallery/$label.png"
done
python3 - <<'PY'
import json, os
root='plugins/interactive_mantel_correlation_network'; labels=['basic','interactive','custom_layout']
items=[]
for label in labels:
    m=json.load(open(os.path.join(root,'examples',label,'manifest.json')))
    m['bundle']='../examples/'+label; m['gallery_png']=label+'.png'; m['params_filename']='example_'+label+'_params.json'; items.append(m)
json.dump(items,open(os.path.join(root,'all_examples_gallery','example_gallery.json'),'w'),indent=2)
json.dump({'plugin_id':'interactive_mantel_correlation_network','examples':items},open(os.path.join(root,'examples','index.json'),'w'),indent=2)
PY
echo "interactive_mantel_correlation_network examples complete"
