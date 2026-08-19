formatDF4statPlot <- function(df, stat.by = NULL, group.by = NULL, split.by = NULL, 
                              bg.by = NULL, stat.by.factorize = T, plot.type = plot.type, 
                              add.rownames = 'cells', return.all = F){
  .group.by <- group.by
  .split.by <- split.by
  .bg.by <- bg.by
  .df <- data.frame()
  if (nrow(df) == 0) cli::cli_abort("Input data is empty.")
  if (is.null(.group.by)) {
    .group.by <- "All.groups"
    df[[.group.by]] <- factor("")
  }
  if (is.null(.split.by)) {
    .split.by <- "All.groups"
    df[[.split.by]] <- factor("")
  }
  for (i in unique(c(.group.by, .split.by, .bg.by))) {
    if (!i %in% colnames(df)) cli::cli_abort("{i} is not in the Input data.")
    if (!is.factor(df[[i]])) df[[i]] <- factor(df[[i]], levels = unique(df[[i]]))
  }
  .bg.map <- NULL
  if (!is.null(.bg.by)) {
    for (g in .group.by) {
      .df.tb <- table(df[[g]], df[[.bg.by]])
      if (max(rowSums(.df.tb > 0), na.rm = TRUE) > 1) {
        stop("The values in the 'group.by' column must be a subset of the ones in 'bg.by' when 'bg.by' is provided.")
      } else {
        .bg.map[[g]] <- setNames(colnames(.df.tb)[apply(.df.tb, 1, function(x) which(x > 0))], rownames(.df.tb))
      }
    }
  } else {
    for (g in .group.by) {
      .bg.map[[g]] <- setNames(levels(df[[g]]), levels(df[[g]]))
    }
  }
  if (!is.null(stat.by)){
    for (i in unique(stat.by)) {
      if (!i %in% colnames(df)) cli::cli_abort("stat.by {i} is not in the Input data.")
      if (isTRUE(stat.by.factorize)){
        if (!is.factor(df[[i]])) {
          if (plot.type %in% c("venn", "upset") && is.logical(df[[i]])) next
          df[[i]] <- factor(df[[i]], levels = unique(df[[i]]))
        }
      }
    }
  }
  if (!is.null(add.rownames)) {
    if (add.rownames %in% colnames(df)) {
      cli::cli_inform("Cell name {add.rownames} is already in the Input data.")
      if ( ! identical(df[[add.rownames]], rownames(df))) {
        cli::cli_inform("The values in {add.rownames} are not equal to the rownames of the Input data,changing to rownames")
        df[[add.rownames]] <- as.character(rownames(df))
      }
    }
  }
  .output.var <- unique(c(stat.by, .group.by, .split.by, .bg.by))
  if (isFALSE(return.all)) df <- df[,.output.var]
  return(list(df = df, bg.map = .bg.map))
}


expStatPlot <- function (expM, meta.data, stat.by, group.by = 'orig.ident', split.by = NULL, 
                      cells = NULL, cells.h = NULL, bg.by = NULL, 
                      fill.by = c("group", "feature", "expression"),  keep.na = FALSE, 
                      seperate.group = FALSE, palette = "Paired", palcolor = NULL, 
                      plot.type = c("violin", "box", "bar", "dot", "col"), 
                      violin.scale = "width", violin.trim = TRUE, violin.color = NA, violin.linewidth = 0.5,
                      boxplot.color = "black", boxplot.fill = NA, boxplot.width = 0.8,
                      boxplot.linewidth = 0.5, boxplot.outlier.shape = NA,
                      median.point.color = "black", median.point.fill = "white",
                      median.point.size = 1.5, median.point.shape = 21,
                      bar.width = 0.8, bar.color = "black", bar.linewidth = 0.5,
                      errorbar.width = 0.2, errorbar.color = "black", errorbar.linewidth = 0.5,
                      zero.line.show = TRUE, zero.line.color = "black", zero.line.type = 2, zero.line.size = 0.5,
                      dot.count.shape = 21, dot.count.max.size = 6, dot.count.nbreaks = 4,
                      dot.count.legend.title = "Count",
                      col.color = NA, col.linewidth = 0.3, col.width = NULL,
                      col.group.border.show = TRUE, col.group.border.color = "black",
                      col.group.border.type = 2, col.group.border.alpha = 0.5,
                      alpha = 1, bg.palette = "Paired", bg.palcolor = NULL, bg.alpha = 0.2, 
                      add.box = FALSE, box.color = "black", box.width = 0.1, box.ptsize = 2, 
                      add.dot = FALSE, dot.color = "grey30", dot.size = NULL, dot.alpha = 1,
                      dot.shape = 19, highlight.shape = 19,
                      jitter.width = 0.4, jitter.height = 0.1, 
                      add.trend = FALSE,  trend.color = "black", trend.linewidth = 1, trend.ptsize = 2, 
                      add.stat = c("mean"), add.stat.para = list(), 
                      stat.color = "black", stat.size = 1, stat.stroke = 1, stat.shape = 25,
                      add.line.x = NULL, line.color.x = "red", line.size.x = 1, line.type.x = 1,
                      add.line.y = NULL, line.color.y = "red", line.size.y = 1, line.type.y = 1,
                      cols.highlight = "red", sizes.highlight = 1, alpha.highlight = 1, 
                      coexp = NULL, coexp.para = list(), same.y.lims = FALSE, y.min = NULL, 
                      y.max = NULL, y.trans = "identity", y.nbreaks = 5, 
                      sort = 'increasing', sort.by = 'median', 
                      stack = FALSE, flip = FALSE, comparisons = NULL, ref.group = NULL, 
                      pairwise.method = "wilcox.test", multiple.method = "kruskal.test", 
                      sig.label = c("p.signif", "p.format"), multiplegroup.comparisons = FALSE,
                      sig.labelsize = 3.5, aspect.ratio = NULL, 
                      title = NULL, subtitle = NULL, xlab = NULL, ylab = "Expression level", 
                      legend.position = "right", legend.direction = "vertical", 
                      theme.use = "themeDefault", theme.args = list(), force = FALSE, 
                      seed = 10086, ...) 
{
  suppressPackageStartupMessages({
    library(tidyverse)
    library(rlang)
    library(gtable)
    library(patchwork)
  })
  set.seed(seed)
  plot.type <- match.arg(plot.type)
  fill.by <- match.arg(fill.by)
  sig.label <- match.arg(sig.label)
  .xlab <- xlab
  if (is.null(group.by)) cli::cli_abort("Unavailable group.by")
  if (missing(meta.data) || nrow(meta.data) == 0) cli::cli_abort("Unavailable meta.data ")
  if (missing(expM) || nrow(expM) == 0)  {
    .exp.data <- matrix(0, nrow = 1, ncol = nrow(meta.data), dimnames = list("", rownames(meta.data)))
  } else {
    .exp.data <- expM
  }
  .features.exp <- rownames(.exp.data)
  .feature.meta <- colnames(meta.data)
  .cell.all <- rownames(meta.data)
  .stat.by <- unique(stat.by)
  .stat.by.exp <- intersect(.stat.by, .features.exp)
  .stat.by.meta <- intersect(.stat.by, .feature.meta)
  .allfeatures <- unique(c(.stat.by.exp, .stat.by.meta))
  .stat.by.ava <- .stat.by %in% .allfeatures
  if (sum(.stat.by.ava) == 0) {
    cli::cli_abort("features in 'stat.by' are NOT found in meta.data and expM.")
  } else{
    .features.miss <- .stat.by[!.stat.by.ava]
    if (length(.features.miss) > 0) cli::cli_alert("{paste0(.features.miss, collapse= ',') } in 'stat.by' are found in meta.data and expM.")
    .stat.by <- .stat.by[.stat.by.ava]
  }
  if (length(.stat.by) == 0) cli::cli_abort("No features found in expM and meta.data.")
  if (length(.stat.by.exp) == 0) cli::cli_inform("No features found in expM.")
  if (length(.stat.by.meta) == 0) cli::cli_inform("No features found in meta.data.")
  .feature.2 <- intersect(.stat.by.exp, .stat.by.meta)
  if (length(.feature.2) > 0) {
    cli::cli_alert('Both exp matrix and metadata have the same feature: {paste0((.feature.2), collapse = ",")}. ')
  }
  multiplegroup.comparisons <- FALSE
  if (plot.type == "col") {
    add.box <- add.dot <- add.trend <- FALSE
    cli::cli_inform("Setting add.box, add.dot, add.trend to FALSE for plot.type 'col'")
    comparisons <- NULL
    cli::cli_inform("Setting multiplegroup.comparisons, comparisons to FALSE for plot.type 'col'")
  }
  if (length(comparisons) > 0) {
    ckPacsR("ggpubr")
    if (isTRUE(comparisons)){
      if (is.null(split.by)) cli::cli_abort("'split.by' is needed when comparisons=TRUE")
    } else {
      if (!is.list(comparisons)) stop("'comparisons' must be a list")
      invisible(sapply(seq_along(comparisons), function(x){
        .comparison <- comparisons[[x]]
        .comparison.n <- length(.comparison)
        if (.comparison.n == 0 || .comparison.n > 2) {
          cli::cli_abort("Each element in comparisons should be a 2-words vector: treat at 1st, control 2nd")
        }
      }))
    }
  }
  .df.fmt <- formatDF4statPlot(df = meta.data, stat.by = .stat.by.meta, 
                                group.by = group.by, split.by = split.by, 
                                bg.by = bg.by, plot.type = plot.type, 
                               stat.by.factorize = F)
  .df <- .df.fmt$df
  bg.map <- .df.fmt$bg.map
  .cells.h <- cells.h
  if (!is.null(cells.h)){
    add.dot <- TRUE
    if (isTRUE(cells.h)){
      .cells.h <- .cell.all
    } else {
      .cell.h.ava <- cells.h %in% .cell.all
      if (any(!.cell.h.ava)) cli::cli_abort("Some cells in 'cells.h' not found.")
      .cells.h <- cells.h[.cell.h.ava]
    }
  }
  if (isTRUE(stack)) sort <- FALSE
  .feature.exp.data <- NULL
  if (length(.stat.by.exp) > 0) {
    .feature.exp.data <- t(expM[.stat.by.exp, , drop = FALSE])
  } else {
    .feature.exp.data <- matrix(nrow = nrow(.df), ncol = 0)
  }
  if (!is.null(coexp)) {
    if (length(.stat.by.exp) > 1) {
      .dt <- ckDataType(expM)
      cli::cli_info("Input data type of expression matrix: ", .dt)
      .exp.m <- expM[.stat.by.exp, , drop = FALSE]
      if (.dt %in% c("rawCounts", "rawCountsNormalized")) {
        .df[["CoExp"]] <- apply(.exp.m, 2, function(x) mmdata(x, m = coexp, model = 1))
      } else if (.dt == "countsLogNormal") {
        .df[["CoExp"]] <- apply(.exp.m, 2, function(x) mmdata(x, m = coexp, model = 2))
      } else {
        stop("Unknown data type.")
      }
    } else {
      .df[["CoExp"]]  <- expM[.stat.by.exp, , drop = TRUE]
    }
    .stat.by <- .stat.by.exp <- unique(c(.stat.by, "CoExp"))
    .stat.by.meta <- c(.stat.by.meta, "CoExp")
  }
  .df.data <- .df
#  if (length(.stat.by.meta) == 0) {
#    .df.data <- matrix(nrow = length(.cell.all), ncol = 0)
#  }
  ###here
  .data.merge <- cbind(.feature.exp.data, .df.data)
  .data.merge.c <- sapply(c('matrix', 'Matrix'), function(z) inherits(.data.merge, what = z))
#  if (!is.numeric(.data.merge) && !any(.data.merge.c)) stop("Some of the variables are not numeric.")
  .data.merge <- as.data.frame(.data.merge)
  if (is.null(split.by)) split.by <- "All.groups"
  if (!is.null(cells)) {
    .cell.idx <- which(cells %in% .cell.all)
    if (length(.cell.idx) == 0) stop("No specified cells found.")
    if (length(.cell.idx) < length(cells)) cli::cli_alert("Some cells not found.")
    .data.merge <- .data.merge[.cell.idx, , drop = FALSE]
    .df.data <- .df.data[.cell.idx, , drop = FALSE]
  }
  if (is.null(dot.size)) dot.size <- min(3000/nrow(.data.merge), 0.5)
  .levels.n <- sapply(.df.data, nlevels)
  .levels.n <- .levels.n[.levels.n > 100]
  if (length(.levels.n) > 0 && !isTRUE(force)) {
    warning(paste(names(.levels.n), sep = ", "), " have more than 100 levels.", immediate. = TRUE)
    if (!isTRUE(askYesNo("Continue?", default = FALSE))) return(invisible(NULL))
  }
  if (isTRUE(same.y.lims)) {
    .tmp.matrix <- toDenseMatrix(.data.merge[, .stat.by, drop = FALSE])
    .tmp.matrix.na <- .tmp.matrix[is.finite(.tmp.matrix)]
    if (is.null(y.max)) {
      y.max <- max(.tmp.matrix.na, na.rm = TRUE)
    } else if (is.character(y.max)) {
      q.max <- as.numeric(sub("(^q)(\\d+)", "\\2", y.max))/100
      y.max <- quantile(.tmp.matrix.na, q.max, na.rm = TRUE)
    }
    if (is.null(y.min)) {
      y.min <- min(.tmp.matrix.na, na.rm = TRUE)
    }else if (is.character(y.min)) {
      q.min <- as.numeric(sub("(^q)(\\d+)", "\\2", y.min))/100
      y.min <- quantile(.tmp.matrix.na, q.min, na.rm = TRUE)
    }
  }
  .comb <- expand.grid(group_name = group.by, stat_name = .stat.by, stringsAsFactors = FALSE)
  .comb <- do.call(rbind, lapply(group.by, function(g){
    .group.element <- levels(.data.merge[[g]])
    .split.name <- levels(.data.merge[[split.by]])
    if (isFALSE(seperate.group)){
      .group.element <- list(.group.element)
      .split.name <- list(.split.name)
    }
    .o <- merge(.comb, 
          expand.grid(group_name = g, 
                      group_element = .group.element, 
                      split_name = .split.name, 
                      stringsAsFactors = FALSE), by = "group_name", 
          all = FALSE)
    return(.o)
  }))
  .comb.nm <- paste0(.comb[["stat_name"]], 
                     ":", 
                     .comb[["group_name"]], 
                     ":", 
                     sapply(.comb[["group_element"]], function(x) paste0(x,collapse = ",")), 
                     ":", 
                     sapply(.comb[["split_name"]], function(x) paste0(x, collapse = ","))
  )
  rownames(.comb) <- .comb.nm
  .plist <- lapply(.comb.nm, 
                  function(r) {
                    .g <- .comb[r, "group_name"]
                    .f <- .comb[r, "stat_name"]
                    .sg <- .comb[[r, "group_element"]]
                    .sp <- .comb[[r, "split_name"]]
                    xlab <- xlab %||% .g
                    ylab <- ylab %||% "Expression level"
                    if (identical(theme.use, "theme_blank")) {
                      theme.args[["xlab"]] <- xlab
                      theme.args[["ylab"]] <- ylab
                    }
                    if (fill.by == "feature") {
                      colors <- paletteCustomize(.stat.by, palette = palette, 
                                            palcolor = palcolor)
                    }
                    if (fill.by == "group") {
                      colors <- paletteCustomize(levels(.data.merge[[.g]]), 
                                                 palette = palette, palcolor = palcolor)
                      if (split.by != "All.groups") {
                        colors <- paletteCustomize(levels(.data.merge[[split.by]]), 
                                                   palette = palette, palcolor = palcolor)
                      }
                    }
                    if (fill.by == "expression") {
                      .medians <- aggregate(.data.merge[, .stat.by, drop = FALSE], 
                                                 by = list(.data.merge[[.g]], .data.merge[[split.by]]), 
                                                 FUN = median)
                      rownames(.medians) <- paste0(.medians[, 1], "-", .medians[, 2])
                      colors <- paletteCustomize(unlist(.medians[, stat.by]), type = "continuous", 
                                                 palette = palette, palcolor = palcolor)
                      colors.limits <- range(.medians[, stat.by])
                    }
                    .data.plot <- .data.merge[.data.merge[[.g]] %in% .sg & .data.merge[[split.by]] %in% .sp, c(colnames(.df.data), .f)]
                    if (is.factor(.data.plot[[.g]])) {
                      .data.plot[[.g]] <- droplevels(.data.plot[[.g]])
                    }else {
                      .data.plot[[.g]] <- factor(.data.plot[[.g]], levels = unique(.data.plot[[.g]]))
                    }
                    if (!is.null(bg.by)) {
                      .bg <- bg.by
                      .bg.color <- paletteCustomize(levels(.data.plot[[.bg]]), palette = bg.palette, palcolor = bg.palcolor)
                    }else {
                      .bg <- .g
                      .bg.color <- paletteCustomize(levels(.data.plot[[.bg]]), palcolor = bg.palcolor %||% 
                                                rep(c("transparent", "grey85"), nlevels(.data.plot[[.bg]])))
                    }
                    .data.plot[["bg.by"]] <- .data.plot[[.bg]]
                    .data.plot[["value"]] <- .data.plot[[.f]]
                    .data.plot[["group.by"]] <- .data.plot[[.g]]
                    .data.plot[["split.by"]] <- .data.plot[[split.by]]
                    if (split.by == .g) .data.plot[["split.by"]] <- .data.plot[["group.by"]]
                    .data.plot[, "features"] <- rep(.f, nrow(.data.plot))
                    if (nrow(.data.plot) > 0 && ((is.character(x = sort) && nchar(x = sort) > 0) || isTRUE(sort))) {
                      .df.sort <- aggregate(.data.plot[, "value", drop = FALSE], 
                                           by = list(.data.plot[["group.by"]]), 
                                           FUN = get(sort.by))
                      decreasing <- if (is.character(sort) && sort == "increasing") FALSE else TRUE
                      .sortlevel <- as.character(.df.sort[order(.df.sort[["value"]], decreasing = decreasing), 1])
                      .data.plot[, "group.by"] <- factor(.data.plot[, "group.by"], 
                                                  levels = .sortlevel)
                    }
                    if (fill.by == "feature") {
                      .data.plot[, "fill.by"] <- rep(.f, nrow(.data.plot))
                      .key.nm <- "Features"
                    }
                    if (fill.by == "group") {
                      .data.plot[, "fill.by"] <- if (split.by == "All.groups") .data.plot[, "group.by"] else .data.plot[, "split.by"]
                      .key.nm <- ifelse(split.by == "All.groups", .g, split.by)
                    }
                    if (fill.by == "expression") {
                      .data.plot[, "fill.by"] <- .medians[paste0(.data.plot[["group.by"]], "-", .data.plot[["split.by"]]), .f]
                      .key.nm <- "Median expression"
                    }
                    if (split.by != "All.groups") {
                      levels_order <- levels(.data.plot[["split.by"]])
                    } else {
                      levels_order <- levels(.data.plot[["group.by"]])
                    }
                    if (fill.by == "feature") levels_order <- unique(.stat.by)
                    .group.comb <- expand.grid(x = levels(.data.plot[["split.by"]]), 
                                              y = levels(.data.plot[["group.by"]]))
                    .data.plot[["group.unique"]] <- head(factor(paste("sp", .data.plot[["split.by"]], "gp", .data.plot[["group.by"]], sep = "-"), 
                                                               levels = paste("sp", .group.comb[[1]], "gp", .group.comb[[2]], sep = "-")), 
                                                         nrow(.data.plot))
                    .data.plot <- .data.plot[order(.data.plot[["group.unique"]]), , drop = FALSE]
                    values <- .data.plot[, "value"][is.finite(x = .data.plot[, "value"])]
                    .plot.y.max <- y.max
                    if (is.null(.plot.y.max)) {
                      .plot.y.max <- max(values, na.rm = TRUE)
                    } else if (is.character(.plot.y.max)) {
                      .q.max <- as.numeric(sub("(^q)(\\d+)", "\\2", .plot.y.min))/100
                      .plot.y.max <- quantile(values, .q.max, na.rm = TRUE)
                    }
                    .plot.y.min <- y.min
                    if (is.null(.plot.y.min)) {
                      .plot.y.min <- min(values, na.rm = TRUE)
                    } else if (is.character(.plot.y.min)) {
                      .q.min <- as.numeric(sub("(^q)(\\d+)", "\\2", .plot.y.min))/100
                      .plot.y.min <- quantile(values, .q.min, na.rm = TRUE)
                    }
                    if (isTRUE(flip)) {
                      .data.plot[["group.by"]] <- factor(.data.plot[["group.by"]], levels = rev(levels(.data.plot[["group.by"]])))
                      if (length(aspect.ratio) == 0 || is.na(aspect.ratio)) {
                        aspect.ratio <- NULL
                      } else {
                        aspect.ratio <- 1 / aspect.ratio
                      }
                    }
                    if (plot.type == "col") {
                      if (isTRUE(flip)) {
                        .data.plot[["cell"]] <- rev(seq_len(nrow(.data.plot)))
                      } else {
                        .data.plot[["cell"]] <- seq_len(nrow(.data.plot))
                      }
                      .p <- ggplot(.data.plot, aes(x = .data[["cell"]], y = .data[["value"]], 
                                           fill = .data[["fill.by"]]))
                    } else {
                      .p <- ggplot(.data.plot, aes(x = .data[["group.by"]], 
                                           y = .data[["value"]], fill = .data[["fill.by"]]))
                    }
                    if (isFALSE(seperate.group)) {
                      .xrange.key <- c('x', 'x')
                      if (plot.type == "col") {
                        .idx.x <- split(.data.plot[["cell"]], .data.plot[["group.by"]])
                        .data.bg <- as.data.frame(t(sapply(.idx.x, 
                                                          range)))
                        colnames(.data.bg) <- c("xmin", "xmax")
                        .data.bg[["group.by"]] <- names(.idx.x)
                        .xrange.key <- c('xmin', 'xmax')
                      } else {
                        .data.bg <- unique(.data.plot[, "group.by", drop = FALSE])
                        .data.bg[["x"]] <- as.numeric(.data.bg[["group.by"]])
                      }
                      .data.bg[["xmin"]] <- ifelse(.data.bg[[.xrange.key[1]]] == 
                                                     min(.data.bg[[.xrange.key[2]]]), -Inf, .data.bg[[.xrange.key[1]]] - 
                                                     0.5)
                      .data.bg[["xmax"]] <- ifelse(.data.bg[[.xrange.key[2]]] == 
                                                     max(.data.bg[[.xrange.key[2]]]), Inf, .data.bg[[.xrange.key[2]]] + 
                                                     0.5)
                      .data.bg[["ymin"]] <- -Inf
                      .data.bg[["ymax"]] <- Inf
                      .data.bg[["fill"]] <- .bg.color[bg.map[[.g]][as.character(.data.bg[["group.by"]])]]
                      .bg.layer <- geom_rect(data = .data.bg, xmin = .data.bg[["xmin"]], 
                                            xmax = .data.bg[["xmax"]], ymin = .data.bg[["ymin"]], 
                                            ymax = .data.bg[["ymax"]], fill = .data.bg[["fill"]], 
                                            alpha = bg.alpha, inherit.aes = FALSE)
                      .p <- .p + .bg.layer
                    }
                    if (plot.type %in% c("bar", "col") && isTRUE(zero.line.show)) {
                      .p <- .p + geom_hline(yintercept = 0, linetype = zero.line.type,
                                            color = zero.line.color, linewidth = zero.line.size)
                    }
                    if (plot.type == "violin") {
                      .p <- .p + geom_violin(scale = violin.scale, trim = violin.trim, alpha = alpha,
                                             color = violin.color, linewidth = violin.linewidth,
                                             position = position_dodge())
                    }
                    if (plot.type == "box") {
                      add.box <- FALSE
                      .boxplot.args <- list(mapping = aes(group = .data[["group.unique"]]),
                                            position = position_dodge(width = 0.9),
                                            color = boxplot.color,
                                            width = boxplot.width,
                                            linewidth = boxplot.linewidth,
                                            outlier.shape = boxplot.outlier.shape)
                      if (!is.null(boxplot.fill)) .boxplot.args[["fill"]] <- boxplot.fill
                      .p <- .p +
                        do.call(geom_boxplot, .boxplot.args) +
                        stat_summary(fun = median, geom = "point", mapping = aes(group = .data[["split.by"]]), 
                                     position = position_dodge(width = 0.9), color = median.point.color,
                                     fill = median.point.fill, size = median.point.size,
                                     shape = median.point.shape, )
                    }
                    if (plot.type == "bar") {
                      .p <- .p + 
                        stat_summary(fun = mean, geom = "col", 
                                     mapping = aes(group = .data[["split.by"]]),
                                     position = position_dodge(width = 0.9), width = bar.width,
                                     color = bar.color, linewidth = bar.linewidth) + 
                        stat_summary(fun.data = mean_sdl, fun.args = list(mult = 1), geom = "errorbar", 
                                     mapping = aes(group = .data[["split.by"]]), 
                                     position = position_dodge(width = 0.9), width = errorbar.width,
                                     color = errorbar.color, linewidth = errorbar.linewidth)
                      .plot.y.min <- layer_scales(.p)$y$range$range[1]
                    }
                    if (plot.type == "dot") {
                      .bins <- cut(.data.plot$value, 
                                  breaks = seq(min(.data.plot$value), max(.data.plot$value), length.out = 15), 
                                  include.lowest = TRUE)
                      .bins.median <- sapply(strsplit(levels(.bins), ","), 
                                             function(x) {
                                               median(as.numeric(gsub("\\(|\\)|\\[|\\]", "", x)), na.rm = TRUE)
                                              })
                      names(.bins.median) <- levels(.bins)
                      .data.plot[["bins"]] <- .bins.median[.bins]
                      .p <- .p + 
                        geom_count(data = .data.plot, aes(y = bins), 
                                          shape = dot.count.shape, alpha = alpha, position = position_dodge(width = 0.9)) + 
                        scale_size_area(name = dot.count.legend.title, max_size = dot.count.max.size, n.breaks = dot.count.nbreaks) + 
                        guides(size = guide_legend(override.aes = list(fill = "grey30", shape = dot.count.shape), order = 2))
                    }
                    if (plot.type == "col") {
                      .p <- .p + geom_col(color = col.color, linewidth = col.linewidth, width = col.width)
                      if (isTRUE(flip)) {
                        .p <- .p + theme(axis.text.y = element_blank(), 
                                        axis.ticks.y = element_blank())
                      }else {
                        .p <- .p + theme(axis.text.x = element_blank(), 
                                       axis.ticks.x = element_blank())
                      }
                      if (isTRUE(col.group.border.show) && isFALSE(seperate.group) && nlevels(.data.plot[["group.by"]]) > 1) {
                        .idx.x <- split(.data.plot[["cell"]], .data.plot[["group.by"]])
                        .border.data <- as.data.frame(sapply(.idx.x, min) - 0.5)
                        colnames(.border.data) <- "xintercept"
                        .border.data <- .border.data[2:nrow(.border.data), , drop = FALSE]
                        .layer.border <- geom_vline(xintercept = .border.data[["xintercept"]], 
                                                   linetype = col.group.border.type,
                                                   color = col.group.border.color,
                                                   alpha = col.group.border.alpha)
                        .p <- .p + .layer.border
                      }
                    }
                    if (!is.null(comparisons)) {
                        .group.tab <- table(.data.plot[["group.by"]], .data.plot[["split.by"]])
                        .group.cand <- rowSums( .group.tab >= 2)
                        .group.com <- names(which(.group.cand >= 2))
                        if (any(.group.cand >= 3)) {
                          cli::cli_inform("Using {multiple.method} for comparison when there are more than 2 groups.")
                          .test.method <- multiple.method
                        }else {
                          .test.method <- pairwise.method
                        }
                        if (isTRUE(comparisons)){
                          .data.comp <- .data.plot[.data.plot[["group.by"]] %in% .group.com, , drop = FALSE]
                          .p <- .p + 
                            ggpubr::stat_compare_means(data = .data.comp,
                                                       mapping = aes(x = .data[["group.by"]], 
                                                                     y = .data[["value"]], 
                                                                     group = .data[["group.unique"]]), 
                                                       label = sig.label, label.y = .plot.y.max, 
                                                       size = sig.labelsize, step.increase = 0.1, 
                                                       tip.length = 0.03, vjust = 1,  
                                                       ref.group = ref.group, method = pairwise.method)
                          .plot.y.max <- mmY(.p, 1)
                        } else {
                          if ( split.by != "All.groups") {
                            .target.grp <- names(comparisons) 
                            .grp.nom <- setdiff(.target.grp, .data.plot[["group.by"]])
                             if (length(.grp.nom) > 0) cli::cli_abort("{.grp.nom} in comparisons not found.")
                            .data.comp <- .data.plot[.data.plot[["group.by"]] %in% .target.grp, , drop = FALSE]
                            .comparisons <- NULL
                          } else {
                            .data.comp <- .data.plot
                            .comparisons <- comparisons
                          }
                          .p <- .p + 
                            ggpubr::stat_compare_means(data = .data.comp,
                                                       mapping = aes(x = .data[["group.by"]], 
                                                                     y = .data[["value"]], 
                                                                     group = .data[["group.unique"]]), 
                                                       label = sig.label, label.y = .plot.y.max, 
                                                       size = sig.labelsize, step.increase = 0.1, 
                                                       comparisons = .comparisons, 
                                                       ref.group = ref.group, method = .test.method,
                                                       tip.length = 0.03, vjust = 0)
                          .plot.y.max <- mmY(.p, 2)
                        }
                    }
                    if (isTRUE(multiplegroup.comparisons)) {
                      .p <- .p + 
                        ggpubr::stat_compare_means(aes(x = .data[["group.by"]], 
                                                       y = .data[["value"]], 
                                                       group = .data[["group.unique"]]),
                                                   method = multiple.method, 
                                                   label = sig.label, label.y = .plot.y.max, 
                                                   size = sig.labelsize, vjust = 1.2, hjust = 0)
                      .plot.y.max <- mmY(.p, 2)
                    }
                    if (isTRUE(add.dot)) {
                      suppressWarnings(.p <- .p + geom_point(aes(x = .data[["group.by"]], 
                                                                 y = .data[["value"]], 
                                                                 linetype = rep(.f, nrow(.data.plot)), 
                                                                 group = .data[["group.unique"]]), 
                                                             inherit.aes = FALSE, color = dot.color, 
                                                             size = dot.size, alpha = dot.alpha,
                                                             shape = dot.shape,
                                                             position = position_jitterdodge(jitter.width = jitter.width, 
                                                                                           jitter.height = jitter.height, dodge.width = 0.9, 
                                                                                           seed = 11), 
                                                             show.legend = FALSE))
                      if (!is.null(.cells.h)) {
                        .df.cells <- subset(.p$data, rownames(.p$data) %in% .cells.h)
                        if (nrow(.df.cells) > 0) {
                          .p <- .p + geom_point(data = .df.cells, 
                                                aes(x = .data[["group.by"]], 
                                                    y = .data[["value"]], 
                                                    linetype = rep(.f, nrow(.df.cells)), 
                                                    group = .data[["group.unique"]]), 
                                                inherit.aes = FALSE, color = cols.highlight, 
                                                size = sizes.highlight, alpha = alpha.highlight,
                                                shape = highlight.shape,
                                                position = position_jitterdodge(jitter.width = jitter.width, 
                                                                              jitter.height = jitter.height, dodge.width = 0.9, 
                                                                              seed = 11), show.legend = FALSE)
                        }
                      }
                    }
                    if (isTRUE(add.box)) {
                      .p <- .p + geom_boxplot(aes(group = .data[["group.unique"]]), 
                                              position = position_dodge(width = 0.9), color = box.color, 
                                              fill = box.color, width = box.width, show.legend = FALSE, 
                                              outlier.shape = NA) + stat_summary(fun = median, 
                                                                               geom = "point", mapping = aes(group = .data[["split.by"]]), 
                                                                               position = position_dodge(width = 0.9), color = "black", 
                                                                               fill = "white", size = box.ptsize, shape = 21, 
                                            )
                    }
                    if (isTRUE(add.trend)) {
                      if (plot.type %in% c("violin", "box")) {
                        if (nlevels(.data.plot[["split.by"]]) > 1) {
                          layer.point <- stat_summary(fun = median, 
                                                      geom = "point", 
                                                      mapping = aes(group = .data[["split.by"]],
                                                                    color = .data[["group.by"]]), 
                                                      position = position_dodge(width = 0.9), 
                                                      fill = "white", size = trend.ptsize, shape = 21)
                          .p.data <- .p + layer.point
                          .p <- .p +
                            geom_line(data = layer_data(.p.data, length(.p.data$layers)), 
                                      aes(x = x, y = y, group = colour), 
                                      color = trend.color, 
                                      linewidth = trend.linewidth, inherit.aes = FALSE) + 
                            stat_summary(fun = median, geom = "point", 
                                         mapping = aes(group = .data[["split.by"]]), 
                                         position = position_dodge(width = 0.9), 
                                         color = "black", fill = "white", size = trend.ptsize, 
                                         shape = 21)
                        } else {
                          .p <- .p + 
                            stat_summary(fun = median, geom = "line", 
                                                mapping = aes(group = .data[["split.by"]]), 
                                                position = position_dodge(width = 0.9), 
                                                color = trend.color, linewidth = trend.linewidth) + 
                            stat_summary(fun = median, geom = "point", 
                                         mapping = aes(group = .data[["split.by"]]), 
                                         position = position_dodge(width = 0.9), 
                                         color = "black", fill = "white", size = trend.ptsize, 
                                         shape = 21)
                        }
                      }
                      if (plot.type %in% c("bar")) {
                        if (nlevels(.data.plot[["split.by"]]) > 1) {
                          layer.point <- stat_summary(fun = mean, 
                                                      geom = "point", 
                                                      mapping = aes(group = .data[["split.by"]], 
                                                                    color = .data[["group.by"]]), 
                                                      position = position_dodge(width = 0.9), 
                                                      fill = "white", size = trend.ptsize, shape = 21)
                          .p.data <- .p + layer.point
                          .p <- .p + 
                            geom_line(data = layer_data(.p.data, length(.p.data$layers)), 
                                               aes(x = x, y = y,  group = colour), 
                                               color = trend.color, 
                                               linewidth = trend.linewidth, inherit.aes = FALSE) + 
                            stat_summary(fun = mean, geom = "point", 
                                         mapping = aes(group = .data[["split.by"]]), 
                                         position = position_dodge(width = 0.9), 
                                         color = "black", fill = "white", size = trend.ptsize, 
                                         shape = 21)
                        } else {
                          .p <- .p + 
                            stat_summary(fun = mean, geom = "line", 
                                         mapping = aes(group = .data[["split.by"]]), 
                                         position = position_dodge(width = 0.9), 
                                         color = trend.color, linewidth = trend.linewidth) +
                            stat_summary(fun = mean, geom = "point", 
                                           mapping = aes(group = .data[["split.by"]]), 
                                           position = position_dodge(width = 0.9), 
                                           color = "black", fill = "white", size = trend.ptsize, 
                                           shape = 21)
                        }
                      }
                    }
                    if (add.stat != "none") {
                      .p <- .p + stat_summary(fun = get(add.stat), fun.args = add.stat.para, 
                                              geom = "point", 
                                              mapping = aes(group = .data[["split.by"]], 
                                                            shape = stat.shape), 
                                              position = position_dodge(width = 0.9), 
                                              color = stat.color, fill = stat.color, size = stat.size, 
                                              stroke = stat.stroke, ) + scale_shape_identity()
                    }
                    if (!is.null(add.line.x)) {
                      .p <- .p + geom_hline(yintercept = add.line.x, color = line.color.x, 
                                          linetype = line.type.x, linewidth = line.size.x)
                    }
                    if (!is.null(add.line.y)) {
                      .p <- .p + geom_vline(xintercept = add.line.y, color = line.color.y, 
                                          linetype = line.type.y, linewidth = line.size.y)
                    }
                    if (nrow(.data.plot) == 0) {
                      .p <- .p + facet_null()
                    } else {
                      if (isTRUE(stack) && !isTRUE(flip)) {
                        .p <- .p + 
                          facet_grid(features ~ .) + 
                          theme(strip.text.y = element_text(angle = 0))
                      } else {
                        .p <- .p + facet_grid(. ~ features)
                      }
                    }
                    .p <- .p + labs(title = title, subtitle = subtitle, x = xlab, y = ylab)
                    if (nrow(.data.plot) != 0) .p <- .p + scale_x_discrete(drop = !keep.na)
                    if (isTRUE(flip)) {
                      if (isTRUE(stack)) {
                        .p <- .p + 
                          do.call(theme.use, theme.args) + 
                          theme(aspect.ratio = aspect.ratio, 
                                axis.text.x = element_text(angle = 90, hjust = 1), 
                                strip.text.x = element_text(angle = 90), 
                                panel.grid.major.x = element_line(color = "grey", linetype = 2), 
                                legend.position = legend.position, 
                                legend.direction = legend.direction) + 
                          coord_flip(ylim = c(.plot.y.min, .plot.y.max))
                      } else {
                        .p <- .p + 
                          do.call(theme.use, theme.args) + 
                          theme(aspect.ratio = aspect.ratio, 
                                axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1), 
                                strip.text.y = element_text(angle = 0), 
                                panel.grid.major.x = element_line(color = "grey", linetype = 2), 
                                legend.position = legend.position, 
                                legend.direction = legend.direction) + 
                          coord_flip(ylim = c(.plot.y.min, .plot.y.max))
                      }
                    } else {
                      .p <- .p + 
                        do.call(theme.use, theme.args) + 
                        theme(aspect.ratio = aspect.ratio, 
                              axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1), 
                              strip.text.y = element_text(angle = 0), 
                              panel.grid.major.y = element_line(color = "grey", linetype = 2), 
                              legend.position = legend.position, 
                              legend.direction = legend.direction) + 
                        coord_cartesian(ylim = c(.plot.y.min, .plot.y.max))
                    }
                    if (isTRUE(stack)) {
                      .p <- .p + 
                        scale_y_continuous(trans = y.trans, 
                                           breaks = c(.plot.y.min, .plot.y.max), 
                                           labels = c(round(.plot.y.min, 1), round(.plot.y.max, 1)))
                    } else {
                      .p <- .p + scale_y_continuous(trans = y.trans, n.breaks = y.nbreaks)
                    }
                    if (fill.by != "expression") {
                      if (isTRUE(stack)) {
                        .p <- .p + 
                          scale_fill_manual(name = paste0(.key.nm, ":"),
                                            values = colors, breaks = levels_order,
                                            limits = levels_order, drop = FALSE) + 
                          scale_color_manual(name = paste0(.key.nm, ":"), 
                                             values = colors, breaks = levels_order, 
                                             limits = levels_order, drop = FALSE)
                      } else {
                        .p <- .p + 
                          scale_fill_manual(name = paste0(.key.nm, ":"), 
                                                     values = colors, breaks = levels_order, 
                                                     drop = FALSE) + 
                          scale_color_manual(name = paste0(.key.nm, ":"), 
                                             values = colors, breaks = levels_order, 
                                             drop = FALSE)
                      }
                      .p <- .p + 
                        guides(fill = guide_legend(title.hjust = 0, order = 1, 
                                                   override.aes = list(size = 4, color = "black", alpha = 1)))
                    } else {
                      .p <- .p + 
                        scale_fill_gradientn(name = paste0(.key.nm, ":"), 
                                             colours = colors, limits = colors.limits) + 
                        guides(fill = guide_colorbar(frame.colour = "black", 
                                                     ticks.colour = "black", title.hjust = 0, 
                                                     order = 1))
                    }
                  })
  names(.plist) <- .comb.nm
#  return(.plist)
  if (isTRUE(stack) && length(stat.by) > 1 && isFALSE(seperate.group)) {
    .plist.stack <- list()
    for (g in group.by) {
      .plot.g <- .plist[sapply(strsplit(names(.plist), ":"), function(x) x[2]) == g]
      legend <- get_legend.local(.plot.g[[1]])
      if (isTRUE(flip)) {
        lab <- grid::textGrob(label = ifelse(is.null(ylab), "Expression level", ylab), hjust = 0.5)
        .plot.g <- lapply(seq_along(.plot.g), FUN = function(i) {
          .p <- .plot.g[[i]]
          if (i != 1) {
            suppressWarnings(.p <- .p + 
                               theme(legend.position = "none", 
                                     panel.grid = element_blank(), 
                                     plot.title = element_blank(), 
                                     plot.subtitle = element_blank(), 
                                     axis.title = element_blank(), 
                                     axis.text.y = element_blank(), 
                                     axis.text.x = element_text(vjust = c(1, 0)), 
                                     axis.ticks.length.y = unit(0, "pt"), 
                                     plot.margin = unit(c(0, -0.5, 0, 0), "mm")))
          } else {
            suppressWarnings(.p <- .p + 
                               theme(legend.position = "none", 
                                     panel.grid = element_blank(), 
                                     axis.title.x = element_blank(), 
                                     axis.text.x = element_text(vjust = c(1, 0)),
                                     axis.ticks.length.y = unit(0, "pt"), 
                                     plot.margin = unit(c(0, -0.5, 0, 0), "mm")))
          }
        return(as_grob(.p))
        })
        gtable <- do.call(cbind, .plot.g)
        gtable <- add_grob.local(gtable, lab, "bottom", clip = "off")
        gtable <- add_grob.local(gtable, legend, legend.position)
      } else {
        lab <- grid::textGrob(label = ifelse(is.null(ylab), "Expression level", ylab), rot = 90, hjust = 0.5)
        .plot.g <- lapply(seq_along(.plot.g), FUN = function(i) {
          .p <- .plot.g[[i]]
          if (i != length(.plot.g)) {
            suppressWarnings(.p <- .p + 
                               theme(legend.position = "none", 
                                     panel.grid = element_blank(), 
                                     axis.title = element_blank(), 
                                     axis.text.x = element_blank(), 
                                     axis.text.y = element_text(vjust = c(0, 1)), 
                                     axis.ticks.length.x = unit(0, "pt"), 
                                     plot.margin = unit(c(-0.5, 0, 0, 0), "mm")))
            if (i == 1) {
              .p <- .p + theme(plot.title = element_blank(), plot.subtitle = element_blank())
            }
          } else {
            suppressWarnings(.p <- .p + 
                               theme(legend.position = "none", 
                                     panel.grid = element_blank(), 
                                     axis.title.y = element_blank(), 
                                     axis.text.y = element_text(vjust = c(0, 1)), 
                                     axis.ticks.length.x = unit(0, "pt"), 
                                     plot.margin = unit(c(-0.5, 0, 0, 0), "mm")))
          }
          return(as_grob(.p))
        })
        gtable <- do.call(rbind, .plot.g)
        gtable <- add_grob.local(gtable, lab, "left", clip = "off")
        gtable <- add_grob.local(gtable, legend, legend.position)
      }
      gtable <- gtable_add_padding(gtable, unit(c(1, 1, 1, 1), units = "cm"))
      .plot <- patchwork::wrap_plots(gtable)
      .plist.stack[[g]] <- .plot
    }
  if (length(.plist.stack) > 0) {
    if (length(.plist.stack) > 1) {
      .plist <- patchwork::wrap_plots(plotlist = .plist.stack, nrow = nrow, ncol = ncol, byrow = byrow)
    } else {
      .plist <- .plist.stack[[1]]
    }
  }
  }
  return(.plist)
}
