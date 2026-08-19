#!/usr/bin/env Rscript

# OmicsCanvas Plugin: Interactive Violin / Box / Point Plot
# ----------------------------------------------------------
# Vertical violin "cloud" + box + jitter combo distribution plot, exported as
# static graphics (SVG/PDF/PNG) and an interactive Plotly HTML widget.
#
# Runtime contract:
#   Rscript plot.R --input <input.csv> --params <params.json> --output <out_dir>
#
# Input may be wide (id column + numeric feature columns) or long
# (feature + value columns, optional group column). Every parameter is optional
# and defaults to a documented value (see README.md / params_schema.json).

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
})

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x
op <- parse_args(OptionParser(option_list = list(
  make_option('--input', type = 'character'), make_option('--params', type = 'character'),
  make_option('--output', type = 'character')
)))
out <- op$output %||% getwd()
dir.create(out, recursive = TRUE, showWarnings = FALSE)
logmsg <- function(x) {
  line <- sprintf('[%s] %s\n', format(Sys.time(), '%F %T'), x)
  cat(line)
  cat(line, file = file.path(out, 'run.log'), append = TRUE)
}
fail <- function(message, detail = '', suggestion = 'Check the input columns and params.json.') {
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  writeLines(toJSON(list(error = message, detail = detail, suggestion = suggestion),
                    auto_unbox = TRUE, pretty = TRUE), file.path(out, 'error.json'))
  quit(status = 1)
}

main <- function() {
  if (is.null(op$input) || !file.exists(op$input)) fail('Input file not found', as.character(op$input))
  p <- if (!is.null(op$params) && file.exists(op$params)) fromJSON(op$params, simplifyVector = FALSE) else list()

  val <- function(name, default = NULL, aliases = character()) {
    x <- p[[name]]
    if (is.null(x)) for (g in names(p)) if (is.list(p[[g]]) && !is.null(p[[g]][[name]])) { x <- p[[g]][[name]]; break }
    if (is.null(x)) for (a in aliases) if (!is.null(p[[a]])) { x <- p[[a]]; break }
    x %||% default
  }
  vec <- function(x) {
    if (is.null(x)) return(character())
    x <- unlist(x, use.names = FALSE)
    if (length(x) == 1 && grepl(',', x, fixed = TRUE)) x <- strsplit(x, ',', fixed = TRUE)[[1]]
    trimws(as.character(x))
  }
  num <- function(name, default = 0, aliases = character()) {
    x <- suppressWarnings(as.numeric(unlist(val(name, default, aliases))[1]))
    if (is.na(x)) default else x
  }
  boo <- function(name, default = FALSE, aliases = character()) {
    x <- val(name, default, aliases)
    if (is.logical(x)) isTRUE(x[1]) else tolower(as.character(x[1])) %in% c('true', 't', 'yes', 'y', '1', 'on')
  }
  readtab <- function(path) if (tolower(tools::file_ext(path)) %in% c('tsv', 'txt')) read.delim(path, check.names = FALSE, stringsAsFactors = FALSE) else read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)

  logmsg('Starting interactive_violin_plot')
  d_orig <- readtab(op$input); cn <- names(d_orig); lower <- tolower(cn)
  findcol <- function(requested, defaults = character(), required = TRUE, label = 'column') {
    hits <- match(tolower(c(requested, defaults)), lower); hits <- hits[!is.na(hits)]
    if (length(hits)) cn[hits[1]] else if (required) fail('Required column not found', paste(c(requested, defaults), collapse = ', '), paste('Set', label, 'in params.json.')) else NULL
  }

  mode <- tolower(as.character(val('input_mode', 'auto')))
  fc <- findcol(val('feature_column', NULL, c('feature_col', 'category_column', 'variable_column', 'key_column')), c('feature', 'variable', 'key', 'category', 'feature_name'), FALSE, 'feature_column')
  vc <- findcol(val('value_column', NULL, c('value_col')), c('value', 'measurement', 'score', 'abundance'), FALSE, 'value_column')
  gc <- findcol(val('group_column', NULL, c('group_col')), c('group', 'condition', 'class'), FALSE, 'group_column')
  idc <- findcol(val('id_column', NULL, c('sample_column', 'sample_id_column')), c('id', 'sample', 'sample_id', 'observation'), FALSE, 'id_column')
  is_long <- mode == 'long' || (mode == 'auto' && !is.null(fc) && !is.null(vc))
  if (!mode %in% c('auto', 'wide', 'long')) fail('Unsupported input_mode', mode, 'Use auto, wide, or long.')

  original_n <- nrow(d_orig); filtered <- FALSE
  row_keep <- rep(TRUE, nrow(d_orig))
  rows_inc <- vec(val('rows_include')); rows_exc <- vec(val('rows_exclude'))
  row_ids <- if (is.null(idc)) as.character(seq_len(nrow(d_orig))) else as.character(d_orig[[idc]])
  if (length(rows_inc)) { row_keep <- seq_len(nrow(d_orig)) %in% suppressWarnings(as.integer(rows_inc)) | row_ids %in% rows_inc; filtered <- TRUE }
  if (length(rows_exc)) { row_keep <- row_keep & !(seq_len(nrow(d_orig)) %in% suppressWarnings(as.integer(rows_exc)) | row_ids %in% rows_exc); filtered <- TRUE }
  n_rows_filtered <- original_n - sum(row_keep)
  d <- d_orig[row_keep, , drop = FALSE]; row_ids <- row_ids[row_keep]

  if (is_long) {
    if (is.null(fc) || is.null(vc)) fail('Long input requires feature/category and value columns', '', 'Set feature_column and value_column in params.json (or use wide input).')
    z <- data.frame(id = if (is.null(idc)) as.character(seq_len(nrow(d))) else as.character(d[[idc]]),
                    feature = as.character(d[[fc]]),
                    value = suppressWarnings(as.numeric(d[[vc]])),
                    group = if (is.null(gc)) 'All' else as.character(d[[gc]]),
                    stringsAsFactors = FALSE)
    logmsg(sprintf('Long input: %d rows, feature column "%s", value column "%s"', nrow(d), fc, vc))
  } else {
    if (is.null(idc)) idc <- cn[1]
    excl <- c(idc, if (!is.null(gc)) gc else character())
    feature_cols <- setdiff(cn, excl)
    numeric_cols <- feature_cols[vapply(d[feature_cols], function(x) any(is.finite(suppressWarnings(as.numeric(x)))), logical(1))]
    if (!length(numeric_cols)) fail('Wide input has no numeric feature columns', '', 'Use an id column followed by numeric feature columns.')
    z <- do.call(rbind, lapply(numeric_cols, function(f) data.frame(
      id = as.character(d[[idc]]), feature = f,
      value = suppressWarnings(as.numeric(d[[f]])),
      group = if (is.null(gc)) 'All' else as.character(d[[gc]]),
      stringsAsFactors = FALSE)))
    logmsg(sprintf('Wide input: %d rows, %d numeric feature columns (id column "%s")', nrow(d), length(numeric_cols), idc))
  }

  n_na <- sum(!is.finite(z$value))
  if (n_na > 0) { logmsg(sprintf('Dropping %d rows with non-finite values', n_na)); z <- z[is.finite(z$value), , drop = FALSE] }
  z <- z[!is.na(z$feature) & nzchar(z$feature), , drop = FALSE]
  if (!nrow(z)) fail('No valid numeric rows remain', '', 'Check value column / numeric contents.')

  fi <- vec(val('features_include')); fe <- vec(val('features_exclude'))
  if (length(fi)) { z <- z[z$feature %in% fi, , drop = FALSE]; filtered <- TRUE }
  if (length(fe)) { z <- z[!z$feature %in% fe, , drop = FALSE]; filtered <- TRUE }
  if (!nrow(z)) fail('No features remain after filtering', '', 'Relax features_include / features_exclude.')

  features <- unique(z$feature)
  top_n <- as.integer(num('top_n', 0))
  if (top_n > 0) {
    vr <- tapply(z$value, z$feature, stats::var)
    keep_top <- names(sort(vr, decreasing = TRUE))[seq_len(min(top_n, length(vr)))]
    z <- z[z$feature %in% keep_top, , drop = FALSE]; filtered <- TRUE
    features <- unique(z$feature)
    if (!nrow(z)) fail('No rows remain after top_n selection')
  }

  order_req <- vec(val('feature_order', NULL, c('features_order')))
  sort_features <- boo('sort_features', FALSE); sort_by <- tolower(as.character(val('sort_by', 'variance')))
  if (!length(order_req) && sort_features) {
    s <- switch(sort_by,
      variance = sort(tapply(z$value, z$feature, stats::var), decreasing = TRUE),
      mean     = sort(tapply(z$value, z$feature, mean), decreasing = TRUE),
      median   = sort(tapply(z$value, z$feature, stats::median), decreasing = TRUE),
      alphabetical = sort(unique(z$feature)),
      sort(tapply(z$value, z$feature, stats::var), decreasing = TRUE))
    if (!is.null(s)) features <- names(s)
  }
  if (length(order_req)) { features <- unique(c(order_req, features)); features <- features[features %in% unique(z$feature)] }
  if (boo('reverse_features')) features <- rev(features)
  z <- z[z$feature %in% features, , drop = FALSE]
  z$feature <- factor(z$feature, levels = features)
  if (!nrow(z)) fail('No rows remain after feature selection')
  z$group <- factor(z$group, levels = unique(z$group))
  groups <- as.character(unique(z$group)); n_groups <- length(groups)

  # ---- tooltips ----
  tooltip_cols <- vec(val('tooltip_columns'))
  available <- c('id', 'feature', 'group', 'value')
  if (!length(tooltip_cols)) tooltip_cols <- c('feature', 'group', 'value')
  tooltip_cols <- intersect(tooltip_cols, available)
  mktt <- function(df) do.call(paste, c(lapply(tooltip_cols, function(col) {
    v <- df[[col]]; if (col == 'value') sprintf('%s: %s', col, signif(as.numeric(v), 5)) else sprintf('%s: %s', col, v)
  }), list(sep = '<br>')))
  z$tt <- mktt(z)

  write.csv(z[, c('id', 'feature', 'group', 'value')], file.path(out, 'distribution_data_used.csv'), row.names = FALSE)
  write.csv(d, file.path(out, 'selected_rows.csv'), row.names = FALSE)
  logmsg(sprintf('distribution_data_used.csv and selected_rows.csv written (%d rows)', nrow(z)))

  # ---- layout ----
  flip <- boo('flip', FALSE)
  w <- num('width', 10); h <- num('height', 6)
  ar <- suppressWarnings(as.numeric(val('aspect_ratio', NA_real_)))
  if (is.finite(ar)) h <- w / ar
  dpi <- as.integer(num('dpi', 300))

  # ---- grouping / faceting ----
  has_groups <- !is.null(gc) && n_groups >= 1
  group_mode <- tolower(as.character(val('group_mode', 'facet')))
  if (!group_mode %in% c('facet', 'grouped')) group_mode <- 'facet'
  use_grouped <- has_groups && group_mode == 'grouped'
  use_facet <- has_groups && group_mode == 'facet'
  facet_scales <- tolower(as.character(val('facet_scales', 'free_y')))
  if (!facet_scales %in% c('fixed', 'free', 'free_x', 'free_y')) facet_scales <- 'free_y'
  dodge_w <- 0.9
  dodge_off <- NULL
  if (use_grouped) {
    tbl <- unique(z[, c('feature', 'group'), drop = FALSE])
    dodge_off <- lapply(features, function(f) {
      gs <- sort(unique(tbl$group[as.character(tbl$feature) == f]))
      setNames(dodge_w * ((match(gs, gs) - .5) / length(gs) - .5), gs)
    })
    names(dodge_off) <- features
  }
  xoff_for <- function(f, g) if (use_grouped) unname(dodge_off[[f]][[g]]) else 0

  # ---- cloud ----
  show_cloud <- boo('cloud_show', TRUE)
  cloud_stat <- tolower(as.character(val('cloud_stat', 'density')))
  cloud_fill_mode <- tolower(as.character(val('cloud_fill_mode', 'feature')))
  fill_var <- if (cloud_fill_mode == 'group' && has_groups) 'group' else 'feature'
  cloud_alpha <- num('cloud_alpha', .7)
  cloud_width <- num('cloud_width', .9)
  cloud_trim <- boo('cloud_trim', FALSE)
  cloud_adjust <- num('cloud_adjust', 1); bw_param <- num('cloud_bandwidth', NA_real_)
  pal_default <- c('#4E79A7', '#F28E2B', '#E15759', '#59A14F', '#B07AA1', '#76B7B2', '#EDC948', '#FF9DA7', '#9C755F', '#BAB0AC')
  cloud_color_single <- val('cloud_color', NULL)
  palette_value <- val('cloud_colors', NULL, c('palette'))
  fill_levels <- levels(factor(z[[fill_var]]))
  build_color_vec <- function(cvals, levels, single) {
    if (!is.null(single)) return(NULL)
    cvals <- unlist(cvals, use.names = TRUE); if (!length(cvals)) cvals <- pal_default
    if (!is.null(names(cvals)) && any(nzchar(names(cvals)))) {
      out2 <- character(); for (lvl in levels) out2[[lvl]] <- if (lvl %in% names(cvals)) as.character(cvals[[lvl]]) else as.character(pal_default[(match(lvl, levels) - 1) %% length(pal_default) + 1])
      return(out2)
    }
    out2 <- rep(NA_character_, length(levels))
    for (i in seq_along(levels)) out2[i] <- as.character(cvals[(i - 1) %% length(cvals) + 1])
    setNames(out2, levels)
  }
  fill_colors <- build_color_vec(palette_value, fill_levels, cloud_color_single)
  legend_title <- val('legend_title', if (fill_var == 'group') 'Group' else 'Feature')

  # ---- box / median / quantile ----
  show_box <- boo('box_show', TRUE)
  box_width <- num('box_width', .22)
  box_stats <- function(v) {
    q <- stats::quantile(v, c(.25, .5, .75), na.rm = TRUE)
    iqr <- q[3] - q[1]
    lo <- max(min(v), q[1] - 1.5 * iqr); hi <- min(max(v), q[3] + 1.5 * iqr)
    list(lower = q[1], middle = q[2], upper = q[3], ymin = lo, ymax = hi, outliers = v[v < lo | v > hi])
  }
  box_df <- data.frame(); out_df <- data.frame(); med_df <- data.frame(); qseg_df <- data.frame()
  show_median <- boo('median_show', TRUE); show_quantile <- boo('quantile_show', FALSE)
  for (f in features) {
    for (g in groups) {
      v <- z$value[as.character(z$feature) == f & as.character(z$group) == g]
      if (!length(v)) next
      s <- box_stats(v); xo <- xoff_for(f, g)
      if (show_box) box_df <- rbind(box_df, data.frame(feature = f, group = g, xoff = xo,
        lower = s$lower, middle = s$middle, upper = s$upper, ymin = s$ymin, ymax = s$ymax))
      if (length(s$outliers)) out_df <- rbind(out_df, data.frame(feature = f, group = g, xoff = xo, value = s$outliers))
      if (show_median) med_df <- rbind(med_df, data.frame(feature = f, group = g, xoff = xo, y = s$middle))
      if (show_quantile) qseg_df <- rbind(qseg_df, data.frame(feature = f, group = g, xoff = xo, y = s$lower, y2 = s$upper))
    }
  }
  box_outlier_show <- boo('box_outlier_show', FALSE) && nrow(out_df) > 0
  median_width <- num('median_width', .3)
  quantile_width <- num('quantile_width', .8)

  # ---- points ----
  show_points <- boo('point_show', TRUE)
  point_data <- tolower(as.character(val('point_data', 'all')))
  point_density_sample <- as.integer(num('point_density_sample', 100))
  point_position <- tolower(as.character(val('point_position', 'within')))
  if (use_grouped && is.null(val('point_position', NULL))) point_position <- 'split'
  point_df <- z
  if (show_points && point_data == 'density_sample' && point_density_sample > 0) {
    set.seed(as.integer(num('point_jitter_seed', 42)))
    idx <- unlist(lapply(features, function(f) lapply(groups, function(g) {
      r <- which(as.character(z$feature) == f & as.character(z$group) == g)
      v <- z$value[r]
      if (length(r) <= point_density_sample || length(unique(v)) == 1) return(r)
      dens <- suppressWarnings(stats::density(v, n = length(v)))
      wts <- suppressWarnings(approx(dens$x, dens$y, xout = v, rule = 2)$y)
      wts[is.na(wts)] <- 1e-6; wts <- pmax(wts, 1e-6)
      r[sort(sample(seq_along(v), point_density_sample, prob = wts))]
    })))
    point_df <- z[idx, , drop = FALSE]
    logmsg(sprintf('Density-sampled %d points (target %d per feature/group)', nrow(point_df), point_density_sample))
  }
  point_colors <- val('point_colors', NULL)
  point_color_single <- val('point_color', '#333333')
  point_col_vec <- if (!is.null(point_colors)) build_color_vec(point_colors, fill_levels, NULL) else NULL

  # ---- ggplot layers ----
  q <- suppressWarnings({
  q <- ggplot()
  if (show_cloud) {
    cloud_aes <- aes(x = feature, y = value)
    if (is.null(cloud_color_single)) cloud_aes$fill <- rlang::sym(fill_var)
    if (use_grouped) cloud_aes$group <- quote(interaction(feature, group))
    cloud_args <- list(data = z, mapping = cloud_aes, width = cloud_width,
                       scale = if (cloud_stat == 'count') 'count' else 'area',
                       adjust = cloud_adjust, trim = cloud_trim, alpha = cloud_alpha,
                       position = if (use_grouped) position_dodge(dodge_w) else 'identity',
                       colour = if (boo('cloud_outline_show', TRUE)) val('cloud_stroke', '#333333') else NA,
                       linewidth = num('cloud_stroke_width', .4))
    if (is.finite(bw_param) && bw_param > 0) cloud_args$bw <- bw_param
    if (!is.null(cloud_color_single)) cloud_args$fill <- cloud_color_single
    q <- q + do.call(geom_violin, cloud_args)
  }
  if (show_box) {
    box_mapping <- aes(x = feature, ymin = ymin, lower = lower, middle = middle, upper = upper, ymax = ymax,
        text = sprintf('Feature: %s<br>Group: %s<br>Median: %s<br>IQR: %s', feature, group, signif(middle, 4), signif(upper - lower, 4)))
    if (use_grouped) box_mapping$group <- quote(interaction(feature, group))
    q <- q + geom_boxplot(data = box_df, mapping = box_mapping,
        stat = 'identity', width = box_width, fill = val('box_fill', '#FFFFFF'), alpha = num('box_alpha', .8),
        colour = val('box_stroke', '#333333'), linewidth = num('box_stroke_width', .5), fatten = 0, outlier.shape = NA,
        position = if (use_grouped) position_dodge(dodge_w) else 'identity')
  }
  if (box_outlier_show) q <- q + geom_point(data = out_df,
      aes(x = feature, group = group, y = value, text = sprintf('Outlier<br>Feature: %s<br>Group: %s<br>Value: %s', feature, group, signif(value, 5))),
      position = if (use_grouped) position_dodge(dodge_w) else 'identity',
      shape = 16, size = num('box_outlier_size', 1.5), alpha = num('box_outlier_alpha', .8), colour = val('box_outlier_color', '#333333'))
  if (show_median && nrow(med_df)) q <- q + geom_segment(data = med_df,
      aes(x = as.numeric(factor(feature, levels = features)) + xoff - median_width / 2,
          xend = as.numeric(factor(feature, levels = features)) + xoff + median_width / 2, y = y, yend = y,
          text = sprintf('Median: %s', signif(y, 5))),
      colour = val('median_color', '#111111'), linewidth = num('median_line_width', 1.1), linetype = val('median_linetype', 'solid'))
  if (show_quantile && nrow(qseg_df)) {
    qw <- box_width * .9 * quantile_width / 2
    for (yy in c('y', 'y2')) q <- q + geom_segment(data = qseg_df,
      aes(x = as.numeric(factor(feature, levels = features)) + xoff - qw,
          xend = as.numeric(factor(feature, levels = features)) + xoff + qw, y = .data[[yy]], yend = .data[[yy]],
          text = sprintf('Quantile: %s', signif(.data[[yy]], 5))),
      colour = val('quantile_color', '#333333'), linewidth = num('quantile_line_width', .6),
      linetype = val('quantile_linetype', 'dashed'), alpha = num('quantile_alpha', .7))
  }
  if (show_points) {
    jw <- num('point_jitter_width', .35) * .45
    pt_aes <- aes(x = feature, y = value, text = tt)
    pt_pos <- if (use_grouped) position_jitterdodge(jitter.width = jw, dodge.width = dodge_w, seed = as.integer(num('point_jitter_seed', 42)))
              else position_jitter(width = jw, seed = as.integer(num('point_jitter_seed', 42)))
    if (!is.null(point_col_vec)) {
      pt_aes$colour <- rlang::sym(fill_var)
      if (use_grouped) pt_aes$group <- rlang::sym('group')
      q <- q + geom_point(data = point_df, mapping = pt_aes, position = pt_pos,
                          shape = val('point_shape', 16), size = num('point_size', 1.2), alpha = num('point_alpha', .6), stroke = num('point_stroke', .25))
    } else if (use_grouped) {
      pt_aes$colour <- rlang::sym('group'); pt_aes$group <- rlang::sym('group')
      q <- q + geom_point(data = point_df, mapping = pt_aes, position = pt_pos,
                          shape = val('point_shape', 16), size = num('point_size', 1.2), alpha = num('point_alpha', .6), stroke = num('point_stroke', .25))
      q <- q + scale_colour_manual(values = setNames(rep(point_color_single, n_groups), groups),
                                   name = legend_title, drop = FALSE, guide = 'none')
    } else {
      q <- q + geom_point(data = point_df, mapping = pt_aes, position = pt_pos, colour = point_color_single,
                          shape = val('point_shape', 16), size = num('point_size', 1.2), alpha = num('point_alpha', .6), stroke = num('point_stroke', .25))
    }
  }

  hl <- intersect(vec(val('highlight_features')), as.character(features))
  if (length(hl)) {
    hl_df <- data.frame(feature = hl, xpos = match(hl, features), stringsAsFactors = FALSE)
    q <- q + geom_rect(data = hl_df, aes(xmin = xpos - .5, xmax = xpos + .5, ymin = -Inf, ymax = Inf),
                       fill = val('highlight_color', '#FFD166'), alpha = num('highlight_alpha', .15), inherit.aes = FALSE)
  }

  xbr <- vec(val('x_breaks')); xlm <- vec(val('x_limits'))
  ybr <- suppressWarnings(as.numeric(unlist(val('y_breaks', NULL)))); ybr <- ybr[is.finite(ybr)]
  ylm <- suppressWarnings(as.numeric(unlist(val('y_limits', NULL)))); ylm <- ylm[is.finite(ylm)]
  if (length(ylm) == 1) ylm <- NULL
  q <- q + scale_x_discrete(breaks = if (length(xbr)) xbr else waiver(),
                            limits = if (length(xlm)) xlm else NULL, drop = FALSE) +
    scale_y_continuous(breaks = if (length(ybr)) ybr else waiver(),
                       limits = if (length(ylm)) ylm else NULL, oob = scales::squish)
  if (show_cloud && !is.null(fill_colors)) q <- q + scale_fill_manual(values = fill_colors, name = legend_title, drop = FALSE)
  if (show_points && !is.null(point_col_vec)) q <- q + scale_colour_manual(values = point_col_vec, name = legend_title, drop = FALSE)
  q <- q + labs(x = val('xlab', 'Feature'), y = val('ylab', 'Value'),
                title = if (boo('title_show', TRUE)) val('title', 'Violin / Box / Point Plot') else NULL,
                subtitle = val('subtitle', NULL), caption = val('caption', NULL))
  if (use_facet) q <- q + facet_wrap(~ group, scales = facet_scales)
  if (flip) q <- q + coord_flip()

  feat_lab_show <- boo('feature_label_show', TRUE)
  feat_axis <- element_text(size = num('feature_label_size', num('x_axis_text_size', 10)),
                            colour = val('feature_label_color', val('x_axis_text_color', '#333333')),
                            angle = num('feature_label_angle', num('x_axis_text_angle', 0)),
                            face = val('feature_label_face', 'plain'))
  val_axis <- element_text(size = num('y_axis_text_size', 10), colour = val('y_axis_text_color', '#333333'))
  q <- q + theme_minimal(base_size = num('base_size', 11), base_family = val('font_family', 'sans')) +
    theme(
      panel.background = element_rect(fill = val('panel_background', '#FFFFFF'), colour = NA),
      plot.background = element_rect(fill = val('plot_background', '#FFFFFF'), colour = NA),
      panel.grid.major = if (boo('grid_show', TRUE)) element_line(colour = val('grid_color', '#E6E6E6'), linewidth = num('grid_width', .35), linetype = val('grid_linetype', 'solid')) else element_blank(),
      panel.grid.minor = if (boo('grid_minor_show', FALSE)) element_line(colour = val('grid_color', '#E6E6E6'), linewidth = num('grid_width', .25), linetype = 'dotted') else element_blank(),
      axis.line = if (boo('axis_line_show', TRUE)) element_line(colour = val('axis_line_color', '#555555'), linewidth = num('axis_line_width', .4)) else element_blank(),
      axis.ticks = if (boo('tick_show', TRUE)) element_line(colour = val('tick_color', '#555555'), linewidth = num('tick_width', .4)) else element_blank(),
      axis.text.x = if (feat_lab_show) feat_axis else element_blank(),
      axis.text.y = val_axis,
      axis.title = element_text(colour = val('axis_line_color', '#333333')),
      plot.title = element_text(size = num('title_size', 16), colour = val('title_color', '#222222'), face = val('title_face', 'bold'), hjust = num('title_hjust', 0)),
      plot.subtitle = element_text(size = num('subtitle_size', 11), colour = val('subtitle_color', '#555555'), face = val('subtitle_face', 'plain')),
      panel.border = if (boo('panel_border_show', FALSE)) element_rect(fill = NA, colour = val('panel_border_color', '#555555'), linewidth = num('panel_border_width', .5)) else element_blank(),
      legend.position = if (boo('legend_show', TRUE)) val('legend_position', 'right') else 'none',
      legend.title = element_text(size = num('legend_title_size', 10)),
      legend.text = element_text(size = num('legend_text_size', 9)),
      legend.key.size = unit(num('legend_key_size', 1.2), 'lines'),
      strip.background = element_rect(fill = val('panel_background', '#FFFFFF'), colour = NA),
      strip.text = element_text(size = num('title_size', 16) * .8, colour = val('title_color', '#222222'))
    )
  if (!boo('x_axis_show', TRUE)) q <- q + theme(axis.text.x = element_blank(), axis.ticks.x = element_blank(), axis.title.x = element_blank())
  if (!boo('y_axis_show', TRUE)) q <- q + theme(axis.text.y = element_blank(), axis.ticks.y = element_blank(), axis.title.y = element_blank())
  legend_ncol <- as.integer(num('legend_ncol', 1))
  if (legend_ncol > 1) q <- q + guides(fill = guide_legend(ncol = legend_ncol), colour = guide_legend(ncol = legend_ncol))
  q })

  # ---- static exports ----
  formats <- tolower(vec(val('export_formats', c('svg', 'pdf', 'png', 'html')))); if (!length(formats)) formats <- c('svg', 'pdf', 'png', 'html')
  if ('svg' %in% formats) { ggsave(file.path(out, 'result.svg'), q, width = w, height = h, units = 'in', dpi = dpi); logmsg('Wrote result.svg') }
  if ('pdf' %in% formats) { ggsave(file.path(out, 'result.pdf'), q, width = w, height = h, units = 'in'); logmsg('Wrote result.pdf') }
  if ('png' %in% formats) { ggsave(file.path(out, 'result.png'), q, width = w, height = h, units = 'in', dpi = dpi); logmsg('Wrote result.png') }

  # ---- interactive HTML ----
  interactive <- boo('interactive', TRUE)
  if (interactive) {
    if (!requireNamespace('plotly', quietly = TRUE) || !requireNamespace('htmlwidgets', quietly = TRUE))
      fail('plotly / htmlwidgets not available', '', 'Install plotly and htmlwidgets, or set interactive=false.')
    tryCatch({
      pl <- plotly::ggplotly(q, tooltip = 'text')
      if (!is.null(val('hover_template'))) {
        pb <- tryCatch(plotly::plotly_build(pl), error = function(e) NULL)
        if (!is.null(pb)) {
          for (i in seq_along(pb$x$data)) pb$x$data[[i]]$hovertemplate <- as.character(val('hover_template'))
          pl <- pb
        }
      }
      pl <- plotly::layout(pl, autosize = TRUE,
                           paper_bgcolor = val('plot_background', '#FFFFFF'),
                           plot_bgcolor = val('panel_background', '#FFFFFF'),
                           title = list(text = if (boo('title_show', TRUE)) val('title', 'Violin / Box / Point Plot') else ''))
      mbtr <- unique(Filter(nzchar, c(if (!boo('zoom', TRUE)) c('zoom2d', 'zoomIn2d', 'zoomOut2d'),
                                      if (!boo('pan', TRUE)) 'pan2d',
                                      if (!boo('reset_view', TRUE)) c('autoScale2d', 'resetScale2d'))))
      pl <- plotly::config(pl, displaylogo = FALSE, displayModeBar = TRUE,
                           scrollZoom = boo('zoom', TRUE),
                           doubleClick = if (boo('reset_view', TRUE)) 'reset' else FALSE,
                           modeBarButtonsToAdd = if (boo('lasso_select', TRUE) || boo('selectable', TRUE)) c('lasso2d', 'select2d') else character(),
                           modeBarButtonsToRemove = mbtr)
      saved <- tryCatch({ htmlwidgets::saveWidget(pl, file.path(out, 'result.html'), selfcontained = TRUE); TRUE },
                        error = function(e) { logmsg(sprintf('selfcontained HTML failed (%s); using non-selfcontained fallback', conditionMessage(e))); FALSE })
      if (!saved) { htmlwidgets::saveWidget(pl, file.path(out, 'result.html'), selfcontained = FALSE); logmsg('Wrote result.html (non-selfcontained fallback)') }
      if (saved) unlink(file.path(out, 'result_files'), recursive = TRUE, force = TRUE)
      logmsg('Wrote result.html (interactive Plotly)')
    }, error = function(e) fail('Interactive HTML generation failed', conditionMessage(e), 'Set interactive=false to skip Plotly output.'))
  } else {
    writeLines('<html><body><p>Interactive Plotly output is disabled.</p></body></html>', file.path(out, 'result.html'))
    logmsg('Wrote result.html placeholder (interactive=false)')
  }

  # ---- figure.json ----
  stats_by_feature <- lapply(features, function(f) {
    v <- z$value[as.character(z$feature) == f]
    list(mean = round(mean(v), 4), median = round(stats::median(v), 4), sd = round(stats::sd(v), 4), iqr = round(IQR(v), 4), n = length(v))
  })
  names(stats_by_feature) <- features
  figure <- list(
    plugin = 'interactive_violin_plot',
    title = if (boo('title_show', TRUE)) val('title', 'Violin / Box / Point Plot') else NULL,
    input_mode = mode, group_mode = if (has_groups) group_mode else NULL,
    n_features = length(features), n_groups = n_groups,
    n_points_plotted = if (show_points) nrow(point_df) else 0,
    n_values_total = nrow(z),
    original_rows = original_n, rows_after_row_filters = sum(row_keep), n_rows_filtered = n_rows_filtered,
    filtered = filtered,
    features = as.character(features), groups = groups,
    layers = list(cloud = show_cloud, box = show_box, median = show_median, quantile = show_quantile,
                  points = show_points, facet = use_facet, grouped = use_grouped, flip = flip, interactive = interactive),
    stats = stats_by_feature,
    outputs = c('result.svg', 'result.pdf', 'result.png', 'result.html', 'figure.json', 'run.log', 'distribution_data_used.csv', 'selected_rows.csv')
  )
  writeLines(toJSON(figure, auto_unbox = TRUE, pretty = TRUE), file.path(out, 'figure.json'))
  if (file.exists(file.path(out, 'error.json'))) unlink(file.path(out, 'error.json'))
  logmsg(sprintf('Rendered %d values across %d features and %d groups', nrow(z), length(features), n_groups))
  logmsg('Finished interactive_violin_plot')
}

tryCatch(main(), error = function(e) {
  tb <- paste(capture.output(traceback(3)), collapse = '\n')
  fail('Plot generation failed', paste(conditionMessage(e), tb, sep = '\n'),
       'Check input columns, params.json values, and installed R packages.')
})
