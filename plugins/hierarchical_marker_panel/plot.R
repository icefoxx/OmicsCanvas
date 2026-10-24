#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
  library(grid)
  library(gridExtra)
})

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

opt <- parse_args(OptionParser(option_list = list(
  make_option('--input', type = 'character'),
  make_option('--params', type = 'character'),
  make_option('--output', type = 'character')
)))
out <- opt$output %||% getwd()
dir.create(out, recursive = TRUE, showWarnings = FALSE)
unlink(file.path(out, c('result.svg', 'result.pdf', 'result.png', 'figure.json', 'error.json', 'data_used.csv', 'visual_config_used.json')), force = TRUE)

script_dir <- local({
  f <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[1])
  if (is.na(f)) getwd() else dirname(normalizePath(f))
})
repo_root <- normalizePath(file.path(script_dir, '..', '..'), mustWork = FALSE)

log_msg <- function(...) {
  line <- sprintf('[%s] %s\n', format(Sys.time(), '%F %T'), paste0(...))
  cat(line, file = file.path(out, 'run.log'), append = TRUE)
}

fail <- function(message, detail = '', suggestion = 'Check the input columns and params.json.') {
  writeLines(toJSON(list(error = message, detail = as.character(detail), suggestion = suggestion),
                    auto_unbox = TRUE, pretty = TRUE), file.path(out, 'error.json'))
  log_msg('ERROR: ', message, ' ', detail)
  quit(save = 'no', status = 1)
}

params <- if (!is.null(opt$params) && file.exists(opt$params)) fromJSON(opt$params, simplifyVector = FALSE) else list()
param <- function(key, default = NULL) params[[key]] %||% default
visual_config <- param('visual_config', list())
config_value <- function(section, key, default = NULL) {
  section_value <- visual_config[[section]]
  if (is.null(section_value) || !is.list(section_value) || is.null(section_value[[key]])) default else section_value[[key]]
}
config_level_value <- function(section, level, key, default = NULL) {
  section_value <- visual_config[[section]]
  level_value <- if (is.list(section_value)) section_value[[level]] else NULL
  if (is.null(level_value) || !is.list(level_value) || is.null(level_value[[key]])) default else level_value[[key]]
}
config_nested_value <- function(section, subgroup, level, key, default = NULL) {
  section_value <- visual_config[[section]]
  subgroup_value <- if (is.list(section_value)) section_value[[subgroup]] else NULL
  level_value <- if (is.list(subgroup_value)) subgroup_value[[level]] else NULL
  if (is.null(level_value) || !is.list(level_value) || is.null(level_value[[key]])) default else level_value[[key]]
}
config_flag <- function(section, key, default = FALSE) {
  value <- config_value(section, key, default)
  if (is.logical(value)) isTRUE(value[[1]]) else tolower(as.character(value[[1]])) %in% c('true', 't', 'yes', '1', 'on')
}
config_num <- function(section, key, default) {
  value <- suppressWarnings(as.numeric(unlist(config_value(section, key, default)))[1])
  if (length(value) && is.finite(value)) value else default
}
config_chr <- function(section, key, default = '') as.character(config_value(section, key, default))[1]
num <- function(key, default) {
  value <- suppressWarnings(as.numeric(unlist(param(key)))[1])
  if (length(value) && is.finite(value)) value else default
}
flag <- function(key, default = FALSE) {
  value <- param(key)
  if (is.null(value)) return(default)
  if (is.logical(value)) return(isTRUE(value[[1]]))
  tolower(as.character(value[[1]])) %in% c('true', 't', 'yes', 'y', '1', 'on')
}
chr <- function(key, default = '') {
  value <- unlist(param(key))
  if (!length(value) || is.na(value[[1]])) default else as.character(value[[1]])
}
chr_vec <- function(key) {
  value <- unlist(param(key), use.names = FALSE)
  if (!length(value)) character() else trimws(as.character(value))
}
or_auto <- function(value, automatic) if (nzchar(value)) value else automatic

read_table <- function(path) {
  if (is.null(path) || !file.exists(path)) fail('Input file not found', path %||% '')
  if (tolower(tools::file_ext(path)) %in% c('tsv', 'txt')) {
    read.delim(path, check.names = FALSE, stringsAsFactors = FALSE)
  } else {
    read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  }
}

find_column <- function(df, key, defaults) {
  wanted <- c(chr(key, ''), defaults)
  wanted <- wanted[nzchar(wanted)]
  hit <- match(tolower(wanted), tolower(colnames(df)))
  hit <- hit[!is.na(hit)]
  if (length(hit)) return(colnames(df)[hit[[1]]])
  fail(sprintf('Column for %s not found', key), paste(wanted, collapse = ', '),
       sprintf('Set %s to one of: %s', key, paste(colnames(df), collapse = ', ')))
}

find_optional_column <- function(df, key, defaults) {
  wanted <- c(chr(key, ''), defaults)
  wanted <- wanted[nzchar(wanted)]
  if (!length(wanted)) return(NULL)
  hit <- match(tolower(wanted), tolower(colnames(df)))
  hit <- hit[!is.na(hit)]
  if (length(hit)) colnames(df)[hit[[1]]] else NULL
}

named_colors <- function(value, levels, fallback) {
  colors <- grDevices::hcl.colors(max(3, length(levels)), palette = fallback)[seq_along(levels)]
  names(colors) <- levels
  supplied <- unlist(value, use.names = TRUE)
  if (length(supplied) && !is.null(names(supplied))) {
    hits <- intersect(names(supplied), levels)
    colors[hits] <- as.character(supplied[hits])
  }
  colors
}

main <- function() {
  raw <- read_table(opt$input)
  cols <- list(
    cell_type = find_column(raw, 'cell_type_column', c('cell_type', 'cell type')),
    class = find_column(raw, 'class_column', c('class', 'cell_class')),
    subclass = find_column(raw, 'subclass_column', c('subclass', 'cell_subclass')),
    cell_count = find_column(raw, 'cell_count_column', c('cell_number', 'cell_count', 'n_cells')),
    marker = find_column(raw, 'marker_column', c('gene', 'marker', 'feature')),
    average = find_column(raw, 'average_transcript_column', c('average_transcript', 'avg_exp', 'mean_expression')),
    pct = find_column(raw, 'pct_expressed_column', c('pct_expressed', 'pct_exp', 'percent_expressed')),
    sample = find_optional_column(raw, 'sample_column', c('sample', 'orig.ident', 'orig_id')),
    sample_count = find_optional_column(raw, 'sample_count_column', c('sample_cell_number', 'sample_count', 'n_cells_sample'))
  )
  d <- data.frame(
    cell_type = as.character(raw[[cols$cell_type]]),
    class = as.character(raw[[cols$class]]),
    subclass = as.character(raw[[cols$subclass]]),
    cell_count = suppressWarnings(as.numeric(raw[[cols$cell_count]])),
    marker = as.character(raw[[cols$marker]]),
    average = suppressWarnings(as.numeric(raw[[cols$average]])),
    pct = suppressWarnings(as.numeric(raw[[cols$pct]])),
    stringsAsFactors = FALSE
  )
  if (!is.null(cols$sample)) d$sample <- as.character(raw[[cols$sample]])
  if (!is.null(cols$sample_count)) d$sample_count <- suppressWarnings(as.numeric(raw[[cols$sample_count]]))
  missing_hierarchy <- is.na(d$cell_type) | !nzchar(trimws(d$cell_type)) |
    is.na(d$class) | !nzchar(trimws(d$class)) |
    is.na(d$subclass) | !nzchar(trimws(d$subclass))
  if (any(missing_hierarchy)) {
    fail('Missing hierarchy labels', sprintf('%d rows have empty cell_type, class, or subclass values.', sum(missing_hierarchy)), 'Fill all three hierarchy columns before plotting.')
  }
  bad <- is.na(d$marker) | !nzchar(trimws(d$marker)) | !is.finite(d$cell_count) |
    !is.finite(d$average) | !is.finite(d$pct)
  if (any(bad)) log_msg(sprintf('Dropped %d rows with missing labels or numeric values.', sum(bad)))
  d <- d[!bad, , drop = FALSE]
  if (!nrow(d)) fail('No valid marker rows remain')
  d$pct <- pmax(0, pmin(100, d$pct))
  d$cell_count <- d$cell_count / num('cell_count_divisor', 1000)

  requested_cell_order <- chr_vec('cell_type_order')
  cell_order <- requested_cell_order
  marker_order <- chr_vec('marker_order')
  if (!length(cell_order)) {
    hierarchy_order <- order(d$class, d$subclass, match(d$cell_type, unique(d$cell_type)))
    cell_order <- unique(d$cell_type[hierarchy_order])
  }
  cell_order <- c(intersect(cell_order, unique(d$cell_type)), setdiff(unique(d$cell_type), cell_order))
  marker_order <- c(intersect(marker_order, unique(d$marker)), setdiff(unique(d$marker), marker_order))
  cell_include <- chr_vec('cell_types_include')
  marker_include <- chr_vec('markers_include')
  if (length(cell_include)) d <- d[as.character(d$cell_type) %in% cell_include, , drop = FALSE]
  if (length(marker_include)) d <- d[as.character(d$marker) %in% marker_include, , drop = FALSE]
  if (!nrow(d)) fail('No rows remain after hierarchy filtering', '', 'Check cell_types_include and markers_include.')
  cell_order <- c(intersect(cell_order, unique(d$cell_type)), setdiff(unique(d$cell_type), cell_order))
  marker_order <- c(intersect(marker_order, unique(d$marker)), setdiff(unique(d$marker), marker_order))
  hierarchy_check <- unique(d[, c('cell_type', 'class', 'subclass')])
  if (anyDuplicated(as.character(hierarchy_check$cell_type))) {
    fail('Inconsistent hierarchy mapping', 'Each cell type must map to exactly one class and subclass.', 'Correct class_column and subclass_column values.')
  }
  hierarchy_check <- hierarchy_check[match(cell_order, as.character(hierarchy_check$cell_type)), , drop = FALSE]
  if (length(cell_order) > 1) {
    class_rle <- rle(as.character(hierarchy_check$class))
    subclass_rle <- rle(as.character(hierarchy_check$subclass))
    if (anyDuplicated(class_rle$values) || anyDuplicated(subclass_rle$values)) {
      fail('Non-contiguous hierarchy order', 'A class or subclass appears in multiple separated x-axis blocks.', 'Order cell types contiguously by class and subclass.')
    }
  }
  d$cell_type <- factor(d$cell_type, levels = cell_order)
  d$marker <- factor(d$marker, levels = rev(marker_order))
  d$class <- factor(d$class, levels = unique(as.character(d$class)))
  d$subclass <- factor(d$subclass, levels = unique(as.character(d$subclass)))

  count_data <- unique(d[, c('cell_type', 'class', 'subclass', 'cell_count')])
  if (anyDuplicated(as.character(count_data$cell_type))) {
    fail('Cell count is not unique per cell type', 'Each cell type must have one cell_count value.')
  }
  count_data <- count_data[match(cell_order, as.character(count_data$cell_type)), , drop = FALSE]
  count_data$x <- seq_along(cell_order)
  d$x <- match(as.character(d$cell_type), cell_order)
  d$y <- as.numeric(d$marker)
  write.csv(d, file.path(out, 'data_used.csv'), row.names = FALSE)
  dot_data <- aggregate(cbind(average, pct) ~ cell_type + marker, d, mean)
  dot_data$x <- match(as.character(dot_data$cell_type), cell_order)
  dot_data$y <- as.numeric(dot_data$marker)

  font_family <- chr('font_family', 'sans')
  text_color <- chr('text_color', '#222222')
  group_colors <- named_colors(param('class_colors', list()), levels(count_data$class), 'Dark 3')
  marker_colors <- unlist(config_value('dotplot', 'colormap', NULL), use.names = FALSE)
  if (!length(marker_colors)) marker_colors <- chr_vec('average_transcript_colors')
  if (length(marker_colors) < 2) marker_colors <- c('#F7FBFF', '#2171B5')
  dot_min <- config_num('dotplot', 'dot_min_size', num('dot_min', 1.2))
  dot_max <- config_num('dotplot', 'dot_max_size', num('dot_max', 5.2))
  size_scale <- function(value) dot_min + (dot_max - dot_min) * sqrt(pmax(0, pmin(100, value)) / 100)

  hierarchy <- data.frame(x = seq_along(cell_order), cell_type = cell_order,
                          class = as.character(count_data$class),
                          subclass = as.character(count_data$subclass))
  span <- function(values) {
    split_x <- split(hierarchy$x, values)
    data.frame(label = names(split_x), xmin = vapply(split_x, min, numeric(1)),
               xmax = vapply(split_x, max, numeric(1)), stringsAsFactors = FALSE)
  }
  class_spans <- span(hierarchy$class)
  subclass_spans <- span(hierarchy$subclass)
  class_y <- num('class_branch_height', 3)
  subclass_y <- num('subclass_branch_height', 2)
  cell_type_y <- num('cell_type_branch_height', 0.55)
  class_length <- config_num('hierarchy', 'class_branch_length', num('class_branch_length', config_nested_value('hierarchy', 'linker', 'class', 'vertical_length', 0.2)))
  subclass_length <- config_num('hierarchy', 'subclass_branch_length', num('subclass_branch_length', config_nested_value('hierarchy', 'linker', 'subclass', 'vertical_length', 0.2)))
  cell_type_length <- config_num('hierarchy', 'cell_type_branch_length', num('cell_type_branch_length', config_nested_value('hierarchy', 'linker', 'cluster', 'vertical_length', 0.2)))
  class_branch_color <- config_chr('hierarchy', 'class_branch_color', config_nested_value('hierarchy', 'linker', 'class', 'color', chr('class_branch_color', '#555555')))
  subclass_branch_color <- config_chr('hierarchy', 'subclass_branch_color', config_nested_value('hierarchy', 'linker', 'subclass', 'color', chr('subclass_branch_color', '#777777')))
  cell_type_branch_color <- config_chr('hierarchy', 'cell_type_branch_color', config_nested_value('hierarchy', 'linker', 'cluster', 'color', chr('cell_type_branch_color', '#777777')))
  class_branch_width <- config_num('hierarchy', 'class_branch_linewidth', config_nested_value('hierarchy', 'linker', 'class', 'linewidth', 0.45))
  subclass_branch_width <- config_num('hierarchy', 'subclass_branch_linewidth', config_nested_value('hierarchy', 'linker', 'subclass', 'linewidth', 0.4))
  cell_type_branch_width <- config_num('hierarchy', 'cell_type_branch_linewidth', config_nested_value('hierarchy', 'linker', 'cluster', 'linewidth', 0.35))
  class_branch_alpha <- config_num('hierarchy', 'class_branch_alpha', config_nested_value('hierarchy', 'linker', 'class', 'alpha', 1))
  subclass_branch_alpha <- config_num('hierarchy', 'subclass_branch_alpha', config_nested_value('hierarchy', 'linker', 'subclass', 'alpha', 0.9))
  cell_type_branch_alpha <- config_num('hierarchy', 'cell_type_branch_alpha', config_nested_value('hierarchy', 'linker', 'cluster', 'alpha', 0.8))
  class_branch_type <- config_chr('hierarchy', 'class_branch_linetype', config_nested_value('hierarchy', 'linker', 'class', 'linetype', 'solid'))
  subclass_branch_type <- config_chr('hierarchy', 'subclass_branch_linetype', config_nested_value('hierarchy', 'linker', 'subclass', 'linetype', 'solid'))
  cell_type_branch_type <- config_chr('hierarchy', 'cell_type_branch_linetype', config_nested_value('hierarchy', 'linker', 'cluster', 'linetype', 'solid'))
  linker_visible <- config_flag('hierarchy', 'linker_visible', TRUE)
  if (!linker_visible) {
    class_branch_alpha <- 0
    subclass_branch_alpha <- 0
    cell_type_branch_alpha <- 0
  }
  class_label_size <- config_num('hierarchy', 'class_label_size', num('class_label_size', 3.4))
  subclass_label_size <- config_num('hierarchy', 'subclass_label_size', num('subclass_label_size', 3))
  cell_label_size <- config_num('hierarchy', 'cell_type_label_size', num('cell_type_label_size', 2.7))
  class_label_color <- config_chr('hierarchy', 'class_label_color', config_nested_value('hierarchy', 'text', 'class', 'color', text_color))
  subclass_label_color <- config_chr('hierarchy', 'subclass_label_color', config_nested_value('hierarchy', 'text', 'subclass', 'color', text_color))
  cluster_label_color_mode <- config_chr('hierarchy', 'cluster_text_color', config_nested_value('hierarchy', 'text', 'cluster', 'color', 'inherit_cluster'))
  automatic_angle <- if (length(cell_order) > 20) 90 else if (length(cell_order) > 10) 65 else 55
  label_angle <- if (flag('label_auto', TRUE)) max(automatic_angle, num('cell_type_label_angle', 60)) else num('cell_type_label_angle', 60)
  label_width <- num('label_wrap_width', 0)
  if (label_width <= 0) label_width <- max(8, floor(20 - length(cell_order) / 3))
  wrap_text <- function(label, width) {
    if (nchar(label) <= width) return(label)
    chars <- strsplit(label, '', fixed = TRUE)[[1]]
    paste(vapply(seq(1, length(chars), by = width), function(start) paste(chars[start:min(start + width - 1, length(chars))], collapse = ''), character(1)), collapse = '\n')
  }
  hierarchy$cell_type_display <- vapply(as.character(hierarchy$cell_type), function(label) {
    wrap_text(label, max(1, label_width))
  }, character(1))
  class_spans$display_label <- vapply(class_spans$label, function(label) wrap_text(label, max(1, label_width)), character(1))
  subclass_spans$display_label <- vapply(subclass_spans$label, function(label) wrap_text(label, max(1, label_width)), character(1))
  label_size <- if (flag('label_auto', TRUE)) {
    adaptive_size <- 3.2 - max(nchar(as.character(hierarchy$cell_type))) / 10
    max(1.6, adaptive_size * cell_label_size / 2.7)
  } else cell_label_size
  hierarchy_y_max <- max(class_y + 0.7, subclass_y + 0.6, 1.2)
  shared_x_limits <- c(0.5, length(cell_order) + 0.5)
  cluster_text_layer <- if (cluster_label_color_mode %in% c('inherit_cluster', 'auto')) {
    geom_text(data = hierarchy, aes(x = x, y = 0.35, label = cell_type_display, color = class), angle = config_nested_value('hierarchy', 'text', 'cluster', 'rotation', label_angle), hjust = config_nested_value('hierarchy', 'text', 'cluster', 'hjust', 0), vjust = config_nested_value('hierarchy', 'text', 'cluster', 'vjust', 0.5), size = label_size, family = config_nested_value('hierarchy', 'text', 'cluster', 'fontfamily', font_family), fontface = config_nested_value('hierarchy', 'text', 'cluster', 'fontweight', 'plain'), alpha = config_nested_value('hierarchy', 'text', 'cluster', 'alpha', 1), show.legend = FALSE)
  } else {
    geom_text(data = hierarchy, aes(x = x, y = 0.35, label = cell_type_display), angle = config_nested_value('hierarchy', 'text', 'cluster', 'rotation', label_angle), hjust = config_nested_value('hierarchy', 'text', 'cluster', 'hjust', 0), vjust = config_nested_value('hierarchy', 'text', 'cluster', 'vjust', 0.5), size = label_size, family = config_nested_value('hierarchy', 'text', 'cluster', 'fontfamily', font_family), fontface = config_nested_value('hierarchy', 'text', 'cluster', 'fontweight', 'plain'), color = cluster_label_color_mode, alpha = config_nested_value('hierarchy', 'text', 'cluster', 'alpha', 1), show.legend = FALSE)
  }
  hierarchy_plot <- ggplot() +
    geom_segment(data = class_spans, aes(x = xmin, xend = xmax, y = class_y, yend = class_y), linewidth = class_branch_width, color = class_branch_color, alpha = class_branch_alpha, linetype = class_branch_type, lineend = 'butt', linejoin = 'mitre', na.rm = !linker_visible) +
    geom_segment(data = class_spans, aes(x = xmin, xend = xmin, y = class_y - class_length, yend = class_y), linewidth = class_branch_width, color = class_branch_color, alpha = class_branch_alpha, linetype = class_branch_type, lineend = 'butt', linejoin = 'mitre', na.rm = !linker_visible) +
    geom_segment(data = class_spans, aes(x = xmax, xend = xmax, y = class_y - class_length, yend = class_y), linewidth = class_branch_width, color = class_branch_color, alpha = class_branch_alpha, linetype = class_branch_type, lineend = 'butt', linejoin = 'mitre', na.rm = !linker_visible) +
    geom_text(data = class_spans, aes(x = (xmin + xmax) / 2, y = class_y + 0.35, label = display_label), size = class_label_size, family = config_nested_value('hierarchy', 'text', 'class', 'fontfamily', font_family), fontface = config_nested_value('hierarchy', 'text', 'class', 'fontweight', 'plain'), angle = config_nested_value('hierarchy', 'text', 'class', 'rotation', 0), color = class_label_color, alpha = config_nested_value('hierarchy', 'text', 'class', 'alpha', 1)) +
    geom_segment(data = subclass_spans, aes(x = xmin, xend = xmax, y = subclass_y, yend = subclass_y), linewidth = subclass_branch_width, color = subclass_branch_color, alpha = subclass_branch_alpha, linetype = subclass_branch_type, lineend = 'butt', linejoin = 'mitre', na.rm = !linker_visible) +
    geom_segment(data = subclass_spans, aes(x = xmin, xend = xmin, y = subclass_y - subclass_length, yend = subclass_y), linewidth = subclass_branch_width, color = subclass_branch_color, alpha = subclass_branch_alpha, linetype = subclass_branch_type, lineend = 'butt', linejoin = 'mitre', na.rm = !linker_visible) +
    geom_segment(data = subclass_spans, aes(x = xmax, xend = xmax, y = subclass_y - subclass_length, yend = subclass_y), linewidth = subclass_branch_width, color = subclass_branch_color, alpha = subclass_branch_alpha, linetype = subclass_branch_type, lineend = 'butt', linejoin = 'mitre', na.rm = !linker_visible) +
    geom_text(data = subclass_spans, aes(x = (xmin + xmax) / 2, y = subclass_y + 0.3, label = display_label), size = subclass_label_size, family = config_nested_value('hierarchy', 'text', 'subclass', 'fontfamily', font_family), fontface = config_nested_value('hierarchy', 'text', 'subclass', 'fontweight', 'plain'), angle = config_nested_value('hierarchy', 'text', 'subclass', 'rotation', 0), color = subclass_label_color, alpha = config_nested_value('hierarchy', 'text', 'subclass', 'alpha', 1)) +
    geom_segment(data = hierarchy, aes(x = x, xend = x, y = cell_type_y - cell_type_length, yend = cell_type_y), linewidth = cell_type_branch_width, color = cell_type_branch_color, alpha = cell_type_branch_alpha, linetype = cell_type_branch_type, lineend = 'butt', linejoin = 'mitre', na.rm = !linker_visible) +
    cluster_text_layer +
    scale_color_manual(values = group_colors) +
    scale_x_continuous(limits = shared_x_limits, breaks = NULL, expand = c(0, 0)) +
    scale_y_continuous(limits = c(0, hierarchy_y_max), breaks = NULL, expand = c(0, 0)) +
    labs(x = NULL, y = NULL) +
    theme_void(base_family = font_family) +
    coord_cartesian(clip = 'off') +
    theme(plot.margin = margin(2, 24, 8, 24))

  summary_plot_type <- chr('summary_plot_type', '')
  if (!nzchar(summary_plot_type)) {
    summary_plot_type <- switch(chr('bar_mode', 'cell_number'), cell_number = 'bar', sample_number = 'stacked_bar', sample_percent = 'stacked_bar_100', 'bar')
  }
  valid_summary_types <- c('bar', 'stacked_bar', 'stacked_bar_100', 'grouped_bar', 'pie', 'donut')
  if (!summary_plot_type %in% valid_summary_types) {
    fail('Unsupported summary_plot_type', summary_plot_type, paste('Choose:', paste(valid_summary_types, collapse = ', ')))
  }
  bar_mode <- switch(summary_plot_type, bar = 'cell_number', stacked_bar = 'sample_number', stacked_bar_100 = 'sample_percent', 'sample_number')
  bar_data <- count_data
  bar_fill_colors <- group_colors
  if (summary_plot_type != 'bar') {
    if (is.null(cols$sample) && is.null(cols$sample_count)) {
      d$sample <- 'All'
      d$sample_count <- d$cell_count * num('cell_count_divisor', 1000)
      log_msg('No sample columns supplied; using one synthetic All sample for the requested sample bar mode.')
    } else if (is.null(cols$sample) || is.null(cols$sample_count)) {
      fail('Incomplete sample composition mapping', 'sample_column and sample_count_column must be supplied together.', 'Map both sample columns in params.json.')
    }
    if (any(!nzchar(d$sample)) || any(!is.finite(d$sample_count))) {
      fail('Invalid sample composition values', 'Sample labels must be non-empty and sample counts must be numeric.')
    }
    sample_data <- aggregate(sample_count ~ cell_type + sample, d, function(values) {
      unique_values <- unique(values)
      if (length(unique_values) != 1) NA_real_ else unique_values[[1]]
    })
    if (any(!is.finite(sample_data$sample_count))) {
      fail('Inconsistent sample counts', 'Each cell_type/sample pair must have one sample count repeated across marker rows.')
    }
    sample_data$sample_count <- sample_data$sample_count / num('cell_count_divisor', 1000)
    sample_data$x <- match(as.character(sample_data$cell_type), cell_order)
    sample_order <- chr_vec('sample_order')
    sample_levels <- c(intersect(sample_order, unique(sample_data$sample)), setdiff(unique(sample_data$sample), sample_order))
    sample_data$sample <- factor(sample_data$sample, levels = sample_levels)
    if (summary_plot_type == 'stacked_bar_100') {
      totals <- aggregate(sample_count ~ x, sample_data, sum)
      names(totals)[2] <- 'total_count'
      sample_data <- merge(sample_data, totals, by = 'x', sort = FALSE)
      sample_data$value <- 100 * sample_data$sample_count / sample_data$total_count
      percent_checks <- aggregate(value ~ x, sample_data, sum)
      if (any(abs(percent_checks$value - 100) > 1e-8)) {
        fail('Sample percentages do not sum to 100%', 'At least one cluster has an invalid sample composition total.', 'Check sample_count_column values for each cell type.')
      }
    } else {
      sample_data$value <- sample_data$sample_count
    }
    bar_data <- sample_data
    bar_fill_colors <- named_colors(param('sample_colors', list()), sample_levels, 'Set 2')
    sample_data <- sample_data[order(sample_data$x, sample_data$sample), , drop = FALSE]
    sample_totals <- aggregate(sample_count ~ x, sample_data, sum)
    sample_data$total_count <- sample_totals$sample_count[match(sample_data$x, sample_totals$x)]
    sample_data$share <- sample_data$sample_count / sample_data$total_count
    angle_offset <- config_num(if (summary_plot_type == 'pie') 'pie' else 'donut', 'startangle', 90) * pi / 180
    counterclockwise <- config_flag(if (summary_plot_type == 'pie') 'pie' else 'donut', 'counterclock', FALSE)
    cumulative <- ave(sample_data$share, sample_data$x, FUN = cumsum) * 2 * pi
    segment_size <- sample_data$share * 2 * pi
    if (counterclockwise) {
      sample_data$start <- angle_offset + cumulative - segment_size
      sample_data$end <- angle_offset + cumulative
    } else {
      sample_data$start <- angle_offset - cumulative
      sample_data$end <- sample_data$start + segment_size
    }
  }
  bar_y_label <- if (summary_plot_type == 'stacked_bar_100') 'Sample composition (%)' else if (summary_plot_type %in% c('stacked_bar', 'grouped_bar', 'pie', 'donut')) 'Cell Number (x10^3)' else or_auto(chr('count_label'), 'Cell Number (x10^3)')
  summary_edgecolor <- config_chr('summary', 'edgecolor', 'none')
  if (tolower(summary_edgecolor) == 'none') summary_edgecolor <- NA_character_
  summary_show_grid <- config_flag('summary', 'show_grid', FALSE)
  summary_show_yticks <- config_flag('summary', 'show_yticks', TRUE)
  summary_show_ylabel <- config_flag('summary', 'show_ylabel', TRUE)
  summary_show_values <- config_flag('summary', 'show_values', FALSE)
  summary_value_data <- if (summary_plot_type == 'bar') count_data else bar_data
  if (!identical(length(shared_x_limits), 2L) || shared_x_limits[[1]] >= shared_x_limits[[2]]) {
    fail('Invalid shared x coordinate system', 'At least one cell type is required.')
  }
  layout_legend_width <- if (flag('legend_show', TRUE)) num('legend_panel_width', 2.45) else 0.05
  layout_main_width <- if (flag('auto_width', TRUE)) 4 + length(cell_order) * num('width_per_cell_type', 0.65) else max(1, num('width', 10) - layout_legend_width)
  layout_height <- if (flag('auto_height', TRUE)) 4.5 + length(marker_order) * num('height_per_marker', 0.22) + 0.8 else num('height', 7)
  summary_rel_height <- num('count_height', 1.25)
  total_rel_height <- num('hierarchy_height', 1.5) + summary_rel_height + num('dot_height', 3.2)
  pie_coord_ratio <- (summary_rel_height / total_rel_height) * (layout_main_width / layout_height) * diff(shared_x_limits) / 1.3
  bar_plot <- ggplot(bar_data, aes(x = x, y = if (summary_plot_type == 'bar') cell_count else value, fill = if (summary_plot_type == 'bar') class else sample)) +
    geom_col(width = config_num('summary', 'bar_width', num('bar_width', 0.82)), color = summary_edgecolor, linewidth = config_num('summary', 'linewidth', 0), alpha = config_num('summary', 'alpha', 1), position = if (summary_plot_type == 'grouped_bar') position_dodge(width = config_num('summary', 'bar_width', 0.82)) else 'stack') +
    scale_fill_manual(values = bar_fill_colors, guide = if (flag('legend_show', TRUE) && summary_plot_type != 'bar') 'legend' else 'none', name = if (summary_plot_type == 'bar') NULL else 'Sample') +
    scale_x_continuous(limits = shared_x_limits, breaks = NULL, expand = c(0, 0)) +
    scale_y_continuous(limits = if (summary_plot_type == 'stacked_bar_100') c(0, 100) else NULL, expand = expansion(mult = c(0, 0.08))) +
    labs(x = NULL, y = bar_y_label) +
    theme_classic(base_family = font_family, base_size = num('base_size', 11)) +
    theme(axis.text.x = element_blank(), axis.ticks.x = element_blank(), axis.title.x = element_blank(),
          axis.title.y = if (summary_show_ylabel) element_text(size = num('axis_label_size', 9), color = text_color) else element_blank(),
          axis.text.y = if (summary_show_yticks) element_text(size = num('axis_text_size', 8), color = text_color) else element_blank(),
          axis.ticks.y = if (summary_show_yticks) element_line() else element_blank(),
          panel.grid.major.y = if (summary_show_grid) element_line(color = config_chr('summary', 'grid_color', '#E6E6E6')) else element_blank(),
          panel.grid.major.x = element_blank(), plot.margin = margin(0, 24, 0, 24))
  if (summary_show_values && summary_plot_type %in% c('bar', 'stacked_bar_100')) {
    value_label_data <- if (summary_plot_type == 'bar') count_data else bar_data
    value_column <- if (summary_plot_type == 'bar') 'cell_count' else 'value'
    bar_plot <- bar_plot + geom_text(data = value_label_data, aes(x = x, y = .data[[value_column]], label = round(.data[[value_column]], 2)), inherit.aes = FALSE, vjust = -0.35, size = config_num('summary', 'value_fontsize', 9) / 3.2, color = config_chr('summary', 'value_color', 'black'), fontface = config_chr('summary', 'value_fontweight', 'plain'))
  }
  summary_plot <- bar_plot
  if (summary_plot_type %in% c('pie', 'donut')) {
    pie_section <- if (summary_plot_type == 'pie') 'pie' else 'donut'
    default_outer <- if (summary_plot_type == 'pie') 0.38 else 0.4
    outer_radius <- config_num(pie_section, 'outer_radius', config_num(pie_section, 'radius', default_outer))
    inner_radius <- if (summary_plot_type == 'donut') config_num('donut', 'inner_radius', 0.22) else 0
    size_mode <- config_chr(pie_section, 'size_mode', config_chr('summary', 'pie_size_mode', 'fixed'))
    totals <- unique(sample_data[, c('x', 'total_count')])
    if (size_mode == 'cell_count') {
      total_range <- range(totals$total_count, finite = TRUE)
      normalized <- if (diff(total_range) == 0) rep(1, nrow(totals)) else sqrt((totals$total_count - total_range[[1]]) / diff(total_range))
      min_radius <- config_num(pie_section, 'min_radius', outer_radius * 0.65)
      max_radius <- config_num(pie_section, 'max_radius', outer_radius)
      totals$radius <- min_radius + normalized * (max_radius - min_radius)
    } else {
      totals$radius <- outer_radius
    }
    sample_data$radius <- totals$radius[match(sample_data$x, totals$x)]
    sample_data$inner_radius <- if (summary_plot_type == 'donut') pmin(inner_radius, sample_data$radius * 0.9) else 0
    pie_plots <- lapply(seq_along(cell_order), function(cluster_index) {
      cluster_data <- sample_data[sample_data$x == cluster_index, , drop = FALSE]
      cluster_plot <- ggplot(cluster_data) +
        ggforce::geom_arc_bar(aes(x0 = 0, y0 = 0, r0 = inner_radius, r = radius, start = start, end = end, fill = sample),
                              color = config_chr(pie_section, 'edgecolor', 'white'), linewidth = config_num(pie_section, 'linewidth', 0.6), alpha = config_num(pie_section, 'alpha', 1), inherit.aes = FALSE) +
        scale_fill_manual(values = bar_fill_colors, name = 'Sample') +
        coord_fixed(xlim = c(-1, 1), ylim = c(-1, 1), expand = FALSE, clip = 'off') +
        theme_void(base_family = font_family) +
        theme(plot.margin = margin(0, 2, 0, 2), legend.position = 'none')
      if (config_flag(pie_section, 'show_percentage', FALSE)) {
        label_data <- cluster_data
        label_data$label_x <- cos((label_data$start + label_data$end) / 2) * label_data$radius * 1.15
        label_data$label_y <- sin((label_data$start + label_data$end) / 2) * label_data$radius * 1.15
        label_data$label <- paste0(round(label_data$share * 100, 1), '%')
        cluster_plot <- cluster_plot + geom_text(data = label_data, aes(x = label_x, y = label_y, label = label), inherit.aes = FALSE, size = config_num(pie_section, 'label_fontsize', 8) / 3.2, color = config_chr(pie_section, 'label_color', 'black'))
      }
      if (summary_plot_type == 'donut' && config_chr('donut', 'center_text', 'none') != 'none') {
        center_row <- count_data[count_data$x == cluster_index, , drop = FALSE]
        center_text <- switch(config_chr('donut', 'center_text', 'none'), cell_count = format(round(center_row$cell_count[[1]], 2), trim = TRUE), cluster_name = as.character(center_row$cell_type[[1]]), cluster_percent = paste0(round(100 * center_row$cell_count[[1]] / sum(count_data$cell_count), 1), '%'), config_chr('donut', 'center_text', ''))
        cluster_plot <- cluster_plot + geom_text(data = data.frame(x = 0, y = 0, label = center_text), aes(x = x, y = y, label = label), inherit.aes = FALSE, size = config_num('donut', 'center_fontsize', 9) / 3.2, fontface = config_chr('donut', 'center_fontweight', 'bold'), color = config_chr('donut', 'center_color', 'black'))
      }
      cluster_plot
    })
    summary_plot <- do.call(cowplot::plot_grid, c(pie_plots, list(ncol = length(pie_plots), align = 'h', axis = 'lr', rel_widths = rep(1, length(pie_plots)))))
  }

  dot_plot <- ggplot(dot_data, aes(x = x, y = y, size = pct, color = average)) +
    geom_point(shape = config_num('dotplot', 'marker_shape', 16), alpha = config_num('dotplot', 'dot_alpha', num('point_alpha', 0.95)), stroke = config_num('dotplot', 'dot_linewidth', num('point_stroke', 0.15)) ) +
    scale_size_continuous(range = c(dot_min, dot_max), limits = c(0, 100), breaks = c(0, 25, 50, 75, 100), name = or_auto(chr('size_legend_title'), '% cell expressed')) +
    scale_color_gradientn(colors = marker_colors, limits = c(config_num('dotplot', 'color_vmin', num('average_min', min(d$average))), config_num('dotplot', 'color_vmax', num('average_max', max(d$average)))), name = or_auto(chr('average_legend_title'), 'Average transcript')) +
    scale_x_continuous(limits = shared_x_limits, breaks = NULL, expand = c(0, 0)) +
    scale_y_continuous(limits = c(0.5, length(marker_order) + 0.5), breaks = seq_along(marker_order), labels = rev(marker_order), expand = c(0, 0)) +
    labs(x = NULL, y = NULL) +
    theme_classic(base_family = font_family, base_size = num('base_size', 11)) +
    theme(axis.text.x = element_blank(), axis.ticks.x = element_blank(), axis.text.y = element_text(size = num('marker_label_size', 8), color = text_color, face = 'italic'),
          axis.ticks.y = element_blank(), axis.line.x = element_blank(), panel.grid = element_blank(),
          legend.position = if (config_flag('legend', 'visible', flag('legend_show', TRUE))) 'right' else 'none',
          legend.title = element_text(size = config_num('legend', 'title_fontsize', num('legend_title_size', 8)), family = config_chr('legend', 'fontfamily', font_family)), legend.text = element_text(size = config_num('legend', 'fontsize', num('legend_text_size', 7)), family = config_chr('legend', 'fontfamily', font_family)),
          plot.margin = margin(0, 24, 2, 24))

  title_grob <- if (flag('title_show', FALSE) && nzchar(chr('title', ''))) textGrob(chr('title'), gp = gpar(fontfamily = font_family, fontsize = num('title_size', 13), col = text_color)) else nullGrob()
  legend_show <- config_flag('legend', 'visible', flag('legend_show', TRUE))
  legend_width <- if (legend_show) config_num('legend', 'width', num('legend_panel_width', 2.45)) else 0.05
  legend_position <- config_chr('legend', 'position', chr('legend_position', 'right'))
  legend_extract_position <- if (legend_position %in% c('top', 'bottom')) 'bottom' else 'right'
  bar_without_legend <- summary_plot + theme(legend.position = 'none')
  dot_without_legend <- dot_plot + theme(legend.position = 'none')
  legend_grobs <- list()
  if (legend_show && summary_plot_type != 'bar') {
    summary_legend_source <- if (summary_plot_type %in% c('pie', 'donut')) bar_plot else summary_plot
    bar_legend <- cowplot::get_legend(summary_legend_source + theme(legend.position = legend_extract_position))
    if (!is.null(bar_legend)) legend_grobs[[length(legend_grobs) + 1]] <- bar_legend
  }
  if (legend_show) {
    dot_legend <- cowplot::get_legend(dot_plot + theme(legend.position = legend_extract_position))
    if (!is.null(dot_legend)) legend_grobs[[length(legend_grobs) + 1]] <- dot_legend
  }
  aligned <- cowplot::align_plots(
    hierarchy_plot,
    bar_without_legend,
    dot_without_legend,
    align = 'h',
    axis = 'lr'
  )
  if (length(aligned) != 3L) fail('Failed to align plot panels', 'The shared hierarchy, bar, and dot panels were not created.')
  main_plot <- cowplot::plot_grid(
    aligned[[1]], aligned[[2]], aligned[[3]],
    ncol = 1,
    align = 'v',
    axis = 'lr',
    rel_heights = c(num('hierarchy_height', 1.5), num('count_height', 1.25), num('dot_height', 3.2))
  )
  legend_column <- if (length(legend_grobs)) {
    legend_stack <- do.call(cowplot::plot_grid, c(legend_grobs, list(ncol = 1, align = 'v', rel_heights = rep(1, length(legend_grobs)))))
    grid::grobTree(ggplotGrob(legend_stack), vp = grid::viewport(x = 0.5, y = 0.5, width = 0.94, height = 0.9))
  } else {
    nullGrob()
  }
  main_width <- if (flag('auto_width', TRUE)) 4 + length(cell_order) * num('width_per_cell_type', 0.65) else max(1, num('width', 10) - legend_width)
  combined <- arrangeGrob(
    arrangeGrob(main_plot, top = title_grob, padding = unit(c(4, 4, 4, 4), 'pt')),
    legend_column,
    ncol = 2,
    widths = grid::unit(c(main_width, legend_width), c('null', 'null')),
    padding = unit(c(2, 2, 2, 2), 'pt')
  )

  width <- if (flag('auto_width', TRUE)) main_width + legend_width else num('width', 10)
  legend_height_extra <- if (length(legend_grobs) > 2) 0.8 else if (length(legend_grobs) > 0) 0.35 else 0
  height <- if (flag('auto_height', TRUE)) 4.5 + length(marker_order) * num('height_per_marker', 0.22) + legend_height_extra else num('height', 7)
  dpi <- num('dpi', 300)
  ggsave(file.path(out, 'result.svg'), combined, width = width, height = height, device = grDevices::svg)
  ggsave(file.path(out, 'result.pdf'), combined, width = width, height = height, device = grDevices::cairo_pdf)
  ggsave(file.path(out, 'result.png'), combined, width = width, height = height, dpi = dpi, device = ragg::agg_png)
  config_output <- file.path(out, 'visual_config_used.json')
  writeLines(toJSON(visual_config, auto_unbox = TRUE, pretty = TRUE), config_output)
  figure <- list(plugin = 'hierarchical_marker_panel', version = '1.0.0',
                 data = list(rows = nrow(d), cell_types = cell_order, markers = marker_order,
                             mapping = cols),
                 layers = c('hierarchy_brackets', 'cell_count_bar', 'marker_dot_matrix'),
                 encodings = list(color = 'average_transcript', size = 'pct_expressed', bar_mode = bar_mode,
                                   summary_plot_type = summary_plot_type, bar_fill = if (summary_plot_type == 'bar') 'class' else 'sample'),
                 export = list(width = width, height = height, dpi = dpi,
                               files = c('result.svg', 'result.pdf', 'result.png', 'data_used.csv', 'visual_config_used.json')),
                 layout = list(shared_x_limits = shared_x_limits, aligned_panels = TRUE,
                               summary_plot_type = summary_plot_type, n_clusters = length(cell_order), n_markers = length(marker_order)))
  writeLines(toJSON(figure, auto_unbox = TRUE, pretty = TRUE), file.path(out, 'figure.json'))
  log_msg(sprintf('Done: %d marker rows, %d cell types, %d markers.', nrow(d), length(cell_order), length(marker_order)))
}

tryCatch(main(), error = function(e) fail('Plot generation failed', conditionMessage(e)))
