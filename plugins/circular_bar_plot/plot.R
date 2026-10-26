#!/usr/bin/env Rscript
# Circular Bar Plot
#   Rscript plugins/circular_bar_plot/plot.R --input data.csv --params params.json --output out_dir

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
  cat(line)
  cat(line, file = file.path(out, 'run.log'), append = TRUE)
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
  cat_col <- find_column(df, 'category_column', c('category', 'term', 'name', 'x'))
  val_col <- find_column(df, 'value_column', c('value', 'y', 'score'))
  group_col <- find_column(df, 'group_column', c('group', 'stack', 'class'), required = FALSE)
  plot_type <- chr('plot_type', 'stacked')
  if (!plot_type %in% c('stacked', 'single')) plot_type <- 'stacked'

  d <- data.frame(
    category = as.character(df[[cat_col]]),
    value = suppressWarnings(as.numeric(df[[val_col]])),
    group = if (is.null(group_col) || plot_type == 'single') 'All' else as.character(df[[group_col]]),
    stringsAsFactors = FALSE
  )
  dropped <- sum(!is.finite(d$value) | !nzchar(d$category))
  d <- d[is.finite(d$value) & nzchar(d$category), , drop = FALSE]
  if (dropped) log_msg(sprintf('Dropped %d rows with missing category or non-numeric value', dropped))
  if (!nrow(d)) fail('No numeric rows to plot')

  include <- chr_vec('groups_include'); exclude <- chr_vec('groups_exclude')
  if (length(include)) d <- d[d$group %in% include, , drop = FALSE]
  if (length(exclude)) d <- d[!d$group %in% exclude, , drop = FALSE]
  if (!nrow(d)) fail('No rows left after group filtering')

  if (plot_type == 'single') {
    d <- aggregate(value ~ category, d, sum)
    d$group <- 'All'
  }
  cat_levels <- unique(c(intersect(chr_vec('category_order'), d$category), d$category))
  grp_levels <- unique(c(intersect(chr_vec('group_order'), d$group), d$group))
  d$category <- factor(d$category, levels = cat_levels)
  d$group <- factor(d$group, levels = grp_levels)
  write.csv(d, file.path(out, 'data_used.csv'), row.names = FALSE)

  fill_levels <- if (plot_type == 'single') cat_levels else grp_levels
  fill_aes <- if (plot_type == 'single') 'category' else 'group'
  cols <- group_palette(fill_levels)

  totals <- aggregate(value ~ category, d, sum)
  ymax <- max(totals$value, na.rm = TRUE)
  if (!is.finite(ymax) || ymax <= 0) fail('Values must include a positive total')
  hole <- max(0, min(0.9, num('inner_radius', 0.2)))
  y_floor <- -hole / max(1e-6, 1 - hole) * ymax

  p <- ggplot(d, aes(x = .data$category, y = .data$value, fill = .data[[fill_aes]])) +
    geom_col(width = num('bar_width', 0.9), alpha = num('bar_alpha', 0.95), colour = NA) +
    scale_fill_manual(values = cols, name = or_auto(chr('legend_title'), if (plot_type == 'single') cat_col else (group_col %||% ''))) +
    coord_polar(start = 0, clip = 'off') +
    ylim(y_floor, ymax * 1.05) +
    labs(title = chr('title', ''), subtitle = chr('subtitle', ''), x = NULL, y = NULL) +
    theme_minimal(base_size = num('base_size', 11), base_family = chr('font_family', 'sans')) +
    theme(
      axis.text.y = element_blank(),
      axis.ticks = element_blank(),
      panel.grid.major.x = element_blank(),
      panel.grid.major.y = if (flag('grid_show', TRUE)) element_line(colour = '#dddddd', linewidth = 0.3) else element_blank(),
      panel.grid.minor = element_blank(),
      axis.text.x = if (flag('label_show', TRUE)) element_text(size = num('label_size', 8)) else element_blank(),
      legend.position = if (flag('legend_show', TRUE)) chr('legend_position', 'right') else 'none',
      plot.background = element_rect(fill = 'white', colour = NA),
      panel.background = element_rect(fill = 'white', colour = NA),
      plot.margin = margin(18, 28, 18, 36)
    )

  source(file.path(repo_root, 'R', 'runtime', 'omicscanvas_theme.R'), local = TRUE)
  p <- omicscanvas_apply_theme(p, params, only = c('title_size', 'legend_text_size'))

  width <- num('width', 7); height <- num('height', 7); dpi <- num('dpi', 300)
  ggsave(file.path(out, 'result.svg'), p, width = width, height = height, bg = 'white')
  ggsave(file.path(out, 'result.pdf'), p, width = width, height = height, device = grDevices::cairo_pdf, bg = 'white')
  ggsave(file.path(out, 'result.png'), p, width = width, height = height, dpi = dpi, device = ragg::agg_png, bg = 'white')

  figure <- list(
    plugin = 'circular_bar_plot', version = '1.0.0',
    data = list(rows = nrow(d), dropped_rows = dropped,
                mapping = list(category = cat_col, value = val_col, group = group_col %||% NA)),
    layers = c('polar_bar', plot_type),
    export = list(width = width, height = height, dpi = dpi,
                  files = c('result.svg', 'result.pdf', 'result.png', 'data_used.csv'))
  )
  writeLines(toJSON(figure, auto_unbox = TRUE, pretty = TRUE, null = 'null'), file.path(out, 'figure.json'))
  log_msg(sprintf('Done: %d bars, mode %s', nlevels(d$category), plot_type))
}

tryCatch(main(), error = function(e) fail('Plot generation failed', conditionMessage(e)))
