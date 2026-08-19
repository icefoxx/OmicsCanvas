plot.den.cols <- function(mtx, annot, sample_col = 'sample', 
                          group_col = 'celltype', 
                          dist_mtd = "euclidean",
                          clu_mtd = "average", title = "Clustering Dendrogram",
                          tile_height_ratio  = 0.05,
                          label_size = 4, legend_size = 8,
                          legend_title = group_col,
                          legend_position = "right",
                          group_colors = NULL,
                          point_size = 4,
                          x_text_angle = 90,
                          x_text_hjust = 1,
                          x_text_vjust = 0.5,
                          x_text_color_col = NULL,
                          x_text_colors = NULL,
                          show_x_text_legend = TRUE,
                          x_text_legend_title = NULL) {
  load_pkgs(c('ggplot2', 'ggdendro', 'patchwork'))
  stopifnot (!is.null(rownames(mtx))) 
  stopifnot (!is.null(colnames(mtx)))
  stopifnot (is.data.frame(annot))
  stopifnot (is.character(sample_col))
  stopifnot (is.character(group_col))
  stopifnot (sample_col %in% colnames(annot))
  stopifnot (group_col %in% colnames(annot))
  if (!is.null(x_text_color_col)) {
    stopifnot(is.character(x_text_color_col))
    stopifnot(length(x_text_color_col) == 1)
    stopifnot(x_text_color_col %in% colnames(annot))
  }
  
  .sams   <- colnames(mtx)
  .annot <- annot
  if (!all(.sams %in% .annot[[sample_col]])) warning("Some samples in `mtx` have no matching annotation")

  .mtx <- as.matrix(mtx)
  storage.mode(.mtx) <- "double"
  if (ncol(.mtx) < 2) {
    stop("`mtx` must contain at least 2 sample profiles to build a dendrogram.")
  }
  if (anyNA(.mtx) || any(!is.finite(.mtx))) {
    stop("`mtx` contains NA/Inf values; cannot compute distances.")
  }

  if (tolower(dist_mtd) %in% c("correlation", "pearson", "spearman")) {
    .cor.method <- ifelse(tolower(dist_mtd) == "spearman", "spearman", "pearson")
    .cor <- stats::cor(.mtx, method = .cor.method, use = "pairwise.complete.obs")
    .dist <- stats::as.dist(1 - .cor)
  } else {
    .dist <- stats::dist(t(.mtx), method = dist_mtd)
  }
  .hc <- stats::hclust(.dist, method = clu_mtd)
  .ddata <- ggdendro::dendro_data(.hc, type = "rectangle")
  .tip.df      <- .ddata$labels
  .tip.df$Group <- .annot[[group_col]][match(.tip.df$label, .annot[[sample_col]])]
  if (any(is.na(.tip.df$Group))) {
    .tip.df$Group[is.na(.tip.df$Group)] <- "Unknown"
    warning("Assigned 'Unknown' to missing Group for some tips.")
  }
  .use_markdown_x_text <- !is.null(x_text_color_col)
  if (.use_markdown_x_text) {
    if (!requireNamespace("ggtext", quietly = TRUE)) {
      stop("Package 'ggtext' is required for colored x-axis text.")
    }
    .tip.df$LabelGroup <- as.character(.annot[[x_text_color_col]][match(.tip.df$label, .annot[[sample_col]])])
    .tip.df$LabelGroup[is.na(.tip.df$LabelGroup)] <- "Unknown"
    .label_groups <- unique(.tip.df$LabelGroup)
    if (is.null(x_text_colors)) {
      x_text_colors <- setNames(grDevices::hcl.colors(length(.label_groups), palette = "Dark 3"), .label_groups)
    } else {
      if (is.null(names(x_text_colors))) {
        stop("`x_text_colors` must be a named vector keyed by label groups.")
      }
      .missing_groups <- setdiff(.label_groups, names(x_text_colors))
      if (length(.missing_groups) > 0) {
        .extra_cols <- setNames(grDevices::hcl.colors(length(.missing_groups), palette = "Dark 3"), .missing_groups)
        x_text_colors <- c(x_text_colors, .extra_cols)
      }
    }
    if ("Unknown" %in% .label_groups) {
      x_text_colors["Unknown"] <- "grey30"
    }
    .tip.df$LabelColor <- unname(x_text_colors[.tip.df$LabelGroup])
    .tip.df$LabelColor[is.na(.tip.df$LabelColor)] <- "black"
    .tip.df$LabelMarkdown <- sprintf(
      "<span style='color:%s;'>%s</span>",
      .tip.df$LabelColor,
      gsub(">", "&gt;", gsub("<", "&lt;", gsub("&", "&amp;", .tip.df$label, fixed = TRUE), fixed = TRUE), fixed = TRUE)
    )
  }
  .segs <- .ddata$segments
  # for each segment use xend to find closest tip x coordinate
  #  .segs$Group <- sapply(.segs$xend, function(xv) {
  #    .idx <- which.min(abs(.tip.df$x - xv))
  #    .tip.df$Group[.idx]
  #  })
  .segs$Group <- .tip.df$Group[match(.segs$xend, .tip.df$x)]
  .segs$low <- .segs$yend == 0
  
  .grps    <- unique(.tip.df$Group)
  .grps.n  <- length(.grps)
  if (requireNamespace("RColorBrewer", quietly = TRUE) &&
      .grps.n <= RColorBrewer::brewer.pal.info["Set1", "maxcolors"]) {
    pal <- RColorBrewer::brewer.pal(n = .grps.n, name = "Set1")
  } else {
    pal <- grDevices::rainbow(.grps.n)
  }
  .grps.cols <- setNames(pal, .grps)
  if (!is.null(group_colors)) {
    if (is.null(names(group_colors))) {
      stop("`group_colors` must be a named vector keyed by group labels.")
    }
    .hits <- intersect(names(group_colors), .grps)
    .grps.cols[.hits] <- group_colors[.hits]
  }
  if ("Unknown" %in% .grps) .grps.cols["Unknown"] <- "grey70"
  .y.min   <- min(.ddata$segments$y)
  .y.range <- diff(range(.ddata$segments$y))
  .bar.y <- .y.min - 0.05 * .y.range
  .bar.h   <- 0.05 * .y.range
  
  .x.limits   <- range(.tip.df$x)
  .n.tips     <- length(unique(.tip.df$x))
  .tile.width <- if (length(.tip.df$x) > 1) diff(.x.limits) / (.n.tips - 1) else 1
  if (.use_markdown_x_text && show_x_text_legend) {
    .legend.df <- data.frame(
      x = rep(.x.limits[1], length(.label_groups)),
      y = rep(1, length(.label_groups)),
      LabelGroup = .label_groups,
      stringsAsFactors = FALSE
    )
  }
  
  .p.tree <- ggplot() +
    geom_segment(data = .segs,
                 aes(x = x, y = y, xend = xend, yend = yend)) +
    geom_segment(data = subset(.segs, low),
                 aes(x = x, y = y, xend = xend, yend = yend, color = Group),
                 linewidth = 0.8) +
    geom_point(data = .tip.df,
               aes(x = x, y = 0, color = Group),
               size = point_size) +
    scale_color_manual(values = .grps.cols, name = legend_title) +
    scale_x_continuous(limits = .x.limits, expand = c(0,0)) +
    scale_y_continuous(expand = c(0, 0)) +
    theme_void() +
    labs(title = title) +
    theme(legend.position = 'None')
  
  .p.bar <- ggplot(.tip.df, aes(x = x, fill = Group)) +
    geom_tile(aes(y = 1), width = .tile.width, height = 1) +
    {
      if (.use_markdown_x_text && show_x_text_legend) {
        geom_point(
          data = .legend.df,
          mapping = aes(x = x, y = y, color = LabelGroup),
          inherit.aes = FALSE,
          alpha = 0,
          size = 3,
          show.legend = TRUE
        )
      }
    } +
    scale_x_continuous(
      breaks = .tip.df$x,
      labels = if (.use_markdown_x_text) .tip.df$LabelMarkdown else .tip.df$label,
      expand = c(0,0)
    ) +
    coord_cartesian(xlim = .x.limits) +
    scale_fill_manual(values = .grps.cols, name = legend_title) +
    {
      if (.use_markdown_x_text && show_x_text_legend) {
        scale_color_manual(
          values = x_text_colors,
          name = if (is.null(x_text_legend_title)) x_text_color_col else x_text_legend_title
        )
      }
    } +
    labs(x = NULL, y = NULL) +
    theme_minimal() +
    theme(
      axis.ticks.x    = element_blank(),
      axis.ticks.y    = element_blank(),
      axis.text.y     = element_blank(),
      axis.text.x     = if (.use_markdown_x_text) {
        ggtext::element_markdown(
          size = label_size,
          angle = x_text_angle,
          hjust = x_text_hjust,
          vjust = x_text_vjust
        )
      } else {
        element_text(
          size = label_size,
          angle = x_text_angle,
          hjust = x_text_hjust,
          vjust = x_text_vjust
        )
      },
      axis.title      = element_blank(),
      legend.position  = legend_position,
      legend.title     = element_text(size = legend_size),
      legend.text      = element_text(size = legend_size),
      panel.grid       = element_blank(),
      plot.margin      = grid::unit(c(0, 0, 0, 0), "lines")
    ) +
    guides(
      fill = guide_legend(order = 1),
      color = guide_legend(
        order = 2,
        override.aes = list(alpha = 1, shape = 15, size = 5)
      )
    )
  .p <- .p.tree / .p.bar +
    patchwork::plot_layout(heights = c(1, tile_height_ratio))
  return(.p)
}
