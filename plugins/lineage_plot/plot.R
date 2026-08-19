#!/usr/bin/env Rscript

# BioFigureAI Plot Plugin: Lineage Plot
# ------------------------------------------------------------
# Runtime contract:
#   Rscript plot.R --input embedding.csv --lineages lineage_table.csv \
#     --params params.json --output output_dir
#
# This plugin wraps the SCA lineagePlot() visual style (loess-fitted
# colored paths with arrows, optional whiskers, background stroke) but
# operates on plain CSV inputs (an embedding matrix + a lineage/pseudotime
# table) instead of a Seurat object. The core fitting/plotting algorithm is
# reimplemented from reference_sca_helpers/lineagePlot.R::lineagePlot
# (.curve.layer block) to work on data frames/matrices directly.

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
  library(grid)
})

option_list <- list(
  make_option(c('--input'), type = 'character', default = NULL,
              help = 'Cell embedding CSV/TSV/TXT. First column = cell id; next two columns = dim1, dim2.'),
  make_option(c('--lineages'), type = 'character', default = NULL,
              help = 'Lineage/pseudotime table CSV/TSV/TXT. First column = cell id; remaining columns = lineage values.'),
  make_option(c('--params'), type = 'character', default = NULL,
              help = 'Path to params.json.'),
  make_option(c('--output'), type = 'character', default = NULL,
              help = 'Output directory.')
)

opt <- parse_args(OptionParser(option_list = option_list))
input_file <- opt$input
lineages_file <- opt$lineages
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
  if (length(name) > 1) return(get_param_any(params, name, default))
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

num_param_any <- function(params, names, default) {
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
# SCA reference loading (util.plot.R for paletteCustomize/themeDefault/
# themeBlank; lineagePlot.R kept for reference/fidelity).
# ------------------------------------------------------------
load_sca_reference <- function() {
  script_arg <- grep('^--file=', commandArgs(FALSE), value = TRUE)
  script_path <- if (length(script_arg) > 0) sub('^--file=', '', script_arg[1]) else file.path(getwd(), 'plugins', 'lineage_plot', 'plot.R')
  helper_dir <- file.path(dirname(normalizePath(script_path, mustWork = FALSE)), 'reference_sca_helpers')
  if (!dir.exists(helper_dir)) helper_dir <- file.path('plugins', 'lineage_plot', 'reference_sca_helpers')

  # Locally define helpers that lineagePlot.R / util.plot.R expect.
  `%||%` <<- function(x, y) if (is.null(x) || length(x) == 0) y else x
  scale01 <<- function(x) (x - min(x, na.rm = TRUE)) / (max(x, na.rm = TRUE) - min(x, na.rm = TRUE))
  # DefaultReduction stub (lineagePlot calls it only when reduction is NULL;
  # not used in CLI mode but defined for safe sourcing).
  DefaultReduction <<- function(seu) {
    if (!is.null(seu) && exists('reductions', where = seu)) return(names(seu$reductions)[1])
    'umap'
  }
  rescale <<- scales::rescale
  melt <<- reshape2::melt

  load_pkgs <- function(pkgs) {
    missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
    if (length(missing) > 0) stop('Missing required R package(s): ', paste(missing, collapse = ', '), call. = FALSE)
    invisible(lapply(pkgs, function(p) suppressPackageStartupMessages(library(p, character.only = TRUE))))
  }
  load_pkgs(c('cli', 'dplyr', 'tidyr'))

  source(file.path(helper_dir, 'util.plot.R'), local = .GlobalEnv)
  # lineagePlot.R is sourced for reference/fidelity; the CLI reimplementation
  # below does not call it (it requires a Seurat object).
  tryCatch(source(file.path(helper_dir, 'lineagePlot.R'), local = .GlobalEnv),
           error = function(e) write_log(paste('Note: lineagePlot.R sourced with warning:', conditionMessage(e))))

  # Patch paletteCustomize to read the OmicsCanvas palettes.rds asset.
  old_palette <- paletteCustomize
  palette_file <- file.path(getwd(), 'assets', 'palettes.rds')
  paletteCustomize <<- function(..., palettePath = NULL) {
    old_palette(..., palettePath = palettePath %||% palette_file)
  }
  invisible(TRUE)
}

# ------------------------------------------------------------
# Core lineage plotting (reimplemented from lineagePlot.R .curve.layer).
# Takes a cell.xy matrix (n_cells x 2) and a lineages.df data frame
# (cell-aligned, columns = lineage values) instead of a Seurat object.
# ------------------------------------------------------------
build_lineage_plot <- function(cell.xy, lineages.df, lineages, params) {
  dims <- as_numeric_vector(get_param_any(params, c('dims'), c(1, 2)), c(1, 2))
  if (length(dims) < 2) dims <- c(dims, dims[1])
  dims <- dims[1:2]
  trim <- as_numeric_vector(get_param_any(params, c('trim'), c(0.01, 0.99)), c(0.01, 0.99))
  if (length(trim) < 2) trim <- c(trim[1], trim[1])
  trim <- trim[1:2]
  span <- num_param(params, 'span', 0.75)

  linewidth <- num_param(params, 'linewidth', 1)
  line.bg <- get_param_any(params, c('line_bg', 'line.bg'), 'white')
  line.bg.stroke <- num_param_any(params, c('line_bg_stroke', 'line.bg.stroke'), 0.5)
  whiskers <- as_bool(get_param(params, 'whiskers', FALSE), FALSE)
  whiskers.linewidth <- num_param_any(params, c('whiskers_linewidth', 'whiskers.linewidth'), 0.5)
  whiskers.alpha <- num_param_any(params, c('whiskers_alpha', 'whiskers.alpha'), 0.5)
  aspect.ratio <- num_param_any(params, c('aspect_ratio', 'aspect.ratio'), 1)

  arrow_opt <- get_param_any(params, c('lineages_arrow', 'lineages.arrow'), TRUE)
  lineages_arrow <- if (isTRUE(as_bool(arrow_opt, TRUE))) {
    arrow(length = unit(0.1, 'inches'))
  } else if (is.character(arrow_opt) && !as_bool(arrow_opt, FALSE)) {
    # user passed false-ish string -> no arrow
    NULL
  } else {
    arrow(length = unit(0.1, 'inches'))
  }

  palette <- get_param(params, 'palette', 'Dark2')
  palcolor <- as_named_vector(get_param_any(params, c('palcolor', 'lineage_colors', 'group_colors'), NULL), default = NULL)

  # axis names
  axis_names <- colnames(cell.xy)
  if (is.null(axis_names)) axis_names <- paste0('Dim', dims)
  axes <- axis_names

  xlab <- get_param(params, 'xlab', axes[1])
  ylab <- get_param(params, 'ylab', axes[2])
  title <- get_param(params, 'title', NULL)
  subtitle <- get_param(params, 'subtitle', NULL)

  # colors via SCA paletteCustomize (patched to read assets/palettes.rds)
  .colors <- paletteCustomize(lineages, palette = palette, palcolor = palcolor)

  # Build a combined data frame mirroring lineagePlot.R .df
  .df <- as.data.frame(cell.xy, stringsAsFactors = FALSE)
  colnames(.df) <- axes
  .df$cell <- rownames(.df) %||% seq_len(nrow(.df))
  .df <- cbind(.df, lineages.df[, lineages, drop = FALSE])

  # .curve.layer reimplementation
  curve_layers <- list()
  for (l in lineages) {
    vals <- .df[[l]]
    .trim.qc <- vals > quantile(vals, trim[1], na.rm = TRUE) & vals < quantile(vals, trim[2], na.rm = TRUE)
    .na.qc <- !is.na(vals)
    .index <- which(.trim.qc & .na.qc)
    if (length(.index) < 4) {
      write_log(paste('Lineage', l, 'has too few cells after trim (', length(.index), '); skipping.'))
      next
    }
    .index <- .index[order(vals[.index])]
    .df.ava <- .df[.index, , drop = FALSE]
    .weights <- rep(1, nrow(.df.ava))
    .fits <- lapply(axes, function(x) {
      loess(formula(paste(x, l, sep = ' ~ ')), weights = .weights, data = .df.ava, span = span, degree = 2)$fitted
    })
    names(.fits) <- axes
    .fits[['index']] <- .index
    .fits <- as.data.frame(.fits, stringsAsFactors = FALSE)
    colnames(.fits) <- c(paste0('Axis_', seq_along(axes)), 'index')
    .fits[['Lineages']] <- factor(l, levels = lineages)

    if (isTRUE(whiskers)) {
      whisker_df <- .df.ava
      whisker_df[['Axis_1']] <- .fits[['Axis_1']]
      whisker_df[['Axis_2']] <- .fits[['Axis_2']]
      whisker_df[['raw_Axis_1']] <- .df.ava[[axes[1]]]
      whisker_df[['raw_Axis_2']] <- .df.ava[[axes[2]]]
      whisker_df[['Lineages']] <- factor(l, levels = lineages)
      curve_layers <- c(curve_layers, list(
        geom_segment(
          data = whisker_df, mapping = aes(x = Axis_1, y = Axis_2, xend = raw_Axis_1, yend = raw_Axis_2, color = Lineages),
          linewidth = whiskers.linewidth, alpha = whiskers.alpha,
          show.legend = TRUE, inherit.aes = FALSE
        )
      ))
    }

    .fits <- unique(na.omit(.fits))
    curve_layers <- c(curve_layers, list(
      geom_path(
        data = .fits, mapping = aes(x = Axis_1, y = Axis_2), color = line.bg,
        linewidth = linewidth + line.bg.stroke, arrow = lineages_arrow,
        show.legend = TRUE, inherit.aes = FALSE
      ),
      geom_path(
        data = .fits, mapping = aes(x = Axis_1, y = Axis_2, color = Lineages),
        linewidth = linewidth, arrow = lineages_arrow,
        show.legend = TRUE, inherit.aes = FALSE
      )
    ))
  }

  if (length(curve_layers) == 0) {
    write_error_and_exit('No lineage curves could be fitted',
                         paste('Lineages:', paste(lineages, collapse = ', ')),
                         'Check that lineage columns have enough non-NA values and relax trim.')
  }

  curve_layers <- c(curve_layers, list(scale_color_manual(values = .colors)))

  # labels
  title_show <- as_bool(get_param(params, 'title_show', TRUE), TRUE)
  xlab_show <- as_bool(get_param(params, 'xlab_show', TRUE), TRUE)
  ylab_show <- as_bool(get_param(params, 'ylab_show', TRUE), TRUE)
  lab_layer <- list(labs(
    title = if (isTRUE(title_show)) title else NULL,
    subtitle = subtitle,
    x = if (isTRUE(xlab_show)) xlab else NULL,
    y = if (isTRUE(ylab_show)) ylab else NULL
  ))

  # theme
  theme.use <- get_param_any(params, c('theme_use', 'theme.use'), 'themeDefault')
  theme.fn <- if (identical(theme.use, 'themeBlank') || identical(theme.use, 'theme_blank')) {
    themeBlank
  } else {
    themeDefault
  }
  legend.position <- get_param(params, 'legend_position', 'right')
  legend.direction <- get_param(params, 'legend_direction', 'vertical')
  base_size <- num_param(params, 'base_size', 12)
  font_family <- get_param(params, 'font_family', NULL)
  title_size <- num_param(params, 'title_size', NA_real_)
  axis_label_size <- num_param(params, 'axis_label_size', NA_real_)
  x_axis_text_size <- num_param(params, 'x_axis_text_size', NA_real_)
  y_axis_text_size <- num_param(params, 'y_axis_text_size', NA_real_)
  legend_title_size <- num_param(params, 'legend_title_size', NA_real_)
  legend_text_size <- num_param(params, 'legend_text_size', NA_real_)
  legend_key_size <- num_param(params, 'legend_key_size', NA_real_)

  theme.args <- list()
  if (!is.null(font_family)) theme.args$text <- element_text(family = font_family)
  theme.args$aspect.ratio <- aspect.ratio
  theme.args$legend.position <- legend.position
  theme.args$legend.direction <- legend.direction
  if (is.finite(title_size)) theme.args$plot.title <- element_text(size = title_size)
  if (is.finite(axis_label_size)) theme.args$axis.title <- element_text(size = axis_label_size)
  if (is.finite(x_axis_text_size)) theme.args$axis.text.x <- element_text(size = x_axis_text_size)
  if (is.finite(y_axis_text_size)) theme.args$axis.text.y <- element_text(size = y_axis_text_size)
  if (is.finite(legend_title_size)) theme.args$legend.title <- element_text(size = legend_title_size)
  if (is.finite(legend_text_size)) theme.args$legend.text <- element_text(size = legend_text_size)
  if (is.finite(legend_key_size)) theme.args$legend.key.size <- unit(legend_key_size, 'pt')

  theme.layer <- do.call(theme.fn, c(list(baseSize = base_size), theme.args))

  return.layer <- as_bool(get_param(params, c('return_layer', 'return.layer'), FALSE), FALSE)
  if (isTRUE(return.layer)) {
    return(list(curve.layer = curve_layers, lab.layer = lab_layer, theme.layer = theme.layer))
  }

  p <- ggplot() + curve_layers + lab_layer + theme.layer
  p
}

# ------------------------------------------------------------
# save_plot (svg/pdf/png with retry)
# ------------------------------------------------------------
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

# ------------------------------------------------------------
main <- function() {
  if (is.null(input_file)) write_error_and_exit('Missing --input argument')
  if (is.null(lineages_file)) write_error_and_exit('Missing --lineages argument')
  if (is.null(params_file) || !file.exists(params_file)) write_error_and_exit('Params file not found', paste('Params path:', params_file), 'Provide params.json.')
  if (is.null(output_dir)) write_error_and_exit('Missing --output argument')
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  old_outputs <- file.path(output_dir, c('error.json', 'result.svg', 'result.pdf', 'result.png', 'figure.json', 'selected_rows.csv', 'run.log'))
  old_outputs <- old_outputs[file.exists(old_outputs)]
  if (length(old_outputs) > 0) unlink(old_outputs)
  write_log('Starting lineage_plot plugin.')

  params <- jsonlite::fromJSON(params_file, simplifyVector = FALSE)

  load_sca_reference()
  write_log('Loaded SCA reference helpers (util.plot.R, lineagePlot.R).')

  # ---- read embedding ----
  emb <- read_table_auto(input_file)
  id_col_e <- get_param_any(params, c('cell_id_column', 'id_column'), colnames(emb)[1])
  validate_columns(emb, id_col_e, 'embedding')
  dim1_col <- get_param_any(params, c('dim1_column'), colnames(emb)[2])
  dim2_col <- get_param_any(params, c('dim2_column'), colnames(emb)[3])
  validate_columns(emb, c(dim1_col, dim2_col), 'embedding')
  emb[[id_col_e]] <- make.unique(as.character(emb[[id_col_e]]))

  # ---- read lineage table ----
  lin <- read_table_auto(lineages_file)
  id_col_l <- get_param_any(params, c('lineage_id_column', 'cell_id_column', 'id_column'), colnames(lin)[1])
  validate_columns(lin, id_col_l, 'lineage table')
  lin[[id_col_l]] <- make.unique(as.character(lin[[id_col_l]]))

  # ---- match cells ----
  common <- intersect(emb[[id_col_e]], lin[[id_col_l]])
  if (length(common) == 0) {
    write_error_and_exit('No matching cell ids between embedding and lineage table',
                         paste('embedding id col:', id_col_e, '; lineage id col:', id_col_l),
                         'Ensure cell id columns share the same identifiers.')
  }
  emb <- emb[match(common, emb[[id_col_e]]), , drop = FALSE]
  lin <- lin[match(common, lin[[id_col_l]]), , drop = FALSE]
  write_log(paste('Matched cells:', length(common)))

  # ---- cells include/exclude ----
  cells_include <- as_string_vector(get_param_any(params, c('cells_include', 'rows_include'), NULL))
  cells_exclude <- as_string_vector(get_param_any(params, c('cells_exclude', 'rows_exclude'), NULL))
  selected <- common
  if (length(cells_include) > 0) selected <- intersect(selected, cells_include)
  if (length(cells_exclude) > 0) selected <- setdiff(selected, cells_exclude)
  if (length(selected) == 0) write_error_and_exit('No cells left after cells_include/exclude', '', 'Relax cell filters.')
  if (length(selected) < length(common)) {
    write_log(paste('Cell filter applied:', length(selected), 'of', length(common), 'cells kept.'))
    emb <- emb[match(selected, emb[[id_col_e]]), , drop = FALSE]
    lin <- lin[match(selected, lin[[id_col_l]]), , drop = FALSE]
  }

  # ---- lineage columns ----
  lineage_candidates <- setdiff(colnames(lin), id_col_l)
  lineages <- as_string_vector(get_param(params, 'lineages', NULL))
  if (length(lineages) == 0) lineages <- lineage_candidates
  lineages <- intersect(lineages, lineage_candidates)
  if (length(lineages) == 0) {
    write_error_and_exit('No lineage columns selected',
                         paste('available:', paste(lineage_candidates, collapse = ', ')),
                         'Set lineages to one or more lineage/pseudotime columns.')
  }
  validate_columns(lin, lineages, 'lineage table')

  # ---- build cell.xy and lineages.df ----
  cell.xy <- matrix(NA_real_, nrow = nrow(emb), ncol = 2)
  cell.xy[, 1] <- suppressWarnings(as.numeric(emb[[dim1_col]]))
  cell.xy[, 2] <- suppressWarnings(as.numeric(emb[[dim2_col]]))
  colnames(cell.xy) <- c(dim1_col, dim2_col)
  rownames(cell.xy) <- emb[[id_col_e]]
  keep <- rowSums(is.finite(cell.xy)) == 2
  if (!all(keep)) {
    write_log(paste('Dropping cells with non-finite embedding coords:', sum(!keep)))
    cell.xy <- cell.xy[keep, , drop = FALSE]
    emb <- emb[keep, , drop = FALSE]
    lin <- lin[keep, , drop = FALSE]
  }

  lineages.df <- as.data.frame(lin[, lineages, drop = FALSE], stringsAsFactors = FALSE)
  for (l in lineages) {
    lineages.df[[l]] <- suppressWarnings(as.numeric(lineages.df[[l]]))
  }
  rownames(lineages.df) <- lin[[id_col_l]]

  # drop cells where ALL lineages are NA
  all_na <- apply(lineages.df, 1, function(r) all(is.na(r)))
  if (any(all_na)) {
    write_log(paste('Dropping cells with all-NA lineage values:', sum(all_na)))
    cell.xy <- cell.xy[!all_na, , drop = FALSE]
    lineages.df <- lineages.df[!all_na, , drop = FALSE]
    emb <- emb[!all_na, , drop = FALSE]
  }

  if (nrow(cell.xy) < 5) {
    write_error_and_exit('Too few cells to fit lineage curves', paste('n_cells:', nrow(cell.xy)), 'Provide more cells with valid embedding and lineage values.')
  }

  seed <- num_param(params, 'seed', 10086)
  set.seed(seed)

  write_log(paste('Fitting lineages:', paste(lineages, collapse = ', '),
                  '| n_cells:', nrow(cell.xy), '| dims:', paste(colnames(cell.xy), collapse = ' / ')))

  p <- build_lineage_plot(cell.xy, lineages.df, lineages, params)

  # ---- export selected rows ----
  utils::write.csv(data.frame(cell = emb[[id_col_e]], stringsAsFactors = FALSE),
                   file.path(output_dir, 'selected_rows.csv'), row.names = FALSE)

  # ---- save outputs ----
  width <- num_param(params, 'width', 7)
  height <- num_param(params, 'height', 6)
  dpi <- num_param(params, 'dpi', 300)
  save_plot(p, output_dir, width, height, dpi)
  write_log('Saved result.svg/pdf/png.')

  # ---- figure.json ----
  figure <- list(
    plot_type = 'lineage_plot',
    source_engine = 'SCA lineagePlot.R (reimplemented for CSV inputs)',
    input_file = normalizePath(input_file, mustWork = FALSE),
    lineages_file = normalizePath(lineages_file, mustWork = FALSE),
    lineages = lineages,
    n_cells = nrow(cell.xy),
    dims = colnames(cell.xy),
    span = num_param(params, 'span', 0.75),
    trim = as_numeric_vector(get_param_any(params, c('trim'), c(0.01, 0.99)), c(0.01, 0.99)),
    palette = get_param(params, 'palette', 'Dark2'),
    whiskers = as_bool(get_param(params, 'whiskers', FALSE), FALSE),
    outputs = list(svg = 'result.svg', pdf = 'result.pdf', png = 'result.png',
                   selected_rows = 'selected_rows.csv', log = 'run.log')
  )
  writeLines(jsonlite::toJSON(figure, auto_unbox = TRUE, pretty = TRUE), file.path(output_dir, 'figure.json'))
  write_log('Completed lineage_plot plugin.')
}

tryCatch(main(), error = function(e) {
  write_error_and_exit('Lineage plot failed', conditionMessage(e), 'Check embedding/lineage columns, cell id matching, and params.json.')
})