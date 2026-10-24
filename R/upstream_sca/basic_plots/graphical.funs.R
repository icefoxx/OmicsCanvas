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
