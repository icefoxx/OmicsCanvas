#!/usr/bin/env Rscript
suppressPackageStartupMessages({ library(optparse); library(jsonlite) })

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x
op <- parse_args(OptionParser(option_list=list(
  make_option('--upper', type='character'), make_option('--lower', type='character'),
  make_option('--input', type='character'), make_option('--params', type='character'),
  make_option('--annotation', dest='annotation', type='character'), make_option('--annot', dest='annotation', type='character'), make_option('--output', type='character')
)))
out <- op$output %||% getwd(); dir.create(out, recursive=TRUE, showWarnings=FALSE)
unlink(file.path(out, c('result.svg','result.pdf','result.png','result.html','figure.json',
  'upper_matrix_used.csv','lower_matrix_used.csv','row_order.csv','column_order.csv','error.json','run.log')), force=TRUE)
logmsg <- function(x) cat(sprintf('[%s] %s\n', format(Sys.time(), '%F %T'), x), file=file.path(out,'run.log'), append=TRUE)
fail <- function(e, detail='', suggestion='Check both square matrices and params.json.') {
  writeLines(toJSON(list(error=e, detail=detail, suggestion=suggestion), auto_unbox=TRUE, pretty=TRUE), file.path(out,'error.json'))
  logmsg(paste(e, detail)); quit(status=1)
}
bool <- function(x, d=FALSE) { if (is.null(x)) return(d); if (is.logical(x)) return(isTRUE(x[1])); tolower(as.character(x[1])) %in% c('true','t','yes','y','1','on') }
vec <- function(x) if (is.null(x)) character() else trimws(as.character(unlist(x, use.names=FALSE)))
num <- function(x, d=NA_real_) { z <- suppressWarnings(as.numeric(unlist(x, use.names=FALSE))[1]); if (is.finite(z)) z else d }
nums <- function(x) suppressWarnings(as.numeric(unlist(x, use.names=FALSE)))
readtab <- function(f) { if (is.null(f) || !file.exists(f)) fail('Input file not found', as.character(f)); if (tolower(tools::file_ext(f)) %in% c('tsv','txt')) read.delim(f, check.names=FALSE, stringsAsFactors=FALSE) else read.csv(f, check.names=FALSE, stringsAsFactors=FALSE) }
flat <- function(x) { z <- x; for (n in names(x)) if (is.list(x[[n]]) && is.null(dim(x[[n]]))) for (k in names(x[[n]])) if (is.null(z[[k]])) z[[k]] <- x[[n]][[k]]; z }
palette <- function(pal, colors, values, limits) {
  known <- list(viridis=c('#440154','#21908C','#FDE725'), plasma=c('#0D0887','#CC4778','#F0F921'),
    magma=c('#000004','#B73779','#FCFDBF'), inferno=c('#000004','#B63679','#FCFFA4'),
    cividis=c('#00204C','#7A7B56','#FDE737'), red=c('#FFF5F0','#CB181D'),
    blue=c('#F7FBFF','#2171B5'), blue_white_red=c('#2166AC','#F7F7F7','#B2182B'))
  cs <- if (tolower(as.character(pal)[1]) == 'custom') vec(colors) else known[[tolower(as.character(pal)[1])]]
  if (length(cs) < 2) cs <- known$viridis
  lim <- nums(limits); lim <- lim[is.finite(lim)]
  if (length(lim) != 2) lim <- range(values, na.rm=TRUE)
  if (!length(lim) || !all(is.finite(lim))) lim <- c(0,1)
  if (lim[1] == lim[2]) lim <- lim + c(-.5,.5)
  list(name=as.character(pal)[1], colors=grDevices::colorRampPalette(cs)(256), limits=lim)
}
colour_at <- function(z, pp, na) { if (is.na(z)) return(na); pp$colors[max(1,min(256,1+round(255*(z-pp$limits[1])/diff(pp$limits))))] }
matrix_input <- function(path, allow_reorder=FALSE) {
  d <- readtab(path); if (ncol(d) < 2 || nrow(d) != ncol(d)-1) fail('Matrix must be square', path)
  r <- as.character(d[[1]]); c <- names(d)[-1]
  if (anyDuplicated(r) || anyDuplicated(c)) fail('Matrix labels must be unique', path)
  if (!setequal(r,c)) fail('Matrix row and column feature sets do not match', path)
  if (!allow_reorder && !identical(r,c)) fail('Matrix row and column labels must be in the same order', path, 'Set allow_reorder to true to reorder matching labels.')
  m <- as.matrix(data.frame(lapply(d[-1], function(x) suppressWarnings(as.numeric(as.character(x))))))
  if (any(!is.finite(m) & !is.na(m))) fail('Matrix contains non-numeric values', path)
  rownames(m) <- r; colnames(m) <- c; m[c,c,drop=FALSE]
}
tryCatch({
  if (is.null(op$params) || !file.exists(op$params)) fail('Params file not found', as.character(op$params))
  p <- flat(fromJSON(op$params, simplifyVector=FALSE)); base <- dirname(normalizePath(op$params, mustWork=FALSE))
  resolve <- function(x) { if (is.null(x) || !nzchar(as.character(x)[1])) return(NULL); x <- as.character(x)[1]; if (!file.exists(x)) file.path(base,x) else x }
  upper_path <- resolve(op$upper %||% op$input); lower_path <- resolve(op$lower %||% p[['lower_input']])
  if (is.null(upper_path)) fail('Upper matrix is required'); if (is.null(lower_path)) fail('Lower matrix is required', 'Use --lower or lower_input.')
  reorder <- bool(p[['allow_reorder']], FALSE); upper <- matrix_input(upper_path, reorder); lower <- matrix_input(lower_path, reorder)
  features <- rownames(upper); if (!setequal(features, rownames(lower)) || !setequal(features, colnames(lower))) fail('Upper and lower feature sets do not match')
  if (!reorder && (!identical(features, rownames(lower)) || !identical(colnames(upper), colnames(lower)))) fail('Upper and lower labels are not aligned', 'Set allow_reorder to true for matching labels in different orders.')
  lower <- lower[features,features,drop=FALSE]; upper <- upper[features,features,drop=FALSE]
  inc <- vec(p[['features_include']]); exc <- vec(p[['features_exclude']]); if (length(inc)) features <- intersect(features,inc); features <- setdiff(features,exc)
  requested <- vec(p[['feature_order']]); if (length(requested)) features <- c(intersect(requested,features),setdiff(features,requested))
  upper <- upper[features,features,drop=FALSE]; lower <- lower[features,features,drop=FALSE]
  source <- tolower(as.character(p[['cluster_source']] %||% 'mean')[1]); source_mat <- if (source=='upper') upper else if (source=='lower') lower else (upper+lower)/2
  if (bool(p[['cluster_features']],FALSE) && length(features)>1) { z <- source_mat; z[!is.finite(z)] <- mean(z[is.finite(z)],na.rm=TRUE); if (!is.finite(z[1])) z[,] <- 0; features <- features[hclust(dist(z), method=as.character(p[['cluster_method']] %||% 'complete')[1])$order] }
  if (bool(p[['reverse_order']],FALSE)) features <- rev(features)
  upper <- upper[features,features,drop=FALSE]; lower <- lower[features,features,drop=FALSE]; n <- length(features)
  write.csv(upper,file.path(out,'upper_matrix_used.csv')); write.csv(lower,file.path(out,'lower_matrix_used.csv'))
  write.csv(data.frame(feature=features),file.path(out,'row_order.csv'),row.names=FALSE); write.csv(data.frame(feature=features),file.path(out,'column_order.csv'),row.names=FALSE)
  up <- palette(p[['upper_palette']] %||% 'red', p[['upper_colors']], upper, p[['upper_limits']]); lo <- palette(p[['lower_palette']] %||% 'blue', p[['lower_colors']], lower, p[['lower_limits']])
  breaks <- function(x, d) { z<-nums(x); if(length(z)) z else pretty(d$limits,n=5) }; ub <- breaks(p[['upper_breaks']],up); lb <- breaks(p[['lower_breaks']],lo)
  upper_show <- bool(p[['upper_triangle_show']],TRUE); lower_show <- bool(p[['lower_triangle_show']],TRUE); diagmode <- tolower(as.character(p[['diagonal_mode']] %||% 'none')[1])
  ann_path <- resolve(op$annotation %||% p[['annotation_file']]); ann <- if (!is.null(ann_path)) readtab(ann_path) else NULL
  ann_cols <- vec(p[['annotation_columns']]); if (!is.null(ann) && length(ann_cols)) ann <- ann[,c(names(ann)[1],intersect(ann_cols,names(ann))),drop=FALSE]
  ann <- if (!is.null(ann) && ncol(ann)>1) ann[match(features,as.character(ann[[1]])),,drop=FALSE] else NULL
  logmsg(sprintf('Loaded independent matrices: upper=%s lower=%s',upper_path,lower_path))
  draw <- function(device) {
    library(grid); w<-num(p[['width']],11); h<-num(p[['height']],10); if(device=='svg') svg(file.path(out,'result.svg'),w,h); if(device=='pdf') grDevices::cairo_pdf(file.path(out,'result.pdf'),w,h); if(device=='png') ragg::agg_png(file.path(out,'result.png'),width=w,height=h,units='in',res=as.integer(num(p[['dpi']],300))); on.exit(dev.off()); grid.newpage(); grid.rect(gp=gpar(fill=as.character(p[['plot_background']] %||% '#FFFFFF')[1],col=NA))
    left<-0.22; right<-0.78; bottom<-0.16; top<-0.80; cw<-(right-left)/n; ch<-(top-bottom)/n
    if ((bool(p[['annotation_strip_show']],FALSE) || bool(p[['dataset_annotation_show']],FALSE)) && !is.null(ann)) { ah<-num(p[['annotation_strip_height']],.035)*ncol(ann[-1]); grid.rect((left+right)/2,top+ah/2,right-left,ah,gp=gpar(fill='#EEEEEE',col=NA)); for(k in seq_len(ncol(ann)-1)) { vals<-as.character(ann[[k+1]]); lev<-unique(vals); cols<-setNames(grDevices::hcl.colors(max(1,length(lev)),'Set 2'),lev); for(j in seq_len(n)) grid.rect(left+(j-.5)*cw,top+ah*(k-.5)/(ncol(ann)-1),cw,ah/(ncol(ann)-1),gp=gpar(fill=cols[vals[j]],col=NA)) } }
    if (bool(p[['dataset_annotation_show']],FALSE) && !is.null(ann)) { aw<-num(p[['annotation_strip_height']],.035)*ncol(ann[-1]); for(k in seq_len(ncol(ann)-1)) { vals<-as.character(ann[[k+1]]); lev<-unique(vals); cols<-setNames(grDevices::hcl.colors(max(1,length(lev)),'Set 2'),lev); for(i in seq_len(n)) grid.rect(right+aw*(k-.5)/(ncol(ann)-1),top-(i-.5)*ch,aw/(ncol(ann)-1),ch,gp=gpar(fill=cols[vals[i]],col=NA)) } }
    for(i in seq_len(n)) for(j in seq_len(n)) { part<-if(j>i)'upper' else if(j<i)'lower' else 'diagonal'; show<-part=='upper'&&upper_show || part=='lower'&&lower_show || part=='diagonal'&&diagmode!='none'; if(!show) next; z<-if(part=='upper')upper[i,j] else if(part=='lower')lower[i,j] else if(diagmode=='upper')upper[i,j] else if(diagmode=='lower')lower[i,j] else (upper[i,j]+lower[i,j])/2; pp<-if(part=='upper')up else lo; fill<-if(part=='diagonal'&&diagmode=='label')as.character(p[['diagonal_color']] %||% '#DDDDDD')[1] else colour_at(z,pp,as.character(p[[paste0(part,'_na_color')]] %||% '#EEEEEE')[1]); grid.rect(left+(j-.5)*cw,top-(i-.5)*ch,cw,ch,gp=gpar(fill=fill,col=if(bool(p[['cell_border_show']],TRUE))as.character(p[['cell_border_color']] %||% '#FFFFFF')[1] else NA,lwd=num(p[['cell_border_width']],.2))); if(bool(p[['show_values']],FALSE)&&part!='diagonal'||bool(p[['show_values']],FALSE)&&part=='diagonal'&&diagmode!='label') grid.text(formatC(z,format='f',digits=as.integer(num(p[[paste0(part,'_value_digits')]],2))),left+(j-.5)*cw,top-(i-.5)*ch,gp=gpar(col=as.character(p[['value_color']] %||% '#222222')[1],fontsize=num(p[['value_size']],7))) }
    if (bool(p[['x_text_show']],TRUE)) for(j in seq_len(n)) grid.text(features[j],left+(j-.5)*cw,bottom-.025,rot=num(p[['x_text_angle']],45),just='right',gp=gpar(fontsize=num(p[['x_text_size']],8),col=as.character(p[['x_text_color']] %||% '#222222')[1])); if(bool(p[['y_text_show']],TRUE)) for(i in seq_len(n)) grid.text(features[i],left-.012,top-(i-.5)*ch,just='right',gp=gpar(fontsize=num(p[['y_text_size']],8),col=as.character(p[['y_text_color']] %||% '#222222')[1]))
    # Colour bar: bottom = lower limit = colors[1], matching colour_at() used for the cells.
    legend <- function(pp, title, x, show) { if(!show)return(); for(k in seq_len(80)) { idx <- max(1,min(256,1+round((k-1)*255/79))); grid.rect(x,.36+(k-.5)*.30/80,.025,.30/80,gp=gpar(fill=pp$colors[idx],col=NA)) }; grid.text(title,x-.025,.51,rot=90,gp=gpar(fontsize=9)); grid.text(formatC(pp$limits[1],digits=3),x+.045,.35,gp=gpar(fontsize=8)); grid.text(formatC(pp$limits[2],digits=3),x+.045,.67,gp=gpar(fontsize=8)) }
    legend(up,p[['upper_colorbar_title']] %||% p[['upper_label']] %||% 'Jaccard similarity',.84,bool(p[['upper_colorbar_show']],TRUE)); legend(lo,p[['lower_colorbar_title']] %||% p[['lower_label']] %||% 'Pearson correlation',.94,bool(p[['lower_colorbar_show']],TRUE)); if(bool(p[['title_show']],TRUE)) grid.text(as.character(p[['title']] %||% 'Dual-triangle heatmap')[1],.5,.96,gp=gpar(fontsize=num(p[['title_size']],16),col=as.character(p[['title_color']] %||% '#222222')[1],fontface=as.character(p[['title_face']] %||% 'bold')[1])); if(!is.null(p[['subtitle']]))grid.text(as.character(p[['subtitle']])[1],.5,.925,gp=gpar(fontsize=num(p[['subtitle_size']],11))); if(!is.null(p[['caption']]))grid.text(as.character(p[['caption']])[1],.5,.04,gp=gpar(fontsize=num(p[['caption_size']],9))); if(bool(p[['annotation_label_show']],FALSE)&&!is.null(ann))grid.text(p[['annotation_label']] %||% 'Dataset',right+.04,top+.03,gp=gpar(fontsize=num(p[['annotation_label_size']],8)))
  }
  for (device in c('svg','pdf','png')) draw(device)
  if (bool(p[['interactive']],TRUE) && requireNamespace('plotly',quietly=TRUE) && requireNamespace('htmlwidgets',quietly=TRUE)) {
    mask <- function(m, part) { z<-m; if(part=='upper') z[lower.tri(z,diag=TRUE)]<-NA else z[upper.tri(z,diag=TRUE)]<-NA; z }
    hover <- function(m, part, metric, dataset) { z<-matrix('',n,n); for(i in seq_len(n))for(j in seq_len(n)) if((part=='upper'&&j>i)||(part=='lower'&&j<i)) z[i,j]<-sprintf('Row: %s<br>Column: %s<br>Triangle: %s<br>Metric: %s<br>Dataset: %s<br>Value: %.6g',features[i],features[j],part,metric,dataset,m[i,j]); z }
    pl<-plotly::plot_ly(); if(upper_show)pl<-plotly::add_trace(pl,x=features,y=features,z=mask(upper,'upper'),type='heatmap',colorscale=list(list(0,up$colors[1]),list(1,up$colors[256])),zmin=up$limits[1],zmax=up$limits[2],text=hover(upper,'upper',p[['upper_metric']] %||% 'jaccard',p[['upper_dataset']] %||% 'upper'),hoverinfo='text',name=p[['upper_label']] %||% 'Jaccard similarity',showscale=bool(p[['upper_colorbar_show']],TRUE)); if(lower_show)pl<-plotly::add_trace(pl,x=features,y=features,z=mask(lower,'lower'),type='heatmap',colorscale=list(list(0,lo$colors[1]),list(1,lo$colors[256])),zmin=lo$limits[1],zmax=lo$limits[2],text=hover(lower,'lower',p[['lower_metric']] %||% 'pearson',p[['lower_dataset']] %||% 'lower'),hoverinfo='text',name=p[['lower_label']] %||% 'Pearson correlation',showscale=bool(p[['lower_colorbar_show']],TRUE)); pl<-plotly::layout(pl,title=p[['title']] %||% 'Dual-triangle heatmap',yaxis=list(autorange='reversed'),xaxis=list(tickangle=num(p[['x_text_angle']],45)),dragmode=if(bool(p[['lasso_select']],FALSE))'lasso' else if(bool(p[['selectable']],FALSE))'select' else if(bool(p[['pan']],TRUE))'pan' else FALSE); htmlwidgets::saveWidget(pl,file.path(out,'result.html'),selfcontained=TRUE)
  } else writeLines('<html><body><h1>Dual-triangle heatmap</h1><p>Plotly is unavailable; see static outputs.</p></body></html>',file.path(out,'result.html'))
  fig<-list(plugin='interactive_dual_triangle_heatmap_plot',inputs=list(upper=upper_path,lower=lower_path,annotation=ann_path),metrics=list(upper=p[['upper_metric']] %||% 'jaccard',lower=p[['lower_metric']] %||% 'pearson'),labels=list(upper=p[['upper_label']] %||% 'Jaccard similarity',lower=p[['lower_label']] %||% 'Pearson correlation'),dimensions=list(rows=n,columns=n),ordering=list(features=features,reverse=bool(p[['reverse_order']],FALSE),cluster=bool(p[['cluster_features']],FALSE),cluster_source=source),ranges=list(upper=up$limits,lower=lo$limits),palettes=list(upper=up$name,lower=lo$name),triangle_source_mapping=list(upper='upper matrix / upper triangle',lower='lower matrix / lower triangle',diagonal=diagmode),outputs=c('result.svg','result.pdf','result.png','result.html','figure.json','run.log','upper_matrix_used.csv','lower_matrix_used.csv','row_order.csv','column_order.csv'))
  writeLines(toJSON(fig,auto_unbox=TRUE,pretty=TRUE),file.path(out,'figure.json')); unlink(file.path(out,'error.json'),force=TRUE); logmsg(sprintf('Completed dual triangle heatmap with %d features.',n))
}, error=function(e) fail('Dual-triangle heatmap rendering failed',conditionMessage(e),'Check matching IDs, numeric values, and independent scale parameters.'))
