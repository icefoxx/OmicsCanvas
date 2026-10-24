#!/usr/bin/env Rscript

# Interactive UpSet Plot.  This is intentionally independent of ComplexUpset:
# the exported tables use the same concepts, while the renderer stays usable
# in a minimal ggplot2/grid installation.
suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
  library(grid)
})

op <- parse_args(OptionParser(option_list=list(
  make_option('--input', type='character'),
  make_option('--params', type='character'),
  make_option('--output', type='character')
)))
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x
out <- op$output %||% getwd()
dir.create(out, recursive=TRUE, showWarnings=FALSE)

logmsg <- function(x) cat(sprintf('[%s] %s\n', format(Sys.time(), '%F %T'), x), file=file.path(out, 'run.log'), append=TRUE)
fail <- function(message, detail='', suggestion='Check input columns and params.json.') {
  dir.create(out, recursive=TRUE, showWarnings=FALSE)
  writeLines(toJSON(list(error=message, detail=detail, suggestion=suggestion), auto_unbox=TRUE, pretty=TRUE), file.path(out, 'error.json'))
  quit(status=1)
}
val <- function(p, name, default=NULL, aliases=character()) {
  x <- p[[name]]
  if (is.null(x)) for (a in aliases) if (!is.null(p[[a]])) { x <- p[[a]]; break }
  if (is.null(x)) for (g in names(p)) if (is.list(p[[g]]) && !is.null(p[[g]][[name]])) { x <- p[[g]][[name]]; break }
  if (is.null(x)) default else x
}
vec <- function(x, default=character()) {
  if (is.null(x)) return(default)
  x <- unlist(x, use.names=FALSE)
  if (length(x) == 1 && grepl(',', x, fixed=TRUE)) x <- strsplit(x, ',', fixed=TRUE)[[1]]
  x <- trimws(as.character(x)); x[nzchar(x)]
}
num <- function(p, n, d=0) { x <- suppressWarnings(as.numeric(unlist(val(p,n,d))[1])); ifelse(is.na(x), d, x) }
boo <- function(p, n, d=FALSE) {
  x <- val(p,n,d); if (is.logical(x)) return(isTRUE(x[1]))
  tolower(as.character(unlist(x)[1])) %in% c('true','t','yes','y','1','on')
}
readtab <- function(f) {
  if (!file.exists(f)) fail('Input file not found', f)
  if (tolower(tools::file_ext(f)) %in% c('tsv','txt')) read.delim(f, check.names=FALSE, stringsAsFactors=FALSE) else read.csv(f, check.names=FALSE, stringsAsFactors=FALSE)
}
check_cols <- function(d, cols, label) { m <- setdiff(cols, names(d)); if (length(m)) fail('Required columns not found', paste(label, paste(m, collapse=', '), sep=': ')); invisible(TRUE) }
as_member <- function(x, na_action) {
  if (is.logical(x)) z <- x else {
    s <- tolower(trimws(as.character(x))); n <- suppressWarnings(as.numeric(s))
    z <- s %in% c('true','t','yes','y','present','on','1') | (!is.na(n) & n != 0)
    z[s %in% c('', 'na', 'nan', 'null')] <- NA
  }
  if (na_action == 'zero') z[is.na(z)] <- FALSE
  z
}
safe_name <- function(x) gsub('[^A-Za-z0-9_.-]+', '_', x)
palette_default <- c('#386CB0','#F0027F','#BF5B17','#1B9E77','#7570B3','#E7298A','#66A61E','#E6AB02','#A6761D','#666666')
get_colors <- function(p, n, name='intersection_bar_colors') {
  x <- val(p, name, NULL); if (is.null(x)) return(rep(palette_default, length.out=n))
  x <- as.character(unlist(x)); if (!length(x)) return(rep(palette_default, length.out=n)); rep(x, length.out=n)
}

make_membership <- function(d, p) {
  mode <- tolower(as.character(val(p,'input_mode','wide'))[1])
  id <- as.character(val(p,'item_column', names(d)[1])); check_cols(d,id,'item_column')
  if (mode == 'long') {
    sc <- as.character(val(p,'set_column', ifelse(length(names(d)) > 1, names(d)[2], 'set'))); check_cols(d,c(id,sc),'long columns')
    vc <- as.character(val(p,'value_column', '')); if (nzchar(vc) && vc %in% names(d)) present <- as_member(d[[vc]], 'zero') else present <- rep(TRUE,nrow(d))
    sets <- vec(val(p, 'set_columns', unique(as.character(d[[sc]])))); if (!length(sets)) sets <- sort(unique(as.character(d[[sc]])))
    ids <- unique(as.character(d[[id]])); m <- matrix(FALSE, nrow=length(ids), ncol=length(sets), dimnames=list(ids,sets))
    for (i in which(present & !is.na(d[[id]]) & !is.na(d[[sc]]))) if (as.character(d[[sc]][i]) %in% sets) m[as.character(d[[id]][i]),as.character(d[[sc]][i])] <- TRUE
    meta <- d[match(ids, as.character(d[[id]])),,drop=FALSE]; rownames(meta) <- ids
  } else {
    sets <- vec(val(p,'set_columns', setdiff(names(d), id))); check_cols(d,sets,'set_columns')
    ids <- make.unique(as.character(d[[id]])); m <- sapply(sets, function(s) as_member(d[[s]], as.character(val(p,'na_action','zero')))); m <- as.matrix(m); rownames(m) <- ids; colnames(m) <- sets
    meta <- d; rownames(meta) <- ids
  }
  inc <- vec(val(p,'sets_include')); exc <- vec(val(p,'sets_exclude')); if (length(inc)) sets <- sets[sets %in% inc]; if (length(exc)) sets <- sets[!sets %in% exc];
  ord <- vec(val(p,'set_order')); if (length(ord)) sets <- c(ord[ord %in% sets], setdiff(sets,ord))
  m <- m[,sets,drop=FALSE]; keep <- rep(TRUE,nrow(m)); filter <- val(p,'item_filter',NULL)
  if (is.list(filter) && !is.null(filter$include)) keep <- rownames(m) %in% vec(filter$include)
  if (is.list(filter) && !is.null(filter$exclude)) keep <- keep & !(rownames(m) %in% vec(filter$exclude))
  empty <- tolower(as.character(val(p,'empty_set_handling','keep'))[1]); if (empty %in% c('drop','remove')) m <- m[,colSums(m)>0,drop=FALSE]
  if (!nrow(m) || !ncol(m)) fail('No membership data remain', '', 'Check set selection and item_filter.')
  meta <- meta[rownames(m),,drop=FALSE]
  list(matrix=m, meta=meta, id=id, sets=colnames(m))
}

pattern_label <- function(x) { z <- names(x)[as.logical(x)]; if (length(z)) paste(z, collapse=' & ') else '(empty)' }
combos <- function(sets, degrees) {
  out <- list(); for (k in degrees) if (k == 0) out <- c(out, list(character())) else if (k <= length(sets)) out <- c(out, lapply(combn(sets,k,simplify=FALSE), identity)); out
}
build_intersections <- function(m, p) {
  sets <- colnames(m); mode <- tolower(as.character(val(p,'mode','exclusive_intersection'))[1]); if (!mode %in% c('exclusive_intersection','inclusive_intersection','exclusive_union','inclusive_union')) fail('Invalid intersection mode', mode)
  observed <- unique(apply(m,1,function(z) pattern_label(setNames(z,sets))))
  type <- tolower(as.character(val(p,'intersections','observed'))[1]); custom <- val(p,'intersection_order',NULL); custom <- if (is.null(custom)) NULL else custom
  degrees <- seq_len(length(sets)); mind <- as.integer(num(p,'min_degree',0)); maxd <- as.integer(num(p,'max_degree',length(sets))); degrees <- degrees[degrees >= max(1,mind) & degrees <= maxd]
  pats <- if (type == 'all') combos(sets,degrees) else if (length(custom)) lapply(custom, function(x) vec(x)) else lapply(observed, function(x) if (x == '(empty)') character() else strsplit(x,' & ',fixed=TRUE)[[1]])
  rows <- lapply(pats, function(target) {
    hit <- if (length(target)) rowSums(m[,target,drop=FALSE]) == length(target) else rowSums(m)==0
    if (mode %in% c('exclusive_intersection','exclusive_union')) hit <- hit & if (length(target)) rowSums(m[,setdiff(sets,target),drop=FALSE]) == 0 else TRUE
    if (mode %in% c('exclusive_union','inclusive_union')) { u <- if(length(target)) rowSums(m[,target,drop=FALSE]) > 0 else rowSums(m)==0; outside <- if(length(target)) rowSums(m[,setdiff(sets,target),drop=FALSE]) > 0 else FALSE; hit <- if (mode=='exclusive_union') u & !outside else u }
    if (mode == 'inclusive_intersection') hit <- if(length(target)) rowSums(m[,target,drop=FALSE]) == length(target) else rowSums(m)==0
    list(target=target, hit=hit, count=sum(hit), degree=length(target))
  })
  allsize <- nrow(m); union_size <- sum(rowSums(m)>0); denom <- ifelse(union_size>0,union_size,1)
  z <- data.frame(intersection=character(), pattern=character(), count=numeric(), degree=numeric(), ratio=numeric(), stringsAsFactors=FALSE)
  for (r in rows) z <- rbind(z,data.frame(intersection=if(length(r$target)) paste(r$target,collapse=' & ') else '(empty)', pattern=paste(as.integer(sets %in% r$target),collapse=''), count=r$count, degree=r$degree, ratio=r$count/denom, stringsAsFactors=FALSE))
  z <- z[!duplicated(z$intersection),,drop=FALSE]; minsz <- num(p,'min_size',0); maxsz <- num(p,'max_size',Inf); z <- z[z$count>=minsz & z$count<=maxsz & z$degree>=num(p,'min_degree',0) & z$degree<=num(p,'max_degree',length(sets)),,drop=FALSE]
  sb <- tolower(as.character(val(p,'sort_intersections','descending'))[1]); by <- tolower(as.character(val(p,'sort_intersections_by','cardinality'))[1]); if (sb != 'false' && nrow(z)) { key <- if(by=='degree') z$degree else if(by=='ratio') z$ratio else z$count; z <- z[order(key,decreasing=sb!='ascending',z$intersection),,drop=FALSE] }
  ni <- as.integer(num(p,'n_intersections',0)); if (ni>0 && nrow(z)>ni) z <- z[seq_len(ni),,drop=FALSE]
  z$index <- seq_len(nrow(z)); z$label <- z$intersection; z$total_items <- allsize; z
}

theme_up <- function(p) {
  base <- num(p,'base_size',11); bg <- as.character(val(p,'background','#FFFFFF')); panel <- as.character(val(p,'panel_background',bg)); g <- if(boo(p,'grid_show',TRUE)) as.character(val(p,'grid_color','#E5E7EB')) else NA
  theme_minimal(base_size=base, base_family=as.character(val(p,'font_family','sans'))) + theme(plot.background=element_rect(fill=bg,colour=NA), panel.background=element_rect(fill=panel,colour=NA), panel.grid.major=element_line(colour=g, linewidth=num(p,'grid_width',.25)), panel.grid.minor=element_blank(), plot.title=element_text(face='bold'), axis.text.x=element_text(angle=num(p,'intersection_label_angle',45), hjust=1, size=num(p,'intersection_label_size',8)), axis.text.y=element_text(size=num(p,'set_label_size',9)), legend.position=val(p,'legend_position','right'))
}
geom_shape <- function(shape, size, colour, fill) { if(shape=='square') geom_point(shape=15,size=size,colour=colour,fill=fill) else if(shape=='diamond') geom_point(shape=18,size=size,colour=colour,fill=fill) else geom_point(shape=21,size=size,colour=colour,fill=fill) }
make_plots <- function(m, meta, z, p, subclass, queries) {
  sets <- colnames(m); n <- nrow(z); x <- z$index; active <- matrix(FALSE,nrow=length(sets),ncol=n,dimnames=list(sets,z$intersection)); for(i in seq_len(n)) if(nchar(z$pattern[i])) active[,i] <- strsplit(z$pattern[i],'',fixed=TRUE)[[1]] == '1'
  qfill <- rep(as.character(val(p,'intersection_bar_fill','#386CB0')),n); qset <- rep(FALSE,n); qitems <- vec(val(p,'highlight_items')); item_hi <- rownames(m) %in% qitems
  q <- queries %||% list(); if (length(q)) for (qq in q) { if (!is.null(qq$intersect)) { ii <- z$intersection %in% paste(vec(qq$intersect),collapse=' & '); if (is.null(qq$intersect) || !any(ii)) ii <- vapply(z$intersection,function(s) all(vec(qq$intersect) %in% strsplit(s,' & ',fixed=TRUE)[[1]]),logical(1)); if (!is.null(qq$fill)) qfill[ii] <- as.character(qq$fill); if (!is.null(qq$color)) qfill[ii] <- as.character(qq$color) }; if (!is.null(qq$set)) qset <- qset | z$intersection %in% as.character(qq$set) }
  bar <- data.frame(x=x,count=z$count,ratio=z$ratio,label=z$label,fill=qfill,stringsAsFactors=FALSE)
  ib <- ggplot(bar,aes(x=x,y=count)) + geom_col(aes(fill=fill),width=num(p,'intersection_bar_width',.72),alpha=num(p,'intersection_bar_alpha',.9),colour=if(val(p,'intersection_bar_color_by','constant')=='constant') val(p,'intersection_bar_color','#FFFFFF') else NA) + scale_fill_identity() + scale_x_continuous(breaks=x,labels=z$label,expand=expansion(add=.5)) + labs(x=NULL,y=val(p,'intersection_size_label','Intersection size')) + theme_up(p)
  if(boo(p,'intersection_count_show',TRUE) && n) ib <- ib + geom_text(aes(label=formatC(count,format='fg',digits=as.integer(num(p,'intersection_count_digits',3)))),vjust=-.35,size=3,colour=val(p,'intersection_count_color','#222222'))
  if(boo(p,'intersection_percent_show',FALSE) && n) ib <- ib + geom_text(aes(y=count,label=paste0(round(count/sum(count)*100,num(p,'intersection_percent_digits',1)),'%')),vjust=1.4,size=2.6,colour=val(p,'intersection_count_color','#222222'))
  ss <- data.frame(set=sets,size=colSums(m),x=seq_along(sets)); setfill <- get_colors(p,length(sets),'set_bar_colors'); if(length(q)) for(qq in q) if(!is.null(qq$set) && (!is.null(qq$fill) || !is.null(qq$color))) setfill[match(as.character(qq$set),sets)] <- as.character(qq$fill %||% qq$color); sb <- ggplot(ss,aes(x=x,y=size)) + geom_col(fill=setfill,alpha=num(p,'set_bar_alpha',.9),width=num(p,'set_bar_width',.7)) + scale_x_continuous(breaks=ss$x,labels=ss$set,expand=expansion(add=.5)) + labs(x=NULL,y=val(p,'set_size_label','Set size')) + theme_up(p) + theme(axis.text.x=element_text(angle=num(p,'set_label_angle',45),hjust=1))
  mat <- expand.grid(set=sets,index=x,KEEP.OUT.ATTRS=FALSE,stringsAsFactors=FALSE); mat$active <- as.vector(active); mat$y <- match(mat$set,rev(sets)); mat$index <- mat$index
  mp <- ggplot(mat,aes(x=index,y=y)) + geom_shape(val(p,'matrix_shape','circle'),num(p,'matrix_point_size',3),val(p,'matrix_outline_color','#FFFFFF'),ifelse(mat$active,val(p,'matrix_active_color','#222222'),val(p,'matrix_inactive_color','#D1D5DB'))) + scale_y_continuous(breaks=seq_along(sets),labels=rev(sets),expand=expansion(add=.4)) + scale_x_continuous(breaks=x,labels=z$label,expand=expansion(add=.5)) + labs(x=NULL,y=NULL) + theme_up(p) + theme(axis.text.x=element_blank(),axis.ticks.x=element_blank(),panel.grid.major.x=element_blank())
  for(i in seq_len(n)) { yy <- which(active[,i]); if(length(yy)>1) mp <- mp + geom_segment(data=data.frame(x=x[i],xend=x[i],y=min(yy),yend=max(yy)),aes(x=x,xend=xend,y=y,yend=yend),colour=val(p,'matrix_segment_color','#222222'),linewidth=num(p,'matrix_segment_width',.7),inherit.aes=FALSE) }
  rp <- ggplot(bar,aes(x=x,y=ratio)) + geom_col(fill=rep(get_colors(p,max(1,n),'ratio_palette'),length.out=n),width=.72,alpha=.85) + scale_x_continuous(breaks=x,labels=z$label,expand=expansion(add=.5)) + labs(x=NULL,y='Intersection / union') + theme_up(p); lim <- unlist(val(p,'ratio_limits',NULL)); if(length(lim)==2) rp <- rp + coord_cartesian(ylim=as.numeric(lim))
  annotations <- list(); ac <- vec(val(p,'annotation_columns')); at <- vec(val(p,'annotation_types')); ag <- vec(val(p,'annotation_geoms')); titles <- vec(val(p,'annotation_titles')); for(i in seq_along(ac)) if(ac[i] %in% names(meta)) { a <- data.frame(intersection=rep('(unassigned)',nrow(meta)),value=meta[[ac[i]]],stringsAsFactors=FALSE); for(j in seq_len(nrow(meta))) { hit <- rowSums(m[j,,drop=FALSE])>0; matches <- which(vapply(seq_len(n),function(k) all(m[j,] == (strsplit(z$pattern[k],'',fixed=TRUE)[[1]]=='1')),logical(1))); if(length(matches)) a$intersection[j] <- z$intersection[matches[1]] }; typ <- if(length(at)>=i) tolower(at[i]) else if(is.numeric(a$value)) 'numeric' else 'categorical'; geomn <- if(length(ag)>=i) tolower(ag[i]) else if(typ=='numeric') 'box' else 'bar'; if(typ=='numeric') { a$value<-suppressWarnings(as.numeric(a$value)); g <- ggplot(a[!is.na(a$value),],aes(x=intersection,y=value))+theme_up(p)+labs(x=NULL,y=if(length(titles)>=i)titles[i] else ac[i])+theme(axis.text.x=element_blank(),axis.ticks.x=element_blank()); if(geomn=='violin') g<-g+geom_violin(fill=val(p,'annotation_colors','#9ECAE1'),alpha=num(p,'annotation_alpha',.6),trim=FALSE) else {g<-g+geom_boxplot(fill=val(p,'annotation_colors','#9ECAE1'),alpha=num(p,'annotation_alpha',.6));if(geomn%in%c('jitter','point'))g<-g+geom_jitter(size=num(p,'annotation_size',1.5),width=.12,alpha=num(p,'annotation_alpha',.5))} } else { a$value<-as.character(a$value); g<-ggplot(a,aes(x=intersection,fill=value))+geom_bar(position=if(geomn=='fill')'fill' else 'stack')+theme_up(p)+labs(x=NULL,y=ifelse(geomn=='fill','Proportion','Count'),fill=if(length(titles)>=i)titles[i] else ac[i])+theme(axis.text.x=element_blank(),axis.ticks.x=element_blank()) }; annotations[[ac[i]]] <- g }
  panels <- list(); if(boo(p,'intersection_size_show',TRUE) && subclass!='matrix_only') panels <- c(panels,list(intersection=ib)); if(boo(p,'ratio_show',subclass=='ratio'||subclass=='intersection_size'&&boo(p,'ratio_show',FALSE))) panels <- c(panels,list(ratio=rp)); if(boo(p,'matrix_show',TRUE)) panels <- c(panels,list(matrix=mp)); if(boo(p,'set_sizes_show',TRUE) && subclass!='matrix_only') panels <- c(panels,list(sets=sb)); if(subclass=='set_size') panels <- list(sets=sb,matrix=mp); if(subclass=='intersection_size') panels <- list(intersection=ib,matrix=mp); if(subclass=='matrix_only') panels <- list(matrix=mp); if(length(annotations)) panels <- c(panels,annotations); if(!length(panels)) panels <- list(matrix=mp)
  list(panels=panels, matrix=active, item_highlight=item_hi, bar=bar, set_sizes=ss)
}

save_static <- function(panels,p,w,h,dpi) {
  if (requireNamespace('patchwork',quietly=TRUE)) plot <- patchwork::wrap_plots(panels, ncol=1) + patchwork::plot_annotation(title=val(p,'title',NULL),subtitle=val(p,'subtitle',NULL),caption=val(p,'caption',NULL)) else plot <- panels[[1]]
  if (!exists('omicscanvas_apply_theme')) { .oc_f <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[1]); .oc_rt <- file.path(dirname(normalizePath(.oc_f, mustWork = FALSE)), '..', '..', 'R', 'runtime', 'omicscanvas_theme.R'); if (!file.exists(.oc_rt)) .oc_rt <- file.path('R', 'runtime', 'omicscanvas_theme.R'); sys.source(.oc_rt, envir = globalenv()) }; plot <- omicscanvas_apply_theme(plot, p, only = c('axis_label_size', 'legend_text_size', 'panel_spacing', 'title_size')); grDevices::svg(file.path(out,'result.svg'),width=w,height=h); print(plot); dev.off(); grDevices::cairo_pdf(file.path(out,'result.pdf'),width=w,height=h); print(plot); dev.off(); (if (requireNamespace('ragg', quietly = TRUE)) ragg::agg_png else function(...) grDevices::png(..., type = 'cairo'))(file.path(out,'result.png'),width=w,height=h,units='in',res=dpi); print(plot); dev.off()
}
save_html <- function(z,m,meta,p,panels) {
  html <- file.path(out,'result.html'); if (!requireNamespace('plotly',quietly=TRUE) || !requireNamespace('htmlwidgets',quietly=TRUE)) { writeLines('<html><body><h1>Interactive UpSet Plot</h1><p>Plotly is unavailable; see result.svg/pdf/png and exported CSV tables.</p></body></html>',html); return(FALSE) }
  b <- plotly::plot_ly(x=z$label,y=z$count,type='bar',name='Intersection size',text=z$label,hovertemplate='%{text}<br>count=%{y}<extra></extra>')
  for (i in seq_along(colnames(m))) { active_set <- vapply(z$pattern, function(s) if(nchar(s)) as.integer(strsplit(s,'',fixed=TRUE)[[1]][i]) else 0, integer(1)); b <- plotly::add_trace(b,x=z$label,y=active_set,type='scatter',mode='markers',name=colnames(m)[i],visible='legendonly',text=z$label,hovertemplate='%{text}<extra></extra>') }
  b <- plotly::layout(b,title=list(text=as.character(val(p,'title','Interactive UpSet Plot'))),xaxis=list(title='Intersection'),yaxis=list(title='Count'),paper_bgcolor=val(p,'background','#FFFFFF'),plot_bgcolor=val(p,'panel_background','#FFFFFF'))
  b <- plotly::config(b,displaylogo=FALSE,scrollZoom=boo(p,'zoom',TRUE),doubleClick='reset',modeBarButtonsToAdd=if(boo(p,'lasso_select',FALSE)) c('lasso2d','select2d') else if(boo(p,'selectable',TRUE)) 'select2d' else character()); htmlwidgets::saveWidget(b,html,selfcontained=TRUE); TRUE
}

main <- function() {
  if (is.null(op$input) || is.null(op$params) || !file.exists(op$params)) fail('Missing input or params argument')
  unlink(file.path(out,c('error.json','result.svg','result.pdf','result.png','result.html','figure.json','run.log','membership_matrix_used.csv','intersections_used.csv','set_sizes_used.csv'))); logmsg('Starting interactive_upset_plot.')
  p <- fromJSON(op$params,simplifyVector=FALSE); d <- readtab(op$input); mm <- make_membership(d,p); m <- mm$matrix; z <- build_intersections(m,p); subclass <- tolower(as.character(val(p,'plot_subclass','basic'))[1]); allowed <- c('basic','intersection_size','set_size','matrix_only','ratio','annotated_numeric','annotated_categorical','query_highlight','grouped','all_intersections'); if(!subclass%in%allowed) fail('Invalid plot_subclass',subclass)
  queries <- val(p,'queries',list()); if(!is.list(queries)) queries <- list(); if(subclass=='all_intersections' && tolower(as.character(val(p,'intersections','all'))[1])!='all') logmsg('all_intersections subclass requested without intersections=all; using selected intersections.')
  rr <- make_plots(m,mm$meta,z,p,subclass,queries); w<-num(p,'width',10);h<-num(p,'height',8);dpi<-num(p,'dpi',180);save_static(rr$panels,p,w,h,dpi); html_ok<-save_html(z,m,mm$meta,p,rr$panels)
  matrix_export <- data.frame(item_id=rownames(m),as.data.frame(m,check.names=FALSE),check.names=FALSE); utils::write.csv(matrix_export,file.path(out,'membership_matrix_used.csv'),row.names=FALSE); utils::write.csv(z,file.path(out,'intersections_used.csv'),row.names=FALSE); utils::write.csv(rr$set_sizes,file.path(out,'set_sizes_used.csv'),row.names=FALSE)
  fig <- list(plugin='interactive_upset_plot',source_engine=if(requireNamespace('ComplexUpset',quietly=TRUE))'native ggplot2/grid (ComplexUpset available)' else 'native ggplot2/grid',subclass=subclass,input=normalizePath(op$input,mustWork=FALSE),input_mode=val(p,'input_mode','wide'),item_column=mm$id,set_order=mm$sets,intersections=unname(lapply(seq_len(nrow(z)),function(i) list(label=z$intersection[i],pattern=strsplit(z$pattern[i],'',fixed=TRUE)[[1]],count=z$count[i],degree=z$degree[i],ratio=z$ratio[i]))),set_sizes=rr$set_sizes,mode=val(p,'mode','exclusive_intersection'),filters=list(min_size=val(p,'min_size',0),max_size=val(p,'max_size',NULL),min_degree=val(p,'min_degree',0),max_degree=val(p,'max_degree',NULL),n_intersections=val(p,'n_intersections',NULL),sets_include=val(p,'sets_include',NULL),sets_exclude=val(p,'sets_exclude',NULL),item_filter=val(p,'item_filter',NULL)),queries=queries,annotation_panels=vec(val(p,'annotation_columns')),panels=names(rr$panels),outputs=list(svg='result.svg',pdf='result.pdf',png='result.png',html='result.html',figure='figure.json',log='run.log',membership_matrix='membership_matrix_used.csv',intersections='intersections_used.csv',set_sizes='set_sizes_used.csv'),capabilities=list(plotly=html_ok,complexupset=requireNamespace('ComplexUpset',quietly=TRUE)))
  writeLines(toJSON(fig,auto_unbox=TRUE,null='null',pretty=TRUE),file.path(out,'figure.json')); if(file.exists(file.path(out,'error.json')))unlink(file.path(out,'error.json')); logmsg(sprintf('Rendered subclass=%s, %d items, %d intersections, %d sets.',subclass,nrow(m),nrow(z),ncol(m)))
}
tryCatch(main(), error=function(e) fail('Plot generation failed',conditionMessage(e)))
