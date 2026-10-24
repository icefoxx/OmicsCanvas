#!/usr/bin/env Rscript

# BioFigureAI Plot Plugin: Threshold Matrix Heatmap
# ------------------------------------------------------------
# Runtime contract:
#   Rscript plot.R --input input.csv --params params.json --output output_dir
#
# Purpose:
#   Draw a highly customizable matrix heatmap where users choose row/column
#   subsets, row label column, per-column cutoff rules, cell shape, labels,
#   legends, and exported selected rows for table-driven editing.

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
  error_obj <- list(
    error = error,
    detail = ifelse(is.null(detail), '', detail),
    suggestion = ifelse(is.null(suggestion), '', suggestion)
  )
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
      suggestion = 'Please check row_label_column/value_columns in params.json.'
    )
  }
}

normalize_shape <- function(shape) {
  shape <- tolower(trimws(as.character(shape)[1]))
  if (shape %in% c('circle', 'round', 'point', 'bubble')) return('circle')
  if (shape %in% c('square', 'tile', 'rect', 'rectangle', 'cell')) return('tile')
  if (shape %in% c('diamond')) return('diamond')
  if (shape %in% c('triangle', 'tri')) return('triangle')
  'tile'
}

split_rule_entries <- function(x) {
  if (is.null(x)) return(character())
  if (is.list(x) && !is.data.frame(x)) x <- unlist(x, use.names = FALSE)
  entries <- unlist(strsplit(as.character(x), ';', fixed = TRUE), use.names = FALSE)
  trimws(entries[nzchar(trimws(entries))])
}

parse_rule_string <- function(rule_string, default_label_prefix = NULL) {
  entries <- split_rule_entries(rule_string)
  if (length(entries) == 1 && grepl(',', entries, fixed = TRUE)) {
    entries <- trimws(unlist(strsplit(entries, ',', fixed = TRUE), use.names = FALSE))
  }
  rows <- list()
  idx <- 1
  for (entry in entries) {
    entry <- trimws(entry)
    if (!nzchar(entry)) next
    lower <- tolower(entry)
    if (grepl('^(else|default)\\s*=', lower)) {
      rhs <- trimws(sub('^(else|default)\\s*=\\s*', '', entry, ignore.case = TRUE))
      parts <- trimws(unlist(strsplit(rhs, '\\|', perl = TRUE), use.names = FALSE))
      rows[[idx]] <- data.frame(
        operator = 'else',
        cutoff = NA_real_,
        color = parts[1],
        label = ifelse(length(parts) >= 2 && nzchar(parts[2]), parts[2], 'non-sig'),
        stringsAsFactors = FALSE
      )
      idx <- idx + 1
      next
    }
    if (grepl('^(missing|na)\\s*=', lower)) {
      rhs <- trimws(sub('^(missing|na)\\s*=\\s*', '', entry, ignore.case = TRUE))
      parts <- trimws(unlist(strsplit(rhs, '\\|', perl = TRUE), use.names = FALSE))
      rows[[idx]] <- data.frame(
        operator = 'missing',
        cutoff = NA_real_,
        color = parts[1],
        label = ifelse(length(parts) >= 2 && nzchar(parts[2]), parts[2], 'none'),
        stringsAsFactors = FALSE
      )
      idx <- idx + 1
      next
    }
    m <- regexec('^(<=|>=|<|>|==|!=)\\s*(-?[0-9.]+(?:[eE][-+]?[0-9]+)?)\\s*=\\s*([^|]+)(?:\\|(.+))?$', entry, perl = TRUE)
    hit <- regmatches(entry, m)[[1]]
    if (length(hit) == 0) next
    op <- hit[2]
    cutoff <- suppressWarnings(as.numeric(hit[3]))
    color <- trimws(hit[4])
    label <- if (length(hit) >= 5 && nzchar(trimws(hit[5]))) trimws(hit[5]) else paste0(op, cutoff)
    if (!is.null(default_label_prefix) && nzchar(default_label_prefix)) label <- paste(default_label_prefix, label)
    rows[[idx]] <- data.frame(operator = op, cutoff = cutoff, color = color, label = label, stringsAsFactors = FALSE)
    idx <- idx + 1
  }
  if (length(rows) == 0) {
    return(data.frame(
      operator = c('<', 'else', 'missing'),
      cutoff = c(0.05, NA, NA),
      color = c('#C6FF1A', '#C9C9C9', '#FFFFFF'),
      label = c('sig', 'non-sig', 'none'),
      stringsAsFactors = FALSE
    ))
  }
  out <- do.call(rbind, rows)
  if (!any(out$operator == 'else')) {
    out <- rbind(out, data.frame(operator = 'else', cutoff = NA_real_, color = '#C9C9C9', label = 'non-sig', stringsAsFactors = FALSE))
  }
  if (!any(out$operator == 'missing')) {
    out <- rbind(out, data.frame(operator = 'missing', cutoff = NA_real_, color = '#FFFFFF', label = 'none', stringsAsFactors = FALSE))
  }
  out
}

parse_column_rule_string <- function(x) {
  entries <- split_rule_entries(x)
  out <- list()
  current_col <- NULL
  current_rules <- character()
  flush_current <- function() {
    if (!is.null(current_col) && length(current_rules) > 0) {
      out[[current_col]] <<- parse_rule_string(paste(current_rules, collapse = ';'))
    }
  }
  for (entry in entries) {
    if (grepl(':', entry, fixed = TRUE) && !grepl('^(<=|>=|<|>|==|!=)', trimws(entry))) {
      flush_current()
      parts <- strsplit(entry, ':', fixed = TRUE)[[1]]
      current_col <- trimws(parts[1])
      current_rules <- trimws(paste(parts[-1], collapse = ':'))
    } else {
      current_rules <- c(current_rules, entry)
    }
  }
  flush_current()
  out
}

rules_for_columns <- function(params, columns) {
  default_rules <- parse_rule_string(get_param(params, 'default_rules', get_param(params, 'cutoff_rules', '<0.01=#F97316|strong sig;<0.05=#C6FF1A|sig;else=#C9C9C9|non-sig;missing=#FFFFFF|none')))
  by_col <- stats::setNames(rep(list(default_rules), length(columns)), columns)

  string_rules <- parse_column_rule_string(get_param(params, 'column_rules_string', get_param(params, 'rules_by_column_string', NULL)))
  for (nm in intersect(names(string_rules), columns)) by_col[[nm]] <- string_rules[[nm]]

  object_rules <- get_param(params, 'column_rules', get_param(params, 'rules_by_column', NULL))
  if (!is.null(object_rules)) {
    if (is.data.frame(object_rules)) object_rules <- as.list(object_rules)
    for (nm in intersect(names(object_rules), columns)) {
      value <- object_rules[[nm]]
      if (is.character(value)) by_col[[nm]] <- parse_rule_string(value)
      if (is.list(value) && !is.data.frame(value)) {
        rows <- lapply(value, function(rule) {
          data.frame(
            operator = as.character(get_param(rule, 'operator', get_param(rule, 'op', '<')))[1],
            cutoff = suppressWarnings(as.numeric(get_param(rule, 'cutoff', NA_real_))),
            color = as.character(get_param(rule, 'color', '#C9C9C9'))[1],
            label = as.character(get_param(rule, 'label', 'value'))[1],
            stringsAsFactors = FALSE
          )
        })
        if (length(rows) > 0) by_col[[nm]] <- do.call(rbind, rows)
      }
    }
  }
  by_col
}

rule_match <- function(value, op, cutoff) {
  if (op == 'missing') return(is.na(value))
  if (op == 'else') return(TRUE)
  if (is.na(value) || is.na(cutoff)) return(FALSE)
  switch(op,
         '<' = value < cutoff,
         '<=' = value <= cutoff,
         '>' = value > cutoff,
         '>=' = value >= cutoff,
         '==' = value == cutoff,
         '!=' = value != cutoff,
         FALSE)
}

classify_value <- function(value, rules) {
  if (is.na(value)) {
    idx <- which(rules$operator == 'missing')[1]
    if (!is.na(idx)) return(rules[idx, , drop = FALSE])
  }
  for (i in seq_len(nrow(rules))) {
    if (rules$operator[i] == 'missing') next
    if (rule_match(value, rules$operator[i], rules$cutoff[i])) return(rules[i, , drop = FALSE])
  }
  rules[nrow(rules), , drop = FALSE]
}

named_values <- function(x, names_needed, default_value) {
  out <- stats::setNames(rep(default_value, length(names_needed)), names_needed)
  if (is.null(x)) return(out)
  values <- unlist(x, use.names = TRUE)
  if (!is.null(names(values))) {
    hits <- intersect(names(values), names_needed)
    out[hits] <- values[hits]
  }
  out
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

row_label_column <- get_param_any(params, c('row_label_column', 'label_column', 'term_column', 'id_column'), NULL)
if (is.null(row_label_column)) row_label_column <- colnames(df)[1]
validate_columns(df, row_label_column)

value_columns <- as_string_vector(get_param_any(params, c('value_columns', 'columns_include', 'selected_columns'), NULL))
if (length(value_columns) == 0) {
  value_columns <- setdiff(colnames(df)[vapply(df, function(x) is.numeric(x) || all(is.na(suppressWarnings(as.numeric(x))) == is.na(x)), logical(1))], row_label_column)
}
value_columns <- intersect(value_columns, colnames(df))
value_columns <- setdiff(value_columns, as_string_vector(get_param_any(params, c('columns_exclude', 'value_columns_exclude'), NULL)))
if (length(value_columns) == 0) write_error_and_exit('No value columns selected', 'No numeric/value columns remained after include/exclude filtering.', 'Set value_columns in params.json.')
validate_columns(df, c(row_label_column, value_columns))

row_labels <- as.character(df[[row_label_column]])
row_labels[is.na(row_labels) | !nzchar(row_labels)] <- paste0('row_', which(is.na(row_labels) | !nzchar(row_labels)))
row_labels <- make.unique(row_labels)
df$.__row_label <- row_labels

rows_include <- as_string_vector(get_param_any(params, c('rows_include', 'selected_rows', 'row_labels_include'), NULL))
rows_exclude <- as_string_vector(get_param_any(params, c('rows_exclude', 'hidden_rows', 'row_labels_exclude'), NULL))
row_keep <- rep(TRUE, nrow(df))
if (length(rows_include) > 0) row_keep <- df$.__row_label %in% rows_include | as.character(df[[row_label_column]]) %in% rows_include
if (length(rows_exclude) > 0) row_keep <- row_keep & !(df$.__row_label %in% rows_exclude | as.character(df[[row_label_column]]) %in% rows_exclude)
df <- df[row_keep, , drop = FALSE]
if (nrow(df) == 0) write_error_and_exit('No rows selected', 'Row include/exclude settings removed all rows.', 'Select at least one row.')

row_order <- as_string_vector(get_param(params, 'row_order', NULL))
if (length(row_order) == 0) row_order <- df$.__row_label
row_order <- c(intersect(row_order, df$.__row_label), setdiff(df$.__row_label, row_order))
column_order <- as_string_vector(get_param(params, 'column_order', NULL))
if (length(column_order) == 0) column_order <- value_columns
column_order <- c(intersect(column_order, value_columns), setdiff(value_columns, column_order))

rules <- rules_for_columns(params, value_columns)

plot_rows <- list()
idx <- 1
for (r in seq_len(nrow(df))) {
  for (col in value_columns) {
    value <- suppressWarnings(as.numeric(df[[col]][r]))
    rule <- classify_value(value, rules[[col]])
    plot_rows[[idx]] <- data.frame(
      row_label = df$.__row_label[r],
      column_name = col,
      value = value,
      category = as.character(rule$label[1]),
      fill_color = as.character(rule$color[1]),
      stringsAsFactors = FALSE
    )
    idx <- idx + 1
  }
}
plot_df <- do.call(rbind, plot_rows)
plot_df$row_label <- factor(plot_df$row_label, levels = rev(row_order))
plot_df$column_name <- factor(plot_df$column_name, levels = column_order)

shape <- normalize_shape(get_param(params, 'cell_shape', get_param(params, 'plot_shape', 'tile')))
title <- as.character(get_param(params, 'title', 'Threshold matrix heatmap'))[1]
title_show <- as_bool(get_param(params, 'title_show', TRUE), TRUE)
x_title <- as.character(get_param(params, 'x_title', ''))[1]
y_title <- as.character(get_param(params, 'y_title', ''))[1]
show_axis_titles <- as_bool(get_param(params, 'axis_title_show', get_param(params, 'show_axis_titles', FALSE)), FALSE)
show_x_axis <- as_bool(get_param(params, 'show_x_axis', TRUE), TRUE)
show_y_axis <- as_bool(get_param(params, 'show_y_axis', TRUE), TRUE)
row_label_position <- tolower(as.character(get_param(params, 'row_label_position', get_param(params, 'y_axis_position', 'right')))[1])
if (!row_label_position %in% c('left', 'right')) row_label_position <- 'right'
column_label_position <- tolower(as.character(get_param(params, 'column_label_position', get_param(params, 'x_axis_position', 'bottom')))[1])
if (!column_label_position %in% c('top', 'bottom')) column_label_position <- 'bottom'
font_family <- as.character(get_param(params, 'font_family', ''))[1]
text_color <- as.character(get_param(params, 'text_color', '#000000'))[1]
title_size <- as.numeric(get_param(params, 'title_size', 16))
axis_title_size <- as.numeric(get_param(params, 'axis_title_size', 12))
row_name_size <- as.numeric(get_param(params, 'row_name_size', get_param(params, 'axis_text_size', 10)))
column_name_size <- as.numeric(get_param(params, 'column_name_size', get_param(params, 'axis_text_size', 10)))
row_name_angle <- as.numeric(get_param(params, 'row_name_angle', 0))
column_name_angle <- as.numeric(get_param(params, 'column_name_angle', get_param(params, 'label_angle', 90)))
row_name_italic <- as_bool(get_param(params, 'row_name_italic', FALSE), FALSE)
column_name_italic <- as_bool(get_param(params, 'column_name_italic', FALSE), FALSE)
highlight_rows <- as_string_vector(get_param(params, 'highlight_rows', NULL))
highlight_columns <- as_string_vector(get_param(params, 'highlight_columns', NULL))
highlight_color <- as.character(get_param(params, 'highlight_color', '#D73027'))[1]
row_label_colors <- named_values(get_param(params, 'row_label_colors', NULL), row_order, text_color)
column_label_colors <- named_values(get_param(params, 'column_label_colors', NULL), column_order, text_color)
row_label_colors[intersect(highlight_rows, names(row_label_colors))] <- highlight_color
column_label_colors[intersect(highlight_columns, names(column_label_colors))] <- highlight_color
axis_row_color <- if (length(unique(row_label_colors[row_order])) == 1) unique(row_label_colors[row_order]) else row_label_colors[row_order]
axis_column_color <- if (length(unique(column_label_colors[column_order])) == 1) unique(column_label_colors[column_order]) else column_label_colors[column_order]

cell_width <- as.numeric(get_param(params, 'cell_width', 0.95))
cell_height <- as.numeric(get_param(params, 'cell_height', 0.95))
cell_size <- as.numeric(get_param(params, 'cell_size', 7))
cell_alpha <- as.numeric(get_param(params, 'cell_alpha', 1))
cell_border_color <- as.character(get_param(params, 'cell_border_color', get_param(params, 'border_color', '#FFFFFF')))[1]
cell_border_width <- as.numeric(get_param(params, 'cell_border_width', get_param(params, 'border_width', 0.35)))
show_cell_border <- as_bool(get_param(params, 'show_cell_border', get_param(params, 'show_grid_border', TRUE)), TRUE)
show_value <- as_bool(get_param(params, 'show_value', get_param(params, 'show_cell_value', FALSE)), FALSE)
value_digits <- as.integer(get_param(params, 'value_digits', 3))
value_text_size <- as.numeric(get_param(params, 'value_text_size', get_param(params, 'cell_text_size', 3)))
value_text_color <- as.character(get_param(params, 'value_text_color', '#111111'))[1]

legend_name <- as.character(get_param(params, 'legend_name', get_param(params, 'legend_title', '')))[1]
show_legend <- as_bool(get_param(params, 'show_legend', TRUE), TRUE)
legend_position <- as.character(get_param(params, 'legend_position', 'right'))[1]
legend_title_size <- as.numeric(get_param(params, 'legend_title_size', get_param(params, 'legend_size', 11)))
legend_text_size <- as.numeric(get_param(params, 'legend_text_size', get_param(params, 'legend_size', 10)))
legend_key_size <- as.numeric(get_param(params, 'legend_key_size', 0.45))
legend_ncol <- get_param(params, 'legend_ncol', NULL)
legend_nrow <- get_param(params, 'legend_nrow', NULL)
legend_reverse <- as_bool(get_param(params, 'legend_reverse', FALSE), FALSE)
legend_order <- as.integer(get_param(params, 'legend_order', 1))
legend_title_position <- as.character(get_param(params, 'legend_title_position', 'top'))[1]

width <- as.numeric(get_param(params, 'width', max(5, length(value_columns) * 0.45 + 4)))
height <- as.numeric(get_param(params, 'height', max(5, nrow(df) * 0.28 + 1.5)))

all_categories <- unique(plot_df$category)
legend_order_values <- as_string_vector(get_param(params, 'legend_levels', NULL))
all_categories <- c(intersect(legend_order_values, all_categories), setdiff(all_categories, legend_order_values))
plot_df$category <- factor(plot_df$category, levels = all_categories)
fill_values <- tapply(plot_df$fill_color, plot_df$category, function(x) x[which(!is.na(x) & nzchar(x))[1]])
fill_values <- fill_values[levels(plot_df$category)]

p <- ggplot(plot_df, aes(x = column_name, y = row_label))
if (shape == 'circle') {
  p <- p + geom_point(
    aes(fill = category),
    shape = 21,
    color = if (show_cell_border) cell_border_color else NA,
    stroke = cell_border_width,
    size = cell_size,
    alpha = cell_alpha
  )
} else if (shape == 'diamond') {
  p <- p + geom_point(
    aes(fill = category),
    shape = 23,
    color = if (show_cell_border) cell_border_color else NA,
    stroke = cell_border_width,
    size = cell_size,
    alpha = cell_alpha
  )
} else if (shape == 'triangle') {
  p <- p + geom_point(
    aes(fill = category),
    shape = 24,
    color = if (show_cell_border) cell_border_color else NA,
    stroke = cell_border_width,
    size = cell_size,
    alpha = cell_alpha
  )
} else {
  p <- p + geom_tile(
    aes(fill = category),
    color = if (show_cell_border) cell_border_color else NA,
    linewidth = cell_border_width,
    width = cell_width,
    height = cell_height,
    alpha = cell_alpha
  )
}

if (show_value) {
  plot_df$label <- ifelse(is.na(plot_df$value), '', formatC(plot_df$value, format = 'fg', digits = value_digits))
  p <- p + geom_text(data = plot_df, aes(label = label), color = value_text_color, size = value_text_size, family = font_family)
}

p <- p +
  scale_fill_manual(name = legend_name, values = fill_values, drop = FALSE) +
  scale_x_discrete(limits = column_order, position = column_label_position) +
  scale_y_discrete(limits = rev(row_order), position = row_label_position) +
  labs(
    title = if (title_show) title else NULL,
    x = if (show_axis_titles && show_x_axis) x_title else NULL,
    y = if (show_axis_titles && show_y_axis) y_title else NULL
  ) +
  coord_fixed(ratio = as.numeric(get_param(params, 'aspect_ratio', 1))) +
  theme_minimal(base_family = font_family) +
  theme(
    plot.title = element_text(hjust = 0.5, size = title_size, color = text_color, face = ifelse(as_bool(get_param(params, 'title_bold', TRUE), TRUE), 'bold', 'plain')),
    axis.title.x = if (show_axis_titles && show_x_axis) element_text(size = axis_title_size, color = text_color) else element_blank(),
    axis.title.y = if (show_axis_titles && show_y_axis) element_text(size = axis_title_size, color = text_color) else element_blank(),
    axis.text.x = if (show_x_axis) element_text(size = column_name_size, angle = column_name_angle, hjust = ifelse(column_name_angle == 0, 0.5, 1), vjust = ifelse(column_name_angle == 0, 0.5, 0.5), face = ifelse(column_name_italic, 'italic', 'plain'), color = axis_column_color) else element_blank(),
    axis.text.y = if (show_y_axis) element_text(size = row_name_size, angle = row_name_angle, face = ifelse(row_name_italic, 'italic', 'plain'), color = rev(axis_row_color)) else element_blank(),
    axis.ticks = if (as_bool(get_param(params, 'axis_tick_show', FALSE), FALSE)) element_line(color = as.character(get_param(params, 'axis_tick_color', '#333333'))[1]) else element_blank(),
    axis.line = if (as_bool(get_param(params, 'axis_line_show', FALSE), FALSE)) element_line(color = as.character(get_param(params, 'axis_line_color', '#333333'))[1]) else element_blank(),
    panel.grid = element_blank(),
    panel.background = element_rect(fill = as.character(get_param(params, 'panel_background', '#FFFFFF'))[1], color = NA),
    plot.background = element_rect(fill = as.character(get_param(params, 'plot_background', '#FFFFFF'))[1], color = NA),
    legend.position = if (show_legend) legend_position else 'none',
    legend.title = element_text(size = legend_title_size, color = text_color, face = 'bold'),
    legend.text = element_text(size = legend_text_size, color = text_color),
    legend.key.size = grid::unit(legend_key_size, 'cm')
  )

if (show_legend) {
  p <- p + guides(fill = guide_legend(
    title = legend_name,
    order = legend_order,
    ncol = if (is.null(legend_ncol)) NULL else as.integer(legend_ncol),
    nrow = if (is.null(legend_nrow)) NULL else as.integer(legend_nrow),
    reverse = legend_reverse,
    title.position = legend_title_position,
    override.aes = list(size = as.numeric(get_param(params, 'legend_point_size', 4)), alpha = 1)
  ))
}

# Generic appearance parameters not handled by this plugin (R/runtime/omicscanvas_theme.R).
if (!exists('omicscanvas_apply_theme')) { .oc_f <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[1]); .oc_rt <- file.path(dirname(normalizePath(.oc_f, mustWork = FALSE)), '..', '..', 'R', 'runtime', 'omicscanvas_theme.R'); if (!file.exists(.oc_rt)) .oc_rt <- file.path('R', 'runtime', 'omicscanvas_theme.R'); sys.source(.oc_rt, envir = globalenv()) }; p <- omicscanvas_apply_theme(p, params, only = c('legend_show'))
svg_file <- file.path(output_dir, 'result.svg')
pdf_file <- file.path(output_dir, 'result.pdf')
png_file <- file.path(output_dir, 'result.png')
figure_json_file <- file.path(output_dir, 'figure.json')
selected_rows_file <- file.path(output_dir, 'selected_rows.csv')

tryCatch({
  ggsave(svg_file, p, width = width, height = height, device = grDevices::svg)
  ggsave(pdf_file, p, width = width, height = height, device = grDevices::pdf)
  ggsave(png_file, p, width = width, height = height, dpi = 300, device = grDevices::png)
}, error = function(e) {
  write_error_and_exit('Failed to save plot outputs', conditionMessage(e), 'Check plotting code, output directory permissions, and graphics device support.')
})

selected_rows_export <- df[, setdiff(colnames(df), '.__row_label'), drop = FALSE]
selected_rows_export$plot_row_label <- df$.__row_label
selected_rows_export$is_selected <- TRUE
utils::write.csv(selected_rows_export, selected_rows_file, row.names = FALSE)

figure_json <- list(
  figure_type = get_param(params, 'plugin_id', 'threshold_matrix_heatmap'),
  title = title,
  layout = list(width = width, height = height),
  columns = list(row_label_column = row_label_column, value_columns = value_columns),
  style = list(
    cell_shape = shape,
    title_show = title_show,
    title_size = title_size,
    show_x_axis = show_x_axis,
    show_y_axis = show_y_axis,
    row_label_position = row_label_position,
    column_label_position = column_label_position,
    row_name_size = row_name_size,
    column_name_size = column_name_size,
    row_name_angle = row_name_angle,
    column_name_angle = column_name_angle,
    legend_name = legend_name,
    legend_position = legend_position,
    legend_title_size = legend_title_size,
    legend_text_size = legend_text_size,
    legend_key_size = legend_key_size,
    cell_width = cell_width,
    cell_height = cell_height,
    cell_size = cell_size,
    show_cell_border = show_cell_border,
    cell_border_color = cell_border_color,
    cell_border_width = cell_border_width,
    show_value = show_value
  ),
  data = list(
    input_file = basename(input_file),
    n_rows = nrow(df),
    n_columns = length(value_columns),
    selected_rows_file = 'selected_rows.csv',
    categories = all_categories
  ),
  rules = lapply(rules, function(x) {
    lapply(seq_len(nrow(x)), function(i) as.list(x[i, , drop = FALSE]))
  }),
  layers = list(
    list(id = 'matrix_cells', type = shape, editable = TRUE),
    list(id = 'row_selection', type = 'selection_table', editable = TRUE, table = 'selected_rows.csv'),
    list(id = 'row_labels', type = 'axis_text', editable = TRUE),
    list(id = 'column_labels', type = 'axis_text', editable = TRUE),
    list(id = 'legend', type = 'legend', editable = TRUE)
  ),
  export = list(svg = 'result.svg', pdf = 'result.pdf', png = 'result.png', selected_rows = 'selected_rows.csv')
)

writeLines(jsonlite::toJSON(figure_json, auto_unbox = TRUE, pretty = TRUE), figure_json_file)
write_log('Plugin completed successfully.')
quit(status = 0)
