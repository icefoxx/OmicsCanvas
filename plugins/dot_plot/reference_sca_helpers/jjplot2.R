# CLI compatibility patches for OmicsCanvas dot_plot plugin.
# These definitions make jjDotPlot1 usable outside the SCA Shiny environment.
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

PercentAbove <- function(x, threshold = 0) {
  Seurat::PercentAbove(x, threshold = threshold)
}

jjDotPlot1 <- function(
    object = NULL,
    assay = NULL,
    slot = "data",
    id = "seurat_clusters",
    split.by = NULL,
    split.by.aesGroup = FALSE,
    gene = NULL,
    markerGene = NULL,
    gene.order = NULL,
    cluster.order = NULL,
    point.geom = TRUE,
    point.shape = 21,
    tile.geom = FALSE,
    dot.col = c("white", "#990000"),
    midpoint = 0.5,
    scale = TRUE,
    col.min = -2.5,
    col.max = 2.5,
    rescale = FALSE,
    rescale.min = 0,
    rescale.max = 1,
    dot.min = 1,
    dot.max = 6,
    base_size = 14,
    x.text.angle = 90,
    x.text.hjust = 1,
    x.text.vjust = 0,
    coord.fixed = TRUE,
    coord.ratio = 1,
    aspect.ratio = NULL,
    clip = "off",
    ytree = TRUE,
    xtree = FALSE,
    tree.pos = NULL,
    same.pos.label = FALSE,
    size.width = 0.3,
    bar.width = 4.5,
    plot.margin = c(1, 1, 1, 1),
    anno = FALSE,
    aesGroName = "cluster",
    segWidth = 0.8,
    lwd = 3,
    textRot = 90,
    textSize = 14,
    hjust = 0,
    legend.position = "right",
    bar.legendTitle = "Mean expression \n in group",
    point.legendTitle = "Fraction of cells \n in group (%)",
    ...) {
  .input.is.df <- is.data.frame(object) || data.table::is.data.table(object)

  if (is.null(gene) == is.null(markerGene)) {
    stop("Please supply exactly one of `gene` or `markerGene`.")
  }

  gene.use <- if (!is.null(markerGene)) unique(markerGene$gene) else unique(gene)
  if (length(gene.use) == 0) {
    stop("No genes were supplied to `jjDotPlot1()`.")
  }

  if (.input.is.df) {
    object <- as.data.frame(object, stringsAsFactors = FALSE)
    required.cols <- unique(c(gene.use, id, split.by))
    missing.cols <- setdiff(required.cols, colnames(object))
    if (length(missing.cols) > 0) {
      stop(
        sprintf(
          "Missing required columns in data frame input: %s",
          paste(missing.cols, collapse = ", ")
        )
      )
    }

    geneExp <- object[, gene.use, drop = FALSE]
    if (is.null(split.by)) {
      geneExp$id <- object[[id]]
    } else {
      geneExp$id <- paste(
        object[[id]],
        " (", object[[split.by]], ")",
        sep = ""
      )
    }
  } else {
    assay <- assay %||% Seurat::DefaultAssay(object = object)
    Seurat::DefaultAssay(object = object) <- assay

    geneExp <- Seurat::FetchData(
      object = object,
      vars = gene.use,
      slot = slot
    )

    if (is.null(split.by)) {
      if (id %in% colnames(object@meta.data)) {
        geneExp$id <- object@meta.data[[id]]
      } else {
        geneExp$id <- Seurat::Idents(object)
      }
    } else {
      if (!split.by %in% colnames(object@meta.data)) {
        stop(sprintf("Column `%s` was not found in `object@meta.data`.", split.by))
      }

      if (id %in% colnames(object@meta.data)) {
        geneExp$id <- paste(
          object@meta.data[[id]],
          " (", object@meta.data[[split.by]], ")",
          sep = ""
        )
      } else {
        geneExp$id <- paste(
          Seurat::Idents(object),
          " (", object@meta.data[[split.by]], ")",
          sep = ""
        )
      }
    }
  }
  
  # calculate mean expressions and percent expression
  data.plot <- lapply(
    X = unique(x = geneExp$id),
    FUN = function(ident) {
      data.use <- geneExp[geneExp$id == ident, 1:(ncol(x = geneExp) - 1), drop = FALSE]
      avg.exp <- apply(
        X = data.use,
        MARGIN = 2,
        FUN = function(x) {
          return(mean(x = expm1(x = x)))
        }
      )
      pct.exp <- apply(X = data.use, MARGIN = 2, FUN = PercentAbove, threshold = 0)
      
      res <- data.frame(id = ident, avg.exp = avg.exp, pct.exp = pct.exp * 100)
      res$gene <- rownames(res)
      return(res)
    }
  ) %>%
    do.call("rbind", .) %>%
    data.frame()

  # scale mean expressions
  if (scale == TRUE) {
    purrr::map_df(unique(data.plot$gene), function(x) {
      tmp <- data.plot %>%
        dplyr::filter(gene == x)
      
      # scale value cross groups
      if (rescale == TRUE) {
        avg.exp.scale <- tmp %>%
          dplyr::select(avg.exp) %>%
          scale(.) %>%
          scales::rescale(., to = c(rescale.min, rescale.max))
      } else {
        avg.exp.scale <- tmp %>%
          dplyr::select(avg.exp) %>%
          scale(.) %>%
          Seurat::MinMax(., min = col.min, max = col.max)
      }
      
      # add scaled exp
      tmp$avg.exp.scaled <- as.numeric(avg.exp.scale)
      return(tmp)
    }) -> data.plot
  } else {
    # no scale or rescale using log1p
    data.plot$avg.exp.scaled <- log1p(data.plot$avg.exp)
  }
  
  if (!is.null(markerGene)) {
    celltype_info <- markerGene
    
    # add celltype
    purrr::map_df(seq_len(nrow(data.plot)), function(x) {
      tmp <- data.plot[x, ]
      tmp$celltype <- celltype_info[which(celltype_info$gene == tmp$gene), aesGroName][[1]]
      return(tmp)
    }) -> data.plot.res
    
    # arrange cell type
    data.plot.res <- data.plot.res %>%
      dplyr::arrange(celltype)
  } else {
    data.plot.res <- data.plot
  }
  
  # gene order
  if (is.null(gene.order)) {
    data.plot.res$gene <- factor(data.plot.res$gene, levels = unique(data.plot.res$gene))
  } else {
    data.plot.res$gene <- factor(data.plot.res$gene, levels = unique(gene.order))
  }
  
  # cluster order
  if (!is.null(cluster.order)) {
    data.plot.res$id <- factor(data.plot.res$id, levels = unique(cluster.order))
  }
  
  # add group info
  if (!is.null(split.by)) {
    data.plot.res$group <- sapply(strsplit(as.character(data.plot.res$id), split = "\\(|\\)"), "[", 2)
  }
  
  # ============================================================================
  # plot
  pmain <- ggplot2::ggplot(
    data.plot.res,
    ggplot2::aes(x = gene, y = id)
  ) +
    ggplot2::theme_bw(base_size = base_size) +
    ggplot2::xlab("") +
    ggplot2::ylab("") +
    ggplot2::theme(
      plot.margin = ggplot2::margin(
        t = plot.margin[1], r = plot.margin[2],
        b = plot.margin[3], l = plot.margin[4],
        unit = "cm"
      ),
      axis.text = ggplot2::element_text(color = "black"),
      legend.direction = "horizontal",
      axis.text.x = ggplot2::element_text(
        angle = x.text.angle,
        hjust = x.text.hjust,
        vjust = x.text.vjust
      ),
      aspect.ratio = aspect.ratio,
      legend.position = legend.position
    )

  if (isTRUE(coord.fixed)) {
    pmain <- pmain + ggplot2::coord_fixed(ratio = coord.ratio, clip = clip)
  } else {
    pmain <- pmain + ggplot2::coord_cartesian(clip = clip)
  }
  
  # colorbar layer
  colorbar.layer <- ggplot2::guides(
    fill = ggplot2::guide_colorbar(
      title = bar.legendTitle,
      title.position = "top",
      title.hjust = 0.5,
      barwidth = unit(bar.width, "cm"),
      frame.colour = "black",
      frame.linewidth = 0.8,
      ticks.colour = "black"
    )
  )
  # point size layer
  point.layer <- ggplot2::guides(
    size = ggplot2::guide_legend(
      title = point.legendTitle,
      title.position = "top",
      title.hjust = 0.5,
      label.position = "bottom",
      override.aes = list(
        color = "black",
        fill = "grey50"
      ),
      keywidth = ggplot2::unit(size.width, "cm")
    )
  )
  
  # change colors
  if (is.null(split.by)) {
    if (length(dot.col) == 2) {
      pmain <- pmain +
        ggplot2::scale_fill_gradient(low = dot.col[1], high = dot.col[2])
    } else {
      pmain <- pmain +
        ggplot2::scale_fill_gradient2(
          low = dot.col[1],
          mid = dot.col[2],
          high = dot.col[3],
          midpoint = midpoint
        )
    }
  } else {
    if (split.by.aesGroup == FALSE) {
      pmain <- pmain +
        ggplot2::scale_fill_manual(values = dot.col)
    } else {
      if (length(dot.col) == 2) {
        pmain <- pmain +
          ggplot2::scale_fill_gradient(low = dot.col[1], high = dot.col[2])
      } else {
        pmain <- pmain +
          ggplot2::scale_fill_gradient2(
            low = dot.col[1],
            mid = dot.col[2],
            high = dot.col[3],
            midpoint = midpoint
          )
      }
    }
  }
  
  # add point or tile layer
  if (point.geom == TRUE) {
    if (is.null(split.by)) {
      pmain <- pmain +
        ggplot2::geom_point(
          ggplot2::aes(fill = avg.exp.scaled, size = pct.exp),
          color = "black", shape = point.shape
        ) +
        colorbar.layer +
        point.layer +
        ggplot2::scale_size(range = c(dot.min, dot.max))
    } else {
      if (split.by.aesGroup == FALSE) {
        pmain <- pmain +
          ggplot2::geom_point(
            ggplot2::aes(fill = group, size = pct.exp),
            color = "black", shape = point.shape
          ) +
          point.layer +
          ggplot2::scale_size(range = c(dot.min, dot.max))
      } else {
        pmain <- pmain +
          ggplot2::geom_point(
            ggplot2::aes(fill = avg.exp.scaled, size = pct.exp),
            color = "black", shape = point.shape
          ) +
          colorbar.layer +
          point.layer +
          ggplot2::scale_size(range = c(dot.min, dot.max))
      }
    }
  } else if (tile.geom == TRUE) {
    if (is.null(split.by)) {
      pmain <- pmain +
        ggplot2::geom_tile(
          ggplot2::aes(fill = avg.exp.scaled),
          color = "black"
        ) +
        colorbar.layer
    } else {
      if (split.by.aesGroup == FALSE) {
        pmain <- pmain +
          ggplot2::geom_tile(
            ggplot2::aes(fill = group),
            color = "black"
          ) +
          colorbar.layer
      } else {
        pmain <- pmain +
          ggplot2::geom_tile(
            ggplot2::aes(fill = avg.exp.scaled),
            color = "black"
          ) +
          colorbar.layer
      }
    }
  }
  
  # long to wide matrix
  plot.matrix <- data.plot.res %>%
    reshape2::dcast(id ~ gene, value.var = "avg.exp.scaled")
  
  rownames(plot.matrix) <- plot.matrix$id
  plot.matrix <- plot.matrix %>% dplyr::select(-id)
  
  # =======================================
  # define label position
  if (is.null(tree.pos)) {
    if (ytree == TRUE && xtree == FALSE) {
      tree.pos <- c("right", "right")
    } else if (xtree == TRUE && ytree == FALSE) {
      tree.pos <- c("top", "top")
    } else {
      tree.pos <- c("right", "top")
    }
  } else {
    tree.pos <- tree.pos
  }
  
  # add ytree
  if (ytree == TRUE) {
    # whether put label same with tree
    if (same.pos.label == FALSE) {
      pytree <- pmain +
        ggh4x::scale_y_dendrogram(
          hclust = stats::hclust(stats::dist(plot.matrix)),
          position = tree.pos[1],
          labels = NULL
        ) +
        ggplot2::guides(y.sec = ggh4x::guide_axis_manual(labels = function(x) {
          x
        }))
    } else {
      pytree <- pmain +
        ggh4x::scale_y_dendrogram(
          hclust = stats::hclust(stats::dist(plot.matrix)),
          position = tree.pos[1]
        )
    }
  } else {
    pytree <- pmain
  }
  
  # add xtree
  if (xtree == TRUE) {
    # whether put label same with tree
    if (same.pos.label == FALSE) {
      pxtree <- pytree +
        ggh4x::scale_x_dendrogram(
          hclust = stats::hclust(stats::dist(t(plot.matrix))),
          position = tree.pos[2],
          labels = NULL
        ) +
        ggplot2::guides(x.sec = ggh4x::guide_axis_manual(labels = function(x) {
          x
        }))
    } else {
      pxtree <- pytree +
        ggh4x::scale_x_dendrogram(
          hclust = stats::hclust(stats::dist(t(plot.matrix))),
          position = tree.pos[2]
        )
    }
  } else {
    pxtree <- pytree
  }
}

custDotplot <- function(
    data,
    x,
    y,
    size.by = NULL,
    fill.by = NULL,
    shape.by = NULL,
    x.order = NULL,
    y.order = NULL,
    x.lab = "",
    y.lab = "",
    title = NULL,
    point.shape = 21,
    point.color = "black",
    point.stroke = 0.2,
    point.alpha = 1,
    shape.values = NULL,
    shape.legendTitle = NULL,
    dot.min = 1,
    dot.max = 8,
    dot.size = 4,
    dot.col = c("#2b6cb0", "white", "#c53030"),
    midpoint = 0,
    fill.limits = NULL,
    fill.na = "grey90",
    size.limits = NULL,
    size.breaks = NULL,
    size.n.breaks = 4,
    base_size = 14,
    x.text.angle = 45,
    x.text.hjust = 1,
    x.text.vjust = 1,
    x.expand = c(0.6, 0.6),
    y.expand = c(0.6, 0.6),
    protect.edge = TRUE,
    edge.expand = NULL,
    aspect.ratio = NULL,
    legend.position = "right",
    legend.direction = "vertical",
    fill.legendTitle = NULL,
    size.legendTitle = NULL,
    bar.width = 1.5,
    size.width = 0.6,
    plot.margin = c(0.5, 0.5, 0.5, 0.5),
    panel.grid = TRUE,
    panel.border = TRUE,
    coord.fixed = FALSE,
    flip = FALSE,
    clip = "off",
    top.n = NULL,
    top.by = NULL,
    top.abs = TRUE,
    ...) {
  data <- as.data.frame(data, stringsAsFactors = FALSE)

  required.cols <- unique(c(x, y, size.by, fill.by, shape.by, top.by))
  missing.cols <- setdiff(required.cols, colnames(data))
  if (length(missing.cols) > 0) {
    stop(
      sprintf(
        "Missing required columns in `data`: %s",
        paste(missing.cols, collapse = ", ")
      )
    )
  }

  if (!is.null(top.n)) {
    if (is.null(top.by)) {
      stop("Please provide `top.by` when using `top.n`.")
    }
    top.n <- as.integer(top.n)[1]
    if (is.na(top.n) || top.n <= 0) {
      stop("`top.n` must be a positive integer.")
    }
    rank.value <- data[[top.by]]
    if (top.abs) {
      rank.value <- abs(rank.value)
    }
    ord <- order(rank.value, decreasing = TRUE, na.last = NA)
    data <- data[ord, , drop = FALSE]
    data <- data[seq_len(min(top.n, nrow(data))), , drop = FALSE]
  }

  if (is.null(x.order)) {
    x.order <- unique(as.character(data[[x]]))
  }
  if (is.null(y.order)) {
    y.order <- unique(as.character(data[[y]]))
  }

  data[[x]] <- factor(data[[x]], levels = unique(x.order))
  data[[y]] <- factor(data[[y]], levels = unique(y.order))

  x.expand.use <- x.expand
  y.expand.use <- y.expand
  if (isTRUE(protect.edge)) {
    edge.expand.use <- edge.expand
    if (is.null(edge.expand.use)) {
      edge.expand.use <- max(0.6, dot.max / 8)
    }
    x.expand.use <- pmax(as.numeric(x.expand.use), edge.expand.use)
    y.expand.use <- pmax(as.numeric(y.expand.use), edge.expand.use)
  }

  size.breaks.use <- size.breaks
  if (!is.null(size.by) && is.null(size.breaks.use)) {
    size.values <- data[[size.by]]
    size.values <- size.values[is.finite(size.values)]
    if (length(size.values) > 0) {
      if (diff(range(size.values)) == 0) {
        size.breaks.use <- unique(size.values)
      } else {
        size.breaks.use <- pretty(size.values, n = size.n.breaks)
        size.breaks.use <- size.breaks.use[
          size.breaks.use >= min(size.values) &
            size.breaks.use <= max(size.values)
        ]
        size.breaks.use <- unique(size.breaks.use)
      }
    }
  }

  aes.args <- list(x = data[[x]], y = data[[y]])
  if (!is.null(size.by)) {
    aes.args$size <- data[[size.by]]
  }
  if (!is.null(fill.by)) {
    aes.args$fill <- data[[fill.by]]
  }
  if (!is.null(shape.by)) {
    data[[shape.by]] <- as.factor(data[[shape.by]])
    aes.args$shape <- data[[shape.by]]
  }

  p <- ggplot2::ggplot(data, do.call(ggplot2::aes, aes.args)) +
    ggplot2::theme_bw(base_size = base_size) +
    ggplot2::labs(x = x.lab, y = y.lab, title = title) +
    ggplot2::scale_x_discrete(expand = ggplot2::expansion(add = x.expand.use)) +
    ggplot2::scale_y_discrete(expand = ggplot2::expansion(add = y.expand.use)) +
    ggplot2::theme(
      plot.margin = ggplot2::margin(
        t = plot.margin[1], r = plot.margin[2],
        b = plot.margin[3], l = plot.margin[4],
        unit = "cm"
      ),
      axis.text = ggplot2::element_text(color = "black"),
      axis.text.x = ggplot2::element_text(
        angle = x.text.angle,
        hjust = x.text.hjust,
        vjust = x.text.vjust
      ),
      aspect.ratio = aspect.ratio,
      legend.position = legend.position,
      legend.direction = legend.direction,
      panel.grid.major = if (panel.grid) ggplot2::element_line(color = "grey85") else ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank(),
      panel.border = if (panel.border) ggplot2::element_rect(color = "black") else ggplot2::element_blank()
    )

  if (!is.null(size.by)) {
    p <- p +
      ggplot2::geom_point(
        color = point.color,
        stroke = point.stroke,
        alpha = point.alpha,
        show.legend = TRUE,
        shape = if (is.null(shape.by)) point.shape else NULL,
        ...
      ) +
      ggplot2::scale_size_continuous(
        name = if (is.null(size.legendTitle)) size.by else size.legendTitle,
        range = c(dot.min, dot.max),
        limits = size.limits,
        breaks = size.breaks.use,
        guide = ggplot2::guide_legend(
          title.position = "top",
          title.hjust = 0.5,
          keywidth = ggplot2::unit(size.width, "cm"),
          order = 1,
          override.aes = list(
            shape = if (is.null(shape.by)) point.shape else 21,
            fill = "grey60",
            color = point.color,
            alpha = 1
          )
        )
      )
  } else {
    p <- p + ggplot2::geom_point(
      color = point.color,
      stroke = point.stroke,
      alpha = point.alpha,
      size = dot.size,
      show.legend = !is.null(fill.by),
      shape = if (is.null(shape.by)) point.shape else NULL,
      ...
    )
  }

  if (!is.null(shape.by)) {
    p <- p + ggplot2::scale_shape_manual(
      values = if (is.null(shape.values)) c(21, 22, 24, 23, 25) else shape.values,
      name = if (is.null(shape.legendTitle)) shape.by else shape.legendTitle,
      guide = ggplot2::guide_legend(
        title.position = "top",
        title.hjust = 0.5,
        order = 3,
        override.aes = list(
          size = max(dot.min, dot.size),
          fill = "grey60",
          color = point.color,
          alpha = 1
        )
      )
    )
  }

  if (!is.null(fill.by)) {
    if (length(dot.col) == 2) {
      p <- p +
        ggplot2::scale_fill_gradient(
          low = dot.col[1],
          high = dot.col[2],
          limits = fill.limits,
          na.value = fill.na,
          name = if (is.null(fill.legendTitle)) fill.by else fill.legendTitle,
          guide = ggplot2::guide_colorbar(
            title.position = "top",
            title.hjust = 0.5,
            barwidth = grid::unit(bar.width, "cm"),
            frame.colour = "black",
            frame.linewidth = 0.8,
            ticks.colour = "black",
            order = 2
          )
        )
    } else {
      p <- p +
        ggplot2::scale_fill_gradient2(
          low = dot.col[1],
          mid = dot.col[2],
          high = dot.col[3],
          midpoint = midpoint,
          limits = fill.limits,
          na.value = fill.na,
          name = if (is.null(fill.legendTitle)) fill.by else fill.legendTitle,
          guide = ggplot2::guide_colorbar(
            title.position = "top",
            title.hjust = 0.5,
            barwidth = grid::unit(bar.width, "cm"),
            frame.colour = "black",
            frame.linewidth = 0.8,
            ticks.colour = "black",
            order = 2
          )
        )
    }
  }

  if (isTRUE(coord.fixed)) {
    p <- p + ggplot2::coord_fixed(clip = clip)
  } else if (isTRUE(flip)) {
    p <- p + ggplot2::coord_flip(clip = clip)
  } else {
    p <- p + ggplot2::coord_cartesian(clip = clip)
  }

  p
}
