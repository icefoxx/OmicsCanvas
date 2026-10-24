# Shared ggplot theme overrides for OmicsCanvas plugins.
#
# Maps the generic appearance parameters that many params_schema.json files expose
# (titles, fonts, legend, axes, panel, grid, margins) onto ggplot2::theme().
# Only parameters the user actually set are applied, so default renders are unchanged.
#
# Usage in a plugin (after the plot object is final, before saving):
#   source(file.path(<repo>/R/runtime, 'omicscanvas_theme.R'))
#   p <- omicscanvas_apply_theme(p, params)

omicscanvas_theme_overrides <- function(params) {
  get <- function(k) params[[k]]
  first <- function(keys, f) {
    for (k in keys) {
      v <- f(k)
      if (!is.null(v)) return(v)
    }
    NULL
  }
  num <- function(k) {
    v <- suppressWarnings(as.numeric(unlist(get(k))))
    if (length(v) && is.finite(v[1])) v[1] else NULL
  }
  chr <- function(k) {
    v <- unlist(get(k))
    if (is.null(v) || !length(v) || is.na(v[1]) || !nzchar(as.character(v[1]))) NULL else as.character(v[1])
  }
  flag <- function(k) {
    v <- unlist(get(k))
    if (is.null(v) || !length(v)) return(NULL)
    if (is.logical(v)) return(isTRUE(v[1]))
    tolower(as.character(v[1])) %in% c('true', '1', 'yes', 'y', 'on')
  }
  txt <- function(size = NULL, colour = NULL, face = NULL, hjust = NULL, angle = NULL, family = NULL, margin = NULL) {
    args <- Filter(Negate(is.null), list(size = size, colour = colour, face = face, hjust = hjust,
                                         angle = angle, family = family, margin = margin))
    if (!length(args)) return(NULL)
    if (!is.null(args$angle) && args$angle != 0 && is.null(args$hjust)) {
      args$hjust <- 1
      args$vjust <- 1
    }
    do.call(ggplot2::element_text, args)
  }
  th <- list()
  put <- function(name, el) if (!is.null(el)) th[[name]] <<- el

  family <- chr('font_family')
  base <- first(c('base_size', 'font_size'), num)
  if (!is.null(family) || !is.null(base)) put('text', txt(size = base, family = family))

  put('plot.title', txt(num('title_size'), chr('title_color'), chr('title_face'), num('title_hjust')))
  put('plot.subtitle', txt(num('subtitle_size'), chr('subtitle_color'), chr('subtitle_face'), num('subtitle_hjust')))

  axis_title <- num('axis_label_size')
  put('axis.title', txt(axis_title))
  # Margin: a single number (gap to the axis) or a c(top, right, bottom, left) vector in pt.
  title_margin <- function(k, side) {
    v <- suppressWarnings(as.numeric(unlist(get(k))))
    v <- v[is.finite(v)]
    if (!length(v)) return(NULL)
    if (length(v) >= 4) return(ggplot2::margin(v[1], v[2], v[3], v[4]))
    if (side == 'x') ggplot2::margin(t = v[1]) else ggplot2::margin(r = v[1])
  }
  put('axis.title.x', txt(num('x_axis_title_size'), chr('x_axis_title_color'), margin = title_margin('x_axis_title_margin', 'x')))
  put('axis.title.y', txt(num('y_axis_title_size'), chr('y_axis_title_color'), margin = title_margin('y_axis_title_margin', 'y')))
  put('axis.text.x', txt(num('x_axis_text_size'), angle = num('x_axis_text_angle')))
  put('axis.text.y', txt(num('y_axis_text_size')))
  put('strip.text.x', txt(num('facet_text_x_size')))
  put('strip.text.y', txt(num('facet_text_y_size')))

  if (identical(flag('show_x_axis'), FALSE)) {
    th$axis.text.x <- ggplot2::element_blank(); th$axis.ticks.x <- ggplot2::element_blank(); th$axis.title.x <- ggplot2::element_blank()
  }
  if (identical(flag('show_y_axis'), FALSE)) {
    th$axis.text.y <- ggplot2::element_blank(); th$axis.ticks.y <- ggplot2::element_blank(); th$axis.title.y <- ggplot2::element_blank()
  }
  if (identical(flag('x_axis_ticks_show'), FALSE)) th$axis.ticks.x <- ggplot2::element_blank()
  if (identical(flag('y_axis_ticks_show'), FALSE)) th$axis.ticks.y <- ggplot2::element_blank()
  line_col <- chr('axis_line_color'); line_w <- num('axis_line_width')
  if (isTRUE(flag('axis_line_show')) || !is.null(line_col) || !is.null(line_w)) {
    th$axis.line <- ggplot2::element_line(colour = line_col %||% 'black', linewidth = line_w %||% 0.5)
  }
  if (identical(flag('axis_line_show'), FALSE)) th$axis.line <- ggplot2::element_blank()
  if (isTRUE(flag('x_axis_line_show'))) th$axis.line.x <- ggplot2::element_line(colour = line_col %||% 'black')
  if (identical(flag('x_axis_line_show'), FALSE)) th$axis.line.x <- ggplot2::element_blank()
  if (isTRUE(flag('y_axis_line_show'))) th$axis.line.y <- ggplot2::element_line(colour = line_col %||% 'black')
  if (identical(flag('y_axis_line_show'), FALSE)) th$axis.line.y <- ggplot2::element_blank()

  put('legend.text', txt(num('legend_text_size')))
  put('legend.title', txt(num('legend_title_size')))
  key <- num('legend_key_size')
  if (!is.null(key)) th$legend.key.size <- grid::unit(key, 'pt')
  pos <- chr('legend_position')
  if (!is.null(pos)) th$legend.position <- pos
  dir <- chr('legend_direction')
  if (!is.null(dir)) th$legend.direction <- dir
  if (identical(flag('legend_show'), FALSE)) th$legend.position <- 'none'

  panel_fill <- first(c('panel_background', 'panel_fill', 'grid_background'), chr)
  if (!is.null(panel_fill)) th$panel.background <- ggplot2::element_rect(fill = panel_fill, colour = NA)
  plot_fill <- first(c('plot_background', 'plot_fill'), chr)
  if (!is.null(plot_fill)) th$plot.background <- ggplot2::element_rect(fill = plot_fill, colour = NA)
  border_col <- chr('panel_border_color'); border_w <- first(c('panel_border_width', 'panel_border_size'), num)
  if (isTRUE(flag('panel_border_show')) || !is.null(border_col) || !is.null(border_w)) {
    th$panel.border <- ggplot2::element_rect(fill = NA, colour = border_col %||% 'black', linewidth = border_w %||% 0.5)
  }
  if (identical(flag('panel_border_show'), FALSE)) th$panel.border <- ggplot2::element_blank()

  if (identical(flag('grid_show'), FALSE)) th$panel.grid <- ggplot2::element_blank()
  if (isTRUE(flag('grid_show'))) th$panel.grid.major <- ggplot2::element_line(colour = 'grey90', linewidth = 0.3)
  grid_col <- chr('grid_color'); grid_lt <- chr('grid_linetype')
  if (!is.null(grid_col) || !is.null(grid_lt)) {
    th$panel.grid.major <- ggplot2::element_line(colour = grid_col %||% 'grey90', linetype = grid_lt %||% 'solid')
  }
  if (!is.null(chr('grid_minor_color'))) th$panel.grid.minor <- ggplot2::element_line(colour = chr('grid_minor_color'))
  gx <- chr('grid_major_x_color'); gy <- chr('grid_major_y_color')
  if (!is.null(gx)) th$panel.grid.major.x <- ggplot2::element_line(colour = gx)
  if (!is.null(gy)) th$panel.grid.major.y <- ggplot2::element_line(colour = gy)
  spacing <- num('panel_spacing')
  if (!is.null(spacing)) th$panel.spacing <- grid::unit(spacing, 'pt')

  m_all <- num('margin')
  sides <- list(num('margin_top'), num('margin_right'), num('margin_bottom'), num('margin_left'))
  if (!is.null(m_all) || any(!vapply(sides, is.null, logical(1)))) {
    d <- m_all %||% 5.5
    th$plot.margin <- ggplot2::margin(sides[[1]] %||% d, sides[[2]] %||% d, sides[[3]] %||% d, sides[[4]] %||% d)
  }
  ar <- num('aspect_ratio')
  if (!is.null(ar)) th$aspect.ratio <- ar

  if (!length(th)) return(NULL)
  do.call(ggplot2::theme, th)
}

omicscanvas_apply_theme <- function(p, params, only = NULL) {
  # `only`: restrict to the parameters this plugin does not implement itself, so
  # options a plugin already handles (possibly with its own units) are untouched.
  if (!is.null(only)) params <- params[intersect(names(params), only)]
  th <- omicscanvas_theme_overrides(params)
  if (is.null(th) || !inherits(p, 'ggplot')) return(p)
  if (inherits(p, 'patchwork')) p & th else p + th
}

if (!exists('%||%')) `%||%` <- function(a, b) if (is.null(a)) b else a
