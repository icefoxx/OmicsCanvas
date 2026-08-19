#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
# shellcheck source=/dev/null
source "$ROOT/plugins/example_gallery_helpers.sh"

# Prefer long-format input for long examples
run_plugin_examples_wrapped() {
  local plugin="stacked_bar_plot" root="$ROOT"
  local dir="plugins/$plugin"
  local gallery="$dir/all_examples_gallery" failures="$dir/all_examples_gallery/example_failures.txt"
  local bundles="$dir/examples"
  mkdir -p "$gallery" "$bundles"; : > "$failures"
  local -a files=() pngs=() labels=()
  while IFS= read -r f; do files+=("$f"); done < <(find "$dir" -maxdepth 1 -type f -name 'example*_params.json' -print | sort)
  local f stem label n out input used_labels=" " records="/tmp/${plugin}_example_records.jsonl"
  : > "$records"
  for f in "${files[@]}"; do
    stem="${f##*/}"; stem="${stem%.json}"; label="${stem#example_}"; label="${label%_params}"
    n=1; while [[ "$used_labels" == *" $label "* ]]; do label="${stem#example_}"; label="${label%_params}_${n}"; n=$((n+1)); done
    used_labels+="$label "
    out="/tmp/${plugin}_${label}_out"; rm -rf "$out"
    if [[ "$stem" == *long* ]]; then
      input="$dir/example_long.csv"
    elif [[ "$stem" == *normal* ]]; then
      input="$dir/example_normal_input.csv"
    else
      input="$dir/example_input.csv"
    fi
    echo ">>> $plugin: $label"
    if Rscript "$dir/plot.R" --input "$input" --params "$f" --output "$out" && [[ -s "$out/result.png" ]]; then
      local bundle="$bundles/$label"
      rm -rf "$bundle"; mkdir -p "$bundle/input" "$bundle/expected"
      cp "$f" "$bundle/params.json"
      cp "$out/result.png" "$bundle/expected/result.png"
      cp "$input" "$bundle/input/$(basename "$input")"
      PLUGIN="$plugin" LABEL="$label" PARAMS="$f" BUNDLE="$bundle" INPUT="$input" CMD="Rscript plugins/$plugin/plot.R --input plugins/$plugin/examples/$label/input/$(basename "$input") --params plugins/$plugin/examples/$label/params.json --output /tmp/out" python3 - <<'PY'
import json, os
plugin, label, params, bundle = os.environ['PLUGIN'], os.environ['LABEL'], os.environ['PARAMS'], os.environ['BUNDLE']
input_name = os.path.basename(os.environ['INPUT'])
x = json.load(open(params))
manifest = {
  "id": label,
  "label": label,
  "plugin_id": plugin,
  "plot_type": x.get("position", "stack"),
  "mode": x.get("orientation", "horizontal"),
  "params": "params.json",
  "inputs": {"input": "input/" + input_name},
  "expected": "expected/result.png",
  "reproduce": {"command": os.environ['CMD']},
}
json.dump(manifest, open(os.path.join(bundle, 'manifest.json'), 'w'), indent=2)
print(json.dumps(manifest))
PY
      printf '%s\n' "$bundle" >> "$records"
      cp "$out/result.png" "$gallery/$label.png"
      pngs+=("$gallery/$label.png")
      labels+=("$label")
    else
      printf '%s\t%s\n' "$stem" "generation failed (see $out)" >> "$failures"
    fi
  done
  if ((${#pngs[@]})); then
    GALLERY_DIR="$gallery" PNG_LIST="${pngs[*]}" PLUGIN="$plugin" Rscript -e '
f <- strsplit(Sys.getenv("PNG_LIST"), " ", fixed = TRUE)[[1]]
f <- f[nzchar(f) & file.exists(f)]
if (length(f)) {
  a <- lapply(f, png::readPNG)
  h <- max(vapply(a, function(x) dim(x)[1], integer(1)))
  w <- sum(vapply(a, function(x) dim(x)[2], integer(1))) + 12 * (length(a) - 1)
  z <- array(1, c(h, w, 3))
  x <- 1
  for (i in a) {
    ih <- dim(i)[1]; iw <- dim(i)[2]
    z[seq_len(ih), x:(x + iw - 1), ] <- i[, , 1:3]
    x <- x + iw + 12
  }
  png::writePNG(z, file.path(Sys.getenv("GALLERY_DIR"), paste0(Sys.getenv("PLUGIN"), "_gallery.png")))
}' || true
  fi
  PLUGIN="$plugin" DIR="$dir" GALLERY="$gallery" RECORDS="$records" python3 - <<'PY'
import json, os
plugin, gallery, records = os.environ['PLUGIN'], os.environ['GALLERY'], os.environ['RECORDS']
items = []
for line in open(records):
    b = line.strip()
    if not b:
        continue
    m = json.load(open(os.path.join(b, 'manifest.json')))
    items.append(m)
items.sort(key=lambda x: x['id'])
for m in items:
    m['bundle'] = os.path.relpath(os.path.join(os.environ['DIR'], 'examples', m['id']), os.environ['GALLERY'])
    m['params'] = m['bundle'] + '/params.json'
    m['expected'] = m['bundle'] + '/expected/result.png'
    m['gallery_png'] = m['id'] + '.png'
    m['params_filename'] = 'example_' + m['id'] + '_params.json'
json.dump(items, open(os.path.join(gallery, 'example_gallery.json'), 'w'), indent=2)
index = {"examples": [{"id": m["id"], "label": m["label"]} for m in items]}
json.dump(index, open(os.path.join(os.environ['DIR'], 'examples', 'index.json'), 'w'), indent=2)
print('examples:', len(items))
PY
}

run_plugin_examples_wrapped
echo "Done stacked_bar_plot examples"
