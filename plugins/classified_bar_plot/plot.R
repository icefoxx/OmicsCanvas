#!/usr/bin/env Rscript

# BioFigureAI Plot Plugin: Classified Bar Plot (分类柱状图)
# ------------------------------------------------------------
# Horizontal or vertical bars for categorical items, colored by a
# classification/group column. One bar per category (not stacked).
# Matches ChiPlot-style "classified bar chart" with full WYSIWYG
# axes, title, legend, grid, colors, and export controls.
#
# Runtime:
#   Rscript plot.R --input input.csv --params params.json --output output_dir
#
# Input (long/recommended):
#   category | type/group | value
# Input (wide): first column category labels; remaining numeric columns
#   can be melted, or a single value column + type column.

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
  library(scales)
})

option_list <- list(
  make_option(c('--input'), type = 'character', default = NULL,
              help = 'CSV/TSV/TXT: category, type/group, value columns.'),
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
  # Match image-like groups: coral, blue, gray, green
  base <- c('#E07A5F', '#3D5A80', '#6B6B6B', '#6A994E', '#66C2A5', '#FC8D62',
            '#8DA0CB', '#E78AC3', '#A6D854', '#FFD92F', '#E5C494', '#B3B3B3')
  if (n <= length(base)) return(base[seq_len(n)])
  grDevices::colorRampPalette(base)(n)
}

resolve_colors <- function(n, params, ids) {
  color_map <- as_named_character(get_param_any(params, c(
    'type_colors', 'group_colors', 'category_colors', 'class_colors', 'color_map', 'set_colors'
  ), NULL))
  if (length(color_map) > 0) {
    cols <- rep(NA_character_, n)
    names(cols) <- ids
    hit <- intersect(ids, names(color_map))
    cols[hit] <- color_map[hit]
    missing <- ids[is.na(cols)]
    if (length(missing) > 0) cols[missing] <- default_palette(length(missing))
    return(setNames(unname(cols[ids]), ids))
  }
  colors <- as_string_vector(get_param_any(params, c('colors', 'palette_colors'), NULL))
  if (length(colors) > 0) {
    if (length(colors) >= n) return(setNames(colors[seq_len(n)], ids))
    return(setNames(grDevices::colorRampPalette(colors)(n), ids))
  }
  palette_name <- get_param_any(params, c('palette', 'palette_scheme'), NULL)
  if (!is.null(palette_name) && nzchar(as.character(palette_name)[1])) {
    name <- as.character(palette_name)[1]
    if (requireNamespace('RColorBrewer', quietly = TRUE) && name %in% rownames(RColorBrewer::brewer.pal.info)) {
      k <- min(n, RColorBrewer::brewer.pal.info[name, 'maxcolors'])
      cols <- RColorBrewer::brewer.pal(max(3, k), name)
      if (n > length(cols)) cols <- grDevices::colorRampPalette(cols)(n)
      return(setNames(cols[seq_len(n)], ids))
    }
  }
  setNames(default_palette(n), ids)
}

save_plot <- function(plot, output_dir, width, height, dpi) {
  draw_plot_object <- function(x) {
    if (inherits(x, c('grob', 'gTree', 'gtable'))) {
      grid::grid.newpage(); grid::grid.draw(x)
    } else print(x)
  }
  draw_with_retry <- function(open_device, close_device = grDevices::dev.off) {
    scale <- 1; last_error <- NULL
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

write_log('Plugin classified_bar_plot started.')

params <- tryCatch(
  jsonlite::fromJSON(params_file, simplifyVector = TRUE, simplifyDataFrame = FALSE),
  error = function(e) write_error_and_exit('Failed to parse params.json', conditionMessage(e),
                                           'Please make sure params.json is valid JSON.')
)

df <- read_table_auto(input_file)
write_log(sprintf('Loaded input with %s rows and %s columns.', nrow(df), ncol(df)))

# ------------------------------------------------------------
# Column mapping
# ------------------------------------------------------------
cat_col <- get_param_any(params, c(
  'category_column', 'label_column', 'y_column', 'name_column', 'term_column', 'feature_column', 'row_label_column'
), NULL)
type_col <- get_param_any(params, c(
  'type_column', 'group_column', 'class_column', 'color_column', 'fill_column', 'class_by'
), NULL)
value_col <- get_param_any(params, c(
  'value_column', 'x_column', 'count_column', 'abundance_column', 'score_column'
), NULL)

if (is.null(cat_col) || !cat_col %in% colnames(df)) {
  # first non-numeric-looking or first column
  cat_col <- colnames(df)[1]
}
if (is.null(value_col) || !value_col %in% colnames(df)) {
  nums <- colnames(df)[vapply(df, function(x) {
    suppressWarnings(sum(is.finite(as.numeric(x)))) > nrow(df) * 0.5
  }, logical(1))]
  nums <- setdiff(nums, cat_col)
  if (length(nums) < 1) {
    write_error_and_exit('value_column not found',
                         paste('Columns:', paste(colnames(df), collapse = ', ')),
                         'Set value_column to a numeric column.')
  }
  value_col <- nums[1]
}
if (is.null(type_col) || !type_col %in% colnames(df)) {
  # optional: look for type/group/class column
  candidates <- intersect(c('type', 'group', 'class', 'Type', 'Group', 'Class', 'category_type'), colnames(df))
  candidates <- setdiff(candidates, c(cat_col, value_col))
  if (length(candidates) > 0) {
    type_col <- candidates[1]
  } else {
    # single class
    type_col <- NULL
  }
}

plot_df <- data.frame(
  category = as.character(df[[cat_col]]),
  value = suppressWarnings(as.numeric(df[[value_col]])),
  type = if (!is.null(type_col)) as.character(df[[type_col]]) else 'all',
  stringsAsFactors = FALSE
)
plot_df <- plot_df[is.finite(plot_df$value), , drop = FALSE]
if (nrow(plot_df) < 1) write_error_and_exit('No finite values to plot', '', 'Check value_column.')

# Filters
cats_include <- as_string_vector(get_param_any(params, c('categories_include', 'rows_include', 'labels_include'), NULL))
cats_exclude <- as_string_vector(get_param_any(params, c('categories_exclude', 'rows_exclude', 'labels_exclude'), NULL))
types_include <- as_string_vector(get_param_any(params, c('types_include', 'groups_include', 'classes_include'), NULL))
types_exclude <- as_string_vector(get_param_any(params, c('types_exclude', 'groups_exclude', 'classes_exclude'), NULL))
if (length(cats_include) > 0) plot_df <- plot_df[plot_df$category %in% cats_include, , drop = FALSE]
if (length(cats_exclude) > 0) plot_df <- plot_df[!plot_df$category %in% cats_exclude, , drop = FALSE]
if (length(types_include) > 0) plot_df <- plot_df[plot_df$type %in% types_include, , drop = FALSE]
if (length(types_exclude) > 0) plot_df <- plot_df[!plot_df$type %in% types_exclude, , drop = FALSE]
if (nrow(plot_df) < 1) write_error_and_exit('No rows left after filtering', '', 'Relax include/exclude filters.')

# Order: preserve input order by default (image order: type blocks)
type_order <- as_string_vector(get_param_any(params, c('type_order', 'group_order', 'class_order', 'legend_order'), NULL))
cat_order <- as_string_vector(get_param_any(params, c('category_order', 'label_order', 'row_order'), NULL))
sort_by <- tolower(as.character(get_param_any(params, c('sort_by', 'order_by'), 'input')[1]))
# input | value | value_desc | category | type_value

if (length(type_order) > 0) {
  plot_df$type <- factor(plot_df$type, levels = unique(c(type_order, unique(plot_df$type))))
} else {
  plot_df$type <- factor(plot_df$type, levels = unique(plot_df$type))
}

if (length(cat_order) > 0) {
  plot_df$category <- factor(plot_df$category, levels = unique(c(cat_order, unique(plot_df$category))))
} else if (sort_by %in% c('value', 'value_asc')) {
  plot_df <- plot_df[order(plot_df$value, plot_df$category), , drop = FALSE]
  plot_df$category <- factor(plot_df$category, levels = unique(plot_df$category))
} else if (sort_by %in% c('value_desc', 'value_decreasing', 'desc')) {
  plot_df <- plot_df[order(-plot_df$value, plot_df$category), , drop = FALSE]
  plot_df$category <- factor(plot_df$category, levels = unique(plot_df$category))
} else if (sort_by %in% c('type_value', 'group_value')) {
  plot_df <- plot_df[order(plot_df$type, -plot_df$value), , drop = FALSE]
  plot_df$category <- factor(plot_df$category, levels = unique(plot_df$category))
} else if (sort_by %in% c('category', 'label', 'alpha', 'name')) {
  plot_df <- plot_df[order(plot_df$category), , drop = FALSE]
  plot_df$category <- factor(plot_df$category, levels = unique(plot_df$category))
} else {
  # input order
  plot_df$category <- factor(plot_df$category, levels = unique(plot_df$category))
}

# Deduplicate categories if needed (keep first)
if (any(duplicated(as.character(plot_df$category)))) {
  write_log(sprintf('Duplicate categories detected; keeping first of each (%s dups).',
                    sum(duplicated(as.character(plot_df$category)))))
  plot_df <- plot_df[!duplicated(as.character(plot_df$category)), , drop = FALSE]
  plot_df$category <- factor(plot_df$category, levels = unique(as.character(plot_df$category)))
}

types <- levels(plot_df$type)
fill_cols <- resolve_colors(length(types), params, types)

# ------------------------------------------------------------
# Style
# ------------------------------------------------------------
orientation <- tolower(as.character(get_param_any(params, c('orientation', 'bar_orientation'), 'horizontal')[1]))
horizontal <- orientation %in% c('horizontal', 'horiz', 'h', 'y')

width <- num_param(params, 'width', 8)
height <- num_param(params, 'height', 7)
dpi <- as.integer(num_param(params, 'dpi', 300))
font_family <- get_param_any(params, c('font_family', 'base_font_family'), 'sans')
margin_top <- num_param(params, 'margin_top', 10)
margin_right <- num_param(params, 'margin_right', 10)
margin_bottom <- num_param(params, 'margin_bottom', 10)
margin_left <- num_param(params, 'margin_left', 10)

# Bar geometry
outer_padding <- num_param(params, 'outerPadding', num_param(params, 'outer_padding', 0.15))
bar_width <- num_param(params, 'bar_width', NA)
if (!is.finite(bar_width)) bar_width <- max(0.05, min(1, 1 - outer_padding))
bar_alpha <- num_param(params, 'bar_fill_opacity', num_param(params, 'bar_alpha', num_param(params, 'fill_opacity', 1)))
bar_stroke <- get_param_any(params, c('bar_stroke', 'stroke', 'bar_border_color'), '#000000')
bar_stroke_width <- num_param(params, 'bar_stroke_width', num_param(params, 'stroke_width', 0))
bar_stroke_opacity <- num_param(params, 'bar_stroke_opacity', num_param(params, 'stroke_opacity', 1))

# Bar text
bar_text_show <- as_bool(get_param_any(params, c('bar_text_show', 'show_bar_text', 'show_value', 'show_label'), FALSE), FALSE)
bar_text_size_raw <- num_param(params, 'bar_text_size', 9)
bar_text_size <- if (bar_text_size_raw > 8) bar_text_size_raw / ggplot2::.pt else bar_text_size_raw
bar_text_fill <- get_param_any(params, c('bar_text_fill', 'bar_text_color'), '#222222')
bar_text_weight <- get_param_any(params, c('bar_text_font_weight'), 'normal')
bar_text_style <- get_param_any(params, c('bar_text_font_style'), 'normal')
bar_text_digits <- as.integer(num_param(params, 'bar_text_digits', 0))
bar_text_suffix <- as.character(get_param(params, 'bar_text_suffix', '')[1] %||% '')
bar_text_nudge <- num_param(params, 'bar_text_nudge', 0.02)  # fraction of max value

# Title
title_show <- as_bool(get_param_any(params, c('title_show', 'title_switch'), TRUE), TRUE)
title_text <- as.character(get_param_any(params, c('title', 'title_text'), 'Hello world')[1] %||% 'Hello world')
title_size <- num_param(params, 'title_size', 13)
title_fill <- get_param_any(params, c('title_fill', 'title_color'), '#000000')
title_weight <- get_param_any(params, c('title_font_weight', 'title_weight'), 'normal')
title_style <- get_param_any(params, c('title_font_style'), 'normal')
title_hjust <- switch(tolower(as.character(get_param_any(params, c('title_text_anchor'), 'middle')[1])),
                      start = 0, end = 1, middle = 0.5, 0.5)
subtitle_show <- as_bool(get_param(params, 'subtitle_show', FALSE), FALSE)
subtitle_text <- as.character(get_param(params, 'subtitle', '')[1] %||% '')

# Title background strip
title_bg_show <- as_bool(get_param_any(params, c('title_background_show', 'title_bg_switch'), TRUE), TRUE)
title_bg_fill <- get_param_any(params, c('title_background_fill', 'title_bg_fill'), '#F0F0F0')
title_bg_opacity <- num_param(params, 'title_background_fill_opacity', 1)

# Axes
xlab <- as.character(get_param_any(params, c('xlab', 'x_title', 'x_label'), '')[1] %||% '')
ylab <- as.character(get_param_any(params, c('ylab', 'y_title', 'y_label'), '')[1] %||% '')
xlab_show <- as_bool(get_param_any(params, c('xlab_show', 'x_title_show'), nzchar(xlab)), nzchar(xlab))
ylab_show <- as_bool(get_param_any(params, c('ylab_show', 'y_title_show'), nzchar(ylab)), nzchar(ylab))

x_text_show <- as_bool(get_param_any(params, c('x_axis_text_show'), TRUE), TRUE)
y_text_show <- as_bool(get_param_any(params, c('y_axis_text_show'), TRUE), TRUE)
x_rotate <- num_param(params, 'x_axis_text_angle', num_param(params, 'x_rotate', 0))
y_rotate <- num_param(params, 'y_axis_text_angle', num_param(params, 'y_rotate', 0))
x_text_size <- num_param(params, 'x_axis_text_size', 9)
y_text_size <- num_param(params, 'y_axis_text_size', 9)
x_text_fill <- get_param_any(params, c('x_axis_text_fill', 'x_axis_text_color'), '#000000')
y_text_fill <- get_param_any(params, c('y_axis_text_fill', 'y_axis_text_color'), '#000000')
x_text_weight <- get_param_any(params, c('x_axis_font_weight'), 'normal')
y_text_weight <- get_param_any(params, c('y_axis_font_weight'), 'normal')
x_text_style <- get_param_any(params, c('x_axis_font_style'), 'normal')
y_text_style <- get_param_any(params, c('y_axis_font_style'), 'normal')
x_label_size <- num_param(params, 'x_axis_title_size', 11)
y_label_size <- num_param(params, 'y_axis_title_size', 11)
x_label_fill <- get_param_any(params, c('x_axis_title_color'), '#000000')
y_label_fill <- get_param_any(params, c('y_axis_title_color'), '#000000')

# Ticks
x_tick_stroke <- get_param_any(params, c('x_tick_stroke', 'tick_stroke'), '#000000')
y_tick_stroke <- get_param_any(params, c('y_tick_stroke', 'tick_stroke'), '#000000')
x_tick_width <- num_param(params, 'x_tick_stroke_width', 0.8)
y_tick_width <- num_param(params, 'y_tick_stroke_width', 0.8)
x_tick_length <- num_param(params, 'x_tick_length', 4)
y_tick_length <- num_param(params, 'y_tick_length', 4)
x_tick_orientation <- tolower(as.character(get_param_any(params, c('x_tick_orientation', 'tick_orientation'), 'outside')[1]))
y_tick_orientation <- tolower(as.character(get_param_any(params, c('y_tick_orientation', 'tick_orientation'), 'outside')[1]))
x_remove_path <- as_bool(get_param_any(params, c('x_remove_path', 'removePath'), FALSE), FALSE)
y_remove_path <- as_bool(get_param_any(params, c('y_remove_path', 'removePath'), FALSE), FALSE)
x_remove_tick <- as_bool(get_param_any(params, c('x_remove_tick', 'removeTick'), FALSE), FALSE)
y_remove_tick <- as_bool(get_param_any(params, c('y_remove_tick', 'removeTick'), FALSE), FALSE)
tick_dir_x <- if (x_tick_orientation == 'inside') -1 else 1
tick_dir_y <- if (y_tick_orientation == 'inside') -1 else 1

# Value axis limits
x_min <- suppressWarnings(as.numeric(get_param_any(params, c('x_min', 'min_value', 'value_min'), NA))[1])
x_max <- suppressWarnings(as.numeric(get_param_any(params, c('x_max', 'max_value', 'value_max'), NA))[1])
if (!is.finite(x_min)) x_min <- 0
if (!is.finite(x_max)) {
  x_max <- max(plot_df$value, na.rm = TRUE) * 1.05
  if (!is.finite(x_max) || x_max <= x_min) x_max <- x_min + 1
}

# Grid (image has light horizontal/vertical grid)
x_grid_show <- as_bool(get_param_any(params, c('x_grid_show', 'grid_show', 'show_grid'), TRUE), TRUE)
y_grid_show <- as_bool(get_param_any(params, c('y_grid_show', 'grid_show', 'show_grid'), FALSE), FALSE)
# for horizontal bars, major grid along value axis (x)
if (horizontal && is.null(params$x_grid_show) && is.null(params$grid_show) && is.null(params$show_grid)) {
  x_grid_show <- TRUE
  y_grid_show <- FALSE
}
grid_stroke <- get_param_any(params, c('grid_stroke', 'grid_color'), '#CCCCCC')
grid_stroke_width <- num_param(params, 'grid_stroke_width', 0.4)
grid_stroke_opacity <- num_param(params, 'grid_stroke_opacity', 0.7)
grid_line_type <- get_param_any(params, c('grid_line_type', 'grid_type'), 'solid')

# Background / panel
plot_bg_show <- as_bool(get_param_any(params, c('background_show'), FALSE), FALSE)
plot_bg_fill <- get_param_any(params, c('background_fill', 'plot_background'), '#FFFFFF')
plot_bg_opacity <- num_param(params, 'background_fill_opacity', 1)
panel_border <- as_bool(get_param_any(params, c('panel_border', 'panel_border_show'), TRUE), TRUE)
panel_border_color <- get_param_any(params, c('panel_border_color'), '#444444')
panel_border_width <- num_param(params, 'panel_border_width', 0.5)

# Legend
legend_show <- as_bool(get_param_any(params, c('legend_show', 'legend_switch', 'show_legend'), TRUE), TRUE)
legend_title <- as.character(get_param_any(params, c('legend_title', 'legend_name'), 'xiaoshi')[1] %||% 'xiaoshi')
legend_position <- get_param(params, 'legend_position', 'right')
legend_direction <- get_param(params, 'legend_direction', 'vertical')
legend_title_size <- num_param(params, 'legend_title_size', 11)
legend_text_size <- num_param(params, 'legend_text_size', 10)
legend_key_size <- num_param(params, 'legend_key_size', 0.4)
legend_title_fill <- get_param_any(params, c('legend_title_fill', 'legend_title_color'), '#000000')
legend_text_fill <- get_param_any(params, c('legend_text_fill'), '#000000')
legend_title_weight <- get_param_any(params, c('legend_title_font_weight'), 'normal')
legend_columns <- as.integer(num_param(params, 'legend_columns', num_param(params, 'legend_ncol', 1)))
legend_reverse <- as_bool(get_param(params, 'legend_reverse', FALSE), FALSE)
# Image shows type-D on top of legend — reverse of factor order if types are A,B,C,D in data order
if (is.null(params$legend_reverse) && length(types) > 1) {
  # default: reverse so last type appears first (matches image type-D top)
  legend_reverse <- TRUE
}

# Reverse categorical axis so first row in data appears at top (horizontal bars)
reverse_cat <- as_bool(get_param_any(params, c('reverse_category', 'reverse_y', 'reverse_x'), TRUE), TRUE)

# ------------------------------------------------------------
# Build plot
# ------------------------------------------------------------
stroke_col <- if (bar_stroke_width > 0) alpha(bar_stroke, bar_stroke_opacity) else NA

if (horizontal) {
  p <- ggplot(plot_df, aes(y = .data$category, x = .data$value, fill = .data$type))
} else {
  p <- ggplot(plot_df, aes(x = .data$category, y = .data$value, fill = .data$type))
}

p <- p +
  geom_col(
    width = bar_width,
    alpha = bar_alpha,
    colour = stroke_col,
    linewidth = if (bar_stroke_width > 0) bar_stroke_width / 2 else 0,
    show.legend = legend_show
  ) +
  scale_fill_manual(
    values = fill_cols,
    name = legend_title,
    breaks = if (legend_reverse) rev(types) else types,
    drop = FALSE,
    guide = if (legend_show) 'legend' else 'none'
  )

if (bar_text_show) {
  nudge <- (x_max - x_min) * bar_text_nudge
  plot_df$label_str <- paste0(formatC(plot_df$value, format = 'f', digits = bar_text_digits), bar_text_suffix)
  if (horizontal) {
    p <- p + geom_text(
      data = plot_df,
      aes(y = .data$category, x = .data$value + nudge, label = .data$label_str),
      hjust = 0, size = bar_text_size, colour = bar_text_fill,
      fontface = face_from_style(bar_text_weight, bar_text_style),
      family = font_family, inherit.aes = FALSE
    )
  } else {
    p <- p + geom_text(
      data = plot_df,
      aes(x = .data$category, y = .data$value + nudge, label = .data$label_str),
      vjust = 0, size = bar_text_size, colour = bar_text_fill,
      fontface = face_from_style(bar_text_weight, bar_text_style),
      family = font_family, inherit.aes = FALSE
    )
  }
}

# Scales
cat_levels <- levels(plot_df$category)
if (reverse_cat) cat_levels <- rev(cat_levels)

if (horizontal) {
  p <- p +
    scale_x_continuous(limits = c(x_min, x_max), expand = expansion(mult = c(0, 0.02)),
                       labels = scales::comma) +
    scale_y_discrete(limits = cat_levels)
} else {
  p <- p +
    scale_y_continuous(limits = c(x_min, x_max), expand = expansion(mult = c(0, 0.02)),
                       labels = scales::comma) +
    scale_x_discrete(limits = cat_levels)
}

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
    face = face_from_style(title_weight, title_style),
    hjust = title_hjust,
    margin = margin(t = 4, b = 4)
  ) else element_blank(),
  plot.subtitle = if (subtitle_show && nzchar(subtitle_text)) element_text(size = title_size * 0.85) else element_blank(),
  plot.background = element_rect(fill = bg_fill_final, colour = NA),
  panel.background = element_rect(fill = bg_fill_final, colour = NA),
  panel.border = if (panel_border) element_rect(fill = NA, colour = panel_border_color, linewidth = panel_border_width) else element_blank(),
  # title strip background via plot title margin + optional rect is limited in ggplot;
  # approximate with light panel + title area using plot.margin
  axis.title.x = if (xlab_show) element_text(size = x_label_size, colour = x_label_fill) else element_blank(),
  axis.title.y = if (ylab_show) element_text(size = y_label_size, colour = y_label_fill) else element_blank(),
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
    angle = y_rotate,
    hjust = 1
  ) else element_blank(),
  axis.ticks.x = if (x_remove_tick) element_blank() else element_line(colour = x_tick_stroke, linewidth = x_tick_width / 2),
  axis.ticks.y = if (y_remove_tick) element_blank() else element_line(colour = y_tick_stroke, linewidth = y_tick_width / 2),
  axis.ticks.length.x = grid::unit(tick_dir_x * x_tick_length, 'pt'),
  axis.ticks.length.y = grid::unit(tick_dir_y * y_tick_length, 'pt'),
  axis.line.x = if (x_remove_path) element_blank() else element_line(colour = x_tick_stroke, linewidth = x_tick_width / 2),
  axis.line.y = if (y_remove_path) element_blank() else element_line(colour = y_tick_stroke, linewidth = y_tick_width / 2),
  panel.grid.major.x = if ((horizontal && x_grid_show) || (!horizontal && y_grid_show)) {
    element_line(colour = alpha(grid_stroke, grid_stroke_opacity), linewidth = grid_stroke_width / 2, linetype = grid_line_type)
  } else element_blank(),
  panel.grid.major.y = if ((!horizontal && x_grid_show) || (horizontal && y_grid_show)) {
    element_line(colour = alpha(grid_stroke, grid_stroke_opacity), linewidth = grid_stroke_width / 2, linetype = grid_line_type)
  } else element_blank(),
  panel.grid.minor = element_blank(),
  legend.position = if (legend_show) legend_position else 'none',
  legend.direction = legend_direction,
  legend.title = element_text(
    size = legend_title_size, colour = legend_title_fill,
    face = face_from_style(legend_title_weight, 'normal')
  ),
  legend.text = element_text(size = legend_text_size, colour = legend_text_fill),
  legend.key.size = grid::unit(legend_key_size, 'cm'),
  plot.margin = margin(margin_top, margin_right, margin_bottom, margin_left)
)

if (legend_show) {
  p <- p + guides(fill = guide_legend(ncol = max(1, legend_columns), reverse = FALSE))
}

# Title background strip via cowplot/patchwork-free approach: use ggtitle with theme
# and optionally annotate a rect in plot space is hard; if title_bg_show, lighten title area
if (title_bg_show && title_show && nzchar(title_text)) {
  p <- p + theme(
    plot.title = element_text(
      size = title_size, colour = title_fill,
      face = face_from_style(title_weight, title_style),
      hjust = title_hjust,
      margin = margin(t = 6, b = 6, l = 4, r = 4)
    ),
    plot.background = element_rect(
      fill = bg_fill_final,
      colour = alpha(title_bg_fill, title_bg_opacity),
      linewidth = 0.3
    )
  )
}

write_log(sprintf(
  'Built classified bar: %s categories, %s types, orientation=%s.',
  nrow(plot_df), length(types), orientation
))

# Exports
selected <- data.frame(
  category = as.character(plot_df$category),
  type = as.character(plot_df$type),
  value = plot_df$value,
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
  figure_type = 'classified_bar_plot',
  title = if (title_show) title_text else '',
  theme = 'classic',
  layout = list(width = width, height = height, orientation = orientation),
  analysis = list(
    n_categories = nrow(plot_df),
    n_types = length(types),
    types = types,
    category_column = cat_col,
    type_column = type_col %||% '',
    value_column = value_col,
    value_range = c(x_min, x_max)
  ),
  style = list(
    bar_width = bar_width,
    palette = as.list(fill_cols),
    legend_position = legend_position,
    legend_title = legend_title,
    grid_show = x_grid_show || y_grid_show
  ),
  data = list(input_file = basename(input_file), n_rows = nrow(plot_df)),
  layers = list(
    list(id = 'bars', type = 'bar', editable = TRUE),
    list(id = 'bar_text', type = 'text', editable = TRUE),
    list(id = 'x_axis', type = 'axis', editable = TRUE),
    list(id = 'y_axis', type = 'axis', editable = TRUE),
    list(id = 'legend', type = 'legend', editable = TRUE),
    list(id = 'title', type = 'text', editable = TRUE),
    list(id = 'grid', type = 'grid', editable = TRUE)
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
