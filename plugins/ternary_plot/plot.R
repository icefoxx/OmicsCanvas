#!/usr/bin/env Rscript
# Ternary Plot
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
group_palette <- function(levels_use) {
  pal <- chr('palette', 'Set 2')
  n <- max(3, length(levels_use))
  cols <- tryCatch(grDevices::hcl.colors(n, pal), error = function(e) grDevices::hcl.colors(n, 'Set 2'))
  cols <- cols[seq_along(levels_use)]; names(cols) <- levels_use
  custom <- unlist(param('group_colors', list()))
  if (length(custom)) cols[intersect(names(custom), levels_use)] <- custom[intersect(names(custom), levels_use)]
  cols
}

main <- function() {
  df <- read_table(opt$input)
  a_col <- find_column(df, 'a_column', c('a', 'A'))
  b_col <- find_column(df, 'b_column', c('b', 'B'))
  c_col <- find_column(df, 'c_column', c('c', 'C'))
  group_col <- find_column(df, 'group_column', c('group', 'sample'), required = FALSE)
  size_col <- find_column(df, 'size_column', character(), required = FALSE)
  d <- data.frame(
    a = pmax(0, suppressWarnings(as.numeric(df[[a_col]]))),
    b = pmax(0, suppressWarnings(as.numeric(df[[b_col]]))),
    c = pmax(0, suppressWarnings(as.numeric(df[[c_col]]))),
    group = if (is.null(group_col)) 'All' else as.character(df[[group_col]]),
    size = if (is.null(size_col)) NA_real_ else suppressWarnings(as.numeric(df[[size_col]])),
    stringsAsFactors = FALSE
  )
  tot <- d$a + d$b + d$c
  dropped <- sum(!is.finite(tot) | tot <= 0)
  d <- d[is.finite(tot) & tot > 0, , drop = FALSE]
  tot <- d$a + d$b + d$c
  d$a <- d$a / tot; d$b <- d$b / tot; d$c <- d$c / tot
  if (dropped) log_msg(sprintf('Dropped %d rows with non-positive composition', dropped))
  if (!nrow(d)) fail('No valid three-part compositions')
  include <- chr_vec('groups_include'); exclude <- chr_vec('groups_exclude')
  if (length(include)) d <- d[d$group %in% include, , drop = FALSE]
  if (length(exclude)) d <- d[!d$group %in% exclude, , drop = FALSE]
  if (!nrow(d)) fail('No rows left after group filtering')
  levels_use <- unique(c(intersect(chr_vec('group_order'), d$group), d$group))
  d$group <- factor(d$group, levels = levels_use)
  d$x <- 0.5 * (2 * d$c + d$b)
  d$y <- (sqrt(3) / 2) * d$a
  write.csv(d, file.path(out, 'data_used.csv'), row.names = FALSE)
  cols <- group_palette(levels_use)

  tri <- data.frame(x = c(0, 1, 0.5, 0), y = c(0, 0, sqrt(3) / 2, 0))
  grid <- data.frame()
  if (flag('grid_show', TRUE)) {
    br <- seq(0.2, 0.8, by = 0.2)
    for (p in br) {
      grid <- rbind(grid,
        data.frame(x = c(p / 2, 1 - p / 2), y = c(p * sqrt(3) / 2, p * sqrt(3) / 2), id = paste0('a', p)),
        data.frame(x = c(p, p / 2), y = c(0, p * sqrt(3) / 2), id = paste0('b', p)),
        data.frame(x = c(1 - p, 1 - p / 2), y = c(0, p * sqrt(3) / 2), id = paste0('c', p))
      )
    }
  }
  p <- ggplot(d, aes(x = .data$x, y = .data$y, colour = .data$group)) +
    geom_polygon(data = tri, aes(x = .data$x, y = .data$y), inherit.aes = FALSE,
                 fill = NA, colour = '#333333', linewidth = 0.4)
  if (nrow(grid)) {
    p <- p + geom_path(data = grid, aes(x = .data$x, y = .data$y, group = .data$id),
                       inherit.aes = FALSE, colour = '#dddddd', linewidth = 0.25)
  }
  if (!is.null(size_col) && any(is.finite(d$size))) {
    p <- p + geom_point(aes(size = .data$size), alpha = num('point_alpha', 0.85))
  } else {
    p <- p + geom_point(size = num('point_size', 2.5), alpha = num('point_alpha', 0.85))
  }
  al <- or_auto(chr('a_label'), a_col); bl <- or_auto(chr('b_label'), b_col); cl <- or_auto(chr('c_label'), c_col)
  labs_df <- data.frame(x = c(0.5, 0, 1), y = c(sqrt(3) / 2 + 0.04, -0.05, -0.05), lab = c(al, bl, cl))
  p <- p + geom_text(data = labs_df, aes(x = .data$x, y = .data$y, label = .data$lab),
                     inherit.aes = FALSE, size = num('vertex_label_size', 11) / .pt, colour = '#222222') +
    scale_colour_manual(values = cols, name = or_auto(chr('legend_title'), group_col %||% '')) +
    coord_equal(clip = 'off') +
    labs(title = chr('title', ''), subtitle = chr('subtitle', '')) +
    theme_void(base_size = num('base_size', 11), base_family = chr('font_family', 'sans')) +
    theme(legend.position = if (flag('legend_show', TRUE)) chr('legend_position', 'right') else 'none',
          plot.margin = margin(12, 12, 18, 12),
          plot.background = element_rect(fill = 'white', colour = NA),
          panel.background = element_rect(fill = 'white', colour = NA))
  source(file.path(repo_root, 'R', 'runtime', 'omicscanvas_theme.R'), local = TRUE)
  p <- omicscanvas_apply_theme(p, params, only = c('title_size', 'legend_text_size'))
  width <- num('width', 6.5); height <- num('height', 6); dpi <- num('dpi', 300)
  ggsave(file.path(out, 'result.svg'), p, width = width, height = height, bg = 'white')
  ggsave(file.path(out, 'result.pdf'), p, width = width, height = height, device = grDevices::cairo_pdf, bg = 'white')
  ggsave(file.path(out, 'result.png'), p, width = width, height = height, dpi = dpi, device = ragg::agg_png, bg = 'white')
  writeLines(toJSON(list(plugin = 'ternary_plot', version = '1.0.0',
                         data = list(rows = nrow(d), dropped_rows = dropped, groups = levels_use),
                         layers = c('ternary'),
                         export = list(width = width, height = height, dpi = dpi,
                                       files = c('result.svg', 'result.pdf', 'result.png', 'data_used.csv'))),
                    auto_unbox = TRUE, pretty = TRUE, null = 'null'), file.path(out, 'figure.json'))
  log_msg(sprintf('Done: %d points', nrow(d)))
}
tryCatch(main(), error = function(e) fail('Plot generation failed', conditionMessage(e)))
