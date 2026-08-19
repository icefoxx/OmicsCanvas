#!/usr/bin/env Rscript

# BioFigureAI Plot Plugin: Regression Scatter Plot
# ------------------------------------------------------------
# Multi-group scatter with per-group linear (or loess) regression,
# confidence band, and ChiPlot-style formula / R² / P annotations.
#
# Runtime:
#   Rscript plot.R --input input.csv --params params.json --output output_dir

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
})

option_list <- list(
  make_option(c('--input'), type = 'character', default = NULL),
  make_option(c('--params'), type = 'character', default = NULL),
  make_option(c('--output'), type = 'character', default = NULL)
)
opt <- parse_args(OptionParser(option_list = option_list))
input_file <- opt$input
params_file <- opt$params
output_dir <- opt$output

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x

write_log <- function(msg) {
  cat(sprintf('[%s] %s\n', format(Sys.time(), '%F %T'), msg),
      file = file.path(output_dir, 'run.log'), append = TRUE)
}

write_error_and_exit <- function(error, detail = NULL, suggestion = NULL, status = 1) {
  if (is.null(output_dir) || !nzchar(output_dir)) output_dir <<- getwd()
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  writeLines(
    jsonlite::toJSON(list(error = error, detail = detail %||% '', suggestion = suggestion %||% ''),
                     auto_unbox = TRUE, pretty = TRUE),
    file.path(output_dir, 'error.json')
  )
  message(error)
  quit(status = status)
}

if (is.null(input_file) || !file.exists(input_file)) write_error_and_exit('Input file not found', as.character(input_file))
if (is.null(params_file) || !file.exists(params_file)) write_error_and_exit('Params file not found', as.character(params_file))
if (is.null(output_dir)) write_error_and_exit('Missing --output')
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
if (file.exists(file.path(output_dir, 'error.json'))) unlink(file.path(output_dir, 'error.json'))

write_log('Plugin regression_scatter_plot started.')

params <- tryCatch(
  jsonlite::fromJSON(params_file, simplifyVector = TRUE, simplifyDataFrame = FALSE),
  error = function(e) write_error_and_exit('Invalid params.json', conditionMessage(e))
)

get_param <- function(name, default = NULL) {
  if (!is.null(params[[name]])) params[[name]] else default
}
get_param_any <- function(names, default = NULL) {
  for (n in names) if (!is.null(params[[n]])) return(params[[n]])
  default
}
as_bool <- function(x, default = FALSE) {
  if (is.null(x)) return(default)
  if (is.logical(x)) return(isTRUE(x[1]))
  tolower(trimws(as.character(x[1]))) %in% c('true', 't', 'yes', 'y', '1', 'on')
}
num_param <- function(name, default) {
  v <- suppressWarnings(as.numeric(get_param(name, default))[1])
  if (is.na(v)) default else v
}
as_string_vector <- function(x, default = character()) {
  if (is.null(x)) return(default)
  if (is.list(x) && !is.data.frame(x)) x <- unlist(x, use.names = FALSE)
  if (length(x) == 1 && grepl(',', x, fixed = TRUE)) x <- strsplit(as.character(x), ',', fixed = TRUE)[[1]]
  x <- trimws(as.character(x)); x[nzchar(x)]
}
as_named_character <- function(x, default = character()) {
  if (is.null(x)) return(default)
  u <- unlist(x, use.names = TRUE)
  if (!length(u)) return(default)
  setNames(as.character(u), names(u))
}

ext <- tolower(tools::file_ext(input_file))
df <- if (ext == 'csv') {
  read.csv(input_file, check.names = FALSE, stringsAsFactors = FALSE)
} else {
  read.delim(input_file, check.names = FALSE, stringsAsFactors = FALSE)
}
write_log(sprintf('Loaded %s rows x %s cols', nrow(df), ncol(df)))

cn <- colnames(df)
lo <- tolower(cn)
find_col <- function(requested, aliases) {
  if (!is.null(requested) && nzchar(as.character(requested)[1])) {
    i <- match(tolower(requested), lo)
    if (!is.na(i)) return(cn[i])
  }
  for (a in aliases) {
    i <- match(tolower(a), lo)
    if (!is.na(i)) return(cn[i])
  }
  NULL
}

x_col <- find_col(get_param_any(c('x_column', 'x'), NULL), c('x', 'x_value', 'x_ratio', 'X'))
y_col <- find_col(get_param_any(c('y_column', 'y'), NULL), c('y', 'y_value', 'y_ratio', 'Y'))
g_col <- find_col(get_param_any(c('group_column', 'color_column', 'class_column'), NULL),
                  c('group', 'type', 'class', 'condition', 'Group'))
id_col <- find_col(get_param_any(c('id_column', 'label_column'), NULL),
                   c('id', 'gene', 'sample', 'name', 'label'))

if (is.null(x_col) || is.null(y_col)) {
  nums <- cn[vapply(df, function(x) is.numeric(x) || suppressWarnings(sum(is.finite(as.numeric(x)))) > 0, logical(1))]
  if (length(nums) < 2) write_error_and_exit('Need x_column and y_column', paste(cn, collapse = ', '))
  if (is.null(x_col)) x_col <- nums[1]
  if (is.null(y_col)) y_col <- nums[2]
}

plot_df <- data.frame(
  x = suppressWarnings(as.numeric(df[[x_col]])),
  y = suppressWarnings(as.numeric(df[[y_col]])),
  group = if (!is.null(g_col)) as.character(df[[g_col]]) else 'All',
  id = if (!is.null(id_col)) as.character(df[[id_col]]) else as.character(seq_len(nrow(df))),
  stringsAsFactors = FALSE
)
plot_df <- plot_df[is.finite(plot_df$x) & is.finite(plot_df$y), , drop = FALSE]
if (!nrow(plot_df)) write_error_and_exit('No finite x/y rows')

# Filters
rows_inc <- as_string_vector(get_param_any(c('rows_include', 'ids_include'), NULL))
rows_exc <- as_string_vector(get_param_any(c('rows_exclude', 'ids_exclude'), NULL))
if (length(rows_inc)) plot_df <- plot_df[plot_df$id %in% rows_inc, , drop = FALSE]
if (length(rows_exc)) plot_df <- plot_df[!plot_df$id %in% rows_exc, , drop = FALSE]
g_inc <- as_string_vector(get_param_any(c('groups_include'), NULL))
g_exc <- as_string_vector(get_param_any(c('groups_exclude'), NULL))
if (length(g_inc)) plot_df <- plot_df[plot_df$group %in% g_inc, , drop = FALSE]
if (length(g_exc)) plot_df <- plot_df[!plot_df$group %in% g_exc, , drop = FALSE]
if (!nrow(plot_df)) write_error_and_exit('No rows after filtering')

g_order <- as_string_vector(get_param_any(c('group_order', 'legend_order'), NULL))
if (length(g_order)) {
  plot_df$group <- factor(plot_df$group, levels = unique(c(g_order, unique(plot_df$group))))
} else {
  plot_df$group <- factor(plot_df$group, levels = unique(plot_df$group))
}
groups <- levels(plot_df$group)

# Colors
default_pal <- c('#66C2A5', '#FC8D62', '#8DA0CB', '#E78AC3', '#A6D854', '#FFD92F')
fill_cols <- setNames(rep(default_pal, length.out = length(groups)), groups)
for (key in c('group_colors', 'type_colors', 'category_colors', 'color_map', 'custom_colors')) {
  m <- as_named_character(get_param(key, NULL))
  if (length(m)) {
    hit <- intersect(names(m), groups)
    fill_cols[hit] <- m[hit]
  }
}

# Point style (ChiPlot)
point_show <- as_bool(get_param_any(c('point_show', 'scatter_show'), TRUE), TRUE)
point_size_raw <- num_param('point_size', num_param('size', 40))
# ChiPlot size ~40 is roughly ggplot size ~2.5
point_size <- if (point_size_raw > 10) point_size_raw / 15 else point_size_raw
point_alpha <- num_param('point_alpha', num_param('fill_opacity', num_param('point_fill_opacity', 1)))
point_stroke <- num_param('point_stroke', num_param('stroke_width', 0.5))
point_stroke_color <- as.character(get_param_any(c('point_stroke_color', 'stroke'), '#000000')[1] %||% '#000000')
stroke_as_fill <- as_bool(get_param_any(c('stroke_as_fill', 'stroke-as-fill'), TRUE), TRUE)
point_shape <- as.integer(num_param('point_shape', 16))
if (stroke_as_fill) {
  point_stroke_color <- NA
  point_stroke <- 0
}

# Center line
center_line_show <- as_bool(get_param_any(c('center_line_show', 'show_center_line'), FALSE), FALSE)
center_line_color <- as.character(get_param_any(c('center_line_color', 'center_line_stroke'), '#000000')[1] %||% '#000000')
center_line_width <- num_param('center_line_width', 0.6)
center_line_alpha <- num_param('center_line_opacity', 0.4)

# Regression
reg_show <- as_bool(get_param_any(c('regression_show', 'show_regression', 'reg_line_show'), TRUE), TRUE)
reg_method <- tolower(as.character(get_param_any(c('regression_method', 'method'), 'lm')[1] %||% 'lm'))
if (!reg_method %in% c('lm', 'loess', 'glm')) reg_method <- 'lm'
loess_span <- num_param('loess_span', 0.5)
reg_se <- as_bool(get_param_any(c('ci_show', 'confidence_interval_show', 'se_show', 'show_ci'), TRUE), TRUE)
reg_linewidth <- num_param('regression_line_width', num_param('reg_stroke_width', 1.2))
# ChiPlot stroke-width 4 is thick in px → ~1.2–1.5 ggplot
if (reg_linewidth > 2.5) reg_linewidth <- reg_linewidth / 3
reg_line_alpha <- num_param('regression_line_opacity', num_param('reg_stroke_opacity', 1))
ci_alpha <- num_param('ci_fill_opacity', num_param('ci_alpha', 0.2))
ci_fill <- as.character(get_param_any(c('ci_fill', 'ci_color'), '#888888')[1] %||% '#888888')
# fill-as-line: CI uses same color as line (group-colored band)
ci_fill_as_line <- as_bool(get_param_any(c('ci_fill_as_line', 'fill_as_line'), FALSE), FALSE)

# Formula / R / P text
formula_show <- as_bool(get_param_any(c('formula_show', 'show_formula'), TRUE), TRUE)
r2_show <- as_bool(get_param_any(c('r2_show', 'show_r2', 'r_text_show'), TRUE), TRUE)
p_show <- as_bool(get_param_any(c('p_show', 'show_p', 'p_text_show'), TRUE), TRUE)
stat_text_size <- num_param('formula_font_size', num_param('stat_text_size', 3.8))
if (stat_text_size > 8) stat_text_size <- stat_text_size / ggplot2::.pt
stat_text_color <- as.character(get_param_any(c('formula_fill', 'stat_text_color'), '#222222')[1] %||% '#222222')
stat_text_face <- as.character(get_param_any(c('formula_font_weight'), 'plain')[1] %||% 'plain')
if (tolower(stat_text_face) == 'bold') stat_text_face <- 'bold' else if (tolower(stat_text_face) == 'normal') stat_text_face <- 'plain'
# Placement: ChiPlot puts R2/P top-right, equations mid-right
formula_x <- suppressWarnings(as.numeric(get_param('formula_x', NA))[1])
formula_y <- suppressWarnings(as.numeric(get_param('formula_y', NA))[1])
r2_x <- suppressWarnings(as.numeric(get_param('r2_x', NA))[1])
r2_y <- suppressWarnings(as.numeric(get_param('r2_y', NA))[1])

# Point labels
point_text_show <- as_bool(get_param_any(c('point_text_show', 'label_show'), FALSE), FALSE)
point_text_size <- num_param('point_text_size', 3)
if (point_text_size > 8) point_text_size <- point_text_size / ggplot2::.pt
point_text_color <- as.character(get_param_any(c('point_text_fill'), '#222222')[1] %||% '#222222')
point_text_dx <- num_param('point_text_dx', 0)
point_text_dy <- num_param('point_text_dy', -0.15)

# Title / axes / legend / theme
title_show <- as_bool(get_param('title_show', FALSE), FALSE)
title <- as.character(get_param_any(c('title', 'title_text'), '')[1] %||% '')
title_size <- num_param('title_size', 14)
xlab <- as.character(get_param_any(c('xlab', 'x_title'), x_col)[1] %||% x_col)
ylab <- as.character(get_param_any(c('ylab', 'y_title'), y_col)[1] %||% y_col)
xlab_show <- as_bool(get_param_any(c('xlab_show', 'x_title_show'), nzchar(xlab)), nzchar(xlab))
ylab_show <- as_bool(get_param_any(c('ylab_show', 'y_title_show'), nzchar(ylab)), nzchar(ylab))

legend_show <- as_bool(get_param('legend_show', TRUE), TRUE)
legend_title <- as.character(get_param_any(c('legend_title', 'legend_name'), 'ChiPlot')[1] %||% 'ChiPlot')
legend_position <- as.character(get_param('legend_position', 'right')[1] %||% 'right')
legend_title_size <- num_param('legend_title_size', 12)
legend_text_size <- num_param('legend_text_size', 10)
legend_title_face <- as.character(get_param_any(c('legend_title_font_weight'), 'bold')[1] %||% 'bold')
if (tolower(legend_title_face) == 'normal') legend_title_face <- 'plain'

grid_show <- as_bool(get_param('grid_show', TRUE), TRUE)
panel_bg <- as.character(get_param_any(c('panel_background', 'background_fill'), '#F7F7F7')[1] %||% '#F7F7F7')
plot_bg <- as.character(get_param('plot_background', '#FFFFFF')[1] %||% '#FFFFFF')

x_min <- suppressWarnings(as.numeric(get_param_any(c('x_min'), NA))[1])
x_max <- suppressWarnings(as.numeric(get_param_any(c('x_max'), NA))[1])
y_min <- suppressWarnings(as.numeric(get_param_any(c('y_min'), NA))[1])
y_max <- suppressWarnings(as.numeric(get_param_any(c('y_max'), NA))[1])

width <- num_param('width', 8)
height <- num_param('height', 6.5)
dpi <- as.integer(num_param('dpi', 300))
font_family <- as.character(get_param('font_family', 'sans')[1] %||% 'sans')

# Per-group regression stats for annotations
fmt_num <- function(x, dig = 3) {
  if (!is.finite(x)) return('NA')
  if (abs(x) >= 1000 || (abs(x) > 0 && abs(x) < 0.001)) format(x, scientific = TRUE, digits = dig)
  else format(round(x, dig), nsmall = 0, scientific = FALSE)
}
fmt_p <- function(p) {
  if (!is.finite(p)) return('NA')
  if (p < 1e-3) format(p, scientific = TRUE, digits = 3) else format(round(p, 4), nsmall = 4)
}

stat_rows <- list()
for (g in groups) {
  sub <- plot_df[plot_df$group == g, , drop = FALSE]
  if (nrow(sub) < 3) next
  fit <- tryCatch(stats::lm(y ~ x, data = sub), error = function(e) NULL)
  if (is.null(fit)) next
  sm <- summary(fit)
  coefs <- stats::coef(fit)
  intercept <- unname(coefs[1])
  slope <- unname(coefs[2])
  r2 <- unname(sm$r.squared)
  pval <- tryCatch({
    ct <- stats::cor.test(sub$x, sub$y)
    unname(ct$p.value)
  }, error = function(e) {
    if (!is.null(sm$coefficients) && nrow(sm$coefficients) >= 2) sm$coefficients[2, 4] else NA_real_
  })
  # equation string
  sign_chr <- if (is.finite(intercept) && intercept >= 0) '+' else '-'
  eq <- sprintf('%s: y = %sx %s %s', g, fmt_num(slope, 3), sign_chr, fmt_num(abs(intercept), 3))
  r2s <- sprintf('%s: R² = %s', g, fmt_num(r2, 4))
  ps <- sprintf('%s: P = %s', g, fmt_p(pval))
  stat_rows[[length(stat_rows) + 1]] <- data.frame(
    group = g, slope = slope, intercept = intercept, r2 = r2, pvalue = pval,
    equation = eq, r2_label = r2s, p_label = ps, n = nrow(sub),
    stringsAsFactors = FALSE
  )
}
stat_df <- if (length(stat_rows)) do.call(rbind, stat_rows) else data.frame()

# Build plot
p <- ggplot(plot_df, aes(x = .data$x, y = .data$y, colour = .data$group, fill = .data$group))

if (center_line_show) {
  p <- p + geom_hline(
    yintercept = mean(plot_df$y), colour = alpha(center_line_color, center_line_alpha),
    linewidth = center_line_width
  )
}

if (reg_show) {
  if (ci_fill_as_line) {
    p <- p + geom_smooth(
      method = reg_method,
      formula = y ~ x,
      se = reg_se,
      linewidth = reg_linewidth,
      alpha = ci_alpha,
      span = loess_span,
      fullrange = FALSE
    )
  } else {
    # grey CI, colored lines — need two layers
    if (reg_se) {
      p <- p + geom_smooth(
        method = reg_method, formula = y ~ x, se = TRUE,
        fill = ci_fill, colour = NA, alpha = ci_alpha,
        span = loess_span, show.legend = FALSE
      )
    }
    p <- p + geom_smooth(
      method = reg_method, formula = y ~ x, se = FALSE,
      linewidth = reg_linewidth, alpha = reg_line_alpha,
      span = loess_span
    )
  }
}

if (point_show) {
  p <- p + geom_point(
    size = point_size,
    alpha = point_alpha,
    shape = point_shape,
    stroke = point_stroke
  )
}

p <- p +
  scale_colour_manual(values = fill_cols, name = legend_title, drop = FALSE) +
  scale_fill_manual(values = fill_cols, name = legend_title, drop = FALSE)

# Axis limits
if (is.finite(x_min) || is.finite(x_max) || is.finite(y_min) || is.finite(y_max)) {
  p <- p + coord_cartesian(
    xlim = c(if (is.finite(x_min)) x_min else NA, if (is.finite(x_max)) x_max else NA),
    ylim = c(if (is.finite(y_min)) y_min else NA, if (is.finite(y_max)) y_max else NA)
  )
}

# Annotations for formula / R2 / P
xr <- range(plot_df$x, na.rm = TRUE)
yr <- range(plot_df$y, na.rm = TRUE)
if (nrow(stat_df) > 0 && (formula_show || r2_show || p_show)) {
  # default positions: R2/P top-right stack, equations mid-right
  if (r2_show || p_show) {
    labels_top <- character()
    if (r2_show) labels_top <- c(labels_top, stat_df$r2_label)
    if (p_show) labels_top <- c(labels_top, stat_df$p_label)
    # pair R2 and P per group on two columns like image
    if (r2_show && p_show) {
      left <- stat_df$r2_label
      right <- stat_df$p_label
      top_text <- paste(paste(left, collapse = '\n'), paste(right, collapse = '\n'), sep = '      ')
      # Actually image has two columns: left R2 for A/B, right P for A/B
      # Build multi-line two-column via separate annotations
      n_g <- nrow(stat_df)
      base_x <- if (is.finite(r2_x)) r2_x else xr[1] + diff(xr) * 0.42
      base_y <- if (is.finite(r2_y)) r2_y else yr[2] - diff(yr) * 0.02
      line_h <- diff(yr) * 0.055
      for (i in seq_len(n_g)) {
        p <- p + annotate(
          'text', x = base_x, y = base_y - (i - 1) * line_h,
          label = stat_df$r2_label[i], hjust = 0, vjust = 1,
          size = stat_text_size, colour = stat_text_color,
          fontface = stat_text_face, family = font_family
        )
        p <- p + annotate(
          'text', x = base_x + diff(xr) * 0.32, y = base_y - (i - 1) * line_h,
          label = stat_df$p_label[i], hjust = 0, vjust = 1,
          size = stat_text_size, colour = stat_text_color,
          fontface = stat_text_face, family = font_family
        )
      }
    } else {
      txt <- paste(if (r2_show) stat_df$r2_label else stat_df$p_label, collapse = '\n')
      p <- p + annotate(
        'text',
        x = if (is.finite(r2_x)) r2_x else xr[1] + diff(xr) * 0.5,
        y = if (is.finite(r2_y)) r2_y else yr[2] - diff(yr) * 0.05,
        label = txt, hjust = 0, vjust = 1,
        size = stat_text_size, colour = stat_text_color,
        fontface = stat_text_face, family = font_family
      )
    }
  }
  if (formula_show) {
    eq_text <- paste(stat_df$equation, collapse = '\n')
    p <- p + annotate(
      'text',
      x = if (is.finite(formula_x)) formula_x else xr[1] + diff(xr) * 0.55,
      y = if (is.finite(formula_y)) formula_y else yr[1] + diff(yr) * 0.72,
      label = eq_text, hjust = 0, vjust = 1,
      size = stat_text_size, colour = stat_text_color,
      fontface = stat_text_face, family = font_family
    )
  }
}

if (point_text_show) {
  p <- p + geom_text(
    aes(label = .data$id),
    size = point_text_size, colour = point_text_color,
    nudge_x = point_text_dx, nudge_y = point_text_dy,
    show.legend = FALSE, check_overlap = TRUE
  )
}

p <- p + labs(
  title = if (title_show && nzchar(title)) title else NULL,
  x = if (xlab_show) xlab else NULL,
  y = if (ylab_show) ylab else NULL
)

p <- p + theme_bw(base_family = font_family) + theme(
  plot.title = if (title_show) element_text(size = title_size, hjust = 0.5) else element_blank(),
  plot.background = element_rect(fill = plot_bg, colour = NA),
  panel.background = element_rect(fill = panel_bg, colour = NA),
  panel.grid.major = if (grid_show) element_line(colour = '#FFFFFF', linewidth = 0.4) else element_blank(),
  panel.grid.minor = if (grid_show) element_line(colour = '#FFFFFF', linewidth = 0.2) else element_blank(),
  axis.title.x = if (xlab_show) element_text() else element_blank(),
  axis.title.y = if (ylab_show) element_text() else element_blank(),
  legend.position = if (legend_show) legend_position else 'none',
  legend.title = element_text(
    size = legend_title_size,
    face = if (tolower(legend_title_face) == 'bold') 'bold' else 'plain'
  ),
  legend.text = element_text(size = legend_text_size)
)

# Avoid double legends
p <- p + guides(
  colour = if (legend_show) guide_legend(override.aes = list(size = 3, alpha = 1, linewidth = 1.2)) else 'none',
  fill = 'none'
)

write_log(sprintf('Built regression scatter: %s points, %s groups, method=%s.',
                  nrow(plot_df), length(groups), reg_method))

# Save
save_one <- function(path, device) {
  if (device == 'png') {
    ggsave(path, p, width = width, height = height, dpi = dpi, units = 'in')
  } else {
    ggsave(path, p, width = width, height = height, units = 'in', device = device)
  }
}
tryCatch({
  save_one(file.path(output_dir, 'result.svg'), 'svg')
  save_one(file.path(output_dir, 'result.pdf'), 'pdf')
  save_one(file.path(output_dir, 'result.png'), 'png')
}, error = function(e) write_error_and_exit('Failed to save plot', conditionMessage(e)))

utils::write.csv(plot_df, file.path(output_dir, 'selected_rows.csv'), row.names = FALSE)
if (nrow(stat_df)) {
  utils::write.csv(stat_df, file.path(output_dir, 'regression_stats.csv'), row.names = FALSE)
}

figure_json <- list(
  figure_type = 'regression_scatter_plot',
  title = if (title_show) title else '',
  layout = list(width = width, height = height),
  analysis = list(
    n_points = nrow(plot_df),
    groups = groups,
    method = reg_method,
    regression = if (nrow(stat_df)) stat_df else NULL
  ),
  layers = list(
    list(id = 'points', type = 'point', editable = TRUE),
    list(id = 'regression', type = 'smooth', editable = TRUE),
    list(id = 'ci', type = 'ribbon', editable = TRUE),
    list(id = 'stats_text', type = 'text', editable = TRUE),
    list(id = 'legend', type = 'legend', editable = TRUE)
  ),
  export = list(
    svg = 'result.svg', pdf = 'result.pdf', png = 'result.png',
    selected_rows = 'selected_rows.csv',
    regression_stats = if (nrow(stat_df)) 'regression_stats.csv' else NULL
  )
)
writeLines(
  jsonlite::toJSON(figure_json, auto_unbox = TRUE, pretty = TRUE, null = 'null'),
  file.path(output_dir, 'figure.json')
)

write_log('Plugin completed successfully.')
quit(status = 0)
