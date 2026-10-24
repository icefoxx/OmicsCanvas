statPlot <- function(df, stat.by = NULL, group.by = NULL, split.by = NULL, bg.by = NULL, flip = FALSE,
                     color.na = "grey", keep.na = TRUE, keep.empty = FALSE, each = FALSE, stat.level = NULL,
                     plot.type = c("bar", "rose", "ring", "pie", "trend", "area", "dot", "sankey", "chord", "venn", "upset"),
                     stat.type = c("percent", "count"), position = c("stack", "dodge"),
                     palette = "Paired", palcolor = NULL, alpha = 1,
                     palette.bg = "Paired", palcolor.bg = NULL, alpha.bg = 0.2,
                     label = FALSE, label.size = 3.5, label.fg = "black", 
                     label.bg = "white", label.bg.r = 0.1, aspect.ratio = NULL,
                     title = NULL, subtitle = NULL, xlab = NULL, ylab = NULL,
                     legend.position = "right", legend.direction = "vertical",
                     theme.use = "themeDefault", theme.args = list(),
                     combine = TRUE, nrow = NULL, ncol = NULL, byrow = TRUE, 
                     force = FALSE, seed = 10086) {
  .require.pacs <- c('tidyverse', 'ggrepel', 'patchwork', 'gtable')
  invisible(sapply(.require.pacs, library, quietly = TRUE, character.only = T))
  set.seed(seed)
  .stat.type <- match.arg(stat.type)
  .plot.type <- match.arg(plot.type)
  .position <- match.arg(position)
  .bg.by <- bg.by
  .xlab <- xlab
  if (nrow(df) == 0) cli::cli_abort("Input data is empty.")
  .df.data <- formatDF4statPlot(df, stat.by = stat.by, group.by = group.by, 
                                split.by = split.by, bg.by = .bg.by, 
                                plot.type = .plot.type)
  .group.by <- if (is.null(group.by) || length(group.by) == 0) "All.groups" else group.by
  .split.by <- if (is.null(split.by) || length(split.by) == 0) 'All.groups' else split.by
  if (is.null(.group.by)) .xlab <- ""
  if (all(sapply(.df.data, is.null))) cli::cli_abort("No data to plot, please check the format of input data.")
  df <- .df.data$df
  .bg.map <- .df.data$bg.map
  if (length(stat.by) >= 2) {
    if (!.plot.type %in% c("sankey", "chord", "venn", "upset")) {
      cli::cli_abort("plot.type must be one of 'sankey', 'chord', 'venn' and 'upset' whtn multiple 'stat.by' provided.")
    }
    if (length(stat.by) > 2 && .plot.type == "chord") {
      cli::cli_abort("'stat.by' can only be a vector of length 2 when 'plot.type' is 'chord'.")
    }
    if (length(stat.by) > 7 && .plot.type == "venn") {
      cli::cli_abort("'stat.by' can only be a vector of length <= 7 when 'plot.type' is 'venn'.")
    }
  }
  if (.plot.type == "sankey" && length(stat.by) < 2) {
    cli::cli_abort("'sankey' plot requires at least two variables in `stat.by`; `group.by` is ignored for this plot type.")
  }
  if (.plot.type == "chord" && length(stat.by) != 2) {
    cli::cli_abort("'chord' plot requires exactly two variables in `stat.by`.")
  }
  .levels.stat.by <- unique(unlist(lapply(df[, stat.by, drop = FALSE], function(x) {
    if (is.factor(x)) return(levels(x)) 
    if (is.logical(x)) return(as.character(unique(x)))
  })))
  if (.plot.type %in% c("venn", "upset")) {
    if (is.null(stat.level)) {
      .stat.level <- lapply(stat.by, function(s) levels(df[[s]])[1] %||% sort(unique(df[[s]]))[1])
      cli::cli_inform('stat_level is set to {paste0(.stat.level, collapse = ", ")}')
    } else {
        if (length(stat.level) == 1) {
          .stat.level <- rep(stat.level, length(stat.by))
        } else {
          .stat.level <- stat.level
        }
        if (length(.stat.level) != length(stat.by)) cli::cli_abort("'stat_level' must be of length 1 or the same length as 'stat.by'")
      }
    if (is.null(names(.stat.level))) names(.stat.level) <- stat.by
    for (i in stat.by) df[[i]] <- df[[i]] %in% .stat.level[[i]]
  }
  if (.plot.type %in% c("rose", "ring", "pie")) aspect.ratio <- 1
  if (any(.group.by != "All.groups") && .plot.type %in% c("sankey", "chord", "venn", "upset")) {
    cli::cli_alert_info("group.by is not used when plot sankey, chord, venn or upset")
  }
  if (.stat.type == "percent" && .plot.type %in% c("sankey", "chord", "venn", "upset")) {
    cli::cli_alert_info("`stat.type` is forcibly set to 'count' when plot sankey, chord, venn or upset")
    .stat.type <- "count"
  }
  .data.use <- df[, unique(c(stat.by, .group.by, .split.by, .bg.by)), drop = FALSE]
  .lev.n <- sapply(.data.use, nlevels)
  .lev.n <- .lev.n[.lev.n > 100]
  if (length(.lev.n) > 0 && !isTRUE(force)) {
    cli::cli_alert_info('{paste(names(.lev.n), sep = ",")} have more than 100 levels.')
    .answer <- askYesNo("Still continue?", default = FALSE)
    if (!isTRUE(.answer)) return(invisible(NULL))
  }
  if (!is.null(.split.by)) {
    .data.split <- split(.data.use, .data.use[[.split.by]])
  } else {
    .data.split <- list(All.groups = .data.use) 
  }
  ##pre-set the plot parameters  
  .plist <- list()
  if (.plot.type %in% c("bar", "rose", "ring", "pie", "trend", "area", "dot")) {
    .xlab <- .xlab %||% .group.by
    .ylab <- ylab %||% ifelse(.stat.type == "count", "Count", "Percentage")
    if (identical(theme.use, "theme_blank")) {
      theme.args[["xlab"]] <- .xlab
      theme.args[["ylab"]] <- .ylab
      if (.plot.type %in% c("rose", "ring", "pie")) theme_args[["add_coord"]] <- FALSE
    }
    .colors.use <- paletteCustomize(.data.use[[stat.by]], 
                                    palette = palette, 
                                    palcolor = palcolor, color.na = color.na, keep.na = keep.na)
    
    .comb.lst <- list()
    .combs <- expand.grid(stat_name = stat.by, group_name = .group.by, stringsAsFactors = FALSE)
    for (g in .group.by) {
      .group.element <- if (isTRUE(each)) levels(.data.use[[g]]) else list(levels(.data.use[[g]]))
      .comb.lst[[g]] <- merge(.combs, expand.grid(
        group_name = g, group_element = .group.element,
        split_name = if (is.null(.split.by)) 'All' else levels(.data.use[[.split.by]]), 
        stringsAsFactors = FALSE), 
        by = "group_name")
    }
    .combs <- do.call(rbind, .comb.lst)
    rownames(.combs) <- paste0(
      .combs[["group_name"]], ":",
      sapply(.combs[["group_element"]], function(x) paste0(x, collapse = ",")), ":",
      .combs[["split_name"]]
    )
    
    .plist <- lapply(setNames(rownames(.combs), rownames(.combs)), function(i) {
      stat.by <- .combs[i, "stat_name"]
      .sp <- .combs[i, "split_name"]
      .g <- .combs[i, "group_name"]
      .sg <- .combs[[i, "group_element"]]
      .data.engage.idx <- ifelse(.split.by == "All.groups", 1, .sp)
      .data.engage <- .data.split[[.data.engage.idx]]
      .colors.use.local <- .colors.use[names(.colors.use) %in% .data.engage[[stat.by]]]
      if (any(is.na(.data.engage[[stat.by]])) && isTRUE(keep.na)) {
        .colors.use.local <- c(.colors.use.local, .colors.use["NA"])
      }
      .df.pre <- .data.engage %>%
        xtabs(formula = paste0("~", stat.by, "+", .g), addNA = keep.na) %>%
        as.data.frame()
      if (.stat.type == "percent") {
        .df.pre <- .df.pre %>%
          group_by(across(all_of(.g)), .drop = FALSE) %>%
          mutate(groupn = sum(Freq)) %>%
          group_by(across(all_of(c(stat.by, .g))), .drop = FALSE) %>%
          mutate(value = Freq / groupn) %>%
          as.data.frame()
      } else {
        .df.pre <- .df.pre %>%
          mutate(value = Freq)
      }
      .data.plot <- .df.pre[.df.pre[[.g]] %in% .sg, , drop = FALSE]
      .data.plot[[.g]] <- factor(.data.plot[[.g]], 
                                 levels = levels(.data.plot[[.g]])[levels(.data.plot[[.g]]) %in% .data.plot[[.g]]])
      .data.plot <- .data.plot[!is.na(.data.plot[["value"]]), , drop = FALSE]
      ###take mark
      if (!is.null(.bg.by)) {
        .bg <- .bg.by 
        .colors.use.bg <- paletteCustomize(levels(.data.use[[.bg]]), palette = palette.bg, palcolor = palcolor.bg)
      } else {
        .bg <- .g
        .colors.use.bg <- paletteCustomize(levels(.data.use[[.bg]]), 
                                           palcolor = palcolor.bg %||% rep(c("transparent", "grey85"), nlevels(.data.use[[.bg]])))
      }
      
      if (isTRUE(flip)) {
        .data.plot[[.g]] <- factor(.data.plot[[.g]], levels = rev(levels(.data.plot[[.g]])))
        aspect.ratio <- 1 / aspect.ratio
        if (length(aspect.ratio) == 0 || is.na(aspect.ratio)) aspect.ratio <- NULL
      }
      if (.plot.type == "ring") {
        .data.plot[[.g]] <- factor(.data.plot[[.g]], levels = c("   ", levels(.data.plot[[.g]])))
        .data.plot <- rbind(.data.plot, .data.plot[nrow(.data.plot) + 1, , drop = FALSE])
        .data.plot[nrow(.data.plot), .g] <- "   "
      }
      if (.plot.type == "dot") {
        .position.use <- position_identity()
        .scalex <- scale_x_discrete(drop = !keep.empty)
      } else {
        if (.position == "stack") {
          .position.use <- position_stack(vjust = 0.5)
          .scalex <- scale_x_discrete(drop = !keep.empty, expand = c(0, 0))
          .scaley <- scale_y_continuous(
            labels = if (.stat.type == "count") scales::number else scales::percent,
            expand = c(0, 0)
          )
        } else if (.position == "dodge") {
          if (.plot.type == "area") {
            .position.use <- position_dodge2(width = 0.9, preserve = "total")
          } else {
            .position.use <- position_dodge2(width = 0.9, preserve = "single")
          }
          .scalex <- scale_x_discrete(drop = !keep.empty)
          .scaley <- scale_y_continuous(
            limits = c(0, max(.data.plot[["value"]], na.rm = TRUE) * 1.1),
            labels = if (.stat.type == "count") scales::number else scales::percent,
            expand = c(0, 0)
          )
        }
      }
      if (.position == "stack") {
        .bg.layer <- NULL
      } else {
        .data.bg <- na.omit(unique(.data.plot[, .g, drop = FALSE]))
        .data.bg[["x"]] <- as.numeric(.data.bg[[.g]])
        .data.bg[["xmin"]] <- ifelse(.data.bg[["x"]] == min(.data.bg[["x"]]), -Inf, .data.bg[["x"]] - 0.5)
        .data.bg[["xmax"]] <- ifelse(.data.bg[["x"]] == max(.data.bg[["x"]]), Inf, .data.bg[["x"]] + 0.5)
        .data.bg[["ymin"]] <- -Inf
        .data.bg[["ymax"]] <- Inf
        .data.bg[["fill"]] <- .colors.use.bg[.bg.map[[.g]][as.character(.data.bg[[g]])]]
        .bg.layer <- geom_rect(data = .data.bg, xmin = .data.bg[["xmin"]], 
                               xmax = .data.bg[["xmax"]], ymin = .data.bg[["ymin"]],
                               ymax = .data.bg[["ymax"]], fill = .data.bg[["fill"]], 
                               alpha = alpha.bg, inherit.aes = FALSE)
      }
      if (.plot.type == "bar") {
        .p <- ggplot(.data.plot, aes(x = .data[[.g]], y = value, group = .data[[stat.by]])) +
          .bg.layer +
          geom_col(aes(fill = .data[[stat.by]]),
                   width = 0.8,
                   color = "black",
                   alpha = alpha,
                   position = .position.use
          ) +
          .scalex +
          .scaley
      }
      if (.plot.type == "trend") {
        .data.area <- .data.plot[rep(seq_len(nrow(.data.plot)), each = 2), , drop = FALSE]
        .data.area[[.g]] <- as.numeric(.data.area[[.g]])
        .data.area[seq(1, nrow(.data.area), 2), .g] <- .data.area[seq(1, nrow(.data.area), 2), .g] - 0.3
        .data.area[seq(2, nrow(.data.area), 2), .g] <- .data.area[seq(2, nrow(.data.area), 2), .g] + 0.3
        .p <- ggplot(.data.plot, aes(x = .data[[.g]], y = value, fill = .data[[stat.by]])) +
          .bg.layer +
          geom_area(
            data = .data.area, mapping = aes(x = .data[[.g]], fill = .data[[stat.by]]),
            alpha = alpha / 2, color = "grey50", position = .position.use
          ) +
          geom_col(aes(fill = .data[[stat.by]]),
                   width = 0.6,
                   color = "black",
                   alpha = alpha,
                   position = .position.use
          ) +
          .scalex +
          .scaley
      }
      if (.plot.type == "rose") {
        .p <- ggplot(.data.plot, aes(x = .data[[g]], y = value, group = .data[[stat.by]])) +
          .bg.layer +
          geom_col(aes(fill = .data[[stat.by]]),
                   width = 0.8,
                   color = "black",
                   alpha = alpha,
                   position = .position.use
          ) +
          .scalex +
          .scaley +
          coord_polar(theta = "x", start = ifelse(flip, pi / 2, 0))
      }
      if (.plot.type == "ring" || .plot.type == "pie") {
        .p <- ggplot(.data.plot, aes(x = .data[[.g]], y = value, group = .data[[stat.by]])) +
          .bg.layer +
          geom_col(aes(fill = .data[[stat.by]]),
                   width = 0.8,
                   color = "black",
                   alpha = alpha,
                   position = .position.use
          ) +
          .scalex +
          .scaley +
          coord_polar(theta = "y", start = ifelse(flip, pi / 2, 0))
      }
      if (.plot.type == "area") {
        .p <- ggplot(.data.plot, aes(x = .data[[g]], y = value, group = .data[[stat.by]])) +
          .bg.layer +
          geom_area(aes(fill = .data[[stat.by]]),
                    color = "black",
                    alpha = alpha,
                    position = .position.use
          ) +
          .scalex +
          .scaley
      }
      if (.plot.type == "dot") {
        .p <- ggplot(.data.plot, aes(x = .data[[.g]], y = .data[[stat.by]])) +
          .bg.layer +
          geom_point(aes(fill = .data[[stat.by]], size = value),
                     color = "black",
                     alpha = alpha,
                     shape = 21,
                     position = .position.use
          ) +
          .scalex +
          scale_size_area(name = toUpperX(.stat.type), max_size = 12) +
          guides(size = guide_legend(override.aes = list(fill = "grey30")))
      }
      ####here to be continued
      if (isTRUE(label)) {
        if (.plot.type == "dot") {
          .p <- .p + geom_text_repel(
            aes(
              x = .data[[.g]], y = .data[[stat.by]],
              label = if (.stat.type == "count") value else paste0(round(value * 100, 1), "%"),
            ),
            colour = label.fg, size = label.size,
            bg.color = label.bg, bg.r = label.bg.r,
            point.size = NA, max.overlaps = 100, min.segment.length = 0, force = 0,
            position = .position.use
          )
        } else {
          .p <- .p + geom_text_repel(
            aes(
              label = if (.stat.type == "count") value else paste0(round(value * 100, 1), "%"),
              y = value
            ),
            colour = label.fg, size = label.size,
            bg.color = label.bg, bg.r = label.bg.r,
            point.size = NA, max.overlaps = 100, min.segment.length = 0, force = 0,
            position = .position.use
          )
        }
      }
      if (.plot.type %in% c("rose", "ring", "pie")) {
        .axis.text.x <- element_text()
      } else {
        .axis.text.x <- element_text(angle = 45, hjust = 1, vjust = 1)
      }
      title <- title %||% .sp
      .p <- .p + labs(title = title, subtitle = subtitle, x = .xlab, y = .ylab) +
        scale_fill_manual(
          name = paste0(stat.by, ":"), values = .colors.use.local, 
          na.value = .colors.use.local["NA"], drop = FALSE,
          limits = names(.colors.use.local), na.translate = T
        ) +
        do.call(theme.use, theme.args) +
        theme(
          aspect.ratio = aspect.ratio,
          axis.text.x = .axis.text.x,
          legend.position = legend.position,
          legend.direction = legend.direction,
          panel.grid.major = if (.plot.type == "trend" & .stat.type == "percent") element_blank() else element_line(colour = "grey80", linetype = 2)
        ) + guides(fill = guide_legend(
          title.hjust = 0,
          order = 1,
          override.aes = list(size = 4, color = "black", alpha = 1)
        ))
      if (isTRUE(flip) && !.plot.type %in% c("pie", "rose")) {
        .p <- .p + coord_flip()
      }
      return(.p)
    })
  } else if (.plot.type %in% c("chord", "sankey", "venn", "upset")) {
    .colors.use <- paletteCustomize(.data.use[[.group.by]], palette = palette, palcolor = palcolor)
    if (.plot.type == "chord" && isTRUE(combine)) {
      .temp <- tempfile(fileext = "png")
      png(.temp)
      dev.control("enable")
      .lev.n <- nlevels(.data.use[[.split.by]])
      if (is.null(nrow) && is.null(ncol)) {
        nrow <- ceiling(sqrt(.lev.n))
        ncol <- ceiling(.lev.n / nrow)
      }
      if (is.null(nrow)) nrow <- ceiling(sqrt(ncol))
      if (is.null(ncol)) ncol <- ceiling(sqrt(nrow))
      par(mfrow = c(nrow, ncol))
    }
    for (.sp in levels(.data.use[[.split.by]])) {
      .df.pre <- .data.split[[ifelse(.split.by == "All.groups", 1, .sp)]]
      if (.plot.type == "venn") {
        ckPacsR(c("ggVennDiagram", "sf"))
        .df.lst <- lapply(setNames(stat.by, stat.by), function(x) {
          .lg <- .df.pre[[x]]
          .rn <- rownames(.df.pre)
          if (is.null(.rn)) .rn <- as.character(seq_len(nrow(.df.pre)))
          .rn[which(.lg)]
        })
        .df.lst <- .df.lst[lengths(.df.lst) > 0]
        if (length(.df.lst) < 2) {
          cli::cli_abort("At least two non-empty sets are required for venn plot. Please check `stat.by` and `stat.level`.")
        }
        .venn <- ggVennDiagram::Venn(.df.lst)
        .data.venn <- ggVennDiagram::process_data(.venn)
        .data.venn.region <- .data.venn$regionLabel
        .data.venn.region.edge <- .data.venn$regionEdge
        .data.venn.setedge <- .data.venn$setEdge
        .data.venn.setlabel <- .data.venn$setLabel
        .venn.name.idx <- which(.data.venn.region[["name"]] %in% names(.df.lst))
        .idname <- .data.venn.region[["name"]][.venn.name.idx]
        names(.idname) <- .data.venn.region[["id"]][.venn.name.idx]
        .idcomb <- strsplit(.data.venn.region[["id"]], split = "/")
        .colors.use <- paletteCustomize(names(.df.lst), palette = palette, palcolor = palcolor)
        names(.colors.use) <- names(.df.lst)
        .colorcomb <- lapply(.idcomb, function(x) .colors.use[.idname[x]])
        .data.venn.region[["colors"]] <- sapply(.colorcomb, function(x) blendcolors(x, mode = "blend"))
        .data.venn.region[["label"]] <- paste0(
          .data.venn.region[["count"]], "\n",
          round(.data.venn.region[["count"]] / sum(.data.venn.region[["count"]]) * 100, 1), "%"
        )
        .edge.name <- .data.venn.setlabel[["name"]][match(.data.venn.setedge[["id"]], .data.venn.setlabel[["id"]])]
        .edge.colors <- .colors.use[.edge.name]
        .edge.colors[is.na(.edge.colors)] <- unname(.colors.use[1])
        .data.venn.setedge[["colors"]] <- .edge.colors
        .data.venn.title <- .data.venn.setlabel[, c("X", "Y"), drop = FALSE]
        colnames(.data.venn.title) <- c("x", "y")
        .data.venn.title[["label"]] <- paste0(
          .data.venn.setlabel[["name"]], "\n",
          "(", sapply(.df.lst, length)[.data.venn.setlabel[["name"]]], ")"
        )
        .data.stat.venn <- .data.venn.region[, c("X", "Y"), drop = FALSE]
        colnames(.data.stat.venn) <- c("x", "y")
        .data.stat.venn[["label"]] <- .data.venn.region[["label"]]
        .p <- ggplot() +
          geom_polygon(data = .data.venn.region.edge, aes(x = X, y = Y, group = id,
                                                          fill = .data.venn.region[["colors"]][match(id, .data.venn.region[["id"]])]),
                       alpha = alpha, color = NA) +
          geom_path(data = .data.venn.setedge, aes(x = X, y = Y, group = id, color = colors), linewidth = 1) +
          geom_text_repel(
            data = .data.venn.title, aes(label = label, x = x, y = y),
            fontface = "bold",
            colour = label.fg, size = label.size + 0.5,
            bg.color = label.bg, bg.r = label.bg.r,
            point.size = NA, max.overlaps = 100, force = 0,
            min.segment.length = 0, segment.colour = "black"
          ) +
          geom_text_repel(
            data = .data.stat.venn, aes(label = label, x = x, y = y),
            colour = label.fg, size = label.size,
            bg.color = label.bg, bg.r = label.bg.r,
            point.size = NA, max.overlaps = 100, force = 0,
            min.segment.length = 0, segment.colour = "black"
          ) +
          scale_fill_identity() +
          scale_color_identity() +
          # Set labels sit outside the circles: leave room and do not clip them.
          scale_x_continuous(expand = expansion(mult = 0.15)) +
          scale_y_continuous(expand = expansion(mult = 0.08)) +
          coord_cartesian(clip = "off") +
          theme(
            plot.title = element_text(hjust = 0.5),
            plot.background = element_blank(),
            panel.background = element_blank(),
            axis.title.y = element_blank(),
            axis.text = element_blank(),
            axis.ticks = element_blank()
          )
        .p <- .p + labs(x = .sp, title = title, subtitle = subtitle)
      }
      if (.plot.type == "upset") {
        ckPacsR("ggupset")
        for (n in seq_len(nrow(.df.pre))) {
          .df.pre[["intersection"]][n] <- list(stat.by[unlist(.df.pre[n, stat.by])])
        }
        .data.plot <- .df.pre[sapply(.df.pre[["intersection"]], length) > 0, , drop = FALSE]
        .p <- ggplot(.data.plot, aes(x = intersection)) +
          geom_bar(aes(fill = after_stat(count)), color = "black", width = 0.5, show.legend = FALSE) +
          geom_text_repel(aes(label = after_stat(count)),
                          stat = "count",
                          colour = label.fg, size = label.size,
                          bg.color = label.bg, bg.r = label.bg.r,
                          point.size = NA, max.overlaps = 100, force = 0,
                          min.segment.length = 0, segment.colour = "black"
          ) +
          labs(title = title, subtitle = subtitle, x = .sp, y = "Intersection size") +
          ggupset::scale_x_upset(sets = stat.by, n_intersections = 20) +
          scale_fill_gradientn(colors = paletteCustomize(palette = "material-indigo")) +
          themeDefault(
            aspect.ratio = 0.6,
            panel.grid.major = element_line(colour = "grey80", linetype = 2)
          ) +
          ggupset::theme_combmatrix(
            combmatrix.label.text = element_text(size = 12, color = "black"),
            combmatrix.label.extra_spacing = 6
          )
        .p <- .p + labs(title = title, subtitle = subtitle)
      }
      if (.plot.type == "sankey") {
        .colors.sankey <- paletteCustomize(c(unique(unlist(lapply(.data.use[, stat.by, drop = FALSE], levels))), NA), 
                                           palette = palette, palcolor = palcolor, 
                                           keep.na = keep.na, color.na = color.na)
        ckPacsR('ggsankey')
        invisible(suppressWarnings(library(ggsankey)))
        .legend.sankey <- list()
        for (l in stat.by) {
          .data.plot <- data.frame(factor(levels(.df.pre[[l]]), levels = levels(.df.pre[[l]])))
          colnames(.data.plot) <- l
          .legend.sankey[[l]] <- get_legend.local(ggplot(data = .data.plot) +
                                              geom_col(aes(x = 1, y = 1, fill = .data[[l]]), color = "black") +
                                              scale_fill_manual(values = .colors.sankey[levels( .df.pre[[l]])]) +
                                              guides(fill = guide_legend(
                                                title.hjust = 0,
                                                title.vjust = 0,
                                                order = 1,
                                                override.aes = list(size = 4, color = "black", alpha = 1)
                                              )) +
                                              theme_scp(
                                                legend.position = "bottom",
                                                legend.direction = legend.direction
                                              ))
          if (any(is.na(.df.pre[[l]]))) {
            .levels.raw <- levels(.df.pre[[l]])
            .df.pre[[l]] <- as.character(.df.pre[[l]])
            .df.pre[[l]][is.na(.df.pre[[l]])] <- "NA"
            .df.pre[[l]] <- factor(.df.pre[[l]], levels = c(.levels.raw, "NA"))
          }
        }
        .legend.sankey <- do.call(rbind, .legend.sankey)
        ## NOTE: original SCA line `if (legend.direction == "vertical") legend <- do.call(cbind, .legend.sankey)`
        ## errors because .legend.sankey is a gtable after rbind (do.call(cbind, gtable) spreads its list
        ## elements). The `legend` variable is never used downstream, so this dead line is patched out
        ## for standalone CLI use. The stacked legend gtable (.legend.sankey) is added via add_grob.local below.
        .data.plot <- suppressWarnings(make_long( .df.pre, all_of(stat.by)))
        .data.plot$node <- factor(.data.plot$node, levels = rev(names(.colors.sankey)))
        .p0 <- ggplot(.data.plot, aes(x = x, next_x = next_x, node = node, next_node = next_node, fill = node)) +
          geom_sankey(color = "black", flow.alpha = alpha, show.legend = FALSE, na.rm = FALSE) +
          scale_fill_manual(values = .colors.sankey, drop = FALSE) +
          scale_x_discrete(expand = c(0, 0.2)) +
          theme_void() +
          theme(axis.text.x = element_text())
        .gtable <- as_grob(.p0)
        .gtable <- add_grob.local(.gtable, .legend.sankey, legend.position)
        .p <- wrap_plots(.gtable)
      }
      if (.plot.type == "chord") {
        ckPacsR("circlize")
        .colors.chord <- paletteCustomize(c(unique(unlist(lapply(.data.use[, stat.by, drop = FALSE], levels))), NA), 
                                          palette = palette, palcolor = palcolor, 
                                          keep.na = keep.na, color.na = color.na)
        .df.pre.tb <- table(.df.pre[[stat.by[1]]], .df.pre[[stat.by[2]]], useNA = "ifany")
        .df.pre.tb.m <- matrix(.df.pre.tb, ncol = ncol(.df.pre.tb), dimnames = dimnames(.df.pre.tb))
        colnames(.df.pre.tb.m)[is.na(colnames(.df.pre.tb.m))] <- "NA"
        circlize::chordDiagram(.df.pre.tb.m,
                               grid.col = .colors.chord,
                               transparency = 0.2,
                               link.lwd = 1,
                               link.lty = 1,
                               link.border = 1
        )
        circlize::circos.clear()
        .p <- recordPlot()
        
      }
      
      .plist[[.sp]] <- .p
    }
  }
  if (isTRUE(combine)){
    if (.plot.type == "chord") {
      .plot.out <- recordPlot()
      dev.off()
      unlink(.temp)
    } else {
      if (length(.plist) > 1) {
        .plot.out <- wrap_plots(plotlist = .plist, nrow = nrow, ncol = ncol, byrow = byrow)
      } else {
        .plot.out <- .plist[[1]]
      }
    }
    return(.plot.out)
  } else {
    return(.plist)
  }
}
