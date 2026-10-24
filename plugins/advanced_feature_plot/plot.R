#!/usr/bin/env Rscript

# BioFigureAI Plot Plugin: Advanced Feature Plot
# ------------------------------------------------------------
# Runtime contract:
#   Rscript plot.R --input input.csv --params params.json --output output_dir
#
# This plugin wraps the original SCA advFeaPlot() engine while exposing a
# stable table/JSON interface and standard result.svg/pdf/png/figure.json files.

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
  library(grid)
})

option_list <- list(
  make_option(c('--input'), type = 'character', default = NULL,
              help = 'Path to a CSV/TSV/TXT table containing cell id, dim1/dim2, and numeric feature columns.'),
  make_option(c('--params'), type = 'character', default = NULL,
              help = 'Path to params.json.'),
  make_option(c('--output'), type = 'character', default = NULL,
              help = 'Output directory.')
)

opt <- parse_args(OptionParser(option_list = option_list))
input_file <- opt$input
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
  as.character(values)
}

first_existing_col <- function(df, candidates, required = TRUE, label = 'column') {
  hit <- candidates[candidates %in% colnames(df)][1]
  if (!is.na(hit)) return(hit)
  if (required) {
    write_error_and_exit('Could not detect required column', paste(label, 'candidates:', paste(candidates, collapse = ', ')), paste('Provide', label, 'in params.json.'))
  }
  NULL
}

validate_columns <- function(df, cols) {
  cols <- cols[!is.na(cols) & nzchar(cols)]
  missing_cols <- setdiff(cols, colnames(df))
  if (length(missing_cols) > 0) {
    write_error_and_exit('Required input columns not found', paste('Missing columns:', paste(missing_cols, collapse = ', ')), 'Check column params and the input header.')
  }
}

normalize_theme_name <- function(x) {
  value <- as.character(x)[1]
  if (is.na(value) || !nzchar(value)) return(value)
  if (value == 'themeBlank') return('themeBlank')
  if (value == 'themeDefault') return('themeDefault')
  if (value == 'blank') return('themeBlank')
  'themeDefault'
}

load_sca_advfea_reference <- function() {
  script_arg <- grep('^--file=', commandArgs(FALSE), value = TRUE)
  script_path <- if (length(script_arg) > 0) sub('^--file=', '', script_arg[1]) else file.path(getwd(), 'plugins', 'advanced_feature_plot', 'plot.R')
  # Shared SCA helper library (one canonical copy for all plugins): <repo>/R/sca
  helper_dir <- file.path(dirname(normalizePath(script_path, mustWork = FALSE)), '..', '..', 'R', 'sca')
  if (!dir.exists(helper_dir)) helper_dir <- file.path('R', 'sca')

  `%||%` <<- function(x, y) if (is.null(x) || length(x) == 0) y else x
  ckPacsR <<- function(packages, ...) {
    packages <- sub('@.*$', '', packages)
    packages <- sub('^.*/', '', packages)
    missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
    if (length(missing) > 0) stop('Missing required R package(s): ', paste(missing, collapse = ', '), call. = FALSE)
    invisible(TRUE)
  }
  toDenseMatrix <<- function(x) {
    if (inherits(x, 'Matrix')) return(as.matrix(x))
    as.matrix(x)
  }
  melt <<- function(...) reshape2::melt(...)
  rescale <<- scales::rescale
  theme_scp <<- function(...) themeDefault(...)

  source(file.path(helper_dir, 'util.plot.R'), local = .GlobalEnv)
  source(file.path(helper_dir, 'add.on.layers.4.dimplot.R'), local = .GlobalEnv)
  source(file.path(helper_dir, 'expStatPlot.R'), local = .GlobalEnv)
  source(file.path(helper_dir, 'statPlot.R'), local = .GlobalEnv)
  source(file.path(helper_dir, 'advFeaPlot.R'), local = .GlobalEnv)

  source(file.path(helper_dir, 'omicscanvas_shims.R'), local = .GlobalEnv)
  omicscanvas_patch_palette(helper_dir)
  invisible(TRUE)
}

theme_args_from_params <- function(params, xlab, ylab) {
  args <- get_param_any(params, c('theme_args', 'theme.args'), list())
  if (is.null(args) || !is.list(args)) args <- list()
  if (!is.null(get_param(params, 'axis_label_size', NULL)) && is.null(args$lab.size)) args$lab.size <- num_param(params, 'axis_label_size', 12)
  if (!is.null(get_param(params, 'axis_arrow_x_length_npc', NULL)) && is.null(args$xlen.npc)) args$xlen.npc <- num_param(params, 'axis_arrow_x_length_npc', 0.15)
  if (!is.null(get_param(params, 'axis_arrow_y_length_npc', NULL)) && is.null(args$ylen.npc)) args$ylen.npc <- num_param(params, 'axis_arrow_y_length_npc', 0.15)
  if (is.null(args$xlab)) args$xlab <- xlab
  if (is.null(args$ylab)) args$ylab <- ylab
  args
}

rename_xy_for_sca <- function(df, x_col, y_col) {
  out <- df
  out$x <- suppressWarnings(as.numeric(out[[x_col]]))
  out$y <- suppressWarnings(as.numeric(out[[y_col]]))
  out <- out[is.finite(out$x) & is.finite(out$y), , drop = FALSE]
  out
}

apply_row_selection <- function(df, id_col, group_col, params) {
  include <- as_string_vector(get_param_any(params, c('rows_include', 'cells_include', 'ids_include'), NULL))
  exclude <- as_string_vector(get_param_any(params, c('rows_exclude', 'cells_exclude', 'ids_exclude'), NULL))
  if (length(include) > 0) df <- df[df[[id_col]] %in% include, , drop = FALSE]
  if (length(exclude) > 0) df <- df[!df[[id_col]] %in% exclude, , drop = FALSE]
  groups_include <- as_string_vector(get_param(params, 'groups_include', NULL))
  groups_exclude <- as_string_vector(get_param(params, 'groups_exclude', NULL))
  if (!is.null(group_col) && length(groups_include) > 0) df <- df[as.character(df[[group_col]]) %in% groups_include, , drop = FALSE]
  if (!is.null(group_col) && length(groups_exclude) > 0) df <- df[!as.character(df[[group_col]]) %in% groups_exclude, , drop = FALSE]
  df
}

build_advfea_args <- function(df, params, x_col, y_col, id_col, group_col, split_col, feature_cols) {
  xlab <- get_param(params, 'xlab', x_col)
  ylab <- get_param(params, 'ylab', y_col)
  theme_use <- normalize_theme_name(get_param_any(params, c('theme.use', 'theme_use'), 'themeDefault'))
  palcolor <- get_param_any(params, c('palcolor', 'feature_colors'), NULL)
  color_map <- as_named_vector(get_param_any(params, c('feature_color_map', 'feature_level_colors'), NULL), default = NULL)
  if (!is.null(color_map)) palcolor <- color_map

  data <- rename_xy_for_sca(df, x_col, y_col)
  data[[id_col]] <- as.character(data[[id_col]])
  rownames(data) <- make.unique(data[[id_col]])
  data <- apply_row_selection(data, id_col, group_col, params)
  if (nrow(data) == 0) write_error_and_exit('No rows left after filtering', '', 'Relax rows_include/rows_exclude or group selectors.')
  validate_columns(data, c(id_col, group_col, split_col, feature_cols))

  cells_highlight <- get_param_any(params, c('cells.highlight', 'highlight_rows', 'highlight_cells'), NULL)
  highlight_col <- get_param_any(params, c('highlight_column', 'highlight.by', 'cells.highlight.by'), NULL)
  highlight_levels <- as_string_vector(get_param_any(params, c('highlight_levels', 'highlight.values', 'highlight_values'), NULL))
  if (!is.null(highlight_col) && highlight_col %in% colnames(data) && length(highlight_levels) > 0) {
    cells_highlight <- data[[id_col]][as.character(data[[highlight_col]]) %in% highlight_levels]
  }

  value_cutoff <- get_param_any(params, c('value.cutoff', 'value_cutoff'), NULL)
  if (!is.null(value_cutoff)) value_cutoff <- as.numeric(unlist(value_cutoff, use.names = FALSE))[1:2]
  value_scale_range <- get_param_any(params, c('value.scale.range', 'value_scale_range'), NULL)
  if (!is.null(value_scale_range)) value_scale_range <- as.numeric(unlist(value_scale_range, use.names = FALSE))[1:2]
  value_scale_breaks <- get_param_any(params, c('value.scale.breaks', 'value_scale_breaks'), NULL)
  if (!is.null(value_scale_breaks)) value_scale_breaks <- as.numeric(unlist(value_scale_breaks, use.names = FALSE))

  layout <- tolower(as.character(get_param(params, 'feature_layout', ''))[1])
  if (identical(layout, 'single')) {
    params[['facet_ncol']] <- 1
    params[['facet_nrow']] <- 1
  } else if (layout %in% c('side_by_side', 'side by side')) {
    params[['facet_nrow']] <- 1
  }
  agg <- tolower(as.character(get_param(params, 'aggregation_style', ''))[1])
  if (agg %in% c('hex', 'hexbin')) params[['hex']] <- TRUE
  if (agg %in% c('density', 'contour', 'contours')) params[['show_density']] <- TRUE
  render_mode <- tolower(as.character(get_param(params, 'rendering_mode', ''))[1])
  if (identical(render_mode, 'raster')) params[['raster']] <- TRUE
  if (identical(render_mode, 'vector')) params[['raster']] <- FALSE
  if (as_bool(get_param(params, 'feature_comp', FALSE), FALSE) || as_bool(get_param(params, 'feature_composition', FALSE), FALSE)) {
    params[['feature_comp']] <- TRUE
  }

  list(
    data = data,
    args = list(
      data = data,
      graph = NULL,
      lineage = NULL,
      group.by = group_col,
      split.by = split_col,
      global.split = as_bool(get_param_any(params, c('global_split', 'global.split'), TRUE), TRUE),
      bg.by = get_param_any(params, c('background_column', 'bg_by', 'bg.by'), NULL),
      dims = as.numeric(unlist(get_param(params, 'dims', c(1, 2))))[1:2],
      cell.column.nm = id_col,
      keep.0 = as_bool(get_param_any(params, c('keep.0', 'keep_zero'), FALSE), FALSE),
      features = feature_cols,
      show.stat = as_bool(get_param_any(params, c('show.stat', 'show_stat'), ifelse(theme_use == 'themeBlank', FALSE, TRUE)), ifelse(theme_use == 'themeBlank', FALSE, TRUE)),
      palette = get_param_any(params, c('palette', 'feature_palette'), ifelse(as_bool(get_param_any(params, c('feature.comp', 'feature_comp'), FALSE), FALSE), 'Set1', 'Spectral')),
      palcolor = palcolor,
      pt.size = get_param_any(params, c('pt.size', 'point_size'), NULL),
      pt.alpha = num_param(params, 'point_alpha', num_param(params, 'pt.alpha', 1)),
      bg.cutoff = num_param(params, 'background_cutoff', num_param(params, 'bg.cutoff', 0)),
      bg.color = get_param_any(params, c('bg.color', 'background_color'), 'grey80'),
      scale.by = get_param_any(params, c('scale.by', 'scale_by'), 'feature'),
      quantile.cutoff = as.numeric(unlist(get_param_any(params, c('quantile.cutoff', 'quantile_cutoff'), c(0, 0.95)), use.names = FALSE))[1:2],
      value.cutoff = value_cutoff,
      value.scale.range = value_scale_range,
      value.scale.breaks = value_scale_breaks,
      feature.low.alpha = num_param(params, 'feature_low_alpha', num_param(params, 'feature.low.alpha', 0.1)),
      add.density = as_bool(get_param_any(params, c('add.density', 'show_density'), FALSE), FALSE),
      density.filled = as_bool(get_param_any(params, c('density.filled', 'density_filled'), FALSE), FALSE),
      density.color = get_param_any(params, c('density.color', 'density_color'), 'grey80'),
      density.palette = get_param_any(params, c('density.palette', 'density_palette'), 'Greys'),
      density.palcolor = get_param_any(params, c('density.palcolor', 'density_colors'), NULL),
      cells.highlight = cells_highlight,
      highlight.col = get_param_any(params, c('highlight.col', 'highlight_border_color'), 'black'),
      highlight.size = num_param(params, 'highlight_size', num_param(params, 'highlight.size', 1)),
      highlight.alpha = num_param(params, 'highlight_alpha', num_param(params, 'highlight.alpha', 1)),
      highlight.stroke = num_param(params, 'highlight_stroke', num_param(params, 'highlight.stroke', 0.5)),
      label = as_bool(get_param(params, 'label_show', get_param(params, 'label', TRUE)), TRUE),
      group.label = as_bool(get_param_any(params, c('group.label', 'group_label_show'), FALSE), FALSE),
      group.label.repel = as_bool(get_param_any(params, c('group.label.repel', 'group_label_repel'), TRUE), TRUE),
      group.label.size = num_param(params, 'group_label_size', num_param(params, 'group.label.size', 4)),
      group.label.fg = get_param_any(params, c('group.label.fg', 'group_label_color'), 'black'),
      group.label.bg = get_param_any(params, c('group.label.bg', 'group_label_bg_color'), 'white'),
      group.label.bg.r = num_param(params, 'group_label_bg_radius', num_param(params, 'group.label.bg.r', 0.1)),
      group.label.seg.color = get_param_any(params, c('group.label.seg.color', 'group_label_line_color'), 'black'),
      coexp = as_bool(get_param(params, 'coexp', FALSE), FALSE),
      feature.comp = as_bool(get_param_any(params, c('feature.comp', 'feature_comp', 'feature_composition'), FALSE), FALSE),
      color.mix.mode = get_param_any(params, c('color.mix.mode', 'color_mix_mode'), 'blend'),
      legend.title = get_param_any(params, c('legend.title', 'legend_title', 'legend_name'), NULL),
      legend.label = as_bool(get_param_any(params, c('legend.label', 'legend_label'), FALSE), FALSE),
      legend.label.size = num_param(params, 'legend_label_size', num_param(params, 'legend.label.size', 4)),
      legend.label.fg = get_param_any(params, c('legend.label.fg', 'legend_label_color'), 'white'),
      legend.label.bg = get_param_any(params, c('legend.label.bg', 'legend_label_bg_color'), 'black'),
      legend.label.bg.r = num_param(params, 'legend_label_bg_radius', num_param(params, 'legend.label.bg.r', 0.1)),
      label.insitu = as_bool(get_param_any(params, c('label.insitu', 'label_insitu'), FALSE), FALSE),
      label.repel = as_bool(get_param_any(params, c('label.repel', 'label_repel'), FALSE), FALSE),
      label.repulsion = num_param(params, 'label_force', num_param(params, 'label.repulsion', 20)),
      label.pt.size = num_param(params, 'label_point_size', num_param(params, 'label.pt.size', 1)),
      label.pt.color = get_param_any(params, c('label.pt.color', 'label_point_color'), 'black'),
      label.seg.color = get_param_any(params, c('label.seg.color', 'label_line_color'), 'black'),
      lineages = get_param(params, 'lineages', NULL),
      lineages_trim = as.numeric(unlist(get_param_any(params, c('lineages_trim', 'lineages.trim'), c(0.01, 0.99)), use.names = FALSE))[1:2],
      lineages_span = num_param(params, 'lineages_span', num_param(params, 'lineages.span', 0.75)),
      lineages_palette = get_param_any(params, c('lineages_palette', 'lineages.palette'), 'Dark2'),
      lineages_palcolor = get_param_any(params, c('lineages_palcolor', 'lineages.palcolor'), NULL),
      lineages_linewidth = num_param(params, 'lineages_linewidth', num_param(params, 'lineages.linewidth', 1)),
      edge.size = as.numeric(unlist(get_param_any(params, c('edge.size', 'edge_size'), c(0.05, 0.5)), use.names = FALSE))[1:2],
      edge.alpha = num_param(params, 'edge_alpha', num_param(params, 'edge.alpha', 0.1)),
      edge.color = get_param_any(params, c('edge.color', 'edge_color'), 'grey40'),
      hex = as_bool(get_param(params, 'hex', FALSE), FALSE),
      hex.linewidth = num_param(params, 'hex_line_width', num_param(params, 'hex.linewidth', 0.5)),
      hex.color = get_param_any(params, c('hex.color', 'hex_color'), 'grey90'),
      hex.bins = num_param(params, 'hex_bins', num_param(params, 'hex.bins', 50)),
      hex.binwidth = get_param_any(params, c('hex.binwidth', 'hex_binwidth'), NULL),
      raster = get_param(params, 'raster', NULL),
      raster.dpi = as.numeric(unlist(get_param_any(params, c('raster.dpi', 'raster_dpi'), c(512, 512)), use.names = FALSE))[1:2],
      aspect.ratio = num_param(params, 'aspect_ratio', num_param(params, 'aspect.ratio', 1)),
      title = if (as_bool(get_param(params, 'title_show', TRUE), TRUE)) get_param(params, 'title', NULL) else NULL,
      subtitle = if (as_bool(get_param(params, 'subtitle_show', TRUE), TRUE)) get_param(params, 'subtitle', NULL) else NULL,
      xlab = if (as_bool(get_param(params, 'xlab_show', TRUE), TRUE)) xlab else NULL,
      ylab = if (as_bool(get_param(params, 'ylab_show', TRUE), TRUE)) ylab else NULL,
      legend.position = get_param_any(params, c('legend.position', 'legend_position'), 'right'),
      legend.direction = get_param_any(params, c('legend.direction', 'legend_direction'), 'vertical'),
      theme.use = theme_use,
      theme.args = theme_args_from_params(params, xlab, ylab),
      combine = as_bool(get_param(params, 'combine', TRUE), TRUE),
      nrow = get_param_any(params, c('nrow', 'facet_nrow'), NULL),
      ncol = get_param_any(params, c('ncol', 'facet_ncol'), NULL),
      byrow = as_bool(get_param(params, 'byrow', TRUE), TRUE),
      force = as_bool(get_param(params, 'force', TRUE), TRUE),
      seed = num_param(params, 'seed', 10086)
    )
  )
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
  old_outputs <- file.path(output_dir, c('error.json', 'result.svg', 'result.pdf', 'result.png', 'figure.json', 'selected_rows.csv', 'run.log'))
  old_outputs <- old_outputs[file.exists(old_outputs)]
  if (length(old_outputs) > 0) unlink(old_outputs)
  write_log('Starting advanced feature plot plugin.')

  params <- jsonlite::fromJSON(params_file, simplifyVector = FALSE)
  df <- read_table_auto(input_file)
  x_col <- get_param_any(params, c('x_column', 'dim1_column'), first_existing_col(df, c('dim1', 'Dim1', 'UMAP_1', 'umap_1', 'tSNE_1', 'tsne_1', 'PC_1', 'x'), TRUE, 'x_column'))
  y_col <- get_param_any(params, c('y_column', 'dim2_column'), first_existing_col(df, c('dim2', 'Dim2', 'UMAP_2', 'umap_2', 'tSNE_2', 'tsne_2', 'PC_2', 'y'), TRUE, 'y_column'))
  id_col <- get_param_any(params, c('id_column', 'cell_column', 'cell_id_column', 'cell.column.nm'), first_existing_col(df, c('cell', 'cell_id', 'barcode', 'Cell', 'id', colnames(df)[1]), TRUE, 'id_column'))
  group_col <- get_param_any(params, c('group_column', 'group_by', 'group.by'), first_existing_col(df, c('cluster', 'celltype', 'group', 'ident', 'seurat_clusters'), FALSE, 'group_column'))
  split_col <- get_param_any(params, c('split_column', 'split_by', 'split.by'), NULL)
  feature_cols <- as_string_vector(get_param_any(params, c('feature_columns', 'features', 'feature_column'), NULL))
  if (length(feature_cols) == 0) {
    reserved <- c(x_col, y_col, id_col, group_col, split_col)
    numeric_cols <- colnames(df)[vapply(df, function(x) is.numeric(suppressWarnings(as.numeric(x))), logical(1))]
    feature_cols <- setdiff(numeric_cols, reserved)
  }
  validate_columns(df, c(x_col, y_col, id_col, group_col, split_col, feature_cols))
  if (length(feature_cols) == 0) write_error_and_exit('No feature columns selected', '', 'Set feature_columns/features in params.json.')

  load_sca_advfea_reference()
  built <- build_advfea_args(df, params, x_col, y_col, id_col, group_col, split_col, feature_cols)
  write_log(paste('SCA advFeaPlot args:',
                  paste0('features=', paste(feature_cols, collapse = ',')),
                  paste0('split.by=', split_col %||% 'NULL'),
                  paste0('feature.comp=', built$args$feature.comp),
                  paste0('hex=', built$args$hex)))
  plot <- do.call(advFeaPlot, built$args)

  write.csv(built$data, file.path(output_dir, 'selected_rows.csv'), row.names = FALSE)
  width <- num_param(params, 'width', ifelse(length(feature_cols) > 1, 9.0, 6.5))
  height <- num_param(params, 'height', ifelse(length(feature_cols) > 2, 7.0, 5.5))
  dpi <- num_param(params, 'dpi', 300)
  # Generic appearance parameters not handled by this plugin (R/runtime/omicscanvas_theme.R).
  if (!exists('omicscanvas_apply_theme')) { .oc_f <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[1]); .oc_rt <- file.path(dirname(normalizePath(.oc_f, mustWork = FALSE)), '..', '..', 'R', 'runtime', 'omicscanvas_theme.R'); if (!file.exists(.oc_rt)) .oc_rt <- file.path('R', 'runtime', 'omicscanvas_theme.R'); sys.source(.oc_rt, envir = globalenv()) }; plot <- omicscanvas_apply_theme(plot, params, only = c('legend_show', 'panel_border_show', 'show_x_axis', 'show_y_axis'))
  save_plot(plot, output_dir, width, height, dpi)

  figure <- list(
    plot_type = 'advanced_feature_plot',
    input_file = normalizePath(input_file, mustWork = FALSE),
    x_column = x_col,
    y_column = y_col,
    id_column = id_col,
    group_column = group_col,
    split_column = split_col,
    feature_columns = feature_cols,
    row_count = nrow(built$data),
    style = list(
      theme_use = built$args$theme.use,
      feature_comp = built$args$feature.comp,
      color_mix_mode = built$args$color.mix.mode,
      point_size = built$args$pt.size,
      point_alpha = built$args$pt.alpha,
      keep_zero = built$args$keep.0,
      show_density = built$args$add.density,
      hex = built$args$hex,
      raster = built$args$raster
    ),
    outputs = list(svg = 'result.svg', pdf = 'result.pdf', png = 'result.png', selected_rows = 'selected_rows.csv', log = 'run.log')
  )
  writeLines(jsonlite::toJSON(figure, auto_unbox = TRUE, pretty = TRUE), file.path(output_dir, 'figure.json'))
  write_log('Completed advanced feature plot plugin.')
}

tryCatch(main(), error = function(e) {
  write_error_and_exit('Advanced feature plot failed', conditionMessage(e), 'Check feature columns and params.json.')
})
