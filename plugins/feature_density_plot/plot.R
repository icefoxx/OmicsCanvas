#!/usr/bin/env Rscript

# BioFigureAI Plot Plugin: Feature Density Plot
# ------------------------------------------------------------
# Wraps SCA GsDenPlot.R functions (GsDenPlot, plotFeatureDen,
# densityPlot, calDensity) for CLI use with CSV inputs.
#
# Runtime contract:
#   Rscript plot.R --input expression.csv --embed embedding.csv \
#                  --params params.json --output output_dir
#
# Required outputs: result.svg, result.pdf, result.png, figure.json,
#   run.log, selected_features.csv
# On failure: error.json {error, detail, suggestion}

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
  library(grid)
})

option_list <- list(
  make_option(c('--input'), type = 'character', default = NULL,
              help = 'Expression matrix CSV/TSV/TXT. First column = feature/gene id; remaining columns = cells.'),
  make_option(c('--embed'), type = 'character', default = NULL,
              help = '2D embedding CSV/TSV/TXT. First column = cell id; next 2 columns = dim1, dim2.'),
  make_option(c('--params'), type = 'character', default = NULL,
              help = 'Path to params.json.'),
  make_option(c('--output'), type = 'character', default = NULL,
              help = 'Output directory.')
)

opt <- parse_args(OptionParser(option_list = option_list))
input_file <- opt$input
embed_file <- opt$embed
params_file <- opt$params
output_dir <- opt$output

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

# ---------------------------------------------------------------------------
# Standard helpers (copied from den_plot/plot.R)
# ---------------------------------------------------------------------------

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

validate_columns <- function(df, cols, label = 'column') {
  missing <- setdiff(cols, colnames(df))
  if (length(missing) > 0) {
    write_error_and_exit(paste('Missing', label), paste('Not found in input:', paste(missing, collapse = ', ')), paste('Check', label, 'names in params.json or input file header.'))
  }
  invisible(TRUE)
}

# ---------------------------------------------------------------------------
# Plot saving (svg/pdf/png with retry)
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# Load SCA helper (GsDenPlot.R: scale01, calDensity, plotFeatureDen, densityPlot)
# ---------------------------------------------------------------------------

load_sca_reference <- function() {
  script_arg <- grep('^--file=', commandArgs(FALSE), value = TRUE)
  script_path <- if (length(script_arg) > 0) sub('^--file=', '', script_arg[1]) else file.path(getwd(), 'plugins', 'feature_density_plot', 'plot.R')
  helper_dir <- file.path(dirname(normalizePath(script_path, mustWork = FALSE)), 'reference_sca_helpers')
  if (!dir.exists(helper_dir)) helper_dir <- file.path('plugins', 'feature_density_plot', 'reference_sca_helpers')
  helper_file <- file.path(helper_dir, 'GsDenPlot.R')
  if (!file.exists(helper_file)) {
    write_error_and_exit('SCA helper missing', paste('Expected:', helper_file), 'Restore reference_sca_helpers/GsDenPlot.R.')
  }
  # Ensure required packages are available before sourcing.
  required_pkgs <- c('ks', 'Matrix', 'ggplot2', 'ggrastr', 'viridis')
  missing <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    write_error_and_exit('Missing R package(s)', paste(missing, collapse = ', '), paste('Install:', paste('install.packages("', missing, '")', collapse = ' ')))
  }
  source(helper_file, local = .GlobalEnv)
  invisible(TRUE)
}

# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------

build_expression_matrix <- function(expr_df, params, keep_cells) {
  feature_id_col <- get_param_any(params, c('feature_id_column', 'feature_column', 'gene_id_column', 'id_column'), colnames(expr_df)[1])
  if (!feature_id_col %in% colnames(expr_df)) {
    write_error_and_exit('Feature id column not found', paste('Missing:', feature_id_col), 'Set feature_id_column to a valid expression row-id column.')
  }
  candidate_cells <- setdiff(colnames(expr_df), feature_id_col)
  cells_include <- as_string_vector(get_param_any(params, c('cells_include', 'columns_include', 'samples_include'), NULL))
  cells_exclude <- as_string_vector(get_param_any(params, c('cells_exclude', 'columns_exclude', 'samples_exclude'), NULL))
  if (length(cells_include) > 0) candidate_cells <- intersect(cells_include, candidate_cells)
  if (length(cells_exclude) > 0) candidate_cells <- setdiff(candidate_cells, cells_exclude)
  candidate_cells <- intersect(candidate_cells, keep_cells)
  if (length(candidate_cells) < 2) {
    write_error_and_exit('Not enough cells after filtering', paste('Cells left:', length(candidate_cells)), 'Check cells_include/cells_exclude and that expression columns match embedding cell ids.')
  }
  mat_df <- expr_df[, candidate_cells, drop = FALSE]
  mat <- suppressWarnings(as.matrix(data.frame(lapply(mat_df, as.numeric), check.names = FALSE)))
  rownames(mat) <- make.unique(as.character(expr_df[[feature_id_col]]))
  colnames(mat) <- candidate_cells
  # Drop rows with all-NA
  keep <- rowSums(is.finite(mat)) > 0
  if (!all(keep)) {
    write_log(paste('Dropping expression rows with no finite values:', sum(!keep)))
    mat <- mat[keep, , drop = FALSE]
  }
  if (nrow(mat) < 1) write_error_and_exit('No expression rows left', '', 'Check feature_id_column and expression values.')
  mat
}

build_embedding <- function(embed_df, params, keep_cells) {
  cell_id_col <- get_param_any(params, c('cell_id_column', 'cell_column', 'sample_id_column', 'id_column'), colnames(embed_df)[1])
  if (!cell_id_col %in% colnames(embed_df)) {
    write_error_and_exit('Cell id column not found', paste('Missing:', cell_id_col), 'Set cell_id_column to a valid embedding cell-id column.')
  }
  dim1_col <- get_param_any(params, c('dim1_column', 'dim1', 'x_column', 'x_col'), colnames(embed_df)[2])
  dim2_col <- get_param_any(params, c('dim2_column', 'dim2', 'y_column', 'y_col'), colnames(embed_df)[3])
  validate_columns(embed_df, c(dim1_col, dim2_col), 'embedding dimension column')
  embed <- embed_df[, c(cell_id_col, dim1_col, dim2_col), drop = FALSE]
  colnames(embed) <- c('cell', dim1_col, dim2_col)
  embed$cell <- as.character(embed$cell)
  embed <- embed[embed$cell %in% keep_cells, , drop = FALSE]
  embed <- embed[!duplicated(embed$cell), , drop = FALSE]
  if (nrow(embed) < 2) {
    write_error_and_exit('Not enough embedding cells', paste('Rows:', nrow(embed)), 'Check embedding file and cell_id_column.')
  }
  cell.xy <- as.matrix(embed[, c(dim1_col, dim2_col)])
  storage.mode(cell.xy) <- 'double'
  rownames(cell.xy) <- embed$cell
  colnames(cell.xy) <- c(dim1_col, dim2_col)
  list(cell.xy = cell.xy, dim1 = dim1_col, dim2 = dim2_col, cells = embed$cell)
}

# ---------------------------------------------------------------------------
# Theme customization applied on top of the SCA-returned (rasterised) plot
# ---------------------------------------------------------------------------

apply_custom_theme <- function(p, params) {
  base_size <- num_param(params, 'base_size', 14)
  font_family <- get_param(params, 'font_family', NULL)
  font_size <- num_param(params, 'font_size', NA_real_)
  text_size <- if (is.finite(font_size)) font_size else base_size

  title <- get_param(params, 'title', NULL)
  title_show <- as_bool(get_param(params, 'title_show', TRUE), TRUE)
  xlab <- get_param(params, 'xlab', NULL)
  ylab <- get_param(params, 'ylab', NULL)
  xlab_show <- as_bool(get_param(params, 'xlab_show', TRUE), TRUE)
  ylab_show <- as_bool(get_param(params, 'ylab_show', TRUE), TRUE)

  title_size <- num_param(params, 'title_size', NA_real_)
  axis_label_size <- num_param(params, 'axis_label_size', NA_real_)
  x_axis_text_size <- num_param(params, 'x_axis_text_size', NA_real_)
  y_axis_text_size <- num_param(params, 'y_axis_text_size', NA_real_)

  point_color <- get_param(params, 'point_color', 'black')
  axis_line_size <- num_param(params, 'axis_line_size', 0.25)
  strip_fill <- get_param(params, 'strip_fill', '#ffe5cc')

  legend_show <- as_bool(get_param(params, 'legend_show', TRUE), TRUE)
  legend_position <- get_param(params, 'legend_position', 'right')
  legend_title_size <- num_param(params, 'legend_title_size', NA_real_)
  legend_text_size <- num_param(params, 'legend_text_size', NA_real_)
  colorbar_width <- num_param(params, 'colorbar_width', NA_real_)
  colorbar_height <- num_param(params, 'colorbar_height', NA_real_)

  # Title / labels overrides
  if (!is.null(title) && title_show) {
    p <- p + ggtitle(title)
  } else if (!title_show) {
    p <- p + ggtitle(NULL)
  }
  if (!is.null(xlab) && xlab_show) {
    p <- p + xlab(xlab)
  } else if (!xlab_show) {
    p <- p + xlab(NULL)
  }
  if (!is.null(ylab) && ylab_show) {
    p <- p + ylab(ylab)
  } else if (!ylab_show) {
    p <- p + ylab(NULL)
  }

  # Build theme overrides
  th <- theme(
    text = element_text(size = text_size, family = font_family %||% ""),
    panel.background = element_blank(),
    axis.text.x = element_text(color = point_color),
    axis.text.y = element_text(color = point_color),
    axis.line = element_line(size = axis_line_size),
    strip.background = element_rect(color = 'black', fill = strip_fill)
  )
  if (is.finite(title_size)) th <- th + theme(plot.title = element_text(size = title_size))
  if (is.finite(axis_label_size)) th <- th + theme(axis.title = element_text(size = axis_label_size))
  if (is.finite(x_axis_text_size)) th <- th + theme(axis.text.x = element_text(size = x_axis_text_size))
  if (is.finite(y_axis_text_size)) th <- th + theme(axis.text.y = element_text(size = y_axis_text_size))
  if (is.finite(legend_title_size)) th <- th + theme(legend.title = element_text(size = legend_title_size))
  if (is.finite(legend_text_size)) th <- th + theme(legend.text = element_text(size = legend_text_size))
  if (!legend_show) {
    th <- th + theme(legend.position = 'none')
  } else {
    th <- th + theme(legend.position = legend_position)
  }
  p <- p + th

  # Colorbar dimensions via guide
  if (legend_show && (is.finite(colorbar_width) || is.finite(colorbar_height))) {
    barwidth <- if (is.finite(colorbar_width)) colorbar_width else NULL
    barheight <- if (is.finite(colorbar_height)) colorbar_height else NULL
    p <- p + guides(color = guide_colorbar(barwidth = barwidth, barheight = barheight))
  }

  p
}

# ---------------------------------------------------------------------------
# Highlight cells overlay
# ---------------------------------------------------------------------------

add_highlight <- function(p, params, cell.xy) {
  highlight_cells <- as_string_vector(get_param_any(params, c('highlight_cells', 'highlight_points', 'selected_points'), NULL))
  if (length(highlight_cells) == 0) return(p)
  hits <- intersect(highlight_cells, rownames(cell.xy))
  if (length(hits) == 0) return(p)
  hl <- data.frame(
    x = cell.xy[hits, 1],
    y = cell.xy[hits, 2]
  )
  colnames(hl) <- colnames(cell.xy)
  hl_color <- get_param(params, 'highlight_color', '#E64B35')
  hl_size <- num_param(params, 'highlight_size', 1.2)
  hl_shape <- num_param(params, 'highlight_shape', 21)
  hl_alpha <- num_param(params, 'highlight_alpha', 1)
  aes_x <- colnames(cell.xy)[1]
  aes_y <- colnames(cell.xy)[2]
  p <- p + geom_point(
    data = hl,
    aes_string(x = aes_x, y = aes_y),
    color = hl_color,
    size = hl_size,
    shape = hl_shape,
    alpha = hl_alpha,
    stroke = 0.6,
    inherit.aes = FALSE
  )
  p
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main <- function() {
  if (is.null(input_file)) write_error_and_exit('Missing --input argument')
  if (is.null(embed_file)) write_error_and_exit('Missing --embed argument')
  if (is.null(params_file) || !file.exists(params_file)) write_error_and_exit('Params file not found', paste('Params path:', params_file), 'Provide params.json.')
  if (is.null(output_dir)) write_error_and_exit('Missing --output argument')
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  old_outputs <- file.path(output_dir, c('error.json', 'result.svg', 'result.pdf', 'result.png', 'figure.json', 'selected_features.csv', 'run.log'))
  old_outputs <- old_outputs[file.exists(old_outputs)]
  if (length(old_outputs) > 0) unlink(old_outputs)

  write_log('Starting feature_density_plot plugin.')

  params <- jsonlite::fromJSON(params_file, simplifyVector = FALSE)

  # Read inputs
  expr_df <- read_table_auto(input_file)
  embed_df <- read_table_auto(embed_file)

  # Determine feature id column to detect cell columns
  feature_id_col <- get_param_any(params, c('feature_id_column', 'feature_column', 'gene_id_column', 'id_column'), colnames(expr_df)[1])
  if (!feature_id_col %in% colnames(expr_df)) {
    write_error_and_exit('Feature id column not found', paste('Missing:', feature_id_col), 'Set feature_id_column to a valid expression row-id column.')
  }
  cell_id_col <- get_param_any(params, c('cell_id_column', 'cell_column', 'sample_id_column', 'id_column'), colnames(embed_df)[1])
  if (!cell_id_col %in% colnames(embed_df)) {
    write_error_and_exit('Cell id column not found', paste('Missing:', cell_id_col), 'Set cell_id_column to a valid embedding cell-id column.')
  }

  expr_cells <- setdiff(colnames(expr_df), feature_id_col)
  embed_cells <- as.character(embed_df[[cell_id_col]])
  common_cells <- intersect(expr_cells, embed_cells)
  if (length(common_cells) < 2) {
    write_error_and_exit('No matching cells between expression and embedding', paste('Common cells:', length(common_cells)), 'Ensure expression column names match embedding cell ids.')
  }
  write_log(paste('Common cells between expression and embedding:', length(common_cells)))

  # Build matrices
  mat <- build_expression_matrix(expr_df, params, common_cells)
  emb <- build_embedding(embed_df, params, colnames(mat))

  # Align cells between mat and embedding
  shared <- intersect(colnames(mat), rownames(emb$cell.xy))
  if (length(shared) < 2) {
    write_error_and_exit('Cells lost after building matrices', paste('Shared:', length(shared)), 'Check cell id formats.')
  }
  mat <- mat[, shared, drop = FALSE]
  cell.xy <- emb$cell.xy[shared, , drop = FALSE]
  write_log(paste('Cells used for density:', length(shared)))

  # Select features
  features <- as_string_vector(get_param_any(params, c('features', 'selected_features', 'selected_genes', 'genes'), NULL))
  if (length(features) == 0) {
    write_error_and_exit('No features selected', 'features parameter is required.', 'Provide a features array in params.json (e.g. ["GeneA"]).')
  }
  # features_include / features_exclude refinement
  features_include <- as_string_vector(get_param(params, 'features_include', NULL))
  features_exclude <- as_string_vector(get_param(params, 'features_exclude', NULL))
  if (length(features_include) > 0) features <- intersect(features, features_include)
  if (length(features_exclude) > 0) features <- setdiff(features, features_exclude)
  if (length(features) == 0) {
    write_error_and_exit('No features left after filtering', '', 'Check features/features_include/features_exclude against expression row ids.')
  }
  missing_features <- setdiff(features, rownames(mat))
  if (length(missing_features) > 0) {
    write_error_and_exit('Feature(s) not found in expression', paste('Missing:', paste(missing_features, collapse = ', ')), 'Check feature names against the feature_id_column of the expression matrix.')
  }
  mat <- mat[features, , drop = FALSE]
  write_log(paste('Features used:', paste(features, collapse = ', ')))

  # Plot mode params
  scale01 <- as_bool(get_param(params, 'scale01', FALSE), FALSE)
  raster <- as_bool(get_param(params, 'raster', TRUE), TRUE)
  bias <- num_param(params, 'bias', 1)
  cells_knn <- as.integer(num_param(params, 'cells_knn', 25))[1]
  if (is.na(cells_knn) || cells_knn < 1) cells_knn <- 25L
  palette <- get_param(params, 'palette', 'turbo')
  point_size <- num_param(params, 'point_size', 0.5)
  point_shape <- num_param(params, 'point_shape', 16)
  point_alpha <- num_param(params, 'point_alpha', NA_real_)
  coexpression <- as_bool(get_param(params, 'coexpression', length(features) > 1), length(features) > 1)
  legend_name <- get_param(params, 'legend_name', 'Density')

  # Load SCA helpers (defines scale01, calDensity, plotFeatureDen, densityPlot)
  load_sca_reference()

  # Call plotFeatureDen. It returns list(plot=., data=.) and the plot is
  # already rasterised by ggrastr::rasterise inside densityPlot.
  res <- tryCatch({
    plotFeatureDen(
      Mat = mat,
      cell.xy = cell.xy,
      features = features,
      bias = bias,
      size = point_size,
      shape = point_shape,
      cells = cells_knn,
      pal = palette,
      raster = raster,
      scale01 = scale01
    )
  }, error = function(e) {
    write_error_and_exit('plotFeatureDen failed', conditionMessage(e), 'Check expression values, embedding coordinates, and cells_knn/bias.')
  })

  p <- res$plot
  density_data <- res$data

  # Override legend name if requested (the SCA helper hard-codes "Density").
  if (!is.null(get_param(params, 'legend_name', NULL))) {
    # Replace the color scale to rename the legend.
    p <- p + scale_color_viridis_c(option = palette, name = legend_name)
  }

  # Apply additional theme / label customizations.
  p <- apply_custom_theme(p, params)

  # Highlight overlay (drawn on top of the rasterised scatter).
  p <- add_highlight(p, params, cell.xy)

  # Save outputs
  width <- num_param(params, 'width', 7)
  height <- num_param(params, 'height', 5.5)
  dpi <- num_param(params, 'dpi', 300)
  save_plot(p, output_dir, width, height, dpi)

  # selected_features.csv
  sel_df <- data.frame(feature = features, stringsAsFactors = FALSE)
  utils::write.csv(sel_df, file.path(output_dir, 'selected_features.csv'), row.names = FALSE)

  # figure.json
  figure <- list(
    plugin = 'feature_density_plot',
    source_engine = 'SCA GsDenPlot.R',
    wrapped_functions = c('GsDenPlot', 'plotFeatureDen', 'densityPlot', 'calDensity'),
    input_file = normalizePath(input_file, mustWork = FALSE),
    embed_file = normalizePath(embed_file, mustWork = FALSE),
    features = features,
    n_cells = length(shared),
    dims = list(dim1 = emb$dim1, dim2 = emb$dim2),
    style = list(
      palette = palette,
      scale01 = scale01,
      coexpression = coexpression,
      bias = bias,
      cells_knn = cells_knn,
      raster = raster,
      point_size = point_size,
      point_shape = point_shape,
      legend_name = legend_name,
      legend_position = get_param(params, 'legend_position', 'right')
    ),
    density_summary = list(
      min = as.numeric(min(density_data, na.rm = TRUE)),
      max = as.numeric(max(density_data, na.rm = TRUE))
    ),
    outputs = list(svg = 'result.svg', pdf = 'result.pdf', png = 'result.png', selected_features = 'selected_features.csv', log = 'run.log')
  )
  writeLines(jsonlite::toJSON(figure, auto_unbox = TRUE, pretty = TRUE), file.path(output_dir, 'figure.json'))
  write_log('Completed feature_density_plot plugin.')
}

tryCatch(main(), error = function(e) {
  write_error_and_exit('Feature density plot failed', conditionMessage(e), 'Check inputs, params.json, and that required R packages are installed.')
})