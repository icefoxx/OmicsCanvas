

lineagePlot <- function(seu, lineages, reduction = NULL, dims = c(1, 2), cells = NULL,
                        trim = c(0.01, 0.99), span = 0.75,
                        palette = "Dark2", palcolor = NULL, 
                        lineages_arrow = arrow(length = unit(0.1, "inches")),
                        linewidth = 1, line.bg = "white", line.bg.stroke = 0.5,
                        whiskers = FALSE, whiskers.linewidth = 0.5, whiskers.alpha = 0.5,
                        aspect.ratio = 1, title = NULL, subtitle = NULL, xlab = NULL, ylab = NULL,
                        legend.position = "right", legend.direction = "vertical",
                        theme.use = "themeDefault", theme.args = list(),
                        return.layer = FALSE, seed = 10086) {
  set.seed(seed)
  if (is.null(reduction)) {
    .reduction <- DefaultReduction(seu) 
  } else {
    if (reduction %in% names(seu@reductions)) {
      .reduction <- reduction
    } else {
      stop(paste0(reduction, " is not in the seu reduction."))
    }
  }
  .reduction.key <- seu@reductions[[.reduction]]@key
  .df.dim <- seu@reductions[[.reduction]]@cell.embeddings
  colnames(.df.dim) <- paste0(.reduction.key, 1:ncol(.df.dim))
  rownames(.df.dim) <- rownames(.df.dim) %||% colnames(seu@assays[[1]])
  .df.lineages <- seu@meta.data[, unique(lineages), drop = FALSE]
  .df <- cbind(.df.dim, .df.lineages[row.names(.df.dim), , drop = FALSE])
  .df[, "cell"] <- rownames(.df)
  
  if (!is.null(cells)) {
    .cell.ava <- intersect(rownames(.df), cells)
    if (length(.cell.ava) == 0) stop("Input cells are not in the Seurat object.")
    .df <- .df[intersect(rownames(.df), cells), , drop = FALSE]
  }
  .axes <- paste0(.reduction.key, dims)
  .xlab <- xlab %||% .axes[1]
  .ylab <- ylab %||% .axes[2]
  if (identical(theme.use, "theme_blank")) {
    theme.args[["xlab"]] <- .xlab
    theme.args[["ylab"]] <- .ylab
  }
  .colors <- paletteCustomize(lineages, palette = palette, palcolor = palcolor)
  fitted_list <- lapply(lineages, function(l) {
    trim_pass <- dat[[l]] > quantile(dat[[l]], trim[1], na.rm = TRUE) & dat[[l]] < quantile(dat[[l]], trim[2], na.rm = TRUE)
    na_pass <- !is.na(dat[[l]])
    index <- which(trim_pass & na_pass)
    index <- index[order(dat[index, l])]
    dat_sub <- dat[index, , drop = FALSE]
    weights_used <- rep(1, nrow(dat_sub))
    fitted <- lapply(axes, function(x) {
      loess(formula(paste(x, l, sep = "~")), weights = weights_used, data = dat_sub, span = span, degree = 2)$fitted
    })
    names(fitted) <- axes
    fitted[["index"]] <- index
    return(fitted)
  })
  names(fitted_list) <- lineages
  
  .curve.layer <- lapply(lineages, function(l) {
    .trim.qc <- .df[[l]] > quantile(.df[[l]], trim[1], na.rm = TRUE) & .df[[l]] < quantile(.df[[l]], trim[2], na.rm = TRUE)
    .na.qc <- !is.na(.df[[l]])
    .index <- which(.trim.qc & .na.qc)
    .index <- .index[order(.df[.index, l])]
    .df.ava <- .df[.index, , drop = FALSE]
    .weights <- rep(1, nrow(.df.ava))
    .fits <- lapply(.axes, function(x) {
      loess(formula(paste(x, l, sep = "~")), weights = .weights, data = .df.ava, span = span, degree = 2)$fitted
    })
    names(.fits) <- .axes
    .fits[["index"]] <- .index
    .fits <- as.data.frame(.fits)
    colnames(.fits) <- c(paste0("Axis_", 1:(ncol(.fits) - 1)), "index")
    .fits[, "Lineages"] <- factor(l, levels = lineages)
    .fits <- unique(na.omit(.fits))
    .curve <- list()
    if (isTRUE(whiskers)) {
      .df.ava[, "raw_Axis_1"] <- .df[.df.ava[, "index"], .axes[1]]
      .df.ava[, "raw_Axis_2"] <- .df[.df.ava[, "index"], .axes[2]]
      .curve <- c(.curve, geom_segment(
        data = .df.ava, mapping = aes(x = Axis_1, y = Axis_2, xend = raw_Axis_1, yend = raw_Axis_2, color = Lineages),
        linewidth = whiskers.linewidth, alpha = whiskers.alpha,
        show.legend = TRUE, inherit.aes = FALSE
      ))
    }
    .curve <- c(
      .curve,
      geom_path(
        data = .fits, mapping = aes(x = Axis_1, y = Axis_2), color = line.bg,
        linewidth = linewidth + line.bg.stroke, arrow = lineages_arrow,
        show.legend = TRUE, inherit.aes = FALSE
      ),
      geom_path(
        data = .fits, mapping = aes(x = Axis_1, y = Axis_2, color = Lineages),
        linewidth = linewidth, arrow = lineages_arrow,
        show.legend = TRUE, inherit.aes = FALSE
      )
    )
    return(.curve)
  })
  .curve.layer <- c(unlist(.curve.layer), list(scale_color_manual(values = .colors)))
  
  .lab.layer <- list(labs(title = title, subtitle = subtitle, x = xlab, y = ylab))
  .theme.layer <- list(do.call(theme.use, theme.args) +
                        theme(
                          aspect.ratio = aspect.ratio,
                          legend.position = legend.position,
                          legend.direction = legend.direction
                        ))
  if (isTRUE(return.layer)) {
    return(list(
      curve.layer = .curve.layer,
      lab.layer = .lab.layer,
      theme.layer = .theme.layer
    ))
  } else {
    return(ggplot() +
             .curve.layer +
             .lab.layer +
             .theme.layer)
  }
}