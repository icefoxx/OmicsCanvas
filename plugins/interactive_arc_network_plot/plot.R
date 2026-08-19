#!/usr/bin/env Rscript
suppressPackageStartupMessages({library(optparse); library(jsonlite); library(ggplot2); library(magrittr)})

op <- parse_args(OptionParser(option_list=list(
  make_option('--input', type='character'), make_option('--params', type='character'),
  make_option('--output', type='character'), make_option('--nodes', type='character', default=NULL))))
`%||%` <- function(a,b) if(is.null(a) || length(a)==0 || all(is.na(a))) b else a
out <- op$output %||% 'output'; dir.create(out, recursive=TRUE, showWarnings=FALSE)
fail <- function(message, detail='') {
  writeLines(toJSON(list(error=message, detail=detail, suggestion='Check input columns and params.json.'), auto_unbox=TRUE, pretty=TRUE), file.path(out,'error.json'))
  quit(status=1)
}
logmsg <- function(x) cat(sprintf('[%s] %s\n', format(Sys.time(), '%F %T'), x), file=file.path(out,'run.log'), append=TRUE)
readtab <- function(f) { if(is.null(f) || !file.exists(f)) stop('Input file not found: ', f); if(tolower(tools::file_ext(f))=='csv') read.csv(f, check.names=FALSE, stringsAsFactors=FALSE) else read.delim(f, check.names=FALSE, stringsAsFactors=FALSE) }
getp <- function(p, n, d=NULL) if(!is.null(p[[n]]) && length(p[[n]])) p[[n]] else d
scalar <- function(p,n,d=NULL) as.character(getp(p,n,d)[1])
num <- function(p,n,d) { z <- suppressWarnings(as.numeric(getp(p,n,d)[1])); if(!length(z) || is.na(z)) d else z }
bool <- function(p,n,d=FALSE) { z <- getp(p,n,d); if(is.logical(z)) isTRUE(z[1]) else tolower(as.character(z[1])) %in% c('true','t','yes','y','1','on') }
vec <- function(x) { if(is.null(x)) return(character()); z <- unlist(x, use.names=FALSE); if(length(z)==1 && grepl(',',z,fixed=TRUE)) z <- strsplit(z,',',fixed=TRUE)[[1]]; z <- trimws(as.character(z)); z[nzchar(z)] }
named <- function(x) { if(is.null(x)) return(character()); z <- unlist(x); if(is.null(names(z))) character() else setNames(as.character(z),names(z)) }
palette_for <- function(x, keys) { z <- named(x); pal <- c('#3B82A0','#E07A5F','#81B29A','#F2CC8F','#7B6D8D','#D1495B','#4D908E','#F9844A'); out <- setNames(rep(pal,length.out=length(keys)),keys); if(length(z)) out[names(z)[names(z)%in%keys]] <- z[names(z)[names(z)%in%keys]]; out }

tryCatch({
  unlink(file.path(out,'error.json')); unlink(file.path(out,c('result.svg','result.pdf','result.png','result.html','figure.json','nodes_used.csv','edges_used.csv','selected_nodes.csv'))); writeLines('',file.path(out,'run.log'))
  p <- if(!is.null(op$params) && file.exists(op$params)) fromJSON(op$params, simplifyVector=FALSE) else list()
  e0 <- readtab(op$input); sc <- scalar(p,'source_column','source'); tc <- scalar(p,'target_column','target')
  if(!all(c(sc,tc) %in% names(e0))) stop('Missing edge columns: ', paste(setdiff(c(sc,tc),names(e0)),collapse=', '))
  wc <- scalar(p,'weight_column','weight'); if(!wc %in% names(e0)) wc <- NULL
  edge <- data.frame(source=as.character(e0[[sc]]), target=as.character(e0[[tc]]), stringsAsFactors=FALSE)
  edge$weight <- if(is.null(wc)) 1 else suppressWarnings(as.numeric(e0[[wc]])); edge$weight[!is.finite(edge$weight)] <- 1
  copycol <- function(name, fallback='') if(name %in% names(e0)) as.character(e0[[name]]) else rep(fallback,nrow(e0))
  edge$group <- copycol(scalar(p,'group_column','group'),'Edges'); edge$direction <- copycol('direction',''); edge$color <- copycol('color',''); edge$label <- copycol('label','')
  wmin <- num(p,'edge_weight_min',-Inf); wmax <- num(p,'edge_weight_max',Inf); edge <- edge[edge$weight>=wmin & edge$weight<=wmax,,drop=FALSE]
  if(!bool(p,'self_loop_show',TRUE)) edge <- edge[edge$source != edge$target,,drop=FALSE]
  if(bool(p,'deduplicate_edges',FALSE) && nrow(edge)) { key <- if(bool(p,'directed',FALSE)) paste(edge$source,edge$target,sep='\r') else paste(pmin(edge$source,edge$target),pmax(edge$source,edge$target),sep='\r'); edge <- edge[!duplicated(key),,drop=FALSE] }
  nodefile <- if(!is.null(op$nodes)) readtab(op$nodes) else NULL; nid <- scalar(p,'node_id_column','id'); nlabel <- scalar(p,'node_label_column','label')
  ids <- unique(c(edge$source,edge$target)); if(!is.null(nodefile) && nid %in% names(nodefile)) ids <- unique(c(ids,as.character(nodefile[[nid]])))
  orderp <- vec(getp(p,'node_order',NULL)); ordercol <- scalar(p,'order_column','order'); orderby <- scalar(p,'order_by','input')
  if(!length(orderp) && !is.null(nodefile) && nid %in% names(nodefile) && ordercol %in% names(nodefile)) { oo <- suppressWarnings(as.numeric(nodefile[[ordercol]])); orderp <- as.character(nodefile[[nid]][order(oo, na.last=TRUE)]) }
  if(length(orderp)) ids <- c(orderp[orderp%in%ids],setdiff(ids,orderp))
  if(orderby=='label' && !is.null(nodefile) && nlabel %in% names(nodefile)) { q <- as.character(nodefile[[nlabel]]); ids <- ids[order(q[match(ids,as.character(nodefile[[nid]]))],ids,na.last=TRUE)] }
  if(orderby=='degree') { deg <- table(c(edge$source,edge$target)); ids <- ids[order(-as.numeric(deg[ids]),ids,na.last=TRUE)] }
  inc <- vec(getp(p,'nodes_include',NULL)); exc <- vec(getp(p,'nodes_exclude',NULL)); if(length(inc)) ids <- ids[ids%in%inc]; if(length(exc)) ids <- ids[!ids%in%exc]
  edge <- edge[edge$source%in%ids & edge$target%in%ids,,drop=FALSE]
  n <- data.frame(id=ids,label=ids,group='Network',size=1,color=NA_character_,stringsAsFactors=FALSE)
  if(!is.null(nodefile) && nid %in% names(nodefile)) for(i in seq_len(nrow(n))) { j <- match(n$id[i],as.character(nodefile[[nid]])); if(!is.na(j)) { if(nlabel%in%names(nodefile)) n$label[i] <- as.character(nodefile[[nlabel]][j]); for(k in c('group','size','color')) if(k%in%names(nodefile)) n[[k]][i] <- nodefile[[k]][j] } }
  n$label[is.na(n$label)|!nzchar(n$label)] <- n$id; n$group[is.na(n$group)|!nzchar(n$group)] <- 'Network'; n$size <- suppressWarnings(as.numeric(n$size)); n$size[!is.finite(n$size)] <- num(p,'node_size',3)
  groups <- unique(as.character(n$group)); gcols <- palette_for(getp(p,'node_colors',NULL),groups); n$color <- ifelse(is.na(n$color)|!nzchar(n$color),unname(gcols[as.character(n$group)]),as.character(n$color)); nc <- scalar(p,'node_color',''); if(nzchar(nc)) n$color <- nc
  nmap <- setNames(seq_len(nrow(n)),n$id); edge$si <- unname(nmap[edge$source]); edge$ti <- unname(nmap[edge$target]); edge$distance <- abs(edge$ti-edge$si)
  if(bool(p,'sort_edges',FALSE) && nrow(edge)) edge <- edge[order(edge$distance,-edge$weight,edge$source,edge$target),,drop=FALSE]
  if(scalar(p,'layout','baseline')=='circle') { ang <- seq(pi/2,pi/2+2*pi,length.out=nrow(n)+1)[-1]; n$x <- cos(ang); n$y <- sin(ang); baseline <- 0 } else { n$x <- seq_len(nrow(n)); n$y <- num(p,'baseline_y',0); baseline <- num(p,'baseline_y',0) }
  rng <- range(edge$weight,finite=TRUE); if(!length(rng)||!all(is.finite(rng))) rng <- c(1,1); normw <- if(diff(rng)==0) rep(.5,nrow(edge)) else (edge$weight-rng[1])/diff(rng)
  hscale <- num(p,'arc_height_scale',1); hmin <- num(p,'arc_height_min',.15); hmax <- num(p,'arc_height_max',max(1,nrow(n)*.15)); by <- scalar(p,'arc_height_by','distance'); dnorm <- if(nrow(n)>1) edge$distance/max(1,nrow(n)-1) else rep(0,nrow(edge)); hn <- if(by=='weight') normw else if(by=='constant') rep(.5,nrow(edge)) else dnorm; edge$height <- pmin(hmax,pmax(hmin,hmin+(hmax-hmin)*hn*hscale)); edge$height[edge$source==edge$target] <- num(p,'loop_height',hmax*.65)
  direction <- scalar(p,'arc_direction','upward'); if(direction=='downward') edge$side <- -1 else if(direction=='both') edge$side <- ifelse(seq_len(nrow(edge))%%2==0,-1,1) else edge$side <- 1
  edge$offset <- ifelse(edge$source==edge$target, ifelse(seq_len(nrow(edge))%%2==0,-1,1)*num(p,'parallel_edge_offset',.12), 0)
  bezier <- function(a,b,h,side,offset=0) { t <- seq(0,1,length.out=31); x <- (1-t)*a + t*b; y <- baseline + side*4*h*t*(1-t); if(a==b) x <- a + offset*sin(pi*t); data.frame(x=x,y=y) }
  geom <- do.call(rbind,lapply(seq_len(nrow(edge)),function(i) { z <- bezier(n$x[edge$si[i]],n$x[edge$ti[i]],edge$height[i],edge$side[i],edge$offset[i]); z$edge <- i; z }))
  if(is.null(geom)) geom <- data.frame(x=numeric(),y=numeric(),edge=integer())
  edge$color[!nzchar(edge$color)] <- scalar(p,'edge_color','#718096'); ecol <- named(getp(p,'edge_colors',NULL)); if(length(ecol)) edge$color <- ifelse(edge$group%in%names(ecol),ecol[edge$group],edge$color)
  edge$width <- num(p,'edge_width',.45); er <- getp(p,'edge_width_range',c(.3,2.5)); er <- as.numeric(unlist(er)); if(length(er)>=2 && nrow(edge)) edge$width <- er[1]+(er[2]-er[1])*normw
  write.csv(n,file.path(out,'nodes_used.csv'),row.names=FALSE); write.csv(edge,file.path(out,'edges_used.csv'),row.names=FALSE)
  xr <- getp(p,'x_limits',NULL); yr <- getp(p,'y_limits',NULL); xr <- if(is.null(xr)) range(c(n$x,geom$x),finite=TRUE)+c(-.8,.8) else as.numeric(unlist(xr)); yr <- if(is.null(yr)) range(c(n$y,geom$y,-.5),finite=TRUE)+c(-.2,.2) else as.numeric(unlist(yr));
  W <- num(p,'width',12); H <- num(p,'height',7); alpha <- num(p,'edge_alpha',.55); node_range <- as.numeric(unlist(getp(p,'node_size_range',c(2,7)))); ns <- if(diff(range(n$size))==0) mean(node_range) else node_range[1]+(node_range[2]-node_range[1])*(n$size-min(n$size))/diff(range(n$size))
  q <- ggplot() + geom_path(data=geom,aes(x=x,y=y,group=edge),linewidth=edge$width[geom$edge],colour=edge$color[geom$edge],alpha=alpha,lineend='round')
  if(bool(p,'baseline_show',TRUE) && scalar(p,'layout','baseline')=='baseline') q <- q + geom_hline(yintercept=baseline,colour=scalar(p,'baseline_color','#9CA3AF'),linewidth=num(p,'baseline_width',.35))
  if(bool(p,'node_show',TRUE)) q <- q + geom_point(data=n,aes(x=x,y=y),size=ns,colour=scalar(p,'node_stroke','#FFFFFF'),stroke=num(p,'node_stroke_width',.35),fill=n$color,alpha=num(p,'node_alpha',1),shape=21)
  if(bool(p,'node_label_show',TRUE)) q <- q + geom_text(data=n,aes(x=x,y=y,label=label),angle=num(p,'node_label_angle',60),hjust=num(p,'node_label_hjust',1),vjust=num(p,'node_label_vjust',1.1),nudge_y=-num(p,'node_label_offset',.12),size=num(p,'node_label_size',3)/ggplot2::.pt,colour=scalar(p,'node_label_color','#202124'),family=scalar(p,'font_family','sans'))
  q <- q + coord_cartesian(xlim=xr,ylim=yr,expand=FALSE) + theme_minimal(base_size=num(p,'base_size',11),base_family=scalar(p,'font_family','sans')) + theme(panel.background=element_rect(fill=scalar(p,'panel_background','#FFFFFF'),colour=NA),plot.background=element_rect(fill=scalar(p,'plot_background','#FFFFFF'),colour=NA),panel.grid=if(bool(p,'grid_show',FALSE)) element_line(colour=scalar(p,'grid_color','#E5E7EB')) else element_blank(),plot.title=element_text(size=num(p,'title_size',16),colour=scalar(p,'title_color','#222222'),face=scalar(p,'title_face','plain'),hjust=num(p,'title_hjust',.5))) + labs(title=if(bool(p,'title_show',TRUE)) scalar(p,'title','') else NULL,subtitle=scalar(p,'subtitle',''),caption=scalar(p,'caption',''),x=scalar(p,'xlab',''),y=scalar(p,'ylab',''))
  ggsave(file.path(out,'result.svg'),q,width=W,height=H); ggsave(file.path(out,'result.pdf'),q,width=W,height=H); ggsave(file.path(out,'result.png'),q,width=W,height=H,dpi=num(p,'dpi',150))
  if(bool(p,'interactive',TRUE) && requireNamespace('plotly',quietly=TRUE)) { fig <- plotly::plot_ly(); for(i in seq_len(nrow(edge))) { z <- geom[geom$edge==i,,drop=FALSE]; tip <- paste(edge$source[i],edge$target[i],sep=' -> '); if(nzchar(edge$label[i])) tip <- paste(tip,edge$label[i],sep='<br>'); fig <- fig %>% plotly::add_trace(x=z$x,y=z$y,type='scatter',mode='lines',name=edge$group[i],line=list(color=edge$color[i],width=max(1,edge$width[i]*2)),opacity=alpha,hoverinfo='text',text=paste0(tip,'<br>weight: ',signif(edge$weight[i],4))) }; fig <- fig %>% plotly::add_trace(x=n$x,y=n$y,type='scatter',mode='markers+text',text=if(bool(p,'node_label_show',TRUE)) n$label else NULL,textposition='bottom center',marker=list(size=pmax(4,ns*2.2),color=n$color,line=list(color=scalar(p,'node_stroke','#FFFFFF'),width=num(p,'node_stroke_width',.35))),customdata=n$id,hovertemplate=paste0('<b>%{text}</b><br>id: %{customdata}<extra></extra>'),name='Nodes') %>% plotly::layout(title=scalar(p,'title',''),xaxis=list(range=xr,showgrid=bool(p,'grid_show',FALSE),title=scalar(p,'xlab',''),showticklabels=bool(p,'x_axis_show',FALSE)),yaxis=list(range=yr,showgrid=bool(p,'grid_show',FALSE),title=scalar(p,'ylab',''),showticklabels=bool(p,'y_axis_show',FALSE)),plot_bgcolor=scalar(p,'panel_background','#FFFFFF'),paper_bgcolor=scalar(p,'plot_background','#FFFFFF'),dragmode=if(bool(p,'selectable',FALSE)) 'select' else if(bool(p,'zoom',TRUE)) 'zoom' else FALSE,showlegend=bool(p,'edge_legend_show',FALSE)); htmlwidgets::saveWidget(fig,file.path(out,'result.html'),selfcontained=TRUE) } else writeLines('<html><body><p>Interactive arc network requires plotly.</p></body></html>',file.path(out,'result.html'))
  metadata <- list(plugin='interactive_arc_network_plot',engine='ggplot2 + plotly',node_order=n$id,node_count=nrow(n),edge_count=nrow(edge),groups=setNames(as.list(gcols),groups),geometry=list(layout=scalar(p,'layout','baseline'),arc_direction=direction,arc_height_by=by,arc_height_scale=hscale,arc_height_min=hmin,arc_height_max=hmax,baseline_y=baseline,sampled_points=31),ranges=list(x=xr,y=yr),outputs=list('result.svg','result.pdf','result.png','result.html','figure.json','run.log','nodes_used.csv','edges_used.csv'),limitations=c('Static geometry is deterministic; HTML selection does not mutate edge geometry.','Circle layout uses the same quadratic arc model around circular node positions.'))
  writeLines(toJSON(metadata,auto_unbox=TRUE,pretty=TRUE),file.path(out,'figure.json')); logmsg(sprintf('Completed arc network plot: %d nodes, %d edges',nrow(n),nrow(edge)))
}, error=function(e) fail('Interactive arc network plot failed',conditionMessage(e)))
