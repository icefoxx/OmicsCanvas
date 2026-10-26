#!/usr/bin/env Rscript
# Line Plot
#   Rscript plugins/line_plot/plot.R --input data.csv --params params.json --output out_dir

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
})

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x
opt <- parse_args(OptionParser(option_list = list(
  make_option('--input', type = 'character'),
  make_option('--params', type = 'character'),
  make_option('--output', type = 'character')
)))
out <- opt$output %||% getwd()
dir.create(out, recursive = TRUE, showWarnings = FALSE)
unlink(file.path(out, c('result.svg', 'result.pdf', 'result.png', 'figure.json', 'error.json', 'data_used.csv')), force = TRUE)
script_dir <- local({
  f <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[1])
  if (is.na(f)) getwd() else dirname(normalizePath(f))
})
repo_root <- normalizePath(file.path(script_dir, '..', '..'), mustWork = FALSE)
log_msg <- function(...) {
  line <- sprintf('[%s] %s\n', format(Sys.time(), '%F %T'), paste0(...))
  cat(line); cat(line, file = file.path(out, 'run.log'), append = TRUE)
}
fail <- function(message, detail = '', suggestion = 'Check the input columns and params.json.') {
  writeLines(toJSON(list(error = message, detail = as.character(detail), suggestion = suggestion),
                    auto_unbox = TRUE, pretty = TRUE), file.path(out, 'error.json'))
  log_msg('ERROR: ', message, ' ', detail)
  quit(save = 'no', status = 1)
}
params <- if (!is.null(opt$params) && file.exists(opt$params)) fromJSON(opt$params, simplifyVector = FALSE) else list()
param <- function(key, default = NULL) params[[key]] %||% default
num <- function(key, default) {
  v <- suppressWarnings(as.numeric(unlist(param(key)))[1])
  if (length(v) && is.finite(v)) v else default
}
flag <- function(key, default = FALSE) {
  v <- param(key)
  if (is.null(v)) return(default)
  if (is.logical(v)) return(isTRUE(v[[1]]))
  tolower(as.character(v[[1]])) %in% c('true', 't', 'yes', 'y', '1', 'on')
}
chr <- function(key, default = '') {
  v <- unlist(param(key))
  if (is.null(v) || !length(v) || is.na(v[1])) default else as.character(v[1])
}
or_auto <- function(v, auto) if (nzchar(v)) v else auto
chr_vec <- function(key) {
  v <- unlist(param(key), use.names = FALSE)
  if (is.null(v)) character() else trimws(as.character(v))
}
read_table <- function(path) {
  if (is.null(path) || !file.exists(path)) fail('Input file not found', path %||% '')
  ext <- tolower(tools::file_ext(path))
  if (ext %in% c('tsv', 'txt')) read.delim(path, check.names = FALSE, stringsAsFactors = FALSE)
  else read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}
find_column <- function(df, key, defaults = character(), required = TRUE) {
  wanted <- c(chr(key, ''), defaults)
  wanted <- wanted[nzchar(wanted)]
  hit <- match(tolower(wanted), tolower(colnames(df)))
  hit <- hit[!is.na(hit)]
  if (length(hit)) return(colnames(df)[hit[1]])
  if (required) fail(sprintf('Column for %s not found', key), paste(wanted, collapse = ', '),
                     sprintf('Set %s to one of: %s', key, paste(colnames(df), collapse = ', ')))
  NULL
}
group_palette <- function(levels_use) {
  pal <- chr('palette', 'Set 2')
  n <- max(3, length(levels_use))
  cols <- tryCatch(grDevices::hcl.colors(n, pal), error = function(e) grDevices::hcl.colors(n, 'Set 2'))
  cols <- cols[seq_along(levels_use)]
  names(cols) <- levels_use
  custom <- unlist(param('group_colors', list()))
  if (length(custom)) cols[intersect(names(custom), levels_use)] <- custom[intersect(names(custom), levels_use)]
  cols
}

main <- function() {
  df <- read_table(opt$input)
  x_col <- find_column(df, 'x_column', c('x', 'time', 'day'))
  y_col <- find_column(df, 'y_column', c('y', 'value'))
  group_col <- find_column(df, 'group_column', c('group', 'series'), required = FALSE)
  lower_col <- if (flag('band_show', FALSE)) find_column(df, 'lower_column', c('lower', 'lwr')) else NULL
  upper_col <- if (flag('band_show', FALSE)) find_column(df, 'upper_column', c('upper', 'upr')) else NULL
  se_col <- find_column(df, 'se_column', c('se', 'sem', 'stderr'), required = FALSE)
  y2_col <- find_column(df, 'y2_column', character(), required = FALSE)

  x_num <- suppressWarnings(as.numeric(df[[x_col]]))
  x_is_num <- mean(is.finite(x_num)) > 0.8
  d <- data.frame(
    x_raw = as.character(df[[x_col]]),
    x = if (x_is_num) x_num else seq_len(nrow(df)),
    y = suppressWarnings(as.numeric(df[[y_col]])),
    group = if (is.null(group_col)) 'All' else as.character(df[[group_col]]),
    se = if (is.null(se_col)) NA_real_ else suppressWarnings(as.numeric(df[[se_col]])),
    y2 = if (is.null(y2_col)) NA_real_ else suppressWarnings(as.numeric(df[[y2_col]])),
    stringsAsFactors = FALSE
  )
  dropped <- sum(!is.finite(d$y) | (x_is_num & !is.finite(d$x)))
  d <- d[is.finite(d$y) & (!x_is_num | is.finite(d$x)), , drop = FALSE]
  if (dropped) log_msg(sprintf('Dropped %d rows with non-numeric y/x', dropped))
  if (!nrow(d)) fail('No numeric rows to plot')

  include <- chr_vec('groups_include'); exclude <- chr_vec('groups_exclude')
  if (length(include)) d <- d[d$group %in% include, , drop = FALSE]
  if (length(exclude)) d <- d[!d$group %in% exclude, , drop = FALSE]
  if (!nrow(d)) fail('No rows left after group filtering')
  levels_use <- unique(c(intersect(chr_vec('group_order'), d$group), d$group))
  d$group <- factor(d$group, levels = levels_use)
  if (!x_is_num) {
    x_levels <- unique(d$x_raw)
    d$x <- factor(d$x_raw, levels = x_levels)
  }
  write.csv(d, file.path(out, 'data_used.csv'), row.names = FALSE)
  if (flag('band_show', FALSE)) {
    d$lower <- suppressWarnings(as.numeric(df[[lower_col]]))[as.integer(rownames(d))]
    d$upper <- suppressWarnings(as.numeric(df[[upper_col]]))[as.integer(rownames(d))]
    if (any(!is.finite(d$lower) | !is.finite(d$upper)) || any(d$lower > d$y | d$upper < d$y)) fail('Bounds must be finite and contain each supplied y value')
    write.csv(d, file.path(out, 'data_used.csv'), row.names = FALSE)
  }
  cols <- group_palette(levels_use)

  p <- ggplot(d, aes(x = .data$x, y = .data$y, colour = .data$group, group = .data$group))
  layers <- 'line'
  if (flag('band_show', FALSE)) p <- p + geom_ribbon(aes(ymin = .data$lower, ymax = .data$upper, fill = .data$group), alpha = num('band_alpha', 0.18), colour = NA) + scale_fill_manual(values = cols, guide = 'none')
  if (flag('error_show', TRUE) && any(is.finite(d$se))) {
    p <- p + geom_errorbar(aes(ymin = .data$y - .data$se, ymax = .data$y + .data$se),
                           width = 0.15, linewidth = 0.35, alpha = 0.7)
    layers <- c(layers, 'errorbar')
  }
  p <- p + geom_line(linewidth = num('line_width', 0.8), alpha = num('line_alpha', 1))
  if (flag('point_show', TRUE)) {
    p <- p + geom_point(size = num('point_size', 2), alpha = 0.9)
    layers <- c(layers, 'point')
  }
  if (flag('smooth_show', FALSE) && x_is_num) {
    p <- p + geom_smooth(method = 'loess', se = FALSE, linewidth = 0.5, formula = y ~ x)
    layers <- c(layers, 'smooth')
  }
  if (!is.null(y2_col) && any(is.finite(d$y2))) {
    yr <- range(d$y, na.rm = TRUE); y2r <- range(d$y2, na.rm = TRUE)
    span <- diff(yr); if (!is.finite(span) || span == 0) span <- 1
    span2 <- diff(y2r); if (!is.finite(span2) || span2 == 0) span2 <- 1
    d$y2s <- (d$y2 - y2r[1]) / span2 * span + yr[1]
    p <- p + geom_line(data = d, aes(y = .data$y2s, linetype = 'y2'), colour = '#555555', linewidth = 0.7) +
      scale_y_continuous(sec.axis = sec_axis(~ (. - yr[1]) / span * span2 + y2r[1], name = y2_col)) +
      scale_linetype_manual(values = c(y2 = 'dashed'), name = '')
    layers <- c(layers, 'y2')
  }
  p <- p +
    scale_colour_manual(values = cols, name = or_auto(chr('legend_title'), group_col %||% '')) +
    labs(title = chr('title', ''), subtitle = chr('subtitle', ''),
         x = or_auto(chr('xlab'), x_col), y = or_auto(chr('ylab'), y_col)) +
    theme_classic(base_size = num('base_size', 11), base_family = chr('font_family', 'sans')) +
    theme(
      legend.position = if (flag('legend_show', TRUE)) chr('legend_position', 'right') else 'none',
      panel.grid.major = if (flag('grid_show', TRUE)) element_line(colour = 'grey90', linewidth = 0.3) else element_blank()
    )

  source(file.path(repo_root, 'R', 'runtime', 'omicscanvas_theme.R'), local = TRUE)
  p <- omicscanvas_apply_theme(p, params, only = c('title_size', 'axis_label_size', 'x_axis_text_angle',
                                                   'legend_text_size', 'panel_border_show', 'grid_show'))

  width <- num('width', 7); height <- num('height', 4.5); dpi <- num('dpi', 300)
  ggsave(file.path(out, 'result.svg'), p, width = width, height = height)
  ggsave(file.path(out, 'result.pdf'), p, width = width, height = height, device = grDevices::cairo_pdf)
  ggsave(file.path(out, 'result.png'), p, width = width, height = height, dpi = dpi, device = ragg::agg_png)
  figure <- list(
    plugin = 'line_plot', version = '1.0.0',
    data = list(rows = nrow(d), dropped_rows = dropped,
                mapping = list(x = x_col, y = y_col, group = group_col %||% NA, se = se_col %||% NA)),
    layers = layers,
    export = list(width = width, height = height, dpi = dpi,
                  files = c('result.svg', 'result.pdf', 'result.png', 'data_used.csv'))
  )
  writeLines(toJSON(figure, auto_unbox = TRUE, pretty = TRUE, null = 'null'), file.path(out, 'figure.json'))
  log_msg(sprintf('Done: %d points in %d series', nrow(d), length(levels_use)))
}
tryCatch(main(), error = function(e) fail('Plot generation failed', conditionMessage(e)))
