#!/usr/bin/env Rscript

# OmicsCanvas Plot Plugin: Violin Plot
# ------------------------------------------------------------
# Wraps the SCA violinPlot.R::classicVlnPlot() visual style.
#
# Runtime contract:
#   Rscript plot.R --input expression.csv --annot metadata.csv --params params.json --output output_dir
#
# Input modes (params `input_mode`):
#   long       : long-format table [cell_id, feature, value, group] (+ optional annotation)
#   wide_matrix: features x cells matrix + annotation file (--annot) with a group column
#   wide_cells : cells x features table + annotation file (--annot) with a group column
#
# The original classicVlnPlot is Seurat-centric (uses ckFeas which reads seu@assays).
# For CLI use we REIMPLEMENT the same ggplot2 layers and SCA visual style operating
# directly on a long-format data frame. The original SCA source is preserved in
# R/sca/violinPlot.R for reference only.

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
  library(patchwork)
  library(ggbeeswarm)
})

option_list <- list(
  make_option(c('--input'), type = 'character', default = NULL,
              help = 'Expression table (long, wide_matrix, or wide_cells) CSV/TSV/TXT.'),
  make_option(c('--annot'), type = 'character', default = NULL,
              help = 'Optional annotation/metadata CSV/TSV/TXT with cell id and group columns (required for wide_matrix/wide_cells).'),
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

# --------------------------------------------------------------------
# Standard helpers (copied from den_plot/plot.R)
# --------------------------------------------------------------------

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

as_numeric_vector <- function(x, default = numeric()) {
  if (is.null(x)) return(default)
  if (is.list(x) && !is.data.frame(x)) x <- unlist(x, use.names = FALSE)
  if (length(x) == 1 && is.character(x) && grepl(',', x, fixed = TRUE)) x <- strsplit(x, ',', fixed = TRUE)[[1]]
  out <- suppressWarnings(as.numeric(x))
  out[is.finite(out)]
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
    write_error_and_exit(paste('Missing required', label), paste('Missing columns:', paste(missing, collapse = ', ')), paste('Check params column names; available:', paste(colnames(df), collapse = ', ')))
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

# --------------------------------------------------------------------
# Data loading
# --------------------------------------------------------------------

load_long_data <- function(params) {
  df <- read_table_auto(input_file)
  cell_col <- get_param_any(params, c('cell_id_column', 'cell_column'), first_existing_col(df, c('cell', 'cell_id', 'Cell', 'sample', 'barcode'), TRUE, 'cell_id_column'))
  feat_col <- get_param_any(params, c('feature_column', 'gene_column'), first_existing_col(df, c('gene', 'feature', 'Gene', 'Feature'), TRUE, 'feature_column'))
  val_col <- get_param_any(params, c('value_column'), first_existing_col(df, c('value', 'Value', 'expression', 'expr'), TRUE, 'value_column'))
  group_col <- get_param_any(params, c('group_column', 'group_col'), first_existing_col(df, c('cluster', 'group', 'Group', 'celltype', 'condition'), TRUE, 'group_column'))
  anno_col <- get_param_any(params, c('annotation_column', 'annovar'), NULL)
  validate_columns(df, c(cell_col, feat_col, val_col, group_col), 'long-format column')
  long <- data.frame(
    cell = as.character(df[[cell_col]]),
    feature = as.character(df[[feat_col]]),
    value = suppressWarnings(as.numeric(df[[val_col]])),
    group = as.character(df[[group_col]]),
    stringsAsFactors = FALSE
  )
  if (!is.null(anno_col) && anno_col %in% colnames(df)) {
    long$annotation <- as.character(df[[anno_col]])
  } else {
    long$annotation <- long$feature
  }
  long
}

melt_matrix_to_long <- function(df, annot, params, orientation) {
  feat_col <- get_param_any(params, c('feature_column', 'row_id_column', 'id_column'), if (orientation == 'matrix') colnames(df)[1] else NULL)
  if (orientation == 'matrix') {
    # features x cells: first column is feature id
    if (is.null(feat_col) || !feat_col %in% colnames(df)) feat_col <- colnames(df)[1]
    id_vals <- as.character(df[[feat_col]])
    cell_cols <- setdiff(colnames(df), feat_col)
    mat <- suppressWarnings(as.matrix(data.frame(lapply(df[, cell_cols, drop = FALSE], as.numeric), check.names = FALSE)))
    rownames(mat) <- make.unique(id_vals)
    colnames(mat) <- cell_cols
    features <- rownames(mat)
    cells <- colnames(mat)
  } else {
    # cells x features: first column is cell id
    cell_id_col <- get_param_any(params, c('cell_id_column', 'id_column'), colnames(df)[1])
    if (!cell_id_col %in% colnames(df)) cell_id_col <- colnames(df)[1]
    cell_vals <- as.character(df[[cell_id_col]])
    feat_cols <- setdiff(colnames(df), cell_id_col)
    mat <- suppressWarnings(as.matrix(data.frame(lapply(df[, feat_cols, drop = FALSE], as.numeric), check.names = FALSE)))
    rownames(mat) <- make.unique(cell_vals)
    colnames(mat) <- feat_cols
    cells <- rownames(mat)
    features <- colnames(mat)
  }
  # melt (as.numeric(mat) is column-major: down rows first, then across cols)
  if (orientation == 'matrix') {
    # rows = features, cols = cells
    long <- data.frame(
      cell = rep(colnames(mat), each = nrow(mat)),
      feature = rep(rownames(mat), times = ncol(mat)),
      value = as.numeric(mat),
      stringsAsFactors = FALSE
    )
  } else {
    # rows = cells, cols = features
    long <- data.frame(
      cell = rep(rownames(mat), times = ncol(mat)),
      feature = rep(colnames(mat), each = nrow(mat)),
      value = as.numeric(mat),
      stringsAsFactors = FALSE
    )
  }
  # join group from annotation
  if (is.null(annot)) {
    write_error_and_exit('Annotation file required for wide_matrix/wide_cells mode', '', 'Provide --annot with a cell id and group column.')
  }
  cell_col <- get_param_any(params, c('cell_id_column', 'sample_col', 'sample_column'), first_existing_col(annot, c('cell', 'cell_id', 'Cell', 'sample', 'Sample', 'barcode'), TRUE, 'cell_id_column'))
  group_col <- get_param_any(params, c('group_column', 'group_col'), first_existing_col(annot, c('cluster', 'group', 'Group', 'celltype', 'condition'), TRUE, 'group_column'))
  anno_col <- get_param_any(params, c('annotation_column', 'annovar'), NULL)
  validate_columns(annot, c(cell_col, group_col), 'annotation column')
  annot_sub <- annot[, c(cell_col, group_col), drop = FALSE]
  colnames(annot_sub) <- c('cell', 'group')
  if (!is.null(anno_col) && anno_col %in% colnames(annot)) {
    annot_sub$annotation <- as.character(annot[[anno_col]])
  }
  long <- merge(long, annot_sub, by = 'cell', all.x = TRUE)
  long$group[is.na(long$group)] <- 'Unknown'
  if (!'annotation' %in% colnames(long)) long$annotation <- long$feature
  long$annotation[is.na(long$annotation)] <- long$feature[is.na(long$annotation)]
  long
}

load_data <- function(params) {
  input_mode <- tolower(as.character(get_param(params, 'input_mode', 'long'))[1])
  annot <- NULL
  if (!is.null(annot_file)) annot <- read_table_auto(annot_file)
  if (input_mode == 'long') {
    long <- load_long_data(params)
  } else if (input_mode == 'wide_matrix') {
    df <- read_table_auto(input_file)
    long <- melt_matrix_to_long(df, annot, params, 'matrix')
  } else if (input_mode == 'wide_cells') {
    df <- read_table_auto(input_file)
    long <- melt_matrix_to_long(df, annot, params, 'cells')
  } else {
    write_error_and_exit('Unsupported input_mode', paste('input_mode:', input_mode), 'Use one of: long, wide_matrix, wide_cells.')
  }
  # drop NA values
  n_na <- sum(is.na(long$value))
  if (n_na > 0) {
    write_log(paste('Dropping', n_na, 'rows with NA values.'))
    long <- long[is.finite(long$value), , drop = FALSE]
  }
  if (nrow(long) == 0) write_error_and_exit('No valid expression rows after loading', '', 'Check value column / numeric matrix contents.')
  long
}

# --------------------------------------------------------------------
# Filtering
# --------------------------------------------------------------------

apply_filters <- function(long, params) {
  features_include <- as_string_vector(get_param_any(params, c('features_include', 'features'), NULL))
  features_exclude <- as_string_vector(get_param_any(params, c('features_exclude'), NULL))
  rows_include <- as_string_vector(get_param_any(params, c('rows_include', 'cells_include'), NULL))
  rows_exclude <- as_string_vector(get_param_any(params, c('rows_exclude', 'cells_exclude'), NULL))

  if (length(features_include) > 0) long <- long[long$feature %in% features_include, , drop = FALSE]
  if (length(features_exclude) > 0) long <- long[!long$feature %in% features_exclude, , drop = FALSE]
  if (length(rows_include) > 0) long <- long[long$cell %in% rows_include, , drop = FALSE]
  if (length(rows_exclude) > 0) long <- long[!long$cell %in% rows_exclude, , drop = FALSE]

  if (nrow(long) == 0) write_error_and_exit('No data left after filtering', '', 'Relax features_include/exclude or rows_include/exclude.')

  # factor ordering
  long$feature <- factor(long$feature, levels = unique(long$feature))
  long$group <- factor(long$group, levels = unique(long$group))
  long
}

# --------------------------------------------------------------------
# Plot construction (reimplements classicVlnPlot visual style)
# --------------------------------------------------------------------

median_quartile <- function(x) {
  out <- stats::quantile(x, probs = c(0.25, 0.5, 0.75), na.rm = TRUE)
  names(out) <- c('ymin', 'y', 'ymax')
  out
}

build_main_plot <- function(long, params) {
  add_dot <- as_bool(get_param(params, 'add_dot', FALSE))
  add_stat <- tolower(as.character(get_param(params, 'add_stat', 'boxplot'))[1])
  if (add_stat %in% c('none', 'null', '')) add_stat <- 'none'

  violin_scale <- as.character(get_param(params, 'violin_scale', 'width'))[1]
  violin_adjust <- num_param(params, 'violin_adjust', 1)
  violin_trim <- as_bool(get_param(params, 'violin_trim', TRUE), TRUE)
  violin_alpha <- num_param(params, 'violin_alpha', NA_real_)
  boxplot_width <- num_param(params, 'boxplot_width', 0.1)
  boxplot_outlier_size <- num_param(params, 'boxplot_outlier_size', num_param(params, 'point_size', 0.5))
  median_point_size <- num_param(params, 'median_point_size', num_param(params, 'psize', 0.5))
  dot_size <- num_param(params, 'dot_size', 0.1)
  point_size <- num_param(params, 'point_size', num_param(params, 'psize', 0.5))

  x_axis_text_angle <- num_param(params, 'x_axis_text_angle', 45)
  strip_text_size <- num_param(params, 'strip_text_size', NA_real_)
  base_size <- num_param(params, 'base_size', 11)
  font_family <- get_param(params, 'font_family', NULL)
  font_size <- num_param(params, 'font_size', NA_real_)

  legend_show <- as_bool(get_param(params, 'legend_show', FALSE), FALSE)
  legend_position <- get_param(params, 'legend_position', 'right')

  title <- get_param(params, 'title', '')
  title_show <- as_bool(get_param(params, 'title_show', TRUE), TRUE)
  ylab <- get_param(params, 'ylab', 'Expression level')
  ylab_show <- as_bool(get_param(params, 'ylab_show', TRUE), TRUE)
  xlab <- get_param(params, 'xlab', '')
  xlab_show <- as_bool(get_param(params, 'xlab_show', FALSE), FALSE)

  group_colors <- as_named_vector(get_param_any(params, c('group_colors', 'color.use', 'color_use'), NULL), default = NULL)
  point_color <- get_param(params, 'point_color', '#333333')

  rotate_x <- as_bool(get_param(params, 'rotate_x', FALSE), FALSE)
  # rotate_x toggles whether x axis text is rotated; default SCA style uses 45 angle.
  # If rotate_x is FALSE we still keep the SCA default 45 angle unless x_axis_text_angle is set to 0.
  x_angle <- if (isTRUE(rotate_x)) 90 else x_axis_text_angle

  p <- ggplot(long, aes(x = feature, y = value, fill = feature)) +
    geom_violin(scale = violin_scale, adjust = violin_adjust, trim = violin_trim)

  if (is.finite(violin_alpha)) p <- p + aes(alpha = after_stat(violin_alpha))

  if (add_stat == 'boxplot') {
    p <- p + geom_boxplot(width = boxplot_width, position = position_dodge(0.9), outlier.size = boxplot_outlier_size)
  } else if (add_stat == 'median') {
    p <- p + stat_summary(fun.data = median_quartile, geom = 'point', size = median_point_size)
  }

  if (isTRUE(add_dot)) {
    p <- p + geom_quasirandom(dodge.width = 0.9, varwidth = TRUE, size = dot_size, color = point_color)
  }

  # SCA right-side y axis label trick
  p <- p + scale_y_continuous(
    # A little headroom per row so violins never run into the neighbouring facet row.
    expand = expansion(mult = c(0.04, 0.06)),
    position = 'right',
    labels = function(x) c(rep('', length(x) - 2), x[length(x) - 1], '')
  )

  p <- p + facet_grid(rows = vars(group), scales = 'free')

  # theme (SCA style)
  theme_args <- list(
    legend.position = if (isTRUE(legend_show)) legend_position else 'none',
    panel.spacing = unit(0, 'lines'),
    plot.title = element_text(hjust = 0.5),
    panel.background = element_rect(fill = NA, color = 'black'),
    plot.margin = margin(7, 7, 0, 7, 'pt'),
    strip.background = element_rect(fill = 'white'),
    strip.text = element_text(face = 'bold'),
    strip.text.y.right = element_text(angle = 0),
    axis.title.x = element_blank(),
    axis.ticks.x = element_blank(),
    axis.text.x = element_text(angle = x_angle, hjust = 1, vjust = 1, color = 'black')
  )
  if (is.finite(strip_text_size)) theme_args$strip.text <- element_text(face = 'bold', size = strip_text_size)
  if (!is.null(font_family)) {
    theme_args$text <- element_text(family = font_family)
  }
  if (is.finite(font_size)) {
    theme_args$text <- element_text(size = font_size)
  }
  p <- p + do.call(theme, theme_args)

  if (!is.null(group_colors)) {
    p <- p + scale_fill_manual(values = group_colors)
  }

  if (isTRUE(title_show) && nzchar(title)) p <- p + ggtitle(title)
  if (isTRUE(ylab_show)) p <- p + ylab(ylab) else p <- p + ylab(NULL)
  if (isTRUE(xlab_show) && nzchar(xlab)) p <- p + xlab(xlab)

  p
}

build_anno_plot <- function(long, params) {
  anno_df <- unique(long[, c('feature', 'annotation'), drop = FALSE])
  anno_df$annotation <- factor(anno_df$annotation)
  anno_df$feature <- factor(anno_df$feature, levels = levels(long$feature))

  y_anno_label <- get_param(params, 'y_anno_label', get_param(params, 'plot.y.anno', ''))
  anno_colors <- as_named_vector(get_param_any(params, c('anno_colors', 'annotation_colors'), NULL), default = NULL)

  p <- ggplot(anno_df, aes(x = feature, y = 1, fill = annotation)) +
    geom_tile() +
    theme_bw(base_size = 12) +
    scale_y_continuous(expand = c(0, 0)) +
    ylab(y_anno_label) + xlab('') +
    guides(fill = guide_legend(direction = 'vertical', label.position = 'right',
                               title.theme = element_blank(), keyheight = 0.5, nrow = 2)) +
    theme(
      legend.position = 'bottom',
      legend.justification = 'left',
      legend.margin = margin(0, 0, 0, 0),
      legend.box.margin = margin(-10, 5, 0, 0),
      panel.spacing = unit(0, 'lines'),
      panel.background = element_blank(),
      panel.border = element_blank(),
      plot.background = element_blank(),
      plot.margin = margin(0, 7, 7, 7, 'pt'),
      axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5, color = 'black'),
      axis.ticks.y = element_blank(),
      axis.text.y = element_blank()
    )
  if (!is.null(anno_colors)) p <- p + scale_fill_manual(values = anno_colors)
  p
}

# --------------------------------------------------------------------
# Main
# --------------------------------------------------------------------

main <- function() {
  if (is.null(input_file)) write_error_and_exit('Missing --input argument')
  if (is.null(params_file) || !file.exists(params_file)) write_error_and_exit('Params file not found', paste('Params path:', params_file), 'Provide params.json.')
  if (is.null(output_dir)) write_error_and_exit('Missing --output argument')
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  old_outputs <- file.path(output_dir, c('error.json', 'result.svg', 'result.pdf', 'result.png', 'figure.json', 'selected_rows.csv', 'run.log'))
  old_outputs <- old_outputs[file.exists(old_outputs)]
  if (length(old_outputs) > 0) unlink(old_outputs)

  write_log('Starting violin_plot plugin.')

  params <- jsonlite::fromJSON(params_file, simplifyVector = FALSE)
  input_mode <- tolower(as.character(get_param(params, 'input_mode', 'long'))[1])

  long <- load_data(params)
  write_log(sprintf('Loaded %d long rows in %s mode.', nrow(long), input_mode))

  long <- apply_filters(long, params)
  n_features <- length(levels(long$feature))
  n_cells <- length(unique(as.character(long$cell)))
  n_groups <- length(levels(long$group))
  write_log(sprintf('After filtering: %d features, %d cells, %d groups.', n_features, n_cells, n_groups))

  add_anno <- as_bool(get_param(params, 'add_anno', FALSE), FALSE)
  add_dot <- as_bool(get_param(params, 'add_dot', FALSE), FALSE)
  add_stat <- tolower(as.character(get_param(params, 'add_stat', 'boxplot'))[1])

  main_plot <- build_main_plot(long, params)

  if (isTRUE(add_anno)) {
    anno_plot <- build_anno_plot(long, params)
    main_plot <- main_plot + theme(axis.text.x = element_blank())
    final_plot <- main_plot / anno_plot + plot_layout(heights = c(20, 1))
  } else {
    final_plot <- main_plot
  }

  # Export selected rows
  selected <- unique(long[, c('feature', 'cell', 'group'), drop = FALSE])
  utils::write.csv(selected, file.path(output_dir, 'selected_rows.csv'), row.names = FALSE)
  write_log(sprintf('Wrote selected_rows.csv with %d rows.', nrow(selected)))

  width <- num_param(params, 'width', 8)
  height <- num_param(params, 'height', 6)
  dpi <- num_param(params, 'dpi', 300)
  # Generic appearance parameters not handled by this plugin (R/runtime/omicscanvas_theme.R).
  if (!exists('omicscanvas_apply_theme')) { .oc_f <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[1]); .oc_rt <- file.path(dirname(normalizePath(.oc_f, mustWork = FALSE)), '..', '..', 'R', 'runtime', 'omicscanvas_theme.R'); if (!file.exists(.oc_rt)) .oc_rt <- file.path('R', 'runtime', 'omicscanvas_theme.R'); sys.source(.oc_rt, envir = globalenv()) }; final_plot <- omicscanvas_apply_theme(final_plot, params, only = c('axis_label_size', 'title_size', 'x_axis_text_size', 'y_axis_text_size'))
  save_plot(final_plot, output_dir, width, height, dpi)
  write_log('Saved result.svg/pdf/png.')

  figure <- list(
    plot_type = 'violin_plot',
    source_engine = 'SCA classicVlnPlot (reimplemented for CSV)',
    input_mode = input_mode,
    input_file = normalizePath(input_file, mustWork = FALSE),
    annotation_file = if (!is.null(annot_file)) normalizePath(annot_file, mustWork = FALSE) else NULL,
    n_features = n_features,
    n_cells = n_cells,
    n_groups = n_groups,
    features = as.character(levels(long$feature)),
    groups = as.character(levels(long$group)),
    add_stat = add_stat,
    add_dot = add_dot,
    add_anno = add_anno,
    outputs = list(svg = 'result.svg', pdf = 'result.pdf', png = 'result.png', selected_rows = 'selected_rows.csv', log = 'run.log')
  )
  writeLines(jsonlite::toJSON(figure, auto_unbox = TRUE, pretty = TRUE), file.path(output_dir, 'figure.json'))
  write_log('Completed violin_plot plugin.')
}

tryCatch(main(), error = function(e) {
  write_error_and_exit('Violin plot failed', conditionMessage(e), 'Check input columns, params.json, and that ggbeeswarm/patchwork are installed.')
})