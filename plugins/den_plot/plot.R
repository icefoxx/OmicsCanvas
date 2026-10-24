#!/usr/bin/env Rscript

# BioFigureAI Plot Plugin: Den Plot
# ------------------------------------------------------------
# Runtime contract:
#   Rscript plot.R --input matrix.csv --annot annotation.csv --params params.json --output output_dir
#
# Current plot_kind:
#   column_dendrogram: standardized wrapper for SCA common.plots.R::plot.den.cols()

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
  library(grid)
})

option_list <- list(
  make_option(c('--input'), type = 'character', default = NULL,
              help = 'Matrix CSV/TSV/TXT. First column is row/feature id by default; remaining columns are samples.'),
  make_option(c('--annot'), type = 'character', default = NULL,
              help = 'Optional sample annotation CSV/TSV/TXT with sample and group columns.'),
  make_option(c('--params'), type = 'character', default = NULL,
              help = 'Path to params.json.'),
  make_option(c('--output'), type = 'character', default = NULL,
              help = 'Output directory.')
)

opt <- parse_args(OptionParser(option_list = option_list))
input_file <- opt$input
annot_file <- opt$annot
params_file <- opt$params
output_dir <- opt$output

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

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

first_existing_col <- function(df, candidates, required = TRUE, label = 'column') {
  hit <- candidates[candidates %in% colnames(df)][1]
  if (!is.na(hit)) return(hit)
  if (required) {
    write_error_and_exit('Could not detect required column', paste(label, 'candidates:', paste(candidates, collapse = ', ')), paste('Provide', label, 'in params.json.'))
  }
  NULL
}

load_common_reference <- function() {
  script_arg <- grep('^--file=', commandArgs(FALSE), value = TRUE)
  script_path <- if (length(script_arg) > 0) sub('^--file=', '', script_arg[1]) else file.path(getwd(), 'plugins', 'den_plot', 'plot.R')
  # Shared SCA helper library (one canonical copy for all plugins): <repo>/R/sca
  helper_dir <- file.path(dirname(normalizePath(script_path, mustWork = FALSE)), '..', '..', 'R', 'sca')
  if (!dir.exists(helper_dir)) helper_dir <- file.path('R', 'sca')
  load_pkgs <<- function(pkgs) {
    missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
    if (length(missing) > 0) stop('Missing required R package(s): ', paste(missing, collapse = ', '), call. = FALSE)
    invisible(lapply(pkgs, library, character.only = TRUE))
  }
  source(file.path(helper_dir, 'common.plots.R'), local = .GlobalEnv)
  invisible(TRUE)
}

table_to_matrix <- function(df, params) {
  row_id_col <- get_param_any(params, c('row_id_column', 'feature_column', 'id_column'), colnames(df)[1])
  if (!row_id_col %in% colnames(df)) {
    write_error_and_exit('Row id column not found', paste('Missing:', row_id_col), 'Set row_id_column to a valid matrix row-id column.')
  }
  sample_include <- as_string_vector(get_param_any(params, c('sample_columns', 'columns_include', 'samples_include'), NULL))
  sample_exclude <- as_string_vector(get_param_any(params, c('columns_exclude', 'samples_exclude'), NULL))
  candidates <- setdiff(colnames(df), row_id_col)
  if (length(sample_include) > 0) candidates <- intersect(sample_include, candidates)
  if (length(sample_exclude) > 0) candidates <- setdiff(candidates, sample_exclude)
  if (length(candidates) < 2) {
    write_error_and_exit('Not enough sample columns', paste('Detected sample columns:', paste(candidates, collapse = ', ')), 'Select at least two numeric sample columns.')
  }
  mat_df <- df[, candidates, drop = FALSE]
  mat <- suppressWarnings(as.matrix(data.frame(lapply(mat_df, as.numeric), check.names = FALSE)))
  rownames(mat) <- make.unique(as.character(df[[row_id_col]]))
  colnames(mat) <- candidates
  keep <- rowSums(is.finite(mat)) == ncol(mat)
  if (!all(keep)) {
    write_log(paste('Dropping rows with NA/Inf values:', sum(!keep)))
    mat <- mat[keep, , drop = FALSE]
  }
  rows_include <- as_string_vector(get_param_any(params, c('rows_include', 'features_include'), NULL))
  rows_exclude <- as_string_vector(get_param_any(params, c('rows_exclude', 'features_exclude'), NULL))
  if (length(rows_include) > 0) mat <- mat[intersect(rows_include, rownames(mat)), , drop = FALSE]
  if (length(rows_exclude) > 0) mat <- mat[setdiff(rownames(mat), rows_exclude), , drop = FALSE]
  if (nrow(mat) < 1) write_error_and_exit('No matrix rows left after filtering', '', 'Relax rows_include/rows_exclude or check row IDs.')
  mat
}

build_annotation <- function(mat, params) {
  sample_col <- get_param_any(params, c('sample_col', 'sample_column'), 'sample')
  group_col <- get_param_any(params, c('group_col', 'group_column'), 'celltype')
  if (!is.null(annot_file)) {
    annot <- read_table_auto(annot_file)
  } else if (!is.null(get_param(params, 'annotation', NULL))) {
    annot <- as.data.frame(get_param(params, 'annotation'), stringsAsFactors = FALSE)
  } else {
    group_assignments <- as_named_vector(get_param_any(params, c('group_assignments', 'sample_groups'), NULL), default = NULL)
    annot <- data.frame(sample = colnames(mat), celltype = 'All', stringsAsFactors = FALSE)
    if (!is.null(group_assignments)) {
      hits <- intersect(annot$sample, names(group_assignments))
      annot$celltype[match(hits, annot$sample)] <- group_assignments[hits]
    }
  }
  if (!sample_col %in% colnames(annot)) {
    sample_guess <- first_existing_col(annot, c('sample', 'Sample', 'sample_id', 'id', colnames(annot)[1]), TRUE, 'sample_column')
    annot[[sample_col]] <- annot[[sample_guess]]
  }
  if (!group_col %in% colnames(annot)) {
    group_guess <- first_existing_col(annot, c('celltype', 'group', 'Group', 'condition', 'cluster'), FALSE, 'group_column')
    annot[[group_col]] <- if (!is.null(group_guess)) annot[[group_guess]] else 'All'
  }
  missing_samples <- setdiff(colnames(mat), annot[[sample_col]])
  if (length(missing_samples) > 0) {
    add <- data.frame(
      sample = missing_samples,
      celltype = 'Unknown',
      stringsAsFactors = FALSE
    )
    colnames(add) <- c(sample_col, group_col)
    annot <- rbind(annot[, unique(c(sample_col, group_col, colnames(annot))), drop = FALSE], add)
  }
  annot
}

apply_common_style <- function(p, params) {
  title_size <- num_param(params, 'title_size', NA_real_)
  if (is.finite(title_size)) {
    p <- p + plot_annotation(theme = theme(plot.title = element_text(size = title_size)))
  }
  p
}

make_column_dendrogram <- function(mat, annot, params) {
  sample_col <- get_param_any(params, c('sample_col', 'sample_column'), 'sample')
  group_col <- get_param_any(params, c('group_col', 'group_column'), 'celltype')
  group_colors <- as_named_vector(get_param_any(params, c('group_colors', 'group_color_map'), NULL), default = NULL)
  label_colors <- as_named_vector(get_param_any(params, c('x_text_colors', 'label_colors', 'sample_label_colors'), NULL), default = NULL)

  p <- plot.den.cols(
    mtx = mat,
    annot = annot,
    sample_col = sample_col,
    group_col = group_col,
    dist_mtd = get_param_any(params, c('dist_mtd', 'distance_method'), 'euclidean'),
    clu_mtd = get_param_any(params, c('clu_mtd', 'cluster_method'), 'average'),
    title = get_param(params, 'title', 'Clustering Dendrogram'),
    tile_height_ratio = num_param(params, 'tile_height_ratio', 0.05),
    label_size = num_param(params, 'label_size', num_param(params, 'x_text_size', 4)),
    legend_size = num_param(params, 'legend_size', 8),
    legend_title = get_param(params, 'legend_title', group_col),
    legend_position = get_param(params, 'legend_position', 'right'),
    group_colors = group_colors,
    point_size = num_param(params, 'point_size', 4),
    x_text_angle = num_param(params, 'x_text_angle', 90),
    x_text_hjust = num_param(params, 'x_text_hjust', 1),
    x_text_vjust = num_param(params, 'x_text_vjust', 0.5),
    x_text_color_col = get_param_any(params, c('x_text_color_col', 'sample_label_color_column'), NULL),
    x_text_colors = label_colors,
    show_x_text_legend = as_bool(get_param(params, 'show_x_text_legend', TRUE), TRUE),
    x_text_legend_title = get_param(params, 'x_text_legend_title', NULL)
  )

  apply_common_style(p, params)
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
  draw_with_retry(function(w, h) (if (requireNamespace('ragg', quietly = TRUE)) ragg::agg_png else function(...) grDevices::png(..., type = 'cairo'))(file.path(output_dir, 'result.png'), width = w, height = h, units = 'in', res = dpi))
}

main <- function() {
  if (is.null(input_file)) write_error_and_exit('Missing --input argument')
  if (is.null(params_file) || !file.exists(params_file)) write_error_and_exit('Params file not found', paste('Params path:', params_file), 'Provide params.json.')
  if (is.null(output_dir)) write_error_and_exit('Missing --output argument')
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  old_outputs <- file.path(output_dir, c('error.json', 'result.svg', 'result.pdf', 'result.png', 'figure.json', 'selected_rows.csv', 'run.log', 'matrix_used.csv', 'annotation_used.csv'))
  old_outputs <- old_outputs[file.exists(old_outputs)]
  if (length(old_outputs) > 0) unlink(old_outputs)
  write_log('Starting den plot plugin.')

  params <- jsonlite::fromJSON(params_file, simplifyVector = FALSE)
  plot_kind <- tolower(as.character(get_param_any(params, c('plot_kind', 'plot_type'), 'column_dendrogram'))[1])
  if (!plot_kind %in% c('column_dendrogram', 'dendrogram', 'sample_dendrogram', 'plot.den.cols')) {
    write_error_and_exit('Unsupported plot_kind', paste('plot_kind:', plot_kind), 'Currently supported: column_dendrogram.')
  }

  load_common_reference()
  df <- read_table_auto(input_file)
  mat <- table_to_matrix(df, params)
  annot <- build_annotation(mat, params)
  p <- make_column_dendrogram(mat, annot, params)

  utils::write.csv(as.data.frame(mat), file.path(output_dir, 'matrix_used.csv'), row.names = TRUE)
  utils::write.csv(annot, file.path(output_dir, 'annotation_used.csv'), row.names = FALSE)
  width <- num_param(params, 'width', 9)
  height <- num_param(params, 'height', 5.8)
  dpi <- num_param(params, 'dpi', 300)
  save_plot(p, output_dir, width, height, dpi)

  figure <- list(
    plot_type = 'den_plot',
    plot_kind = plot_kind,
    input_file = normalizePath(input_file, mustWork = FALSE),
    annotation_file = if (!is.null(annot_file)) normalizePath(annot_file, mustWork = FALSE) else NULL,
    n_rows = nrow(mat),
    n_samples = ncol(mat),
    samples = colnames(mat),
    style = list(
      distance_method = get_param_any(params, c('dist_mtd', 'distance_method'), 'euclidean'),
      cluster_method = get_param_any(params, c('clu_mtd', 'cluster_method'), 'average'),
      title = get_param(params, 'title', 'Clustering Dendrogram'),
      point_size = num_param(params, 'point_size', 4),
      label_size = num_param(params, 'label_size', num_param(params, 'x_text_size', 4)),
      legend_position = get_param(params, 'legend_position', 'right')
    ),
    outputs = list(svg = 'result.svg', pdf = 'result.pdf', png = 'result.png', matrix_used = 'matrix_used.csv', annotation_used = 'annotation_used.csv', log = 'run.log')
  )
  writeLines(jsonlite::toJSON(figure, auto_unbox = TRUE, pretty = TRUE), file.path(output_dir, 'figure.json'))
  write_log('Completed den plot plugin.')
}

tryCatch(main(), error = function(e) {
  write_error_and_exit('Common plots failed', conditionMessage(e), 'Check matrix/annotation columns and params.json.')
})
