#!/usr/bin/env Rscript

# BioFigureAI Plot Plugin: Combo Bar + Dot Matrix
# ------------------------------------------------------------
# Top: bars ± error, optional pairwise p brackets, reference hline(s)
# Bottom: binary or continuous dots sharing the same x categories
#
# Runtime:
#   Rscript plot.R --input bars.csv --params params.json --output out
#                  [--matrix matrix.csv] [--comparisons comparisons.csv]

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
})

option_list <- list(
  make_option('--input', type = 'character', default = NULL),
  make_option('--params', type = 'character', default = NULL),
  make_option('--output', type = 'character', default = NULL),
  make_option('--matrix', type = 'character', default = NULL),
  make_option('--comparisons', type = 'character', default = NULL)
)
opt <- parse_args(OptionParser(option_list = option_list))
input_file <- opt$input
params_file <- opt$params
output_dir <- opt$output

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) return(y)
  if (length(x) == 1 && is.na(x)) return(y)
  x
}

write_log <- function(msg) {
  cat(sprintf('[%s] %s\n', format(Sys.time(), '%F %T'), msg),
      file = file.path(output_dir, 'run.log'), append = TRUE)
}

write_error_and_exit <- function(error, detail = NULL, suggestion = NULL, status = 1) {
  if (is.null(output_dir) || !nzchar(as.character(output_dir %||% ''))) output_dir <<- getwd()
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  writeLines(
    jsonlite::toJSON(list(error = error, detail = as.character(detail %||% ''),
                          suggestion = as.character(suggestion %||% '')),
                     auto_unbox = TRUE, pretty = TRUE),
    file.path(output_dir, 'error.json')
  )
  message(error)
  quit(status = status)
}

read_table_auto <- function(path) {
  if (is.null(path) || !nzchar(as.character(path %||% '')) || !file.exists(path)) return(NULL)
  ext <- tolower(tools::file_ext(path))
  if (ext == 'csv') return(read.csv(path, check.names = FALSE, stringsAsFactors = FALSE))
  if (ext %in% c('tsv', 'txt')) return(read.delim(path, check.names = FALSE, stringsAsFactors = FALSE))
  tryCatch(read.csv(path, check.names = FALSE, stringsAsFactors = FALSE),
           error = function(e) read.delim(path, check.names = FALSE, stringsAsFactors = FALSE))
}

get_param <- function(params, name, default = NULL) {
  if (!is.null(params[[name]])) return(params[[name]])
  default
}

as_chr_vec <- function(x) {
  if (is.null(x)) return(character())
  out <- trimws(as.character(unlist(x, use.names = FALSE)))
  out[nzchar(out) & !is.na(out)]
}

as_num <- function(x, default = NA_real_) {
  z <- suppressWarnings(as.numeric(x %||% default)[1])
  if (is.na(z)) default else z
}

as_bool <- function(x, default = FALSE) {
  if (is.null(x)) return(default)
  if (is.logical(x)) return(isTRUE(x[1]))
  tolower(as.character(x[1])) %in% c('true', '1', 'yes', 'on', 't')
}

named_chr <- function(x) {
  if (is.null(x)) return(character())
  if (is.atomic(x) && !is.null(names(x))) return(setNames(as.character(x), names(x)))
  if (is.list(x)) {
    nms <- names(x)
    if (is.null(nms)) return(character())
    return(setNames(vapply(x, function(z) as.character(z %||% '')[1], character(1)), nms))
  }
  character()
}

format_p_scientific <- function(p) {
  if (is.null(p) || !is.finite(p)) return('')
  if (p >= 0.01) return(sprintf('P = %.2g', p))
  # P = a × 10^b style
  expo <- floor(log10(p))
  coef <- p / 10^expo
  sprintf('P = %.0f × 10^{%d}', round(coef), expo)
  # ggplot label will use plain text; for plotmath use different path
}

format_p_label <- function(p, style = 'plain') {
  if (is.null(p) || !is.finite(as.numeric(p)[1])) return('')
  p <- as.numeric(p)[1]
  if (tolower(style) == 'scientific') {
    expo <- floor(log10(p))
    coef <- p / (10^expo)
    # unicode superscripts for simple text geom
    sup <- c('0'='⁰','1'='¹','2'='²','3'='³','4'='⁴','5'='⁵','6'='⁶','7'='⁷','8'='⁸','9'='⁹','-'='⁻')
    es <- strsplit(as.character(expo), '')[[1]]
    es <- paste(vapply(es, function(ch) if (ch %in% names(sup)) sup[[ch]] else ch, character(1)), collapse = '')
    return(sprintf('P = %s × 10%s', format(round(coef, 1), nsmall = 0), es))
  }
  if (p < 0.001) return(sprintf('P = %.1e', p))
  sprintf('P = %.3g', p)
}

# ------------------------------------------------------------
tryCatch({
  if (is.null(output_dir) || !nzchar(output_dir)) write_error_and_exit('Missing --output')
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  if (file.exists(file.path(output_dir, 'error.json'))) unlink(file.path(output_dir, 'error.json'))
  write_log('Starting combo_bar_dot_matrix')

  if (is.null(params_file) || !file.exists(params_file)) {
    write_error_and_exit('Missing params.json', params_file)
  }
  params <- jsonlite::fromJSON(params_file, simplifyVector = FALSE)
  bars_raw <- read_table_auto(input_file)
  if (is.null(bars_raw) || !nrow(bars_raw)) write_error_and_exit('Bar input empty', input_file)

  # ---- bar columns ----
  x_col <- as.character(get_param(params, 'x_column', names(bars_raw)[1]) %||% names(bars_raw)[1])[1]
  y_col <- as.character(get_param(params, 'y_column', 'auprc') %||% 'auprc')[1]
  if (!y_col %in% names(bars_raw)) {
    for (a in c('value', 'mean', 'score', 'y', 'metric', 'auroc', 'auprc')) {
      if (a %in% names(bars_raw)) { y_col <- a; break }
    }
  }
  se_col <- as.character(get_param(params, 'se_column', 'se') %||% 'se')[1]
  ci_low_col <- as.character(get_param(params, 'ci_low_column', 'ci_low') %||% 'ci_low')[1]
  ci_high_col <- as.character(get_param(params, 'ci_high_column', 'ci_high') %||% 'ci_high')[1]
  group_col <- as.character(get_param(params, 'group_column', 'group') %||% 'group')[1]
  color_col <- as.character(get_param(params, 'color_column', 'color') %||% 'color')[1]
  annot_col <- as.character(get_param(params, 'annotation_column', 'annotation') %||% 'annotation')[1]

  if (!x_col %in% names(bars_raw) || !y_col %in% names(bars_raw)) {
    write_error_and_exit('Missing x/y columns', paste(names(bars_raw), collapse = ', '))
  }

  bars <- data.frame(
    x = as.character(bars_raw[[x_col]]),
    y = suppressWarnings(as.numeric(bars_raw[[y_col]])),
    stringsAsFactors = FALSE
  )
  if (se_col %in% names(bars_raw)) {
    se <- suppressWarnings(as.numeric(bars_raw[[se_col]]))
    bars$ymin <- bars$y - se
    bars$ymax <- bars$y + se
  } else if (ci_low_col %in% names(bars_raw) && ci_high_col %in% names(bars_raw)) {
    bars$ymin <- suppressWarnings(as.numeric(bars_raw[[ci_low_col]]))
    bars$ymax <- suppressWarnings(as.numeric(bars_raw[[ci_high_col]]))
  } else {
    bars$ymin <- bars$y
    bars$ymax <- bars$y
  }
  if (group_col %in% names(bars_raw)) bars$group <- as.character(bars_raw[[group_col]])
  else bars$group <- 'A'
  if (color_col %in% names(bars_raw)) bars$color <- as.character(bars_raw[[color_col]])
  else bars$color <- NA_character_
  if (annot_col %in% names(bars_raw)) bars$annotation <- as.character(bars_raw[[annot_col]])
  else bars$annotation <- NA_character_

  bars <- bars[is.finite(bars$y) & !is.na(bars$x) & nzchar(bars$x), , drop = FALSE]

  x_order <- as_chr_vec(get_param(params, 'x_order', NULL))
  if (!length(x_order)) x_order <- unique(bars$x)
  else x_order <- c(x_order[x_order %in% bars$x], setdiff(unique(bars$x), x_order))
  bars$x <- factor(bars$x, levels = x_order)
  n_x <- length(x_order)

  # colors
  group_colors <- named_chr(get_param(params, 'group_colors', NULL))
  palette_reds <- c('#8B1A1A', '#A52A2A', '#C04040', '#CD5C5C', '#E07070')
  palette_blues <- c('#1B3A6B', '#2E5A9C', '#3D7AB5', '#5B9BD5', '#7EB6E0')
  default_map <- c(red = '#B22222', blue = '#2E5A9C', A = '#4C72B0', B = '#DD8452')
  bars$fill <- NA_character_
  for (i in seq_len(nrow(bars))) {
    if (!is.na(bars$color[i]) && nzchar(bars$color[i]) && grepl('^#', bars$color[i])) {
      bars$fill[i] <- bars$color[i]
    } else if (!is.na(bars$color[i]) && nzchar(bars$color[i]) && bars$color[i] %in% names(default_map)) {
      bars$fill[i] <- default_map[[bars$color[i]]]
    } else if (bars$group[i] %in% names(group_colors)) {
      bars$fill[i] <- group_colors[[bars$group[i]]]
    } else if (tolower(bars$group[i]) %in% names(default_map)) {
      bars$fill[i] <- default_map[[tolower(bars$group[i])]]
    }
  }
  # gradient within groups if still NA
  for (g in unique(bars$group)) {
    idx <- which(bars$group == g & (is.na(bars$fill) | !nzchar(bars$fill)))
    if (!length(idx)) next
    pal <- if (grepl('red|warm|full', tolower(g))) palette_reds else if (grepl('blue|cool|core', tolower(g))) palette_blues else {
      grDevices::hcl(h = seq(15, 375, length.out = length(idx) + 1)[-1], c = 55, l = 45)
    }
    bars$fill[idx] <- rep(pal, length.out = length(idx))
  }
  single_fill <- as.character(get_param(params, 'bar_fill', '') %||% '')[1]
  if (nzchar(single_fill)) bars$fill <- single_fill

  # ---- comparisons / p brackets ----
  comp_file <- opt$comparisons
  if (is.null(comp_file) || !nzchar(comp_file %||% '')) {
    comp_file <- as.character(get_param(params, 'comparisons_file', '') %||% '')[1]
  }
  comp_raw <- read_table_auto(comp_file)
  # also allow params$comparisons as list of objects
  comp_list <- get_param(params, 'comparisons', NULL)
  comparisons <- NULL
  if (!is.null(comp_raw) && nrow(comp_raw)) {
    c1 <- as.character(get_param(params, 'comp_x1_column', 'x1') %||% 'x1')[1]
    c2 <- as.character(get_param(params, 'comp_x2_column', 'x2') %||% 'x2')[1]
    cp <- as.character(get_param(params, 'comp_pvalue_column', 'pvalue') %||% 'pvalue')[1]
    cl <- as.character(get_param(params, 'comp_label_column', 'label') %||% 'label')[1]
    if (!c1 %in% names(comp_raw)) c1 <- names(comp_raw)[1]
    if (!c2 %in% names(comp_raw)) c2 <- names(comp_raw)[2]
    comparisons <- data.frame(
      x1 = as.character(comp_raw[[c1]]),
      x2 = as.character(comp_raw[[c2]]),
      stringsAsFactors = FALSE
    )
    if (cp %in% names(comp_raw)) comparisons$pvalue <- suppressWarnings(as.numeric(comp_raw[[cp]]))
    else comparisons$pvalue <- NA_real_
    if (cl %in% names(comp_raw)) comparisons$label <- as.character(comp_raw[[cl]])
    else comparisons$label <- NA_character_
  } else if (is.list(comp_list) && length(comp_list)) {
    comparisons <- do.call(rbind, lapply(comp_list, function(z) {
      data.frame(
        x1 = as.character(z$x1 %||% z$xmin %||% ''),
        x2 = as.character(z$x2 %||% z$xmax %||% ''),
        pvalue = suppressWarnings(as.numeric(z$pvalue %||% z$p %||% NA)),
        label = as.character(z$label %||% ''),
        stringsAsFactors = FALSE
      )
    }))
  }

  p_style <- as.character(get_param(params, 'pvalue_label_style', 'scientific') %||% 'scientific')[1]
  if (!is.null(comparisons) && nrow(comparisons)) {
    comparisons$label <- ifelse(
      !is.na(comparisons$label) & nzchar(comparisons$label),
      comparisons$label,
      vapply(comparisons$pvalue, format_p_label, character(1), style = p_style)
    )
    # map to numeric x positions
    comparisons$x1n <- match(comparisons$x1, x_order)
    comparisons$x2n <- match(comparisons$x2, x_order)
    comparisons <- comparisons[is.finite(comparisons$x1n) & is.finite(comparisons$x2n), , drop = FALSE]
  }

  # ---- matrix / dots ----
  mat_file <- opt$matrix
  if (is.null(mat_file) || !nzchar(mat_file %||% '')) {
    mat_file <- as.character(get_param(params, 'matrix_file', '') %||% '')[1]
  }
  mat_raw <- read_table_auto(mat_file)
  show_matrix <- as_bool(get_param(params, 'matrix_show', TRUE), TRUE) && !is.null(mat_raw) && nrow(mat_raw) > 0

  dots <- NULL
  if (show_matrix) {
    mat_mode <- tolower(as.character(get_param(params, 'matrix_mode', 'auto') %||% 'auto')[1])
    feat_col <- as.character(get_param(params, 'feature_column', names(mat_raw)[1]) %||% names(mat_raw)[1])[1]
    mx_col <- as.character(get_param(params, 'matrix_x_column', 'x') %||% 'x')[1]
    mv_col <- as.character(get_param(params, 'matrix_value_column', 'value') %||% 'value')[1]

    if (mat_mode == 'auto') {
      if (mx_col %in% names(mat_raw) && mv_col %in% names(mat_raw)) mat_mode <- 'long'
      else mat_mode <- 'wide'
    }
    if (mat_mode == 'wide') {
      if (!feat_col %in% names(mat_raw)) feat_col <- names(mat_raw)[1]
      vcols <- setdiff(names(mat_raw), feat_col)
      # align to x_order when possible
      pieces <- lapply(vcols, function(cn) {
        data.frame(
          feature = as.character(mat_raw[[feat_col]]),
          x = cn,
          value = suppressWarnings(as.numeric(mat_raw[[cn]])),
          stringsAsFactors = FALSE
        )
      })
      dots <- do.call(rbind, pieces)
    } else {
      dots <- data.frame(
        feature = as.character(mat_raw[[feat_col]]),
        x = as.character(mat_raw[[mx_col]]),
        value = suppressWarnings(as.numeric(mat_raw[[mv_col]])),
        stringsAsFactors = FALSE
      )
    }
    dots$value[!is.finite(dots$value)] <- 0
    # keep features in input order
    feat_order <- as_chr_vec(get_param(params, 'feature_order', NULL))
    if (!length(feat_order)) feat_order <- unique(dots$feature)
    else feat_order <- c(feat_order[feat_order %in% dots$feature], setdiff(unique(dots$feature), feat_order))
    dots$feature <- factor(dots$feature, levels = rev(feat_order)) # top feature first in figure
    dots$x <- factor(dots$x, levels = x_order)
    dots <- dots[!is.na(dots$x), , drop = FALSE]

    matrix_value_mode <- tolower(as.character(get_param(params, 'matrix_value_mode', 'binary') %||% 'binary')[1])
    # binary | continuous | fraction
    if (matrix_value_mode == 'binary') {
      dots$on <- dots$value > 0
      dots$fill_val <- ifelse(dots$on, 1, 0)
    } else {
      dots$on <- TRUE
      dots$fill_val <- dots$value
    }
  }

  # ---- horizontal reference lines (highly customizable) ----
  # params$hlines: list of {y, label, color, linewidth, linetype, label_x, label_y,
  #   label_size, label_color, label_face, label_hjust, label_vjust, label_angle,
  #   show_arrow, arrow_x, arrow_y}
  hlines_raw <- get_param(params, 'hlines', NULL)
  # also single-line convenience params
  hline_y <- get_param(params, 'hline_y', NULL)
  hlines <- list()
  if (is.list(hlines_raw) && length(hlines_raw) && !is.null(names(hlines_raw)) && 'y' %in% names(hlines_raw)) {
    # single object not list of objects
    hlines <- list(hlines_raw)
  } else if (is.list(hlines_raw) && length(hlines_raw)) {
    # list of line specs — may be unnamed list
    if (!is.null(names(hlines_raw)) && all(names(hlines_raw) != '')) {
      # named dict of lines? treat values as specs if they have y
      hlines <- lapply(hlines_raw, function(z) z)
      # filter to those that look like line objects
      hlines <- Filter(function(z) is.list(z) && !is.null(z$y), hlines)
      if (!length(hlines) && !is.null(hlines_raw$y)) hlines <- list(hlines_raw)
    } else {
      hlines <- hlines_raw
    }
  }
  if (!length(hlines) && !is.null(hline_y) && is.finite(as_num(hline_y, NA))) {
    hlines <- list(list(
      y = as_num(hline_y, 0.5),
      label = as.character(get_param(params, 'hline_label', '') %||% '')[1],
      color = as.character(get_param(params, 'hline_color', '#666666') %||% '#666666')[1],
      linewidth = as_num(get_param(params, 'hline_linewidth', 0.5), 0.5),
      linetype = as.character(get_param(params, 'hline_linetype', 'solid') %||% 'solid')[1],
      label_x = get_param(params, 'hline_label_x', NULL),
      label_y = get_param(params, 'hline_label_y', NULL),
      label_size = as_num(get_param(params, 'hline_label_size', 3.2), 3.2),
      label_color = as.character(get_param(params, 'hline_label_color', '#444444') %||% '#444444')[1],
      label_face = as.character(get_param(params, 'hline_label_face', 'plain') %||% 'plain')[1],
      label_hjust = as_num(get_param(params, 'hline_label_hjust', 0), 0),
      label_vjust = as_num(get_param(params, 'hline_label_vjust', 0.5), 0.5),
      label_angle = as_num(get_param(params, 'hline_label_angle', 0), 0),
      show_arrow = as_bool(get_param(params, 'hline_show_arrow', TRUE), TRUE)
    ))
  }

  # ---- style params ----
  bar_width <- as_num(get_param(params, 'bar_width', 0.72), 0.72)
  bar_alpha <- as_num(get_param(params, 'bar_alpha', 1), 1)
  errorbar_width <- as_num(get_param(params, 'errorbar_width', 0.22), 0.22)
  errorbar_linewidth <- as_num(get_param(params, 'errorbar_linewidth', 0.45), 0.45)
  errorbar_color <- as.character(get_param(params, 'errorbar_color', '#222222') %||% '#222222')[1]
  errorbar_show <- as_bool(get_param(params, 'errorbar_show', TRUE), TRUE)

  ylab <- as.character(get_param(params, 'ylab', 'AUPRC') %||% 'AUPRC')[1]
  xlab <- as.character(get_param(params, 'xlab', '') %||% '')[1]
  ylim <- get_param(params, 'ylim', NULL)
  y_min <- if (!is.null(ylim) && length(ylim) >= 1) as_num(ylim[[1]], 0) else as_num(get_param(params, 'ymin', 0), 0)
  y_max <- if (!is.null(ylim) && length(ylim) >= 2) as_num(ylim[[2]], NA) else as_num(get_param(params, 'ymax', NA), NA)
  if (!is.finite(y_max)) {
    y_max <- max(bars$ymax, na.rm = TRUE)
    if (!is.null(comparisons) && nrow(comparisons)) y_max <- y_max + 0.28
    else y_max <- y_max + 0.08
  }

  bracket_tip <- as_num(get_param(params, 'bracket_tip_length', 0.015), 0.015)
  bracket_linewidth <- as_num(get_param(params, 'bracket_linewidth', 0.4), 0.4)
  bracket_color <- as.character(get_param(params, 'bracket_color', '#333333') %||% '#333333')[1]
  bracket_text_size <- as_num(get_param(params, 'bracket_text_size', 2.8), 2.8)
  bracket_text_color <- as.character(get_param(params, 'bracket_text_color', '#333333') %||% '#333333')[1]
  bracket_base_y <- as_num(get_param(params, 'bracket_base_y', NA), NA)
  bracket_step <- as_num(get_param(params, 'bracket_step', 0.055), 0.055)

  # dots style
  dot_size <- as_num(get_param(params, 'dot_size', 3.2), 3.2)
  dot_stroke <- as_num(get_param(params, 'dot_stroke', 0.55), 0.55)
  dot_on_color <- as.character(get_param(params, 'dot_on_color', '#111111') %||% '#111111')[1]
  dot_off_color <- as.character(get_param(params, 'dot_off_color', '#FFFFFF') %||% '#FFFFFF')[1]
  dot_border_color <- as.character(get_param(params, 'dot_border_color', '#111111') %||% '#111111')[1]
  matrix_panel_border <- as_bool(get_param(params, 'matrix_panel_border', TRUE), TRUE)
  matrix_border_color <- as.character(get_param(params, 'matrix_border_color', '#333333') %||% '#333333')[1]
  matrix_border_width <- as_num(get_param(params, 'matrix_border_width', 0.5), 0.5)
  matrix_row_label_size <- as_num(get_param(params, 'matrix_row_label_size', 9), 9)
  matrix_show_x_text <- as_bool(get_param(params, 'matrix_show_x_text', FALSE), FALSE)
  # continuous heatmap dots
  matrix_low_color <- as.character(get_param(params, 'matrix_low_color', '#F7FBFF') %||% '#F7FBFF')[1]
  matrix_high_color <- as.character(get_param(params, 'matrix_high_color', '#08306B') %||% '#08306B')[1]
  matrix_mid_color <- as.character(get_param(params, 'matrix_mid_color', '#6BAED6') %||% '#6BAED6')[1]

  bar_height_rel <- as_num(get_param(params, 'bar_panel_height', 3.2), 3.2)
  mat_height_rel <- as_num(get_param(params, 'matrix_panel_height', 1.6), 1.6)
  panel_gap <- as_num(get_param(params, 'panel_gap', 0.08), 0.08)

  W <- as_num(get_param(params, 'width', max(6, n_x * 0.7 + 2)), max(6, n_x * 0.7 + 2))
  H <- as_num(get_param(params, 'height', if (show_matrix) 5.2 else 3.5), if (show_matrix) 5.2 else 3.5)
  dpi <- as_num(get_param(params, 'dpi', 300), 300)
  bg <- as.character(get_param(params, 'background_color', '#FFFFFF') %||% '#FFFFFF')[1]
  base_size <- as_num(get_param(params, 'base_size', 11), 11)
  font_family <- as.character(get_param(params, 'font_family', 'sans') %||% 'sans')[1]
  x_text_size <- as_num(get_param(params, 'x_text_size', 9), 9)
  x_text_angle <- as_num(get_param(params, 'x_text_angle', 45), 45)
  x_text_hjust <- as_num(get_param(params, 'x_text_hjust', 1), 1)
  y_text_size <- as_num(get_param(params, 'y_text_size', 10), 10)
  title_show <- as_bool(get_param(params, 'title_show', FALSE), FALSE)
  title <- as.character(get_param(params, 'title', '') %||% '')[1]

  # ---- build bar plot ----
  p_bar <- ggplot(bars, aes(x = x, y = y)) +
    geom_col(aes(fill = fill), width = bar_width, alpha = bar_alpha, colour = NA)

  if (errorbar_show && any(is.finite(bars$ymin) & bars$ymin != bars$y)) {
    p_bar <- p_bar + geom_errorbar(
      aes(ymin = ymin, ymax = ymax),
      width = errorbar_width,
      linewidth = errorbar_linewidth,
      colour = errorbar_color
    )
  }

  # hlines
  hline_label_df <- list()
  if (length(hlines)) {
    for (i in seq_along(hlines)) {
      hl <- hlines[[i]]
      if (is.null(hl) || is.null(hl$y)) next
      yy <- as_num(hl$y, NA)
      if (!is.finite(yy)) next
      col <- as.character(hl$color %||% '#666666')[1]
      lw <- as_num(hl$linewidth %||% hl$size, 0.5)
      lt <- as.character(hl$linetype %||% 'solid')[1]
      p_bar <- p_bar + geom_hline(yintercept = yy, colour = col, linewidth = lw, linetype = lt)
      lab <- as.character(hl$label %||% '')[1]
      if (nzchar(lab)) {
        lx <- as_num(hl$label_x, n_x + 0.35)
        # if label_x is character matching a category, map it
        if (!is.null(hl$label_x) && is.character(hl$label_x) && hl$label_x %in% x_order) {
          lx <- match(hl$label_x, x_order)
        }
        ly <- as_num(hl$label_y, yy + 0.03)
        hline_label_df[[length(hline_label_df) + 1]] <- data.frame(
          x = lx, y = ly, label = lab,
          color = as.character(hl$label_color %||% col)[1],
          size = as_num(hl$label_size, 3.2),
          face = as.character(hl$label_face %||% 'plain')[1],
          hjust = as_num(hl$label_hjust, 0),
          vjust = as_num(hl$label_vjust, 0.5),
          angle = as_num(hl$label_angle, 0),
          show_arrow = as_bool(hl$show_arrow, TRUE),
          arrow_x = as_num(hl$arrow_x, n_x + 0.05),
          arrow_y = as_num(hl$arrow_y, yy),
          line_y = yy,
          stringsAsFactors = FALSE
        )
      }
    }
  }
  if (length(hline_label_df)) {
    hld <- do.call(rbind, hline_label_df)
    for (i in seq_len(nrow(hld))) {
      if (isTRUE(hld$show_arrow[i])) {
        p_bar <- p_bar + annotate(
          'segment',
          x = hld$arrow_x[i], xend = hld$x[i] - 0.05,
          y = hld$line_y[i], yend = hld$y[i],
          colour = hld$color[i],
          linewidth = 0.35,
          arrow = arrow(length = unit(0.08, 'inches'), type = 'closed')
        )
      }
      p_bar <- p_bar + annotate(
        'text',
        x = hld$x[i], y = hld$y[i], label = hld$label[i],
        colour = hld$color[i], size = hld$size[i],
        fontface = hld$face[i], hjust = hld$hjust[i], vjust = hld$vjust[i],
        angle = hld$angle[i], family = font_family
      )
    }
  }

  # p-value brackets
  if (!is.null(comparisons) && nrow(comparisons)) {
    if (!is.finite(bracket_base_y)) {
      bracket_base_y <- max(bars$ymax, na.rm = TRUE) + 0.04
    }
    comparisons <- comparisons[order(pmin(comparisons$x1n, comparisons$x2n),
                                     pmax(comparisons$x1n, comparisons$x2n)), , drop = FALSE]
    comparisons$y <- bracket_base_y + (seq_len(nrow(comparisons)) - 1) * bracket_step
    for (i in seq_len(nrow(comparisons))) {
      x1 <- comparisons$x1n[i]; x2 <- comparisons$x2n[i]; yy <- comparisons$y[i]
      # bracket: vertical tips + horizontal bar
      p_bar <- p_bar +
        annotate('segment', x = x1, xend = x1, y = yy - bracket_tip, yend = yy,
                 colour = bracket_color, linewidth = bracket_linewidth) +
        annotate('segment', x = x2, xend = x2, y = yy - bracket_tip, yend = yy,
                 colour = bracket_color, linewidth = bracket_linewidth) +
        annotate('segment', x = x1, xend = x2, y = yy, yend = yy,
                 colour = bracket_color, linewidth = bracket_linewidth) +
        annotate('text', x = (x1 + x2) / 2, y = yy + bracket_tip * 0.8,
                 label = comparisons$label[i], size = bracket_text_size,
                 colour = bracket_text_color, family = font_family, vjust = 0)
    }
    y_max <- max(y_max, max(comparisons$y) + bracket_step)
  }

  # bar top annotations from column
  if (any(!is.na(bars$annotation) & nzchar(bars$annotation))) {
    ann <- bars[!is.na(bars$annotation) & nzchar(bars$annotation), , drop = FALSE]
    p_bar <- p_bar + geom_text(
      data = ann, aes(x = x, y = ymax, label = annotation),
      vjust = -0.5, size = as_num(get_param(params, 'bar_annotation_size', 2.8), 2.8),
      colour = as.character(get_param(params, 'bar_annotation_color', '#333333') %||% '#333333')[1],
      family = font_family
    )
  }

  p_bar <- p_bar +
    scale_fill_identity() +
    scale_y_continuous(limits = c(y_min, y_max), expand = expansion(mult = c(0, 0.02)),
                       name = ylab) +
    scale_x_discrete(drop = FALSE) +
    theme_classic(base_size = base_size, base_family = font_family) +
    theme(
      plot.background = element_rect(fill = bg, colour = NA),
      panel.background = element_rect(fill = bg, colour = NA),
      axis.title.x = element_blank(),
      axis.text.x = if (show_matrix && !matrix_show_x_text) {
        element_blank()
      } else {
        element_text(size = x_text_size, angle = x_text_angle, hjust = x_text_hjust)
      },
      axis.ticks.x = if (show_matrix && !matrix_show_x_text) element_blank() else element_line(),
      axis.text.y = element_text(size = y_text_size),
      axis.line = element_line(colour = '#333333', linewidth = 0.45),
      plot.margin = margin(8, 28, 2, 8)
    )

  if (title_show && nzchar(title)) {
    p_bar <- p_bar + ggtitle(title) +
      theme(plot.title = element_text(size = as_num(get_param(params, 'title_size', 13), 13),
                                      face = 'bold', hjust = 0))
  }

  # ---- matrix plot ----
  p_mat <- NULL
  if (show_matrix && !is.null(dots) && nrow(dots)) {
    matrix_value_mode <- tolower(as.character(get_param(params, 'matrix_value_mode', 'binary') %||% 'binary')[1])
    p_mat <- ggplot(dots, aes(x = x, y = feature))

    if (matrix_value_mode == 'binary') {
      p_mat <- p_mat +
        geom_point(
          data = dots, aes(x = x, y = feature),
          shape = 21, size = dot_size, stroke = dot_stroke,
          fill = ifelse(dots$fill_val > 0, dot_on_color, dot_off_color),
          colour = dot_border_color
        )
    } else {
      # continuous heatmap-style dots
      p_mat <- p_mat +
        geom_point(
          aes(fill = fill_val),
          shape = 21, size = dot_size, stroke = dot_stroke, colour = dot_border_color
        ) +
        scale_fill_gradient2(
          low = matrix_low_color, mid = matrix_mid_color, high = matrix_high_color,
          midpoint = mean(range(dots$fill_val, na.rm = TRUE)),
          guide = if (as_bool(get_param(params, 'matrix_legend_show', FALSE), FALSE)) 'colourbar' else 'none'
        )
    }

    p_mat <- p_mat +
      scale_x_discrete(drop = FALSE, position = 'bottom') +
      scale_y_discrete(drop = FALSE) +
      theme_classic(base_size = base_size, base_family = font_family) +
      theme(
        plot.background = element_rect(fill = bg, colour = NA),
        panel.background = element_rect(fill = bg, colour = if (matrix_panel_border) matrix_border_color else NA,
                                        linewidth = matrix_border_width),
        axis.title = element_blank(),
        axis.text.x = if (matrix_show_x_text) {
          element_text(size = x_text_size, angle = x_text_angle, hjust = x_text_hjust)
        } else {
          element_blank()
        },
        axis.ticks.x = if (matrix_show_x_text) element_line() else element_blank(),
        axis.text.y = element_text(size = matrix_row_label_size, colour = '#222222'),
        axis.line = element_blank(),
        legend.position = if (matrix_value_mode != 'binary' && as_bool(get_param(params, 'matrix_legend_show', FALSE), FALSE)) 'right' else 'none',
        plot.margin = margin(2, 28, 8, 8)
      )

    # optional x-axis context label under matrix
    x_context <- as.character(get_param(params, 'x_context_label', '') %||% '')[1]
    if (nzchar(x_context)) {
      p_mat <- p_mat + xlab(x_context) +
        theme(axis.title.x = element_text(size = x_text_size, colour = '#444444'))
    } else if (nzchar(xlab)) {
      p_mat <- p_mat + xlab(xlab) +
        theme(axis.title.x = element_text(size = x_text_size))
    }
  }

  # ---- combine ----
  write_log('Composing panels')
  if (show_matrix && !is.null(p_mat)) {
    if (requireNamespace('patchwork', quietly = TRUE)) {
      # align x axes
      p_bar <- p_bar + theme(axis.title.x = element_blank())
      combined <- p_bar / p_mat + patchwork::plot_layout(heights = c(bar_height_rel, mat_height_rel))
      combined <- combined & theme(plot.background = element_rect(fill = bg, colour = NA))
    } else if (requireNamespace('cowplot', quietly = TRUE)) {
      combined <- cowplot::plot_grid(
        p_bar, p_mat, ncol = 1, align = 'v', axis = 'lr',
        rel_heights = c(bar_height_rel, mat_height_rel)
      )
    } else {
      combined <- p_bar
      write_log('patchwork/cowplot missing — bar panel only')
    }
  } else {
    combined <- p_bar
  }

  write_log('Rendering SVG/PDF/PNG')
  save_one <- function(dev_fn) {
    dev_fn()
    print(combined)
    grDevices::dev.off()
  }
  save_one(function() svglite::svglite(file.path(output_dir, 'result.svg'), width = W, height = H))
  save_one(function() grDevices::cairo_pdf(file.path(output_dir, 'result.pdf'), width = W, height = H))
  save_one(function() (if (requireNamespace('ragg', quietly = TRUE)) ragg::agg_png else function(...) grDevices::png(..., type = 'cairo'))(
    file.path(output_dir, 'result.png'), width = W, height = H, units = 'in', res = dpi))

  write.csv(bars, file.path(output_dir, 'bars_used.csv'), row.names = FALSE)
  if (!is.null(dots) && nrow(dots)) write.csv(dots, file.path(output_dir, 'matrix_used.csv'), row.names = FALSE)
  else write.csv(data.frame(), file.path(output_dir, 'matrix_used.csv'), row.names = FALSE)

  meta <- list(
    plugin = 'combo_bar_dot_matrix',
    engine = 'ggplot2 + patchwork',
    n_bars = nrow(bars),
    n_x = n_x,
    matrix_show = show_matrix,
    n_matrix_cells = if (!is.null(dots)) nrow(dots) else 0,
    n_comparisons = if (!is.null(comparisons)) nrow(comparisons) else 0,
    n_hlines = length(hlines),
    outputs = c('result.svg', 'result.pdf', 'result.png', 'bars_used.csv', 'matrix_used.csv')
  )
  writeLines(jsonlite::toJSON(meta, auto_unbox = TRUE, pretty = TRUE, null = 'null'),
             file.path(output_dir, 'figure.json'))
  write_log('Completed combo_bar_dot_matrix')
  quit(status = 0)

}, error = function(e) {
  write_error_and_exit(
    'Combo bar + dot matrix failed',
    conditionMessage(e),
    'Provide bar table (x, y) and optional matrix/comparisons. Check hlines y is numeric.'
  )
})
