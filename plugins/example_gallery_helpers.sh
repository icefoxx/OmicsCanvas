#!/usr/bin/env bash
set -uo pipefail

# Run examples and, for every successful render, retain the complete invocation
# (including the data files) as a portable example bundle.
run_plugin_examples() {
  local plugin="$1" root="${2:-$(pwd)}"; cd "$root"
  local dir="plugins/$plugin"
  local gallery="$dir/all_examples_gallery" failures="$dir/all_examples_gallery/example_failures.txt"
  local bundles="$dir/examples"
  mkdir -p "$gallery" "$bundles"; : > "$failures"
  local -a files=() pngs=() labels=(); while IFS= read -r f; do files+=("$f"); done < <(find "$dir" -maxdepth 1 -type f -name 'example*_params.json' -print | sort)
  local f stem label n out input lower annot used_labels=" "; local -a extra cmd input_specs
  local records="/tmp/${plugin}_example_records.jsonl"; : > "$records"
  for f in "${files[@]}"; do
    stem="${f##*/}"; stem="${stem%.json}"; label="${stem#example_}"; label="${label%_params}"
    n=1; while [[ "$used_labels" == *" $label "* ]]; do label="${stem#example_}"; label="${label%_params}_${n}"; n=$((n+1)); done; used_labels+="$label "
    out="/tmp/${plugin}_${label}_out"; rm -rf "$out"; input="$dir/example_input.csv"; annot=""; extra=()
    case "$plugin" in
      balloon_plot) input="$dir/example_matrix.csv";;
      cluster_dendrogram_plot) input="$dir/example_expression.csv"; annot="$dir/example_annotation.csv";;
      den_plot) input="$dir/example_matrix.csv"; annot="$dir/example_annotation.csv";;
      dot_plot) [[ "$label" == aggregate* ]] && { input="$dir/example_matrix.csv"; annot="$dir/example_annotation.csv"; };;
      dynamic_venn_diagram) [[ "$stem" == *abundance* ]] && input="$dir/example_abundance_input.csv" || input="$dir/example_element_input.csv";;
      interactive_network_plot) [[ "$stem" == *membership* ]] && input="$dir/example_membership_input.csv"; [[ "$stem" == *network* || "$stem" == *manual* ]] && input="$dir/example_input.csv"; [[ "$stem" == *network* ]] && extra=(--nodes "$dir/example_nodes.csv"); ;;
      interactive_arc_network_plot) input="$dir/example_edges.csv"; [[ "$stem" != *basic* ]] && extra=(--nodes "$dir/example_nodes.csv"); ;;
      interactive_violin_plot) [[ "$stem" == *long* ]] && input="$dir/example_input_long.csv";;
      exp_stat_plot) input="$dir/example_metadata.csv"; extra=(--expr "$dir/example_expression.csv");;
      feature_density_plot) input="$dir/example_expression.csv"; extra=(--embed "$dir/example_embedding.csv");;
      fgsea_enrichment_plot) if [[ "$stem" == *summary* || "$stem" == *dot_summary* ]]; then input="$dir/example_fgsea_results.csv"; elif [[ "$stem" == *multigroup* ]]; then input="$dir/example_multigroup_ranks.csv"; extra=(--genesets "$dir/example_multigroup_pathways.gmt"); elif [[ "$stem" == *ridge* || "$stem" == *gene_sankey* ]]; then input="$dir/example_ridge_ranks.csv"; extra=(--genesets "$dir/example_ridge_pathways.gmt"); else input="$dir/example_ranks.csv"; extra=(--genesets "$dir/example_pathways.gmt"); fi;;
      gsea_pathway_heatmap) input="$dir/example_ranks.csv"; extra=(--genesets "$dir/example_pathways.gmt" --expr "$dir/example_expression.csv"); [[ "$stem" == *annotation* ]] && extra+=(--col_annot "$dir/example_col_annot.csv"); [[ "$stem" == *precomputed* ]] && extra+=(--enrichment "$dir/example_enrichment.csv");;
      lineage_plot) input="$dir/example_embedding.csv"; extra=(--lineages "$dir/example_lineages.csv");;
      sca_volcano_plot) input="$dir/example_markers.csv";;
      stat_plot) input="$dir/example_metadata.csv";;
      interactive_enrichment_lollipop) [[ "$stem" == *CAB_demo* ]] && input="$dir/example_CAB_demo_input.csv" || input="$dir/example_input.csv";;
      interactive_ridgeline_plot) [[ "$stem" == *CAB_demo* ]] && input="$dir/example_CAB_demo_input.csv" || input="$dir/example_input.csv";;
      regression_scatter_plot) input="$dir/example_input.csv";;
      alluvial_plot) [[ "$stem" == *long* ]] && input="$dir/example_long.csv"; [[ "$stem" == *edges* ]] && input="$dir/example_edges.csv";;
      pie_dot_matrix) input="$dir/example_input.csv"; extra=(--col_annot "$dir/example_col_annot.csv" --marks "$dir/example_marks.csv");;
      highlight_effect_plot) [[ "$stem" == *summary* ]] && input="$dir/example_summary.csv" || input="$dir/example_input.csv";;
      combo_bar_dot_matrix) input="$dir/example_input.csv"; extra=(--matrix "$dir/example_matrix.csv" --comparisons "$dir/example_comparisons.csv"); [[ "$stem" == *bar_only* ]] && extra=();;
      interactive_bubble_score_matrix) input="$dir/example_input.csv"; [[ "$stem" == *multi_score* ]] && input="$dir/example_multi_input.csv"; [[ "$stem" == *external_score* ]] && extra=(--scores "$dir/example_scores.csv");;
      violin_plot) if [[ "$label" == matrix* ]]; then input="$dir/example_matrix.csv"; annot="$dir/example_annotation.csv"; else input="$dir/example_long.csv"; fi;;
       interactive_histogram_plot|interactive_motif_logo_plot) input="$dir/example_input.csv";;
       interactive_clustered_heatmap_plot) input="$dir/example_matrix.csv"; extra=(--row-annot "$dir/example_row_annotation.csv" --col-annot "$dir/example_column_annotation.csv"); [[ "$stem" == *panels* ]] && extra+=(--panel-groups "$dir/example_panel_groups.csv");;
       interactive_genomic_signal_track_plot) input="$dir/example_signal.csv"; extra=(--expression "$dir/example_expression.csv" --features "$dir/example_features.csv");;
       interactive_dual_triangle_heatmap_plot) input="$dir/example_upper.csv"; lower="$dir/example_lower.csv"; annot="$dir/example_annotation.csv"; extra=(--lower "$lower" --annotation "$annot");;
    esac
    echo ">>> $plugin: $label"; cmd=(Rscript "$dir/plot.R" --input "$input" --params "$f" --output "$out"); [[ -n "$annot" ]] && cmd+=(--annot "$annot"); if ((${#extra[@]})); then cmd+=("${extra[@]}"); fi
    if "${cmd[@]}" && [[ -s "$out/result.png" ]]; then
      local bundle="$bundles/$label"; rm -rf "$bundle"; mkdir -p "$bundle/input" "$bundle/expected"
      cp "$f" "$bundle/params.json"; cp "$out/result.png" "$bundle/expected/result.png"
      input_specs=("input=$input"); [[ -n "$annot" ]] && input_specs+=("annot=$annot"); for ((n=0;n<${#extra[@]};n++)); do [[ "${extra[$n]}" == --* ]] && input_specs+=("${extra[$n]#--}=${extra[$((n+1))]}") && n=$((n+1)); done
      # The Python writer also normalizes paths and handles duplicate basenames.
      PLUGIN="$plugin" LABEL="$label" PARAMS="$f" BUNDLE="$bundle" INPUTS="${input_specs[*]}" CMD="${cmd[*]}" python3 - <<'PY'
import json, os, shutil
plugin,label,params,bundle=os.environ['PLUGIN'],os.environ['LABEL'],os.environ['PARAMS'],os.environ['BUNDLE']
specs=os.environ['INPUTS'].split(); names={}; inputs={}; paths=[]
for i,spec in enumerate(specs):
    key,p=spec.split('=',1); paths.append(p)
    base=os.path.basename(p)
    # Preserve the actual filename while making collisions deterministic.
    dst=base if base not in names else str(i)+'_'+base; names[base]=1
    shutil.copy2(p, os.path.join(bundle,'input',dst)); inputs[key]='input/'+dst
x=json.load(open(params)); plot_type=x.get('plot_type',x.get('plot_kind',x.get('input_mode',label)))
mode=x.get('mode',x.get('plot_mode',x.get('plot_mode_name','')))
manifest={'id':label,'label':label,'plugin_id':plugin,'plot_type':plot_type,'mode':mode,'params':'params.json','inputs':inputs,'expected':'expected/result.png','reproduce':{'command':os.environ['CMD']}}
cmd=os.environ['CMD']
cmd=cmd.replace(params, 'plugins/'+plugin+'/examples/'+label+'/params.json')
for p in paths:
    base=os.path.basename(p); dst=base if list(names).count(base)==1 else str(paths.index(p))+'_'+base
    cmd=cmd.replace(p, 'plugins/'+plugin+'/examples/'+label+'/input/'+dst)
manifest['reproduce']['command']=cmd
json.dump(manifest,open(os.path.join(bundle,'manifest.json'),'w'),indent=2); print(json.dumps(manifest))
PY
      printf '%s\n' "$bundle" >> "$records"; cp "$out/result.png" "$gallery/$label.png"; pngs+=("$gallery/$label.png"); labels+=("$label")
    else printf '%s\t%s\n' "$stem" "generation failed (see $out)" >> "$failures"; fi
  done
  if ((${#pngs[@]})); then
    GALLERY_DIR="$gallery" PNG_LIST="${pngs[*]}" PLUGIN="$plugin" Rscript -e 'f<-strsplit(Sys.getenv("PNG_LIST")," ",fixed=T)[[1]];f<-f[nzchar(f)&file.exists(f)];if(length(f)){a<-lapply(f,png::readPNG);h<-max(vapply(a,function(x)dim(x)[1],integer(1)));w<-sum(vapply(a,function(x)dim(x)[2],integer(1)))+12*(length(a)-1);z<-array(1,c(h,w,3));x<-1;for(i in a){ih<-dim(i)[1];iw<-dim(i)[2];z[seq_len(ih),x:(x+iw-1),]<-i[,,1:3];x<-x+iw+12};png::writePNG(z,file.path(Sys.getenv("GALLERY_DIR"),paste0(Sys.getenv("PLUGIN"),"_gallery.png")))}'
  fi
  PLUGIN="$plugin" DIR="$dir" GALLERY="$gallery" RECORDS="$records" python3 - <<'PY'
import json,os
plugin, gallery, records=os.environ['PLUGIN'],os.environ['GALLERY'],os.environ['RECORDS']
items=[]
for line in open(records):
 b=line.strip();
 if not b: continue
 m=json.load(open(os.path.join(b,'manifest.json'))); items.append(m)
items.sort(key=lambda x:x['id'])
for m in items:
 m['bundle']=os.path.relpath(os.path.join(os.environ['DIR'],'examples',m['id']),os.environ['GALLERY'])
 m['params']=m['bundle']+'/params.json'; m['expected']=m['bundle']+'/expected/result.png'
 m['gallery_png']=m['id']+'.png'; m['params_filename']='example_'+m['id']+'_params.json'
json.dump(items,open(os.path.join(gallery,'example_gallery.json'),'w'),indent=2)
json.dump({'plugin_id':plugin,'examples':items},open(os.path.join(os.environ['DIR'],'examples','index.json'),'w'),indent=2)
PY
  echo "$plugin examples complete; failures: $failures"
}
