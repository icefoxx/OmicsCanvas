#!/usr/bin/env Rscript

# OmicsCanvas: Interactive Enrichment Lollipop
# ------------------------------------------------------------
# Horizontal (default) or vertical zero-centered lollipop / Cleveland
# plot with group colors, optional size mapping, stems, zero line,
# labels, and full axis/title/legend/export controls.
#
# Also accepts CAB_demo-style aliases:
#   min_radius / max_radius, type_colors, lollipop_*, stem/line style, etc.
#
# Runtime:
#   Rscript plot.R --input input.csv --params params.json --output output_dir

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
  library(ggrepel)
})

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

op <- parse_args(OptionParser(option_list = list(
  make_option('--input', type = 'character'),
  make_option('--params', type = 'character'),
  make_option('--output', type = 'character')
)))

out <- op$output %||% getwd()
dir.create(out, recursive = TRUE, showWarnings = FALSE)
err_path <- file.path(out, 'error.json')
if (file.exists(err_path)) unlink(err_path)
unlink(file.path(out, c('result.svg', 'result.pdf', 'result.png', 'result.html', 'figure.json')))

logmsg <- function(x) {
  cat(sprintf('[%s] %s\n', format(Sys.time(), '%F %T'), x),
      file = file.path(out, 'run.log'), append = TRUE)
}

fail <- function(m, d = '', s = 'Check input and params.') {
  unlink(file.path(out, c('result.svg', 'result.pdf', 'result.png', 'result.html', 'figure.json')))
  writeLines(
    toJSON(list(error = m, detail = d, suggestion = s), auto_unbox = TRUE, pretty = TRUE),
    err_path
  )
  message(m)
  quit(status = 1)
}

tryCatch({
  if (is.null(op$input) || !file.exists(op$input)) fail('Input file not found', as.character(op$input))
  p <- if (!is.null(op$params) && file.exists(op$params)) {
    fromJSON(op$params, simplifyVector = FALSE)
  } else {
    list()
  }

  readtab <- function(f) {
    if (tolower(tools::file_ext(f)) == 'csv') {
      read.csv(f, check.names = FALSE, stringsAsFactors = FALSE)
    } else {
      read.delim(f, check.names = FALSE, stringsAsFactors = FALSE)
    }
  }

  d <- readtab(op$input)
  cn <- names(d)
  lo <- tolower(cn)

  # `p` is reassigned to the ggplot object later; read params from a frozen copy
  # so options looked up after plotting starts (subtitle, backgrounds, ...) still apply.
  prm <- p
  val <- function(n, z = NULL) {
    if (!is.null(prm[[n]])) return(prm[[n]])
    z
  }
  # first matching alias
  val_any <- function(names, z = NULL) {
    for (n in names) {
      if (!is.null(prm[[n]])) return(prm[[n]])
    }
    z
  }
  bool <- function(names, z = FALSE) {
    if (is.character(names) && length(names) == 1 && !names %in% names(prm) && grepl('_', names)) {
      # single name
      x <- val(names, z)
    } else if (is.character(names) && length(names) > 1) {
      x <- val_any(names, z)
    } else {
      x <- val(names, z)
    }
    if (is.null(x)) return(z)
    if (is.logical(x)) return(isTRUE(x[1]))
    tolower(as.character(x[1])) %in% c('true', '1', 'yes', 'y', 'on')
  }
  num <- function(names, z) {
    x <- if (length(names) > 1) val_any(names, z) else val(names, z)
    x <- suppressWarnings(as.numeric(unlist(x)[1]))
    if (is.na(x)) z else x
  }
  vec <- function(x) {
    if (is.null(x)) character() else trimws(as.character(unlist(x)))
  }
  named_chr <- function(x) {
    if (is.null(x)) return(character())
    u <- unlist(x, use.names = TRUE)
    if (length(u) == 0) return(character())
    setNames(as.character(u), names(u))
  }

  colfind <- function(requested, aliases, required = FALSE) {
    i <- match(tolower(requested %||% ''), lo)
    if (!is.na(i)) return(cn[i])
    i <- match(tolower(aliases), lo)
    i <- i[!is.na(i)]
    if (length(i)) cn[i[1]] else if (required) {
      fail('Required column not found', paste(aliases, collapse = ', '))
    } else {
      NULL
    }
  }

  logmsg('Plugin interactive_enrichment_lollipop started.')

  cc <- colfind(
    val_any(c('category_column', 'label_column', 'y_column', 'term_column'), NULL),
    c('category', 'term', 'pathway', 'description', 'label', 'name', 'id'),
    TRUE
  )
  vc <- colfind(
    val_any(c('value_column', 'x_column', 'effect_column', 'score_column'), NULL),
    c('effect', 'value', 'nes', 'enrichment', 'score', 'log2fc', 'estimate', 'stat'),
    TRUE
  )
  gc <- colfind(
    val_any(c('group_column', 'type_column', 'class_column', 'color_column'), NULL),
    c('group', 'type', 'class', 'cluster'),
    FALSE
  )
  sc <- colfind(
    val_any(c('size_column', 'radius_column', 'weight_column'), NULL),
    c('size', 'count', 'gene_count', 'n', 'set_size', 'weight'),
    FALSE
  )
  lc <- colfind(val('label_column', NULL), c('label', 'annotation', 'text'), FALSE)
  pc <- colfind(
    val('pvalue_column', NULL),
    c('pvalue', 'p_value', 'p.val', 'pval', 'fdr', 'padj', 'qvalue'),
    FALSE
  )

  z <- data.frame(
    category = as.character(d[[cc]]),
    value = suppressWarnings(as.numeric(d[[vc]])),
    group = if (is.null(gc)) 'All' else as.character(d[[gc]]),
    size = if (is.null(sc)) NA_real_ else suppressWarnings(as.numeric(d[[sc]])),
    label = if (is.null(lc)) as.character(d[[cc]]) else as.character(d[[lc]]),
    pvalue = if (is.null(pc)) NA_real_ else suppressWarnings(as.numeric(d[[pc]])),
    stringsAsFactors = FALSE
  )
  valid <- is.finite(z$value) & !is.na(z$category) & nzchar(z$category)
  logmsg(sprintf('Dropped %d rows with missing labels or non-finite effects.', sum(!valid)))
  z <- z[valid, , drop = FALSE]

  size_transform <- as.character(val('size_transform', 'identity'))
  if (size_transform == 'neg_log10_pvalue') {
    if (is.null(pc)) fail('P-value column required', 'Set pvalue_column to a raw or adjusted p-value column.')
    valid_p <- is.finite(z$pvalue) & z$pvalue >= 0 & z$pvalue <= 1
    if (!all(valid_p)) fail('Invalid p-values', 'P-values must be finite numbers between 0 and 1; missing values are not accepted in this size mode.')
    if (any(z$pvalue == 0)) logmsg('Zero p-values were floored at the smallest positive double for size transformation.')
    z$size <- -log10(pmax(z$pvalue, .Machine$double.xmin))
  }

  # Size: use size column, or |value| when size mapping is on without a size column
  size_map <- bool(c('size_switch', 'lollipop_size_switch', 'map_size', 'size_scale'), TRUE)
  if (all(is.na(z$size))) {
    z$size <- if (size_map) abs(z$value) else 1
  }
  z$size[is.na(z$size)] <- 1

  # Filters
  inc <- vec(val_any(c('rows_include', 'categories_include'), NULL))
  exc <- vec(val_any(c('rows_exclude', 'categories_exclude'), NULL))
  if (length(inc)) z <- z[z$category %in% inc | seq_len(nrow(z)) %in% suppressWarnings(as.integer(inc)), , drop = FALSE]
  if (length(exc)) z <- z[!(z$category %in% exc | seq_len(nrow(z)) %in% suppressWarnings(as.integer(exc))), , drop = FALSE]
  tinc <- vec(val_any(c('types_include', 'groups_include'), NULL))
  texc <- vec(val_any(c('types_exclude', 'groups_exclude'), NULL))
  if (length(tinc)) z <- z[z$group %in% tinc, , drop = FALSE]
  if (length(texc)) z <- z[!z$group %in% texc, , drop = FALSE]
  if (!nrow(z)) fail('No valid rows remain')

  # Order
  sb <- tolower(as.character(val_any(c('sort_by', 'order_by'), 'input')[1] %||% 'input'))
  so <- tolower(as.character(val_any(c('sort', 'sort_direction'), 'descending')[1] %||% 'descending'))
  if (sb %in% c('input', 'none', 'original')) {
    # keep file order
  } else if (sb %in% c('category', 'term', 'name')) {
    z <- z[order(z$category), , drop = FALSE]
  } else if (sb == 'size') {
    z <- z[order(z$size, decreasing = so != 'ascending'), , drop = FALSE]
  } else if (sb %in% c('group', 'type', 'type_value')) {
    z <- z[order(z$group, -abs(z$value)), , drop = FALSE]
  } else {
    z <- z[order(z$value, decreasing = so != 'ascending'), , drop = FALSE]
  }
  top <- as.integer(num('top_n', 0))
  if (top > 0) z <- z[seq_len(min(top, nrow(z))), , drop = FALSE]

  co <- vec(val_any(c('category_order', 'label_order'), NULL))
  z$category <- factor(
    z$category,
    levels = if (length(co)) unique(c(co, as.character(z$category))) else unique(z$category)
  )
  # CAB_demo / image: first rows at top → reverse factor for horizontal
  reverse_cat <- bool(c('reverse_categories', 'reverse_y', 'reverse_category'), TRUE)
  if (reverse_cat) z$category <- factor(z$category, levels = rev(levels(z$category)))

  go <- vec(val_any(c('group_order', 'type_order', 'legend_order'), NULL))
  # Without an explicit order, follow the order the user listed colours in.
  if (!length(go)) go <- names(named_chr(val_any(c('group_colors', 'type_colors', 'lollipop_colors', 'color_map'), NULL)))
  if (length(go)) {
    z$group <- factor(z$group, levels = unique(c(go, unique(as.character(z$group)))))
  } else {
    z$group <- factor(z$group, levels = unique(as.character(z$group)))
  }

  # Coordinates
  orientation <- tolower(as.character(val_any(c('orientation', 'type'), 'horizontal')[1] %||% 'horizontal'))
  horizontal <- orientation %in% c('horizontal', 'horiz', 'h')

  z$.x <- z$value
  z$.y <- as.numeric(z$category)
  if (bool('dodge', FALSE) && nlevels(z$group) > 1) {
    z$.y <- z$.y + (as.numeric(z$group) - mean(seq_len(nlevels(z$group)))) *
      num(c('dodge_width', 'padding'), 0.65) / max(1, nlevels(z$group))
  }

  # Colors — CAB_demo type_colors / group_colors / color_map
  groups <- levels(z$group)
  default_pal <- c('#66C2A5', '#FC8D62', '#8DA0CB', '#E78AC3', '#A6D854', '#FFD92F', '#B3B3B3')
  pal <- setNames(rep(default_pal, length.out = length(groups)), groups)
  for (key in c('group_colors', 'type_colors', 'lollipop_colors', 'category_colors', 'color_map')) {
    gm <- named_chr(val(key, NULL))
    if (length(gm)) {
      hit <- intersect(names(gm), groups)
      pal[hit] <- gm[hit]
    }
  }

  # Style params (CAB_demo aliases)
  stem_show <- bool(c('stem_show', 'line_show', 'show_stem'), TRUE)
  stem_color <- as.character(val_any(c('stem_color', 'line_color', 'line_stroke'), '#B0B0B0')[1] %||% '#B0B0B0')
  stem_width <- num(c('stem_width', 'line_width', 'line_stroke_width'), 0.7)
  stem_alpha <- num(c('stem_alpha', 'line_opacity', 'line_stroke_opacity'), 0.9)
  stem_lty <- as.character(val_any(c('stem_linetype', 'line_type', 'line_linetype'), 'solid')[1] %||% 'solid')
  # stroke-dasharray empty → solid; if non-empty treat as dashed
  dash <- val_any(c('stroke_dasharray', 'line_dasharray'), NULL)
  if (!is.null(dash) && nzchar(as.character(dash)[1])) stem_lty <- 'dashed'

  zero_show <- bool(c('zero_line_show', 'show_zero_line'), TRUE)
  zero_color <- as.character(val_any(c('zero_line_color'), '#888888')[1] %||% '#888888')
  zero_width <- num(c('zero_line_width'), 0.5)
  zero_lty <- as.character(val_any(c('zero_line_linetype'), 'solid')[1] %||% 'solid')

  # Point / lollipop head
  # CAB_demo r=8 is fixed radius when size switch off; min/max when on
  size_switch <- size_map
  r_fixed <- num(c('r', 'point_size', 'lollipop_r'), 8)
  # convert CSS-ish radius to ggplot size roughly
  # point_size_min/max are ggplot size units; min_radius/max_radius (and the
  # defaults) are CAB_demo px radii, converted with the same factor at both ends
  # so the size range is never compressed.
  px_to_size <- function(x) x / 2.5
  pt_min <- num('point_size_min', NA)
  if (is.na(pt_min)) pt_min <- px_to_size(num(c('min_radius', 'min-radius'), 4))
  pt_max <- num('point_size_max', NA)
  if (is.na(pt_max)) pt_max <- px_to_size(num(c('max_radius', 'max-radius'), 20))
  if (!size_switch) {
    # fixed size from r
    fixed_sz <- if (r_fixed > 3) r_fixed / 2.5 else r_fixed
    z$size <- fixed_sz
    pt_min <- fixed_sz
    pt_max <- fixed_sz
  }

  point_alpha <- num(c('point_alpha', 'fill_opacity', 'lollipop_fill_opacity', 'bar_fill_opacity'), 1)
  point_stroke <- num(c('point_stroke', 'lollipop_stroke_width', 'stroke_width'), 0)
  point_border <- as.character(val_any(c('point_border_color', 'lollipop_stroke', 'stroke'), '#000000')[1] %||% '#000000')
  point_shape <- as.integer(num(c('point_shape', 'shape'), if (point_stroke > 0) 21 else 16))
  # shape 16 ignores fill; for stroke use 21
  if (point_stroke > 0 && point_shape == 16) point_shape <- 21

  label_show <- bool(c('label_show', 'lollipop_text_show', 'show_label', 'bar_text_show'), FALSE)
  label_size_raw <- num(c('label_size', 'lollipop_text_size', 'font_size'), 3.5)
  label_size <- if (label_size_raw > 8) label_size_raw / ggplot2::.pt else label_size_raw
  label_color <- as.character(val_any(c('label_color', 'lollipop_text_fill', 'text_fill'), '#222222')[1] %||% '#222222')
  label_face <- as.character(val_any(c('label_face', 'lollipop_text_weight'), 'plain')[1] %||% 'plain')
  if (tolower(label_face) %in% c('bold', 'normal', 'italic')) {
    label_face <- switch(tolower(label_face), bold = 'bold', italic = 'italic', 'plain')
  }
  label_nudge_x <- num(c('label_nudge_x', 'lollipop_text_x'), 0)
  label_repel <- bool(c('label_repel'), FALSE)
  value_format <- as.character(val_any(c('value_format', 'lollipop_value_format'), '')[1] %||% '')

  # Title / axes / legend
  title_show <- bool(c('title_show'), TRUE)
  title <- as.character(val_any(c('title', 'title_text'), '')[1] %||% '')
  title_size <- num(c('title_size'), 14)
  title_color <- as.character(val_any(c('title_color', 'title_fill'), '#222222')[1] %||% '#222222')
  title_face <- as.character(val_any(c('title_face', 'title_font_weight'), 'plain')[1] %||% 'plain')
  if (tolower(title_face) == 'bold') title_face <- 'bold' else if (tolower(title_face) == 'normal') title_face <- 'plain'
  title_hjust <- num(c('title_hjust'), 0.5)

  xlab <- as.character(val_any(c('xlab', 'x_title'), '')[1] %||% '')
  ylab <- as.character(val_any(c('ylab', 'y_title'), '')[1] %||% '')
  # Axis titles are hidden by default (CAB_demo style) but shown when one is given.
  xlab_show <- bool(c('x_title_show', 'xlab_show'), nzchar(xlab))
  ylab_show <- bool(c('y_title_show', 'ylab_show'), nzchar(ylab))

  legend_show <- bool(c('legend_show'), TRUE)
  legend_title_raw <- trimws(as.character(val_any(c('legend_title', 'legend_name'), '')[1] %||% ''))
  if (!nzchar(legend_title_raw)) {
    legend_title <- if (!is.null(gc)) 'Group' else NULL
  } else {
    legend_title <- legend_title_raw
  }
  legend_position <- as.character(val('legend_position', 'right')[1] %||% 'right')
  legend_text_size <- num(c('legend_text_size'), 10)
  legend_title_size <- num(c('legend_title_size'), 11)
  show_size_legend <- bool(c('show_size_legend', 'size_legend_show'), TRUE) && size_switch
  size_legend_title_raw <- trimws(as.character(val_any(c('size_legend_title'), '')[1] %||% ''))
  if (!nzchar(size_legend_title_raw)) {
    size_key <- tolower(as.character(sc %||% ''))
    size_legend_title <- if (size_transform == 'neg_log10_pvalue') {
      paste0('-log10(', pc, ')')
    } else if (size_key %in% c('size', 'count', 'n', 'set_size', 'gene_count')) {
      'Set size'
    } else if (nzchar(size_key)) {
      sc
    } else {
      'Size'
    }
  } else {
    size_legend_title <- size_legend_title_raw
  }
  size_legend_breaks <- suppressWarnings(as.numeric(unlist(val('size_legend_breaks', NULL))))
  size_legend_breaks <- size_legend_breaks[is.finite(size_legend_breaks)]
  if (!length(size_legend_breaks) && show_size_legend) {
    rng <- range(z$size, na.rm = TRUE)
    if (all(is.finite(rng))) {
      br <- pretty(rng, n = 4)
      br <- br[br >= min(rng) - diff(rng) * 0.05 & br <= max(rng) + diff(rng) * 0.05]
      if (all(abs(z$size - round(z$size)) < 1e-8)) br <- unique(round(br))
      br <- br[is.finite(br) & br > 0]
      if (length(br) >= 2) size_legend_breaks <- br
    }
  }

  grid_show <- bool(c('grid_show'), TRUE)
  grid_color <- as.character(val_any(c('grid_major_color', 'grid_stroke', 'grid_color'), '#E5E5E5')[1] %||% '#E5E5E5')
  panel_border <- bool(c('panel_border_show', 'panel_border'), TRUE)
  panel_border_color <- as.character(val_any(c('panel_border_color'), '#444444')[1] %||% '#444444')
  axis_text_size <- num(c('axis_text_size', 'y_axis_text_size'), 10)
  axis_text_color <- as.character(val_any(c('axis_text_color'), '#333333')[1] %||% '#333333')
  x_axis_text_size <- num(c('x_axis_text_size', 'axis_text_size'), 10)
  y_axis_text_size <- num(c('y_axis_text_size', 'axis_text_size'), 10)

  x_limits <- unlist(val_any(c('x_limits', 'xlim'), NULL))
  if (length(x_limits) != 2) {
    xmin <- num(c('x_min', 'min_value'), NA)
    xmax <- num(c('x_max', 'max_value'), NA)
    if (is.finite(xmin) || is.finite(xmax)) {
      x_limits <- c(
        if (is.finite(xmin)) xmin else min(z$value, na.rm = TRUE) * 1.05,
        if (is.finite(xmax)) xmax else max(z$value, na.rm = TRUE) * 1.05
      )
    }
  } else {
    x_limits <- as.numeric(x_limits)
  }

  w <- num(c('width'), 9)
  h <- num(c('height'), 7)
  dpi <- as.integer(num(c('dpi'), 300))
  base_size <- num(c('base_size', 'font_size'), 11)
  font_family <- as.character(val_any(c('font_family'), 'sans')[1] %||% 'sans')
  margin_cm <- num(c('margin'), 0.4)
  color_mode <- as.character(val('color_mode', 'group'))
  central_labels <- identical(as.character(val('category_label_position', 'axis')), 'zero_opposite')
  direction_labels_show <- bool('direction_labels_show', FALSE)
  if (!horizontal && (central_labels || direction_labels_show)) {
    logmsg('Vertical orientation uses category-axis labels and omits horizontal enrichment arrows.')
    central_labels <- FALSE
    direction_labels_show <- FALSE
  }
  if (central_labels && length(x_limits) == 2 && (min(x_limits) >= 0 || max(x_limits) <= 0)) {
    fail('Zero must be inside the effect axis', 'Set x_limits to include negative and positive space for the labels.')
  }

  # Build plot
  if (horizontal) {
    p <- ggplot(z, aes(x = .data$.x, y = .data$.y))
  } else {
    p <- ggplot(z, aes(x = .data$.y, y = .data$.x))
  }

  if (stem_show && color_mode == 'value') {
    if (horizontal) {
      p <- p + geom_segment(aes(x = 0, xend = .data$.x, y = .data$.y, yend = .data$.y,
                                colour = .data$value), linewidth = stem_width, linetype = stem_lty, alpha = stem_alpha)
    } else {
      p <- p + geom_segment(aes(x = .data$.y, xend = .data$.y, y = 0, yend = .data$.x,
                                colour = .data$value), linewidth = stem_width, linetype = stem_lty, alpha = stem_alpha)
    }
  } else if (stem_show) {
    if (horizontal) {
      p <- p + geom_segment(
        aes(x = 0, xend = .data$.x, y = .data$.y, yend = .data$.y),
        colour = stem_color, linewidth = stem_width, linetype = stem_lty,
        alpha = stem_alpha, inherit.aes = FALSE
      )
    } else {
      p <- p + geom_segment(
        aes(x = .data$.y, xend = .data$.y, y = 0, yend = .data$.x),
        colour = stem_color, linewidth = stem_width, linetype = stem_lty,
        alpha = stem_alpha, inherit.aes = FALSE
      )
    }
  }

  if (zero_show) {
    if (horizontal) {
      p <- p + geom_vline(
        xintercept = 0, colour = zero_color,
        linewidth = zero_width, linetype = zero_lty
      )
    } else {
      p <- p + geom_hline(
        yintercept = 0, colour = zero_color,
        linewidth = zero_width, linetype = zero_lty
      )
    }
  }

  if (color_mode == 'value') {
    if (point_shape %in% c(21, 22, 23, 24, 25)) {
      p <- p + geom_point(aes(fill = .data$value, size = .data$size), shape = point_shape,
                          colour = if (point_stroke > 0) point_border else NA,
                          alpha = point_alpha, stroke = point_stroke) +
        scale_fill_gradient2(low = as.character(val('color_low', '#879B39')),
                             mid = as.character(val('color_mid', '#FFFFED')),
                             high = as.character(val('color_high', '#CB6582')),
                             midpoint = 0, name = if (nzchar(legend_title_raw)) legend_title_raw else vc)
    } else {
      p <- p + geom_point(aes(colour = .data$value, size = .data$size),
                          shape = point_shape, alpha = point_alpha, stroke = point_stroke)
    }
    p <- p +
      scale_colour_gradient2(low = as.character(val('color_low', '#879B39')),
                             mid = as.character(val('color_mid', '#FFFFED')),
                             high = as.character(val('color_high', '#CB6582')),
                             midpoint = 0, name = if (nzchar(legend_title_raw)) legend_title_raw else vc)
  } else if (point_shape %in% c(21, 22, 23, 24, 25)) {
    p <- p + geom_point(
      aes(fill = .data$group, size = .data$size),
      shape = point_shape,
      colour = if (point_stroke > 0) point_border else NA,
      stroke = point_stroke,
      alpha = point_alpha
    ) +
      scale_fill_manual(values = pal, name = legend_title, drop = FALSE)
  } else {
    p <- p + geom_point(
      aes(colour = .data$group, size = .data$size),
      shape = point_shape,
      alpha = point_alpha,
      stroke = point_stroke
    ) +
      scale_colour_manual(values = pal, name = legend_title, drop = FALSE)
  }

  if (size_switch) {
    p <- p + scale_size_continuous(
      range = c(pt_min, pt_max),
      name = size_legend_title,
      limits = if (size_transform == 'neg_log10_pvalue') c(0, max(z$size, size_legend_breaks, na.rm = TRUE)) else NULL,
      breaks = if (length(size_legend_breaks)) size_legend_breaks else waiver()
    )
  } else {
    p <- p + scale_size_identity(guide = 'none')
  }

  if (label_show) {
    lab_df <- z
    if (nzchar(value_format)) {
      # simple sprintf-like: if contains % use sprintf on value
      lab_df$label_out <- tryCatch(
        sprintf(value_format, lab_df$value),
        error = function(e) as.character(round(lab_df$value, 2))
      )
    } else {
      lab_df$label_out <- as.character(round(lab_df$value, 2))
    }
    if (label_repel) {
      p <- p + geom_text_repel(
        data = lab_df,
        aes(x = .data$.x, y = .data$.y, label = .data$label_out),
        size = label_size, colour = label_color, fontface = label_face,
        nudge_x = label_nudge_x, show.legend = FALSE, inherit.aes = FALSE
      )
    } else {
      p <- p + geom_text(
        data = lab_df,
        aes(x = .data$.x + label_nudge_x, y = .data$.y, label = .data$label_out),
        size = label_size, colour = label_color, fontface = label_face,
        hjust = if (label_nudge_x >= 0) 0 else 1,
        show.legend = FALSE, inherit.aes = FALSE
      )
    }
  }

  if (bool(c('pvalue_label_show'), FALSE)) {
    p <- p + geom_text(
      aes(label = ifelse(is.na(.data$pvalue), '', format.pval(.data$pvalue, digits = 2))),
      hjust = -0.1, size = label_size, show.legend = FALSE
    )
  }

  # Scales for category axis
  if (central_labels) {
    label_gap <- num('label_gap', 0.012) * max(diff(range(c(0, z$value))), .Machine$double.eps)
    p <- p + geom_text(aes(x = ifelse(.data$value >= 0, -label_gap, label_gap),
                           y = .data$.y, label = .data$label,
                           hjust = ifelse(.data$value >= 0, 1, 0)),
                       size = label_size, colour = label_color, fontface = label_face,
                       show.legend = FALSE, inherit.aes = FALSE)
  }
  if (horizontal) {
    p <- p + scale_y_continuous(
      breaks = seq_along(levels(z$category)),
      labels = if (central_labels) NULL else levels(z$category),
      expand = expansion(mult = c(0.02, 0.02))
    )
    if (length(x_limits) == 2 && all(is.finite(x_limits))) {
      p <- p + scale_x_continuous(limits = x_limits, expand = expansion(mult = c(0.07, 0.07)))
    } else {
      p <- p + scale_x_continuous(expand = expansion(mult = c(0.07, 0.07)))
    }
  } else {
    p <- p + scale_x_continuous(
      breaks = seq_along(levels(z$category)),
      labels = levels(z$category),
      expand = expansion(mult = c(0.02, 0.02))
    )
    if (length(x_limits) == 2 && all(is.finite(x_limits))) {
      p <- p + scale_y_continuous(limits = x_limits, expand = expansion(mult = c(0.07, 0.07)))
    }
  }

  p <- p + labs(
    title = if (title_show && nzchar(title)) title else NULL,
    subtitle = val('subtitle', NULL),
    caption = val('caption', NULL),
    x = if (xlab_show && nzchar(xlab)) xlab else NULL,
    y = if (ylab_show && nzchar(ylab)) ylab else NULL
  )

  p <- p + theme_bw(base_size = base_size, base_family = font_family) + theme(
    plot.title = if (title_show) element_text(
      size = title_size, colour = title_color, face = title_face,
      hjust = title_hjust,
      margin = margin(t = 4, b = 6)
    ) else element_blank(),
    plot.background = element_rect(fill = as.character(val('plot_background', 'white')[1] %||% 'white'), colour = NA),
    panel.background = element_rect(fill = as.character(val('panel_background', 'white')[1] %||% 'white'), colour = NA),
    panel.border = if (panel_border) element_rect(fill = NA, colour = panel_border_color, linewidth = 0.5) else element_blank(),
    panel.grid.major = if (grid_show) element_line(colour = grid_color, linewidth = 0.35) else element_blank(),
    panel.grid.minor = element_blank(),
    axis.title.x = if (xlab_show) element_text() else element_blank(),
    axis.title.y = if (ylab_show) element_text() else element_blank(),
    axis.text.x = element_text(size = x_axis_text_size, colour = axis_text_color),
    axis.text.y = element_text(size = y_axis_text_size, colour = axis_text_color),
    legend.position = if (legend_show || show_size_legend) legend_position else 'none',
    legend.box = 'vertical',
    legend.spacing.y = grid::unit(0.35, 'cm'),
    legend.text = element_text(size = legend_text_size),
    legend.title = element_text(size = legend_title_size),
    plot.margin = grid::unit(rep(margin_cm, 4), 'cm')
  )

  size_guide <- if (show_size_legend) {
    guide_legend(
      title = size_legend_title,
      override.aes = list(colour = '#555555', fill = '#555555', alpha = 1, shape = 16)
    )
  } else {
    'none'
  }
  if (color_mode == 'value') {
    filled_head <- point_shape %in% c(21, 22, 23, 24, 25)
    p <- p + guides(colour = if (legend_show && !filled_head) guide_colourbar(order = 2) else 'none',
                    fill = if (legend_show && filled_head) guide_colourbar(order = 2) else 'none',
                    size = if (show_size_legend) guide_legend(order = 1,
                      override.aes = list(colour = 'black', alpha = 1, shape = 16)) else 'none')
  } else if (point_shape %in% c(21, 22, 23, 24, 25)) {
    p <- p + guides(
      fill = if (legend_show) guide_legend(title = legend_title, override.aes = list(size = 4, alpha = 1)) else 'none',
      size = size_guide,
      colour = 'none'
    )
  } else {
    p <- p + guides(
      colour = if (legend_show) guide_legend(title = legend_title, override.aes = list(size = 4, alpha = 1)) else 'none',
      size = size_guide
    )
  }

  if (central_labels) {
    p <- p + theme(axis.text.y = element_blank(), axis.ticks.y = element_blank(),
                    axis.line.x = element_line(colour = axis_text_color, linewidth = 0.45))
  }
  if (legend_position == 'inside') {
    p <- p + theme(legend.position = c(0.97, 0.06),
                    legend.justification = c(1, 0), legend.background = element_blank())
  }
  if (direction_labels_show) {
    extent <- if (length(x_limits) == 2) x_limits else range(c(-abs(z$value), abs(z$value))) * 1.1
    points_per_row <- max(1, h * 72 - 100) / max(1, length(levels(z$category)))
    arrow_y <- min(z$.y) - 0.7 - 24 / points_per_row
    text_y <- min(z$.y) - 0.7 - 40 / points_per_row
    p <- p + annotate('segment', x = extent[1] * 0.18, xend = extent[1] * 0.85,
                       y = arrow_y, yend = arrow_y, linewidth = 1.2,
                       colour = as.character(val('color_low', '#879B39')),
                       arrow = grid::arrow(length = grid::unit(0.12, 'in'), type = 'closed')) +
      annotate('segment', x = extent[2] * 0.18, xend = extent[2] * 0.85,
               y = arrow_y, yend = arrow_y, linewidth = 1.2,
               colour = as.character(val('color_high', '#CB6582')),
               arrow = grid::arrow(length = grid::unit(0.12, 'in'), type = 'closed')) +
      annotate('text', x = extent[1] * 0.52, y = text_y,
               label = as.character(val('negative_label', 'Enriched in group 1')), size = label_size) +
      annotate('text', x = extent[2] * 0.52, y = text_y,
               label = as.character(val('positive_label', 'Enriched in group 2')), size = label_size) +
      coord_cartesian(ylim = c(min(z$.y) - 0.7, max(z$.y) + 0.8), clip = 'off', expand = FALSE) +
      theme(plot.margin = margin(t = margin_cm * 28.35, r = margin_cm * 28.35,
                                 b = 65, l = margin_cm * 28.35))
  }
  logmsg(sprintf('Built lollipop: %s categories, %s groups, orientation=%s.',
                 nrow(z), nlevels(z$group), orientation))

  ggsave(file.path(out, 'result.svg'), p, width = w, height = h, units = 'in', dpi = dpi)
  # cairo_pdf matches system fonts and falls back for unknown families (pdf() errors).
  ggsave(file.path(out, 'result.pdf'), p, width = w, height = h, units = 'in',
         device = if (capabilities('cairo')) grDevices::cairo_pdf else 'pdf')
  ggsave(file.path(out, 'result.png'), p, width = w, height = h, units = 'in', dpi = dpi, device = ragg::agg_png)

  html_ok <- FALSE
  if (bool(c('interactive'), FALSE) && requireNamespace('plotly', quietly = TRUE)) {
    html_ok <- tryCatch({
      q <- plotly::ggplotly(p, tooltip = 'text')
      q <- plotly::config(q, displaylogo = FALSE, scrollZoom = bool(c('zoom'), TRUE),
                          modeBarButtonsToAdd = c('lasso2d', 'select2d'))
      htmlwidgets::saveWidget(q, file.path(out, 'result.html'), selfcontained = TRUE)
      TRUE
    }, error = function(e) {
      logmsg(paste('Interactive conversion unavailable; static exports preserved:', conditionMessage(e)))
      FALSE
    })
  }
  if (!html_ok) {
    png_path <- file.path(out, 'result.png')
    image_data <- jsonlite::base64_enc(readBin(png_path, 'raw', n = file.info(png_path)$size))
    writeLines(
      paste0('<!doctype html><html><head><meta charset="utf-8"><title>Lollipop preview</title></head>',
             '<body><p>Static preview. Use PNG, SVG or PDF for the reference layout.</p>',
             '<img alt="Lollipop plot" style="max-width:100%;height:auto" src="data:image/png;base64,',
             image_data, '"></body></html>'),
      file.path(out, 'result.html')
    )
  }

  write.csv(
    data.frame(
      category = as.character(z$category),
      value = z$value,
      group = as.character(z$group),
      size = z$size,
      pvalue = z$pvalue,
      is_selected = TRUE,
      stringsAsFactors = FALSE
    ),
    file.path(out, 'selected_rows.csv'),
    row.names = FALSE
  )

  writeLines(
    toJSON(list(
      figure_type = 'interactive_enrichment_lollipop',
      plugin = 'interactive_enrichment_lollipop', version = '1.2.0',
      mapping = list(category = cc, signed_effect = vc, pvalue = pc, size = sc),
      transforms = list(size = size_transform, color = color_mode, category_labels = if (central_labels) 'zero_opposite' else 'axis'),
      interactive_html = html_ok,
      title = if (title_show) title else '',
      layout = list(width = w, height = h, orientation = orientation),
      analysis = list(
        n_categories = nrow(z),
        groups = levels(z$group),
        value_range = range(z$value, na.rm = TRUE),
        size_mapped = size_switch
      ),
      layers = list(
        list(id = 'stems', type = 'segment', editable = TRUE),
        list(id = 'points', type = 'point', editable = TRUE),
        list(id = 'zero_line', type = 'line', editable = TRUE),
        list(id = 'legend', type = 'legend', editable = TRUE)
      ),
      export = list(svg = 'result.svg', pdf = 'result.pdf', png = 'result.png', html = 'result.html')
    ), auto_unbox = TRUE, pretty = TRUE),
    file.path(out, 'figure.json')
  )

  logmsg(sprintf('Rendered %d categories', nrow(z)))
  quit(status = 0)
}, error = function(e) fail('Plot generation failed', conditionMessage(e)))
