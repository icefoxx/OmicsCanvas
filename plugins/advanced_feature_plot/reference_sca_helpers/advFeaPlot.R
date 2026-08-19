advFeaPlot <- function (data, graph = NULL, lineage = NULL, group.by = NULL, split.by = NULL, 
                        global.split = TRUE, bg.by = NULL, dims = c(1, 2), 
                        cell.column.nm = "cell.barcodes.selected", keep.0  = F,
                        features = NULL,
                        show.stat = ifelse(identical(theme.use, "themeBlank"), FALSE, TRUE), 
                        palette = ifelse(isTRUE(feature.comp), "Set1", "Spectral"), 
                        palcolor = NULL, pt.size = NULL, pt.alpha = 1, 
                        bg.cutoff = 0, bg.color = "grey80", scale.by = "feature",
                        quantile.cutoff = c(0, 0.95), value.cutoff = NULL,
                        value.scale.range = NULL, value.scale.breaks = NULL,
                        feature.low.alpha = 0.1,
                        add.density = FALSE, density.filled = F, density.color = "grey80",
                        density.palette = "Greys", density.palcolor = NULL, 
                        cells.highlight = NULL, highlight.col = "black", 
                        highlight.size = 1, highlight.alpha = 1, label = TRUE,
                        group.label = FALSE, group.label.repel = TRUE, group.label.size = 4,
                        group.label.fg = "black", group.label.bg = "white", group.label.bg.r = 0.1,
                        group.label.seg.color = "black",
                        highlight.stroke = 0.5, coexp = FALSE, feature.comp = FALSE,
                        color.mix.mode = c("blend", "average", "screen", "multiply"),
                        legend.title = NULL, legend.label = FALSE, legend.label.size = 4, 
                        legend.label.fg = "white", legend.label.bg = "black", 
                        legend.label.bg.r = 0.1, label.insitu = FALSE, 
                        label.repel = FALSE,  label.repulsion = 20, 
                        label.pt.size = 1, label.pt.color = "black", 
                        label.seg.color = "black", lineages = NULL, 
                        lineages_trim = c(0.01, 0.99), lineages_span = 0.75, 
                        lineages_palette = "Dark2", lineages_palcolor = NULL, 
                        lineages_arrow = arrow(length = unit(0.1, "inches")), 
                        lineages_linewidth = 1, lineages_line_bg = "white", 
                        lineages_line_bg_stroke = 0.5, lineages_whiskers = FALSE, 
                        lineages_whiskers_linewidth = 0.5, lineages_whiskers_alpha = 0.5, 
                        edge.size = c(0.05, 0.5), edge.alpha = 0.1, 
                        edge.color = "grey40", hex = FALSE, hex.linewidth = 0.5, 
                        hex.color = "grey90", hex.bins = 50, hex.binwidth = NULL, 
                        raster = NULL, raster.dpi = c(512, 512), aspect.ratio = 1, 
                        title = NULL, subtitle = NULL, xlab = NULL, ylab = NULL, 
                        legend.position = "right", legend.direction = "vertical", 
                        theme.use = "themeDefault", theme.args = list(), combine = TRUE, 
                        nrow = NULL, ncol = NULL, byrow = TRUE, force = FALSE, seed = 10086) 
{
  suppressPackageStartupMessages({
    library(tidyverse)
    library(rlang)
    library(ggrepel)
    library(ggnewscale)
    library(gtable)
  })
  set.seed(seed)
  .color.mix.mode <- match.arg(color.mix.mode)
  data <- as.data.frame(data)
  if (!is.null(scale.by)) .scale.by <- match.arg(scale.by, choices = c("feature", "all"))
  if (!is.null(value.scale.range)) {
    if (!is.numeric(value.scale.range) || length(value.scale.range) != 2 || any(!is.finite(value.scale.range))) {
      cli::cli_abort("`value.scale.range` must be a finite numeric vector of length 2.")
    }
    value.scale.range <- sort(value.scale.range)
  }
  if (!is.null(value.scale.breaks) && (!is.numeric(value.scale.breaks) || any(!is.finite(value.scale.breaks)))) {
    cli::cli_abort("`value.scale.breaks` must be a finite numeric vector.")
  }
  if (!is.numeric(feature.low.alpha) || length(feature.low.alpha) != 1 || !is.finite(feature.low.alpha) ||
      feature.low.alpha < 0 || feature.low.alpha > 1) {
    cli::cli_abort("`feature.low.alpha` must be a single numeric value between 0 and 1.")
  }
  .add_group_labels <- function(p, dat, group.by) {
    if (is.null(group.by) || !isTRUE(group.label)) {
      return(p)
    }
    if (!group.by %in% colnames(dat)) {
      cli::cli_abort("`group.by` column '{group.by}' is not present in the plotting data.")
    }
    .label.df <- aggregate(dat[, c("x", "y"), drop = FALSE], by = list(label = as.character(dat[[group.by]])), FUN = median)
    .label.df <- .label.df[!is.na(.label.df[["label"]]) & .label.df[["label"]] != "NA", , drop = FALSE]
    if (nrow(.label.df) == 0) {
      return(p)
    }
    if (isTRUE(group.label.repel)) {
      p + geom_text_repel(
        data = .label.df,
        aes(x = .data[["x"]], y = .data[["y"]], label = .data[["label"]]),
        fontface = "bold",
        min.segment.length = 0,
        segment.color = group.label.seg.color,
        point.size = NA,
        max.overlaps = 100,
        force = label.repulsion,
        color = group.label.fg,
        bg.color = group.label.bg,
        bg.r = group.label.bg.r,
        size = group.label.size,
        inherit.aes = FALSE
      )
    } else {
      p + geom_text(
        data = .label.df,
        aes(x = .data[["x"]], y = .data[["y"]], label = .data[["label"]]),
        fontface = "bold",
        color = group.label.fg,
        size = group.label.size,
        inherit.aes = FALSE
      )
    }
  }
  .resolve_legend_titles <- function(features, legend.title = NULL) {
    if (is.null(legend.title)) {
      return(stats::setNames(features, features))
    }
    legend.title <- as.character(legend.title)
    if (!is.null(names(legend.title)) && all(features %in% names(legend.title))) {
      return(legend.title[features])
    }
    if (length(legend.title) == 1) {
      return(stats::setNames(rep(legend.title, length(features)), features))
    }
    if (length(legend.title) == length(features)) {
      return(stats::setNames(legend.title, features))
    }
    cli::cli_abort("`legend.title` must be `NULL`, length 1, length equal to plotted features, or a named vector keyed by feature.")
  }
  .rescale_display_values <- function(x, from = NULL, to = NULL) {
    if (is.null(to)) {
      return(x)
    }
    .out <- x
    .finite <- is.finite(x)
    if (!any(.finite)) {
      return(.out)
    }
    .from <- from %||% range(x[.finite], na.rm = TRUE)
    if (length(.from) != 2 || any(!is.finite(.from))) {
      return(.out)
    }
    if (diff(.from) == 0) {
      .out[.finite] <- mean(to)
      return(.out)
    }
    .out[.finite] <- scales::rescale(x[.finite], from = .from, to = to)
    .out
  }
  if (cell.column.nm %in% colnames(data)) {
    .cell.all <- data[[cell.column.nm]]
    rownames(data) <- .cell.all
    data[[cell.column.nm]] <- NULL
    print(cell.column.nm)
  }
  .feas <- colnames(data)
  .instric.v <- c('x', 'y', group.by, split.by)
  .feas.plot <- setdiff(.feas, .instric.v)
  if (length(.feas.plot) == 0) cli::cli_abort('At least 1 feature detected in the data except the xy loci information.')
  if (length(.feas.plot) > 20 && !isTRUE(force)) {
    warning("More than 50 features to be plotted", immediate. = TRUE)
    answer <- askYesNo("Are you sure to continue?", default = FALSE)
    if (!isTRUE(answer)) {
      return(invisible(NULL))
    }
  }
  if (!is.null(features)) {
    .features.requested <- if (is.list(features)) unlist(features, use.names = FALSE) else features
    if (!inherits(.features.requested, "character")) stop("'features' is not a character vector")
    .features.missing <- setdiff(.features.requested, colnames(data))
    if (length(.features.missing) > 0) {
      cli::cli_abort("Feature(s) not found in plotting data: {paste(.features.missing, collapse = ', ')}")
    }
    .feas.plot <- intersect(.features.requested, .feas.plot)
    if (length(.feas.plot) == 0) cli::cli_abort("No requested numeric feature column remains after excluding x/y/group/split columns.")
  }
  .df.fmt <- formatDF4statPlot(df = data, stat.by = .feas, split.by = split.by, 
                               bg.by = bg.by, stat.by.factorize = F, return.all = T)
  .df <- .df.fmt$df
  .feas.plot.numeric <- .feas.plot[sapply(.df[, .feas.plot, drop = FALSE], is.numeric)]
  .feas.plot.skipped <- setdiff(.feas.plot, .feas.plot.numeric)
  if (length(.feas.plot.skipped) > 0) {
    cli::cli_alert_warning("Skipping non-numeric feature(s) in {.fn advFeaPlot}: {paste(.feas.plot.skipped, collapse = ', ')}")
  }
  .feas.plot <- .feas.plot.numeric
  if (length(.feas.plot) == 0) {
    cli::cli_abort("No numeric features are available to plot after removing x/y and grouping columns.")
  }
  if (is.null(split.by)) {
    split.by <- "All.groups"
  }
  if (!is.null(cells.highlight)) {
    .cell.highlight <- intersect(cells.highlight, .cell.all)
    if (length(.cell.highlight) == 0) {
      cli::cli_abort("No cells in 'cells.highlight' are found in current assay")
      cells.highlight <- NULL
    } else if (length(.cell.highlight) < length(cells.highlight)) {
      cli::cli_alert("Some cells in 'cells.highlight' are NOT found in current assay")
      cells.highlight <- .cell.highlight
    }
  }
  if (isFALSE(keep.0)) {
    for(f in .feas.plot){
      .tmp.v <- .df[[f]]
      .tmp.v[.tmp.v <= bg.cutoff] <- NA
      .df[[f]] <- .tmp.v
    }
  }
  .subtitle <- subtitle
  if (is.null(.subtitle)) .subtitle <- paste0('Featureplot: ', .feas.plot)
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
  if (identical(theme.use, "themeBlank")) {
    theme.args[["xlab"]] <- xlab
    theme.args[["ylab"]] <- ylab
  }
  .split.levels <- levels(.df[[split.by]])
  if (isTRUE(feature.comp) && length(.feas.plot) > 1) {
    .legend.title.map <- .resolve_legend_titles(.feas.plot, legend.title = legend.title)
    .df.split <- split.data.frame(.df, .df[[split.by]])
    plist <- lapply(.split.levels, function(s) {
      .dat <- .df.split[[ifelse(split.by == "All.groups", 1, s)]]
      .dat <- as.data.frame(.dat)
      for (f in .feas.plot) {
        .dat.f.v <- .dat[, f, drop = T]
        if (any(is.infinite(.dat.f.v))) {
          .dat.f.v.r <- range(.dat.f.v[is.finite(.dat.f.v)], na.rm = T)
          .dat.f.v[.dat.f.v == min(.dat.f.v, na.rm = TRUE)] <- .dat.f.v.r[1]
          .dat.f.v[.dat.f.v == max(.dat.f.v, na.rm = TRUE)] <- .dat.f.v.r[2]
          .dat[, f, with = F] <- .dat.f.v
        }
      }
      .dat[, "split.by"] <- s
      .dat[, "features"] <- paste(.feas.plot, collapse = "|")
      .subtitle.s <- paste0(.feas.plot, collapse = "|") %||% s
      .colors <- paletteCustomize(.feas.plot, type = "discrete", palette = palette, palcolor = palcolor)
      .lst.col <- list()
      .lst.val <- list()
      .lst.pal <- list()
      .lst.legend <- list()
      .geom.tmp <- list()
      .legend.breaks.use <- if (!is.null(value.scale.range)) {
        value.scale.breaks %||% pretty(value.scale.range, n = 5)
      } else {
        ggplot2::waiver()
      }
      .scale.from.lst <- setNames(vector("list", length(.feas.plot)), .feas.plot)
      if (!is.null(value.scale.range)) {
        if (is.null(scale.by) || identical(scale.by, "feature")) {
          .scale.from.lst <- lapply(.feas.plot, function(f) {
            .v <- .dat[[f]]
            .v <- .v[is.finite(.v)]
            if (length(.v) == 0) c(NA_real_, NA_real_) else range(.v, na.rm = TRUE)
          })
          names(.scale.from.lst) <- .feas.plot
        } else if (identical(scale.by, "all")) {
          .v.all <- unlist(.dat[, .feas.plot, drop = FALSE], use.names = FALSE)
          .v.all <- .v.all[is.finite(.v.all)]
          .range.all <- if (length(.v.all) == 0) c(NA_real_, NA_real_) else range(.v.all, na.rm = TRUE)
          .scale.from.lst <- stats::setNames(rep(list(.range.all), length(.feas.plot)), .feas.plot)
        }
      }
      for (i in seq_along(.colors)) {
        .aim.feas <- names(.colors)[i]
        .dat.v <- .dat[[.aim.feas]]
        .dat.v.display <- .rescale_display_values(.dat.v, from = .scale.from.lst[[.aim.feas]], to = value.scale.range)
        .feature.low.color <- col4alpha(.colors[i], feature.low.alpha)
        .lst.col[[i]] <- paletteCustomize(.dat.v.display, color.na = NA, keep.na = TRUE, 
                                        matched = TRUE, type = "continuous", 
                                        palcolor = c(.feature.low.color, .colors[i]))
        .lst.pal[[i]] <- paletteCustomize(.dat.v.display, color.na = NA, keep.na = FALSE, 
                                     matched = FALSE, type = "continuous",
                                     palcolor = c(.feature.low.color, .colors[i]))
        .lst.val[[i]] <- if (!is.null(value.scale.range)) {
          seq(value.scale.range[1], value.scale.range[2], length.out = 100)
        } else {
          seq(min(.dat.v.display, na.rm = TRUE), max(.dat.v.display, na.rm = TRUE), length.out = 100)
        }
        .dat.legend <- .dat
        .dat.legend[["value.display"]] <- .dat.v.display
        .geom.tmp[[i]] <- list(geom_point(data = .dat.legend, 
                                          mapping = aes(x = .data[["x"]], 
                                                        y = .data[["y"]], 
                                                        color = .data[["value.display"]])))
        if (all(is.na(.lst.col[[i]]))) {
          .geom.tmp[[i]] <- append(.geom.tmp[[i]], 
                                   scale_colour_gradient(name = .legend.title.map[[.aim.feas]], na.value = bg.color, 
                                                         breaks = .legend.breaks.use,
                                                         guide = guide_colorbar(frame.colour = "black", 
                                                                                ticks.colour = "black", 
                                                                                title.hjust = 0)))
        } else if (length(.lst.col[[i]]) == 1) {
          .geom.tmp[[i]] <- append(.geom.tmp[[i]], scale_colour_gradient(name = .legend.title.map[[.aim.feas]], low = .lst.col[[i]], 
                                                                         breaks = .legend.breaks.use,
                                                                         na.value = bg.color, 
                                                                         guide = guide_colorbar(frame.colour = "black", 
                                                                                                ticks.colour = "black", 
                                                                                                title.hjust = 0)))
        } else {
          .geom.tmp[[i]] <- append(.geom.tmp[[i]], scale_color_gradientn(name = .legend.title.map[[.aim.feas]], colours = .lst.pal[[i]], 
                                                                         values = scales::rescale(.lst.val[[i]]), breaks = .legend.breaks.use,
                                                                         na.value = bg.color, 
                                                                         guide = guide_colorbar(frame.colour = "black", 
                                                                                                ticks.colour = "black", 
                                                                                                title.hjust = 0)))
        }
        .lst.legend[[i]] <- get_legend(ggplot(.dat, aes(x = .data[["x"]], y = .data[["y"]])) + 
                                         .geom.tmp[[i]] + do.call(theme.use,  theme.args) + 
                                         theme(aspect.ratio = aspect.ratio, legend.position = legend.position, legend.direction = legend.direction))
      }
      .feat.norm <- sapply(.feas.plot, function(f) {
        .v <- .dat[[f]]
        .v.finite <- .v[is.finite(.v)]
        if (length(.v.finite) == 0) {
          return(rep(0, length(.v)))
        }
        .v.range <- range(.v.finite, na.rm = TRUE)
        if (diff(.v.range) == 0) {
          .out <- rep(0, length(.v))
          .out[is.finite(.v) & .v > 0] <- 1
          return(.out)
        }
        .out <- scales::rescale(.v, to = c(0, 1), from = .v.range)
        .out[!is.finite(.out)] <- 0
        .out
      })
      .feat.norm <- as.matrix(.feat.norm)
      rownames(.feat.norm) <- rownames(.dat)
      for (j in seq_len(nrow(.dat))) {
        .dat[j, "color_blend"] <- blendcolors(sapply(.lst.col, function(x) x[j]), mode = color.mix.mode)
      }
      .dat["color_value"] <- colSums(col2rgb(.dat[, "color_blend"]))
      .dat[["plot_signal"]] <- rowSums(.feat.norm, na.rm = TRUE)
      .dat[["plot_balance"]] <- apply(.feat.norm, 1, function(x) {
        .x <- x[is.finite(x) & x > 0]
        if (length(.x) <= 1) {
          return(0)
        }
        1 - (max(.x) - min(.x)) / max(sum(.x), .Machine$double.eps)
      })
      .dat[["plot_bg"]] <- rowSums(is.na(.dat[, names(.colors), drop = FALSE])) == length(.colors)
      .dat[.dat[["plot_bg"]], "color_value"] <- NA
      .dat[.dat[["plot_bg"]], "color_blend"] <- bg.color
      .dat[["plot_layer"]] <- ifelse(.dat[["plot_bg"]], 0, 1)
      .dat[["plot_seed"]] <- stats::runif(nrow(.dat))
      .dat <- .dat[order(.dat[["plot_layer"]], .dat[["plot_signal"]], .dat[["plot_balance"]], .dat[["plot_seed"]], decreasing = FALSE, na.last = FALSE), , drop = FALSE]
      .cell.highlight.use <- cells.highlight
      if (!is.null(.cell.highlight.use)) {
        .cell.highlight.use <- rownames(.dat)[.dat[["color_blend"]] != bg.color]
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
      .limits.x <- c(min(.dat[["x"]], na.rm = TRUE), max(.dat[["x"]], na.rm = TRUE))
      .limits.y <- c(min(.dat[["y"]], na.rm = TRUE), max(.dat[["y"]], na.rm = TRUE))
      p <- ggplot(.dat) + net + density + 
        labs(title = title,  subtitle = .subtitle.s, x = xlab, y = ylab) + 
        scale_x_continuous(limits = .limits.x) + 
        scale_y_continuous(limits = .limits.y)
      if (split.by == "All.groups") {
        p <- p + facet_grid(. ~ features)
      } else {
        p <- p + facet_grid(split.by ~ features)
      }
      p <- p + do.call(theme.use, theme.args) + 
        theme(aspect.ratio = aspect.ratio, 
              legend.position = "none", 
              legend.direction = legend.direction)
      if (isTRUE(raster)) {
        .blend.idx <- .dat$color_blend == bg.color
        p <- p + scattermore::geom_scattermore(data = .dat[which(.blend.idx), , drop = FALSE], 
                                               mapping = aes(x = .data[["x"]], 
                                                             y = .data[["y"]], 
                                                             color = .data[["color_blend"]]), 
                                               pointsize = ceiling(pt.size), 
                                               alpha = pt.alpha, pixels = raster.dpi) + 
          scattermore::geom_scattermore(data = .dat[which(!.blend.idx), , drop = FALSE], 
                                        mapping = aes(x = .data[["x"]], 
                                                      y = .data[["y"]], 
                                                      color = .data[["color_blend"]]), 
                                        pointsize = ceiling(pt.size), 
                                        alpha = pt.alpha, pixels = raster.dpi) + 
          scale_color_identity() + 
          new_scale_color()
      } else if (isTRUE(hex)) {
        ckPacsR("hexbin")
        .hex.xbins <- hex.bins
        if (!is.null(hex.binwidth)) {
          .hex.binwidth.x <- hex.binwidth[[1]]
          if (is.numeric(.hex.binwidth.x) && is.finite(.hex.binwidth.x) && .hex.binwidth.x > 0) {
            .hex.xbins <- max(1, ceiling(diff(.limits.x) / .hex.binwidth.x))
          }
        }
        .hex.bin <- hexbin::hexbin(
          x = .dat[["x"]],
          y = .dat[["y"]],
          xbins = .hex.xbins,
          xbnds = .limits.x,
          ybnds = .limits.y,
          shape = diff(.limits.y) / diff(.limits.x),
          IDs = TRUE
        )
        .hex.centers <- hexbin::hcell2xy(.hex.bin)
        .hex.dat <- data.frame(
          hex_id = .hex.bin@cell,
          x = .hex.centers$x,
          y = .hex.centers$y,
          color_blend = bg.color,
          stringsAsFactors = FALSE
        )
        .blend.idx <- is.na(.dat$color_blend) | .dat$color_blend == bg.color
        if (any(!.blend.idx)) {
          .hex.colors <- tapply(which(!.blend.idx), .hex.bin@cID[!.blend.idx], function(idx) {
            .rgb.mean <- rowMeans(grDevices::col2rgb(.dat$color_blend[idx]))
            grDevices::rgb(.rgb.mean[1], .rgb.mean[2], .rgb.mean[3], maxColorValue = 255)
          })
          .hex.match <- match(.hex.dat$hex_id, as.integer(names(.hex.colors)))
          .hex.dat$color_blend[!is.na(.hex.match)] <- unname(.hex.colors[.hex.match[!is.na(.hex.match)]])
        }
        .sx <- .hex.bin@xbins / diff(.hex.bin@xbnds)
        .sy <- (.hex.bin@xbins * .hex.bin@shape) / diff(.hex.bin@ybnds)
        .inner <- 0.5
        .outer <- (2 * .inner) / sqrt(3)
        .dx <- .inner / .sx
        .dy <- .outer / (2 * .sy)
        .hex.coords <- hexbin::hexcoords(.dx, .dy, sep = NULL)
        .hex.poly <- data.frame(
          x = rep(.hex.coords$x, times = nrow(.hex.dat)) + rep(.hex.dat$x, each = length(.hex.coords$x)),
          y = rep(.hex.coords$y, times = nrow(.hex.dat)) + rep(.hex.dat$y, each = length(.hex.coords$y)),
          hex_id = rep(.hex.dat$hex_id, each = length(.hex.coords$x)),
          color_blend = rep(.hex.dat$color_blend, each = length(.hex.coords$x)),
          stringsAsFactors = FALSE
        )
        p <- p + geom_polygon(
          data = .hex.poly,
          mapping = aes(x = .data[["x"]], y = .data[["y"]], group = .data[["hex_id"]], fill = .data[["color_blend"]]),
          color = hex.color,
          linewidth = hex.linewidth,
          inherit.aes = FALSE
        ) +
          scale_fill_identity()
      } else {
        p <- p + geom_point(mapping = aes(x = .data[["x"]], 
                                          y = .data[["y"]], 
                                          color = .data[["color_blend"]]), 
                            size = pt.size, alpha = pt.alpha) + 
          scale_color_identity() + 
          new_scale_color()
      }
      if (!is.null(.cell.highlight.use) && !isTRUE(hex)) {
        .cell.df <- subset(p$data, rownames(p$data) %in% 
                            .cell.highlight.use)
        if (nrow(.cell.df) > 0) {
          if (isTRUE(raster)) {
            p <- p + scattermore::geom_scattermore(data = .cell.df, 
                                                   aes(x = .data[["x"]], 
                                                       y = .data[["y"]]), 
                                                   color = highlight.col, 
                                                   pointsize = floor(highlight.size) + highlight.stroke, alpha = highlight.alpha, 
                                                   pixels = raster.dpi) + 
              scattermore::geom_scattermore(data = .cell.df, aes(x = .data[["x"]], 
                                                                 y = .data[["y"]],  
                                                                 color = .data[["color_blend"]]), 
                                            pointsize = floor(highlight.size), 
                                            alpha = highlight.alpha, 
                                            pixels = raster.dpi) + 
              scale_color_identity() + new_scale_color()
          } else {
            p <- p + geom_point(data = .cell.df, aes(x = .data[["x"]], 
                                                    y = .data[["y"]]), 
                                color = highlight.col, 
                                size = highlight.size + highlight.stroke, 
                                alpha = highlight.alpha) +
              geom_point(data = .cell.df, aes(x = .data[["x"]], 
                                              y = .data[["y"]], 
                                              color = .data[["color_blend"]]), 
                         size = highlight.size, alpha = highlight.alpha) + 
              scale_color_identity() + new_scale_color()
          }
        }
      }
      p <- .add_group_labels(p, .dat, group.by = group.by)
      legend2 <- NULL
      .label.df <- NULL
      if (isTRUE(label)) {
        .label.df <- reshape2::melt(p$data, measure.vars = .feas.plot)
        .label.df <- .label.df %>% group_by(variable) %>% 
          filter(value >= quantile(value[is.finite(value)], quantile.cutoff[2], na.rm = TRUE) & 
                   value <= quantile(value[is.finite(value)], 0.99, na.rm = TRUE)) %>%
          reframe(x = median(.data[["x"]]), y = median(.data[["y"]])) %>% 
          drop_na() %>% as.data.frame() 
        colnames(.label.df)[1] <- "label"
        .label.df[, "rank"] <- seq_len(nrow(.label.df))
        if (isTRUE(label.insitu)) {
          if (isTRUE(label.repel)) {
            p <- p + geom_point(data = .label.df, 
                                mapping = aes(x = .data[["x"]], y = .data[["y"]]), 
                                color = label.pt.color, 
                                size = label.pt.size)
          }
          p <- p + geom_text_repel(data = .label.df, 
                              aes(x = .data[["x"]],
                                  y = .data[["y"]], 
                                  label = .data[["label"]], 
                                  color = .data[["label"]]), 
                              fontface = "bold", 
                              min.segment.length = 10, 
                              segment.color = label.seg.color, 
                              point.size = ifelse(label.repel, label.pt.size, NA),
                              max.overlaps = 100, 
                              force = ifelse(label.repel, label.repulsion, 0),
                              color = legend.label.fg, bg.color = legend.label.bg, 
                              bg.r = legend.label.bg.r, size = legend.label.size, 
                              inherit.aes = FALSE, show.legend = FALSE)
        }
        p <- p + scale_color_manual(name = "Label:", values = col4alpha(.colors[.label.df$label], 0.5), 
                                      labels = .label.df$label, na.value = bg.color)
      } else if (isTRUE(legend.label)) {
        .label.df <- reshape2::melt(p$data, measure.vars = .feas.plot)
        .label.df <- .label.df %>% group_by(variable) %>% 
          filter(value >= quantile(value[is.finite(value)], quantile.cutoff[2], na.rm = TRUE) & 
                   value <= quantile(value[is.finite(value)], 0.99, na.rm = TRUE)) %>%
          reframe(x = median(.data[["x"]]), y = median(.data[["y"]])) %>% 
          drop_na() %>% as.data.frame()
        colnames(.label.df)[1] <- "label"
        .label.df[, "rank"] <- seq_len(nrow(.label.df))
        if (isTRUE(label.repel)) {
          p <- p + geom_point(data = .label.df, 
                              mapping = aes(x = .data[["x"]], y = .data[["y"]]), 
                              color = "black", size = pt.size + 1)
        }
        p <- p + geom_text_repel(data = .label.df, 
                                 aes(x = .data[["x"]],
                                     y = .data[["y"]], 
                                     label = .data[["rank"]], 
                                     color = .data[["label"]]), 
                                 fontface = "bold", min.segment.length = 0, 
                                 segment.color = label.seg.color,
                                 point.size = ifelse(isTRUE(label.repel), pt.size + 1, NA),
                                 max.overlaps = 100, key_glyph = "point",
                                 force = ifelse(label.repel, label.repulsion, 0), 
                                 bg.color = legend.label.bg, bg.r = legend.label.bg.r, 
                                 size = legend.label.size, inherit.aes = FALSE)
        p <- p + 
          scale_color_manual(name = "Label:", 
                                    values = col4alpha(.colors[.label.df$label], 0.5), 
                                    labels = paste(.label.df$rank, .label.df$label, sep = ": "), 
                                    na.value = bg.color) + 
          guides(colour = guide_legend(override.aes = list(color = .colors[.label.df$label]), order = 1)) + 
          theme(legend.position = "none")
        legend2 <- get_legend(p + do.call(theme.use, theme.args) + 
                                theme(aspect.ratio = aspect.ratio, 
                                      legend.position = legend.position, 
                                      legend.direction = legend.direction))
      }
      .legend.nrow <- min(ceiling(sqrt(length(.lst.legend))), 3)
      .lst.legend.n <- length(.lst.legend)
      .lst.legend.new <- list()
      n <- 1
      for (i in 1:.lst.legend.n) {
        if (i == 1 || is.null(.tmp.leg)) {
          .tmp.leg <- .lst.legend[[i]]
        }
        else {
          .tmp.leg <- cbind(.tmp.leg, .lst.legend[[i]])
        }
        if (i %% .legend.nrow == 0) {
          .lst.legend.new[[n]] <- .tmp.leg
          .tmp.leg <- NULL
          n <- n + 1
        }
        if (i %% .legend.nrow != 0 && i == .lst.legend.n) {
          .ncol.insert <- dim(.lst.legend.new[[n - 1]])[2] - dim(.tmp.leg)[2]
          for (.nouse in 1:.ncol.insert) {
            .tmp.leg <- gtable_add_cols(.tmp.leg, sum(.lst.legend[[n - 1]]$widths)/.ncol.insert, -1)
          }
          .lst.legend.new[[n]] <- .tmp.leg
        }
      }
      legend <- do.call(rbind, .lst.legend.new)
      if (!is.null(lineages)) {
        lineages_layers <- c(list(new_scale_color()), 
                             lineages_layers)
        suppressMessages({
          legend_curve <- get_legend(ggplot() + lineages_layers + 
                                       theme_scp())
        })
        legend <- add_grob.local(legend, legend_curve, "top")
        p <- suppressMessages({
          p + lineages_layers + theme(legend.position = "none")
        })
      }
      gtable <- as_grob(p)
      gtable <- add_grob.local(gtable, legend, legend.position)
      if (!is.null(legend2)) {
        gtable <- add_grob.local(gtable, legend2, legend.position)
      }
      p <- patchwork::wrap_plots(gtable)
      return(p)
    })
    names(plist) <- paste0(.split.levels, ":", paste0(.feas.plot, collapse = "|"))
  } else {
    .comb <- expand.grid(split = levels(.df[[split.by]]), feature = .feas.plot, stringsAsFactors = FALSE)
    .comb.nm <- paste0('Featureplot:', .comb[["split"]], ":", .comb[["feature"]])
    rownames(.comb) <- .comb.nm
    names(.comb.nm) <- .feas.plot
    .df.split <- split.data.frame(.df, .df[[split.by]])
    colors <- paletteCustomize(type = "continuous", palette = palette, palcolor = palcolor)
    ###here
    plist <- lapply(.comb.nm, function(i) {
                      .f <- .comb[i, "feature"]
                      .s <- .comb[i, "split"]
                      .dat <- .df.split[[ifelse(split.by == "All.groups", 1, .s)]]
                      .f.v <- .dat[[.f]]
                      .f.v.range <- range(.f.v[is.finite(.f.v)], na.rm = TRUE)
                      .f.v[.f.v == min(.f.v, na.rm = TRUE)] <- .f.v.range[1]
                      .f.v[.f.v == max(.f.v, na.rm = TRUE)] <- .f.v.range[2]
                      .dat[, .f] <- .f.v
                      .dat[["value"]] <- .dat[[.f]]
                      .dat <- .dat[order(.dat[, "value"], method = "radix", 
                                         decreasing = FALSE, na.last = FALSE), , drop = FALSE]
                      .dat[, "features"] <- .f
                      .cell.highlight.use <- cells.highlight
                      if (isTRUE(.cell.highlight.use)) {
                        .cell.highlight.use <- rownames(.dat)[!is.na(.dat[["value"]])]
                      }
                      .lst.legend <- list()
                      if (isTRUE(show.stat)) {
                        .fea.in.cell <- sum(.dat[["value"]] > 0, na.rm = TRUE)
                        .fea.stat <- paste0(.s, " nPos:", .fea.in.cell, ", ", round(.fea.in.cell/nrow(.dat) * 100, 2), "%")
                        .subtitle.s <- .fea.stat
                      }
                      else {
                        .subtitle.s <- .comb.nm[.f]
                      }
                      if (all(is.na(.dat[["value"]]))) {
                        .color.v <- rep(0, 100)
                      } else {
                        
                        if (is.null(scale.by)) {
                          .feas.v <- .dat$value
                        } else if (scale.by == "feature") {
                          .feas.v <- .dat[[.f]]
                        } else if (scale.by == "all") {
                          .feas.v <- unlist(.dat[, .feas.plot, drop = FALSE], use.names = FALSE)
                        }
                        .feas.v <- .feas.v[is.finite(.feas.v)]
                        .color.v <- seq(value.cutoff[1] %||% quantile(.feas.v, quantile.cutoff[1], na.rm = TRUE), 
                                        value.cutoff[2] %||% quantile(.feas.v, quantile.cutoff[2], na.rm = TRUE) + 0.001, 
                                        length.out = 100)
                      }
                      .dat[which(.dat[, "value"] > max(.color.v, na.rm = TRUE)), "value"] <- max(.color.v, na.rm = TRUE)
                      .dat[which(.dat[, "value"] < min(.color.v, na.rm = TRUE)), "value"] <- min(.color.v, na.rm = TRUE)
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
                      if (isTRUE(global.split)){
                        .limits.x <- range(.df$x, na.rm = TRUE)
                        .limits.y <- range(.df$y, na.rm = TRUE)
                        .df.tmp <- .df
                        .df.tmp$features <- .f
                        .df.tmp$value <- .df.tmp[[.f]]
#                        p <- ggplot(.df.tmp) + geom_point(aes(x = x, y = y), color = bg.color, size = 0.1)
                      } else {
                        .limits.x <- extendrange(.dat[['x']])
                        .limits.y <- extendrange(.dat[['y']])
#                        p <- ggplot(.dat)
                      }
                      p <- ggplot(.dat) + net + density + 
                        labs(title = title, subtitle = .subtitle.s, x = xlab, y = ylab) + 
                        scale_x_continuous(limits = .limits.x) +
                        scale_y_continuous(limits = .limits.y) + 
                        do.call(theme.use, theme.args) + 
                        theme(aspect.ratio = aspect.ratio, 
                              legend.position = legend.position, 
                              legend.direction = legend.direction)
                      if (isTRUE(raster)) {
                        p <- p + scattermore::geom_scattermore(data = .dat[is.na(.dat[, "value"]), , drop = FALSE], 
                                                               mapping = aes(x = .data[["x"]], 
                                                                             y = .data[["y"]], 
                                                                             color = .data[["value"]]), 
                                                               pointsize = ceiling(pt.size), alpha = pt.alpha, 
                                                               pixels = raster.dpi) + 
                          ###here to see any different with and without !na
                          scattermore::geom_scattermore(data = .dat[!is.na(.dat[, "value"]), , drop = FALSE], 
                                                        mapping = aes(x = .data[["x"]], 
                                                                      y = .data[["y"]], 
                                                                      color = .data[["value"]]), 
                                                        pointsize = ceiling(pt.size), alpha = pt.alpha, 
                                                        pixels = raster.dpi)
                      } else if (isTRUE(hex)) {
                        ckPacsR("hexbin")
                        .na.idx <- is.na(.dat[["value"]])
                        .dat.na <- .dat[which(.na.idx), , drop = FALSE]
                        .dat.hex <- .dat[which(!.na.idx), , drop = FALSE]
                        if (nrow(.dat.na) > 0) {
                          p <- p + geom_hex(data = .dat.na, 
                                            mapping = aes(x = .data[["x"]], 
                                                          y = .data[["y"]]), 
                                            fill = bg.color, color = hex.color, 
                                            linewidth = hex.linewidth, bins = hex.bins, 
                                            binwidth = hex.binwidth)
                        }
                        if (nrow(.dat.hex) > 0) {
                          p <- p + stat_summary_hex(data = .dat.hex, 
                                                    mapping = aes(x = .data[["x"]], 
                                                                  y = .data[["y"]], 
                                                                  z = .data[["value"]]),
                                                    color = hex.color, 
                                                    linewidth = hex.linewidth, bins = hex.bins, 
                                                    binwidth = hex.binwidth)
                          if (sum(.na.idx) == nrow(.dat)) {
                            p <- p + scale_fill_gradient(name = "", na.value = bg.color)
                          } else {
                            p <- p + scale_fill_gradientn(name = "", colours = colors, 
                                                          values = rescale(.color.v), 
                                                          limits = range(.color.v), na.value = bg.color)
                          }
                          p <- p + new_scale_fill()
                        }
                      } else {
                        p <- p + geom_point(mapping = aes(x = .data[["x"]], 
                                                          y = .data[["y"]], 
                                                          color = .data[["value"]]), 
                                            size = pt.size, alpha = pt.alpha)
                      }
                      if (!is.null(.cell.highlight.use) && !isTRUE(hex)) {
                        .cell.df <- subset(p$data, rownames(p$data) %in% 
                                            .cell.highlight.use)
                        if (nrow(.cell.df) > 0) {
                          if (isTRUE(raster)) {
                            p <- p + 
                              scattermore::geom_scattermore(data = .cell.df, 
                                                            aes(x = .data[["x"]], 
                                                                y = .data[["y"]]),
                                                            color = highlight.col, 
                                                            pointsize = floor(highlight.size) + highlight.stroke, 
                                                            alpha = highlight.alpha, 
                                                            pixels = raster.dpi) + 
                              scattermore::geom_scattermore(data = .cell.df, 
                                                            aes(x = .data[["x"]], 
                                                                y = .data[["y"]], 
                                                                color = .data[["value"]]), 
                                                            pointsize = floor(highlight.size), 
                                                            alpha = highlight.alpha, pixels = raster.dpi)
                          } else {
                            p <- p + 
                              geom_point(data = .cell.df,
                                         aes(x = .data[["x"]],
                                             y = .data[["y"]]), 
                                         color = highlight.col, 
                                         size = highlight.size + highlight.stroke, 
                                         alpha = highlight.alpha) + 
                              geom_point(data = .cell.df, 
                                         aes(x = .data[["x"]], 
                                             y = .data[["y"]],  
                                             color = .data[["value"]]), 
                                         size = highlight.size, 
                                         alpha = highlight.alpha)
                          }
                        }
                      }
                      p <- .add_group_labels(p, .dat, group.by = group.by)
                      if (nrow(.dat) > 0) {
                        if (split.by == "All.groups") {
                          p <- p + facet_grid(. ~ features)
                        }
                        else {
                          p <- p + facet_grid(formula(paste0(split.by, "~features")))
                        }
                      }
                      if (all(is.na(.dat[["value"]]))) {
                        p <- p + scale_colour_gradient(name = "", na.value = bg.color, aesthetics = c("color"))
                      }
                      else {
                        p <- p + scale_color_gradientn(name = "", 
                                                       colours = colors, values = rescale(.color.v), 
                                                       limits = range(.color.v), na.value = bg.color, 
                                                       aesthetics = c("color"))
                      }
                      p <- p + guides(color = guide_colorbar(frame.colour = "black", 
                                                             ticks.colour = "black", 
                                                             title.hjust = 0, order = 1))
                      p_base <- p
                      if (!is.null(lineages)) {
                        lineages_layers <- c(list(new_scale_color()), 
                                             lineages_layers)
                        suppressMessages({
                          legend_list[["lineages"]] <- get_legend(ggplot() + 
                                                                    lineages_layers + theme_scp(legend.position = "bottom", 
                                                                                                legend.direction = legend.direction))
                        })
                        p <- suppressWarnings({
                          p + lineages_layers + theme(legend.position = "none")
                        })
                        if (is.null(legend_list[["lineages"]])) {
                          legend_list["lineages"] <- list(NULL)
                        }
                      }
                      if (isTRUE(label)) {
                        #p$data tried the .dat not work. here is the problem
                        .label.df <- p$data %>% 
                          filter(value >= quantile(value[is.finite(value)], 0.95, na.rm = TRUE) & 
                                   value <= quantile(value[is.finite(value)], 0.99, na.rm = TRUE)) %>% 
                          reframe(x = median(.data[["x"]]), y = median(.data[["y"]])) %>% as.data.frame()
                        .label.df[, "label"] <- .f
                        .label.df[, "rank"] <- seq_len(nrow(.label.df))
                        if (isTRUE(label.repel)) {
                          p <- p + annotate(geom = "point", 
                                            x = .label.df[["x"]], 
                                            y = .label.df[["y"]], 
                                            color = "black", 
                                            size = pt.size + 1) + 
                            annotate(geom = GeomTextRepel, 
                                     x = .label.df[["x"]], 
                                     y = .label.df[["y"]], 
                                     label = .label.df[["label"]], 
                                     fontface = "bold", size = legend.label.size,
                                     min.segment.length = 0, 
                                     segment.color = label.seg.color, 
                                     point.size = pt.size + 1, max.overlaps = 100, 
                                     force = label.repulsion, color = legend.label.fg, 
                                     bg.color = legend.label.bg, bg.r = legend.label.bg.r)
                        } else {
                          p <- p + annotate(geom = GeomTextRepel, 
                                            x = .label.df[["x"]], 
                                            y = .label.df[["y"]], 
                                            label = .label.df[["label"]], 
                                            fontface = "bold", point.size = NA,
                                            max.overlaps = 100, force = 0, 
                                            color = legend.label.fg, bg.color = legend.label.bg, 
                                            bg.r = legend.label.bg.r, size = legend.label.size)
                        }
                      }
                      if (length(.lst.legend) > 0) {
                        .lst.legend <- .lst.legend[!sapply(.lst.legend, is.null)]
                        .legend.base <- get_legend(p_base)
                        if (legend.direction == "vertical") {
                          legend <- do.call(cbind, c(list(base = .legend.base), .lst.legend))
                        } else {
                          legend <- do.call(rbind, c(list(base = .legend.base), .lst.legend))
                        }
                        gtable <- as_grob(p + theme(legend.position = "none"))
                        gtable <- add_grob.local(gtable, legend, legend.position)
                        p <- patchwork::wrap_plots(gtable)
                      }
                      return(p)
                    })
  }
  if (isTRUE(combine)) {
    if (length(plist) > 1) {
      plot <- patchwork::wrap_plots(plotlist = plist, nrow = nrow, ncol = ncol, byrow = byrow)
    }
    else {
      plot <- plist[[1]]
    }
    return(plot)
  }
  else {
    return(plist)
  }
}
