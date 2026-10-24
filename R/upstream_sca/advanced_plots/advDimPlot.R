advDimPlot <- function (data, group.by = NULL, split.by = NULL, stat.plot.by = NULL, 
                        paga = NULL, velocity = NULL,  graph = NULL, lineage = NULL,
                        global.split = TRUE, bg.by = NULL, 
                        dims = c(1, 2),  cell.column.nm = "cell.barcodes.selected",
                        show.stat = ifelse(identical(theme.use, "themeBlank"), FALSE, TRUE), 
                        palette = ifelse(isTRUE(feature.comp), "Set1", "Spectral"), 
                        palcolor = NULL, pt.size = NULL, pt.alpha = 1, 
                        bg.cutoff = 0, bg.color = "grey80", show.mark = FALSE,
                        mark.type = c("hull", "ellipse", "rect", "circle"), 
                        mark.expand = unit(3, "mm"), mark.alpha = 0.1, mark.linetype = 1,
                        stat.plot.source = "percent", stat.plot.type = "pie", 
                        stat.plot.position = c("stack", "dodge"), stat.plot.size = 0.15, 
                        stat.plot.palette = "Set1", stat.palcolor = NULL, stat.plot.alpha = 1, 
                        stat.plot.label = FALSE, stat.plot.label.size = 3, 
                        add.density = FALSE, density.filled = F, density.color = "grey80",
                        density.palette = "Greys", density.palcolor = NULL, 
                        cells.highlight = NULL, highlight.col = "black", 
                        highlight.size = 1, highlight.alpha = 1, label = TRUE,
                        highlight.stroke = 0.5, highlight.mode = c("overlay", "contrast"),
                        non.highlight.col = "grey50", non.highlight.alpha = NULL,
                        coexp = FALSE, feature.comp = FALSE,
                        color.mix.mode = c("blend", "average", "screen", "multiply"),
                        label.size = 4, label.bg.r = 0.1, label.insitu = FALSE, 
                        label.repel = FALSE,  label.repulsion = 20, 
                        label.pt.size = 1, label.pt.color = "black", 
                        label.fg = "white", label.bg = "black",
                        label.seg.color = "black", lineages = NULL, 
                        lineages_trim = c(0.01, 0.99), lineages_span = 0.75, 
                        lineages_palette = "Dark2", lineages_palcolor = NULL, 
                        lineages_arrow = arrow(length = unit(0.1, "inches")), 
                        lineages_linewidth = 1, lineages_line_bg = "white", 
                        lineages_line_bg_stroke = 0.5, lineages_whiskers = FALSE, 
                        lineages_whiskers_linewidth = 0.5, lineages_whiskers_alpha = 0.5, 
                        edge.size = c(0.05, 0.5), edge.alpha = 0.1, edge.color = "grey40",
                        hex = FALSE, hex.count = T, hex.linewidth = 0.5, 
                        hex.color = "grey90", hex.bins = 50, hex.binwidth = NULL, 
                        raster = NULL, raster.dpi = c(512, 512), aspect.ratio = 1, 
                        title = NULL, subtitle = NULL, xlab = NULL, ylab = NULL, 
                        legend.position = "right", legend.direction = "vertical", 
                        theme.use = "themeDefault", theme.args = list(), combine = TRUE, 
                        nrow = NULL, ncol = NULL, byrow = TRUE, force = FALSE, seed = 10086) 
{
  .std.pacs <- c("tidyverse", "ggnewscale", "gtable", "scattermore", "ggrepel", "rlang")
  invisible(suppressPackageStartupMessages(lapply(.std.pacs, library, character.only = TRUE)))
  set.seed(seed)
  .color.mix.mode <- match.arg(color.mix.mode)
  highlight.mode <- match.arg(highlight.mode)
  .feas <- colnames(data)
  .instric.v <- c('x', 'y', split.by, group.by, stat.plot.by)
  .feas.plot <- setdiff(.feas, .instric.v)
  if (length(.feas.plot) == 0) cli::cli_abort('At least 1 feature detected in the data except the xy loci information.')
  if (length(.feas.plot) > 20 && !isTRUE(force)) {
    warning("More than 50 features to be plotted", immediate. = TRUE)
    answer <- askYesNo("Are you sure to continue?", default = FALSE)
    if (!isTRUE(answer)) {
      return(invisible(NULL))
    }
  }
  .df.fmt <- formatDF4statPlot(df = data, stat.by = stat.plot.by,  
                               stat.by.factorize = F, split.by = split.by,
                               plot.type = stat.plot.type, bg.by = NULL, 
                               group.by = group.by, return.all = T)
  .df <- .df.fmt$df
  if (is.null(group.by)) {
    group.by <- "All.groups"
  }
  if (is.null(split.by)) {
    split.by <- "All.groups"
  }
  .bg.mask.global <- rep(FALSE, nrow(.df))
  if (!is.null(bg.by)) {
    if (!bg.by %in% colnames(.df)) {
      cli::cli_abort("`bg.by` must be a column in the input data.")
    }
    .bg.values <- .df[[bg.by]]
    if (is.numeric(.bg.values) || is.integer(.bg.values)) {
      .bg.mask.global <- is.na(.bg.values) | .bg.values <= bg.cutoff
    } else if (is.logical(.bg.values)) {
      .bg.mask.global <- is.na(.bg.values) | as.numeric(.bg.values) <= bg.cutoff
    } else {
      if (length(bg.cutoff) == 0) {
        cli::cli_abort("When `bg.by` is categorical, `bg.cutoff` must contain one or more levels to background.")
      }
      .bg.mask.global <- is.na(.bg.values) | as.character(.bg.values) %in% as.character(bg.cutoff)
    }
  }
  .cell.all <- .df[[cell.column.nm]]
  if (!is.null(cells.highlight) && !isTRUE(cells.highlight)) {
    .cell.highlight <- intersect(cells.highlight, .cell.all)
    if (length(.cell.highlight) == 0) {
      cli::cli_abort("No cells in 'cells.highlight' are found in current assay")
      cells.highlight <- NULL
    } else if (length(.cell.highlight) < length(cells.highlight)) {
      cli::cli_alert("Some cells in 'cells.highlight' are NOT found in current assay")
      cells.highlight <- .cell.highlight
    }
  }
  .subtitle <- subtitle
  if (is.null(pt.size)) pt.size <- min(3000/nrow(.df), 0.5)
  raster <- raster %||% (nrow(.df) > 1e+05)
  if (isTRUE(raster)) ckPacsR("exaexa/scattermore")
  if (!is.null(x = raster.dpi)) {
    if (!is.numeric(x = raster.dpi) || length(x = raster.dpi) != 2) {
      stop("'raster.dpi' must be a two-length numeric vector")
    }
  }
  plist <- list()
  xlab <- xlab %||% paste0('dim', dims[1])
  ylab <- ylab %||% paste0('dim', dims[2])
  .theme.args.main <- theme.args
  .theme.args.stat <- theme.args
  if (identical(theme.use, "themeBlank")) {
    .theme.args.main[["xlab"]] <- xlab
    .theme.args.main[["ylab"]] <- ylab
    .theme.args.stat[["add.coord"]] <- FALSE
    .theme.args.stat[["xlab"]] <- NULL
    .theme.args.stat[["ylab"]] <- NULL
  }
  if (!is.null(stat.plot.by)) {
    .stat.plot <- statPlot(.df, group.by = group.by, stat.by = stat.plot.by, 
                           split.by = split.by, stat.type = stat.plot.source, 
                           plot.type = stat.plot.type, position = stat.plot.position, 
                           palette = stat.plot.palette, palcolor = stat.palcolor, 
                           alpha = stat.plot.alpha, label = stat.plot.label, 
                           label.size = stat.plot.label.size, legend.position = "bottom", 
                           legend.direction = legend.direction, theme.use = theme.use, 
                           theme.args = .theme.args.stat, each = TRUE, combine = FALSE)
  }
  .split.levels <- levels(.df[[split.by]])
  .comb <- expand.grid(split = .split.levels, group = group.by, stringsAsFactors = FALSE)
  .comb.nm <- paste0(.comb[["split"]], ":", .comb[["group"]])
  rownames(.comb) <- .comb.nm
  .plist <- lapply(.comb.nm, function(i) {
    .g <- .comb[i, "group"]
    .s <- .comb[i, "split"]
    colors <- paletteCustomize(levels(.df[[.g]]), palette = palette, palcolor = palcolor, keep.na = T)
    .dat <- .df
    .dat <- as.data.frame(.dat)
    .cells.dim <- .dat[[split.by]] != .s
    .cells.bg <- .bg.mask.global
    .dat[[.g]][.cells.dim | .cells.bg] <- NA
    .lst.legend <- list()
    .label.tb <- table(.dat[[.g]])
    .label.tb <- .label.tb[.label.tb != 0]
    .cells.highlight <- cells.highlight
    if (isTRUE(.cells.highlight)) .cells.highlight <- .cell.all[!.cells.dim]
    if (isTRUE(label.insitu)) {
      .label.use <- paste0(names(.label.tb))
      if (isTRUE(show.stat)) {
        .label.use <- paste0(names(.label.tb), "(", .label.tb, ")")
      } 
    } else {
      if (isTRUE(label)) {
        .label.use <- paste0(seq_along(.label.tb), ": ", names(.label.tb))
        if (isTRUE(show.stat)) {
          .label.use <- paste0(seq_along(.label.tb), ": ", names(.label.tb), "(", .label.tb, ")")
        }
      } else {
        .label.use <- paste0(names(.label.tb))
        if (isTRUE(show.stat)) {
          .label.use <- paste0(names(.label.tb), "(", .label.tb, ")")
        }
      }
    }
    #here
    .dat[["group.by"]] <- .dat[[.g]]
    .dat[, "split.by"] <- .s
    .dat.idx <- order(.dat[, "group.by"], decreasing = FALSE,  na.last = FALSE)
    .dat <- .dat[.dat.idx, , drop = FALSE]
    .na.gp <- is.na(.dat[, "group.by"])
    .na.idx <- which(.na.gp)
    .na.idx <- ifelse(length(.na.idx) > 0, max(.na.idx), 1)
    .dat <- .dat[c(1:.na.idx, sample((min(.na.idx + 1, nrow(.dat))):nrow(.dat))), , drop = FALSE]
    .sub.title <- subtitle
    if (isTRUE(show.stat)) {
      .sub.title <- subtitle %||% paste0(.s, " nCells:", sum(!is.na(.dat[["group.by"]])))
    }
    .mark.layer <- NULL
    .color.gp <- colors[names(.label.tb)]
    if (isTRUE(show.mark)) {
      suppressPackageStartupMessages(library(ggforce))
      if (mark.type == "ellipse" && nrow(.dat[!.na.gp, , drop = FALSE]) < 3) {
        mark.type <- "hull"
      }
      .mark.fun <- switch(mark.type, 
                         ellipse = "geom_mark_ellipse", 
                         hull = "geom_mark_hull", 
                         rect = "geom_mark_rect", 
                         circle = "geom_mark_circle")
      .mark.layer <- list(do.call(.mark.fun, 
                                  list(data = .dat[!.na.gp, , drop = FALSE], 
                                       mapping = aes(x = .data[["x"]],
                                                     y = .data[["y"]], 
                                                     color = .data[["group.by"]], 
                                                     fill = .data[["group.by"]]),
                                       expand = mark.expand, 
                                       alpha = mark.alpha, 
                                       linetype = mark.linetype, 
                                       show.legend = FALSE, 
                                       inherit.aes = FALSE)), 
                          scale_fill_manual(values = .color.gp), 
      scale_color_manual(values = .color.gp), 
      new_scale_fill(), 
      new_scale_color())
    }
    if (!is.null(graph)) {
      net <- visGraph(graph = graph, loci = .dat, edge.color = "black", 
                      edge.alpha = 0.5, edge.size = c(0.5, 5), show.legend = F)
    } else {
      net <- NULL
    }
    if (isTRUE(add.density)) {
      density <- visDense(data = .dat, fill = F, density.color = "grey80", 
                          palette = "Greys", palcolor =  NULL)
    }else {
      density <- NULL
    }
    .x.lim <- range(.dat$x, na.rm = TRUE)
    .y.lim <- range(.dat$y, na.rm = TRUE)
      p <- ggplot(.dat) + .mark.layer + net + density + 
      labs(title = title, subtitle = .sub.title, x = xlab, y = ylab) + 
      scale_x_continuous(limits = .x.lim) + 
      scale_y_continuous(limits = .y.lim) + 
      do.call(theme.use, .theme.args.main) + 
      theme(aspect.ratio = aspect.ratio, 
            legend.position = legend.position, 
            legend.direction = legend.direction)
    if (split.by != "All.groups") p <- p + facet_grid(. ~ split.by) + theme(strip.text = element_blank())
    .highlight.use <- !is.null(.cells.highlight) && !isTRUE(hex)
    .highlight.idx <- if (.highlight.use) .dat[[cell.column.nm]] %in% .cells.highlight else rep(FALSE, nrow(.dat))
    .non.highlight.alpha <- non.highlight.alpha %||% min(pt.alpha, 0.2)
    if (isTRUE(raster)) {
      if (.highlight.use && identical(highlight.mode, "contrast")) {
        p <- p + scattermore::geom_scattermore(
          data = .dat[!.highlight.idx, , drop = FALSE],
          mapping = aes(x = .data[["x"]], y = .data[["y"]]),
          color = non.highlight.col,
          pointsize = ceiling(pt.size),
          alpha = .non.highlight.alpha,
          pixels = raster.dpi
        )
      } else {
        p <- p + scattermore::geom_scattermore(data = .dat[.na.gp, , drop = FALSE], 
                                               mapping = aes(x = .data[["x"]], y = .data[["y"]]), 
                                               color = bg.color, pointsize = ceiling(pt.size), 
                                               alpha = pt.alpha, pixels = raster.dpi) + 
          scattermore::geom_scattermore(data = .dat[!.na.gp, , drop = FALSE], 
                                        mapping = aes(x = .data[["x"]], y = .data[["y"]], color = .data[["group.by"]]),
                                        pointsize = ceiling(pt.size), 
                                        alpha = pt.alpha, pixels = raster.dpi)
      }
    } else if (isTRUE(hex)) {
      ckPacsR("hexbin")
      if (isTRUE(hex.count)) {
        p <- p + geom_hex(mapping = aes(x = .data[["x"]], 
                                        y = .data[["y"]], 
                                        fill = .data[["group.by"]], 
                                        color = .data[["group.by"]], 
                                        alpha = after_stat(count)), 
                          linewidth = hex.linewidth, bins = hex.bins, 
                          binwidth = hex.binwidth)
      } else {
        p <- p + geom_hex(mapping = aes(x = .data[["x"]], 
                                        y = .data[["y"]], 
                                        fill = .data[["group.by"]], 
                                        color = .data[["group.by"]]), 
                          linewidth = hex.linewidth, bins = hex.bins,
                          binwidth = hex.binwidth)
      }
    } else {
      if (.highlight.use && identical(highlight.mode, "contrast")) {
        p <- p + geom_point(
          data = .dat[!.highlight.idx, , drop = FALSE],
          mapping = aes(x = .data[["x"]], y = .data[["y"]]),
          color = non.highlight.col,
          size = pt.size,
          alpha = .non.highlight.alpha
        )
      } else {
        p <- p + geom_point(mapping = aes(x = .data[["x"]], 
                                          y = .data[["y"]], 
                                          color = .data[["group.by"]]), 
                            size = pt.size, alpha = pt.alpha)
      }
    }
    if (!is.null(.cells.highlight) && !isTRUE(hex)) {
      .cell.df <- p$data[p$data[[cell.column.nm]] %in% .cells.highlight, , drop = FALSE]
      if (nrow(.cell.df) > 0) {
        if (isTRUE(raster)) {
          p <- p + scattermore::geom_scattermore(data = .cell.df, 
                                                 aes(x = .data[["x"]], 
                                                     y = .data[["y"]]), 
                                                 color = highlight.col, 
                                                 pointsize = floor(highlight.size) + highlight.stroke, 
                                                 alpha = highlight.alpha, 
                                                 pixels = raster.dpi) + 
            scattermore::geom_scattermore(data = .cell.df,
                                          aes(x = .data[["x"]],
                                              y = .data[["y"]],  
                                              color = .data[["group.by"]]), 
                                          pointsize = floor(highlight.size), 
                                          alpha = highlight.alpha, 
                                          pixels = raster.dpi)
        } else {
          p <- p + geom_point(data = .cell.df, 
                              aes(x = .data[["x"]], y = .data[["y"]]), 
                              color = highlight.col, 
                              size = highlight.size + highlight.stroke, 
                              alpha = highlight.alpha) + 
            geom_point(data = .cell.df, 
                       aes(x = .data[["x"]], y = .data[["y"]], color = .data[["group.by"]]), 
                       size = highlight.size, alpha = highlight.alpha)
        }
      }
    }
    .scale.name <- paste0(.g, ":")
    .scale.value <- colors[names(.label.tb)]
    p <- p + scale_color_manual(name = .scale.name, 
                                values = .scale.value, 
                                labels = .label.use, 
                                na.value = bg.color, 
                                guide = guide_legend(title.hjust = 0, order = 1, 
                                                     override.aes = list(size = 4, alpha = 1))) + 
      scale_fill_manual(name = .scale.name, 
                        values = .scale.value, 
                        labels = .label.use, 
                        na.value = bg.color,
                        guide = guide_legend(title.hjust = 0, order = 1))
    
    p_base <- p
    #here 
    if (!is.null(stat.plot.by)) {
      .coor.df.stat <- aggregate(p$data[, c("x", "y")], by = list(p$data[["group.by"]]), FUN = median)
      colnames(.coor.df.stat)[1] <- "group"
      .x.range <- diff(layer_scales(p)$x$range$range)
      .y.range <- diff(layer_scales(p)$y$range$range)
      .gp.levels <- levels(.dat[, "group.by"])
      .stat.plot.sub <- .stat.plot[paste0(.g, ":", .gp.levels, ":", .s)]
      names(.stat.plot.sub) <- .gp.levels
      .stat.plot.sub.lst <- list()
      for (i in seq_len(nrow(.coor.df.stat))) {
        .gp.c <- .coor.df.stat[i, "group"]
        .xmin <- .coor.df.stat[i, "x"] - .x.range * stat.plot.size/2
        .ymin <- .coor.df.stat[i, "y"] - .y.range * stat.plot.size/2
        .xmax <- .coor.df.stat[i, "x"] + .x.range * stat.plot.size/2
        .ymax <- .coor.df.stat[i, "y"] + .y.range * stat.plot.size/2
        .stat.plot.sub.lst[[i]] <- annotation_custom(xmin = .xmin, ymin = .ymin, 
                                                 xmax = .xmax, ymax = .ymax,
                                                 as_grob(.stat.plot.sub[[.gp.c]] + 
                                                           theme_void() + theme(legend.position = "none")))
      }
      .lst.legend[["stat.by"]] <- get_legend.local(.stat.plot.sub[[1]] + theme(legend.position = "bottom"))
      p <- p + .stat.plot.sub.lst
    }
    if (!is.null(lineages)) {
      lineages_layers <- c(list(new_scale_color()), lineages_layers)
      suppressMessages({
        .lst.legend[["lineages"]] <- get_legend(ggplot() + 
                                                  lineages_layers + theme_scp(legend.position = "bottom", 
                                                                              legend.direction = legend.direction))
      })
      p <- suppressWarnings({
        p + lineages_layers + theme(legend.position = "none")
      })
      if (is.null(.lst.legend[["lineages"]])) {
        .lst.legend["lineages"] <- list(NULL)
      }
    }
    if (!is.null(paga)) {
      paga_layers <- c(list(new_scale_color()), paga_layers)
      if (g != paga$groups) {
        suppressMessages({
          .lst.legend[["paga"]] <- get_legend(ggplot() + 
                                                paga_layers + theme_scp(legend.position = "bottom", 
                                                                        legend.direction = legend.direction))
        })
      }
      p <- suppressWarnings({
        p + paga_layers + theme(legend.position = "none")
      })
      if (is.null(legend_list[["paga"]])) {
        .lst.legend["paga"] <- list(NULL)
      }
    }
    if (!is.null(velocity)) {
      velocity_layers <- c(list(new_scale_color()), 
                           list(new_scale("size")), velocity_layers)
      if (velocity_plot_type != "raw") {
        suppressMessages({
          .lst.legend[["velocity"]] <- get_legend(ggplot() + 
                                                    velocity_layers + theme_scp(legend.position = "bottom", 
                                                                                legend.direction = legend.direction))
        })
      }
      p <- suppressWarnings({
        p + velocity_layers + theme(legend.position = "none")
      })
      if (is.null(.lst.legend[["velocity"]])) {
        .lst.legend["velocity"] <- list(NULL)
      }
    }
    if (isTRUE(label)) {
      .label.df <- aggregate(p$data[, c("x", "y")], by = list(p$data[["group.by"]]), FUN = median)
      colnames(.label.df)[1] <- "label"
      .label.df <- .label.df[!is.na(.label.df[, "label"]), , drop = FALSE]
      if (!isTRUE(label.insitu)) .label.df[, "label"] <- seq_len(nrow(.label.df))
      if (isTRUE(label.repel)) {
        p <- p + geom_point(data = .label.df, 
                            mapping = aes(x = .data[["x"]], y = .data[["y"]]), 
                            color = label.pt.color, 
                            size = label.pt.size) + 
          geom_text_repel(data = .label.df, 
                          aes(x = .data[["x"]], y = .data[["y"]], label = .data[["label"]]), 
                          fontface = "bold", min.segment.length = 0, 
                          segment.color = label.seg.color, 
                          point.size = label.pt.size, max.overlaps = 100, 
                          force = label.repulsion, color = label.fg, 
                          bg.color = label.bg, bg.r = label.bg.r, 
                          size = label.size, inherit.aes = FALSE)
      } else {
        p <- p + geom_text_repel(data = .label.df, 
                                 aes(x = .data[["x"]], y = .data[["y"]], 
                                     label = .data[["label"]]), fontface = "bold", 
                                 min.segment.length = 0, segment.color = label.seg.color, 
                                 point.size = NA, max.overlaps = 100, force = 0, 
                                 color = label.fg, bg.color = label.bg, bg.r = label.bg.r, 
                                 size = label.size, inherit.aes = FALSE)
      }
    }
    if (length(.lst.legend) > 0) {
      .lst.legend <- .lst.legend[!sapply(.lst.legend, is.null)]
      .legend <- get_legend.local(p_base + themeDefault(legend.position = "bottom", legend.direction = legend.direction))
      if (legend.direction == "vertical") {
        legend <- do.call(cbind, c(list(base = .legend), .lst.legend))
      } else {
        legend <- do.call(rbind, c(list(base = .legend), .lst.legend))
      }
      gtable <- as_grob(p + theme(legend.position = "none"))
      gtable <- add_grob.local(gtable, legend, legend.position)
      p <- patchwork::wrap_plots(gtable)
    }
    return(p)
  })
  if (isTRUE(combine)) {
    if (length(.plist) > 1) {
      plot <- patchwork::wrap_plots(plotlist = .plist, nrow = nrow, ncol = ncol, byrow = byrow)
    }
    else {
      plot <- .plist[[1]]
    }
    return(plot)
  }
  else {
    return(.plist)
  }
}
