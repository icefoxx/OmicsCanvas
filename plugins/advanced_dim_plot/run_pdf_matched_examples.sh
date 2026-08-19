#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT"
INPUT="plugins/advanced_dim_plot/example_pdf_like_input.csv"

run_one() {
  local name="$1"
  local params="$2"
  Rscript plugins/advanced_dim_plot/plot.R \
    --input "$INPUT" \
    --params "plugins/advanced_dim_plot/${params}" \
    --output "/tmp/advanced_dim_pdf_${name}_out"
  local bundle="plugins/advanced_dim_plot/examples/${name}"
  rm -rf "$bundle"; mkdir -p "$bundle/input" "$bundle/expected"
  cp "plugins/advanced_dim_plot/${params}" "$bundle/params.json"
  cp "$INPUT" "$bundle/input/$(basename "$INPUT")"
  BUNDLE="$bundle" NAME="$name" PARAMS="$params" python3 - <<'PY'
import json, os
b=os.environ['BUNDLE']; n=os.environ['NAME']
m={'id':n,'label':n,'plugin_id':'advanced_dim_plot','plot_type':n,'mode':'group',
   'params':'params.json','inputs':{'input':'input/example_pdf_like_input.csv'},
   'expected':'expected/result.png','reproduce':{'command':
   'Rscript plugins/advanced_dim_plot/plot.R --input plugins/advanced_dim_plot/examples/'+n+'/input/example_pdf_like_input.csv --params plugins/advanced_dim_plot/examples/'+n+'/params.json --output /tmp/advanced_dim_pdf_'+n+'_out'}}
import shutil
shutil.copy2('/tmp/advanced_dim_pdf_'+n+'_out/result.png',b+'/expected/result.png')
json.dump(m,open(b+'/manifest.json','w'),indent=2)
PY
}

run_one basic_umap example_pdf_basic_umap_params.json
run_one ellipse_mark example_pdf_ellipse_mark_params.json
run_one split_samples example_pdf_split_samples_params.json
run_one cluster_composition_ring example_pdf_cluster_composition_ring_params.json
run_one highlight_cells example_pdf_highlight_cells_params.json
run_one bg_cutoff example_pdf_bg_cutoff_params.json
run_one bg_condition example_pdf_bg_condition_params.json

# Keep the normal machine-readable index inclusive of the PDF-matched renders.
python3 - <<'PY'
import json
from pathlib import Path
d=Path('plugins/advanced_dim_plot/examples')
ms=[json.loads(p.read_text()) for p in d.glob('*/manifest.json')]
json.dump({'plugin_id':'advanced_dim_plot','examples':sorted(ms,key=lambda x:x['id'])},open(d/'index.json','w'),indent=2)
PY

echo "PDF-matched advDimPlot examples written to /tmp/advanced_dim_pdf_*_out"
