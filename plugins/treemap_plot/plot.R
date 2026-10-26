#!/usr/bin/env Rscript
# Treemap Plot
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

slice_dice <- function(items, x, y, w, h, vertical = TRUE) {
  total <- sum(items$value)
  if (!is.finite(total) || total <= 0) return(items[0, ])
  pos <- 0
  out <- items
  out$xmin <- out$xmax <- out$ymin <- out$ymax <- NA_real_
  for (i in seq_len(nrow(items))) {
    frac <- items$value[i] / total
    if (vertical) {
      ww <- w * frac
      out$xmin[i] <- x + pos; out$xmax[i] <- x + pos + ww
      out$ymin[i] <- y; out$ymax[i] <- y + h
      pos <- pos + ww
    } else {
      hh <- h * frac
      out$xmin[i] <- x; out$xmax[i] <- x + w
      out$ymin[i] <- y + pos; out$ymax[i] <- y + pos + hh
      pos <- pos + hh
    }
  }
  out
}

main <- function() {
  df <- read_table(opt$input)
  l1 <- find_column(df, 'level1_column', c('level1', 'parent', 'group'))
  l2 <- find_column(df, 'level2_column', c('level2', 'child', 'label'), required = FALSE)
  vcol <- find_column(df, 'value_column', c('value', 'count', 'n'))
  raw <- data.frame(
    level1 = as.character(df[[l1]]),
    level2 = if (is.null(l2)) NA_character_ else as.character(df[[l2]]),
    value = suppressWarnings(as.numeric(df[[vcol]])),
    stringsAsFactors = FALSE
  )
  dropped <- sum(!is.finite(raw$value) | raw$value < 0 | !nzchar(raw$level1))
  raw <- raw[is.finite(raw$value) & raw$value >= 0 & nzchar(raw$level1), , drop = FALSE]
  if (dropped) log_msg(sprintf('Dropped %d rows', dropped))
  if (!nrow(raw)) fail('No non-negative values to plot')

  parents <- aggregate(value ~ level1, raw, sum)
  names(parents)[1] <- 'label'
  parents <- parents[order(-parents$value), , drop = FALSE]
  parents <- slice_dice(parents, 0, 0, 1, 1, TRUE)
  tiles <- data.frame()
  if (is.null(l2) || !any(nzchar(raw$level2) & !is.na(raw$level2))) {
    tiles <- parents
    tiles$parent <- tiles$label
  } else {
    kids <- aggregate(value ~ level1 + level2, raw, sum)
    for (i in seq_len(nrow(parents))) {
      sub <- kids[kids$level1 == parents$label[i], , drop = FALSE]
      if (!nrow(sub)) next
      sub$label <- sub$level2
      sub <- sub[order(-sub$value), , drop = FALSE]
      lay <- slice_dice(sub[, c('label', 'value')], parents$xmin[i], parents$ymin[i],
                        parents$xmax[i] - parents$xmin[i], parents$ymax[i] - parents$ymin[i], FALSE)
      lay$parent <- parents$label[i]
      tiles <- rbind(tiles, lay)
    }
  }
  pal <- chr('palette', 'Set 2')
  roots <- unique(parents$label)
  cols <- tryCatch(grDevices::hcl.colors(max(3, length(roots)), pal), error = function(e) grDevices::hcl.colors(max(3, length(roots)), 'Set 2'))
  cols <- cols[seq_along(roots)]; names(cols) <- roots
  tiles$fill_group <- tiles$parent
  tiles$xmid <- (tiles$xmin + tiles$xmax) / 2
  tiles$ymid <- (tiles$ymin + tiles$ymax) / 2
  write.csv(tiles, file.path(out, 'data_used.csv'), row.names = FALSE)

  p <- ggplot(tiles) +
    geom_rect(aes(xmin = .data$xmin, xmax = .data$xmax, ymin = .data$ymin, ymax = .data$ymax, fill = .data$fill_group),
              colour = chr('border_color', '#FFFFFF'), linewidth = num('border_width', 0.4))
  if (!is.null(l2)) {
    p <- p + geom_rect(data = parents, aes(xmin = .data$xmin, xmax = .data$xmax, ymin = .data$ymin, ymax = .data$ymax),
                       fill = NA, colour = '#333333', linewidth = num('parent_border_width', 1.2), inherit.aes = FALSE)
  }
  if (flag('label_show', TRUE)) {
    p <- p + geom_text(aes(x = .data$xmid, y = .data$ymid, label = .data$label),
                       size = num('label_size', 8) / .pt, colour = '#222222')
  }
  p <- p + scale_fill_manual(values = cols, name = or_auto(chr('legend_title'), l1)) +
    coord_fixed(expand = FALSE) +
    labs(title = chr('title', ''), subtitle = chr('subtitle', ''), x = NULL, y = NULL) +
    theme_void(base_size = num('base_size', 11), base_family = chr('font_family', 'sans')) +
    theme(
      legend.position = if (flag('legend_show', TRUE)) chr('legend_position', 'right') else 'none',
      plot.background = element_rect(fill = 'white', colour = NA),
      panel.background = element_rect(fill = 'white', colour = NA)
    )
  source(file.path(repo_root, 'R', 'runtime', 'omicscanvas_theme.R'), local = TRUE)
  p <- omicscanvas_apply_theme(p, params, only = c('title_size', 'legend_text_size'))
  width <- num('width', 8); height <- num('height', 6); dpi <- num('dpi', 300)
  ggsave(file.path(out, 'result.svg'), p, width = width, height = height, bg = 'white')
  ggsave(file.path(out, 'result.pdf'), p, width = width, height = height, device = grDevices::cairo_pdf, bg = 'white')
  ggsave(file.path(out, 'result.png'), p, width = width, height = height, dpi = dpi, device = ragg::agg_png, bg = 'white')
  writeLines(toJSON(list(plugin = 'treemap_plot', version = '1.0.0',
                         data = list(rows = nrow(tiles), dropped_rows = dropped),
                         layers = c('treemap'),
                         export = list(width = width, height = height, dpi = dpi,
                                       files = c('result.svg', 'result.pdf', 'result.png', 'data_used.csv'))),
                    auto_unbox = TRUE, pretty = TRUE, null = 'null'), file.path(out, 'figure.json'))
  log_msg(sprintf('Done: %d tiles', nrow(tiles)))
}
tryCatch(main(), error = function(e) fail('Plot generation failed', conditionMessage(e)))
