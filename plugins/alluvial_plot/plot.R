#!/usr/bin/env Rscript

# BioFigureAI Plot Plugin: Alluvial / Multi-Stage Flow
# ------------------------------------------------------------
# Highly customizable multi-stage alluvial chart (冲积图 / ggsankey).
# Matches publication-style clone / lineage tracking figures with
# vertical strata bars and flowing ribbons between stages.
#
# Runtime:
#   Rscript plot.R --input input.csv --params params.json --output output_dir
#
# Input modes (auto-detected):
#   wide  - id + stage columns (category labels) + optional weight
#   long  - id, stage, node [, weight]
#   edges - source, target, value [, source_stage, target_stage]

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
})

option_list <- list(
  make_option(c('--input'), type = 'character', default = NULL,
              help = 'CSV/TSV table (wide stages, long alluvia, or edge list).'),
  make_option(c('--params'), type = 'character', default = NULL,
              help = 'Path to params.json.'),
  make_option(c('--output'), type = 'character', default = NULL,
              help = 'Output directory.')
)

opt <- parse_args(OptionParser(option_list = option_list))
input_file <- opt$input
params_file <- opt$params
output_dir <- opt$output

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) return(y)
  if (length(x) == 1 && is.na(x)) return(y)
  x
}

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

write_log <- function(message) {
  log_file <- file.path(output_dir, 'run.log')
  timestamp <- format(Sys.time(), '%Y-%m-%d %H:%M:%S')
  cat(sprintf('[%s] %s\n', timestamp, message), file = log_file, append = TRUE)
}

write_error_and_exit <- function(error, detail = NULL, suggestion = NULL, status = 1) {
  if (is.null(output_dir) || !nzchar(as.character(output_dir %||% ''))) output_dir <<- getwd()
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  error_obj <- list(
    error = error,
    detail = as.character(detail %||% ''),
    suggestion = as.character(suggestion %||% '')
  )
  writeLines(jsonlite::toJSON(error_obj, auto_unbox = TRUE, pretty = TRUE),
             file.path(output_dir, 'error.json'))
  message(error)
  quit(status = status)
}

read_table_auto <- function(path) {
  if (is.null(path) || !file.exists(path)) {
    write_error_and_exit('Input file not found', paste('Input path:', path),
                         'Provide a valid csv, tsv, or txt file.')
  }
  ext <- tolower(tools::file_ext(path))
  if (ext == 'csv') return(read.csv(path, check.names = FALSE, stringsAsFactors = FALSE))
  if (ext %in% c('tsv', 'txt')) return(read.delim(path, check.names = FALSE, stringsAsFactors = FALSE))
  df <- tryCatch(read.csv(path, check.names = FALSE, stringsAsFactors = FALSE), error = function(e) NULL)
  if (is.null(df)) df <- read.delim(path, check.names = FALSE, stringsAsFactors = FALSE)
  df
}

get_param <- function(params, name, default = NULL) {
  if (!is.null(params[[name]])) return(params[[name]])
  default
}

as_chr_vec <- function(x) {
  if (is.null(x)) return(character())
  out <- trimws(as.character(unlist(x, use.names = FALSE)))
  out[nzchar(out) & !is.na(out)]
}

as_num <- function(x, default = NA_real_) {
  z <- suppressWarnings(as.numeric(x %||% default)[1])
  if (is.na(z)) default else z
}

as_bool <- function(x, default = FALSE) {
  if (is.null(x)) return(default)
  if (is.logical(x)) return(isTRUE(x[1]))
  tolower(as.character(x[1])) %in% c('true', '1', 'yes', 'on', 't')
}

named_chr <- function(x) {
  if (is.null(x)) return(character())
  if (is.atomic(x) && !is.null(names(x))) return(setNames(as.character(x), names(x)))
  if (is.list(x)) {
    nms <- names(x)
    if (is.null(nms)) return(character())
    return(setNames(vapply(x, function(z) as.character(z %||% '')[1], character(1)), nms))
  }
  character()
}

sci_palette <- function(n, name = 'npg') {
  pals <- list(
    npg = c('#E64B35', '#4DBBD5', '#00A087', '#3C5488', '#F39B7F', '#8491B4', '#91D1C2', '#DC0000', '#7E6148', '#B09C85'),
    aaas = c('#3B4992', '#EE0000', '#008B45', '#631879', '#008280', '#BB0021', '#5F559B', '#A20056', '#808180', '#1B1919'),
    nejm = c('#BC3C29', '#0072B5', '#E18727', '#20854E', '#7876B1', '#6F99AD', '#FFDC91', '#EE4C97'),
    lancet = c('#00468B', '#ED0000', '#42B540', '#0099B4', '#925E9F', '#FDAF91', '#AD002A', '#ADB6B6'),
    jco = c('#0073C2', '#EFC000', '#868686', '#CD534C', '#7AA6DC', '#003C67', '#8F7700', '#A73030'),
    pastel = c('#8DD3C7', '#FFFFB3', '#BEBADA', '#FB8072', '#80B1D3', '#FDB462', '#B3DE69', '#FCCDE5', '#D9D9D9', '#BC80BD'),
    soft = c('#A8D5E5', '#6BAED6', '#74C476', '#A1D99B', '#FDBB84', '#FDAE6B', '#FC9272', '#DE2D26', '#9E9AC8', '#C7B3D9')
  )
  base <- pals[[tolower(name %||% 'npg')]] %||% pals$npg
  if (n <= length(base)) return(base[seq_len(n)])
  grDevices::colorRampPalette(base)(n)
}

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------

tryCatch({
  if (is.null(output_dir) || !nzchar(output_dir)) {
    write_error_and_exit('Missing --output', 'Output directory is required.')
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  if (file.exists(file.path(output_dir, 'error.json'))) unlink(file.path(output_dir, 'error.json'))
  write_log('Starting alluvial_plot')

  if (is.null(params_file) || !file.exists(params_file)) {
    write_error_and_exit('Missing params.json', paste('params path:', params_file))
  }
  params <- jsonlite::fromJSON(params_file, simplifyVector = FALSE)

  if (!requireNamespace('ggsankey', quietly = TRUE)) {
    write_error_and_exit(
      'Package ggsankey is required',
      'install.packages("ggsankey") or remotes::install_github("davidsjoberg/ggsankey")',
      'Install ggsankey then re-run.'
    )
  }
  suppressPackageStartupMessages(library(ggsankey))

  raw <- read_table_auto(input_file)
  write_log(sprintf('Loaded input: %d rows × %d cols', nrow(raw), ncol(raw)))

  # ---- detect mode ----
  mode <- tolower(as.character(get_param(params, 'input_mode', 'auto') %||% 'auto')[1])
  cols <- names(raw)
  id_col <- as.character(get_param(params, 'id_column', 'id') %||% 'id')[1]
  stage_col <- as.character(get_param(params, 'stage_column', 'stage') %||% 'stage')[1]
  node_col <- as.character(get_param(params, 'node_column', 'node') %||% 'node')[1]
  weight_col <- as.character(get_param(params, 'weight_column', 'weight') %||% 'weight')[1]
  source_col <- as.character(get_param(params, 'source_column', 'source') %||% 'source')[1]
  target_col <- as.character(get_param(params, 'target_column', 'target') %||% 'target')[1]
  value_col <- as.character(get_param(params, 'value_column', 'value') %||% 'value')[1]

  stage_columns <- as_chr_vec(get_param(params, 'stage_columns', NULL))
  if (!length(stage_columns)) {
    # heuristic: non-id, non-weight columns that look like stages
    skip <- unique(c(id_col, weight_col, 'weight', 'count', 'n', 'freq', 'value'))
    stage_columns <- setdiff(cols, skip)
  }

  if (mode == 'auto') {
    if (source_col %in% cols && target_col %in% cols) {
      mode <- 'edges'
    } else if (stage_col %in% cols && node_col %in% cols) {
      mode <- 'long'
    } else {
      mode <- 'wide'
    }
  }
  write_log(sprintf('Input mode: %s', mode))

  # ---- build long alluvia: id, stage, node, weight ----
  long_df <- NULL

  if (mode == 'wide') {
    if (!length(stage_columns) || !all(stage_columns %in% cols)) {
      # auto-pick character/factor columns excluding id/weight
      skip <- unique(c(id_col, weight_col, 'weight', 'count', 'n', 'freq', 'value'))
      stage_columns <- setdiff(cols, skip)
      stage_columns <- stage_columns[vapply(stage_columns, function(cn) {
        is.character(raw[[cn]]) || is.factor(raw[[cn]]) || is.logical(raw[[cn]])
      }, logical(1))]
    }
    if (length(stage_columns) < 2) {
      write_error_and_exit(
        'Need at least 2 stage columns for wide mode',
        paste('Available columns:', paste(cols, collapse = ', ')),
        'Set stage_columns to sequential categorical columns (e.g. stage1, stage2, stage3).'
      )
    }
    if (!id_col %in% cols) {
      raw$.id <- paste0('row', seq_len(nrow(raw)))
      id_col <- '.id'
    }
    w <- if (weight_col %in% cols) as.numeric(raw[[weight_col]]) else rep(1, nrow(raw))
    w[!is.finite(w) | w <= 0] <- 1
    pieces <- lapply(seq_along(stage_columns), function(i) {
      data.frame(
        id = as.character(raw[[id_col]]),
        stage = stage_columns[i],
        node = as.character(raw[[stage_columns[i]]]),
        weight = w,
        stringsAsFactors = FALSE
      )
    })
    long_df <- do.call(rbind, pieces)

  } else if (mode == 'long') {
    need <- c(stage_col, node_col)
    if (!all(need %in% cols)) {
      write_error_and_exit(
        'Missing long-format columns',
        paste('Need:', paste(need, collapse = ', '), '; have:', paste(cols, collapse = ', ')),
        'Provide stage_column and node_column (and optional id_column, weight_column).'
      )
    }
    if (!id_col %in% cols) {
      # fabricate id by grouping sequential stage blocks is hard; use row groups via interaction of path if possible
      # if weight is present, treat each row independently with synthetic id
      raw$.id <- paste0('row', seq_len(nrow(raw)))
      id_col <- '.id'
    }
    w <- if (weight_col %in% cols) as.numeric(raw[[weight_col]]) else rep(1, nrow(raw))
    w[!is.finite(w) | w <= 0] <- 1
    long_df <- data.frame(
      id = as.character(raw[[id_col]]),
      stage = as.character(raw[[stage_col]]),
      node = as.character(raw[[node_col]]),
      weight = w,
      stringsAsFactors = FALSE
    )

  } else if (mode == 'edges') {
    need <- c(source_col, target_col)
    if (!all(need %in% cols)) {
      write_error_and_exit(
        'Missing edge-list columns',
        paste('Need:', paste(need, collapse = ', ')),
        'Provide source_column, target_column, and optional value_column.'
      )
    }
    val <- if (value_col %in% cols) as.numeric(raw[[value_col]]) else rep(1, nrow(raw))
    val[!is.finite(val) | val <= 0] <- 1
    # Two-stage alluvial: each edge is an independent path (source → target).
    # Optional source_stage/target_stage are used only for axis labels when uniform.
    ss_col <- as.character(get_param(params, 'source_stage_column', 'source_stage') %||% 'source_stage')[1]
    ts_col <- as.character(get_param(params, 'target_stage_column', 'target_stage') %||% 'target_stage')[1]
    ss <- if (ss_col %in% cols) as.character(raw[[ss_col]]) else rep('Source', nrow(raw))
    ts <- if (ts_col %in% cols) as.character(raw[[ts_col]]) else rep('Target', nrow(raw))
    # Collapse heterogeneous stage pairs into ordered left/right axes so reshape stays complete
    left_lab <- if (length(unique(ss)) == 1) unique(ss)[1] else 'Source'
    right_lab <- if (length(unique(ts)) == 1) unique(ts)[1] else 'Target'
    if (identical(left_lab, right_lab)) {
      left_lab <- paste0(left_lab, '_from')
      right_lab <- paste0(right_lab, '_to')
    }
    long_df <- rbind(
      data.frame(
        id = paste0('e', seq_len(nrow(raw))),
        stage = left_lab,
        node = as.character(raw[[source_col]]),
        weight = val,
        stringsAsFactors = FALSE
      ),
      data.frame(
        id = paste0('e', seq_len(nrow(raw))),
        stage = right_lab,
        node = as.character(raw[[target_col]]),
        weight = val,
        stringsAsFactors = FALSE
      )
    )
  } else {
    write_error_and_exit('Unsupported input_mode', mode, 'Use auto, wide, long, or edges.')
  }

  long_df <- long_df[!is.na(long_df$node) & nzchar(long_df$node) & !is.na(long_df$stage) & nzchar(long_df$stage), , drop = FALSE]
  if (!nrow(long_df)) {
    write_error_and_exit('No alluvia remaining after filtering', 'All rows were empty or invalid.')
  }

  # filters
  nodes_include <- as_chr_vec(get_param(params, 'nodes_include', NULL))
  nodes_exclude <- as_chr_vec(get_param(params, 'nodes_exclude', NULL))
  stages_include <- as_chr_vec(get_param(params, 'stages_include', NULL))
  stages_exclude <- as_chr_vec(get_param(params, 'stages_exclude', NULL))
  ids_include <- as_chr_vec(get_param(params, 'ids_include', NULL))
  ids_exclude <- as_chr_vec(get_param(params, 'ids_exclude', NULL))

  if (length(nodes_include)) long_df <- long_df[long_df$node %in% nodes_include, , drop = FALSE]
  if (length(nodes_exclude)) long_df <- long_df[!long_df$node %in% nodes_exclude, , drop = FALSE]
  if (length(stages_include)) long_df <- long_df[long_df$stage %in% stages_include, , drop = FALSE]
  if (length(stages_exclude)) long_df <- long_df[!long_df$stage %in% stages_exclude, , drop = FALSE]
  if (length(ids_include)) long_df <- long_df[long_df$id %in% ids_include, , drop = FALSE]
  if (length(ids_exclude)) long_df <- long_df[!long_df$id %in% ids_exclude, , drop = FALSE]

  # drop incomplete paths (need ≥2 stages per id)
  keep_ids <- names(which(tapply(long_df$stage, long_df$id, function(z) length(unique(z)) >= 2)))
  long_df <- long_df[long_df$id %in% keep_ids, , drop = FALSE]
  if (!nrow(long_df)) {
    write_error_and_exit(
      'No complete multi-stage paths',
      'Each alluvium id must appear in at least two stages.',
      'Check stage columns / long format completeness.'
    )
  }

  # stage order
  stage_order <- as_chr_vec(get_param(params, 'stage_order', NULL))
  stages_present <- unique(long_df$stage)
  if (length(stage_order)) {
    stages_present <- c(stage_order[stage_order %in% stages_present], setdiff(stages_present, stage_order))
  } else if (mode == 'wide' && length(stage_columns)) {
    stages_present <- stage_columns[stage_columns %in% stages_present]
  } else {
    # try natural order
    stages_present <- unique(long_df$stage)
  }
  long_df$stage <- factor(long_df$stage, levels = stages_present)

  # node order within strata
  node_order <- as_chr_vec(get_param(params, 'node_order', NULL))
  reverse_nodes <- as_bool(get_param(params, 'reverse_nodes', FALSE), FALSE)
  nodes_all <- unique(long_df$node)
  if (length(node_order)) {
    nodes_all <- c(node_order[node_order %in% nodes_all], setdiff(nodes_all, node_order))
  } else {
    # order by total weight desc for nicer stacking
    wt <- tapply(long_df$weight, long_df$node, sum)
    nodes_all <- names(sort(wt, decreasing = TRUE))
  }
  if (reverse_nodes) nodes_all <- rev(nodes_all)
  long_df$node <- factor(long_df$node, levels = nodes_all)

  # expand to one row per unit weight for count-based make_long, or use value
  # ggsankey::make_long works on wide factor columns; convert long → wide path matrix
  # Aggregate identical paths first
  path_key <- interaction(long_df$id, drop = TRUE)
  # Build wide path table with weight
  wide_paths <- reshape(
    long_df[, c('id', 'stage', 'node', 'weight')],
    idvar = 'id', timevar = 'stage', direction = 'wide'
  )
  # reshape renames to node.stage
  node_cols <- grep('^node\\.', names(wide_paths), value = TRUE)
  # weight: take first non-NA weight per id
  wcol <- grep('^weight\\.', names(wide_paths), value = TRUE)
  if (length(wcol)) {
    wide_paths$weight <- apply(wide_paths[wcol], 1, function(r) {
      z <- suppressWarnings(as.numeric(r))
      z <- z[is.finite(z)]
      if (!length(z)) 1 else z[1]
    })
  } else {
    wide_paths$weight <- 1
  }
  # rename node.stageX → stage level names
  stage_from_col <- sub('^node\\.', '', node_cols)
  names(wide_paths)[match(node_cols, names(wide_paths))] <- stage_from_col
  stage_cols_use <- stages_present[stages_present %in% names(wide_paths)]
  if (length(stage_cols_use) < 2) {
    write_error_and_exit('Could not reshape to multi-stage wide paths', paste(names(wide_paths), collapse = ', '))
  }

  # drop rows with any NA stages among used stages
  ok <- complete.cases(wide_paths[, stage_cols_use, drop = FALSE])
  wide_paths <- wide_paths[ok, , drop = FALSE]
  if (!nrow(wide_paths)) {
    write_error_and_exit('No complete paths after reshaping', 'Some ids lack labels in every selected stage.')
  }

  # Expand by weight (integer weights) for make_long, or pass value=
  # Prefer value= for performance
  sankey_df <- tryCatch({
    do.call(ggsankey::make_long, c(list(.df = wide_paths, value = wide_paths$weight), as.list(stage_cols_use)))
  }, error = function(e) {
    # fallback: expand rows
    nrep <- pmax(1L, as.integer(round(wide_paths$weight)))
    exp_idx <- rep(seq_len(nrow(wide_paths)), nrep)
    exp_df <- wide_paths[exp_idx, stage_cols_use, drop = FALSE]
    do.call(ggsankey::make_long, c(list(.df = exp_df), as.list(stage_cols_use)))
  })

  # fill aesthetic
  fill_by <- tolower(as.character(get_param(params, 'fill_by', 'node') %||% 'node')[1])
  # node | first | last | alluvium
  if (fill_by == 'first') {
    first_map <- setNames(as.character(wide_paths[[stage_cols_use[1]]]), as.character(wide_paths$id))
    # sankey_df has no id; use node as fill (ggsankey default)
    sankey_df$fill_key <- sankey_df$node
  } else if (fill_by == 'last') {
    sankey_df$fill_key <- sankey_df$node
  } else {
    sankey_df$fill_key <- sankey_df$node
  }

  # colors
  palette_name <- as.character(get_param(params, 'palette', 'npg') %||% 'npg')[1]
  node_colors <- named_chr(get_param(params, 'node_colors', NULL))
  levels_fill <- levels(factor(sankey_df$fill_key))
  if (!length(levels_fill)) levels_fill <- unique(as.character(sankey_df$fill_key))
  cols_map <- sci_palette(length(levels_fill), palette_name)
  names(cols_map) <- levels_fill
  if (length(node_colors)) {
    for (nm in names(node_colors)) {
      if (nm %in% names(cols_map) && nzchar(node_colors[[nm]])) cols_map[[nm]] <- node_colors[[nm]]
    }
  }
  single_fill <- as.character(get_param(params, 'flow_color', '') %||% '')[1]
  if (nzchar(single_fill)) {
    cols_map[] <- single_fill
  }

  # geometry params
  flow_alpha <- as_num(get_param(params, 'flow_alpha', 0.55), 0.55)
  flow_smooth <- as_num(get_param(params, 'flow_smooth', 8), 8)
  stratum_width <- as_num(get_param(params, 'stratum_width', 0.12), 0.12)
  stratum_alpha <- as_num(get_param(params, 'stratum_alpha', 1), 1)
  stratum_border_color <- as.character(get_param(params, 'stratum_border_color', '#333333') %||% '#333333')[1]
  stratum_border_width <- as_num(get_param(params, 'stratum_border_width', 0.4), 0.4)
  space <- as_num(get_param(params, 'node_space', NULL), NULL)
  type_geom <- tolower(as.character(get_param(params, 'flow_type', 'sankey') %||% 'sankey')[1])
  if (!type_geom %in% c('sankey', 'alluvial')) type_geom <- 'sankey'

  # labels
  label_show <- as_bool(get_param(params, 'label_show', TRUE), TRUE)
  label_size <- as_num(get_param(params, 'label_size', 3.2), 3.2)
  label_color <- as.character(get_param(params, 'label_color', '#222222') %||% '#222222')[1]
  label_face <- as.character(get_param(params, 'label_face', 'plain') %||% 'plain')[1]
  label_fill <- as.character(get_param(params, 'label_fill', 'white') %||% 'white')[1]
  label_fill_alpha <- as_num(get_param(params, 'label_fill_alpha', 0.65), 0.65)
  label_angle <- as_num(get_param(params, 'label_angle', 0), 0)

  # stage axis
  stage_label_show <- as_bool(get_param(params, 'stage_label_show', TRUE), TRUE)
  stage_label_size <- as_num(get_param(params, 'stage_label_size', 11), 11)
  stage_label_color <- as.character(get_param(params, 'stage_label_color', '#333333') %||% '#333333')[1]
  stage_labels <- named_chr(get_param(params, 'stage_labels', NULL))

  # title / theme
  title_show <- as_bool(get_param(params, 'title_show', TRUE), TRUE)
  title <- as.character(get_param(params, 'title', 'Alluvial Plot') %||% 'Alluvial Plot')[1]
  subtitle <- get_param(params, 'subtitle', NULL)
  if (!is.null(subtitle)) subtitle <- as.character(subtitle)[1]
  caption <- get_param(params, 'caption', NULL)
  if (!is.null(caption)) caption <- as.character(caption)[1]
  title_size <- as_num(get_param(params, 'title_size', 14), 14)
  title_color <- as.character(get_param(params, 'title_color', '#222222') %||% '#222222')[1]
  title_face <- as.character(get_param(params, 'title_face', 'bold') %||% 'bold')[1]
  title_hjust <- as_num(get_param(params, 'title_hjust', 0.5), 0.5)
  base_size <- as_num(get_param(params, 'base_size', 12), 12)
  font_family <- as.character(get_param(params, 'font_family', 'sans') %||% 'sans')[1]
  bg <- as.character(get_param(params, 'background_color', '#FFFFFF') %||% '#FFFFFF')[1]
  panel_bg <- as.character(get_param(params, 'panel_background', bg) %||% bg)[1]
  legend_show <- as_bool(get_param(params, 'legend_show', FALSE), FALSE)
  legend_position <- as.character(get_param(params, 'legend_position', 'right') %||% 'right')[1]
  legend_title <- as.character(get_param(params, 'legend_title', '') %||% '')[1]
  legend_text_size <- as_num(get_param(params, 'legend_text_size', 10), 10)
  legend_title_size <- as_num(get_param(params, 'legend_title_size', 11), 11)

  W <- as_num(get_param(params, 'width', 12), 12)
  H <- as_num(get_param(params, 'height', 7), 7)
  dpi <- as_num(get_param(params, 'dpi', 300), 300)

  # plot — keep fill only on geom_sankey so label boxes can use solid fill
  sankey_df$fill_key <- factor(as.character(sankey_df$fill_key), levels = names(cols_map))
  g <- ggplot(
    sankey_df,
    aes(
      x = x,
      next_x = next_x,
      node = node,
      next_node = next_node,
      label = node
    )
  )

  sankey_layer <- ggsankey::geom_sankey(
    aes(fill = fill_key),
    flow.alpha = flow_alpha,
    node.color = if (nzchar(stratum_border_color)) stratum_border_color else NA,
    node.alpha = stratum_alpha,
    node.linewidth = stratum_border_width,
    width = stratum_width,
    smooth = flow_smooth,
    type = type_geom,
    space = if (!is.null(space) && is.finite(space)) space else NULL
  )
  g <- g + sankey_layer

  if (label_show) {
    g <- g + ggsankey::geom_sankey_label(
      size = label_size,
      color = label_color,
      fill = label_fill,
      alpha = label_fill_alpha,
      fontface = label_face,
      angle = label_angle,
      show.legend = FALSE
    )
  }

  g <- g + scale_fill_manual(
    values = cols_map,
    name = if (nzchar(legend_title)) legend_title else waiver(),
    drop = FALSE
  )

  # stage axis labels
  if (stage_label_show) {
    xlabs <- as.character(stage_cols_use)
    if (length(stage_labels)) {
      xlabs <- ifelse(xlabs %in% names(stage_labels), stage_labels[xlabs], xlabs)
    }
    g <- g + scale_x_discrete(labels = xlabs)
  } else {
    g <- g + scale_x_discrete(labels = rep('', length(stage_cols_use)))
  }

  g <- g + ggsankey::theme_sankey(base_size = base_size, base_family = font_family)

  g <- g + theme(
    plot.background = element_rect(fill = bg, colour = NA),
    panel.background = element_rect(fill = panel_bg, colour = NA),
    axis.text.x = if (stage_label_show) {
      element_text(size = stage_label_size, colour = stage_label_color, face = 'plain')
    } else {
      element_blank()
    },
    legend.position = if (legend_show) legend_position else 'none',
    legend.text = element_text(size = legend_text_size),
    legend.title = element_text(size = legend_title_size),
    plot.title = element_text(size = title_size, colour = title_color, face = title_face, hjust = title_hjust),
    plot.subtitle = element_text(hjust = title_hjust, colour = '#555555'),
    plot.margin = margin(
      as_num(get_param(params, 'margin_top', 10), 10),
      as_num(get_param(params, 'margin_right', 12), 12),
      as_num(get_param(params, 'margin_bottom', 10), 10),
      as_num(get_param(params, 'margin_left', 12), 12)
    )
  )

  if (title_show && nzchar(title)) {
    g <- g + labs(title = title, subtitle = subtitle, caption = caption)
  } else if (!is.null(subtitle) || !is.null(caption)) {
    g <- g + labs(subtitle = subtitle, caption = caption)
  }

  # highlight selected nodes with outline strata already have border; optional overplot
  highlight_nodes <- as_chr_vec(get_param(params, 'highlight_nodes', NULL))
  if (length(highlight_nodes)) {
    write_log(sprintf('Highlight nodes: %s', paste(highlight_nodes, collapse = ', ')))
  }

  write_log('Rendering SVG/PDF/PNG')
  save_plot <- function(device_fn) {
    device_fn()
    print(g)
    grDevices::dev.off()
  }
  save_plot(function() svglite::svglite(file.path(output_dir, 'result.svg'), width = W, height = H))
  save_plot(function() grDevices::cairo_pdf(file.path(output_dir, 'result.pdf'), width = W, height = H))
  save_plot(function() (if (requireNamespace('ragg', quietly = TRUE)) ragg::agg_png else function(...) grDevices::png(..., type = 'cairo'))(
    file.path(output_dir, 'result.png'),
    width = W, height = H, units = 'in', res = dpi))

  # side outputs
  write.csv(long_df, file.path(output_dir, 'alluvia_used.csv'), row.names = FALSE)
  node_summary <- as.data.frame(table(stage = long_df$stage, node = long_df$node), stringsAsFactors = FALSE)
  write.csv(node_summary, file.path(output_dir, 'nodes_used.csv'), row.names = FALSE)

  meta <- list(
    plugin = 'alluvial_plot',
    engine = 'ggsankey + ggplot2',
    input_mode = mode,
    n_paths = nrow(wide_paths),
    n_stages = length(stage_cols_use),
    stages = as.character(stage_cols_use),
    n_nodes = length(levels_fill),
    nodes = levels_fill,
    fill_by = fill_by,
    palette = palette_name,
    outputs = c('result.svg', 'result.pdf', 'result.png', 'alluvia_used.csv', 'nodes_used.csv')
  )
  writeLines(jsonlite::toJSON(meta, auto_unbox = TRUE, pretty = TRUE, null = 'null'),
             file.path(output_dir, 'figure.json'))
  write_log('Completed alluvial_plot')
  quit(status = 0)

}, error = function(e) {
  write_error_and_exit(
    'Alluvial plot failed',
    conditionMessage(e),
    'Check stage columns, input_mode, and that each path has ≥2 stages.'
  )
})
