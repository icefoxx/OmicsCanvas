#!/usr/bin/env Rscript

# BioFigureAI Plot Plugin: Pie Dot Matrix
# ------------------------------------------------------------
# Matrix of circles; filled pie portion = continuous value
# (gene ratio, correlation, prevalence, score). Optional center
# marks (star/plus/cross/…). Column group bands + row stripes.
#
# Runtime:
#   Rscript plot.R --input input.csv --params params.json --output out
#                  [--col_annot col_annot.csv] [--row_annot row_annot.csv]
#                  [--marks marks.csv]

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
})

option_list <- list(
  make_option('--input', type = 'character', default = NULL),
  make_option('--params', type = 'character', default = NULL),
  make_option('--output', type = 'character', default = NULL),
  make_option('--col_annot', type = 'character', default = NULL),
  make_option('--row_annot', type = 'character', default = NULL),
  make_option('--marks', type = 'character', default = NULL)
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
  if (is.null(path) || !nzchar(path) || !file.exists(path)) return(NULL)
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

sci_palette <- function(n, name = 'npg') {
  pals <- list(
    npg = c('#3C5488', '#4DBBD5', '#00A087', '#E64B35', '#F39B7F', '#8491B4', '#91D1C2', '#DC0000', '#7E6148', '#B09C85'),
    ocean = c('#1B3A6B', '#2E5A9C', '#4A90C8', '#5BA3D9', '#7EC8E8', '#A8D8EA'),
    habitat = c('#2C3E8C', '#3D5A9E', '#1E90C8', '#6B3FA0', '#2A9D8F', '#8B5A2B', '#C9A227', '#6B7280'),
    aaas = c('#3B4992', '#EE0000', '#008B45', '#631879', '#008280', '#BB0021', '#5F559B', '#A20056'),
    soft = c('#6B8FCE', '#7EB8D8', '#5BC0DE', '#9B7EBD', '#6DB3A8', '#C4A574', '#E8C547', '#A0AEC0')
  )
  base <- pals[[tolower(name %||% 'habitat')]] %||% pals$habitat
  if (n <= length(base)) return(base[seq_len(n)])
  grDevices::colorRampPalette(base)(n)
}

# Build pie wedge polygon for one cell (fraction in [0,1])
# start_angle in degrees, 0 = right, 90 = top (ggplot cartesian)
pie_poly <- function(x, y, r, fraction, start_deg = 90, clockwise = TRUE, n = 48) {
  fraction <- max(0, min(1, fraction))
  if (fraction <= 0) {
    return(data.frame(x = numeric(), y = numeric()))
  }
  if (fraction >= 1) {
    th <- seq(0, 2 * pi, length.out = n + 1)
    return(data.frame(x = x + r * cos(th), y = y + r * sin(th)))
  }
  start <- start_deg * pi / 180
  sweep <- 2 * pi * fraction
  if (clockwise) {
    th <- seq(start, start - sweep, length.out = max(3L, ceiling(n * fraction) + 1L))
  } else {
    th <- seq(start, start + sweep, length.out = max(3L, ceiling(n * fraction) + 1L))
  }
  data.frame(
    x = c(x, x + r * cos(th), x),
    y = c(y, y + r * sin(th), y)
  )
}

circle_poly <- function(x, y, r, n = 48) {
  th <- seq(0, 2 * pi, length.out = n + 1)
  data.frame(x = x + r * cos(th), y = y + r * sin(th))
}

mark_to_shape <- function(mark) {
  m <- tolower(trimws(as.character(mark %||% '')))
  if (!nzchar(m) || m %in% c('none', 'na', 'false', '0')) return(NA_integer_)
  map <- c(
    star = 8L, asterisk = 8L, `*` = 8L,
    plus = 3L, cross = 4L, x = 4L,
    diamond = 5L, triangle = 2L, square = 0L,
    circle = 1L, point = 16L, dot = 16L
  )
  if (m %in% names(map)) return(unname(map[[m]]))
  # unicode / free text → use text layer instead
  NA_integer_
}

mark_to_text <- function(mark) {
  m <- as.character(mark %||% '')
  if (!nzchar(trimws(m))) return(NA_character_)
  low <- tolower(trimws(m))
  if (low %in% c('none', 'na', 'false', '0', 'star', 'asterisk', '*', 'plus', 'cross', 'x',
                 'diamond', 'triangle', 'square', 'circle', 'point', 'dot')) {
    # shape-based
    if (low %in% c('star', 'asterisk', '*')) return('★')
    return(NA_character_)
  }
  m
}

# ------------------------------------------------------------
tryCatch({
  if (is.null(output_dir) || !nzchar(output_dir)) {
    write_error_and_exit('Missing --output')
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  if (file.exists(file.path(output_dir, 'error.json'))) unlink(file.path(output_dir, 'error.json'))
  write_log('Starting pie_dot_matrix')

  if (is.null(params_file) || !file.exists(params_file)) {
    write_error_and_exit('Missing params.json', params_file)
  }
  params <- jsonlite::fromJSON(params_file, simplifyVector = FALSE)
  raw <- read_table_auto(input_file)
  if (is.null(raw) || !nrow(raw)) write_error_and_exit('Input empty or missing', input_file)

  mode <- tolower(as.character(get_param(params, 'input_mode', 'auto') %||% 'auto')[1])
  row_col <- as.character(get_param(params, 'row_column', names(raw)[1]) %||% names(raw)[1])[1]
  col_col <- as.character(get_param(params, 'column_column', 'column') %||% 'column')[1]
  val_col <- as.character(get_param(params, 'value_column', 'value') %||% 'value')[1]
  mark_col <- as.character(get_param(params, 'mark_column', 'mark') %||% 'mark')[1]
  group_col <- as.character(get_param(params, 'group_column', 'group') %||% 'group')[1]
  color_col <- as.character(get_param(params, 'color_column', 'color') %||% 'color')[1]

  # detect mode
  if (mode == 'auto') {
    if (col_col %in% names(raw) && val_col %in% names(raw)) mode <- 'long' else mode <- 'wide'
  }
  write_log(sprintf('Input mode: %s (%d x %d)', mode, nrow(raw), ncol(raw)))

  long_df <- NULL
  if (mode == 'wide') {
    if (!row_col %in% names(raw)) {
      write_error_and_exit('row_column not found', paste(names(raw), collapse = ', '))
    }
    value_columns <- as_chr_vec(get_param(params, 'value_columns', NULL))
    if (!length(value_columns)) {
      value_columns <- setdiff(names(raw), row_col)
      # keep numeric-ish
      value_columns <- value_columns[vapply(value_columns, function(cn) {
        suppressWarnings(any(is.finite(as.numeric(raw[[cn]]))))
      }, logical(1))]
    }
    if (!length(value_columns)) {
      write_error_and_exit('No value columns found in wide matrix')
    }
    pieces <- lapply(value_columns, function(cn) {
      data.frame(
        row = as.character(raw[[row_col]]),
        column = cn,
        value = suppressWarnings(as.numeric(raw[[cn]])),
        stringsAsFactors = FALSE
      )
    })
    long_df <- do.call(rbind, pieces)
    # preserve row order with unique y for duplicate labels
    long_df$row_id <- rep(seq_len(nrow(raw)), times = length(value_columns))
    long_df$row_label <- long_df$row
  } else {
    need <- c(row_col, col_col, val_col)
    if (!all(need %in% names(raw))) {
      write_error_and_exit('Missing long columns', paste(need, collapse = ', '))
    }
    long_df <- data.frame(
      row = as.character(raw[[row_col]]),
      column = as.character(raw[[col_col]]),
      value = suppressWarnings(as.numeric(raw[[val_col]])),
      stringsAsFactors = FALSE
    )
    if (mark_col %in% names(raw)) long_df$mark <- as.character(raw[[mark_col]])
    if (group_col %in% names(raw)) long_df$group <- as.character(raw[[group_col]])
    if (color_col %in% names(raw)) long_df$color <- as.character(raw[[color_col]])
    # unique row order by first appearance
    row_levels <- unique(long_df$row)
    long_df$row_id <- match(long_df$row, row_levels)
    long_df$row_label <- long_df$row
  }

  long_df$value[!is.finite(long_df$value)] <- 0

  # external marks file
  marks_file <- opt$marks
  if (is.null(marks_file) || !nzchar(marks_file %||% '')) {
    # also allow path in params
    marks_file <- as.character(get_param(params, 'marks_file', '') %||% '')[1]
  }
  marks_df <- read_table_auto(marks_file)
  if (!is.null(marks_df) && nrow(marks_df)) {
    mc_row <- as.character(get_param(params, 'marks_row_column', names(marks_df)[1]) %||% names(marks_df)[1])[1]
    mc_col <- as.character(get_param(params, 'marks_column_column', names(marks_df)[2]) %||% names(marks_df)[2])[1]
    mc_mark <- as.character(get_param(params, 'marks_mark_column', 'mark') %||% 'mark')[1]
    if (!mc_mark %in% names(marks_df)) mc_mark <- names(marks_df)[3]
    key <- paste(long_df$row_label, long_df$column, sep = '\r')
    mkey <- paste(as.character(marks_df[[mc_row]]), as.character(marks_df[[mc_col]]), sep = '\r')
    long_df$mark <- ifelse(is.null(long_df$mark), NA_character_, long_df$mark)
    hit <- match(key, mkey)
    long_df$mark <- ifelse(!is.na(hit), as.character(marks_df[[mc_mark]][hit]), long_df$mark)
  }
  if (is.null(long_df$mark)) long_df$mark <- NA_character_

  # filters
  rows_include <- as_chr_vec(get_param(params, 'rows_include', NULL))
  rows_exclude <- as_chr_vec(get_param(params, 'rows_exclude', NULL))
  cols_include <- as_chr_vec(get_param(params, 'columns_include', NULL))
  cols_exclude <- as_chr_vec(get_param(params, 'columns_exclude', NULL))
  if (length(rows_include)) long_df <- long_df[long_df$row_label %in% rows_include, , drop = FALSE]
  if (length(rows_exclude)) long_df <- long_df[!long_df$row_label %in% rows_exclude, , drop = FALSE]
  if (length(cols_include)) long_df <- long_df[long_df$column %in% cols_include, , drop = FALSE]
  if (length(cols_exclude)) long_df <- long_df[!long_df$column %in% cols_exclude, , drop = FALSE]
  if (!nrow(long_df)) write_error_and_exit('No cells remaining after filtering')

  # value scaling → fraction
  value_mode <- tolower(as.character(get_param(params, 'value_mode', 'fraction') %||% 'fraction')[1])
  # fraction: already 0-1; abs_correlation: abs then clamp; rescale: min-max; binary: >0 → 1
  if (value_mode == 'binary') {
    long_df$fraction <- ifelse(long_df$value > 0, 1, 0)
  } else if (value_mode == 'abs_correlation' || value_mode == 'abs') {
    long_df$fraction <- pmin(1, pmax(0, abs(long_df$value)))
  } else if (value_mode == 'rescale' || value_mode == 'minmax') {
    rng <- range(long_df$value, na.rm = TRUE)
    if (diff(rng) < 1e-12) long_df$fraction <- ifelse(long_df$value > 0, 1, 0)
    else long_df$fraction <- (long_df$value - rng[1]) / diff(rng)
  } else if (value_mode == 'percent') {
    long_df$fraction <- pmin(1, pmax(0, long_df$value / 100))
  } else {
    # fraction / ratio / correlation in [0,1] (negatives → 0 unless abs)
    long_df$fraction <- pmin(1, pmax(0, long_df$value))
  }

  min_show <- as_num(get_param(params, 'min_value_show', 0), 0)
  # keep zeros as hollow circles

  # orders
  col_order <- as_chr_vec(get_param(params, 'column_order', NULL))
  row_order <- as_chr_vec(get_param(params, 'row_order', NULL))
  cols_present <- unique(long_df$column)
  if (length(col_order)) cols_present <- c(col_order[col_order %in% cols_present], setdiff(cols_present, col_order))
  # rows: preserve input order of row_id
  row_map <- unique(long_df[, c('row_id', 'row_label')])
  row_map <- row_map[order(row_map$row_id), , drop = FALSE]
  if (length(row_order)) {
    # reorder groups of labels
    idx <- order(match(row_map$row_label, c(row_order, setdiff(unique(row_map$row_label), row_order)), nomatch = 1e9))
    row_map <- row_map[idx, , drop = FALSE]
    row_map$row_id <- seq_len(nrow(row_map))
    long_df$row_id <- match(paste(long_df$row_label, long_df$column, long_df$value),
                            paste(long_df$row_label, long_df$column, long_df$value)) # fragile
    # simpler remap by first occurrence of (row_label, original row_id)
  }
  # stable: reassign y from unique row_id sorted
  uid <- sort(unique(long_df$row_id))
  long_df$y <- match(long_df$row_id, uid)
  long_df$x <- match(long_df$column, cols_present)
  n_rows <- length(uid)
  n_cols <- length(cols_present)

  # label map for y axis: for duplicate labels, show only first of each run or all
  y_labels <- vapply(uid, function(i) {
    long_df$row_label[match(i, long_df$row_id)]
  }, character(1))
  label_duplicates <- as_bool(get_param(params, 'label_duplicate_rows', FALSE), FALSE)
  if (!label_duplicates) {
    # show label only at first occurrence of each consecutive label
    show_lab <- rep(TRUE, length(y_labels))
    if (length(y_labels) > 1) {
      for (i in seq(2, length(y_labels))) {
        if (identical(y_labels[i], y_labels[i - 1])) show_lab[i] <- FALSE
      }
    }
    y_axis_labels <- ifelse(show_lab, y_labels, '')
  } else {
    y_axis_labels <- y_labels
  }

  # colors by row category (label)
  palette_name <- as.character(get_param(params, 'palette', 'habitat') %||% 'habitat')[1]
  row_colors <- named_chr(get_param(params, 'row_colors', NULL))
  cats <- unique(y_labels)
  col_map <- sci_palette(length(cats), palette_name)
  names(col_map) <- cats
  if (length(row_colors)) {
    for (nm in names(row_colors)) if (nm %in% names(col_map) && nzchar(row_colors[[nm]])) col_map[[nm]] <- row_colors[[nm]]
  }
  # row_annot override
  row_annot <- read_table_auto(opt$row_annot)
  if (!is.null(row_annot) && nrow(row_annot)) {
    rid <- as.character(get_param(params, 'row_annot_id_column', names(row_annot)[1]) %||% names(row_annot)[1])[1]
    rcolor <- as.character(get_param(params, 'row_annot_color_column', 'color') %||% 'color')[1]
    if (rcolor %in% names(row_annot)) {
      for (i in seq_len(nrow(row_annot))) {
        nm <- as.character(row_annot[[rid]][i])
        if (nm %in% names(col_map)) col_map[[nm]] <- as.character(row_annot[[rcolor]][i])
      }
    }
  }
  long_df$fill <- unname(col_map[long_df$row_label])
  long_df$fill[is.na(long_df$fill)] <- '#888888'

  # column annotation
  col_annot <- read_table_auto(opt$col_annot)
  col_ann_df <- NULL
  if (!is.null(col_annot) && nrow(col_annot)) {
    cid <- as.character(get_param(params, 'col_annot_id_column', names(col_annot)[1]) %||% names(col_annot)[1])[1]
    cgroup <- as.character(get_param(params, 'col_annot_group_column', 'group') %||% 'group')[1]
    ccolor <- as.character(get_param(params, 'col_annot_color_column', 'color') %||% 'color')[1]
    col_ann_df <- data.frame(
      column = as.character(col_annot[[cid]]),
      group = if (cgroup %in% names(col_annot)) as.character(col_annot[[cgroup]]) else 'Group',
      color = if (ccolor %in% names(col_annot)) as.character(col_annot[[ccolor]]) else '#DDDDDD',
      stringsAsFactors = FALSE
    )
    col_ann_df <- col_ann_df[col_ann_df$column %in% cols_present, , drop = FALSE]
    col_ann_df$x <- match(col_ann_df$column, cols_present)
  }

  # geometry params
  r <- as_num(get_param(params, 'circle_radius', 0.38), 0.38)
  r <- max(0.08, min(0.48, r))
  empty_fill <- as.character(get_param(params, 'empty_fill', '#FFFFFF') %||% '#FFFFFF')[1]
  empty_border <- as.character(get_param(params, 'circle_border_color', '#222222') %||% '#222222')[1]
  border_width <- as_num(get_param(params, 'circle_border_width', 0.45), 0.45)
  pie_start <- as_num(get_param(params, 'pie_start_angle', 90), 90)
  pie_clockwise <- as_bool(get_param(params, 'pie_clockwise', TRUE), TRUE)
  pie_n <- as.integer(as_num(get_param(params, 'pie_segments', 48), 48))
  show_zero <- as_bool(get_param(params, 'show_zero_circles', TRUE), TRUE)
  stripe_show <- as_bool(get_param(params, 'row_stripe_show', TRUE), TRUE)
  stripe_alpha <- as_num(get_param(params, 'row_stripe_alpha', 0.12), 0.12)
  col_band_show <- as_bool(get_param(params, 'column_band_show', TRUE), TRUE)
  col_band_height <- as_num(get_param(params, 'column_band_height', 0.35), 0.35)

  # build polygon layers
  empty_polys <- list()
  pie_polys <- list()
  ei <- 0L
  pi <- 0L
  for (i in seq_len(nrow(long_df))) {
    xi <- long_df$x[i]; yi <- long_df$y[i]
    fr <- long_df$fraction[i]
    if (!show_zero && fr <= 0) next
    ei <- ei + 1L
    ep <- circle_poly(xi, yi, r, n = pie_n)
    ep$id <- ei
    empty_polys[[ei]] <- ep
    if (fr > 0) {
      pi <- pi + 1L
      pp <- pie_poly(xi, yi, r, fr, start_deg = pie_start, clockwise = pie_clockwise, n = pie_n)
      if (nrow(pp)) {
        pp$id <- pi
        pp$fill <- long_df$fill[i]
        pie_polys[[pi]] <- pp
      }
    }
  }
  empty_df <- if (length(empty_polys)) do.call(rbind, empty_polys) else data.frame(x = numeric(), y = numeric(), id = integer())
  pie_df <- if (length(pie_polys)) do.call(rbind, pie_polys) else data.frame(x = numeric(), y = numeric(), id = integer(), fill = character())

  # marks
  mark_df <- long_df[!is.na(long_df$mark) & nzchar(as.character(long_df$mark)) &
                       !tolower(as.character(long_df$mark)) %in% c('none', 'na', 'false', '0'),
                     c('x', 'y', 'mark', 'fill'), drop = FALSE]
  mark_df$shape <- vapply(mark_df$mark, mark_to_shape, integer(1))
  mark_df$label <- vapply(mark_df$mark, mark_to_text, character(1))
  mark_shape_df <- mark_df[!is.na(mark_df$shape), , drop = FALSE]
  mark_text_df <- mark_df[!is.na(mark_df$label) & nzchar(mark_df$label), , drop = FALSE]
  # stars as text always for nicer look
  star_mask <- tolower(trimws(as.character(mark_df$mark))) %in% c('star', 'asterisk', '*')
  if (any(star_mask)) {
    star_df <- mark_df[star_mask, , drop = FALSE]
    star_df$label <- '★'
    mark_text_df <- rbind(mark_text_df, star_df[, c('x', 'y', 'mark', 'fill', 'shape', 'label')])
    mark_shape_df <- mark_shape_df[!tolower(trimws(as.character(mark_shape_df$mark))) %in% c('star', 'asterisk', '*'), , drop = FALSE]
  }

  mark_size <- as_num(get_param(params, 'mark_size', 2.8), 2.8)
  mark_color <- as.character(get_param(params, 'mark_color', '#111111') %||% '#111111')[1]
  mark_use_row_color <- as_bool(get_param(params, 'mark_use_row_color', FALSE), FALSE)

  # row stripes
  stripe_df <- data.frame(
    ymin = seq_len(n_rows) - 0.5,
    ymax = seq_len(n_rows) + 0.5,
    label = y_labels,
    stringsAsFactors = FALSE
  )
  stripe_df$fill <- unname(col_map[stripe_df$label])
  stripe_df$fill[is.na(stripe_df$fill)] <- '#CCCCCC'

  # plot
  W <- as_num(get_param(params, 'width', max(8, n_cols * 0.32 + 2.5)), max(8, n_cols * 0.32 + 2.5))
  H <- as_num(get_param(params, 'height', max(4, n_rows * 0.45 + 1.8)), max(4, n_rows * 0.45 + 1.8))
  dpi <- as_num(get_param(params, 'dpi', 300), 300)
  bg <- as.character(get_param(params, 'background_color', '#FFFFFF') %||% '#FFFFFF')[1]
  panel_border <- as_bool(get_param(params, 'panel_border', TRUE), TRUE)
  panel_border_color <- as.character(get_param(params, 'panel_border_color', '#333333') %||% '#333333')[1]
  panel_border_width <- as_num(get_param(params, 'panel_border_width', 0.6), 0.6)

  base_size <- as_num(get_param(params, 'base_size', 11), 11)
  font_family <- as.character(get_param(params, 'font_family', 'sans') %||% 'sans')[1]
  x_text_size <- as_num(get_param(params, 'x_text_size', 8), 8)
  y_text_size <- as_num(get_param(params, 'y_text_size', 10), 10)
  x_text_angle <- as_num(get_param(params, 'x_text_angle', 90), 90)
  x_text_color <- as.character(get_param(params, 'x_text_color', '#222222') %||% '#222222')[1]
  y_text_color <- as.character(get_param(params, 'y_text_color', '#222222') %||% '#222222')[1]
  x_hjust <- as_num(get_param(params, 'x_text_hjust', 1), 1)
  x_vjust <- as_num(get_param(params, 'x_text_vjust', 0.5), 0.5)

  title_show <- as_bool(get_param(params, 'title_show', FALSE), FALSE)
  title <- as.character(get_param(params, 'title', 'Pie Dot Matrix') %||% 'Pie Dot Matrix')[1]
  title_size <- as_num(get_param(params, 'title_size', 14), 14)
  legend_show <- as_bool(get_param(params, 'legend_show', FALSE), FALSE)

  g <- ggplot()

  if (stripe_show) {
    g <- g + geom_rect(
      data = stripe_df,
      aes(xmin = 0.5, xmax = n_cols + 0.5, ymin = ymin, ymax = ymax, fill = fill),
      alpha = stripe_alpha, colour = NA, inherit.aes = FALSE
    )
  }

  if (col_band_show && !is.null(col_ann_df) && nrow(col_ann_df)) {
    band_y0 <- n_rows + 0.55
    band_y1 <- n_rows + 0.55 + col_band_height
    g <- g + geom_rect(
      data = col_ann_df,
      aes(xmin = x - 0.5, xmax = x + 0.5, ymin = band_y0, ymax = band_y1, fill = color),
      colour = NA, inherit.aes = FALSE
    )
  }

  if (nrow(empty_df)) {
    g <- g + geom_polygon(
      data = empty_df,
      aes(x = x, y = y, group = id),
      fill = empty_fill, colour = empty_border, linewidth = border_width
    )
  }
  if (nrow(pie_df)) {
    g <- g + geom_polygon(
      data = pie_df,
      aes(x = x, y = y, group = id, fill = fill),
      colour = empty_border, linewidth = border_width * 0.6
    )
  }

  # redraw borders on full circles for crisp edge
  if (nrow(empty_df)) {
    g <- g + geom_polygon(
      data = empty_df,
      aes(x = x, y = y, group = id),
      fill = NA, colour = empty_border, linewidth = border_width
    )
  }

  if (nrow(mark_shape_df)) {
    g <- g + geom_point(
      data = mark_shape_df,
      aes(x = x, y = y, shape = factor(shape)),
      size = mark_size,
      colour = if (mark_use_row_color) mark_shape_df$fill else mark_color,
      stroke = 0.8,
      inherit.aes = FALSE
    ) + scale_shape_manual(values = setNames(as.integer(levels(factor(mark_shape_df$shape))), levels(factor(mark_shape_df$shape))), guide = 'none')
  }
  if (nrow(mark_text_df)) {
    g <- g + geom_text(
      data = mark_text_df,
      aes(x = x, y = y, label = label),
      size = mark_size,
      colour = if (mark_use_row_color) mark_text_df$fill else mark_color,
      family = font_family,
      vjust = 0.4,
      inherit.aes = FALSE
    )
  }

  g <- g + scale_fill_identity()
  g <- g + scale_x_continuous(
    breaks = seq_len(n_cols),
    labels = cols_present,
    expand = expansion(mult = 0, add = 0.15),
    position = 'top'
  )
  g <- g + scale_y_reverse(
    breaks = seq_len(n_rows),
    labels = y_axis_labels,
    expand = expansion(mult = 0, add = 0.15)
  )

  g <- g + coord_fixed(ratio = 1, clip = 'off')
  g <- g + theme_void(base_size = base_size, base_family = font_family)
  g <- g + theme(
    plot.background = element_rect(fill = bg, colour = NA),
    panel.background = element_rect(fill = bg, colour = if (panel_border) panel_border_color else NA,
                                    linewidth = panel_border_width),
    axis.text.x = element_text(
      size = x_text_size, colour = x_text_color, angle = x_text_angle,
      hjust = x_hjust, vjust = x_vjust
    ),
    axis.text.y = element_text(size = y_text_size, colour = y_text_color, hjust = 1),
    plot.margin = margin(
      as_num(get_param(params, 'margin_top', 12), 12),
      as_num(get_param(params, 'margin_right', 10), 10),
      as_num(get_param(params, 'margin_bottom', 8), 8),
      as_num(get_param(params, 'margin_left', 8), 8)
    ),
    legend.position = if (legend_show) 'right' else 'none'
  )

  if (title_show && nzchar(title)) {
    g <- g + labs(title = title) +
      theme(plot.title = element_text(
        size = title_size,
        colour = as.character(get_param(params, 'title_color', '#222222') %||% '#222222')[1],
        face = as.character(get_param(params, 'title_face', 'bold') %||% 'bold')[1],
        hjust = as_num(get_param(params, 'title_hjust', 0.5), 0.5)
      ))
  }

  # optional legend for row colors via dummy points
  if (legend_show) {
    leg <- data.frame(label = cats, fill = unname(col_map[cats]), stringsAsFactors = FALSE)
    g <- g + geom_point(
      data = leg, aes(x = -Inf, y = -Inf, colour = label), size = 0, show.legend = TRUE
    ) + scale_color_manual(values = setNames(leg$fill, leg$label), name = as.character(get_param(params, 'legend_title', 'Category') %||% 'Category')[1])
  }

  write_log('Rendering SVG/PDF/PNG')
  save_one <- function(dev_fn) {
    dev_fn()
    print(g)
    grDevices::dev.off()
  }
  save_one(function() svglite::svglite(file.path(output_dir, 'result.svg'), width = W, height = H))
  save_one(function() grDevices::cairo_pdf(file.path(output_dir, 'result.pdf'), width = W, height = H))
  save_one(function() grDevices::png(
    file.path(output_dir, 'result.png'), width = W, height = H, units = 'in', res = dpi, type = 'cairo'
  ))

  write.csv(long_df, file.path(output_dir, 'cells_used.csv'), row.names = FALSE)
  # wide matrix used
  wide_out <- reshape(
    long_df[, c('row_id', 'row_label', 'column', 'value')],
    idvar = c('row_id', 'row_label'), timevar = 'column', direction = 'wide'
  )
  write.csv(wide_out, file.path(output_dir, 'matrix_used.csv'), row.names = FALSE)

  meta <- list(
    plugin = 'pie_dot_matrix',
    engine = 'ggplot2 pie polygons',
    input_mode = mode,
    n_rows = n_rows,
    n_cols = n_cols,
    n_cells = nrow(long_df),
    value_mode = value_mode,
    categories = cats,
    columns = cols_present,
    n_marks = nrow(mark_df),
    outputs = c('result.svg', 'result.pdf', 'result.png', 'cells_used.csv', 'matrix_used.csv')
  )
  writeLines(jsonlite::toJSON(meta, auto_unbox = TRUE, pretty = TRUE, null = 'null'),
             file.path(output_dir, 'figure.json'))
  write_log('Completed pie_dot_matrix')
  quit(status = 0)

}, error = function(e) {
  write_error_and_exit(
    'Pie dot matrix failed',
    conditionMessage(e),
    'Check row/value columns, value_mode (fraction/binary/rescale), and mark file format.'
  )
})
