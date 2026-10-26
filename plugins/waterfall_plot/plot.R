#!/usr/bin/env Rscript
# Waterfall Plot
suppressPackageStartupMessages({
  library(optparse); library(jsonlite); library(ggplot2)
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
  log_msg('ERROR: ', message, ' ', detail); quit(save = 'no', status = 1)
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
  wanted <- c(chr(key, ''), defaults); wanted <- wanted[nzchar(wanted)]
  hit <- match(tolower(wanted), tolower(colnames(df))); hit <- hit[!is.na(hit)]
  if (length(hit)) return(colnames(df)[hit[1]])
  if (required) fail(sprintf('Column for %s not found', key), paste(wanted, collapse = ', '),
                     sprintf('Set %s to one of: %s', key, paste(colnames(df), collapse = ', ')))
  NULL
}

main <- function() {
  df <- read_table(opt$input)
  cat_col <- find_column(df, 'category_column', c('category', 'step', 'name', 'x'))
  val_col <- find_column(df, 'value_column', c('value', 'delta', 'y'))
  d0 <- data.frame(category = as.character(df[[cat_col]]),
                   value = suppressWarnings(as.numeric(df[[val_col]])), stringsAsFactors = FALSE)
  dropped <- sum(!is.finite(d0$value) | !nzchar(d0$category))
  d0 <- d0[is.finite(d0$value) & nzchar(d0$category), , drop = FALSE]
  if (dropped) log_msg(sprintf('Dropped %d rows', dropped))
  if (!nrow(d0)) fail('No numeric rows to plot')
  order_use <- unique(c(intersect(chr_vec('category_order'), d0$category), d0$category))
  d0 <- d0[match(order_use, d0$category), , drop = FALSE]
  d0 <- d0[!is.na(d0$category), , drop = FALSE]

  start <- 0
  ymin <- ymax <- kind <- numeric(nrow(d0))
  for (i in seq_len(nrow(d0))) {
    v <- d0$value[i]
    if (v >= 0) { ymin[i] <- start; ymax[i] <- start + v; kind[i] <- 1 } else { ymax[i] <- start; ymin[i] <- start + v; kind[i] <- -1 }
    start <- start + v
  }
  d <- data.frame(category = d0$category, value = d0$value, ymin = ymin, ymax = ymax,
                  type = ifelse(kind > 0, 'Increase', 'Decrease'), stringsAsFactors = FALSE)
  if (flag('total_show', TRUE)) {
    tot_lab <- or_auto(chr('total_label', 'Total'), 'Total')
    d <- rbind(d, data.frame(category = tot_lab, value = start, ymin = min(0, start), ymax = max(0, start),
                             type = 'Total', stringsAsFactors = FALSE))
  }
  d$category <- factor(d$category, levels = d$category)
  d$x <- as.numeric(d$category)
  d$mid <- (d$ymin + d$ymax) / 2
  write.csv(d, file.path(out, 'data_used.csv'), row.names = FALSE)

  bw <- num('bar_width', 0.7)
  fill_vals <- c(Increase = chr('increase_color', '#66C2A5'), Decrease = chr('decrease_color', '#FC8D62'),
                 Total = chr('total_color', '#8DA0CB'))
  p <- ggplot(d, aes(xmin = .data$x - bw / 2, xmax = .data$x + bw / 2,
                     ymin = .data$ymin, ymax = .data$ymax, fill = .data$type)) +
    geom_rect(colour = NA, alpha = num('bar_alpha', 0.95))
  if (flag('connector_show', TRUE) && nrow(d) > 1) {
    conn <- data.frame(x = d$x[-nrow(d)] + bw / 2,
                       xend = d$x[-1] - bw / 2,
                       y = d$ymax[-nrow(d)])
    if (d$type[nrow(d)] == 'Total') conn <- conn[-nrow(conn), , drop = FALSE]
    if (nrow(conn)) p <- p + geom_segment(data = conn, aes(x = .data$x, xend = .data$xend, y = .data$y, yend = .data$y),
                                          inherit.aes = FALSE, colour = '#666666', linewidth = 0.3)
  }
  if (flag('label_show', TRUE)) {
    p <- p + geom_text(aes(x = .data$x, y = .data$ymax, label = sprintf('%+.2g', .data$value)),
                       vjust = -0.4, size = num('label_size', 8) / .pt, colour = '#222222', inherit.aes = FALSE)
  }
  p <- p + scale_fill_manual(values = fill_vals, name = '') +
    scale_x_continuous(breaks = d$x, labels = as.character(d$category)) +
    scale_y_continuous(expand = expansion(mult = c(0.05, 0.14))) +
    labs(title = chr('title', ''), subtitle = chr('subtitle', ''),
         x = or_auto(chr('xlab'), cat_col), y = or_auto(chr('ylab'), 'Value')) +
    theme_classic(base_size = num('base_size', 11), base_family = chr('font_family', 'sans')) +
    theme(legend.position = if (flag('legend_show', TRUE)) chr('legend_position', 'right') else 'none')

  source(file.path(repo_root, 'R', 'runtime', 'omicscanvas_theme.R'), local = TRUE)
  p <- omicscanvas_apply_theme(p, params, only = c('title_size', 'axis_label_size', 'x_axis_text_angle',
                                                   'legend_text_size', 'panel_border_show', 'grid_show'))
  width <- num('width', 8); height <- num('height', 5); dpi <- num('dpi', 300)
  ggsave(file.path(out, 'result.svg'), p, width = width, height = height)
  ggsave(file.path(out, 'result.pdf'), p, width = width, height = height, device = grDevices::cairo_pdf)
  ggsave(file.path(out, 'result.png'), p, width = width, height = height, dpi = dpi, device = ragg::agg_png)
  writeLines(toJSON(list(plugin = 'waterfall_plot', version = '1.0.0',
                         data = list(rows = nrow(d), dropped_rows = dropped),
                         layers = c('waterfall'),
                         export = list(width = width, height = height, dpi = dpi,
                                       files = c('result.svg', 'result.pdf', 'result.png', 'data_used.csv'))),
                    auto_unbox = TRUE, pretty = TRUE, null = 'null'), file.path(out, 'figure.json'))
  log_msg(sprintf('Done: %d steps', nrow(d)))
}
tryCatch(main(), error = function(e) fail('Plot generation failed', conditionMessage(e)))
