#!/usr/bin/env Rscript

# BioFigureAI Plot Plugin: Dot Plot
# ------------------------------------------------------------
# Wraps SCA jjplot2.R functions (custDotplot and jjDotPlot1).
#
# Runtime contract:
#   Rscript plot.R --input data.csv [--annot annotation.csv] --params params.json --output output_dir
#
# Input modes (params `input_mode`):
#   precomputed (default): long/tidy data frame with x, y, size.by, fill.by columns
#                          fed directly to custDotplot.
#   aggregate:             expression matrix (genes x cells) + annotation file
#                          (--annot) with a cluster column; per-group avg.exp and
#                          pct.exp are computed (jjDotPlot1 style) then custDotplot
#                          is called with x=gene, y=cluster, size.by=pct.exp,
#                          fill.by=avg.exp.scaled.

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
  library(grid)
})

option_list <- list(
  make_option(c('--input'), type = 'character', default = NULL,
              help = 'Input CSV/TSV/TXT. Tidy data frame (precomputed) or genes x cells matrix (aggregate).'),
  make_option(c('--annot'), type = 'character', default = NULL,
              help = 'Optional cell annotation CSV/TSV/TXT with a cluster column (aggregate mode).'),
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

# ------------------------------------------------------------------
# Standard helpers (copied from den_plot/plot.R)
# ------------------------------------------------------------------

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
  vals <- vals[is.finite(vals)]
  if (length(vals) == 0) default else vals
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

validate_columns <- function(df, cols, label = 'column') {
  missing <- setdiff(cols, colnames(df))
  if (length(missing) > 0) {
    write_error_and_exit(paste('Missing', label), paste('Missing columns:', paste(missing, collapse = ', ')), paste('Check', label, 'names in params.json.'))
  }
  invisible(TRUE)
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

# ------------------------------------------------------------------
# SCA helper loading
# ------------------------------------------------------------------

load_sca_reference <- function() {
  script_arg <- grep('^--file=', commandArgs(FALSE), value = TRUE)
  script_path <- if (length(script_arg) > 0) sub('^--file=', '', script_arg[1]) else file.path(getwd(), 'plugins', 'dot_plot', 'plot.R')
  # Shared SCA helper library (one canonical copy for all plugins): <repo>/R/sca
  helper_dir <- file.path(dirname(normalizePath(script_path, mustWork = FALSE)), '..', '..', 'R', 'sca')
  if (!dir.exists(helper_dir)) helper_dir <- file.path('R', 'sca')
  ensure_pkgs <- function(pkgs) {
    missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
    if (length(missing) > 0) stop('Missing required R package(s): ', paste(missing, collapse = ', '), call. = FALSE)
    invisible(lapply(pkgs, function(p) suppressPackageStartupMessages(library(p, character.only = TRUE))))
  }
  ensure_pkgs(c('ggplot2', 'ggh4x', 'scales', 'reshape2', 'purrr', 'dplyr', 'Seurat'))
  source(file.path(helper_dir, 'jjplot2.R'), local = .GlobalEnv)
  invisible(TRUE)
}

# ------------------------------------------------------------------
# Data preparation
# ------------------------------------------------------------------

read_matrix <- function(df, params) {
  row_id_col <- get_param_any(params, c('row_id_column', 'gene_column', 'feature_column'), colnames(df)[1])
  if (!row_id_col %in% colnames(df)) {
    write_error_and_exit('Row id column not found', paste('Missing:', row_id_col), 'Set row_id_column to a valid matrix row-id column.')
  }
  sample_include <- as_string_vector(get_param_any(params, c('columns_include', 'samples_include', 'cells_include'), NULL))
  sample_exclude <- as_string_vector(get_param_any(params, c('columns_exclude', 'samples_exclude', 'cells_exclude'), NULL))
  candidates <- setdiff(colnames(df), row_id_col)
  if (length(sample_include) > 0) candidates <- intersect(sample_include, candidates)
  if (length(sample_exclude) > 0) candidates <- setdiff(candidates, sample_exclude)
  if (length(candidates) < 1) {
    write_error_and_exit('Not enough cell columns', paste('Detected cell columns:', paste(candidates, collapse = ', ')), 'Select at least one numeric cell column.')
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
  mat
}

compute_aggregate <- function(mat, annot, params) {
  if (is.null(annot) || nrow(annot) == 0) {
    write_error_and_exit('Annotation required for aggregate mode', 'No annotation file supplied via --annot.', 'Provide --annot with a cluster column.')
  }
  cluster_col <- get_param_any(params, c('cluster_column', 'group_column'), 'cluster')
  if (!cluster_col %in% colnames(annot)) {
    cluster_col <- first_existing_col(annot, c('cluster', 'celltype', 'group', 'Cluster', 'celltype'), TRUE, 'cluster_column')
  }
  cell_col <- get_param_any(params, c('cell_column', 'sample_column'), 'cell')
  if (!cell_col %in% colnames(annot)) {
    cell_col <- first_existing_col(annot, c('cell', 'sample', 'Cell', 'barcode', 'Barcode'), TRUE, 'cell_column')
  }

  cells <- colnames(mat)
  annot <- annot[match(cells, annot[[cell_col]]), , drop = FALSE]
  if (any(is.na(annot[[cell_col]]))) {
    write_error_and_exit('Annotation cells do not match matrix columns', 'Some matrix columns are missing in annotation cell column.', 'Check that annotation cell ids match matrix column names.')
  }
  clusters <- as.character(annot[[cluster_col]])

  features_include <- as_string_vector(get_param_any(params, c('features_include', 'rows_include'), NULL))
  features_exclude <- as_string_vector(get_param_any(params, c('features_exclude', 'rows_exclude'), NULL))
  genes <- rownames(mat)
  if (length(features_include) > 0) genes <- intersect(genes, features_include)
  if (length(features_exclude) > 0) genes <- setdiff(genes, features_exclude)
  if (length(genes) < 1) write_error_and_exit('No genes left after filtering', '', 'Relax features_include/features_exclude.')
  mat <- mat[genes, , drop = FALSE]

  cluster_levels <- as_string_vector(get_param_any(params, c('cluster_order', 'columns_include'), NULL))
  if (length(cluster_levels) == 0) cluster_levels <- unique(clusters)
  clusters_exclude <- as_string_vector(get_param_any(params, c('columns_exclude', 'clusters_exclude'), NULL))
  if (length(clusters_exclude) > 0) cluster_levels <- setdiff(cluster_levels, clusters_exclude)

  scale <- as_bool(get_param(params, 'scale', TRUE), TRUE)
  rescale <- as_bool(get_param(params, 'rescale', FALSE), FALSE)
  col_min <- num_param(params, 'col_min', -2.5)
  col_max <- num_param(params, 'col_max', 2.5)
  rescale_min <- num_param(params, 'rescale_min', 0)
  rescale_max <- num_param(params, 'rescale_max', 1)

  out <- do.call(rbind, lapply(cluster_levels, function(cl) {
    cells_in <- cells[clusters == cl]
    if (length(cells_in) == 0) return(NULL)
    sub <- mat[, cells_in, drop = FALSE]
    avg <- apply(sub, 1, function(x) mean(expm1(x)))
    pct <- apply(sub, 1, function(x) Seurat::PercentAbove(x, 0) * 100)
    data.frame(cluster = cl, gene = rownames(sub),
               avg.exp = avg, pct.exp = pct, stringsAsFactors = FALSE)
  }))
  if (is.null(out) || nrow(out) == 0) {
    write_error_and_exit('No aggregate rows produced', 'Selected clusters have no cells.', 'Check cluster_column and cluster levels.')
  }

  if (scale) {
    out$avg.exp.scaled <- ave(out$avg.exp, out$gene, FUN = function(x) {
      s <- scale(x)
      if (rescale) as.numeric(scales::rescale(s, to = c(rescale_min, rescale_max)))
      else as.numeric(Seurat::MinMax(s, min = col_min, max = col_max))
    })
  } else {
    out$avg.exp.scaled <- log1p(out$avg.exp)
  }
  out
}

prepare_precomputed <- function(df, params) {
  x_col <- get_param_any(params, c('x_column', 'x'), 'gene')
  y_col <- get_param_any(params, c('y_column', 'y'), 'cluster')
  if (!x_col %in% colnames(df)) x_col <- first_existing_col(df, c('gene', 'Gene', 'feature', 'x'), TRUE, 'x_column')
  if (!y_col %in% colnames(df)) y_col <- first_existing_col(df, c('cluster', 'Cluster', 'group', 'y'), TRUE, 'y_column')

  size_by <- get_param_any(params, c('size_by', 'size.by'), 'pct.exp')
  fill_by <- get_param_any(params, c('fill_by', 'fill.by'), 'avg.exp.scaled')
  shape_by <- get_param_any(params, c('shape_by', 'shape.by'), NULL)

  # row/feature filtering (applied to x levels by default for tidy data)
  x_include <- as_string_vector(get_param_any(params, c('features_include', 'rows_include', 'x_include'), NULL))
  x_exclude <- as_string_vector(get_param_any(params, c('features_exclude', 'rows_exclude', 'x_exclude'), NULL))
  if (length(x_include) > 0) df <- df[as.character(df[[x_col]]) %in% x_include, , drop = FALSE]
  if (length(x_exclude) > 0) df <- df[!(as.character(df[[x_col]]) %in% x_exclude), , drop = FALSE]

  y_include <- as_string_vector(get_param_any(params, c('columns_include', 'y_include', 'clusters_include'), NULL))
  y_exclude <- as_string_vector(get_param_any(params, c('columns_exclude', 'y_exclude', 'clusters_exclude'), NULL))
  if (length(y_include) > 0) df <- df[as.character(df[[y_col]]) %in% y_include, , drop = FALSE]
  if (length(y_exclude) > 0) df <- df[!(as.character(df[[y_col]]) %in% y_exclude), , drop = FALSE]

  if (nrow(df) == 0) write_error_and_exit('No rows left after filtering', '', 'Relax include/exclude filters.')

  list(df = df, x = x_col, y = y_col, size_by = size_by, fill_by = fill_by, shape_by = shape_by)
}

# ------------------------------------------------------------------
# Dendrogram layer (jjDotPlot1 style, ggh4x)
# ------------------------------------------------------------------

add_dendrograms <- function(p, data, x, y, value_col, params) {
  ytree <- as_bool(get_param(params, 'ytree', FALSE))
  xtree <- as_bool(get_param(params, 'xtree', FALSE))
  if (!ytree && !xtree) return(p)
  if (is.null(value_col) || !value_col %in% colnames(data)) return(p)

  wide <- tryCatch(
    reshape2::dcast(as.data.frame(data), as.formula(paste(y, '~', x)), value.var = value_col),
    error = function(e) NULL
  )
  if (is.null(wide)) return(p)
  rownames(wide) <- wide[[1]]
  wide <- wide[, -1, drop = FALSE]
  wide <- as.matrix(wide)
  wide[is.na(wide)] <- 0

  tree_pos <- as_string_vector(get_param_any(params, c('tree_pos'), NULL))
  cluster_method <- get_param_any(params, c('cluster_method', 'clu_mtd'), 'average')
  distance_method <- get_param_any(params, c('distance_method', 'dist_mtd'), 'euclidean')
  same_pos_label <- as_bool(get_param(params, 'same_pos_label', FALSE))

  if (is.null(tree_pos)) {
    if (ytree && !xtree) tree_pos <- c('right', 'right')
    else if (xtree && !ytree) tree_pos <- c('top', 'top')
    else tree_pos <- c('right', 'top')
  } else if (length(tree_pos) == 1) {
    tree_pos <- c(tree_pos, tree_pos)
  }

  if (ytree) {
    hc_y <- stats::hclust(stats::dist(wide, method = distance_method), method = cluster_method)
    if (!same_pos_label) {
      p <- p + ggh4x::scale_y_dendrogram(hclust = hc_y, position = tree_pos[1], labels = NULL) +
        ggplot2::guides(y.sec = ggh4x::guide_axis_manual(labels = function(z) z))
    } else {
      p <- p + ggh4x::scale_y_dendrogram(hclust = hc_y, position = tree_pos[1])
    }
  }
  if (xtree) {
    hc_x <- stats::hclust(stats::dist(t(wide), method = distance_method), method = cluster_method)
    if (!same_pos_label) {
      p <- p + ggh4x::scale_x_dendrogram(hclust = hc_x, position = tree_pos[2], labels = NULL) +
        ggplot2::guides(x.sec = ggh4x::guide_axis_manual(labels = function(z) z))
    } else {
      p <- p + ggh4x::scale_x_dendrogram(hclust = hc_x, position = tree_pos[2])
    }
  }
  p
}

# ------------------------------------------------------------------
# Highlight layer
# ------------------------------------------------------------------

add_highlight <- function(p, data, x, y, fill_by, params) {
  highlight_features <- as_string_vector(get_param_any(params, c('highlight_features', 'highlight_rows'), NULL))
  if (length(highlight_features) == 0) return(p)
  highlight_color <- get_param(params, 'highlight_color', '#E64B35')
  dot_max <- num_param(params, 'dot_max', 8)
  sub <- data[as.character(data[[x]]) %in% highlight_features, , drop = FALSE]
  if (nrow(sub) == 0) return(p)
  aes_args <- list(x = sub[[x]], y = sub[[y]])
  if (!is.null(fill_by) && fill_by %in% colnames(sub)) aes_args$fill <- sub[[fill_by]]
  p <- p + ggplot2::geom_point(
    data = sub,
    mapping = do.call(ggplot2::aes, aes_args),
    shape = 21, fill = NA, color = highlight_color,
    stroke = 1.4, size = dot_max + 3, alpha = 1, show.legend = FALSE
  )
  p
}

# ------------------------------------------------------------------
# Build plot
# ------------------------------------------------------------------

build_plot <- function(data, x, y, size_by, fill_by, shape_by, params) {
  dot_col <- as_string_vector(get_param_any(params, c('dot_col', 'colors', 'palette_colors'), NULL),
                              default = c('#2b6cb0', 'white', '#c53030'))
  if (length(dot_col) == 1) dot_col <- c('white', dot_col)
  midpoint <- num_param(params, 'midpoint', if (length(dot_col) == 3) 0 else 0.5)

  fill_limits <- as_numeric_vector(get_param(params, 'fill_limits', NULL), default = NULL)
  fill_na <- get_param(params, 'fill_na_color', 'grey90')

  point_geom <- as_bool(get_param(params, 'point_geom', TRUE), TRUE)
  tile_geom <- as_bool(get_param(params, 'tile_geom', FALSE), FALSE)

  p <- custDotplot(
    data = data,
    x = x,
    y = y,
    size.by = if (!is.null(size_by) && size_by %in% colnames(data)) size_by else NULL,
    fill.by = if (!is.null(fill_by) && fill_by %in% colnames(data)) fill_by else NULL,
    shape.by = if (!is.null(shape_by) && shape_by %in% colnames(data)) shape_by else NULL,
    x.lab = if (as_bool(get_param(params, 'xlab_show', TRUE), TRUE)) get_param(params, 'xlab', '') else '',
    y.lab = if (as_bool(get_param(params, 'ylab_show', TRUE), TRUE)) get_param(params, 'ylab', '') else '',
    title = if (as_bool(get_param(params, 'title_show', TRUE), TRUE)) get_param(params, 'title', NULL) else NULL,
    point.shape = as.numeric(get_param(params, 'point_shape', 21))[1],
    point.color = get_param(params, 'point_color', 'black'),
    point.stroke = num_param(params, 'point_stroke', 0.2),
    point.alpha = num_param(params, 'point_alpha', 1),
    shape.values = as_numeric_vector(get_param(params, 'shape_values', NULL), default = NULL),
    shape.legendTitle = get_param(params, 'shape_legend_title', NULL),
    dot.min = num_param(params, 'dot_min', 1),
    dot.max = num_param(params, 'dot_max', 8),
    dot.size = num_param(params, 'dot_size', 4),
    dot.col = dot_col,
    midpoint = midpoint,
    fill.limits = fill_limits,
    fill.na = fill_na,
    base_size = num_param(params, 'base_size', 14),
    x.text.angle = num_param(params, 'x_text_angle', 45),
    x.text.hjust = num_param(params, 'x_text_hjust', 1),
    x.text.vjust = num_param(params, 'x_text_vjust', 1),
    aspect.ratio = {
      ar <- num_param(params, 'aspect_ratio', NA_real_)
      if (is.finite(ar)) ar else NULL
    },
    legend.position = get_param(params, 'legend_position', 'right'),
    legend.direction = get_param(params, 'legend_direction', 'vertical'),
    fill.legendTitle = get_param(params, 'fill_legend_title', NULL),
    size.legendTitle = get_param(params, 'size_legend_title', NULL),
    bar.width = num_param(params, 'colorbar_width', 1.5),
    size.width = num_param(params, 'size_width', 0.6),
    plot.margin = as_numeric_vector(get_param(params, 'plot_margin', c(0.5, 0.5, 0.5, 0.5)),
                                    default = c(0.5, 0.5, 0.5, 0.5)),
    panel.grid = as_bool(get_param(params, 'show_grid', TRUE), TRUE),
    panel.border = as_bool(get_param(params, 'show_border', TRUE), TRUE),
    coord.fixed = as_bool(get_param(params, 'coord_fixed', FALSE), FALSE),
    flip = as_bool(get_param(params, 'flip', FALSE), FALSE),
    clip = get_param(params, 'clip', 'off')
  )

  # tile geom overlay (custDotplot uses point by default; add tile if requested)
  if (tile_geom && !is.null(fill_by) && fill_by %in% colnames(data)) {
    p <- p + ggplot2::geom_tile(ggplot2::aes(fill = .data[[fill_by]]), color = 'black')
  }

  # typography tweaks
  title_size <- num_param(params, 'title_size', NA_real_)
  y_text_size <- num_param(params, 'y_text_size', NA_real_)
  legend_title_size <- num_param(params, 'legend_title_size', NA_real_)
  legend_text_size <- num_param(params, 'legend_text_size', NA_real_)
  font_family <- get_param(params, 'font_family', NULL)
  p <- p + ggplot2::theme(
    text = if (!is.null(font_family)) ggplot2::element_text(family = font_family) else ggplot2::element_text(),
    axis.text.y = if (is.finite(y_text_size)) ggplot2::element_text(size = y_text_size, color = 'black') else ggplot2::element_text(color = 'black'),
    plot.title = if (is.finite(title_size)) ggplot2::element_text(size = title_size) else ggplot2::element_text(),
    legend.title = if (is.finite(legend_title_size)) ggplot2::element_text(size = legend_title_size) else ggplot2::element_text(),
    legend.text = if (is.finite(legend_text_size)) ggplot2::element_text(size = legend_text_size) else ggplot2::element_text()
  )

  # subtitle
  subtitle <- get_param(params, 'subtitle', NULL)
  if (!is.null(subtitle) && as_bool(get_param(params, 'subtitle_show', TRUE), TRUE)) {
    p <- p + ggplot2::labs(subtitle = subtitle)
  }

  # dendrograms
  p <- add_dendrograms(p, data, x, y, fill_by, params)

  # highlight
  p <- add_highlight(p, data, x, y, fill_by, params)

  p
}

# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------

main <- function() {
  if (is.null(input_file)) write_error_and_exit('Missing --input argument')
  if (is.null(params_file) || !file.exists(params_file)) write_error_and_exit('Params file not found', paste('Params path:', params_file), 'Provide params.json.')
  if (is.null(output_dir)) write_error_and_exit('Missing --output argument')
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  old_outputs <- file.path(output_dir, c('error.json', 'result.svg', 'result.pdf', 'result.png', 'figure.json', 'selected_rows.csv', 'run.log'))
  old_outputs <- old_outputs[file.exists(old_outputs)]
  if (length(old_outputs) > 0) unlink(old_outputs)
  write_log('Starting dot_plot plugin.')

  params <- jsonlite::fromJSON(params_file, simplifyVector = FALSE)
  input_mode <- tolower(as.character(get_param_any(params, c('input_mode', 'mode'), 'precomputed'))[1])

  load_sca_reference()

  filtered <- FALSE
  if (input_mode == 'precomputed') {
    df <- read_table_auto(input_file)
    prep <- prepare_precomputed(df, params)
    data <- prep$df
    x <- prep$x
    y <- prep$y
    size_by <- prep$size_by
    fill_by <- prep$fill_by
    shape_by <- prep$shape_by
    if (length(as_string_vector(get_param_any(params, c('features_include', 'rows_include', 'features_exclude', 'rows_exclude', 'columns_include', 'columns_exclude'), NULL))) > 0) filtered <- TRUE
  } else if (input_mode == 'aggregate') {
    df <- read_table_auto(input_file)
    mat <- read_matrix(df, params)
    annot <- if (!is.null(annot_file)) read_table_auto(annot_file) else as.data.frame(get_param(params, 'annotation', NULL), stringsAsFactors = FALSE)
    data <- compute_aggregate(mat, annot, params)
    x <- get_param_any(params, c('x_column', 'gene_column'), 'gene')
    y <- get_param_any(params, c('y_column', 'cluster_column'), 'cluster')
    size_by <- get_param_any(params, c('size_by', 'size.by'), 'pct.exp')
    fill_by <- get_param_any(params, c('fill_by', 'fill.by'), 'avg.exp.scaled')
    shape_by <- get_param_any(params, c('shape_by', 'shape.by'), NULL)
    if (length(as_string_vector(get_param_any(params, c('features_include', 'rows_include', 'features_exclude', 'rows_exclude', 'columns_include', 'columns_exclude', 'clusters_exclude'), NULL))) > 0) filtered <- TRUE
  } else {
    write_error_and_exit('Unsupported input_mode', paste('input_mode:', input_mode), 'Use precomputed or aggregate.')
  }

  # top_n selector
  top_n <- as.integer(num_param(params, 'top_n', NA_real_))
  if (is.finite(top_n) && top_n > 0) {
    top_by <- get_param_any(params, c('top_by'), NULL)
    if (!is.null(top_by) && top_by %in% colnames(data)) {
      top_abs <- as_bool(get_param(params, 'top_abs', TRUE), TRUE)
      rv <- data[[top_by]]
      if (top_abs) rv <- abs(rv)
      ord <- order(rv, decreasing = TRUE, na.last = NA)
      keep_ids <- unique(as.character(data[[x]][ord]))[seq_len(min(top_n, length(unique(as.character(data[[x]])))))]
      data <- data[as.character(data[[x]]) %in% keep_ids, , drop = FALSE]
      filtered <- TRUE
    }
  }

  p <- build_plot(data, x, y, size_by, fill_by, shape_by, params)

  if (filtered) {
    sel <- unique(as.character(data[[x]]))
    utils::write.csv(data.frame(feature = sel, stringsAsFactors = FALSE),
                     file.path(output_dir, 'selected_rows.csv'), row.names = FALSE)
  }

  width <- num_param(params, 'width', 9)
  height <- num_param(params, 'height', 5.5)
  dpi <- num_param(params, 'dpi', 300)
  save_plot(p, output_dir, width, height, dpi)

  n_genes <- length(unique(as.character(data[[x]])))
  n_clusters <- length(unique(as.character(data[[y]])))
  figure <- list(
    plugin = 'dot_plot',
    source_engine = 'SCA jjplot2.R (custDotplot / jjDotPlot1)',
    input_mode = input_mode,
    input_file = normalizePath(input_file, mustWork = FALSE),
    annotation_file = if (!is.null(annot_file)) normalizePath(annot_file, mustWork = FALSE) else NULL,
    n_genes = n_genes,
    n_clusters = n_clusters,
    style = list(
      point_geom = as_bool(get_param(params, 'point_geom', TRUE), TRUE),
      tile_geom = as_bool(get_param(params, 'tile_geom', FALSE), FALSE),
      ytree = as_bool(get_param(params, 'ytree', FALSE), FALSE),
      xtree = as_bool(get_param(params, 'xtree', FALSE), FALSE),
      coord_fixed = as_bool(get_param(params, 'coord_fixed', FALSE), FALSE),
      flip = as_bool(get_param(params, 'flip', FALSE), FALSE),
      legend_position = get_param(params, 'legend_position', 'right')
    ),
    outputs = list(svg = 'result.svg', pdf = 'result.pdf', png = 'result.png',
                   figure = 'figure.json', log = 'run.log',
                   selected_rows = if (filtered) 'selected_rows.csv' else NULL)
  )
  writeLines(jsonlite::toJSON(figure, auto_unbox = TRUE, pretty = TRUE), file.path(output_dir, 'figure.json'))
  write_log('Completed dot_plot plugin.')
}

tryCatch(main(), error = function(e) {
  write_error_and_exit('Dot plot failed', conditionMessage(e), 'Check input columns, params.json, and annotation file.')
})