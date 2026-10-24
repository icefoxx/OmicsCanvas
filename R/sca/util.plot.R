
get_legend.local <- function(plot, legend = NULL) {
  
  gt <- ggplotGrob(plot)
  
  pattern <- "guide-box"
  if (!is.null(legend)) {
    pattern <- paste0(pattern, "-", legend)
  }
  
  indices <- grep(pattern, gt$layout$name)
  
  not_empty <- !vapply(
    gt$grobs[indices], 
    inherits, what = "zeroGrob", 
    FUN.VALUE = logical(1)
  )
  indices <- indices[not_empty]
  
  if (length(indices) > 0) {
    return(gt$grobs[[indices[1]]])
  }
  return(NULL)
}

themeBlank <- function (add.coord = TRUE, xlen.npc = 0.15, ylen.npc = 0.15, 
          xlab = "", ylab = "", lab.size = 12, theme.parent = themeDefault, ...) 
{
  args1 <- list(panel.border = element_blank(), 
                panel.grid = element_blank(), 
                axis.title = element_blank(), 
                axis.line = element_blank(), 
                axis.ticks = element_blank(), 
                axis.text = element_blank(), 
                legend.background = element_blank(), 
                legend.box.margin = margin(0, 0, 0, 0), 
                legend.margin = margin(0, 0, 0, 0), 
                legend.key.size = unit(10, "pt"),
                plot.margin = margin(lab.size + 2, lab.size + 2, lab.size + 2, lab.size + 2, unit = "points"))
  args2 <- as.list(match.call())[-1]
  call.envir <- parent.frame(1)
  args2 <- lapply(args2, function(arg) {
    if (is.symbol(arg)) {
      eval(arg, envir = call.envir)
    } else if (is.call(arg)) {
      eval(arg, envir = call.envir)
    } else {
      arg
    }
  })
  for (n in names(args2)) args1[[n]] <- args2[[n]]
  args <- args1[names(args1) %in% formalArgs(theme)]
  out <- do.call(what = theme, args = args)
  if (isTRUE(add.coord)) {
    g <- grid::grobTree(grid::gList(grid::linesGrob(x = unit(c(0, xlen.npc),  "npc"), 
                                  y = unit(c(0, 0), "npc"), 
                                  arrow = arrow(length = unit(0.02, "npc")), 
                                  gp = grid::gpar(lwd = 2)), 
                        grid::textGrob(label = xlab,  
                                 x = unit(0, "npc"),
                                 y = unit(0, "npc"), vjust = 4/3,
                                 hjust = 0,  
                                 gp = grid::gpar(fontsize = lab.size)),
                        grid::linesGrob(x = unit(c(0, 0), "npc"), 
                                  y = unit(c(0, ylen.npc), "npc"), 
                                  arrow = arrow(length = unit(0.02,"npc")), 
                                  gp = grid::gpar(lwd = 2)), 
                        grid::textGrob(label = ylab, 
                                 x = unit(0, "npc"), 
                                 y = unit(0, "npc"), 
                                 vjust = -2/3,
                                 hjust = 0, rot = 90, 
                                 gp = grid::gpar(fontsize = lab.size))
                        ))
    return(list(list(annotation_custom(g)), 
                list(theme.parent() + out), 
                list(coord_cartesian(clip = "off"))))
  }
  else {
    return(list(list(theme.parent() + out)))
  }
}


#' @importFrom grDevices col2rgb rgb
col2hex <- function(cname) {
  colMat <- col2rgb(cname)
  rgb(red = colMat[1, ] / 255, green = colMat[2, ] / 255, blue = colMat[3, ] / 255)
}


paletteCustomize <- function(x, n = 100, display = FALSE, codes = T,  
                             palettePath = NULL, palette = "Paired", palcolor = NULL, 
                             type = "auto", matched = FALSE, reverse = FALSE,  
                             keep.na = FALSE, color.na = "grey80") {
  .palette.type <- match.arg(type, c("auto", "discrete", "continuous"))
  .palette.path <- palettePath %||% paste0(getwd(), '/', 'palettes.rds')
  .palette.lst <- readRDS(.palette.path)
  .palette.names <- names(.palette.lst)
  if (isTRUE(display)){
    if (!is.null(palette)){
      .palette.ava <- intersect(palette, .palette.names)
      .palette.mis <- setdiff(palette, .palette.ava)
      if (length(.palette.ava) > 0) {
      .palette.display <- .palette.ava
      if (length(.palette.mis) > 0) cli::cli_alert('Input palette `{(.palette.mis)}` is not available.')
      } else {
      cli::cli_abort('Input palette is not available. Please check or set palette to NULL')
      }
    } else {
      if(type == 'auto') {
        .palette.display <- .palette.names
      } else {
        .palette.display <- names(.palette.lst[sapply(.palette.lst, function(x) isTRUE(attr(x, "type") %in% type))])
    }
    }
    .df <- data.frame(palettes = rep(.palette.display, sapply(.palette.lst[.palette.display], length)), 
                     color = unlist(.palette.lst[.palette.display]))
    .df[["palettes"]] <- factor(.df[["palettes"]], levels = rev(unique(.df[["palettes"]])))
    .df[["color_order"]] <- factor(seq_len(nrow(.df)), levels = seq_len(nrow(.df)))
    .df[["proportion"]] <- as.numeric(1 / table(.df$palettes)[.df$palettes])
    .p <- ggplot(data = .df, aes(y = .data[["palettes"]], x = .data[["proportion"]], fill = .data[["color_order"]])) +
      geom_col(show.legend = FALSE) +
      scale_fill_manual(values = .df[["color"]]) +
      scale_x_continuous(expand = c(0, 0), trans = "reverse") +
      themeDefault(
        axis.title = element_blank(),
        axis.ticks = element_blank(),
        axis.text.x = element_blank(),
        panel.border = element_blank()
      )
    print(.p)
    .p <- if(isTRUE(codes)) .df else NULL
    return(.p)
  }
  if (missing(x)) {
    x <- 1:n
    type <- "continuous"
  }
  .palcolor <- palcolor
  if (is.null(palcolor) && is.null(palette)) cli::cli_abort( 'Please specify a color (palcolor) or color set (palette). Set `display` to T to see colors')
  # Unknown palette names (free text from the UI) fall back instead of failing the whole figure.
  if (is.null(palcolor) && !palette %in% .palette.names) {
    fallback <- if (type == "continuous" || identical(type, "auto") && is.numeric(x)) "Spectral" else "Paired"
    if (!fallback %in% .palette.names) fallback <- .palette.names[1]
    warning(sprintf("Palette '%s' is not available; using '%s'.", palette, fallback), call. = FALSE)
    palette <- fallback
  }
  if (is.null(palcolor) || length(palcolor) == 0) .palcolor <- .palette.lst[[palette]]
  if (is.list(palcolor)) .palcolor <- unlist(palcolor, use.names = F)
  if (all(palcolor == "")) .palcolor <- .palette.lst[[palette]]
  if (!is.null(names(.palcolor))) {
    if (all(x %in% names(.palcolor))) {
      .palcolor <- .palcolor[intersect(names(.palcolor), x)]
    }
  }
  .pal.n <- length(.palcolor)
  if (.palette.type == "auto") .palette.type <- if (is.numeric(x)) "continuous" else "discrete"
  if (.palette.type == "discrete") {
    if (!is.factor(x)) x <- factor(x, levels = unique(x))
    .x.ln <- nlevels(x)
    if (isTRUE(attr(.palcolor, "type") == "continuous")) {
      .color.use <- colorRampPalette(.palcolor)(.x.ln)
    } else {
      .color.use <- ifelse(rep(.x.ln, .x.ln) <= .pal.n, .palcolor[1:.x.ln], colorRampPalette(.palcolor)(.x.ln))
    }
    names(.color.use) <- levels(x)
    if (any(is.na(x))) .color.use <- c(.color.use, setNames(color.na, "NA"))
    if (isTRUE(matched)) {
      .color.use <- .color.use[x]
      .color.use[is.na(.color.use)] <- color.na
    }
  } else if (.palette.type == "continuous") {
    if (!is.numeric(x) && all(!is.na(x))) cli::cli_abort("'x' must be numeric for continuous palettes.")
    if (all(is.na(x))) {
      .values <- as.factor(rep(0, n))
    } else if (length(unique(na.omit(as.numeric(x)))) == 1) {
      .values <- as.factor(rep(unique(na.omit(as.numeric(x))), n))
    } else {
      if (isTRUE(matched)) {
        .values <- cut(x, breaks = seq(min(x, na.rm = TRUE), max(x, na.rm = TRUE), length.out = n + 1), include.lowest = TRUE)
      } else {
        .values <- cut(1:100, breaks = seq(min(x, na.rm = TRUE), max(x, na.rm = TRUE), length.out = n + 1), include.lowest = TRUE)
      }
    }
    .x.ln <- nlevels(.values)
    .color.use <- ifelse(rep(.x.ln, .x.ln) <= .pal.n, .palcolor[1:.x.ln], colorRampPalette(.palcolor)(.x.ln))
    names(.color.use) <- levels(.values)
    if (any(is.na(x))) .color.use <- c(.color.use, setNames(color.na, "NA"))
    if (isTRUE(matched)) {
      if (all(is.na(x))) {
        .color.use <- color.na
      } else if (length(unique(na.omit(x))) == 1) {
        .color.use <- .color.use[as.character(unique(na.omit(x)))]
        .color.use[is.na(.color.use)] <- color.na
      } else {
        .color.use <- .color.use[as.character(.values)]
        .color.use[is.na(.color.use)] <- color.na
      }
    }
  }
  if (isTRUE(reverse)) .color.use <- rev(.color.use)
  if (!isTRUE(keep.na)) .color.use <- .color.use[names(.color.use) != "NA"]
  return(.color.use)
}


themeDefault <- function(aspect.ratio = NULL, baseSize = 12, ...) {
  .scale.textsize <- baseSize / 12
  .args1 <- list(
    aspect.ratio = aspect.ratio,
    text = element_text(size = 12 * .scale.textsize, color = "black"),
    plot.title = element_text(size = 14 * .scale.textsize, colour = "black", vjust = 1),
    plot.subtitle = element_text(size = 13 * .scale.textsize, hjust = 0, margin = margin(b = 3)),
    plot.background = element_rect(fill = "white", color = "white"),
    axis.line = element_blank(),
    axis.title = element_text(size = 13 * .scale.textsize, colour = "black"),
    axis.text = element_text(size = 12 * .scale.textsize, colour = "black"),
    strip.text = element_text(size = 12.5 * .scale.textsize, colour = "black", hjust = 0.5, margin = margin(3, 3, 3, 3)),
    strip.background = element_rect(fill = "transparent", linetype = 0),
    strip.switch.pad.grid = unit(-1, "pt"),
    strip.switch.pad.wrap = unit(-1, "pt"),
    strip.placement = "outside",
    legend.title = element_text(size = 12 * .scale.textsize, colour = "black", hjust = 0),
    legend.text = element_text(size = 11 * .scale.textsize, colour = "black"),
    legend.key = element_rect(fill = "transparent", color = "transparent"),
    legend.key.size = unit(10, "pt"),
    legend.background = element_blank(),
    panel.background = element_rect(fill = "white", color = "white"),
    panel.border = element_rect(fill = "transparent", colour = "black", linewidth = 1)
  )
  .args2 <- as.list(match.call())[-1]
  .call.envir <- parent.frame(1)
  .args2 <- lapply(.args2, function(arg) {
    if (is.symbol(arg)) {
      eval(arg, envir = .call.envir)
    } else if (is.call(arg)) {
      eval(arg, envir = .call.envir)
    } else {
      arg
    }
  })
  for (n in names(.args2)) .args1[[n]] <- .args2[[n]]
  .args <- .args1[names(.args1) %in% formalArgs(theme)]
  .out <- do.call(
    what = theme,
    args = .args
  )
  return(.out)
}

#modified from cowplot
get_legend <- function(plot) {
  plot <- as_gtable(plot)
  grob_names <- plot$layout$name
  grobs <- plot$grobs
  grobIndex <- which(grepl("guide-box", grob_names))
  grobIndex <- grobIndex[1]
  matched_grobs <- grobs[[grobIndex]]
  return(matched_grobs)
}

#modified from cowplot
as_gtable <- function(plot, ...) {
  if (inherits(plot, "gtable")) {
    return(plot)
  }
  if (inherits(plot, "grob")) {
    u <- unit(1, "null")
    gt <- gtable_col(NULL, list(plot), u, u)
    gt$layout$clip <- "inherit"
    return(gt)
  } else {
    grob <- as_grob(plot, ...)
    if (inherits(grob, "gtable")) {
      return(grob)
    } else {
      return(as_gtable(grob, ...))
    }
  }
}

#modified from cowplot
as_grob <- function(plot, ...) {
  .plot.formats <- c("gList", "patchwork", "ggplot")
  .format <- sapply(.plot.formats, function(f) inherits(x = plot, what = f))
  .format.idx <- which(.format)[1]
  switch(.format.idx,
         '1' = grid::grobTree(plot),
         '2' = patchworkGrob(plot, ...),
         '3' = ggplotGrob(plot),
         cli::cli_alert("Cannot convert input plot to grob class.")
         )
}

makeLong <- function(df, ..., value = NULL) {
  if ("..r" %in% names(df)) stop("The column name '..r' is not allowed")
  .vars <- dplyr::quos(...)
  if (!missing(value)) {
    .var.value <- dplyr::enquo(value)
    .out <- df %>%
      dplyr::select(!!!.vars, value = !!.var.value) %>%
      dplyr::mutate(..r = dplyr::row_number()) %>%
      tidyr::gather(x, node, -..r, -value) %>%
      dplyr::arrange(.data$..r) %>%
      dplyr::group_by(.data$..r) %>%
      dplyr::mutate(
        next_x = dplyr::lead(.data$x),
        next_node = dplyr::lead(.data$node)
      ) %>%
      dplyr::ungroup() %>%
      dplyr::select(-..r) %>%
      dplyr::relocate(value, .after = dplyr::last_col())
  } else {
    .out <- df %>%
      dplyr::select(!!!.vars) %>%
      dplyr::mutate(..r = dplyr::row_number()) %>%
      tidyr::gather(x, node, -..r) %>%
      dplyr::arrange(.data$..r) %>%
      dplyr::group_by(.data$..r) %>%
      dplyr::mutate(
        next_x = dplyr::lead(.data$x),
        next_node = dplyr::lead(.data$node)
      ) %>%
      dplyr::ungroup() %>%
      dplyr::select(-..r)
  }
  levels <- unique(.out$x)
  .out %>%
    dplyr::mutate(dplyr::across(c(x, next_x), ~ factor(., levels = levels)))
}

blendcolors <- function(colors, mode = c("blend", "average", "screen", "multiply")) {
  mode <- match.arg(mode)
  colors <- colors[!is.na(colors)]
  if (length(colors) == 0) {
    return(NA)
  }
  if (length(colors) == 1) {
    return(colors)
  }
  .rgba <- grDevices::col2rgb(colors, alpha = TRUE) / 255
  .alpha <- .rgba["alpha", , drop = TRUE]
  .rgb <- .rgba[rownames(.rgba) != "alpha", , drop = FALSE]
  .rgb.alpha <- sweep(.rgb, 2, .alpha, `*`) + (1 - .alpha)
  if (mode == "blend") {
    .weights <- .alpha
    if (sum(.weights) <= 0) {
      .weights <- rep(1, length(colors))
    }
    .weights <- .weights / sum(.weights)
    .blend <- rowSums(sweep(.rgb, 2, .weights, `*`))
  } else if (mode == "average") {
    .blend <- rowMeans(.rgb.alpha)
  } else if (mode == "screen") {
    .blend <- apply(.rgb.alpha, 1, function(x) 1 - prod(1 - x))
  } else if (mode == "multiply") {
    .blend <- apply(.rgb.alpha, 1, prod)
  }
  blend_color <- grDevices::rgb(.blend[1], .blend[2], .blend[3])
  return(blend_color)
}

RGBA2RGB <- function(RGBA, BackGround = c(1, 1, 1)) {
  A <- RGBA[[length(RGBA)]]
  RGB <- RGBA[[-length(RGBA)]] * A + BackGround * (1 - A)
  return(RGB)
}

Blend2Color <- function(C1, C2, mode = "blend") {
  c1 <- C1[[1]]
  c1a <- C1[[2]]
  c2 <- C2[[1]]
  c2a <- C2[[2]]
  A <- 1 - (1 - c1a) * (1 - c2a)
  if (A < 1.0e-6) {
    return(list(c(0, 0, 0), 1))
  }
  if (mode == "blend") {
    out <- (c1 * c1a + c2 * c2a * (1 - c1a)) / A
    A <- 1
  }
  if (mode == "average") {
    out <- (c1 + c2) / 2
    out[out > 1] <- 1
  }
  if (mode == "screen") {
    out <- 1 - (1 - c1) * (1 - c2)
  }
  if (mode == "multiply") {
    out <- c1 * c2
  }
  return(list(out, A))
}

BlendRGBList <- function(Clist, mode = "blend", RGB_BackGround = c(1, 1, 1)) {
  N <- length(Clist)
  ClistUse <- Clist
  while (N != 1) {
    temp <- ClistUse
    ClistUse <- list()
    for (C in temp[1:(length(temp) - 1)]) {
      c1 <- C[[1]]
      a1 <- C[[2]]
      c2 <- temp[[length(temp)]][[1]]
      a2 <- temp[[length(temp)]][[2]]
      ClistUse <- append(ClistUse, list(Blend2Color(C1 = list(c1, a1 * (1 - 1 / N)), C2 = list(c2, a2 * 1 / N), mode = mode)))
    }
    N <- length(ClistUse)
  }
  Result <- list(ClistUse[[1]][[1]], ClistUse[[1]][[2]])
  Result <- RGBA2RGB(Result, BackGround = RGB_BackGround)
  return(Result)
}

panel_fix_overall <- function (x, panel_index = NULL, respect = NULL, width = NULL, 
                               height = NULL, margin = 1, units = "in", raster = FALSE, 
                               dpi = 300, BPPARAM = BiocParallel::SerialParam(), return_grob = FALSE, 
                               bg_color = "white", save = NULL, verbose = TRUE) {
  suppressPackageStartupMessages(require(grid))
  suppressPackageStartupMessages(require(gridExtra))
  suppressPackageStartupMessages(require(gtable))
  if (!inherits(x, "gtable")) {
    if (inherits(x, "gTree")) x <- x[["children"]]
    tryCatch({
      gtable <- as_gtable(x, BPPARAM = BPPARAM)
    }, error = function(error) {
      stop(error, "\nCannot convert the x to a gtable object")
    })
  }
  else {
    gtable <- x
  }
  if (is.null(panel_index)) {
    non_zero <- grep(pattern = "zeroGrob", 
                     vapply(gtable$grobs, as.character, character(1)), 
                     invert = TRUE)
    panel_index <- grep("panel|full", gtable[["layout"]][["name"]])
    panel_index <- intersect(panel_index, non_zero)
  }
  if (length(panel_index) == 0 && length(gtable$grobs) ==  1) panel_index <- 1
  if (!length(width) %in% c(0, 1, length(panel_index)) || 
      !length(height) %in% c(0, 1, length(panel_index))) {
    stop("The length of 'width' and 'height' must be 1 or the length of panels.")
  }
  if (inherits(x, "gList")) {
    panel_index <- 1
    panel_index_h <- panel_index_w <- list(1)
    w_comp <- h_comp <- list(unit(1, "null"))
    w <- h <- list(unit(1, "null"))
  } else if (length(panel_index) > 0) {
    panel_index_w <- panel_index_h <- list()
    w_comp <- h_comp <- list()
    w <- h <- list()
    for (i in seq_along(panel_index)) {
      index <- panel_index[i]
      panel_index_h[[i]] <- sort(unique(c(gtable[["layout"]][["t"]][index], 
                                          gtable[["layout"]][["b"]][index])))
      panel_index_w[[i]] <- sort(unique(c(gtable[["layout"]][["l"]][index], 
                                          gtable[["layout"]][["r"]][index])))
      w_comp[[i]] <- gtable[["widths"]][seq(min(panel_index_w[[i]]), 
                                            max(panel_index_w[[i]]))]
      h_comp[[i]] <- gtable[["heights"]][seq(min(panel_index_h[[i]]), 
                                             max(panel_index_h[[i]]))]
      if (length(w_comp[[i]]) == 1) {
        w[[i]] <- w_comp[[i]]
      } else if (length(w_comp[[i]]) > 1 && any(unitType(w_comp[[i]]) == "null")) {
        w[[i]] <- unit(1, units = "null")
      } else {
        w[[i]] <- sum(w_comp[[i]])
      }
      if (length(h_comp[[i]]) == 1) {
        h[[i]] <- h_comp[[i]]
      } else if (length(h_comp[[i]]) > 1 && any(unitType(h_comp[[i]]) == "null")) {
        h[[i]] <- unit(1, units = "null")
      } else {
        h[[i]] <- sum(h_comp[[i]])
      }
    }
  } else {
    stop("No panel detected.")
  }
  if (units != "null") {
    raw_w <- sapply(w, function(x) convertWidth(x, unitTo = units, valueOnly = TRUE))
    raw_h <- sapply(h, function(x) convertHeight(x, unitTo = units, valueOnly = TRUE))
    for (i in seq_along(w)) {
      if (unitType(w[[i]]) == "null" || convertUnit(w[[i]], unitTo = "cm", valueOnly = TRUE) < 1e-10) {
        raw_w[i] <- 0
      }
    }
    for (i in seq_along(h)) {
      if (unitType(h[[i]]) == "null" || convertUnit(h[[i]], unitTo = "cm", valueOnly = TRUE) < 1e-10) {
        raw_h[i] <- 0
      }
    }
    if (isTRUE(gtable$respect)) {
      raw_aspect <- sapply(h, as.vector)/sapply(w, as.vector)
    } else {
      if (all(raw_w != 0) && all(raw_h != 0)) {
        raw_aspect <- raw_h/raw_w
      } else {
        raw_aspect <- convertHeight(unit(1, "npc"), "cm", valueOnly = TRUE)/convertWidth(unit(1, "npc"), "cm", valueOnly = TRUE)
      }
    }
    if (is.null(width) && is.null(height)) {
      width <- raw_w
      height <- raw_h
      if (all(width == 0) && all(height == 0)) {
        width <- convertWidth(unit(1, "npc"), units, valueOnly = TRUE)
        height <- convertHeight(unit(1, "npc"), units, valueOnly = TRUE)
        if (isTRUE(gtable$respect)) {
          if (raw_aspect <= 1) {
            height <- width * raw_aspect
          } else {
            width <- height/raw_aspect
          }
        }
      }
    }
    for (i in seq_along(raw_aspect)) {
      if (is.finite(raw_aspect[i]) && raw_aspect[i] != 0) {
        if (is.null(width[i]) || is.na(width[i]) || width[i] == 0) {
          width[i] <- height[i]/raw_aspect[i]
        }
        if (is.null(height[i]) || is.na(height[i]) || height[i] == 0) {
          height[i] <- width[i] * raw_aspect[i]
        }
      }
    }
    for (i in seq_along(width)) {
      if (inherits(width[i], "unit")) {
        width[i] <- convertWidth(width[i], unitTo = units, valueOnly = TRUE)
      }
    }
    for (i in seq_along(height)) {
      if (inherits(height[i], "unit")) {
        height[i] <- convertHeight(height[i], unitTo = units, valueOnly = TRUE)
      }
    }
  }
  if (length(width) == 1) width <- rep(width, length(panel_index))
  if (length(height) == 1) height <- rep(height, length(panel_index))
  for (i in seq_along(panel_index)) {
    tmp.idx.w <- seq(min(panel_index_w[[i]]), max(panel_index_w[[i]]))
    tmp.idx.h <- seq(min(panel_index_h[[i]]), max(panel_index_h[[i]]))
    if (!is.null(width)) {
      width_unit <- width[i]/length(w_comp[[i]])
      gtable[["widths"]][tmp.idx.w] <- rep(unit(width_unit, units = units), length(w_comp[[i]]))
    }
    if (!is.null(height)) {
      height_unit <- height[i]/length(h_comp[[i]])
      gtable[["heights"]][tmp.idx.h] <- rep(unit(height_unit,  units = units), length(h_comp[[i]]))
    }
  }
  gtable <- gtable_add_padding(gtable, padding = unit(margin, units = units))
  if (isTRUE(raster)) {
    suppressMessages(ckPacsR(c("png", "ragg")))
    for (i in seq_along(panel_index)) {
      index <- panel_index[i]
      g <- g_new <- gtable$grobs[[index]]
      vp <- g$vp
      childrenOrder <- g$childrenOrder
      if (is.null(g$vp)) g$vp <- viewport()
      for (j in seq_along(g[["children"]])) {
        child <- g[["children"]][[j]]
        child_nm <- names(g[["children"]])[j]
        if (!is.null(child$vp) || any(grepl("(text)|(label)", child_nm)) || any(grepl("(text)|(segments)|(legend)", class(child$list[[1]])))) {
          zero <- zeroGrob()
          zero$name <- g[["children"]][[j]]$name
          g[["children"]][[j]] <- zero
        } else if (inherits(child$list[[1]], "grob") || is.null(child$list[[1]])) {
          g_new[["children"]][[j]] <- zeroGrob()
        }
      }
      temp <- tempfile(fileext = "png")
      ragg::agg_png(temp, width = width[i], height = height[i], bg = "transparent", res = dpi, units = units)
      grid.draw(g)
      dev.off()
      g_ras <- rasterGrob(png::readPNG(temp, native = TRUE))
      unlink(temp)
      g <- addGrob(g_new, g_ras)
      g$vp <- vp
      g$childrenOrder <- c(g_ras$name, childrenOrder)
      gtable$grobs[[index]] <- g
    }
  }
  if (!is.null(respect)) gtable$respect <- respect
  if (isTRUE(return_grob)) {
    return(gtable)
  } else {
    p <- wrap_plots(gtable) + theme(plot.background = element_rect(fill = bg_color, color = bg_color))
    if (units != "null") {
      plot_width <- convertWidth(sum(gtable[["widths"]]), 
                                 unitTo = units, valueOnly = TRUE)
      plot_height <- convertHeight(sum(gtable[["heights"]]), 
                                   unitTo = units, valueOnly = TRUE)
      attr(p, "size") <- list(width = plot_width, height = plot_height, 
                              units = units)
    }
    if (!is.null(save) && is.character(save) && nchar(save) > 0) {
      if (units == "null") stop("units can not be 'null' if want to save the plot.")
      filename <- normalizePath(save)
      if (isTRUE(verbose)) message("Save the plot to the file: ", filename)
      if (!dir.exists(dirname(filename)))  dir.create(dirname(filename), recursive = TRUE, showWarnings = FALSE)
      ggsave(plot = p, filename = filename, width = plot_width, 
             height = plot_height, units = units, dpi = dpi, 
             limitsize = FALSE)
    }
    return(p)
  }
}

# Please help me write the discription of this function
#' @param gtable A gtable object
#' @param grob A grob object
#' @param position the position of added grob, one of "top", "bottom", "left", "right" or "none"
#' @param space the space between the added grob and the original gtable
#' @param clip whether to clip the grob
#' @return A gtable object
#' @export
#' @import grid rlang gtable
add_grob.local <- function (gtable, grob, position = c("top", "bottom", "left", "right", "none"),
                            space = NULL, clip = "on") {
  position <- match.arg(position)
  if (position == "none" || is.null(grob)) return(gtable)
  if (is.null(space)) {
    if (is.gtable(grob)) {
      if (position %in% c("top", "bottom")) {
        space <- sum(grob$heights)
      } else {
        space <- sum(grob$widths)
      }
    } else if (is.grob(grob)) {
      if (position %in% c("top", "bottom")) {
        space <- grobHeight(grob)
      } else {
        space <- grobWidth(grob)
      }
    }
  }
  if (position == "top") {
    gtable <- gtable_add_rows(gtable, space, 0)
    gtable <- gtable_add_grob(gtable, grob, t = 1, 
                              l = mean(gtable$layout[grepl(pattern = "panel", x = gtable$layout$name), "l"]), 
                              clip = clip)
  }
  if (position == "bottom") {
    gtable <- gtable_add_rows(gtable, space, -1)
    gtable <- gtable_add_grob(gtable, grob, t = dim(gtable)[1], 
                              l = mean(gtable$layout[grepl(pattern = "panel", x = gtable$layout$name), "l"]), 
                              clip = clip)
  }
  if (position == "left") {
    gtable <- gtable_add_cols(gtable, space, 0)
    gtable <- gtable_add_grob(gtable, grob, 
                              t = mean(gtable$layout[grep("panel", gtable$layout$name), "t"]), l = 1, 
                              clip = clip)
  }
  if (position == "right") {
    gtable <- gtable_add_cols(gtable, space, -1)
    gtable <- gtable_add_grob(gtable, grob, 
                              t = mean(gtable$layout[grep("panel", gtable$layout$name), "t"]), l = dim(gtable)[2], 
                              clip = clip)
  }
  return(gtable)
}


DE.color.gradient <- function(x, colors=c("#456700", "white", "#990000"), colsteps=100) {
  if (as.numeric(x) <= 5 && length(x) <= 5 ) stop('At least 5 colors are returned') 
  .x <- if (is.numeric(x) & length(x) == 1) seq.int(x) else seq_along(x)
  return( colorRampPalette(colors) (colsteps) [ findInterval(.x, seq(min(.x), max(.x), length.out=colsteps)) ] )
}

col4alpha <- function(colors, alpha) {
  .out <- sapply(as.data.frame(col2rgb(colors)/255), function(color) {
    .color.rgb <- RGBA2RGB(list(color, alpha))
    return(rgb(.color.rgb[1], .color.rgb[2], .color.rgb[3]))
  })
  return(.out)
}

mmdata <- function(x, m = c('mean', 'median'), model = 1) {
  if (m %in% c('mean', 'median')){
    .out <- switch (m,
                    mean = { if (model == 1) return(exp(mean(log(x)))) else return(log1p(exp(mean(log(x))))) },
                    median = { if (model == 1) return(exp(median(log(x)))) else return(log1p(exp(median(log(x))))) }
    )
  } else {
    .m <- match.fun(m)
    if ('x' %in% names(model)) cli::cli_abort("x is a reserved name for data used in function.")
    model[['x']] <- x
    .out <- invoke(.m, model)
  }
  return(.out)
}

mmY <- function(gg, mode = 1, scale = 1.15){
  if (mode == 1) {
    return(layer_scales(gg)$y$range$range[2])
  } else if (mode == 2){
    layer_scales(gg)$y$range$range[1] + (layer_scales(gg)$y$range$range[2] - layer_scales(gg)$y$range$range[1]) * scale
  }
}
