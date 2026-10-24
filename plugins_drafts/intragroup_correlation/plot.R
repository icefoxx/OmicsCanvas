#!/usr/bin/env Rscript

# BioFigureAI Plot Plugin: Intragroup Correlation Heatmap
# ------------------------------------------------------------
# Runtime contract:
#   Rscript plot.R --input input.csv --params params.json --output output_dir
#   Optional cross-matrix mode:
#   Rscript plot.R --input matrix1.csv --input2 matrix2.csv --params params.json --output output_dir
#
# Supported input:
#   CSV/TSV/TXT numeric matrix. A row-name column can be supplied through
#   params$row_name_column, or the first column is used automatically.
#
# Main analysis modes:
#   pearson, spearman, kendall, jaccard, jarrad, cosine, cos, raw

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
  library(grid)
})

option_list <- list(
  make_option(c('--input'), type = 'character', default = NULL,
              help = 'Path to the main input file, usually CSV/TSV/TXT.'),
  make_option(c('--input2'), type = 'character', default = NULL,
              help = 'Optional path to the second matrix file for cross-matrix correlation.'),
  make_option(c('--params'), type = 'character', default = NULL,
              help = 'Path to params.json.'),
  make_option(c('--output'), type = 'character', default = NULL,
              help = 'Output directory.')
)

opt <- parse_args(OptionParser(option_list = option_list))
input_file <- opt$input
input2_file <- opt$input2
params_file <- opt$params
output_dir <- opt$output

write_log <- function(message) {
  log_file <- file.path(output_dir, 'run.log')
  timestamp <- format(Sys.time(), '%Y-%m-%d %H:%M:%S')
  cat(sprintf('[%s] %s\n', timestamp, message), file = log_file, append = TRUE)
}

write_error_and_exit <- function(error, detail = NULL, suggestion = NULL, status = 1) {
  if (is.null(output_dir)) {
    output_dir <<- getwd()
  }
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  error_obj <- list(
    error = error,
    detail = ifelse(is.null(detail), '', detail),
    suggestion = ifelse(is.null(suggestion), '', suggestion)
  )

  writeLines(
    jsonlite::toJSON(error_obj, auto_unbox = TRUE, pretty = TRUE),
    file.path(output_dir, 'error.json')
  )

  message(error)
  quit(status = status)
}

read_table_auto <- function(path) {
  if (is.null(path) || !file.exists(path)) {
    write_error_and_exit(
      error = 'Input file not found',
      detail = paste('Input path:', path),
      suggestion = 'Please provide a valid input file path.'
    )
  }

  ext <- tolower(tools::file_ext(path))
  if (ext == 'csv') {
    return(read.csv(path, check.names = FALSE, stringsAsFactors = FALSE))
  }
  if (ext %in% c('tsv', 'txt')) {
    return(read.delim(path, check.names = FALSE, stringsAsFactors = FALSE))
  }

  write_error_and_exit(
    error = 'Unsupported input file type',
    detail = paste('File extension:', ext),
    suggestion = 'For MVP, use csv, tsv, or txt input files.'
  )
}

get_param <- function(params, name, default = NULL) {
  if (!is.null(params[[name]])) {
    return(params[[name]])
  }
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
  if (is.list(x) && !is.data.frame(x)) {
    x <- unlist(x, use.names = FALSE)
  }
  if (length(x) == 1 && is.character(x) && grepl(',', x, fixed = TRUE)) {
    x <- strsplit(x, ',', fixed = TRUE)[[1]]
  }
  x <- trimws(as.character(x))
  x[nzchar(x)]
}

normalize_method <- function(method) {
  method <- tolower(trimws(as.character(method)[1]))
  if (method %in% c('jarrad', 'jaccard_binary')) return('jaccard')
  if (method == 'cos') return('cosine')
  if (method %in% c('value', 'values', 'matrix')) return('raw')
  method
}

normalize_shape <- function(shape) {
  shape <- tolower(trimws(as.character(shape)[1]))
  if (shape %in% c('circle', 'round', 'point', 'bubble')) return('circle')
  if (shape %in% c('square', 'tile', 'rect', 'rectangle', 'cell')) return('tile')
  shape
}

scale_ui_cell_size <- function(x, default = 1) {
  x <- suppressWarnings(as.numeric(x)[1])
  if (is.na(x) || x <= 0) return(default)
  if (x > 5) return(x / 25)
  x
}

palette_colors <- function(params) {
  scheme <- tolower(as.character(get_param(params, 'palette_scheme', get_param(params, 'color_scheme', 'custom')))[1])
  schemes <- list(
    custom = c(
      as.character(get_param(params, 'low_color', '#2FB344'))[1],
      as.character(get_param(params, 'mid_color', '#FFFFFF'))[1],
      as.character(get_param(params, 'high_color', '#F05AB8'))[1]
    ),
    genedenovo1 = c('#2C7BB6', '#F7F7F7', '#D7191C'),
    genedenovo2 = c('#00B000', '#F7F7F7', '#D7191C'),
    genedenovo3 = c('#3155D4', '#F7F7F7', '#D73027'),
    genedenovo4 = c('#2166AC', '#F7F7F7', '#B2182B'),
    genedenovo5 = c('#28A9E0', '#FFFFBF', '#D95F02'),
    genedenovo6 = c('#1B9E77', '#F7F7F7', '#D95F02'),
    genedenovo7 = c('#66BD63', '#F7F7F7', '#D01C8B'),
    genedenovo8 = c('#1F9EAA', '#F7F7F7', '#D65F9E'),
    rdbu = c('#2166AC', '#F7F7F7', '#B2182B'),
    blue_white_red = c('#2166AC', '#F7F7F7', '#B2182B'),
    green_white_pink = c('#2FB344', '#FFFFFF', '#F05AB8')
  )
  if (!scheme %in% names(schemes)) scheme <- 'custom'
  colors <- schemes[[scheme]]
  names(colors) <- c('low', 'mid', 'high')
  colors
}

normalize_matrix_values <- function(mat, mode) {
  mode <- tolower(as.character(mode)[1])
  if (is.na(mode) || mode %in% c('none', 'no', 'off', 'raw')) return(mat)

  if (mode %in% c('row_zscore', 'row_z', 'zscore_row')) {
    return(t(scale(t(mat))))
  }
  if (mode %in% c('column_zscore', 'col_zscore', 'col_z', 'zscore_column')) {
    return(scale(mat))
  }
  if (mode %in% c('zscore', 'global_zscore')) {
    return((mat - mean(mat, na.rm = TRUE)) / stats::sd(as.vector(mat), na.rm = TRUE))
  }

  minmax <- function(x) {
    rng <- range(x, na.rm = TRUE)
    if (!all(is.finite(rng)) || diff(rng) == 0) return(rep(0, length(x)))
    (x - rng[1]) / diff(rng)
  }
  if (mode %in% c('row_minmax', 'minmax_row')) {
    out <- t(apply(mat, 1, minmax))
    dimnames(out) <- dimnames(mat)
    return(out)
  }
  if (mode %in% c('column_minmax', 'col_minmax', 'minmax_column')) {
    out <- apply(mat, 2, minmax)
    dimnames(out) <- dimnames(mat)
    return(out)
  }
  if (mode %in% c('minmax', 'global_minmax')) {
    out <- matrix(minmax(as.vector(mat)), nrow = nrow(mat), dimnames = dimnames(mat))
    return(out)
  }

  mat
}

validate_columns <- function(df, cols) {
  missing_cols <- setdiff(cols, colnames(df))
  if (length(missing_cols) > 0) {
    write_error_and_exit(
      error = 'Required input columns not found',
      detail = paste('Missing columns:', paste(missing_cols, collapse = ', ')),
      suggestion = 'Please check column names in params.json.'
    )
  }
}

make_numeric_matrix <- function(df, params, prefix = '') {
  pref <- function(name) if (nzchar(prefix)) paste0(prefix, '_', name) else name
  row_name_column <- get_param_any(
    params,
    c(pref('row_name_column'), pref('row_column'), pref('id_column'), 'row_name_column'),
    NULL
  )

  if (!is.null(row_name_column) && nzchar(row_name_column)) {
    validate_columns(df, row_name_column)
    row_names <- make.unique(as.character(df[[row_name_column]]))
    data_df <- df[, setdiff(colnames(df), row_name_column), drop = FALSE]
  } else {
    first_column_as_row_names <- as_bool(
      get_param_any(params, c(pref('first_column_as_row_names'), 'first_column_as_row_names'), TRUE),
      TRUE
    )
    if (first_column_as_row_names && ncol(df) >= 2) {
      row_names <- make.unique(as.character(df[[1]]))
      data_df <- df[, -1, drop = FALSE]
    } else {
      numeric_flags <- vapply(df, is.numeric, logical(1))
      if (any(!numeric_flags)) {
        first_label_col <- colnames(df)[which(!numeric_flags)[1]]
        row_names <- make.unique(as.character(df[[first_label_col]]))
        data_df <- df[, numeric_flags, drop = FALSE]
      } else {
        row_names <- rownames(df)
        data_df <- df
      }
    }
  }

  include_columns <- as_string_vector(get_param_any(
    params,
    c(pref('columns_include'), pref('value_columns'), pref('columns_keep'), pref('keep_columns'), 'value_columns'),
    NULL
  ))
  exclude_columns <- as_string_vector(get_param_any(
    params,
    c(pref('columns_exclude'), pref('columns_hide'), pref('hide_columns')),
    NULL
  ))
  if (length(include_columns) > 0) {
    validate_columns(data_df, include_columns)
    data_df <- data_df[, include_columns, drop = FALSE]
  }
  if (length(exclude_columns) > 0) {
    data_df <- data_df[, setdiff(colnames(data_df), exclude_columns), drop = FALSE]
  }

  mat <- as.matrix(data_df)
  suppressWarnings(storage.mode(mat) <- 'numeric')
  if (anyNA(mat)) {
    write_log(sprintf('%sInput matrix contains NA values. Pairwise complete observations will be used where possible.', ifelse(nzchar(prefix), paste0(prefix, ': '), '')))
  }
  rownames(mat) <- row_names

  include_rows <- as_string_vector(get_param_any(params, c(pref('rows_include'), pref('rows_keep'), pref('keep_rows')), NULL))
  exclude_rows <- as_string_vector(get_param_any(params, c(pref('rows_exclude'), pref('rows_hide'), pref('hide_rows')), NULL))
  if (length(include_rows) > 0) {
    mat <- mat[intersect(include_rows, rownames(mat)), , drop = FALSE]
  }
  if (length(exclude_rows) > 0) {
    mat <- mat[setdiff(rownames(mat), exclude_rows), , drop = FALSE]
  }

  if (nrow(mat) == 0 || ncol(mat) == 0) {
    write_error_and_exit(
      error = 'No numeric matrix data available',
      detail = 'The input table did not contain usable numeric columns after filtering.',
      suggestion = 'Upload a numeric matrix or specify *_columns_include / *_columns_exclude in params.json.'
    )
  }

  mat
}

cosine_similarity <- function(mat, compute_by) {
  x <- if (compute_by == 'row') mat else t(mat)
  x[is.na(x)] <- 0
  denom <- sqrt(rowSums(x * x))
  sim <- tcrossprod(x)
  denom_matrix <- outer(denom, denom)
  sim <- sim / denom_matrix
  sim[!is.finite(sim)] <- NA_real_
  dimnames(sim) <- list(rownames(x), rownames(x))
  sim
}

jaccard_similarity <- function(mat, compute_by, threshold = 0) {
  x <- if (compute_by == 'row') mat else t(mat)
  x <- abs(x) > threshold
  sim <- matrix(NA_real_, nrow = nrow(x), ncol = nrow(x), dimnames = list(rownames(x), rownames(x)))
  for (i in seq_len(nrow(x))) {
    for (j in seq_len(nrow(x))) {
      union_n <- sum(x[i, ] | x[j, ], na.rm = TRUE)
      intersect_n <- sum(x[i, ] & x[j, ], na.rm = TRUE)
      sim[i, j] <- if (union_n == 0) NA_real_ else intersect_n / union_n
    }
  }
  sim
}

cor_pvalue_matrix <- function(mat, compute_by, method) {
  x <- if (compute_by == 'row') mat else t(mat)
  pmat <- matrix(NA_real_, nrow = nrow(x), ncol = nrow(x), dimnames = list(rownames(x), rownames(x)))
  for (i in seq_len(nrow(x))) {
    for (j in seq_len(nrow(x))) {
      xi <- as.numeric(x[i, ])
      xj <- as.numeric(x[j, ])
      ok <- stats::complete.cases(xi, xj)
      if (sum(ok) >= 3 && stats::sd(xi[ok]) > 0 && stats::sd(xj[ok]) > 0) {
        pmat[i, j] <- tryCatch(
          stats::cor.test(xi[ok], xj[ok], method = method, exact = FALSE)$p.value,
          error = function(e) NA_real_
        )
      }
    }
  }
  pmat
}

cross_cor_pvalue_matrix <- function(mat1, mat2, method, compute_by) {
  x <- if (compute_by == 'row') mat1 else t(mat1)
  y <- if (compute_by == 'row') mat2 else t(mat2)
  pmat <- matrix(NA_real_, nrow = nrow(x), ncol = nrow(y), dimnames = list(rownames(x), rownames(y)))
  for (i in seq_len(nrow(x))) {
    for (j in seq_len(nrow(y))) {
      xi <- as.numeric(x[i, ])
      yj <- as.numeric(y[j, ])
      ok <- stats::complete.cases(xi, yj)
      if (sum(ok) >= 3 && stats::sd(xi[ok]) > 0 && stats::sd(yj[ok]) > 0) {
        pmat[i, j] <- tryCatch(
          stats::cor.test(xi[ok], yj[ok], method = method, exact = FALSE)$p.value,
          error = function(e) NA_real_
        )
      }
    }
  }
  pmat
}

cross_cosine_similarity <- function(mat1, mat2, compute_by) {
  x <- if (compute_by == 'row') mat1 else t(mat1)
  y <- if (compute_by == 'row') mat2 else t(mat2)
  x[is.na(x)] <- 0
  y[is.na(y)] <- 0
  denom <- outer(sqrt(rowSums(x * x)), sqrt(rowSums(y * y)))
  sim <- x %*% t(y)
  sim <- sim / denom
  sim[!is.finite(sim)] <- NA_real_
  dimnames(sim) <- list(rownames(x), rownames(y))
  sim
}

cross_jaccard_similarity <- function(mat1, mat2, compute_by, threshold = 0) {
  x <- if (compute_by == 'row') mat1 else t(mat1)
  y <- if (compute_by == 'row') mat2 else t(mat2)
  x <- abs(x) > threshold
  y <- abs(y) > threshold
  sim <- matrix(NA_real_, nrow = nrow(x), ncol = nrow(y), dimnames = list(rownames(x), rownames(y)))
  for (i in seq_len(nrow(x))) {
    for (j in seq_len(nrow(y))) {
      union_n <- sum(x[i, ] | y[j, ], na.rm = TRUE)
      intersect_n <- sum(x[i, ] & y[j, ], na.rm = TRUE)
      sim[i, j] <- if (union_n == 0) NA_real_ else intersect_n / union_n
    }
  }
  sim
}

align_two_matrices <- function(mat1, mat2, compute_by) {
  if (compute_by == 'row') {
    shared_columns <- intersect(colnames(mat1), colnames(mat2))
    if (length(shared_columns) < 2) {
      write_error_and_exit(
        error = 'Not enough shared columns between matrices',
        detail = paste('Shared columns:', length(shared_columns)),
        suggestion = 'For row-wise cross-correlation, both matrices need at least two shared numeric column names.'
      )
    }
    return(list(
      mat1 = mat1[, shared_columns, drop = FALSE],
      mat2 = mat2[, shared_columns, drop = FALSE],
      shared_features = shared_columns
    ))
  }

  shared_rows <- intersect(rownames(mat1), rownames(mat2))
  if (length(shared_rows) < 3) {
    write_error_and_exit(
      error = 'Not enough shared rows between matrices',
      detail = paste('Shared rows:', length(shared_rows)),
      suggestion = 'For column-wise cross-correlation, both matrices need at least three shared row IDs/features in the first column.'
    )
  }
  list(
    mat1 = mat1[shared_rows, , drop = FALSE],
    mat2 = mat2[shared_rows, , drop = FALSE],
    shared_features = shared_rows
  )
}

compute_cross_value_matrices <- function(mat1, mat2, method, compute_by, binary_threshold) {
  aligned <- align_two_matrices(mat1, mat2, compute_by)
  mat1 <- aligned$mat1
  mat2 <- aligned$mat2

  if (method == 'raw') {
    write_error_and_exit(
      error = 'raw analysis_type is not supported for two input matrices',
      detail = 'Two-matrix mode calculates relationships between matrix 1 and matrix 2.',
      suggestion = 'Use pearson, spearman, kendall, jaccard, jarrad, cosine, or cos.'
    )
  }

  if (method %in% c('pearson', 'spearman', 'kendall')) {
    value <- if (compute_by == 'row') {
      stats::cor(t(mat1), t(mat2), method = method, use = 'pairwise.complete.obs')
    } else {
      stats::cor(mat1, mat2, method = method, use = 'pairwise.complete.obs')
    }
    pvalue <- cross_cor_pvalue_matrix(mat1, mat2, method, compute_by)
    return(list(value = value, pvalue = pvalue, shared_features = aligned$shared_features))
  }

  if (method == 'cosine') {
    value <- cross_cosine_similarity(mat1, mat2, compute_by)
    pvalue <- matrix(NA_real_, nrow(value), ncol(value), dimnames = dimnames(value))
    return(list(value = value, pvalue = pvalue, shared_features = aligned$shared_features))
  }

  if (method == 'jaccard') {
    value <- cross_jaccard_similarity(mat1, mat2, compute_by, binary_threshold)
    pvalue <- matrix(NA_real_, nrow(value), ncol(value), dimnames = dimnames(value))
    return(list(value = value, pvalue = pvalue, shared_features = aligned$shared_features))
  }

  write_error_and_exit(
    error = 'Unsupported analysis_type',
    detail = paste('analysis_type:', method),
    suggestion = 'Use pearson, spearman, kendall, jaccard, jarrad, cosine, or cos.'
  )
}

compute_value_matrices <- function(mat, method, compute_by, binary_threshold) {
  if (method == 'raw') {
    return(list(value = mat, pvalue = matrix(NA_real_, nrow(mat), ncol(mat), dimnames = dimnames(mat))))
  }

  if (method %in% c('pearson', 'spearman', 'kendall')) {
    value <- if (compute_by == 'row') {
      stats::cor(t(mat), method = method, use = 'pairwise.complete.obs')
    } else {
      stats::cor(mat, method = method, use = 'pairwise.complete.obs')
    }
    pvalue <- cor_pvalue_matrix(mat, compute_by, method)
    return(list(value = value, pvalue = pvalue))
  }

  if (method == 'cosine') {
    value <- cosine_similarity(mat, compute_by)
    pvalue <- matrix(NA_real_, nrow(value), ncol(value), dimnames = dimnames(value))
    return(list(value = value, pvalue = pvalue))
  }

  if (method == 'jaccard') {
    value <- jaccard_similarity(mat, compute_by, binary_threshold)
    pvalue <- matrix(NA_real_, nrow(value), ncol(value), dimnames = dimnames(value))
    return(list(value = value, pvalue = pvalue))
  }

  write_error_and_exit(
    error = 'Unsupported analysis_type',
    detail = paste('analysis_type:', method),
    suggestion = 'Use pearson, spearman, kendall, jaccard, jarrad, cosine, cos, or raw.'
  )
}

subset_matrix <- function(mat, keep_rows, hide_rows, keep_cols, hide_cols) {
  if (length(keep_rows) > 0) {
    mat <- mat[intersect(keep_rows, rownames(mat)), , drop = FALSE]
  }
  if (length(hide_rows) > 0) {
    mat <- mat[setdiff(rownames(mat), hide_rows), , drop = FALSE]
  }
  if (length(keep_cols) > 0) {
    mat <- mat[, intersect(keep_cols, colnames(mat)), drop = FALSE]
  }
  if (length(hide_cols) > 0) {
    mat <- mat[, setdiff(colnames(mat), hide_cols), drop = FALSE]
  }
  mat
}

cluster_order <- function(mat, axis = 'row') {
  target <- if (axis == 'row') mat else t(mat)
  if (nrow(target) < 2) return(rownames(target))
  target[is.na(target)] <- 0
  d <- tryCatch(stats::dist(target), error = function(e) NULL)
  if (is.null(d)) return(rownames(target))
  rownames(target)[stats::hclust(d)$order]
}

apply_ordering <- function(value, pvalue, params) {
  keep_rows <- as_string_vector(get_param(params, 'rows_keep', get_param(params, 'keep_rows', NULL)))
  hide_rows <- as_string_vector(get_param(params, 'rows_hide', get_param(params, 'hide_rows', NULL)))
  keep_cols <- as_string_vector(get_param(params, 'columns_keep', get_param(params, 'keep_columns', NULL)))
  hide_cols <- as_string_vector(get_param(params, 'columns_hide', get_param(params, 'hide_columns', NULL)))

  value <- subset_matrix(value, keep_rows, hide_rows, keep_cols, hide_cols)
  pvalue <- subset_matrix(pvalue, keep_rows, hide_rows, keep_cols, hide_cols)

  if (nrow(value) == 0 || ncol(value) == 0) {
    write_error_and_exit(
      error = 'Matrix is empty after filtering',
      detail = 'rows_keep/rows_hide/columns_keep/columns_hide removed all displayable values.',
      suggestion = 'Relax the row or column filtering parameters.'
    )
  }

  row_order <- as_string_vector(get_param(params, 'row_order', NULL))
  col_order <- as_string_vector(get_param(params, 'column_order', get_param(params, 'col_order', NULL)))

  if (length(row_order) > 0) {
    row_order <- c(intersect(row_order, rownames(value)), setdiff(rownames(value), row_order))
  } else if (as_bool(get_param(params, 'cluster_rows', FALSE))) {
    row_order <- cluster_order(value, 'row')
  } else {
    row_order <- rownames(value)
  }

  if (length(col_order) > 0) {
    col_order <- c(intersect(col_order, colnames(value)), setdiff(colnames(value), col_order))
  } else if (as_bool(get_param(params, 'cluster_columns', FALSE))) {
    col_order <- cluster_order(value, 'column')
  } else {
    col_order <- colnames(value)
  }

  list(
    value = value[row_order, col_order, drop = FALSE],
    pvalue = pvalue[row_order, col_order, drop = FALSE],
    row_order = row_order,
    column_order = col_order
  )
}

significance_label <- function(p) {
  ifelse(
    is.na(p), '',
    ifelse(p < 0.001, '***', ifelse(p < 0.01, '**', ifelse(p < 0.05, '*', '')))
  )
}

format_number <- function(x, digits) {
  ifelse(is.na(x), '', formatC(x, digits = digits, format = 'f'))
}

build_cell_label <- function(value, pvalue, params, method) {
  display_mode <- tolower(as.character(get_param(params, 'cell_text', get_param(params, 'display_numbers', 'none'))[1]))
  show_value <- as_bool(get_param(params, 'show_value', get_param(params, 'show_values', NULL)), NA)
  show_p_mark <- as_bool(get_param(params, 'show_p_mark', get_param(params, 'show_significance', NULL)), NA)
  show_pvalue <- as_bool(get_param(params, 'show_pvalue', get_param(params, 'show_p_value', NULL)), FALSE)

  if (!is.na(show_value) || !is.na(show_p_mark)) {
    show_value <- ifelse(is.na(show_value), FALSE, show_value)
    show_p_mark <- ifelse(is.na(show_p_mark), FALSE, show_p_mark)
    if (show_value && show_p_mark) display_mode <- 'value_significance'
    if (show_value && !show_p_mark && !show_pvalue) display_mode <- 'value'
    if (!show_value && show_p_mark) display_mode <- 'significance'
    if (!show_value && !show_p_mark && !show_pvalue) display_mode <- 'none'
    if (show_value && show_pvalue) display_mode <- 'value_pvalue'
    if (!show_value && show_pvalue) display_mode <- 'pvalue'
  }

  if (display_mode %in% c('yes', 'true', 'value')) display_mode <- 'value'
  if (display_mode %in% c('no', 'false', 'off')) display_mode <- 'none'
  if (display_mode == 'correlation') display_mode <- 'value'

  value_digits <- as.integer(get_param(params, 'value_digits', ifelse(method == 'raw', 2, 2)))
  pvalue_digits <- as.integer(get_param(params, 'pvalue_digits', 3))
  sig <- significance_label(pvalue)
  v <- format_number(value, value_digits)
  pv <- ifelse(is.na(pvalue), '', paste0('p=', formatC(pvalue, digits = pvalue_digits, format = 'g')))

  if (display_mode == 'none') return(rep('', length(value)))
  if (display_mode == 'pvalue') return(pv)
  if (display_mode == 'significance') return(sig)
  if (display_mode == 'value_significance') return(ifelse(nzchar(sig), paste0(v, '\n', sig), v))
  if (display_mode == 'value_pvalue') return(ifelse(nzchar(pv), paste0(v, '\n', pv), v))
  if (display_mode == 'all') {
    return(ifelse(nzchar(pv) | nzchar(sig), paste0(v, '\n', pv, ifelse(nzchar(sig), paste0('\n', sig), '')), v))
  }
  v
}

named_group_vector <- function(x, levels_needed) {
  if (is.null(x)) return(stats::setNames(rep(NA_character_, length(levels_needed)), levels_needed))
  if (is.list(x) && !is.data.frame(x)) {
    if (!is.null(names(x)) && all(nzchar(names(x)))) {
      values <- stats::setNames(as.character(unlist(x, use.names = FALSE)), names(x))
    } else {
      values <- as.character(unlist(x, use.names = FALSE))
      names(values) <- levels_needed[seq_along(values)]
    }
  } else {
    values <- as.character(x)
    if (is.null(names(values))) names(values) <- levels_needed[seq_along(values)]
  }
  out <- stats::setNames(rep(NA_character_, length(levels_needed)), levels_needed)
  out[intersect(names(values), levels_needed)] <- values[intersect(names(values), levels_needed)]
  out
}

group_color_map <- function(groups, palette_values = NULL) {
  groups <- groups[!is.na(groups) & nzchar(groups)]
  levels <- unique(groups)
  if (length(levels) == 0) return(character())

  if (!is.null(palette_values)) {
    pal <- as.character(unlist(palette_values, use.names = TRUE))
    if (!is.null(names(pal)) && all(levels %in% names(pal))) {
      return(pal[levels])
    }
  }

  colors <- grDevices::hcl.colors(length(levels), palette = 'Set 2')
  stats::setNames(colors, levels)
}

named_color_vector <- function(x, levels_needed, default_color) {
  out <- stats::setNames(rep(default_color, length(levels_needed)), levels_needed)
  if (is.null(x)) return(out)

  values <- as.character(unlist(x, use.names = TRUE))
  if (length(values) == 0) return(out)

  if (!is.null(names(values)) && any(nzchar(names(values)))) {
    hits <- intersect(names(values), levels_needed)
    out[hits] <- values[hits]
  } else {
    out[seq_len(min(length(values), length(out)))] <- values[seq_len(min(length(values), length(out)))]
  }
  out
}

make_group_tracks <- function(row_order, column_order, params) {
  row_groups <- named_group_vector(get_param(params, 'row_groups', NULL), row_order)
  col_groups <- named_group_vector(get_param(params, 'column_groups', get_param(params, 'col_groups', NULL)), column_order)
  row_colors <- group_color_map(row_groups, get_param(params, 'row_group_colors', NULL))
  col_colors <- group_color_map(col_groups, get_param(params, 'column_group_colors', get_param(params, 'col_group_colors', NULL)))

  list(
    row_groups = row_groups,
    column_groups = col_groups,
    row_colors = row_colors,
    column_colors = col_colors
  )
}

save_complex_heatmap_outputs <- function(
    value,
    pvalue,
    params,
    output_dir,
    width,
    height,
    analysis_type,
    plot_shape,
    low_color,
    mid_color,
    high_color,
    na_color,
    colorbar_title,
    show_colorbar,
    show_grid_border,
    border_color,
    border_width,
    cell_alpha,
    circle_max_size,
    cell_text_size,
    font_family,
    label_color,
    row_name_size,
    column_name_size,
    column_name_angle,
    base_text_color,
    highlight_rows,
    highlight_cols,
    highlight_color,
    show_row_names,
    show_column_names,
    show_row_dendrogram,
    show_column_dendrogram,
    cluster_rows,
    cluster_columns,
    title,
    title_show,
    title_size,
    title_color,
    title_bold,
    legend_title_size,
    legend_text_size) {
  if (!requireNamespace('ComplexHeatmap', quietly = TRUE) ||
      !requireNamespace('circlize', quietly = TRUE)) {
    write_error_and_exit(
      error = 'Dendrogram rendering requires ComplexHeatmap and circlize',
      detail = 'show_row_dendrogram/show_column_dendrogram was requested, but required packages are not installed.',
      suggestion = 'Install ComplexHeatmap and circlize, or set show_row_dendrogram/show_column_dendrogram to false.'
    )
  }

  vals <- as.numeric(value)
  vals <- vals[is.finite(vals)]
  if (length(vals) == 0) vals <- c(-1, 1)
  center_at_zero <- !(analysis_type == 'raw' && !as_bool(get_param(params, 'center_color_at_zero', TRUE), TRUE))
  if (center_at_zero) {
    max_abs <- max(abs(vals), na.rm = TRUE)
    if (!is.finite(max_abs) || max_abs == 0) max_abs <- 1
    col_fun <- circlize::colorRamp2(c(-max_abs, 0, max_abs), c(low_color, mid_color, high_color))
  } else {
    rng <- range(vals, na.rm = TRUE)
    if (!all(is.finite(rng)) || diff(rng) == 0) rng <- rng + c(-0.5, 0.5)
    col_fun <- circlize::colorRamp2(rng, c(low_color, high_color))
  }

  label_mat <- matrix(
    build_cell_label(as.vector(value), as.vector(pvalue), params, analysis_type),
    nrow = nrow(value),
    ncol = ncol(value),
    dimnames = dimnames(value)
  )
  max_abs_value <- max(abs(as.numeric(value)), na.rm = TRUE)
  if (!is.finite(max_abs_value) || max_abs_value == 0) max_abs_value <- 1

  row_label_colors <- named_color_vector(
    get_param(params, 'row_label_colors', get_param(params, 'sample_label_colors', get_param(params, 'gene_label_colors', NULL))),
    rownames(value),
    base_text_color
  )
  column_label_colors <- named_color_vector(
    get_param(params, 'column_label_colors', get_param(params, 'sample_label_colors', NULL)),
    colnames(value),
    base_text_color
  )
  row_label_colors[intersect(highlight_rows, rownames(value))] <- highlight_color
  column_label_colors[intersect(highlight_cols, colnames(value))] <- highlight_color
  row_label_faces <- ifelse(rownames(value) %in% highlight_rows, 'bold', 'plain')
  column_label_faces <- ifelse(colnames(value) %in% highlight_cols, 'bold', 'plain')

  legend_position <- as.character(get_param(params, 'legend_position', get_param(params, 'colorbar_position', 'right')))[1]
  if (!legend_position %in% c('right', 'left', 'top', 'bottom')) legend_position <- 'right'
  legend_bar_width <- as.numeric(get_param(params, 'legend_bar_width', get_param(params, 'colorbar_width', 4)))
  legend_bar_height <- as.numeric(get_param(params, 'legend_bar_height', get_param(params, 'colorbar_height', 35)))
  legend_frame_color <- as.character(get_param(params, 'legend_frame_color', NA_character_))[1]
  legend_tick_color <- as.character(get_param(params, 'legend_tick_color', '#FFFFFF'))[1]
  if (is.na(legend_bar_width) || legend_bar_width <= 0) legend_bar_width <- 4
  if (is.na(legend_bar_height) || legend_bar_height <= 0) legend_bar_height <- 35

  row_tree_color <- as.character(get_param(params, 'row_tree_color', get_param(params, 'tree_color', '#444444')))[1]
  column_tree_color <- as.character(get_param(params, 'column_tree_color', get_param(params, 'tree_color', '#444444')))[1]
  tree_line_width <- as.numeric(get_param(params, 'tree_line_width', get_param(params, 'dendrogram_line_width', 1)))
  if (is.na(tree_line_width) || tree_line_width <= 0) tree_line_width <- 1
  row_dend_width <- as.numeric(get_param(params, 'row_dendrogram_width_mm', 18))
  column_dend_height <- as.numeric(get_param(params, 'column_dendrogram_height_mm', 18))
  if (is.na(row_dend_width) || row_dend_width <= 0) row_dend_width <- 18
  if (is.na(column_dend_height) || column_dend_height <= 0) column_dend_height <- 18

  tracks <- make_group_tracks(rownames(value), colnames(value), params)
  show_row_groups <- as_bool(get_param(params, 'show_row_group_colors', TRUE), TRUE) && any(!is.na(tracks$row_groups))
  show_col_groups <- as_bool(get_param(params, 'show_column_group_colors', TRUE), TRUE) && any(!is.na(tracks$column_groups))
  show_group_names <- as_bool(get_param(params, 'show_group_names', TRUE), TRUE)
  row_group_name <- as.character(get_param(params, 'row_group_name', 'Row group'))[1]
  column_group_name <- as.character(get_param(params, 'column_group_name', 'Column group'))[1]
  group_track_size_mm <- as.numeric(get_param(params, 'group_track_size_mm', 4))
  if (is.na(group_track_size_mm) || group_track_size_mm <= 0) group_track_size_mm <- 4

  left_annotation <- NULL
  top_annotation <- NULL
  if (show_row_groups) {
    row_group_factor <- factor(tracks$row_groups, levels = names(tracks$row_colors))
    row_annotation_values <- stats::setNames(list(row_group_factor), row_group_name)
    row_annotation_colors <- stats::setNames(list(tracks$row_colors), row_group_name)
    left_annotation <- do.call(ComplexHeatmap::rowAnnotation, c(
      row_annotation_values,
      list(
      col = row_annotation_colors,
      show_annotation_name = show_group_names,
      annotation_name_gp = grid::gpar(fontsize = legend_text_size, fontfamily = font_family),
      simple_anno_size = grid::unit(group_track_size_mm, 'mm')
      )
    ))
  }
  if (show_col_groups) {
    column_group_factor <- factor(tracks$column_groups, levels = names(tracks$column_colors))
    column_annotation_values <- stats::setNames(list(column_group_factor), column_group_name)
    column_annotation_colors <- stats::setNames(list(tracks$column_colors), column_group_name)
    top_annotation <- do.call(ComplexHeatmap::HeatmapAnnotation, c(
      column_annotation_values,
      list(
      col = column_annotation_colors,
      show_annotation_name = show_group_names,
      annotation_name_gp = grid::gpar(fontsize = legend_text_size, fontfamily = font_family),
      simple_anno_size = grid::unit(group_track_size_mm, 'mm')
      )
    ))
  }

  row_split <- NULL
  column_split <- NULL
  if (as_bool(get_param(params, 'split_rows_by_group', FALSE), FALSE) && show_row_groups) {
    row_split <- factor(tracks$row_groups, levels = names(tracks$row_colors))
  }
  if (as_bool(get_param(params, 'split_columns_by_group', FALSE), FALSE) && show_col_groups) {
    column_split <- factor(tracks$column_groups, levels = names(tracks$column_colors))
  }

  cell_fun <- function(j, i, x, y, w, h, fill) {
    v <- value[i, j]
    if (is.na(v)) {
      grid::grid.rect(x, y, w, h, gp = grid::gpar(fill = na_color, col = NA, alpha = cell_alpha))
      return()
    }
    fill_col <- col_fun(v)
    if (plot_shape == 'circle') {
      size_scale <- sqrt(abs(v) / max_abs_value)
      cell_w_mm <- grid::convertWidth(w, 'mm', valueOnly = TRUE)
      cell_h_mm <- grid::convertHeight(h, 'mm', valueOnly = TRUE)
      radius_mm <- min(cell_w_mm, cell_h_mm) * 0.45 * size_scale
      grid::grid.circle(
        x,
        y,
        r = grid::unit(radius_mm, 'mm'),
        gp = grid::gpar(
          fill = fill_col,
          col = if (show_grid_border) border_color else NA,
          lwd = border_width,
          alpha = cell_alpha
        )
      )
    } else {
      grid::grid.rect(
        x,
        y,
        w,
        h,
        gp = grid::gpar(
          fill = fill_col,
          col = if (show_grid_border) border_color else NA,
          lwd = border_width,
          alpha = cell_alpha
        )
      )
    }
    if (nzchar(label_mat[i, j])) {
      grid::grid.text(
        label_mat[i, j],
        x,
        y,
        gp = grid::gpar(col = label_color, fontsize = cell_text_size * 3.2, fontfamily = font_family),
        just = 'center'
      )
    }
  }

  ht <- ComplexHeatmap::Heatmap(
    value,
    name = colorbar_title,
    col = col_fun,
    na_col = na_color,
    rect_gp = grid::gpar(type = 'none'),
    cell_fun = cell_fun,
    cluster_rows = isTRUE(cluster_rows) || isTRUE(show_row_dendrogram),
    cluster_columns = isTRUE(cluster_columns) || isTRUE(show_column_dendrogram),
    show_row_dend = isTRUE(show_row_dendrogram),
    show_column_dend = isTRUE(show_column_dendrogram),
    row_dend_gp = grid::gpar(col = row_tree_color, lwd = tree_line_width),
    column_dend_gp = grid::gpar(col = column_tree_color, lwd = tree_line_width),
    row_dend_width = grid::unit(row_dend_width, 'mm'),
    column_dend_height = grid::unit(column_dend_height, 'mm'),
    left_annotation = left_annotation,
    top_annotation = top_annotation,
    row_split = row_split,
    column_split = column_split,
    row_title_gp = grid::gpar(fontsize = row_name_size, fontfamily = font_family),
    column_title_gp = grid::gpar(fontsize = column_name_size, fontfamily = font_family),
    show_row_names = isTRUE(show_row_names),
    show_column_names = isTRUE(show_column_names),
    row_names_gp = grid::gpar(fontsize = row_name_size, col = row_label_colors, fontface = row_label_faces, fontfamily = font_family),
    column_names_gp = grid::gpar(fontsize = column_name_size, col = column_label_colors, fontface = column_label_faces, fontfamily = font_family),
    column_names_rot = column_name_angle,
    show_heatmap_legend = isTRUE(show_colorbar),
    heatmap_legend_param = list(
      title_gp = grid::gpar(fontsize = legend_title_size, fontfamily = font_family),
      labels_gp = grid::gpar(fontsize = legend_text_size, fontfamily = font_family),
      legend_width = grid::unit(legend_bar_width, 'mm'),
      legend_height = grid::unit(legend_bar_height, 'mm'),
      border = legend_frame_color,
      tick_gp = grid::gpar(col = legend_tick_color)
    )
  )

  draw_plot <- function() {
    if (title_show) {
      ComplexHeatmap::draw(
        ht,
        heatmap_legend_side = legend_position,
        column_title = title,
        column_title_gp = grid::gpar(
          fontsize = title_size,
          col = title_color,
          fontface = ifelse(title_bold, 'bold', 'plain'),
          fontfamily = font_family
        )
      )
    } else {
      ComplexHeatmap::draw(ht, heatmap_legend_side = legend_position)
    }
  }

  grDevices::svg(file.path(output_dir, 'result.svg'), width = width, height = height)
  draw_plot()
  grDevices::dev.off()

  grDevices::pdf(file.path(output_dir, 'result.pdf'), width = width, height = height)
  draw_plot()
  grDevices::dev.off()

  grDevices::png(file.path(output_dir, 'result.png'), width = width, height = height, units = 'in', res = 300)
  draw_plot()
  grDevices::dev.off()
}

if (is.null(input_file)) {
  write_error_and_exit('Missing --input argument')
}
if (is.null(params_file) || !file.exists(params_file)) {
  write_error_and_exit(
    error = 'Params file not found',
    detail = paste('Params path:', params_file),
    suggestion = 'Backend should generate params.json and pass it through --params.'
  )
}
if (is.null(output_dir)) {
  write_error_and_exit('Missing --output argument')
}
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
}

write_log('Plugin started.')

params <- tryCatch(
  jsonlite::fromJSON(params_file),
  error = function(e) {
    write_error_and_exit(
      error = 'Failed to parse params.json',
      detail = conditionMessage(e),
      suggestion = 'Please make sure params.json is valid JSON.'
    )
  }
)

input2_file <- get_param_any(params, c('input2_file', 'matrix2_file', 'second_input', 'input2'), input2_file)
two_matrix_mode <- !is.null(input2_file) && nzchar(as.character(input2_file)[1])

df <- read_table_auto(input_file)
write_log(sprintf('Loaded input table with %s rows and %s columns.', nrow(df), ncol(df)))
df2 <- NULL
if (two_matrix_mode) {
  df2 <- read_table_auto(input2_file)
  write_log(sprintf('Loaded second input table with %s rows and %s columns.', nrow(df2), ncol(df2)))
}

title <- get_param(params, 'title', 'Intragroup Correlation Analysis')
width <- as.numeric(get_param(params, 'width', 8))
height <- as.numeric(get_param(params, 'height', 7))
theme_name <- get_param(params, 'theme', 'default')
analysis_type <- normalize_method(get_param(params, 'analysis_type', get_param(params, 'method', 'pearson')))
compute_by <- tolower(as.character(get_param(params, 'compute_by', get_param(params, 'calculate_direction', 'column'))[1]))
if (compute_by %in% c('col', 'columns', 'sample', 'samples')) compute_by <- 'column'
if (compute_by %in% c('rows', 'feature', 'features')) compute_by <- 'row'
if (!compute_by %in% c('row', 'column')) {
  write_error_and_exit(
    error = 'Unsupported compute_by value',
    detail = paste('compute_by:', compute_by),
    suggestion = 'Use row or column.'
  )
}

normalization <- get_param(params, 'normalization', get_param(params, 'normalize', 'none'))
binary_threshold <- as.numeric(get_param(params, 'binary_threshold', 0))

if (two_matrix_mode) {
  mat1 <- make_numeric_matrix(df, params, 'matrix1')
  mat2 <- make_numeric_matrix(df2, params, 'matrix2')
  mat1 <- normalize_matrix_values(mat1, normalization)
  mat2 <- normalize_matrix_values(mat2, normalization)
  computed <- compute_cross_value_matrices(mat1, mat2, analysis_type, compute_by, binary_threshold)
  write_log(sprintf(
    'Two-matrix mode used %s shared %s for cross-correlation.',
    length(computed$shared_features),
    ifelse(compute_by == 'row', 'columns', 'rows')
  ))
} else {
  mat <- make_numeric_matrix(df, params)
  mat <- normalize_matrix_values(mat, normalization)
  computed <- compute_value_matrices(mat, analysis_type, compute_by, binary_threshold)
}
ordered <- apply_ordering(computed$value, computed$pvalue, params)
value <- ordered$value
pvalue <- ordered$pvalue

row_order <- rownames(value)
column_order <- colnames(value)
plot_df <- as.data.frame(as.table(value), stringsAsFactors = FALSE)
colnames(plot_df) <- c('row_name', 'column_name', 'value')
plot_df$pvalue <- as.vector(pvalue)
plot_df$row_name <- factor(plot_df$row_name, levels = rev(row_order))
plot_df$column_name <- factor(plot_df$column_name, levels = column_order)
plot_df$significance <- significance_label(plot_df$pvalue)
plot_df$label <- build_cell_label(plot_df$value, plot_df$pvalue, params, analysis_type)
plot_df$abs_value <- abs(plot_df$value)

plot_shape <- normalize_shape(get_param(params, 'plot_shape', get_param(params, 'cell_shape', 'circle')))
if (!plot_shape %in% c('circle', 'tile')) plot_shape <- 'circle'

pal <- palette_colors(params)
low_color <- pal[['low']]
mid_color <- pal[['mid']]
high_color <- pal[['high']]
na_color <- as.character(get_param(params, 'na_color', 'grey90'))[1]
colorbar_title <- as.character(get_param(params, 'colorbar_title', ifelse(analysis_type == 'raw', 'Value', 'Similarity')))[1]
colorbar_title <- as.character(get_param(params, 'legend_name', get_param(params, 'legend_title', colorbar_title)))[1]
show_colorbar <- as_bool(get_param(params, 'show_colorbar', TRUE), TRUE)
legend_position <- as.character(get_param(params, 'legend_position', get_param(params, 'colorbar_position', 'right')))[1]
if (!legend_position %in% c('right', 'left', 'top', 'bottom', 'none')) legend_position <- 'right'
legend_bar_width <- as.numeric(get_param(params, 'legend_bar_width', get_param(params, 'colorbar_width', 0.45)))
legend_bar_height <- as.numeric(get_param(params, 'legend_bar_height', get_param(params, 'colorbar_height', 3.2)))
legend_frame_color <- as.character(get_param(params, 'legend_frame_color', NA_character_))[1]
legend_tick_color <- as.character(get_param(params, 'legend_tick_color', '#FFFFFF'))[1]
show_grid_border <- as_bool(get_param(params, 'show_grid_border', get_param(params, 'cell_border', get_param(params, 'show_cell_border', FALSE))), FALSE)
border_color <- as.character(get_param(params, 'border_color', get_param(params, 'cell_border_color', 'white')))[1]
border_width <- as.numeric(get_param(params, 'border_width', get_param(params, 'cell_border_width', 0.25)))
cell_width <- scale_ui_cell_size(get_param(params, 'cell_width', get_param(params, 'cell_size', 1)), 1)
cell_height <- scale_ui_cell_size(get_param(params, 'cell_height', get_param(params, 'cell_size', 1)), 1)
cell_alpha <- as.numeric(get_param(params, 'cell_alpha', get_param(params, 'alpha', 1)))
if (is.na(cell_alpha)) cell_alpha <- 1
cell_alpha <- max(0, min(1, cell_alpha))
circle_max_size <- as.numeric(get_param(params, 'circle_max_size', get_param(params, 'cell_size', cell_width * 11)))
if (is.na(circle_max_size) || circle_max_size <= 0) circle_max_size <- 11
if (circle_max_size > 20) circle_max_size <- circle_max_size * 0.45

row_name_size <- as.numeric(get_param(params, 'row_name_size', get_param(params, 'axis_text_size', 10)))
column_name_size <- as.numeric(get_param(params, 'column_name_size', get_param(params, 'axis_text_size', 10)))
cell_text_size <- as.numeric(get_param(params, 'cell_text_size', get_param(params, 'font_size', 3)))
font_family <- as.character(get_param(params, 'font_family', ''))[1]
base_text_color <- as.character(get_param(params, 'text_color', '#000000'))[1]
row_name_italic <- as_bool(get_param(params, 'row_name_italic', FALSE), FALSE)
column_name_italic <- as_bool(get_param(params, 'column_name_italic', FALSE), FALSE)
column_name_angle <- as.numeric(get_param(params, 'column_name_angle', get_param(params, 'label_angle', 45)))
row_name_angle <- as.numeric(get_param(params, 'row_name_angle', 0))
show_row_names <- as_bool(get_param(params, 'show_row_names', TRUE), TRUE)
show_column_names <- as_bool(get_param(params, 'show_column_names', TRUE), TRUE)
title_show <- as_bool(get_param(params, 'title_show', get_param(params, 'show_title', TRUE)), TRUE)
title_size <- as.numeric(get_param(params, 'title_size', 16))
title_color <- as.character(get_param(params, 'title_color', base_text_color))[1]
title_bold <- as_bool(get_param(params, 'title_bold', TRUE), TRUE)
x_title <- as.character(get_param(params, 'x_title', get_param(params, 'x_axis_title', '')))[1]
y_title <- as.character(get_param(params, 'y_title', get_param(params, 'y_axis_title', '')))[1]
show_axis_titles <- as_bool(get_param(params, 'axis_title_show', get_param(params, 'show_axis_titles', nzchar(x_title) || nzchar(y_title))), nzchar(x_title) || nzchar(y_title))
show_x_axis <- as_bool(get_param(params, 'show_x_axis', get_param(params, 'x_axis_show', show_column_names)), show_column_names)
show_y_axis <- as_bool(get_param(params, 'show_y_axis', get_param(params, 'y_axis_show', show_row_names)), show_row_names)
axis_title_size <- as.numeric(get_param(params, 'axis_title_size', 12))
axis_title_color <- as.character(get_param(params, 'axis_title_color', base_text_color))[1]
axis_line_show <- as_bool(get_param(params, 'axis_line_show', FALSE), FALSE)
axis_line_color <- as.character(get_param(params, 'axis_line_color', '#333333'))[1]
axis_line_width <- as.numeric(get_param(params, 'axis_line_width', 0.4))
axis_tick_show <- as_bool(get_param(params, 'axis_tick_show', FALSE), FALSE)
axis_tick_color <- as.character(get_param(params, 'axis_tick_color', axis_line_color))[1]
axis_tick_width <- as.numeric(get_param(params, 'axis_tick_width', axis_line_width))
legend_title_size <- as.numeric(get_param(params, 'legend_title_size', get_param(params, 'legend_size', 12)))
legend_text_size <- as.numeric(get_param(params, 'legend_text_size', get_param(params, 'legend_size', 10)))

label_color <- as.character(get_param(params, 'cell_text_color', 'black'))[1]
highlight_rows <- as_string_vector(get_param(params, 'highlight_rows', get_param(params, 'highlight_row_names', NULL)))
highlight_cols <- as_string_vector(get_param(params, 'highlight_columns', get_param(params, 'highlight_column_names', NULL)))
highlight_color <- as.character(get_param(params, 'highlight_color', '#D73027'))[1]
show_row_dendrogram <- as_bool(get_param(params, 'show_row_dendrogram', get_param(params, 'row_dendrogram', FALSE)), FALSE)
show_column_dendrogram <- as_bool(get_param(params, 'show_column_dendrogram', get_param(params, 'column_dendrogram', FALSE)), FALSE)
cluster_rows_flag <- as_bool(get_param(params, 'cluster_rows', FALSE), FALSE)
cluster_columns_flag <- as_bool(get_param(params, 'cluster_columns', FALSE), FALSE)
if ((show_row_dendrogram || show_column_dendrogram) && !(as_bool(get_param(params, 'cluster_rows', FALSE)) || as_bool(get_param(params, 'cluster_columns', FALSE)))) {
  write_log('Dendrogram display was requested. Rows/columns with visible dendrograms will also be clustered.')
}

if (show_row_dendrogram || show_column_dendrogram) {
  svg_file <- file.path(output_dir, 'result.svg')
  pdf_file <- file.path(output_dir, 'result.pdf')
  png_file <- file.path(output_dir, 'result.png')
  figure_json_file <- file.path(output_dir, 'figure.json')

  tryCatch({
    save_complex_heatmap_outputs(
      value = value,
      pvalue = pvalue,
      params = params,
      output_dir = output_dir,
      width = width,
      height = height,
      analysis_type = analysis_type,
      plot_shape = plot_shape,
      low_color = low_color,
      mid_color = mid_color,
      high_color = high_color,
      na_color = na_color,
      colorbar_title = colorbar_title,
      show_colorbar = show_colorbar,
      show_grid_border = show_grid_border,
      border_color = border_color,
      border_width = border_width,
      cell_alpha = cell_alpha,
      circle_max_size = circle_max_size,
      cell_text_size = cell_text_size,
      font_family = font_family,
      label_color = label_color,
      row_name_size = row_name_size,
      column_name_size = column_name_size,
      column_name_angle = column_name_angle,
      base_text_color = base_text_color,
      highlight_rows = highlight_rows,
      highlight_cols = highlight_cols,
      highlight_color = highlight_color,
      show_row_names = show_row_names,
      show_column_names = show_column_names,
      show_row_dendrogram = show_row_dendrogram,
      show_column_dendrogram = show_column_dendrogram,
      cluster_rows = cluster_rows_flag,
      cluster_columns = cluster_columns_flag,
      title = title,
      title_show = title_show,
      title_size = title_size,
      title_color = title_color,
      title_bold = title_bold,
      legend_title_size = legend_title_size,
      legend_text_size = legend_text_size
    )
  }, error = function(e) {
    write_error_and_exit(
      error = 'Failed to save dendrogram heatmap outputs',
      detail = conditionMessage(e),
      suggestion = 'Check ComplexHeatmap/circlize availability, output directory permissions, and graphics device support.'
    )
  })

  figure_json <- list(
    figure_type = get_param(params, 'plugin_id', 'intragroup_correlation'),
    title = title,
    theme = theme_name,
    layout = list(width = width, height = height),
    analysis = list(
      analysis_type = analysis_type,
      compute_by = compute_by,
      input_mode = ifelse(two_matrix_mode, 'two_matrices', 'single_matrix'),
      renderer = 'complexheatmap',
      normalization = normalization,
      plot_shape = plot_shape,
      cluster_rows = cluster_rows_flag || show_row_dendrogram,
      cluster_columns = cluster_columns_flag || show_column_dendrogram,
      show_row_dendrogram = show_row_dendrogram,
      show_column_dendrogram = show_column_dendrogram
    ),
    style = list(
      title_show = title_show,
      title_size = title_size,
      title_color = title_color,
      title_bold = title_bold,
      x_title = x_title,
      y_title = y_title,
      show_x_axis = show_x_axis,
      show_y_axis = show_y_axis,
      show_axis_titles = show_axis_titles,
      font_family = font_family,
      text_color = base_text_color,
      row_name_size = row_name_size,
      column_name_size = column_name_size,
      label_angle = column_name_angle,
      axis_title_size = axis_title_size,
      axis_title_color = axis_title_color,
      axis_line_show = axis_line_show,
      axis_line_color = axis_line_color,
      axis_line_width = axis_line_width,
      axis_tick_show = axis_tick_show,
      legend_title_size = legend_title_size,
      legend_text_size = legend_text_size,
      legend_position = legend_position,
      legend_bar_width = legend_bar_width,
      legend_bar_height = legend_bar_height,
      legend_frame_color = legend_frame_color,
      legend_tick_color = legend_tick_color,
      cell_width = cell_width,
      cell_height = cell_height,
      cell_alpha = cell_alpha,
      show_grid_border = show_grid_border,
      border_color = border_color,
      border_width = border_width,
      colorbar_title = colorbar_title,
      palette_scheme = get_param(params, 'palette_scheme', get_param(params, 'color_scheme', 'custom')),
      low_color = low_color,
      mid_color = mid_color,
      high_color = high_color
    ),
    data = list(
      input_file = basename(input_file),
      input2_file = if (two_matrix_mode) basename(input2_file) else '',
      n_input_rows = nrow(df),
      n_input_columns = ncol(df),
      n_input2_rows = if (two_matrix_mode) nrow(df2) else 0,
      n_input2_columns = if (two_matrix_mode) ncol(df2) else 0,
      n_shared_features = if (two_matrix_mode) length(computed$shared_features) else 0,
      n_plot_rows = nrow(value),
      n_plot_columns = ncol(value)
    ),
    layers = list(
      list(id = 'heatmap_cells', type = plot_shape, editable = TRUE),
      list(id = 'row_dendrogram', type = 'dendrogram', editable = TRUE, visible = show_row_dendrogram),
      list(id = 'column_dendrogram', type = 'dendrogram', editable = TRUE, visible = show_column_dendrogram),
      list(id = 'cell_text', type = 'text', editable = TRUE),
      list(id = 'axis_labels', type = 'text', editable = TRUE),
      list(id = 'colorbar', type = 'legend', editable = TRUE)
    ),
    export = list(svg = 'result.svg', pdf = 'result.pdf', png = 'result.png')
  )

  writeLines(
    jsonlite::toJSON(figure_json, auto_unbox = TRUE, pretty = TRUE),
    figure_json_file
  )

  write_log('Plugin completed successfully with visible dendrogram renderer.')
  quit(status = 0)
}

p <- ggplot(plot_df, aes(x = column_name, y = row_name, fill = value))

if (plot_shape == 'circle') {
  max_abs <- max(plot_df$abs_value, na.rm = TRUE)
  if (!is.finite(max_abs) || max_abs == 0) max_abs <- 1
  p <- p +
    geom_point(
      aes(size = abs_value),
      shape = 21,
      color = ifelse(show_grid_border, border_color, 'transparent'),
      stroke = border_width,
      alpha = cell_alpha
    ) +
    scale_size_continuous(range = c(1, circle_max_size), guide = 'none')
} else {
  p <- p + geom_tile(
    color = if (show_grid_border) border_color else NA,
    linewidth = border_width,
    width = cell_width,
    height = cell_height,
    alpha = cell_alpha
  )
}

if (analysis_type == 'raw' && !as_bool(get_param(params, 'center_color_at_zero', TRUE), TRUE)) {
  p <- p + scale_fill_gradient(
    low = low_color,
    high = high_color,
    na.value = na_color,
    name = colorbar_title,
    guide = guide_colorbar(
      barwidth = grid::unit(legend_bar_width, 'cm'),
      barheight = grid::unit(legend_bar_height, 'cm'),
      frame.colour = legend_frame_color,
      ticks.colour = legend_tick_color
    )
  )
} else {
  p <- p + scale_fill_gradient2(
    low = low_color,
    mid = mid_color,
    high = high_color,
    midpoint = 0,
    na.value = na_color,
    name = colorbar_title,
    guide = guide_colorbar(
      barwidth = grid::unit(legend_bar_width, 'cm'),
      barheight = grid::unit(legend_bar_height, 'cm'),
      frame.colour = legend_frame_color,
      ticks.colour = legend_tick_color
    )
  )
}

if (any(nzchar(plot_df$label))) {
  p <- p + geom_text(aes(label = label), color = label_color, size = cell_text_size, family = font_family, lineheight = 0.9)
}

tracks <- make_group_tracks(row_order, column_order, params)
show_row_groups <- as_bool(get_param(params, 'show_row_group_colors', TRUE), TRUE) && any(!is.na(tracks$row_groups))
show_col_groups <- as_bool(get_param(params, 'show_column_group_colors', TRUE), TRUE) && any(!is.na(tracks$column_groups))

if (show_row_groups) {
  row_track_df <- data.frame(
    row_name = factor(names(tracks$row_groups), levels = rev(row_order)),
    column_name = factor('__row_group__', levels = c('__row_group__', column_order)),
    group = unname(tracks$row_groups),
    stringsAsFactors = FALSE
  )
  p <- p +
    geom_tile(
      data = row_track_df,
      aes(x = column_name, y = row_name),
      inherit.aes = FALSE,
      fill = tracks$row_colors[row_track_df$group],
      width = 0.35
    )
}

if (show_col_groups) {
  col_track_df <- data.frame(
    column_name = factor(names(tracks$column_groups), levels = column_order),
    row_name = factor('__column_group__', levels = c(rev(row_order), '__column_group__')),
    group = unname(tracks$column_groups),
    stringsAsFactors = FALSE
  )
  p <- p +
    geom_tile(
      data = col_track_df,
      aes(x = column_name, y = row_name),
      inherit.aes = FALSE,
      fill = tracks$column_colors[col_track_df$group],
      height = 0.35
    )
}

x_limits <- if (show_row_groups) c('__row_group__', column_order) else column_order
y_limits <- if (show_col_groups) c(rev(row_order), '__column_group__') else rev(row_order)
x_labels <- stats::setNames(ifelse(x_limits == '__row_group__', '', x_limits), x_limits)
y_labels <- stats::setNames(ifelse(y_limits == '__column_group__', '', y_limits), y_limits)

axis_text_x_element <- element_text(
  size = column_name_size,
  angle = column_name_angle,
  hjust = ifelse(column_name_angle == 0, 0.5, 1),
  vjust = ifelse(column_name_angle == 0, 0.5, 1),
  face = ifelse(column_name_italic, 'italic', 'plain'),
  color = base_text_color
)
axis_text_y_element <- element_text(
  size = row_name_size,
  angle = row_name_angle,
  face = ifelse(row_name_italic, 'italic', 'plain'),
  color = base_text_color
)

if (requireNamespace('ggtext', quietly = TRUE)) {
  decorate_label <- function(label, highlighted) {
    ifelse(
      label %in% highlighted,
      sprintf("<span style='color:%s;font-weight:700'>%s</span>", highlight_color, label),
      label
    )
  }
  x_labels <- stats::setNames(decorate_label(unname(x_labels), highlight_cols), names(x_labels))
  y_labels <- stats::setNames(decorate_label(unname(y_labels), highlight_rows), names(y_labels))
  axis_text_x_element <- ggtext::element_markdown(
    size = column_name_size,
    angle = column_name_angle,
    hjust = ifelse(column_name_angle == 0, 0.5, 1),
    vjust = ifelse(column_name_angle == 0, 0.5, 1),
    face = ifelse(column_name_italic, 'italic', 'plain'),
    color = base_text_color
  )
  axis_text_y_element <- ggtext::element_markdown(
    size = row_name_size,
    angle = row_name_angle,
    face = ifelse(row_name_italic, 'italic', 'plain'),
    color = base_text_color
  )
} else if (length(highlight_rows) > 0 || length(highlight_cols) > 0) {
  write_log('Package ggtext is not installed. Highlighted axis labels will use default axis text color.')
}

p <- p +
  labs(
    title = if (title_show) title else NULL,
    x = if (show_axis_titles && show_x_axis) x_title else NULL,
    y = if (show_axis_titles && show_y_axis) y_title else NULL
  ) +
  scale_x_discrete(limits = x_limits, labels = x_labels) +
  scale_y_discrete(limits = y_limits, labels = y_labels) +
  coord_fixed(clip = 'off') +
  theme_classic(base_family = font_family) +
  theme(
    plot.title = element_text(
      hjust = 0.5,
      size = title_size,
      color = title_color,
      face = ifelse(title_bold, 'bold', 'plain')
    ),
    axis.line = element_blank(),
    axis.line.x = if (axis_line_show && show_x_axis) element_line(color = axis_line_color, linewidth = axis_line_width) else element_blank(),
    axis.line.y = if (axis_line_show && show_y_axis) element_line(color = axis_line_color, linewidth = axis_line_width) else element_blank(),
    axis.ticks.x = if (axis_tick_show && show_x_axis) element_line(color = axis_tick_color, linewidth = axis_tick_width) else element_blank(),
    axis.ticks.y = if (axis_tick_show && show_y_axis) element_line(color = axis_tick_color, linewidth = axis_tick_width) else element_blank(),
    axis.title.x = if (show_axis_titles && show_x_axis) element_text(size = axis_title_size, color = axis_title_color, face = 'bold') else element_blank(),
    axis.title.y = if (show_axis_titles && show_y_axis) element_text(size = axis_title_size, color = axis_title_color, face = 'bold') else element_blank(),
    panel.border = element_blank(),
    axis.text.x = if (show_column_names && show_x_axis) axis_text_x_element else element_blank(),
    axis.text.y = if (show_row_names && show_y_axis) axis_text_y_element else element_blank(),
    legend.position = if (show_colorbar) legend_position else 'none',
    legend.title = element_text(size = legend_title_size, color = base_text_color),
    legend.text = element_text(size = legend_text_size, color = base_text_color),
    plot.margin = margin(12, 16, 16, 16)
  )

if (theme_name == 'minimal') {
  p <- p + theme_minimal(base_family = font_family)
}

svg_file <- file.path(output_dir, 'result.svg')
pdf_file <- file.path(output_dir, 'result.pdf')
png_file <- file.path(output_dir, 'result.png')
figure_json_file <- file.path(output_dir, 'figure.json')

tryCatch({
  ggsave(svg_file, p, width = width, height = height, device = grDevices::svg)
  ggsave(pdf_file, p, width = width, height = height, device = grDevices::pdf)
  ggsave(png_file, p, width = width, height = height, dpi = 300, device = grDevices::png)
}, error = function(e) {
  write_error_and_exit(
    error = 'Failed to save plot outputs',
    detail = conditionMessage(e),
    suggestion = 'Check plotting code, output directory permissions, and graphics device support.'
  )
})

figure_json <- list(
  figure_type = get_param(params, 'plugin_id', 'intragroup_correlation'),
  title = title,
  theme = theme_name,
  layout = list(width = width, height = height),
  analysis = list(
    analysis_type = analysis_type,
    compute_by = compute_by,
    input_mode = ifelse(two_matrix_mode, 'two_matrices', 'single_matrix'),
    normalization = normalization,
    plot_shape = plot_shape,
    cluster_rows = as_bool(get_param(params, 'cluster_rows', FALSE)),
    cluster_columns = as_bool(get_param(params, 'cluster_columns', FALSE)),
    show_row_dendrogram = show_row_dendrogram,
    show_column_dendrogram = show_column_dendrogram
  ),
  style = list(
    title_show = title_show,
    title_size = title_size,
      title_color = title_color,
      title_bold = title_bold,
      x_title = x_title,
      y_title = y_title,
      show_x_axis = show_x_axis,
      show_y_axis = show_y_axis,
      show_axis_titles = show_axis_titles,
      font_family = font_family,
      text_color = base_text_color,
    row_name_size = row_name_size,
    column_name_size = column_name_size,
      label_angle = column_name_angle,
      axis_title_size = axis_title_size,
      axis_title_color = axis_title_color,
      axis_line_show = axis_line_show,
      axis_line_color = axis_line_color,
      axis_line_width = axis_line_width,
      axis_tick_show = axis_tick_show,
      legend_title_size = legend_title_size,
      legend_text_size = legend_text_size,
      legend_position = legend_position,
      legend_bar_width = legend_bar_width,
      legend_bar_height = legend_bar_height,
      legend_frame_color = legend_frame_color,
      legend_tick_color = legend_tick_color,
      cell_width = cell_width,
    cell_height = cell_height,
    cell_alpha = cell_alpha,
    show_grid_border = show_grid_border,
    border_color = border_color,
    border_width = border_width,
    colorbar_title = colorbar_title,
    palette_scheme = get_param(params, 'palette_scheme', get_param(params, 'color_scheme', 'custom')),
    low_color = low_color,
    mid_color = mid_color,
    high_color = high_color
  ),
  data = list(
    input_file = basename(input_file),
    input2_file = if (two_matrix_mode) basename(input2_file) else '',
    n_input_rows = nrow(df),
    n_input_columns = ncol(df),
    n_input2_rows = if (two_matrix_mode) nrow(df2) else 0,
    n_input2_columns = if (two_matrix_mode) ncol(df2) else 0,
    n_shared_features = if (two_matrix_mode) length(computed$shared_features) else 0,
    n_plot_rows = nrow(value),
    n_plot_columns = ncol(value)
  ),
  layers = list(
    list(id = 'heatmap_cells', type = plot_shape, editable = TRUE),
    list(id = 'cell_text', type = 'text', editable = TRUE),
    list(id = 'axis_labels', type = 'text', editable = TRUE),
    list(id = 'colorbar', type = 'legend', editable = TRUE)
  ),
  export = list(svg = 'result.svg', pdf = 'result.pdf', png = 'result.png')
)

writeLines(
  jsonlite::toJSON(figure_json, auto_unbox = TRUE, pretty = TRUE),
  figure_json_file
)

write_log('Plugin completed successfully.')
quit(status = 0)
