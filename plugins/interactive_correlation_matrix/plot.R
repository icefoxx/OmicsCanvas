#!/usr/bin/env Rscript

`%||%` <- function(a,b) if (is.null(a)) b else a
suppressPackageStartupMessages({ library(optparse); library(jsonlite); library(ggplot2) })
op <- parse_args(OptionParser(option_list=list(
  make_option('--input', type='character'), make_option('--params', type='character'), make_option('--output', type='character'))))
out <- op$output %||% getwd(); dir.create(out, recursive=TRUE, showWarnings=FALSE)
logmsg <- function(x) cat(sprintf('[%s] %s\n',format(Sys.time(),'%F %T'),x),file=file.path(out,'run.log'),append=TRUE)
fail <- function(e,d='',s='Check the input and params.json.') { dir.create(out,recursive=TRUE,showWarnings=FALSE); write(toJSON(list(error=e,detail=d,suggestion=s),auto_unbox=TRUE,pretty=TRUE),file.path(out,'error.json')); logmsg(paste(e,d)); quit(status=1) }
tryCatch({
  if (is.null(op$input)||!file.exists(op$input)) fail('Input file not found',as.character(op$input))
  if (is.null(op$params)||!file.exists(op$params)) fail('Params file not found',as.character(op$params))
  p <- fromJSON(op$params, simplifyVector=FALSE)
  # Accept either a flat params object or grouped schema objects.
  flat <- unlist(p, recursive=TRUE, use.names=TRUE); for (n in names(p)) if (is.list(p[[n]])) p <- c(p, p[[n]])
  get <- function(n,d=NULL) { x <- p[[n]]; if (is.null(x) && n %in% names(flat)) x <- flat[[n]]; if (is.null(x)) d else x }
  bool <- function(x,d=FALSE) { if(is.null(x))return(d); if(is.logical(x))return(isTRUE(x[1])); tolower(as.character(x[1])) %in% c('true','t','yes','y','1','on') }
  vec <- function(x) { if(is.null(x)) character() else trimws(as.character(unlist(x,use.names=FALSE))) }
  readtab <- function(f) { e<-tolower(tools::file_ext(f)); if(e=='csv') read.csv(f,check.names=FALSE,stringsAsFactors=FALSE) else if(e%in%c('tsv','txt')) read.delim(f,check.names=FALSE,stringsAsFactors=FALSE) else fail('Unsupported input file type',e,'Use CSV, TSV, or TXT.') }
  dat <- readtab(op$input); logmsg('Input loaded'); mode <- tolower(as.character(get('input_mode','raw'))[1]); method <- tolower(as.character(get('correlation_method','pearson'))[1]);
  if(!method%in%c('pearson','spearman','kendall')) fail('Invalid correlation method',method)
  inc <- vec(get('features_include')); exc <- vec(get('features_exclude')); rowsi <- vec(get('rows_include')); rowse <- vec(get('rows_exclude'))
  if(mode=='matrix') {
    if(ncol(dat)<2) fail('Matrix input must be square with row labels')
    labs <- as.character(dat[[1]]); mat <- as.matrix(data.frame(lapply(dat[-1],function(x) suppressWarnings(as.numeric(as.character(x)))))); colnames(mat)<-colnames(dat)[-1]; rownames(mat)<-labs
    if(nrow(mat)!=ncol(mat) || !setequal(rownames(mat),colnames(mat))) fail('Matrix input must be square with matching row and column labels')
    mat <- mat[match(colnames(mat),rownames(mat)),,drop=FALSE]; rownames(mat)<-colnames(mat)
    pv <- matrix(NA_real_,nrow(mat),ncol(mat),dimnames=dimnames(mat))
  } else {
    idcol <- as.character(get('id_column',''))[1]; if(!nzchar(idcol)) idcol <- names(dat)[1]
    if(!idcol%in%names(dat)) idcol <- ''
    candidates <- names(dat)[vapply(dat,function(x) all(is.na(x)|!is.na(suppressWarnings(as.numeric(as.character(x))))),logical(1))]
    features <- vec(get('feature_columns')); if(!length(features)) features <- setdiff(candidates,idcol)
    if(length(inc)) features <- intersect(features,inc); features <- setdiff(features,exc)
    if(!length(features)) fail('No numeric features selected','Select numeric feature columns.')
    x <- as.data.frame(lapply(dat[features],function(z)suppressWarnings(as.numeric(as.character(z))))); names(x)<-features
    keep <- rep(TRUE,nrow(x)); ids <- if(nzchar(idcol)) as.character(dat[[idcol]]) else as.character(seq_len(nrow(x)))
    if(length(rowsi)) keep <- keep & ids%in%rowsi; if(length(rowse)) keep <- keep & !ids%in%rowse; x<-x[keep,,drop=FALSE]
    if(nrow(x)<2) fail('Not enough rows after filtering','At least two observations are required.')
    mat <- cor(x,use=if(tolower(as.character(get('na_action','pairwise.complete.obs'))[1])=='complete.obs') 'complete.obs' else 'pairwise.complete.obs',method=method)
    pv <- matrix(NA_real_,ncol(x),ncol(x),dimnames=list(features,features))
    for(i in seq_len(ncol(x))) for(j in seq_len(ncol(x))) { ok <- complete.cases(x[,c(i,j)]); if(sum(ok)>2 && i!=j) pv[i,j] <- tryCatch(cor.test(x[ok,i],x[ok,j],method=method,exact=FALSE)$p.value,error=function(e)NA_real_) }
    diag(pv)<-0; diag(mat)<-1
  }
  # Selection and deterministic ordering are shared by every output.
  features <- rownames(mat); if(length(inc)) features<-intersect(features,inc); features<-setdiff(features,exc)
  fo <- vec(get('feature_order')); if(length(fo)) features<-c(intersect(fo,features),setdiff(features,fo))
  mat<-mat[features,features,drop=FALSE]; pv<-pv[features,features,drop=FALSE]
  if(bool(get('cluster_features',FALSE)) && length(features)>2) { dmat<-1-mat; dmat[!is.finite(dmat)]<-1; diag(dmat)<-0; d<-as.dist(dmat); hc<-hclust(d,method=as.character(get('cluster_method','complete'))[1]); features<-features[hc$order]; mat<-mat[features,features,drop=FALSE];pv<-pv[features,features,drop=FALSE] }
  if(bool(get('reverse_order',FALSE))) { features<-rev(features); mat<-mat[features,features,drop=FALSE];pv<-pv[features,features,drop=FALSE] }
  logmsg('Matrix calculated and ordered'); write.csv(mat,file.path(out,'correlation_matrix.csv')); write.csv(pv,file.path(out,'pvalue_matrix.csv')); write.csv(data.frame(feature=features),file.path(out,'selected_features.csv'),row.names=FALSE)
  n<-length(features); mm<-expand.grid(x=seq_len(n),y=seq_len(n)); mm$feature_x<-features[mm$x];mm$feature_y<-features[mm$y];mm$correlation<-as.vector(mat);mm$p_value<-as.vector(pv); logmsg('Long matrix prepared')
  cutoffs<-as.numeric(unlist(get('significance_cutoffs',c(.05,.01,.001)))); syms<-vec(get('significance_symbols',c('*','**','***'))); if(!length(syms))syms<-c('*','**','***')
  mm$significance<-vapply(mm$p_value,function(z) if(is.na(z)||!bool(get('significance_show',TRUE)))'' else if(length(cutoffs)>=3&&z<cutoffs[3])syms[min(3,length(syms))] else if(length(cutoffs)>=2&&z<cutoffs[2])syms[min(2,length(syms))] else if(z<cutoffs[1])syms[1] else '',character(1))
  tri<-tolower(as.character(get('triangle_mode','both'))[1]); lm<-tolower(as.character(get('lower_mode','tile'))[1]); um<-tolower(as.character(get('upper_mode','number'))[1]); logmsg('Significance prepared')
  if(tri=='mixed'){lm<-'tile';um<-'number'}; if(tri%in%c('circle','tile','square','number')){lm<-if(tri=='circle')'circle' else if(tri=='number')'number' else 'tile';um<-lm}
  mm$part<-ifelse(mm$y>mm$x,'lower',ifelse(mm$y<mm$x,'upper','diagonal')); mm$show<-mm$part=='diagonal' | (mm$part=='lower' & tri%in%c('both','lower','mixed')) | (mm$part=='upper' & tri%in%c('both','upper','mixed'))
  mm$mode<-ifelse(mm$part=='lower',lm,ifelse(mm$part=='upper',um,as.character(get('diagonal_mode','tile'))[1])); mm<-mm[mm$show,,drop=FALSE]; mm$label<-ifelse(mm$mode=='number' & bool(get('number_show',TRUE)),sprintf(paste0('%.',as.integer(get('number_digits',2)),'f'),mm$correlation),''); mm$label<-paste0(mm$label,mm$significance)
  mm$hover<-sprintf('%s × %s<br>Correlation: %s<br>P-value: %s<br>Significance: %s',mm$feature_y,mm$feature_x,formatC(mm$correlation,format='f',digits=as.integer(get('number_digits',2))),ifelse(is.na(mm$p_value),'NA',formatC(mm$p_value,format='g',digits=3)),ifelse(nzchar(mm$significance),mm$significance,'none'))
  low<-as.character(get('low_color','#3B4CC0')); mid<-as.character(get('mid_color','#F7F7F7')); high<-as.character(get('high_color','#B40426')); lim<-as.numeric(unlist(get('color_limits',c(-1,1)))); if(length(lim)!=2)lim<-c(-1,1)
  cell<-mm[mm$mode%in%c('tile','square','circle') & mm$part!='upper' | mm$mode%in%c('tile','square','circle') & mm$part=='upper',,drop=FALSE]
  g<-ggplot(mm,aes(x=x,y=y)); if(nrow(cell)) { tiles<-cell[cell$mode%in%c('tile','square'),,drop=FALSE]; circles<-cell[cell$mode=='circle',,drop=FALSE]; if(nrow(tiles)) g<-g+geom_tile(data=tiles,aes(fill=correlation),color=as.character(get('cell_border_color','#555555'))[1],linewidth=as.numeric(get('cell_border_width',.25)),alpha=as.numeric(get('cell_alpha',1))); if(nrow(circles))g<-g+geom_point(data=circles,aes(color=correlation),shape=16,size=as.numeric(get('cell_size',7))/3,alpha=as.numeric(get('cell_alpha',1))) }
  nums<-mm[nzchar(mm$label),,drop=FALSE]; if(nrow(nums))g<-g+geom_text(data=nums,aes(label=label),color=as.character(get('number_color','#111111'))[1],size=as.numeric(get('number_size',3)))
  g<-g+scale_fill_gradient2(low=low,mid=mid,high=high,limits=lim,na.value=as.character(get('na_color','#EEEEEE'))[1],name=as.character(get('legend_title','Correlation'))[1])+scale_color_gradient2(low=low,mid=mid,high=high,limits=lim,guide='none')+scale_x_continuous(breaks=seq_len(n),labels=features,expand=c(0,0))+scale_y_continuous(breaks=seq_len(n),labels=rev(features),trans='reverse',expand=c(0,0))+coord_fixed(ratio=as.numeric(get('aspect_ratio',1)))+theme_minimal(base_size=as.numeric(get('base_size',11)),base_family=as.character(get('font_family','sans'))[1])+theme(panel.grid=element_blank(),panel.background=element_rect(fill=as.character(get('panel_background','white'))[1],colour=NA),plot.background=element_rect(fill=as.character(get('plot_background','white'))[1],colour=NA),axis.text.x=element_text(angle=as.numeric(get('x_text_angle',45)),hjust=1,size=as.numeric(get('x_text_size',9)),colour=as.character(get('x_text_color','#222222'))[1]),axis.text.y=element_text(angle=as.numeric(get('y_text_angle',0)),size=as.numeric(get('y_text_size',9)),colour=as.character(get('y_text_color','#222222'))[1]),axis.title=element_text(size=10),legend.position=if(bool(get('legend_show',TRUE)))as.character(get('legend_position','right'))[1] else 'none')
  if(bool(get('title_show',TRUE)))g<-g+labs(title=as.character(get('title','Interactive Correlation Matrix'))[1],subtitle=if(bool(get('subtitle_show',TRUE)))as.character(get('subtitle',''))[1] else NULL,caption=if(bool(get('caption_show',FALSE)))as.character(get('caption',''))[1] else NULL,x=if(bool(get('x_title_show',TRUE)))as.character(get('xlab','Features'))[1] else NULL,y=if(bool(get('y_title_show',TRUE)))as.character(get('ylab','Features'))[1] else NULL)
  w<-as.numeric(get('width',8));h<-as.numeric(get('height',8)); dpi<-as.numeric(get('dpi',300)); if (!exists('omicscanvas_apply_theme')) { .oc_f <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[1]); .oc_rt <- file.path(dirname(normalizePath(.oc_f, mustWork = FALSE)), '..', '..', 'R', 'runtime', 'omicscanvas_theme.R'); if (!file.exists(.oc_rt)) .oc_rt <- file.path('R', 'runtime', 'omicscanvas_theme.R'); sys.source(.oc_rt, envir = globalenv()) }; g <- omicscanvas_apply_theme(g, p, only = c('grid_show', 'legend_text_size', 'legend_title_size', 'margin', 'panel_border_color', 'panel_border_show', 'panel_border_width', 'panel_spacing', 'subtitle_color', 'subtitle_face', 'subtitle_size', 'title_color', 'title_face', 'title_hjust', 'title_size')); for(ext in c('png','pdf','svg'))ggsave(file.path(out,paste0('result.',ext)),g,width=w,height=h,units='in',dpi=dpi)
  # Plotly heatmap uses the exact ordered/filtered matrix and hover text.
  if(requireNamespace('plotly',quietly=TRUE)&&requireNamespace('htmlwidgets',quietly=TRUE)) { z<-mat; z[lower.tri(z)]<-if(tri%in%c('upper','number'))NA else z[lower.tri(z)]; z[upper.tri(z)]<-if(tri%in%c('lower'))NA else z[upper.tri(z)]; ht<-matrix('',n,n,dimnames=dimnames(z)); for(i in seq_len(n))for(j in seq_len(n))ht[i,j]<-sprintf('%s × %s<br>Correlation: %.3f<br>P-value: %s',features[i],features[j],mat[i,j],ifelse(is.na(pv[i,j]),'NA',formatC(pv[i,j],format='g',digits=3))); pl<-plotly::plot_ly(x=features,y=features,z=z,type='heatmap',colorscale=list(list(0,low),list(.5,mid),list(1,high)),zmin=lim[1],zmax=lim[2],text=ht,hoverinfo='text',showscale=bool(get('legend_show',TRUE))); pl<-plotly::layout(pl,title=as.character(get('title','Interactive Correlation Matrix'))[1],xaxis=list(tickangle=as.numeric(get('x_text_angle',45))),yaxis=list(autorange='reversed',scaleanchor='x')); htmlwidgets::saveWidget(pl,file.path(out,'result.html'),selfcontained=TRUE) } else writeLines('<html><body>Plotly is unavailable.</body></html>',file.path(out,'result.html'))
  fig<-list(plugin='interactive_correlation_matrix',source_engine='ggplot2/plotly',input_mode=mode,correlation_method=method,features=features,n_features=n,triangle_mode=tri,outputs=list('result.svg','result.pdf','result.png','result.html','correlation_matrix.csv','pvalue_matrix.csv','selected_features.csv')); write(toJSON(fig,auto_unbox=TRUE,pretty=TRUE),file.path(out,'figure.json')); if(file.exists(file.path(out,'error.json')))unlink(file.path(out,'error.json')); logmsg(sprintf('Completed %d features in %s mode.',n,mode))
}, error=function(e) fail('Correlation matrix rendering failed',paste(conditionMessage(e),paste(capture.output(traceback()),collapse=' ')),'Check feature names, numeric values, and plotting parameters.'))
