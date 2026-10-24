#!/usr/bin/env Rscript

# BioFigureAI Plot Plugin: Highlight Effect Plot
# ------------------------------------------------------------
# Focus categories → large points + error bars (mean ± CI)
# Non-highlight terms → single "Other" lane, individual jittered
# gray points (the distinctive treatment in the reference figure).
#
# Runtime:
#   Rscript plot.R --input input.csv --params params.json --output out
#
# Input modes:
#   points  - one row per observation (category, value [, pvalue])
#   summary - pre-aggregated (category, mean, ci_low, ci_high [, pvalue, highlight])

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
})

option_list <- list(
  make_option('--input', type = 'character', default = NULL),
  make_option('--params', type = 'character', default = NULL),
  make_option('--output', type = 'character', default = NULL)
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

write_log <- function(msg) {
  cat(sprintf('[%s] %s\n', format(Sys.time(), '%F %T'), msg),
      file = file.path(output_dir, 'run.log'), append = TRUE)
}

write_error_and_exit <- function(error, detail = NULL, suggestion = NULL, status = 1) {
  if (is.null(output_dir) || !nzchar(as.character(output_dir %||% ''))) output_dir <<- getwd()
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  writeLines(
    jsonlite::toJSON(list(error = error, detail = as.character(detail %||% ''),
                          suggestion = as.character(suggestion %||% '')),
                     auto_unbox = TRUE, pretty = TRUE),
    file.path(output_dir, 'error.json')
  )
  message(error)
  quit(status = status)
}

read_table_auto <- function(path) {
  if (is.null(path) || !file.exists(path)) {
    write_error_and_exit('Input file not found', paste('path:', path))
  }
  ext <- tolower(tools::file_ext(path))
  if (ext == 'csv') return(read.csv(path, check.names = FALSE, stringsAsFactors = FALSE))
  if (ext %in% c('tsv', 'txt')) return(read.delim(path, check.names = FALSE, stringsAsFactors = FALSE))
  tryCatch(read.csv(path, check.names = FALSE, stringsAsFactors = FALSE),
           error = function(e) read.delim(path, check.names = FALSE, stringsAsFactors = FALSE))
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

p_to_stars <- function(p, thresholds = c(0.001, 0.01, 0.05), labels = c('***', '**', '*')) {
  if (is.null(p) || !is.finite(p)) return('')
  for (i in seq_along(thresholds)) {
    if (p < thresholds[i]) return(labels[i])
  }
  ''
}

# ------------------------------------------------------------
tryCatch({
  if (is.null(output_dir) || !nzchar(output_dir)) write_error_and_exit('Missing --output')
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  if (file.exists(file.path(output_dir, 'error.json'))) unlink(file.path(output_dir, 'error.json'))
  write_log('Starting highlight_effect_plot')

  if (is.null(params_file) || !file.exists(params_file)) {
    write_error_and_exit('Missing params.json', params_file)
  }
  params <- jsonlite::fromJSON(params_file, simplifyVector = FALSE)
  raw <- read_table_auto(input_file)
  cols <- names(raw)

  mode <- tolower(as.character(get_param(params, 'input_mode', 'auto') %||% 'auto')[1])
  cat_col <- as.character(get_param(params, 'category_column', 'category') %||% 'category')[1]
  # aliases
  if (!cat_col %in% cols) {
    for (a in c('term', 'label', 'group', 'name', 'celltype', 'cell_type')) {
      if (a %in% cols) { cat_col <- a; break }
    }
  }
  val_col <- as.character(get_param(params, 'value_column', 'value') %||% 'value')[1]
  if (!val_col %in% cols) {
    for (a in c('mean', 'score', 'effect', 'estimate', 'x', 'nes', 'log2fc')) {
      if (a %in% cols) { val_col <- a; break }
    }
  }
  mean_col <- as.character(get_param(params, 'mean_column', 'mean') %||% 'mean')[1]
  ci_low_col <- as.character(get_param(params, 'ci_low_column', 'ci_low') %||% 'ci_low')[1]
  ci_high_col <- as.character(get_param(params, 'ci_high_column', 'ci_high') %||% 'ci_high')[1]
  se_col <- as.character(get_param(params, 'se_column', 'se') %||% 'se')[1]
  p_col <- as.character(get_param(params, 'pvalue_column', 'pvalue') %||% 'pvalue')[1]
  if (!p_col %in% cols) {
    for (a in c('p', 'padj', 'p_val', 'p_value', 'fdr', 'qvalue')) {
      if (a %in% cols) { p_col <- a; break }
    }
  }
  hl_col <- as.character(get_param(params, 'highlight_column', 'highlight') %||% 'highlight')[1]

  if (mode == 'auto') {
    if (mean_col %in% cols && (ci_low_col %in% cols || se_col %in% cols)) mode <- 'summary'
    else mode <- 'points'
  }
  write_log(sprintf('Input mode: %s', mode))

  # ---- which categories are highlighted ----
  highlight_terms <- as_chr_vec(get_param(params, 'highlight_terms', NULL))
  # also accept highlight_categories, focus_terms
  if (!length(highlight_terms)) {
    highlight_terms <- as_chr_vec(get_param(params, 'highlight_categories', NULL))
  }
  if (!length(highlight_terms)) {
    highlight_terms <- as_chr_vec(get_param(params, 'focus_terms', NULL))
  }

  other_label <- as.character(get_param(params, 'other_label', 'Other biosamples') %||% 'Other biosamples')[1]
  collapse_others <- as_bool(get_param(params, 'collapse_others', TRUE), TRUE)
  # TRUE (default): non-highlight → one shared y-lane with individual points
  # FALSE: each non-highlight category keeps its own row (still gray / smaller)

  ci_level <- as_num(get_param(params, 'ci_level', 0.95), 0.95)
  z_crit <- stats::qnorm(1 - (1 - ci_level) / 2)

  points_df <- NULL   # individual non-highlight (or all) points for jitter
  summary_df <- NULL  # highlight summaries with CI

  if (mode == 'points') {
    if (!cat_col %in% cols || !val_col %in% cols) {
      write_error_and_exit(
        'Missing category/value columns',
        paste('Need', cat_col, 'and', val_col, '; have:', paste(cols, collapse = ', '))
      )
    }
    df <- data.frame(
      category = as.character(raw[[cat_col]]),
      value = suppressWarnings(as.numeric(raw[[val_col]])),
      stringsAsFactors = FALSE
    )
    if (p_col %in% cols) df$pvalue <- suppressWarnings(as.numeric(raw[[p_col]]))
    else df$pvalue <- NA_real_
    if (hl_col %in% cols) {
      hl_raw <- raw[[hl_col]]
      df$is_highlight <- if (is.logical(hl_raw)) hl_raw else tolower(as.character(hl_raw)) %in% c('true', '1', 'yes', 'on', 'highlight', 'focus')
    } else {
      df$is_highlight <- FALSE
    }
    df <- df[is.finite(df$value) & !is.na(df$category) & nzchar(df$category), , drop = FALSE]

    # determine highlight set
    if (length(highlight_terms)) {
      df$is_highlight <- df$category %in% highlight_terms
    } else if (!any(df$is_highlight)) {
      # default: top-N categories by mean value
      n_focus <- as.integer(as_num(get_param(params, 'auto_highlight_n', 4), 4))
      means <- tapply(df$value, df$category, mean, na.rm = TRUE)
      highlight_terms <- names(sort(means, decreasing = TRUE))[seq_len(min(n_focus, length(means)))]
      df$is_highlight <- df$category %in% highlight_terms
      write_log(sprintf('Auto-highlight top %d by mean: %s', length(highlight_terms), paste(highlight_terms, collapse = ', ')))
    } else {
      highlight_terms <- unique(df$category[df$is_highlight])
    }

    # filters
    cats_include <- as_chr_vec(get_param(params, 'categories_include', NULL))
    cats_exclude <- as_chr_vec(get_param(params, 'categories_exclude', NULL))
    if (length(cats_include)) df <- df[df$category %in% cats_include, , drop = FALSE]
    if (length(cats_exclude)) df <- df[!df$category %in% cats_exclude, , drop = FALSE]

    # summary for highlight (and optionally non-highlight if not collapsing)
    agg_one <- function(sub) {
      m <- mean(sub$value, na.rm = TRUE)
      s <- stats::sd(sub$value, na.rm = TRUE)
      n <- sum(is.finite(sub$value))
      se <- if (n > 1) s / sqrt(n) else 0
      # prefer SE from data; CI from SE
      ci_l <- m - z_crit * se
      ci_h <- m + z_crit * se
      # pvalue: take first non-NA or min
      p <- if (all(is.na(sub$pvalue))) NA_real_ else min(sub$pvalue, na.rm = TRUE)
      data.frame(mean = m, se = se, ci_low = ci_l, ci_high = ci_h, n = n, pvalue = p, stringsAsFactors = FALSE)
    }

    hl_cats <- unique(df$category[df$is_highlight])
    # respect order from highlight_terms then data
    hl_order <- as_chr_vec(get_param(params, 'highlight_order', NULL))
    if (!length(hl_order)) hl_order <- highlight_terms
    hl_cats <- c(hl_order[hl_order %in% hl_cats], setdiff(hl_cats, hl_order))

    sum_list <- lapply(hl_cats, function(cat) {
      s <- agg_one(df[df$category == cat, , drop = FALSE])
      s$category <- cat
      s$is_highlight <- TRUE
      s
    })
    summary_df <- do.call(rbind, sum_list)

    # non-highlight points
    other_pts <- df[!df$is_highlight, , drop = FALSE]
    if (nrow(other_pts)) {
      if (collapse_others) {
        other_pts$plot_category <- other_label
      } else {
        other_pts$plot_category <- other_pts$category
      }
      points_df <- other_pts
    }

    # also keep individual highlight points if requested
    show_hl_points <- as_bool(get_param(params, 'show_highlight_raw_points', FALSE), FALSE)
    if (show_hl_points) {
      hp <- df[df$is_highlight, , drop = FALSE]
      hp$plot_category <- hp$category
      points_df <- rbind(points_df, hp)
    }

  } else {
    # summary mode
    if (!cat_col %in% cols) write_error_and_exit('Missing category column in summary input')
    mean_use <- if (mean_col %in% cols) mean_col else if (val_col %in% cols) val_col else NULL
    if (is.null(mean_use)) write_error_and_exit('Missing mean/value column')

    summary_df <- data.frame(
      category = as.character(raw[[cat_col]]),
      mean = suppressWarnings(as.numeric(raw[[mean_use]])),
      stringsAsFactors = FALSE
    )
    if (ci_low_col %in% cols && ci_high_col %in% cols) {
      summary_df$ci_low <- suppressWarnings(as.numeric(raw[[ci_low_col]]))
      summary_df$ci_high <- suppressWarnings(as.numeric(raw[[ci_high_col]]))
    } else if (se_col %in% cols) {
      se <- suppressWarnings(as.numeric(raw[[se_col]]))
      summary_df$ci_low <- summary_df$mean - z_crit * se
      summary_df$ci_high <- summary_df$mean + z_crit * se
      summary_df$se <- se
    } else {
      summary_df$ci_low <- summary_df$mean
      summary_df$ci_high <- summary_df$mean
    }
    if (p_col %in% cols) summary_df$pvalue <- suppressWarnings(as.numeric(raw[[p_col]]))
    else summary_df$pvalue <- NA_real_

    if (hl_col %in% cols) {
      hl_raw <- raw[[hl_col]]
      summary_df$is_highlight <- if (is.logical(hl_raw)) hl_raw else tolower(as.character(hl_raw)) %in% c('true', '1', 'yes', 'on')
    } else if (length(highlight_terms)) {
      summary_df$is_highlight <- summary_df$category %in% highlight_terms
    } else {
      n_focus <- as.integer(as_num(get_param(params, 'auto_highlight_n', 4), 4))
      o <- order(summary_df$mean, decreasing = TRUE)
      summary_df$is_highlight <- FALSE
      summary_df$is_highlight[o[seq_len(min(n_focus, nrow(summary_df)))]] <- TRUE
      highlight_terms <- summary_df$category[summary_df$is_highlight]
    }

    # non-highlight: if only summary available, plot as small points at mean (no jitter cloud of individuals)
    others <- summary_df[!summary_df$is_highlight, , drop = FALSE]
    if (nrow(others)) {
      points_df <- data.frame(
        category = others$category,
        value = others$mean,
        pvalue = others$pvalue,
        is_highlight = FALSE,
        plot_category = if (collapse_others) other_label else others$category,
        stringsAsFactors = FALSE
      )
    }
    summary_df <- summary_df[summary_df$is_highlight, , drop = FALSE]
  }

  if (is.null(summary_df) || !nrow(summary_df)) {
    write_error_and_exit(
      'No highlighted categories to plot',
      'Set highlight_terms or provide a highlight column.',
      'Example: "highlight_terms": ["Normoblasts","Erythroblasts"]'
    )
  }

  # ---- y-axis order: highlights top → other at bottom ----
  hl_order <- as_chr_vec(get_param(params, 'highlight_order', NULL))
  if (!length(hl_order)) hl_order <- highlight_terms
  y_levels <- c(
    hl_order[hl_order %in% summary_df$category],
    setdiff(summary_df$category, hl_order)
  )
  other_at <- tolower(as.character(get_param(params, 'other_position', 'bottom') %||% 'bottom')[1])
  # bottom (default) or top
  if (collapse_others && !is.null(points_df) && nrow(points_df)) {
    if (other_at == 'top') y_levels <- c(other_label, y_levels)
    else y_levels <- c(y_levels, other_label)
  } else if (!collapse_others && !is.null(points_df) && nrow(points_df)) {
    other_cats <- unique(points_df$plot_category)
    if (other_at == 'top') y_levels <- c(other_cats, y_levels)
    else y_levels <- c(y_levels, other_cats)
  }
  reverse_y <- as_bool(get_param(params, 'reverse_y', TRUE), TRUE)
  # reverse so first highlight is at top (ggplot y discrete: first level at bottom unless reverse)
  if (reverse_y) y_levels <- rev(y_levels)

  summary_df$y <- factor(summary_df$category, levels = y_levels)
  if (!is.null(points_df) && nrow(points_df)) {
    points_df$y <- factor(points_df$plot_category, levels = y_levels)
  }

  # significance stars
  star_show <- as_bool(get_param(params, 'stars_show', TRUE), TRUE)
  thr <- suppressWarnings(as.numeric(unlist(get_param(params, 'star_thresholds', c(0.001, 0.01, 0.05)))))
  if (!length(thr) || any(!is.finite(thr))) thr <- c(0.001, 0.01, 0.05)
  star_labels <- as_chr_vec(get_param(params, 'star_labels', c('***', '**', '*')))
  if (length(star_labels) < length(thr)) {
    star_labels <- c(star_labels, rep('*', length(thr) - length(star_labels)))
  }
  p_override <- named_chr(get_param(params, 'pvalue_map', NULL))
  # also accept stars_map directly
  stars_map <- named_chr(get_param(params, 'stars_map', NULL))

  summary_df$stars <- ''
  if (star_show) {
    for (i in seq_len(nrow(summary_df))) {
      cat <- summary_df$category[i]
      if (cat %in% names(stars_map) && nzchar(stars_map[[cat]])) {
        summary_df$stars[i] <- stars_map[[cat]]
        next
      }
      p <- summary_df$pvalue[i]
      if (cat %in% names(p_override)) p <- suppressWarnings(as.numeric(p_override[[cat]]))
      summary_df$stars[i] <- p_to_stars(p, thr, star_labels)
    }
  }

  # ---- style ----
  hl_colors <- named_chr(get_param(params, 'highlight_colors', NULL))
  default_hl_palette <- c('#1A0A2E', '#2D1B4E', '#3D2A5C', '#7B2D8E', '#9B4DCA', '#C77DFF')
  if (!length(hl_colors)) {
    pal <- as_chr_vec(get_param(params, 'highlight_palette', NULL))
    if (!length(pal)) pal <- default_hl_palette
    cats <- as.character(summary_df$category)
    hl_colors <- setNames(rep(pal, length.out = length(cats)), cats)
  }
  # single color for all highlights?
  single_hl <- as.character(get_param(params, 'highlight_color', '') %||% '')[1]
  summary_df$color <- unname(hl_colors[summary_df$category])
  summary_df$color[is.na(summary_df$color) | !nzchar(summary_df$color)] <- default_hl_palette[1]
  if (nzchar(single_hl)) summary_df$color <- single_hl

  other_color <- as.character(get_param(params, 'other_color', '#B0B0B0') %||% '#B0B0B0')[1]
  other_alpha <- as_num(get_param(params, 'other_alpha', 0.75), 0.75)
  other_size <- as_num(get_param(params, 'other_point_size', 1.8), 1.8)
  other_shape <- as.integer(as_num(get_param(params, 'other_point_shape', 16), 16))
  jitter_width <- as_num(get_param(params, 'jitter_width', 0.55), 0.55)
  jitter_height <- as_num(get_param(params, 'jitter_height', 0.22), 0.22)
  jitter_seed <- as.integer(as_num(get_param(params, 'jitter_seed', 1), 1))

  hl_size <- as_num(get_param(params, 'highlight_point_size', 4.5), 4.5)
  hl_shape <- as.integer(as_num(get_param(params, 'highlight_point_shape', 16), 16))
  hl_stroke <- as_num(get_param(params, 'highlight_point_stroke', 0), 0)
  hl_border <- as.character(get_param(params, 'highlight_border_color', NA) %||% NA)[1]

  errorbar_height <- as_num(get_param(params, 'errorbar_height', 0.18), 0.18)
  errorbar_width <- as_num(get_param(params, 'errorbar_linewidth', 0.55), 0.55)
  errorbar_color_mode <- tolower(as.character(get_param(params, 'errorbar_color_mode', 'match') %||% 'match')[1])
  # match | fixed
  errorbar_color_fixed <- as.character(get_param(params, 'errorbar_color', '#333333') %||% '#333333')[1]

  star_size <- as_num(get_param(params, 'star_size', 4.2), 4.2)
  star_color <- as.character(get_param(params, 'star_color', '#222222') %||% '#222222')[1]
  star_nudge <- as_num(get_param(params, 'star_nudge', 0.6), 0.6)
  star_face <- as.character(get_param(params, 'star_face', 'plain') %||% 'plain')[1]

  # axes / canvas
  W <- as_num(get_param(params, 'width', 6.5), 6.5)
  H <- as_num(get_param(params, 'height', 4.2), 4.2)
  dpi <- as_num(get_param(params, 'dpi', 300), 300)
  bg <- as.character(get_param(params, 'background_color', '#FFFFFF') %||% '#FFFFFF')[1]
  base_size <- as_num(get_param(params, 'base_size', 12), 12)
  font_family <- as.character(get_param(params, 'font_family', 'sans') %||% 'sans')[1]

  xlab <- as.character(get_param(params, 'xlab', '') %||% '')[1]
  ylab <- as.character(get_param(params, 'ylab', '') %||% '')[1]
  xlab_show <- as_bool(get_param(params, 'xlab_show', nzchar(xlab)), nzchar(xlab))
  ylab_show <- as_bool(get_param(params, 'ylab_show', FALSE), FALSE)
  x_text_size <- as_num(get_param(params, 'x_text_size', 10), 10)
  y_text_size <- as_num(get_param(params, 'y_text_size', 11), 11)
  x_text_color <- as.character(get_param(params, 'x_text_color', '#333333') %||% '#333333')[1]
  y_text_color <- as.character(get_param(params, 'y_text_color', '#333333') %||% '#333333')[1]
  axis_line_color <- as.character(get_param(params, 'axis_line_color', '#333333') %||% '#333333')[1]
  axis_line_width <- as_num(get_param(params, 'axis_line_width', 0.5), 0.5)
  tick_color <- as.character(get_param(params, 'tick_color', '#333333') %||% '#333333')[1]
  grid_show <- as_bool(get_param(params, 'grid_show', FALSE), FALSE)
  grid_color <- as.character(get_param(params, 'grid_color', '#EEEEEE') %||% '#EEEEEE')[1]

  xlim <- get_param(params, 'xlim', NULL)
  x_min <- if (!is.null(xlim) && length(xlim) >= 1) as_num(xlim[[1]], NA) else as_num(get_param(params, 'xmin', NA), NA)
  x_max <- if (!is.null(xlim) && length(xlim) >= 2) as_num(xlim[[2]], NA) else as_num(get_param(params, 'xmax', NA), NA)

  title_show <- as_bool(get_param(params, 'title_show', FALSE), FALSE)
  title <- as.character(get_param(params, 'title', '') %||% '')[1]
  subtitle <- get_param(params, 'subtitle', NULL)
  if (!is.null(subtitle)) subtitle <- as.character(subtitle)[1]

  # expand x for stars
  x_all <- c(summary_df$mean, summary_df$ci_low, summary_df$ci_high)
  if (!is.null(points_df) && nrow(points_df)) x_all <- c(x_all, points_df$value)
  x_all <- x_all[is.finite(x_all)]
  if (!is.finite(x_min)) x_min <- min(x_all, na.rm = TRUE) - 0.5
  if (!is.finite(x_max)) {
    x_max <- max(x_all, na.rm = TRUE)
    if (star_show && any(nzchar(summary_df$stars))) x_max <- x_max + star_nudge + 1.2
    else x_max <- x_max + 0.8
  }

  # ---- plot ----
  set.seed(jitter_seed)
  g <- ggplot()

  # 1) non-highlight cloud FIRST (underneath)
  if (!is.null(points_df) && nrow(points_df)) {
    g <- g + geom_jitter(
      data = points_df,
      aes(x = value, y = y),
      width = jitter_width,
      height = jitter_height,
      size = other_size,
      shape = other_shape,
      color = other_color,
      alpha = other_alpha,
      stroke = 0
    )
  }

  # 2) error bars for highlights
  eb_col <- if (errorbar_color_mode == 'fixed') errorbar_color_fixed else summary_df$color
  g <- g + geom_errorbarh(
    data = summary_df,
    aes(y = y, xmin = ci_low, xmax = ci_high),
    height = errorbar_height,
    linewidth = errorbar_width,
    color = eb_col
  )

  # 3) highlight points
  if (nzchar(as.character(hl_border)) && !is.na(hl_border) && hl_border != 'NA') {
    g <- g + geom_point(
      data = summary_df,
      aes(x = mean, y = y),
      size = hl_size,
      shape = hl_shape,
      fill = summary_df$color,
      color = hl_border,
      stroke = max(0.4, hl_stroke),
      alpha = 1
    )
  } else {
    g <- g + geom_point(
      data = summary_df,
      aes(x = mean, y = y),
      size = hl_size,
      shape = hl_shape,
      color = summary_df$color,
      alpha = 1
    )
  }

  # 4) significance stars to the right of CI
  if (star_show && any(nzchar(summary_df$stars))) {
    star_df <- summary_df[nzchar(summary_df$stars), , drop = FALSE]
    star_df$x_star <- star_df$ci_high + star_nudge
    g <- g + geom_text(
      data = star_df,
      aes(x = x_star, y = y, label = stars),
      size = star_size,
      color = star_color,
      fontface = star_face,
      hjust = 0,
      vjust = 0.5,
      family = font_family
    )
  }

  g <- g + scale_y_discrete(drop = FALSE)
  g <- g + scale_x_continuous(limits = c(x_min, x_max), expand = expansion(mult = c(0.02, 0.02)))
  g <- g + labs(
    x = if (xlab_show) xlab else NULL,
    y = if (ylab_show) ylab else NULL,
    title = if (title_show && nzchar(title)) title else NULL,
    subtitle = subtitle
  )

  g <- g + theme_classic(base_size = base_size, base_family = font_family)
  g <- g + theme(
    plot.background = element_rect(fill = bg, colour = NA),
    panel.background = element_rect(fill = bg, colour = NA),
    axis.line = element_line(colour = axis_line_color, linewidth = axis_line_width),
    axis.ticks = element_line(colour = tick_color, linewidth = axis_line_width * 0.9),
    axis.text.x = element_text(size = x_text_size, colour = x_text_color),
    axis.text.y = element_text(size = y_text_size, colour = y_text_color),
    axis.title.x = element_text(size = x_text_size + 1, colour = x_text_color),
    axis.title.y = element_text(size = y_text_size + 1, colour = y_text_color),
    panel.grid.major.x = if (grid_show) element_line(colour = grid_color, linewidth = 0.3) else element_blank(),
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(),
    legend.position = 'none',
    plot.margin = margin(
      as_num(get_param(params, 'margin_top', 8), 8),
      as_num(get_param(params, 'margin_right', 14), 14),
      as_num(get_param(params, 'margin_bottom', 8), 8),
      as_num(get_param(params, 'margin_left', 8), 8)
    )
  )

  # optional panel panel letter "e" style via caption is skipped; user can title

  write_log('Rendering SVG/PDF/PNG')
  save_one <- function(dev_fn) {
    dev_fn()
    print(g)
    grDevices::dev.off()
  }
  save_one(function() svglite::svglite(file.path(output_dir, 'result.svg'), width = W, height = H))
  save_one(function() grDevices::cairo_pdf(file.path(output_dir, 'result.pdf'), width = W, height = H))
  save_one(function() (if (requireNamespace('ragg', quietly = TRUE)) ragg::agg_png else function(...) grDevices::png(..., type = 'cairo'))(
    file.path(output_dir, 'result.png'), width = W, height = H, units = 'in', res = dpi))

  write.csv(summary_df, file.path(output_dir, 'summary_used.csv'), row.names = FALSE)
  if (!is.null(points_df) && nrow(points_df)) {
    write.csv(points_df, file.path(output_dir, 'points_used.csv'), row.names = FALSE)
  } else {
    write.csv(data.frame(), file.path(output_dir, 'points_used.csv'), row.names = FALSE)
  }

  meta <- list(
    plugin = 'highlight_effect_plot',
    engine = 'ggplot2',
    input_mode = mode,
    n_highlight = nrow(summary_df),
    highlight_terms = as.character(summary_df$category),
    other_label = other_label,
    collapse_others = collapse_others,
    n_other_points = if (!is.null(points_df)) nrow(points_df) else 0,
    ci_level = ci_level,
    outputs = c('result.svg', 'result.pdf', 'result.png', 'summary_used.csv', 'points_used.csv')
  )
  writeLines(jsonlite::toJSON(meta, auto_unbox = TRUE, pretty = TRUE, null = 'null'),
             file.path(output_dir, 'figure.json'))
  write_log('Completed highlight_effect_plot')
  quit(status = 0)

}, error = function(e) {
  write_error_and_exit(
    'Highlight effect plot failed',
    conditionMessage(e),
    'Provide category+value columns and highlight_terms (or a highlight column).'
  )
})
