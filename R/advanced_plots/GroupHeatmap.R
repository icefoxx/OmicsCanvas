.safe_palette <- function(x, palette = "Paired", palcolor = NULL, type = "discrete", n = 101, color.na = "grey80") {
  tryCatch(
    paletteCustomize(x = x, palette = palette, palcolor = palcolor, type = type, n = n, matched = FALSE, color.na = color.na),
    error = function(e) {
      if (identical(type, "continuous")) {
        .pal.name <- tolower(as.character(palette)[1])
        if (.pal.name %in% c("vlag", "rdbu", "rdbu_r")) {
          colorRampPalette(c("#3B4CC0", "white", "#B40426"))(n)
        } else {
          colorRampPalette(c("#2166AC", "white", "#B2182B"))(n)
        }
      } else {
        .lev <- levels(x)
        if (is.null(.lev)) .lev <- unique(as.character(x))
        stats::setNames(grDevices::hcl.colors(length(.lev), palette = "Set 2"), .lev)
      }
    }
  )
}

    .feature_group_cols_from_group <- function(split_values, group_levels, palette = "Paired", palcolor = NULL, sep = group_sep) {
  .split.levels <- unique(as.character(split_values))
  .group.levels <- as.character(group_levels)
  .group.cols <- .safe_palette(
    factor(.group.levels, levels = .group.levels),
    palette = palette,
    palcolor = palcolor,
    type = "discrete"
  )
  .match_one <- function(.label) {
        .hits <- .group.levels[
          .label == .group.levels |
            startsWith(.label, paste0(.group.levels, "_")) |
            startsWith(.label, paste0(.group.levels, sep))
        ]
    if (length(.hits) == 0) return(NA_character_)
    .hits[which.max(nchar(.hits))]
  }
  .matched <- stats::setNames(vapply(.split.levels, .match_one, character(1)), .split.levels)
  .out <- stats::setNames(rep(NA_character_, length(.split.levels)), .split.levels)
  .matched.idx <- !is.na(.matched)
  if (any(.matched.idx)) {
    .out[names(.matched)[.matched.idx]] <- unname(.group.cols[.matched[.matched.idx]])
  }
  .unmatched <- names(.matched)[!.matched.idx]
  if (length(.unmatched) > 0) {
    .fallback <- .safe_palette(
      factor(.unmatched, levels = .unmatched),
      palette = palette,
      palcolor = palcolor,
      type = "discrete"
    )
    .out[.unmatched] <- unname(.fallback)
  }
  .out
}

GroupHeatmap <- function(
    srt = NULL,
    features,
    assay = NULL,
    slot = "data",
    group.by,
    cell_annotation = NULL,
    top_annotation_labels = NULL,
    group_order = NULL,
    feature_order = NULL,
    feature_split = NULL,
    feature_annotation = NULL,
    feature_annotation_palette = NULL,
    threshold = 0,
    plot_type = c("dotplot", "heatmap", "violin", "clustered_dotplot"),
    heatmap_mode = c("group", "cell"),
    violin_mode = c("plain", "blocks"),
    violin_cluster_features = FALSE,
    style = c("merge", "seperate"),
    summary = c("mean", "zscore", "log1p"),
    group_heatmap_split_by_annotation = FALSE,
    heatmap_palette = "YlOrRd",
    heatmap_palcolor = NULL,
    cell_annotation_palette = NULL,
    cell_annotation_palcolor = NULL,
    group_palette = "Paired",
    group_palcolor = NULL,
    show_row_names = TRUE,
    row_names_fontsize = NULL,
    row_names_every_n = NULL,
    row_names_max = NULL,
    row_names_layers = 1,
    row_names_method = c("plain", "linker", "area"),
    row_name_link_col = "#666666",
    row_name_link_lwd = 0.6,
    highlight_features = NULL,
    highlight_features_side = "left",
    highlight_features_gp = NULL,
    show_top_annotation_name = TRUE,
    top_annotation_name_rot = 0,
    top_annotation_name_fontsize = NULL,
    show_feature_split_title = TRUE,
    feature_split_title_rot = 90,
    feature_split_title_fontsize = NULL,
    show_feature_group_name = TRUE,
    feature_group_side = c("left", "right"),
    feature_group_name_rot = 90,
    feature_group_name_fontsize = NULL,
    show_column_names = TRUE,
    column_names_fontsize = NULL,
    row_names_side = c("left", "right"),
    orientation = c("vertical", "horizontal", "horizontal_blocks"),
    cluster_rows = FALSE,
    cluster_columns = FALSE,
    add_dot = FALSE,
    add_reticle = FALSE,
    dot_range = c(0.5, 3.5),
    border = TRUE,
    group_sep = " | ",
    annotation_pie_scale = 0.32,
    annotation_track_scale = 0.8,
    annotation_track_gap = 0.01,
    annotation_pie_y_span = 0.28,
    annotation_pie_mode = c("round", "flush"),
    annotation_attach = TRUE,
    annotation_row_frame = FALSE,
    show_annotation_frame = TRUE,
    show_annotation_y_axis = TRUE,
    show_annotation_label = TRUE,
    annotation_label_angle = 90,
    annotation_label_size = NULL,
    annotation_label_face = "plain",
    annotation_label_family = "",
    annotation_label_margin_pt = 4,
    track_heights = c(group = 0.55, categorical = 0.9, numeric = 1.35, dot = 6),
    clustered_dotplot_row_mm = NULL,
    clustered_dotplot_col_mm = NULL,
    clustered_dotplot_max_height_mm = 220,
    clustered_dotplot_max_width_mm = 180,
    clustered_dotplot_row_fontsize = NULL,
    clustered_dotplot_column_fontsize = NULL,
    violin_alpha = 0.75,
    point_stroke = 0.5,
    left_label_angle = 0,
    position_track_label_side = c("left", "right"),
    legend_width_ratio = 0.18,
    legend_stack_spacing = 0.02,
    legend_title_size = NULL,
    legend_text_size = NULL,
    legend_key_size_pt = NULL,
    legend_scale = 1,
    return_data = FALSE,
    ...
) {
  if (is.null(srt)) stop("Input `srt` is NULL.")
  if (!requireNamespace("ComplexHeatmap", quietly = TRUE)) {
    stop("Package `ComplexHeatmap` is required.")
  }
  if (!requireNamespace("circlize", quietly = TRUE)) {
    stop("Package `circlize` is required.")
  }
  if (!requireNamespace("grid", quietly = TRUE)) {
    stop("Package `grid` is required.")
  }
  if (!requireNamespace("data.table", quietly = TRUE)) {
    stop("Package `data.table` is required.")
  }
  .input.is.df <- is.data.frame(srt) || data.table::is.data.table(srt)
  if (!.input.is.df) {
    ckSeu(srt)
  }

  .summary <- match.arg(summary)
  .plot_type <- match.arg(plot_type)
  .heatmap_mode <- match.arg(heatmap_mode)
  .violin_mode <- match.arg(violin_mode)
  .style <- match.arg(style)
  group_heatmap_split_by_annotation <- isTRUE(group_heatmap_split_by_annotation)
    row_names_fontsize <- suppressWarnings(as.numeric(row_names_fontsize)[1])
    if (is.na(row_names_fontsize) || row_names_fontsize <= 0) row_names_fontsize <- NULL
    row_names_every_n <- suppressWarnings(as.integer(row_names_every_n)[1])
    if (is.na(row_names_every_n) || row_names_every_n <= 1) row_names_every_n <- NULL
    row_names_max <- suppressWarnings(as.integer(row_names_max)[1])
    if (is.na(row_names_max) || row_names_max <= 0) row_names_max <- NULL
    row_names_layers <- suppressWarnings(as.integer(row_names_layers)[1])
    if (is.na(row_names_layers) || row_names_layers <= 0) row_names_layers <- 1
    row_names_method <- match.arg(row_names_method)
    row_name_link_col <- as.character(row_name_link_col)[1]
    if (is.na(row_name_link_col) || !nzchar(row_name_link_col)) row_name_link_col <- "#666666"
    row_name_link_lwd <- suppressWarnings(as.numeric(row_name_link_lwd)[1])
    if (is.na(row_name_link_lwd) || row_name_link_lwd <= 0) row_name_link_lwd <- 0.6
    show_top_annotation_name <- isTRUE(show_top_annotation_name)
    top_annotation_name_rot <- suppressWarnings(as.numeric(top_annotation_name_rot)[1])
    if (is.na(top_annotation_name_rot)) top_annotation_name_rot <- 0
    if (is.null(top_annotation_name_fontsize)) top_annotation_name_fontsize <- 10
    top_annotation_name_fontsize <- suppressWarnings(as.numeric(top_annotation_name_fontsize)[1])
    if (is.na(top_annotation_name_fontsize) || top_annotation_name_fontsize <= 0) top_annotation_name_fontsize <- 10
    show_feature_split_title <- isTRUE(show_feature_split_title)
    feature_split_title_rot <- suppressWarnings(as.numeric(feature_split_title_rot)[1])
    if (is.na(feature_split_title_rot)) feature_split_title_rot <- 90
    if (is.null(feature_split_title_fontsize)) feature_split_title_fontsize <- 10
    feature_split_title_fontsize <- suppressWarnings(as.numeric(feature_split_title_fontsize)[1])
    if (is.na(feature_split_title_fontsize) || feature_split_title_fontsize <= 0) feature_split_title_fontsize <- 10
    show_feature_group_name <- isTRUE(show_feature_group_name)
    feature_group_side <- match.arg(feature_group_side)
    feature_group_name_rot <- suppressWarnings(as.numeric(feature_group_name_rot)[1])
    if (is.na(feature_group_name_rot)) feature_group_name_rot <- 90
    if (is.null(feature_group_name_fontsize)) feature_group_name_fontsize <- 10
    feature_group_name_fontsize <- suppressWarnings(as.numeric(feature_group_name_fontsize)[1])
    if (is.na(feature_group_name_fontsize) || feature_group_name_fontsize <= 0) feature_group_name_fontsize <- 10
    column_names_fontsize <- suppressWarnings(as.numeric(column_names_fontsize)[1])
    if (is.na(column_names_fontsize) || column_names_fontsize <= 0) column_names_fontsize <- NULL
    row_names_side <- match.arg(row_names_side)
    .orientation <- match.arg(orientation)
    position_track_label_side <- match.arg(position_track_label_side)
    legend_width_ratio <- as.numeric(legend_width_ratio)[1]
    if (is.na(legend_width_ratio) || legend_width_ratio <= 0 || legend_width_ratio >= 1) {
      legend_width_ratio <- 0.18
    }
    legend_stack_spacing <- as.numeric(legend_stack_spacing)[1]
    if (is.na(legend_stack_spacing) || legend_stack_spacing < 0) {
      legend_stack_spacing <- 0.02
    }
    legend_scale <- as.numeric(legend_scale)[1]
    if (is.na(legend_scale) || legend_scale <= 0) legend_scale <- 1
    if (is.null(legend_title_size)) legend_title_size <- 12 * legend_scale
    legend_title_size <- as.numeric(legend_title_size)[1]
    if (is.na(legend_title_size) || legend_title_size <= 0) legend_title_size <- 12 * legend_scale
    if (is.null(legend_text_size)) legend_text_size <- 11 * legend_scale
    legend_text_size <- as.numeric(legend_text_size)[1]
    if (is.na(legend_text_size) || legend_text_size <= 0) legend_text_size <- 11 * legend_scale
    if (is.null(legend_key_size_pt)) legend_key_size_pt <- 10 * legend_scale
    legend_key_size_pt <- as.numeric(legend_key_size_pt)[1]
    if (is.na(legend_key_size_pt) || legend_key_size_pt <= 0) legend_key_size_pt <- 10 * legend_scale
  .horizontal_blocks_mode <- identical(.orientation, "horizontal_blocks")
  if (.horizontal_blocks_mode) {
    .orientation <- "horizontal"
  }
  .orientation.base <- .orientation
  .group.expand <- ggplot2::expansion(add = c(0.5, 0.5))
  annotation_track_scale <- as.numeric(annotation_track_scale)[1]
  if (is.na(annotation_track_scale) || annotation_track_scale <= 0) annotation_track_scale <- 0.8
  annotation_track_gap <- as.numeric(annotation_track_gap)[1]
  if (is.na(annotation_track_gap) || annotation_track_gap < 0) annotation_track_gap <- 0.01
  annotation_pie_y_span <- as.numeric(annotation_pie_y_span)[1]
  if (is.na(annotation_pie_y_span) || annotation_pie_y_span <= 0) annotation_pie_y_span <- 0.28
    annotation_pie_mode <- match.arg(annotation_pie_mode)
    annotation_attach <- isTRUE(annotation_attach)
    annotation_row_frame <- isTRUE(annotation_row_frame)
    show_annotation_frame <- isTRUE(show_annotation_frame)
    show_annotation_label <- isTRUE(show_annotation_label)
    annotation_label_angle <- as.numeric(annotation_label_angle)[1]
    if (is.na(annotation_label_angle)) annotation_label_angle <- 90
    if (is.null(annotation_label_size)) annotation_label_size <- 13 * legend_scale
    annotation_label_size <- as.numeric(annotation_label_size)[1]
    if (is.na(annotation_label_size) || annotation_label_size <= 0) annotation_label_size <- 13 * legend_scale
    annotation_label_face <- as.character(annotation_label_face)[1]
    if (is.na(annotation_label_face) || !nzchar(annotation_label_face)) annotation_label_face <- "plain"
    annotation_label_family <- as.character(annotation_label_family)[1]
    if (is.na(annotation_label_family)) annotation_label_family <- ""
    annotation_label_margin_pt <- as.numeric(annotation_label_margin_pt)[1]
    if (is.na(annotation_label_margin_pt) || annotation_label_margin_pt < 0) annotation_label_margin_pt <- 4
  .pie.y.limits <- function(scale.use, base.span = annotation_pie_y_span) {
    .span <- max(base.span, 0.5 * scale.use)
    c(1 - .span, 1 + .span)
  }
  .annotation.margin <- if (annotation_attach) grid::unit(c(-2, 0, -2, 0), "pt") else grid::unit(c(0, 0, 0, 0), "pt")
  .assay <- if (.input.is.df) assay %||% "data.frame" else assay %||% Seurat::DefaultAssay(srt)

  .feature.split <- feature_split
  .features <- features
  if (is.list(.features) && !is.null(names(.features)) && "genelist" %in% names(.features)) {
    .features <- .features[["genelist"]]
  }
  if (is.list(.features)) {
    .feature.grp <- names(.features)
    if (is.null(.feature.grp)) {
      .feature.grp <- paste0("FeatureSet", seq_along(.features))
    }
    .feature.split <- rep(.feature.grp, lengths(.features))
    .features <- unlist(.features, use.names = FALSE)
  }
  if (!is.null(.feature.split)) {
    if (length(.feature.split) != length(.features)) {
      stop("`feature_split` must have the same length as `features`.")
    }
    .feature.keep <- !duplicated(.features)
    .feature.split <- .feature.split[.feature.keep]
    .features <- .features[.feature.keep]
  } else {
    .features <- unique(.features)
  }
  .meta.cols <- unique(c(group.by, cell_annotation))
  if (.input.is.df) {
    .plot.df <- data.table::as.data.table(as.data.frame(srt, stringsAsFactors = FALSE))
    ckCols(.plot.df, cols = unique(c(.features, .meta.cols)))
  } else {
    ckCols(srt@meta.data, cols = .meta.cols)

    .assay.features <- rownames(srt[[.assay]])
    .features.missing <- setdiff(.features, .assay.features)
    if (length(.features.missing) > 0) {
      stop(stringr::str_glue(
        "Input features are not present in assay `{.assay}`: {paste(.features.missing, collapse = ', ')}"
      ))
    }

    if (identical(slot, "scale.data")) {
      .scale.data <- Seurat::GetAssayData(srt, assay = .assay, slot = "scale.data")
      if (nrow(.scale.data) == 0 || ncol(.scale.data) == 0) {
        warning("Layer `scale.data` is empty in this assay. Falling back to `data`.", immediate. = TRUE)
        slot <- "data"
      }
    }

    .plot.df <- fetchFeasMeta(
      seu = srt,
      features = c(.features, .meta.cols),
      assay = .assay,
      slot = slot,
      ident.return = FALSE
    )
    data.table::setDT(.plot.df)
  }

  if ("cell.barcodes.selected" %in% colnames(.plot.df)) {
    .plot.df[, cell.barcodes.selected := NULL]
  }

  .group.by <- unique(group.by)

  if (identical(.plot_type, "heatmap")) {
    .resolve_order <- function(var, data) {
      .ord <- NULL
      if (is.list(group_order)) {
        .ord <- group_order[[var]]
      } else if (!is.null(group_order) && length(.group.by) == 1) {
        .ord <- group_order
      }
      .lev <- unique(data[[var]])
      if (is.factor(data[[var]])) .lev <- levels(data[[var]])
      if (!is.null(.ord)) .lev <- unique(c(intersect(.ord, .lev), setdiff(.lev, .ord)))
      .lev
    }

    .feature.levels <- unique(.features)
    if (!is.null(feature_order)) {
      .feature.levels <- unique(c(intersect(feature_order, .features), setdiff(.features, feature_order)))
    }
    if (.input.is.df) {
      .heat.df <- data.table::copy(.plot.df)
      if (!"cell.barcodes.selected" %in% colnames(.heat.df)) {
        .heat.df[, cell.barcodes.selected := paste0("cell_", seq_len(.N))]
      }
    } else {
      .heat.df <- fetchFeasMeta(
        seu = srt,
        features = c(.features, .meta.cols),
        assay = .assay,
        slot = slot,
        ident.return = FALSE
      )
      data.table::setDT(.heat.df)
      if (!"cell.barcodes.selected" %in% colnames(.heat.df)) {
        .heat.df[, cell.barcodes.selected := colnames(srt)]
      }
    }
    for (.g in .group.by) {
      .lev <- .resolve_order(.g, .heat.df)
      .heat.df[[.g]] <- factor(.heat.df[[.g]], levels = .lev)
    }
    .heat.df[, group_id := do.call(paste, c(.SD, sep = group_sep)), .SDcols = .group.by]

    if (identical(.heatmap_mode, "cell")) {
      .heat.df <- .heat.df[do.call(order, .heat.df[, .group.by, with = FALSE])]
      .mat <- t(as.matrix(.heat.df[, .features, with = FALSE]))
      rownames(.mat) <- .features
      colnames(.mat) <- .heat.df$cell.barcodes.selected
      .anno.df <- as.data.frame(.heat.df[, unique(c(.group.by, cell_annotation)), with = FALSE])
      rownames(.anno.df) <- .heat.df$cell.barcodes.selected
      .col.split <- .heat.df[[.group.by[1]]]
    } else {
      .split.anno <- character(0)
      if (group_heatmap_split_by_annotation && !is.null(cell_annotation)) {
        .split.anno <- vapply(cell_annotation, function(.nm) {
          !is.numeric(.heat.df[[.nm]])
        }, logical(1))
        .split.anno <- cell_annotation[.split.anno]
      }
      .agg.by <- unique(c(.group.by, .split.anno))

      .group.meta <- unique(.heat.df[, .agg.by, with = FALSE])
      .group.meta[, group_id := do.call(paste, c(.SD, sep = group_sep)), .SDcols = .group.by]
      .group.meta[, column_id := do.call(paste, c(.SD, sep = group_sep)), .SDcols = .agg.by]
      .group.meta <- .group.meta[do.call(order, .group.meta[, .agg.by, with = FALSE])]
      .column.levels <- .group.meta$column_id

      .mean.dt <- .heat.df[, lapply(.SD, mean, na.rm = TRUE), by = .agg.by, .SDcols = .features]
      .mean.dt[, group_id := do.call(paste, c(.SD, sep = group_sep)), .SDcols = .group.by]
      .mean.dt[, column_id := do.call(paste, c(.SD, sep = group_sep)), .SDcols = .agg.by]
      .mean.dt <- .mean.dt[match(.column.levels, .mean.dt$column_id)]
      .mat <- t(as.matrix(.mean.dt[, .features, with = FALSE]))
      rownames(.mat) <- .features
      colnames(.mat) <- .mean.dt$column_id

      .anno.df <- as.data.frame(.group.meta[, .agg.by, with = FALSE])
      rownames(.anno.df) <- .group.meta$column_id
      if (!is.null(cell_annotation)) {
        .anno.extra <- setdiff(cell_annotation, .split.anno)
        if (length(.anno.extra) > 0) {
          .anno.sum <- .heat.df[, lapply(.SD, function(x) {
            if (is.numeric(x)) mean(x, na.rm = TRUE) else names(sort(table(x), decreasing = TRUE))[1]
          }), by = .agg.by, .SDcols = .anno.extra]
          .anno.sum[, column_id := do.call(paste, c(.SD, sep = group_sep)), .SDcols = .agg.by]
          .anno.sum <- as.data.frame(.anno.sum[, c("column_id", .anno.extra), with = FALSE])
          rownames(.anno.sum) <- .anno.sum$column_id
          .anno.sum$column_id <- NULL
          .anno.df <- cbind(.anno.df, .anno.sum[rownames(.anno.df), , drop = FALSE])
        }
      }
      .col.split <- .group.meta[[.group.by[1]]]
    }

    .mat <- .mat[.feature.levels, , drop = FALSE]
    .mat.plot <- switch(
      .summary,
      mean = .mat,
      log1p = log1p(.mat),
      zscore = t(scale(t(.mat)))
    )
    .mat.plot[is.na(.mat.plot)] <- 0

    .heat.cols <- .safe_palette(seq(-2, 2, length.out = 101), palette = heatmap_palette, palcolor = heatmap_palcolor, type = "continuous")
    .value.range <- range(.mat.plot, na.rm = TRUE)
    if (identical(.summary, "zscore")) {
      .value.range <- c(max(-2, .value.range[1]), min(2, .value.range[2]))
    }
    if (diff(.value.range) == 0) .value.range <- c(.value.range[1] - 1, .value.range[2] + 1)
    .col.fun <- circlize::colorRamp2(seq(.value.range[1], .value.range[2], length.out = length(.heat.cols)), .heat.cols)

    .anno.names <- colnames(.anno.df)
    if (!is.null(top_annotation_labels)) {
      .anno.labels <- top_annotation_labels
      if (is.null(names(.anno.labels))) {
        if (length(.anno.labels) == length(.anno.names)) {
          names(.anno.labels) <- .anno.names
        } else {
          .anno.labels <- stats::setNames(as.character(.anno.labels), .anno.names[seq_along(.anno.labels)])
        }
      }
      .rename.idx <- intersect(.anno.names, names(.anno.labels))
      if (length(.rename.idx) > 0) {
        colnames(.anno.df)[match(.rename.idx, colnames(.anno.df))] <- unname(.anno.labels[.rename.idx])
        .anno.names <- colnames(.anno.df)
      }
    }
    .anno.cols <- list()
    for (i in seq_along(.anno.names)) {
      .nm <- .anno.names[i]
      .x <- .anno.df[[.nm]]
      if (is.numeric(.x)) {
        .xr <- range(.x, na.rm = TRUE)
        if (diff(.xr) == 0) .xr <- c(.xr[1] - 1, .xr[2] + 1)
        .anno.cols[[.nm]] <- circlize::colorRamp2(
          seq(.xr[1], .xr[2], length.out = 101),
          .safe_palette(.x, palette = ifelse(length(cell_annotation_palette) >= i, cell_annotation_palette[[i]], "Paired"), palcolor = cell_annotation_palcolor, type = "continuous")
        )
      } else {
        .x <- factor(.x, levels = unique(as.character(.x)))
        .anno.cols[[.nm]] <- .safe_palette(
          .x,
          palette = ifelse(length(cell_annotation_palette) >= i, cell_annotation_palette[[i]], "Paired"),
          palcolor = cell_annotation_palcolor,
          type = "discrete"
        )
      }
    }

    .top.anno <- ComplexHeatmap::HeatmapAnnotation(
      df = .anno.df,
      col = .anno.cols,
      which = "column",
      border = TRUE,
      show_annotation_name = show_top_annotation_name,
      annotation_name_side = "left",
      annotation_name_rot = top_annotation_name_rot,
      annotation_name_gp = grid::gpar(fontsize = top_annotation_name_fontsize)
    )

    .row.split <- NULL
    .left.anno <- NULL
    .right.anno <- NULL
    .left.anno.args <- list()
    .right.anno.args <- list()
    if (!is.null(.feature.split)) {
      if (length(.feature.split) != length(.features)) stop("`feature_split` must have the same length as `features`.")
      names(.feature.split) <- .features
      .row.split <- .feature.split[rownames(.mat.plot)]
      .group.levels.primary <- .resolve_order(.group.by[1], .heat.df)
      .group.palette.primary <- if (is.list(group_palette)) group_palette[[1]] else group_palette[[1]]
      .group.palcolor.primary <- if (is.list(group_palcolor)) group_palcolor[[1]] else group_palcolor
      .feature.group.args <- list(
        feature_group = .row.split,
        col = list(
        feature_group = .feature_group_cols_from_group(
          split_values = .row.split,
          group_levels = .group.levels.primary,
          palette = .group.palette.primary,
          palcolor = .group.palcolor.primary,
          sep = group_sep
        )
        )
      )
      if (identical(feature_group_side, "right")) {
        .right.anno.args <- c(.right.anno.args, .feature.group.args)
      } else {
        .left.anno.args <- c(.left.anno.args, .feature.group.args)
      }
    }
    if (!is.null(highlight_features)) {
      .highlight.features <- intersect(highlight_features, rownames(.mat.plot))
      if (length(.highlight.features) > 0) {
        .mark.at <- match(.highlight.features, rownames(.mat.plot))
        .left.anno.args[["highlight"]] <- ComplexHeatmap::anno_mark(
          at = .mark.at,
          labels = .highlight.features,
          which = "row",
          side = highlight_features_side,
          labels_gp = highlight_features_gp %||% grid::gpar(fontsize = 10)
        )
        show_row_names <- FALSE
      }
    }
    .row.names.gp <- if (is.null(row_names_fontsize)) grid::gpar() else grid::gpar(fontsize = row_names_fontsize)
    .row.split.title <- if (is.null(.row.split) || isTRUE(show_feature_split_title)) {
      NULL
    } else {
      rep("", length(unique(as.character(.row.split))))
    }
    .row.split.title.gp <- grid::gpar(fontsize = feature_split_title_fontsize)

    .row.labels <- rownames(.mat.plot)
    if (isTRUE(show_row_names) && length(.row.labels) > 0) {
      .row.keep.idx <- seq_along(.row.labels)
      if (!is.null(row_names_every_n)) {
        .row.keep.idx <- seq(1, length(.row.labels), by = row_names_every_n)
      } else {
        .effective.row.names.max <- row_names_max
        if (!is.null(.effective.row.names.max) &&
            length(.row.labels) > .effective.row.names.max) {
          .row.step <- ceiling(length(.row.labels) / .effective.row.names.max)
          .row.keep.idx <- seq(1, length(.row.labels), by = .row.step)
        }
      }
      if (length(.row.keep.idx) < length(.row.labels)) {
        .row.labels[-.row.keep.idx] <- ""
      }
    }

    if (isTRUE(show_row_names) &&
        identical(row_names_method, "area") &&
        !is.null(.row.split) &&
        length(.row.labels) > 0) {
      .row.split.chr <- as.character(.row.split)
      .row.split.rle <- rle(.row.split.chr)
      .row.ends <- cumsum(.row.split.rle$lengths)
      .row.starts <- .row.ends - .row.split.rle$lengths + 1
      .row.group.text <- vapply(seq_along(.row.starts), function(.i) {
        .idx <- .row.starts[.i]:.row.ends[.i]
        .grp <- .row.split.rle$values[.i]
        .genes <- rownames(.mat.plot)[.idx]
        .txt <- paste0(.grp, ": ", paste(.genes, collapse = " "))
        paste(strwrap(.txt, width = 32), collapse = "\n")
      }, character(1))
      .area.df <- data.frame(
        start = .row.starts,
        end = .row.ends,
        label = .row.group.text,
        stringsAsFactors = FALSE
      )
      .row.label.area.anno <- ComplexHeatmap::AnnotationFunction(
        which = "row",
        n = nrow(.mat.plot),
        width = grid::unit(55, "mm"),
        show_name = FALSE,
        var_import = list(
          .area.df = .area.df,
          .row.names.side = row_names_side,
          .row.names.gp = .row.names.gp,
          .row.name.link.col = row_name_link_col,
          .row.name.link.lwd = row_name_link_lwd
        ),
        fun = function(index) {
          if (length(index) == 0) return(invisible(NULL))
          .y.map <- stats::setNames(1 - ((seq_along(index) - 0.5) / length(index)), index)
          .box.fill <- "#E6E6E6"
          .box.col <- "#B0B0B0"
          .areas <- .area.df[.area.df$start %in% index | .area.df$end %in% index, , drop = FALSE]
          if (nrow(.areas) == 0) return(invisible(NULL))
          for (.i in seq_len(nrow(.areas))) {
            .s <- .areas$start[.i]
            .e <- .areas$end[.i]
            .visible.idx <- index[index >= .s & index <= .e]
            if (length(.visible.idx) == 0) next
            .y0 <- min(.y.map[as.character(.visible.idx)])
            .y1 <- max(.y.map[as.character(.visible.idx)])
            .ym <- mean(c(.y0, .y1))
            if (.row.names.side == "right") {
              grid::grid.lines(
                x = grid::unit(c(0.02, 0.12, 1), "npc"),
                y = grid::unit(c(.ym, .ym, .ym), "npc"),
                gp = grid::gpar(col = .row.name.link.col, lwd = .row.name.link.lwd)
              )
              grid::grid.rect(
                x = grid::unit(0.52, "npc"),
                y = grid::unit(.ym, "npc"),
                width = grid::unit(0.76, "npc"),
                height = grid::unit(max(0.06, .y1 - .y0), "npc"),
                gp = grid::gpar(fill = .box.fill, col = .box.col)
              )
              grid::grid.text(
                .areas$label[.i],
                x = grid::unit(0.16, "npc"),
                y = grid::unit(.ym, "npc"),
                just = "left",
                gp = .row.names.gp
              )
            } else {
              grid::grid.lines(
                x = grid::unit(c(0, 0.88, 0.98), "npc"),
                y = grid::unit(c(.ym, .ym, .ym), "npc"),
                gp = grid::gpar(col = .row.name.link.col, lwd = .row.name.link.lwd)
              )
              grid::grid.rect(
                x = grid::unit(0.48, "npc"),
                y = grid::unit(.ym, "npc"),
                width = grid::unit(0.76, "npc"),
                height = grid::unit(max(0.06, .y1 - .y0), "npc"),
                gp = grid::gpar(fill = .box.fill, col = .box.col)
              )
              grid::grid.text(
                .areas$label[.i],
                x = grid::unit(0.84, "npc"),
                y = grid::unit(.ym, "npc"),
                just = "right",
                gp = .row.names.gp
              )
            }
          }
        }
      )
      if (identical(row_names_side, "right")) {
        .right.anno.args[["row_label_area"]] <- .row.label.area.anno
      } else {
        .left.anno.args[["row_label_area"]] <- .row.label.area.anno
      }
      show_row_names <- FALSE
    } else if (isTRUE(show_row_names) && identical(row_names_method, "linker") && row_names_layers > 1 && length(.row.labels) > 0) {
      .row.label.idx <- which(nzchar(.row.labels))
      if (length(.row.label.idx) > 0) {
        .row.label.layers <- ((seq_along(.row.label.idx) - 1L) %% row_names_layers) + 1L
        .row.label.map <- data.frame(
          idx = .row.label.idx,
          label = .row.labels[.row.label.idx],
          layer = .row.label.layers,
          stringsAsFactors = FALSE
        )
        .layer.width.mm <- max(10, 12 * row_names_layers)
        .row.label.layer.anno <- ComplexHeatmap::AnnotationFunction(
          which = "row",
          n = nrow(.mat.plot),
          width = grid::unit(.layer.width.mm, "mm"),
          show_name = FALSE,
          var_import = list(
            .row.label.map = .row.label.map,
            .row.names.gp = .row.names.gp,
            .row.names.side = row_names_side,
            .row.name.link.col = row_name_link_col,
            .row.name.link.lwd = row_name_link_lwd,
            .row.names.layers = row_names_layers
          ),
          fun = function(index) {
            if (length(index) == 0) return(invisible(NULL))
            .map <- .row.label.map[.row.label.map$idx %in% index, , drop = FALSE]
            if (nrow(.map) == 0) return(invisible(NULL))
            .ord <- match(.map$idx, index)
            .y <- 1 - ((.ord - 0.5) / length(index))
            if (.row.names.side == "right") {
              .x.text <- seq(0.85, 0.15, length.out = .row.names.layers)
              .x.anchor <- 0
              .text.just <- "left"
              .x.seg.start <- .x.text[.map$layer] - 0.015
              .x.seg.end <- rep(.x.anchor, nrow(.map))
            } else {
              .x.text <- seq(0.15, 0.85, length.out = .row.names.layers)
              .x.anchor <- 1
              .text.just <- "right"
              .x.seg.start <- .x.text[.map$layer] + 0.015
              .x.seg.end <- rep(.x.anchor, nrow(.map))
            }
            grid::grid.segments(
              x0 = grid::unit(.x.seg.start, "npc"),
              y0 = grid::unit(.y, "npc"),
              x1 = grid::unit(.x.seg.end, "npc"),
              y1 = grid::unit(.y, "npc"),
              gp = grid::gpar(col = .row.name.link.col, lwd = .row.name.link.lwd)
            )
            grid::grid.text(
              label = .map$label,
              x = grid::unit(.x.text[.map$layer], "npc"),
              y = grid::unit(.y, "npc"),
              just = .text.just,
              gp = .row.names.gp
            )
          }
        )
        if (identical(row_names_side, "right")) {
          .right.anno.args[["row_label_layers"]] <- .row.label.layer.anno
        } else {
          .left.anno.args[["row_label_layers"]] <- .row.label.layer.anno
        }
        show_row_names <- FALSE
      }
    }

    if ("feature_group" %in% names(.left.anno.args)) {
      .left.anno.args[["show_annotation_name"]] <- show_feature_group_name
      .left.anno.args[["annotation_name_rot"]] <- feature_group_name_rot
      .left.anno.args[["annotation_name_gp"]] <- grid::gpar(fontsize = feature_group_name_fontsize)
    }
    if (length(.left.anno.args) > 0) {
      .left.anno <- do.call(ComplexHeatmap::rowAnnotation, .left.anno.args)
    }
    if ("feature_group" %in% names(.right.anno.args)) {
      .right.anno.args[["show_annotation_name"]] <- show_feature_group_name
      .right.anno.args[["annotation_name_rot"]] <- feature_group_name_rot
      .right.anno.args[["annotation_name_gp"]] <- grid::gpar(fontsize = feature_group_name_fontsize)
    }
    if (length(.right.anno.args) > 0) {
      .right.anno <- do.call(ComplexHeatmap::rowAnnotation, .right.anno.args)
    }

    .ht <- ComplexHeatmap::Heatmap(
      matrix = .mat.plot,
      name = switch(.summary, mean = "Expression", log1p = "log1p(expression)", zscore = "zscore(normalized counts)"),
      col = .col.fun,
      top_annotation = .top.anno,
      left_annotation = .left.anno,
      right_annotation = .right.anno,
      row_split = .row.split,
      row_title = .row.split.title,
      row_title_rot = feature_split_title_rot,
      row_title_gp = .row.split.title.gp,
      column_split = .col.split,
      cluster_rows = cluster_rows,
      cluster_columns = cluster_columns,
      show_row_names = show_row_names,
      row_labels = .row.labels,
      show_column_names = FALSE,
      row_names_gp = .row.names.gp,
      row_names_side = row_names_side,
      border = border,
      rect_gp = grid::gpar(col = if (isTRUE(border)) "grey85" else NA)
    )

    if (isTRUE(return_data)) {
      return(list(heatmap = .ht, matrix = .mat.plot, column_meta = .anno.df, row_split = .row.split, column_split = .col.split))
    }
    return(.ht)
  }

  if (identical(.plot_type, "violin")) {
    if (!requireNamespace("ggplot2", quietly = TRUE)) stop("Package `ggplot2` is required for `plot_type = 'violin'`.")
    if (!requireNamespace("patchwork", quietly = TRUE)) stop("Package `patchwork` is required for `plot_type = 'violin'`.")

    .group.var <- if (length(.group.by) == 1) .group.by else "group_id"
    if (!identical(.group.var, "group_id")) {
      .plot.df$group_id <- .plot.df[[.group.var]]
    } else {
      .plot.df$group_id <- do.call(paste, c(as.data.frame(.plot.df[, .group.by, with = FALSE]), sep = group_sep))
    }
    .group.levels <- unique(.plot.df$group_id)
    if (!is.null(group_order) && !is.list(group_order)) {
      .group.levels <- unique(c(intersect(group_order, .group.levels), setdiff(.group.levels, group_order)))
    }
    .plot.df$group_id <- factor(.plot.df$group_id, levels = .group.levels)

    .feature.levels <- unique(.features)
    if (!is.null(feature_order)) {
      .feature.levels <- unique(c(intersect(feature_order, .features), setdiff(.features, feature_order)))
    }
    .feature.group.levels <- if (is.null(.feature.split)) {
      "Features"
    } else {
      unique(.feature.split)
    }
    .feature.group <- if (is.null(.feature.split)) {
      stats::setNames(rep("Features", length(.feature.levels)), .feature.levels)
    } else {
      .tmp <- .feature.split[match(.feature.levels, .features)]
      names(.tmp) <- .feature.levels
      .tmp
    }
    .avg.exp <- .plot.df[, lapply(.SD, mean, na.rm = TRUE), by = "group_id", .SDcols = .feature.levels]
    .feature.by.group <- t(as.matrix(.avg.exp[, .feature.levels, with = FALSE]))
    .feature.hclust <- stats::setNames(vector("list", length(.feature.group.levels)), .feature.group.levels)
    if (isTRUE(violin_cluster_features) && length(.feature.levels) > 1) {
      .feature.levels <- unlist(lapply(.feature.group.levels, function(.grp) {
        feas <- .feature.levels[.feature.group[.feature.levels] == .grp]
        if (length(feas) <= 2) return(feas)
        .hc <- stats::hclust(stats::dist(.feature.by.group[feas, , drop = FALSE]))
        .feature.hclust[[.grp]] <<- .hc
        feas[.hc$order]
      }), use.names = FALSE)
    }
    for (.grp in .feature.group.levels) {
      if (!is.null(.feature.hclust[[.grp]])) next
      .feas <- .feature.levels[.feature.group[.feature.levels] == .grp]
      if (length(.feas) >= 2) {
        .feature.hclust[[.grp]] <- stats::hclust(stats::dist(.feature.by.group[.feas, , drop = FALSE]))
      }
    }

    .plot.long <- data.table::melt(
      .plot.df,
      id.vars = unique(c(.group.by, "group_id", cell_annotation)),
      measure.vars = .features,
      variable.name = "feature",
      value.name = "value"
    )
    .plot.long$feature <- factor(.plot.long$feature, levels = .feature.levels)
    .plot.long$feature_group <- factor(.feature.group[as.character(.plot.long$feature)], levels = .feature.group.levels)

    .group.cols <- tryCatch(
      paletteCustomize(factor(.group.levels, levels = .group.levels), palette = group_palette, palcolor = group_palcolor, type = "discrete"),
      error = function(e) stats::setNames(grDevices::hcl.colors(length(.group.levels), palette = "Set 2"), .group.levels)
    )
    if (identical(.violin_mode, "plain")) {
      .p <- ggplot2::ggplot(.plot.long, ggplot2::aes(x = 1, y = .data$value, fill = .data$group_id)) +
        ggplot2::geom_violin(scale = "width", trim = TRUE, linewidth = 0.5, color = "grey20", alpha = violin_alpha) +
        ggplot2::geom_boxplot(width = 0.14, outlier.shape = NA, fill = "white", color = "black", linewidth = 0.35) +
        ggplot2::facet_grid(rows = ggplot2::vars(.data$group_id), cols = ggplot2::vars(.data$feature), scales = "free_y", switch = "y") +
        ggplot2::scale_fill_manual(values = .group.cols, guide = "none") +
        ggplot2::labs(x = NULL, y = "Expression level") +
        themeDefault() +
        ggplot2::theme(
          axis.text.x = ggplot2::element_blank(),
          axis.ticks.x = ggplot2::element_blank(),
          strip.background = ggplot2::element_rect(fill = "white", colour = "black", linewidth = 0.8),
          strip.text.x = ggplot2::element_text(face = "plain"),
          strip.text.y.left = ggplot2::element_text(angle = 0),
          panel.grid.major.x = ggplot2::element_blank(),
          panel.grid.minor = ggplot2::element_blank(),
          panel.border = ggplot2::element_rect(fill = NA, colour = "black", linewidth = 0.8)
        )
      return(.p)
    }

    .feature.levels.blocks <- rev(.feature.levels)
    .plot.long$feature <- factor(as.character(.plot.long$feature), levels = .feature.levels.blocks)

    .top.df <- data.frame(group_id = factor(.group.levels, levels = .group.levels), y = 1)
    .top.bar <- ggplot2::ggplot(.top.df, ggplot2::aes(x = .data$group_id, y = .data$y, fill = .data$group_id)) +
      ggplot2::geom_tile(color = "black", linewidth = 0.8) +
      ggplot2::scale_fill_manual(values = .group.cols, name = .group.var) +
      ggplot2::labs(x = NULL, y = ifelse(length(.group.by) == 1, .group.by, "Group"), title = ifelse(length(.group.by) == 1, .group.by, "Group")) +
      themeDefault() +
      ggplot2::theme(
        plot.title = ggplot2::element_text(hjust = 0.5, face = "plain"),
        axis.text = ggplot2::element_blank(),
        axis.ticks = ggplot2::element_blank(),
        panel.grid = ggplot2::element_blank(),
        panel.border = ggplot2::element_rect(fill = NA, colour = "black", linewidth = 0.8),
        legend.position = "none",
        plot.margin = grid::unit(c(3, 6, 2, 2), "pt")
      )

    .main <- ggplot2::ggplot(.plot.long, ggplot2::aes(x = 1, y = .data$value, fill = .data$group_id)) +
      ggplot2::geom_violin(scale = "width", trim = TRUE, linewidth = 0.45, color = "grey20", alpha = violin_alpha) +
      ggplot2::geom_boxplot(width = 0.1, outlier.shape = NA, fill = "white", color = "black", linewidth = 0.3) +
      ggplot2::facet_grid(rows = ggplot2::vars(.data$feature), cols = ggplot2::vars(.data$group_id), scales = "free_y", switch = "y") +
      ggplot2::scale_fill_manual(values = .group.cols, guide = "none") +
      ggplot2::scale_x_continuous(breaks = NULL, expand = ggplot2::expansion(mult = c(0.28, 0.28))) +
      ggplot2::labs(x = NULL, y = NULL) +
      themeDefault() +
      ggplot2::theme(
        axis.text.x = ggplot2::element_blank(),
        axis.ticks.x = ggplot2::element_blank(),
        axis.text.y = ggplot2::element_blank(),
        axis.ticks.y = ggplot2::element_blank(),
        strip.background = ggplot2::element_rect(fill = "white", colour = "black", linewidth = 0.8),
        strip.text.x = ggplot2::element_blank(),
        strip.text.y.left = ggplot2::element_text(angle = 0),
        panel.grid.major.x = ggplot2::element_blank(),
        panel.grid.minor = ggplot2::element_blank(),
        panel.border = ggplot2::element_rect(fill = NA, colour = "black", linewidth = 0.8),
        plot.margin = grid::unit(c(0, 6, 4, 0), "pt")
      )

    .build_dendro_segments <- function(hc, y_map, x_left = 0.12, x_right = 0.34) {
      if (is.null(hc) || length(hc$order) < 2) return(NULL)
      .dend <- stats::as.dendrogram(hc)
      .max.height <- max(hc$height, na.rm = TRUE)
      if (!is.finite(.max.height) || .max.height <= 0) .max.height <- 1
      .segments <- list()
      .walk <- function(node) {
        if (is.leaf(node)) {
          .lab <- as.character(attr(node, "label"))
          return(list(y = unname(y_map[.lab]), x = x_right))
        }
        .kids <- lapply(node, .walk)
        .ys <- vapply(.kids, function(z) z$y, numeric(1))
        .xs <- vapply(.kids, function(z) z$x, numeric(1))
        .x <- x_left + (attr(node, "height") / .max.height) * (x_right - x_left)
        .segments[[length(.segments) + 1]] <<- data.frame(x = .x, xend = .x, y = min(.ys), yend = max(.ys))
        for (.k in seq_along(.kids)) {
          .segments[[length(.segments) + 1]] <<- data.frame(x = .x, xend = .xs[.k], y = .ys[.k], yend = .ys[.k])
        }
        list(y = mean(range(.ys)), x = .x)
      }
      .walk(.dend)
      do.call(rbind, .segments)
    }

    .side.df <- data.frame(
      feature = .feature.levels.blocks,
      y = seq_along(.feature.levels.blocks),
      feature_group = factor(.feature.group[.feature.levels.blocks], levels = .feature.group.levels),
      x = 1
    )
    .side.runs <- rle(as.character(.side.df$feature_group))
    .side.ends <- cumsum(.side.runs$lengths)
    .side.starts <- .side.ends - .side.runs$lengths + 1
    .side.centers <- (.side.starts + .side.ends) / 2
    .side.labels <- data.frame(
      feature_group = .side.runs$values,
      start = .side.starts,
      end = .side.ends,
      center = .side.centers,
      x = 1
    )
    .feature.y.map <- stats::setNames(.side.df$y, .side.df$feature)
    .side.tree <- do.call(rbind, lapply(.feature.group.levels, function(.grp) {
      .seg <- .build_dendro_segments(.feature.hclust[[.grp]], .feature.y.map)
      if (is.null(.seg)) return(NULL)
      .seg$feature_group <- .grp
      .seg
    }))
    .side.tree.guide <- data.frame(
      feature_group = .side.runs$values,
      y0 = .side.starts - 0.5,
      y1 = .side.ends + 0.5,
      yc = .side.centers,
      x0 = 0.0,
      x1 = 0.12
    )
    .feature.group.cols <- tryCatch(
      {
        .cols <- paletteCustomize(
          factor(.feature.group.levels, levels = .feature.group.levels),
          palette = group_palette,
          palcolor = group_palcolor,
          type = "discrete"
        )
        stats::setNames(unname(.cols)[seq_along(.feature.group.levels)], .feature.group.levels)
      },
      error = function(e) stats::setNames(grDevices::hcl.colors(length(levels(.side.df$feature_group)), palette = "Set 2"), levels(.side.df$feature_group))
    )
    .side.bar <- ggplot2::ggplot(.side.df, ggplot2::aes(x = .data$x, y = .data$y, fill = .data$feature_group)) +
      ggplot2::geom_tile(
        ggplot2::aes(x = 0.92),
        width = 0.12,
        height = 0.98,
        color = "grey30",
        linewidth = 0.2
      ) +
      ggplot2::geom_hline(
        yintercept = .side.ends + 0.5,
        linewidth = 0.8,
        color = "grey30"
      ) +
      ggplot2::geom_segment(
        data = .side.tree.guide,
        ggplot2::aes(x = .data$x0, xend = .data$x0, y = .data$y0, yend = .data$y1),
        inherit.aes = FALSE,
        linewidth = 0.8,
        color = "grey35"
      ) +
      ggplot2::geom_segment(
        data = .side.tree.guide,
        ggplot2::aes(x = .data$x0, xend = .data$x1, y = .data$yc, yend = .data$yc),
        inherit.aes = FALSE,
        linewidth = 0.8,
        color = "grey35"
      ) +
      {
        if (!is.null(.side.tree) && nrow(.side.tree) > 0) {
          ggplot2::geom_segment(
            data = .side.tree,
            ggplot2::aes(x = .data$x, xend = .data$xend, y = .data$y, yend = .data$yend),
            inherit.aes = FALSE,
            linewidth = 0.8,
            color = "grey35"
          )
        }
      } +
      ggplot2::geom_text(
        data = .side.labels,
        ggplot2::aes(x = 0.02, y = .data$center, label = .data$feature_group),
        inherit.aes = FALSE,
        angle = 0,
        hjust = 0,
        vjust = 0.5,
        size = 4
      ) +
      ggplot2::scale_fill_manual(values = .feature.group.cols, guide = "none") +
      ggplot2::scale_y_reverse(limits = c(nrow(.side.df) + 0.5, 0.5), expand = c(0, 0)) +
      ggplot2::scale_x_continuous(limits = c(0, 1), expand = c(0, 0)) +
      ggplot2::labs(x = NULL, y = NULL) +
      themeDefault() +
      ggplot2::theme(
        axis.text = ggplot2::element_blank(),
        axis.ticks = ggplot2::element_blank(),
        panel.grid = ggplot2::element_blank(),
        panel.border = ggplot2::element_blank(),
        plot.margin = grid::unit(c(0, 0, 4, 2), "pt")
      ) +
      ggplot2::coord_cartesian(clip = "off")

    .out <- ((patchwork::plot_spacer() | .top.bar) / (.side.bar | .main)) +
      patchwork::plot_layout(widths = c(0.28, 1), heights = c(0.12, 1))
    return(.out)
  }

  if (identical(.plot_type, "dotplot") && .style %in% c("merge", "seperate")) {
    if (!requireNamespace("ggplot2", quietly = TRUE)) stop("Package `ggplot2` is required for grouped dotplot styles.")
    if (!requireNamespace("patchwork", quietly = TRUE)) stop("Package `patchwork` is required for grouped dotplot styles.")
    if (!requireNamespace("scales", quietly = TRUE)) stop("Package `scales` is required for grouped dotplot styles.")
    if (!requireNamespace("cowplot", quietly = TRUE)) stop("Package `cowplot` is required for grouped dotplot styles.")

    .resolve_order <- function(var) {
      .ord <- NULL
      if (is.list(group_order)) {
        .ord <- group_order[[var]]
      } else if (!is.null(group_order) && length(.group.by) == 1) {
        .ord <- group_order
      }
      .lev <- unique(.plot.df[[var]])
      if (is.factor(.plot.df[[var]])) .lev <- levels(.plot.df[[var]])
      if (!is.null(.ord)) .lev <- unique(c(intersect(.ord, .lev), setdiff(.lev, .ord)))
      .lev
    }

    .resolve_palette_value <- function(x, idx, default = "Paired") {
      if (is.null(x)) return(default)
      if (length(x) == 1) return(x)
      x[[min(idx, length(x))]]
    }

    .safe_palette <- function(x, palette = "Paired", palcolor = NULL, type = "discrete", n = 101, color.na = "grey80") {
      tryCatch(
        paletteCustomize(x = x, palette = palette, palcolor = palcolor, type = type, n = n, matched = FALSE, color.na = color.na),
        error = function(e) {
          if (identical(type, "continuous")) {
            .pal.name <- tolower(as.character(palette)[1])
            if (.pal.name %in% c("vlag", "rdbu", "rdbu_r")) {
              colorRampPalette(c("#3B4CC0", "white", "#B40426"))(n)
            } else {
              colorRampPalette(c("#FFF7BC", "#D95F0E"))(n)
            }
          } else {
            .lev <- levels(x)
            if (is.null(.lev)) .lev <- unique(as.character(x))
            stats::setNames(grDevices::hcl.colors(length(.lev), palette = "Set 2"), .lev)
          }
        }
      )
    }

    .feature.levels <- unique(.features)
    if (!is.null(feature_order)) {
      .feature.levels <- unique(c(intersect(feature_order, .features), setdiff(.features, feature_order)))
    }
    .feature.df <- data.frame(
      feature = .feature.levels,
      feature_group = if (is.null(.feature.split)) "Features" else unname(.feature.split[match(.feature.levels, .features)]),
      stringsAsFactors = FALSE
    )
    .feature.df$feature <- factor(.feature.df$feature, levels = rev(.feature.levels))
    .feature.anno.df <- NULL
    if (!is.null(feature_annotation)) {
      if (is.data.frame(feature_annotation)) {
        .feature.anno.df <- as.data.frame(feature_annotation, stringsAsFactors = FALSE)
        if ("feature" %in% colnames(.feature.anno.df)) {
          rownames(.feature.anno.df) <- .feature.anno.df$feature
          .feature.anno.df$feature <- NULL
        } else if (is.null(rownames(.feature.anno.df))) {
          stop("`feature_annotation` data.frame must contain a `feature` column or rownames.")
        }
        .feature.anno.df <- .feature.anno.df[intersect(.feature.levels, rownames(.feature.anno.df)), , drop = FALSE]
        .feature.anno.df <- .feature.anno.df[.feature.levels, , drop = FALSE]
        .feature.anno.df$feature <- rownames(.feature.anno.df)
      } else if (is.list(feature_annotation)) {
        .feature.anno.df <- data.frame(feature = .feature.levels, stringsAsFactors = FALSE)
        for (.nm in names(feature_annotation)) {
          .feature.anno.df[[.nm]] <- ifelse(.feature.anno.df$feature %in% feature_annotation[[.nm]], .nm, "")
        }
      } else {
        stop("`feature_annotation` must be a data.frame or a named list.")
      }
      .feature.df <- merge(.feature.df, .feature.anno.df, by = "feature", all.x = TRUE, sort = FALSE)
      .feature.df$feature <- factor(.feature.df$feature, levels = rev(.feature.levels))
    }

    .annotation.label.theme <- function() {
      ggplot2::theme(
        axis.title.y = if (isTRUE(show_annotation_label)) {
          ggplot2::element_text(
            size = annotation_label_size,
            angle = annotation_label_angle,
            face = annotation_label_face,
            family = annotation_label_family,
            margin = ggplot2::margin(r = annotation_label_margin_pt)
          )
        } else {
          ggplot2::element_blank()
        }
      )
    }


	      .build_annotation_plot <- function(data, group_levels, group_cols, anno, palette.use) {
	      if (is.numeric(data[[anno]])) {
        .anno.df <- data.frame(group = factor(data$group_id, levels = rev(group_levels)), value = data[[anno]])
        .anno.df <- .anno.df[!is.na(.anno.df$group) & !is.na(.anno.df$value), , drop = FALSE]
        if (identical(.orientation.base, "horizontal")) {
          .plot <- ggplot2::ggplot(.anno.df, ggplot2::aes(y = .data$group, x = .data$value, fill = .data$group)) +
            ggplot2::geom_violin(scale = "width", linewidth = 0.7, alpha = violin_alpha, color = "grey25") +
            ggplot2::scale_fill_manual(values = group_cols, guide = "none") +
            ggplot2::scale_y_discrete(limits = rev(group_levels), expand = .group.expand) +
            ggplot2::labs(title = NULL, x = if (isTRUE(.horizontal_blocks_mode)) NULL else anno, y = NULL) +
            themeDefault() +
            ggplot2::theme(
              plot.title = ggplot2::element_text(
                hjust = 0.5,
                size = 14,
                angle = if (isTRUE(.horizontal_blocks_mode)) 90 else 0,
                vjust = 0.5
              ),
              axis.title.x = if (isTRUE(.horizontal_blocks_mode)) ggplot2::element_blank() else ggplot2::element_text(),
              axis.text.x = if (isTRUE(.horizontal_blocks_mode)) ggplot2::element_blank() else ggplot2::element_text(),
              axis.ticks.x = if (isTRUE(.horizontal_blocks_mode)) ggplot2::element_blank() else ggplot2::element_line(),
              axis.text.y = if (isTRUE(.horizontal_blocks_mode)) ggplot2::element_blank() else ggplot2::element_text(),
              axis.ticks.y = ggplot2::element_blank(),
              panel.grid.major.y = ggplot2::element_blank(),
              panel.grid.minor = ggplot2::element_blank(),
              panel.border = ggplot2::element_rect(fill = NA, colour = "black", linewidth = 1),
              plot.margin = grid::unit(c(0, 0, 0, 0), "pt")
            )
	        } else {
            .anno.df$x_id <- match(as.character(.anno.df$group), group_levels)
	          .plot <- ggplot2::ggplot(.anno.df, ggplot2::aes(x = .data$x_id, y = .data$value, fill = .data$group)) +
	            ggplot2::geom_violin(scale = "width", linewidth = 0.7, alpha = violin_alpha, color = "grey25") +
            ggplot2::scale_fill_manual(values = group_cols, guide = "none") +
            ggplot2::scale_x_continuous(limits = c(0.5, length(group_levels) + 0.5), breaks = seq_along(group_levels), labels = group_levels, expand = c(0, 0)) +
            ggplot2::labs(x = NULL, y = if (isTRUE(show_annotation_label)) anno else NULL) +
            themeDefault() +
	            ggplot2::theme(
	              axis.title.x = ggplot2::element_blank(),
	              axis.text.x = ggplot2::element_blank(),
	              axis.ticks.x = ggplot2::element_blank(),
	              axis.text.y = if (isTRUE(show_annotation_y_axis)) ggplot2::element_text() else ggplot2::element_blank(),
	              axis.ticks.y = if (isTRUE(show_annotation_y_axis)) ggplot2::element_line() else ggplot2::element_blank(),
	              panel.grid.major.x = ggplot2::element_blank(),
	              panel.grid.minor = ggplot2::element_blank(),
	              panel.border = ggplot2::element_rect(fill = NA, colour = "black", linewidth = 1),
                plot.margin = .annotation.margin
	            ) + .annotation.label.theme()
	        }
	        return(list(plot = .plot, height = track_heights[["numeric"]] * annotation_track_scale))
	      }
      .anno.tab <- as.data.frame(table(group = factor(data$group_id, levels = group_levels), value = data[[anno]]), stringsAsFactors = FALSE)
      .anno.tab <- .anno.tab[.anno.tab$Freq > 0, , drop = FALSE]
      .anno.cols <- .safe_palette(
        factor(unique(.anno.tab$value), levels = unique(.anno.tab$value)),
        palette = palette.use,
        palcolor = cell_annotation_palcolor,
        type = "discrete"
      )
      if (!.horizontal_blocks_mode && requireNamespace("scatterpie", quietly = TRUE)) {
        .anno.wide <- tidyr::pivot_wider(.anno.tab, names_from = "value", values_from = "Freq", values_fill = 0)
        .anno.wide <- as.data.frame(.anno.wide)
        .anno.wide$x <- seq_len(nrow(.anno.wide))
        .anno.wide$y <- 1
        .pie.cols <- setdiff(colnames(.anno.wide), c("group", "x", "y"))
        if (length(.pie.cols) > 0) {
          .pie.scale.auto <- min(0.9, 0.9 * 14 / max(14, length(group_levels)))
          .pie.scale.use <- min(max(annotation_pie_scale, 0.42), .pie.scale.auto)
          .pie.y.lim <- .pie.y.limits(.pie.scale.use)
          .plot <- ggplot2::ggplot() +
            scatterpie::geom_scatterpie(data = .anno.wide, ggplot2::aes(x = x, y = y), cols = .pie.cols, color = "black", pie_scale = .pie.scale.use) +
            ggplot2::scale_fill_manual(values = .anno.cols, name = anno) +
            ggplot2::scale_x_continuous(limits = c(0.5, length(group_levels) + 0.5), breaks = seq_along(group_levels), labels = group_levels, expand = c(0, 0)) +
            ggplot2::scale_y_continuous(limits = .pie.y.lim, expand = c(0, 0)) +
            ggplot2::labs(x = NULL, y = if (isTRUE(show_annotation_label)) anno else NULL) +
            themeDefault() +
	            ggplot2::theme(
	              axis.text.x = ggplot2::element_blank(),
	              axis.ticks.x = ggplot2::element_blank(),
	              axis.text.y = if (isTRUE(show_annotation_y_axis)) ggplot2::element_text() else ggplot2::element_blank(),
	              axis.ticks.y = if (isTRUE(show_annotation_y_axis)) ggplot2::element_line() else ggplot2::element_blank(),
	              panel.grid = ggplot2::element_blank(),
	              panel.border = ggplot2::element_rect(fill = NA, colour = "black", linewidth = 1),
                plot.margin = .annotation.margin
	            ) + .annotation.label.theme()
          if (identical(annotation_pie_mode, "round")) {
            .pie.aspect <- diff(.pie.y.lim) / max(1, length(group_levels))
            .plot <- .plot + ggplot2::theme(aspect.ratio = .pie.aspect)
          }
	          return(list(plot = .plot, height = track_heights[["categorical"]] * annotation_track_scale * 0.75))
	        }
	      }
      if (.horizontal_blocks_mode && requireNamespace("scatterpie", quietly = TRUE)) {
        .anno.wide <- tidyr::pivot_wider(.anno.tab, names_from = "value", values_from = "Freq", values_fill = 0)
        .anno.wide <- as.data.frame(.anno.wide)
        .anno.wide$group <- factor(.anno.wide$group, levels = rev(group_levels))
        .anno.wide$x <- seq_len(nrow(.anno.wide))
        .anno.wide$y <- 1
        .pie.cols <- setdiff(colnames(.anno.wide), c("group", "x", "y"))
        .pie.scale.use <- max(annotation_pie_scale, 3.8)
        .pie.y.lim <- .pie.y.limits(.pie.scale.use)
        .plot <- ggplot2::ggplot() +
          scatterpie::geom_scatterpie(
            data = .anno.wide,
            ggplot2::aes(x = x, y = y),
            cols = .pie.cols,
            color = "black",
            pie_scale = .pie.scale.use
          ) +
          ggplot2::scale_fill_manual(values = .anno.cols, name = anno) +
          ggplot2::scale_x_continuous(
            limits = c(0.5, nrow(.anno.wide) + 0.5),
            breaks = seq_len(nrow(.anno.wide)),
            labels = rev(group_levels),
            expand = c(0, 0)
          ) +
          ggplot2::scale_y_continuous(limits = .pie.y.lim, expand = c(0, 0)) +
          ggplot2::coord_fixed(ratio = 1) +
          ggplot2::coord_flip() +
          ggplot2::labs(x = NULL, y = NULL) +
          themeDefault() +
          ggplot2::theme(
            axis.text.x = ggplot2::element_blank(),
            axis.text.y = ggplot2::element_blank(),
            axis.ticks = ggplot2::element_blank(),
            panel.grid = ggplot2::element_blank(),
            panel.border = ggplot2::element_rect(fill = NA, colour = "black", linewidth = 1),
            plot.margin = .annotation.margin
          )
      } else if (identical(.orientation.base, "horizontal")) {
        .plot <- ggplot2::ggplot(.anno.tab, ggplot2::aes(y = .data$group, x = .data$Freq, fill = .data$value)) +
          ggplot2::geom_col(position = "fill", width = 0.72, color = "black", linewidth = 0.3) +
          ggplot2::scale_fill_manual(values = .anno.cols, name = anno) +
          ggplot2::scale_y_discrete(limits = rev(group_levels), expand = .group.expand) +
          ggplot2::scale_x_continuous(labels = scales::percent, expand = c(0, 0)) +
          ggplot2::labs(x = anno, y = NULL) +
          themeDefault() +
          ggplot2::theme(
            axis.text.y = ggplot2::element_text(),
            axis.ticks.y = ggplot2::element_blank(),
            panel.grid.major.y = ggplot2::element_blank(),
            panel.grid.minor = ggplot2::element_blank(),
            panel.border = ggplot2::element_rect(fill = NA, colour = "black", linewidth = 1),
            plot.margin = .annotation.margin
          )
      } else {
        .anno.tab$x_id <- match(as.character(.anno.tab$group), group_levels)
        .plot <- ggplot2::ggplot(.anno.tab, ggplot2::aes(x = .data$x_id, y = .data$Freq, fill = .data$value)) +
          ggplot2::geom_col(position = "fill", width = 0.72, color = "black", linewidth = 0.3) +
          ggplot2::scale_fill_manual(values = .anno.cols, name = anno) +
          ggplot2::scale_x_continuous(limits = c(0.5, length(group_levels) + 0.5), breaks = seq_along(group_levels), labels = group_levels, expand = c(0, 0)) +
          ggplot2::scale_y_continuous(labels = scales::percent, expand = c(0, 0)) +
          ggplot2::labs(x = NULL, y = if (isTRUE(show_annotation_label)) anno else NULL) +
          themeDefault() +
          ggplot2::theme(
            axis.text.x = ggplot2::element_blank(),
            axis.ticks.x = ggplot2::element_blank(),
            panel.grid.major.x = ggplot2::element_blank(),
            panel.grid.minor = ggplot2::element_blank(),
            panel.border = ggplot2::element_rect(fill = NA, colour = "black", linewidth = 1),
            plot.margin = grid::unit(c(0, 0, 0, 0), "pt")
          ) + .annotation.label.theme()
      }
	      list(plot = .plot, height = track_heights[["categorical"]] * annotation_track_scale * 0.75)
	    }

    .resolve_dot_size_range <- function(n_features, base_range = dot_range) {
      .base <- as.numeric(base_range)
      if (length(.base) < 2 || any(is.na(.base))) .base <- c(0.5, 3.5)
      .base <- sort(.base)[1:2]
      .n <- max(1, as.integer(n_features))
      .shrink <- min(1, sqrt(30 / max(.n, 30)))
      .max.size <- max(.base[1] + 0.1, .base[2] * .shrink)
      c(.base[1], .max.size)
    }

    .build_dot_plot <- function(dot.df, xvar, xlevels, ylevels = NULL) {
      .dot.cols <- .safe_palette(seq(-1, 1, length.out = 101), palette = heatmap_palette, palcolor = heatmap_palcolor, type = "continuous")
      .dot.breaks <- pretty(range(dot.df$zscore, na.rm = TRUE), n = 5)
      .dot.breaks <- .dot.breaks[.dot.breaks >= min(dot.df$zscore, na.rm = TRUE) & .dot.breaks <= max(dot.df$zscore, na.rm = TRUE)]
      .dot.size.range <- .resolve_dot_size_range(length(unique(as.character(dot.df$feature))))
      if (identical(.orientation.base, "horizontal")) {
        .p <- ggplot2::ggplot(dot.df, ggplot2::aes(x = .data$feature, y = .data[[xvar]])) +
          ggplot2::geom_point(ggplot2::aes(size = .data$pct_exp, fill = .data$zscore), shape = 21, color = "black", stroke = point_stroke) +
          ggplot2::scale_fill_gradientn(colours = .dot.cols, limits = range(dot.df$zscore, na.rm = TRUE), breaks = .dot.breaks, name = "zscore(normalized counts)") +
          ggplot2::scale_size(range = .dot.size.range, labels = scales::percent, name = "Percent") +
          ggplot2::scale_x_discrete(limits = rev(levels(dot.df$feature)), expand = ggplot2::expansion(add = 0.6)) +
          ggplot2::scale_y_discrete(limits = xlevels) +
          ggplot2::labs(x = NULL, y = NULL) +
          themeDefault() +
          ggplot2::theme(
            axis.text.x = ggplot2::element_text(angle = 90, vjust = 0.5, hjust = 1),
            panel.grid.minor = ggplot2::element_blank(),
            panel.grid.major = ggplot2::element_line(color = "#C9C9C9", linewidth = 0.5),
            panel.border = ggplot2::element_rect(fill = NA, colour = "black", linewidth = 1),
            plot.margin = grid::unit(c(0, 0, 0, 0), "pt")
          )
      } else {
        .x.levels <- xlevels
        .x.positions <- stats::setNames(seq_along(.x.levels), .x.levels)
        dot.df$x_id <- unname(.x.positions[as.character(dot.df[[xvar]])])
        .p <- ggplot2::ggplot(dot.df, ggplot2::aes(x = .data$x_id, y = .data$feature)) +
          ggplot2::geom_point(ggplot2::aes(size = .data$pct_exp, fill = .data$zscore), shape = 21, color = "black", stroke = point_stroke) +
          ggplot2::scale_fill_gradientn(colours = .dot.cols, limits = range(dot.df$zscore, na.rm = TRUE), breaks = .dot.breaks, name = "zscore(normalized counts)") +
          ggplot2::scale_size(range = .dot.size.range, labels = scales::percent, name = "Percent") +
          ggplot2::scale_x_continuous(limits = c(0.5, length(.x.levels) + 0.5), breaks = seq_along(.x.levels), labels = .x.levels, expand = c(0, 0)) +
          ggplot2::labs(x = NULL, y = NULL) +
          themeDefault() +
          ggplot2::theme(
            axis.text.x = ggplot2::element_blank(),
            axis.ticks.x = ggplot2::element_blank(),
            axis.text.y = if (identical(row_names_side, "left")) ggplot2::element_text() else ggplot2::element_blank(),
            axis.ticks.y = if (identical(row_names_side, "left")) ggplot2::element_line() else ggplot2::element_blank(),
            axis.text.y.right = if (identical(row_names_side, "right")) ggplot2::element_text() else ggplot2::element_blank(),
            axis.ticks.y.right = if (identical(row_names_side, "right")) ggplot2::element_line() else ggplot2::element_blank(),
            panel.grid.minor = ggplot2::element_blank(),
            panel.grid.major = ggplot2::element_line(color = "#C9C9C9", linewidth = 0.5),
            panel.border = ggplot2::element_rect(fill = NA, colour = "black", linewidth = 1),
            plot.margin = grid::unit(c(0, 0, 0, 0), "pt")
          )
        if (!is.null(ylevels)) {
          .p <- .p + ggplot2::scale_y_discrete(
            limits = ylevels,
            expand = ggplot2::expansion(add = 0.6),
            position = row_names_side
          )
        }
      }
      .p
    }

    .build_feature_annotation_strip <- function(feature.df, annos) {
      if (length(annos) == 0) return(NULL)
      .fa.df <- feature.df[, c("feature", annos), drop = FALSE]
      if (isTRUE(.horizontal_blocks_mode) && "feature_group" %in% colnames(feature.df)) {
        .feature.levels.local <- unlist(lapply(unique(as.character(feature.df$feature_group)), function(.grp) {
          as.character(feature.df$feature[feature.df$feature_group == .grp])
        }), use.names = FALSE)
        .feature.levels.local <- unique(.feature.levels.local)
      } else {
        .feature.levels.local <- levels(feature.df$feature)
      }
      .fa.long <- tidyr::pivot_longer(.fa.df, cols = all_of(annos), names_to = "annotation", values_to = "value")
      .fa.long$feature <- factor(.fa.long$feature, levels = .feature.levels.local)
      .fa.long$annotation <- factor(.fa.long$annotation, levels = rev(annos))
      .col.list <- list()
      for (.k in seq_along(annos)) {
        .anno <- annos[.k]
        .vals <- unique(as.character(.fa.long$value[.fa.long$annotation == .anno]))
        .vals <- .vals[!is.na(.vals)]
        .vals <- unique(c("", .vals[.vals != ""]))
        .pal <- if (is.null(feature_annotation_palette)) group_palette else if (length(feature_annotation_palette) == 1) feature_annotation_palette else feature_annotation_palette[[min(.k, length(feature_annotation_palette))]]
        .cols <- .safe_palette(factor(.vals, levels = .vals), palette = .pal, type = "discrete")
        if ("" %in% names(.cols)) .cols[""] <- "white"
        .col.list[[.anno]] <- .cols
      }
      .fa.long$fill_key <- paste(.fa.long$annotation, .fa.long$value, sep = "___")
      .fill.values <- unlist(lapply(names(.col.list), function(.anno) {
        .vals <- .col.list[[.anno]]
        stats::setNames(unname(.vals), paste(.anno, names(.vals), sep = "___"))
      }), use.names = TRUE)
      if (identical(.orientation.base, "horizontal")) {
        .vlines <- NULL
        if (isTRUE(.horizontal_blocks_mode) && "feature_group" %in% colnames(feature.df)) {
          .block.order <- unique(as.character(feature.df$feature_group))
          .block.ends <- cumsum(vapply(.block.order, function(.grp) sum(as.character(feature.df$feature_group) == .grp), numeric(1)))
          .vlines <- .block.ends[-length(.block.ends)] + 0.5
        }
        ggplot2::ggplot(.fa.long, ggplot2::aes(x = .data$feature, y = .data$annotation, fill = .data$fill_key)) +
          ggplot2::geom_tile(color = "grey35", linewidth = 0.3) +
          {
            if (!is.null(.vlines) && length(.vlines) > 0) {
              ggplot2::geom_vline(xintercept = .vlines, color = "grey35", linewidth = 0.8)
            }
          } +
          ggplot2::scale_fill_manual(values = .fill.values, guide = "none") +
          ggplot2::scale_x_discrete(limits = .feature.levels.local, expand = c(0, 0)) +
          ggplot2::labs(x = NULL, y = NULL) +
          themeDefault() +
          ggplot2::theme(
            axis.text.x = ggplot2::element_text(angle = 90, hjust = 1, vjust = 0.5),
            axis.text.y = ggplot2::element_text(angle = 0),
            axis.ticks = ggplot2::element_blank(),
            panel.grid = ggplot2::element_blank(),
            panel.border = ggplot2::element_rect(fill = NA, colour = "black", linewidth = 1),
            plot.margin = if (isTRUE(.horizontal_blocks_mode)) grid::unit(c(2, 0, 2, 0), "pt") else grid::unit(c(0, 0, 0, 0), "pt")
          )
      } else {
        ggplot2::ggplot(.fa.long, ggplot2::aes(x = .data$annotation, y = .data$feature, fill = .data$fill_key)) +
          ggplot2::geom_tile(color = "grey35", linewidth = 0.3) +
          ggplot2::scale_fill_manual(values = .fill.values, guide = "none") +
          ggplot2::scale_y_discrete(limits = levels(feature.df$feature), expand = c(0, 0)) +
          ggplot2::labs(x = NULL, y = NULL) +
          themeDefault() +
          ggplot2::theme(
            axis.text.x = ggplot2::element_text(angle = 0, hjust = 0.5, vjust = 0.5),
            axis.text.y = ggplot2::element_blank(),
            axis.ticks = ggplot2::element_blank(),
            panel.grid = ggplot2::element_blank(),
            panel.border = ggplot2::element_rect(fill = NA, colour = "black", linewidth = 1),
            plot.margin = grid::unit(c(0, 0, 0, 0), "pt")
          )
      }
    }

    .build_group_strip_panel <- function(group_levels, group_cols, title = NULL) {
      .df <- data.frame(group = factor(group_levels, levels = rev(group_levels)), x = 1)
      .title <- if (isTRUE(.horizontal_blocks_mode)) "Group" else (title %||% .group.by[1])
      .y.lab <- NULL
      ggplot2::ggplot(.df, ggplot2::aes(x = .data$x, y = .data$group, fill = .data$group)) +
        ggplot2::geom_tile(width = 0.95, color = "black", linewidth = 0.3) +
        ggplot2::scale_fill_manual(values = group_cols, name = .title) +
        ggplot2::scale_y_discrete(limits = rev(group_levels), expand = .group.expand) +
        ggplot2::labs(title = if (isTRUE(.horizontal_blocks_mode)) NULL else .title, x = NULL, y = .y.lab) +
        themeDefault() +
        ggplot2::theme(
          plot.title = ggplot2::element_text(
            hjust = 0.5,
            size = 14,
            angle = if (isTRUE(.horizontal_blocks_mode)) 90 else 0,
            vjust = if (isTRUE(.horizontal_blocks_mode)) 0.5 else 1
          ),
          axis.title.y = ggplot2::element_text(
            angle = if (isTRUE(.horizontal_blocks_mode)) 0 else 90,
            hjust = 0.5,
            vjust = 0.5
          ),
          axis.text = ggplot2::element_blank(),
          axis.ticks = ggplot2::element_blank(),
          panel.grid = ggplot2::element_blank(),
          panel.border = ggplot2::element_rect(fill = NA, colour = "black", linewidth = 1),
          plot.margin = grid::unit(c(0, 0, 0, 0), "pt"),
          legend.position = "none"
        )
    }

    .build_left_categorical_track <- function(data, group_levels, anno, palette.use) {
      .tab <- as.data.frame(table(group = factor(data$group_id, levels = group_levels), value = data[[anno]]), stringsAsFactors = FALSE)
      .tab <- .tab[.tab$Freq > 0, , drop = FALSE]
      .cols <- .safe_palette(
        factor(unique(.tab$value), levels = unique(.tab$value)),
        palette = palette.use,
        palcolor = cell_annotation_palcolor,
        type = "discrete"
      )
      if (.horizontal_blocks_mode && requireNamespace("scatterpie", quietly = TRUE)) {
        .wide <- tidyr::pivot_wider(.tab, names_from = "value", values_from = "Freq", values_fill = 0)
        .wide <- as.data.frame(.wide)
        .wide$group <- factor(.wide$group, levels = rev(group_levels))
        .wide$x <- seq_len(nrow(.wide))
        .wide$y <- 1
        .pie.cols <- setdiff(colnames(.wide), c("group", "x", "y"))
        .pie.scale.use <- max(annotation_pie_scale, 3.8)
        .pie.y.lim <- .pie.y.limits(.pie.scale.use)
        ggplot2::ggplot() +
          scatterpie::geom_scatterpie(
            data = .wide,
            ggplot2::aes(x = x, y = y),
            cols = .pie.cols,
            color = "black",
            pie_scale = .pie.scale.use
          ) +
          ggplot2::scale_fill_manual(values = .cols, name = anno) +
          ggplot2::scale_x_continuous(
            limits = c(0.5, nrow(.wide) + 0.5),
            breaks = seq_len(nrow(.wide)),
            labels = rev(group_levels),
            expand = c(0, 0)
          ) +
          ggplot2::scale_y_continuous(limits = .pie.y.lim, expand = c(0, 0)) +
          ggplot2::coord_fixed(ratio = 1) +
          ggplot2::coord_flip() +
          ggplot2::labs(title = if (isTRUE(.horizontal_blocks_mode)) NULL else anno, x = NULL, y = NULL) +
          themeDefault() +
          ggplot2::theme(
            plot.title = ggplot2::element_text(hjust = 0.5, size = 14, angle = 90, vjust = 0.5),
            axis.text.x = ggplot2::element_blank(),
            axis.text.y = ggplot2::element_blank(),
            axis.ticks = ggplot2::element_blank(),
            panel.grid = ggplot2::element_blank(),
            panel.border = ggplot2::element_rect(fill = NA, colour = "black", linewidth = 1),
            plot.margin = grid::unit(c(0, 0, 0, 0), "pt")
          )
      } else {
        ggplot2::ggplot(.tab, ggplot2::aes(y = factor(.data$group, levels = rev(group_levels)), x = .data$Freq, fill = .data$value)) +
          ggplot2::geom_col(position = "fill", width = 0.75, color = "black", linewidth = 0.25) +
          ggplot2::scale_fill_manual(values = .cols, name = anno) +
          ggplot2::scale_y_discrete(limits = rev(group_levels), expand = .group.expand) +
          ggplot2::labs(title = anno, x = NULL, y = NULL) +
          themeDefault() +
          ggplot2::theme(
            plot.title = ggplot2::element_text(hjust = 0.5, size = 14, angle = if (isTRUE(.horizontal_blocks_mode)) 90 else 0, vjust = 0.5),
            axis.text = ggplot2::element_blank(),
            axis.ticks = ggplot2::element_blank(),
            panel.grid = ggplot2::element_blank(),
            panel.border = ggplot2::element_rect(fill = NA, colour = "black", linewidth = 1),
            plot.margin = grid::unit(c(0, 0, 0, 0), "pt")
          )
      }
    }

    if (isTRUE(.horizontal_blocks_mode)) {
      if (length(.group.by) != 1) stop("`orientation = 'horizontal_blocks'` currently supports exactly one `group.by` variable.")
      .g <- .group.by[1]
      .group.levels <- .resolve_order(.g)
      .plot.df$group_id <- factor(.plot.df[[.g]], levels = .group.levels)
      .group.cols <- .safe_palette(factor(.group.levels, levels = .group.levels), palette = .resolve_palette_value(group_palette, 1, "Paired"), palcolor = group_palcolor, type = "discrete")

      .dot.agg <- .plot.df[, lapply(.SD, function(x) c(mean = mean(x, na.rm = TRUE), pct = mean(x > threshold, na.rm = TRUE))), by = "group_id", .SDcols = .features]
      .dot.mean <- .dot.agg[rep(c(TRUE, FALSE), length = .N)]
      .dot.pct <- .dot.agg[rep(c(FALSE, TRUE), length = .N)]
      .dot.mean$group_id <- factor(.dot.mean$group_id, levels = .group.levels)
      .dot.pct$group_id <- factor(.dot.pct$group_id, levels = .group.levels)
      .dot.mean.long <- data.table::melt(.dot.mean, id.vars = "group_id", variable.name = "feature", value.name = "mean_exp")
      .dot.pct.long <- data.table::melt(.dot.pct, id.vars = "group_id", variable.name = "feature", value.name = "pct_exp")
      .dot.df <- merge(.dot.mean.long, .dot.pct.long, by = c("group_id", "feature"), all = TRUE)
      .dot.df <- merge(.dot.df, .feature.df, by = "feature", all.x = TRUE, sort = FALSE)

      .feature.block.order <- if (is.null(.feature.split)) "Features" else unique(.feature.split)
      .feature.levels.blocks <- unlist(lapply(.feature.block.order, function(.blk) {
        .feature.df$feature[.feature.df$feature_group == .blk]
      }), use.names = FALSE)
      .dot.df$feature <- factor(.dot.df$feature, levels = .feature.levels.blocks)
      .dot.df$group_id <- factor(.dot.df$group_id, levels = rev(.group.levels))
      .dot.df$zscore <- ave(.dot.df$mean_exp, .dot.df$feature, FUN = function(x) {
        .sd <- stats::sd(x, na.rm = TRUE)
        if (is.na(.sd) || .sd == 0) rep(0, length(x)) else as.numeric(scale(x))
      })

      .main.dot <- ggplot2::ggplot(.dot.df, ggplot2::aes(x = .data$feature, y = .data$group_id)) +
        ggplot2::geom_tile(
          ggplot2::aes(fill = .data$zscore),
          width = 0.98,
          height = 0.98,
          alpha = 0.28,
          color = "#E8C66A",
          linewidth = 0.25
        ) +
        ggplot2::geom_point(ggplot2::aes(size = .data$pct_exp, fill = .data$zscore), shape = 21, color = "black", stroke = point_stroke) +
        ggplot2::scale_fill_gradientn(
          colours = .safe_palette(seq(-1, 1, length.out = 101), palette = heatmap_palette, palcolor = heatmap_palcolor, type = "continuous"),
          limits = range(.dot.df$zscore, na.rm = TRUE),
          breaks = pretty(range(.dot.df$zscore, na.rm = TRUE), n = 5),
          name = "zscore(normalized counts)"
        ) +
        ggplot2::scale_size(range = .resolve_dot_size_range(length(.feature.levels.blocks)), labels = scales::percent, name = "Percent") +
        ggplot2::scale_x_discrete(limits = .feature.levels.blocks, expand = c(0, 0)) +
        ggplot2::scale_y_discrete(limits = rev(.group.levels), expand = .group.expand) +
        ggplot2::labs(x = NULL, y = NULL) +
        themeDefault() +
        ggplot2::theme(
          axis.text.x = ggplot2::element_text(angle = 60, hjust = 0, vjust = 0.5),
          axis.text.y = ggplot2::element_blank(),
          axis.ticks.y = ggplot2::element_blank(),
          panel.grid = ggplot2::element_blank(),
          panel.border = ggplot2::element_rect(fill = NA, colour = "black", linewidth = 1),
          plot.margin = grid::unit(c(4, 0, 0, 0), "pt")
        )

      .feature.group.df <- unique(.feature.df[, c("feature", "feature_group"), drop = FALSE])
      .feature.group.df$feature <- factor(.feature.group.df$feature, levels = .feature.levels.blocks)
      .feature.group.cols <- .safe_palette(factor(.feature.block.order, levels = .feature.block.order), palette = group_palette, palcolor = group_palcolor, type = "discrete")
      .top.group.bar <- ggplot2::ggplot(.feature.group.df, ggplot2::aes(x = .data$feature, y = 1, fill = .data$feature_group)) +
        ggplot2::geom_tile(color = "black", linewidth = 0.3) +
        ggplot2::scale_fill_manual(values = .feature.group.cols, name = "Cluster") +
        ggplot2::scale_x_discrete(limits = .feature.levels.blocks, expand = c(0, 0)) +
        ggplot2::scale_y_continuous(limits = c(0.5, 1.5), expand = c(0, 0)) +
        ggplot2::labs(x = NULL, y = NULL) +
        themeDefault() +
        ggplot2::theme(
          axis.text.x = ggplot2::element_blank(),
          axis.text.y = ggplot2::element_blank(),
          axis.ticks = ggplot2::element_blank(),
          panel.grid = ggplot2::element_blank(),
          panel.border = ggplot2::element_rect(fill = NA, colour = "black", linewidth = 1),
          legend.position = "right",
          plot.margin = grid::unit(c(0, 0, 0, 0), "pt")
        )
      .bottom.feature <- NULL
      if (!is.null(.feature.anno.df)) {
        .anno.cols <- setdiff(colnames(.feature.df), c("feature", "feature_group"))
        .bottom.feature <- .build_feature_annotation_strip(.feature.df, .anno.cols)
      }

      .left.panels <- list(.build_group_strip_panel(.group.levels, .group.cols, .g))
      .left.titles <- c("Group")
      .legend.grobs <- list()
      .left.widths <- c(0.22)
      if (!is.null(cell_annotation)) {
        for (j in seq_along(cell_annotation)) {
          .anno <- cell_annotation[j]
          if (is.numeric(.plot.df[[.anno]])) {
            .anno.plot <- .build_annotation_plot(.plot.df, .group.levels, .group.cols, .anno, .resolve_palette_value(cell_annotation_palette, j, "Paired"))$plot
            .left.panels[[length(.left.panels) + 1]] <- .anno.plot + ggplot2::theme(legend.position = "none")
          } else {
            .anno.plot <- .build_left_categorical_track(.plot.df, .group.levels, .anno, .resolve_palette_value(cell_annotation_palette, j, "Paired"))
            .legend.grobs[[length(.legend.grobs) + 1]] <- NULL
            .left.panels[[length(.left.panels) + 1]] <- .anno.plot + ggplot2::theme(legend.position = "none")
          }
          .left.titles <- c(.left.titles, .anno)
          .left.widths <- c(.left.widths, if (is.numeric(.plot.df[[.anno]])) 0.34 else 0.34)
        }
      }
      .left.label.row <- cowplot::plot_grid(
        plotlist = lapply(.left.titles, function(.ttl) {
          cowplot::ggdraw() + cowplot::draw_label(.ttl, x = 0.5, y = 2.5, size = 14, angle = left_label_angle)
        }),
        nrow = 1,
        rel_widths = .left.widths,
        align = "h",
        axis = "tb"
      )
      .legend.theme <- ggplot2::theme(
        legend.position = "right",
        legend.title = ggplot2::element_text(size = 10 * legend_scale),
        legend.text = ggplot2::element_text(size = 8 * legend_scale),
        legend.key.height = grid::unit(9 * legend_scale, "pt"),
        legend.key.width = grid::unit(9 * legend_scale, "pt"),
        legend.spacing.y = grid::unit(max(1, legend_scale), "pt"),
        legend.box.spacing = grid::unit(max(1, legend_scale), "pt"),
        legend.margin = ggplot2::margin(0, 0, 0, 0)
      )
      .cluster.legend <- cowplot::get_legend(.top.group.bar + .legend.theme)
      .phase.legend <- if (!is.null(cell_annotation) && any(!vapply(cell_annotation, function(.a) is.numeric(.plot.df[[.a]]), logical(1)))) {
        .phase.idx <- which(!vapply(cell_annotation, function(.a) is.numeric(.plot.df[[.a]]), logical(1)))[1]
        cowplot::get_legend(.build_left_categorical_track(.plot.df, .group.levels, cell_annotation[.phase.idx], .resolve_palette_value(cell_annotation_palette, .phase.idx, "Paired")) + .legend.theme)
      } else NULL
      .main.legend <- cowplot::get_legend(.main.dot + .legend.theme)
      .left.block <- cowplot::plot_grid(
        plotlist = .left.panels,
        nrow = 1,
        rel_widths = .left.widths,
        align = "hv",
        axis = "tblr"
      )
      .layout.left.width <- 0.30
      .top.row <- cowplot::plot_grid(
        cowplot::ggdraw(),
        .top.group.bar + ggplot2::theme(legend.position = "none"),
        nrow = 1,
        rel_widths = c(.layout.left.width, 1),
        align = "h",
        axis = "tb"
      )
      .middle.row <- cowplot::plot_grid(
        .left.block,
        .main.dot + ggplot2::theme(legend.position = "none"),
        nrow = 1,
        rel_widths = c(.layout.left.width, 1),
        align = "h",
        axis = "tb"
      )
      if (is.null(.bottom.feature)) {
        .core.plot <- cowplot::plot_grid(
          .top.row,
          .middle.row,
          .left.label.row,
          ncol = 1,
          rel_heights = c(0.04, 1, 0.045),
          align = "v",
          axis = "lr"
        )
      } else {
        .bottom.row <- cowplot::plot_grid(
          .left.label.row,
          .bottom.feature + ggplot2::theme(legend.position = "none"),
          nrow = 1,
          rel_widths = c(.layout.left.width, 1),
          align = "h",
          axis = "tb"
        )
        .core.plot <- cowplot::plot_grid(
          .top.row,
          .middle.row,
          .bottom.row,
          ncol = 1,
          rel_heights = c(0.04, 1, 0.22),
          align = "v",
          axis = "lr"
        )
      }
      .legend.grobs <- Filter(Negate(is.null), c(list(.cluster.legend, .phase.legend, .main.legend)))
      if (length(.legend.grobs) > 0) {
        .legend.blocks <- list()
        .legend.heights <- numeric()
        for (.i in seq_along(.legend.grobs)) {
          .legend.blocks[[length(.legend.blocks) + 1]] <- .legend.grobs[[.i]]
          .legend.heights <- c(.legend.heights, if (.i == length(.legend.grobs)) 1.6 else 0.9)
          if (.i < length(.legend.grobs)) {
            .legend.blocks[[length(.legend.blocks) + 1]] <- cowplot::ggdraw()
            .legend.heights <- c(.legend.heights, 0.08)
          }
        }
        .legend.blocks[[length(.legend.blocks) + 1]] <- cowplot::ggdraw()
        .legend.heights <- c(.legend.heights, 1)
        .legend.col <- cowplot::plot_grid(
          plotlist = .legend.blocks,
          ncol = 1,
          align = "v",
          rel_heights = .legend.heights
        )
        .out.plot <- cowplot::plot_grid(.core.plot, .legend.col, nrow = 1, rel_widths = c(1, 0.11 * max(1, legend_scale)), align = "h")
      } else {
        .out.plot <- .core.plot
      }
      if (isTRUE(return_data)) return(list(plot = .out.plot, dot_data = .dot.df, feature_data = .feature.df, data = .plot.df))
      return(.out.plot)
    }

    if (identical(.style, "seperate")) {
      .panel.plots <- list()
      .panel.data <- list()
      for (i in seq_along(.group.by)) {
        .g <- .group.by[i]
        .group.levels <- .resolve_order(.g)
        .group.cols <- .safe_palette(factor(.group.levels, levels = .group.levels), palette = .resolve_palette_value(group_palette, i, "Paired"), palcolor = group_palcolor, type = "discrete")
        .group.bar.df <- data.frame(group = factor(.group.levels, levels = .group.levels), y = 1)
        .group.bar <- ggplot2::ggplot(.group.bar.df, ggplot2::aes(x = .data$group, y = .data$y, fill = .data$group)) +
          ggplot2::geom_tile(color = "black", linewidth = 0.8) +
          ggplot2::scale_fill_manual(values = .group.cols, name = .g) +
          ggplot2::labs(title = .g, x = NULL, y = NULL) +
          themeDefault() +
          ggplot2::theme(
            plot.title = ggplot2::element_text(hjust = 0.5, face = "plain", size = 16),
            axis.text = ggplot2::element_blank(),
            axis.ticks = ggplot2::element_blank(),
            panel.grid = ggplot2::element_blank(),
            panel.border = ggplot2::element_rect(fill = NA, colour = "black", linewidth = 1),
            legend.position = "right"
          )
        .panel.data.local <- data.frame(group_id = factor(.plot.df[[.g]], levels = .group.levels), .plot.df[, cell_annotation, with = FALSE])
        .anno.plots <- list()
        .anno.heights <- c()
        if (!is.null(cell_annotation)) {
          for (j in seq_along(cell_annotation)) {
            .anno.res <- .build_annotation_plot(.panel.data.local, .group.levels, .group.cols, cell_annotation[j], .resolve_palette_value(cell_annotation_palette, j, "Paired"))
            .anno.plots[[cell_annotation[j]]] <- .anno.res$plot
            .anno.heights <- c(.anno.heights, .anno.res$height)
          }
        }
        .dot.agg <- .plot.df[, lapply(.SD, function(x) c(mean = mean(x, na.rm = TRUE), pct = mean(x > threshold, na.rm = TRUE))), by = .g, .SDcols = .features]
        .dot.mean <- .dot.agg[rep(c(TRUE, FALSE), length = .N)]
        .dot.pct <- .dot.agg[rep(c(FALSE, TRUE), length = .N)]
        .dot.mean[[.g]] <- factor(.dot.mean[[.g]], levels = .group.levels)
        .dot.pct[[.g]] <- factor(.dot.pct[[.g]], levels = .group.levels)
        .dot.mean.long <- data.table::melt(.dot.mean, id.vars = .g, variable.name = "feature", value.name = "mean_exp")
        .dot.pct.long <- data.table::melt(.dot.pct, id.vars = .g, variable.name = "feature", value.name = "pct_exp")
        .dot.df <- merge(.dot.mean.long, .dot.pct.long, by = c(.g, "feature"), all = TRUE)
        .dot.df <- merge(.dot.df, .feature.df, by = "feature", all.x = TRUE, sort = FALSE)
        .dot.df$feature <- factor(.dot.df$feature, levels = rev(.feature.levels))
        .dot.df[[.g]] <- factor(.dot.df[[.g]], levels = .group.levels)
        .dot.df$zscore <- ave(.dot.df$mean_exp, .dot.df$feature, FUN = function(x) { .sd <- stats::sd(x, na.rm = TRUE); if (is.na(.sd) || .sd == 0) rep(0, length(x)) else as.numeric(scale(x)) })
        .p.dot <- .build_dot_plot(.dot.df, .g, .group.levels, ylevels = levels(.feature.df$feature))
        .p.feature.anno <- NULL
        .panel.right.width <- 0.12
        .wrap_with_feature_space <- function(.p) {
          if (identical(.orientation.base, "horizontal")) return(.p)
          if (is.null(.p.feature.anno)) return(.p)
          (.p | patchwork::plot_spacer()) + patchwork::plot_layout(widths = c(1, .panel.right.width))
        }
        if (!is.null(.feature.anno.df)) {
          .anno.cols <- setdiff(colnames(.feature.df), c("feature", "feature_group"))
          .p.feature.anno <- .build_feature_annotation_strip(.feature.df, .anno.cols)
        }
        if (!show_row_names) .p.dot <- .p.dot + ggplot2::theme(axis.text.y = ggplot2::element_blank(), axis.ticks.y = ggplot2::element_blank())
        if (!show_column_names) .group.bar <- .group.bar + ggplot2::theme(axis.text.x = ggplot2::element_blank(), axis.ticks.x = ggplot2::element_blank())
        if (identical(.orientation.base, "horizontal")) {
          .left.panels <- c(list(.group.bar), .anno.plots)
          .left.widths <- c(track_heights[["group"]], .anno.heights)
          .left.panel <- Reduce(function(x, y) x / y, .left.panels) + patchwork::plot_layout(heights = .left.widths)
          .dot.panel <- if (is.null(.p.feature.anno)) .p.dot else (.p.dot / .p.feature.anno) + patchwork::plot_layout(heights = c(1, 0.12))
          .panel.plots[[.g]] <- (.left.panel | .dot.panel) + patchwork::plot_layout(widths = c(0.22, 1), guides = "collect") & ggplot2::theme(legend.position = "right")
        } else {
          .dot.panel <- if (is.null(.p.feature.anno)) .p.dot else (.p.dot | .p.feature.anno) + patchwork::plot_layout(widths = c(1, .panel.right.width))
          .group.bar.panel <- .wrap_with_feature_space(.group.bar)
          .anno.plot.panels <- lapply(.anno.plots, .wrap_with_feature_space)
          .panel.components <- c(list(.group.bar.panel))
          .panel.heights <- c(track_heights[["group"]])
          if (length(.anno.plot.panels) > 0) {
            for (.k in seq_along(.anno.plot.panels)) {
              .panel.components <- c(.panel.components, list(.anno.plot.panels[[.k]]))
              .panel.heights <- c(.panel.heights, .anno.heights[.k])
              if (.k < length(.anno.plot.panels)) {
                .panel.components <- c(.panel.components, list(patchwork::plot_spacer()))
                .panel.heights <- c(.panel.heights, annotation_track_gap)
              }
            }
          }
          .panel.components <- c(.panel.components, list(.dot.panel))
          .panel.heights <- c(.panel.heights, track_heights[["dot"]])
          .panel.plots[[.g]] <- Reduce(function(x, y) x / y, .panel.components) + patchwork::plot_layout(heights = .panel.heights, guides = "collect") & ggplot2::theme(legend.position = "right")
        }
        .panel.data[[.g]] <- list(group_levels = .group.levels, dot_data = .dot.df)
      }
      .out.plot <- Reduce(function(x, y) x | y, .panel.plots) + patchwork::plot_layout(guides = "collect")
      if (isTRUE(return_data)) return(list(plot = .out.plot, panel_data = .panel.data, data = .plot.df))
      return(.out.plot)
    }

    .group.meta <- unique(.plot.df[, .group.by, with = FALSE])
    for (i in seq_along(.group.by)) .group.meta[[.group.by[i]]] <- factor(.group.meta[[.group.by[i]]], levels = .resolve_order(.group.by[i]))
    .group.meta <- .group.meta[do.call(order, .group.meta), , drop = FALSE]
    .group.meta$group_id <- do.call(paste, c(as.data.frame(.group.meta[, .group.by, with = FALSE]), sep = group_sep))
    .group.levels <- .group.meta$group_id
    .group.axis.labels <- .group.levels
    names(.group.axis.labels) <- .group.levels
    .plot.df$group_id <- factor(do.call(paste, c(as.data.frame(.plot.df[, .group.by, with = FALSE]), sep = group_sep)), levels = .group.levels)
    .group.cols.primary <- .safe_palette(factor(.group.levels, levels = .group.levels), palette = .resolve_palette_value(group_palette, 1, "Paired"), palcolor = group_palcolor, type = "discrete")
    .annotation.group.var <- .group.by[which.max(vapply(.group.by, function(.g) data.table::uniqueN(.plot.df[[.g]]), integer(1)))]
    .annotation.group.levels <- .resolve_order(.annotation.group.var)
    .annotation.data <- data.table::copy(.plot.df)
    .annotation.data$group_id <- factor(.annotation.data[[.annotation.group.var]], levels = .annotation.group.levels)
    .annotation.group.cols <- .safe_palette(
      factor(.annotation.group.levels, levels = .annotation.group.levels),
      palette = .resolve_palette_value(group_palette, match(.annotation.group.var, .group.by), "Paired"),
      palcolor = group_palcolor,
      type = "discrete"
    )

    .build_position_track <- function(values, title, n) {
      .values <- as.character(values)
      .runs <- rle(.values)
      .ends <- cumsum(.runs$lengths)
      .starts <- .ends - .runs$lengths + 1
      .centers <- (.starts + .ends) / 2
      .track.df <- data.frame(
        label = .runs$values,
        start = .starts,
        end = .ends,
        center = .centers
      )
      ggplot2::ggplot(.track.df) +
        ggplot2::geom_segment(
          ggplot2::aes(x = .data$start - 0.45, xend = .data$end + 0.45, y = 0.5, yend = 0.5),
          linewidth = 0.4,
          color = "grey30"
        ) +
        ggplot2::geom_text(
          ggplot2::aes(x = .data$center, y = 0.78, label = .data$label),
          size = 3
        ) +
        ggplot2::scale_x_continuous(limits = c(0.5, n + 0.5), expand = c(0, 0)) +
        ggplot2::scale_y_continuous(limits = c(0, 1), expand = c(0, 0), position = position_track_label_side) +
        ggplot2::labs(x = NULL, y = title) +
        themeDefault() +
        ggplot2::theme(
          axis.title.y.left = if (identical(position_track_label_side, "left")) {
            ggplot2::element_text(angle = 0, vjust = 0.5, hjust = 1)
          } else {
            ggplot2::element_blank()
          },
          axis.title.y.right = if (identical(position_track_label_side, "right")) {
            ggplot2::element_text(angle = 0, vjust = 0.5, hjust = 0)
          } else {
            ggplot2::element_blank()
          },
          axis.text = ggplot2::element_blank(),
          axis.ticks = ggplot2::element_blank(),
          panel.grid = ggplot2::element_blank(),
          panel.border = ggplot2::element_blank()
        )
    }

    .track.plots <- list()
    .track.heights.local <- c()
    if (!is.null(cell_annotation)) {
      for (j in seq_along(cell_annotation)) {
        .anno.res <- .build_annotation_plot(
          .annotation.data,
          .annotation.group.levels,
          .annotation.group.cols,
          cell_annotation[j],
          .resolve_palette_value(cell_annotation_palette, j, "Paired")
        )
        .track.plots[[cell_annotation[j]]] <- .anno.res$plot
        .track.heights.local <- c(.track.heights.local, .anno.res$height)
      }
    }
    .dot.agg <- .plot.df[, lapply(.SD, function(x) c(mean = mean(x, na.rm = TRUE), pct = mean(x > threshold, na.rm = TRUE))), by = "group_id", .SDcols = .features]
    .dot.mean <- .dot.agg[rep(c(TRUE, FALSE), length = .N)]
    .dot.pct <- .dot.agg[rep(c(FALSE, TRUE), length = .N)]
    .dot.mean$group_id <- factor(.dot.mean$group_id, levels = .group.levels)
    .dot.pct$group_id <- factor(.dot.pct$group_id, levels = .group.levels)
    .dot.mean.long <- data.table::melt(.dot.mean, id.vars = "group_id", variable.name = "feature", value.name = "mean_exp")
    .dot.pct.long <- data.table::melt(.dot.pct, id.vars = "group_id", variable.name = "feature", value.name = "pct_exp")
    .dot.df <- merge(.dot.mean.long, .dot.pct.long, by = c("group_id", "feature"), all = TRUE)
    .dot.df <- merge(.dot.df, .feature.df, by = "feature", all.x = TRUE, sort = FALSE)
    .dot.df$feature <- factor(.dot.df$feature, levels = rev(.feature.levels))
    .dot.df$group_id <- factor(.dot.df$group_id, levels = .group.levels)
    .dot.df$zscore <- ave(.dot.df$mean_exp, .dot.df$feature, FUN = function(x) { .sd <- stats::sd(x, na.rm = TRUE); if (is.na(.sd) || .sd == 0) rep(0, length(x)) else as.numeric(scale(x)) })
    .p.dot <- .build_dot_plot(.dot.df, "group_id", .group.levels, ylevels = levels(.feature.df$feature))
    .p.feature.anno <- NULL
    .panel.right.width <- 0.12
    .wrap_with_feature_space <- function(.p) {
      if (identical(.orientation.base, "horizontal")) return(.p)
      if (is.null(.p.feature.anno)) return(.p)
      (.p | patchwork::plot_spacer()) + patchwork::plot_layout(widths = c(1, .panel.right.width))
    }
    if (!is.null(.feature.anno.df)) {
      .anno.cols <- setdiff(colnames(.feature.df), c("feature", "feature_group"))
      .p.feature.anno <- .build_feature_annotation_strip(.feature.df, .anno.cols)
    }
    if (!show_row_names) .p.dot <- .p.dot + ggplot2::theme(axis.text.y = ggplot2::element_blank(), axis.ticks.y = ggplot2::element_blank())
    if (isTRUE(show_column_names)) {
      if (identical(.orientation.base, "horizontal")) {
        .p.dot <- .p.dot +
          ggplot2::scale_x_discrete(labels = .group.axis.labels) +
          ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 90, vjust = 0.5, hjust = 1))
      } else {
        .p.dot <- .p.dot +
          ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 90, vjust = 0.5, hjust = 1),
                         axis.ticks.x = ggplot2::element_line())
      }
    }
    .position.tracks <- list()
    .position.heights <- c()
    .extract_legend_grob <- function(.p) {
      .legend.theme <- ggplot2::theme(
        legend.position = "right",
        legend.title = ggplot2::element_text(size = legend_title_size),
        legend.text = ggplot2::element_text(size = legend_text_size),
        legend.key.size = grid::unit(legend_key_size_pt, "pt")
      )
      .g <- tryCatch(
        get_legend.local(.p + .legend.theme),
        error = function(e) NULL
      )
      if (is.null(.g) || inherits(.g, "zeroGrob")) return(NULL)
      .g
    }
    .wrap_grob_plot <- function(.grob) {
      if (is.null(.grob)) return(NULL)
      cowplot::ggdraw() + cowplot::draw_grob(.grob, x = 0, y = 0, width = 1, height = 1)
    }
    .pack_legend_column <- function(.grobs, spacing = legend_stack_spacing) {
      .grobs <- Filter(Negate(is.null), .grobs)
      if (length(.grobs) == 0) return(NULL)
      .heights <- vapply(.grobs, function(.g) {
        max(grid::convertHeight(grid::grobHeight(.g), "mm", valueOnly = TRUE), 1)
      }, numeric(1))
      .spacing.mm <- if (length(.grobs) > 1) rep(max(spacing, 0) * sum(.heights), length(.grobs) - 1) else numeric()
      .total.mm <- sum(.heights) + sum(.spacing.mm)
      .current.top <- 1
      .layers <- list()
      for (.i in seq_along(.grobs)) {
        .h.norm <- .heights[.i] / .total.mm
        .y.bottom <- .current.top - .h.norm
        .layers[[length(.layers) + 1]] <- cowplot::draw_grob(.grobs[[.i]], x = 0, y = .y.bottom, width = 1, height = .h.norm, hjust = 0, vjust = 0)
        .current.top <- .y.bottom
        if (.i < length(.grobs)) {
          .current.top <- .current.top - (.spacing.mm[.i] / .total.mm)
        }
      }
      Reduce(`+`, c(list(cowplot::ggdraw()), .layers))
    }
    if (length(.group.by) > 1) {
      for (i in seq_along(.group.by)) {
        .g <- .group.by[i]
        .position.tracks[[.g]] <- .build_position_track(.group.meta[[.g]], .g, length(.group.levels))
        .position.heights <- c(.position.heights, 0.45)
      }
    }
    if (identical(.orientation.base, "horizontal")) {
      .left.panels <- c(
        list(.build_group_strip_panel(.group.levels, .group.cols.primary, .group.by[1])),
        .track.plots,
        .position.tracks
      )
      .left.widths <- c(track_heights[["group"]], .track.heights.local, .position.heights)
      .left.panel <- if (length(.left.panels) > 0) {
        .left.row <- Reduce(function(x, y) x | y, .left.panels)
        .left.row + patchwork::plot_layout(widths = .left.widths)
      } else patchwork::plot_spacer()
      .dot.panel <- if (is.null(.p.feature.anno)) .p.dot else (.p.dot / .p.feature.anno) + patchwork::plot_layout(heights = c(1, 0.12))
      .out.plot <- (.left.panel | .dot.panel) + patchwork::plot_layout(widths = c(0.34, 1), guides = "collect") & ggplot2::theme(legend.position = "right")
    } else {
      .annotation.legend.grobs <- Filter(Negate(is.null), lapply(.track.plots, .extract_legend_grob))
      .dot.legend.grob <- .extract_legend_grob(.p.dot)
      .p.dot.display <- .p.dot + ggplot2::theme(legend.position = "none")
      .dot.panel <- if (is.null(.p.feature.anno)) .p.dot.display else (.p.dot.display | .p.feature.anno) + patchwork::plot_layout(widths = c(1, .panel.right.width))
      .track.plot.panels <- lapply(.track.plots, .wrap_with_feature_space)
      if (isTRUE(annotation_attach) && length(.track.plot.panels) > 0) {
        .track.plot.panels <- lapply(seq_along(.track.plot.panels), function(.i) {
          .p <- .track.plot.panels[[.i]] + ggplot2::theme(
            plot.margin = grid::unit(c(0, 0, 0, 0), "pt"),
            legend.position = "none"
          )
          if (!isTRUE(annotation_row_frame)) {
            .p <- .p + ggplot2::theme(
              panel.border = ggplot2::element_blank(),
              axis.line = ggplot2::element_blank()
            )
          }
          .p
        })
      }
      .position.track.panels <- lapply(.position.tracks, .wrap_with_feature_space)
      .panel.components <- list()
      .panel.heights <- numeric()
      if (length(.track.plot.panels) > 0) {
        .annotation.stack <- NULL
        .annotation.heights <- numeric()
        for (.k in seq_along(.track.plot.panels)) {
          .annotation.stack <- if (is.null(.annotation.stack)) .track.plot.panels[[.k]] else (.annotation.stack / .track.plot.panels[[.k]])
          .annotation.heights <- c(.annotation.heights, .track.heights.local[.k])
          if (.k < length(.track.plot.panels)) {
            .annotation.stack <- .annotation.stack / patchwork::plot_spacer()
            .annotation.heights <- c(.annotation.heights, annotation_track_gap)
          }
        }
        .annotation.stack <- .annotation.stack + patchwork::plot_layout(heights = .annotation.heights, guides = "collect")
        .panel.components <- c(.panel.components, list(.annotation.stack))
        .panel.heights <- c(.panel.heights, sum(.annotation.heights))
      }
      .panel.components <- c(.panel.components, list(.dot.panel), .position.track.panels)
      .panel.heights <- c(.panel.heights, track_heights[["dot"]], .position.heights)
      .aligned.main.parts <- tryCatch(
        do.call(cowplot::align_plots, c(.panel.components, list(align = "v", axis = "lr"))),
        error = function(e) .panel.components
      )
      .main.column <- do.call(
        cowplot::plot_grid,
        c(.aligned.main.parts, list(ncol = 1, rel_heights = .panel.heights, align = "v", axis = "lr"))
      )
      .legend.grobs <- c(.annotation.legend.grobs, if (!is.null(.dot.legend.grob)) list(.dot.legend.grob) else list())
      .legend.grobs <- Filter(Negate(is.null), .legend.grobs)
      if (length(.legend.grobs) > 0) {
        .legend.column <- .pack_legend_column(.legend.grobs)
        .out.plot <- cowplot::plot_grid(
          .main.column,
          .legend.column,
          ncol = 2,
          rel_widths = c(1 - legend_width_ratio, legend_width_ratio),
          align = "h",
          axis = "tb"
        )
      } else {
        .out.plot <- .main.column
      }
    }
    if (isTRUE(return_data)) return(list(plot = .out.plot, group_meta = .group.meta, dot_data = .dot.df, data = .plot.df))
    return(.out.plot)
  }

  .agg <- avgPctExp(.plot.df, cluster = .group.by, threshold = threshold)
  .mean.long <- data.table::melt(
    .agg$mean,
    id.vars = .group.by,
    measure.vars = .features,
    variable.name = "feature",
    value.name = "mean_exp"
  )
  .pct.long <- data.table::melt(
    .agg$pct,
    id.vars = .group.by,
    measure.vars = .features,
    variable.name = "feature",
    value.name = "pct_exp"
  )
  .heat.long <- merge(.mean.long, .pct.long, by = c(.group.by, "feature"), all = TRUE)

  .group.meta <- unique(.heat.long[, .group.by, with = FALSE])
  .group.meta[, group_id := do.call(paste, c(.SD, sep = group_sep)), .SDcols = .group.by]

  if (!is.null(group_order)) {
    .group.meta[, group_id := factor(group_id, levels = unique(group_order))]
    .group.meta <- .group.meta[order(group_id)]
    .group.meta[, group_id := as.character(group_id)]
  }

  if (!is.null(cell_annotation)) {
    .anno.summary <- .plot.df[, lapply(.SD, function(x) {
      if (is.numeric(x)) {
        mean(x, na.rm = TRUE)
      } else {
        .tab <- sort(table(x), decreasing = TRUE)
        names(.tab)[1]
      }
    }), by = .group.by, .SDcols = cell_annotation]
    .group.meta <- merge(.group.meta, .anno.summary, by = .group.by, all.x = TRUE, sort = FALSE)
  }

  .heat.long <- merge(.heat.long, .group.meta, by = .group.by, all.x = TRUE, sort = FALSE)

  .group.id.levels <- .group.meta$group_id
  .feature.levels <- unique(.features)
  if (!is.null(feature_order)) {
    .feature.levels <- unique(c(intersect(feature_order, .features), setdiff(.features, feature_order)))
  }

  .heat.long[, group_id := factor(group_id, levels = .group.id.levels)]
  .heat.long[, feature := factor(feature, levels = .feature.levels)]
  .heat.long <- .heat.long[order(feature, group_id)]

  .mat.mean <- data.table::dcast(.heat.long, feature ~ group_id, value.var = "mean_exp")
  .mat.pct <- data.table::dcast(.heat.long, feature ~ group_id, value.var = "pct_exp")

  .mat.mean <- as.data.frame(.mat.mean)
  .mat.pct <- as.data.frame(.mat.pct)
  rownames(.mat.mean) <- .mat.mean$feature
  rownames(.mat.pct) <- .mat.pct$feature
  .mat.mean$feature <- NULL
  .mat.pct$feature <- NULL

  .mat.mean <- as.matrix(.mat.mean)
  .mat.pct <- as.matrix(.mat.pct)
  .mat.mean <- .mat.mean[.feature.levels, .group.id.levels, drop = FALSE]
  .mat.pct <- .mat.pct[.feature.levels, .group.id.levels, drop = FALSE]

  .mat.plot <- switch(
    .summary,
    mean = .mat.mean,
    log1p = log1p(.mat.mean),
    zscore = t(scale(t(.mat.mean)))
  )
  .mat.plot[is.na(.mat.plot)] <- 0

  .heat.cols <- .safe_palette(
    as.numeric(.mat.plot),
    n = 101,
    palette = heatmap_palette,
    palcolor = heatmap_palcolor,
    type = "continuous"
  )
  .heat.breaks <- seq(min(.mat.plot, na.rm = TRUE), max(.mat.plot, na.rm = TRUE), length.out = length(.heat.cols))
  if (diff(range(.heat.breaks)) == 0) {
    .heat.breaks <- seq(.heat.breaks[1] - 1, .heat.breaks[1] + 1, length.out = length(.heat.cols))
  }
  .col.fun <- circlize::colorRamp2(.heat.breaks, .heat.cols)

  .column.meta <- as.data.frame(.group.meta)
  rownames(.column.meta) <- .column.meta$group_id
  .column.meta <- .column.meta[colnames(.mat.plot), , drop = FALSE]

  .anno.names <- unique(c(.group.by, cell_annotation))
  if (!is.null(top_annotation_labels)) {
    .anno.labels <- top_annotation_labels
    if (is.null(names(.anno.labels))) {
      if (length(.anno.labels) == length(.anno.names)) {
        names(.anno.labels) <- .anno.names
      } else {
        .anno.labels <- stats::setNames(as.character(.anno.labels), .anno.names[seq_along(.anno.labels)])
      }
    }
    .rename.idx <- intersect(.anno.names, names(.anno.labels))
    if (length(.rename.idx) > 0) {
      colnames(.column.meta)[match(.rename.idx, colnames(.column.meta))] <- unname(.anno.labels[.rename.idx])
      .anno.names[match(.rename.idx, .anno.names)] <- unname(.anno.labels[.rename.idx])
    }
  }
  .anno.cols <- list()
  .anno.palette <- rep_len(cell_annotation_palette %||% "Paired", length(.anno.names))
  if (length(.anno.names) > 0) {
    for (i in seq_along(.anno.names)) {
      .nm <- .anno.names[i]
      .x <- .column.meta[[.nm]]
      if (is.numeric(.x)) {
        .x.range <- range(.x, na.rm = TRUE)
        if (diff(.x.range) == 0) {
          .x.range <- c(.x.range[1] - 1, .x.range[1] + 1)
        }
        .anno.cols[[.nm]] <- circlize::colorRamp2(
          seq(.x.range[1], .x.range[2], length.out = 101),
          tryCatch(
            paletteCustomize(x = .x, n = 101, palette = .anno.palette[i], palcolor = cell_annotation_palcolor, type = "continuous"),
            error = function(e) colorRampPalette(c("white", "steelblue"))(101)
          )
        )
      } else {
        .x <- as.character(.x)
        .anno.cols[[.nm]] <- tryCatch(
          paletteCustomize(x = factor(.x, levels = unique(.x)), palette = .anno.palette[i], palcolor = cell_annotation_palcolor, type = "discrete"),
          error = function(e) {
            .cols <- grDevices::hcl.colors(length(unique(.x)), palette = "Dark 3")
            stats::setNames(.cols, unique(.x))
          }
        )
      }
    }
  }

  .top.anno <- NULL
  if (length(.anno.names) > 0) {
    .anno.df <- .column.meta[, .anno.names, drop = FALSE]
    .top.anno <- ComplexHeatmap::HeatmapAnnotation(
      df = .anno.df,
      col = .anno.cols,
      which = "column",
      border = FALSE,
      show_annotation_name = show_top_annotation_name,
      annotation_name_side = "left",
      annotation_name_rot = top_annotation_name_rot,
      annotation_name_gp = grid::gpar(fontsize = top_annotation_name_fontsize)
    )
  }

  .resolve_order <- function(var) {
    .ord <- NULL
    if (is.list(group_order)) {
      .ord <- group_order[[var]]
    } else if (!is.null(group_order) && length(.group.by) == 1) {
      .ord <- group_order
    }
    .lev <- unique(.group.meta[[var]])
    if (is.factor(.group.meta[[var]])) .lev <- levels(.group.meta[[var]])
    if (!is.null(.ord)) .lev <- unique(c(intersect(.ord, .lev), setdiff(.lev, .ord)))
    .lev
  }

  .resolve_palette_value <- function(x, idx, default = "Paired") {
    if (is.null(x)) return(default)
    if (length(x) == 1) return(x)
    x[[min(idx, length(x))]]
  }

  .safe_palette <- function(x, palette = "Paired", palcolor = NULL, type = "discrete", n = 101, color.na = "grey80") {
    tryCatch(
      paletteCustomize(x = x, palette = palette, palcolor = palcolor, type = type, n = n, matched = FALSE, color.na = color.na),
      error = function(e) {
        if (identical(type, "continuous")) {
          .pal.name <- tolower(as.character(palette)[1])
          if (.pal.name %in% c("vlag", "rdbu", "rdbu_r")) {
            colorRampPalette(c("#3B4CC0", "white", "#B40426"))(n)
          } else {
            colorRampPalette(c("#FFF7BC", "#D95F0E"))(n)
          }
        } else {
          .lev <- levels(x)
          if (is.null(.lev)) .lev <- unique(as.character(x))
          stats::setNames(grDevices::hcl.colors(length(.lev), palette = "Set 2"), .lev)
        }
      }
    )
  }

  .feature_group_cols_from_group <- function(split_values, group_levels, palette = "Paired", palcolor = NULL, sep = group_sep) {
    .split.levels <- unique(as.character(split_values))
    .group.levels <- as.character(group_levels)
    .group.cols <- .safe_palette(
      factor(.group.levels, levels = .group.levels),
      palette = palette,
      palcolor = palcolor,
      type = "discrete"
    )
    .match_one <- function(.label) {
      .hits <- .group.levels[
        .label == .group.levels |
          startsWith(.label, paste0(.group.levels, "_")) |
          startsWith(.label, paste0(.group.levels, sep))
      ]
      if (length(.hits) == 0) return(NA_character_)
      .hits[which.max(nchar(.hits))]
    }
    .matched <- stats::setNames(vapply(.split.levels, .match_one, character(1)), .split.levels)
    .out <- stats::setNames(rep(NA_character_, length(.split.levels)), .split.levels)
    .matched.idx <- !is.na(.matched)
    if (any(.matched.idx)) {
      .out[names(.matched)[.matched.idx]] <- unname(.group.cols[.matched[.matched.idx]])
    }
    .unmatched <- names(.matched)[!.matched.idx]
    if (length(.unmatched) > 0) {
      .fallback <- .safe_palette(
        factor(.unmatched, levels = .unmatched),
        palette = palette,
        palcolor = palcolor,
        type = "discrete"
      )
      .out[.unmatched] <- unname(.fallback)
    }
    .out
  }

  .row.split <- NULL
  .left.anno <- NULL
  if (!is.null(.feature.split)) {
    if (length(.feature.split) != length(.features)) {
      stop("`feature_split` must have the same length as `features`.")
    }
    names(.feature.split) <- .features
    .row.split <- .feature.split[rownames(.mat.plot)]
    .group.levels.primary <- .resolve_order(.group.by[1])
    .group.palette.primary <- .resolve_palette_value(group_palette, 1, "Paired")
    .group.palcolor.primary <- if (is.list(group_palcolor)) group_palcolor[[1]] else group_palcolor
    .left.anno <- ComplexHeatmap::rowAnnotation(
      feature_group = .row.split,
      col = list(
        feature_group = tryCatch(
          .feature_group_cols_from_group(
            split_values = .row.split,
            group_levels = .group.levels.primary,
            palette = .group.palette.primary,
            palcolor = .group.palcolor.primary,
            sep = group_sep
          ),
          error = function(e) {
            .safe_palette(
              factor(.row.split, levels = unique(.row.split)),
              palette = .group.palette.primary,
              palcolor = .group.palcolor.primary,
              type = "discrete"
            )
          }
        )
      ),
      show_annotation_name = show_feature_group_name,
      annotation_name_rot = feature_group_name_rot,
      annotation_name_gp = grid::gpar(fontsize = feature_group_name_fontsize)
    )
  }

  .cell.fun <- NULL
  .clustered.dotplot.height <- NULL
  .clustered.dotplot.width <- NULL
  .clustered.dotplot.row.names.gp <- NULL
  .clustered.dotplot.column.names.gp <- NULL
  .default.row.names.gp <- if (is.null(row_names_fontsize)) grid::gpar() else grid::gpar(fontsize = row_names_fontsize)
  .default.column.names.gp <- if (is.null(column_names_fontsize)) grid::gpar() else grid::gpar(fontsize = column_names_fontsize)
  .row.split.title <- if (is.null(.row.split) || isTRUE(show_feature_split_title)) {
    NULL
  } else {
    rep("", length(unique(as.character(.row.split))))
  }
  .row.split.title.gp <- grid::gpar(fontsize = feature_split_title_fontsize)
  if (identical(.plot_type, "clustered_dotplot")) {
    .row.mm <- clustered_dotplot_row_mm %||% max(1.8, min(6, clustered_dotplot_max_height_mm / max(1, nrow(.mat.plot))))
    .col.mm <- clustered_dotplot_col_mm %||% max(4.5, min(9, clustered_dotplot_max_width_mm / max(1, ncol(.mat.plot))))
    .clustered.dotplot.height <- grid::unit(nrow(.mat.plot) * .row.mm, "mm")
    .clustered.dotplot.width <- grid::unit(ncol(.mat.plot) * .col.mm, "mm")
    .row.fontsize <- clustered_dotplot_row_fontsize %||% max(4.5, min(10, .row.mm * 2.2))
    .col.fontsize <- clustered_dotplot_column_fontsize %||% max(6, min(10, .col.mm * 0.9))
    .clustered.dotplot.row.names.gp <- grid::gpar(fontsize = .row.fontsize)
    .clustered.dotplot.column.names.gp <- grid::gpar(fontsize = .col.fontsize)
    .pct.breaks <- c(0.2, 0.4, 0.6, 0.8, 1)
    .pct.sizes <- dot_range[1] + (.pct.breaks - min(.pct.breaks)) / diff(range(.pct.breaks)) * diff(dot_range)
    .lgd.pct <- ComplexHeatmap::Legend(
      title = "Percent",
      type = "points",
      pch = 16,
      legend_gp = grid::gpar(col = "grey30"),
      size = grid::unit(.pct.sizes, "mm"),
      labels = scales::percent(.pct.breaks)
    )
    .pct.range <- range(.mat.pct, na.rm = TRUE)
    .pct.span <- diff(.pct.range)
    if (.pct.span == 0) .pct.span <- 1
    .cell.fun <- function(j, i, x, y, width, height, fill) {
      grid::grid.rect(
        x = x, y = y, width = width, height = height,
        gp = grid::gpar(fill = "white", col = NA)
      )
      grid::grid.segments(
        x0 = x - width / 2, x1 = x + width / 2, y0 = y, y1 = y,
        gp = grid::gpar(col = "#D0D0D0", lwd = 0.6)
      )
      grid::grid.segments(
        x0 = x, x1 = x, y0 = y - height / 2, y1 = y + height / 2,
        gp = grid::gpar(col = "#D0D0D0", lwd = 0.6)
      )
      .pct <- .mat.pct[i, j]
      if (is.na(.pct) || .pct <= 0) return(invisible(NULL))
      .size <- dot_range[1] + ((.pct - .pct.range[1]) / .pct.span) * diff(dot_range)
      grid::grid.points(
        x = x, y = y, pch = 21, size = grid::unit(.size, "mm"),
        gp = grid::gpar(
          fill = .col.fun(.mat.plot[i, j]),
          col = "#555555",
          lwd = 0.6
        )
      )
    }
  } else if (isTRUE(add_dot) || isTRUE(add_reticle)) {
    .pct.range <- range(.mat.pct, na.rm = TRUE)
    .pct.span <- diff(.pct.range)
    if (.pct.span == 0) .pct.span <- 1
    .cell.fun <- function(j, i, x, y, width, height, fill) {
      if (isTRUE(add_reticle)) {
        grid::grid.rect(x = x, y = y, width = width, height = height,
                        gp = grid::gpar(col = "#D9D9D9", fill = NA, lwd = 0.6))
      }
      if (isTRUE(add_dot)) {
        .pct <- .mat.pct[i, j]
        .size <- dot_range[1] + ((.pct - .pct.range[1]) / .pct.span) * diff(dot_range)
        grid::grid.points(
          x = x, y = y, pch = 16, size = grid::unit(.size, "mm"),
          gp = grid::gpar(col = "#1F1F1F", alpha = 0.65)
        )
      }
    }
  }

  .row.labels <- rownames(.mat.plot)
    if (isTRUE(show_row_names) && length(.row.labels) > 0) {
      .row.keep.idx <- seq_along(.row.labels)
      if (!is.null(row_names_every_n)) {
        .row.keep.idx <- seq(1, length(.row.labels), by = row_names_every_n)
      } else {
        .effective.row.names.max <- row_names_max
        if (!is.null(.effective.row.names.max) &&
            length(.row.labels) > .effective.row.names.max) {
          .row.step <- ceiling(length(.row.labels) / .effective.row.names.max)
          .row.keep.idx <- seq(1, length(.row.labels), by = .row.step)
      }
    }
    if (length(.row.keep.idx) < length(.row.labels)) {
      .row.labels[-.row.keep.idx] <- ""
    }
  }

  .ht <- ComplexHeatmap::Heatmap(
    matrix = .mat.plot,
    name = switch(.summary, mean = "Mean expression", log1p = "log1p(mean)", zscore = "zscore(normalized counts)"),
    col = if (identical(.plot_type, "clustered_dotplot")) .col.fun else .col.fun,
    top_annotation = .top.anno,
    left_annotation = .left.anno,
    row_split = .row.split,
    row_title = .row.split.title,
    row_title_rot = feature_split_title_rot,
    row_title_gp = .row.split.title.gp,
    cluster_rows = cluster_rows,
    cluster_columns = cluster_columns,
    show_row_names = show_row_names,
    show_column_names = show_column_names,
    row_labels = .row.labels,
    row_names_gp = if (identical(.plot_type, "clustered_dotplot")) .clustered.dotplot.row.names.gp else .default.row.names.gp,
    column_names_gp = if (identical(.plot_type, "clustered_dotplot")) .clustered.dotplot.column.names.gp else .default.column.names.gp,
    row_names_side = row_names_side,
    rect_gp = grid::gpar(col = if (identical(.plot_type, "clustered_dotplot")) NA else if (isTRUE(border)) "white" else NA),
    border = if (identical(.plot_type, "clustered_dotplot")) TRUE else border,
    cell_fun = .cell.fun,
    heatmap_legend_param = list(
      at = pretty(range(.mat.plot, na.rm = TRUE), n = 5),
      color_bar = "continuous"
    ),
    width = if (identical(.plot_type, "clustered_dotplot")) .clustered.dotplot.width else NULL,
    height = if (identical(.plot_type, "clustered_dotplot")) .clustered.dotplot.height else NULL,
    ...
  )

  if (isTRUE(return_data)) {
    return(list(
      heatmap = .ht,
      matrix = .mat.plot,
      mean = .mat.mean,
      pct = .mat.pct,
      column_meta = .column.meta,
      row_split = .row.split,
      percent_legend = if (exists(".lgd.pct")) .lgd.pct else NULL
    ))
  }
  .ht
}
