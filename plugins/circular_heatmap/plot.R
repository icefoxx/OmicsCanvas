#!/usr/bin/env Rscript
# Circular Heatmap
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

hclust_order <- function(mat, margin) {
  mat2 <- mat
  mat2[!is.finite(mat2)] <- 0
  if (margin == 1) {
    if (nrow(mat2) < 2) return(rownames(mat))
    hc <- hclust(dist(mat2))
    rownames(mat)[hc$order]
  } else {
    if (ncol(mat2) < 2) return(colnames(mat))
    hc <- hclust(dist(t(mat2)))
    colnames(mat)[hc$order]
  }
}

main <- function() {
  df <- read_table(opt$input)
  row_col <- find_column(df, 'row_column', c('row', 'gene', 'feature', 'id'))
  col_col <- find_column(df, 'column_column', c('column', 'sample', 'group', 'x'))
  val_col <- find_column(df, 'value_column', c('value', 'z', 'score'))
  categorical <- chr("value_mode", "numeric") == "categorical"
  d <- data.frame(
    row = as.character(df[[row_col]]),
    column = as.character(df[[col_col]]),
    value = if (categorical) as.character(df[[val_col]]) else suppressWarnings(as.numeric(df[[val_col]])),
    stringsAsFactors = FALSE
  )
  dropped <- sum(!nzchar(d$row) | !nzchar(d$column))
  d <- d[nzchar(d$row) & nzchar(d$column), , drop = FALSE]
  if (dropped) log_msg(sprintf('Dropped %d rows with missing ids', dropped))
  if (!nrow(d)) fail('No rows to plot')
  if (categorical && (flag("cluster_rows", FALSE) || flag("cluster_columns", FALSE))) fail("Categorical rings cannot use numeric distance clustering")
  if (categorical && anyDuplicated(d[c("row", "column")])) fail("Categorical rings require one category per row-column cell")
  wide <- if (categorical) tapply(rep(0, nrow(d)), list(d$row, d$column), mean) else tapply(d$value, list(d$row, d$column), mean, na.rm = TRUE)
  wide[!is.finite(wide)] <- NA
  row_levels <- unique(c(intersect(chr_vec('row_order'), rownames(wide)), rownames(wide)))
  col_levels <- unique(c(intersect(chr_vec('column_order'), colnames(wide)), colnames(wide)))
  if (flag('cluster_rows', FALSE)) row_levels <- hclust_order(wide, 1)
  if (flag('cluster_columns', FALSE)) col_levels <- hclust_order(wide, 2)
  d$row <- factor(d$row, levels = row_levels)
  d$column <- factor(d$column, levels = col_levels)
  d <- d[!is.na(d$row) & !is.na(d$column), , drop = FALSE]
  write.csv(d, file.path(out, 'data_used.csv'), row.names = FALSE)

  n_row <- nlevels(d$row)
  hole <- num('inner_radius', 0.25)
  offset <- hole / max(1e-6, 1 - hole) * n_row
  d$y <- as.numeric(d$row) + offset
  pal <- chr('palette', 'Blue-Red 3')
  nfill <- 11
  fill_cols <- tryCatch(grDevices::hcl.colors(nfill, pal), error = function(e) grDevices::hcl.colors(nfill, 'Blue-Red 3'))

  p <- ggplot(d, aes(x = .data$column, y = .data$y, fill = .data$value)) +
    geom_tile(colour = 'white', linewidth = num('border_width', 0.1), height = 1) +
    (if (categorical) scale_fill_manual(values = local({
      lev <- unique(d$value[!is.na(d$value)]); colors <- setNames(grDevices::hcl.colors(max(3, length(lev)), 'Dark 3')[seq_along(lev)], lev)
      custom <- unlist(param('group_colors'), use.names = TRUE); if (length(custom)) colors[intersect(names(custom), lev)] <- custom[intersect(names(custom), lev)]; colors
    }), na.value = chr('na_color', '#EEEEEE'), name = or_auto(chr('legend_title'), val_col)) else scale_fill_gradientn(colours = fill_cols, na.value = chr('na_color', '#EEEEEE'), name = or_auto(chr('legend_title'), val_col))) +
    coord_polar(clip = 'off') +
    ylim(0, offset + n_row + 0.5) +
    labs(title = chr('title', ''), subtitle = chr('subtitle', ''), x = NULL, y = NULL) +
    theme_void(base_size = num('base_size', 11), base_family = chr('font_family', 'sans')) +
    theme(
      axis.text.x = if (flag('label_show', TRUE)) element_text(size = num('label_size', 8), colour = '#222222') else element_blank(),
      legend.position = if (flag('legend_show', TRUE)) chr('legend_position', 'right') else 'none',
      plot.background = element_rect(fill = 'white', colour = NA),
      panel.background = element_rect(fill = 'white', colour = NA)
    )
  if (categorical) p <- p + labs(caption = paste('Rings, inner to outer:', paste(row_levels, collapse = ' / ')))
  source(file.path(repo_root, 'R', 'runtime', 'omicscanvas_theme.R'), local = TRUE)
  p <- omicscanvas_apply_theme(p, params, only = c('title_size', 'legend_text_size'))
  width <- num('width', 7); height <- num('height', 7); dpi <- num('dpi', 300)
  ggsave(file.path(out, 'result.svg'), p, width = width, height = height, bg = 'white')
  ggsave(file.path(out, 'result.pdf'), p, width = width, height = height, device = grDevices::cairo_pdf, bg = 'white')
  ggsave(file.path(out, 'result.png'), p, width = width, height = height, dpi = dpi, device = ragg::agg_png, bg = 'white')
  writeLines(toJSON(list(plugin = 'circular_heatmap', version = '1.0.0',
                         data = list(rows = nrow(d), dropped_rows = dropped,
                                     n_row = n_row, n_column = nlevels(d$column)),
                         layers = c('circular_heatmap'),
                         export = list(width = width, height = height, dpi = dpi,
                                       files = c('result.svg', 'result.pdf', 'result.png', 'data_used.csv'))),
                    auto_unbox = TRUE, pretty = TRUE, null = 'null'), file.path(out, 'figure.json'))
  log_msg(sprintf('Done: %d x %d tiles', n_row, nlevels(d$column)))
}
tryCatch(main(), error = function(e) fail('Plot generation failed', conditionMessage(e)))
