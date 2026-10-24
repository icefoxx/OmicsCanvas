#!/usr/bin/env Rscript

# BioFigureAI Plot Plugin: SCA Volcano Plot
# ------------------------------------------------------------
# Wraps SCA VocalnoPlot.R functions:
#   volcanoPlot     -> plot_kind = "volcano"
#   avgVolcano      -> plot_kind = "avg_volcano"
#   percentVocalno  -> plot_kind = "percent_volcano"
#
# Runtime contract:
#   Rscript plot.R --input markers.csv --params params.json --output output_dir

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
  library(grid)
})

option_list <- list(
  make_option(c('--input'), type = 'character', default = NULL,
              help = 'Marker/differential table CSV/TSV/TXT. Required columns: gene, avg_log2FC, p_val_adj, pct.1, pct.2 (aliases autodetected).'),
  make_option(c('--params'), type = 'character', default = NULL,
              help = 'Path to params.json.'),
  make_option(c('--output'), type = 'character', default = NULL,
              help = 'Output directory.'),
  make_option(c('--regions'), type = 'character', default = NULL,
              help = 'Optional region annotation CSV/TSV (overrides params region_annotations_file).')
)

opt <- parse_args(OptionParser(option_list = option_list))
input_file <- opt$input
params_file <- opt$params
output_dir <- opt$output
regions_arg <- opt$regions

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

scale01 <- function(x) {
  x <- as.numeric(x)
  rng <- range(x, na.rm = TRUE)
  if (is.infinite(rng[1]) || is.infinite(rng[2]) || rng[2] == rng[1]) return(rep(0.5, length(x)))
  (x - rng[1]) / (rng[2] - rng[1])
}

# ---------------------------------------------------------------------------
# SCA reference loading
# ---------------------------------------------------------------------------

load_sca_volcano_reference <- function() {
  script_arg <- grep('^--file=', commandArgs(FALSE), value = TRUE)
  script_path <- if (length(script_arg) > 0) sub('^--file=', '', script_arg[1]) else file.path(getwd(), 'plugins', 'sca_volcano_plot', 'plot.R')
  # Shared SCA helper library (one canonical copy for all plugins): <repo>/R/sca
  helper_dir <- file.path(dirname(normalizePath(script_path, mustWork = FALSE)), '..', '..', 'R', 'sca')
  if (!dir.exists(helper_dir)) helper_dir <- file.path('R', 'sca')

  # Local palette_scp fallback (not defined in SCA source).
  palette_scp <<- function(x = NULL, palette = 'RdBu', palcolor = NULL, ...) {
    if (!is.null(palcolor) && length(palcolor) > 0) {
      cols <- as.character(palcolor)
      return(grDevices::colorRampPalette(cols)(100))
    }
    pal <- tolower(as.character(palette)[1])
    brewer_map <- list(
      rdbu = 'RdBu', rdylbu = 'RdYlBu', spectral = 'Spectral',
      redblue = 'RdBu', viridis = 'viridis', magma = 'magma',
      plasma = 'plasma', inferno = 'inferno'
    )
    name <- brewer_map[[pal]]
    if (!is.null(name) && name %in% c('viridis', 'magma', 'plasma', 'inferno')) {
      return(viridisLite::viridis_pal(option = name)(100))
    }
    if (!is.null(name) && name %in% rownames(RColorBrewer::brewer.pal.info)) {
      n_max <- RColorBrewer::brewer.pal.info[name, 'maxcolors']
      cols <- RColorBrewer::brewer.pal(n_max, name)
      return(grDevices::colorRampPalette(cols)(100))
    }
    # default: RdBu
    cols <- RColorBrewer::brewer.pal(11, 'RdBu')
    grDevices::colorRampPalette(cols)(100)
  }

  # Minimal stubs that some SCA helpers may reference.
  ckPacsR <<- function(packages, ...) {
    packages <- sub('@.*$', '', packages)
    packages <- sub('^.*/', '', packages)
    missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
    if (length(missing) > 0) stop('Missing required R package(s): ', paste(missing, collapse = ', '), call. = FALSE)
    invisible(TRUE)
  }
  toUpperX <<- function(x) {
    if (is.null(x)) return(NULL)
    if (is.character(x)) return(toupper(x))
    x
  }

  # VocalnoPlot.R uses %>% , case_when, map_df, ensym, str_wrap, etc.
  # Make sure the pipe and helper namespaces are attached in .GlobalEnv.
  suppressPackageStartupMessages({
    library(dplyr)
    library(magrittr)
    library(purrr)
    library(stringr)
    library(rlang)
    library(tibble)
    library(ggrepel)
    library(patchwork)
  })

  # Source util.plot.R (defines paletteCustomize + themeDefault).
  source(file.path(helper_dir, 'util.plot.R'), local = .GlobalEnv)

  # Patch paletteCustomize to read palettes.rds from the OmicsCanvas assets dir.
  source(file.path(helper_dir, 'omicscanvas_shims.R'), local = .GlobalEnv)
  omicscanvas_patch_palette(helper_dir)

  # Source ck + scf helpers, then the VocalnoPlot functions.
  source(file.path(helper_dir, 'util.ck_helpers.R'), local = .GlobalEnv)
  source(file.path(helper_dir, 'util.scf_helpers.R'), local = .GlobalEnv)
  source(file.path(helper_dir, 'VocalnoPlot.R'), local = .GlobalEnv)

  invisible(TRUE)
}

# ---------------------------------------------------------------------------
# Data preparation
# ---------------------------------------------------------------------------

prepare_markers <- function(df, params) {
  gene_col <- get_param_any(params, c('gene_column', 'gene_col'), NULL)
  if (is.null(gene_col)) gene_col <- first_existing_col(df, c('gene', 'Gene', 'gene_id', 'feature', 'symbol', 'SYMBOL', colnames(df)[1]), TRUE, 'gene_column')
  log2fc_col <- get_param_any(params, c('log2fc_column', 'log2FC_column', 'avg_log2FC_column'), NULL)
  if (is.null(log2fc_col)) log2fc_col <- first_existing_col(df, c('avg_log2FC', 'log2FC', 'logFC', 'log2_fold_change', 'lfc'), TRUE, 'log2fc_column')
  pval_col <- get_param_any(params, c('pval_column', 'pval_adj_column', 'p_value_column'), NULL)
  if (is.null(pval_col)) pval_col <- first_existing_col(df, c('p_val_adj', 'p_val', 'pvalue', 'p.adj', 'p_adj', 'padj', 'FDR', 'qval'), TRUE, 'pval_column')
  pct1_col <- get_param_any(params, c('pct1_column', 'pct.1_column'), NULL)
  if (is.null(pct1_col)) pct1_col <- first_existing_col(df, c('pct.1', 'pct1', 'pct_1'), TRUE, 'pct1_column')
  pct2_col <- get_param_any(params, c('pct2_column', 'pct.2_column'), NULL)
  if (is.null(pct2_col)) pct2_col <- first_existing_col(df, c('pct.2', 'pct2', 'pct_2'), TRUE, 'pct2_column')
  cluster_col <- get_param_any(params, c('cluster_column', 'cluster_col'), NULL)
  if (is.null(cluster_col)) cluster_col <- first_existing_col(df, c('cluster', 'Cluster', 'cell_type', 'celltype', 'group'), FALSE, 'cluster_column')
  split_col <- get_param_any(params, c('split_column', 'split_col'), NULL)
  if (is.null(split_col)) split_col <- first_existing_col(df, c('split.by', 'split_by', 'batch', 'condition'), FALSE, 'split_column')

  validate_columns(df, c(gene_col, log2fc_col, pval_col, pct1_col, pct2_col), 'markers')

  # Standardize column names expected by SCA functions.
  df$gene <- as.character(df[[gene_col]])
  df$avg_log2FC <- suppressWarnings(as.numeric(df[[log2fc_col]]))
  df$p_val_adj <- suppressWarnings(as.numeric(df[[pval_col]]))
  df$pct.1 <- suppressWarnings(as.numeric(df[[pct1_col]]))
  df$pct.2 <- suppressWarnings(as.numeric(df[[pct2_col]]))
  if (!is.null(cluster_col) && cluster_col %in% colnames(df)) {
    df$cluster <- as.character(df[[cluster_col]])
  } else {
    df$cluster <- 'all'
  }
  if (!is.null(split_col) && split_col %in% colnames(df)) {
    df$split.by <- as.character(df[[split_col]])
  } else {
    df$split.by <- 'all'
    split_col <- 'split.by'
  }

  # Drop rows with non-finite core values.
  keep <- is.finite(df$avg_log2FC) & is.finite(df$p_val_adj) & is.finite(df$pct.1) & is.finite(df$pct.2)
  if (!all(keep)) {
    write_log(paste('Dropping rows with NA/Inf in core columns:', sum(!keep)))
    df <- df[keep, , drop = FALSE]
  }

  # Row/gene include/exclude filters.
  rows_include <- as_string_vector(get_param_any(params, c('rows_include', 'features_include'), NULL))
  rows_exclude <- as_string_vector(get_param_any(params, c('rows_exclude', 'features_exclude'), NULL))
  if (length(rows_include) > 0) df <- df[df$gene %in% rows_include, , drop = FALSE]
  if (length(rows_exclude) > 0) df <- df[!df$gene %in% rows_exclude, , drop = FALSE]
  if (nrow(df) == 0) write_error_and_exit('No marker rows left after filtering', '', 'Relax rows_include/features_include or rows_exclude/features_exclude.')

  # Guard against p_val_adj == 0 (would give -Inf on -log10).
  df$p_val_adj[df$p_val_adj <= 0] <- .Machine$double.xmin

  attr(df, 'gene_col') <- gene_col
  attr(df, 'cluster_col') <- if (!is.null(cluster_col) && cluster_col %in% colnames(df)) cluster_col else 'cluster'
  attr(df, 'split_col') <- if (!is.null(split_col) && split_col %in% colnames(df)) split_col else 'split.by'
  df
}

# ---------------------------------------------------------------------------
# Plot builders
# ---------------------------------------------------------------------------

resolve_limits <- function(value, observed, padding = 0.05) {
  if (!is.null(value)) {
    v <- as_numeric_vector(value)
    if (length(v) >= 2 && all(is.finite(v[1:2])) && v[1] < v[2]) return(v[1:2])
  }
  span <- diff(observed)
  if (!is.finite(span) || span == 0) span <- max(abs(observed), 1)
  observed + c(-1, 1) * span * padding
}

resolve_coord <- function(value, axis, limits, threshold) {
  if (is.null(value) || length(value) == 0 || !nzchar(as.character(value)[1])) return(NA_real_)
  s <- tolower(trimws(as.character(value)[1]))
  aliases <- c('-threshold' = -threshold, 'threshold' = threshold, '-inf' = -Inf, 'inf' = Inf)
  if (axis == 'x') aliases <- c(aliases, x_min = limits[1], x_max = limits[2])
  if (axis == 'y') aliases <- c(aliases, y_min = limits[1], y_max = limits[2])
  if (s %in% names(aliases)) return(aliases[[s]])
  suppressWarnings(as.numeric(s))
}

normalize_point_groups <- function(params) {
  groups <- get_param(params, 'point_groups', NULL)
  if (is.null(groups)) {
    mapping <- get_param(params, 'feature_groups', NULL)
    if (is.null(mapping)) return(list())
    groups <- lapply(names(mapping), function(n) {
      value <- mapping[[n]]
      if (is.list(value) && !is.null(value$genes %||% value$features)) c(list(name = n), value) else list(name = n, genes = value)
    })
  }
  if (!is.list(groups)) return(list())
  groups
}

read_regions_file <- function(path) {
  if (!file.exists(path)) write_error_and_exit('Region annotations file not found', paste('Path:', path), 'Use an absolute path or a path relative to the current working directory/plugin.')
  read_table_auto(path)
}

resolve_regions <- function(params, xlim, ylim, threshold) {
  raw <- get_param(params, 'region_annotations', NULL)
  path <- regions_arg %||% get_param(params, 'region_annotations_file', NULL)
  if (!is.null(path) && length(path) > 0) {
    path <- as.character(path)[1]
    if (!grepl('^/', path)) {
      script_arg <- grep('^--file=', commandArgs(FALSE), value = TRUE)[1]
      script_path <- if (!is.na(script_arg)) sub('^--file=', '', script_arg) else file.path(getwd(), 'plot.R')
      plugin_dir <- dirname(normalizePath(script_path, mustWork = FALSE))
      params_dir <- dirname(normalizePath(params_file, mustWork = FALSE))
      candidates <- c(file.path(params_dir, path), file.path(getwd(), path), file.path(plugin_dir, path))
      path <- candidates[file.exists(candidates)][1] %||% candidates[1]
    }
    region_table <- read_regions_file(path)
    raw <- split(region_table, seq_len(nrow(region_table)))
  }
  context <- tolower(as.character(get_param(params, 'annotation_context', 'none'))[1])
  if (is.null(raw) && context != 'none') raw <- get_param(get_param(params, 'annotation_contexts', list()), context, NULL)
  if (is.null(raw) && as_bool(get_param(params, 'default_volcano_regions', FALSE), FALSE)) {
    raw <- list(
      list(id = 'down', label = 'Significant Downregulated', xmin = 'x_min', xmax = '-threshold', ymin = 'y_min', ymax = 0, fill = '#4C78A8'),
      list(id = 'no_change', label = 'Significant No Change', xmin = '-threshold', xmax = 'threshold', ymin = 'y_min', ymax = 'y_max', fill = '#BDBDBD'),
      list(id = 'up', label = 'Significantly Upregulated', xmin = 'threshold', xmax = 'x_max', ymin = 'y_min', ymax = 0, fill = '#E45756'),
      list(id = 'noise', label = 'Insignificant Noise Area', xmin = 'x_min', xmax = 'x_max', ymin = 0, ymax = 'y_max', fill = '#F2CF5B')
    )
  }
  if (is.null(raw) || length(raw) == 0) return(data.frame())
  if (is.data.frame(raw)) raw <- split(raw, seq_len(nrow(raw)))
  out <- lapply(seq_along(raw), function(i) {
    r <- raw[[i]]
    label <- as.character(r$label %||% r$text %||% r$id %||% paste0('region_', i))[1]
    vals <- c(xmin = resolve_coord(r$xmin, 'x', xlim, threshold), xmax = resolve_coord(r$xmax, 'x', xlim, threshold), ymin = resolve_coord(r$ymin, 'y', ylim, threshold), ymax = resolve_coord(r$ymax, 'y', ylim, threshold))
    vals[is.na(vals)] <- c(xlim[1], xlim[2], ylim[1], ylim[2])[is.na(vals)]
    data.frame(id = as.character(r$id %||% paste0('region_', i))[1], label = label, xmin = min(vals[1:2]), xmax = max(vals[1:2]), ymin = min(vals[3:4]), ymax = max(vals[3:4]), fill = as.character(r$fill %||% get_param(params, 'region_fill', '#D9D9D9'))[1], alpha = num_param(r, 'alpha', num_param(params, 'region_fill_alpha', 0.18)), border_color = as.character(r$border_color %||% r$color %||% get_param(params, 'region_border_color', NA))[1], border_width = num_param(r, 'border_width', num_param(params, 'region_border_width', 0.4)), border_linetype = as.character(r$border_linetype %||% get_param(params, 'region_border_linetype', 'solid'))[1], show = as_bool(r$show, TRUE), label_x = resolve_coord(r$label_x, 'x', xlim, threshold), label_y = resolve_coord(r$label_y, 'y', ylim, threshold), label_hjust = num_param(r, 'label_hjust', 0.5), label_vjust = num_param(r, 'label_vjust', 0.5), label_angle = num_param(r, 'label_angle', 0), stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, out)
  out$label_x[!is.finite(out$label_x)] <- (out$xmin[!is.finite(out$label_x)] + out$xmax[!is.finite(out$label_x)]) / 2
  out$label_y[!is.finite(out$label_y)] <- (out$ymin[!is.finite(out$label_y)] + out$ymax[!is.finite(out$label_y)]) / 2
  out[order(seq_len(nrow(out))), , drop = FALSE]
}

resolve_regions <- function(params, xlim, ylim, threshold) {
  raw <- get_param(params, 'region_annotations', NULL)
  path <- regions_arg %||% get_param(params, 'region_annotations_file', NULL)
  if (!is.null(path) && length(path) > 0) {
    path <- as.character(path)[1]
    if (!grepl('^/', path) || !file.exists(path)) {
      script_arg <- grep('^--file=', commandArgs(FALSE), value = TRUE)[1]
      script_path <- if (!is.na(script_arg) && nzchar(script_arg)) sub('^--file=', '', script_arg) else file.path(getwd(), 'plot.R')
      plugin_dir <- dirname(normalizePath(script_path, mustWork = FALSE))
      params_dir <- dirname(normalizePath(params_file, mustWork = FALSE))
      candidates <- unique(c(
        path,
        file.path(params_dir, path),
        file.path(getwd(), path),
        file.path(plugin_dir, path),
        file.path(plugin_dir, 'examples', 'regions', path),
        file.path(plugin_dir, 'examples', 'regions', 'input', path)
      ))
      found <- candidates[file.exists(candidates)]
      path <- if (length(found)) found[1] else candidates[1]
    }
    region_table <- read_regions_file(path)
    raw <- split(region_table, seq_len(nrow(region_table)))
  }
  if (is.null(raw) && as_bool(get_param(params, 'default_volcano_regions', FALSE), FALSE)) {
    labels <- as_string_vector(get_param(params, 'default_region_labels', c('Downregulated', 'No change', 'Upregulated', 'Noise')))
    fills <- as_string_vector(get_param(params, 'default_region_fills', c('#4C78A8', '#BDBDBD', '#E45756', '#F2CF5B')))
    ty <- -log10(num_param(params, 'qval_threshold', 0.05))
    positions <- get_param(params, 'default_region_label_positions', NULL)
    pos <- function(i, x, y) if (is.list(positions) && length(positions) >= i) positions[[i]] else list(label_x=x, label_y=y)
    raw <- list(c(list(label=labels[1],xmin='x_min',xmax='-threshold',ymin='threshold_y',ymax='y_max',fill=fills[1]), pos(1,'x_min','threshold_y')), c(list(label=labels[2],xmin='-threshold',xmax='threshold',ymin='threshold_y',ymax='y_max',fill=fills[2]), pos(2,0,'threshold_y')), c(list(label=labels[3],xmin='threshold',xmax='x_max',ymin='threshold_y',ymax='y_max',fill=fills[3]), pos(3,'x_max','threshold_y')), c(list(label=labels[4],xmin='x_min',xmax='x_max',ymin='y_min',ymax='threshold_y',fill=fills[4]), pos(4,0,'y_min')))
  }
  if (is.null(raw) || length(raw) == 0) return(data.frame())
  if (is.data.frame(raw)) raw <- split(raw, seq_len(nrow(raw)))
  ty <- -log10(num_param(params, 'qval_threshold', 0.05))
  out <- lapply(seq_along(raw), function(i) {
    r <- raw[[i]]; get <- function(n, alias = NULL) r[[n]] %||% if (!is.null(alias)) r[[alias]] else NULL
    coord <- function(v, axis) { if (is.null(v)) return(NA_real_); s <- tolower(as.character(v)[1]); if (s == 'threshold_y') return(ty); value <- resolve_coord(v, axis, if (axis == 'x') xlim else ylim, threshold); if (is.infinite(value)) value <- if (value < 0) if (axis == 'x') xlim[1] else ylim[1] else if (axis == 'x') xlim[2] else ylim[2]; value }
    x1 <- coord(get('xmin','x_min'),'x'); x2 <- coord(get('xmax','x_max'),'x'); y1 <- coord(get('ymin','y_min'),'y'); y2 <- coord(get('ymax','y_max'),'y')
    vals <- c(x1,x2,y1,y2); vals[is.na(vals)] <- c(xlim[1],xlim[2],ylim[1],ylim[2])[is.na(vals)]
    data.frame(id=as.character(get('id') %||% paste0('region_',i))[1], label=as.character(get('label') %||% get('text') %||% '')[1], xmin=min(vals[1:2]), xmax=max(vals[1:2]), ymin=min(vals[3:4]), ymax=max(vals[3:4]), fill=as.character(get('fill') %||% '#D9D9D9')[1], alpha=num_param(r,'alpha',num_param(params,'default_region_alpha',0.18)), border_color=as.character(get('border_color') %||% get('color') %||% NA)[1], border_width=num_param(r,'border_width',0.4), border_linetype=as.character(get('border_linetype') %||% 'solid')[1], show=as_bool(get('show'),TRUE), z_order=num_param(r,'z_order',i), label_x=coord(get('label_x'),'x'), label_y=coord(get('label_y'),'y'), label_color=as.character(get('label_color') %||% get_param(params,'region_label_color','black'))[1], label_size=num_param(r,'label_size',num_param(params,'region_label_size',3.5)), label_face=as.character(get('label_face') %||% get_param(params,'region_label_face','plain'))[1], label_angle=num_param(r,'label_angle',num_param(params,'region_label_angle',0)), label_hjust=num_param(r,'label_hjust',num_param(params,'region_label_hjust',0.5)), label_vjust=num_param(r,'label_vjust',num_param(params,'region_label_vjust',0.5)), stringsAsFactors=FALSE)
  })
  out <- do.call(rbind, out); out$label_x[!is.finite(out$label_x)] <- (out$xmin[!is.finite(out$label_x)] + out$xmax[!is.finite(out$label_x)])/2; out$label_y[!is.finite(out$label_y)] <- (out$ymin[!is.finite(out$label_y)] + out$ymax[!is.finite(out$label_y)])/2; out[order(out$z_order),,drop=FALSE]
}

add_region_rects <- function(p, regions, params) {
  shown <- regions[regions$show, , drop = FALSE]
  if (nrow(shown) == 0) return(p)
  p + ggplot2::geom_rect(data = shown, ggplot2::aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax), fill = shown$fill, alpha = shown$alpha, color = if (as_bool(get_param(params, 'region_border_show', TRUE), TRUE)) shown$border_color else NA, linewidth = shown$border_width, linetype = shown$border_linetype, inherit.aes = FALSE)
}

build_volcano_native <- function(df, params) {
  # Native volcano mode is intentional: the SCA function creates its layers
  # internally, which prevents reliable placement and point-level overrides.
  x <- df$pct.1 - df$pct.2
  y <- -log10(df$p_val_adj)
  y[x < 0] <- -y[x < 0]
  plot_df <- data.frame(df, x = x, y = y, stringsAsFactors = FALSE)
  de_expr <- get_param(params, 'de_expr', 'avg_log2FC > 0 & p_val_adj < 0.05')
  plot_df$DE <- tryCatch(as.logical(with(plot_df, eval(parse(text = de_expr)))), error = function(e) FALSE)
  plot_df$DE[is.na(plot_df$DE)] <- FALSE
  threshold <- num_param(params, 'threshold', 0.25)
  plot_df$de_class <- ifelse(plot_df$DE & plot_df$avg_log2FC < -threshold, 'sigDown',
    ifelse(plot_df$DE & plot_df$avg_log2FC > threshold, 'sigUp', 'Nonsig'))
  plot_df$point_color <- NA_character_
  plot_df$point_size <- num_param(params, 'pt_size', 1)
  plot_df$point_alpha <- num_param(params, 'pt_alpha', 1)
  groups <- normalize_point_groups(params)
  if (length(groups) > 0) for (g in groups) {
    hit <- plot_df$gene %in% as_string_vector(g$genes %||% g$features)
    if (any(hit)) {
      plot_df$point_color[hit] <- as.character(g$color %||% NA_character_)[1]
      plot_df$point_size[hit] <- num_param(g, 'size', 1)
      plot_df$point_alpha[hit] <- num_param(g, 'alpha', 1)
    }
  }
  palette <- get_param(params, 'palette', 'RdBu')
  palcolor <- as_string_vector(get_param_any(params, c('palcolor', 'palette_colors'), NULL))
  if (length(palcolor) == 0) palcolor <- NULL
  color_by <- get_param_any(params, c('legend', 'color_by'), 'avg_log2FC')
  plot_df$color_value <- suppressWarnings(as.numeric(plot_df[[color_by]]))
  if (!all(is.finite(plot_df$color_value))) plot_df$color_value <- plot_df$avg_log2FC
  xlim <- resolve_limits(get_param(params, 'x_limits', NULL), range(plot_df$x, finite = TRUE), 0.05)
  ylim <- resolve_limits(get_param(params, 'y_limits', NULL), range(plot_df$y, finite = TRUE), 0.05)
  p <- ggplot2::ggplot(plot_df, ggplot2::aes(x = x, y = y))
  regions <- resolve_regions(params, xlim, ylim, threshold)
  region_enabled <- as_bool(get_param(params, 'region_show', length(regions) > 0), length(regions) > 0)
  if (region_enabled && nrow(regions) > 0 && get_param(params, 'annotation_layer', 'background') %in% c('background', 'midground'))
    p <- add_region_rects(p, regions, params)
  base <- plot_df[is.na(plot_df$point_color), , drop = FALSE]
  if (nrow(base) > 0) p <- p + ggplot2::geom_point(data = base, ggplot2::aes(color = color_value, alpha = point_alpha, size = point_size))
  classes <- split(plot_df[!is.na(plot_df$point_color), , drop = FALSE], plot_df$point_color[!is.na(plot_df$point_color)])
  if (length(classes) > 0) for (cc in names(classes)) p <- p + ggplot2::geom_point(data = classes[[cc]], color = cc, ggplot2::aes(alpha = point_alpha, size = point_size))
  p <- p + ggplot2::scale_color_gradientn(name = color_by, colors = palette_scp(palette = palette, palcolor = palcolor))
  p <- p + ggplot2::scale_alpha_identity() + ggplot2::scale_size_identity()
  if (as_bool(get_param(params, 'threshold_line_show', TRUE), TRUE)) {
    line_col <- get_param(params, 'threshold_line_color', 'grey')
    line_width <- num_param(params, 'threshold_line_width', 0.4)
    line_type <- get_param(params, 'threshold_line_type', 'dashed')
    p <- p + ggplot2::geom_hline(yintercept = 0, color = line_col, linewidth = line_width, linetype = line_type) +
      ggplot2::geom_vline(xintercept = 0, color = line_col, linewidth = line_width, linetype = line_type)
  }
  p <- p + ggplot2::labs(x = get_param(params, 'xlab', 'diff.pct'), y = get_param(params, 'ylab', '-log10(p-adjust)'))
  if (as_bool(get_param(params, 'region_label_show', length(regions) > 0), length(regions) > 0) && nrow(regions) > 0) {
    region_labels <- regions[regions$show, , drop = FALSE]
    p <- p + ggplot2::geom_text(data = region_labels, ggplot2::aes(x = label_x, y = label_y, label = label, hjust = label_hjust, vjust = label_vjust, angle = label_angle), inherit.aes = FALSE, size = num_param(params, 'region_label_size', 3.5), color = get_param(params, 'region_label_color', 'black'), fontface = get_param(params, 'region_label_face', 'plain'), alpha = num_param(params, 'region_label_alpha', 1))
  }
  features_label <- as_string_vector(get_param_any(params, c('features_label', 'features.label', 'features_to_label'), NULL))
  labels <- plot_df[plot_df$gene %in% features_label, , drop = FALSE]
  if (nrow(labels) > 0) p <- p + ggrepel::geom_text_repel(data = labels, ggplot2::aes(label = gene), color = get_param(params, 'label_fg', 'black'), size = num_param(params, 'label_size', 4), max.overlaps = 100)
  if (as_bool(get_param(params, 'point_group_labels', TRUE), TRUE) && length(groups) > 0) for (g in groups) {
    group_label <- g$label %||% NULL
    if (!is.null(group_label) && !identical(tolower(as.character(group_label)[1]), 'false')) {
      hit <- plot_df[plot_df$gene %in% as_string_vector(g$genes %||% g$features), , drop = FALSE]
      if (nrow(hit) > 0) p <- p + ggplot2::annotate('text', x = num_param(g, 'label_x', mean(hit$x)), y = num_param(g, 'label_y', mean(hit$y)), label = as.character(group_label)[1], color = as.character(g$label_color %||% g$color %||% 'black')[1], size = num_param(g, 'label_size', 3.5), hjust = num_param(g, 'label_hjust', 0.5), vjust = num_param(g, 'label_vjust', 0.5), angle = num_param(g, 'label_angle', 0))
    }
  }
  if (!is.null(get_param(params, 'title', NULL)) && as_bool(get_param(params, 'title_show', TRUE), TRUE)) p <- p + ggplot2::ggtitle(get_param(params, 'title', NULL))
  if (region_enabled && nrow(regions) > 0 && get_param(params, 'annotation_layer', 'background') == 'foreground') p <- add_region_rects(p, regions, params)
  p <- p + ggplot2::coord_cartesian(xlim = xlim, ylim = ylim, clip = if (as_bool(get_param(params, 'region_clip', TRUE), TRUE)) 'on' else 'off')
  p <- p + ggplot2::theme_classic(base_size = num_param(params, 'base_size', 12)) + ggplot2::theme(panel.grid = if (as_bool(get_param(params, 'grid_show', FALSE), FALSE)) ggplot2::element_line(color = get_param(params, 'grid_color', 'grey90'), linetype = get_param(params, 'grid_linetype', 'solid')) else ggplot2::element_blank(), panel.background = ggplot2::element_rect(fill = get_param(params, 'panel_background', 'white'), color = NA), plot.background = ggplot2::element_rect(fill = get_param(params, 'plot_background', 'white'), color = NA), axis.line = ggplot2::element_line(color = get_param(params, 'axis_line_color', 'black'), linewidth = num_param(params, 'axis_line_width', 0.4)))
  attr(p, 'region_metadata') <- regions
  attr(p, 'point_group_metadata') <- groups
  attr(p, 'axis_metadata') <- list(x_limits = xlim, y_limits = ylim)
  p
}

build_volcano <- function(df, params) {
  params2 <- params
  params2$region_label_show <- FALSE
  params2$annotation_layer <- if (get_param(params, 'region_layer', 'background') == 'foreground') 'foreground' else 'background'
  p <- build_volcano_native(df, params2)
  xlim <- attr(p, 'axis_metadata')$x_limits
  ylim <- attr(p, 'axis_metadata')$y_limits
  p <- p + ggplot2::scale_x_continuous(breaks = as_numeric_vector(get_param(params, 'x_breaks', NULL))) + ggplot2::scale_y_continuous(breaks = as_numeric_vector(get_param(params, 'y_breaks', NULL)), labels = abs)
  regions <- attr(p, 'region_metadata')
  if (as_bool(get_param(params, 'region_label_show', nrow(regions) > 0), nrow(regions) > 0) && nrow(regions) > 0) {
    shown <- regions[regions$show, , drop = FALSE]
    for (i in seq_len(nrow(shown))) p <- p + ggplot2::annotate('text', x = shown$label_x[i], y = shown$label_y[i], label = shown$label[i], color = shown$label_color[i], size = shown$label_size[i], angle = shown$label_angle[i], hjust = shown$label_hjust[i], vjust = shown$label_vjust[i], fontface = shown$label_face[i])
  }
  if (as_bool(get_param(params, 'region_show', FALSE), FALSE) && identical(get_param(params, 'region_layer', 'background'), 'foreground')) p <- p + add_region_rects(p, regions, params)
  p
}

build_avg_volcano <- function(df, params) {
  cluster_col <- attr(df, 'cluster_col')
  features_label <- as_string_vector(get_param_any(params, c('features_label', 'features.label', 'features_to_label'), NULL))
  if (length(features_label) == 0) features_label <- NULL
  de_colors <- as_named_vector(get_param_any(params, c('de_colors', 'DEcolor', 'labelCol'), NULL), default = NULL)
  if (is.null(de_colors)) de_colors <- c(sigDown = '#0099CC', sigUp = '#CC3333', Nonsig = 'grey53')
  cluster_order <- as_string_vector(get_param_any(params, c('cluster_order', 'clusterOrder'), NULL))
  if (length(cluster_order) == 0) cluster_order <- NULL
  highlight_n <- as.integer(num_param(params, 'highlight_n', 5))
  keep_all <- as_bool(get_param(params, 'keep_all', TRUE), TRUE)
  qval_threshold <- num_param(params, 'qval_threshold', 0.05)
  threshold <- num_param(params, 'threshold', 0.25)
  rank_by <- get_param(params, 'rank_by', 'Ranking = abs(pct.1 - pct.2) * abs(avg_log2FC)')
  title <- get_param(params, 'title', NULL)
  base_size <- num_param(params, 'base_size', 14)
  pt_size <- num_param(params, 'pt_size', 1.5)

  p <- avgVolcano(
    markers.seu = df,
    highlightN = highlight_n,
    features = features_label,
    clusterOrder = cluster_order,
    DEcolor = de_colors,
    geneCol = 'gene',
    qvalcol = 'p_val_adj',
    qval.thres = qval_threshold,
    keep.all = keep_all,
    cluster.key = cluster_col,
    title = title,
    threshold = threshold,
    rank.by = rank_by,
    shift = c(0.1, 0.01),
    psize = pt_size,
    base_size = base_size
  )
  p
}

build_percent_volcano <- function(df, params) {
  cluster_col <- attr(df, 'cluster_col')
  features_label <- as_string_vector(get_param_any(params, c('features_label', 'features.label', 'features_to_label'), NULL))
  if (length(features_label) == 0) features_label <- NULL
  de_colors <- as_named_vector(get_param_any(params, c('de_colors', 'labelCol', 'DEcolor'), NULL), default = NULL)
  highlight_n <- as.integer(num_param(params, 'highlight_n', 5))
  threshold <- num_param(params, 'threshold', 0.25)
  hline_size <- num_param(params, 'hline_size', 1)
  hline_color <- get_param(params, 'hline_color', 'grey50')
  pforce <- num_param(params, 'pforce', 5)
  nforce <- num_param(params, 'nforce', 2.5)
  nudge_x <- num_param(params, 'nudge_x', 0.8)
  pnudge_y <- num_param(params, 'pnudge_y', 0.25)
  nnudge_y <- num_param(params, 'nnudge_y', 0)
  base_size <- num_param(params, 'base_size', 14)
  facet_color <- get_param(params, 'facet_color', NA)
  facet_fill <- get_param(params, 'facet_fill', 'white')
  ylab <- get_param(params, 'ylab', 'Log2-Fold Change')
  nrow <- as.integer(num_param(params, 'nrow', 1))
  title <- get_param(params, 'title', NULL)

  p <- percentVocalno(
    markers.seu = df,
    features = features_label,
    highlightN = highlight_n,
    log2FC = threshold,
    labelCol = de_colors,
    hlineSize = hline_size,
    hlineColor = hline_color,
    cluster.key = cluster_col,
    pforce = pforce,
    nforce = nforce,
    nudge_x = nudge_x,
    pnudge_y = pnudge_y,
    nnudge_y = nnudge_y,
    base_size = base_size,
    facetColor = facet_color,
    facetFill = facet_fill,
    ylab = ylab,
    nrow = nrow,
    title = title
  )
  p
}

# ---------------------------------------------------------------------------
# Output helpers
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
  draw_with_retry(function(w, h) (if (requireNamespace('ragg', quietly = TRUE)) ragg::agg_png else function(...) grDevices::png(..., type = 'cairo'))(file.path(output_dir, 'result.png'), width = w, height = h, units = 'in', res = dpi))
}

export_selected_points <- function(df, params, output_dir) {
  selected_genes <- as_string_vector(get_param_any(params, c('selected_genes', 'selected_points', 'features_label', 'features.label'), NULL))
  if (length(selected_genes) == 0) return(invisible(NULL))
  hits <- df[df$gene %in% selected_genes, , drop = FALSE]
  if (nrow(hits) == 0) return(invisible(NULL))
  out <- hits[, intersect(c('gene', 'cluster', 'avg_log2FC', 'p_val_adj', 'pct.1', 'pct.2'), colnames(hits))]
  utils::write.csv(out, file.path(output_dir, 'selected_points.csv'), row.names = FALSE)
  invisible(nrow(out))
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main <- function() {
  if (is.null(input_file)) write_error_and_exit('Missing --input argument')
  if (is.null(params_file) || !file.exists(params_file)) write_error_and_exit('Params file not found', paste('Params path:', params_file), 'Provide params.json.')
  if (is.null(output_dir)) write_error_and_exit('Missing --output argument')
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  old_outputs <- file.path(output_dir, c('error.json', 'result.svg', 'result.pdf', 'result.png', 'result.html', 'figure.json', 'selected_points.csv', 'run.log'))
  old_outputs <- old_outputs[file.exists(old_outputs)]
  if (length(old_outputs) > 0) unlink(old_outputs)
  write_log('Starting sca_volcano_plot plugin.')

  params <- jsonlite::fromJSON(params_file, simplifyVector = FALSE)
  plot_kind <- tolower(as.character(get_param_any(params, c('plot_kind', 'plot_type'), 'volcano'))[1])
  if (!plot_kind %in% c('volcano', 'avg_volcano', 'percent_volcano')) {
    write_error_and_exit('Unsupported plot_kind', paste('plot_kind:', plot_kind), 'Supported: volcano, avg_volcano, percent_volcano.')
  }
  write_log(paste('plot_kind =', plot_kind))

  load_sca_volcano_reference()
  raw <- read_table_auto(input_file)
  df <- prepare_markers(raw, params)
  write_log(paste('Marker rows:', nrow(df), '| clusters:', length(unique(df$cluster))))

  p <- tryCatch({
    if (plot_kind == 'volcano') build_volcano(df, params)
    else if (plot_kind == 'avg_volcano') build_avg_volcano(df, params)
    else build_percent_volcano(df, params)
  }, error = function(e) e)
  if (inherits(p, 'error')) {
    write_error_and_exit(paste0(plot_kind, ' plot failed'), conditionMessage(p), 'Check marker columns and params.json values.')
  }

  width <- num_param(params, 'width', if (plot_kind == 'percent_volcano') 10 else 8)
  height <- num_param(params, 'height', if (plot_kind == 'avg_volcano') 6 else 5.5)
  dpi <- as.numeric(get_param(params, 'dpi', 300))
  # Generic appearance parameters not handled by this plugin (R/runtime/omicscanvas_theme.R).
  if (!exists('omicscanvas_apply_theme')) { .oc_f <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[1]); .oc_rt <- file.path(dirname(normalizePath(.oc_f, mustWork = FALSE)), '..', '..', 'R', 'runtime', 'omicscanvas_theme.R'); if (!file.exists(.oc_rt)) .oc_rt <- file.path('R', 'runtime', 'omicscanvas_theme.R'); sys.source(.oc_rt, envir = globalenv()) }; p <- omicscanvas_apply_theme(p, params, only = c('aspect_ratio', 'axis_label_size', 'font_family', 'font_size', 'legend_direction', 'legend_position', 'legend_text_size', 'legend_title_size', 'title_size', 'x_axis_text_angle', 'x_axis_text_size'))
  save_plot(p, output_dir, width, height, dpi)
  write_log('Saved result.svg/pdf/png.')
  html_meta <- list(plugin = 'sca_volcano_plot', plot_kind = plot_kind,
                    region_annotations = attr(p, 'region_metadata') %||% list(),
                    point_groups = attr(p, 'point_group_metadata') %||% list(),
                    axes = attr(p, 'axis_metadata') %||% list())
  writeLines(c('<!doctype html><meta charset="utf-8"><title>SCA Volcano Plot</title>', '<h1>SCA Volcano Plot</h1><p>Static output: <a href="result.svg">result.svg</a></p>', '<pre id="metadata"></pre>', sprintf('<script>document.getElementById("metadata").textContent=%s</script>', jsonlite::toJSON(html_meta, auto_unbox = TRUE, pretty = TRUE))), file.path(output_dir, 'result.html'))

  export_selected_points(df, params, output_dir)

  figure <- list(
    plugin = 'sca_volcano_plot',
    source_engine = 'SCA::VocalnoPlot.R',
    plot_kind = plot_kind,
    input_file = normalizePath(input_file, mustWork = FALSE),
    n_genes = nrow(df),
    n_clusters = length(unique(df$cluster)),
    de_expr = get_param(params, 'de_expr', 'avg_log2FC > 0 & p_val_adj < 0.05'),
    threshold = num_param(params, 'threshold', 0.25),
    qval_threshold = num_param(params, 'qval_threshold', 0.05),
    highlight_n = as.integer(num_param(params, 'highlight_n', 5)),
    outputs = c('result.svg', 'result.pdf', 'result.png', 'result.html', 'figure.json', 'run.log')
  )
  if (plot_kind == 'volcano') {
    figure$region_annotations <- attr(p, 'region_metadata') %||% list()
    figure$point_groups <- attr(p, 'point_group_metadata') %||% list()
    figure$axis_limits <- attr(p, 'axis_metadata') %||% list()
    figure$precedence <- 'point group > DE class > nonsig'
  }
  if (file.exists(file.path(output_dir, 'selected_points.csv'))) figure$outputs <- c(figure$outputs, 'selected_points.csv')
  writeLines(jsonlite::toJSON(figure, auto_unbox = TRUE, pretty = TRUE), file.path(output_dir, 'figure.json'))
  write_log('Completed sca_volcano_plot plugin.')
}

tryCatch(main(), error = function(e) {
  write_error_and_exit('Unhandled plugin error', conditionMessage(e), 'Inspect run.log and params.json.')
})
