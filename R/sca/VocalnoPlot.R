avgVolcano <- function(markers.seu, highlightN = 5 , features = NULL, clusterOrder = NULL,
                       DEcolor = c(sigDown = "#0099CC", sigUp = "#CC3333", Nonsig = "grey53"), geneCol = 'gene',
                       qvalcol = 'p_val_adj', qval.thres = 0.05, keep.all = TRUE, 
                       cluster.key = "cluster", title = NULL, threshold = 0.25,
                       rank.by = "Ranking = abs(pct.1 - pct.2) * abs(avg_log2FC)", 
                       shift = c(0.1, 0.01), psize = 1.5, base_size = 14, ...){
  markers.seu <- markers.seu %>% 
    dplyr::mutate(UpDown = case_when(avg_log2FC > threshold ~ "sigUp", 
                                     avg_log2FC < -threshold ~ "sigDown", 
                                     TRUE ~ 'Nonsig'))
  markers.seu[['UpDown']] <- ifelse(markers.seu[[qvalcol]] > qval.thres, 'Nonsig', markers.seu[['UpDown']])
  if (isFALSE(keep.all)) markers.seu <- markers.seu %>% dplyr::filter(UpDown != 'Nonsig')
  .markers.seu <- topMarkers.seu(markers.seu = markers.seu, features = features, threshold = threshold,
                                 featureCount = highlightN, selection = cluster.key, 
                                 rank.by = rank.by)$df
  .feature.pos <- .markers.seu %>% dplyr::filter(UpDown == 'sigUp')
  .feature.neg <- .markers.seu %>% dplyr::filter(UpDown == 'sigDown')
  .feas.all <- markers.seu[[geneCol]]
  .gene.label <- .markers.seu[[geneCol]]
  if (!is.null(features)) {
    .f.idx <- features %in% .feas.all
    if (length(.f.idx) != length(features)) cli::cli_alert("Some features are not found in the data")
    .gene.label <- c(.gene.label, features[.f.idx])
  }
  if (!is.null(clusterOrder)) {
    markers.seu[[cluster.key]] <- factor(markers.seu[[cluster.key]], levels = clusterOrder)
  } else {
    if (!is.factor(markers.seu[[cluster.key]])) {
      markers.seu[[cluster.key]] <- factor(markers.seu[[cluster.key]])
    }
  }
  .clusters <- levels(markers.seu[[cluster.key]])
  .data.bg <- purrr::map_df(.clusters, function(x){
    .tmp <- markers.seu %>% dplyr::filter(.data[[cluster.key]] == x)
    return(data.frame(
      cluster = x,
      min = min(.tmp[['avg_log2FC']]) - shift[1],
      max = max(.tmp[['avg_log2FC']]) + shift[1]
    ))
  })
  .is.hl <- rep("", length(markers.seu[[geneCol]]))
  .is.hl.t <- paste0(markers.seu[[cluster.key]], markers.seu[[geneCol]]) %in% paste0(.markers.seu[[cluster.key]], .markers.seu[[geneCol]])
  .is.hl.t.index <- which(.is.hl.t)
  .is.hl[.is.hl.t.index] <- markers.seu[[geneCol]][.is.hl.t.index]
  markers.seu$Feature <- .is.hl
  markers.seu$Shape <- c("", 1)[.is.hl.t + 1]
  markers.seu$Color <- c("", 1)[.is.hl.t + 1]
  markers.seu$Alpha <- as.numeric(.is.hl.t)
  markers.seu$xj <- jitter(as.numeric(markers.seu[[cluster.key]]), amount = 0.4)
  .breaks.y <- trunc(range(markers.seu$avg_log2FC))
  .breaks.y <- seq.int(.breaks.y[1], .breaks.y[2], length.out = 6)
  .breaks.y <- .breaks.y[which(!abs(.breaks.y) < threshold)]
  .breaks.y <- c(.breaks.y, threshold, -threshold)
  .p <- ggplot(data = markers.seu, aes(x = xj, y = avg_log2FC)) +
    geom_col(data = .data.bg, aes(x = cluster, y = min), fill = "grey93") +
    geom_col(data = .data.bg, aes(x = cluster, y = max), fill = "grey93") +
    geom_point(aes(color = UpDown)) +
    geom_point(
      data = markers.seu, 
      aes(x = xj, y = avg_log2FC, shape = Shape, alpha = Alpha), 
      size = psize, stroke = 1,
      show.legend = FALSE
    ) +
    scale_shape_manual(
      values = c(0, 1)
    ) +
    xlab(label = "Clusters") +
    ylab(label = "Average log2FoldChange") +
    scale_color_manual(values = DEcolor) +
    scale_y_continuous(
      breaks = .breaks.y
    ) +
    theme_classic(base_size = base_size) +
    theme(
      panel.grid = element_blank(),
      legend.title = element_blank(),
      legend.background = element_blank()
    ) +
    guides(
      color = guide_legend(
        override.aes = list(size = 5)
      )
    )
  .p <- .p + geom_tile(
    aes(x = !!ensym(cluster.key), y = 0, fill = !!ensym(cluster.key)),
    # color of tile edge
    color = "black",
    # height of tiles
    height = threshold * 2,
    alpha = 0.1, 
    show.legend = FALSE
  ) +
    geom_text_repel(
      data = markers.seu,
      aes(x = xj, y = avg_log2FC, label = Feature),
      max.overlaps = 1000
    ) +
    ggtitle(label = title)+
    geom_text(aes(x = !!ensym(cluster.key), y = 0, label = str_wrap(!!ensym(cluster.key), width = 15)), size = 3) +
    theme(
      axis.line.x = element_blank(), 
      axis.text.x = element_blank(), 
      axis.ticks.x = element_blank()
    )
  
  return(.p) 
}

percentVocalno <- function(markers.seu = NULL, features = NULL, highlightN = 5, log2FC = 0.25,
                           labelCol = NULL, hlineSize = 1, hlineColor = 'grey50', cluster.key = 'cluster',
                           pforce = 5, nforce = 2.5, nudge_x = 0.8, pnudge_y = 0.25,
                           nnudge_y = 0, base_size = 14, facetColor = NA,
                           facetFill = 'white', ylab = 'Log2-Fold Change',nrow = 1,
                           title = NULL) {
  .markers.seu <- topMarkers.seu(markers.seu = markers.seu, features = features, 
                                 featureCount = highlightN, selection = cluster.key)$df
  .markers.seu[[cluster.key]] <- as.factor(.markers.seu[[cluster.key]])
  .feature.pos <- .markers.seu %>% dplyr::filter(UpDown == 'sigUp')
  .feature.neg <- .markers.seu %>% dplyr::filter(UpDown == 'sigDown')
  
  # plot
  .p <- ggplot2::ggplot(markers.seu,
                        ggplot2::aes(x = pct.1 - pct.2, y = avg_log2FC)) +
    ggplot2::geom_point(color = 'grey80') +
    ggplot2::geom_hline(
      yintercept = c(-log2FC, log2FC), lty = 'dashed', size = hlineSize, color = hlineColor) +
    ggrepel::geom_text_repel(
      data = .feature.pos,
      ggplot2::aes(
        x = pct.1 - pct.2,
        y = avg_log2FC,
        label = gene,
        color = .data[[cluster.key]]
      ),
      show.legend = F,
      direction = 'y',
      hjust = 1,
      nudge_y = pnudge_y,
      force = pforce,
      nudge_x = -nudge_x - (.feature.pos$pct.1 - .feature.pos$pct.2)
    ) +
    ggrepel::geom_text_repel(
      data = .feature.neg,
      ggplot2::aes(
        x = pct.1 - pct.2,
        y = avg_log2FC,
        label = gene,
        color = !!ensym(cluster.key)
      ),
      show.legend = F,
      direction = 'y',
      hjust = 0,
      nudge_y = nnudge_y,
      force = nforce,
      nudge_x = nudge_x - (.feature.neg$pct.1 - .feature.neg$pct.2)
    ) +
    ggplot2::geom_point(
      data = .markers.seu,
      show.legend = F,
      ggplot2::aes(
        x = pct.1 - pct.2,
        y = avg_log2FC,
        color = !!ensym(cluster.key)
      )
    ) +
    ggplot2::scale_color_manual(name = '', values = labelCol) +
    ggplot2::theme_bw(base_size = base_size) +
    ggplot2::theme(
      panel.grid = ggplot2::element_blank(),
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1),
      strip.background = ggplot2::element_rect(color = facetColor, fill = facetFill)
    ) +
    ggplot2::xlab(expression(Delta ~ 'Percentage Difference')) +
    ggplot2::ylab(ylab) +
    ggplot2::facet_wrap(~ .data[[cluster.key]], nrow = nrow, scales = 'fixed') + 
    see::scale_color_flat()
  if (is.null(title)) {
    .p <- .p + ggplot2::ggtitle('Volcano Plot')
  } else {
    .p <- .p + ggplot2::ggtitle(title)
  }
  return(.p)
}

volcanoPlot <- function(df, features.label = NULL, split.by = NULL, 
                        legend = 'avg_log2FC', DE.expr = "avg_log2FC > 0 & p_val_adj < 0.05", 
                        xlab = "diff.pct", pct.1 = 'pct.1', pct.2 = 'pct.2',
                        palette = "RdBu", palcolor = NULL, pt.size = 1, pt.alpha = 1, 
                        cols.highlight = "black", sizes.highlight = 1, 
                        alpha.highlight = 1, stroke.highlight = 0.5,
                        nlabel = 5, x2y = FALSE,
                        label.fg = "black", label.bg = "white", 
                        label.bg.r = 0.1, label.size = 4,
                        aspect.ratio = NULL, ylab = "-log10(p-adjust)",
                        theme.use = "themeDefault", theme.args = list(),
                        combine = TRUE, nrow = NULL, ncol = NULL, 
                        byrow = TRUE, seed = 10086){
  .req.libs <- c("ggplot2", "ggrepel", "dplyr", "tibble")
  invisible(lapply(.req.libs, require, character.only = TRUE))
  .df <- df
  if (! 'gene' %in% colnames(.df)) .df <- tibble::rownames_to_column(.df, var = 'gene')
  if (!xlab %in% colnames(.df)) {
    .tmp.df <- ckCols(.df, c(pct.1, pct.2), col.return = T)
    if (is.null(.tmp.df)) {
      cli::cli_abort("The columns pct.1 and pct.2 and xlab are not found in the input data frame.")
    } else {
      .df[[xlab]] <- .tmp.df[[pct.1]] - .tmp.df[[pct.2]]
    }
  }
  if (ylab == "-log10(p-adjust)") {
    if (!"p_val_adj" %in% colnames(.df)) {
      cli::cli_abort("The column p_val_adj is not found in the input data frame.")
    } else {
      .df[["-log10(p-adjust)"]] <- -log10(.df$p_val_adj)
    }
  }
  if (! 'DE' %in% colnames(.df)) .df[, "DE"] <- FALSE
  .df[with(.df, eval(rlang::parse_expr(DE.expr))), "DE"] <- TRUE
  .x.upper <- quantile(.df[["avg_log2FC"]][is.finite(.df[["avg_log2FC"]])], c(0.99, 1))
  .x.lower <- quantile(.df[["avg_log2FC"]][is.finite(.df[["avg_log2FC"]])], c(0.01, 0))
  .x.upper <- ifelse(.x.upper[1] > 0, .x.upper[1], .x.upper[2])
  .x.lower <- ifelse(.x.lower[1] < 0, .x.lower[1], .x.lower[2])
  if (.x.upper > 0 & .x.lower < 0) {
    .value.range <- min(abs(c(.x.upper, .x.lower)), na.rm = TRUE)
    .x.upper <- .value.range
    .x.lower <- - .value.range
  }
  .df[, "border"] <- FALSE
  .df[.df[["avg_log2FC"]] > .x.upper, "border"] <- TRUE
  .df[.df[["avg_log2FC"]] > .x.upper, "avg_log2FC"] <- .x.upper
  .df[.df[["avg_log2FC"]] < .x.lower, "border"] <- TRUE
  .df[.df[["avg_log2FC"]] < .x.lower, "avg_log2FC"] <- .x.lower
  .xlab <- xlab
  .ylab <- ylab
  if (isTRUE(x2y)) {
    .df[, "y"] <- .df[, xlab]
    .df[, "x"] <- -log10(.df[, "p_val_adj"])
    .df[.df[, "avg_log2FC"] < 0, "y"] <- - .df[.df[, "avg_log2FC"] < 0, "y"]
    .df <- .df[order(abs(.df[, "avg_log2FC"]), decreasing = FALSE, na.last = FALSE), , drop = FALSE]
    .xlab <- ylab
    .ylab <- xlab
  } else {
    .df[, "y"] <- -log10(.df[, "p_val_adj"])
    .df[, "x"] <- .df[, xlab]
    .df[.df[, "diff.pct"] < 0, "y"] <- - .df[.df[, "diff.pct"] < 0, "y"]
    .df <- .df[order(abs(.df[, "diff.pct"]), decreasing = FALSE, na.last = FALSE), , drop = FALSE]
  }
  
  #  .df[.df[, "avg_log2FC"] < 0, "y"] <- - .df[.df[, "avg_log2FC"] < 0, "y"]
  #  .df <- .df[order(abs(.df[, "avg_log2FC"]), decreasing = FALSE, na.last = FALSE), , drop = FALSE]
  .df[, "distance"] <- .df[, "x"]^2 + .df[, "y"]^2
  .plist <- list()
  .df[['split.by']] <- .df[[split.by]]
  .df.use.lst <- split(.df, .df[[split.by]])
  .split.vars <- names(.df.use.lst)
  for ( .idx in seq_along(.df.use.lst)) {
    .df.use <- .df.use.lst[[.idx]]
    .var <- .split.vars[[.idx]]
    if (nrow(.df.use) == 0) next
    .x.nudge <- diff(range(.df.use$x)) * 0.05
    .df.use[, "label"] <- FALSE
    if (is.null(features.label)) {
      .df.use[.df.use[["y"]] >= 0, ][head(order(.df.use[.df.use[["y"]] >= 0, "distance"], decreasing = TRUE), nlabel), "label"] <- TRUE
      .df.use[.df.use[["y"]] < 0, ][head(order(.df.use[.df.use[["y"]] < 0, "distance"], decreasing = TRUE), nlabel), "label"] <- TRUE
    } else {
      .df.use[.df.use[["gene"]] %in% features.label, "label"] <- TRUE
    }
    .jitter <- position_jitter(width = 0.2, height = 0.2, seed = seed)
    .color.by <- legend
    if (is.null(.color.by)) .color.by <- setdiff(c("diff.pct", "avg_log2FC"), c(.xlab, .ylab))[1]
    .p <- ggplot() +
      geom_point(data = .df.use[!.df.use[["DE"]] & !.df.use[["border"]], , drop = FALSE], aes(x = x, y = y, color = .data[[.color.by]]), size = pt.size, alpha = pt.alpha) +
      geom_point(data = .df.use[!.df.use[["DE"]] & .df.use[["border"]], , drop = FALSE], aes(x = x, y = y, color = .data[[.color.by]]), size = pt.size, alpha = pt.alpha, position = .jitter) +
      geom_point(data = .df.use[.df.use[["DE"]] & !.df.use[["border"]], , drop = FALSE], aes(x = x, y = y), color = cols.highlight, size = sizes.highlight + stroke.highlight, alpha = alpha.highlight) +
      geom_point(data = .df.use[.df.use[["DE"]] & .df.use[["border"]], , drop = FALSE], aes(x = x, y = y), color = cols.highlight, size = sizes.highlight + stroke.highlight, alpha = alpha.highlight, position = .jitter) +
      geom_point(data = .df.use[.df.use[["DE"]] & !.df.use[["border"]], , drop = FALSE], aes(x = x, y = y, color = .data[[.color.by]]), size = pt.size, alpha = pt.alpha) +
      geom_point(data = .df.use[.df.use[["DE"]] & .df.use[["border"]], , drop = FALSE], aes(x = x, y = y, color = .data[[.color.by]]), size = pt.size, alpha = pt.alpha, position = .jitter) +
      geom_hline(yintercept = 0, color = "black", linetype = 1) +
      geom_vline(xintercept = 0, color = "grey", linetype = 2) +
      geom_text_repel(
        data = .df.use[.df.use[["label"]], , drop = FALSE], aes(x = x, y = y, label = gene),
        min.segment.length = 0, max.overlaps = 100, segment.colour = "grey40",
        color = label.fg, bg.color = label.bg, bg.r = label.bg.r, size = label.size, force = 20,
        nudge_x = ifelse(.df.use[.df.use[["label"]], "y"] >= 0, -.x.nudge, .x.nudge)
      ) +
      labs(x = .xlab, y = .ylab) +
      scale_color_gradientn(
        name = .color.by, colors = palette_scp(palette = palette, palcolor = palcolor),
        values = scale01(unique(c(min(c(.df.use[, .color.by], 0), na.rm = TRUE), 0, max(.df.use[, .color.by], na.rm = TRUE)))),
        guide = guide_colorbar(frame.colour = "black", ticks.colour = "black", title.hjust = 0, order = 1)
      ) +
      scale_y_continuous(labels = abs) +
      facet_wrap(~split.by) +
      do.call(theme.use, theme.args) +
      theme(aspect.ratio = aspect.ratio)
    .plist[[.var]] <- .p
  }
  if (isTRUE(combine)) {
    if (length(.plist) > 1) {
      .plot <- patchwork::wrap_plots(plotlist = .plist, nrow = nrow, ncol = ncol, byrow = byrow)
    } else {
      .plot <- .plist[[1]]
    }
    return(.plot)
  } else {
    return(.plist)
  }
}


