#!/usr/bin/env Rscript

# BioFigureAI Plot Plugin: Dynamic Venn Diagram
# ------------------------------------------------------------
# Runtime contract:
#   Rscript plot.R --input input.csv --params params.json --output output_dir
#
# Purpose:
#   Draw highly customizable Venn diagrams from element-list files or
#   abundance matrices. 2-5 selected groups are rendered as Venn diagrams;
#   6+ selected groups automatically use a flower Venn layout.

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
  library(VennDiagram)
  library(grid)
  library(gridExtra)
  library(cowplot)
})

option_list <- list(
  make_option(c('--input'), type = 'character', default = NULL,
              help = 'Path to the main input file, usually CSV/TSV/TXT.'),
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
    write_error_and_exit('Input file not found', paste('Input path:', path), 'Please provide a valid input file path.')
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
  if (length(x) == 1 && is.character(x) && grepl(',', x, fixed = TRUE)) {
    x <- strsplit(x, ',', fixed = TRUE)[[1]]
  }
  x <- trimws(as.character(x))
  x[nzchar(x)]
}

as_named_vector <- function(x, default = NULL) {
  if (is.null(x)) return(default)
  if (is.list(x) && !is.data.frame(x)) return(unlist(x))
  if (is.character(x) && length(x) == 1 && grepl(':', x, fixed = TRUE)) {
    entries <- trimws(unlist(strsplit(x, ';', fixed = TRUE), use.names = FALSE))
    out <- character()
    for (entry in entries[nzchar(entries)]) {
      parts <- trimws(strsplit(entry, ':', fixed = TRUE)[[1]])
      if (length(parts) >= 2 && nzchar(parts[1]) && nzchar(parts[2])) out[parts[1]] <- parts[2]
    }
    return(out)
  }
  x
}

coalesce_number <- function(x, default) {
  if (is.null(x) || length(x) == 0 || is.na(x[1])) return(default)
  value <- suppressWarnings(as.numeric(x[1]))
  if (is.na(value)) default else value
}

validate_columns <- function(df, cols) {
  missing_cols <- setdiff(cols, colnames(df))
  if (length(missing_cols) > 0) {
    write_error_and_exit(
      'Required input columns not found',
      paste('Missing columns:', paste(missing_cols, collapse = ', ')),
      'Check groups_include, groups_exclude, group_order, element_id_column, and abundance_group_columns.'
    )
  }
}

compare_values <- function(values, operator, threshold) {
  if (operator == '>') return(values > threshold)
  if (operator == '>=') return(values >= threshold)
  if (operator == '<') return(values < threshold)
  if (operator == '<=') return(values <= threshold)
  if (operator == '==') return(values == threshold)
  if (operator == '!=') return(values != threshold)
  values > threshold
}

palette_colors <- function(n, scheme = 'bold') {
  palettes <- list(
    bold = c('#69A4F9', '#BFE046', '#EDAC2E', '#F2F225', '#D98BC5', '#64C2A6', '#8F7AC8'),
    soft = c('#8DA9C9', '#FEC66D', '#F28E8C', '#A9D6DC', '#9ACDAF', '#C9B3D4', '#E6D65B'),
    publication = c('#4E79A7', '#F28E2B', '#E15759', '#76B7B2', '#59A14F', '#EDC948', '#B07AA1'),
    vivid = c('#3B82F6', '#22C55E', '#F97316', '#EF4444', '#A855F7', '#14B8A6', '#EAB308')
  )
  base <- palettes[[tolower(scheme)]]
  if (is.null(base)) base <- palettes$bold
  rep(base, length.out = n)
}

apply_named_colors <- function(group_names, colors, scheme) {
  base <- palette_colors(length(group_names), scheme)
  names(base) <- group_names
  custom <- as_named_vector(colors, default = NULL)
  if (!is.null(custom)) {
    if (is.null(names(custom)) || any(!nzchar(names(custom)))) {
      custom <- as.character(custom)
      base[seq_len(min(length(base), length(custom)))] <- custom[seq_len(min(length(base), length(custom)))]
    } else {
      for (nm in intersect(names(custom), group_names)) base[nm] <- as.character(custom[[nm]])
    }
  }
  unname(base)
}

detect_input_type <- function(df, params, group_cols) {
  requested <- tolower(trimws(as.character(get_param(params, 'input_type', 'auto'))[1]))
  if (requested %in% c('element', 'list', 'element_list')) return('element')
  if (requested %in% c('abundance', 'matrix', 'count', 'counts')) return('abundance')
  numeric_flags <- vapply(df[group_cols], function(x) all(is.na(x) | !is.na(suppressWarnings(as.numeric(x)))), logical(1))
  if (all(numeric_flags)) 'abundance' else 'element'
}

select_group_columns <- function(df, params) {
  include <- as_string_vector(get_param_any(params, c('groups_include', 'group_columns', 'abundance_group_columns'), NULL))
  exclude <- as_string_vector(get_param(params, 'groups_exclude', NULL))
  order_cols <- as_string_vector(get_param(params, 'group_order', NULL))
  element_id_column <- get_param_any(params, c('element_id_column', 'id_column', 'row_label_column'), colnames(df)[1])
  requested_type <- tolower(trimws(as.character(get_param(params, 'input_type', 'auto'))[1]))

  if (length(include) == 0) {
    candidate_numeric <- if (ncol(df) > 1) {
      vapply(df[-1], function(x) all(is.na(x) | !is.na(suppressWarnings(as.numeric(x)))), logical(1))
    } else {
      logical()
    }
    if (requested_type %in% c('element', 'list', 'element_list')) {
      include <- colnames(df)
    } else if (requested_type %in% c('abundance', 'matrix', 'count', 'counts')) {
      include <- setdiff(colnames(df), element_id_column)
    } else if (length(candidate_numeric) > 0 && all(candidate_numeric)) {
      include <- colnames(df)[-1]
    } else {
      include <- colnames(df)
    }
  }
  validate_columns(df, include)
  if (length(exclude) > 0) include <- setdiff(include, exclude)
  if (length(order_cols) > 0) include <- c(intersect(order_cols, include), setdiff(include, order_cols))
  if (length(include) < 1) write_error_and_exit('No groups selected', '', 'Select at least one group column.')

  max_groups <- coalesce_number(get_param(params, 'max_groups', Inf), Inf)
  if (is.finite(max_groups) && length(include) > max_groups) include <- include[seq_len(max_groups)]
  include
}

sets_from_element_file <- function(df, group_cols) {
  sets <- list()
  for (col in group_cols) {
    values <- trimws(as.character(df[[col]]))
    values <- values[!is.na(values) & nzchar(values)]
    sets[[col]] <- unique(values)
  }
  sets
}

sets_from_abundance_file <- function(df, params, group_cols) {
  id_col <- get_param_any(params, c('element_id_column', 'id_column', 'row_label_column'), colnames(df)[1])
  validate_columns(df, c(id_col, group_cols))
  ids <- trimws(as.character(df[[id_col]]))
  default_operator <- as.character(get_param_any(params, c('abundance_operator', 'threshold_operator'), '>'))[1]
  default_threshold <- coalesce_number(get_param_any(params, c('abundance_threshold', 'threshold'), 0), 0)
  group_operators <- as_named_vector(get_param(params, 'group_operators', NULL), default = NULL)
  group_thresholds <- as_named_vector(get_param(params, 'group_thresholds', NULL), default = NULL)

  sets <- list()
  for (col in group_cols) {
    values <- suppressWarnings(as.numeric(df[[col]]))
    op <- default_operator
    threshold <- default_threshold
    if (!is.null(group_operators) && !is.null(group_operators[[col]])) op <- as.character(group_operators[[col]])[1]
    if (!is.null(group_thresholds) && !is.null(group_thresholds[[col]])) {
      threshold <- suppressWarnings(as.numeric(group_thresholds[[col]]))
      if (is.na(threshold)) threshold <- default_threshold
    }
    keep <- compare_values(values, op, threshold)
    keep[is.na(keep)] <- FALSE
    sets[[col]] <- unique(ids[keep & nzchar(ids)])
  }
  sets
}

build_subset_table <- function(sets) {
  group_names <- names(sets)
  all_elements <- sort(unique(unlist(sets, use.names = FALSE)))
  total <- length(all_elements)
  if (total == 0) total <- 1
  rows <- list()
  long_rows <- list()
  idx <- 1
  long_idx <- 1
  for (bits in seq_len(2 ^ length(group_names) - 1)) {
    present <- as.logical(as.integer(intToBits(bits))[seq_along(group_names)])
    active_groups <- group_names[present]
    absent_groups <- group_names[!present]
    exact <- all_elements
    for (grp in active_groups) exact <- intersect(exact, sets[[grp]])
    for (grp in absent_groups) exact <- setdiff(exact, sets[[grp]])
    exact <- sort(unique(exact))
    subset_id <- paste0(as.integer(present), collapse = '')
    subset_name <- paste(active_groups, collapse = '_AND_')
    rows[[idx]] <- data.frame(
      subset_id = subset_id,
      subset_name = subset_name,
      groups = paste(active_groups, collapse = ';'),
      count = length(exact),
      percent = round(length(exact) / total * 100, 4),
      elements = paste(exact, collapse = ';'),
      stringsAsFactors = FALSE
    )
    idx <- idx + 1
    if (length(exact) > 0) {
      for (element in exact) {
        long_rows[[long_idx]] <- data.frame(
          subset_id = subset_id,
          subset_name = subset_name,
          groups = paste(active_groups, collapse = ';'),
          element = element,
          stringsAsFactors = FALSE
        )
        long_idx <- long_idx + 1
      }
    }
  }
  subset_table <- if (length(rows) > 0) do.call(rbind, rows) else data.frame()
  long_table <- if (length(long_rows) > 0) do.call(rbind, long_rows) else data.frame()
  list(summary = subset_table, long = long_table, universe_size = length(all_elements))
}

make_bar_plot <- function(set_sizes, group_colors, params) {
  bar_df <- data.frame(
    group = factor(names(set_sizes), levels = names(set_sizes)),
    count = as.numeric(set_sizes),
    color = group_colors,
    stringsAsFactors = FALSE
  )
  show_bar_values <- as_bool(get_param(params, 'bar_show_values', TRUE), TRUE)
  bar_label_size <- coalesce_number(get_param(params, 'bar_label_size', 3.8), 3.8)
  bar_width <- coalesce_number(get_param(params, 'bar_width', 0.62), 0.62)
  p <- ggplot(bar_df, aes(x = group, y = count, fill = group)) +
    geom_col(width = bar_width, color = get_param(params, 'bar_border_color', NA)) +
    scale_fill_manual(values = stats::setNames(group_colors, names(set_sizes)), guide = 'none') +
    scale_y_continuous(expand = expansion(mult = c(0, 0.16))) +
    labs(x = NULL, y = get_param(params, 'bar_y_title', 'Elements')) +
    theme_classic(base_family = get_param(params, 'font_family', 'sans')) +
    theme(
      axis.text.x = element_text(size = coalesce_number(get_param(params, 'bar_axis_text_size', 10), 10),
                                 color = get_param(params, 'bar_axis_text_color', '#222222'),
                                 angle = coalesce_number(get_param(params, 'bar_label_angle', 0), 0),
                                 hjust = 0.5),
      axis.text.y = element_text(size = coalesce_number(get_param(params, 'bar_axis_text_size', 10), 10),
                                 color = get_param(params, 'bar_axis_text_color', '#222222')),
      axis.title.y = element_text(size = coalesce_number(get_param(params, 'bar_axis_title_size', 11), 11),
                                  color = get_param(params, 'bar_axis_title_color', '#222222')),
      plot.margin = margin(5, 16, 5, 16)
    )
  if (show_bar_values) {
    p <- p + geom_text(aes(label = count), vjust = -0.35, size = bar_label_size,
                       family = get_param(params, 'font_family', 'sans'),
                       color = get_param(params, 'bar_value_color', '#222222'))
  }
  p
}

make_venn_grob <- function(sets, group_colors, params) {
  count_mode <- tolower(as.character(get_param(params, 'count_mode', 'raw'))[1])
  show_counts <- as_bool(get_param(params, 'show_counts', TRUE), TRUE)
  show_percent <- as_bool(get_param(params, 'show_percent', FALSE), FALSE)
  print_mode <- character()
  if (show_counts) print_mode <- c(print_mode, 'raw')
  if (show_percent) print_mode <- c(print_mode, 'percent')
  if (length(print_mode) == 0) print_mode <- 'none'
  if (count_mode %in% c('raw', 'percent') && length(print_mode) == 0) print_mode <- count_mode

  label_show <- as_bool(get_param(params, 'show_group_names', TRUE), TRUE)
  group_labels <- if (label_show) names(sets) else rep('', length(sets))
  line_type <- as.character(get_param(params, 'border_lty', get_param(params, 'border_type', 'solid')))[1]
  title_text <- if (as_bool(get_param(params, 'title_show', TRUE), TRUE)) get_param(params, 'title', 'Venn diagram') else NULL

  args <- list(
    x = sets,
    filename = NULL,
    imagetype = 'png',
    fill = group_colors,
    alpha = coalesce_number(get_param(params, 'fill_alpha', get_param(params, 'opacity', 0.62)), 0.62),
    col = get_param(params, 'border_color', '#FFFFFF'),
    lwd = coalesce_number(get_param(params, 'border_width', 2.2), 2.2),
    lty = line_type,
    cex = coalesce_number(get_param(params, 'count_cex', get_param(params, 'count_size', 1.25)), 1.25),
    fontface = get_param(params, 'count_fontface', 'plain'),
    fontfamily = get_param(params, 'font_family', 'sans'),
    cat.cex = coalesce_number(get_param(params, 'group_name_cex', get_param(params, 'group_name_size', 1.35)), 1.35),
    cat.fontface = get_param(params, 'group_name_fontface', 'bold'),
    cat.fontfamily = get_param(params, 'font_family', 'sans'),
    cat.col = get_param(params, 'group_name_color', '#222222'),
    category.names = group_labels,
    print.mode = print_mode,
    disable.logging = TRUE,
    margin = coalesce_number(get_param(params, 'plot_margin', 0.08), 0.08),
    main = title_text,
    main.cex = coalesce_number(get_param(params, 'title_cex', get_param(params, 'title_size', 1.45)), 1.45),
    main.fontface = get_param(params, 'title_fontface', 'bold'),
    main.fontfamily = get_param(params, 'font_family', 'sans')
  )
  if (length(sets) == 1) {
    args$area.vector <- length(sets[[1]])
  }
  grobs <- NULL
  invisible(capture.output(
    capture.output({
      grobs <- do.call(VennDiagram::venn.diagram, args)
    }, type = 'message'),
    type = 'output'
  ))
  if (inherits(grobs, 'grob')) grobs else grid::grobTree(children = do.call(grid::gList, grobs))
}

ellipse_polygon <- function(cx, cy, longitudinal_radius, transverse_radius, angle, id, n = 160) {
  theta <- seq(0, 2 * pi, length.out = n)
  x0 <- longitudinal_radius * cos(theta)
  y0 <- transverse_radius * sin(theta)
  ca <- cos(angle)
  sa <- sin(angle)
  data.frame(
    x = cx + x0 * ca - y0 * sa,
    y = cy + x0 * sa + y0 * ca,
    group = id,
    stringsAsFactors = FALSE
  )
}

make_flower_plot <- function(sets, group_colors, subset_table, params) {
  group_names <- names(sets)
  n <- length(group_names)
  angles <- seq(pi / 2, pi / 2 - 2 * pi + 2 * pi / n, length.out = n)
  petal_rx <- coalesce_number(get_param(params, 'petal_width', 0.38), 0.38)
  petal_ry <- coalesce_number(get_param(params, 'petal_length', 0.94), 0.94)
  inner_gap <- coalesce_number(get_param(params, 'flower_inner_gap', -0.04), -0.04)
  radius <- coalesce_number(get_param(params, 'flower_radius', petal_ry + inner_gap), petal_ry + inner_gap)
  outer_distance <- radius + petal_ry
  label_distance <- coalesce_number(get_param(params, 'flower_label_distance', outer_distance + 0.34), outer_distance + 0.34)
  count_distance <- coalesce_number(get_param(params, 'flower_count_distance', radius + petal_ry * 0.18), radius + petal_ry * 0.18)

  petal_df <- do.call(rbind, lapply(seq_along(group_names), function(i) {
    cx <- radius * cos(angles[i])
    cy <- radius * sin(angles[i])
    ellipse_polygon(cx, cy, petal_ry, petal_rx, angles[i], group_names[i])
  }))
  petal_df$group <- factor(petal_df$group, levels = group_names)

  set_sizes <- vapply(sets, length, integer(1))
  exact_only <- subset_table$count[match(vapply(seq_along(group_names), function(i) {
    paste0(as.integer(seq_along(group_names) == i), collapse = '')
  }, character(1)), subset_table$subset_id)]
  exact_only[is.na(exact_only)] <- 0
  count_mode <- tolower(as.character(get_param(params, 'flower_count_mode', 'exclusive'))[1])
  petal_counts <- if (count_mode %in% c('set_size', 'total')) set_sizes else exact_only

  text_df <- data.frame(
    group = group_names,
    x = count_distance * cos(angles),
    y = count_distance * sin(angles),
    count = as.integer(petal_counts),
    label_x = label_distance * cos(angles),
    label_y = label_distance * sin(angles),
    label_angle = ifelse(cos(angles) < -0.1, angles * 180 / pi + 180, angles * 180 / pi),
    stringsAsFactors = FALSE
  )
  all_id <- paste(rep(1, n), collapse = '')
  center_count <- subset_table$count[match(all_id, subset_table$subset_id)]
  if (length(center_count) == 0 || is.na(center_count)) center_count <- length(Reduce(intersect, sets))
  center_label <- if (as_bool(get_param(params, 'show_percent', FALSE), FALSE)) {
    total <- max(1, length(unique(unlist(sets, use.names = FALSE))))
    paste0(center_count, '\n(', round(center_count / total * 100, coalesce_number(get_param(params, 'percent_digits', 2), 2)), '%)')
  } else {
    as.character(center_count)
  }

  p <- ggplot() +
    geom_polygon(data = petal_df, aes(x = x, y = y, group = group, fill = group),
                 color = get_param(params, 'border_color', '#FFFFFF'),
                 linewidth = coalesce_number(get_param(params, 'border_width', 2.2), 2.2),
                 linetype = get_param(params, 'border_lty', get_param(params, 'border_type', 'solid')),
                 alpha = coalesce_number(get_param(params, 'fill_alpha', get_param(params, 'opacity', 0.78)), 0.78)) +
    scale_fill_manual(values = stats::setNames(group_colors, group_names), name = get_param(params, 'legend_title', 'Groups')) +
    coord_equal(clip = 'off') +
    theme_void(base_family = get_param(params, 'font_family', 'sans')) +
    theme(
      legend.position = if (as_bool(get_param(params, 'legend_show', FALSE), FALSE)) get_param(params, 'legend_position', 'right') else 'none',
      legend.title = element_text(size = coalesce_number(get_param(params, 'legend_title_size', 11), 11),
                                  color = get_param(params, 'legend_title_color', '#222222')),
      legend.text = element_text(size = coalesce_number(get_param(params, 'legend_text_size', 10), 10),
                                 color = get_param(params, 'legend_text_color', '#222222')),
      plot.title = element_text(size = coalesce_number(get_param(params, 'title_size', 18), 18),
                                face = get_param(params, 'title_fontface', 'bold'),
                                color = get_param(params, 'title_color', '#222222'),
                                hjust = coalesce_number(get_param(params, 'title_hjust', 0.5), 0.5)),
      plot.margin = margin(20, 40, 20, 40)
    )

  if (as_bool(get_param(params, 'show_counts', TRUE), TRUE)) {
    p <- p + geom_text(data = text_df, aes(x = x, y = y, label = count),
                       family = get_param(params, 'font_family', 'sans'),
                       fontface = get_param(params, 'count_fontface', 'plain'),
                       size = coalesce_number(get_param(params, 'flower_count_size', get_param(params, 'count_size', 5.2)), 5.2),
                       color = get_param(params, 'count_color', '#222222'))
  }
  if (as_bool(get_param(params, 'show_group_names', TRUE), TRUE)) {
    p <- p + geom_text(data = text_df, aes(x = label_x, y = label_y, label = group, angle = label_angle),
                       family = get_param(params, 'font_family', 'sans'),
                       fontface = get_param(params, 'group_name_fontface', 'bold'),
                       size = coalesce_number(get_param(params, 'flower_group_name_size', get_param(params, 'group_name_size', 6.2)), 6.2),
                       color = get_param(params, 'group_name_color', '#222222'))
  }
  if (as_bool(get_param(params, 'center_show', TRUE), TRUE)) {
    p <- p +
      annotate('point', x = 0, y = 0, size = coalesce_number(get_param(params, 'center_size', 24), 24),
               shape = 21, fill = get_param(params, 'center_fill', '#FFFFFF'),
               color = get_param(params, 'center_border_color', '#444444'),
               stroke = coalesce_number(get_param(params, 'center_border_width', 1.1), 1.1)) +
      annotate('text', x = 0, y = 0, label = center_label,
               family = get_param(params, 'font_family', 'sans'),
               fontface = get_param(params, 'center_fontface', 'plain'),
               size = coalesce_number(get_param(params, 'center_count_size', get_param(params, 'count_size', 4.4)), 4.4),
               color = get_param(params, 'center_count_color', '#222222'))
  }
  if (as_bool(get_param(params, 'title_show', TRUE), TRUE)) p <- p + labs(title = get_param(params, 'title', 'Flower Venn diagram'))
  p
}

compose_output_grob <- function(main_grob, bar_plot, params) {
  show_bar <- as_bool(get_param(params, 'show_bar_chart', FALSE), FALSE)
  if (!show_bar) return(main_grob)
  bar_height_ratio <- coalesce_number(get_param(params, 'bar_height_ratio', 0.28), 0.28)
  gridExtra::arrangeGrob(
    main_grob,
    ggplotGrob(bar_plot),
    ncol = 1,
    heights = c(1, bar_height_ratio)
  )
}

save_grob_outputs <- function(grob, output_dir, width, height, dpi) {
  svg_file <- file.path(output_dir, 'result.svg')
  pdf_file <- file.path(output_dir, 'result.pdf')
  png_file <- file.path(output_dir, 'result.png')

  svglite::svglite(svg_file, width = width, height = height)
  grid.newpage()
  grid.draw(grob)
  dev.off()

  pdf(pdf_file, width = width, height = height, useDingbats = FALSE)
  grid.newpage()
  grid.draw(grob)
  dev.off()

  png(png_file, width = width, height = height, units = 'in', res = dpi, type = 'cairo')
  grid.newpage()
  grid.draw(grob)
  dev.off()
}

main <- function() {
  if (is.null(output_dir)) write_error_and_exit('Missing --output argument')
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  if (file.exists(file.path(output_dir, 'run.log'))) file.remove(file.path(output_dir, 'run.log'))
  old_outputs <- file.path(output_dir, c(
    'error.json', 'result.svg', 'result.pdf', 'result.png', 'figure.json',
    'subsets.csv', 'subset_elements_long.csv', 'set_sizes.csv'
  ))
  old_outputs <- old_outputs[file.exists(old_outputs)]
  if (length(old_outputs) > 0) unlink(old_outputs)
  write_log('Starting dynamic Venn diagram plugin.')

  params <- list()
  if (!is.null(params_file) && file.exists(params_file)) {
    params <- jsonlite::fromJSON(params_file, simplifyVector = FALSE)
  }
  df <- read_table_auto(input_file)
  if (ncol(df) < 1) write_error_and_exit('Input table is empty')

  group_cols <- select_group_columns(df, params)
  input_type <- detect_input_type(df, params, group_cols)
  write_log(paste('Detected input type:', input_type))

  sets <- if (input_type == 'abundance') {
    sets_from_abundance_file(df, params, group_cols)
  } else {
    sets_from_element_file(df, group_cols)
  }
  sets <- sets[vapply(sets, function(x) length(x) > 0, logical(1))]
  if (length(sets) == 0) write_error_and_exit('No non-empty sets after filtering', '', 'Relax thresholds or choose groups with elements.')

  group_names <- names(sets)
  if (length(group_names) > 7 && tolower(as.character(get_param(params, 'plot_mode', 'auto'))[1]) %in% c('venn', 'auto')) {
    write_log('More than 7 groups selected. Flower mode will show all groups, but exact subset count grows quickly.')
  }
  group_colors <- apply_named_colors(group_names, get_param_any(params, c('set_colors', 'group_colors'), NULL), get_param(params, 'palette_scheme', 'bold'))
  set_sizes <- vapply(sets, length, integer(1))
  subset_data <- build_subset_table(sets)

  write.csv(subset_data$summary, file.path(output_dir, 'subsets.csv'), row.names = FALSE)
  write.csv(subset_data$long, file.path(output_dir, 'subset_elements_long.csv'), row.names = FALSE)
  write.csv(data.frame(group = group_names, count = as.integer(set_sizes), color = group_colors, stringsAsFactors = FALSE),
            file.path(output_dir, 'set_sizes.csv'), row.names = FALSE)

  mode <- tolower(as.character(get_param(params, 'plot_mode', 'auto'))[1])
  if (mode == 'auto') mode <- if (length(sets) <= 5) 'venn' else 'flower'
  if (mode == 'venn' && length(sets) > 5) {
    write_log('VennDiagram supports up to five sets in this plugin. Falling back to flower mode.')
    mode <- 'flower'
  }

  bar_plot <- make_bar_plot(set_sizes, group_colors, params)
  if (mode == 'flower') {
    main_plot <- make_flower_plot(sets, group_colors, subset_data$summary, params)
    main_grob <- ggplotGrob(main_plot)
  } else {
    main_grob <- make_venn_grob(sets, group_colors, params)
  }

  combined <- compose_output_grob(main_grob, bar_plot, params)
  width <- coalesce_number(get_param(params, 'width', ifelse(mode == 'flower', 8.2, 7.2)), ifelse(mode == 'flower', 8.2, 7.2))
  height <- coalesce_number(get_param(params, 'height', ifelse(as_bool(get_param(params, 'show_bar_chart', FALSE), FALSE), 7.8, 6.6)), ifelse(as_bool(get_param(params, 'show_bar_chart', FALSE), FALSE), 7.8, 6.6))
  dpi <- coalesce_number(get_param(params, 'dpi', 300), 300)
  save_grob_outputs(combined, output_dir, width, height, dpi)

  figure <- list(
    plot_type = 'dynamic_venn_diagram',
    input_file = normalizePath(input_file, mustWork = FALSE),
    input_type = input_type,
    mode = mode,
    groups = group_names,
    group_count = length(group_names),
    set_sizes = as.list(set_sizes),
    universe_size = subset_data$universe_size,
    style = list(
      palette_scheme = get_param(params, 'palette_scheme', 'bold'),
      set_colors = as.list(stats::setNames(group_colors, group_names)),
      fill_alpha = coalesce_number(get_param(params, 'fill_alpha', get_param(params, 'opacity', ifelse(mode == 'flower', 0.78, 0.62))), ifelse(mode == 'flower', 0.78, 0.62)),
      border_color = get_param(params, 'border_color', '#FFFFFF'),
      border_width = coalesce_number(get_param(params, 'border_width', 2.2), 2.2),
      show_counts = as_bool(get_param(params, 'show_counts', TRUE), TRUE),
      show_percent = as_bool(get_param(params, 'show_percent', FALSE), FALSE),
      show_bar_chart = as_bool(get_param(params, 'show_bar_chart', FALSE), FALSE)
    ),
    outputs = list(
      svg = 'result.svg',
      pdf = 'result.pdf',
      png = 'result.png',
      subsets = 'subsets.csv',
      subset_elements = 'subset_elements_long.csv',
      set_sizes = 'set_sizes.csv',
      log = 'run.log'
    )
  )
  writeLines(jsonlite::toJSON(figure, auto_unbox = TRUE, pretty = TRUE), file.path(output_dir, 'figure.json'))
  write_log('Completed dynamic Venn diagram plugin.')
}

tryCatch(main(), error = function(e) {
  write_error_and_exit('Dynamic Venn diagram failed', conditionMessage(e), 'Check input format, selected groups, and params.json.')
})
