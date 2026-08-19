#!/usr/bin/env Rscript

# BioFigureAI Plot Plugin: Advanced Dimension Plot
# ------------------------------------------------------------
# Runtime contract:
#   Rscript plot.R --input input.csv --params params.json --output output_dir
#
# Purpose:
#   Draw highly customizable 2D embedding plots such as UMAP/t-SNE/PCA/dim1-dim2
#   views with group colors, feature gradients, split panels, labels, highlights,
#   density/hex modes, mark regions, coexpression color mixing, and lineage paths.

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
  library(ggrepel)
  library(patchwork)
  library(grid)
})

option_list <- list(
  make_option(c('--input'), type = 'character', default = NULL,
              help = 'Path to the embedding table, usually CSV/TSV/TXT.'),
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

set_if_missing <- function(params, to, from, transform = identity) {
  if (is.null(params[[to]]) && !is.null(params[[from]])) params[[to]] <- transform(params[[from]])
  params
}

normalize_theme_name <- function(x) {
  value <- as.character(x)[1]
  if (is.na(value) || !nzchar(value)) return(value)
  if (value == 'themeBlank') return('blank')
  if (value == 'themeDefault') return('default')
  value
}

normalize_advdim_params <- function(params) {
  # Accept the old SCA advDimPlot argument names while keeping the new
  # BioFigureAI names as the stable plugin surface.
  params <- set_if_missing(params, 'group_column', 'group.by')
  params <- set_if_missing(params, 'split_column', 'split.by')
  params <- set_if_missing(params, 'stat_plot_column', 'stat.plot.by')
  params <- set_if_missing(params, 'background_column', 'bg.by')
  params <- set_if_missing(params, 'background_cutoff', 'bg.cutoff')
  params <- set_if_missing(params, 'background_color', 'bg.color')
  params <- set_if_missing(params, 'point_size', 'pt.size')
  params <- set_if_missing(params, 'point_alpha', 'pt.alpha')
  params <- set_if_missing(params, 'group_colors', 'palcolor')
  params <- set_if_missing(params, 'stat_colors', 'stat.palcolor')
  params <- set_if_missing(params, 'group_palette', 'palette')
  params <- set_if_missing(params, 'stat_palette', 'stat.plot.palette')
  params <- set_if_missing(params, 'show_mark', 'show.mark')
  params <- set_if_missing(params, 'mark_type', 'mark.type')
  params <- set_if_missing(params, 'mark_alpha', 'mark.alpha')
  params <- set_if_missing(params, 'mark_linetype', 'mark.linetype')
  params <- set_if_missing(params, 'mark_line_width', 'mark.linewidth')
  params <- set_if_missing(params, 'show_density', 'add.density')
  params <- set_if_missing(params, 'density_filled', 'density.filled')
  params <- set_if_missing(params, 'density_color', 'density.color')
  params <- set_if_missing(params, 'highlight_rows', 'cells.highlight')
  params <- set_if_missing(params, 'highlight_border_color', 'highlight.col')
  params <- set_if_missing(params, 'highlight_size', 'highlight.size')
  params <- set_if_missing(params, 'highlight_alpha', 'highlight.alpha')
  params <- set_if_missing(params, 'highlight_stroke', 'highlight.stroke')
  params <- set_if_missing(params, 'non_highlight_color', 'non.highlight.col')
  params <- set_if_missing(params, 'non_highlight_alpha', 'non.highlight.alpha')
  params <- set_if_missing(params, 'color_mix_mode', 'color.mix.mode')
  params <- set_if_missing(params, 'label_show', 'label')
  params <- set_if_missing(params, 'label_size', 'label.size')
  params <- set_if_missing(params, 'label_repel', 'label.repel')
  params <- set_if_missing(params, 'label_force', 'label.repulsion')
  params <- set_if_missing(params, 'label_point_size', 'label.pt.size')
  params <- set_if_missing(params, 'label_point_color', 'label.pt.color')
  params <- set_if_missing(params, 'label_color', 'label.fg')
  params <- set_if_missing(params, 'label_bg_color', 'label.bg')
  params <- set_if_missing(params, 'label_line_color', 'label.seg.color')
  params <- set_if_missing(params, 'lineage_line_width', 'lineages_linewidth')
  params <- set_if_missing(params, 'legend_position', 'legend.position')
  params <- set_if_missing(params, 'legend_direction', 'legend.direction')
  params <- set_if_missing(params, 'facet_nrow', 'nrow')
  params <- set_if_missing(params, 'facet_ncol', 'ncol')
  params <- set_if_missing(params, 'font_family', 'font_type')
  params <- set_if_missing(params, 'axis_title_font_family', 'axis_label_font_type')
  params <- set_if_missing(params, 'axis_title_font_family', 'axis_label_font_family')
  params <- set_if_missing(params, 'axis_title_size', 'axis_label_size')
  params <- set_if_missing(params, 'axis_title_margin', 'axis_label_distance')
  params <- set_if_missing(params, 'x_axis_title_margin_top', 'x_axis_label_distance')
  params <- set_if_missing(params, 'y_axis_title_margin_right', 'y_axis_label_distance')
  params <- set_if_missing(params, 'theme_use', 'theme.use', normalize_theme_name)
  if (!is.null(params[['theme_use']])) params[['theme_use']] <- normalize_theme_name(params[['theme_use']])
  if (!is.null(params[['stat_plot_column']]) && is.null(params[['show_stat_embedded']]) && is.null(params[['show_stat_panel']])) {
    params[['show_stat_embedded']] <- TRUE
  }
  if (is.null(params[['label_groups']]) && as_bool(params[['label_show']], TRUE)) params[['label_groups']] <- TRUE
  if (is.null(params[['label_repel']])) params[['label_repel']] <- FALSE
  if (is.null(params[['advdim_compat']])) params[['advdim_compat']] <- TRUE
  params
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

palette_values <- function(n, params, prefix = 'group') {
  explicit <- as_string_vector(get_param_any(params, c(paste0(prefix, '_colors'), 'palette_colors', 'palcolor'), NULL))
  if (length(explicit) > 0) return(rep(explicit, length.out = n))
  scheme <- as.character(get_param_any(params, c(paste0(prefix, '_palette'), 'palette'), 'Set2'))[1]
  if (requireNamespace('RColorBrewer', quietly = TRUE) && scheme %in% rownames(RColorBrewer::brewer.pal.info)) {
    maxn <- RColorBrewer::brewer.pal.info[scheme, 'maxcolors']
    return(grDevices::colorRampPalette(RColorBrewer::brewer.pal(min(maxn, max(3, min(maxn, n))), scheme))(n))
  }
  grDevices::hcl.colors(n, palette = ifelse(scheme %in% grDevices::hcl.pals(), scheme, 'Dark 3'))
}

named_palette <- function(levels, params, prefix = 'group', default = '#BDBDBD') {
  colors <- stats::setNames(rep(palette_values(length(levels), params, prefix), length.out = length(levels)), levels)
  named <- as_named_vector(get_param_any(params, c(paste0(prefix, '_color_map'), paste0(prefix, '_level_colors')), NULL), default = NULL)
  if (!is.null(named) && !is.null(names(named))) {
    hits <- intersect(names(named), levels)
    colors[hits] <- named[hits]
  }
  colors[is.na(colors) | !nzchar(colors)] <- default
  colors
}

cap_numeric <- function(x, lower_q = 0.01, upper_q = 0.99, limits = NULL) {
  x <- suppressWarnings(as.numeric(x))
  if (!is.null(limits)) {
    lim <- suppressWarnings(as.numeric(unlist(limits, use.names = FALSE)))
    if (length(lim) >= 2 && all(is.finite(lim[1:2]))) return(pmax(pmin(x, lim[2]), lim[1]))
  }
  qs <- stats::quantile(x, c(lower_q, upper_q), na.rm = TRUE)
  if (any(!is.finite(qs)) || qs[1] == qs[2]) return(x)
  pmax(pmin(x, qs[2]), qs[1])
}

normalize01 <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  rng <- range(x, na.rm = TRUE)
  if (any(!is.finite(rng)) || rng[1] == rng[2]) return(rep(0.5, length(x)))
  z <- (x - rng[1]) / (rng[2] - rng[1])
  pmax(pmin(z, 1), 0)
}

mix_colors <- function(values, colors, mode = 'blend') {
  values <- as.data.frame(values)
  z <- as.data.frame(lapply(values, normalize01))
  rgb_m <- lapply(seq_along(colors), function(i) grDevices::col2rgb(colors[i]) / 255)
  n <- nrow(values)
  out <- matrix(0, nrow = n, ncol = 3)
  mode <- tolower(mode)
  if (mode == 'screen') {
    out[,] <- 1
    for (i in seq_along(rgb_m)) out <- out * (1 - matrix(rep(as.numeric(rgb_m[[i]]), each = n), ncol = 3) * z[[i]])
    out <- 1 - out
  } else if (mode == 'multiply') {
    out[,] <- 1
    for (i in seq_along(rgb_m)) out <- out * (matrix(rep(as.numeric(rgb_m[[i]]), each = n), ncol = 3) * pmax(z[[i]], 0.08))
  } else {
    weight <- rowSums(z)
    weight[weight == 0] <- 1
    for (i in seq_along(rgb_m)) out <- out + matrix(rep(as.numeric(rgb_m[[i]]), each = n), ncol = 3) * z[[i]]
    out <- out / weight
  }
  out <- pmax(pmin(out, 1), 0)
  grDevices::rgb(out[, 1], out[, 2], out[, 3])
}

load_sca_advdim_reference <- function() {
  script_arg <- grep('^--file=', commandArgs(FALSE), value = TRUE)
  script_path <- if (length(script_arg) > 0) sub('^--file=', '', script_arg[1]) else file.path(getwd(), 'plugins', 'advanced_dim_plot', 'plot.R')
  helper_dir <- file.path(dirname(normalizePath(script_path, mustWork = FALSE)), 'reference_sca_helpers')
  if (!dir.exists(helper_dir)) helper_dir <- file.path('plugins', 'advanced_dim_plot', 'reference_sca_helpers')
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
  theme_scp <<- function(...) themeDefault(...)
  source(file.path(helper_dir, 'util.plot.R'), local = .GlobalEnv)
  source(file.path(helper_dir, 'add.on.layers.4.dimplot.R'), local = .GlobalEnv)
  source(file.path(helper_dir, 'expStatPlot.R'), local = .GlobalEnv)
  source(file.path(helper_dir, 'statPlot.R'), local = .GlobalEnv)
  source(file.path(helper_dir, 'advDimPlot.R'), local = .GlobalEnv)

  old_palette <- paletteCustomize
  palette_file <- file.path(getwd(), 'assets', 'palettes.rds')
  paletteCustomize <<- function(..., palettePath = NULL) {
    old_palette(..., palettePath = palettePath %||% palette_file)
  }
  invisible(TRUE)
}

advdim_theme_args_from_params <- function(params) {
  args <- get_param_any(params, c('theme_args', 'theme.args'), list())
  if (is.null(args) || !is.list(args)) args <- list()
  if (!is.null(get_param(params, 'axis_label_size', NULL)) && is.null(args$lab.size)) args$lab.size <- num_param(params, 'axis_label_size', 12)
  if (!is.null(get_param(params, 'axis_arrow_x_length_npc', NULL)) && is.null(args$xlen.npc)) args$xlen.npc <- num_param(params, 'axis_arrow_x_length_npc', 0.15)
  if (!is.null(get_param(params, 'axis_arrow_y_length_npc', NULL)) && is.null(args$ylen.npc)) args$ylen.npc <- num_param(params, 'axis_arrow_y_length_npc', 0.15)
  args
}

params_to_advdim_args <- function(params, df, x_col, y_col, id_col, group_col, split_col) {
  data <- df
  data$x <- suppressWarnings(as.numeric(data[[x_col]]))
  data$y <- suppressWarnings(as.numeric(data[[y_col]]))
  data <- data[is.finite(data$x) & is.finite(data$y), , drop = FALSE]
  data[[id_col]] <- as.character(data[[id_col]])
  rownames(data) <- make.unique(data[[id_col]])
  if (!is.null(group_col) && group_col %in% colnames(data)) data[[group_col]] <- factor(data[[group_col]], levels = unique(data[[group_col]]))
  if (!is.null(split_col) && split_col %in% colnames(data)) data[[split_col]] <- factor(data[[split_col]], levels = unique(data[[split_col]]))
  stat_col <- get_param_any(params, c('stat_plot_column', 'stat_plot_by', 'stat.by', 'stat.plot.by'), NULL)
  stat_col_for_adv <- stat_col
  if (is.null(get_param_any(params, c('stat.plot.by', 'stat.by'), NULL)) && !as_bool(get_param(params, 'show_stat_embedded', FALSE), FALSE)) {
    stat_col_for_adv <- NULL
  }
  bg_col <- get_param_any(params, c('background_column', 'bg_by', 'bg.by'), NULL)
  if (!is.null(stat_col) && stat_col %in% colnames(data)) data[[stat_col]] <- factor(data[[stat_col]], levels = unique(data[[stat_col]]))
  cells_highlight <- get_param_any(params, c('cells.highlight', 'highlight_rows', 'highlight_cells'), NULL)
  highlight_col <- get_param_any(params, c('highlight_column', 'highlight.by', 'cells.highlight.by'), NULL)
  highlight_levels <- as_string_vector(get_param_any(params, c('highlight_levels', 'highlight.values', 'highlight_values'), NULL))
  if (!is.null(highlight_col) && highlight_col %in% colnames(data) && length(highlight_levels) > 0) {
    cells_highlight <- data[[id_col]][as.character(data[[highlight_col]]) %in% highlight_levels]
  }
  palcolor <- get_param_any(params, c('palcolor', 'group_colors'), NULL)
  group_color_map <- as_named_vector(get_param_any(params, c('group_color_map', 'group_level_colors'), NULL), default = NULL)
  if (!is.null(group_color_map)) palcolor <- group_color_map
  stat_palcolor <- get_param_any(params, c('stat.palcolor', 'stat_colors'), NULL)
  stat_color_map <- as_named_vector(get_param_any(params, c('stat_color_map', 'stat_level_colors'), NULL), default = NULL)
  if (!is.null(stat_color_map)) stat_palcolor <- stat_color_map

  adv_split_col <- split_col
  if (!as_bool(get_param(params, 'facet_split', TRUE), TRUE) && is.null(get_param_any(params, c('split.by', 'advdim_split_by'), NULL))) {
    adv_split_col <- NULL
  }
  adv_split_col <- get_param_any(params, c('advdim_split_by', 'split.by'), adv_split_col)

  list(
    data = data,
    args = list(
      data = data,
      group.by = group_col,
      split.by = adv_split_col,
      stat.plot.by = stat_col_for_adv,
      global.split = as_bool(get_param_any(params, c('global_split', 'global.split'), TRUE), TRUE),
      bg.by = bg_col,
      dims = as.numeric(unlist(get_param(params, 'dims', c(1, 2))))[1:2],
      cell.column.nm = id_col,
      show.stat = as_bool(get_param_any(params, c('show_stat', 'show.stat'), FALSE), FALSE),
      palette = get_param_any(params, c('palette', 'group_palette'), 'Spectral'),
      palcolor = palcolor,
      pt.size = get_param_any(params, c('pt.size', 'point_size'), NULL),
      pt.alpha = num_param(params, 'point_alpha', num_param(params, 'pt.alpha', 1)),
      bg.cutoff = get_param_any(params, c('bg.cutoff', 'background_cutoff'), 0),
      bg.color = get_param_any(params, c('bg.color', 'background_color'), 'grey80'),
      show.mark = as_bool(get_param_any(params, c('show.mark', 'show_mark'), FALSE), FALSE),
      mark.type = get_param_any(params, c('mark.type', 'mark_type'), 'hull'),
      mark.alpha = num_param(params, 'mark_alpha', num_param(params, 'mark.alpha', 0.1)),
      mark.linetype = get_param_any(params, c('mark.linetype', 'mark_linetype'), 1),
      stat.plot.source = get_param_any(params, c('stat.plot.source', 'stat_plot_source'), 'percent'),
      stat.plot.type = get_param_any(params, c('stat.plot.type', 'stat_plot_type'), 'pie'),
      stat.plot.position = get_param_any(params, c('stat.plot.position', 'stat_plot_position'), 'stack'),
      stat.plot.size = num_param(params, 'stat_embedded_size', num_param(params, 'stat.plot.size', 0.15)),
      stat.plot.palette = get_param_any(params, c('stat.plot.palette', 'stat_palette'), 'Set1'),
      stat.palcolor = stat_palcolor,
      stat.plot.alpha = num_param(params, 'stat_embedded_alpha', num_param(params, 'stat.plot.alpha', 1)),
      add.density = as_bool(get_param_any(params, c('add.density', 'show_density'), FALSE), FALSE),
      density.filled = as_bool(get_param_any(params, c('density.filled', 'density_filled'), FALSE), FALSE),
      density.color = get_param_any(params, c('density.color', 'density_color'), 'grey80'),
      cells.highlight = cells_highlight,
      highlight.col = get_param_any(params, c('highlight.col', 'highlight_border_color'), 'black'),
      highlight.size = num_param(params, 'highlight_size', num_param(params, 'highlight.size', 1)),
      highlight.alpha = num_param(params, 'highlight_alpha', num_param(params, 'highlight.alpha', 1)),
      highlight.stroke = num_param(params, 'highlight_stroke', num_param(params, 'highlight.stroke', 0.5)),
      highlight.mode = get_param_any(params, c('highlight.mode', 'highlight_mode'), 'overlay'),
      non.highlight.col = get_param_any(params, c('non.highlight.col', 'non_highlight_color'), 'grey50'),
      non.highlight.alpha = get_param_any(params, c('non.highlight.alpha', 'non_highlight_alpha'), NULL),
      label = as_bool(get_param(params, 'label_show', get_param(params, 'label', TRUE)), TRUE),
      label.size = num_param(params, 'label_size', num_param(params, 'label.size', 4)),
      label.insitu = as_bool(get_param_any(params, c('label.insitu', 'label_insitu'), FALSE), FALSE),
      label.repel = as_bool(get_param_any(params, c('label.repel', 'label_repel'), FALSE), FALSE),
      label.repulsion = num_param(params, 'label_force', num_param(params, 'label.repulsion', 20)),
      label.pt.size = num_param(params, 'label_point_size', num_param(params, 'label.pt.size', 1)),
      label.pt.color = get_param_any(params, c('label.pt.color', 'label_point_color'), 'black'),
      label.fg = get_param_any(params, c('label.fg', 'label_color'), 'white'),
      label.bg = get_param_any(params, c('label.bg', 'label_bg_color'), 'black'),
      label.seg.color = get_param_any(params, c('label.seg.color', 'label_line_color'), 'black'),
      hex = as_bool(get_param(params, 'hex', FALSE), FALSE),
      hex.count = as_bool(get_param_any(params, c('hex.count', 'hex_count'), TRUE), TRUE),
      hex.bins = num_param(params, 'hex_bins', num_param(params, 'hex.bins', 50)),
      raster = as_bool(get_param(params, 'raster', FALSE), FALSE),
      aspect.ratio = num_param(params, 'aspect_ratio', num_param(params, 'aspect.ratio', 1)),
      title = if (as_bool(get_param(params, 'title_show', TRUE), TRUE)) get_param(params, 'title', NULL) else NULL,
      subtitle = if (as_bool(get_param(params, 'subtitle_show', TRUE), TRUE)) get_param(params, 'subtitle', NULL) else NULL,
      xlab = if (as_bool(get_param(params, 'xlab_show', TRUE), TRUE)) get_param(params, 'xlab', x_col) else NULL,
      ylab = if (as_bool(get_param(params, 'ylab_show', TRUE), TRUE)) get_param(params, 'ylab', y_col) else NULL,
      legend.position = get_param_any(params, c('legend.position', 'legend_position'), 'right'),
      legend.direction = get_param_any(params, c('legend.direction', 'legend_direction'), 'vertical'),
      theme.use = normalize_theme_name(get_param_any(params, c('theme.use', 'theme_use'), 'themeDefault')),
      theme.args = advdim_theme_args_from_params(params),
      combine = TRUE,
      nrow = get_param_any(params, c('nrow', 'facet_nrow'), NULL),
      ncol = get_param_any(params, c('ncol', 'facet_ncol'), NULL),
      byrow = as_bool(get_param(params, 'byrow', TRUE), TRUE),
      force = TRUE,
      seed = num_param(params, 'seed', 10086)
    )
  )
}

make_sca_advdim_plot <- function(df, params, x_col, y_col, id_col, group_col, split_col) {
  load_sca_advdim_reference()
  packed <- params_to_advdim_args(params, df, x_col, y_col, id_col, group_col, split_col)
  args <- packed$args
  if (identical(args$theme.use, 'blank')) args$theme.use <- 'themeBlank'
  if (identical(args$theme.use, 'default') || identical(args$theme.use, 'classic') || identical(args$theme.use, 'minimal')) args$theme.use <- 'themeDefault'
  write_log(paste('SCA advDimPlot args:',
                  paste0('group.by=', args$group.by %||% 'NULL'),
                  paste0('split.by=', args$split.by %||% 'NULL'),
                  paste0('stat.plot.by=', args$stat.plot.by %||% 'NULL'),
                  paste0('nrow=', args$nrow %||% 'NULL'),
                  paste0('ncol=', args$ncol %||% 'NULL')))
  plot <- do.call(advDimPlot, args)
  write_log('SCA advDimPlot upper plot completed.')
  if (as_bool(get_param(params, 'show_stat_panel', FALSE), FALSE)) {
    panel_group <- get_param_any(params, c('stat_panel_group_column', 'stat.panel.group.by'), split_col %||% args$split.by %||% args$group.by)
    panel_stat <- get_param_any(params, c('stat_panel_stat_column', 'stat.panel.stat.by'), args$group.by)
    if (is.null(panel_group) || is.null(panel_stat)) return(list(plot = plot, selected = packed$data))
    tab <- as.data.frame(table(group = packed$data[[panel_group]], stat = packed$data[[panel_stat]]), stringsAsFactors = FALSE)
    tab <- tab[tab$Freq > 0, , drop = FALSE]
    stat_type <- get_param_any(params, c('stat_panel_source', 'stat_plot_source'), 'percent')
    if (identical(stat_type, 'percent')) {
      tab$value <- tab$Freq / ave(tab$Freq, tab$group, FUN = sum) * 100
      ylab <- get_param(params, 'stat_ylab', 'Percent')
    } else {
      tab$value <- tab$Freq
      ylab <- get_param(params, 'stat_ylab', 'Count')
    }
    stat_levels <- unique(as.character(packed$data[[panel_stat]]))
    stat_cols <- paletteCustomize(factor(stat_levels, levels = stat_levels), palette = args$palette, palcolor = args$palcolor)
    write_log(paste('Building stat panel:', paste0('group=', panel_group), paste0('stat=', panel_stat), paste0('rows=', nrow(tab))))
    bar <- ggplot(tab, aes(x = group, y = value, fill = stat)) +
      geom_col(width = num_param(params, 'stat_bar_width', 0.8), color = get_param(params, 'stat_bar_border_color', 'black'), linewidth = num_param(params, 'stat_bar_border_width', 0.2), alpha = num_param(params, 'stat_plot_alpha', 1), position = get_param_any(params, c('stat_panel_position', 'stat_plot_position'), 'stack')) +
      scale_fill_manual(values = stat_cols, name = get_param(params, 'stat_legend_name', panel_stat)) +
      scale_y_continuous(expand = c(0, 0)) +
      labs(x = get_param(params, 'stat_xlab', NULL), y = ylab) +
      themeDefault(legend.position = get_param_any(params, c('stat_legend_position', 'legend_position'), 'right'), legend.direction = args$legend.direction)
    rel_heights <- as.numeric(unlist(get_param(params, 'stat_rel_heights', list(3, 1))))
    write_log('Arranging upper/stat plots with cowplot.')
    plot <- cowplot::plot_grid(
      cowplot::as_grob(plot),
      cowplot::as_grob(bar),
      ncol = 1,
      rel_heights = rel_heights
    )
  }
  list(plot = plot, selected = packed$data)
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

theme_for_plot <- function(params) {
  theme_name <- tolower(as.character(get_param(params, 'theme_use', get_param(params, 'theme', 'default')))[1])
  base <- switch(
    theme_name,
    blank = theme_void(base_family = get_param(params, 'font_family', 'sans')),
    minimal = theme_minimal(base_family = get_param(params, 'font_family', 'sans')),
    classic = theme_classic(base_family = get_param(params, 'font_family', 'sans')),
    theme_classic(base_family = get_param(params, 'font_family', 'sans')) +
      theme(
        plot.background = element_rect(fill = 'white', color = 'white'),
        panel.background = element_rect(fill = 'white', color = 'white'),
        axis.line = element_blank(),
        panel.border = element_rect(fill = NA, color = 'black', linewidth = 1)
      )
  )
  out <- base + theme(
    aspect.ratio = num_param(params, 'aspect_ratio', 1),
    plot.title = element_text(size = num_param(params, 'title_size', 14), face = get_param(params, 'title_fontface', 'plain'), color = get_param(params, 'title_color', 'black'), hjust = num_param(params, 'title_hjust', 0)),
    plot.subtitle = element_text(size = num_param(params, 'subtitle_size', 13), color = get_param(params, 'subtitle_color', 'black'), hjust = num_param(params, 'subtitle_hjust', 0), margin = margin(b = 3)),
    axis.title = element_text(size = num_param(params, 'axis_title_size', 13), color = get_param(params, 'axis_title_color', 'black'), face = get_param(params, 'axis_title_fontface', 'plain'), family = get_param(params, 'axis_title_font_family', get_param(params, 'font_family', 'sans'))),
    axis.title.x = element_text(size = num_param(params, 'x_axis_title_size', num_param(params, 'axis_title_size', 13)), color = get_param(params, 'x_axis_title_color', get_param(params, 'axis_title_color', 'black')), face = get_param(params, 'x_axis_title_fontface', get_param(params, 'axis_title_fontface', 'plain')), family = get_param(params, 'x_axis_title_font_family', get_param(params, 'axis_title_font_family', get_param(params, 'font_family', 'sans'))), margin = margin(t = num_param(params, 'x_axis_title_margin_top', num_param(params, 'axis_title_margin', 6)), r = num_param(params, 'x_axis_title_margin_right', 0), b = num_param(params, 'x_axis_title_margin_bottom', 0), l = num_param(params, 'x_axis_title_margin_left', 0))),
    axis.title.y = element_text(size = num_param(params, 'y_axis_title_size', num_param(params, 'axis_title_size', 13)), color = get_param(params, 'y_axis_title_color', get_param(params, 'axis_title_color', 'black')), face = get_param(params, 'y_axis_title_fontface', get_param(params, 'axis_title_fontface', 'plain')), family = get_param(params, 'y_axis_title_font_family', get_param(params, 'axis_title_font_family', get_param(params, 'font_family', 'sans'))), angle = num_param(params, 'y_axis_title_angle', 90), margin = margin(t = num_param(params, 'y_axis_title_margin_top', 0), r = num_param(params, 'y_axis_title_margin_right', num_param(params, 'axis_title_margin', 6)), b = num_param(params, 'y_axis_title_margin_bottom', 0), l = num_param(params, 'y_axis_title_margin_left', 0))),
    axis.text = element_text(size = num_param(params, 'axis_text_size', 12), color = get_param(params, 'axis_text_color', 'black'), family = get_param(params, 'axis_text_font_family', get_param(params, 'font_family', 'sans')), face = get_param(params, 'axis_text_fontface', 'plain')),
    axis.text.x = element_text(size = num_param(params, 'x_axis_text_size', num_param(params, 'axis_text_size', 12)), color = get_param(params, 'x_axis_text_color', get_param(params, 'axis_text_color', 'black')), family = get_param(params, 'x_axis_text_font_family', get_param(params, 'axis_text_font_family', get_param(params, 'font_family', 'sans'))), angle = num_param(params, 'x_axis_text_angle', 0), hjust = num_param(params, 'x_axis_text_hjust', 0.5), vjust = num_param(params, 'x_axis_text_vjust', 0.5), margin = margin(t = num_param(params, 'x_axis_text_margin_top', 2))),
    axis.text.y = element_text(size = num_param(params, 'y_axis_text_size', num_param(params, 'axis_text_size', 12)), color = get_param(params, 'y_axis_text_color', get_param(params, 'axis_text_color', 'black')), family = get_param(params, 'y_axis_text_font_family', get_param(params, 'axis_text_font_family', get_param(params, 'font_family', 'sans'))), angle = num_param(params, 'y_axis_text_angle', 0), hjust = num_param(params, 'y_axis_text_hjust', 0.5), vjust = num_param(params, 'y_axis_text_vjust', 0.5), margin = margin(r = num_param(params, 'y_axis_text_margin_right', 2))),
    axis.line = if (as_bool(get_param(params, 'axis_line_show', FALSE), FALSE)) element_line(color = get_param(params, 'axis_line_color', '#111111'), linewidth = num_param(params, 'axis_line_width', 0.45)) else element_blank(),
    axis.ticks = if (as_bool(get_param(params, 'axis_tick_show', TRUE), TRUE)) element_line(color = get_param(params, 'axis_tick_color', '#111111'), linewidth = num_param(params, 'axis_tick_width', 0.35)) else element_blank(),
    panel.grid.major = if (as_bool(get_param(params, 'show_grid', FALSE), FALSE)) element_line(color = get_param(params, 'grid_color', '#E6E6E6'), linetype = get_param(params, 'grid_line_type', 'solid'), linewidth = num_param(params, 'grid_line_width', 0.25)) else element_blank(),
    panel.grid.minor = if (as_bool(get_param(params, 'show_minor_grid', FALSE), FALSE)) element_line(color = get_param(params, 'minor_grid_color', '#F0F0F0'), linewidth = num_param(params, 'minor_grid_line_width', 0.2)) else element_blank(),
    panel.border = if (as_bool(get_param(params, 'panel_border_show', theme_name == 'default'), theme_name == 'default')) element_rect(fill = NA, color = get_param(params, 'panel_border_color', 'black'), linewidth = num_param(params, 'panel_border_width', 1)) else element_blank(),
    legend.position = get_param(params, 'legend_position', 'right'),
    legend.direction = get_param(params, 'legend_direction', 'vertical'),
    legend.title = element_text(size = num_param(params, 'legend_title_size', 12), face = get_param(params, 'legend_title_fontface', 'plain'), color = get_param(params, 'legend_title_color', 'black'), hjust = 0),
    legend.text = element_text(size = num_param(params, 'legend_text_size', 11), color = get_param(params, 'legend_text_color', 'black')),
    legend.key = element_rect(fill = 'transparent', color = 'transparent'),
    legend.key.size = grid::unit(num_param(params, 'legend_key_size_pt', 10), 'pt'),
    legend.background = element_blank(),
    strip.text = element_text(size = num_param(params, 'strip_text_size', 12.5), face = get_param(params, 'strip_text_fontface', 'plain'), color = get_param(params, 'strip_text_color', 'black'), hjust = 0.5, margin = margin(3, 3, 3, 3)),
    strip.background = element_rect(fill = 'transparent', linetype = 0),
    plot.margin = margin(num_param(params, 'plot_margin_top', 8), num_param(params, 'plot_margin_right', 8), num_param(params, 'plot_margin_bottom', 8), num_param(params, 'plot_margin_left', 8))
  )
  if (theme_name == 'blank') {
    out <- out + theme(
      axis.title = element_blank(),
      axis.text = element_blank(),
      axis.line = element_blank(),
      axis.ticks = element_blank(),
      panel.grid = element_blank(),
      panel.border = element_blank()
    )
  }
  out
}

mark_layer <- function(plot_df, params, group_col) {
  if (!as_bool(get_param(params, 'show_mark', FALSE), FALSE) || is.null(group_col)) return(list())
  if (!requireNamespace('ggforce', quietly = TRUE)) return(list())
  type <- tolower(as.character(get_param(params, 'mark_type', 'hull'))[1])
  fun <- switch(type, ellipse = ggforce::geom_mark_ellipse, rect = ggforce::geom_mark_rect, circle = ggforce::geom_mark_circle, ggforce::geom_mark_hull)
  list(fun(
    data = plot_df[!is.na(plot_df[[group_col]]), , drop = FALSE],
    aes(x = .data$.__x, y = .data$.__y, color = .data[[group_col]], fill = .data[[group_col]]),
    expand = grid::unit(num_param(params, 'mark_expand_mm', 3), 'mm'),
    alpha = num_param(params, 'mark_alpha', 0.12),
    linetype = get_param(params, 'mark_linetype', 'solid'),
    linewidth = num_param(params, 'mark_line_width', 0.4),
    show.legend = FALSE,
    inherit.aes = FALSE
  ))
}

add_lineages <- function(p, params) {
  lineages <- get_param(params, 'lineages', NULL)
  if (is.null(lineages)) return(p)
  if (is.data.frame(lineages)) {
    lineages <- lapply(seq_len(nrow(lineages)), function(i) as.list(lineages[i, , drop = FALSE]))
  }
  if (!is.list(lineages) || length(lineages) == 0) return(p)
  dfs <- list()
  for (i in seq_along(lineages)) {
    item <- lineages[[i]]
    xs <- suppressWarnings(as.numeric(unlist(item$x, use.names = FALSE)))
    ys <- suppressWarnings(as.numeric(unlist(item$y, use.names = FALSE)))
    if (length(xs) < 2 || length(ys) < 2) next
    n <- min(length(xs), length(ys))
    dfs[[length(dfs) + 1]] <- data.frame(
      lineage = as.character(ifelse(is.null(item$name), paste0('lineage_', i), item$name)),
      x = xs[seq_len(n)],
      y = ys[seq_len(n)],
      order = seq_len(n),
      stringsAsFactors = FALSE
    )
  }
  if (length(dfs) == 0) return(p)
  ld <- do.call(rbind, dfs)
  lineage_levels <- unique(ld$lineage)
  colors <- named_palette(lineage_levels, params, 'lineage', default = get_param(params, 'lineage_color', '#111111'))
  arrow_obj <- if (as_bool(get_param(params, 'lineage_arrow', TRUE), TRUE)) grid::arrow(length = grid::unit(num_param(params, 'lineage_arrow_length_mm', 2.5), 'mm'), type = get_param(params, 'lineage_arrow_type', 'closed')) else NULL
  if (requireNamespace('ggnewscale', quietly = TRUE)) p <- p + ggnewscale::new_scale_color()
  p +
    geom_path(
      data = ld,
      aes(x = x, y = y, color = lineage, group = lineage),
      linewidth = num_param(params, 'lineage_line_width', 1.1),
      linetype = get_param(params, 'lineage_line_type', 'solid'),
      alpha = num_param(params, 'lineage_alpha', 0.95),
      arrow = arrow_obj,
      inherit.aes = FALSE,
      show.legend = as_bool(get_param(params, 'lineage_legend_show', TRUE), TRUE)
    ) +
    scale_color_manual(values = colors, name = get_param(params, 'lineage_legend_name', 'Lineage'))
}

make_label_df <- function(plot_df, params, group_col, id_col, feature_col = NULL) {
  selected <- as_string_vector(get_param_any(params, c('selected_labels', 'label_rows', 'label_cells', 'label_ids'), NULL))
  label_df <- plot_df[plot_df[[id_col]] %in% selected, , drop = FALSE]
  if (as_bool(get_param(params, 'label_groups', FALSE), FALSE) && !is.null(group_col)) {
    usable <- plot_df
    if ('.__forced_bg' %in% colnames(usable)) usable <- usable[!usable$.__forced_bg, , drop = FALSE]
    usable <- usable[!is.na(usable[[group_col]]), , drop = FALSE]
    if (nrow(usable) == 0) return(usable[FALSE, , drop = FALSE])
    med <- aggregate(usable[, c('.__x', '.__y')], by = list(label = usable[[group_col]]), FUN = stats::median)
    med$.__label_name <- as.character(med$label)
    if (!as_bool(get_param(params, 'label_insitu', get_param(params, 'label.insitu', FALSE)), FALSE)) {
      med$.__label_name <- as.character(seq_len(nrow(med)))
    }
    med[[id_col]] <- med$label
    return(med)
  }
  top_n <- num_param(params, 'label_top_n', 0)
  if (!is.null(feature_col) && top_n > 0) {
    d <- plot_df[order(-suppressWarnings(as.numeric(plot_df[[feature_col]]))), , drop = FALSE]
    label_df <- unique(rbind(label_df, head(d, top_n)))
  }
  label_df
}

add_labels <- function(p, label_df, params, id_col, label_col = NULL) {
  if (is.null(label_df) || nrow(label_df) == 0 || !as_bool(get_param(params, 'label_show', TRUE), TRUE)) return(p)
  if (is.null(label_col) || !label_col %in% colnames(label_df)) label_col <- id_col
  if (num_param(params, 'label_point_size', 1) > 0) {
    p <- p + geom_point(
      data = label_df,
      aes(x = .data$.__x, y = .data$.__y),
      color = get_param(params, 'label_point_color', '#111111'),
      size = num_param(params, 'label_point_size', 1),
      alpha = num_param(params, 'label_point_alpha', 1),
      inherit.aes = FALSE
    )
  }
  if (!as_bool(get_param(params, 'label_repel', TRUE), TRUE)) {
    return(p + ggrepel::geom_text_repel(
      data = label_df,
      aes(x = .data$.__x, y = .data$.__y, label = .data[[label_col]]),
      size = num_param(params, 'label_size', 4),
      color = get_param(params, 'label_color', 'white'),
      bg.color = get_param(params, 'label_bg_color', 'black'),
      bg.r = num_param(params, 'label_bg_radius', 0.1),
      fontface = get_param(params, 'label_fontface', 'bold'),
      min.segment.length = 0,
      segment.color = get_param(params, 'label_line_color', 'black'),
      point.size = NA,
      max.overlaps = num_param(params, 'label_max_overlaps', 100),
      force = 0,
      inherit.aes = FALSE
    ))
  }
  p +
    ggrepel::geom_text_repel(
      data = label_df,
      aes(x = .data$.__x, y = .data$.__y, label = .data[[label_col]]),
      size = num_param(params, 'label_size', 4),
      color = get_param(params, 'label_color', 'white'),
      bg.color = get_param(params, 'label_bg_color', 'black'),
      bg.r = num_param(params, 'label_bg_radius', 0.1),
      fontface = get_param(params, 'label_fontface', 'bold'),
      segment.color = get_param(params, 'label_line_color', '#555555'),
      segment.size = num_param(params, 'label_line_width', 0.35),
      segment.linetype = get_param(params, 'label_line_type', 'solid'),
      max.overlaps = num_param(params, 'label_max_overlaps', 100),
      box.padding = num_param(params, 'label_box_padding', 0.35),
      point.padding = num_param(params, 'label_point_padding', 0.15),
      force = num_param(params, 'label_force', 20),
      min.segment.length = 0,
      inherit.aes = FALSE
    )
}

base_plot <- function(plot_df, params, x_col, y_col) {
  p <- ggplot(plot_df, aes(x = .data$.__x, y = .data$.__y)) +
    labs(
      title = if (as_bool(get_param(params, 'title_show', TRUE), TRUE)) get_param(params, 'title', 'Advanced dimension plot') else NULL,
      subtitle = if (as_bool(get_param(params, 'subtitle_show', TRUE), TRUE)) get_param(params, 'subtitle', NULL) else NULL,
      x = if (as_bool(get_param(params, 'xlab_show', TRUE), TRUE)) get_param(params, 'xlab', x_col) else NULL,
      y = if (as_bool(get_param(params, 'ylab_show', TRUE), TRUE)) get_param(params, 'ylab', y_col) else NULL
    ) +
    theme_for_plot(params)
  if (!is.null(get_param(params, 'xlim', NULL))) p <- p + scale_x_continuous(limits = as.numeric(unlist(get_param(params, 'xlim'))))
  if (!is.null(get_param(params, 'ylim', NULL))) p <- p + scale_y_continuous(limits = as.numeric(unlist(get_param(params, 'ylim'))))
  if (as_bool(get_param(params, 'axis_arrow_show', FALSE), FALSE)) {
    xr <- range(plot_df$.__x, na.rm = TRUE)
    yr <- range(plot_df$.__y, na.rm = TRUE)
    dx <- diff(xr)
    dy <- diff(yr)
    x0 <- xr[1] + dx * num_param(params, 'axis_arrow_x_npc', 0.04)
    y0 <- yr[1] + dy * num_param(params, 'axis_arrow_y_npc', 0.06)
    x1 <- x0 + dx * num_param(params, 'axis_arrow_x_length_npc', 0.14)
    y1 <- y0 + dy * num_param(params, 'axis_arrow_y_length_npc', 0.14)
    arrow_obj <- grid::arrow(length = grid::unit(num_param(params, 'axis_arrow_length_mm', 4), 'mm'), type = 'open')
    p <- p +
      annotate('segment', x = x0, xend = x1, y = y0, yend = y0, arrow = arrow_obj, linewidth = num_param(params, 'axis_arrow_width', 0.55), color = get_param(params, 'axis_arrow_color', '#111111')) +
      annotate('segment', x = x0, xend = x0, y = y0, yend = y1, arrow = arrow_obj, linewidth = num_param(params, 'axis_arrow_width', 0.55), color = get_param(params, 'axis_arrow_color', '#111111')) +
      annotate('text', x = x1 + dx * num_param(params, 'axis_arrow_x_label_dx_npc', 0), y = y0 + dy * num_param(params, 'axis_arrow_x_label_dy_npc', -0.012), label = get_param(params, 'axis_arrow_x_label', x_col), hjust = num_param(params, 'axis_arrow_x_label_hjust', 1), vjust = num_param(params, 'axis_arrow_x_label_vjust', 1), size = num_param(params, 'axis_arrow_x_label_size', num_param(params, 'axis_arrow_label_size', 3.2)), color = get_param(params, 'axis_arrow_x_label_color', get_param(params, 'axis_arrow_label_color', '#111111')), family = get_param(params, 'axis_arrow_label_font_family', get_param(params, 'font_family', 'sans')), fontface = get_param(params, 'axis_arrow_label_fontface', 'plain')) +
      annotate('text', x = x0 + dx * num_param(params, 'axis_arrow_y_label_dx_npc', -0.012), y = y1 + dy * num_param(params, 'axis_arrow_y_label_dy_npc', 0), label = get_param(params, 'axis_arrow_y_label', y_col), angle = num_param(params, 'axis_arrow_y_label_angle', 90), hjust = num_param(params, 'axis_arrow_y_label_hjust', 1), vjust = num_param(params, 'axis_arrow_y_label_vjust', 1), size = num_param(params, 'axis_arrow_y_label_size', num_param(params, 'axis_arrow_label_size', 3.2)), color = get_param(params, 'axis_arrow_y_label_color', get_param(params, 'axis_arrow_label_color', '#111111')), family = get_param(params, 'axis_arrow_label_font_family', get_param(params, 'font_family', 'sans')), fontface = get_param(params, 'axis_arrow_label_fontface', 'plain')) +
      coord_cartesian(clip = 'off')
  }
  p
}

make_group_plot <- function(plot_df, params, x_col, y_col, group_col, id_col, split_col = NULL) {
  validate_columns(plot_df, group_col)
  plot_df[[group_col]] <- factor(plot_df[[group_col]], levels = as_string_vector(get_param(params, 'group_order', unique(as.character(plot_df[[group_col]])))))
  levels <- levels(plot_df[[group_col]])
  colors <- named_palette(levels, params, 'group')
  bg_col <- get_param_any(params, c('background_column', 'bg_by'), NULL)
  forced_bg <- rep(FALSE, nrow(plot_df))
  if (!is.null(bg_col) && bg_col %in% colnames(plot_df)) {
    bg_values <- plot_df[[bg_col]]
    if (is.numeric(bg_values) || is.integer(bg_values)) {
      forced_bg <- is.na(bg_values) | bg_values <= num_param(params, 'background_cutoff', num_param(params, 'bg_cutoff', 0))
    } else {
      forced_bg <- is.na(bg_values) | as.character(bg_values) %in% as_string_vector(get_param_any(params, c('background_levels', 'bg_levels', 'background_cutoff'), NULL))
    }
  }
  if ('.__forced_bg_seed' %in% colnames(plot_df)) forced_bg <- forced_bg | plot_df$.__forced_bg_seed
  plot_df$.__forced_bg <- forced_bg
  point_size_default <- min(3000 / max(nrow(plot_df), 1), 0.5)
  point_size <- num_param(params, 'point_size', point_size_default)
  p <- base_plot(plot_df, params, x_col, y_col)
  p <- p + mark_layer(plot_df, params, group_col)
  if (as_bool(get_param(params, 'show_density', FALSE), FALSE)) {
    if (as_bool(get_param(params, 'density_filled', TRUE), TRUE)) {
      p <- p + stat_density_2d(aes(alpha = after_stat(level)), geom = 'polygon', bins = num_param(params, 'density_bins', 8), fill = get_param(params, 'density_fill_color', '#BDBDBD'), color = get_param(params, 'density_color', '#999999'), show.legend = FALSE)
    } else {
      p <- p + stat_density_2d(geom = 'density_2d', bins = num_param(params, 'density_bins', 8), color = get_param(params, 'density_color', '#999999'), linewidth = num_param(params, 'density_line_width', 0.25), alpha = num_param(params, 'density_alpha', 0.65), show.legend = FALSE)
    }
  }
  if (as_bool(get_param(params, 'hex', FALSE), FALSE)) {
    p <- p +
      geom_hex(aes(fill = after_stat(count)), bins = num_param(params, 'hex_bins', 45), alpha = num_param(params, 'hex_alpha', 0.85), linewidth = num_param(params, 'hex_line_width', 0.15), color = get_param(params, 'hex_border_color', '#FFFFFF')) +
      scale_fill_gradientn(colors = as_string_vector(get_param(params, 'hex_count_colors', c('#F7FBFF', '#6BAED6', '#08306B'))), name = get_param(params, 'hex_legend_name', 'Count'))
  } else {
    fg_df <- plot_df[!plot_df$.__forced_bg, , drop = FALSE]
    bg_df <- plot_df[plot_df$.__forced_bg, , drop = FALSE]
    if (nrow(bg_df) > 0) {
      p <- p + geom_point(data = bg_df, aes(x = .data$.__x, y = .data$.__y), color = get_param(params, 'background_color', '#D0D0D0'), size = num_param(params, 'background_point_size', point_size), alpha = num_param(params, 'background_alpha', 0.35), inherit.aes = FALSE)
    }
    if (as_bool(get_param(params, 'raster', FALSE), FALSE) && requireNamespace('scattermore', quietly = TRUE)) {
      p <- p + scattermore::geom_scattermore(data = fg_df, aes(x = .data$.__x, y = .data$.__y, color = .data[[group_col]]), pointsize = max(1, ceiling(num_param(params, 'raster_point_size', point_size))), alpha = num_param(params, 'point_alpha', 1), pixels = as.numeric(unlist(get_param(params, 'raster_dpi', list(1024, 1024)))), inherit.aes = FALSE)
    } else {
      if (as_bool(get_param(params, 'advdim_randomize_foreground', TRUE), TRUE) && nrow(fg_df) > 1) fg_df <- fg_df[sample(seq_len(nrow(fg_df))), , drop = FALSE]
      p <- p + geom_point(data = fg_df, aes(x = .data$.__x, y = .data$.__y, color = .data[[group_col]]), size = point_size, alpha = num_param(params, 'point_alpha', 1), shape = num_param(params, 'point_shape', 16), stroke = num_param(params, 'point_stroke', 0.2), inherit.aes = FALSE)
    }
  }
  highlight <- as_string_vector(get_param_any(params, c('highlight_rows', 'highlight_cells', 'highlight_ids'), NULL))
  if (length(highlight) > 0) {
    hd <- plot_df[plot_df[[id_col]] %in% highlight, , drop = FALSE]
    if (tolower(as.character(get_param_any(params, c('highlight_mode', 'highlight.mode'), 'overlay'))[1]) == 'contrast') {
      p <- p + geom_point(data = plot_df[!plot_df[[id_col]] %in% highlight, , drop = FALSE], aes(x = .data$.__x, y = .data$.__y), color = get_param(params, 'non_highlight_color', '#808080'), alpha = num_param(params, 'non_highlight_alpha', min(num_param(params, 'point_alpha', 1), 0.2)), size = point_size, inherit.aes = FALSE)
    }
    p <- p +
      geom_point(data = hd, aes(x = .data$.__x, y = .data$.__y), color = get_param(params, 'highlight_border_color', '#111111'), size = num_param(params, 'highlight_size', 2.4), alpha = num_param(params, 'highlight_alpha', 1), shape = num_param(params, 'highlight_shape', 21), stroke = num_param(params, 'highlight_stroke', 0.5), fill = get_param(params, 'highlight_fill', '#FFD400'), inherit.aes = FALSE)
    if (as_bool(get_param(params, 'highlight_ring_show', FALSE), FALSE) && nrow(hd) > 0) {
      p <- p + geom_point(
        data = hd,
        aes(x = .data$.__x, y = .data$.__y),
        shape = num_param(params, 'highlight_ring_shape', 21),
        size = num_param(params, 'highlight_ring_size', num_param(params, 'highlight_size', 2.4) + 1.2),
        stroke = num_param(params, 'highlight_ring_stroke', 0.8),
        color = get_param(params, 'highlight_ring_color', '#111111'),
        fill = get_param(params, 'highlight_ring_fill', NA),
        alpha = num_param(params, 'highlight_ring_alpha', 1),
        inherit.aes = FALSE
      )
    }
  }
  if (!as_bool(get_param(params, 'hex', FALSE), FALSE) || as_bool(get_param(params, 'show_mark', FALSE), FALSE)) {
    legend_labels <- levels
    if (as_bool(get_param(params, 'advdim_numbered_legend', TRUE), TRUE)) {
      counts <- table(plot_df[[group_col]][!plot_df$.__forced_bg])
      counts <- counts[levels]
      legend_labels <- paste0(seq_along(levels), ': ', levels)
      if (as_bool(get_param_any(params, c('show_stat', 'show.stat'), FALSE), FALSE)) {
        legend_labels <- paste0(seq_along(levels), ': ', levels, '(', as.integer(counts), ')')
      }
    }
    p <- p + scale_color_manual(values = colors, name = get_param(params, 'legend_name', paste0(group_col, ':')), labels = legend_labels, drop = FALSE, na.value = get_param(params, 'background_color', '#D0D0D0'), guide = guide_legend(title.hjust = 0, order = 1, override.aes = list(size = num_param(params, 'legend_point_size', 4), alpha = 1)))
  }
  if (as_bool(get_param(params, 'show_mark', FALSE), FALSE) && !as_bool(get_param(params, 'hex', FALSE), FALSE)) {
    p <- p + scale_fill_manual(values = colors, name = get_param(params, 'legend_name', group_col), drop = FALSE)
  }
  p <- add_embedded_stat(p, plot_df[!plot_df$.__forced_bg, , drop = FALSE], params, group_col, split_col)
  label_df <- make_label_df(plot_df, params, group_col, id_col)
  p <- add_labels(p, label_df, params, id_col, get_param(params, 'label_column', if ('.__label_name' %in% colnames(label_df)) '.__label_name' else id_col))
  add_lineages(p, params)
}

make_feature_plot <- function(plot_df, params, x_col, y_col, feature_cols, id_col) {
  validate_columns(plot_df, feature_cols)
  plots <- list()
  multi_feature <- length(feature_cols) > 1
  for (feature_col in feature_cols) {
    plot_df$.__feature <- suppressWarnings(as.numeric(plot_df[[feature_col]]))
    plot_df$.__feature_cap <- cap_numeric(plot_df$.__feature, num_param(params, 'feature_lower_quantile', 0.01), num_param(params, 'feature_upper_quantile', 0.99), get_param(params, 'feature_limits', NULL))
    bg_cutoff <- suppressWarnings(as.numeric(get_param(params, 'feature_bg_cutoff', NA)))
    fg <- plot_df
    if (is.finite(bg_cutoff)) {
      fg$.__background <- is.na(fg$.__feature) | fg$.__feature <= bg_cutoff
    } else {
      fg$.__background <- is.na(fg$.__feature)
    }
    p <- base_plot(fg, params, x_col, y_col) +
      geom_point(data = fg[fg$.__background, , drop = FALSE], aes(x = .data$.__x, y = .data$.__y), color = get_param(params, 'background_color', '#D9D9D9'), size = num_param(params, 'background_point_size', num_param(params, 'point_size', 0.7)), alpha = num_param(params, 'background_alpha', 0.45), inherit.aes = FALSE) +
      geom_point(data = fg[!fg$.__background, , drop = FALSE], aes(x = .data$.__x, y = .data$.__y, color = .data$.__feature_cap), size = num_param(params, 'point_size', 0.8), alpha = num_param(params, 'point_alpha', 0.9), shape = num_param(params, 'point_shape', 16), stroke = num_param(params, 'point_stroke', 0.2), inherit.aes = FALSE) +
      scale_color_gradientn(
        colors = as_string_vector(get_param(params, 'feature_colors', c('#E6E6E6', '#67A9CF', '#2166AC', '#B2182B'))),
        name = get_param(params, 'legend_name', feature_col),
        guide = guide_colorbar(
          title.position = get_param(params, 'legend_title_position', 'top'),
          barheight = grid::unit(num_param(params, 'legend_bar_height_cm', 2.4), 'cm'),
          barwidth = grid::unit(num_param(params, 'legend_bar_width_cm', 0.35), 'cm')
        )
      ) +
      labs(
        title = if (as_bool(get_param(params, 'title_show', TRUE), TRUE)) if (multi_feature) feature_col else get_param(params, 'title', feature_col) else NULL,
        subtitle = if (multi_feature) NULL else if (as_bool(get_param(params, 'subtitle_show', TRUE), TRUE)) get_param(params, 'subtitle', NULL) else NULL
      )
    if (as_bool(get_param(params, 'show_density', FALSE), FALSE)) {
      p <- p + stat_density_2d(color = get_param(params, 'density_color', '#222222'), linewidth = num_param(params, 'density_line_width', 0.25), bins = num_param(params, 'density_bins', 8), alpha = num_param(params, 'density_alpha', 0.55))
    }
    label_df <- make_label_df(fg, params, NULL, id_col, feature_col)
    plots[[feature_col]] <- add_labels(add_lineages(p, params), label_df, params, id_col, get_param(params, 'label_column', id_col))
  }
  if (length(plots) == 1) {
    plots[[1]]
  } else {
    wrap_plots(plots, nrow = get_param(params, 'nrow', NULL), ncol = get_param(params, 'ncol', NULL), byrow = as_bool(get_param(params, 'byrow', TRUE), TRUE)) +
      plot_annotation(
        title = if (as_bool(get_param(params, 'title_show', TRUE), TRUE)) get_param(params, 'title', 'Feature expression maps') else NULL,
        subtitle = if (as_bool(get_param(params, 'subtitle_show', TRUE), TRUE)) get_param(params, 'subtitle', NULL) else NULL,
        theme = theme(
          plot.title = element_text(size = num_param(params, 'title_size', 16), face = get_param(params, 'title_fontface', 'plain'), color = get_param(params, 'title_color', '#111111'), hjust = num_param(params, 'title_hjust', 0.5)),
          plot.subtitle = element_text(size = num_param(params, 'subtitle_size', 10), color = get_param(params, 'subtitle_color', '#555555'), hjust = num_param(params, 'subtitle_hjust', 0.5))
        )
      )
  }
}

make_coexpression_plot <- function(plot_df, params, x_col, y_col, feature_cols, id_col) {
  if (length(feature_cols) < 2) write_error_and_exit('Coexpression mode requires at least two feature columns', '', 'Set feature_columns to two or three numeric columns.')
  feature_cols <- head(feature_cols, 3)
  validate_columns(plot_df, feature_cols)
  values <- plot_df[, feature_cols, drop = FALSE]
  colors <- as_string_vector(get_param(params, 'coexpression_colors', c('#E41A1C', '#377EB8', '#4DAF4A')))
  plot_df$.__mix_color <- mix_colors(values, rep(colors, length.out = length(feature_cols)), get_param(params, 'color_mix_mode', 'blend'))
  plot_df$.__mix_score <- rowSums(as.data.frame(lapply(values, normalize01)))
  p <- base_plot(plot_df, params, x_col, y_col) +
    geom_point(aes(x = .data$.__x, y = .data$.__y), color = get_param(params, 'background_color', '#D9D9D9'), size = num_param(params, 'background_point_size', num_param(params, 'point_size', 0.7)), alpha = num_param(params, 'background_alpha', 0.35), inherit.aes = FALSE) +
    geom_point(aes(x = .data$.__x, y = .data$.__y, color = .data$.__mix_color, size = .data$.__mix_score), alpha = num_param(params, 'point_alpha', 0.95), inherit.aes = FALSE) +
    scale_color_identity(name = get_param(params, 'legend_name', 'Mixed expression'), guide = 'none') +
    scale_size_continuous(name = get_param(params, 'size_legend_name', 'Coexpression'), range = c(num_param(params, 'coexpression_size_min', 0.35), num_param(params, 'coexpression_size_max', 1.8))) +
    labs(subtitle = get_param(params, 'subtitle', paste('Color mix:', paste(feature_cols, collapse = ' + '))))
  label_df <- make_label_df(plot_df, params, NULL, id_col, feature_cols[1])
  add_labels(add_lineages(p, params), label_df, params, id_col, get_param(params, 'label_column', id_col))
}

make_stat_plot <- function(plot_df, params, group_col, split_col) {
  if (is.null(group_col)) return(NULL)
  if (is.null(split_col)) split_col <- '.__all'
  tab <- as.data.frame(table(split = plot_df[[split_col]], group = plot_df[[group_col]]), stringsAsFactors = FALSE)
  tab <- tab[tab$Freq > 0, , drop = FALSE]
  if (nrow(tab) == 0) return(NULL)
  colors <- named_palette(unique(as.character(tab$group)), params, 'group')
  stat_type <- tolower(as.character(get_param(params, 'stat_plot_source', 'count'))[1])
  if (stat_type %in% c('percent', 'fraction')) {
    totals <- ave(tab$Freq, tab$split, FUN = sum)
    tab$value <- tab$Freq / totals * 100
    ylab <- get_param(params, 'stat_ylab', 'Percent')
  } else {
    tab$value <- tab$Freq
    ylab <- get_param(params, 'stat_ylab', 'Cells')
  }
  ggplot(tab, aes(x = split, y = value, fill = group)) +
    geom_col(position = get_param(params, 'stat_plot_position', 'stack'), alpha = num_param(params, 'stat_plot_alpha', 0.95), width = num_param(params, 'stat_bar_width', 0.75)) +
    scale_fill_manual(values = colors, name = get_param(params, 'stat_legend_name', group_col)) +
    labs(x = NULL, y = ylab) +
    theme_for_plot(params) +
    theme(aspect.ratio = NULL, legend.position = get_param(params, 'stat_legend_position', 'right'))
}

add_embedded_stat <- function(p, plot_df, params, group_col, split_col = NULL) {
  stat_col <- get_param_any(params, c('stat_plot_column', 'stat_plot_by', 'stat_column'), NULL)
  if (!as_bool(get_param(params, 'show_stat_embedded', FALSE), FALSE) || is.null(stat_col)) return(p)
  if (!requireNamespace('scatterpie', quietly = TRUE)) return(p)
  validate_columns(plot_df, c(group_col, stat_col, split_col))
  work <- plot_df[!is.na(plot_df[[group_col]]) & !is.na(plot_df[[stat_col]]), , drop = FALSE]
  if (nrow(work) == 0) return(p)
  split_key <- if (!is.null(split_col) && split_col %in% colnames(work)) split_col else NULL
  by_cols <- c(group_col, split_key)
  centers <- aggregate(work[, c('.__x', '.__y')], by = work[, by_cols, drop = FALSE], FUN = stats::median)
  stat_levels <- unique(as.character(work[[stat_col]]))
  stat_levels <- stat_levels[nzchar(stat_levels)]
  pie_df <- centers
  for (lvl in stat_levels) pie_df[[lvl]] <- 0
  for (i in seq_len(nrow(centers))) {
    hit <- work[[group_col]] == centers[[group_col]][i]
    if (!is.null(split_key)) hit <- hit & work[[split_key]] == centers[[split_key]][i]
    tb <- table(as.character(work[[stat_col]][hit]))
    for (lvl in intersect(names(tb), stat_levels)) pie_df[[lvl]][i] <- as.numeric(tb[[lvl]])
  }
  if (nrow(pie_df) == 0) return(p)
  pie_df$.__radius <- num_param(params, 'stat_embedded_size', 0.035) * max(diff(range(plot_df$.__x, na.rm = TRUE)), diff(range(plot_df$.__y, na.rm = TRUE)))
  stat_colors <- named_palette(stat_levels, params, 'stat', default = '#BDBDBD')
  if (requireNamespace('ggnewscale', quietly = TRUE)) p <- p + ggnewscale::new_scale_fill()
  p <- p +
    scatterpie::geom_scatterpie(
      data = pie_df,
      aes(x = .data$.__x, y = .data$.__y, r = .data$.__radius),
      cols = stat_levels,
      color = get_param(params, 'stat_embedded_border_color', '#FFFFFF'),
      linewidth = num_param(params, 'stat_embedded_border_width', 0.25),
      alpha = num_param(params, 'stat_embedded_alpha', 0.95)
    ) +
    scale_fill_manual(values = stat_colors, name = get_param(params, 'stat_legend_name', stat_col))
  if (as_bool(get_param(params, 'stat_embedded_ring_show', FALSE), FALSE)) {
    p <- p + geom_point(
      data = pie_df,
      aes(x = .data$.__x, y = .data$.__y),
      shape = num_param(params, 'stat_embedded_ring_shape', 21),
      size = num_param(params, 'stat_embedded_ring_size', 5.5),
      stroke = num_param(params, 'stat_embedded_ring_stroke', 0.7),
      color = get_param(params, 'stat_embedded_ring_color', '#111111'),
      fill = get_param(params, 'stat_embedded_ring_fill', NA),
      alpha = num_param(params, 'stat_embedded_ring_alpha', 1),
      inherit.aes = FALSE
    )
  }
  p
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
  draw_with_retry(function(w, h) png(file.path(output_dir, 'result.png'), width = w, height = h, units = 'in', res = dpi, type = 'cairo'))
}

main <- function() {
  if (is.null(input_file)) write_error_and_exit('Missing --input argument')
  if (is.null(params_file) || !file.exists(params_file)) write_error_and_exit('Params file not found', paste('Params path:', params_file), 'Provide params.json.')
  if (is.null(output_dir)) write_error_and_exit('Missing --output argument')
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  old_outputs <- file.path(output_dir, c('error.json', 'result.svg', 'result.pdf', 'result.png', 'figure.json', 'selected_rows.csv', 'run.log'))
  old_outputs <- old_outputs[file.exists(old_outputs)]
  if (length(old_outputs) > 0) unlink(old_outputs)
  write_log('Starting advanced dimension plot plugin.')

  params <- normalize_advdim_params(jsonlite::fromJSON(params_file, simplifyVector = FALSE))
  df <- read_table_auto(input_file)
  x_col <- get_param_any(params, c('x_column', 'dim1_column'), first_existing_col(df, c('dim1', 'Dim1', 'UMAP_1', 'umap_1', 'tSNE_1', 'tsne_1', 'PC_1', 'x'), TRUE, 'x_column'))
  y_col <- get_param_any(params, c('y_column', 'dim2_column'), first_existing_col(df, c('dim2', 'Dim2', 'UMAP_2', 'umap_2', 'tSNE_2', 'tsne_2', 'PC_2', 'y'), TRUE, 'y_column'))
  id_col <- get_param_any(params, c('id_column', 'cell_column', 'cell_id_column'), first_existing_col(df, c('cell', 'cell_id', 'barcode', 'Cell', 'id', colnames(df)[1]), TRUE, 'id_column'))
  group_col <- get_param_any(params, c('group_column', 'group_by', 'color_by'), first_existing_col(df, c('cluster', 'celltype', 'group', 'ident', 'seurat_clusters'), FALSE, 'group_column'))
  split_col <- get_param_any(params, c('split_column', 'split_by'), NULL)
  validate_columns(df, c(x_col, y_col, id_col, group_col, split_col))

  plot_df <- df
  plot_df[[id_col]] <- as.character(plot_df[[id_col]])
  plot_df$.__x <- suppressWarnings(as.numeric(plot_df[[x_col]]))
  plot_df$.__y <- suppressWarnings(as.numeric(plot_df[[y_col]]))
  plot_df <- plot_df[is.finite(plot_df$.__x) & is.finite(plot_df$.__y), , drop = FALSE]
  plot_df <- apply_row_selection(plot_df, id_col, group_col, params)
  if (nrow(plot_df) == 0) write_error_and_exit('No rows left after filtering', '', 'Relax rows_include/rows_exclude or group selectors.')
  if (is.null(split_col)) plot_df$.__all <- 'All'
  mode <- tolower(as.character(get_param_any(params, c('plot_mode', 'mode'), 'group'))[1])
  feature_cols <- as_string_vector(get_param_any(params, c('feature_columns', 'features', 'feature_column'), NULL))
  if (mode %in% c('feature', 'expression', 'gradient') && length(feature_cols) == 0) {
    feature_cols <- first_existing_col(plot_df, setdiff(colnames(plot_df), c(x_col, y_col, id_col, group_col, split_col, '.__x', '.__y')), TRUE, 'feature_column')
  }

  selected_out <- plot_df
  stat_panel_already_combined <- FALSE
  facet_already_combined <- FALSE
  if (mode %in% c('feature', 'expression', 'gradient')) {
    plot <- make_feature_plot(plot_df, params, x_col, y_col, feature_cols, id_col)
  } else if (mode %in% c('coexpression', 'blend', 'feature_mix')) {
    plot <- make_coexpression_plot(plot_df, params, x_col, y_col, feature_cols, id_col)
  } else {
    if (is.null(group_col)) {
      group_col <- '.__all_group'
      plot_df[[group_col]] <- 'All'
    }
    engine <- tolower(as.character(get_param_any(params, c('plot_engine', 'engine'), 'sca_advdim'))[1])
    if (engine %in% c('sca', 'sca_advdim', 'advdim', 'old', 'original')) {
      built <- make_sca_advdim_plot(df, params, x_col, y_col, id_col, group_col, split_col)
      plot <- built$plot
      selected_out <- built$selected
      stat_panel_already_combined <- as_bool(get_param(params, 'show_stat_panel', FALSE), FALSE)
      facet_already_combined <- !is.null(split_col) && split_col %in% colnames(df) && as_bool(get_param(params, 'facet_split', TRUE), TRUE)
    } else {
      if (!is.null(split_col) && split_col %in% colnames(plot_df) && as_bool(get_param_any(params, c('global_split', 'global.split'), TRUE), TRUE)) {
      split_levels <- unique(as.character(plot_df[[split_col]]))
      expanded <- lapply(split_levels, function(level) {
        d <- plot_df
        d$.__facet_split <- level
        d$.__forced_bg_seed <- as.character(d[[split_col]]) != level
        d
      })
      plot_df <- do.call(rbind, expanded)
      split_col <- '.__facet_split'
      }
      plot <- make_group_plot(plot_df, params, x_col, y_col, group_col, id_col, split_col)
      selected_out <- plot_df
    }
  }

  if (!is.null(split_col) && split_col %in% colnames(plot_df) && as_bool(get_param(params, 'facet_split', TRUE), TRUE) && !facet_already_combined) {
    plot <- plot + facet_wrap(stats::as.formula(paste('~', sprintf('`%s`', split_col))), nrow = get_param(params, 'facet_nrow', NULL), ncol = get_param(params, 'facet_ncol', NULL))
    if (!as_bool(get_param(params, 'split_strip_show', FALSE), FALSE)) plot <- plot + theme(strip.text = element_blank())
  }
  if (as_bool(get_param(params, 'show_stat_panel', FALSE), FALSE) && !stat_panel_already_combined) {
    stat_plot <- make_stat_plot(plot_df, params, group_col, split_col)
    if (!is.null(stat_plot)) plot <- plot / stat_plot + plot_layout(heights = as.numeric(unlist(get_param(params, 'stat_rel_heights', list(3, 1)))))
  }

  write.csv(selected_out, file.path(output_dir, 'selected_rows.csv'), row.names = FALSE)
  width <- num_param(params, 'width', 7.2)
  height <- num_param(params, 'height', 6.2)
  dpi <- num_param(params, 'dpi', 300)
  save_plot(plot, output_dir, width, height, dpi)

  figure <- list(
    plot_type = 'advanced_dim_plot',
    input_file = normalizePath(input_file, mustWork = FALSE),
    mode = mode,
    x_column = x_col,
    y_column = y_col,
    id_column = id_col,
    group_column = group_col,
    split_column = split_col,
    feature_columns = feature_cols,
    row_count = nrow(selected_out),
    style = list(
      title = get_param(params, 'title', 'Advanced dimension plot'),
      point_size = num_param(params, 'point_size', 0.8),
      point_alpha = num_param(params, 'point_alpha', 0.85),
      show_mark = as_bool(get_param(params, 'show_mark', FALSE), FALSE),
      show_density = as_bool(get_param(params, 'show_density', FALSE), FALSE),
      hex = as_bool(get_param(params, 'hex', FALSE), FALSE),
      facet_split = as_bool(get_param(params, 'facet_split', TRUE), TRUE)
    ),
    outputs = list(svg = 'result.svg', pdf = 'result.pdf', png = 'result.png', selected_rows = 'selected_rows.csv', log = 'run.log')
  )
  writeLines(jsonlite::toJSON(figure, auto_unbox = TRUE, pretty = TRUE), file.path(output_dir, 'figure.json'))
  write_log('Completed advanced dimension plot plugin.')
}

tryCatch(main(), error = function(e) {
  write_error_and_exit('Advanced dimension plot failed', conditionMessage(e), 'Check input columns and params.json.')
})
