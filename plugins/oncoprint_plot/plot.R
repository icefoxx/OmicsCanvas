#!/usr/bin/env Rscript
# Mutation Matrix — generated from templates/plugin by scripts/new_plugin.py.
# Contract: docs/standards/01_plugin_contract.md. R rules: docs/standards/03_r_implementation.md.
#
#   Rscript plugins/oncoprint_plot/plot.R --input data.csv --params params.json --output out_dir

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
owned_outputs <- c('result.svg', 'result.pdf', 'result.png', 'figure.json', 'data_used.csv', 'gene_frequencies_used.csv', 'tiles_used.csv', 'result.html')
unlink(file.path(out, c(owned_outputs, 'error.json')), force = TRUE)

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
  unlink(file.path(out, owned_outputs), force = TRUE)
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

source(file.path(repo_root, 'R', 'plots', 'extension_helpers.R'), local = TRUE, encoding = 'UTF-8')
source(file.path(script_dir, 'draw.R'), local = TRUE, encoding = 'UTF-8')
main <- function() {
  oc_validate_parameters(file.path(script_dir, 'params_schema.json'))
  df <- read_table(opt$input)
  if (!nrow(df)) stop('The input table has no rows.')
  ggplot2::update_geom_defaults('text', list(family = chr('font_family', 'sans')))
  ggplot2::update_geom_defaults('label', list(family = chr('font_family', 'sans')))
  result <- draw_plot(df)
  p <- result$plot
  subtitle <- or_auto(chr('subtitle'), result$note %||% sprintf('%d input rows', nrow(df)))
  subtitle <- paste(strwrap(subtitle, width = max(35, min(68, floor(num('width', 8) * 8.5)))), collapse = '\n')
  if (inherits(p, 'patchwork')) {
    p <- p + patchwork::plot_annotation(title = chr('title'), subtitle = subtitle, caption = chr('caption'), theme = theme(plot.title = element_text(size = num('title_size', 13), face = 'bold', hjust = 0), plot.subtitle = element_text(size = num('base_size', 11), color = '#617080', hjust = 0), text = element_text(family = chr('font_family', 'sans'))))
  } else {
    p <- p + labs(title = chr('title'), subtitle = subtitle, caption = chr('caption'))
  }
  source(file.path(repo_root, 'R', 'runtime', 'omicscanvas_theme.R'), local = TRUE)
  p <- omicscanvas_apply_theme(p, params, only = c('font_family', 'base_size', 'title_size', 'legend_show', 'legend_position', 'legend_text_size', 'plot_background', 'grid_show'))
  width <- num('width', 8); height <- num('height', 6); dpi <- num('dpi', 150)
  if (width < 3 || height < 3 || dpi < 72) stop('Set width/height to at least 3 inches and dpi to at least 72.')
  ggsave(file.path(out, 'result.svg'), p, width = width, height = height)
  ggsave(file.path(out, 'result.pdf'), p, width = width, height = height, device = grDevices::cairo_pdf)
  ggsave(file.path(out, 'result.png'), p, width = width, height = height, dpi = dpi, device = ragg::agg_png)
  write.csv(result$data, file.path(out, 'data_used.csv'), row.names = FALSE)
  for (name in names(result$tables)) write.csv(result$tables[[name]], file.path(out, name), row.names = FALSE)
  figure <- list(plugin = 'oncoprint_plot', version = '1.0.0', data = list(input_rows = nrow(df), rows = nrow(result$data)), statistics = result$statistics, export = list(width = width, height = height, dpi = dpi, files = c('result.svg', 'result.pdf', 'result.png', 'data_used.csv', if (file.exists(file.path(out, 'result.html'))) 'result.html', names(result$tables))))
  writeLines(toJSON(figure, auto_unbox = TRUE, pretty = TRUE, null = 'null'), file.path(out, 'figure.json'))
  log_msg(sprintf('Done: %d input rows; %d drawn records.', nrow(df), nrow(result$data)))
}
tryCatch(main(), error = function(e) {
  unlink(file.path(out, c('result.svg', 'result.pdf', 'result.png', 'result.html', 'figure.json')), force = TRUE)
  fail('Cannot draw this figure', conditionMessage(e), 'Check column mappings, numeric ranges and the documented input contract.')
})
