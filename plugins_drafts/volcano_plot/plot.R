#!/usr/bin/env Rscript

# BioFigureAI Plot Plugin: Highly Customized Volcano Plot
# ------------------------------------------------------------
# Runtime contract:
#   Rscript plot.R --input input.csv --params params.json --output output_dir
#
# Supported input:
#   CSV/TSV/TXT differential result table. Common column names are autodetected,
#   but all mappings can be supplied through params.json.

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
  write_error_and_exit('Unsupported input file type', paste('File extension:', ext), 'For MVP, use csv, tsv, or txt input files.')
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
      suggestion = 'Please check column mapping in params.json.'
    )
  }
}

first_existing_col <- function(df, candidates, required = TRUE, label = 'column') {
  hit <- candidates[candidates %in% colnames(df)][1]
  if (!is.na(hit)) return(hit)
  if (required) {
    write_error_and_exit(
      error = paste('Could not detect', label),
      detail = paste('Tried:', paste(candidates, collapse = ', ')),
      suggestion = paste('Provide', label, 'in params.json.')
    )
  }
  NULL
}

palette_colors <- function(params) {
  scheme <- tolower(as.character(get_param(params, 'palette_scheme', get_param(params, 'color_scheme', 'category')))[1])
  schemes <- list(
    category = c(down = '#E6A23C', nodiff = '#58C7E6', up = '#F35A5A'),
    classic = c(down = '#66A61E', nodiff = '#BDBDBD', up = '#F8766D'),
    blue_grey_red = c(down = '#2C7BB6', nodiff = '#D9D9D9', up = '#D7191C'),
    green_grey_red = c(down = '#66A61E', nodiff = '#D9D9D9', up = '#E41A1C')
  )
  colors <- schemes[[ifelse(scheme %in% names(schemes), scheme, 'category')]]
  colors['up'] <- as.character(get_param(params, 'up_color', colors[['up']]))[1]
  colors['down'] <- as.character(get_param(params, 'down_color', colors[['down']]))[1]
  colors['nodiff'] <- as.character(get_param(params, 'nodiff_color', get_param(params, 'no_diff_color', colors[['nodiff']]))) [1]
  colors
}

gradient_palette <- function(params) {
  scheme <- tolower(as.character(get_param(params, 'gradient_scheme', get_param(params, 'gradient_palette', 'orange_red')))[1])
  schemes <- list(
    orange_red = c('#FEF0D9', '#FDCB8A', '#FC8D59', '#E34A33', '#B30000'),
    blue_red = c('#2166AC', '#67A9CF', '#F7F7F7', '#EF8A62', '#B2182B'),
    blue_yellow = c('#2C7BB6', '#ABD9E9', '#FFFFBF', '#FDAE61', '#D7191C'),
    teal_pink = c('#1F9EAA', '#A8DADC', '#F7F7F7', '#F4A3B4', '#D01C8B')
  )
  custom <- as_string_vector(get_param(params, 'gradient_colors', NULL))
  if (length(custom) >= 2) return(custom)
  schemes[[ifelse(scheme %in% names(schemes), scheme, 'orange_red')]]
}

named_color_vector <- function(x, levels_needed, default_color) {
  out <- stats::setNames(rep(default_color, length(levels_needed)), levels_needed)
  if (is.null(x)) return(out)
  values <- as.character(unlist(x, use.names = TRUE))
  if (length(values) == 0) return(out)
  if (!is.null(names(values)) && any(nzchar(names(values)))) {
    hits <- intersect(names(values), levels_needed)
    out[hits] <- values[hits]
  }
  out
}

transform_plot_value <- function(x, transform = 'none') {
  transform <- tolower(trimws(as.character(transform)[1]))
  x <- suppressWarnings(as.numeric(x))
  if (transform %in% c('neglog10', '-log10', 'minus_log10')) {
    return(-log10(pmax(x, .Machine$double.xmin)))
  }
  if (transform %in% c('log10')) {
    return(log10(pmax(x, .Machine$double.xmin)))
  }
  if (transform %in% c('log2')) {
    return(log2(pmax(x, .Machine$double.xmin)))
  }
  x
}

as_region_list <- function(x) {
  if (is.null(x)) return(list())
  if (is.data.frame(x)) {
    return(lapply(seq_len(nrow(x)), function(i) as.list(x[i, , drop = FALSE])))
  }
  if (is.list(x) && length(x) > 0 && all(vapply(x, is.list, logical(1)))) return(x)
  list()
}

region_value <- function(region, name, default = NULL) {
  if (!is.null(region[[name]]) && length(region[[name]]) > 0 && !is.na(region[[name]][1])) {
    return(region[[name]][1])
  }
  default
}

apply_region_styles <- function(plot_df, params) {
  regions <- as_region_list(get_param(params, 'regions', get_param(params, 'region_rules', NULL)))
  plot_df$.__region <- ''
  plot_df$.__region_label <- ''
  plot_df$.__region_fill <- NA_character_
  plot_df$.__region_outline <- NA_character_
  plot_df$.__region_size <- NA_real_
  plot_df$.__region_shape <- NA_integer_
  plot_df$.__region_alpha <- NA_real_
  plot_df$.__region_stroke <- NA_real_

  if (length(regions) == 0) {
    return(list(data = plot_df, region_styles = data.frame(stringsAsFactors = FALSE)))
  }

  style_rows <- list()
  eval_env <- as.list(plot_df)
  eval_env$x <- plot_df$.__x
  eval_env$y <- plot_df$.__y

  for (idx in seq_along(regions)) {
    region <- regions[[idx]]
    region_id <- as.character(region_value(region, 'id', paste0('region_', idx)))
    region_label <- as.character(region_value(region, 'label', region_id))

    condition <- region_value(region, 'condition', NULL)
    if (!is.null(condition) && nzchar(as.character(condition))) {
      hit <- tryCatch(
        eval(parse(text = as.character(condition)), envir = eval_env),
        error = function(e) {
          write_log(sprintf('Region condition failed for %s: %s', region_id, conditionMessage(e)))
          rep(FALSE, nrow(plot_df))
        }
      )
      hit <- as.logical(hit)
      if (length(hit) != nrow(plot_df)) hit <- rep(FALSE, nrow(plot_df))
      hit[is.na(hit)] <- FALSE
    } else {
      xmin <- suppressWarnings(as.numeric(region_value(region, 'xmin', -Inf)))
      xmax <- suppressWarnings(as.numeric(region_value(region, 'xmax', Inf)))
      ymin <- suppressWarnings(as.numeric(region_value(region, 'ymin', -Inf)))
      ymax <- suppressWarnings(as.numeric(region_value(region, 'ymax', Inf)))
      hit <- plot_df$.__x >= xmin & plot_df$.__x <= xmax & plot_df$.__y >= ymin & plot_df$.__y <= ymax
      hit[is.na(hit)] <- FALSE
    }

    fill <- as.character(region_value(region, 'fill', region_value(region, 'color', '#8E24AA')))
    outline <- as.character(region_value(region, 'outline_color', region_value(region, 'border_color', '#212121')))
    size <- suppressWarnings(as.numeric(region_value(region, 'size', region_value(region, 'dot_size', 3))))
    shape <- suppressWarnings(as.integer(region_value(region, 'shape', region_value(region, 'dot_shape', 21))))
    alpha <- suppressWarnings(as.numeric(region_value(region, 'alpha', 1)))
    stroke <- suppressWarnings(as.numeric(region_value(region, 'stroke', region_value(region, 'outline_width', 0.5))))
    if (is.na(size) || size <= 0) size <- 3
    if (is.na(shape)) shape <- 21
    if (is.na(alpha)) alpha <- 1
    if (is.na(stroke) || stroke < 0) stroke <- 0.5

    plot_df$.__region[hit] <- region_id
    plot_df$.__region_label[hit] <- region_label
    plot_df$.__region_fill[hit] <- fill
    plot_df$.__region_outline[hit] <- outline
    plot_df$.__region_size[hit] <- size
    plot_df$.__region_shape[hit] <- shape
    plot_df$.__region_alpha[hit] <- alpha
    plot_df$.__region_stroke[hit] <- stroke

    style_rows[[idx]] <- data.frame(
      id = region_id,
      label = region_label,
      fill = fill,
      outline = outline,
      size = size,
      shape = shape,
      alpha = alpha,
      stroke = stroke,
      stringsAsFactors = FALSE
    )
  }

  region_styles <- do.call(rbind, style_rows)
  region_styles <- region_styles[!duplicated(region_styles$label, fromLast = TRUE), , drop = FALSE]
  list(data = plot_df, region_styles = region_styles)
}

match_region_condition <- function(plot_df, region) {
  condition <- region_value(region, 'condition', NULL)
  if (!is.null(condition) && nzchar(as.character(condition))) {
    eval_env <- as.list(plot_df)
    eval_env$x <- plot_df$.__x
    eval_env$y <- plot_df$.__y
    hit <- tryCatch(
      eval(parse(text = as.character(condition)), envir = eval_env),
      error = function(e) rep(FALSE, nrow(plot_df))
    )
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

apply_selection_regions <- function(plot_df, params) {
  regions <- as_region_list(get_param(params, 'selection_regions', get_param(params, 'brush_regions', get_param(params, 'lasso_regions', NULL))))
  plot_df$.__brush_region <- ''
  if (length(regions) == 0) return(plot_df)
  for (idx in seq_along(regions)) {
    region <- regions[[idx]]
    region_id <- as.character(region_value(region, 'id', paste0('selection_', idx)))
    hit <- match_region_condition(plot_df, region)
    plot_df$.__brush_region[hit] <- region_id
  }
  plot_df
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

apply_selected_point_styles <- function(plot_df, params, selected_point_color, selected_point_size, selected_point_alpha, selected_point_stroke, label_color, label_line_color, label_line_width) {
  plot_df$.__selected_fill <- selected_point_color
  plot_df$.__selected_outline <- as.character(get_param(params, 'selected_point_border_color', '#212121'))[1]
  plot_df$.__selected_size <- selected_point_size
  plot_df$.__selected_shape <- as.integer(get_param(params, 'selected_point_shape', 21))
  plot_df$.__selected_alpha <- selected_point_alpha
  plot_df$.__selected_stroke <- selected_point_stroke
  plot_df$.__label_enabled <- plot_df$.__selected
  plot_df$.__label_x <- NA_real_
  plot_df$.__label_y <- NA_real_
  plot_df$.__label_color <- label_color
  plot_df$.__label_bg <- NA_character_
  plot_df$.__label_line_color <- label_line_color
  plot_df$.__label_line_type <- as.character(get_param(params, 'label_line_type', 'solid'))[1]
  plot_df$.__label_line_width <- label_line_width

  records <- style_records(get_param(params, 'selected_point_styles', get_param(params, 'highlight_point_styles', NULL)))
  if (length(records) == 0) return(plot_df)
  has_specific_ids <- vapply(records, function(record) length(record_ids(record)) > 0, logical(1))
  records <- c(records[!has_specific_ids], records[has_specific_ids])

  for (record in records) {
    ids <- record_ids(record)
    hit <- rep(FALSE, nrow(plot_df))
    if (length(ids) > 0) hit <- hit | plot_df$.__gene %in% ids
    region_id <- region_value(record, 'region_id', NULL)
    if (!is.null(region_id)) hit <- hit | plot_df$.__brush_region == as.character(region_id)
    condition <- region_value(record, 'condition', NULL)
    if (!is.null(condition) && nzchar(as.character(condition))) hit <- hit | match_region_condition(plot_df, record)
    hit[is.na(hit)] <- FALSE
    if (!any(hit)) next

    plot_df$.__selected[hit] <- as_bool(region_value(record, 'selected', TRUE), TRUE)
    plot_df$.__label_enabled[hit] <- as_bool(region_value(record, 'label_show', region_value(record, 'show_label', TRUE)), TRUE)
    plot_df$.__selected_fill[hit] <- as.character(region_value(record, 'fill', region_value(record, 'color', plot_df$.__selected_fill[hit][1])))
    plot_df$.__selected_outline[hit] <- as.character(region_value(record, 'outline_color', region_value(record, 'border_color', plot_df$.__selected_outline[hit][1])))
    plot_df$.__selected_size[hit] <- suppressWarnings(as.numeric(region_value(record, 'size', region_value(record, 'dot_size', plot_df$.__selected_size[hit][1]))))
    plot_df$.__selected_shape[hit] <- suppressWarnings(as.integer(region_value(record, 'shape', region_value(record, 'dot_shape', plot_df$.__selected_shape[hit][1]))))
    plot_df$.__selected_alpha[hit] <- suppressWarnings(as.numeric(region_value(record, 'alpha', plot_df$.__selected_alpha[hit][1])))
    plot_df$.__selected_stroke[hit] <- suppressWarnings(as.numeric(region_value(record, 'stroke', region_value(record, 'outline_width', plot_df$.__selected_stroke[hit][1]))))
    plot_df$.__label_color[hit] <- as.character(region_value(record, 'label_color', plot_df$.__label_color[hit][1]))
    label_bg <- region_value(record, 'label_bg_color', region_value(record, 'label_background', NA_character_))
    if (!is.null(label_bg)) plot_df$.__label_bg[hit] <- as.character(label_bg)
    label_x <- suppressWarnings(as.numeric(region_value(record, 'label_x', NA_real_)))
    label_y <- suppressWarnings(as.numeric(region_value(record, 'label_y', NA_real_)))
    if (!is.na(label_x)) plot_df$.__label_x[hit] <- label_x
    if (!is.na(label_y)) plot_df$.__label_y[hit] <- label_y
    plot_df$.__label_line_color[hit] <- as.character(region_value(record, 'indicator_color', region_value(record, 'label_line_color', plot_df$.__label_line_color[hit][1])))
    plot_df$.__label_line_type[hit] <- as.character(region_value(record, 'indicator_type', region_value(record, 'label_line_type', plot_df$.__label_line_type[hit][1])))
    plot_df$.__label_line_width[hit] <- suppressWarnings(as.numeric(region_value(record, 'indicator_width', region_value(record, 'label_line_width', plot_df$.__label_line_width[hit][1]))))
  }

  plot_df$.__selected_size[!is.finite(plot_df$.__selected_size) | plot_df$.__selected_size <= 0] <- selected_point_size
  plot_df$.__selected_shape[is.na(plot_df$.__selected_shape)] <- 21
  plot_df$.__selected_alpha[!is.finite(plot_df$.__selected_alpha)] <- selected_point_alpha
  plot_df$.__selected_stroke[!is.finite(plot_df$.__selected_stroke) | plot_df$.__selected_stroke < 0] <- selected_point_stroke
  plot_df$.__label_line_width[!is.finite(plot_df$.__label_line_width) | plot_df$.__label_line_width < 0] <- label_line_width
  plot_df
}

if (is.null(input_file)) write_error_and_exit('Missing --input argument')
if (is.null(params_file) || !file.exists(params_file)) {
  write_error_and_exit('Params file not found', paste('Params path:', params_file), 'Backend should generate params.json and pass it through --params.')
}
if (is.null(output_dir)) write_error_and_exit('Missing --output argument')
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
old_outputs <- file.path(output_dir, c('error.json', 'result.svg', 'result.pdf', 'result.png', 'figure.json', 'selected_rows.csv', 'run.log'))
unlink(old_outputs[file.exists(old_outputs)])

write_log('Plugin started.')

params <- tryCatch(
  jsonlite::fromJSON(params_file),
  error = function(e) {
    write_error_and_exit('Failed to parse params.json', conditionMessage(e), 'Please make sure params.json is valid JSON.')
  }
)

df <- read_table_auto(input_file)
write_log(sprintf('Loaded input table with %s rows and %s columns.', nrow(df), ncol(df)))

gene_col <- get_param_any(params, c('gene_column', 'id_column', 'label_column'), NULL)
if (is.null(gene_col)) gene_col <- first_existing_col(df, c('gene', 'Gene', 'GENE', 'symbol', 'Symbol', 'id', 'ID', colnames(df)[1]), TRUE, 'gene_column')
log2fc_col <- get_param_any(params, c('log2fc_column', 'logfc_column', 'x_column'), NULL)
if (is.null(log2fc_col)) log2fc_col <- first_existing_col(df, c('log2FoldChange', 'log2FC', 'Log2FC', 'logFC', 'avg_log2FC', 'avg_logFC'), TRUE, 'log2fc_column')
pvalue_col <- get_param_any(params, c('pvalue_column', 'p_value_column', 'p_col'), NULL)
if (is.null(pvalue_col)) pvalue_col <- first_existing_col(df, c('pvalue', 'p_value', 'p.val', 'p_val', 'PValue', 'P.Value'), FALSE, 'pvalue_column')
padj_col <- get_param_any(params, c('padj_column', 'p_adjust_column', 'pvalue_adj_column'), NULL)
if (is.null(padj_col)) padj_col <- first_existing_col(df, c('padj', 'p_adj', 'p.adjust', 'p_val_adj', 'FDR', 'qvalue', 'q_value', 'PAdjust'), FALSE, 'padj_column')
stat_p_col <- get_param(params, 'use_p_column', NULL)
if (is.null(stat_p_col)) stat_p_col <- if (!is.null(padj_col)) padj_col else pvalue_col
x_col <- get_param_any(params, c('x_column', 'x_col'), log2fc_col)
y_col <- get_param_any(params, c('y_column', 'y_col'), NULL)
if (is.null(y_col)) y_col <- stat_p_col

validate_columns(df, c(gene_col, log2fc_col, stat_p_col, x_col, y_col))

plot_df <- df
plot_df$.__gene <- as.character(plot_df[[gene_col]])
plot_df$.__log2fc <- suppressWarnings(as.numeric(plot_df[[log2fc_col]]))
plot_df$.__p <- suppressWarnings(as.numeric(plot_df[[stat_p_col]]))
plot_df$.__neglog10p <- -log10(plot_df$.__p)
x_transform <- get_param(params, 'x_transform', 'none')
default_y_transform <- if (identical(y_col, stat_p_col)) 'neglog10' else 'none'
y_transform <- get_param(params, 'y_transform', default_y_transform)
plot_df$.__x <- transform_plot_value(plot_df[[x_col]], x_transform)
plot_df$.__y <- transform_plot_value(plot_df[[y_col]], y_transform)
plot_df <- plot_df[
  is.finite(plot_df$.__x) &
    is.finite(plot_df$.__y) &
    is.finite(plot_df$.__log2fc) &
    is.finite(plot_df$.__p) &
    plot_df$.__p > 0,
  ,
  drop = FALSE
]
if (nrow(plot_df) == 0) {
  write_error_and_exit('No valid volcano data', 'No rows had finite x/y values and positive p-value.', 'Check column mappings, transforms, and input values.')
}

fc_cutoff <- as.numeric(get_param(params, 'fc_cutoff', get_param(params, 'log2fc_cutoff', 1)))
p_cutoff <- as.numeric(get_param(params, 'p_cutoff', get_param(params, 'pvalue_cutoff', 0.05)))
neglog10_cutoff <- -log10(p_cutoff)
plot_df$.__group <- 'nodiff'
plot_df$.__group[plot_df$.__log2fc >= fc_cutoff & plot_df$.__p <= p_cutoff] <- 'up'
plot_df$.__group[plot_df$.__log2fc <= -fc_cutoff & plot_df$.__p <= p_cutoff] <- 'down'
plot_df$.__group <- factor(plot_df$.__group, levels = c('up', 'nodiff', 'down'))

selected_genes <- as_string_vector(get_param(params, 'selected_genes', get_param(params, 'label_genes', get_param(params, 'highlight_genes', NULL))))
selected_rows <- as_string_vector(get_param(params, 'selected_ids', NULL))
selected_genes <- unique(c(selected_genes, selected_rows))
top_n_labels <- as.integer(get_param(params, 'top_n_labels', 0))
plot_df$.__selected <- plot_df$.__gene %in% selected_genes
if (top_n_labels > 0) {
  idx <- head(order(plot_df$.__neglog10p * abs(plot_df$.__log2fc), decreasing = TRUE), top_n_labels)
  plot_df$.__selected[idx] <- TRUE
}

title <- as.character(get_param(params, 'title', 'Volcano plot'))[1]
title_show <- as_bool(get_param(params, 'title_show', get_param(params, 'show_title', TRUE)), TRUE)
x_title <- as.character(get_param(params, 'x_title', get_param(params, 'x_axis_title', x_col)))[1]
y_title_default <- if (identical(y_transform, 'neglog10')) paste0('-Log10(', y_col, ')') else y_col
y_title <- as.character(get_param(params, 'y_title', get_param(params, 'y_axis_title', y_title_default)))[1]
show_axis_titles <- as_bool(get_param(params, 'axis_title_show', get_param(params, 'show_axis_titles', TRUE)), TRUE)
show_x_axis <- as_bool(get_param(params, 'show_x_axis', get_param(params, 'x_axis_show', TRUE)), TRUE)
show_y_axis <- as_bool(get_param(params, 'show_y_axis', get_param(params, 'y_axis_show', TRUE)), TRUE)
show_legend <- as_bool(get_param(params, 'show_legend', TRUE), TRUE)
font_family <- as.character(get_param(params, 'font_family', ''))[1]
text_color <- as.character(get_param(params, 'text_color', '#333333'))[1]
title_size <- as.numeric(get_param(params, 'title_size', 18))
axis_title_size <- as.numeric(get_param(params, 'axis_title_size', 16))
axis_text_size <- as.numeric(get_param(params, 'axis_text_size', 12))
axis_line_color <- as.character(get_param(params, 'axis_line_color', '#333333'))[1]
axis_line_width <- as.numeric(get_param(params, 'axis_line_width', 0.5))
axis_tick_show <- as_bool(get_param(params, 'axis_tick_show', TRUE), TRUE)
axis_tick_color <- as.character(get_param(params, 'axis_tick_color', axis_line_color))[1]
axis_tick_width <- as.numeric(get_param(params, 'axis_tick_width', axis_line_width))
x_axis_text_angle <- as.numeric(get_param(params, 'x_axis_text_angle', 0))
y_axis_text_angle <- as.numeric(get_param(params, 'y_axis_text_angle', 0))
legend_text_size <- as.numeric(get_param(params, 'legend_text_size', get_param(params, 'legend_size', 11)))
legend_title_size <- as.numeric(get_param(params, 'legend_title_size', get_param(params, 'legend_size', 12)))
legend_name <- as.character(get_param(params, 'legend_name', get_param(params, 'legend_title', '')))[1]
color_legend_name <- as.character(get_param(params, 'color_legend_name', get_param(params, 'colorbar_title', legend_name)))[1]
legend_bar_width <- as.numeric(get_param(params, 'legend_bar_width', get_param(params, 'colorbar_width', 0.45)))
legend_bar_height <- as.numeric(get_param(params, 'legend_bar_height', get_param(params, 'colorbar_height', 3.2)))
legend_key_size <- as.numeric(get_param(params, 'legend_key_size', 0.45))
legend_frame_color <- as.character(get_param(params, 'legend_frame_color', '#333333'))[1]
legend_tick_color <- as.character(get_param(params, 'legend_tick_color', '#333333'))[1]
region_legend_name <- as.character(get_param(params, 'region_legend_name', get_param(params, 'region_legend_title', 'Custom regions')))[1]
show_region_legend <- as_bool(get_param(params, 'show_region_legend', TRUE), TRUE)
region_legend_order <- as.integer(get_param(params, 'region_legend_order', 3))
region_legend_ncol <- get_param(params, 'region_legend_ncol', NULL)
region_legend_nrow <- get_param(params, 'region_legend_nrow', NULL)
region_legend_reverse <- as_bool(get_param(params, 'region_legend_reverse', FALSE), FALSE)
region_legend_byrow <- as_bool(get_param(params, 'region_legend_byrow', TRUE), TRUE)
region_legend_title_position <- as.character(get_param(params, 'region_legend_title_position', 'top'))[1]
region_legend_direction <- as.character(get_param(params, 'region_legend_direction', 'vertical'))[1]
region_legend_point_size <- get_param(params, 'region_legend_point_size', NULL)

point_size <- as.numeric(get_param(params, 'point_size', get_param(params, 'unselected_point_size', 1.4)))
point_alpha <- as.numeric(get_param(params, 'point_alpha', get_param(params, 'unselected_point_alpha', 0.75)))
selected_point_size <- as.numeric(get_param(params, 'selected_point_size', 3.2))
selected_point_alpha <- as.numeric(get_param(params, 'selected_point_alpha', 1))
selected_point_color <- as.character(get_param(params, 'selected_point_color', '#8E24AA'))[1]
selected_point_stroke <- as.numeric(get_param(params, 'selected_point_stroke', 0.5))

color_mode <- tolower(as.character(get_param(params, 'color_mode', 'category'))[1])
if (!color_mode %in% c('category', 'gradient', 'continuous')) color_mode <- 'category'
category_colors <- palette_colors(params)
gradient_by <- get_param(params, 'gradient_by', get_param(params, 'continuous_color_column', log2fc_col))
if (color_mode %in% c('gradient', 'continuous')) validate_columns(plot_df, gradient_by)

size_mode <- tolower(as.character(get_param(params, 'size_mode', 'fixed'))[1])
size_by <- get_param(params, 'size_by', 'neglog10p')
if (size_by == 'neglog10p') {
  plot_df$.__size_value <- plot_df$.__neglog10p
} else {
  validate_columns(plot_df, size_by)
  plot_df$.__size_value <- suppressWarnings(as.numeric(plot_df[[size_by]]))
}
size_legend_title <- as.character(get_param(params, 'size_legend_title', get_param(params, 'size_legend_name', '-log10(Padjust)')))[1]
min_point_size <- as.numeric(get_param(params, 'min_point_size', 0.5))
max_point_size <- as.numeric(get_param(params, 'max_point_size', 4))

show_threshold_lines <- as_bool(get_param(params, 'show_threshold_lines', TRUE), TRUE)
threshold_line_color <- as.character(get_param(params, 'threshold_line_color', '#555555'))[1]
threshold_line_type <- as.character(get_param(params, 'threshold_line_type', 'dashed'))[1]
threshold_line_width <- as.numeric(get_param(params, 'threshold_line_width', 0.4))
show_zero_line <- as_bool(get_param(params, 'show_zero_line', FALSE), FALSE)
x_thresholds <- get_param(params, 'x_thresholds', NULL)
if (is.null(x_thresholds)) {
  x_thresholds <- if (identical(x_col, log2fc_col) && identical(tolower(as.character(x_transform)[1]), 'none')) c(-fc_cutoff, fc_cutoff) else numeric()
}
x_thresholds <- suppressWarnings(as.numeric(unlist(x_thresholds, use.names = FALSE)))
x_thresholds <- x_thresholds[is.finite(x_thresholds)]
y_thresholds <- get_param(params, 'y_thresholds', NULL)
if (is.null(y_thresholds)) {
  y_thresholds <- if (identical(y_col, stat_p_col) && tolower(as.character(y_transform)[1]) %in% c('neglog10', '-log10', 'minus_log10')) neglog10_cutoff else numeric()
}
y_thresholds <- suppressWarnings(as.numeric(unlist(y_thresholds, use.names = FALSE)))
y_thresholds <- y_thresholds[is.finite(y_thresholds)]
show_grid <- as_bool(get_param(params, 'show_grid', TRUE), TRUE)
panel_border <- as_bool(get_param(params, 'panel_border', TRUE), TRUE)

x_min <- get_param(params, 'x_min', NULL)
x_max <- get_param(params, 'x_max', NULL)
y_min <- get_param(params, 'y_min', 0)
y_max <- get_param(params, 'y_max', NULL)

label_show <- as_bool(get_param(params, 'label_show', get_param(params, 'show_labels', TRUE)), TRUE)
label_size <- as.numeric(get_param(params, 'label_size', 4))
label_color <- as.character(get_param(params, 'label_color', '#212121'))[1]
label_bg_color <- as.character(get_param(params, 'label_bg_color', NA_character_))[1]
label_line_color <- as.character(get_param(params, 'label_line_color', '#777777'))[1]
label_line_width <- as.numeric(get_param(params, 'label_line_width', 0.4))
label_force <- as.numeric(get_param(params, 'label_force', 12))
label_max_overlaps <- as.integer(get_param(params, 'label_max_overlaps', 100))
gene_label_colors <- named_color_vector(get_param(params, 'gene_label_colors', NULL), plot_df$.__gene, label_color)

width <- as.numeric(get_param(params, 'width', 7))
height <- as.numeric(get_param(params, 'height', 6))
theme_name <- as.character(get_param(params, 'theme', 'default'))[1]

region_result <- apply_region_styles(plot_df, params)
plot_df <- region_result$data
region_styles <- region_result$region_styles
plot_df <- apply_selection_regions(plot_df, params)
plot_df <- apply_selected_point_styles(plot_df, params, selected_point_color, selected_point_size, selected_point_alpha, selected_point_stroke, label_color, label_line_color, label_line_width)

selected_rows_df <- plot_df[plot_df$.__selected | nzchar(plot_df$.__brush_region) | nzchar(plot_df$.__region_label), , drop = FALSE]
selected_rows_export <- selected_rows_df[, setdiff(colnames(selected_rows_df), grep('^\\.__', colnames(selected_rows_df), value = TRUE)), drop = FALSE]
selected_rows_export$plot_x <- selected_rows_df$.__x
selected_rows_export$plot_y <- selected_rows_df$.__y
selected_rows_export$de_group <- as.character(selected_rows_df$.__group)
selected_rows_export$style_region <- selected_rows_df$.__region
selected_rows_export$brush_region <- selected_rows_df$.__brush_region
selected_rows_export$is_selected <- selected_rows_df$.__selected

p <- ggplot(plot_df, aes(x = .__x, y = .__y))

if (show_threshold_lines) {
  if (length(x_thresholds) > 0) {
    p <- p + geom_vline(xintercept = x_thresholds, color = threshold_line_color, linetype = threshold_line_type, linewidth = threshold_line_width)
  }
  if (length(y_thresholds) > 0) {
    p <- p + geom_hline(yintercept = y_thresholds, color = threshold_line_color, linetype = threshold_line_type, linewidth = threshold_line_width)
  }
}
if (show_zero_line) {
  p <- p + geom_vline(xintercept = 0, color = threshold_line_color, linetype = 'dotted', linewidth = threshold_line_width)
}

has_regions <- nrow(region_styles) > 0 && any(nzchar(plot_df$.__region_label))
region_df <- plot_df[nzchar(plot_df$.__region_label), , drop = FALSE]
base_df <- plot_df[!plot_df$.__selected & !nzchar(plot_df$.__region_label), , drop = FALSE]
selected_df <- plot_df[plot_df$.__selected, , drop = FALSE]

if (color_mode == 'category') {
  if (size_mode == 'mapped') {
    p <- p +
      geom_point(data = base_df, aes(color = .__group, size = .__size_value), alpha = point_alpha) +
      scale_size_continuous(name = size_legend_title, range = c(min_point_size, max_point_size))
  } else {
    p <- p + geom_point(data = base_df, aes(color = .__group), size = point_size, alpha = point_alpha)
  }
  p <- p + scale_color_manual(name = legend_name, values = category_colors, drop = FALSE)
} else {
  if (size_mode == 'mapped') {
    p <- p +
      geom_point(data = base_df, aes(color = .data[[gradient_by]], size = .__size_value), alpha = point_alpha) +
      scale_size_continuous(name = size_legend_title, range = c(min_point_size, max_point_size))
  } else {
    p <- p + geom_point(data = base_df, aes(color = .data[[gradient_by]]), size = point_size, alpha = point_alpha)
  }
  if (!nzchar(color_legend_name)) color_legend_name <- gradient_by
  p <- p + scale_color_gradientn(name = color_legend_name, colors = gradient_palette(params), na.value = '#BDBDBD')
}

if (has_regions && nrow(region_df) > 0) {
  region_df$.__region_label <- factor(region_df$.__region_label, levels = region_styles$label)
  region_fill_values <- stats::setNames(region_styles$fill, region_styles$label)
  region_shape_values <- stats::setNames(region_styles$shape, region_styles$label)
  region_outline_values <- stats::setNames(region_styles$outline, region_styles$label)

  if (show_region_legend) {
    p <- p +
      geom_point(
        data = region_df,
        aes(fill = .__region_label, shape = .__region_label),
        color = region_df$.__region_outline,
        size = region_df$.__region_size,
        stroke = region_df$.__region_stroke,
        alpha = region_df$.__region_alpha
      ) +
      scale_fill_manual(name = region_legend_name, values = region_fill_values, drop = FALSE) +
      scale_shape_manual(name = region_legend_name, values = region_shape_values, drop = FALSE)
  } else {
    for (region_label in unique(as.character(region_df$.__region_label))) {
      region_part <- region_df[as.character(region_df$.__region_label) == region_label, , drop = FALSE]
      p <- p + geom_point(
        data = region_part,
        shape = region_part$.__region_shape[1],
        fill = region_part$.__region_fill[1],
        color = region_part$.__region_outline[1],
        size = region_part$.__region_size[1],
        stroke = region_part$.__region_stroke[1],
        alpha = region_part$.__region_alpha[1],
        show.legend = FALSE
      )
    }
  }
}

if (nrow(selected_df) > 0) {
  p <- p +
    geom_point(
      data = selected_df,
      shape = selected_df$.__selected_shape,
      fill = selected_df$.__selected_fill,
      color = selected_df$.__selected_outline,
      stroke = selected_df$.__selected_stroke,
      size = selected_df$.__selected_size,
      alpha = selected_df$.__selected_alpha,
      show.legend = FALSE
    )
}

if (label_show && nrow(selected_df) > 0) {
  label_df <- selected_df[selected_df$.__label_enabled, , drop = FALSE]
  manual_label_df <- label_df[is.finite(label_df$.__label_x) & is.finite(label_df$.__label_y), , drop = FALSE]
  repel_label_df <- label_df[!(is.finite(label_df$.__label_x) & is.finite(label_df$.__label_y)), , drop = FALSE]

  if (nrow(manual_label_df) > 0) {
    p <- p + geom_segment(
      data = manual_label_df,
      aes(x = .__x, y = .__y, xend = .__label_x, yend = .__label_y),
      color = manual_label_df$.__label_line_color,
      linetype = manual_label_df$.__label_line_type,
      linewidth = manual_label_df$.__label_line_width
    )
    if (any(!is.na(manual_label_df$.__label_bg) & nzchar(manual_label_df$.__label_bg))) {
      p <- p + geom_label(
        data = manual_label_df,
        aes(x = .__label_x, y = .__label_y, label = .__gene),
        color = manual_label_df$.__label_color,
        fill = ifelse(is.na(manual_label_df$.__label_bg) | !nzchar(manual_label_df$.__label_bg), label_bg_color, manual_label_df$.__label_bg),
        size = label_size,
        family = font_family
      )
    } else {
      p <- p + geom_text(
        data = manual_label_df,
        aes(x = .__label_x, y = .__label_y, label = .__gene),
        color = manual_label_df$.__label_color,
        size = label_size,
        family = font_family
      )
    }
  }

  selected_df <- repel_label_df
  if (nrow(selected_df) == 0) {
    selected_df <- selected_df
  } else
  if (requireNamespace('ggrepel', quietly = TRUE)) {
    if (!is.na(label_bg_color) && nzchar(label_bg_color)) {
      p <- p + ggrepel::geom_label_repel(
        data = selected_df,
        aes(label = .__gene),
        color = selected_df$.__label_color,
        fill = label_bg_color,
        size = label_size,
        family = font_family,
        segment.color = selected_df$.__label_line_color,
        segment.size = selected_df$.__label_line_width,
        segment.linetype = selected_df$.__label_line_type,
        min.segment.length = 0,
        max.overlaps = label_max_overlaps,
        force = label_force
      )
    } else {
      p <- p + ggrepel::geom_text_repel(
        data = selected_df,
        aes(label = .__gene),
        color = selected_df$.__label_color,
        size = label_size,
        family = font_family,
        segment.color = selected_df$.__label_line_color,
        segment.size = selected_df$.__label_line_width,
        segment.linetype = selected_df$.__label_line_type,
        min.segment.length = 0,
        max.overlaps = label_max_overlaps,
        force = label_force
      )
    }
  } else {
    write_log('Package ggrepel is not installed. Labels will be drawn without repel.')
    p <- p + geom_text(data = selected_df, aes(label = .__gene), color = selected_df$.__label_color, size = label_size, family = font_family, vjust = -0.6)
  }
}

p <- p +
  labs(
    title = if (title_show) title else NULL,
    x = if (show_axis_titles && show_x_axis) x_title else NULL,
    y = if (show_axis_titles && show_y_axis) y_title else NULL
  ) +
  theme_classic(base_family = font_family) +
  theme(
    plot.title = element_text(hjust = 0.5, face = ifelse(as_bool(get_param(params, 'title_bold', TRUE), TRUE), 'bold', 'plain'), size = title_size, color = text_color),
    axis.title = element_text(face = ifelse(as_bool(get_param(params, 'axis_title_bold', TRUE), TRUE), 'bold', 'plain'), size = axis_title_size, color = text_color),
    axis.title.x = if (show_x_axis) element_text(face = ifelse(as_bool(get_param(params, 'axis_title_bold', TRUE), TRUE), 'bold', 'plain'), size = axis_title_size, color = text_color) else element_blank(),
    axis.title.y = if (show_y_axis) element_text(face = ifelse(as_bool(get_param(params, 'axis_title_bold', TRUE), TRUE), 'bold', 'plain'), size = axis_title_size, color = text_color) else element_blank(),
    axis.text.x = if (show_x_axis) element_text(size = axis_text_size, color = text_color, angle = x_axis_text_angle, hjust = ifelse(x_axis_text_angle == 0, 0.5, 1)) else element_blank(),
    axis.text.y = if (show_y_axis) element_text(size = axis_text_size, color = text_color, angle = y_axis_text_angle) else element_blank(),
    axis.line.x = if (show_x_axis) element_line(color = axis_line_color, linewidth = axis_line_width) else element_blank(),
    axis.line.y = if (show_y_axis) element_line(color = axis_line_color, linewidth = axis_line_width) else element_blank(),
    axis.ticks = if (axis_tick_show) element_line(color = axis_tick_color, linewidth = axis_tick_width) else element_blank(),
    axis.ticks.x = if (show_x_axis && axis_tick_show) element_line(color = axis_tick_color, linewidth = axis_tick_width) else element_blank(),
    axis.ticks.y = if (show_y_axis && axis_tick_show) element_line(color = axis_tick_color, linewidth = axis_tick_width) else element_blank(),
    legend.position = if (show_legend) as.character(get_param(params, 'legend_position', 'right'))[1] else 'none',
    legend.title = element_text(size = legend_title_size, face = 'bold'),
    legend.text = element_text(size = legend_text_size),
    legend.key.size = grid::unit(legend_key_size, 'cm'),
    panel.grid.major = if (show_grid) element_line(color = '#E6E6E6', linewidth = 0.3) else element_blank(),
    panel.grid.minor = if (show_grid) element_line(color = '#F2F2F2', linewidth = 0.2) else element_blank(),
    panel.border = if (panel_border) element_rect(color = '#444444', fill = NA, linewidth = 0.5) else element_blank()
  )

if (show_legend) {
  region_override_size <- if (!is.null(region_legend_point_size)) {
    rep(as.numeric(region_legend_point_size), max(1, nrow(region_styles)))
  } else if (exists('region_styles') && nrow(region_styles) > 0) {
    region_styles$size
  } else {
    3
  }
  region_guide <- guide_legend(
    title = region_legend_name,
    order = region_legend_order,
    ncol = if (is.null(region_legend_ncol)) NULL else as.integer(region_legend_ncol),
    nrow = if (is.null(region_legend_nrow)) NULL else as.integer(region_legend_nrow),
    byrow = region_legend_byrow,
    reverse = region_legend_reverse,
    title.position = region_legend_title_position,
    direction = region_legend_direction,
    override.aes = list(
      color = if (exists('region_outline_values')) unname(region_outline_values) else '#212121',
      size = region_override_size,
      alpha = 1,
      stroke = if (exists('region_styles') && nrow(region_styles) > 0) region_styles$stroke else 0.5
    )
  )
  if (color_mode %in% c('gradient', 'continuous')) {
    p <- p + guides(
      color = guide_colorbar(
        barwidth = grid::unit(legend_bar_width, 'cm'),
        barheight = grid::unit(legend_bar_height, 'cm'),
        frame.colour = legend_frame_color,
        ticks.colour = legend_tick_color,
        title.position = as.character(get_param(params, 'legend_title_position', 'top'))[1]
      ),
      size = guide_legend(title = size_legend_title),
      fill = region_guide,
      shape = guide_legend(title = region_legend_name, order = region_legend_order)
    )
  } else {
    p <- p + guides(
      color = guide_legend(title = legend_name, override.aes = list(size = as.numeric(get_param(params, 'legend_point_size', 3)), alpha = 1)),
      size = guide_legend(title = size_legend_title),
      fill = region_guide,
      shape = guide_legend(title = region_legend_name, order = region_legend_order)
    )
  }
}

if (theme_name == 'minimal') p <- p + theme_minimal(base_family = font_family)
if (!is.null(x_min) || !is.null(x_max) || !is.null(y_min) || !is.null(y_max)) {
  p <- p + coord_cartesian(
    xlim = c(ifelse(is.null(x_min), NA, as.numeric(x_min)), ifelse(is.null(x_max), NA, as.numeric(x_max))),
    ylim = c(ifelse(is.null(y_min), NA, as.numeric(y_min)), ifelse(is.null(y_max), NA, as.numeric(y_max)))
  )
}

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

utils::write.csv(selected_rows_export, selected_rows_file, row.names = FALSE)

point_colors <- if (color_mode == 'category') {
  vals <- unname(category_colors[as.character(plot_df$.__group)])
  vals[is.na(vals)] <- '#BDBDBD'
  vals
} else {
  '#3B82F6'
}
selected_point_colors <- ifelse(plot_df$.__selected, plot_df$.__selected_outline, point_colors)
plotly_hover <- paste0(
  plot_df$.__gene,
  '<br>', x_title, ': ', signif(plot_df$.__x, 5),
  '<br>', y_title, ': ', signif(plot_df$.__y, 5),
  '<br>group: ', as.character(plot_df$.__group)
)
plotly_json <- list(
  data = list(
    list(
      type = 'scattergl',
      mode = 'markers',
      name = 'points',
      x = plot_df$.__x,
      y = plot_df$.__y,
      text = plot_df$.__gene,
      customdata = plot_df$.__gene,
      hovertext = plotly_hover,
      hoverinfo = 'text',
      marker = list(
        color = selected_point_colors,
        size = ifelse(plot_df$.__selected, plot_df$.__selected_size * 3, point_size * 3),
        opacity = ifelse(plot_df$.__selected, plot_df$.__selected_alpha, point_alpha),
        line = list(color = ifelse(plot_df$.__selected, plot_df$.__selected_outline, '#FFFFFF'), width = ifelse(plot_df$.__selected, 1.2, 0.2))
      ),
      selected = list(marker = list(color = selected_point_color, size = selected_point_size * 3)),
      unselected = list(marker = list(opacity = 0.35))
    )
  ),
  layout = list(
    title = if (title_show) title else '',
    xaxis = list(title = if (show_axis_titles && show_x_axis) x_title else '', zeroline = FALSE),
    yaxis = list(title = if (show_axis_titles && show_y_axis) y_title else '', zeroline = FALSE),
    dragmode = 'select',
    hovermode = 'closest',
    showlegend = FALSE,
    margin = list(l = 70, r = 30, t = if (title_show) 60 else 25, b = 65),
    paper_bgcolor = '#FFFFFF',
    plot_bgcolor = '#FFFFFF'
  ),
  selection = list(id_param = 'selected_genes', label_param = 'selected_genes', label_column = gene_col)
)

figure_json <- list(
  figure_type = get_param(params, 'plugin_id', 'volcano_plot'),
  title = title,
  theme = theme_name,
  layout = list(width = width, height = height),
  columns = list(gene = gene_col, log2fc = log2fc_col, pvalue = stat_p_col, x = x_col, y = y_col, x_transform = x_transform, y_transform = y_transform),
  thresholds = list(fc_cutoff = fc_cutoff, p_cutoff = p_cutoff, neglog10_cutoff = neglog10_cutoff, x_thresholds = x_thresholds, y_thresholds = y_thresholds),
  style = list(
    title_show = title_show,
    title_size = title_size,
    x_title = x_title,
    y_title = y_title,
    show_x_axis = show_x_axis,
    show_y_axis = show_y_axis,
    show_axis_titles = show_axis_titles,
    x_min = x_min,
    x_max = x_max,
    y_min = y_min,
    y_max = y_max,
    axis_title_size = axis_title_size,
    axis_text_size = axis_text_size,
    axis_line_color = axis_line_color,
    axis_line_width = axis_line_width,
    axis_tick_show = axis_tick_show,
    axis_tick_color = axis_tick_color,
    x_axis_text_angle = x_axis_text_angle,
    y_axis_text_angle = y_axis_text_angle,
    color_mode = color_mode,
    legend_name = legend_name,
    color_legend_name = color_legend_name,
    size_legend_title = size_legend_title,
    legend_position = get_param(params, 'legend_position', 'right'),
    legend_title_size = legend_title_size,
    legend_text_size = legend_text_size,
    legend_bar_width = legend_bar_width,
    legend_bar_height = legend_bar_height,
    legend_key_size = legend_key_size,
    legend_frame_color = legend_frame_color,
    legend_tick_color = legend_tick_color,
    region_legend_order = region_legend_order,
    region_legend_ncol = region_legend_ncol,
    region_legend_nrow = region_legend_nrow,
    region_legend_reverse = region_legend_reverse,
    region_legend_byrow = region_legend_byrow,
    region_legend_title_position = region_legend_title_position,
    region_legend_direction = region_legend_direction,
    region_legend_point_size = region_legend_point_size,
    palette_scheme = get_param(params, 'palette_scheme', get_param(params, 'color_scheme', 'category')),
    point_size = point_size,
    selected_point_size = selected_point_size,
    label_show = label_show,
    label_size = label_size,
    show_threshold_lines = show_threshold_lines,
    region_legend_name = region_legend_name,
    show_region_legend = show_region_legend,
    regions = region_styles
  ),
  data = list(
    input_file = basename(input_file),
    n_rows = nrow(df),
    n_plotted = nrow(plot_df),
    n_up = sum(plot_df$.__group == 'up'),
    n_down = sum(plot_df$.__group == 'down'),
    n_nodiff = sum(plot_df$.__group == 'nodiff'),
    n_selected = sum(plot_df$.__selected),
    n_brushed = sum(nzchar(plot_df$.__brush_region)),
    selected_rows_file = 'selected_rows.csv'
  ),
  layers = list(
    list(id = 'points', type = 'scatter', editable = TRUE),
    list(id = 'region_points', type = 'scatter', editable = TRUE),
    list(id = 'brush_selection', type = 'selection', editable = TRUE, table = 'selected_rows.csv'),
    list(id = 'selected_points', type = 'scatter', editable = TRUE),
    list(id = 'labels', type = 'text', editable = TRUE, draggable = TRUE),
    list(id = 'label_indicators', type = 'segment', editable = TRUE),
    list(id = 'threshold_lines', type = 'line', editable = TRUE),
    list(id = 'legend', type = 'legend', editable = TRUE)
  ),
  plotly = plotly_json,
  export = list(svg = 'result.svg', pdf = 'result.pdf', png = 'result.png', selected_rows = 'selected_rows.csv')
)

writeLines(jsonlite::toJSON(figure_json, auto_unbox = TRUE, pretty = TRUE), figure_json_file)
write_log('Plugin completed successfully.')
quit(status = 0)
