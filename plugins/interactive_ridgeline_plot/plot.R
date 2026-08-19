#!/usr/bin/env Rscript

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
logmsg <- function(x) cat(sprintf('[%s] %s\n', format(Sys.time(), '%F %T'), x),
                         file = file.path(out, 'run.log'), append = TRUE)
fail <- function(message, detail = '', suggestion = 'Check the input columns and params.json.') {
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  writeLines(toJSON(list(error = message, detail = detail, suggestion = suggestion), auto_unbox = TRUE, pretty = TRUE), file.path(out, 'error.json'))
  quit(status = 1)
}

tryCatch({
  if (is.null(op$input) || !file.exists(op$input)) fail('Input file not found', as.character(op$input))
  p <- if (!is.null(op$params) && file.exists(op$params)) fromJSON(op$params, simplifyVector = FALSE) else list()
  val <- function(name, default = NULL, aliases = character()) {
    x <- p[[name]]
    if (is.null(x)) for (g in names(p)) if (is.list(p[[g]]) && !is.null(p[[g]][[name]])) { x <- p[[g]][[name]]; break }
    if (is.null(x)) for (a in aliases) if (!is.null(p[[a]])) { x <- p[[a]]; break }
    x %||% default
  }
  vec <- function(x) { if (is.null(x)) return(character()); x <- unlist(x, use.names = FALSE); if (length(x) == 1 && grepl(',', x, fixed = TRUE)) x <- strsplit(x, ',', fixed = TRUE)[[1]]; trimws(as.character(x)) }
  num <- function(name, default = 0, aliases = character()) { x <- suppressWarnings(as.numeric(unlist(val(name, default, aliases))[1])); if (is.na(x)) default else x }
  boo <- function(name, default = FALSE, aliases = character()) { x <- val(name, default, aliases); if (is.logical(x)) isTRUE(x[1]) else tolower(as.character(x[1])) %in% c('true','t','yes','y','1','on') }
  readtab <- function(path) if (tolower(tools::file_ext(path)) %in% c('tsv','txt')) read.delim(path, check.names = FALSE, stringsAsFactors = FALSE) else read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  d <- readtab(op$input); cn <- names(d); lower <- tolower(cn)
  findcol <- function(requested, defaults = character(), required = TRUE, label = 'column') {
    hits <- match(tolower(c(requested, defaults)), lower); hits <- hits[!is.na(hits)]
    if (length(hits)) cn[hits[1]] else if (required) fail('Required column not found', paste(c(requested, defaults), collapse = ', '), paste('Set', label, 'in params.json.')) else NULL
  }
  mode <- tolower(as.character(val('input_mode', 'auto')))
  fc <- findcol(val('feature_column', NULL, c('feature_col','category_column','variable_column','key_column')), c('feature','variable','key','category','feature_name'), FALSE, 'feature_column')
  vc <- findcol(val('value_column', NULL, c('value_col')), c('value','measurement','score','abundance'), FALSE, 'value_column')
  gc <- findcol(val('group_column', NULL, c('group_col')), c('group','condition','class'), FALSE, 'group_column')
  idc <- findcol(val('id_column', NULL, c('sample_column','sample_id_column')), c('id','sample','sample_id','observation'), FALSE, 'id_column')
  is_long <- mode == 'long' || (mode == 'auto' && !is.null(fc) && !is.null(vc))
  original_n <- nrow(d); filtered <- FALSE
  row_keep <- rep(TRUE, nrow(d))
  rows_inc <- vec(val('rows_include')); rows_exc <- vec(val('rows_exclude'))
  row_ids <- if (is.null(idc)) as.character(seq_len(nrow(d))) else as.character(d[[idc]])
  if (length(rows_inc)) { row_keep <- seq_len(nrow(d)) %in% suppressWarnings(as.integer(rows_inc)) | row_ids %in% rows_inc; filtered <- TRUE }
  if (length(rows_exc)) { row_keep <- row_keep & !(seq_len(nrow(d)) %in% suppressWarnings(as.integer(rows_exc)) | row_ids %in% rows_exc); filtered <- TRUE }
  d <- d[row_keep, , drop = FALSE]; row_ids <- row_ids[row_keep]
  if (is_long) {
    if (is.null(fc) || is.null(vc)) fail('Long input requires feature/category and value columns')
    z <- data.frame(feature = as.character(d[[fc]]), value = suppressWarnings(as.numeric(d[[vc]])), id = if (is.null(idc)) as.character(seq_len(nrow(d))) else as.character(d[[idc]]), stringsAsFactors = FALSE)
    z$group <- if (is.null(gc)) 'All' else as.character(d[[gc]])
    # Keep optional supplied-stat columns alongside normalized observations.
    for (nm in names(d)) if (!(nm %in% names(z))) z[[nm]] <- d[[nm]]
  } else {
    if (is.null(idc)) idc <- cn[1]
    feature_cols <- setdiff(cn, idc); numeric_cols <- feature_cols[vapply(d[feature_cols], function(x) any(is.finite(suppressWarnings(as.numeric(x)))), logical(1))]
    if (!length(numeric_cols)) fail('Wide input has no numeric feature columns', '', 'Use an id column followed by numeric feature columns.')
    z <- do.call(rbind, lapply(numeric_cols, function(f) data.frame(feature = f, value = suppressWarnings(as.numeric(d[[f]])), id = as.character(d[[idc]]), group = if (is.null(gc)) 'All' else as.character(d[[gc]]), stringsAsFactors = FALSE)))
  }
  z <- z[!is.na(z$value) & is.finite(z$value) & nzchar(z$feature), , drop = FALSE]
  if (!nrow(z)) fail('No valid numeric rows remain')
  fi <- vec(val('features_include')); fe <- vec(val('features_exclude'))
  if (length(fi)) { z <- z[z$feature %in% fi, , drop = FALSE]; filtered <- TRUE }
  if (length(fe)) { z <- z[!z$feature %in% fe, , drop = FALSE]; filtered <- TRUE }
  if (!nrow(z)) fail('No features remain after filtering')
  features <- unique(z$feature); order_req <- vec(val('feature_order', NULL, c('features_order')))
  if (length(order_req)) features <- unique(c(order_req, features)); features <- features[features %in% unique(z$feature)]
  sort_features <- tolower(as.character(val('sort_features', 'none'))); sort_by <- tolower(as.character(val('sort_by', 'feature')))
  if (!length(order_req) && sort_features %in% c('ascending','descending')) { s <- if (sort_by %in% c('mean','median','value')) tapply(z$value, z$feature, if (sort_by == 'median') median else mean) else setNames(seq_along(features), features); features <- names(sort(s, decreasing = sort_features == 'descending')) }
  if (boo('reverse_features')) features <- rev(features)
  top_n <- as.integer(num('top_n', 0)); if (top_n > 0) { features <- features[seq_len(min(top_n, length(features)))]; filtered <- TRUE }
  z <- z[z$feature %in% features, , drop = FALSE]; z$feature <- factor(z$feature, levels = features)
  if (!nrow(z)) fail('No rows remain after feature selection')
  write.csv(z, file.path(out, 'distribution_data_used.csv'), row.names = FALSE)
  if (filtered || length(rows_inc) || length(rows_exc)) write.csv(z, file.path(out, 'selected_rows.csv'), row.names = FALSE)

  # Compute the shared density coordinates once; these are also the Plotly cloud traces.
  xlim <- suppressWarnings(as.numeric(unlist(val('x_limits', NULL)))); xlim <- xlim[is.finite(xlim)]
  if (length(xlim) != 2) xlim <- range(z$value, finite = TRUE)
  if (xlim[1] == xlim[2]) xlim <- xlim + c(-.5, .5)
  if (xlim[1] > xlim[2]) xlim <- rev(xlim)
  adjust <- max(.01, num('cloud_adjust', 1)); bw_param <- num('cloud_bandwidth', NA_real_); trim <- boo('cloud_trim', FALSE)
  # ChiPlot sample-count controls density grid resolution
  dens_n <- as.integer(num('sample_count', 160, c('density_n', 'ridge_sample_count')))
  dens_n <- max(32, min(1024, dens_n * 16))  # UI 10 → ~160 bins
  density_one <- function(x) {
    if (length(x) < 2 || diff(range(x)) == 0) { xx <- seq(xlim[1], xlim[2], length.out = dens_n); yy <- dnorm(xx, mean(x), max(diff(xlim) / 50, .001)); return(data.frame(x = xx, density = yy)) }
    bw <- if (is.finite(bw_param) && bw_param > 0) bw_param else stats::bw.nrd0(x) * adjust
    if (!is.finite(bw) || bw <= 0) bw <- max(diff(xlim) / 50, .001)
    stats::density(x, from = xlim[1], to = xlim[2], n = dens_n, bw = bw, cut = if (trim) 0 else 3)
  }
  show_cloud <- boo('cloud_show', TRUE); cloud_stat <- tolower(as.character(val('cloud_stat', 'density')))
  groups <- unique(as.character(z$group)); requested_groups <- vec(val('group_order'))
  if (length(requested_groups)) groups <- unique(c(requested_groups, groups))
  z$group <- factor(as.character(z$group), levels = groups)
  fill_mode <- tolower(as.character(val('fill_mode', val('cloud_fill_mode', 'feature'), c('cloud_fill_mode'))))
  group_overlay <- boo('group_overlay', TRUE)
  pal_default <- c('#4E79A7','#F28E2B','#E15759','#59A14F','#B07AA1','#76B7B2','#EDC948','#FF9DA7','#9C755F','#BAB0AC')
  palette_value <- val('group_colors', NULL, c('cloud_colors','point_colors','palette')); pv <- unlist(palette_value, use.names = TRUE); if (!length(pv)) pv <- pal_default
  if (!is.null(val('cloud_color', NULL))) pv <- as.character(val('cloud_color', pal_default[1]))
  color_for <- function(key, index) { if (!is.null(names(pv)) && key %in% names(pv)) as.character(pv[[key]]) else as.character(pv[(index - 1) %% length(pv) + 1]) }
  ridge_spacing <- num('row_spacing', num('ridge_spacing', 1)); ridge_height <- num('ridge_height', .82); overlap <- num('ridge_overlap', .15); cloud_scale <- num('cloud_scale', 1)
  bases <- (length(features):1) * ridge_spacing; names(bases) <- features
  clouds <- list(); cloud_i <- 0
  for (f in features) {
    sub <- z[as.character(z$feature) == f, , drop = FALSE]
    cloud_groups <- if (fill_mode %in% c('group','groups')) groups[groups %in% unique(as.character(sub$group))] else 'All'
    for (g in cloud_groups) { vals <- if (g == 'All') sub$value else sub$value[as.character(sub$group) == g]; if (!length(vals)) next; den <- density_one(vals); h <- den$y / max(den$y); h <- h * ridge_height * cloud_scale * (1 + overlap); b <- bases[[f]]; if (!group_overlay && g != 'All') b <- b - (match(g, groups) - 1) * ridge_spacing * .55; cloud_i <- cloud_i + 1; clouds[[cloud_i]] <- data.frame(feature = f, group = g, baseline = b, x = den$x, y = b + h, density = den$y, colour = color_for(if (fill_mode %in% c('group','groups')) g else f, if (fill_mode %in% c('group','groups')) match(g, groups) else match(f, features)), key = if (fill_mode %in% c('group','groups')) g else f, stringsAsFactors = FALSE) }
  }
  cloud_df <- if (length(clouds)) do.call(rbind, clouds) else data.frame()
  set.seed(as.integer(num('point_jitter_seed', 12345))); point_df <- z
  point_sample <- as.integer(num('point_density_sample', 0)); if (point_sample > 0 && nrow(point_df) > point_sample) point_df <- point_df[sort(sample(seq_len(nrow(point_df)), point_sample)), , drop = FALSE]
  point_df$y <- bases[as.character(point_df$feature)] - runif(nrow(point_df), 0, max(0, num('point_jitter_height', .13))) * ridge_spacing
  point_df$y <- point_df$y + runif(nrow(point_df), -.5, .5) * num('point_jitter_width', .06) * ridge_spacing
  if (tolower(as.character(val('point_position', 'below'))) %in% c('baseline','on_baseline')) point_df$y <- bases[as.character(point_df$feature)]

  # Summary overlays are represented as simple, portable segments/rectangles.
  box_df <- data.frame(); q_df <- data.frame()
  quantile_value <- suppressWarnings(as.numeric(unlist(val('quantile', .5))[1])); if (!is.finite(quantile_value)) quantile_value <- .5; quantile_value <- max(0, min(1, quantile_value))
  for (f in features) { x <- z$value[as.character(z$feature) == f]; qs <- quantile(x, c(.05,.25,.5,.75,.95), names = FALSE, na.rm = TRUE); b <- bases[[f]]; box_df <- rbind(box_df, data.frame(feature = f, xmin = qs[2], xmax = qs[4], ymin = b, ymax = b + num('box_height', .16) * ridge_spacing, low = qs[1], high = qs[5], median = qs[3])); qx <- quantile(x, quantile_value, names = FALSE, na.rm = TRUE); q_df <- rbind(q_df, data.frame(feature = f, x = qx, xend = qx, y = b, yend = b + num('box_height', .16) * ridge_spacing)) }
  br <- suppressWarnings(as.numeric(unlist(val('x_breaks', NULL)))); br <- br[is.finite(br)]
  xexpand <- suppressWarnings(as.numeric(unlist(val('x_expand', c(.04, .04))))); if (length(xexpand) != 2) xexpand <- c(.04, .04)
  yexpand <- suppressWarnings(as.numeric(unlist(val('y_expand', c(.08, .12))))); if (length(yexpand) != 2) yexpand <- c(.08, .12)
  q <- ggplot()
  # ChiPlot aliases: fill_opacity, stroke-as-fill, ridge stroke, sample-count, quantile 50%
  cloud_alpha <- num('cloud_alpha', num('fill_opacity', .75, c('ridge_fill_opacity')))
  outline_show <- boo('cloud_outline_show', FALSE, c('ridge_outline_show', 'stroke_show'))
  stroke_as_fill <- boo('stroke_as_fill', FALSE, c('ridge_stroke_as_fill', 'stroke-as-fill'))
  stroke_w <- num('cloud_stroke_width', .4, c('ridge_stroke_width', 'stroke_width')) * num('cloud_stroke_alpha', 1, c('stroke_opacity', 'ridge_stroke_opacity'))
  if (show_cloud && nrow(cloud_df)) {
    outline_color <- val('group_outline_color', val('cloud_stroke', '#333333', c('ridge_stroke', 'stroke')))
    outline_width <- num('group_outline_width', stroke_w, c('cloud_stroke_width', 'ridge_stroke_width', 'stroke_width'))
    q <- q + geom_ribbon(data = cloud_df, aes(x = x, ymin = baseline, ymax = y, group = interaction(feature, group), fill = key),
      colour = if (outline_show || boo('group_outline_show', FALSE)) outline_color else NA,
      alpha = num('group_alpha', cloud_alpha, c('cloud_alpha', 'fill_opacity', 'ridge_fill_opacity')), linewidth = outline_width)
  }
  if (boo('baseline_show', boo('cloud_baseline', TRUE))) q <- q + geom_segment(data = data.frame(feature = features, y = unname(bases)), aes(x = xlim[1], xend = xlim[2], y = y, yend = y), colour = val('baseline_color', val('cloud_stroke', '#777777')), linewidth = num('baseline_width', .35), linetype = val('baseline_linetype', 'solid'), alpha = num('baseline_alpha', .7))
  # point_show + fill-as-box (ChiPlot): optional rug points under ridges
  if (boo('point_show', FALSE, c('point_switch')) && nrow(point_df)) {
    pt_fill_as_box <- boo('point_fill_as_box', FALSE, c('fill_as_box', 'fill-as-box'))
    pt_size <- num('point_size', 1.8, c('point_r', 'r'))
    if (pt_size > 3) pt_size <- pt_size / 2.5
    pt_col <- val('point_color', NULL)
    if (!is.null(pt_col) && !pt_fill_as_box) {
      q <- q + geom_point(data = point_df, aes(x = value, y = y), colour = as.character(pt_col)[1], shape = as.numeric(num('point_shape', 16)), size = pt_size, alpha = num('point_alpha', .75, c('point_fill_opacity')), stroke = num('point_stroke', .25, c('point_stroke_width')))
    } else {
      q <- q + geom_point(data = point_df, aes(x = value, y = y, colour = group), shape = as.numeric(num('point_shape', 16)), size = pt_size, alpha = num('point_alpha', .75, c('point_fill_opacity')), stroke = num('point_stroke', .25, c('point_stroke_width')))
    }
  }
  if (boo('box_show', FALSE)) q <- q + geom_rect(data = box_df, aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax), fill = val('box_fill', '#FFFFFF'), alpha = num('box_alpha', .7), colour = val('box_stroke', '#333333'), linewidth = num('box_stroke_width', .4), inherit.aes = FALSE) + geom_segment(data = box_df, aes(x = low, xend = high, y = ymin + (ymax-ymin)/2, yend = ymin + (ymax-ymin)/2), colour = val('box_stroke', '#333333'), linewidth = num('box_stroke_width', .4))
  if (boo('median_show', TRUE) && boo('box_show', FALSE)) q <- q + geom_segment(data = box_df, aes(x = median, xend = median, y = ymin, yend = ymax), colour = val('median_color', '#222222'), linewidth = num('median_width', 1))
  # quantile_line_show or ChiPlot "quantiles line 50%"
  q50 <- boo('quantile_line_show', FALSE, c('quantile_50', 'show_quantile_50', 'median_line_show'))
  if (q50) q <- q + geom_segment(data = q_df, aes(x = x, xend = xend, y = y, yend = yend), colour = val('quantile_line_color', '#222222', c('quantile_stroke')), linewidth = num('quantile_line_width', .7, c('quantile_stroke_width')), linetype = val('quantile_line_type', 'dashed', c('quantile_linetype')))
  if (length(vec(val('highlight_features')))) { h <- intersect(vec(val('highlight_features')), as.character(features)); if (length(h)) q <- q + geom_rect(data = data.frame(feature = h, ymin = bases[h] - ridge_spacing*.2, ymax = bases[h] + ridge_spacing, xmin = -Inf, xmax = Inf), aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax), fill = val('highlight_color', '#FFD166'), alpha = num('highlight_alpha', .12), inherit.aes = FALSE) }
  point_palette <- unlist(val('point_colors', NULL, c('group_colors','palette')), use.names = TRUE); if (!length(point_palette)) point_palette <- pal_default; if (!is.null(val('point_color', NULL))) point_palette <- as.character(val('point_color', point_palette[1])); if (length(point_palette) < length(groups)) point_palette <- rep(point_palette, length.out = length(groups)); names(point_palette) <- groups
  if (boo('point_show', FALSE, c('point_switch'))) {
    q <- q + scale_colour_manual(values = point_palette, name = val('legend_title', 'Group'), drop = FALSE)
  }
  statistic_show <- boo('statistic_show', FALSE)
  statistic_method <- tolower(as.character(val('statistic_method', 'none')))
  stat_cols <- vec(val('statistic_columns', c('d', 'p')))
  stat_df <- data.frame()
  if (statistic_show && statistic_method != 'none') {
    stat_rows <- lapply(as.character(features), function(f) {
      s <- z[as.character(z$feature) == f, , drop = FALSE]
      gs <- unique(as.character(s$group)); gs <- gs[nzchar(gs)]
      vals <- lapply(gs, function(g) s$value[as.character(s$group) == g])
      vals <- vals[vapply(vals, length, integer(1)) > 0]
      dval <- pval <- NA_real_
      if (statistic_method %in% c('cohen_d', 't_test', 'wilcoxon') && length(vals) >= 2) {
        a <- vals[[1]]; b <- vals[[2]]
        pooled <- sqrt(((length(a) - 1) * stats::var(a) + (length(b) - 1) * stats::var(b)) / max(1, length(a) + length(b) - 2))
        dval <- if (is.finite(pooled) && pooled > 0) (mean(b) - mean(a)) / pooled else NA_real_
        pval <- tryCatch(if (statistic_method == 't_test') stats::t.test(a, b)$p.value else if (statistic_method == 'wilcoxon') stats::wilcox.test(a, b, exact = FALSE)$p.value else stats::t.test(a, b)$p.value, error = function(e) NA_real_)
      }
      if (statistic_method == 'supplied') {
        mapping <- val('statistic_columns', c('d', 'p'))
        if (is.list(mapping) && !is.null(names(mapping))) { stat_cols <<- names(mapping); source_cols <- unlist(mapping, use.names = FALSE) } else source_cols <- stat_cols
        out <- setNames(rep(NA_character_, length(stat_cols)), stat_cols)
        for (i in seq_along(stat_cols)) { source <- if (length(source_cols) >= i) source_cols[i] else stat_cols[i]; hit <- names(s)[tolower(names(s)) == tolower(source)][1]; if (!is.na(hit)) { ok <- which(!is.na(s[[hit]])); if (length(ok)) out[i] <- as.character(s[[hit]][ok[1]]) } }
        return(data.frame(feature = f, d = if ('d' %in% names(out)) out[['d']] else NA, p = if ('p' %in% names(out)) out[['p']] else NA, stringsAsFactors = FALSE))
      }
      data.frame(feature = f, d = dval, p = pval, stringsAsFactors = FALSE)
    })
    stat_df <- do.call(rbind, stat_rows)
    digits <- as.integer(num('statistic_digits', 3)); label_map <- val('statistic_labels', NULL)
    stat_df$label <- vapply(seq_len(nrow(stat_df)), function(i) {
      parts <- character()
      for (col in stat_cols) if (col %in% names(stat_df) && is.finite(suppressWarnings(as.numeric(stat_df[i, col])))) {
        label <- if (is.list(label_map) && !is.null(label_map[[col]])) as.character(label_map[[col]]) else if (length(label_map) >= match(col, stat_cols) && is.null(names(label_map))) as.character(unlist(label_map)[match(col, stat_cols)]) else col
        parts <- c(parts, paste0(label, '=', formatC(as.numeric(stat_df[i, col]), format = 'f', digits = digits)))
      }
      paste(parts, collapse = '  ')
    }, character(1))
    position <- tolower(as.character(val('statistic_position', 'right')))
    stat_df$x <- num('statistic_x', if (position == 'left') xlim[1] else xlim[2]); stat_df$y <- unname(bases[stat_df$feature]) + num('statistic_y_offset', 0)
    stat_df <- stat_df[nzchar(stat_df$label), , drop = FALSE]
    if (nrow(stat_df)) q <- q + geom_text(data = stat_df, aes(x = x, y = y, label = label), hjust = if (position == 'right') 0 else 1, colour = val('statistic_color', '#333333'), size = num('statistic_size', 3.5))
  }
  if (fill_mode %in% c('group', 'groups') && boo('group_legend_show', TRUE)) {
    group_palette <- setNames(vapply(seq_along(groups), function(i) color_for(groups[i], i), character(1)), groups)
    q <- q + scale_fill_manual(values = group_palette, name = val('group_legend_title', val('legend_title', 'Group')), drop = FALSE)
  }
  q <- q + scale_x_continuous(breaks = if (length(br)) br else waiver(), expand = expansion(mult = xexpand)) + scale_y_continuous(breaks = unname(bases), labels = if (boo('feature_label_show', TRUE)) names(bases) else NULL, expand = expansion(mult = yexpand)) + coord_cartesian(xlim = xlim, clip = 'off') + labs(x = val('xlab', 'Value'), y = val('ylab', NULL), title = if (boo('title_show', TRUE)) val('title', 'Distribution Ridgeline Plot') else NULL, subtitle = val('subtitle', NULL), caption = val('caption', NULL))
  q <- q + theme_minimal(base_size = num('base_size', 11), base_family = val('font_family', 'sans')) + theme(panel.background = element_rect(fill = val('panel_background', '#FFFFFF'), colour = NA), plot.background = element_rect(fill = val('plot_background', '#FFFFFF'), colour = NA), panel.grid = if (boo('grid_show', TRUE)) element_line(colour = val('grid_color', '#E6E6E6'), linewidth = num('grid_width', .35), linetype = val('grid_linetype', 'solid')) else element_blank(), axis.line = if (boo('axis_line_show', TRUE)) element_line(colour = val('axis_line_color', '#555555'), linewidth = num('axis_line_width', .4)) else element_blank(), axis.ticks = if (boo('tick_show', TRUE)) element_line(colour = val('tick_color', '#555555'), linewidth = num('tick_width', .4)) else element_blank(), axis.text.x = element_text(size = num('x_axis_text_size', 10), colour = val('x_axis_text_color', '#333333'), angle = num('x_axis_text_angle', 0)), axis.text.y = element_text(size = num('feature_label_size', num('y_axis_text_size', 10)), colour = val('feature_label_color', val('y_axis_text_color', '#333333')), angle = num('feature_label_angle', num('y_axis_text_angle', 0)), face = val('feature_label_face', 'plain'), family = val('feature_label_family', val('font_family', 'sans'))), axis.title = element_text(colour = val('axis_line_color', '#333333')), plot.title = element_text(size = num('title_size', 16), colour = val('title_color', '#222222'), face = val('title_face', 'bold'), hjust = num('title_hjust', 0)), plot.subtitle = element_text(size = num('subtitle_size', 11), colour = val('subtitle_color', '#555555'), face = val('subtitle_face', 'plain')), panel.border = if (boo('panel_border_show', FALSE)) element_rect(fill = NA, colour = val('panel_border_color', '#555555'), linewidth = num('panel_border_width', .5)) else element_blank(), legend.position = if (boo('legend_show', FALSE)) val('legend_position', 'right') else 'none', legend.title = element_text(size = num('legend_title_size', 10)), legend.text = element_text(size = num('legend_text_size', 9)), plot.margin = grid::unit(c(num('margin_top', .5), num('margin_right', .5), num('margin_bottom', .5), num('margin_left', .5)), 'cm'))
  if (!boo('x_axis_show', TRUE)) q <- q + theme(axis.text.x = element_blank(), axis.ticks.x = element_blank(), axis.title.x = element_blank())
  if (!boo('y_axis_show', TRUE)) q <- q + theme(axis.text.y = element_blank(), axis.ticks.y = element_blank(), axis.title.y = element_blank())
  if (fill_mode %in% c('group', 'groups') && boo('group_legend_show', TRUE)) q <- q + theme(legend.position = val('group_legend_position', 'right'))

  w <- num('width', 10); h <- num('height', max(5, length(features) * .85)); if (!is.null(val('aspect_ratio', NULL))) h <- w / num('aspect_ratio', w/h); dpi <- num('dpi', 300); formats <- tolower(vec(val('export_formats', c('svg','pdf','png','html')))); if (!length(formats)) formats <- c('svg','pdf','png','html')
  if ('svg' %in% formats) ggsave(file.path(out, 'result.svg'), q, width = w, height = h, units = 'in', dpi = dpi)
  if ('pdf' %in% formats) ggsave(file.path(out, 'result.pdf'), q, width = w, height = h, units = 'in')
  if ('png' %in% formats) ggsave(file.path(out, 'result.png'), q, width = w, height = h, units = 'in', dpi = dpi)

  # Plotly receives the same coordinates, preserving the static/interactive view.
  if (boo('interactive', TRUE) && requireNamespace('plotly', quietly = TRUE) && requireNamespace('htmlwidgets', quietly = TRUE)) {
    pl <- plotly::plot_ly(width = as.integer(num('html_width', w*dpi)), height = as.integer(num('html_height', h*dpi)))
    if (show_cloud && nrow(cloud_df)) for (key in unique(interaction(cloud_df$feature, cloud_df$group, drop = TRUE))) { a <- cloud_df[interaction(cloud_df$feature, cloud_df$group, drop = TRUE) == key, ]; poly <- rbind(data.frame(x = a$x, y = a$y), data.frame(x = rev(a$x), y = rep(bases[[as.character(a$feature[1])]], nrow(a)))); pl <- plotly::add_trace(pl, x = poly$x, y = poly$y, type = 'scatter', mode = 'lines', fill = 'toself', fillcolor = a$colour[1], line = list(color = if (boo('cloud_outline_show', FALSE)) val('cloud_stroke', '#333333') else a$colour[1], width = num('cloud_stroke_width', .5)), opacity = num('cloud_alpha', .75), name = as.character(a$feature[1]), legendgroup = as.character(a$feature[1]), hoverinfo = 'name') }
    if (boo('point_show', TRUE) && nrow(point_df)) for (g in unique(as.character(point_df$group))) { a <- point_df[as.character(point_df$group) == g, ]; pl <- plotly::add_trace(pl, x = a$value, y = a$y, type = 'scatter', mode = 'markers', name = g, text = paste0(as.character(a$feature), '<br>Value: ', signif(a$value, 6), '<br>Sample: ', a$id), hoverinfo = 'text', marker = list(color = color_for(g, match(g, groups)), size = max(2, num('point_size', 1.8)*2), opacity = num('point_alpha', .75)), selected = list(marker = list(opacity = 1))) }
    pl <- plotly::layout(pl, title = list(text = if (boo('title_show', TRUE)) val('title', 'Distribution Ridgeline Plot') else ''), xaxis = list(title = val('xlab', 'Value'), range = xlim, tickvals = if (length(br)) br else NULL, showgrid = boo('grid_show', TRUE)), yaxis = list(title = val('ylab', ''), tickvals = unname(bases), ticktext = names(bases), range = c(min(bases)-ridge_spacing*.35, max(bases)+ridge_spacing*(1+overlap))), paper_bgcolor = val('plot_background', '#FFFFFF'), plot_bgcolor = val('panel_background', '#FFFFFF'), showlegend = boo('legend_show', FALSE))
    pl <- plotly::config(pl, displaylogo = FALSE, scrollZoom = boo('zoom', TRUE), modeBarButtonsToAdd = if (boo('lasso_select', TRUE) || boo('selectable', TRUE)) c('lasso2d','select2d') else character(), doubleClick = if (boo('reset_view', TRUE)) 'reset' else FALSE)
    htmlwidgets::saveWidget(pl, file.path(out, 'result.html'), selfcontained = TRUE)
  } else writeLines('<html><body><p>Interactive Plotly output is unavailable.</p></body></html>', file.path(out, 'result.html'))
  figure <- list(plugin = 'interactive_ridgeline_plot', input_mode = mode, features = as.character(features), groups = groups, rows = nrow(z), original_rows = original_n, filtered = filtered, shared_x_scale = boo('shared_x_scale', TRUE), x_limits = xlim, cloud_rows = nrow(cloud_df), outputs = c('result.svg','result.pdf','result.png','result.html','figure.json','distribution_data_used.csv','run.log'))
  writeLines(toJSON(figure, auto_unbox = TRUE, pretty = TRUE), file.path(out, 'figure.json'))
  if (file.exists(file.path(out, 'error.json'))) unlink(file.path(out, 'error.json'))
  logmsg(sprintf('Rendered %d values across %d features and %d groups', nrow(z), length(features), length(groups)))
}, error = function(e) fail('Plot generation failed', conditionMessage(e)))
