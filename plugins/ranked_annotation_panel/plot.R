#!/usr/bin/env Rscript

# BioFigureAI Plot Plugin: Ranked Annotation Panel
# ------------------------------------------------------------
# Runtime contract:
#   Rscript plot.R --input input.csv --params params.json --output output_dir
#
# Purpose:
#   Draw a left ranked numeric/dot panel with a right annotation heatmap panel.
#   Users choose row labels, rows, left value column, right annotation columns,
#   continuous/discrete colors, and detailed legends/axis styling.

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
  library(grid)
  library(gridExtra)
})

option_list <- list(
  make_option(c('--input'), type = 'character', default = NULL,
              help = 'Path to the main input file, usually CSV/TSV/TXT.'),
  make_option(c('--params'), type = 'character', default = NULL,
              help = 'Path to params.json.'),
  make_option(c('--output'), type = 'character', default = NULL,
              help = 'Output directory.')
)

opt <- parse_args(OptionParser(option_list = option_list))
input_file <- opt$input
params_file <- opt$params
output_dir <- opt$output

write_log <- function(message) {
  log_file <- file.path(output_dir, 'run.log')
  timestamp <- format(Sys.time(), '%Y-%m-%d %H:%M:%S')
  cat(sprintf('[%s] %s\n', timestamp, message), file = log_file, append = TRUE)
}

write_error_and_exit <- function(error, detail = NULL, suggestion = NULL, status = 1) {
  if (is.null(output_dir)) output_dir <<- getwd()
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  error_obj <- list(error = error, detail = ifelse(is.null(detail), '', detail), suggestion = ifelse(is.null(suggestion), '', suggestion))
  writeLines(jsonlite::toJSON(error_obj, auto_unbox = TRUE, pretty = TRUE), file.path(output_dir, 'error.json'))
  message(error)
  quit(status = status)
}

read_table_auto <- function(path) {
  if (is.null(path) || !file.exists(path)) {
    write_error_and_exit('Input file not found', paste('Input path:', path), 'Please provide a valid input file path.')
  }
  ext <- tolower(tools::file_ext(path))
  if (ext == 'csv') return(read.csv(path, check.names = FALSE, stringsAsFactors = FALSE))
  if (ext %in% c('tsv', 'txt')) return(read.delim(path, check.names = FALSE, stringsAsFactors = FALSE))
  write_error_and_exit('Unsupported input file type', paste('File extension:', ext), 'Use csv, tsv, or txt input files.')
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

as_string_vector <- function(x, default = character()) {
  if (is.null(x)) return(default)
  if (is.list(x) && !is.data.frame(x)) x <- unlist(x, use.names = FALSE)
  if (length(x) == 1 && is.character(x) && grepl(',', x, fixed = TRUE)) {
    x <- strsplit(x, ',', fixed = TRUE)[[1]]
  }
  x <- trimws(as.character(x))
  x[nzchar(x)]
}

validate_columns <- function(df, cols) {
  missing_cols <- setdiff(cols, colnames(df))
  if (length(missing_cols) > 0) {
    write_error_and_exit(
      error = 'Required input columns not found',
      detail = paste('Missing columns:', paste(missing_cols, collapse = ', ')),
      suggestion = 'Please check row_label_column, left_value_column, and annotation_columns in params.json.'
    )
  }
}

is_numeric_like <- function(x) {
  y <- suppressWarnings(as.numeric(x))
  sum(!is.na(y)) > 0 && sum(is.na(y)) == sum(is.na(x))
}

named_list_value <- function(x, name, default = NULL) {
  if (is.null(x)) return(default)
  if (!is.null(x[[name]])) return(x[[name]])
  default
}

column_settings <- function(params, column) {
  all <- get_param(params, 'annotation_settings', get_param(params, 'right_panel_settings', NULL))
  if (is.null(all)) return(list())
  if (!is.null(all[[column]])) return(all[[column]])
  list()
}

palette_continuous <- function(params, settings) {
  colors <- as_string_vector(get_param(settings, 'colors', get_param(params, 'annotation_continuous_colors', NULL)))
  if (length(colors) >= 2) return(colors)
  low <- as.character(get_param(settings, 'low_color', get_param(params, 'annotation_low_color', '#008B5A')))[1]
  mid <- as.character(get_param(settings, 'mid_color', get_param(params, 'annotation_mid_color', '#FFFFBF')))[1]
  high <- as.character(get_param(settings, 'high_color', get_param(params, 'annotation_high_color', '#B2182B')))[1]
  c(low, mid, high)
}

value_to_gradient_color <- function(values, value, colors, limits = NULL) {
  values <- suppressWarnings(as.numeric(values))
  value <- suppressWarnings(as.numeric(value))
  if (is.na(value)) return('#FFFFFF')
  if (is.null(limits)) {
    limits <- range(values, na.rm = TRUE)
  } else {
    limits <- suppressWarnings(as.numeric(unlist(limits, use.names = FALSE)))
  }
  if (length(limits) < 2 || any(!is.finite(limits)) || limits[1] == limits[2]) limits <- c(value - 1, value + 1)
  ramp <- grDevices::colorRamp(colors)
  z <- (value - limits[1]) / (limits[2] - limits[1])
  z <- max(0, min(1, z))
  rgb <- ramp(z)
  grDevices::rgb(rgb[, 1], rgb[, 2], rgb[, 3], maxColorValue = 255)
}

discrete_palette <- function(values, params, settings) {
  levels <- unique(as.character(values[!is.na(values)]))
  levels <- levels[nzchar(levels)]
  explicit <- get_param(settings, 'colors', get_param(settings, 'palette', NULL))
  if (is.null(explicit)) explicit <- get_param(params, 'annotation_discrete_colors', NULL)
  out <- NULL
  if (!is.null(explicit)) {
    flat <- unlist(explicit, use.names = TRUE)
    if (!is.null(names(flat)) && any(nzchar(names(flat)))) {
      out <- stats::setNames(rep('#BDBDBD', length(levels)), levels)
      hits <- intersect(names(flat), levels)
      out[hits] <- as.character(flat[hits])
    } else {
      vals <- as.character(flat)
      out <- stats::setNames(rep(vals, length.out = length(levels)), levels)
    }
  }
  if (is.null(out)) {
    colors <- grDevices::hcl.colors(max(3, length(levels)), palette = 'Dark 3')
    out <- stats::setNames(colors[seq_along(levels)], levels)
  }
  out
}

make_continuous_legend <- function(name, colors, label_low, label_high, title_size, text_size, font_family, text_color) {
  n <- 80
  df <- data.frame(x = 1, y = seq_len(n), z = seq(0, 1, length.out = n))
  ggplot(df, aes(x = x, y = y, fill = z)) +
    geom_tile(width = 0.5, height = 1) +
    scale_fill_gradientn(colors = colors, guide = 'none') +
    annotate('text', x = 1.55, y = n, label = label_high, hjust = 0, size = text_size / 3.2, family = font_family, color = text_color) +
    annotate('text', x = 1.55, y = 1, label = label_low, hjust = 0, size = text_size / 3.2, family = font_family, color = text_color) +
    labs(title = name) +
    coord_cartesian(clip = 'off') +
    theme_void(base_family = font_family) +
    theme(
      plot.title = element_text(size = title_size, face = 'bold', color = text_color, hjust = 0),
      plot.margin = margin(2, 28, 2, 2)
    )
}

make_discrete_legend <- function(name, colors, title_size, text_size, font_family, text_color) {
  levels <- names(colors)
  if (length(levels) == 0) return(nullGrob())
  df <- data.frame(level = factor(levels, levels = rev(levels)), x = 1, y = seq_along(levels), fill = unname(colors))
  ggplot(df, aes(x = x, y = level)) +
    geom_tile(aes(fill = fill), width = 0.38, height = 0.7, color = '#FFFFFF', linewidth = 0.2) +
    geom_text(aes(x = 1.35, label = as.character(level)), hjust = 0, size = text_size / 3.2, family = font_family, color = text_color) +
    scale_fill_identity() +
    labs(title = name) +
    coord_cartesian(xlim = c(0.7, 3.2), clip = 'off') +
    theme_void(base_family = font_family) +
    theme(
      plot.title = element_text(size = title_size, face = 'bold', color = text_color, hjust = 0),
      plot.margin = margin(2, 40, 2, 2)
    )
}

if (is.null(input_file)) write_error_and_exit('Missing --input argument')
if (is.null(params_file) || !file.exists(params_file)) write_error_and_exit('Params file not found', paste('Params path:', params_file), 'Provide params.json.')
if (is.null(output_dir)) write_error_and_exit('Missing --output argument')
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

write_log('Plugin started.')
params <- tryCatch(
  jsonlite::fromJSON(params_file, simplifyVector = FALSE),
  error = function(e) write_error_and_exit('Failed to parse params.json', conditionMessage(e), 'Make sure params.json is valid JSON.')
)

df <- read_table_auto(input_file)
write_log(sprintf('Loaded input table with %s rows and %s columns.', nrow(df), ncol(df)))

row_label_column <- get_param_any(params, c('row_label_column', 'label_column', 'id_column', 'gene_column'), colnames(df)[1])
left_value_column <- get_param_any(params, c('left_value_column', 'value_column', 'x_column'), NULL)
if (is.null(left_value_column)) {
  numeric_cols <- setdiff(colnames(df)[vapply(df, is_numeric_like, logical(1))], row_label_column)
  if (length(numeric_cols) == 0) write_error_and_exit('No numeric left value column found', 'left_value_column was not supplied.', 'Set left_value_column in params.json.')
  left_value_column <- numeric_cols[1]
}
annotation_columns <- as_string_vector(get_param_any(params, c('annotation_columns', 'right_panel_columns', 'heatmap_columns'), NULL))
if (length(annotation_columns) == 0) annotation_columns <- setdiff(colnames(df), c(row_label_column, left_value_column))
annotation_columns <- intersect(annotation_columns, colnames(df))
annotation_columns <- setdiff(annotation_columns, as_string_vector(get_param(params, 'annotation_columns_exclude', NULL)))
if (length(annotation_columns) == 0) write_error_and_exit('No annotation columns selected', 'Right panel annotation columns are empty.', 'Set annotation_columns in params.json.')
validate_columns(df, c(row_label_column, left_value_column, annotation_columns))

row_labels <- as.character(df[[row_label_column]])
row_labels[is.na(row_labels) | !nzchar(row_labels)] <- paste0('row_', which(is.na(row_labels) | !nzchar(row_labels)))
row_labels <- make.unique(row_labels)
df$.__row_label <- row_labels
df$.__left_value <- suppressWarnings(as.numeric(df[[left_value_column]]))
df <- df[is.finite(df$.__left_value), , drop = FALSE]
if (nrow(df) == 0) write_error_and_exit('No valid left values', 'No selected rows had finite left_value_column values.', 'Check left_value_column and input data.')

rows_include <- as_string_vector(get_param_any(params, c('rows_include', 'selected_rows', 'row_labels_include'), NULL))
rows_exclude <- as_string_vector(get_param_any(params, c('rows_exclude', 'hidden_rows', 'row_labels_exclude'), NULL))
keep <- rep(TRUE, nrow(df))
if (length(rows_include) > 0) keep <- df$.__row_label %in% rows_include | as.character(df[[row_label_column]]) %in% rows_include
if (length(rows_exclude) > 0) keep <- keep & !(df$.__row_label %in% rows_exclude | as.character(df[[row_label_column]]) %in% rows_exclude)
df <- df[keep, , drop = FALSE]
if (nrow(df) == 0) write_error_and_exit('No rows selected', 'Row selection removed all rows.', 'Select at least one row.')

sort_rows <- as_bool(get_param(params, 'sort_rows_by_left_value', TRUE), TRUE)
sort_decreasing <- as_bool(get_param(params, 'sort_decreasing', TRUE), TRUE)
row_order <- as_string_vector(get_param(params, 'row_order', NULL))
if (length(row_order) == 0) {
  if (sort_rows) {
    row_order <- df$.__row_label[order(df$.__left_value, decreasing = sort_decreasing)]
  } else {
    row_order <- df$.__row_label
  }
}
row_order <- c(intersect(row_order, df$.__row_label), setdiff(df$.__row_label, row_order))
df$.__row_factor <- factor(df$.__row_label, levels = rev(row_order))

title <- as.character(get_param(params, 'title', 'Ranked annotation panel'))[1]
title_show <- as_bool(get_param(params, 'title_show', TRUE), TRUE)
font_family <- as.character(get_param(params, 'font_family', ''))[1]
text_color <- as.character(get_param(params, 'text_color', '#222222'))[1]
title_size <- as.numeric(get_param(params, 'title_size', 14))
row_name_size <- as.numeric(get_param(params, 'row_name_size', get_param(params, 'axis_text_size', 8)))
x_axis_text_size <- as.numeric(get_param(params, 'x_axis_text_size', get_param(params, 'axis_text_size', 9)))
x_title <- as.character(get_param(params, 'x_title', left_value_column))[1]
show_x_axis <- as_bool(get_param(params, 'show_x_axis', TRUE), TRUE)
show_y_axis <- as_bool(get_param(params, 'show_y_axis', TRUE), TRUE)
show_grid <- as_bool(get_param(params, 'show_grid', TRUE), TRUE)
grid_color <- as.character(get_param(params, 'grid_color', '#E6E6E6'))[1]
panel_border <- as_bool(get_param(params, 'panel_border', TRUE), TRUE)
panel_border_color <- as.character(get_param(params, 'panel_border_color', '#555555'))[1]
point_color <- as.character(get_param(params, 'point_color', '#001FBC'))[1]
point_fill <- as.character(get_param(params, 'point_fill', point_color))[1]
point_size <- as.numeric(get_param(params, 'point_size', 2.5))
point_shape <- as.integer(get_param(params, 'point_shape', 21))
point_alpha <- as.numeric(get_param(params, 'point_alpha', 1))
point_stroke <- as.numeric(get_param(params, 'point_stroke', 0.25))
x_min <- get_param(params, 'x_min', NULL)
x_max <- get_param(params, 'x_max', NULL)

left_plot <- ggplot(df, aes(x = .__left_value, y = .__row_factor)) +
  geom_point(shape = point_shape, size = point_size, color = point_color, fill = point_fill, stroke = point_stroke, alpha = point_alpha) +
  labs(title = if (title_show) title else NULL, x = x_title, y = NULL) +
  theme_classic(base_family = font_family) +
  theme(
    plot.title = element_text(size = title_size, face = 'bold', hjust = 0.5, color = text_color),
    axis.text.y = if (show_y_axis) element_text(size = row_name_size, color = text_color) else element_blank(),
    axis.text.x = if (show_x_axis) element_text(size = x_axis_text_size, color = text_color) else element_blank(),
    axis.title.x = if (show_x_axis) element_text(size = as.numeric(get_param(params, 'x_title_size', 10)), color = text_color) else element_blank(),
    axis.ticks.y = element_blank(),
    panel.grid.major.y = if (show_grid) element_line(color = grid_color, linewidth = as.numeric(get_param(params, 'grid_line_width', 0.25)), linetype = as.character(get_param(params, 'grid_line_type', 'dotted'))[1]) else element_blank(),
    panel.grid.major.x = if (as_bool(get_param(params, 'show_x_grid', FALSE), FALSE)) element_line(color = grid_color, linewidth = 0.25) else element_blank(),
    panel.border = if (panel_border) element_rect(fill = NA, color = panel_border_color, linewidth = as.numeric(get_param(params, 'panel_border_width', 0.6))) else element_blank(),
    plot.background = element_rect(fill = '#FFFFFF', color = NA),
    panel.background = element_rect(fill = '#FFFFFF', color = NA)
  )
if (!is.null(x_min) || !is.null(x_max)) {
  left_plot <- left_plot + coord_cartesian(xlim = c(ifelse(is.null(x_min), NA, as.numeric(x_min)), ifelse(is.null(x_max), NA, as.numeric(x_max))))
}

ann_rows <- list()
legend_specs <- list()
idx <- 1
for (col in annotation_columns) {
  settings <- column_settings(params, col)
  col_type <- tolower(as.character(get_param(settings, 'type', get_param(settings, 'mode', ifelse(is_numeric_like(df[[col]]), 'continuous', 'discrete'))))[1])
  if (!col_type %in% c('continuous', 'numeric', 'gradient', 'discrete', 'category', 'categorical')) col_type <- 'discrete'
  display_name <- as.character(get_param(settings, 'label', col))[1]
  if (col_type %in% c('continuous', 'numeric', 'gradient')) {
    colors <- palette_continuous(params, settings)
    limits <- get_param(settings, 'limits', get_param(params, 'annotation_limits', NULL))
    values <- suppressWarnings(as.numeric(df[[col]]))
    fill_colors <- vapply(values, value_to_gradient_color, character(1), values = values, colors = colors, limits = limits)
    legend_specs[[col]] <- list(type = 'continuous', name = display_name, colors = colors, low_label = as.character(get_param(settings, 'low_label', 'Low'))[1], high_label = as.character(get_param(settings, 'high_label', 'High'))[1])
  } else {
    values <- as.character(df[[col]])
    pal <- discrete_palette(values, params, settings)
    fill_colors <- ifelse(is.na(values) | !nzchar(values), as.character(get_param(settings, 'missing_color', '#FFFFFF'))[1], pal[values])
    fill_colors[is.na(fill_colors)] <- as.character(get_param(settings, 'other_color', '#BDBDBD'))[1]
    legend_specs[[col]] <- list(type = 'discrete', name = display_name, colors = pal)
  }
  ann_rows[[idx]] <- data.frame(
    row_label = df$.__row_label,
    row_factor = factor(df$.__row_label, levels = rev(row_order)),
    annotation_column = factor(display_name, levels = vapply(annotation_columns, function(x) as.character(get_param(column_settings(params, x), 'label', x))[1], character(1))),
    raw_value = as.character(df[[col]]),
    fill_color = fill_colors,
    stringsAsFactors = FALSE
  )
  idx <- idx + 1
}
ann_df <- do.call(rbind, ann_rows)

annotation_cell_width <- as.numeric(get_param(params, 'annotation_cell_width', 0.85))
annotation_cell_height <- as.numeric(get_param(params, 'annotation_cell_height', 0.85))
annotation_border_color <- as.character(get_param(params, 'annotation_border_color', '#FFFFFF'))[1]
annotation_border_width <- as.numeric(get_param(params, 'annotation_border_width', 0.25))
annotation_label_size <- as.numeric(get_param(params, 'annotation_label_size', get_param(params, 'column_name_size', 8)))
annotation_label_angle <- as.numeric(get_param(params, 'annotation_label_angle', 45))
show_annotation_labels <- as_bool(get_param(params, 'show_annotation_labels', TRUE), TRUE)

annotation_plot <- ggplot(ann_df, aes(x = annotation_column, y = row_factor)) +
  geom_tile(aes(fill = fill_color), width = annotation_cell_width, height = annotation_cell_height, color = annotation_border_color, linewidth = annotation_border_width) +
  scale_fill_identity() +
  labs(x = NULL, y = NULL) +
  theme_void(base_family = font_family) +
  theme(
    axis.text.x = if (show_annotation_labels) element_text(size = annotation_label_size, angle = annotation_label_angle, hjust = 0, vjust = 0.5, color = text_color) else element_blank(),
    axis.text.y = element_blank(),
    axis.ticks = element_blank(),
    plot.background = element_rect(fill = '#FFFFFF', color = NA),
    panel.background = element_rect(fill = '#FFFFFF', color = NA),
    plot.margin = margin(5.5, 5.5, 5.5, 0)
  ) +
  scale_x_discrete(position = 'top')

legend_title_size <- as.numeric(get_param(params, 'legend_title_size', 9))
legend_text_size <- as.numeric(get_param(params, 'legend_text_size', 8))
show_legend <- as_bool(get_param(params, 'show_legend', TRUE), TRUE)
legend_grobs <- list()
if (show_legend) {
  for (spec in legend_specs) {
    legend_grobs[[length(legend_grobs) + 1]] <- if (identical(spec$type, 'continuous')) {
      ggplotGrob(make_continuous_legend(spec$name, spec$colors, spec$low_label, spec$high_label, legend_title_size, legend_text_size, font_family, text_color))
    } else {
      ggplotGrob(make_discrete_legend(spec$name, spec$colors, legend_title_size, legend_text_size, font_family, text_color))
    }
  }
}
legend_panel <- if (length(legend_grobs) > 0) {
  do.call(gridExtra::arrangeGrob, c(legend_grobs, list(ncol = 1)))
} else {
  nullGrob()
}

left_width <- as.numeric(get_param(params, 'left_panel_width', 5.2))
annotation_width <- as.numeric(get_param(params, 'annotation_panel_width', max(0.7, length(annotation_columns) * 0.35)))
legend_width <- as.numeric(get_param(params, 'legend_panel_width', ifelse(show_legend, 1.6, 0.05)))
aligned_panels <- if (requireNamespace('cowplot', quietly = TRUE)) {
  cowplot::align_plots(left_plot, annotation_plot, align = 'h', axis = 'tb')
} else {
  write_log('Package cowplot is not installed. Falling back to unaligned panel arrangement.')
  list(ggplotGrob(left_plot), ggplotGrob(annotation_plot))
}
combined <- gridExtra::arrangeGrob(
  aligned_panels[[1]],
  aligned_panels[[2]],
  legend_panel,
  ncol = 3,
  widths = grid::unit(c(left_width, annotation_width, legend_width), 'null')
)

width <- as.numeric(get_param(params, 'width', 8))
height <- as.numeric(get_param(params, 'height', max(5, nrow(df) * 0.22 + 1.2)))
svg_file <- file.path(output_dir, 'result.svg')
pdf_file <- file.path(output_dir, 'result.pdf')
png_file <- file.path(output_dir, 'result.png')
figure_json_file <- file.path(output_dir, 'figure.json')
selected_rows_file <- file.path(output_dir, 'selected_rows.csv')

tryCatch({
  ggsave(svg_file, combined, width = width, height = height, device = grDevices::svg, bg = '#FFFFFF')
  ggsave(pdf_file, combined, width = width, height = height, device = grDevices::pdf, bg = '#FFFFFF')
  ggsave(png_file, combined, width = width, height = height, dpi = 300, device = grDevices::png, bg = '#FFFFFF')
}, error = function(e) {
  write_error_and_exit('Failed to save plot outputs', conditionMessage(e), 'Check plotting code, output directory permissions, and graphics device support.')
})

selected_rows_export <- df[, setdiff(colnames(df), c('.__row_label', '.__left_value', '.__row_factor')), drop = FALSE]
selected_rows_export$plot_row_label <- df$.__row_label
selected_rows_export$left_value <- df$.__left_value
selected_rows_export$is_selected <- TRUE
utils::write.csv(selected_rows_export, selected_rows_file, row.names = FALSE)

figure_json <- list(
  figure_type = get_param(params, 'plugin_id', 'ranked_annotation_panel'),
  title = title,
  layout = list(width = width, height = height, left_panel_width = left_width, annotation_panel_width = annotation_width, legend_panel_width = legend_width),
  columns = list(row_label_column = row_label_column, left_value_column = left_value_column, annotation_columns = annotation_columns),
  style = list(
    point_color = point_color,
    point_fill = point_fill,
    point_size = point_size,
    point_shape = point_shape,
    point_alpha = point_alpha,
    show_grid = show_grid,
    grid_color = grid_color,
    panel_border = panel_border,
    annotation_cell_width = annotation_cell_width,
    annotation_cell_height = annotation_cell_height,
    annotation_border_color = annotation_border_color,
    annotation_label_size = annotation_label_size,
    annotation_label_angle = annotation_label_angle,
    show_legend = show_legend,
    legend_title_size = legend_title_size,
    legend_text_size = legend_text_size
  ),
  data = list(input_file = basename(input_file), n_rows = nrow(df), n_annotation_columns = length(annotation_columns), selected_rows_file = 'selected_rows.csv'),
  annotation_legends = legend_specs,
  layers = list(
    list(id = 'left_ranked_points', type = 'scatter', editable = TRUE),
    list(id = 'right_annotation_panel', type = 'heatmap', editable = TRUE),
    list(id = 'row_selection', type = 'selection_table', editable = TRUE, table = 'selected_rows.csv'),
    list(id = 'row_labels', type = 'axis_text', editable = TRUE),
    list(id = 'annotation_legends', type = 'legend', editable = TRUE)
  ),
  export = list(svg = 'result.svg', pdf = 'result.pdf', png = 'result.png', selected_rows = 'selected_rows.csv')
)

writeLines(jsonlite::toJSON(figure_json, auto_unbox = TRUE, pretty = TRUE), figure_json_file)
write_log('Plugin completed successfully.')
quit(status = 0)
