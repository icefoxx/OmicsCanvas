#!/usr/bin/env Rscript

# BioFigureAI Plot Plugin: Stat Plot
# ------------------------------------------------------------
# Runtime contract:
#   Rscript plot.R --input metadata.csv --params params.json --output output_dir
#
# This plugin wraps the original SCA statPlot.R::statPlot() engine while
# exposing a stable table/JSON interface and standard result.svg/pdf/png/
# figure.json files. It computes counts or percentages of `stat_by` levels
# within `group_by` groups (optionally split by `split_by`, with optional
# background grouping `bg_by`) and produces bar/rose/ring/pie/trend/area/dot/
# sankey/chord/venn/upset plots.

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
  library(grid)
})

option_list <- list(
  make_option(c('--input'), type = 'character', default = NULL,
              help = 'Metadata CSV/TSV/TXT. Rows are cells/samples; first column is the row id by default.'),
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

num_param_any <- function(params, names, default = NA_real_) {
  value <- suppressWarnings(as.numeric(get_param_any(params, names, default))[1])
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

# ------------------------------------------------------------
# Load SCA reference helpers and patch for standalone CLI use
# ------------------------------------------------------------
load_sca_stat_reference <- function() {
  script_arg <- grep('^--file=', commandArgs(FALSE), value = TRUE)
  script_path <- if (length(script_arg) > 0) sub('^--file=', '', script_arg[1]) else file.path(getwd(), 'plugins', 'stat_plot', 'plot.R')
  # Shared SCA helper library (one canonical copy for all plugins): <repo>/R/sca
  helper_dir <- file.path(dirname(normalizePath(script_path, mustWork = FALSE)), '..', '..', 'R', 'sca')
  if (!dir.exists(helper_dir)) helper_dir <- file.path('R', 'sca')

  # Attach packages that statPlot() expects to be library()-attached.
  attach_pkgs <- function(pkgs) {
    missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
    if (length(missing) > 0) stop('Missing required R package(s): ', paste(missing, collapse = ', '), call. = FALSE)
    invisible(lapply(pkgs, library, character.only = TRUE))
  }
  attach_pkgs(c('tidyverse', 'ggrepel', 'patchwork', 'gtable', 'cli'))

  # Define helpers that statPlot / sourced SCA code rely on.
  `%||%` <<- function(x, y) if (is.null(x) || length(x) == 0) y else x
  scale01 <<- function(x) {
    x <- as.numeric(x)
    rng <- range(x, na.rm = TRUE)
    if (!all(is.finite(rng)) || diff(rng) == 0) return(rep(0, length(x)))
    (x - rng[1]) / diff(rng)
  }
  melt <<- function(...) reshape2::melt(...)
  rescale <<- scales::rescale

  # Source order: util.plot.R, util.com.R, util.ck.R, util.mat.R, expStatPlot.R, statPlot.R
  source(file.path(helper_dir, 'util.plot.R'), local = .GlobalEnv)
  source(file.path(helper_dir, 'util.com.R'), local = .GlobalEnv)
  source(file.path(helper_dir, 'util.ck.R'), local = .GlobalEnv)
  source(file.path(helper_dir, 'util.mat.R'), local = .GlobalEnv)
  source(file.path(helper_dir, 'expStatPlot.R'), local = .GlobalEnv)
  source(file.path(helper_dir, 'statPlot.R'), local = .GlobalEnv)

  # theme_scp alias must be defined after themeDefault is available.
  theme_scp <<- function(...) themeDefault(...)

  # Patch paletteCustomize to read the OmicsCanvas asset palettes.rds by default.
  source(file.path(helper_dir, 'omicscanvas_shims.R'), local = .GlobalEnv)
  omicscanvas_patch_palette(helper_dir)

  # Override ckPacsR with a non-installing stub so CLI runs never trigger
  # interactive package installation prompts.
  ckPacsR <<- function(packages, ...) {
    packages <- sub('@.*$', '', packages)
    packages <- sub('^.*/', '', packages)
    missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
    if (length(missing) > 0) stop('Missing required R package(s): ', paste(missing, collapse = ', '), call. = FALSE)
    invisible(TRUE)
  }

  invisible(TRUE)
}

# ------------------------------------------------------------
# Plot saving (handles ggplot/patchwork/gtable/grob and recorded base plots)
# ------------------------------------------------------------
is_recorded_plot <- function(x) {
  inherits(x, 'recordedplot') || (is.list(x) && !is.null(x$displaylist) && !is.null(x$ds))
}

save_plot <- function(plot, output_dir, width, height, dpi) {
  draw_plot_object <- function(x) {
    if (is_recorded_plot(x)) {
      grid::grid.newpage()
      grDevices::replayPlot(x)
    } else if (inherits(x, c('grob', 'gTree', 'gtable'))) {
      grid::grid.newpage()
      grid::grid.draw(x)
    } else {
      print(x)
    }
  }
  draw_with_retry <- function(open_device) {
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
      grDevices::dev.off()
      if (isTRUE(ok)) return(invisible(TRUE))
      scale <- scale * 1.35
    }
    stop(last_error)
  }
  draw_with_retry(function(w, h) svglite::svglite(file.path(output_dir, 'result.svg'), width = w, height = h))
  draw_with_retry(function(w, h) grDevices::cairo_pdf(file.path(output_dir, 'result.pdf'), width = w, height = h, onefile = TRUE))
  draw_with_retry(function(w, h) (if (requireNamespace('ragg', quietly = TRUE)) ragg::agg_png else function(...) grDevices::png(..., type = 'cairo'))(file.path(output_dir, 'result.png'), width = w, height = h, units = 'in', res = dpi))
}

# ------------------------------------------------------------
# Build the statPlot argument list from params
# ------------------------------------------------------------
build_stat_args <- function(df, params) {
  id_col <- get_param_any(params, c('id_column', 'cell_id_column', 'sample_id_column', 'row_id_column'), NULL)
  if (is.null(id_col)) id_col <- first_existing_col(df, c('cell_id', 'Cell', 'cell', 'sample_id', 'sample', 'barcode', colnames(df)[1]), TRUE, 'id_column')
  validate_columns(df, id_col)
  df[[id_col]] <- make.unique(as.character(df[[id_col]]))
  rownames(df) <- df[[id_col]]

  stat_by <- as_string_vector(get_param_any(params, c('stat_by', 'stat.by', 'stat_columns', 'stat.by'), NULL), NULL)
  if (length(stat_by) == 0) write_error_and_exit('stat_by is required', '', 'Provide one or more metadata columns in stat_by.')
  validate_columns(df, stat_by, 'stat_by')

  group_by <- as_string_vector(get_param_any(params, c('group_by', 'group.by', 'group_column'), NULL), NULL)
  if (length(group_by) > 0) validate_columns(df, group_by, 'group_by')
  split_by <- as_string_vector(get_param_any(params, c('split_by', 'split.by', 'split_column'), NULL), NULL)
  if (length(split_by) > 0) validate_columns(df, split_by, 'split_by')
  bg_by <- as_string_vector(get_param_any(params, c('bg_by', 'bg.by', 'background_column'), NULL), NULL)
  if (length(bg_by) > 0) validate_columns(df, bg_by, 'bg_by')

  plot_type <- tolower(as.character(get_param_any(params, c('plot_type', 'plot.type'), 'bar'))[1])
  stat_type <- tolower(as.character(get_param_any(params, c('stat_type', 'stat.type'), 'percent'))[1])
  position <- tolower(as.character(get_param_any(params, c('position'), 'stack'))[1])

  # Labels with show/hide toggles
  title <- get_param(params, 'title', NULL)
  subtitle <- get_param(params, 'subtitle', NULL)
  xlab <- get_param(params, 'xlab', NULL)
  ylab <- get_param(params, 'ylab', NULL)
  if (!as_bool(get_param_any(params, c('title_show', 'show_title'), TRUE), TRUE)) title <- NULL
  if (!as_bool(get_param_any(params, c('subtitle_show', 'show_subtitle'), TRUE), TRUE)) subtitle <- NULL
  if (!as_bool(get_param_any(params, c('xlab_show', 'show_xlab'), TRUE), TRUE)) xlab <- NULL
  if (!as_bool(get_param_any(params, c('ylab_show', 'show_ylab'), TRUE), TRUE)) ylab <- NULL

  palcolor <- as_named_vector(get_param_any(params, c('palcolor', 'colors', 'group_colors'), NULL), default = NULL)
  palcolor_bg <- as_named_vector(get_param_any(params, c('palcolor_bg', 'bg_palcolor', 'background_colors'), NULL), default = NULL)

  stat_level <- get_param_any(params, c('stat_level', 'stat.level'), NULL)
  if (!is.null(stat_level)) stat_level <- as_string_vector(stat_level, NULL)

  nrow_v <- as.integer(num_param_any(params, c('nrow'), NA_real_))
  if (is.na(nrow_v)) nrow_v <- NULL
  ncol_v <- as.integer(num_param_any(params, c('ncol'), NA_real_))
  if (is.na(ncol_v)) ncol_v <- NULL

  base_size <- num_param(params, 'base_size', 12)
  theme_use <- get_param_any(params, c('theme_use', 'theme.use'), 'themeDefault')
  theme_args <- get_param_any(params, c('theme.args', 'theme_args'), list())
  if (is.null(theme_args) || !is.list(theme_args)) theme_args <- list()
  if (is.null(theme_args$baseSize)) theme_args$baseSize <- base_size

  args <- list(
    df = df,
    stat.by = stat_by,
    group.by = if (length(group_by) > 0) group_by else NULL,
    split.by = if (length(split_by) > 0) split_by else NULL,
    bg.by = if (length(bg_by) > 0) bg_by else NULL,
    flip = as_bool(get_param(params, 'flip', FALSE), FALSE),
    color.na = get_param_any(params, c('color_na', 'color.na'), 'grey'),
    keep.na = as_bool(get_param_any(params, c('keep_na', 'keep.na'), FALSE), FALSE),
    keep.empty = as_bool(get_param_any(params, c('keep_empty', 'keep.empty'), FALSE), FALSE),
    each = as_bool(get_param(params, 'each', FALSE), FALSE),
    stat.level = stat_level,
    plot.type = plot_type,
    stat.type = stat_type,
    position = position,
    palette = get_param(params, 'palette', 'Paired'),
    palcolor = palcolor,
    alpha = num_param(params, 'alpha', 1),
    palette.bg = get_param_any(params, c('palette_bg', 'palette.bg', 'bg_palette'), 'Paired'),
    palcolor.bg = palcolor_bg,
    alpha.bg = num_param_any(params, c('alpha_bg', 'alpha.bg', 'bg_alpha'), 0.2),
    label = as_bool(get_param_any(params, c('show_label', 'label'), FALSE), FALSE),
    label.size = num_param(params, 'label_size', num_param(params, 'label.size', 3.5)),
    label.fg = get_param_any(params, c('label_fg', 'label.fg'), 'black'),
    label.bg = get_param_any(params, c('label_bg', 'label.bg'), 'white'),
    label.bg.r = num_param_any(params, c('label_bg_r', 'label.bg.r'), 0.1),
    aspect.ratio = as_numeric_vector(get_param_any(params, c('aspect_ratio', 'aspect.ratio'), NULL), NULL),
    title = title,
    subtitle = subtitle,
    xlab = xlab,
    ylab = ylab,
    legend.position = get_param_any(params, c('legend_position', 'legend.position'), 'right'),
    legend.direction = get_param_any(params, c('legend_direction', 'legend.direction'), 'vertical'),
    theme.use = theme_use,
    theme.args = theme_args,
    combine = as_bool(get_param(params, 'combine', TRUE), TRUE),
    nrow = nrow_v,
    ncol = ncol_v,
    byrow = as_bool(get_param(params, 'byrow', TRUE), TRUE),
    force = TRUE,
    seed = as.numeric(get_param(params, 'seed', 10086))
  )

  attr(args, 'id_col') <- id_col
  attr(args, 'stat_by') <- stat_by
  attr(args, 'group_by') <- group_by
  attr(args, 'split_by') <- split_by
  attr(args, 'bg_by') <- bg_by
  attr(args, 'plot_type') <- plot_type
  attr(args, 'stat_type') <- stat_type
  args
}

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------
main <- function() {
  if (is.null(input_file)) write_error_and_exit('Missing --input argument')
  if (is.null(params_file) || !file.exists(params_file)) write_error_and_exit('Params file not found', paste('Params path:', params_file), 'Provide params.json.')
  if (is.null(output_dir)) write_error_and_exit('Missing --output argument')
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  old_outputs <- file.path(output_dir, c('error.json', 'result.svg', 'result.pdf', 'result.png', 'figure.json', 'selected_rows.csv', 'run.log'))
  old_outputs <- old_outputs[file.exists(old_outputs)]
  if (length(old_outputs) > 0) unlink(old_outputs)
  write_log('Starting stat_plot plugin.')

  params <- jsonlite::fromJSON(params_file, simplifyVector = FALSE)
  load_sca_stat_reference()

  df <- read_table_auto(input_file)
  id_col <- get_param_any(params, c('id_column', 'cell_id_column', 'sample_id_column', 'row_id_column'), NULL)
  if (is.null(id_col)) id_col <- first_existing_col(df, c('cell_id', 'Cell', 'cell', 'sample_id', 'sample', 'barcode', colnames(df)[1]), TRUE, 'id_column')
  validate_columns(df, id_col)
  df[[id_col]] <- make.unique(as.character(df[[id_col]]))

  # Row filtering
  rows_include <- as_string_vector(get_param_any(params, c('rows_include', 'cells_include', 'samples_include'), NULL), NULL)
  rows_exclude <- as_string_vector(get_param_any(params, c('rows_exclude', 'cells_exclude', 'samples_exclude'), NULL), NULL)
  if (length(rows_include) > 0) df <- df[df[[id_col]] %in% rows_include, , drop = FALSE]
  if (length(rows_exclude) > 0) df <- df[!df[[id_col]] %in% rows_exclude, , drop = FALSE]
  if (nrow(df) == 0) write_error_and_exit('No rows left after filtering', '', 'Relax rows_include/rows_exclude.')

  args <- build_stat_args(df, params)
  write_log(paste('Plot type:', attr(args, 'plot_type'), '| stat type:', attr(args, 'stat_type')))
  write_log(paste('stat_by:', paste(attr(args, 'stat_by'), collapse = ', '),
                  '| group_by:', paste(attr(args, 'group_by'), collapse = ', ') %||% '<none>',
                  '| split_by:', paste(attr(args, 'split_by'), collapse = ', ') %||% '<none>',
                  '| bg_by:', paste(attr(args, 'bg_by'), collapse = ', ') %||% '<none>'))

  plot_obj <- tryCatch(do.call(statPlot, args), error = function(e) e)
  if (inherits(plot_obj, 'error')) {
    write_error_and_exit('statPlot failed', conditionMessage(plot_obj), 'Check stat_by/group_by/split_by columns and plot_type.')
  }

  width <- num_param(params, 'width', 8)
  height <- num_param(params, 'height', 6)
  dpi <- as.numeric(get_param(params, 'dpi', 300))
  # Generic appearance parameters not handled by this plugin (R/runtime/omicscanvas_theme.R).
  if (!exists('omicscanvas_apply_theme')) { .oc_f <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[1]); .oc_rt <- file.path(dirname(normalizePath(.oc_f, mustWork = FALSE)), '..', '..', 'R', 'runtime', 'omicscanvas_theme.R'); if (!file.exists(.oc_rt)) .oc_rt <- file.path('R', 'runtime', 'omicscanvas_theme.R'); sys.source(.oc_rt, envir = globalenv()) }; plot_obj <- omicscanvas_apply_theme(plot_obj, params, only = c('axis_label_size', 'font_family', 'font_size', 'legend_key_size', 'legend_text_size', 'legend_title_size', 'panel_fill', 'plot_fill', 'title_size', 'x_axis_text_angle', 'x_axis_text_size', 'y_axis_text_size'))
  save_plot(plot_obj, output_dir, width, height, dpi)
  write_log('Saved result.svg/pdf/png.')

  # Export filtered input rows used
  out_rows <- df
  utils::write.csv(out_rows, file.path(output_dir, 'selected_rows.csv'), row.names = FALSE)

  # Compute a few summary numbers for figure.json
  stat_by <- attr(args, 'stat_by')
  n_levels <- tryCatch(
    length(unique(unlist(lapply(df[, stat_by, drop = FALSE], function(x) unique(as.character(x)))))),
    error = function(e) NA_integer_
  )

  figure <- list(
    plugin = 'stat_plot',
    source_engine = 'SCA::statPlot',
    input = normalizePath(input_file, mustWork = FALSE),
    plot_type = attr(args, 'plot_type'),
    stat_type = attr(args, 'stat_type'),
    stat_by = attr(args, 'stat_by'),
    group_by = if (length(attr(args, 'group_by')) > 0) attr(args, 'group_by') else NULL,
    split_by = if (length(attr(args, 'split_by')) > 0) attr(args, 'split_by') else NULL,
    bg_by = if (length(attr(args, 'bg_by')) > 0) attr(args, 'bg_by') else NULL,
    n_rows = nrow(df),
    n_levels = n_levels,
    outputs = list(svg = 'result.svg', pdf = 'result.pdf', png = 'result.png', selected_rows = 'selected_rows.csv', log = 'run.log')
  )
  writeLines(jsonlite::toJSON(figure, auto_unbox = TRUE, null = 'null', pretty = TRUE), file.path(output_dir, 'figure.json'))
  write_log('Completed stat_plot plugin.')
}

tryCatch(main(), error = function(e) {
  write_error_and_exit('Unhandled plugin error', conditionMessage(e), 'Inspect run.log and params.json.')
})