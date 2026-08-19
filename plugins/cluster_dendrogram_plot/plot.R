#!/usr/bin/env Rscript

# BioFigureAI Plot Plugin: Cluster Dendrogram Plot
# ------------------------------------------------------------
# Wraps the SCA Seuclu2Denplot.R workflow (Seuclu2Denplot + plot.den.cols)
# for CSV/CLI inputs (no Seurat required).
#
# Runtime contract:
#   Rscript plot.R --input expression.csv --annot metadata.csv \
#                  --params params.json --output output_dir
#
# Workflow:
#   1. Read expression matrix (features x cells) and cell metadata.
#   2. Intersect cells between expression and annotation.
#   3. Apply samples_include/exclude and clusters_include/exclude filters.
#   4. For each sample, compute per-cluster average expression (rowMeans),
#      name columns "<sample>_subCluster_<cluster>".
#   5. Full-join across samples by feature id (fill 0).
#   6. Build annotation data frame (Sample_Group, cellCluster, Sample).
#   7. Apply features_include/exclude on matrix rows.
#   8. Call plot.den.cols() to draw the dendrogram + group color bar + labels.
#   9. Save svg/pdf/png, write matrix_used.csv, annotation_used.csv, figure.json.

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
  library(grid)
})

option_list <- list(
  make_option(c('--input'), type = 'character', default = NULL,
              help = 'Expression matrix CSV/TSV/TXT. First column = feature/gene id; remaining columns = cells.'),
  make_option(c('--annot'), type = 'character', default = NULL,
              help = 'Cell metadata CSV/TSV/TXT. First column = cell id; must contain sample and cluster columns.'),
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

# ----------------------------------------------------------------------------
# Standard helpers (copied from den_plot/plot.R)
# ----------------------------------------------------------------------------

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

as_numeric_vector <- function(x, default = numeric()) {
  if (is.null(x)) return(default)
  if (is.list(x) && !is.data.frame(x)) x <- unlist(x, use.names = FALSE)
  if (length(x) == 1 && is.character(x) && grepl(',', x, fixed = TRUE)) x <- strsplit(x, ',', fixed = TRUE)[[1]]
  vals <- suppressWarnings(as.numeric(x))
  vals[is.finite(vals)]
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

validate_columns <- function(df, cols, label = 'table') {
  missing <- setdiff(cols, colnames(df))
  if (length(missing) > 0) {
    write_error_and_exit(
      paste('Missing required column(s) in', label),
      paste('Missing:', paste(missing, collapse = ', ')),
      paste('Check', label, 'headers or set the matching *_column param in params.json.')
    )
  }
  invisible(TRUE)
}

# ----------------------------------------------------------------------------
# Plot saving (svg/pdf/png with retry)
# ----------------------------------------------------------------------------

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

# ----------------------------------------------------------------------------
# Reference SCA helper loading
# ----------------------------------------------------------------------------

load_reference_helpers <- function() {
  script_arg <- grep('^--file=', commandArgs(FALSE), value = TRUE)
  script_path <- if (length(script_arg) > 0) sub('^--file=', '', script_arg[1]) else file.path(getwd(), 'plugins', 'cluster_dendrogram_plot', 'plot.R')
  helper_dir <- file.path(dirname(normalizePath(script_path, mustWork = FALSE)), 'reference_sca_helpers')
  if (!dir.exists(helper_dir)) helper_dir <- file.path('plugins', 'cluster_dendrogram_plot', 'reference_sca_helpers')
  # Provide load_pkgs in the global env so the sourced helper can use it.
  load_pkgs <<- function(pkgs) {
    missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
    if (length(missing) > 0) stop('Missing required R package(s): ', paste(missing, collapse = ', '), call. = FALSE)
    invisible(lapply(pkgs, library, character.only = TRUE))
  }
  source(file.path(helper_dir, 'Seuclu2Denplot.R'), local = .GlobalEnv)
  invisible(TRUE)
}

# ----------------------------------------------------------------------------
# Core workflow: per-sample cluster averaging + cross-sample join
# ----------------------------------------------------------------------------

read_expression_matrix <- function(params) {
  if (is.null(input_file)) write_error_and_exit('Missing --input argument')
  df <- read_table_auto(input_file)
  feature_id_col <- get_param_any(params,
                                 c('feature_id_column', 'feature_column', 'row_id_column', 'id_column'),
                                 colnames(df)[1])
  if (!feature_id_col %in% colnames(df)) {
    write_error_and_exit('Feature id column not found',
                         paste('Missing:', feature_id_col),
                         'Set feature_id_column to a valid expression row-id column.')
  }
  feature_ids <- make.unique(as.character(df[[feature_id_col]]))
  cell_cols <- setdiff(colnames(df), feature_id_col)
  if (length(cell_cols) < 2) {
    write_error_and_exit('Not enough cell columns in expression matrix',
                         paste('Detected cell columns:', paste(cell_cols, collapse = ', ')),
                         'Expression matrix must have a feature id column plus >=2 cell columns.')
  }
  mat_df <- df[, cell_cols, drop = FALSE]
  mat <- suppressWarnings(as.matrix(data.frame(lapply(mat_df, as.numeric), check.names = FALSE)))
  rownames(mat) <- feature_ids
  colnames(mat) <- cell_cols
  # Replace NA/Inf with 0 (mirrors the original Seuclu2Denplot behavior).
  mat[is.na(mat)] <- 0
  mat[!is.finite(mat)] <- 0
  mat
}

read_cell_metadata <- function(params, mat) {
  if (is.null(annot_file)) {
    write_error_and_exit('Missing --annot argument',
                         'cluster_dendrogram_plot requires cell metadata with sample and cluster columns.',
                         'Provide a CSV/TSV/TXT via --annot.')
  }
  annot <- read_table_auto(annot_file)
  cell_id_col <- get_param_any(params,
                              c('cell_id_column', 'cell_column', 'id_column'),
                              colnames(annot)[1])
  if (!cell_id_col %in% colnames(annot)) {
    write_error_and_exit('Cell id column not found in annotation',
                         paste('Missing:', cell_id_col),
                         'Set cell_id_column to a valid annotation cell-id column.')
  }
  annot[[cell_id_col]] <- as.character(annot[[cell_id_col]])

  sample_col <- get_param_any(params,
                             c('sample_column', 'sample_col'),
                             NULL)
  if (is.null(sample_col)) {
    sample_col <- first_existing_col(annot,
                                     c('sample', 'Sample', 'sample_id', 'orig.ident', 'orig.ident.1'),
                                     TRUE, 'sample_column')
  }
  validate_columns(annot, sample_col, 'annotation')

  cluster_col <- get_param_any(params,
                              c('cluster_column', 'cluster_col'),
                              NULL)
  if (is.null(cluster_col)) {
    cluster_col <- first_existing_col(annot,
                                      c('seurat_clusters', 'cluster', 'Cluster', 'cell_type', 'celltype', 'leiden'),
                                      TRUE, 'cluster_column')
  }
  validate_columns(annot, cluster_col, 'annotation')

  annot[[sample_col]] <- as.character(annot[[sample_col]])
  annot[[cluster_col]] <- as.character(annot[[cluster_col]])
  attr(annot, 'cell_id_col') <- cell_id_col
  attr(annot, 'sample_col') <- sample_col
  attr(annot, 'cluster_col') <- cluster_col
  annot
}

filter_annotation <- function(annot, params) {
  sample_col <- attr(annot, 'sample_col')
  cluster_col <- attr(annot, 'cluster_col')

  samples_include <- as_string_vector(get_param_any(params, c('samples_include', 'sample_include'), NULL))
  samples_exclude <- as_string_vector(get_param_any(params, c('samples_exclude', 'sample_exclude'), NULL))
  clusters_include <- as_string_vector(get_param_any(params, c('clusters_include', 'cluster_include'), NULL))
  clusters_exclude <- as_string_vector(get_param_any(params, c('clusters_exclude', 'cluster_exclude'), NULL))

  keep <- rep(TRUE, nrow(annot))
  if (length(samples_include) > 0)  keep <- keep & (annot[[sample_col]] %in% samples_include)
  if (length(samples_exclude) > 0)  keep <- keep & !(annot[[sample_col]] %in% samples_exclude)
  if (length(clusters_include) > 0) keep <- keep & (annot[[cluster_col]] %in% clusters_include)
  if (length(clusters_exclude) > 0) keep <- keep & !(annot[[cluster_col]] %in% clusters_exclude)
  annot[keep, , drop = FALSE]
}

build_sample_cluster_matrix <- function(mat, annot, params) {
  cell_id_col <- attr(annot, 'cell_id_col')
  sample_col <- attr(annot, 'sample_col')
  cluster_col <- attr(annot, 'cluster_col')

  # Intersect cells between expression columns and annotation cell ids.
  expr_cells <- colnames(mat)
  annot_cells <- annot[[cell_id_col]]
  common_cells <- intersect(expr_cells, annot_cells)
  if (length(common_cells) < 2) {
    write_error_and_exit('Not enough overlapping cells between expression and annotation',
                         paste('Overlap:', length(common_cells), 'cells'),
                         'Ensure expression column names match annotation cell ids.')
  }
  write_log(sprintf('Cells matched between expression and annotation: %d / %d expression cells, %d annotation cells.',
                    length(common_cells), length(expr_cells), length(annot_cells)))

  # Subset annotation to common cells and deduplicate (keep first occurrence).
  annot <- annot[match(common_cells, annot_cells), , drop = FALSE]
  dup <- duplicated(annot[[cell_id_col]])
  if (any(dup)) {
    write_log(sprintf('Dropped %d duplicated annotation rows.', sum(dup)))
    annot <- annot[!dup, , drop = FALSE]
  }
  # Subset expression matrix to the (now unique) annotation cell ids.
  mat <- mat[, annot[[cell_id_col]], drop = FALSE]

  samples <- unique(annot[[sample_col]])
  samples <- samples[nzchar(samples)]
  if (length(samples) < 2) {
    write_error_and_exit('Need at least 2 samples to build a sample-cluster dendrogram',
                         paste('Detected samples:', paste(samples, collapse = ', ')),
                         'Provide an annotation with >=2 distinct sample values, or relax samples_include/exclude.')
  }

  # Per-sample per-cluster average expression (rowMeans of the sub-matrix).
  per_sample_cols <- list()
  for (smpl in samples) {
    smpl_rows <- which(annot[[sample_col]] == smpl)
    if (length(smpl_rows) == 0) next
    smpl_annot <- annot[smpl_rows, , drop = FALSE]
    smpl_cells <- smpl_annot[[cell_id_col]]
    smpl_clusters <- smpl_annot[[cluster_col]]
    clusters_in_sample <- unique(smpl_clusters)
    for (clu in clusters_in_sample) {
      clu_cells <- smpl_cells[smpl_clusters == clu]
      clu_cells <- intersect(clu_cells, colnames(mat))
      if (length(clu_cells) == 0) next
      sub <- mat[, clu_cells, drop = FALSE]
      avg <- if (ncol(sub) > 1) rowMeans(sub, na.rm = TRUE) else as.numeric(sub[, 1])
      avg[is.na(avg)] <- 0
      avg[!is.finite(avg)] <- 0
      col_name <- paste0(smpl, '_subCluster_', clu)
      per_sample_cols[[col_name]] <- avg
    }
  }

  if (length(per_sample_cols) < 2) {
    write_error_and_exit('Not enough sample-cluster profiles to build a dendrogram',
                         paste('Built', length(per_sample_cols), 'profiles'),
                         'Need >=2 sample-cluster combinations; check sample/cluster filters.')
  }

  # Build a data frame keyed by feature id, full-join across samples (fill 0).
  feature_ids <- rownames(mat)
  joined <- data.frame(rn = feature_ids, stringsAsFactors = FALSE)
  for (nm in names(per_sample_cols)) {
    vec <- per_sample_cols[[nm]]
    joined[[nm]] <- vec[match(feature_ids, names(vec))]
  }
  # Fill NA/Inf with 0 (mirrors original full_join + replace behavior).
  for (nm in names(per_sample_cols)) {
    joined[[nm]][is.na(joined[[nm]])] <- 0
    joined[[nm]][!is.finite(joined[[nm]])] <- 0
  }
  rownames(joined) <- joined$rn
  joined$rn <- NULL

  # Apply features_include/exclude on matrix rows.
  features_include <- as_string_vector(get_param_any(params, c('features_include', 'rows_include'), NULL))
  features_exclude <- as_string_vector(get_param_any(params, c('features_exclude', 'rows_exclude'), NULL))
  if (length(features_include) > 0) joined <- joined[intersect(features_include, rownames(joined)), , drop = FALSE]
  if (length(features_exclude) > 0) joined <- joined[setdiff(rownames(joined), features_exclude), , drop = FALSE]
  if (nrow(joined) < 1) {
    write_error_and_exit('No features left after filtering',
                         '', 'Relax features_include/features_exclude or check feature ids.')
  }

  # Build annotation data frame: split colnames by "_subCluster_".
  col_nms <- colnames(joined)
  parts <- strsplit(col_nms, '_subCluster_', fixed = TRUE)
  Sample_Group <- vapply(parts, function(p) p[1], character(1))
  cellCluster <- vapply(parts, function(p) if (length(p) >= 2) p[2] else '', character(1))
  samp_meta <- data.frame(
    Sample_Group = Sample_Group,
    cellCluster = cellCluster,
    Sample = col_nms,
    stringsAsFactors = FALSE
  )

  list(matrix = joined, annotation = samp_meta,
       samples = samples, clusters = unique(annot[[cluster_col]]))
}

# ----------------------------------------------------------------------------
# Plot assembly
# ----------------------------------------------------------------------------

make_dendrogram_plot <- function(mat, annot_df, params, sample_col_name) {
  distance_method <- get_param_any(params, c('distance_method', 'dist_mtd'), 'euclidean')
  cluster_method  <- get_param_any(params, c('cluster_method', 'clu_mtd'), 'average')
  title <- get_param(params, 'title', 'Dendrogram for clusters in samples')
  title_show <- as_bool(get_param(params, 'title_show', TRUE), TRUE)
  if (!title_show) title <- ''

  group_colors <- as_named_vector(get_param_any(params, c('group_colors', 'group_color_map'), NULL), default = NULL)
  label_colors <- as_named_vector(get_param_any(params, c('x_text_colors', 'sample_label_colors'), NULL), default = NULL)

  x_text_color_by <- tolower(as.character(get_param_any(params, c('x_text_color_by', 'x_text_color_col_by'), 'none'))[1])
  if (!x_text_color_by %in% c('none', 'sample', 'cluster')) x_text_color_by <- 'none'
  x_text_color_col <- switch(
    x_text_color_by,
    none = NULL,
    sample = 'Sample_Group',
    cluster = 'cellCluster'
  )
  x_text_legend_title <- get_param(params, 'x_text_legend_title', NULL)
  if (is.null(x_text_legend_title)) {
    x_text_legend_title <- switch(
      x_text_color_by,
      none = NULL,
      sample = sample_col_name,
      cluster = get_param_any(params, c('cluster_column', 'cluster_col'), 'cluster')
    )
  }

  legend_title <- get_param(params, 'legend_title', sample_col_name)
  legend_size  <- num_param(params, 'legend_size', 8)
  legend_title_size <- num_param(params, 'legend_title_size', NA_real_)
  legend_text_size  <- num_param(params, 'legend_text_size', NA_real_)

  p <- plot.den.cols(
    mtx              = as.matrix(mat),
    annot            = annot_df,
    sample_col       = 'Sample',
    group_col        = 'Sample_Group',
    dist_mtd         = distance_method,
    clu_mtd          = cluster_method,
    title            = title,
    tile_height_ratio = num_param(params, 'tile_height_ratio', 0.05),
    label_size       = num_param(params, 'label_size', num_param(params, 'x_text_size', 4)),
    legend_size      = legend_size,
    legend_title     = legend_title,
    legend_position  = get_param(params, 'legend_position', 'right'),
    group_colors     = group_colors,
    point_size       = num_param(params, 'point_size', 4),
    x_text_angle     = num_param(params, 'x_text_angle', 90),
    x_text_hjust     = num_param(params, 'x_text_hjust', 1),
    x_text_vjust     = num_param(params, 'x_text_vjust', 0.5),
    x_text_color_col = x_text_color_col,
    x_text_colors    = label_colors,
    show_x_text_legend = as_bool(get_param(params, 'show_x_text_legend', TRUE), TRUE),
    x_text_legend_title = x_text_legend_title
  )

  # Optional legend title/text size overrides via plot_annotation theme.
  if (is.finite(legend_title_size) || is.finite(legend_text_size)) {
    th <- list()
    if (is.finite(legend_title_size)) th$legend.title <- ggplot2::element_text(size = legend_title_size)
    if (is.finite(legend_text_size))  th$legend.text  <- ggplot2::element_text(size = legend_text_size)
    p <- p + patchwork::plot_annotation(theme = do.call(ggplot2::theme, th))
  }

  p
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

main <- function() {
  if (is.null(input_file)) write_error_and_exit('Missing --input argument')
  if (is.null(annot_file)) write_error_and_exit('Missing --annot argument',
                                                'cluster_dendrogram_plot requires cell metadata.',
                                                'Provide --annot metadata.csv.')
  if (is.null(params_file) || !file.exists(params_file)) write_error_and_exit('Params file not found', paste('Params path:', params_file), 'Provide params.json.')
  if (is.null(output_dir)) write_error_and_exit('Missing --output argument')
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  old_outputs <- file.path(output_dir, c('error.json', 'result.svg', 'result.pdf', 'result.png', 'figure.json', 'run.log', 'matrix_used.csv', 'annotation_used.csv'))
  old_outputs <- old_outputs[file.exists(old_outputs)]
  if (length(old_outputs) > 0) unlink(old_outputs)

  write_log('Starting cluster_dendrogram_plot plugin.')

  params <- jsonlite::fromJSON(params_file, simplifyVector = FALSE)

  load_reference_helpers()

  expr_mat <- read_expression_matrix(params)
  annot <- read_cell_metadata(params, expr_mat)
  annot <- filter_annotation(annot, params)

  built <- build_sample_cluster_matrix(expr_mat, annot, params)
  mat <- built$matrix
  annot_df <- built$annotation
  sample_col_name <- attr(annot, 'sample_col')

  write_log(sprintf('Built sample-cluster matrix: %d features x %d profiles across %d samples.',
                    nrow(mat), ncol(mat), length(built$samples)))

  p <- make_dendrogram_plot(mat, annot_df, params, sample_col_name)

  utils::write.csv(as.data.frame(mat), file.path(output_dir, 'matrix_used.csv'), row.names = TRUE)
  utils::write.csv(annot_df, file.path(output_dir, 'annotation_used.csv'), row.names = FALSE)

  width  <- num_param(params, 'width', 9)
  height <- num_param(params, 'height', 6)
  dpi    <- num_param(params, 'dpi', 300)
  save_plot(p, output_dir, width, height, dpi)

  figure <- list(
    plot_type = 'cluster_dendrogram_plot',
    source_engine = 'SCA::Seuclu2Denplot.R',
    input_file = normalizePath(input_file, mustWork = FALSE),
    annotation_file = normalizePath(annot_file, mustWork = FALSE),
    n_features = nrow(mat),
    n_samples = length(built$samples),
    n_clusters = length(built$clusters),
    n_profiles = ncol(mat),
    samples = built$samples,
    clusters = built$clusters,
    profiles = colnames(mat),
    style = list(
      distance_method = get_param_any(params, c('distance_method', 'dist_mtd'), 'euclidean'),
      cluster_method  = get_param_any(params, c('cluster_method', 'clu_mtd'), 'average'),
      title = get_param(params, 'title', 'Dendrogram for clusters in samples'),
      tile_height_ratio = num_param(params, 'tile_height_ratio', 0.05),
      point_size = num_param(params, 'point_size', 4),
      label_size = num_param(params, 'label_size', num_param(params, 'x_text_size', 4)),
      legend_position = get_param(params, 'legend_position', 'right'),
      x_text_color_by = tolower(as.character(get_param_any(params, c('x_text_color_by', 'x_text_color_col_by'), 'none'))[1])
    ),
    outputs = list(
      svg = 'result.svg',
      pdf = 'result.pdf',
      png = 'result.png',
      matrix_used = 'matrix_used.csv',
      annotation_used = 'annotation_used.csv',
      log = 'run.log'
    )
  )
  writeLines(jsonlite::toJSON(figure, auto_unbox = TRUE, pretty = TRUE), file.path(output_dir, 'figure.json'))
  write_log('Completed cluster_dendrogram_plot plugin.')
}

tryCatch(main(), error = function(e) {
  write_error_and_exit('cluster_dendrogram_plot failed', conditionMessage(e), 'Check expression/annotation columns and params.json.')
})