#!/usr/bin/env Rscript

# BioFigureAI Plot Plugin: Quadrant Correlation Scatter
# ------------------------------------------------------------
# Runtime contract:
#   Rscript plot.R --input input.csv --params params.json --output output_dir
#
# Purpose:
#   Draw a highly customizable x/y scatter plot with quadrant/region coloring,
#   threshold lines, correlation text, selected point labels, and table-driven
#   row selection.

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
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
      suggestion = 'Please check x_column, y_column, and label_column in params.json.'
    )
  }
}

first_existing_col <- function(df, candidates, required = TRUE, label = 'column') {
  hit <- candidates[candidates %in% colnames(df)][1]
  if (!is.na(hit)) return(hit)
  if (required) {
    write_error_and_exit('Could not detect required column', paste(label, 'candidates:', paste(candidates, collapse = ', ')), paste('Provide', label, 'in params.json.'))
  }
  NULL
}

named_color_vector <- function(x, levels_needed, default_color) {
  out <- stats::setNames(rep(default_color, length(levels_needed)), levels_needed)
  if (is.null(x)) return(out)
  values <- as.character(unlist(x, use.names = TRUE))
  if (!is.null(names(values)) && any(nzchar(names(values)))) {
    hits <- intersect(names(values), levels_needed)
    out[hits] <- values[hits]
  } else if (length(values) > 0) {
    out <- stats::setNames(rep(values, length.out = length(levels_needed)), levels_needed)
  }
  out
}

as_region_list <- function(x) {
  if (is.null(x)) return(list())
  if (is.data.frame(x)) return(lapply(seq_len(nrow(x)), function(i) as.list(x[i, , drop = FALSE])))
  if (is.list(x) && length(x) > 0 && all(vapply(x, is.list, logical(1)))) return(x)
  list()
}

region_value <- function(region, name, default = NULL) {
  if (!is.null(region[[name]]) && length(region[[name]]) > 0 && !is.na(region[[name]][1])) return(region[[name]][1])
  default
}

match_region_condition <- function(plot_df, region) {
  condition <- region_value(region, 'condition', NULL)
  if (!is.null(condition) && nzchar(as.character(condition))) {
    eval_env <- as.list(plot_df)
    eval_env$x <- plot_df$.__x
    eval_env$y <- plot_df$.__y
    hit <- tryCatch(eval(parse(text = as.character(condition)), envir = eval_env), error = function(e) rep(FALSE, nrow(plot_df)))
    hit <- as.logical(hit)
    if (length(hit) != nrow(plot_df)) hit <- rep(FALSE, nrow(plot_df))
    hit[is.na(hit)] <- FALSE
    return(hit)
  }
  xmin <- suppressWarnings(as.numeric(region_value(region, 'xmin', -Inf)))
  xmax <- suppressWarnings(as.numeric(region_value(region, 'xmax', Inf)))
  ymin <- suppressWarnings(as.numeric(region_value(region, 'ymin', -Inf)))
  ymax <- suppressWarnings(as.numeric(region_value(region, 'ymax', Inf)))
  hit <- plot_df$.__x >= xmin & plot_df$.__x <= xmax & plot_df$.__y >= ymin & plot_df$.__y <= ymax
  hit[is.na(hit)] <- FALSE
  hit
}

style_records <- function(x) {
  if (is.null(x)) return(list())
  if (is.data.frame(x)) return(lapply(seq_len(nrow(x)), function(i) as.list(x[i, , drop = FALSE])))
  if (is.list(x) && length(x) > 0 && all(vapply(x, is.list, logical(1)))) return(x)
  list()
}

record_ids <- function(record) {
  ids <- as_string_vector(region_value(record, 'ids', NULL))
  ids <- c(ids, as_string_vector(region_value(record, 'genes', NULL)))
  one_id <- region_value(record, 'id', region_value(record, 'gene', NULL))
  if (!is.null(one_id)) ids <- c(ids, as.character(one_id))
  unique(ids[nzchar(ids)])
}

if (is.null(input_file)) write_error_and_exit('Missing --input argument')
if (is.null(params_file) || !file.exists(params_file)) write_error_and_exit('Params file not found', paste('Params path:', params_file), 'Provide params.json.')
if (is.null(output_dir)) write_error_and_exit('Missing --output argument')
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
old_outputs <- file.path(output_dir, c('error.json', 'result.svg', 'result.pdf', 'result.png', 'figure.json', 'selected_rows.csv', 'run.log'))
unlink(old_outputs[file.exists(old_outputs)])

write_log('Plugin started.')
params <- tryCatch(
  jsonlite::fromJSON(params_file, simplifyVector = FALSE),
  error = function(e) write_error_and_exit('Failed to parse params.json', conditionMessage(e), 'Make sure params.json is valid JSON.')
)

df <- read_table_auto(input_file)
write_log(sprintf('Loaded input table with %s rows and %s columns.', nrow(df), ncol(df)))

x_col <- get_param_any(params, c('x_column', 'x_col'), NULL)
y_col <- get_param_any(params, c('y_column', 'y_col'), NULL)
label_col <- get_param_any(params, c('label_column', 'row_label_column', 'id_column', 'gene_column'), NULL)
if (is.null(label_col)) label_col <- first_existing_col(df, c('gene', 'Gene', 'id', 'ID', 'feature', 'Feature', colnames(df)[1]), TRUE, 'label_column')
if (is.null(x_col) || is.null(y_col)) {
  numeric_cols <- setdiff(colnames(df)[vapply(df, function(x) sum(!is.na(suppressWarnings(as.numeric(x)))) > 0, logical(1))], label_col)
  if (is.null(x_col) && length(numeric_cols) >= 1) x_col <- numeric_cols[1]
  if (is.null(y_col) && length(numeric_cols) >= 2) y_col <- numeric_cols[2]
}
validate_columns(df, c(label_col, x_col, y_col))

plot_df <- df
plot_df$.__label <- make.unique(as.character(plot_df[[label_col]]))
plot_df$.__x <- suppressWarnings(as.numeric(plot_df[[x_col]]))
plot_df$.__y <- suppressWarnings(as.numeric(plot_df[[y_col]]))
plot_df <- plot_df[is.finite(plot_df$.__x) & is.finite(plot_df$.__y), , drop = FALSE]
if (nrow(plot_df) == 0) write_error_and_exit('No valid scatter data', 'No rows had finite x/y values.', 'Check x_column and y_column.')

rows_include <- as_string_vector(get_param_any(params, c('rows_include', 'selected_rows', 'row_labels_include'), NULL))
rows_exclude <- as_string_vector(get_param_any(params, c('rows_exclude', 'hidden_rows', 'row_labels_exclude'), NULL))
keep <- rep(TRUE, nrow(plot_df))
if (length(rows_include) > 0) keep <- plot_df$.__label %in% rows_include | as.character(plot_df[[label_col]]) %in% rows_include
if (length(rows_exclude) > 0) keep <- keep & !(plot_df$.__label %in% rows_exclude | as.character(plot_df[[label_col]]) %in% rows_exclude)
plot_df <- plot_df[keep, , drop = FALSE]
if (nrow(plot_df) == 0) write_error_and_exit('No rows selected', 'Row include/exclude settings removed all rows.', 'Select at least one row.')

x_thresholds <- suppressWarnings(as.numeric(unlist(get_param(params, 'x_thresholds', c(-1, 1)), use.names = FALSE)))
y_thresholds <- suppressWarnings(as.numeric(unlist(get_param(params, 'y_thresholds', c(-1, 1)), use.names = FALSE)))
x_thresholds <- x_thresholds[is.finite(x_thresholds)]
y_thresholds <- y_thresholds[is.finite(y_thresholds)]
x_low <- if (length(x_thresholds) >= 1) min(x_thresholds) else -1
x_high <- if (length(x_thresholds) >= 1) max(x_thresholds) else 1
y_low <- if (length(y_thresholds) >= 1) min(y_thresholds) else -1
y_high <- if (length(y_thresholds) >= 1) max(y_thresholds) else 1

quadrant_mode <- tolower(as.character(get_param(params, 'quadrant_mode', 'nine'))[1])
if (!quadrant_mode %in% c('four', 'nine', 'custom')) quadrant_mode <- 'nine'
bin_axis <- function(v, low, high) {
  ifelse(v < low, 'low', ifelse(v > high, 'high', 'mid'))
}
if (quadrant_mode == 'four') {
  x_bin <- ifelse(plot_df$.__x >= 0, 'right', 'left')
  y_bin <- ifelse(plot_df$.__y >= 0, 'top', 'bottom')
  plot_df$.__group <- paste(y_bin, x_bin, sep = '_')
  default_levels <- c('top_right', 'top_left', 'bottom_left', 'bottom_right')
  default_colors <- c('#D63B42', '#66C2E8', '#3BAA68', '#F08A45')
} else {
  x_bin <- bin_axis(plot_df$.__x, x_low, x_high)
  y_bin <- bin_axis(plot_df$.__y, y_low, y_high)
  group_map <- c(
    high_high = 'quadrant 3', mid_high = 'quadrant 2', low_high = 'quadrant 1',
    low_mid = 'quadrant 4', mid_mid = 'quadrant 5', high_mid = 'quadrant 6',
    low_low = 'quadrant 7', mid_low = 'quadrant 8', high_low = 'quadrant 9'
  )
  plot_df$.__group <- unname(group_map[paste(x_bin, y_bin, sep = '_')])
  default_levels <- paste('quadrant', 1:9)
  default_colors <- c('#F2B134', '#62BDEB', '#D63B42', '#3BAA68', '#F9E729', '#9C1C8A', '#00A99D', '#F08A45', '#6D52C1')
}

custom_regions <- as_region_list(get_param(params, 'regions', get_param(params, 'quadrant_regions', NULL)))
region_styles <- NULL
if (length(custom_regions) > 0) {
  style_rows <- list()
  for (idx in seq_along(custom_regions)) {
    region <- custom_regions[[idx]]
    id <- as.character(region_value(region, 'id', paste0('region_', idx)))
    label <- as.character(region_value(region, 'label', id))
    hit <- match_region_condition(plot_df, region)
    plot_df$.__group[hit] <- label
    style_rows[[idx]] <- data.frame(
      id = id,
      label = label,
      color = as.character(region_value(region, 'color', region_value(region, 'fill', default_colors[(idx - 1) %% length(default_colors) + 1]))),
      shape = suppressWarnings(as.integer(region_value(region, 'shape', get_param(params, 'point_shape', 16)))),
      size = suppressWarnings(as.numeric(region_value(region, 'size', get_param(params, 'point_size', 0.8)))),
      alpha = suppressWarnings(as.numeric(region_value(region, 'alpha', get_param(params, 'point_alpha', 0.85)))),
      stringsAsFactors = FALSE
    )
  }
  region_styles <- do.call(rbind, style_rows)
  default_levels <- c(default_levels, region_styles$label)
  default_colors <- c(default_colors, region_styles$color)
}

legend_levels <- as_string_vector(get_param(params, 'legend_levels', default_levels))
legend_levels <- c(intersect(legend_levels, unique(plot_df$.__group)), setdiff(unique(plot_df$.__group), legend_levels))
group_colors <- named_color_vector(get_param(params, 'quadrant_colors', get_param(params, 'group_colors', NULL)), legend_levels, '#BDBDBD')
default_named <- stats::setNames(rep(default_colors, length.out = length(default_levels)), default_levels)
hits <- intersect(names(default_named), names(group_colors))
group_colors[hits] <- default_named[hits]
plot_df$.__group <- factor(plot_df$.__group, levels = legend_levels)

selected_ids <- as_string_vector(get_param(params, 'selected_ids', get_param(params, 'label_ids', get_param(params, 'selected_genes', NULL))))
top_n_labels <- as.integer(get_param(params, 'top_n_labels', 0))
plot_df$.__selected <- plot_df$.__label %in% selected_ids
if (top_n_labels > 0) {
  idx <- head(order(abs(plot_df$.__x) + abs(plot_df$.__y), decreasing = TRUE), top_n_labels)
  plot_df$.__selected[idx] <- TRUE
}

point_size <- as.numeric(get_param(params, 'point_size', 0.8))
point_alpha <- as.numeric(get_param(params, 'point_alpha', 0.85))
point_shape <- as.integer(get_param(params, 'point_shape', 16))
selected_point_size <- as.numeric(get_param(params, 'selected_point_size', 2.4))
selected_point_shape <- as.integer(get_param(params, 'selected_point_shape', 21))
selected_point_fill <- as.character(get_param(params, 'selected_point_fill', '#FFD166'))[1]
selected_point_color <- as.character(get_param(params, 'selected_point_color', '#212121'))[1]
selected_point_stroke <- as.numeric(get_param(params, 'selected_point_stroke', 0.6))

label_show <- as_bool(get_param(params, 'label_show', TRUE), TRUE)
label_size <- as.numeric(get_param(params, 'label_size', 3.2))
label_color <- as.character(get_param(params, 'label_color', '#212121'))[1]
label_line_color <- as.character(get_param(params, 'label_line_color', '#777777'))[1]
label_line_type <- as.character(get_param(params, 'label_line_type', 'solid'))[1]
label_line_width <- as.numeric(get_param(params, 'label_line_width', 0.35))
label_force <- as.numeric(get_param(params, 'label_force', 12))
label_max_overlaps <- as.integer(get_param(params, 'label_max_overlaps', 100))
plot_df$.__label_x <- NA_real_
plot_df$.__label_y <- NA_real_
plot_df$.__label_color <- label_color
plot_df$.__label_line_color <- label_line_color
plot_df$.__label_line_type <- label_line_type
plot_df$.__label_line_width <- label_line_width

records <- style_records(get_param(params, 'selected_point_styles', NULL))
for (record in records) {
  ids <- record_ids(record)
  hit <- plot_df$.__label %in% ids
  if (!any(hit)) next
  plot_df$.__selected[hit] <- as_bool(region_value(record, 'selected', TRUE), TRUE)
  lx <- suppressWarnings(as.numeric(region_value(record, 'label_x', NA_real_)))
  ly <- suppressWarnings(as.numeric(region_value(record, 'label_y', NA_real_)))
  if (!is.na(lx)) plot_df$.__label_x[hit] <- lx
  if (!is.na(ly)) plot_df$.__label_y[hit] <- ly
  plot_df$.__label_color[hit] <- as.character(region_value(record, 'label_color', label_color))
  plot_df$.__label_line_color[hit] <- as.character(region_value(record, 'indicator_color', region_value(record, 'label_line_color', label_line_color)))
  plot_df$.__label_line_type[hit] <- as.character(region_value(record, 'indicator_type', region_value(record, 'label_line_type', label_line_type)))
  plot_df$.__label_line_width[hit] <- suppressWarnings(as.numeric(region_value(record, 'indicator_width', region_value(record, 'label_line_width', label_line_width))))
}

cor_method <- as.character(get_param(params, 'cor_method', get_param(params, 'correlation_method', 'pearson')))[1]
cor_result <- suppressWarnings(stats::cor.test(plot_df$.__x, plot_df$.__y, method = cor_method))
cor_value <- unname(cor_result$estimate)
p_value <- cor_result$p.value
cor_digits <- as.integer(get_param(params, 'cor_digits', 4))
p_digits <- as.integer(get_param(params, 'p_digits', 4))
# A p-value is never 0: below the display precision use scientific notation,
# below machine precision report an upper bound (as base R's format.pval does).
format_p <- function(p) {
  if (is.na(p)) return('NA')
  if (p < .Machine$double.eps) return(sprintf('< %s', formatC(.Machine$double.eps, format = 'e', digits = 1)))
  if (p < 10^-p_digits) return(formatC(p, format = 'e', digits = 2))
  formatC(p, format = 'f', digits = p_digits)
}
cor_label <- as.character(get_param(params, 'correlation_label', sprintf('%s correlation: %s\np-value: %s', cor_method, formatC(cor_value, format = 'f', digits = cor_digits), format_p(p_value))))[1]
show_correlation <- as_bool(get_param(params, 'show_correlation', TRUE), TRUE)
cor_label_position <- tolower(as.character(get_param(params, 'cor_label_position', 'title'))[1])
if (!cor_label_position %in% c('title', 'subtitle', 'panel', 'none')) cor_label_position <- 'title'

title <- as.character(get_param(params, 'title', ''))[1]
title_show <- as_bool(get_param(params, 'title_show', FALSE), FALSE)
x_title <- as.character(get_param(params, 'x_title', x_col))[1]
y_title <- as.character(get_param(params, 'y_title', y_col))[1]
font_family <- as.character(get_param(params, 'font_family', ''))[1]
text_color <- as.character(get_param(params, 'text_color', '#222222'))[1]
title_size <- as.numeric(get_param(params, 'title_size', 14))
axis_title_size <- as.numeric(get_param(params, 'axis_title_size', 12))
axis_text_size <- as.numeric(get_param(params, 'axis_text_size', 10))
legend_name <- as.character(get_param(params, 'legend_name', ''))[1]
legend_position <- as.character(get_param(params, 'legend_position', 'right'))[1]
legend_title_size <- as.numeric(get_param(params, 'legend_title_size', 10))
legend_text_size <- as.numeric(get_param(params, 'legend_text_size', 9))
legend_point_size <- as.numeric(get_param(params, 'legend_point_size', 3))
show_legend <- as_bool(get_param(params, 'show_legend', TRUE), TRUE)
show_grid <- as_bool(get_param(params, 'show_grid', TRUE), TRUE)
grid_color <- as.character(get_param(params, 'grid_color', '#E6E6E6'))[1]
panel_border_color <- as.character(get_param(params, 'panel_border_color', '#222222'))[1]
panel_border_width <- as.numeric(get_param(params, 'panel_border_width', 0.7))
threshold_line_color <- as.character(get_param(params, 'threshold_line_color', '#888888'))[1]
threshold_line_type <- as.character(get_param(params, 'threshold_line_type', 'dashed'))[1]
threshold_line_width <- as.numeric(get_param(params, 'threshold_line_width', 0.4))
zero_line_color <- as.character(get_param(params, 'zero_line_color', threshold_line_color))[1]
show_zero_lines <- as_bool(get_param(params, 'show_zero_lines', TRUE), TRUE)

p <- ggplot(plot_df, aes(x = .__x, y = .__y)) +
  geom_point(aes(color = .__group), size = point_size, shape = point_shape, alpha = point_alpha)
if (length(x_thresholds) > 0) p <- p + geom_vline(xintercept = x_thresholds, color = threshold_line_color, linetype = threshold_line_type, linewidth = threshold_line_width)
if (length(y_thresholds) > 0) p <- p + geom_hline(yintercept = y_thresholds, color = threshold_line_color, linetype = threshold_line_type, linewidth = threshold_line_width)
if (show_zero_lines) {
  p <- p +
    geom_vline(xintercept = 0, color = zero_line_color, linetype = as.character(get_param(params, 'zero_line_type', 'dotted'))[1], linewidth = threshold_line_width) +
    geom_hline(yintercept = 0, color = zero_line_color, linetype = as.character(get_param(params, 'zero_line_type', 'dotted'))[1], linewidth = threshold_line_width)
}
p <- p + scale_color_manual(name = legend_name, values = group_colors, drop = FALSE)

selected_df <- plot_df[plot_df$.__selected, , drop = FALSE]
if (nrow(selected_df) > 0) {
  p <- p + geom_point(data = selected_df, shape = selected_point_shape, fill = selected_point_fill, color = selected_point_color, size = selected_point_size, stroke = selected_point_stroke, show.legend = FALSE)
}
if (label_show && nrow(selected_df) > 0) {
  manual_label_df <- selected_df[is.finite(selected_df$.__label_x) & is.finite(selected_df$.__label_y), , drop = FALSE]
  repel_label_df <- selected_df[!(is.finite(selected_df$.__label_x) & is.finite(selected_df$.__label_y)), , drop = FALSE]
  if (nrow(manual_label_df) > 0) {
    p <- p +
      geom_segment(data = manual_label_df, aes(x = .__x, y = .__y, xend = .__label_x, yend = .__label_y), color = manual_label_df$.__label_line_color, linetype = manual_label_df$.__label_line_type, linewidth = manual_label_df$.__label_line_width) +
      geom_text(data = manual_label_df, aes(x = .__label_x, y = .__label_y, label = .__label), color = manual_label_df$.__label_color, size = label_size, family = font_family)
  }
  if (nrow(repel_label_df) > 0) {
    if (requireNamespace('ggrepel', quietly = TRUE)) {
      p <- p + ggrepel::geom_text_repel(
        data = repel_label_df,
        aes(label = .__label),
        color = repel_label_df$.__label_color,
        size = label_size,
        family = font_family,
        segment.color = repel_label_df$.__label_line_color,
        segment.size = repel_label_df$.__label_line_width,
        segment.linetype = repel_label_df$.__label_line_type,
        min.segment.length = 0,
        max.overlaps = label_max_overlaps,
        force = label_force
      )
    } else {
      p <- p + geom_text(data = repel_label_df, aes(label = .__label), color = repel_label_df$.__label_color, size = label_size, family = font_family, vjust = -0.6)
    }
  }
}

x_min <- get_param(params, 'x_min', NULL)
x_max <- get_param(params, 'x_max', NULL)
y_min <- get_param(params, 'y_min', NULL)
y_max <- get_param(params, 'y_max', NULL)
if (!is.null(x_min) || !is.null(x_max) || !is.null(y_min) || !is.null(y_max)) {
  p <- p + coord_cartesian(
    xlim = c(ifelse(is.null(x_min), NA, as.numeric(x_min)), ifelse(is.null(x_max), NA, as.numeric(x_max))),
    ylim = c(ifelse(is.null(y_min), NA, as.numeric(y_min)), ifelse(is.null(y_max), NA, as.numeric(y_max)))
  )
}

if (show_correlation && cor_label_position == 'panel') {
  cor_default_x <- if (!is.null(x_min) || !is.null(x_max)) {
    mean(c(ifelse(is.null(x_min), min(plot_df$.__x, na.rm = TRUE), as.numeric(x_min)), ifelse(is.null(x_max), max(plot_df$.__x, na.rm = TRUE), as.numeric(x_max))))
  } else {
    mean(range(plot_df$.__x, na.rm = TRUE))
  }
  y_span_for_label <- diff(range(plot_df$.__y, na.rm = TRUE))
  if (!is.null(y_min) || !is.null(y_max)) {
    y_span_for_label <- diff(c(ifelse(is.null(y_min), min(plot_df$.__y, na.rm = TRUE), as.numeric(y_min)), ifelse(is.null(y_max), max(plot_df$.__y, na.rm = TRUE), as.numeric(y_max))))
  }
  cor_default_y <- (if (!is.null(y_max)) as.numeric(y_max) else max(plot_df$.__y, na.rm = TRUE)) - 0.02 * y_span_for_label
  p <- p + annotate(
    'text',
    x = as.numeric(get_param(params, 'cor_label_x', cor_default_x)),
    y = as.numeric(get_param(params, 'cor_label_y', cor_default_y)),
    label = cor_label,
    hjust = as.numeric(get_param(params, 'cor_label_hjust', 0.5)),
    vjust = as.numeric(get_param(params, 'cor_label_vjust', 1)),
    size = as.numeric(get_param(params, 'cor_label_size', 4.3)),
    fontface = ifelse(as_bool(get_param(params, 'cor_label_bold', TRUE), TRUE), 'bold', 'plain'),
    family = font_family,
    color = as.character(get_param(params, 'cor_label_color', text_color))[1]
  )
}

plot_title <- if (title_show) title else NULL
plot_subtitle <- NULL
if (show_correlation && cor_label_position == 'title' && !title_show) plot_title <- cor_label
if (show_correlation && cor_label_position == 'title' && title_show) plot_subtitle <- cor_label
if (show_correlation && cor_label_position == 'subtitle') plot_subtitle <- cor_label

p <- p +
  labs(title = plot_title, subtitle = plot_subtitle, x = x_title, y = y_title) +
  theme_minimal(base_family = font_family) +
  theme(
    plot.title = element_text(hjust = 0.5, size = title_size, face = 'bold', color = text_color),
    plot.subtitle = element_text(hjust = 0.5, size = as.numeric(get_param(params, 'cor_label_size', 4.3)) * 3.2, face = ifelse(as_bool(get_param(params, 'cor_label_bold', TRUE), TRUE), 'bold', 'plain'), color = as.character(get_param(params, 'cor_label_color', text_color))[1]),
    axis.title = element_text(size = axis_title_size, face = ifelse(as_bool(get_param(params, 'axis_title_bold', TRUE), TRUE), 'bold', 'plain'), color = text_color),
    axis.text = element_text(size = axis_text_size, color = text_color),
    panel.grid.major = if (show_grid) element_line(color = grid_color, linewidth = as.numeric(get_param(params, 'grid_line_width', 0.35))) else element_blank(),
    panel.grid.minor = if (show_grid) element_line(color = as.character(get_param(params, 'minor_grid_color', '#F2F2F2'))[1], linewidth = 0.2) else element_blank(),
    panel.border = element_rect(fill = NA, color = panel_border_color, linewidth = panel_border_width),
    plot.background = element_rect(fill = '#FFFFFF', color = NA),
    panel.background = element_rect(fill = '#FFFFFF', color = NA),
    plot.margin = margin(5.5, 5.5, 5.5, 5.5),
    legend.position = if (show_legend) legend_position else 'none',
    legend.title = element_text(size = legend_title_size, face = 'bold', color = text_color),
    legend.text = element_text(size = legend_text_size, color = text_color),
    legend.key.size = grid::unit(as.numeric(get_param(params, 'legend_key_size', 0.45)), 'cm')
  ) +
  guides(color = guide_legend(title = legend_name, override.aes = list(size = legend_point_size, alpha = 1)))

width <- as.numeric(get_param(params, 'width', 6.5))
height <- as.numeric(get_param(params, 'height', 5.5))
# Generic appearance parameters not handled by this plugin (R/runtime/omicscanvas_theme.R).
if (!exists('omicscanvas_apply_theme')) { .oc_f <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[1]); .oc_rt <- file.path(dirname(normalizePath(.oc_f, mustWork = FALSE)), '..', '..', 'R', 'runtime', 'omicscanvas_theme.R'); if (!file.exists(.oc_rt)) .oc_rt <- file.path('R', 'runtime', 'omicscanvas_theme.R'); sys.source(.oc_rt, envir = globalenv()) }; p <- omicscanvas_apply_theme(p, params, only = c('legend_show', 'show_x_axis', 'show_y_axis'))
svg_file <- file.path(output_dir, 'result.svg')
pdf_file <- file.path(output_dir, 'result.pdf')
png_file <- file.path(output_dir, 'result.png')
figure_json_file <- file.path(output_dir, 'figure.json')
selected_rows_file <- file.path(output_dir, 'selected_rows.csv')

tryCatch({
  ggsave(svg_file, p, width = width, height = height, device = grDevices::svg, bg = '#FFFFFF')
  ggsave(pdf_file, p, width = width, height = height, device = grDevices::pdf, bg = '#FFFFFF')
  ggsave(png_file, p, width = width, height = height, dpi = 300, device = grDevices::png, bg = '#FFFFFF')
}, error = function(e) {
  write_error_and_exit('Failed to save plot outputs', conditionMessage(e), 'Check plotting code, output directory permissions, and graphics device support.')
})

selected_rows_export <- plot_df[plot_df$.__selected, setdiff(colnames(plot_df), grep('^\\.__', colnames(plot_df), value = TRUE)), drop = FALSE]
selected_rows_export$plot_x <- plot_df$.__x[plot_df$.__selected]
selected_rows_export$plot_y <- plot_df$.__y[plot_df$.__selected]
selected_rows_export$quadrant <- as.character(plot_df$.__group[plot_df$.__selected])
selected_rows_export$is_selected <- TRUE
utils::write.csv(selected_rows_export, selected_rows_file, row.names = FALSE)

point_colors <- unname(group_colors[as.character(plot_df$.__group)])
point_colors[is.na(point_colors)] <- '#BDBDBD'
plotly_hover <- paste0(
  plot_df$.__label,
  '<br>', x_title, ': ', signif(plot_df$.__x, 5),
  '<br>', y_title, ': ', signif(plot_df$.__y, 5),
  '<br>region: ', as.character(plot_df$.__group)
)
plotly_json <- list(
  data = list(
    list(
      type = 'scattergl',
      mode = 'markers',
      name = 'points',
      x = plot_df$.__x,
      y = plot_df$.__y,
      text = plot_df$.__label,
      customdata = plot_df$.__label,
      hovertext = plotly_hover,
      hoverinfo = 'text',
      marker = list(
        color = ifelse(plot_df$.__selected, selected_point_fill, point_colors),
        size = ifelse(plot_df$.__selected, selected_point_size * 3, point_size * 3),
        opacity = ifelse(plot_df$.__selected, 1, point_alpha),
        line = list(color = ifelse(plot_df$.__selected, selected_point_color, '#FFFFFF'), width = ifelse(plot_df$.__selected, selected_point_stroke * 2, 0.2))
      ),
      selected = list(marker = list(color = selected_point_fill, size = selected_point_size * 3)),
      unselected = list(marker = list(opacity = 0.35))
    )
  ),
  layout = list(
    title = if (title_show) title else '',
    xaxis = list(title = x_title, zeroline = FALSE),
    yaxis = list(title = y_title, zeroline = FALSE),
    dragmode = 'select',
    hovermode = 'closest',
    showlegend = FALSE,
    margin = list(l = 70, r = 30, t = if (title_show) 60 else 25, b = 65),
    paper_bgcolor = '#FFFFFF',
    plot_bgcolor = '#FFFFFF'
  ),
  selection = list(id_param = 'selected_ids', label_param = 'label_ids', label_column = label_col)
)

figure_json <- list(
  figure_type = get_param(params, 'plugin_id', 'quadrant_correlation_scatter'),
  title = title,
  layout = list(width = width, height = height),
  columns = list(label_column = label_col, x_column = x_col, y_column = y_col),
  analysis = list(correlation_method = cor_method, correlation = cor_value, p_value = p_value, quadrant_mode = quadrant_mode, x_thresholds = x_thresholds, y_thresholds = y_thresholds),
  style = list(
    point_size = point_size,
    point_shape = point_shape,
    point_alpha = point_alpha,
    selected_point_size = selected_point_size,
    selected_point_shape = selected_point_shape,
    selected_point_fill = selected_point_fill,
    label_show = label_show,
    label_size = label_size,
    threshold_line_color = threshold_line_color,
    legend_name = legend_name,
    legend_position = legend_position,
    group_colors = group_colors
  ),
  data = list(input_file = basename(input_file), n_rows = nrow(plot_df), n_selected = sum(plot_df$.__selected), selected_rows_file = 'selected_rows.csv'),
  layers = list(
    list(id = 'scatter_points', type = 'scatter', editable = TRUE),
    list(id = 'quadrant_regions', type = 'categorical_color', editable = TRUE),
    list(id = 'selected_points', type = 'scatter', editable = TRUE),
    list(id = 'labels', type = 'text', editable = TRUE, draggable = TRUE),
    list(id = 'label_indicators', type = 'segment', editable = TRUE),
    list(id = 'threshold_lines', type = 'line', editable = TRUE),
    list(id = 'correlation_label', type = 'text', editable = TRUE),
    list(id = 'legend', type = 'legend', editable = TRUE)
  ),
  plotly = plotly_json,
  export = list(svg = 'result.svg', pdf = 'result.pdf', png = 'result.png', selected_rows = 'selected_rows.csv')
)

writeLines(jsonlite::toJSON(figure_json, auto_unbox = TRUE, pretty = TRUE), figure_json_file)
write_log('Plugin completed successfully.')
quit(status = 0)
