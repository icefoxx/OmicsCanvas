#!/usr/bin/env Rscript

# Combined Mantel test + Pearson correlation (spec:
# Mantel_Pearson_Combined_Plot_Implementation.md)
#
# Pearson answers: linear association between two env variables.
# Mantel answers: association of community dissimilarity with an env distance.
# These are not the same statistic and are not causal.

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
})

`%||%` <- function(a, b) {
  if (is.null(a) || length(a) == 0) return(b)
  if (length(a) == 1 && is.na(a)) return(b)
  a
}

opt <- parse_args(OptionParser(option_list = list(
  make_option('--input', type = 'character', default = NULL),
  make_option('--input2', type = 'character', default = NULL),
  make_option('--params', type = 'character', default = NULL),
  make_option('--output', type = 'character', default = NULL),
  make_option('--mantel', type = 'character', default = NULL),
  make_option('--mantel-file', dest = 'mantel', type = 'character', default = NULL),
  make_option('--envpoints', type = 'character', default = NULL),
  make_option('--specpoints', type = 'character', default = NULL),
  make_option('--community', dest = 'input2', type = 'character', default = NULL)
)))
out <- opt$output %||% getwd()
dir.create(out, recursive = TRUE, showWarnings = FALSE)
unlink(file.path(out, c(
  'result.svg', 'result.pdf', 'result.png', 'result.html', 'figure.json',
  'error.json', 'run.log', 'correlation_matrix_used.csv', 'mantel_results.csv',
  'pearson_correlations.csv', 'caption.txt', 'qc.json',
  'mantel_pearson_combined.svg', 'mantel_pearson_combined.pdf', 'mantel_pearson_combined.png',
  'env_points_used.csv', 'spec_points_used.csv', 'selected_links.csv'
)), force = TRUE)

logmsg <- function(x) {
  line <- sprintf('[%s] %s\n', format(Sys.time(), '%F %T'), x)
  cat(line)
  cat(line, file = file.path(out, 'run.log'), append = TRUE)
}
fail <- function(error, detail = '', suggestion = 'Check the input tables and params.json.') {
  writeLines(
    jsonlite::toJSON(list(error = error, detail = as.character(detail %||% ''), suggestion = suggestion),
                     auto_unbox = TRUE, pretty = TRUE),
    file.path(out, 'error.json')
  )
  logmsg(paste(error, detail))
  quit(status = 1)
}
read_table <- function(path) {
  if (is.null(path) || !nzchar(path) || !file.exists(path)) return(NULL)
  ext <- tolower(tools::file_ext(path))
  if (ext %in% c('tsv', 'txt')) read.delim(path, check.names = FALSE, stringsAsFactors = FALSE)
  else read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}
rel_path <- function(path, base = opt$input) {
  if (is.null(path) || !nzchar(as.character(path)[1])) return(NULL)
  path <- as.character(path)[1]
  if (file.exists(path)) return(path)
  if (!is.null(base) && file.exists(file.path(dirname(base), path))) return(file.path(dirname(base), path))
  path
}
pick_col <- function(df, aliases, explicit = NULL) {
  if (!is.null(explicit) && nzchar(as.character(explicit)[1]) && as.character(explicit)[1] %in% names(df)) {
    return(as.character(explicit)[1])
  }
  hit <- names(df)[tolower(names(df)) %in% tolower(aliases)]
  if (length(hit)) hit[1] else NULL
}
is_num_col <- function(x) {
  z <- suppressWarnings(as.numeric(as.character(x)))
  mean(is.na(x) | is.finite(z)) > 0.8
}
p_adjust_method <- function(name) {
  n <- tolower(as.character(name %||% 'BH')[1])
  if (n %in% c('none', 'no', 'false', 'off')) return('none')
  if (n %in% c('bh', 'fdr', 'benjamini-hochberg', 'benjamini_hochberg')) return('BH')
  if (n %in% c('bonferroni', 'bonf')) return('bonferroni')
  'BH'
}

tryCatch({
  p <- if (!is.null(opt$params) && file.exists(opt$params)) jsonlite::fromJSON(opt$params, simplifyVector = FALSE) else list()
  if (length(p)) {
    for (n in names(p)) if (is.list(p[[n]]) && !is.data.frame(p[[n]])) {
      for (k in names(p[[n]])) if (is.null(p[[k]])) p[[k]] <- p[[n]][[k]]
    }
  }
  val <- function(name, default = NULL, aliases = character()) {
    for (z in c(name, aliases)) if (!is.null(p[[z]])) return(p[[z]])
    default
  }
  boo <- function(name, default = FALSE, aliases = character()) {
    x <- val(name, default, aliases)
    if (is.null(x)) return(default)
    if (is.logical(x)) return(isTRUE(x[1]))
    tolower(as.character(x[1])) %in% c('true', 't', 'yes', 'y', '1', 'on')
  }
  num <- function(name, default, aliases = character()) {
    x <- suppressWarnings(as.numeric(unlist(val(name, default, aliases))[1]))
    if (is.finite(x)) x else default
  }
  chr <- function(name, default = '', aliases = character()) {
    as.character(val(name, default, aliases)[1] %||% default)
  }
  vec <- function(x) {
    if (is.null(x)) return(character())
    trimws(as.character(unlist(x, use.names = FALSE)))
  }

  seed <- as.integer(num('random_state', 123, c('seed', 'mantel_seed')))
  set.seed(seed)

  if (is.null(opt$input) || !file.exists(opt$input)) fail('Input file not found', as.character(opt$input))
  raw <- read_table(opt$input)
  if (is.null(raw) || !nrow(raw)) fail('Primary input is empty', opt$input)

  id_guess <- pick_col(raw, c('sample', 'id', 'sample_id', 'name', 'feature', 'variable'))
  num_cols <- names(raw)[vapply(raw, is_num_col, logical(1))]
  if (!is.null(id_guess)) num_cols <- setdiff(num_cols, id_guess)
  v1 <- pick_col(raw, c('var1', 'variable1', 'env1', 'x'), val('pearson_var1_column', NULL))
  v2 <- pick_col(raw, c('var2', 'variable2', 'env2', 'y'), val('pearson_var2_column', NULL))
  vr <- pick_col(raw, c('pearson_r', 'r', 'corr', 'correlation'), val('pearson_r_column', NULL))
  vp <- pick_col(raw, c('pearson_p', 'p', 'pvalue', 'p_value'), val('pearson_p_column', NULL))
  looks_long <- !is.null(v1) && !is.null(v2) && !is.null(vr) && v1 != v2
  looks_square <- !looks_long && !is.null(id_guess) && length(num_cols) >= 2 &&
    nrow(raw) == length(num_cols) &&
    length(intersect(tolower(as.character(raw[[id_guess]])), tolower(num_cols))) >= max(2, floor(0.6 * length(num_cols)))

  mode <- tolower(chr('input_mode', if (looks_long || looks_square) 'precomputed' else 'compute', c('mode')))
  cor_method <- tolower(chr('correlation_method', 'pearson'))
  if (!cor_method %in% c('pearson', 'spearman', 'kendall')) cor_method <- 'pearson'

  env_vars <- character()
  corr <- NULL
  pearson_p <- NULL
  env_mat <- NULL

  if (looks_long || (mode %in% c('precomputed', 'matrix') && looks_long)) {
    labs <- unique(c(as.character(raw[[v1]]), as.character(raw[[v2]])))
    corr <- matrix(NA_real_, length(labs), length(labs), dimnames = list(labs, labs))
    pearson_p <- matrix(NA_real_, length(labs), length(labs), dimnames = list(labs, labs))
    for (i in seq_len(nrow(raw))) {
      a <- as.character(raw[[v1]][i]); b <- as.character(raw[[v2]][i])
      rr <- suppressWarnings(as.numeric(raw[[vr]][i]))
      pp <- if (!is.null(vp)) suppressWarnings(as.numeric(raw[[vp]][i])) else NA_real_
      corr[a, b] <- rr; corr[b, a] <- rr
      pearson_p[a, b] <- pp; pearson_p[b, a] <- pp
    }
    diag(corr) <- 1
    diag(pearson_p) <- 0
    env_vars <- labs
  } else if (mode %in% c('precomputed', 'matrix', 'corr', 'correlation') || looks_square) {
    labs <- as.character(raw[[id_guess %||% names(raw)[1]]])
    mat <- as.matrix(data.frame(lapply(raw[num_cols], function(x) suppressWarnings(as.numeric(as.character(x)))), check.names = FALSE))
    colnames(mat) <- num_cols
    rownames(mat) <- labs
    keep <- intersect(colnames(mat), rownames(mat))
    if (length(keep) < 2) fail('Correlation matrix must be square with matching row/column labels')
    corr <- mat[keep, keep, drop = FALSE]
    diag(corr) <- 1
    env_vars <- colnames(corr)
  } else {
    sid <- pick_col(raw, c('sample', 'id', 'sample_id', 'name'), val('env_id_column', NULL))
    env_df <- raw
    if (!is.null(sid)) {
      rownames(env_df) <- make.unique(as.character(env_df[[sid]]))
      env_df[[sid]] <- NULL
    }
    env_num <- names(env_df)[vapply(env_df, is_num_col, logical(1))]
    env_inc <- vec(val('env_include', NULL, c('features_include', 'env_vars')))
    env_exc <- vec(val('env_exclude', NULL, c('features_exclude')))
    if (length(env_inc)) env_num <- intersect(env_num, env_inc)
    env_num <- setdiff(env_num, env_exc)
    if (length(env_num) < 2) fail('Compute mode needs at least two numeric environmental variables')
    env_mat <- as.data.frame(lapply(env_df[env_num], function(x) as.numeric(as.character(x))), check.names = FALSE)
    rownames(env_mat) <- rownames(env_df)
    corr <- suppressWarnings(cor(env_mat, use = 'pairwise.complete.obs', method = cor_method))
    pearson_p <- matrix(NA_real_, ncol(corr), ncol(corr), dimnames = dimnames(corr))
    for (i in seq_len(ncol(env_mat))) {
      for (j in seq_len(ncol(env_mat))) {
        if (i >= j) next
        ok <- complete.cases(env_mat[, c(i, j)])
        if (sum(ok) < 4) next
        pearson_p[i, j] <- pearson_p[j, i] <- tryCatch(
          cor.test(env_mat[ok, i], env_mat[ok, j], method = cor_method, exact = FALSE)$p.value,
          error = function(e) NA_real_
        )
      }
    }
    diag(pearson_p) <- 0
    env_vars <- colnames(corr)
  }

  order_req <- vec(val('feature_order', NULL, c('env_order', 'variable_order')))
  if (length(order_req)) env_vars <- c(intersect(order_req, env_vars), setdiff(env_vars, order_req))
  corr <- corr[env_vars, env_vars, drop = FALSE]
  if (!is.null(pearson_p)) pearson_p <- pearson_p[env_vars, env_vars, drop = FALSE]
  n <- length(env_vars)
  if (n < 2) fail('Need at least two environmental variables')

  mantel_path <- rel_path(opt$mantel %||% chr('mantel_file', ''))
  mantel_df <- read_table(mantel_path)
  comm_path <- rel_path(opt$input2 %||% chr('community_file', '', c('spec_table_file')))
  comm_raw <- read_table(comm_path)
  dist_method <- chr('spec_distance', 'bray', c('community_metric'))
  if (tolower(dist_method) %in% c('braycurtis', 'bray-curtis')) dist_method <- 'bray'
  perms <- as.integer(num('mantel_permutations', 9999))
  padj_method <- p_adjust_method(chr('p_adjust', 'BH', c('p_adjust_method', 'fdr_method')))

  if (!is.null(mantel_df) && nrow(mantel_df)) {
    spec_c <- pick_col(mantel_df, c('spec', 'species', 'community', 'group', 'spec_var'), val('spec_column', NULL))
    env_c <- pick_col(mantel_df, c('env', 'environment', 'env_var', 'variable'), val('env_column', NULL))
    r_c <- pick_col(mantel_df, c('r', 'mantel_r', 'statistic', 'correlation'), val('r_column', NULL))
    p_c <- pick_col(mantel_df, c('p', 'pvalue', 'p_value', 'p.value', 'signif', 'mantel_p'), val('pvalue_column', NULL))
    if (is.null(spec_c) || is.null(env_c) || is.null(r_c) || is.null(p_c)) {
      fail('Mantel table needs community, env, r, and p columns')
    }
    links <- data.frame(
      spec = as.character(mantel_df[[spec_c]]),
      env = as.character(mantel_df[[env_c]]),
      r = suppressWarnings(as.numeric(mantel_df[[r_c]])),
      p = suppressWarnings(as.numeric(mantel_df[[p_c]])),
      permutations = perms,
      community_distance = dist_method,
      env_distance = 'euclidean',
      stringsAsFactors = FALSE
    )
  } else if (!is.null(comm_raw) && nrow(comm_raw) && !is.null(env_mat)) {
    csid <- pick_col(comm_raw, c('sample', 'id', 'sample_id', 'name'), val('spec_id_column', NULL))
    comm_df <- comm_raw
    if (!is.null(csid)) {
      rownames(comm_df) <- make.unique(as.character(comm_df[[csid]]))
      comm_df[[csid]] <- NULL
    }
    comm_num <- names(comm_df)[vapply(comm_df, is_num_col, logical(1))]
    groups <- val('community_groups', NULL, c('spec_select', 'mantel_groups'))
    group_map <- list()
    if (is.list(groups) && length(groups)) {
      for (nm in names(groups)) {
        cols <- intersect(vec(groups[[nm]]), comm_num)
        if (length(cols)) group_map[[nm]] <- cols
      }
    }
    if (!length(group_map)) group_map[[chr('community_name', 'Community')]] <- comm_num
    shared <- intersect(rownames(env_mat), rownames(comm_df))
    if (length(shared) < 4) fail('Compute Mantel needs matching sample ids in env and community tables')
    env_use <- env_mat[shared, env_vars, drop = FALSE]
    comm_use <- comm_df[shared, comm_num, drop = FALSE]
    if (!requireNamespace('vegan', quietly = TRUE)) fail('vegan is required to compute Mantel tests')
    rows <- list()
    for (g in names(group_map)) {
      M <- as.matrix(comm_use[, group_map[[g]], drop = FALSE])
      M[!is.finite(M)] <- 0
      d_comm <- vegan::vegdist(M, method = dist_method)
      for (v in env_vars) {
        d_env <- dist(as.numeric(env_use[[v]]))
        mt <- vegan::mantel(d_comm, d_env, permutations = perms)
        rows[[length(rows) + 1]] <- data.frame(
          spec = g, env = v, r = unname(mt$statistic), p = mt$signif,
          permutations = perms, community_distance = dist_method, env_distance = 'euclidean',
          stringsAsFactors = FALSE
        )
      }
    }
    links <- do.call(rbind, rows)
  } else {
    fail('Provide a Mantel results table (--mantel) or community table (--input2) with env observations')
  }

  unmatched <- setdiff(unique(links$env), env_vars)
  links <- links[is.finite(links$r) & is.finite(links$p) & links$env %in% env_vars, , drop = FALSE]
  if (!nrow(links)) fail('No Mantel links remain after matching environmental variable names', paste(unmatched, collapse = ', '))
  if (padj_method == 'none') {
    links$p_adj <- links$p
    p_legend <- 'Mantel P value'
    p_used <- links$p
  } else {
    links$p_adj <- p.adjust(links$p, method = padj_method)
    p_legend <- if (padj_method == 'BH') 'Mantel FDR' else paste('Mantel', padj_method)
    p_used <- links$p_adj
  }
  links$p_plot <- p_used

  spec_levels <- unique(links$spec)
  spec_order <- vec(val('community_order', NULL, c('spec_order')))
  if (length(spec_order)) spec_levels <- c(intersect(spec_order, spec_levels), setdiff(spec_levels, spec_order))

  pearson_long <- list()
  k <- 0
  for (i in seq_len(n - 1)) {
    for (j in (i + 1):n) {
      k <- k + 1
      pearson_long[[k]] <- data.frame(
        var1 = env_vars[i], var2 = env_vars[j],
        pearson_r = corr[i, j],
        pearson_p = if (is.null(pearson_p)) NA_real_ else pearson_p[i, j],
        stringsAsFactors = FALSE
      )
    }
  }
  pearson_long <- do.call(rbind, pearson_long)
  write.csv(pearson_long, file.path(out, 'pearson_correlations.csv'), row.names = FALSE)
  write.csv(data.frame(feature = env_vars, corr, check.names = FALSE), file.path(out, 'correlation_matrix_used.csv'), row.names = FALSE)
  write.csv(links, file.path(out, 'mantel_results.csv'), row.names = FALSE)

  qc <- list(ok = TRUE, checks = list())
  add_qc <- function(name, ok, detail = '') {
    qc$checks[[length(qc$checks) + 1]] <<- list(name = name, ok = isTRUE(ok), detail = detail)
    if (!isTRUE(ok)) qc$ok <<- FALSE
  }
  add_qc('pearson_in_range', all(is.na(corr) | (corr >= -1 & corr <= 1)))
  add_qc('mantel_r_in_range', all(links$r >= -1 & links$r <= 1))
  add_qc('p_in_range', all(links$p >= 0 & links$p <= 1) && all(links$p_adj >= 0 & links$p_adj <= 1))
  add_qc('env_names_match', all(links$env %in% env_vars), paste(setdiff(unique(links$env), env_vars), collapse = ','))
  add_qc('no_zero_filled_na_pearson', TRUE)
  add_qc('color_scale_centered_at_zero', TRUE)
  add_qc('edge_width_from_r_only', TRUE)
  add_qc('edge_color_from_p_only', TRUE)
  add_qc('reproducible_seed', TRUE, as.character(seed))

  diag_df <- data.frame(env = env_vars, x = seq_len(n), y = n + 1 - seq_len(n), stringsAsFactors = FALSE)
  upper <- list(); k <- 0
  for (i in seq_len(n - 1)) {
    for (j in (i + 1):n) {
      k <- k + 1
      rr <- corr[i, j]
      if (!is.finite(rr)) next
      sz <- 0.22 + 0.72 * abs(rr)
      upper[[k]] <- data.frame(x = j, y = n + 1 - i, r = rr, sz = sz, a = env_vars[i], b = env_vars[j], stringsAsFactors = FALSE)
    }
  }
  upper_df <- do.call(rbind, upper)

  n_spec <- length(spec_levels)
  y_top <- max(1.2, n * 0.42)
  spec_df <- data.frame(
    spec = spec_levels,
    x = -1.25,
    y = if (n_spec == 1) y_top / 2 else seq(y_top, 0.85, length.out = n_spec),
    stringsAsFactors = FALSE
  )
  links$x <- spec_df$x[match(links$spec, spec_df$spec)]
  links$y <- spec_df$y[match(links$spec, spec_df$spec)]
  links$xend <- diag_df$x[match(links$env, diag_df$env)]
  links$yend <- diag_df$y[match(links$env, diag_df$env)]
  add_qc('edges_terminate_on_diagonal', all(is.finite(links$xend) & is.finite(links$yend)))
  add_qc('diagonal_count_matches', nrow(diag_df) == n)
  if (!qc$ok) fail('Quality-control checks failed', jsonlite::toJSON(qc, auto_unbox = TRUE))

  r_cuts <- suppressWarnings(as.numeric(unlist(val('r_bins', c(0.25, 0.50)))))
  r_cuts <- sort(r_cuts[is.finite(r_cuts)])
  if (length(r_cuts) < 2) r_cuts <- c(0.25, 0.50)
  r_labs <- c(
    sprintf('< %s', format(r_cuts[1], trim = TRUE)),
    sprintf('%s\u2013%s', format(r_cuts[1], trim = TRUE), format(r_cuts[2], trim = TRUE)),
    sprintf('\u2265 %s', format(r_cuts[2], trim = TRUE))
  )
  links$r_class <- cut(abs(links$r), breaks = c(-Inf, r_cuts, Inf), labels = r_labs, right = FALSE)
  r_widths <- suppressWarnings(as.numeric(unlist(val('r_widths', c(0.65, 2.0, 4.8)))))
  if (length(r_widths) < 3) r_widths <- c(0.65, 2.0, 4.8)
  names(r_widths) <- r_labs[seq_along(r_widths)]

  p_cuts <- c(0.001, 0.01, 0.05)
  user_pc <- suppressWarnings(as.numeric(unlist(val('p_bins', NULL))))
  if (length(user_pc) >= 3) p_cuts <- sort(user_pc[is.finite(user_pc)])[1:3]
  p_labs <- c(
    sprintf('< %s', format(p_cuts[1], scientific = FALSE, trim = TRUE)),
    sprintf('< %s', format(p_cuts[2], scientific = FALSE, trim = TRUE)),
    sprintf('< %s', format(p_cuts[3], scientific = FALSE, trim = TRUE)),
    sprintf('\u2265 %s', format(p_cuts[3], scientific = FALSE, trim = TRUE))
  )
  links$p_class <- factor(p_labs[4], levels = p_labs)
  links$p_class[links$p_plot < p_cuts[3]] <- p_labs[3]
  links$p_class[links$p_plot < p_cuts[2]] <- p_labs[2]
  links$p_class[links$p_plot < p_cuts[1]] <- p_labs[1]
  p_colors <- vec(val('p_colors', NULL))
  if (length(p_colors) < 4) p_colors <- c('#E69F00', '#009E73', '#6A3D9A', '#D0D0D0')
  p_colors <- p_colors[1:4]
  names(p_colors) <- p_labs
  draw_rank <- as.integer(links$p_class)
  links <- links[order(draw_rank, decreasing = TRUE), , drop = FALSE]

  fill_neg <- chr('neg_color', '#B2182B')
  fill_pos <- chr('pos_color', '#2166AC')
  mid_c <- chr('mid_color', '#FFFFFF')
  title <- chr('title', 'Combined Mantel test and Pearson correlation')
  title_show <- boo('title_show', TRUE)
  legend_show <- boo('legend_show', TRUE)
  show_top <- boo('show_top_labels', TRUE)
  w <- num('width', max(9.5, 6.5 + n * 0.28))
  h <- num('height', max(7.2, 5.4 + n * 0.2))
  dpi <- as.integer(num('dpi', 300))
  curvature <- num('link_curvature', 0.22)

  g <- ggplot() +
    geom_tile(
      data = upper_df,
      aes(x = .data$x, y = .data$y, fill = .data$r, width = .data$sz, height = .data$sz),
      colour = if (boo('cell_border_show', FALSE)) chr('cell_border_color', '#FFFFFF') else NA,
      linewidth = 0.15
    ) +
    scale_fill_gradient2(
      name = "Pearson's r",
      low = fill_neg, mid = mid_c, high = fill_pos,
      midpoint = 0, limits = c(-1, 1),
      breaks = c(-1, -0.5, 0, 0.5, 1),
      guide = if (legend_show) 'colorbar' else 'none'
    )
  if (show_top) {
    top_df <- data.frame(env = env_vars, x = seq_len(n), y = n + 0.85, stringsAsFactors = FALSE)
    g <- g + geom_text(
      data = top_df,
      aes(x = .data$x, y = .data$y, label = .data$env),
      angle = 90, hjust = 0, vjust = 0.5,
      size = num('top_label_size', 2.8),
      colour = '#444444'
    )
  }
  if (boo('link_show', TRUE) && nrow(links)) {
    g <- g +
      geom_curve(
        data = links,
        aes(x = .data$x, y = .data$y, xend = .data$xend, yend = .data$yend,
            colour = .data$p_class, linewidth = .data$r_class),
        curvature = curvature, ncp = 12, lineend = 'round',
        alpha = num('link_alpha', 0.95),
        inherit.aes = FALSE
      ) +
      scale_colour_manual(name = p_legend, values = p_colors, drop = FALSE) +
      scale_linewidth_manual(name = "Mantel's r", values = r_widths, drop = FALSE)
  }
  g <- g +
    geom_text(
      data = diag_df,
      aes(x = .data$x, y = .data$y, label = .data$env),
      size = num('diag_label_size', 3.2),
      colour = '#222222'
    ) +
    geom_point(
      data = spec_df,
      aes(x = .data$x, y = .data$y),
      size = num('spec_point_size', 3.4),
      colour = '#111111',
      inherit.aes = FALSE
    ) +
    geom_text(
      data = spec_df,
      aes(x = .data$x, y = .data$y, label = .data$spec),
      hjust = 1.2, size = num('spec_label_size', 3.5),
      colour = '#111111',
      inherit.aes = FALSE
    ) +
    coord_equal(
      xlim = c(-2.8, n + 0.8),
      ylim = c(0.2, n + if (show_top) 1.7 else 0.8),
      expand = FALSE, clip = 'off'
    ) +
    labs(
      title = if (title_show && nzchar(title)) title else NULL,
      x = NULL, y = NULL,
      caption = if (boo('caption_show', FALSE)) NULL else NULL
    ) +
    theme_void(base_size = num('base_size', 11), base_family = chr('font_family', 'sans')) +
    theme(
      plot.background = element_rect(fill = '#FFFFFF', colour = NA),
      panel.background = element_rect(fill = '#FFFFFF', colour = NA),
      plot.title = element_text(
        size = num('title_size', 14), colour = '#222222',
        face = if (tolower(chr('title_face', 'plain')) == 'bold') 'bold' else 'plain',
        hjust = 0.5, margin = margin(b = 8)
      ),
      legend.position = if (legend_show) chr('legend_position', 'right') else 'none',
      legend.title = element_text(size = num('legend_title_size', 10)),
      legend.text = element_text(size = num('legend_text_size', 9)),
      plot.margin = margin(12, 16, 10, 10)
    )
  if (legend_show) {
    g <- g + guides(
      fill = guide_colorbar(order = 1, barwidth = 0.55, barheight = 7),
      colour = guide_legend(order = 2, override.aes = list(linewidth = 1.6)),
      linewidth = guide_legend(order = 3)
    )
  }

  caption <- paste0(
    'Combined Mantel test and Pearson correlation analysis. The upper triangular matrix shows pairwise ',
    'Pearson correlations among environmental variables. Square color indicates the direction of Pearson\'s ',
    'correlation coefficient (blue, positive; red, negative), while square size represents the absolute ',
    'magnitude of the correlation. Network edges connect biological/community distance matrices to individual ',
    'environmental variables based on Mantel tests. Edge width represents the magnitude of Mantel\'s r, ',
    'whereas edge color indicates Mantel-test significance',
    if (padj_method == 'BH') ' after Benjamini-Hochberg FDR adjustment' else '',
    '. Gray edges denote nonsignificant associations. A significant Mantel association does not imply a causal environmental effect.'
  )
  writeLines(caption, file.path(out, 'caption.txt'))
  writeLines(jsonlite::toJSON(qc, auto_unbox = TRUE, pretty = TRUE), file.path(out, 'qc.json'))

  logmsg(sprintf('Rendering combined Mantel+Pearson: %d env vars, %d communities, %d links', n, n_spec, nrow(links)))
  save_fig <- function(path, device = NULL) {
    ggsave(path, g, width = w, height = h, units = 'in', dpi = dpi, bg = 'white')
  }
  # Generic appearance parameters not handled by this plugin (R/runtime/omicscanvas_theme.R).
  if (!exists('omicscanvas_apply_theme')) { .oc_f <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[1]); .oc_rt <- file.path(dirname(normalizePath(.oc_f, mustWork = FALSE)), '..', '..', 'R', 'runtime', 'omicscanvas_theme.R'); if (!file.exists(.oc_rt)) .oc_rt <- file.path('R', 'runtime', 'omicscanvas_theme.R'); sys.source(.oc_rt, envir = globalenv()) }; g <- omicscanvas_apply_theme(g, p, only = c('title_color'))
  save_fig(file.path(out, 'result.svg'))
  save_fig(file.path(out, 'result.pdf'))
  save_fig(file.path(out, 'result.png'))
  file.copy(file.path(out, 'result.svg'), file.path(out, 'mantel_pearson_combined.svg'), overwrite = TRUE)
  file.copy(file.path(out, 'result.pdf'), file.path(out, 'mantel_pearson_combined.pdf'), overwrite = TRUE)
  file.copy(file.path(out, 'result.png'), file.path(out, 'mantel_pearson_combined.png'), overwrite = TRUE)

  if (boo('interactive', FALSE) && requireNamespace('plotly', quietly = TRUE) && requireNamespace('htmlwidgets', quietly = TRUE)) {
    pl <- tryCatch(plotly::ggplotly(g, tooltip = c('fill', 'colour', 'label')), error = function(e) NULL)
    if (is.null(pl)) {
      writeLines('<html><body><p>Interactive output could not be built; see result.png.</p></body></html>', file.path(out, 'result.html'))
    } else {
      htmlwidgets::saveWidget(plotly::config(pl, displaylogo = FALSE), file.path(out, 'result.html'), selfcontained = TRUE)
    }
  } else {
    writeLines('<html><body><p>Interactive Plotly output is disabled.</p></body></html>', file.path(out, 'result.html'))
  }

  write.csv(spec_df, file.path(out, 'spec_points_used.csv'), row.names = FALSE)
  write.csv(diag_df, file.path(out, 'env_points_used.csv'), row.names = FALSE)
  write.csv(links, file.path(out, 'selected_links.csv'), row.names = FALSE)
  meta <- list(
    plugin = 'interactive_mantel_correlation_network',
    title = title,
    engine = 'mantel_pearson',
    interpretation = list(
      pearson = 'Linear association between two environmental variables across samples.',
      mantel = 'Association between community pairwise dissimilarity and an environmental variable distance. Not Pearson correlation and not causal.'
    ),
    input_mode = mode,
    n_env = n,
    env_vars = env_vars,
    communities = spec_levels,
    n_links = nrow(links),
    correlation_method = cor_method,
    mantel_permutations = perms,
    p_adjust = padj_method,
    random_state = seed,
    community_distance = dist_method,
    env_distance = 'euclidean',
    caption = caption,
    qc = qc,
    outputs = c(
      'mantel_pearson_combined.pdf', 'mantel_pearson_combined.png', 'mantel_pearson_combined.svg',
      'result.pdf', 'result.png', 'result.svg',
      'pearson_correlations.csv', 'mantel_results.csv', 'caption.txt', 'qc.json'
    )
  )
  writeLines(jsonlite::toJSON(meta, auto_unbox = TRUE, pretty = TRUE, null = 'null'), file.path(out, 'figure.json'))
  logmsg('Completed combined Mantel + Pearson figure.')
}, error = function(e) fail('Mantel + Pearson figure failed', conditionMessage(e)))
