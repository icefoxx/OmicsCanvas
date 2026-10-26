#!/usr/bin/env Rscript
# Raincloud Plot — generated from templates/plugin by scripts/new_plugin.py.
# Contract: docs/standards/01_plugin_contract.md. R rules: docs/standards/03_r_implementation.md.
#
#   Rscript plugins/raincloud_plot/plot.R --input data.csv --params params.json --output out_dir

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
  value_col <- find_column(df, 'value_column', c('value', 'y', 'expression'))
  group_col <- find_column(df, 'group_column', c('group', 'cluster', 'condition'), required = FALSE)

  d <- data.frame(
    value = suppressWarnings(as.numeric(df[[value_col]])),
    group = if (is.null(group_col)) 'All' else as.character(df[[group_col]]),
    stringsAsFactors = FALSE
  )
  dropped <- sum(!is.finite(d$value))
  d <- d[is.finite(d$value), , drop = FALSE]
  if (dropped) log_msg(sprintf('Dropped %d rows with non-numeric values', dropped))
  if (!nrow(d)) fail('No numeric rows to plot', '', 'value_column must be numeric.')

  include <- chr_vec('groups_include'); exclude <- chr_vec('groups_exclude')
  if (length(include)) d <- d[d$group %in% include, , drop = FALSE]
  if (length(exclude)) d <- d[!d$group %in% exclude, , drop = FALSE]
  if (!nrow(d)) fail('No rows left after group filtering')
  levels_use <- unique(c(intersect(chr_vec('group_order'), d$group), d$group))
  d$group <- factor(d$group, levels = levels_use)
  write.csv(d, file.path(out, 'data_used.csv'), row.names = FALSE)

  cols <- group_palette(levels_use)
  orientation <- chr('orientation', 'horizontal')
  if (!orientation %in% c('horizontal', 'vertical')) orientation <- 'horizontal'
  violin_show <- flag('violin_show', TRUE)
  box_show <- flag('box_show', TRUE)
  point_show <- flag('point_show', TRUE)
  if (!violin_show && !box_show && !point_show) fail('Nothing to draw', '', 'Enable violin_show, box_show, or point_show.')

  p <- ggplot(d, aes(x = .data$group, y = .data$value, fill = .data$group, colour = .data$group))
  layers <- character()
  if (violin_show) {
    if (requireNamespace('gghalves', quietly = TRUE)) {
      p <- p + gghalves::geom_half_violin(
        side = 'l', aes(colour = NULL),
        width = num('violin_width', 0.9), alpha = num('violin_alpha', 0.7),
        trim = FALSE, colour = NA
      )
    } else {
      p <- p + geom_violin(width = num('violin_width', 0.9), alpha = num('violin_alpha', 0.7), colour = NA)
    }
    layers <- c(layers, 'violin')
  }
  if (box_show) {
    p <- p + geom_boxplot(
      width = num('box_width', 0.18), outlier.shape = NA, fill = 'white',
      colour = '#333333', alpha = 0.9, linewidth = 0.35
    )
    layers <- c(layers, 'box')
  }
  if (point_show) {
    p <- p + geom_point(
      position = position_jitter(width = num('point_jitter', 0.08), height = 0, seed = 1L),
      size = num('point_size', 1.4), alpha = num('point_alpha', 0.45), stroke = 0
    )
    layers <- c(layers, 'points')
  }
  p <- p +
    scale_fill_manual(values = cols, name = or_auto(chr('legend_title'), group_col %||% '')) +
    scale_colour_manual(values = cols, guide = 'none') +
    labs(title = chr('title', ''), subtitle = chr('subtitle', ''),
         x = or_auto(chr('xlab'), group_col %||% 'group'),
         y = or_auto(chr('ylab'), value_col)) +
    theme_classic(base_size = num('base_size', 11), base_family = chr('font_family', 'sans')) +
    theme(legend.position = if (flag('legend_show', TRUE)) chr('legend_position', 'right') else 'none')
  if (orientation == 'horizontal') p <- p + coord_flip()

  source(file.path(repo_root, 'R', 'runtime', 'omicscanvas_theme.R'), local = TRUE)
  p <- omicscanvas_apply_theme(p, params, only = c('title_size', 'axis_label_size', 'x_axis_text_angle',
                                                   'legend_text_size', 'panel_border_show', 'grid_show'))

  width <- num('width', 7); height <- num('height', 5); dpi <- num('dpi', 300)
  ggsave(file.path(out, 'result.svg'), p, width = width, height = height)
  ggsave(file.path(out, 'result.pdf'), p, width = width, height = height, device = grDevices::cairo_pdf)
  ggsave(file.path(out, 'result.png'), p, width = width, height = height, dpi = dpi, device = ragg::agg_png)

  figure <- list(
    plugin = 'raincloud_plot',
    version = '1.0.0',
    data = list(rows = nrow(d), dropped_rows = dropped,
                mapping = list(value = value_col, group = group_col %||% NA), groups = levels_use),
    layers = layers,
    export = list(width = width, height = height, dpi = dpi,
                  files = c('result.svg', 'result.pdf', 'result.png', 'data_used.csv'))
  )
  writeLines(toJSON(figure, auto_unbox = TRUE, pretty = TRUE, null = 'null'), file.path(out, 'figure.json'))
  log_msg(sprintf('Done: %d rows in %d groups', nrow(d), length(levels_use)))
}

tryCatch(main(), error = function(e) fail('Plot generation failed', conditionMessage(e)))
