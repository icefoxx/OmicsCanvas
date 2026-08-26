#!/usr/bin/env Rscript

# BioFigureAI: Interactive Enrichment Lollipop (ChiPlot-compatible)
# ------------------------------------------------------------
# Horizontal (default) or vertical zero-centered lollipop / Cleveland
# plot with group colors, optional size mapping, stems, zero line,
# labels, and full axis/title/legend/export controls.
#
# Also accepts ChiPlot-style aliases:
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

logmsg <- function(x) {
  cat(sprintf('[%s] %s\n', format(Sys.time(), '%F %T'), x),
      file = file.path(out, 'run.log'), append = TRUE)
}

fail <- function(m, d = '', s = 'Check input and params.') {
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

  val <- function(n, z = NULL) {
    if (!is.null(p[[n]])) return(p[[n]])
    z
  }
  # first matching alias
  val_any <- function(names, z = NULL) {
    for (n in names) {
      if (!is.null(p[[n]])) return(p[[n]])
    }
    z
  }
  bool <- function(names, z = FALSE) {
    if (is.character(names) && length(names) == 1 && !names %in% names(p) && grepl('_', names)) {
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
  z <- z[!is.na(z$value) & nzchar(z$category), , drop = FALSE]

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
  # ChiPlot / image: first rows at top → reverse factor for horizontal
  reverse_cat <- bool(c('reverse_categories', 'reverse_y', 'reverse_category'), TRUE)
  if (reverse_cat) z$category <- factor(z$category, levels = rev(levels(z$category)))

  go <- vec(val_any(c('group_order', 'type_order', 'legend_order'), NULL))
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

  # Colors — ChiPlot type_colors / group_colors / color_map
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

  # Style params (ChiPlot aliases)
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
  # ChiPlot r=8 is fixed radius when size switch off; min/max when on
  size_switch <- size_map
  r_fixed <- num(c('r', 'point_size', 'lollipop_r'), 8)
  # convert CSS-ish radius to ggplot size roughly
  pt_min <- num(c('point_size_min', 'min_radius', 'min-radius'), 4)
  pt_max <- num(c('point_size_max', 'max_radius', 'max-radius'), 20)
  # If values look like px radii (> 3), map to ggplot size units
  if (pt_min > 3) pt_min <- pt_min / 2.5
  if (pt_max > 8) pt_max <- pt_max / 2.5
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
  title <- as.character(val_any(c('title', 'title_text'), 'ChiPlot')[1] %||% 'ChiPlot')
  title_size <- num(c('title_size'), 14)
  title_color <- as.character(val_any(c('title_color', 'title_fill'), '#222222')[1] %||% '#222222')
  title_face <- as.character(val_any(c('title_face', 'title_font_weight'), 'plain')[1] %||% 'plain')
  if (tolower(title_face) == 'bold') title_face <- 'bold' else if (tolower(title_face) == 'normal') title_face <- 'plain'
  title_hjust <- num(c('title_hjust'), 0.5)

  xlab_show <- bool(c('x_title_show', 'xlab_show'), FALSE)
  ylab_show <- bool(c('y_title_show', 'ylab_show'), FALSE)
  xlab <- as.character(val_any(c('xlab', 'x_title'), '')[1] %||% '')
  ylab <- as.character(val_any(c('ylab', 'y_title'), '')[1] %||% '')

  legend_show <- bool(c('legend_show'), TRUE)
  legend_title <- as.character(val_any(c('legend_title', 'legend_name'), 'ChiPlot')[1] %||% 'ChiPlot')
  legend_position <- as.character(val('legend_position', 'right')[1] %||% 'right')
  legend_text_size <- num(c('legend_text_size'), 10)
  legend_title_size <- num(c('legend_title_size'), 11)
  show_size_legend <- bool(c('show_size_legend', 'size_legend_show'), FALSE)
  size_legend_title <- as.character(val_any(c('size_legend_title'), 'Size')[1] %||% 'Size')
  size_legend_breaks <- suppressWarnings(as.numeric(unlist(val('size_legend_breaks', NULL))))
  size_legend_breaks <- size_legend_breaks[is.finite(size_legend_breaks)]

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

  # Build plot
  if (horizontal) {
    p <- ggplot(z, aes(x = .data$.x, y = .data$.y))
  } else {
    p <- ggplot(z, aes(x = .data$.y, y = .data$.x))
  }

  if (stem_show) {
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

  if (point_shape %in% c(21, 22, 23, 24, 25)) {
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
      breaks = if (length(size_legend_breaks)) size_legend_breaks else waiver(),
      guide = if (show_size_legend) 'legend' else 'none'
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
  if (horizontal) {
    p <- p + scale_y_continuous(
      breaks = seq_along(levels(z$category)),
      labels = levels(z$category),
      expand = expansion(mult = c(0.02, 0.02))
    )
    if (length(x_limits) == 2 && all(is.finite(x_limits))) {
      p <- p + scale_x_continuous(limits = x_limits, expand = expansion(mult = c(0.02, 0.05)))
    } else {
      p <- p + scale_x_continuous(expand = expansion(mult = c(0.02, 0.05)))
    }
  } else {
    p <- p + scale_x_continuous(
      breaks = seq_along(levels(z$category)),
      labels = levels(z$category),
      expand = expansion(mult = c(0.02, 0.02))
    )
    if (length(x_limits) == 2 && all(is.finite(x_limits))) {
      p <- p + scale_y_continuous(limits = x_limits, expand = expansion(mult = c(0.02, 0.05)))
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
    legend.position = if (legend_show) legend_position else 'none',
    legend.text = element_text(size = legend_text_size),
    legend.title = element_text(size = legend_title_size),
    plot.margin = grid::unit(rep(margin_cm, 4), 'cm')
  )

  # Guides: only group legend by default (matches ChiPlot image)
  if (point_shape %in% c(21, 22, 23, 24, 25)) {
    p <- p + guides(
      fill = if (legend_show) guide_legend(override.aes = list(size = 4, alpha = 1)) else 'none',
      size = if (show_size_legend && size_switch) guide_legend() else 'none',
      colour = 'none'
    )
  } else {
    p <- p + guides(
      colour = if (legend_show) guide_legend(override.aes = list(size = 4, alpha = 1)) else 'none',
      size = if (show_size_legend && size_switch) guide_legend() else 'none'
    )
  }

  logmsg(sprintf('Built lollipop: %s categories, %s groups, orientation=%s.',
                 nrow(z), nlevels(z$group), orientation))

  ggsave(file.path(out, 'result.svg'), p, width = w, height = h, units = 'in', dpi = dpi)
  ggsave(file.path(out, 'result.pdf'), p, width = w, height = h, units = 'in')
  ggsave(file.path(out, 'result.png'), p, width = w, height = h, units = 'in', dpi = dpi)

  if (bool(c('interactive'), FALSE) && requireNamespace('plotly', quietly = TRUE)) {
    q <- plotly::ggplotly(p, tooltip = 'text')
    q <- plotly::config(q, displaylogo = FALSE, scrollZoom = bool(c('zoom'), TRUE),
                        modeBarButtonsToAdd = c('lasso2d', 'select2d'))
    htmlwidgets::saveWidget(q, file.path(out, 'result.html'), selfcontained = TRUE)
  } else {
    writeLines(
      '<html><body>Static render. Set interactive:true and install plotly for HTML.</body></html>',
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
