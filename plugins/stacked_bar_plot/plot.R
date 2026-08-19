#!/usr/bin/env Rscript

# BioFigureAI Plot Plugin: Stacked Bar Plot (ChiPlot-style)
# ------------------------------------------------------------
# Highly customizable stacked / dodged bar composition chart.
# Matches ChiPlot-style controls: canvas, x/y axes (ticks, grid,
# labels, text style), title, background, bar style/orientation,
# per-category colors, bar text, and legend layout.
#
# Runtime contract:
#   Rscript plot.R --input input.csv --params params.json --output output_dir
#
# Input modes:
#   wide  - sample/id column + optional group + numeric stack columns
#   long  - sample + group + stack category + value columns

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
  library(scales)
})

option_list <- list(
  make_option(c('--input'), type = 'character', default = NULL,
              help = 'CSV/TSV/TXT table (wide abundance matrix or long table).'),
  make_option(c('--params'), type = 'character', default = NULL,
              help = 'Path to params.json.'),
  make_option(c('--output'), type = 'character', default = NULL,
              help = 'Output directory.')
)

opt <- parse_args(OptionParser(option_list = option_list))
input_file <- opt$input
params_file <- opt$params
output_dir <- opt$output

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

write_log <- function(message) {
  log_file <- file.path(output_dir, 'run.log')
  timestamp <- format(Sys.time(), '%Y-%m-%d %H:%M:%S')
  cat(sprintf('[%s] %s\n', timestamp, message), file = log_file, append = TRUE)
}

write_error_and_exit <- function(error, detail = NULL, suggestion = NULL, status = 1) {
  if (is.null(output_dir) || !nzchar(output_dir)) output_dir <<- getwd()
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  error_obj <- list(error = error, detail = detail %||% '', suggestion = suggestion %||% '')
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

as_string_vector <- function(x, default = character()) {
  if (is.null(x)) return(default)
  if (is.list(x) && !is.data.frame(x)) x <- unlist(x, use.names = FALSE)
  if (length(x) == 1 && is.character(x) && grepl(',', x, fixed = TRUE)) {
    x <- strsplit(x, ',', fixed = TRUE)[[1]]
  }
  x <- trimws(as.character(x))
  x[nzchar(x)]
}

as_named_character <- function(x, default = character()) {
  if (is.null(x)) return(default)
  vals <- unlist(x, use.names = TRUE)
  if (length(vals) == 0) return(default)
  out <- as.character(vals)
  names(out) <- names(vals)
  out
}

face_from_style <- function(weight = 'normal', style = 'normal') {
  weight <- tolower(as.character(weight %||% 'normal')[1])
  style <- tolower(as.character(style %||% 'normal')[1])
  if (weight %in% c('bold', 'bolder', '700', '800', '900') && style %in% c('italic', 'oblique')) return('bold.italic')
  if (weight %in% c('bold', 'bolder', '700', '800', '900')) return('bold')
  if (style %in% c('italic', 'oblique')) return('italic')
  'plain'
}

default_palette <- function(n) {
  base <- c('#66C2A5', '#FC8D62', '#8DA0CB', '#E78AC3', '#A6D854', '#FFD92F',
            '#E5C494', '#B3B3B3', '#1B9E77', '#D95F02', '#7570B3', '#E7298A',
            '#66A61E', '#E6AB02', '#A6761D', '#666666')
  if (n <= length(base)) return(base[seq_len(n)])
  grDevices::colorRampPalette(base)(n)
}

resolve_palette <- function(n, params, categories) {
  color_map <- as_named_character(get_param_any(params, c('category_colors', 'stack_colors', 'set_colors', 'color_map'), NULL))
  if (length(color_map) > 0) {
    cols <- rep(NA_character_, n)
    names(cols) <- categories
    hit <- intersect(categories, names(color_map))
    cols[hit] <- color_map[hit]
    missing <- categories[is.na(cols)]
    if (length(missing) > 0) cols[missing] <- default_palette(length(missing))
    return(unname(cols[categories]))
  }

  gradient <- as_string_vector(get_param_any(params, c('color_gradient', 'gradient_colors'), NULL))
  if (length(gradient) >= 2) {
    return(grDevices::colorRampPalette(gradient)(n))
  }

  palette_name <- get_param_any(params, c('palette', 'palette_scheme', 'color_palette'), NULL)
  if (!is.null(palette_name) && nzchar(as.character(palette_name)[1])) {
    name <- as.character(palette_name)[1]
    if (requireNamespace('RColorBrewer', quietly = TRUE)) {
      maxn <- RColorBrewer::brewer.pal.info
      if (name %in% rownames(maxn)) {
        k <- min(n, maxn[name, 'maxcolors'])
        cols <- RColorBrewer::brewer.pal(max(3, k), name)
        if (n <= length(cols)) return(cols[seq_len(n)])
        return(grDevices::colorRampPalette(cols)(n))
      }
    }
    if (name %in% c('npg', 'aaas', 'jco', 'lancet', 'nejm', 'igv', 'ucscgb')) {
      if (requireNamespace('ggsci', quietly = TRUE)) {
        pal_fun <- switch(name,
          npg = ggsci::pal_npg(),
          aaas = ggsci::pal_aaas(),
          jco = ggsci::pal_jco(),
          lancet = ggsci::pal_lancet(),
          nejm = ggsci::pal_nejm(),
          igv = ggsci::pal_igv(),
          ucscgb = ggsci::pal_ucscgb(),
          NULL
        )
        if (!is.null(pal_fun)) return(pal_fun(n))
      }
    }
  }

  colors <- as_string_vector(get_param_any(params, c('colors', 'color'), NULL))
  if (length(colors) > 0) {
    if (length(colors) >= n) return(colors[seq_len(n)])
    return(grDevices::colorRampPalette(colors)(n))
  }

  default_palette(n)
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
  if (requireNamespace('svglite', quietly = TRUE)) {
    draw_with_retry(function(w, h) svglite::svglite(file.path(output_dir, 'result.svg'), width = w, height = h))
  } else {
    draw_with_retry(function(w, h) grDevices::svg(file.path(output_dir, 'result.svg'), width = w, height = h))
  }
  if (capabilities('cairo')) {
    draw_with_retry(function(w, h) grDevices::cairo_pdf(file.path(output_dir, 'result.pdf'), width = w, height = h, onefile = TRUE))
    draw_with_retry(function(w, h) png(file.path(output_dir, 'result.png'), width = w, height = h, units = 'in', res = dpi, type = 'cairo'))
  } else {
    draw_with_retry(function(w, h) grDevices::pdf(file.path(output_dir, 'result.pdf'), width = w, height = h, onefile = TRUE))
    draw_with_retry(function(w, h) png(file.path(output_dir, 'result.png'), width = w, height = h, units = 'in', res = dpi))
  }
}

# ------------------------------------------------------------
# Validate runtime inputs
# ------------------------------------------------------------
if (is.null(input_file)) write_error_and_exit('Missing --input argument')
if (is.null(params_file) || !file.exists(params_file)) {
  write_error_and_exit('Params file not found', paste('Params path:', params_file),
                       'Backend should generate params.json and pass it through --params.')
}
if (is.null(output_dir)) write_error_and_exit('Missing --output argument')
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Clean stale error.json from previous failed runs
error_path <- file.path(output_dir, 'error.json')
if (file.exists(error_path)) file.remove(error_path)

write_log('Plugin stacked_bar_plot started.')

params <- tryCatch(
  jsonlite::fromJSON(params_file, simplifyVector = TRUE, simplifyDataFrame = FALSE),
  error = function(e) {
    write_error_and_exit('Failed to parse params.json', conditionMessage(e),
                         'Please make sure params.json is valid JSON.')
  }
)

df <- read_table_auto(input_file)
write_log(sprintf('Loaded input with %s rows and %s columns.', nrow(df), ncol(df)))

# ------------------------------------------------------------
# Build long data for plotting
# ------------------------------------------------------------

input_mode <- tolower(as.character(get_param(params, 'input_mode', 'auto')[1]))

sample_col <- get_param_any(params, c('sample_column', 'id_column', 'row_id_column', 'row_label_column'), NULL)
group_col <- get_param_any(params, c('group_column', 'group_by', 'facet_column'), NULL)
stack_col <- get_param_any(params, c('stack_column', 'category_column', 'fill_column', 'color_column'), NULL)
value_col <- get_param_any(params, c('value_column', 'abundance_column', 'count_column'), NULL)

# Auto-detect mode
if (identical(input_mode, 'auto')) {
  if (!is.null(stack_col) && !is.null(value_col) && stack_col %in% colnames(df) && value_col %in% colnames(df)) {
    input_mode <- 'long'
  } else {
    input_mode <- 'wide'
  }
}

if (identical(input_mode, 'long')) {
  if (is.null(sample_col) || !sample_col %in% colnames(df)) {
    sample_col <- colnames(df)[1]
  }
  if (is.null(stack_col) || !stack_col %in% colnames(df)) {
    write_error_and_exit('stack_column not found', paste('Available:', paste(colnames(df), collapse = ', ')),
                         'Set stack_column for long-format input.')
  }
  if (is.null(value_col) || !value_col %in% colnames(df)) {
    write_error_and_exit('value_column not found', paste('Available:', paste(colnames(df), collapse = ', ')),
                         'Set value_column for long-format input.')
  }
  plot_df <- data.frame(
    sample = as.character(df[[sample_col]]),
    group = if (!is.null(group_col) && group_col %in% colnames(df)) as.character(df[[group_col]]) else as.character(df[[sample_col]]),
    category = as.character(df[[stack_col]]),
    value = suppressWarnings(as.numeric(df[[value_col]])),
    stringsAsFactors = FALSE
  )
} else {
  # wide mode
  if (is.null(sample_col) || !sample_col %in% colnames(df)) {
    sample_col <- colnames(df)[1]
  }
  if (!sample_col %in% colnames(df)) {
    write_error_and_exit('sample_column not found', paste('Missing:', sample_col),
                         'Set sample_column to the sample/id column.')
  }

  reserved <- c(sample_col)
  if (!is.null(group_col) && group_col %in% colnames(df)) reserved <- c(reserved, group_col)

  value_columns <- as_string_vector(get_param_any(params, c('value_columns', 'stack_columns', 'category_columns', 'columns_include'), NULL))
  columns_exclude <- as_string_vector(get_param_any(params, c('columns_exclude', 'stack_columns_exclude'), NULL))

  candidates <- setdiff(colnames(df), reserved)
  if (length(value_columns) > 0) {
    candidates <- intersect(value_columns, candidates)
  } else {
    # prefer numeric columns
    numeric_like <- candidates[vapply(df[candidates], function(x) {
      suppressWarnings(sum(is.finite(as.numeric(x)))) > 0
    }, logical(1))]
    if (length(numeric_like) > 0) candidates <- numeric_like
  }
  if (length(columns_exclude) > 0) candidates <- setdiff(candidates, columns_exclude)

  if (length(candidates) < 1) {
    write_error_and_exit('No stack value columns found',
                         paste('Columns:', paste(colnames(df), collapse = ', ')),
                         'Provide numeric stack columns or set value_columns.')
  }

  samples_include <- as_string_vector(get_param_any(params, c('samples_include', 'rows_include'), NULL))
  samples_exclude <- as_string_vector(get_param_any(params, c('samples_exclude', 'rows_exclude'), NULL))
  keep_idx <- seq_len(nrow(df))
  sample_ids <- as.character(df[[sample_col]])
  if (length(samples_include) > 0) keep_idx <- which(sample_ids %in% samples_include)
  if (length(samples_exclude) > 0) keep_idx <- setdiff(keep_idx, which(sample_ids %in% samples_exclude))
  if (length(keep_idx) < 1) {
    write_error_and_exit('No samples left after filtering', '', 'Relax samples_include/samples_exclude.')
  }
  df <- df[keep_idx, , drop = FALSE]

  groups <- if (!is.null(group_col) && group_col %in% colnames(df)) {
    as.character(df[[group_col]])
  } else {
    as.character(df[[sample_col]])
  }

  long_list <- lapply(candidates, function(col) {
    data.frame(
      sample = as.character(df[[sample_col]]),
      group = groups,
      category = col,
      value = suppressWarnings(as.numeric(df[[col]])),
      stringsAsFactors = FALSE
    )
  })
  plot_df <- do.call(rbind, long_list)
}

plot_df$value[!is.finite(plot_df$value)] <- 0
plot_df$value[plot_df$value < 0] <- 0

# Category / group / sample filters
categories_include <- as_string_vector(get_param_any(params, c('categories_include', 'stack_include'), NULL))
categories_exclude <- as_string_vector(get_param_any(params, c('categories_exclude', 'stack_exclude'), NULL))
if (length(categories_include) > 0) plot_df <- plot_df[plot_df$category %in% categories_include, , drop = FALSE]
if (length(categories_exclude) > 0) plot_df <- plot_df[!plot_df$category %in% categories_exclude, , drop = FALSE]

groups_include <- as_string_vector(get_param_any(params, c('groups_include'), NULL))
groups_exclude <- as_string_vector(get_param_any(params, c('groups_exclude'), NULL))
if (length(groups_include) > 0) plot_df <- plot_df[plot_df$group %in% groups_include, , drop = FALSE]
if (length(groups_exclude) > 0) plot_df <- plot_df[!plot_df$group %in% groups_exclude, , drop = FALSE]

if (nrow(plot_df) < 1) {
  write_error_and_exit('No rows left to plot after filtering', '',
                       'Check include/exclude filters and input columns.')
}

# Normalize mode: absolute / percent / proportion
value_mode <- tolower(as.character(get_param_any(params, c('value_mode', 'stat_type', 'normalize'), 'absolute')[1]))
if (value_mode %in% c('percent', 'percentage', 'pct', '%')) {
  plot_df$value <- ave(plot_df$value, plot_df$sample, FUN = function(x) {
    s <- sum(x, na.rm = TRUE)
    if (!is.finite(s) || s <= 0) return(rep(0, length(x)))
    100 * x / s
  })
} else if (value_mode %in% c('proportion', 'relative', 'frac', 'fraction')) {
  plot_df$value <- ave(plot_df$value, plot_df$sample, FUN = function(x) {
    s <- sum(x, na.rm = TRUE)
    if (!is.finite(s) || s <= 0) return(rep(0, length(x)))
    x / s
  })
}

# Order control
group_order <- as_string_vector(get_param(params, 'group_order', NULL))
sample_order <- as_string_vector(get_param_any(params, c('sample_order', 'row_order'), NULL))
category_order <- as_string_vector(get_param_any(params, c('category_order', 'stack_order', 'legend_order'), NULL))

if (length(group_order) > 0) {
  plot_df$group <- factor(plot_df$group, levels = unique(c(group_order, unique(plot_df$group))))
} else {
  plot_df$group <- factor(plot_df$group, levels = unique(plot_df$group))
}

if (length(sample_order) > 0) {
  plot_df$sample <- factor(plot_df$sample, levels = unique(c(sample_order, unique(as.character(plot_df$sample)))))
} else {
  # keep input order within groups
  sample_levels <- unique(as.character(plot_df$sample))
  plot_df$sample <- factor(plot_df$sample, levels = sample_levels)
}

if (length(category_order) > 0) {
  plot_df$category <- factor(plot_df$category, levels = unique(c(category_order, unique(as.character(plot_df$category)))))
} else {
  plot_df$category <- factor(plot_df$category, levels = unique(as.character(plot_df$category)))
}

# Optional reverse stack
if (as_bool(get_param(params, 'reverse_stack', FALSE), FALSE)) {
  plot_df$category <- factor(plot_df$category, levels = rev(levels(plot_df$category)))
}

categories <- levels(plot_df$category)
n_cat <- length(categories)
fill_cols <- resolve_palette(n_cat, params, categories)
names(fill_cols) <- categories

# ------------------------------------------------------------
# Plot parameters (ChiPlot-style controls)
# ------------------------------------------------------------

orientation <- tolower(as.character(get_param_any(params, c('orientation', 'bar_orientation', 'type'), 'horizontal')[1]))
horizontal <- orientation %in% c('horizontal', 'horiz', 'h', 'y')

position_mode <- tolower(as.character(get_param_any(params, c('position', 'bar_position'), 'stack')[1]))
if (position_mode %in% c('dodge', 'dodged', 'grouped')) {
  position_mode <- 'dodge'
} else if (position_mode %in% c('fill', 'percent_stack')) {
  position_mode <- 'fill'
} else {
  position_mode <- 'stack'
}

# Bar style
outer_padding <- num_param(params, 'outerPadding', num_param(params, 'outer_padding', 0.3))
inner_padding <- num_param(params, 'innerPadding', num_param(params, 'inner_padding', 0.2))
bar_width <- num_param(params, 'bar_width', NA)
if (!is.finite(bar_width)) {
  # map outerPadding (0-1) to ggplot width (1 - outer)
  bar_width <- max(0.05, min(1, 1 - outer_padding))
}
bar_fill_opacity <- num_param(params, 'bar_fill_opacity', num_param(params, 'fill_opacity', num_param(params, 'fill-opacity', 1)))
bar_stroke <- get_param_any(params, c('bar_stroke', 'stroke', 'bar_border_color'), '#000000')
bar_stroke_width <- num_param(params, 'bar_stroke_width', num_param(params, 'stroke_width', num_param(params, 'stroke-width', 0)))
bar_stroke_opacity <- num_param(params, 'bar_stroke_opacity', num_param(params, 'stroke_opacity', num_param(params, 'stroke-opacity', 1)))

# Bar text
bar_text_show <- as_bool(get_param_any(params, c('bar_text_show', 'show_bar_text', 'show_value', 'show_label'), FALSE), FALSE)
# Accept either ggplot size (~3–5) or CSS-like pt sizes (~12–16 from ChiPlot UI)
bar_text_size_raw <- num_param(params, 'bar_text_size', num_param(params, 'font_size_bar_text', 10))
bar_text_size <- if (bar_text_size_raw > 8) bar_text_size_raw / ggplot2::.pt else bar_text_size_raw
bar_text_fill <- get_param_any(params, c('bar_text_fill', 'bar_text_color'), '#000000')
bar_text_weight <- get_param_any(params, c('bar_text_font_weight', 'bar_text_weight'), 'normal')
bar_text_style <- get_param_any(params, c('bar_text_font_style', 'bar_text_style'), 'normal')
bar_text_anchor <- get_param_any(params, c('bar_text_anchor', 'text_anchor'), 'middle')
bar_text_suffix <- as.character(get_param(params, 'bar_text_suffix', get_param(params, 'suffix', ''))[1] %||% '')
bar_text_digits <- as.integer(num_param(params, 'bar_text_digits', 1))
bar_text_min <- num_param(params, 'bar_text_min_value', 0)

# Title
title_show <- as_bool(get_param_any(params, c('title_show', 'title_switch'), FALSE), FALSE)
title_text <- as.character(get_param_any(params, c('title', 'title_text', 'text'), 'ChiPlot')[1] %||% 'ChiPlot')
title_size <- num_param(params, 'title_size', num_param(params, 'title_font_size', 14))
title_fill <- get_param_any(params, c('title_fill', 'title_color'), '#000000')
title_weight <- get_param_any(params, c('title_font_weight', 'title_weight'), 'normal')
title_style <- get_param_any(params, c('title_font_style', 'title_style'), 'normal')
title_hjust <- switch(tolower(as.character(get_param_any(params, c('title_text_anchor', 'title_anchor'), 'middle')[1])),
                      start = 0, end = 1, middle = 0.5, 0.5)
title_y <- num_param(params, 'title_y', 0)

# Right title (secondary)
right_title_show <- as_bool(get_param_any(params, c('right_title_show', 'right_title_switch'), FALSE), FALSE)
right_title_text <- as.character(get_param_any(params, c('right_title', 'right_title_text'), '')[1] %||% '')
right_title_size <- num_param(params, 'right_title_size', 12)
right_title_fill <- get_param_any(params, c('right_title_fill', 'right_title_color'), '#000000')

# Title background strip (ChiPlot-style)
title_bg_show <- as_bool(get_param_any(params, c('title_background_show', 'title_bg_switch'), FALSE), FALSE)
title_bg_height <- num_param(params, 'title_background_height', 30)
title_bg_fill <- get_param_any(params, c('title_background_fill', 'title_bg_fill'), '#E8E8E8')
title_bg_opacity <- num_param(params, 'title_background_fill_opacity', 1)
title_bg_stroke <- get_param_any(params, c('title_background_stroke'), '#000000')
title_bg_stroke_width <- num_param(params, 'title_background_stroke_width', 1)
title_bg_stroke_opacity <- num_param(params, 'title_background_stroke_opacity', 1)

# Plot background
plot_bg_show <- as_bool(get_param_any(params, c('background_show', 'plot_background_show', 'background_switch'), FALSE), FALSE)
plot_bg_fill <- get_param_any(params, c('background_fill', 'plot_background', 'panel_background'), '#F5F5F5')
plot_bg_opacity <- num_param(params, 'background_fill_opacity', 1)

# Canvas / export size
width <- num_param(params, 'width', 9)
height <- num_param(params, 'height', 7)
dpi <- as.integer(num_param(params, 'dpi', 300))
margin_top <- num_param(params, 'margin_top', 8)
margin_right <- num_param(params, 'margin_right', 8)
margin_bottom <- num_param(params, 'margin_bottom', 8)
margin_left <- num_param(params, 'margin_left', 8)
font_family <- get_param_any(params, c('font_family', 'base_font_family'), 'sans')

# Axis text style (shared defaults; axis-specific overrides)
x_text_show <- as_bool(get_param_any(params, c('x_axis_text_show', 'xaxis_text_switch', 'show_x_axis_text'), TRUE), TRUE)
y_text_show <- as_bool(get_param_any(params, c('y_axis_text_show', 'yaxis_text_switch', 'show_y_axis_text'), TRUE), TRUE)

x_rotate <- num_param(params, 'x_axis_text_angle', num_param(params, 'x_rotate', num_param(params, 'rotate', 0)))
y_rotate <- num_param(params, 'y_axis_text_angle', num_param(params, 'y_rotate', 0))
# ChiPlot defaults: horizontal value-axis labels -45; vertical sample labels 45
if (is.null(params$x_axis_text_angle) && is.null(params$x_rotate) && is.null(params$rotate)) {
  x_rotate <- if (horizontal) -45 else 45
}

x_text_size <- num_param(params, 'x_axis_text_size', num_param(params, 'x_font_size', 11))
y_text_size <- num_param(params, 'y_axis_text_size', num_param(params, 'y_font_size', 12))
x_text_fill <- get_param_any(params, c('x_axis_text_fill', 'x_axis_text_color', 'x_fill'), '#000000')
y_text_fill <- get_param_any(params, c('y_axis_text_fill', 'y_axis_text_color', 'y_fill'), '#000000')
x_text_weight <- get_param_any(params, c('x_axis_font_weight', 'x_font_weight'), 'normal')
y_text_weight <- get_param_any(params, c('y_axis_font_weight', 'y_font_weight'), 'normal')
x_text_style <- get_param_any(params, c('x_axis_font_style', 'x_font_style'), 'normal')
y_text_style <- get_param_any(params, c('y_axis_font_style', 'y_font_style'), 'normal')
x_text_offset <- num_param(params, 'x_axis_text_offset', num_param(params, 'x_offset', -15))
y_text_offset <- num_param(params, 'y_axis_text_offset', num_param(params, 'y_offset', 0))

# Axis labels (axis title text)
x_label <- as.character(get_param_any(params, c('xlab', 'x_title', 'x_label', 'x_axis_label'), '')[1] %||% '')
y_label <- as.character(get_param_any(params, c('ylab', 'y_title', 'y_label', 'y_axis_label'), '')[1] %||% '')
x_label_show <- as_bool(get_param_any(params, c('xlab_show', 'x_title_show', 'x_label_show'), nzchar(x_label)), nzchar(x_label))
y_label_show <- as_bool(get_param_any(params, c('ylab_show', 'y_title_show', 'y_label_show'), nzchar(y_label)), nzchar(y_label))
x_label_size <- num_param(params, 'x_axis_title_size', num_param(params, 'x_label_font_size', 12))
y_label_size <- num_param(params, 'y_axis_title_size', num_param(params, 'y_label_font_size', 12))
x_label_fill <- get_param_any(params, c('x_axis_title_color', 'x_label_fill'), '#000000')
y_label_fill <- get_param_any(params, c('y_axis_title_color', 'y_label_fill'), '#000000')
x_label_offset <- num_param(params, 'x_label_offset', 55)
y_label_offset <- num_param(params, 'y_label_offset', 0)
x_label_weight <- get_param_any(params, c('x_label_font_weight'), 'normal')
y_label_weight <- get_param_any(params, c('y_label_font_weight'), 'normal')
x_label_style <- get_param_any(params, c('x_label_font_style'), 'normal')
y_label_style <- get_param_any(params, c('y_label_font_style'), 'normal')

# Ticks
x_tick_stroke <- get_param_any(params, c('x_tick_stroke', 'x_tick_color', 'tick_stroke'), '#000000')
y_tick_stroke <- get_param_any(params, c('y_tick_stroke', 'y_tick_color', 'tick_stroke'), '#000000')
x_tick_width <- num_param(params, 'x_tick_stroke_width', num_param(params, 'tick_stroke_width', 1))
y_tick_width <- num_param(params, 'y_tick_stroke_width', num_param(params, 'tick_stroke_width', 1))
x_tick_opacity <- num_param(params, 'x_tick_stroke_opacity', num_param(params, 'tick_stroke_opacity', 1))
y_tick_opacity <- num_param(params, 'y_tick_stroke_opacity', num_param(params, 'tick_stroke_opacity', 1))
x_tick_length <- num_param(params, 'x_tick_length', num_param(params, 'tick_length', 6))
y_tick_length <- num_param(params, 'y_tick_length', num_param(params, 'tick_length', 6))
x_tick_orientation <- tolower(as.character(get_param_any(params, c('x_tick_orientation', 'tick_orientation'), 'outside')[1]))
y_tick_orientation <- tolower(as.character(get_param_any(params, c('y_tick_orientation', 'tick_orientation'), 'outside')[1]))
x_remove_path <- as_bool(get_param_any(params, c('x_remove_path', 'removePath', 'remove_path'), FALSE), FALSE)
y_remove_path <- as_bool(get_param_any(params, c('y_remove_path', 'removePath', 'remove_path'), FALSE), FALSE)
x_remove_tick <- as_bool(get_param_any(params, c('x_remove_tick', 'removeTick', 'remove_tick'), FALSE), FALSE)
y_remove_tick <- as_bool(get_param_any(params, c('y_remove_tick', 'removeTick', 'remove_tick'), FALSE), FALSE)

# Axis line colors from tick stroke when path kept
x_axis_line_color <- if (x_remove_path) NA else alpha(x_tick_stroke, x_tick_opacity)
y_axis_line_color <- if (y_remove_path) NA else alpha(y_tick_stroke, y_tick_opacity)

# Value scale limits (numeric axis). For vertical bars the numeric axis is Y.
x_min <- suppressWarnings(as.numeric(get_param_any(params, c('x_min', 'min_value', 'min-value'), NA))[1])
x_max <- suppressWarnings(as.numeric(get_param_any(params, c('x_max', 'max_value', 'max-value'), NA))[1])
y_min <- suppressWarnings(as.numeric(get_param_any(params, c('y_min'), NA))[1])
y_max <- suppressWarnings(as.numeric(get_param_any(params, c('y_max'), NA))[1])
# Allow min_value/max_value to target the numeric axis in either orientation
if (!horizontal) {
  if (!is.finite(y_min) && is.finite(x_min)) y_min <- x_min
  if (!is.finite(y_max) && is.finite(x_max)) y_max <- x_max
}

# Grid
x_grid_show <- as_bool(get_param_any(params, c('x_grid_show', 'grid_show', 'grid_switch', 'show_grid'), FALSE), FALSE)
y_grid_show <- as_bool(get_param_any(params, c('y_grid_show', 'grid_show', 'grid_switch', 'show_grid'), FALSE), FALSE)
grid_stroke <- get_param_any(params, c('grid_stroke', 'grid_color'), '#000000')
grid_stroke_width <- num_param(params, 'grid_stroke_width', num_param(params, 'grid_width', 0.4))
grid_stroke_opacity <- num_param(params, 'grid_stroke_opacity', 0.1)

# Legend
legend_show <- as_bool(get_param_any(params, c('legend_show', 'legend_switch', 'show_legend'), TRUE), TRUE)
legend_title <- as.character(get_param_any(params, c('legend_title', 'legend_name', 'legend_text'), 'ChiPlot')[1] %||% 'ChiPlot')
legend_title_size <- num_param(params, 'legend_title_size', 16)
legend_title_fill <- get_param_any(params, c('legend_title_fill', 'legend_title_color'), '#000000')
legend_title_weight <- get_param_any(params, c('legend_title_font_weight', 'legend_title_weight'), 'bold')
legend_title_style <- get_param_any(params, c('legend_title_font_style'), 'normal')
legend_title_hjust <- switch(tolower(as.character(get_param_any(params, c('legend_title_text_anchor'), 'start')[1])),
                             start = 0, end = 1, middle = 0.5, 0)
legend_position <- get_param_any(params, c('legend_position'), 'right')
legend_direction <- get_param_any(params, c('legend_direction'), 'vertical')
legend_text_size <- num_param(params, 'legend_text_size', num_param(params, 'legend_font_size', 11))
legend_text_fill <- get_param_any(params, c('legend_text_fill', 'legend_text_color'), '#000000')
legend_text_weight <- get_param_any(params, c('legend_text_font_weight'), 'normal')
legend_text_style <- get_param_any(params, c('legend_text_font_style'), 'normal')
legend_key_size <- num_param(params, 'legend_key_size', num_param(params, 'legend_square_size', 0.45))
legend_key_spacing <- num_param(params, 'legend_key_spacing', num_param(params, 'legend_square_spacing', 0.15))
legend_square_stroke <- get_param_any(params, c('legend_square_stroke', 'legend_key_stroke'), '#000000')
legend_square_stroke_width <- num_param(params, 'legend_square_stroke_width', 0)
legend_square_rx <- num_param(params, 'legend_square_rx', num_param(params, 'rx', 2))
legend_ncol <- as.integer(num_param(params, 'legend_columns', num_param(params, 'legend_ncol', 1)))
legend_spacing <- num_param(params, 'legend_spacing', 20)
legend_reverse <- as_bool(get_param(params, 'legend_reverse', FALSE), FALSE)

# Color-row annotation strip (ChiPlot "Color row")
color_row_show <- as_bool(get_param_any(params, c('color_row_show', 'color_row_switch', 'show_color_row'), FALSE), FALSE)
color_row_colors <- as_named_character(get_param(params, 'color_row_colors', NULL))

# Panel border
panel_border <- as_bool(get_param_any(params, c('panel_border', 'panel_border_show'), TRUE), TRUE)
panel_border_color <- get_param_any(params, c('panel_border_color', 'border_color'), '#222222')
panel_border_width <- num_param(params, 'panel_border_width', 0.6)

# ------------------------------------------------------------
# Build plot data frame for ggplot
# ------------------------------------------------------------

# Unique bar key: sample (may share group labels)
plot_df$bar_id <- interaction(plot_df$group, plot_df$sample, drop = TRUE, lex.order = TRUE)

# Order bars: group order, then sample order within group
bar_levels <- unique(as.character(interaction(
  factor(plot_df$group, levels = levels(plot_df$group)),
  factor(plot_df$sample, levels = levels(plot_df$sample)),
  drop = TRUE, lex.order = TRUE
)))
# Prefer explicit sample order if unique samples map 1:1
sample_levels_ordered <- levels(plot_df$sample)
# Build ordered sample list respecting group blocks
ordered_samples <- character()
for (g in levels(plot_df$group)) {
  smp <- unique(as.character(plot_df$sample[plot_df$group == g]))
  smp <- smp[order(match(smp, sample_levels_ordered))]
  ordered_samples <- c(ordered_samples, smp)
}
ordered_samples <- unique(ordered_samples)
plot_df$sample <- factor(plot_df$sample, levels = ordered_samples)

# For display labels: show group only once (mid of block) if multiple samples share a group
show_group_labels <- as_bool(get_param_any(params, c('show_group_labels', 'group_label_mode'), TRUE), TRUE)
y_label_mode <- tolower(as.character(get_param_any(params, c('y_label_mode', 'categorical_label_mode'), 'group')[1]))
# group: label by group (ChiPlot style) | sample: every sample | both

if (y_label_mode %in% c('sample', 'id', 'row')) {
  plot_df$axis_label <- as.character(plot_df$sample)
  axis_levels <- ordered_samples
} else if (y_label_mode %in% c('both', 'group_sample')) {
  plot_df$axis_label <- paste0(as.character(plot_df$group), ' | ', as.character(plot_df$sample))
  axis_levels <- paste0(
    as.character(plot_df$group[match(ordered_samples, as.character(plot_df$sample))]),
    ' | ', ordered_samples
  )
  axis_levels <- unique(axis_levels)
} else {
  # default group mode: each sample is a bar, but axis tick shows group name at block center via custom breaks
  plot_df$axis_label <- as.character(plot_df$sample)
  axis_levels <- ordered_samples
}

plot_df$axis_label <- factor(plot_df$axis_label, levels = if (y_label_mode %in% c('both', 'group_sample')) axis_levels else ordered_samples)

# Compute stacked midpoints for bar text
if (position_mode == 'dodge') {
  plot_df$label_pos <- plot_df$value / 2
  plot_df$label_value <- plot_df$value
} else if (position_mode == 'fill') {
  plot_df <- plot_df[order(plot_df$sample, plot_df$category), , drop = FALSE]
  plot_df$label_value <- ave(plot_df$value, plot_df$sample, FUN = function(x) {
    s <- sum(x); if (s <= 0) rep(0, length(x)) else x / s
  })
  plot_df$label_pos <- ave(plot_df$label_value, plot_df$sample, FUN = function(x) cumsum(x) - x / 2)
} else {
  plot_df <- plot_df[order(plot_df$sample, plot_df$category), , drop = FALSE]
  plot_df$label_value <- plot_df$value
  plot_df$label_pos <- ave(plot_df$value, plot_df$sample, FUN = function(x) cumsum(x) - x / 2)
}

# Position object.
# ChiPlot stacks the first legend category at the origin (left for horizontal bars).
# ggplot2 position_stack draws the first factor level last along the stack unless reverse=TRUE.
stack_reverse <- as_bool(get_param_any(params, c('stack_reverse', 'reverse_position_stack'), TRUE), TRUE)
if (as_bool(get_param(params, 'reverse_stack', FALSE), FALSE)) {
  # reverse_stack already flipped factor levels; keep position reverse off to avoid double reverse
  stack_reverse <- FALSE
}
if (position_mode == 'dodge') {
  pos <- position_dodge(width = bar_width)
  geom_width <- bar_width * (1 - inner_padding)
} else if (position_mode == 'fill') {
  pos <- position_fill(reverse = stack_reverse)
  geom_width <- bar_width
} else {
  pos <- position_stack(reverse = stack_reverse)
  geom_width <- bar_width
}

# Aesthetic mapping
if (horizontal) {
  p <- ggplot(plot_df, aes(y = .data$sample, x = .data$value, fill = .data$category))
} else {
  p <- ggplot(plot_df, aes(x = .data$sample, y = .data$value, fill = .data$category))
}

stroke_col <- if (bar_stroke_width > 0) alpha(bar_stroke, bar_stroke_opacity) else NA

p <- p +
  geom_col(
    position = pos,
    width = geom_width,
    alpha = bar_fill_opacity,
    colour = stroke_col,
    linewidth = if (bar_stroke_width > 0) bar_stroke_width / 2 else 0
  ) +
  scale_fill_manual(values = fill_cols, name = legend_title, breaks = if (legend_reverse) rev(categories) else categories, drop = FALSE)

# Bar text
if (bar_text_show) {
  label_df <- plot_df[plot_df$label_value > bar_text_min, , drop = FALSE]
  if (nrow(label_df) > 0) {
    label_df$label_str <- paste0(
      formatC(label_df$label_value, format = 'f', digits = bar_text_digits),
      bar_text_suffix
    )
    if (horizontal) {
      if (position_mode == 'dodge') {
        p <- p + geom_text(
          data = label_df,
          aes(y = .data$sample, x = .data$label_pos, label = .data$label_str, group = .data$category),
          position = position_dodge(width = bar_width),
          size = bar_text_size,
          colour = bar_text_fill,
          fontface = face_from_style(bar_text_weight, bar_text_style),
          family = font_family,
          hjust = 0.5, vjust = 0.5,
          inherit.aes = FALSE
        )
      } else {
        p <- p + geom_text(
          data = label_df,
          aes(y = .data$sample, x = .data$label_pos, label = .data$label_str),
          size = bar_text_size,
          colour = bar_text_fill,
          fontface = face_from_style(bar_text_weight, bar_text_style),
          family = font_family,
          hjust = 0.5, vjust = 0.5,
          inherit.aes = FALSE
        )
      }
    } else {
      if (position_mode == 'dodge') {
        p <- p + geom_text(
          data = label_df,
          aes(x = .data$sample, y = .data$label_pos, label = .data$label_str, group = .data$category),
          position = position_dodge(width = bar_width),
          size = bar_text_size,
          colour = bar_text_fill,
          fontface = face_from_style(bar_text_weight, bar_text_style),
          family = font_family,
          hjust = 0.5, vjust = 0.5,
          inherit.aes = FALSE
        )
      } else {
        p <- p + geom_text(
          data = label_df,
          aes(x = .data$sample, y = .data$label_pos, label = .data$label_str),
          size = bar_text_size,
          colour = bar_text_fill,
          fontface = face_from_style(bar_text_weight, bar_text_style),
          family = font_family,
          hjust = 0.5, vjust = 0.5,
          inherit.aes = FALSE
        )
      }
    }
  }
}

# Scales / limits
tick_dir_x <- if (x_tick_orientation == 'inside') -1 else 1
tick_dir_y <- if (y_tick_orientation == 'inside') -1 else 1

# Numeric axis limits (x for horizontal, y for vertical)
num_limits <- NULL
if (horizontal) {
  if (is.finite(x_min) || is.finite(x_max)) {
    lo <- if (is.finite(x_min)) x_min else 0
    hi <- if (is.finite(x_max)) x_max else NA
    num_limits <- c(lo, hi)
  }
} else {
  if (is.finite(y_min) || is.finite(y_max)) {
    lo <- if (is.finite(y_min)) y_min else 0
    hi <- if (is.finite(y_max)) y_max else NA
    num_limits <- c(lo, hi)
  }
}

sample_to_group <- setNames(as.character(plot_df$group), as.character(plot_df$sample))
sample_to_group <- sample_to_group[!duplicated(names(sample_to_group))]
reverse_y <- as_bool(get_param(params, 'reverse_y', TRUE), TRUE)
cat_limits <- if (horizontal && reverse_y) rev(levels(plot_df$sample)) else levels(plot_df$sample)

if (horizontal) {
  if (position_mode == 'fill') {
    p <- p + scale_x_continuous(expand = expansion(mult = c(0, 0.02)), labels = scales::percent_format(accuracy = 1))
  } else if (!is.null(num_limits)) {
    p <- p + scale_x_continuous(limits = num_limits, expand = expansion(mult = c(0, 0.02)), oob = scales::squish)
  } else {
    p <- p + scale_x_continuous(expand = expansion(mult = c(0, 0.02)))
  }

  # Group-centered labels when multiple samples share a group (ChiPlot style)
  use_group_labels <- (
    y_label_mode %in% c('group', 'group_center', 'auto', '') &&
    show_group_labels &&
    length(unique(sample_to_group)) < length(ordered_samples)
  )
  if (use_group_labels) {
    mid_breaks <- character()
    mid_labels <- character()
    for (g in levels(plot_df$group)) {
      smps <- ordered_samples[ordered_samples %in% names(sample_to_group)[sample_to_group == g]]
      if (length(smps) == 0) next
      mid_breaks <- c(mid_breaks, smps[ceiling(length(smps) / 2)])
      mid_labels <- c(mid_labels, g)
    }
    p <- p + scale_y_discrete(limits = cat_limits, breaks = mid_breaks, labels = mid_labels)
  } else {
    p <- p + scale_y_discrete(limits = cat_limits)
  }
} else {
  # Vertical bars: discrete samples on x, numeric stack on y
  reverse_x <- as_bool(get_param(params, 'reverse_x', FALSE), FALSE)
  x_cat_limits <- if (reverse_x) rev(levels(plot_df$sample)) else levels(plot_df$sample)
  p <- p + scale_x_discrete(limits = x_cat_limits)
  if (position_mode == 'fill') {
    p <- p + scale_y_continuous(expand = expansion(mult = c(0, 0.02)), labels = scales::percent_format(accuracy = 1))
  } else if (!is.null(num_limits)) {
    p <- p + scale_y_continuous(limits = num_limits, expand = expansion(mult = c(0, 0.02)), oob = scales::squish)
  } else {
    p <- p + scale_y_continuous(expand = expansion(mult = c(0, 0.02)))
  }
}

# Labs
xlab_final <- if (x_label_show) x_label else NULL
ylab_final <- if (y_label_show) y_label else NULL
title_final <- if (title_show) title_text else NULL

p <- p + labs(title = title_final, x = xlab_final, y = ylab_final)

# Theme
bg_fill_final <- if (plot_bg_show) alpha(plot_bg_fill, plot_bg_opacity) else 'white'
panel_fill_final <- if (plot_bg_show) alpha(plot_bg_fill, plot_bg_opacity) else 'white'

p <- p + theme_classic(base_family = font_family) + theme(
  plot.title = if (title_show) element_text(
    size = title_size,
    colour = title_fill,
    face = face_from_style(title_weight, title_style),
    hjust = title_hjust,
    vjust = if (is.finite(title_y)) title_y else 0.5,
    margin = margin(b = 8)
  ) else element_blank(),
  plot.background = element_rect(fill = bg_fill_final, colour = NA),
  panel.background = element_rect(fill = panel_fill_final, colour = NA),
  panel.border = if (panel_border) element_rect(fill = NA, colour = panel_border_color, linewidth = panel_border_width) else element_blank(),
  axis.title.x = if (x_label_show) element_text(
    size = x_label_size, colour = x_label_fill,
    face = face_from_style(x_label_weight, x_label_style),
    margin = margin(t = max(2, x_label_offset / 5))
  ) else element_blank(),
  axis.title.y = if (y_label_show) element_text(
    size = y_label_size, colour = y_label_fill,
    face = face_from_style(y_label_weight, y_label_style),
    margin = margin(r = max(2, y_label_offset / 5))
  ) else element_blank(),
  axis.text.x = if (x_text_show && !x_remove_tick) element_text(
    size = x_text_size, colour = x_text_fill,
    face = face_from_style(x_text_weight, x_text_style),
    angle = x_rotate,
    hjust = if (abs(x_rotate) > 5) 1 else 0.5,
    vjust = if (abs(x_rotate) > 5) 1 else 0.5,
    margin = margin(t = max(2, abs(x_text_offset) / 5))
  ) else element_blank(),
  axis.text.y = if (y_text_show && !y_remove_tick) element_text(
    size = y_text_size, colour = y_text_fill,
    face = face_from_style(y_text_weight, y_text_style),
    angle = y_rotate,
    hjust = 1,
    margin = margin(r = max(2, abs(y_text_offset) / 5))
  ) else element_blank(),
  axis.ticks.x = if (x_remove_tick) element_blank() else element_line(
    colour = alpha(x_tick_stroke, x_tick_opacity),
    linewidth = x_tick_width / 2
  ),
  axis.ticks.y = if (y_remove_tick) element_blank() else element_line(
    colour = alpha(y_tick_stroke, y_tick_opacity),
    linewidth = y_tick_width / 2
  ),
  axis.ticks.length.x = grid::unit(tick_dir_x * x_tick_length, 'pt'),
  axis.ticks.length.y = grid::unit(tick_dir_y * y_tick_length, 'pt'),
  axis.line.x = if (x_remove_path || is.na(x_axis_line_color)) element_blank() else element_line(colour = x_axis_line_color, linewidth = x_tick_width / 2),
  axis.line.y = if (y_remove_path || is.na(y_axis_line_color)) element_blank() else element_line(colour = y_axis_line_color, linewidth = y_tick_width / 2),
  panel.grid.major.x = if ((horizontal && x_grid_show) || (!horizontal && y_grid_show)) {
    element_line(colour = alpha(grid_stroke, grid_stroke_opacity), linewidth = grid_stroke_width / 2)
  } else if (horizontal) {
    element_blank()
  } else {
    element_blank()
  },
  panel.grid.major.y = if ((!horizontal && x_grid_show) || (horizontal && y_grid_show)) {
    element_line(colour = alpha(grid_stroke, grid_stroke_opacity), linewidth = grid_stroke_width / 2)
  } else {
    element_blank()
  },
  panel.grid.minor = element_blank(),
  legend.position = if (legend_show) legend_position else 'none',
  legend.direction = legend_direction,
  legend.title = element_text(
    size = legend_title_size,
    colour = legend_title_fill,
    face = face_from_style(legend_title_weight, legend_title_style),
    hjust = legend_title_hjust
  ),
  legend.text = element_text(
    size = legend_text_size,
    colour = legend_text_fill,
    face = face_from_style(legend_text_weight, legend_text_style)
  ),
  legend.key = element_rect(fill = 'white', colour = NA),
  legend.key.size = grid::unit(legend_key_size, 'cm'),
  legend.spacing.y = grid::unit(legend_key_spacing, 'cm'),
  legend.spacing = grid::unit(legend_spacing / 40, 'cm'),
  plot.margin = margin(margin_top, margin_right, margin_bottom, margin_left)
)

if (legend_show) {
  p <- p + guides(
    fill = guide_legend(
      ncol = max(1, legend_ncol),
      override.aes = list(
        colour = if (legend_square_stroke_width > 0) legend_square_stroke else NA,
        linewidth = legend_square_stroke_width / 2,
        alpha = 1
      ),
      title.position = 'top',
      keywidth = grid::unit(legend_key_size, 'cm'),
      keyheight = grid::unit(legend_key_size * 0.7, 'cm')
    )
  )
}

# Optional color-row strip as secondary x annotation (via annotation_custom is hard;
# instead add a small facet-like ribbon using cowplot if requested)
# Keep simple: color_row recolors legend keys only via category_colors already.

# Right title as secondary y label / caption
if (right_title_show && nzchar(right_title_text)) {
  p <- p + labs(tag = right_title_text) +
    theme(
      plot.tag = element_text(size = right_title_size, colour = right_title_fill, angle = 270),
      plot.tag.position = c(1.02, 0.5)
    )
}

# Title background strip approximated via plot.background + margin
if (title_bg_show && title_show) {
  p <- p + theme(
    plot.title = element_text(
      size = title_size,
      colour = title_fill,
      face = face_from_style(title_weight, title_style),
      hjust = title_hjust,
      margin = margin(
        t = max(4, title_bg_height / 4),
        b = max(4, title_bg_height / 4),
        l = 6, r = 6
      )
    ),
    plot.background = element_rect(
      fill = bg_fill_final,
      colour = alpha(title_bg_stroke, title_bg_stroke_opacity),
      linewidth = title_bg_stroke_width / 2
    )
  )
}

write_log(sprintf('Built stacked bar plot: %s samples, %s categories, orientation=%s, position=%s.',
                  length(unique(as.character(plot_df$sample))), n_cat, orientation, position_mode))

# ------------------------------------------------------------
# Export selected rows and matrix used
# ------------------------------------------------------------
selected_rows <- unique(plot_df[, c('sample', 'group'), drop = FALSE])
selected_rows$is_selected <- TRUE
utils::write.csv(selected_rows, file.path(output_dir, 'selected_rows.csv'), row.names = FALSE)

wide_out <- tryCatch({
  reshape_wide <- tapply(plot_df$value, list(plot_df$sample, plot_df$category), sum, default = 0)
  wide_df <- as.data.frame(reshape_wide, check.names = FALSE)
  wide_df$sample <- rownames(wide_df)
  wide_df$group <- sample_to_group[wide_df$sample]
  wide_df <- wide_df[, c('sample', 'group', setdiff(colnames(wide_df), c('sample', 'group'))), drop = FALSE]
  utils::write.csv(wide_df, file.path(output_dir, 'matrix_used.csv'), row.names = FALSE)
  TRUE
}, error = function(e) {
  write_log(paste('matrix_used export skipped:', conditionMessage(e)))
  FALSE
})

# ------------------------------------------------------------
# Save outputs
# ------------------------------------------------------------
tryCatch({
  save_plot(p, output_dir, width, height, dpi)
}, error = function(e) {
  write_error_and_exit('Failed to save plot outputs', conditionMessage(e),
                       'Check graphics devices (cairo/svglite) and plot size.')
})

figure_json <- list(
  figure_type = 'stacked_bar_plot',
  title = if (title_show) title_text else '',
  theme = 'classic',
  layout = list(width = width, height = height, orientation = orientation, position = position_mode),
  analysis = list(
    input_mode = input_mode,
    value_mode = value_mode,
    n_samples = length(unique(as.character(plot_df$sample))),
    n_groups = length(unique(as.character(plot_df$group))),
    n_categories = n_cat,
    categories = categories
  ),
  style = list(
    palette = unname(fill_cols),
    bar_width = bar_width,
    outer_padding = outer_padding,
    inner_padding = inner_padding,
    bar_fill_opacity = bar_fill_opacity,
    legend_position = legend_position,
    x_rotate = x_rotate,
    grid_show = x_grid_show || y_grid_show
  ),
  data = list(
    input_file = basename(input_file),
    n_rows = nrow(plot_df)
  ),
  layers = list(
    list(id = 'bars', type = 'bar', editable = TRUE),
    list(id = 'bar_text', type = 'text', editable = TRUE),
    list(id = 'x_axis', type = 'axis', editable = TRUE),
    list(id = 'y_axis', type = 'axis', editable = TRUE),
    list(id = 'legend', type = 'legend', editable = TRUE),
    list(id = 'title', type = 'text', editable = TRUE),
    list(id = 'grid', type = 'grid', editable = TRUE)
  ),
  export = list(
    svg = 'result.svg',
    pdf = 'result.pdf',
    png = 'result.png',
    selected_rows = 'selected_rows.csv',
    matrix_used = if (isTRUE(wide_out)) 'matrix_used.csv' else NULL
  )
)

writeLines(
  jsonlite::toJSON(figure_json, auto_unbox = TRUE, pretty = TRUE, null = 'null'),
  file.path(output_dir, 'figure.json')
)

write_log('Plugin completed successfully.')
quit(status = 0)
