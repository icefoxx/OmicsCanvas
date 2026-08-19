#!/usr/bin/env Rscript

# BioFigureAI Plot Plugin: Balloon Plot
# ------------------------------------------------------------
# Rewritten, robust and highly customizable version of the SCA
# `statBalloonplot.R` function. Plots a tile/balloon matrix where
# each cell is sized by its value, with optional row/column
# summary statistics on the margins.
#
# Runtime contract:
#   Rscript plot.R --input matrix.csv --params params.json --output output_dir
#
# Input is a CSV/TSV/TXT matrix. First column is row id by default;
# remaining columns are sample/column values.

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
  library(reshape2)
  library(scales)
})

option_list <- list(
  make_option(c('--input'), type = 'character', default = NULL,
              help = 'Matrix CSV/TSV/TXT. First column is row id by default; remaining columns are sample/column values.'),
  make_option(c('--params'), type = 'character', default = NULL,
              help = 'Path to params.json.'),
  make_option(c('--output'), type = 'character', default = NULL,
              help = 'Output directory.')
)

opt <- parse_args(OptionParser(option_list = option_list))
input_file <- opt$input
params_file <- opt$params
output_dir <- opt$output

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

# ------------------------------------------------------------
# Standard helpers (copied from den_plot/plot.R)
# ------------------------------------------------------------

write_log <- function(message) {
  log_file <- file.path(output_dir, 'run.log')
  timestamp <- format(Sys.time(), '%Y-%m-%d %H:%M:%S')
  cat(sprintf('[%s] %s\n', timestamp, message), file = log_file, append = TRUE)
}

write_error_and_exit <- function(error, detail = NULL, suggestion = NULL, status = 1) {
  if (is.null(output_dir)) output_dir <<- getwd()
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  error_obj <- list(error = error, detail = detail %||% '', suggestion = suggestion %||% '')
  writeLines(jsonlite::toJSON(error_obj, auto_unbox = TRUE, pretty = TRUE), file.path(output_dir, 'error.json'))
  message(error)
  quit(status = status)
}

read_table_auto <- function(path) {
  if (is.null(path) || !file.exists(path)) {
    write_error_and_exit('Input file not found', paste('Input path:', path), 'Please provide a valid csv, tsv, or txt file.')
  }
  ext <- tolower(tools::file_ext(path))
  if (ext == 'csv') return(read.csv(path, check.names = FALSE, stringsAsFactors = FALSE))
  if (ext %in% c('tsv', 'txt')) return(read.delim(path, check.names = FALSE, stringsAsFactors = FALSE))
  # Fallback: try csv then tsv
  df <- tryCatch(read.csv(path, check.names = FALSE, stringsAsFactors = FALSE), error = function(e) NULL)
  if (is.null(df)) df <- read.delim(path, check.names = FALSE, stringsAsFactors = FALSE)
  df
}

get_param <- function(params, name, default = NULL) {
  if (!is.null(params[[name]])) return(params[[name]])
  default
}

get_param_any <- function(params, names, default = NULL) {
  for (name in names) {
    if (!is.null(params[[name]])) return(params[[name]])
  }
  default
}

as_bool <- function(x, default = FALSE) {
  if (is.null(x)) return(default)
  if (is.logical(x)) return(isTRUE(x[1]))
  value <- tolower(trimws(as.character(x[1])))
  if (value %in% c('true', 't', 'yes', 'y', '1', 'on')) return(TRUE)
  if (value %in% c('false', 'f', 'no', 'n', '0', 'off')) return(FALSE)
  default
}

num_param <- function(params, name, default) {
  value <- suppressWarnings(as.numeric(get_param(params, name, default))[1])
  if (is.na(value)) default else value
}

as_string_vector <- function(x, default = character()) {
  if (is.null(x)) return(default)
  if (is.list(x) && !is.data.frame(x)) x <- unlist(x, use.names = FALSE)
  if (length(x) == 1 && is.character(x) && grepl(',', x, fixed = TRUE)) x <- strsplit(x, ',', fixed = TRUE)[[1]]
  x <- trimws(as.character(x))
  x[nzchar(x)]
}

as_named_vector <- function(x, default = NULL) {
  if (is.null(x)) return(default)
  values <- unlist(x, use.names = TRUE)
  if (length(values) == 0) return(default)
  out <- as.character(values)
  names(out) <- names(values)
  out
}

as_numeric_vector <- function(x, default = numeric()) {
  if (is.null(x)) return(default)
  if (is.list(x) && !is.data.frame(x)) x <- unlist(x, use.names = FALSE)
  if (length(x) == 1 && is.character(x) && grepl(',', x, fixed = TRUE)) x <- strsplit(x, ',', fixed = TRUE)[[1]]
  vals <- suppressWarnings(as.numeric(trimws(as.character(x))))
  vals[is.finite(vals)]
}

save_plot <- function(plot, output_dir, width, height, dpi) {
  draw_plot_object <- function(x) {
    if (inherits(x, c('grob', 'gTree', 'gtable'))) {
      grid::grid.newpage()
      grid::grid.draw(x)
    } else {
      print(x)
    }
  }
  draw_with_retry <- function(open_device, close_device = grDevices::dev.off) {
    scale <- 1
    last_error <- NULL
    for (attempt in seq_len(3)) {
      open_device(width * scale, height * scale)
      ok <- tryCatch({
        draw_plot_object(plot)
        TRUE
      }, error = function(e) {
        last_error <<- e
        FALSE
      })
      close_device()
      if (isTRUE(ok)) return(invisible(TRUE))
      scale <- scale * 1.35
    }
    stop(last_error)
  }
  draw_with_retry(function(w, h) svglite::svglite(file.path(output_dir, 'result.svg'), width = w, height = h))
  draw_with_retry(function(w, h) grDevices::cairo_pdf(file.path(output_dir, 'result.pdf'), width = w, height = h, onefile = TRUE))
  draw_with_retry(function(w, h) png(file.path(output_dir, 'result.png'), width = w, height = h, units = 'in', res = dpi, type = 'cairo'))
}

# ------------------------------------------------------------
# Balloon plot helpers
# ------------------------------------------------------------

get_stat_function <- function(name) {
  name <- tolower(as.character(name)[1])
  switch(name,
    sum = function(x) sum(x, na.rm = TRUE),
    mean = function(x) mean(x, na.rm = TRUE),
    median = function(x) median(x, na.rm = TRUE),
    max = function(x) max(x, na.rm = TRUE),
    min = function(x) min(x, na.rm = TRUE),
    sd = function(x) stats::sd(x, na.rm = TRUE),
    var = function(x) stats::var(x, na.rm = TRUE),
    function(x) sum(x, na.rm = TRUE)
  )
}

stat_label <- function(name) {
  name <- tolower(as.character(name)[1])
  label <- switch(name,
    sum = 'Sum', mean = 'Mean', median = 'Median',
    max = 'Max', min = 'Min', sd = 'SD', var = 'Var',
    'Stat')
  label
}

format_value <- function(x, digits = 2) {
  ifelse(is.na(x), '',
    ifelse(abs(x) >= 100, formatC(signif(x, 3), format = 'fg'),
      formatC(round(x, digits), format = 'f', digits = digits, flag = '#')))
}

table_to_matrix <- function(df, params) {
  row_id_col <- get_param_any(params, c('row_id_column', 'feature_column', 'id_column'), colnames(df)[1])
  if (!row_id_col %in% colnames(df)) {
    write_error_and_exit('Row id column not found', paste('Missing:', row_id_col), 'Set row_id_column to a valid matrix row-id column.')
  }
  col_include <- as_string_vector(get_param_any(params, c('columns_include', 'samples_include', 'sample_columns'), NULL))
  col_exclude <- as_string_vector(get_param_any(params, c('columns_exclude', 'samples_exclude'), NULL))
  candidates <- setdiff(colnames(df), row_id_col)
  if (length(col_include) > 0) candidates <- intersect(col_include, candidates)
  if (length(col_exclude) > 0) candidates <- setdiff(candidates, col_exclude)
  if (length(candidates) < 1) {
    write_error_and_exit('Not enough columns', paste('Detected columns:', paste(candidates, collapse = ', ')), 'Select at least one numeric column.')
  }
  mat_df <- df[, candidates, drop = FALSE]
  mat <- suppressWarnings(as.matrix(data.frame(lapply(mat_df, function(x) as.numeric(x)), check.names = FALSE)))
  rownames(mat) <- make.unique(as.character(df[[row_id_col]]))
  colnames(mat) <- candidates
  # Drop rows that are entirely NA/Inf
  keep <- rowSums(is.finite(mat)) > 0
  if (!all(keep)) {
    write_log(paste('Dropping rows with no finite values:', sum(!keep)))
    mat <- mat[keep, , drop = FALSE]
  }
  rows_include <- as_string_vector(get_param_any(params, c('rows_include', 'features_include'), NULL))
  rows_exclude <- as_string_vector(get_param_any(params, c('rows_exclude', 'features_exclude'), NULL))
  if (length(rows_include) > 0) mat <- mat[intersect(rows_include, rownames(mat)), , drop = FALSE]
  if (length(rows_exclude) > 0) mat <- mat[setdiff(rownames(mat), rows_exclude), , drop = FALSE]
  if (nrow(mat) < 1) write_error_and_exit('No matrix rows left after filtering', '', 'Relax rows_include/rows_exclude or check row IDs.')
  mat
}

build_balloon_plot <- function(mat, params) {
  # ---- params ----
  show_value <- as_bool(get_param(params, 'show_value', TRUE), TRUE)
  show_row_stats <- as_bool(get_param(params, 'show_row_stats', TRUE), TRUE)
  show_col_stats <- as_bool(get_param(params, 'show_col_stats', TRUE), TRUE)
  stat_function_name <- get_param_any(params, c('stat_function', 'stat_fn', 'summary_function'), 'sum')
  stat_fn <- get_stat_function(stat_function_name)
  use_gradient <- as_bool(get_param(params, 'use_gradient', FALSE), FALSE)

  # labels
  title <- get_param(params, 'title', 'Balloon Plot')
  subtitle <- get_param(params, 'subtitle', '')
  xlab <- get_param(params, 'xlab', 'Columns')
  ylab <- get_param(params, 'ylab', 'Rows')
  title_show <- as_bool(get_param(params, 'title_show', TRUE), TRUE)
  subtitle_show <- as_bool(get_param(params, 'subtitle_show', nchar(subtitle) > 0), nchar(subtitle) > 0)
  xlab_show <- as_bool(get_param(params, 'xlab_show', TRUE), TRUE)
  ylab_show <- as_bool(get_param(params, 'ylab_show', TRUE), TRUE)

  # typography
  font_family <- get_param(params, 'font_family', 'sans')
  font_size <- num_param(params, 'font_size', 11)
  title_size <- num_param(params, 'title_size', 14)
  axis_label_size <- num_param(params, 'axis_label_size', 11)
  x_axis_text_size <- num_param(params, 'x_axis_text_size', 9)
  y_axis_text_size <- num_param(params, 'y_axis_text_size', 9)
  x_axis_text_angle <- num_param(params, 'x_axis_text_angle', 45)
  value_text_size <- num_param(params, 'value_text_size', 3.2)
  stat_text_size <- num_param(params, 'stat_text_size', 3.4)
  stat_text_color <- get_param(params, 'stat_text_color', get_param(params, 'stat_color', '#C1272D'))

  # colors
  fill_color <- get_param(params, 'fill_color', '#F2F4F7')
  border_color <- get_param(params, 'border_color', '#B0B7C3')
  balloon_color <- get_param(params, 'balloon_color', '#3B7BBF')
  text_color <- get_param(params, 'text_color', '#222222')
  stat_color <- get_param(params, 'stat_color', '#C1272D')
  gradient_low <- get_param(params, 'gradient_low', '#F7FBFF')
  gradient_high <- get_param(params, 'gradient_high', '#1F4E96')
  palette <- get_param(params, 'palette', NULL)

  # layers
  balloon_alpha <- num_param(params, 'balloon_alpha', 0.75)
  balloon_min_size <- num_param(params, 'balloon_min_size', 2)
  balloon_max_size <- num_param(params, 'balloon_max_size', 10)
  tile_border_show <- as_bool(get_param(params, 'tile_border_show', TRUE), TRUE)
  tile_border_color <- get_param(params, 'tile_border_color', border_color)
  tile_border_width <- num_param(params, 'tile_border_width', 0.4)

  # legends
  legend_show <- as_bool(get_param(params, 'legend_show', TRUE), TRUE)
  legend_position <- get_param(params, 'legend_position', 'right')
  legend_name <- get_param(params, 'legend_name', 'Value')
  legend_title_size <- num_param(params, 'legend_title_size', 10)
  legend_text_size <- num_param(params, 'legend_text_size', 9)
  legend_key_size <- num_param(params, 'legend_key_size', 1.2)
  colorbar_width <- num_param(params, 'colorbar_width', 1.2)
  colorbar_height <- num_param(params, 'colorbar_height', 6)

  # selectors
  highlight_rows <- as_string_vector(get_param_any(params, c('highlight_rows', 'highlight_features'), NULL))
  highlight_columns <- as_string_vector(get_param_any(params, c('highlight_columns', 'highlight_samples'), NULL))
  highlight_color <- get_param(params, 'highlight_color', '#E64B35')

  # ---- melt matrix ----
  data_melt <- reshape2::melt(as.matrix(mat))
  colnames(data_melt) <- c('Row', 'Column', 'Value')
  data_melt$Row <- factor(data_melt$Row, levels = rownames(mat))
  data_melt$Column <- factor(data_melt$Column, levels = colnames(mat))

  # ---- stat sentinels ----
  row_stat_label <- paste0(stat_label(stat_function_name), ' (row)')
  col_stat_label <- paste0(stat_label(stat_function_name), ' (col)')

  # Build ordered factor levels for axes
  x_levels <- c(colnames(mat), if (show_row_stats) row_stat_label else character())
  y_levels <- c(rownames(mat), if (show_col_stats) col_stat_label else character())

  data_melt$Column <- factor(data_melt$Column, levels = x_levels)
  data_melt$Row <- factor(data_melt$Row, levels = y_levels)

  # ---- row stats (placed at extra x level) ----
  row_stat_df <- NULL
  if (show_row_stats) {
    row_vals <- apply(mat, 1, stat_fn)
    row_stat_df <- data.frame(
      Row = factor(rownames(mat), levels = y_levels),
      Column = factor(row_stat_label, levels = x_levels),
      Value = row_vals,
      stringsAsFactors = FALSE
    )
  }

  # ---- col stats (placed at extra y level) ----
  col_stat_df <- NULL
  if (show_col_stats) {
    col_vals <- apply(mat, 2, stat_fn)
    col_stat_df <- data.frame(
      Row = factor(col_stat_label, levels = y_levels),
      Column = factor(colnames(mat), levels = x_levels),
      Value = col_vals,
      stringsAsFactors = FALSE
    )
  }

  # ---- highlight df ----
  highlight_mask <- rep(FALSE, nrow(data_melt))
  if (length(highlight_rows) > 0) highlight_mask <- highlight_mask | (as.character(data_melt$Row) %in% highlight_rows)
  if (length(highlight_columns) > 0) highlight_mask <- highlight_mask | (as.character(data_melt$Column) %in% highlight_columns)
  highlight_df <- data_melt[highlight_mask, , drop = FALSE]

  # ---- base plot ----
  p <- ggplot()

  # Tile layer
  if (use_gradient) {
    p <- p + geom_tile(data = data_melt, aes(x = Column, y = Row, fill = Value),
                       color = if (tile_border_show) tile_border_color else NA,
                       linewidth = if (tile_border_show) tile_border_width else 0)
  } else {
    p <- p + geom_tile(data = data_melt, aes(x = Column, y = Row),
                       fill = fill_color,
                       color = if (tile_border_show) tile_border_color else NA,
                       linewidth = if (tile_border_show) tile_border_width else 0)
  }

  # Balloon points
  p <- p + geom_point(data = data_melt, aes(x = Column, y = Row, size = Value),
                      color = balloon_color, alpha = balloon_alpha)

  # Highlight ring (on top of balloon)
  if (nrow(highlight_df) > 0) {
    p <- p + geom_point(data = highlight_df, aes(x = Column, y = Row, size = Value),
                        shape = 21, fill = NA, color = highlight_color,
                        stroke = 1.1, alpha = balloon_alpha)
  }

  # Value text
  if (show_value) {
    p <- p + geom_text(data = data_melt, aes(x = Column, y = Row, label = format_value(Value)),
                       size = value_text_size, color = text_color)
  }

  # Row stat text
  if (show_row_stats) {
    p <- p + geom_text(data = row_stat_df, aes(x = Column, y = Row, label = format_value(Value)),
                       size = stat_text_size, color = stat_text_color, fontface = 'bold')
  }

  # Col stat text
  if (show_col_stats) {
    p <- p + geom_text(data = col_stat_df, aes(x = Column, y = Row, label = format_value(Value)),
                       size = stat_text_size, color = stat_text_color, fontface = 'bold')
  }

  # Scales
  p <- p + scale_size_continuous(name = legend_name, range = c(balloon_min_size, balloon_max_size))

  if (use_gradient) {
    if (!is.null(palette) && nchar(palette) > 0) {
      p <- p + scale_fill_distiller(name = legend_name, palette = palette,
                                    guide = guide_colorbar(title.position = 'top', title.hjust = 0.5,
                                                           barwidth = grid::unit(colorbar_width, 'cm'),
                                                           barheight = grid::unit(colorbar_height, 'cm')))
    } else {
      p <- p + scale_fill_gradient(name = legend_name, low = gradient_low, high = gradient_high,
                                   guide = guide_colorbar(title.position = 'top', title.hjust = 0.5,
                                                          barwidth = grid::unit(colorbar_width, 'cm'),
                                                          barheight = grid::unit(colorbar_height, 'cm')))
    }
  }

  # Labs
  labs_obj <- list(size = legend_name)
  if (use_gradient) labs_obj$fill <- legend_name
  if (title_show) labs_obj$title <- title
  if (subtitle_show) labs_obj$subtitle <- subtitle
  if (xlab_show) labs_obj$x <- xlab
  if (ylab_show) labs_obj$y <- ylab
  p <- p + do.call(labs, labs_obj)

  # Theme
  legend_pos <- if (!legend_show) 'none' else legend_position
  p <- p + theme_minimal(base_family = font_family, base_size = font_size) +
    theme(
      plot.title = element_text(size = title_size, face = 'bold', hjust = 0.5),
      plot.subtitle = element_text(size = title_size - 1, hjust = 0.5, color = '#555555'),
      axis.title.x = element_text(size = axis_label_size, color = text_color),
      axis.title.y = element_text(size = axis_label_size, color = text_color),
      axis.text.x = element_text(size = x_axis_text_size, angle = x_axis_text_angle,
                                 hjust = if (x_axis_text_angle > 0) 1 else 0.5,
                                 vjust = if (x_axis_text_angle > 0) 1 else 0.5,
                                 color = text_color),
      axis.text.y = element_text(size = y_axis_text_size, color = text_color),
      panel.grid = element_blank(),
      panel.border = element_rect(color = border_color, fill = NA, linewidth = 0.5),
      legend.position = legend_pos,
      legend.title = element_text(size = legend_title_size),
      legend.text = element_text(size = legend_text_size),
      legend.key.size = grid::unit(legend_key_size, 'cm'),
      plot.background = element_rect(fill = 'white', color = NA),
      panel.background = element_rect(fill = 'white', color = NA)
    )

  p
}

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------

main <- function() {
  if (is.null(input_file)) write_error_and_exit('Missing --input argument')
  if (is.null(params_file) || !file.exists(params_file)) write_error_and_exit('Params file not found', paste('Params path:', params_file), 'Provide params.json.')
  if (is.null(output_dir)) write_error_and_exit('Missing --output argument')
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  # Clean stale outputs
  stale <- file.path(output_dir, c('error.json', 'result.svg', 'result.pdf', 'result.png', 'figure.json', 'selected_rows.csv', 'run.log'))
  stale <- stale[file.exists(stale)]
  if (length(stale) > 0) unlink(stale)

  write_log('Starting balloon_plot plugin.')

  params <- jsonlite::fromJSON(params_file, simplifyVector = FALSE)
  df <- read_table_auto(input_file)
  mat <- table_to_matrix(df, params)

  write_log(sprintf('Matrix loaded: %d rows x %d columns.', nrow(mat), ncol(mat)))

  p <- build_balloon_plot(mat, params)

  width <- num_param(params, 'width', 8)
  height <- num_param(params, 'height', 6)
  dpi <- num_param(params, 'dpi', 300)
  save_plot(p, output_dir, width, height, dpi)
  write_log('Saved result.svg, result.pdf, result.png.')

  # selected_rows.csv when filtering or highlight applied
  rows_include <- as_string_vector(get_param_any(params, c('rows_include', 'features_include'), NULL))
  rows_exclude <- as_string_vector(get_param_any(params, c('rows_exclude', 'features_exclude'), NULL))
  highlight_rows <- as_string_vector(get_param_any(params, c('highlight_rows', 'highlight_features'), NULL))
  if (length(rows_include) > 0 || length(rows_exclude) > 0 || length(highlight_rows) > 0) {
    out_df <- data.frame(row_id = rownames(mat), as.data.frame(mat), check.names = FALSE)
    utils::write.csv(out_df, file.path(output_dir, 'selected_rows.csv'), row.names = FALSE)
    write_log('Wrote selected_rows.csv.')
  }

  figure <- list(
    plugin = 'balloon_plot',
    plot_type = 'balloon_plot',
    source_engine = 'SCA statBalloonplot.R (rewritten)',
    input_file = normalizePath(input_file, mustWork = FALSE),
    n_rows = nrow(mat),
    n_cols = ncol(mat),
    rows = rownames(mat),
    columns = colnames(mat),
    style = list(
      title = get_param(params, 'title', 'Balloon Plot'),
      show_value = as_bool(get_param(params, 'show_value', TRUE), TRUE),
      show_row_stats = as_bool(get_param(params, 'show_row_stats', TRUE), TRUE),
      show_col_stats = as_bool(get_param(params, 'show_col_stats', TRUE), TRUE),
      stat_function = get_param_any(params, c('stat_function', 'stat_fn', 'summary_function'), 'sum'),
      use_gradient = as_bool(get_param(params, 'use_gradient', FALSE), FALSE),
      balloon_color = get_param(params, 'balloon_color', '#3B7BBF'),
      fill_color = get_param(params, 'fill_color', '#F2F4F7'),
      legend_position = get_param(params, 'legend_position', 'right'),
      width = width,
      height = height,
      dpi = dpi
    ),
    outputs = list(svg = 'result.svg', pdf = 'result.pdf', png = 'result.png',
                   figure = 'figure.json', log = 'run.log',
                   selected_rows = if (file.exists(file.path(output_dir, 'selected_rows.csv'))) 'selected_rows.csv' else NULL)
  )
  writeLines(jsonlite::toJSON(figure, auto_unbox = TRUE, pretty = TRUE), file.path(output_dir, 'figure.json'))
  write_log('Completed balloon_plot plugin.')
}

tryCatch(main(), error = function(e) {
  write_error_and_exit('Balloon plot failed', conditionMessage(e), 'Check matrix format, row_id_column, and params.json values.')
})