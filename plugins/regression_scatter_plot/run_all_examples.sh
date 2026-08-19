#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
plugin="regression_scatter_plot"
dir="plugins/$plugin"
gallery="$dir/all_examples_gallery"
bundles="$dir/examples"
mkdir -p "$gallery" "$bundles"
: > "$gallery/example_failures.txt"
records="/tmp/${plugin}_example_records.jsonl"
: > "$records"
while IFS= read -r f; do
  stem="${f##*/}"; stem="${stem%.json}"
  label="${stem#example_}"; label="${label%_params}"
  out="/tmp/${plugin}_${label}_out"; rm -rf "$out"
  input="$dir/example_input.csv"
  echo ">>> $plugin: $label"
  if Rscript "$dir/plot.R" --input "$input" --params "$f" --output "$out" && [[ -s "$out/result.png" ]]; then
    bundle="$bundles/$label"
    rm -rf "$bundle"; mkdir -p "$bundle/input" "$bundle/expected"
    cp "$f" "$bundle/params.json"
    cp "$out/result.png" "$bundle/expected/result.png"
    cp "$input" "$bundle/input/$(basename "$input")"
    cat > "$bundle/manifest.json" <<EOF
{"id":"$label","label":"$label","plugin_id":"$plugin","plot_type":"regression_scatter","params":"params.json","inputs":{"input":"input/$(basename "$input")"},"expected":"expected/result.png"}
EOF
    printf '%s\n' "$bundle" >> "$records"
    cp "$out/result.png" "$gallery/$label.png"
  else
    echo -e "$stem\tfailed" >> "$gallery/example_failures.txt"
  fi
done < <(find "$dir" -maxdepth 1 -type f -name 'example*_params.json' -print | sort)
python3 - <<PY
import json,os
items=[]
for line in open("$records"):
    b=line.strip()
    if b: items.append(json.load(open(os.path.join(b,"manifest.json"))))
items.sort(key=lambda x:x["id"])
os.makedirs("$gallery",exist_ok=True)
json.dump(items,open("$gallery/example_gallery.json","w"),indent=2)
json.dump({"examples":[{"id":m["id"],"label":m["label"]} for m in items]},open("$dir/examples/index.json","w"),indent=2)
print("examples:",len(items))
PY
echo "Done $plugin"
