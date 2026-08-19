customDotplot <- function(obj, assay = 'RNA', slot = "data", features = NULL,
                          clusters = "seurat_clusters", split.by = NULL, threshold = 0,
                          color.sep = FALSE, color.use = NULL, plot.cell = 'dot',
                          gene.order = NULL, cluster.order = NULL,
                          dot.shape = 21, dot.col = c("#456907", "white", "#990000"), 
                          rescale = FALSE, rescale.range = c(-2.5, 2.5),
                          dot.size = c(1, 6), label.size = 14, change.point = 'auto',
                          text.x.angle = 90, text.x.hjust = 1, text.x.vjust = 0,
                          tree.y = TRUE, tree.x = FALSE, tree.pos = c('left', 'bottom'),
                          same.pos.label = TRUE, size.width = 0.3,
                          bar.width = 4.5, plot.margin = c(1,1,1,1),
                          anno = FALSE,
                          aesGroName = 'cluster',
                          segWidth = 0.8,
                          lwd = 3,
                          textRot = 90,
                          base_size = 14,
                          hjust = 0,
                          legend.position = 'right',
                          bar.legendTitle = "Mean expression",
                          point.lengdTitle = "Expressed in group (%)",  ...){
  invisible(requireNamespace("ggplot2", quietly = TRUE))
  invisible(requireNamespace("data.table", quietly = TRUE))
  .color.code <- c(cols4all::c4a('palette36',36), cols4all::c4a('rainbow',23))
  .df <- tryCatch({
    ckSeu(obj)
    .marker.exp <- fetchFeasMeta(obj, features = c(features, clusters, split.by), assay = assay, slot = slot, ident.return = F)
    if(!is.null(split.by)) {
      .marker.exp[[clusters]] <- paste(.marker.exp[[clusters]], "(", .marker.exp[[split.by]],")", sep = '')
      .marker.exp[[split.by]] <- NULL
    }
    if ('cell.barcodes.selected' %in% colnames(.marker.exp)) .marker.exp <- .marker.exp[, -c('cell.barcodes.selected')]
    .marker.exp.meanpct <- avgPctExp(.marker.exp, cluster = clusters, threshold = threshold)
    .marker.exp.pct <- data.table::melt(.marker.exp.meanpct$pct, id.vars = clusters, variable.name = 'gene', value.name = 'pct.exp') 
    .marker.exp.mean.scale <- NULL
    .marker.exp.mean <- data.table::melt(.marker.exp.meanpct$mean, id.vars = clusters, variable.name = 'gene', value.name = 'avg.exp')
    .df <- dplyr::full_join(.marker.exp.mean, .marker.exp.pct, by = c(clusters, 'gene'))
  }, error = function(e) {
    .df <- if (is.data.frame(obj)) return(obj) else return(NULL)
  })
  if (is.null(.df)) stop("No data to plot")
  .df$id <- .df[[clusters]]
  .idx <- which(.df$gene %in% features)
  .df <- .df[.idx, ]
  if(isTRUE(rescale)) {
    .avg.gene.df <- dcast(.df, id ~ gene, value.var = 'avg.exp')
    .marker.exp.mean.scale <- .avg.gene.df[, lapply(.SD, function(x) scales::rescale(x, to = rescale.range)), 
                                           .SDcols= as.character(unique(.df$gene))]
    .marker.exp.mean.scale$id <- .avg.gene.df$id
    .marker.exp.mean.scaled <- data.table::melt(.marker.exp.mean.scale, 
                                                id.vars = 'id', 
                                                variable.name = 'gene', 
                                                value.name = 'avg.exp.scaled')
    .df$avg.exp.scaled <- .marker.exp.mean.scaled$avg.exp.scaled
  } else {
    .df$avg.exp.scaled <- log1p(.df$avg.exp)
  }
  .groups <- unique(.df$id)
  if (isTRUE(color.sep)) {
    if (is.null(color.use)) {
      .color.use <- .color.code[seq_along(.groups)]
    } else {
      if (length(color.use) != length(.groups)) {
        stop("The length of color.use should be the same as the number of groups")
      }
      .color.use <- color.use
    }
  }
  .df$gene <- factor(.df$gene,levels = unique(.df$gene))
  if(all(unique(gene.order) %in% .df$gene)){
    .gene.in <- unique(gene.order)
    .gene.out <- unique(setdiff(unique(.df$gene), gene.order))
    .gene.order <- c(.gene.in, .gene.out)
    .df$gene <- factor(.df$gene,levels = unique(.gene.order))
  } else {
    stop("gene.order should be a subset OR the whole of the features")
  }
  
  if(!is.null(cluster.order)){
    .df$id <- factor(.df$id,levels = unique(cluster.order))
  }
  
  if(!is.null(split.by)){
    .df$group <- sapply(strsplit(as.character(.df$id),split = '\\(|\\)'),'[',2)
  }
  if (max(.df$pct.exp) <=1) .df$pct.exp <- .df$pct.exp * 100
  #plot
  .pmain <- ggplot(.df, aes(x = gene, y = id)) +
    theme_bw(base_size = base_size) +
    xlab('') + ggplot2::ylab('') +
    coord_fixed(clip = "off") +
    theme(plot.margin = margin(t = plot.margin[1],r = plot.margin[2],
                               b = plot.margin[3],l = plot.margin[4],
                               unit = "cm"),
          axis.text = element_text(color = "black"),
          legend.direction = "horizontal",
          axis.text.x = element_text(angle = text.x.angle, 
                                     hjust = text.x.hjust,
                                     vjust = text.x.vjust),
          legend.position = legend.position)
  
  .colorbar.layer <- ggplot2::guides(fill = guide_colorbar(title = bar.legendTitle,
                                                           title.position = "top",
                                                           title.hjust = 0.5,
                                                           barwidth = unit(bar.width,"cm"),
                                                           frame.colour = "black",
                                                           frame.linewidth = 0.8,
                                                           ticks.colour = "black"))
  # point size layer
  .point.layer <- ggplot2::guides(size = guide_legend(title = point.lengdTitle,
                                                      title.position = "top",
                                                      title.hjust = 0.5,
                                                      label.position = "bottom",
                                                      override.aes = list(color = "black",
                                                                          fill = "grey50"),
                                                      keywidth = ggplot2::unit(size.width,"cm")))
  
  
  if(isTRUE(color.sep)){
    .pmain <- .pmain +
      ggplot2::scale_fill_manual(values = .color.code[1:length(.groups)])
  }else {
    if (isTRUE(rescale)){
      if (change.point == 'auto'){
        .change.point <- mean(rescale.range)
      } else {
        if (is.numeric(change.point)){
          .change.point <- change.point
        } else {
          stop("change.point should be a numeric value")
        }
      }
      .pmain <- .pmain + 
        scale_fill_gradient2(low = dot.col[1],
                             mid = dot.col[2],
                             high = dot.col[3],
                             midpoint = .change.point)
    } else {
      .pmain <- .pmain +
        ggplot2::scale_fill_gradient(low = dot.col[2], high = dot.col[3])
    }
  }
  
  # add point or tile layer
  if(plot.cell == 'dot'){
    if(isFALSE(color.sep)){
      .pmain <- .pmain + geom_point(aes(fill = avg.exp, size = pct.exp),
                                    color = "black", shape = dot.shape) +
        .colorbar.layer +
        .point.layer +
        ggplot2::scale_size(range = dot.size)
    }else{
      .pmain <- .pmain +
        ggplot2::geom_point(ggplot2::aes(fill = id, size = pct.exp),
                            color = "black",shape = dot.shape) +
        .point.layer +
        ggplot2::scale_size(range = dot.size)
    }
  } else if(plot.cell == 'tile'){
    if(isFALSE(color.sep)){
      .pmain <- .pmain +
        ggplot2::geom_tile(ggplot2::aes(fill = avg.exp),
                           color = "black") +
        .colorbar.layer
    }else{
      pmain <- pmain +
        ggplot2::geom_tile(ggplot2::aes(fill = group),
                           color = "black") +
        .colorbar.layer
    }
  } else {
    stop("plot.cell should be either 'dot' or 'tile'")
  }
  # long to wide matrix
  .plot.matrix <- .df %>%
    reshape2::dcast(id~gene, value.var = "avg.exp.scaled")
  
  rownames(.plot.matrix) <- .plot.matrix$id
  .plot.matrix <- .plot.matrix %>% dplyr::select(-id)
  
  # add ytree
  if(isTRUE(tree.y)){
    # whether put label same with tree
    if(isFALSE(same.pos.label)){
      .pytree <- .pmain +
        ggh4x::scale_y_dendrogram(hclust = stats::hclust(stats::dist(.plot.matrix)),
                                  position = tree.pos[1],
                                  labels = NULL) +
        ggplot2::guides(y.sec = ggh4x::guide_axis_manual(labels = function(x) {x}))
    }else{
      .pytree <- .pmain +
        ggh4x::scale_y_dendrogram(hclust = stats::hclust(stats::dist(.plot.matrix)),
                                  position = tree.pos[1])
    }
  }else{
    .pytree <- .pmain
  }
  
  # add xtree
  if(isTRUE(tree.x)){
    # whether put label same with tree
    if(isFALSE(same.pos.label)){
      .pxtree <- .pytree +
        ggh4x::scale_x_dendrogram(hclust = stats::hclust(stats::dist(t(.plot.matrix))),
                                  position = tree.pos[2],
                                  labels = NULL) +
        ggplot2::guides(x.sec = ggh4x::guide_axis_manual(labels = function(x){x}))
    }else{
      .pxtree <- .pytree +
        ggh4x::scale_x_dendrogram(hclust = stats::hclust(stats::dist(t(.plot.matrix))),
                                  position = tree.pos[2])
    }
  }else{
    .pxtree <- .pytree
  }
  return(.pxtree)
}



####need more modification to fit bvars
Balloonplot.TxtNear <- function(df, xvars = NULL, yvars = NULL, vvars = NULL, fvars = NULL, 
                                bvars = NULL, title = '', subtitle = '', caption = ''){
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  .df <- ckCols(df, c(xvars, yvars, fvars, vvars, bvars), col.return = T)
  .row.var <- parse_expr(yvars)
  .col.var <- parse_expr(xvars)
  .df <- .df %>% group_by(!!.row.var) %>% 
    mutate(row = cur_group_id()) %>% ungroup() %>%
    group_by(!!.col.var) %>% mutate(col = cur_group_id()) %>% ungroup()
  .axis.x <- .df %>% arrange(col) %>% pull(!!.col.var) %>% unique()
  .axis.y <- .df %>% group_by(row) %>% pull(!!.row.var) %>% unique()  
  ggplot(.df, aes(x = factor(col), y = factor(row), fill = .data[[fvars]], size = .data[[vvars]], alpha = .data[[vvars]])) +
    geom_point(aes(color = .data[[bvars]], shape = .data[[fvars]]), shape = 21, stroke = 2) +  
    geom_text(aes(label = .data[[vvars]], x = col + 0.15), alpha = 1.0, size = 3) +  
    scale_alpha_continuous(range=c(0.3, 0.7)) + 
    ######modify here
    scale_color_manual(values = c("sig" = "red", "non" = "black")) + 
    ######
  scale_size_area(max_size = 5) +
    scale_x_discrete(breaks=1:length(.axis.x), labels = .axis.x, position='top') +  
    scale_y_discrete(breaks=1:length(.axis.y), labels= .axis.y) + 
    ggtitle(title, subtitle = subtitle) +
    labs(caption = caption) +
    theme_bw() +
    theme(axis.line = element_blank(),            
          axis.title = element_blank(),          
          panel.border = element_blank(),        
          panel.grid.major.x = element_blank(),  
          panel.grid.minor.x = element_blank())  
}
