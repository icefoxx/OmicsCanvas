#!/usr/bin/env Rscript

# BioFigureAI Plot Plugin: Group Heatmap
# ------------------------------------------------------------
# Runtime contract:
#   Rscript plot.R --input input.csv --params params.json --output output_dir
#
# Wraps the original SCA GroupHeatmap() engine with a stable table/JSON
# interface and standard result.svg/pdf/png/figure.json outputs.

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(grid)
  library(ggplot2)
})

option_list <- list(
  make_option(c('--input'), type = 'character', default = NULL,
              help = 'Wide CSV/TSV/TXT table. Rows are cells/samples; columns include metadata and feature values.'),
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

num_param_any <- function(params, names, default = NA_real_) {
  value <- suppressWarnings(as.numeric(get_param_any(params, names, default))[1])
  if (is.na(value)) default else value
}

int_param_any <- function(params, names, default = NA_integer_) {
  value <- suppressWarnings(as.integer(get_param_any(params, names, default))[1])
  if (is.na(value)) default else value
}

as_named_vector <- function(x, default = NULL) {
  if (is.null(x)) return(default)
  values <- unlist(x, use.names = TRUE)
  if (length(values) == 0) return(default)
  out <- as.character(values)
  names(out) <- names(values)
  out
}

validate_columns <- function(df, cols, label = 'input') {
  cols <- cols[!is.na(cols) & nzchar(cols)]
  missing_cols <- setdiff(cols, colnames(df))
  if (length(missing_cols) > 0) {
    write_error_and_exit('Required columns not found', paste(label, 'missing:', paste(missing_cols, collapse = ', ')), 'Check column params and the input header.')
  }
}

load_sca_groupheatmap_reference <- function() {
  script_arg <- grep('^--file=', commandArgs(FALSE), value = TRUE)
  script_path <- if (length(script_arg) > 0) sub('^--file=', '', script_arg[1]) else file.path(getwd(), 'plugins', 'group_heatmap', 'plot.R')
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
  ckSeu <<- function(...) invisible(TRUE)
  ckCols <<- function(data, cols) {
    missing <- setdiff(cols, colnames(data))
    if (length(missing) > 0) stop('Missing required column(s): ', paste(missing, collapse = ', '), call. = FALSE)
    invisible(TRUE)
  }
  fetchFeasMeta <<- function(...) stop('fetchFeasMeta is only available for Seurat input; this plugin standardizes table input.', call. = FALSE)
  toDenseMatrix <<- function(x) {
    if (inherits(x, 'Matrix')) return(as.matrix(x))
    as.matrix(x)
  }
  avgPctExp <<- function(dt, threshold = 0, cluster = c('seurat_clusters')) {
    data.table::setDT(dt)
    .dt.agg <- dt[, lapply(.SD, function(x) c(sum(x > threshold, na.rm = TRUE) / sum(!is.na(x)), mean(x, na.rm = TRUE))), by = cluster]
    .dt.agg.pct <- .dt.agg[rep(c(TRUE, FALSE), length = .N)]
    .dt.agg.mean <- .dt.agg[rep(c(FALSE, TRUE), length = .N)]
    list(pct = .dt.agg.pct, mean = .dt.agg.mean)
  }
  source(file.path(helper_dir, 'util.plot.R'), local = .GlobalEnv)
  source(file.path(helper_dir, 'GroupHeatmap.R'), local = .GlobalEnv)
  source(file.path(helper_dir, 'omicscanvas_shims.R'), local = .GlobalEnv)
  omicscanvas_patch_palette(helper_dir)
  invisible(TRUE)
}

prepare_input <- function(df, params) {
  id_col <- get_param_any(params, c('id_column', 'cell_id_column', 'sample_id_column', 'row_id_column'), NULL)
  if (!is.null(id_col)) validate_columns(df, id_col)
  rows_include <- as_string_vector(get_param_any(params, c('rows_include', 'cells_include', 'samples_include'), NULL))
  rows_exclude <- as_string_vector(get_param_any(params, c('rows_exclude', 'cells_exclude', 'samples_exclude'), NULL))
  if (!is.null(id_col)) {
    df[[id_col]] <- make.unique(as.character(df[[id_col]]))
    rownames(df) <- df[[id_col]]
    if (length(rows_include) > 0) df <- df[df[[id_col]] %in% rows_include, , drop = FALSE]
    if (length(rows_exclude) > 0) df <- df[!df[[id_col]] %in% rows_exclude, , drop = FALSE]
  }
  if (nrow(df) == 0) write_error_and_exit('No rows left after filtering', '', 'Relax rows_include/rows_exclude.')
  attr(df, 'id_col') <- id_col
  df
}

select_features <- function(df, params, metadata_cols) {
  features <- as_string_vector(get_param_any(params, c('features', 'feature_columns', 'genes'), NULL))
  excluded <- unique(c(metadata_cols, attr(df, 'id_col')))
  if (length(features) == 0) {
    candidates <- setdiff(colnames(df), excluded)
    is_num <- vapply(df[, candidates, drop = FALSE], function(x) all(is.finite(suppressWarnings(as.numeric(x)))), logical(1))
    features <- candidates[is_num]
  }
  features <- setdiff(features, as_string_vector(get_param_any(params, c('features_exclude', 'feature_columns_exclude'), NULL)))
  include <- as_string_vector(get_param_any(params, c('features_include', 'feature_columns_include'), NULL))
  if (length(include) > 0) features <- intersect(include, features)
  validate_columns(df, features, 'feature')
  if (length(features) == 0) write_error_and_exit('No features selected', '', 'Set features or provide numeric feature columns.')
  features
}

parse_feature_split <- function(features, params) {
  feature_groups <- get_param_any(params, c('feature_groups', 'feature_split_map'), NULL)
  if (!is.null(feature_groups)) {
    if (is.list(feature_groups) && !is.data.frame(feature_groups)) {
      if (!is.null(names(feature_groups)) && all(features %in% names(feature_groups))) {
        out <- as.character(unlist(feature_groups[features], use.names = FALSE))
        return(out)
      }
      out <- rep(NA_character_, length(features))
      for (grp in names(feature_groups)) {
        hit <- intersect(as_string_vector(feature_groups[[grp]]), features)
        out[match(hit, features)] <- grp
      }
      out[is.na(out)] <- 'Features'
      return(out)
    }
  }
  feature_split <- as_string_vector(get_param_any(params, c('feature_split', 'feature_group_vector'), NULL))
  if (length(feature_split) == length(features)) return(feature_split)
  NULL
}

parse_annotation_labels <- function(params) {
  as_named_vector(get_param_any(params, c('top_annotation_labels', 'annotation_label_map'), NULL), default = NULL)
}

build_groupheatmap_args <- function(df, params) {
  group_by <- as_string_vector(get_param_any(params, c('group.by', 'group_by', 'group_column', 'group_columns'), NULL))
  if (length(group_by) == 0) {
    group_by <- intersect(c('cluster', 'Cluster', 'group', 'Group', 'condition', 'orig.ident'), colnames(df))[1]
  }
  if (is.na(group_by) || length(group_by) == 0) write_error_and_exit('No group column selected', '', 'Set group_column or group_columns.')
  cell_annotation <- as_string_vector(get_param_any(params, c('cell_annotation', 'annotation_columns', 'top_annotation_columns'), NULL))
  validate_columns(df, unique(c(group_by, cell_annotation)), 'metadata')
  features <- select_features(df, params, unique(c(group_by, cell_annotation)))
  feature_split <- parse_feature_split(features, params)
  for (feature in features) df[[feature]] <- suppressWarnings(as.numeric(df[[feature]]))

  list(
    srt = df,
    features = features,
    group.by = group_by,
    cell_annotation = if (length(cell_annotation) == 0) NULL else cell_annotation,
    top_annotation_labels = parse_annotation_labels(params),
    group_order = as_string_vector(get_param_any(params, c('group_order', 'group_levels'), NULL), NULL),
    feature_order = as_string_vector(get_param_any(params, c('feature_order', 'feature_levels'), NULL), NULL),
    feature_split = feature_split,
    feature_annotation = get_param(params, 'feature_annotation', NULL),
    feature_annotation_palette = get_param(params, 'feature_annotation_palette', NULL),
    threshold = num_param_any(params, c('threshold'), 0),
    plot_type = get_param_any(params, c('plot_type', 'plot.type'), 'heatmap'),
    heatmap_mode = get_param_any(params, c('heatmap_mode'), 'group'),
    violin_mode = get_param_any(params, c('violin_mode'), 'plain'),
    violin_cluster_features = as_bool(get_param_any(params, c('violin_cluster_features'), FALSE)),
    style = get_param_any(params, c('style'), 'merge'),
    summary = get_param_any(params, c('summary', 'summary_method'), 'mean'),
    group_heatmap_split_by_annotation = as_bool(get_param_any(params, c('group_heatmap_split_by_annotation'), FALSE)),
    heatmap_palette = get_param_any(params, c('heatmap_palette', 'palette'), 'YlOrRd'),
    heatmap_palcolor = as_string_vector(get_param_any(params, c('heatmap_palcolor', 'heatmap_colors', 'palcolor'), NULL), NULL),
    cell_annotation_palette = get_param_any(params, c('cell_annotation_palette', 'annotation_palette'), NULL),
    cell_annotation_palcolor = as_named_vector(get_param_any(params, c('cell_annotation_palcolor', 'annotation_colors'), NULL), NULL),
    group_palette = get_param_any(params, c('group_palette'), 'Paired'),
    group_palcolor = as_named_vector(get_param_any(params, c('group_palcolor', 'group_colors'), NULL), NULL),
    show_row_names = as_bool(get_param_any(params, c('show_row_names', 'row_names_show'), TRUE), TRUE),
    row_names_fontsize = num_param_any(params, c('row_names_fontsize', 'row_name_size'), NA_real_),
    row_names_every_n = int_param_any(params, c('row_names_every_n'), NA_integer_),
    row_names_max = int_param_any(params, c('row_names_max'), NA_integer_),
    row_names_layers = int_param_any(params, c('row_names_layers'), 1L),
    row_names_method = get_param_any(params, c('row_names_method'), 'plain'),
    row_name_link_col = get_param_any(params, c('row_name_link_col', 'row_name_link_color'), '#666666'),
    row_name_link_lwd = num_param_any(params, c('row_name_link_lwd', 'row_name_link_size'), 0.6),
    highlight_features = as_string_vector(get_param_any(params, c('highlight_features', 'highlight_rows', 'highlight_genes'), NULL), NULL),
    highlight_features_side = get_param_any(params, c('highlight_features_side', 'highlight_side'), 'left'),
    highlight_features_gp = grid::gpar(
      fontsize = num_param_any(params, c('highlight_feature_size', 'highlight_label_size'), 10),
      col = get_param_any(params, c('highlight_feature_color', 'highlight_label_color'), 'black'),
      fontface = get_param_any(params, c('highlight_feature_face', 'highlight_label_face'), 'plain'),
      fontfamily = get_param_any(params, c('font_family', 'highlight_feature_family'), '')
    ),
    show_top_annotation_name = as_bool(get_param_any(params, c('show_top_annotation_name', 'top_annotation_name_show'), TRUE), TRUE),
    top_annotation_name_rot = num_param_any(params, c('top_annotation_name_rot', 'top_annotation_name_angle'), 0),
    top_annotation_name_fontsize = num_param_any(params, c('top_annotation_name_fontsize', 'top_annotation_name_size'), 10),
    show_feature_split_title = as_bool(get_param_any(params, c('show_feature_split_title', 'feature_split_title_show'), TRUE), TRUE),
    feature_split_title_rot = num_param_any(params, c('feature_split_title_rot', 'feature_split_title_angle'), 90),
    feature_split_title_fontsize = num_param_any(params, c('feature_split_title_fontsize', 'feature_split_title_size'), 10),
    show_feature_group_name = as_bool(get_param_any(params, c('show_feature_group_name', 'feature_group_name_show'), TRUE), TRUE),
    feature_group_side = get_param_any(params, c('feature_group_side'), 'left'),
    feature_group_name_rot = num_param_any(params, c('feature_group_name_rot', 'feature_group_name_angle'), 90),
    feature_group_name_fontsize = num_param_any(params, c('feature_group_name_fontsize', 'feature_group_name_size'), 10),
    show_column_names = as_bool(get_param_any(params, c('show_column_names', 'column_names_show'), TRUE), TRUE),
    column_names_fontsize = num_param_any(params, c('column_names_fontsize', 'column_name_size'), NA_real_),
    row_names_side = get_param_any(params, c('row_names_side', 'row_name_side'), 'left'),
    orientation = get_param_any(params, c('orientation'), 'vertical'),
    cluster_rows = as_bool(get_param_any(params, c('cluster_rows', 'show_row_dendrogram'), FALSE)),
    cluster_columns = as_bool(get_param_any(params, c('cluster_columns', 'show_column_dendrogram'), FALSE)),
    add_dot = as_bool(get_param_any(params, c('add_dot', 'show_dot'), FALSE)),
    add_reticle = as_bool(get_param_any(params, c('add_reticle', 'show_reticle'), FALSE)),
    dot_range = as_numeric_vector(get_param_any(params, c('dot_range'), c(0.5, 3.5)), c(0.5, 3.5)),
    border = as_bool(get_param_any(params, c('border', 'cell_border_show'), TRUE), TRUE),
    group_sep = get_param_any(params, c('group_sep'), ' | '),
    annotation_pie_scale = num_param_any(params, c('annotation_pie_scale'), 0.88),
    annotation_track_scale = num_param_any(params, c('annotation_track_scale'), 1.0),
    annotation_track_gap = num_param_any(params, c('annotation_track_gap'), 0.02),
    annotation_pie_y_span = num_param_any(params, c('annotation_pie_y_span'), 0.5),
    annotation_pie_mode = get_param_any(params, c('annotation_pie_mode'), 'flush'),
    annotation_attach = as_bool(get_param_any(params, c('annotation_attach'), TRUE), TRUE),
    annotation_row_frame = as_bool(get_param_any(params, c('annotation_row_frame'), FALSE), FALSE),
    show_annotation_frame = as_bool(get_param_any(params, c('show_annotation_frame'), TRUE), TRUE),
    show_annotation_y_axis = as_bool(get_param_any(params, c('show_annotation_y_axis'), TRUE), TRUE),
    show_annotation_label = as_bool(get_param_any(params, c('show_annotation_label'), TRUE), TRUE),
    annotation_label_angle = num_param_any(params, c('annotation_label_angle'), 90),
    annotation_label_size = num_param_any(params, c('annotation_label_size'), NA_real_),
    annotation_label_face = get_param_any(params, c('annotation_label_face'), 'plain'),
    annotation_label_family = get_param_any(params, c('annotation_label_family', 'font_family'), ''),
    annotation_label_margin_pt = num_param_any(params, c('annotation_label_margin_pt'), 4),
    track_heights = {
      .th <- get_param(params, 'track_heights', c(group = 0.9, categorical = 1.45, numeric = 1.7, dot = 5))
      if (is.list(.th) && !is.data.frame(.th)) .th <- unlist(.th)
      .th.names <- names(.th)
      .th <- suppressWarnings(as.numeric(.th))
      names(.th) <- if (!is.null(.th.names) && any(nzchar(.th.names))) .th.names else c('group', 'categorical', 'numeric', 'dot')[seq_along(.th)]
      .th
    },
    clustered_dotplot_row_mm = num_param_any(params, c('clustered_dotplot_row_mm'), NA_real_),
    clustered_dotplot_col_mm = num_param_any(params, c('clustered_dotplot_col_mm'), NA_real_),
    clustered_dotplot_max_height_mm = num_param_any(params, c('clustered_dotplot_max_height_mm'), 220),
    clustered_dotplot_max_width_mm = num_param_any(params, c('clustered_dotplot_max_width_mm'), 180),
    clustered_dotplot_row_fontsize = num_param_any(params, c('clustered_dotplot_row_fontsize'), NA_real_),
    clustered_dotplot_column_fontsize = num_param_any(params, c('clustered_dotplot_column_fontsize'), NA_real_),
    violin_alpha = num_param_any(params, c('violin_alpha'), 0.75),
    point_stroke = num_param_any(params, c('point_stroke'), 0.5),
    left_label_angle = num_param_any(params, c('left_label_angle'), 0),
    position_track_label_side = get_param_any(params, c('position_track_label_side'), 'left'),
    legend_width_ratio = num_param_any(params, c('legend_width_ratio'), 0.18),
    legend_stack_spacing = num_param_any(params, c('legend_stack_spacing'), 0.02),
    legend_title_size = num_param_any(params, c('legend_title_size'), NA_real_),
    legend_text_size = num_param_any(params, c('legend_text_size'), NA_real_),
    legend_key_size_pt = num_param_any(params, c('legend_key_size_pt', 'legend_key_size'), NA_real_),
    legend_scale = num_param_any(params, c('legend_scale'), 1)
  )
}

draw_object <- function(plot_obj, file, params, device = c('pdf', 'png', 'svg')) {
  device <- match.arg(device)
  width <- num_param_any(params, c('width'), 8)
  height <- num_param_any(params, c('height'), 6)
  dpi <- num_param_any(params, c('dpi'), 300)
  if (device == 'pdf') grDevices::pdf(file, width = width, height = height, useDingbats = FALSE)
  if (device == 'png') grDevices::png(file, width = width, height = height, units = 'in', res = dpi)
  if (device == 'svg') grDevices::svg(file, width = width, height = height)
  on.exit(grDevices::dev.off(), add = TRUE)
  if (inherits(plot_obj, c('gg', 'ggplot', 'patchwork'))) {
    print(plot_obj)
  } else {
    ComplexHeatmap::draw(
      plot_obj,
      heatmap_legend_side = get_param_any(params, c('heatmap_legend_side', 'legend_position'), 'right'),
      annotation_legend_side = get_param_any(params, c('annotation_legend_side', 'annotation_legend_position'), get_param_any(params, c('legend_position'), 'right')),
      merge_legends = as_bool(get_param_any(params, c('merge_legends'), TRUE), TRUE),
      padding = grid::unit(as_numeric_vector(get_param_any(params, c('padding', 'plot_padding'), c(2, 2, 2, 2)), c(2, 2, 2, 2)), 'mm')
    )
  }
}

save_plot_all <- function(plot_obj, outdir, params) {
  draw_object(plot_obj, file.path(outdir, 'result.pdf'), params, 'pdf')
  draw_object(plot_obj, file.path(outdir, 'result.png'), params, 'png')
  draw_object(plot_obj, file.path(outdir, 'result.svg'), params, 'svg')
}

main <- function() {
  if (is.null(input_file) || is.null(params_file) || is.null(output_dir)) {
    write_error_and_exit('Missing required arguments', '', 'Use --input input.csv --params params.json --output output_dir.')
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  unlink(file.path(output_dir, 'error.json'))
  writeLines('', file.path(output_dir, 'run.log'))
  write_log('Starting group_heatmap plugin.')
  params <- jsonlite::fromJSON(params_file, simplifyVector = FALSE)
  load_sca_groupheatmap_reference()
  input_df <- prepare_input(read_table_auto(input_file), params)
  args <- build_groupheatmap_args(input_df, params)
  plot_obj <- tryCatch(do.call(GroupHeatmap, args), error = function(e) e)
  if (inherits(plot_obj, 'error')) {
    write_error_and_exit('GroupHeatmap failed', conditionMessage(plot_obj), 'Check selected group/feature/annotation columns and parameter values.')
  }
  save_plot_all(plot_obj, output_dir, params)
  selected <- input_df
  if (!is.null(attr(input_df, 'id_col'))) selected[[attr(input_df, 'id_col')]] <- rownames(input_df)
  write.csv(selected, file.path(output_dir, 'selected_rows.csv'), row.names = FALSE)
  figure <- list(
    plugin = 'group_heatmap',
    source_engine = 'SCA::GroupHeatmap',
    input = normalizePath(input_file, mustWork = FALSE),
    rows = nrow(input_df),
    features = args$features,
    group_by = args$group.by,
    cell_annotation = args$cell_annotation,
    plot_type = args$plot_type,
    heatmap_mode = args$heatmap_mode,
    summary = args$summary,
    outputs = c('result.svg', 'result.pdf', 'result.png', 'selected_rows.csv')
  )
  writeLines(jsonlite::toJSON(figure, auto_unbox = TRUE, pretty = TRUE), file.path(output_dir, 'figure.json'))
  write_log('Finished successfully.')
}

tryCatch(main(), error = function(e) {
  write_error_and_exit('Unhandled plugin error', conditionMessage(e), 'Inspect run.log and params.json.')
})
