#!/usr/bin/env Rscript
# __PLUGIN_NAME__ — generated from templates/plugin by scripts/new_plugin.py.
# Contract: docs/standards/01_plugin_contract.md. R rules: docs/standards/03_r_implementation.md.
#
#   Rscript plugins/__PLUGIN_ID__/plot.R --input data.csv --params params.json --output out_dir

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
# Never leave outputs of a previous run next to a failed one.
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

# ---- parameters: always params[['key']], never params$key (partial matching) ----
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
# Empty text means "use the automatic value" (the UI sends schema defaults such as "").
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

# Column mapping: the mapped name, else the first default that exists (case-insensitive).
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

main <- function() {
  df <- read_table(opt$input)
  x_col <- find_column(df, 'x_column', c('x'))
  y_col <- find_column(df, 'y_column', c('y'))
  group_col <- find_column(df, 'group_column', c('group', 'cluster'), required = FALSE)

  d <- data.frame(
    x = suppressWarnings(as.numeric(df[[x_col]])),
    y = suppressWarnings(as.numeric(df[[y_col]])),
    group = if (is.null(group_col)) 'All' else as.character(df[[group_col]]),
    stringsAsFactors = FALSE
  )
  dropped <- sum(!is.finite(d$x) | !is.finite(d$y))
  d <- d[is.finite(d$x) & is.finite(d$y), , drop = FALSE]
  if (dropped) log_msg(sprintf('Dropped %d rows with non-numeric x/y', dropped))
  if (!nrow(d)) fail('No numeric rows to plot', '', 'x_column and y_column must be numeric.')

  include <- chr_vec('groups_include'); exclude <- chr_vec('groups_exclude')
  if (length(include)) d <- d[d$group %in% include, , drop = FALSE]
  if (length(exclude)) d <- d[!d$group %in% exclude, , drop = FALSE]
  if (!nrow(d)) fail('No rows left after group filtering')
  levels_use <- unique(c(intersect(chr_vec('group_order'), d$group), d$group))
  d$group <- factor(d$group, levels = levels_use)
  write.csv(d, file.path(out, 'data_used.csv'), row.names = FALSE)

  # Colours: named map from group_colors, the rest from the palette.
  base_cols <- grDevices::hcl.colors(max(3, length(levels_use)), chr('palette', 'Set 2'))[seq_along(levels_use)]
  names(base_cols) <- levels_use
  custom <- unlist(param('group_colors', list()))
  if (length(custom)) base_cols[intersect(names(custom), levels_use)] <- custom[intersect(names(custom), levels_use)]

  p <- ggplot(d, aes(x = .data$x, y = .data$y, colour = .data$group)) +
    geom_point(size = num('point_size', 2), alpha = num('point_alpha', 0.85)) +
    scale_colour_manual(values = base_cols, name = or_auto(chr('legend_title'), group_col %||% '')) +
    labs(title = chr('title', ''), subtitle = chr('subtitle', ''),
         x = or_auto(chr('xlab'), x_col), y = or_auto(chr('ylab'), y_col)) +
    theme_classic(base_size = num('base_size', 11), base_family = chr('font_family', 'sans')) +
    theme(legend.position = if (flag('legend_show', TRUE)) chr('legend_position', 'right') else 'none')
  if (flag('trend_show', FALSE)) {
    p <- p + geom_smooth(method = 'lm', formula = y ~ x, se = FALSE, linewidth = 0.6)
  }

  # Shared appearance parameters (fonts, axes, grid, margins) — only keys this plugin
  # does not implement itself. See docs/standards/02_params_schema.md.
  source(file.path(repo_root, 'R', 'runtime', 'omicscanvas_theme.R'), local = TRUE)
  p <- omicscanvas_apply_theme(p, params, only = c('title_size', 'axis_label_size', 'x_axis_text_angle',
                                                   'legend_text_size', 'panel_border_show', 'grid_show'))

  width <- num('width', 6); height <- num('height', 4.5); dpi <- num('dpi', 300)
  ggsave(file.path(out, 'result.svg'), p, width = width, height = height)
  ggsave(file.path(out, 'result.pdf'), p, width = width, height = height, device = grDevices::cairo_pdf)
  ggsave(file.path(out, 'result.png'), p, width = width, height = height, dpi = dpi, device = ragg::agg_png)

  figure <- list(
    plugin = '__PLUGIN_ID__',
    version = '1.0.0',
    data = list(rows = nrow(d), dropped_rows = dropped,
                mapping = list(x = x_col, y = y_col, group = group_col %||% NA), groups = levels_use),
    layers = c('point', if (flag('trend_show', FALSE)) 'lm_trend'),
    export = list(width = width, height = height, dpi = dpi,
                  files = c('result.svg', 'result.pdf', 'result.png', 'data_used.csv'))
  )
  writeLines(toJSON(figure, auto_unbox = TRUE, pretty = TRUE, null = 'null'), file.path(out, 'figure.json'))
  log_msg(sprintf('Done: %d points in %d groups', nrow(d), length(levels_use)))
}

tryCatch(main(), error = function(e) fail('Plot generation failed', conditionMessage(e)))
