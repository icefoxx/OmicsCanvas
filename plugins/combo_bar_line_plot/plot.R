#!/usr/bin/env Rscript

# BioFigureAI Plot Plugin: Combo Bar + Line (dual-axis)
# ------------------------------------------------------------
# Highly customizable combination chart: categorical bars on the
# primary Y axis with an optional connected line (and points) on a
# secondary Y axis — ChiPlot / publication style.
#
# Runtime:
#   Rscript plot.R --input input.csv --params params.json --output output_dir
#
# Input (wide, recommended):
#   sample | bar_value | line_value | [group] | [color_column]
# Input (long):
#   sample | metric | value   with bar_metric / line_metric params

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
  library(scales)
})

option_list <- list(
  make_option(c('--input'), type = 'character', default = NULL,
              help = 'CSV/TSV/TXT with sample, bar value, and optional line value.'),
  make_option(c('--params'), type = 'character', default = NULL,
              help = 'Path to params.json.'),
  make_option(c('--output'), type = 'character', default = NULL,
              help = 'Output directory.')
)

opt <- parse_args(OptionParser(option_list = option_list))
input_file <- opt$input
params_file <- opt$params
output_dir <- opt$output

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x

write_log <- function(message) {
  log_file <- file.path(output_dir, 'run.log')
  timestamp <- format(Sys.time(), '%Y-%m-%d %H:%M:%S')
  cat(sprintf('[%s] %s\n', timestamp, message), file = log_file, append = TRUE)
}

write_error_and_exit <- function(error, detail = NULL, suggestion = NULL, status = 1) {
  if (is.null(output_dir) || !nzchar(output_dir)) output_dir <<- getwd()
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  error_obj <- list(error = error, detail = detail %||% '', suggestion = suggestion %||% '')
  writeLines(jsonlite::toJSON(error_obj, auto_unbox = TRUE, pretty = TRUE),
             file.path(output_dir, 'error.json'))
  message(error)
  quit(status = status)
}

read_table_auto <- function(path) {
  if (is.null(path) || !file.exists(path)) {
    write_error_and_exit('Input file not found', paste('Input path:', path),
                         'Provide a valid csv, tsv, or txt file.')
  }
  ext <- tolower(tools::file_ext(path))
  if (ext == 'csv') return(read.csv(path, check.names = FALSE, stringsAsFactors = FALSE))
  if (ext %in% c('tsv', 'txt')) return(read.delim(path, check.names = FALSE, stringsAsFactors = FALSE))
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
  if (length(x) == 1 && is.character(x) && grepl(',', x, fixed = TRUE)) {
    x <- strsplit(x, ',', fixed = TRUE)[[1]]
  }
  x <- trimws(as.character(x))
  x[nzchar(x)]
}

as_named_character <- function(x, default = character()) {
  if (is.null(x)) return(default)
  vals <- unlist(x, use.names = TRUE)
  if (length(vals) == 0) return(default)
  out <- as.character(vals)
  names(out) <- names(vals)
  out
}

face_from_style <- function(weight = 'normal', style = 'normal') {
  weight <- tolower(as.character(weight %||% 'normal')[1])
  style <- tolower(as.character(style %||% 'normal')[1])
  if (weight %in% c('bold', 'bolder', '700', '800', '900') && style %in% c('italic', 'oblique')) return('bold.italic')
  if (weight %in% c('bold', 'bolder', '700', '800', '900')) return('bold')
  if (style %in% c('italic', 'oblique')) return('italic')
  'plain'
}

default_palette <- function(n) {
  base <- c('#66C2A5', '#FC8D62', '#8DA0CB', '#E78AC3', '#A6D854', '#FFD92F',
            '#E5C494', '#B3B3B3', '#1B9E77', '#D95F02', '#7570B3', '#E7298A',
            '#66A61E', '#E6AB02', '#A6761D', '#666666')
  if (n <= length(base)) return(base[seq_len(n)])
  grDevices::colorRampPalette(base)(n)
}

resolve_colors <- function(n, params, ids) {
  color_map <- as_named_character(get_param_any(params, c(
    'bar_colors', 'sample_colors', 'category_colors', 'color_map'
  ), NULL))
  if (length(color_map) > 0) {
    cols <- rep(NA_character_, n)
    names(cols) <- ids
    hit <- intersect(ids, names(color_map))
    cols[hit] <- color_map[hit]
    missing <- ids[is.na(cols)]
    if (length(missing) > 0) cols[missing] <- default_palette(length(missing))
    return(unname(cols[ids]))
  }
  colors <- as_string_vector(get_param_any(params, c('colors', 'palette_colors'), NULL))
  if (length(colors) > 0) {
    if (length(colors) >= n) return(colors[seq_len(n)])
    return(grDevices::colorRampPalette(colors)(n))
  }
  palette_name <- get_param_any(params, c('palette', 'palette_scheme'), NULL)
  if (!is.null(palette_name) && nzchar(as.character(palette_name)[1])) {
    name <- as.character(palette_name)[1]
    if (requireNamespace('RColorBrewer', quietly = TRUE) && name %in% rownames(RColorBrewer::brewer.pal.info)) {
      k <- min(n, RColorBrewer::brewer.pal.info[name, 'maxcolors'])
      cols <- RColorBrewer::brewer.pal(max(3, k), name)
      if (n <= length(cols)) return(cols[seq_len(n)])
      return(grDevices::colorRampPalette(cols)(n))
    }
  }
  default_palette(n)
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
      ok <- tryCatch({ draw_plot_object(plot); TRUE }, error = function(e) { last_error <<- e; FALSE })
      close_device()
      if (isTRUE(ok)) return(invisible(TRUE))
      scale <- scale * 1.35
    }
    stop(last_error)
  }
  if (requireNamespace('svglite', quietly = TRUE)) {
    draw_with_retry(function(w, h) svglite::svglite(file.path(output_dir, 'result.svg'), width = w, height = h))
  } else {
    draw_with_retry(function(w, h) grDevices::svg(file.path(output_dir, 'result.svg'), width = w, height = h))
  }
  if (capabilities('cairo')) {
    draw_with_retry(function(w, h) grDevices::cairo_pdf(file.path(output_dir, 'result.pdf'), width = w, height = h, onefile = TRUE))
    draw_with_retry(function(w, h) png(file.path(output_dir, 'result.png'), width = w, height = h, units = 'in', res = dpi, type = 'cairo'))
  } else {
    draw_with_retry(function(w, h) grDevices::pdf(file.path(output_dir, 'result.pdf'), width = w, height = h, onefile = TRUE))
    draw_with_retry(function(w, h) png(file.path(output_dir, 'result.png'), width = w, height = h, units = 'in', res = dpi))
  }
}

# ------------------------------------------------------------
# Runtime
# ------------------------------------------------------------
if (is.null(input_file)) write_error_and_exit('Missing --input argument')
if (is.null(params_file) || !file.exists(params_file)) {
  write_error_and_exit('Params file not found', paste('Params path:', params_file),
                       'Backend should generate params.json and pass it through --params.')
}
if (is.null(output_dir)) write_error_and_exit('Missing --output argument')
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
error_path <- file.path(output_dir, 'error.json')
if (file.exists(error_path)) file.remove(error_path)

write_log('Plugin combo_bar_line_plot started.')

params <- tryCatch(
  jsonlite::fromJSON(params_file, simplifyVector = TRUE, simplifyDataFrame = FALSE),
  error = function(e) write_error_and_exit('Failed to parse params.json', conditionMessage(e),
                                           'Please make sure params.json is valid JSON.')
)

df <- read_table_auto(input_file)
write_log(sprintf('Loaded input with %s rows and %s columns.', nrow(df), ncol(df)))

# ------------------------------------------------------------
# Column mapping / long reshape
# ------------------------------------------------------------
input_mode <- tolower(as.character(get_param(params, 'input_mode', 'auto')[1]))
sample_col <- get_param_any(params, c('sample_column', 'id_column', 'x_column', 'row_id_column'), NULL)
bar_col <- get_param_any(params, c('bar_column', 'bar_value_column', 'primary_column', 'y_column', 'value_column'), NULL)
line_col <- get_param_any(params, c('line_column', 'line_value_column', 'secondary_column', 'y2_column'), NULL)
color_col <- get_param_any(params, c('color_column', 'bar_color_column', 'fill_column'), NULL)
group_col <- get_param_any(params, c('group_column', 'group_by'), NULL)

metric_col <- get_param_any(params, c('metric_column', 'series_column', 'variable_column'), NULL)
bar_metric <- as.character(get_param_any(params, c('bar_metric', 'primary_metric'), 'count')[1])
line_metric <- as.character(get_param_any(params, c('line_metric', 'secondary_metric'), 'percent')[1])
value_long_col <- get_param_any(params, c('long_value_column', 'value_column_long'), 'value')

if (identical(input_mode, 'auto')) {
  if (!is.null(metric_col) && metric_col %in% colnames(df)) {
    input_mode <- 'long'
  } else {
    input_mode <- 'wide'
  }
}

if (is.null(sample_col) || !sample_col %in% colnames(df)) {
  sample_col <- colnames(df)[1]
}

if (identical(input_mode, 'long')) {
  if (is.null(metric_col) || !metric_col %in% colnames(df)) {
    write_error_and_exit('metric_column not found for long input',
                         paste('Columns:', paste(colnames(df), collapse = ', ')),
                         'Set metric_column / bar_metric / line_metric for long data.')
  }
  if (!value_long_col %in% colnames(df)) {
    # try common names
    for (cand in c('value', 'Value', 'abundance', 'count')) {
      if (cand %in% colnames(df)) { value_long_col <- cand; break }
    }
  }
  if (!value_long_col %in% colnames(df)) {
    write_error_and_exit('value column not found for long input', '', 'Set long_value_column.')
  }
  wide <- reshape(
    df[, c(sample_col, metric_col, value_long_col)],
    idvar = sample_col, timevar = metric_col, direction = 'wide'
  )
  names(wide) <- sub(paste0('^', value_long_col, '\\.'), '', names(wide))
  names(wide)[1] <- sample_col
  df <- wide
  if (is.null(bar_col) || !bar_col %in% colnames(df)) bar_col <- if (bar_metric %in% colnames(df)) bar_metric else setdiff(colnames(df), sample_col)[1]
  if (is.null(line_col) || !line_col %in% colnames(df)) {
    line_col <- if (line_metric %in% colnames(df)) line_metric else {
      rest <- setdiff(colnames(df), c(sample_col, bar_col))
      if (length(rest) > 0) rest[1] else NULL
    }
  }
} else {
  if (is.null(bar_col) || !bar_col %in% colnames(df)) {
    # first numeric after sample
    nums <- colnames(df)[vapply(df, function(x) is.numeric(x) || all(grepl('^[-+]?[0-9.]+$', as.character(x)[!is.na(x) & nzchar(as.character(x))])), logical(1))]
    nums <- setdiff(nums, sample_col)
    if (length(nums) < 1) {
      write_error_and_exit('bar_column not found', paste('Columns:', paste(colnames(df), collapse = ', ')),
                           'Set bar_column to a numeric column.')
    }
    bar_col <- nums[1]
    if (is.null(line_col) && length(nums) >= 2) line_col <- nums[2]
  }
  if (!is.null(line_col) && !line_col %in% colnames(df)) line_col <- NULL
}

plot_df <- data.frame(
  sample = as.character(df[[sample_col]]),
  bar = suppressWarnings(as.numeric(df[[bar_col]])),
  stringsAsFactors = FALSE
)
if (!is.null(line_col) && line_col %in% colnames(df)) {
  plot_df$line <- suppressWarnings(as.numeric(df[[line_col]]))
} else {
  plot_df$line <- NA_real_
}
if (!is.null(group_col) && group_col %in% colnames(df)) {
  plot_df$group <- as.character(df[[group_col]])
} else {
  plot_df$group <- plot_df$sample
}
if (!is.null(color_col) && color_col %in% colnames(df)) {
  plot_df$color_key <- as.character(df[[color_col]])
} else {
  plot_df$color_key <- plot_df$sample
}

# Filters
samples_include <- as_string_vector(get_param_any(params, c('samples_include', 'rows_include'), NULL))
samples_exclude <- as_string_vector(get_param_any(params, c('samples_exclude', 'rows_exclude'), NULL))
if (length(samples_include) > 0) plot_df <- plot_df[plot_df$sample %in% samples_include, , drop = FALSE]
if (length(samples_exclude) > 0) plot_df <- plot_df[!plot_df$sample %in% samples_exclude, , drop = FALSE]
if (nrow(plot_df) < 1) write_error_and_exit('No rows left after filtering', '', 'Relax include/exclude filters.')

sample_order <- as_string_vector(get_param_any(params, c('sample_order', 'x_order'), NULL))
if (length(sample_order) > 0) {
  plot_df$sample <- factor(plot_df$sample, levels = unique(c(sample_order, unique(plot_df$sample))))
} else {
  plot_df$sample <- factor(plot_df$sample, levels = unique(plot_df$sample))
}

show_line <- as_bool(get_param_any(params, c('show_line', 'line_show', 'line_switch'), TRUE), TRUE)
show_line_points <- as_bool(get_param_any(params, c('show_line_points', 'line_points_show', 'point_show'), TRUE), TRUE)
show_bar <- as_bool(get_param_any(params, c('show_bar', 'bar_show', 'bar_switch'), TRUE), TRUE)
use_dual_axis <- as_bool(get_param_any(params, c('dual_axis', 'use_secondary_axis', 'secondary_axis'), TRUE), TRUE)
if (!any(is.finite(plot_df$line))) {
  show_line <- FALSE
  use_dual_axis <- FALSE
}

# Dual-axis scale transform: map line values into bar scale for plotting, label with sec_axis
bar_vals <- plot_df$bar[is.finite(plot_df$bar)]
line_vals <- plot_df$line[is.finite(plot_df$line)]
y1_min <- suppressWarnings(as.numeric(get_param_any(params, c('y_min', 'y1_min', 'bar_min'), NA))[1])
y1_max <- suppressWarnings(as.numeric(get_param_any(params, c('y_max', 'y1_max', 'bar_max'), NA))[1])
y2_min <- suppressWarnings(as.numeric(get_param_any(params, c('y2_min', 'line_min', 'secondary_min'), NA))[1])
y2_max <- suppressWarnings(as.numeric(get_param_any(params, c('y2_max', 'line_max', 'secondary_max'), NA))[1])

if (!is.finite(y1_min)) y1_min <- 0
if (!is.finite(y1_max)) {
  y1_max <- if (length(bar_vals)) max(bar_vals, na.rm = TRUE) * 1.05 else 1
  if (!is.finite(y1_max) || y1_max <= y1_min) y1_max <- y1_min + 1
}
if (!is.finite(y2_min)) y2_min <- 0
if (!is.finite(y2_max)) {
  y2_max <- if (length(line_vals)) max(line_vals, na.rm = TRUE) * 1.05 else 1
  if (!is.finite(y2_max) || y2_max <= y2_min) y2_max <- y2_min + 1
}

# scale line -> primary axis range for geom overlay
scale_line_to_bar <- function(v) {
  (v - y2_min) / (y2_max - y2_min) * (y1_max - y1_min) + y1_min
}
scale_bar_to_line <- function(v) {
  (v - y1_min) / (y1_max - y1_min) * (y2_max - y2_min) + y2_min
}
plot_df$line_scaled <- scale_line_to_bar(plot_df$line)

# ------------------------------------------------------------
# Style params
# ------------------------------------------------------------
width <- num_param(params, 'width', 8)
height <- num_param(params, 'height', 5.5)
dpi <- as.integer(num_param(params, 'dpi', 300))
font_family <- get_param_any(params, c('font_family', 'base_font_family'), 'sans')
margin_top <- num_param(params, 'margin_top', 8)
margin_right <- num_param(params, 'margin_right', 12)
margin_bottom <- num_param(params, 'margin_bottom', 10)
margin_left <- num_param(params, 'margin_left', 8)

# Bar style
bar_width <- num_param(params, 'bar_width', num_param(params, 'outerPadding', 0.65))
if (bar_width > 1) bar_width <- 0.65
# accept outerPadding 0-1 as gap → width = 1 - outer
if (!is.null(params$outerPadding) || !is.null(params$outer_padding)) {
  op <- num_param(params, 'outerPadding', num_param(params, 'outer_padding', 0.35))
  if (op >= 0 && op < 1) bar_width <- max(0.05, 1 - op)
}
bar_alpha <- num_param(params, 'bar_fill_opacity', num_param(params, 'bar_alpha', num_param(params, 'fill_opacity', 0.95)))
bar_stroke <- get_param_any(params, c('bar_stroke', 'bar_border_color'), '#000000')
bar_stroke_width <- num_param(params, 'bar_stroke_width', num_param(params, 'stroke_width', 0))
bar_stroke_opacity <- num_param(params, 'bar_stroke_opacity', 1)
bar_color_mode <- tolower(as.character(get_param_any(params, c('bar_color_mode', 'color_mode'), 'by_sample')[1]))
# by_sample | single | by_group | by_column
single_bar_color <- get_param_any(params, c('bar_fill', 'bar_color', 'fill'), '#66C2A5')

ids_for_color <- unique(as.character(plot_df$color_key))
if (bar_color_mode %in% c('single', 'fixed')) {
  fill_cols <- setNames(rep(single_bar_color, length(ids_for_color)), ids_for_color)
  plot_df$fill_id <- plot_df$color_key
} else if (bar_color_mode %in% c('by_group', 'group') && !is.null(group_col)) {
  ids_for_color <- unique(as.character(plot_df$group))
  fill_vals <- resolve_colors(length(ids_for_color), params, ids_for_color)
  names(fill_vals) <- ids_for_color
  fill_cols <- fill_vals
  plot_df$fill_id <- plot_df$group
} else {
  ids_for_color <- levels(plot_df$sample)
  fill_vals <- resolve_colors(length(ids_for_color), params, ids_for_color)
  names(fill_vals) <- ids_for_color
  fill_cols <- fill_vals
  plot_df$fill_id <- as.character(plot_df$sample)
}
plot_df$fill_id <- factor(plot_df$fill_id, levels = names(fill_cols))

# Line style
line_color <- get_param_any(params, c('line_color', 'line_stroke', 'secondary_color'), '#2A9D8F')
line_width <- num_param(params, 'line_width', num_param(params, 'line_stroke_width', 1.2))
line_alpha <- num_param(params, 'line_opacity', num_param(params, 'line_alpha', 1))
line_type <- get_param_any(params, c('line_type', 'line_linetype'), 'solid')
# map common names
line_type <- switch(tolower(as.character(line_type)[1]),
  solid = 'solid', dashed = 'dashed', dotted = 'dotted',
  dotdash = 'dotdash', longdash = 'longdash', twodash = 'twodash',
  '1' = 'solid', '2' = 'dashed', '3' = 'dotted', as.character(line_type)[1]
)
point_size <- num_param(params, 'line_point_size', num_param(params, 'point_size', 2.2))
point_shape <- as.integer(num_param(params, 'line_point_shape', num_param(params, 'point_shape', 16)))
point_fill <- get_param_any(params, c('line_point_fill', 'point_fill'), line_color)
point_stroke <- num_param(params, 'line_point_stroke', 0.4)
point_color <- get_param_any(params, c('line_point_color', 'point_color'), line_color)
point_alpha <- num_param(params, 'line_point_opacity', num_param(params, 'point_alpha', 1))

# Bar text
bar_text_show <- as_bool(get_param_any(params, c('bar_text_show', 'show_bar_text', 'show_value'), FALSE), FALSE)
bar_text_size_raw <- num_param(params, 'bar_text_size', 10)
bar_text_size <- if (bar_text_size_raw > 8) bar_text_size_raw / ggplot2::.pt else bar_text_size_raw
bar_text_fill <- get_param_any(params, c('bar_text_fill', 'bar_text_color'), '#222222')
bar_text_weight <- get_param_any(params, c('bar_text_font_weight'), 'normal')
bar_text_style <- get_param_any(params, c('bar_text_font_style'), 'normal')
bar_text_digits <- as.integer(num_param(params, 'bar_text_digits', 1))
bar_text_vjust <- num_param(params, 'bar_text_vjust', -0.4)
bar_text_suffix <- as.character(get_param(params, 'bar_text_suffix', '')[1] %||% '')

# Line point text
line_text_show <- as_bool(get_param_any(params, c('line_text_show', 'show_line_text'), FALSE), FALSE)
line_text_size_raw <- num_param(params, 'line_text_size', 9)
line_text_size <- if (line_text_size_raw > 8) line_text_size_raw / ggplot2::.pt else line_text_size_raw
line_text_fill <- get_param_any(params, c('line_text_fill', 'line_text_color'), line_color)
line_text_digits <- as.integer(num_param(params, 'line_text_digits', 0))
line_text_vjust <- num_param(params, 'line_text_vjust', -1.1)

# Title
title_show <- as_bool(get_param_any(params, c('title_show', 'title_switch'), FALSE), FALSE)
title_text <- as.character(get_param_any(params, c('title', 'title_text'), '')[1] %||% '')
title_size <- num_param(params, 'title_size', 14)
title_fill <- get_param_any(params, c('title_fill', 'title_color'), '#000000')
title_weight <- get_param_any(params, c('title_font_weight', 'title_weight'), 'bold')
title_style <- get_param_any(params, c('title_font_style'), 'normal')
title_hjust <- switch(tolower(as.character(get_param_any(params, c('title_text_anchor'), 'middle')[1])),
                      start = 0, end = 1, middle = 0.5, 0.5)
subtitle_show <- as_bool(get_param(params, 'subtitle_show', FALSE), FALSE)
subtitle_text <- as.character(get_param(params, 'subtitle', '')[1] %||% '')

# Axes labels
xlab <- as.character(get_param_any(params, c('xlab', 'x_title', 'x_label'), '')[1] %||% '')
ylab <- as.character(get_param_any(params, c('ylab', 'y_title', 'y_label', 'y1_title', 'bar_axis_title'), '')[1] %||% '')
y2lab <- as.character(get_param_any(params, c('y2lab', 'y2_title', 'y2_label', 'line_axis_title', 'secondary_axis_title'), '')[1] %||% '')
xlab_show <- as_bool(get_param_any(params, c('xlab_show', 'x_title_show'), nzchar(xlab)), nzchar(xlab))
ylab_show <- as_bool(get_param_any(params, c('ylab_show', 'y_title_show'), nzchar(ylab)), nzchar(ylab))
y2lab_show <- as_bool(get_param_any(params, c('y2lab_show', 'y2_title_show'), nzchar(y2lab)), nzchar(y2lab))

x_text_show <- as_bool(get_param_any(params, c('x_axis_text_show', 'show_x_axis_text'), TRUE), TRUE)
y_text_show <- as_bool(get_param_any(params, c('y_axis_text_show', 'show_y_axis_text'), TRUE), TRUE)
y2_text_show <- as_bool(get_param_any(params, c('y2_axis_text_show', 'show_y2_axis_text'), TRUE), TRUE)

x_rotate <- num_param(params, 'x_axis_text_angle', num_param(params, 'x_rotate', 45))
if (is.null(params$x_axis_text_angle) && is.null(params$x_rotate)) x_rotate <- 45
y_rotate <- num_param(params, 'y_axis_text_angle', 0)
x_text_size <- num_param(params, 'x_axis_text_size', 10)
y_text_size <- num_param(params, 'y_axis_text_size', 10)
y2_text_size <- num_param(params, 'y2_axis_text_size', 10)
x_text_fill <- get_param_any(params, c('x_axis_text_fill', 'x_axis_text_color'), '#000000')
y_text_fill <- get_param_any(params, c('y_axis_text_fill', 'y_axis_text_color'), '#000000')
y2_text_fill <- get_param_any(params, c('y2_axis_text_fill', 'y2_axis_text_color'), line_color)
x_text_weight <- get_param_any(params, c('x_axis_font_weight'), 'normal')
y_text_weight <- get_param_any(params, c('y_axis_font_weight'), 'normal')
x_text_style <- get_param_any(params, c('x_axis_font_style'), 'normal')
y_text_style <- get_param_any(params, c('y_axis_font_style'), 'normal')
x_label_size <- num_param(params, 'x_axis_title_size', 11)
y_label_size <- num_param(params, 'y_axis_title_size', 11)
y2_label_size <- num_param(params, 'y2_axis_title_size', 11)
x_label_fill <- get_param_any(params, c('x_axis_title_color', 'x_label_fill'), '#000000')
y_label_fill <- get_param_any(params, c('y_axis_title_color', 'y_label_fill'), '#000000')
y2_label_fill <- get_param_any(params, c('y2_axis_title_color', 'y2_label_fill'), line_color)

# Ticks
x_tick_stroke <- get_param_any(params, c('x_tick_stroke', 'tick_stroke'), '#000000')
y_tick_stroke <- get_param_any(params, c('y_tick_stroke', 'tick_stroke'), '#000000')
y2_tick_stroke <- get_param_any(params, c('y2_tick_stroke'), line_color)
x_tick_width <- num_param(params, 'x_tick_stroke_width', 1)
y_tick_width <- num_param(params, 'y_tick_stroke_width', 1)
y2_tick_width <- num_param(params, 'y2_tick_stroke_width', 1)
x_tick_length <- num_param(params, 'x_tick_length', 6)
y_tick_length <- num_param(params, 'y_tick_length', 6)
x_tick_orientation <- tolower(as.character(get_param_any(params, c('x_tick_orientation', 'tick_orientation'), 'outside')[1]))
y_tick_orientation <- tolower(as.character(get_param_any(params, c('y_tick_orientation', 'tick_orientation'), 'outside')[1]))
x_remove_path <- as_bool(get_param_any(params, c('x_remove_path', 'removePath'), FALSE), FALSE)
y_remove_path <- as_bool(get_param_any(params, c('y_remove_path', 'removePath'), FALSE), FALSE)
y2_remove_path <- as_bool(get_param_any(params, c('y2_remove_path'), FALSE), FALSE)
x_remove_tick <- as_bool(get_param_any(params, c('x_remove_tick', 'removeTick'), FALSE), FALSE)
y_remove_tick <- as_bool(get_param_any(params, c('y_remove_tick', 'removeTick'), FALSE), FALSE)
y2_remove_tick <- as_bool(get_param_any(params, c('y2_remove_tick'), FALSE), FALSE)
tick_dir_x <- if (x_tick_orientation == 'inside') -1 else 1
tick_dir_y <- if (y_tick_orientation == 'inside') -1 else 1

# Grid
x_grid_show <- as_bool(get_param_any(params, c('x_grid_show'), FALSE), FALSE)
y_grid_show <- as_bool(get_param_any(params, c('y_grid_show', 'grid_show', 'grid_switch', 'show_grid'), FALSE), FALSE)
grid_stroke <- get_param_any(params, c('grid_stroke', 'grid_color'), '#000000')
grid_stroke_width <- num_param(params, 'grid_stroke_width', 0.4)
grid_stroke_opacity <- num_param(params, 'grid_stroke_opacity', 0.1)

# Background / panel
plot_bg_show <- as_bool(get_param_any(params, c('background_show', 'plot_background_show'), FALSE), FALSE)
plot_bg_fill <- get_param_any(params, c('background_fill', 'plot_background'), '#FFFFFF')
plot_bg_opacity <- num_param(params, 'background_fill_opacity', 1)
panel_border <- as_bool(get_param_any(params, c('panel_border', 'panel_border_show'), FALSE), FALSE)
panel_border_color <- get_param_any(params, c('panel_border_color'), '#222222')
panel_border_width <- num_param(params, 'panel_border_width', 0.6)

# Legend
legend_show <- as_bool(get_param_any(params, c('legend_show', 'legend_switch', 'show_legend'), FALSE), FALSE)
legend_title <- as.character(get_param_any(params, c('legend_title', 'legend_name'), '')[1] %||% '')
legend_position <- get_param(params, 'legend_position', 'right')
legend_direction <- get_param(params, 'legend_direction', 'vertical')
legend_title_size <- num_param(params, 'legend_title_size', 12)
legend_text_size <- num_param(params, 'legend_text_size', 10)
legend_key_size <- num_param(params, 'legend_key_size', 0.4)
legend_title_fill <- get_param_any(params, c('legend_title_fill', 'legend_title_color'), '#000000')
legend_text_fill <- get_param_any(params, c('legend_text_fill'), '#000000')
legend_title_weight <- get_param_any(params, c('legend_title_font_weight'), 'bold')
legend_columns <- as.integer(num_param(params, 'legend_columns', num_param(params, 'legend_ncol', 1)))

# Zero line
zero_line_show <- as_bool(get_param_any(params, c('zero_line_show', 'show_zero_line'), FALSE), FALSE)
zero_line_color <- get_param(params, 'zero_line_color', '#888888')
zero_line_type <- get_param(params, 'zero_line_type', 'solid')
zero_line_width <- num_param(params, 'zero_line_width', 0.4)

# Horizontal reference lines on primary axis
h_lines <- get_param_any(params, c('horizontal_lines', 'h_lines', 'y_thresholds'), NULL)
h_line_vals <- if (is.null(h_lines)) numeric() else {
  if (is.list(h_lines)) unlist(h_lines, use.names = FALSE) else h_lines
}
h_line_vals <- suppressWarnings(as.numeric(h_line_vals))
h_line_vals <- h_line_vals[is.finite(h_line_vals)]
h_line_color <- get_param(params, 'horizontal_line_color', '#666666')
h_line_type <- get_param(params, 'horizontal_line_type', 'dashed')
h_line_width <- num_param(params, 'horizontal_line_width', 0.4)

# ------------------------------------------------------------
# Build plot
# ------------------------------------------------------------
p <- ggplot(plot_df, aes(x = .data$sample))

if (show_bar) {
  stroke_col <- if (bar_stroke_width > 0) alpha(bar_stroke, bar_stroke_opacity) else NA
  p <- p + geom_col(
    aes(y = .data$bar, fill = .data$fill_id),
    width = bar_width,
    alpha = bar_alpha,
    colour = stroke_col,
    linewidth = if (bar_stroke_width > 0) bar_stroke_width / 2 else 0,
    show.legend = legend_show
  ) +
    scale_fill_manual(values = fill_cols, name = legend_title, drop = FALSE, guide = if (legend_show) 'legend' else 'none')
}

if (length(h_line_vals) > 0) {
  p <- p + geom_hline(
    yintercept = h_line_vals,
    colour = h_line_color,
    linetype = h_line_type,
    linewidth = h_line_width
  )
}

if (zero_line_show) {
  p <- p + geom_hline(
    yintercept = 0,
    colour = zero_line_color,
    linetype = zero_line_type,
    linewidth = zero_line_width
  )
}

if (show_line) {
  line_df <- plot_df[is.finite(plot_df$line_scaled), , drop = FALSE]
  if (nrow(line_df) > 0) {
    p <- p + geom_line(
      data = line_df,
      aes(x = .data$sample, y = .data$line_scaled, group = 1),
      colour = alpha(line_color, line_alpha),
      linewidth = line_width,
      linetype = line_type,
      inherit.aes = FALSE
    )
    if (show_line_points) {
      p <- p + geom_point(
        data = line_df,
        aes(x = .data$sample, y = .data$line_scaled),
        colour = alpha(point_color, point_alpha),
        fill = point_fill,
        size = point_size,
        shape = point_shape,
        stroke = point_stroke,
        inherit.aes = FALSE
      )
    }
    if (line_text_show) {
      p <- p + geom_text(
        data = line_df,
        aes(
          x = .data$sample,
          y = .data$line_scaled,
          label = paste0(formatC(.data$line, format = 'f', digits = line_text_digits))
        ),
        colour = line_text_fill,
        size = line_text_size,
        vjust = line_text_vjust,
        family = font_family,
        inherit.aes = FALSE
      )
    }
  }
}

if (bar_text_show && show_bar) {
  bar_df <- plot_df[is.finite(plot_df$bar), , drop = FALSE]
  p <- p + geom_text(
    data = bar_df,
    aes(
      x = .data$sample,
      y = .data$bar,
      label = paste0(formatC(.data$bar, format = 'f', digits = bar_text_digits), bar_text_suffix)
    ),
    colour = bar_text_fill,
    size = bar_text_size,
    fontface = face_from_style(bar_text_weight, bar_text_style),
    vjust = bar_text_vjust,
    family = font_family,
    inherit.aes = FALSE
  )
}

# Scales
if (use_dual_axis && show_line) {
  p <- p + scale_y_continuous(
    limits = c(y1_min, y1_max),
    expand = expansion(mult = c(0, 0.02)),
    sec.axis = sec_axis(
      ~ scale_bar_to_line(.),
      name = if (y2lab_show) y2lab else NULL
    )
  )
} else {
  p <- p + scale_y_continuous(
    limits = c(y1_min, y1_max),
    expand = expansion(mult = c(0, 0.02))
  )
}

reverse_x <- as_bool(get_param(params, 'reverse_x', FALSE), FALSE)
x_limits <- if (reverse_x) rev(levels(plot_df$sample)) else levels(plot_df$sample)
p <- p + scale_x_discrete(limits = x_limits)

p <- p + labs(
  title = if (title_show && nzchar(title_text)) title_text else NULL,
  subtitle = if (subtitle_show && nzchar(subtitle_text)) subtitle_text else NULL,
  x = if (xlab_show) xlab else NULL,
  y = if (ylab_show) ylab else NULL
)

bg_fill_final <- if (plot_bg_show) alpha(plot_bg_fill, plot_bg_opacity) else 'white'

p <- p + theme_classic(base_family = font_family) + theme(
  plot.title = if (title_show && nzchar(title_text)) element_text(
    size = title_size, colour = title_fill,
    face = face_from_style(title_weight, title_style), hjust = title_hjust
  ) else element_blank(),
  plot.subtitle = if (subtitle_show && nzchar(subtitle_text)) element_text(size = title_size * 0.85) else element_blank(),
  plot.background = element_rect(fill = bg_fill_final, colour = NA),
  panel.background = element_rect(fill = bg_fill_final, colour = NA),
  panel.border = if (panel_border) element_rect(fill = NA, colour = panel_border_color, linewidth = panel_border_width) else element_blank(),
  axis.title.x = if (xlab_show) element_text(size = x_label_size, colour = x_label_fill) else element_blank(),
  axis.title.y = if (ylab_show) element_text(size = y_label_size, colour = y_label_fill) else element_blank(),
  axis.title.y.right = if (use_dual_axis && show_line && y2lab_show) {
    element_text(size = y2_label_size, colour = y2_label_fill)
  } else {
    element_blank()
  },
  axis.text.x = if (x_text_show && !x_remove_tick) element_text(
    size = x_text_size, colour = x_text_fill,
    face = face_from_style(x_text_weight, x_text_style),
    angle = x_rotate,
    hjust = if (abs(x_rotate) > 5) 1 else 0.5,
    vjust = if (abs(x_rotate) > 5) 1 else 0.5
  ) else element_blank(),
  axis.text.y = if (y_text_show && !y_remove_tick) element_text(
    size = y_text_size, colour = y_text_fill,
    face = face_from_style(y_text_weight, y_text_style),
    angle = y_rotate
  ) else element_blank(),
  axis.text.y.right = if (use_dual_axis && show_line && y2_text_show && !y2_remove_tick) {
    element_text(size = y2_text_size, colour = y2_text_fill)
  } else {
    element_blank()
  },
  axis.ticks.x = if (x_remove_tick) element_blank() else element_line(colour = x_tick_stroke, linewidth = x_tick_width / 2),
  axis.ticks.y = if (y_remove_tick) element_blank() else element_line(colour = y_tick_stroke, linewidth = y_tick_width / 2),
  axis.ticks.y.right = if (!use_dual_axis || !show_line || y2_remove_tick) element_blank() else element_line(colour = y2_tick_stroke, linewidth = y2_tick_width / 2),
  axis.ticks.length.x = grid::unit(tick_dir_x * x_tick_length, 'pt'),
  axis.ticks.length.y = grid::unit(tick_dir_y * y_tick_length, 'pt'),
  axis.line.x = if (x_remove_path) element_blank() else element_line(colour = x_tick_stroke, linewidth = x_tick_width / 2),
  axis.line.y = if (y_remove_path) element_blank() else element_line(colour = y_tick_stroke, linewidth = y_tick_width / 2),
  axis.line.y.right = if (!use_dual_axis || !show_line || y2_remove_path) element_blank() else element_line(colour = y2_tick_stroke, linewidth = y2_tick_width / 2),
  panel.grid.major.x = if (x_grid_show) element_line(colour = alpha(grid_stroke, grid_stroke_opacity), linewidth = grid_stroke_width / 2) else element_blank(),
  panel.grid.major.y = if (y_grid_show) element_line(colour = alpha(grid_stroke, grid_stroke_opacity), linewidth = grid_stroke_width / 2) else element_blank(),
  panel.grid.minor = element_blank(),
  legend.position = if (legend_show) legend_position else 'none',
  legend.direction = legend_direction,
  legend.title = element_text(size = legend_title_size, colour = legend_title_fill, face = face_from_style(legend_title_weight, 'normal')),
  legend.text = element_text(size = legend_text_size, colour = legend_text_fill),
  legend.key.size = grid::unit(legend_key_size, 'cm'),
  plot.margin = margin(margin_top, margin_right, margin_bottom, margin_left)
)

if (legend_show) {
  p <- p + guides(fill = guide_legend(ncol = max(1, legend_columns)))
}

write_log(sprintf(
  'Built combo bar+line: %s samples, dual_axis=%s, show_line=%s.',
  nrow(plot_df), use_dual_axis && show_line, show_line
))

# Exports
selected <- data.frame(
  sample = as.character(plot_df$sample),
  bar_value = plot_df$bar,
  line_value = plot_df$line,
  is_selected = TRUE,
  stringsAsFactors = FALSE
)
utils::write.csv(selected, file.path(output_dir, 'selected_rows.csv'), row.names = FALSE)
utils::write.csv(selected, file.path(output_dir, 'matrix_used.csv'), row.names = FALSE)

tryCatch({
  save_plot(p, output_dir, width, height, dpi)
}, error = function(e) {
  write_error_and_exit('Failed to save plot outputs', conditionMessage(e),
                       'Check graphics devices and plot size.')
})

figure_json <- list(
  figure_type = 'combo_bar_line_plot',
  title = if (title_show) title_text else '',
  theme = 'classic',
  layout = list(width = width, height = height, dual_axis = use_dual_axis && show_line),
  analysis = list(
    n_samples = nrow(plot_df),
    bar_column = bar_col,
    line_column = line_col %||% '',
    y1_range = c(y1_min, y1_max),
    y2_range = c(y2_min, y2_max),
    show_bar = show_bar,
    show_line = show_line
  ),
  style = list(
    bar_width = bar_width,
    bar_color_mode = bar_color_mode,
    line_color = line_color,
    line_width = line_width,
    legend_position = legend_position,
    x_rotate = x_rotate
  ),
  data = list(input_file = basename(input_file), n_rows = nrow(plot_df)),
  layers = list(
    list(id = 'bars', type = 'bar', editable = TRUE),
    list(id = 'line', type = 'line', editable = TRUE),
    list(id = 'points', type = 'point', editable = TRUE),
    list(id = 'y1_axis', type = 'axis', editable = TRUE),
    list(id = 'y2_axis', type = 'axis', editable = TRUE),
    list(id = 'legend', type = 'legend', editable = TRUE),
    list(id = 'title', type = 'text', editable = TRUE)
  ),
  export = list(
    svg = 'result.svg', pdf = 'result.pdf', png = 'result.png',
    selected_rows = 'selected_rows.csv', matrix_used = 'matrix_used.csv'
  )
)

writeLines(
  jsonlite::toJSON(figure_json, auto_unbox = TRUE, pretty = TRUE, null = 'null'),
  file.path(output_dir, 'figure.json')
)

write_log('Plugin completed successfully.')
quit(status = 0)
