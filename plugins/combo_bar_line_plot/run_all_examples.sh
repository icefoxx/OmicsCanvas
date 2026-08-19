#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
plugin="combo_bar_line_plot"
dir="plugins/$plugin"
gallery="$dir/all_examples_gallery"
bundles="$dir/examples"
mkdir -p "$gallery" "$bundles"
failures="$gallery/example_failures.txt"
: > "$failures"
records="/tmp/${plugin}_example_records.jsonl"
: > "$records"
pngs=()
while IFS= read -r f; do
  stem="${f##*/}"; stem="${stem%.json}"
  label="${stem#example_}"; label="${label%_params}"
  out="/tmp/${plugin}_${label}_out"; rm -rf "$out"
  if [[ "$stem" == *long* ]]; then
    input="$dir/example_long.csv"
  else
    input="$dir/example_input.csv"
  fi
  echo ">>> $plugin: $label"
  if Rscript "$dir/plot.R" --input "$input" --params "$f" --output "$out" && [[ -s "$out/result.png" ]]; then
    bundle="$bundles/$label"
    rm -rf "$bundle"; mkdir -p "$bundle/input" "$bundle/expected"
    cp "$f" "$bundle/params.json"
    cp "$out/result.png" "$bundle/expected/result.png"
    cp "$input" "$bundle/input/$(basename "$input")"
    cat > "$bundle/manifest.json" <<EOF
{
  "id": "$label",
  "label": "$label",
  "plugin_id": "$plugin",
  "plot_type": "combo",
  "mode": "dual_axis",
  "params": "params.json",
  "inputs": {"input": "input/$(basename "$input")"},
  "expected": "expected/result.png"
}
EOF
    printf '%s\n' "$bundle" >> "$records"
    cp "$out/result.png" "$gallery/$label.png"
    pngs+=("$gallery/$label.png")
  else
    printf '%s\tfailed\n' "$stem" >> "$failures"
  fi
done < <(find "$dir" -maxdepth 1 -type f -name 'example*_params.json' -print | sort)

python3 - <<PY
import json, os
plugin, dir_, gallery, records = "$plugin", "$dir", "$gallery", "$records"
items = []
for line in open(records):
    b = line.strip()
    if not b: continue
    m = json.load(open(os.path.join(b, "manifest.json")))
    items.append(m)
items.sort(key=lambda x: x["id"])
json.dump(items, open(os.path.join(gallery, "example_gallery.json"), "w"), indent=2)
json.dump({"examples": [{"id": m["id"], "label": m["label"]} for m in items]},
          open(os.path.join(dir_, "examples", "index.json"), "w"), indent=2)
print("examples:", len(items))
PY
echo "Done $plugin examples"
