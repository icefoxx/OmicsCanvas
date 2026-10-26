#!/usr/bin/env Rscript
# Sunburst Plot
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

layout_ring <- function(items, ymin, ymax, x0 = 0, x1 = 1) {
  total <- sum(items$value)
  if (!is.finite(total) || total <= 0) return(items[FALSE, , drop = FALSE])
  start <- x0
  span <- x1 - x0
  out <- items
  out$xmin <- NA_real_; out$xmax <- NA_real_; out$ymin <- ymin; out$ymax <- ymax
  for (i in seq_len(nrow(items))) {
    w <- items$value[i] / total * span
    out$xmin[i] <- start
    out$xmax[i] <- start + w
    start <- start + w
  }
  out$share <- pmax(0, out$xmax - out$xmin)
  out
}

main <- function() {
  df <- read_table(opt$input)
  l1 <- find_column(df, 'level1_column', c('level1', 'parent', 'ring1'))
  l2 <- find_column(df, 'level2_column', c('level2', 'child', 'ring2'), required = FALSE)
  l3 <- find_column(df, 'level3_column', c('level3', 'ring3'), required = FALSE)
  vcol <- find_column(df, 'value_column', c('value', 'count', 'n'))
  raw <- data.frame(
    level1 = as.character(df[[l1]]),
    level2 = if (is.null(l2)) NA_character_ else as.character(df[[l2]]),
    level3 = if (is.null(l3)) NA_character_ else as.character(df[[l3]]),
    value = suppressWarnings(as.numeric(df[[vcol]])),
    stringsAsFactors = FALSE
  )
  dropped <- sum(!is.finite(raw$value) | raw$value < 0 | !nzchar(raw$level1))
  raw <- raw[is.finite(raw$value) & raw$value >= 0 & nzchar(raw$level1), , drop = FALSE]
  if (dropped) log_msg(sprintf('Dropped %d rows', dropped))
  if (!nrow(raw)) fail('No non-negative values to plot')

  hole <- num('inner_radius', 0.2)
  nring <- 1 + as.integer(!is.null(l2)) + as.integer(!is.null(l3) && any(nzchar(raw$level3) & !is.na(raw$level3)))
  ring_w <- (1 - hole) / nring

  r1 <- aggregate(value ~ level1, raw, sum)
  names(r1)[1] <- 'label'
  r1$ring <- 1
  r1$root <- r1$label
  r1$level1 <- r1$label
  r1 <- layout_ring(r1, hole, hole + ring_w, 0, 1)
  rings <- r1[, c('label', 'value', 'ring', 'root', 'level1', 'xmin', 'xmax', 'ymin', 'ymax', 'share')]
  if (!is.null(l2)) {
    r2 <- aggregate(value ~ level1 + level2, raw, sum)
    parts <- list()
    for (i in seq_len(nrow(r1))) {
      sub <- r2[r2$level1 == r1$label[i], , drop = FALSE]
      if (!nrow(sub)) next
      sub$label <- sub$level2
      sub$ring <- 2
      sub$root <- r1$root[i]
      parts[[length(parts) + 1]] <- layout_ring(
        sub[, c('label', 'value', 'ring', 'root', 'level1')],
        r1$ymin[i] + ring_w, r1$ymax[i] + ring_w, r1$xmin[i], r1$xmax[i]
      )
    }
    if (length(parts)) rings <- rbind(rings, do.call(rbind, parts)[, colnames(rings)])
  }
  if (nring >= 3) {
    r3 <- aggregate(value ~ level1 + level2 + level3, raw, sum)
    r2all <- rings[rings$ring == 2, , drop = FALSE]
    parts <- list()
    for (i in seq_len(nrow(r2all))) {
      sub <- r3[r3$level1 == r2all$level1[i] & r3$level2 == r2all$label[i], , drop = FALSE]
      if (!nrow(sub)) next
      sub$label <- sub$level3
      sub$ring <- 3
      sub$root <- r2all$root[i]
      parts[[length(parts) + 1]] <- layout_ring(
        sub[, c('label', 'value', 'ring', 'root', 'level1')],
        r2all$ymin[i] + ring_w, r2all$ymax[i] + ring_w, r2all$xmin[i], r2all$xmax[i]
      )
    }
    if (length(parts)) rings <- rbind(rings, do.call(rbind, parts)[, colnames(rings)])
  }
  pal <- chr('palette', 'Set 2')
  roots <- unique(r1$root)
  root_cols <- tryCatch(grDevices::hcl.colors(max(3, length(roots)), pal), error = function(e) grDevices::hcl.colors(max(3, length(roots)), 'Set 2'))
  root_cols <- root_cols[seq_along(roots)]; names(root_cols) <- roots
  rings$fill_key <- factor(rings$root, levels = roots)
  rings$xmid <- (rings$xmin + rings$xmax) / 2
  rings$ymid <- (rings$ymin + rings$ymax) / 2
  write.csv(rings, file.path(out, 'data_used.csv'), row.names = FALSE)

  p <- ggplot(rings) +
    geom_rect(aes(xmin = .data$xmin, xmax = .data$xmax, ymin = .data$ymin, ymax = .data$ymax, fill = .data$fill_key),
              colour = 'white', linewidth = num('border_width', 0.2)) +
    scale_x_continuous(limits = c(0, 1), expand = c(0, 0)) +
    coord_polar(clip = 'off') +
    ylim(0, 1.02) +
    scale_fill_manual(values = root_cols, name = or_auto(chr('legend_title'), 'Inner ring'),
                      breaks = roots) +
    labs(title = chr('title', ''), subtitle = chr('subtitle', ''), x = NULL, y = NULL) +
    theme_void(base_size = num('base_size', 11), base_family = chr('font_family', 'sans')) +
    theme(
      legend.position = if (flag('legend_show', TRUE)) chr('legend_position', 'right') else 'none',
      plot.background = element_rect(fill = 'white', colour = NA),
      panel.background = element_rect(fill = 'white', colour = NA)
    )
  if (flag('label_show', TRUE)) {
    lab <- rings[rings$share >= num('label_min_share', 0.04), , drop = FALSE]
    if (nrow(lab)) {
      p <- p + geom_text(data = lab, aes(x = .data$xmid, y = .data$ymid, label = .data$label),
                         size = num('label_size', 7) / .pt, colour = '#222222')
    }
  }
  source(file.path(repo_root, 'R', 'runtime', 'omicscanvas_theme.R'), local = TRUE)
  p <- omicscanvas_apply_theme(p, params, only = c('title_size', 'legend_text_size'))
  width <- num('width', 7); height <- num('height', 7); dpi <- num('dpi', 300)
  ggsave(file.path(out, 'result.svg'), p, width = width, height = height, bg = 'white')
  ggsave(file.path(out, 'result.pdf'), p, width = width, height = height, device = grDevices::cairo_pdf, bg = 'white')
  ggsave(file.path(out, 'result.png'), p, width = width, height = height, dpi = dpi, device = ragg::agg_png, bg = 'white')
  writeLines(toJSON(list(plugin = 'sunburst_plot', version = '1.0.0',
                         data = list(rows = nrow(rings), dropped_rows = dropped),
                         layers = c('sunburst'),
                         export = list(width = width, height = height, dpi = dpi,
                                       files = c('result.svg', 'result.pdf', 'result.png', 'data_used.csv'))),
                    auto_unbox = TRUE, pretty = TRUE, null = 'null'), file.path(out, 'figure.json'))
  log_msg(sprintf('Done: %d slices', nrow(rings)))
}
tryCatch(main(), error = function(e) fail('Plot generation failed', conditionMessage(e)))
