#!/usr/bin/env Rscript

# BioFigureAI Plot Plugin: Expression Statistic Plot
# ------------------------------------------------------------
# Runtime contract:
#   Rscript plot.R --input metadata.csv --expr expression.csv --params params.json --output output_dir
#
# This plugin wraps the original SCA expStatPlot() engine while exposing a
# stable table/JSON interface and standard result.svg/pdf/png/figure.json files.

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
  library(grid)
})

option_list <- list(
  make_option(c('--input'), type = 'character', default = NULL,
              help = 'Metadata CSV/TSV/TXT. Rows are cells/samples; first column is the row id by default.'),
  make_option(c('--expr'), type = 'character', default = NULL,
              help = 'Optional expression matrix CSV/TSV/TXT. First column is feature/gene id; remaining columns are cells/samples.'),
  make_option(c('--params'), type = 'character', default = NULL,
              help = 'Path to params.json.'),
  make_option(c('--output'), type = 'character', default = NULL,
              help = 'Output directory.')
)

opt <- parse_args(OptionParser(option_list = option_list))
input_file <- opt$input
expr_file <- opt$expr
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

as_nullable_bool <- function(x) {
  if (is.null(x)) return(NULL)
  as_bool(x, FALSE)
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

as_numeric_vector <- function(x, default = NULL) {
  if (is.null(x)) return(default)
  if (is.list(x) && !is.data.frame(x)) x <- unlist(x, use.names = FALSE)
  if (length(x) == 1 && is.character(x) && grepl(',', x, fixed = TRUE)) x <- strsplit(x, ',', fixed = TRUE)[[1]]
  value <- suppressWarnings(as.numeric(x))
  value <- value[is.finite(value)]
  if (length(value) == 0) default else value
}

as_named_vector <- function(x, default = NULL) {
  if (is.null(x)) return(default)
  values <- unlist(x, use.names = TRUE)
  if (length(values) == 0) return(default)
  out <- as.character(values)
  names(out) <- names(values)
  out
}

param_exists <- function(params, names) {
  any(vapply(names, function(name) !is.null(params[[name]]), logical(1)))
}

num_param_any <- function(params, names, default = NA_real_) {
  value <- suppressWarnings(as.numeric(get_param_any(params, names, default))[1])
  if (is.na(value)) default else value
}

first_existing_col <- function(df, candidates, required = TRUE, label = 'column') {
  hit <- candidates[candidates %in% colnames(df)][1]
  if (!is.na(hit)) return(hit)
  if (required) {
    write_error_and_exit('Could not detect required column', paste(label, 'candidates:', paste(candidates, collapse = ', ')), paste('Provide', label, 'in params.json.'))
  }
  NULL
}

validate_columns <- function(df, cols, label = 'input') {
  cols <- cols[!is.na(cols) & nzchar(cols)]
  missing_cols <- setdiff(cols, colnames(df))
  if (length(missing_cols) > 0) {
    write_error_and_exit('Required columns not found', paste(label, 'missing:', paste(missing_cols, collapse = ', ')), 'Check column params and the input header.')
  }
}

load_sca_expstat_reference <- function() {
  script_arg <- grep('^--file=', commandArgs(FALSE), value = TRUE)
  script_path <- if (length(script_arg) > 0) sub('^--file=', '', script_arg[1]) else file.path(getwd(), 'plugins', 'exp_stat_plot', 'plot.R')
  helper_dir <- file.path(dirname(normalizePath(script_path, mustWork = FALSE)), 'reference_sca_helpers')
  if (!dir.exists(helper_dir)) helper_dir <- file.path('plugins', 'exp_stat_plot', 'reference_sca_helpers')

  `%||%` <<- function(x, y) if (is.null(x) || length(x) == 0) y else x
  ckPacsR <<- function(packages, ...) {
    packages <- sub('@.*$', '', packages)
    packages <- sub('^.*/', '', packages)
    missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
    if (length(missing) > 0) stop('Missing required R package(s): ', paste(missing, collapse = ', '), call. = FALSE)
    invisible(TRUE)
  }
  ckDataType <<- function(data) {
    values <- suppressWarnings(as.numeric(as.matrix(data)))
    values <- values[is.finite(values)]
    if (length(values) == 0) return('countsLogNormal')
    if (all(values >= 0) && all(abs(values - round(values)) < 1e-8)) return('rawCounts')
    'countsLogNormal'
  }
  toDenseMatrix <<- function(x) {
    if (inherits(x, 'Matrix')) return(as.matrix(x))
    as.matrix(x)
  }
  melt <<- function(...) reshape2::melt(...)
  rescale <<- scales::rescale
  theme_scp <<- function(...) themeDefault(...)

  source(file.path(helper_dir, 'util.plot.R'), local = .GlobalEnv)
  source(file.path(helper_dir, 'expStatPlot.R'), local = .GlobalEnv)

  old_palette <- paletteCustomize
  palette_file <- file.path(getwd(), 'assets', 'palettes.rds')
  paletteCustomize <<- function(..., palettePath = NULL) {
    old_palette(..., palettePath = palettePath %||% palette_file)
  }
  invisible(TRUE)
}

prepare_metadata <- function(df, params) {
  id_col <- get_param_any(params, c('cell_id_column', 'sample_id_column', 'id_column', 'row_id_column'), NULL)
  if (is.null(id_col)) id_col <- first_existing_col(df, c('cell', 'Cell', 'cell_id', 'sample', 'Sample', 'sample_id', 'barcode', colnames(df)[1]), TRUE, 'id_column')
  validate_columns(df, id_col)
  df[[id_col]] <- make.unique(as.character(df[[id_col]]))
  rownames(df) <- df[[id_col]]

  include <- as_string_vector(get_param_any(params, c('rows_include', 'cells_include', 'samples_include'), NULL))
  exclude <- as_string_vector(get_param_any(params, c('rows_exclude', 'cells_exclude', 'samples_exclude'), NULL))
  if (length(include) > 0) df <- df[df[[id_col]] %in% include, , drop = FALSE]
  if (length(exclude) > 0) df <- df[!df[[id_col]] %in% exclude, , drop = FALSE]
  if (nrow(df) == 0) write_error_and_exit('No metadata rows left after filtering', '', 'Relax rows_include/rows_exclude.')
  attr(df, 'id_col') <- id_col
  df
}

prepare_expression <- function(path, meta, params) {
  if (is.null(path)) {
    mat <- matrix(nrow = 0, ncol = nrow(meta))
    colnames(mat) <- rownames(meta)
    return(mat)
  }
  df <- read_table_auto(path)
  gene_col <- get_param_any(params, c('feature_id_column', 'gene_id_column', 'expr_row_id_column'), colnames(df)[1])
  validate_columns(df, gene_col, 'expression')
  sample_cols <- setdiff(colnames(df), gene_col)
  sample_include <- as_string_vector(get_param_any(params, c('expr_columns_include', 'expr_samples_include'), NULL))
  sample_exclude <- as_string_vector(get_param_any(params, c('expr_columns_exclude', 'expr_samples_exclude'), NULL))
  if (length(sample_include) > 0) sample_cols <- intersect(sample_include, sample_cols)
  if (length(sample_exclude) > 0) sample_cols <- setdiff(sample_cols, sample_exclude)
  common <- intersect(sample_cols, rownames(meta))
  if (length(common) == 0) {
    write_error_and_exit('No expression columns match metadata rows', '', 'Expression column names must match metadata cell/sample ids.')
  }
  mat <- suppressWarnings(as.matrix(data.frame(lapply(df[, common, drop = FALSE], as.numeric), check.names = FALSE)))
  rownames(mat) <- make.unique(as.character(df[[gene_col]]))
  colnames(mat) <- common
  keep <- rowSums(is.finite(mat)) > 0
  mat <- mat[keep, , drop = FALSE]
  mat
}

select_stat_columns <- function(meta, expr, params, id_col, group_by, split_by, bg_by) {
  stat_cols <- as_string_vector(get_param_any(params, c('stat.by', 'stat_by', 'stat_columns', 'features', 'feature_columns'), NULL))
  if (length(stat_cols) == 0) {
    excluded <- unique(c(id_col, group_by, split_by, bg_by))
    candidates <- setdiff(colnames(meta), excluded)
    is_num <- vapply(meta[, candidates, drop = FALSE], function(x) any(is.finite(suppressWarnings(as.numeric(x)))), logical(1))
    stat_cols <- candidates[is_num]
  }
  missing <- setdiff(stat_cols, union(colnames(meta), rownames(expr)))
  if (length(missing) > 0) {
    write_error_and_exit('Requested stat features not found', paste('Missing:', paste(missing, collapse = ', ')), 'Use metadata columns or expression row names.')
  }
  if (length(stat_cols) == 0) write_error_and_exit('No stat columns selected', '', 'Set stat_columns/features or provide numeric metadata columns.')
  stat_cols
}

parse_comparisons <- function(value) {
  if (is.null(value)) return(NULL)
  if (is.logical(value)) return(if (isTRUE(value[1])) TRUE else NULL)
  if (is.character(value) && length(value) == 1) {
    v <- trimws(value)
    if (tolower(v) %in% c('true', 'yes', '1')) return(TRUE)
    if (!nzchar(v) || tolower(v) %in% c('false', 'no', '0', 'none')) return(NULL)
    chunks <- strsplit(v, ';', fixed = TRUE)[[1]]
    return(lapply(chunks, function(z) trimws(strsplit(z, ',', fixed = TRUE)[[1]])))
  }
  if (is.list(value)) return(lapply(value, function(z) as.character(unlist(z, use.names = FALSE))))
  NULL
}

theme_args_from_params <- function(params) {
  args <- get_param_any(params, c('theme.args', 'theme_args'), list())
  if (is.null(args) || !is.list(args)) args <- list()
  if (!is.null(get_param(params, 'base_size', NULL)) && is.null(args$baseSize)) args$baseSize <- num_param(params, 'base_size', 12)
  args
}

line_type_param <- function(params, names, default = NULL) {
  value <- get_param_any(params, names, default)
  if (is.null(value)) return(default)
  if (length(value) == 0) return(default)
  value[[1]]
}

margin_from_params <- function(params, prefix, default = c(0, 0, 0, 0)) {
  value <- get_param_any(params, c(prefix, paste0(prefix, '_pt')), NULL)
  if (!is.null(value)) {
    v <- as_numeric_vector(value, default)
    if (length(v) == 1) v <- rep(v, 4)
    if (length(v) >= 4) return(grid::unit(v[1:4], 'pt'))
  }
  top <- num_param_any(params, c(paste0(prefix, '_top'), paste0(prefix, '_top_pt')), default[1])
  right <- num_param_any(params, c(paste0(prefix, '_right'), paste0(prefix, '_right_pt')), default[2])
  bottom <- num_param_any(params, c(paste0(prefix, '_bottom'), paste0(prefix, '_bottom_pt')), default[3])
  left <- num_param_any(params, c(paste0(prefix, '_left'), paste0(prefix, '_left_pt')), default[4])
  grid::unit(c(top, right, bottom, left), 'pt')
}

make_text_element <- function(params, prefix, defaults = list()) {
  show <- as_bool(get_param_any(params, c(paste0(prefix, '_show'), paste0('show_', prefix)), defaults$show %||% TRUE), defaults$show %||% TRUE)
  if (!show) return(ggplot2::element_blank())
  ggplot2::element_text(
    family = get_param_any(params, c(paste0(prefix, '_font'), paste0(prefix, '_family'), 'font_family'), defaults$family %||% ''),
    face = get_param_any(params, c(paste0(prefix, '_face'), paste0(prefix, '_font_face')), defaults$face %||% 'plain'),
    colour = get_param_any(params, c(paste0(prefix, '_color'), paste0(prefix, '_colour')), defaults$color %||% 'black'),
    size = num_param_any(params, c(paste0(prefix, '_size'), paste0(prefix, '_font_size')), defaults$size %||% 11),
    angle = num_param_any(params, c(paste0(prefix, '_angle')), defaults$angle %||% 0),
    hjust = num_param_any(params, c(paste0(prefix, '_hjust')), defaults$hjust %||% 0.5),
    vjust = num_param_any(params, c(paste0(prefix, '_vjust')), defaults$vjust %||% 0.5),
    margin = margin_from_params(params, paste0(prefix, '_margin'), defaults$margin %||% c(0, 0, 0, 0))
  )
}

make_line_element <- function(params, prefix, defaults = list()) {
  show <- as_bool(get_param_any(params, c(paste0(prefix, '_show'), paste0('show_', prefix)), defaults$show %||% TRUE), defaults$show %||% TRUE)
  if (!show) return(ggplot2::element_blank())
  ggplot2::element_line(
    colour = get_param_any(params, c(paste0(prefix, '_color'), paste0(prefix, '_colour')), defaults$color %||% 'grey85'),
    linewidth = num_param_any(params, c(paste0(prefix, '_size'), paste0(prefix, '_linewidth')), defaults$size %||% 0.4),
    linetype = line_type_param(params, c(paste0(prefix, '_type'), paste0(prefix, '_linetype')), defaults$type %||% 1)
  )
}

make_rect_element <- function(params, prefix, defaults = list()) {
  show <- as_bool(get_param_any(params, c(paste0(prefix, '_show'), paste0('show_', prefix)), defaults$show %||% TRUE), defaults$show %||% TRUE)
  if (!show) return(ggplot2::element_blank())
  ggplot2::element_rect(
    fill = get_param_any(params, c(paste0(prefix, '_fill'), paste0(prefix, '_background')), defaults$fill %||% 'white'),
    colour = get_param_any(params, c(paste0(prefix, '_color'), paste0(prefix, '_colour')), defaults$color %||% NA),
    linewidth = num_param_any(params, c(paste0(prefix, '_size'), paste0(prefix, '_linewidth')), defaults$size %||% 0.4),
    linetype = line_type_param(params, c(paste0(prefix, '_type'), paste0(prefix, '_linetype')), defaults$type %||% 1)
  )
}

custom_theme_from_params <- function(params) {
  legend_show <- as_bool(get_param_any(params, c('legend_show', 'show_legend'), TRUE), TRUE)
  panel_border_show <- as_bool(get_param_any(params, c('panel_border_show', 'show_panel_border'), TRUE), TRUE)
  plot_margin <- margin_from_params(params, 'plot_margin', c(5.5, 5.5, 5.5, 5.5))
  ggplot2::theme(
    text = ggplot2::element_text(
      family = get_param(params, 'font_family', ''),
      face = get_param(params, 'font_face', 'plain'),
      colour = get_param(params, 'font_color', 'black'),
      size = num_param(params, 'font_size', 11)
    ),
    plot.title = make_text_element(params, 'title', list(size = 14, face = 'bold', hjust = 0.5, margin = c(0, 0, 4, 0))),
    plot.subtitle = make_text_element(params, 'subtitle', list(size = 11, hjust = 0.5, margin = c(0, 0, 5, 0))),
    axis.title.x = make_text_element(params, 'x_axis_title', list(size = 12, margin = c(6, 0, 0, 0))),
    axis.title.y = make_text_element(params, 'y_axis_title', list(size = 12, angle = 90, margin = c(0, 6, 0, 0))),
    axis.text.x = make_text_element(params, 'x_axis_text', list(size = 10, angle = 45, hjust = 1, vjust = 1)),
    axis.text.y = make_text_element(params, 'y_axis_text', list(size = 10, hjust = 1)),
    axis.ticks.x = make_line_element(params, 'x_axis_ticks', list(color = 'black', size = 0.35)),
    axis.ticks.y = make_line_element(params, 'y_axis_ticks', list(color = 'black', size = 0.35)),
    axis.line.x = make_line_element(params, 'x_axis_line', list(color = 'black', size = 0.45)),
    axis.line.y = make_line_element(params, 'y_axis_line', list(color = 'black', size = 0.45)),
    panel.background = make_rect_element(params, 'panel_background', list(fill = get_param(params, 'panel_fill', 'grey95'), color = NA)),
    plot.background = make_rect_element(params, 'plot_background', list(fill = get_param(params, 'plot_fill', 'white'), color = NA)),
    panel.border = if (panel_border_show) make_rect_element(params, 'panel_border', list(fill = NA, color = 'black', size = 0.45)) else ggplot2::element_blank(),
    panel.grid.major.x = make_line_element(params, 'grid_major_x', list(show = as_bool(get_param_any(params, c('grid_show', 'panel_grid_show'), TRUE)), color = 'white', size = 0.4)),
    panel.grid.major.y = make_line_element(params, 'grid_major_y', list(show = as_bool(get_param_any(params, c('grid_show', 'panel_grid_show'), TRUE)), color = 'grey80', size = 0.4, type = 2)),
    panel.grid.minor.x = make_line_element(params, 'grid_minor_x', list(show = as_bool(get_param_any(params, c('minor_grid_show', 'panel_grid_minor_show'), FALSE)), color = 'grey90', size = 0.25)),
    panel.grid.minor.y = make_line_element(params, 'grid_minor_y', list(show = as_bool(get_param_any(params, c('minor_grid_show', 'panel_grid_minor_show'), FALSE)), color = 'grey90', size = 0.25)),
    strip.text.x = make_text_element(params, 'facet_text_x', list(size = 11, face = 'plain')),
    strip.text.y = make_text_element(params, 'facet_text_y', list(size = 11, face = 'plain', angle = 0)),
    strip.background = make_rect_element(params, 'facet_background', list(fill = 'white', color = NA)),
    legend.position = if (legend_show) get_param_any(params, c('legend.position', 'legend_position'), 'right') else 'none',
    legend.direction = get_param_any(params, c('legend.direction', 'legend_direction'), 'vertical'),
    legend.title = make_text_element(params, 'legend_title', list(size = 10, face = 'plain', hjust = 0)),
    legend.text = make_text_element(params, 'legend_text', list(size = 9, hjust = 0)),
    legend.key = make_rect_element(params, 'legend_key', list(fill = NA, color = NA)),
    legend.background = make_rect_element(params, 'legend_background', list(fill = 'transparent', color = NA)),
    legend.box.background = make_rect_element(params, 'legend_box_background', list(show = FALSE, fill = NA, color = NA)),
    legend.key.size = grid::unit(num_param_any(params, c('legend_key_size', 'legend_key_size_pt'), 11), 'pt'),
    legend.spacing.x = grid::unit(num_param_any(params, c('legend_spacing_x', 'legend_spacing_x_pt'), 4), 'pt'),
    legend.spacing.y = grid::unit(num_param_any(params, c('legend_spacing_y', 'legend_spacing_y_pt'), 4), 'pt'),
    plot.margin = plot_margin
  )
}

guide_overrides_from_params <- function(params) {
  legend_title <- get_param_any(params, c('legend_name', 'legend_title_name', 'legend_title_text'), NULL)
  guide_args <- list(
    title = legend_title,
    title.position = get_param_any(params, c('legend_title_position'), 'top'),
    title.hjust = num_param_any(params, c('legend_title_hjust'), 0),
    label.position = get_param_any(params, c('legend_label_position'), 'right'),
    nrow = get_param(params, 'legend_nrow', NULL),
    ncol = get_param(params, 'legend_ncol', NULL),
    byrow = as_bool(get_param(params, 'legend_byrow', FALSE), FALSE)
  )
  guide_args <- guide_args[!vapply(guide_args, is.null, logical(1))]
  colorbar_args <- list(
    title = legend_title,
    title.position = get_param_any(params, c('colorbar_title_position', 'legend_title_position'), 'top'),
    title.hjust = num_param_any(params, c('colorbar_title_hjust', 'legend_title_hjust'), 0),
    barwidth = grid::unit(num_param_any(params, c('colorbar_width', 'legend_bar_width'), 0.4), 'cm'),
    barheight = grid::unit(num_param_any(params, c('colorbar_height', 'legend_bar_height'), 3.2), 'cm'),
    frame.colour = get_param_any(params, c('colorbar_frame_color', 'legend_bar_border_color'), 'black'),
    frame.linewidth = num_param_any(params, c('colorbar_frame_size', 'legend_bar_border_size'), 0.25),
    ticks = as_bool(get_param_any(params, c('colorbar_ticks_show', 'legend_ticks_show'), TRUE), TRUE),
    ticks.colour = get_param_any(params, c('colorbar_ticks_color', 'legend_ticks_color'), 'black')
  )
  list(discrete = do.call(ggplot2::guide_legend, guide_args),
       continuous = do.call(ggplot2::guide_colorbar, colorbar_args))
}

apply_custom_style_one <- function(p, params) {
  if (!inherits(p, c('gg', 'ggplot'))) return(p)
  title_value <- get_param(params, 'title', NULL)
  subtitle_value <- get_param(params, 'subtitle', NULL)
  xlab_value <- get_param(params, 'xlab', NULL)
  ylab_value <- get_param(params, 'ylab', NULL)
  if (!as_bool(get_param_any(params, c('title_show', 'show_title'), TRUE), TRUE)) title_value <- NULL
  if (!as_bool(get_param_any(params, c('subtitle_show', 'show_subtitle'), TRUE), TRUE)) subtitle_value <- NULL
  if (!as_bool(get_param_any(params, c('xlab_show', 'x_axis_title_show', 'show_xlab'), TRUE), TRUE)) xlab_value <- NULL
  if (!as_bool(get_param_any(params, c('ylab_show', 'y_axis_title_show', 'show_ylab'), TRUE), TRUE)) ylab_value <- NULL
  p <- p + custom_theme_from_params(params)
  if (param_exists(params, c('title', 'subtitle', 'xlab', 'ylab', 'title_show', 'subtitle_show', 'xlab_show', 'ylab_show'))) {
    p <- p + ggplot2::labs(title = title_value, subtitle = subtitle_value, x = xlab_value, y = ylab_value,
                           fill = get_param_any(params, c('legend_name', 'legend_title_name', 'legend_title_text'), ggplot2::waiver()),
                           color = get_param_any(params, c('legend_name', 'legend_title_name', 'legend_title_text'), ggplot2::waiver()))
  }
  guide_override <- guide_overrides_from_params(params)
  fill_mode <- get_param_any(params, c('fill.by', 'fill_by'), 'group')
  force_colorbar <- as_bool(get_param_any(params, c('legend_as_colorbar', 'colorbar_override_show'), identical(fill_mode, 'expression')), identical(fill_mode, 'expression'))
  force_discrete <- as_bool(get_param_any(params, c('legend_as_discrete', 'legend_override_show', 'custom_legend_show'), !force_colorbar), !force_colorbar)
  if (isTRUE(force_discrete)) {
    p <- p + ggplot2::guides(fill = guide_override$discrete, colour = guide_override$discrete)
  }
  if (isTRUE(force_colorbar)) {
    p <- p + ggplot2::guides(fill = guide_override$continuous)
  }
  x_limits <- as_string_vector(get_param_any(params, c('x_limits', 'xlim'), NULL), NULL)
  if (!is.null(x_limits) && length(x_limits) >= 2) p <- p + ggplot2::scale_x_discrete(limits = x_limits)
  y_breaks <- as_numeric_vector(get_param_any(params, c('y_breaks', 'yaxis_breaks'), NULL), NULL)
  if (!is.null(y_breaks)) p <- p + ggplot2::scale_y_continuous(breaks = y_breaks)
  p
}

build_expstat_args <- function(meta, expr, params) {
  id_col <- attr(meta, 'id_col')
  group_by <- get_param_any(params, c('group.by', 'group_by', 'group_column'), first_existing_col(meta, c('cluster', 'Cluster', 'group', 'Group', 'condition', 'orig.ident'), FALSE, 'group_column'))
  if (is.null(group_by)) {
    group_by <- 'All'
    meta[[group_by]] <- 'All'
  }
  split_by <- get_param_any(params, c('split.by', 'split_by', 'split_column'), NULL)
  bg_by <- get_param_any(params, c('bg.by', 'bg_by', 'background_column'), NULL)
  validate_columns(meta, unique(c(group_by, split_by, bg_by)), 'metadata')
  stat_cols <- select_stat_columns(meta, expr, params, id_col, group_by, split_by, bg_by)

  cells <- as_string_vector(get_param_any(params, c('cells', 'cells_include', 'rows_include'), NULL))
  if (length(cells) == 0) cells <- NULL
  cells_h <- as_string_vector(get_param_any(params, c('cells.h', 'cells_highlight', 'highlight_rows', 'highlight_cells'), NULL))
  highlight_col <- get_param_any(params, c('highlight_column', 'highlight.by', 'highlight_by'), NULL)
  highlight_levels <- as_string_vector(get_param_any(params, c('highlight_levels', 'highlight_values'), NULL))
  if (!is.null(highlight_col) && highlight_col %in% colnames(meta) && length(highlight_levels) > 0) {
    cells_h <- rownames(meta)[as.character(meta[[highlight_col]]) %in% highlight_levels]
  }
  if (length(cells_h) == 0) cells_h <- NULL

  palcolor <- as_named_vector(get_param_any(params, c('palcolor', 'colors', 'group_colors', 'feature_colors'), NULL), default = NULL)
  bg_palcolor <- as_named_vector(get_param_any(params, c('bg.palcolor', 'bg_palcolor', 'background_colors'), NULL), default = NULL)
  coexp <- get_param(params, 'coexp', NULL)
  if (!is.null(coexp)) coexp <- as_string_vector(coexp, NULL)

  list(
    expM = expr,
    meta.data = meta,
    stat.by = stat_cols,
    group.by = group_by,
    split.by = split_by,
    cells = cells,
    cells.h = cells_h,
    bg.by = bg_by,
    fill.by = get_param_any(params, c('fill.by', 'fill_by'), 'group'),
    keep.na = as_bool(get_param_any(params, c('keep.na', 'keep_na'), FALSE)),
    seperate.group = as_bool(get_param_any(params, c('seperate.group', 'separate_group', 'seperate_group'), FALSE)),
    palette = get_param(params, 'palette', 'Paired'),
    palcolor = palcolor,
    plot.type = get_param_any(params, c('plot.type', 'plot_type'), 'violin'),
    violin.scale = get_param_any(params, c('violin.scale', 'violin_scale'), 'width'),
    violin.trim = as_bool(get_param_any(params, c('violin.trim', 'violin_trim'), TRUE), TRUE),
    violin.color = get_param_any(params, c('violin.color', 'violin_color', 'violin_border_color'), NA),
    violin.linewidth = num_param_any(params, c('violin.linewidth', 'violin_linewidth', 'violin_border_size'), 0.5),
    boxplot.color = get_param_any(params, c('boxplot.color', 'boxplot_color', 'boxplot_border_color'), 'black'),
    boxplot.fill = get_param_any(params, c('boxplot.fill', 'boxplot_fill'), NULL),
    boxplot.width = num_param_any(params, c('boxplot.width', 'boxplot_width'), 0.8),
    boxplot.linewidth = num_param_any(params, c('boxplot.linewidth', 'boxplot_linewidth', 'boxplot_border_size'), 0.5),
    boxplot.outlier.shape = suppressWarnings(as.numeric(get_param_any(params, c('boxplot.outlier.shape', 'boxplot_outlier_shape'), NA))),
    median.point.color = get_param_any(params, c('median.point.color', 'median_point_color'), 'black'),
    median.point.fill = get_param_any(params, c('median.point.fill', 'median_point_fill'), 'white'),
    median.point.size = num_param_any(params, c('median.point.size', 'median_point_size'), 1.5),
    median.point.shape = as.numeric(get_param_any(params, c('median.point.shape', 'median_point_shape'), 21)),
    bar.width = num_param_any(params, c('bar.width', 'bar_width'), 0.8),
    bar.color = get_param_any(params, c('bar.color', 'bar_color', 'bar_border_color'), 'black'),
    bar.linewidth = num_param_any(params, c('bar.linewidth', 'bar_linewidth', 'bar_border_size'), 0.5),
    errorbar.width = num_param_any(params, c('errorbar.width', 'errorbar_width'), 0.2),
    errorbar.color = get_param_any(params, c('errorbar.color', 'errorbar_color'), 'black'),
    errorbar.linewidth = num_param_any(params, c('errorbar.linewidth', 'errorbar_linewidth'), 0.5),
    zero.line.show = as_bool(get_param_any(params, c('zero.line.show', 'zero_line_show'), TRUE), TRUE),
    zero.line.color = get_param_any(params, c('zero.line.color', 'zero_line_color'), 'black'),
    zero.line.type = get_param_any(params, c('zero.line.type', 'zero_line_type'), 2),
    zero.line.size = num_param_any(params, c('zero.line.size', 'zero_line_size'), 0.5),
    dot.count.shape = as.numeric(get_param_any(params, c('dot.count.shape', 'dot_count_shape'), 21)),
    dot.count.max.size = num_param_any(params, c('dot.count.max.size', 'dot_count_max_size'), 6),
    dot.count.nbreaks = as.numeric(get_param_any(params, c('dot.count.nbreaks', 'dot_count_nbreaks'), 4)),
    dot.count.legend.title = get_param_any(params, c('dot.count.legend.title', 'dot_count_legend_title'), 'Count'),
    col.color = get_param_any(params, c('col.color', 'col_color', 'column_border_color'), NA),
    col.linewidth = num_param_any(params, c('col.linewidth', 'col_linewidth', 'column_border_size'), 0.3),
    col.width = as_numeric_vector(get_param_any(params, c('col.width', 'col_width', 'column_width'), NULL), NULL),
    col.group.border.show = as_bool(get_param_any(params, c('col.group.border.show', 'col_group_border_show'), TRUE), TRUE),
    col.group.border.color = get_param_any(params, c('col.group.border.color', 'col_group_border_color'), 'black'),
    col.group.border.type = get_param_any(params, c('col.group.border.type', 'col_group_border_type'), 2),
    col.group.border.alpha = num_param_any(params, c('col.group.border.alpha', 'col_group_border_alpha'), 0.5),
    alpha = num_param(params, 'alpha', 1),
    bg.palette = get_param_any(params, c('bg.palette', 'bg_palette'), 'Paired'),
    bg.palcolor = bg_palcolor,
    bg.alpha = num_param(params, 'bg.alpha', num_param(params, 'background_alpha', 0.2)),
    add.box = as_bool(get_param_any(params, c('add.box', 'add_box'), FALSE)),
    box.color = get_param_any(params, c('box.color', 'box_color'), 'black'),
    box.width = num_param(params, 'box.width', num_param(params, 'box_width', 0.1)),
    box.ptsize = num_param(params, 'box.ptsize', num_param(params, 'box_point_size', 2)),
    add.dot = as_bool(get_param_any(params, c('add.dot', 'add_dot', 'show_points'), FALSE)),
    dot.color = get_param_any(params, c('dot.color', 'dot_color'), 'grey30'),
    dot.size = get_param_any(params, c('dot.size', 'dot_size', 'point_size'), NULL),
    dot.alpha = num_param(params, 'dot.alpha', num_param(params, 'point_alpha', 1)),
    dot.shape = as.numeric(get_param_any(params, c('dot.shape', 'dot_shape', 'point_shape'), 19)),
    highlight.shape = as.numeric(get_param_any(params, c('highlight.shape', 'highlight_shape'), 19)),
    jitter.width = num_param(params, 'jitter.width', num_param(params, 'jitter_width', 0.4)),
    jitter.height = num_param(params, 'jitter.height', num_param(params, 'jitter_height', 0.1)),
    add.trend = as_bool(get_param_any(params, c('add.trend', 'add_trend'), FALSE)),
    trend.color = get_param_any(params, c('trend.color', 'trend_color'), 'black'),
    trend.linewidth = num_param(params, 'trend.linewidth', num_param(params, 'trend_linewidth', 1)),
    trend.ptsize = num_param(params, 'trend.ptsize', num_param(params, 'trend_point_size', 2)),
    add.stat = get_param_any(params, c('add.stat', 'add_stat'), 'mean'),
    add.stat.para = get_param_any(params, c('add.stat.para', 'add_stat_params'), list()),
    stat.color = get_param_any(params, c('stat.color', 'stat_color'), 'black'),
    stat.size = num_param(params, 'stat.size', num_param(params, 'stat_size', 1)),
    stat.stroke = num_param(params, 'stat.stroke', num_param(params, 'stat_stroke', 1)),
    stat.shape = as.numeric(get_param_any(params, c('stat.shape', 'stat_shape'), 25)),
    add.line.x = as_numeric_vector(get_param_any(params, c('add.line.x', 'add_line_x', 'horizontal_lines'), NULL), NULL),
    line.color.x = get_param_any(params, c('line.color.x', 'line_color_x', 'horizontal_line_color'), 'red'),
    line.size.x = num_param(params, 'line.size.x', num_param(params, 'horizontal_line_size', 1)),
    line.type.x = get_param_any(params, c('line.type.x', 'line_type_x', 'horizontal_line_type'), 1),
    add.line.y = as_numeric_vector(get_param_any(params, c('add.line.y', 'add_line_y', 'vertical_lines'), NULL), NULL),
    line.color.y = get_param_any(params, c('line.color.y', 'line_color_y', 'vertical_line_color'), 'red'),
    line.size.y = num_param(params, 'line.size.y', num_param(params, 'vertical_line_size', 1)),
    line.type.y = get_param_any(params, c('line.type.y', 'line_type_y', 'vertical_line_type'), 1),
    cols.highlight = get_param_any(params, c('cols.highlight', 'highlight_color'), 'red'),
    sizes.highlight = num_param(params, 'sizes.highlight', num_param(params, 'highlight_size', 1)),
    alpha.highlight = num_param(params, 'alpha.highlight', num_param(params, 'highlight_alpha', 1)),
    coexp = coexp,
    coexp.para = get_param_any(params, c('coexp.para', 'coexp_params'), list()),
    same.y.lims = as_bool(get_param_any(params, c('same.y.lims', 'same_y_lims'), FALSE)),
    y.min = get_param_any(params, c('y.min', 'y_min', 'ylim_min'), NULL),
    y.max = get_param_any(params, c('y.max', 'y_max', 'ylim_max'), NULL),
    y.trans = get_param_any(params, c('y.trans', 'y_trans'), 'identity'),
    y.nbreaks = as.numeric(get_param_any(params, c('y.nbreaks', 'y_nbreaks'), 5)),
    sort = get_param(params, 'sort', 'increasing'),
    sort.by = get_param_any(params, c('sort.by', 'sort_by'), 'median'),
    stack = as_bool(get_param(params, 'stack', FALSE)),
    flip = as_bool(get_param(params, 'flip', FALSE)),
    comparisons = parse_comparisons(get_param(params, 'comparisons', NULL)),
    ref.group = get_param_any(params, c('ref.group', 'ref_group'), NULL),
    pairwise.method = get_param_any(params, c('pairwise.method', 'pairwise_method'), 'wilcox.test'),
    multiple.method = get_param_any(params, c('multiple.method', 'multiple_method'), 'kruskal.test'),
    sig.label = get_param_any(params, c('sig.label', 'sig_label'), 'p.signif'),
    multiplegroup.comparisons = as_bool(get_param_any(params, c('multiplegroup.comparisons', 'multiplegroup_comparisons'), FALSE)),
    sig.labelsize = num_param(params, 'sig.labelsize', num_param(params, 'sig_label_size', 3.5)),
    aspect.ratio = get_param_any(params, c('aspect.ratio', 'aspect_ratio'), NULL),
    title = get_param(params, 'title', NULL),
    subtitle = get_param(params, 'subtitle', NULL),
    xlab = get_param(params, 'xlab', NULL),
    ylab = get_param(params, 'ylab', 'Expression level'),
    legend.position = get_param_any(params, c('legend.position', 'legend_position'), 'right'),
    legend.direction = get_param_any(params, c('legend.direction', 'legend_direction'), 'vertical'),
    theme.use = get_param_any(params, c('theme.use', 'theme_use'), 'themeDefault'),
    theme.args = theme_args_from_params(params),
    force = as_bool(get_param(params, 'force', TRUE), TRUE),
    seed = as.numeric(get_param(params, 'seed', 10086))
  )
}

save_plot_all <- function(plot_obj, outdir, params) {
  width <- num_param(params, 'width', 8)
  height <- num_param(params, 'height', 5)
  dpi <- as.numeric(get_param(params, 'dpi', 300))
  files <- list(
    svg = file.path(outdir, 'result.svg'),
    pdf = file.path(outdir, 'result.pdf'),
    png = file.path(outdir, 'result.png')
  )
  for (ext in names(files)) {
    ggplot2::ggsave(files[[ext]], plot = plot_obj, width = width, height = height, units = 'in', dpi = dpi, limitsize = FALSE)
  }
}

normalize_plot_object <- function(plot_obj, params) {
  if (is.list(plot_obj) && !inherits(plot_obj, c('gg', 'ggplot', 'gtable', 'patchwork'))) {
    plot_obj <- lapply(plot_obj, apply_custom_style_one, params = params)
    nrow <- get_param(params, 'nrow', NULL)
    ncol <- get_param(params, 'ncol', NULL)
    byrow <- as_bool(get_param(params, 'byrow', TRUE), TRUE)
    return(patchwork::wrap_plots(plotlist = plot_obj, nrow = nrow, ncol = ncol, byrow = byrow))
  }
  if (inherits(plot_obj, c('gg', 'ggplot'))) return(apply_custom_style_one(plot_obj, params))
  if (inherits(plot_obj, 'patchwork')) return(plot_obj & custom_theme_from_params(params))
  plot_obj
}

main <- function() {
  if (is.null(input_file) || is.null(params_file) || is.null(output_dir)) {
    write_error_and_exit('Missing required arguments', '', 'Use --input metadata.csv --params params.json --output output_dir. Optional: --expr expression.csv.')
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  unlink(file.path(output_dir, 'error.json'))
  writeLines('', file.path(output_dir, 'run.log'))
  write_log('Starting exp_stat_plot plugin.')
  params <- jsonlite::fromJSON(params_file, simplifyVector = FALSE)
  load_sca_expstat_reference()

  meta <- prepare_metadata(read_table_auto(input_file), params)
  id_col <- attr(meta, 'id_col')
  expr <- prepare_expression(expr_file, meta, params)
  common <- intersect(colnames(expr), rownames(meta))
  if (length(common) > 0) {
    meta <- meta[common, , drop = FALSE]
    attr(meta, 'id_col') <- id_col
    expr <- expr[, common, drop = FALSE]
  }
  args <- build_expstat_args(meta, expr, params)
  write_log(paste('Plot type:', args$plot.type))
  write_log(paste('Stat features:', paste(args$stat.by, collapse = ', ')))
  plot_obj <- tryCatch(do.call(expStatPlot, args), error = function(e) e)
  if (inherits(plot_obj, 'error')) {
    write_error_and_exit('expStatPlot failed', conditionMessage(plot_obj), 'Check selected columns/features and parameter values.')
  }
  plot_obj <- normalize_plot_object(plot_obj, params)
  save_plot_all(plot_obj, output_dir, params)
  used_meta <- meta
  used_meta[[attr(meta, 'id_col')]] <- rownames(meta)
  write.csv(used_meta, file.path(output_dir, 'selected_rows.csv'), row.names = FALSE)
  figure <- list(
    plugin = 'exp_stat_plot',
    source_engine = 'SCA::expStatPlot',
    input = normalizePath(input_file, mustWork = FALSE),
    expression = if (!is.null(expr_file)) normalizePath(expr_file, mustWork = FALSE) else NULL,
    rows = nrow(meta),
    expression_features = nrow(expr),
    stat_features = args$stat.by,
    group_by = args$group.by,
    split_by = args$split.by,
    plot_type = args$plot.type,
    fill_by = args$fill.by,
    outputs = c('result.svg', 'result.pdf', 'result.png', 'selected_rows.csv')
  )
  writeLines(jsonlite::toJSON(figure, auto_unbox = TRUE, pretty = TRUE), file.path(output_dir, 'figure.json'))
  write_log('Finished successfully.')
}

tryCatch(main(), error = function(e) {
  write_error_and_exit('Unhandled plugin error', conditionMessage(e), 'Inspect run.log and params.json.')
})
