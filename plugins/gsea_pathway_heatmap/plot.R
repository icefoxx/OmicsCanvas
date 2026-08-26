#!/usr/bin/env Rscript

# BioFigureAI Plot Plugin: GSEA Pathway Heatmap
# ------------------------------------------------------------
# Combines multi-term GSEA running enrichment tracks with
# per-pathway expression heatmaps.
#
# Runtime:
#   Rscript plot.R \
#     --input ranks.csv \
#     --genesets pathways.gmt \
#     --expr expression.csv \
#     --params params.json \
#     --output out_dir \
#     [--enrichment enrichment.csv] \
#     [--col-annot samples.csv]

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
  library(fgsea)
})

option_list <- list(
  make_option(c('--input'), type = 'character', default = NULL,
              help = 'Rank/marker table (gene + statistic).'),
  make_option(c('--genesets'), type = 'character', default = NULL,
              help = 'GMT/CSV/TSV gene-set membership file.'),
  make_option(c('--expr'), type = 'character', default = NULL,
              help = 'Gene x sample expression matrix CSV/TSV.'),
  make_option(c('--enrichment'), type = 'character', default = NULL,
              help = 'Optional precomputed enrichment table.'),
  make_option('--col_annot', dest = 'col_annot', type = 'character', default = NULL,
              help = 'Optional sample annotation table (first column = sample id).'),
  make_option(c('--params'), type = 'character', default = NULL,
              help = 'Path to params.json.'),
  make_option(c('--output'), type = 'character', default = NULL,
              help = 'Output directory.')
)

opt <- parse_args(OptionParser(option_list = option_list))
input_file <- opt$input
genesets_file <- opt$genesets
expr_file <- opt$expr
enrichment_file <- opt$enrichment
col_annot_file <- opt$col_annot
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
    write_error_and_exit('Input file not found', paste('Input path:', path), 'Provide a valid csv/tsv/txt path.')
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
  for (name in names) if (!is.null(params[[name]])) return(params[[name]])
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

as_named_vector <- function(x, default = NULL) {
  if (is.null(x)) return(default)
  if (is.list(x) && !is.data.frame(x)) return(unlist(x))
  x
}

num_param <- function(params, name, default) {
  value <- suppressWarnings(as.numeric(get_param(params, name, default))[1])
  if (is.na(value)) default else value
}

find_column <- function(df, candidates, required = TRUE, purpose = NULL) {
  cn <- colnames(df)
  idx <- match(tolower(candidates), tolower(cn))
  idx <- idx[!is.na(idx)]
  if (length(idx) > 0) return(cn[idx[1]])
  if (required) {
    write_error_and_exit(
      'Required input column not found',
      paste('Candidates:', paste(candidates, collapse = ', ')),
      paste('Check params for', purpose %||% 'column mapping.')
    )
  }
  NULL
}

parse_gene_string <- function(x) {
  if (is.null(x) || length(x) == 0 || is.na(x[1])) return(character())
  x <- gsub('[\\[\\]\"]', '', as.character(x[1]))
  genes <- unlist(strsplit(x, '[,;/|[:space:]]+', perl = TRUE), use.names = FALSE)
  unique(trimws(genes[nzchar(trimws(genes))]))
}

parse_gmt <- function(path) {
  lines <- readLines(path, warn = FALSE)
  out <- list()
  for (line in lines[nzchar(trimws(lines))]) {
    parts <- strsplit(line, '\t', fixed = TRUE)[[1]]
    if (length(parts) < 3) next
    genes <- unique(parts[-c(1, 2)])
    genes <- genes[nzchar(genes)]
    out[[parts[1]]] <- genes
  }
  out[lengths(out) > 0]
}

read_genesets <- function(path) {
  if (is.null(path) || !file.exists(path)) {
    write_error_and_exit('Gene-set file not found', paste('Path:', path), 'Provide --genesets or params$genesets_file.')
  }
  ext <- tolower(tools::file_ext(path))
  if (ext == 'gmt') return(parse_gmt(path))
  gs_df <- read_table_auto(path)
  term_col <- find_column(gs_df, c('term', 'pathway', 'geneset', 'gene_set', 'gs_name'), TRUE, 'gene set term column')
  gene_col <- find_column(gs_df, c('gene', 'gene_symbol', 'symbol', 'feature', 'id'), TRUE, 'gene set gene column')
  sets <- split(as.character(gs_df[[gene_col]]), as.character(gs_df[[term_col]]))
  sets <- lapply(sets, function(x) unique(trimws(x[nzchar(trimws(x))])))
  sets[lengths(sets) > 0]
}

make_ranks <- function(df, params) {
  gene_col <- get_param_any(params, c('gene_col', 'gene_column'), find_column(df, c('gene', 'Gene', 'gene_symbol', 'symbol', 'feature'), TRUE, 'rank gene column'))
  if (!gene_col %in% colnames(df)) {
    write_error_and_exit('Rank gene column not found in input table', as.character(gene_col), 'Pass the ranked-gene table as --input, not the expression matrix.')
  }
  stat_col <- get_param_any(params, c('stat_col', 'stat_column', 'rank_column'), find_column(df, c('avg_log2FC', 'log2FC', 'stat', 'score', 't', 'waldStat'), TRUE, 'rank statistic column'))
  if (is.null(stat_col) || !stat_col %in% colnames(df)) {
    write_error_and_exit(
      'Rank statistic column not found in input table',
      paste('Need avg_log2FC/log2FC/stat. Columns:', paste(colnames(df), collapse = ', ')),
      'The main input must be the ranked gene table. Expression belongs in --expr.'
    )
  }
  comparison_col <- get_param_any(params, c('comparison_col', 'comparison_column'), find_column(df, c('comparison', 'contrast', 'cluster', 'group'), FALSE))
  if (!is.null(comparison_col) && !comparison_col %in% colnames(df)) comparison_col <- NULL
  selected_comparison <- get_param(params, 'selected_comparison', NULL)
  rank_df <- df
  if (!is.null(comparison_col) && !is.null(selected_comparison) && nzchar(as.character(selected_comparison)[1])) {
    keep <- as.character(rank_df[[comparison_col]]) == as.character(selected_comparison)[1]
    if (any(keep, na.rm = TRUE)) {
      rank_df <- rank_df[keep, , drop = FALSE]
    } else {
      write_log(sprintf('selected_comparison=%s not found in %s; using all rank rows.', selected_comparison, comparison_col))
    }
  }
  if (nrow(rank_df) == 0) write_error_and_exit('Rank table is empty after filtering', '', 'Check selected_comparison and the ranked-gene input.')
  stat <- suppressWarnings(as.numeric(rank_df[[stat_col]]))
  genes <- as.character(rank_df[[gene_col]])
  keep <- !is.na(stat) & !is.na(genes) & nzchar(genes)
  agg <- tapply(stat[keep], genes[keep], mean, na.rm = TRUE)
  if (length(agg) < 2) write_error_and_exit('Rank table has fewer than two valid genes')
  stats <- sort(as.numeric(agg), decreasing = TRUE)
  names(stats) <- names(agg)[order(as.numeric(agg), decreasing = TRUE)]
  stats
}

standardize_results <- function(df, params) {
  term_col <- get_param_any(params, c('term_col', 'term_column', 'pathway_col'), find_column(df, c('pathway', 'term', 'Term', 'Description', 'ID'), TRUE, 'term/pathway column'))
  nes_col <- get_param_any(params, c('nes_col', 'nes_column'), find_column(df, c('NES', 'nes'), FALSE))
  p_col <- get_param_any(params, c('p_col', 'pvalue_col', 'p_column'), find_column(df, c('pval', 'pvalue', 'p.value'), FALSE))
  fdr_col <- get_param_any(params, c('fdr_col', 'padj_col', 'q_col'), find_column(df, c('padj', 'FDR', 'qval', 'qvalue', 'p.adjust'), FALSE))
  gene_col <- get_param_any(params, c('leading_genes_col', 'leading_edge_col'), find_column(df, c('leadingEdge', 'leading_genes', 'core_enrichment'), FALSE))
  out <- data.frame(term = as.character(df[[term_col]]), stringsAsFactors = FALSE)
  out$NES <- if (!is.null(nes_col)) suppressWarnings(as.numeric(df[[nes_col]])) else NA_real_
  out$pvalue <- if (!is.null(p_col)) suppressWarnings(as.numeric(df[[p_col]])) else NA_real_
  out$FDR <- if (!is.null(fdr_col)) suppressWarnings(as.numeric(df[[fdr_col]])) else NA_real_
  out$padj <- out$FDR
  out$leading_genes <- if (!is.null(gene_col)) as.character(df[[gene_col]]) else ''
  out
}

select_terms <- function(res, params) {
  include <- as_string_vector(get_param_any(params, c('selected_terms', 'terms_include'), NULL))
  exclude <- as_string_vector(get_param(params, 'terms_exclude', NULL))
  out <- res
  if (length(include) > 0) out <- out[out$term %in% include, , drop = FALSE]
  if (length(exclude) > 0) out <- out[!out$term %in% exclude, , drop = FALSE]
  if (length(include) == 0) {
    top_n <- num_param(params, 'top_n_terms', 2)
    out <- out[order(-abs(out$NES), out$FDR, na.last = TRUE), , drop = FALSE]
    out <- head(out, top_n)
  }
  if (nrow(out) == 0) write_error_and_exit('No terms selected for plotting', '', 'Check selected_terms/top_n_terms.')
  out
}

format_p_value <- function(x, digits = 3) {
  if (is.null(x) || length(x) == 0 || is.na(x[1])) return('NA')
  formatC(as.numeric(x[1]), digits = digits, format = 'e')
}

gsea_scores <- function(gene_list, gene_set, exponent = 1) {
  gene_names <- names(gene_list)
  gene_set <- intersect(gene_set, gene_names)
  n <- length(gene_list)
  nh <- length(gene_set)
  if (nh == 0 || nh == n) {
    write_error_and_exit('Invalid pathway overlap for running plot', '', 'Selected term has no usable overlap with the ranked gene list.')
  }
  hits <- gene_names %in% gene_set
  phit <- numeric(n)
  pmiss <- numeric(n)
  phit[hits] <- abs(gene_list[hits]) ^ exponent
  phit <- cumsum(phit / sum(phit))
  pmiss[!hits] <- 1 / (n - nh)
  pmiss <- cumsum(pmiss)
  data.frame(
    x = seq_len(n),
    runningScore = phit - pmiss,
    is_hit = hits,
    gene = gene_names,
    rank_metric = as.numeric(gene_list),
    stringsAsFactors = FALSE
  )
}

default_term_colors <- function(terms) {
  base <- c('#2CA02C', '#D62728', '#1F77B4', '#FF7F0E', '#9467BD', '#8C564B')
  setNames(rep(base, length.out = length(terms)), terms)
}

read_expression_matrix <- function(path, params) {
  df <- read_table_auto(path)
  gene_col <- get_param_any(params, c('expr_gene_col', 'expression_gene_col'), find_column(df, c('gene', 'Gene', 'gene_symbol', 'symbol', 'feature', 'id'), TRUE, 'expression gene column'))
  genes <- make.unique(as.character(df[[gene_col]]))
  mat <- as.matrix(data.frame(lapply(df[setdiff(colnames(df), gene_col)], function(x) suppressWarnings(as.numeric(as.character(x)))), check.names = FALSE))
  rownames(mat) <- genes
  mat <- mat[rowSums(is.finite(mat)) > 0, , drop = FALSE]
  if (!nrow(mat) || !ncol(mat)) write_error_and_exit('Expression matrix is empty after parsing')
  mat[!is.finite(mat)] <- 0
  mat
}

scale_matrix <- function(mat, mode = 'row') {
  mode <- tolower(as.character(mode)[1])
  if (mode == 'none') return(mat)
  if (mode == 'column') {
    return(apply(mat, 2, function(v) {
      s <- stats::sd(v, na.rm = TRUE)
      if (!is.finite(s) || s == 0) rep(0, length(v)) else (v - mean(v, na.rm = TRUE)) / s
    }))
  }
  t(apply(mat, 1, function(v) {
    s <- stats::sd(v, na.rm = TRUE)
    if (!is.finite(s) || s == 0) rep(0, length(v)) else (v - mean(v, na.rm = TRUE)) / s
  }))
}

pathway_genes_for_term <- function(term, selected_row, pathways, ranks, params) {
  mode <- tolower(as.character(get_param(params, 'heatmap_gene_mode', 'leading_edge'))[1])
  max_n <- num_param(params, 'heatmap_max_genes', 40)
  members <- character()
  if (mode == 'leading_edge') {
    members <- parse_gene_string(selected_row$leading_genes)
  }
  if (length(members) == 0 && term %in% names(pathways)) members <- pathways[[term]]
  members <- intersect(members, names(ranks))
  if (length(members) == 0 && term %in% names(pathways)) members <- intersect(pathways[[term]], names(ranks))
  members <- members[order(-abs(ranks[members]), na.last = TRUE)]
  head(members, max_n)
}

make_heatmap_plot <- function(term, genes, expr_mat, ranks, color, params, col_annot = NULL) {
  genes <- intersect(genes, rownames(expr_mat))
  if (length(genes) == 0) {
    return(ggplot() + annotate('text', x = 0.5, y = 0.5, label = paste0(term, '\n(no overlapping genes)'), size = 3.5) + theme_void())
  }
  sample_order <- as_string_vector(get_param(params, 'sample_order', NULL))
  cols <- colnames(expr_mat)
  if (length(sample_order) > 0) cols <- c(intersect(sample_order, cols), setdiff(cols, sample_order))
  mat <- scale_matrix(expr_mat[genes, cols, drop = FALSE], get_param(params, 'scale', 'row'))
  dimnames(mat) <- list(genes, cols)
  long <- do.call(rbind, lapply(seq_len(nrow(mat)), function(i) {
    data.frame(
      gene = factor(rownames(mat)[i], levels = rownames(mat)),
      sample = factor(colnames(mat), levels = colnames(mat)),
      value = as.numeric(mat[i, ]),
      stringsAsFactors = FALSE
    )
  }))
  lim <- max(abs(range(long$value, na.rm = TRUE)), 1e-6)
  pal <- as_string_vector(get_param(params, 'heatmap_palette_colors', c('#2166AC', '#F7F7F7', '#B2182B')))
  if (length(pal) < 2) pal <- c('#2166AC', '#F7F7F7', '#B2182B')
  p <- ggplot(long, aes(x = gene, y = sample, fill = value)) +
    geom_tile(color = if (as_bool(get_param(params, 'heatmap_cell_border', FALSE), FALSE)) 'white' else NA, linewidth = 0.15) +
    scale_fill_gradientn(colours = pal, limits = c(-lim, lim), name = get_param(params, 'heatmap_legend_title', 'Z-score')) +
    labs(title = NULL, x = NULL, y = term) +
    theme_classic(base_family = get_param(params, 'font_family', 'sans')) +
    theme(
      axis.title.y = element_text(size = num_param(params, 'heatmap_title_size', 10), face = 'bold', color = color, angle = 90),
      axis.text.x = if (as_bool(get_param(params, 'heatmap_show_rownames', TRUE), TRUE)) {
        element_text(angle = num_param(params, 'heatmap_column_angle', 90), hjust = 1, vjust = 0.5, size = num_param(params, 'heatmap_row_size', 6))
      } else {
        element_blank()
      },
      axis.ticks.x = if (as_bool(get_param(params, 'heatmap_show_rownames', TRUE), TRUE)) element_line() else element_blank(),
      axis.text.y = element_text(size = num_param(params, 'heatmap_column_size', 8)),
      legend.position = get_param(params, 'heatmap_legend_position', 'right'),
      plot.margin = margin(4, 6, 4, 6)
    )
  if (!is.null(col_annot) && as_bool(get_param(params, 'heatmap_show_column_annot', TRUE), TRUE)) {
    # lightweight caption of day/group labels if present
    ann_cols <- as_string_vector(get_param(params, 'heatmap_column_annotation_columns', NULL))
    if (length(ann_cols) == 0) {
      ann_cols <- setdiff(colnames(col_annot), colnames(col_annot)[1])
      ann_cols <- head(ann_cols, 2)
    }
    if (length(ann_cols) > 0) {
      labels <- vapply(ann_cols, function(cn) {
        if (!cn %in% colnames(col_annot)) return('')
        vals <- as.character(col_annot[match(cols, as.character(col_annot[[1]])), cn])
        paste0(cn, ': ', paste(unique(vals[!is.na(vals)]), collapse = '/'))
      }, character(1))
      labels <- labels[nzchar(labels)]
      if (length(labels) > 0) {
        p <- p + labs(subtitle = paste(labels, collapse = ' | ')) +
          theme(plot.subtitle = element_text(size = 8, color = '#555555'))
      }
    }
  }
  list(plot = p, matrix = mat, genes = genes)
}

make_gsea_tracks <- function(selected, ranks, pathways, params, term_colors) {
  terms <- selected$term
  exponent <- num_param(params, 'exponent', 1)
  score_df <- do.call(rbind, lapply(terms, function(term) {
    if (!term %in% names(pathways)) return(NULL)
    d <- gsea_scores(ranks, pathways[[term]], exponent)
    d$term <- term
    d
  }))
  if (is.null(score_df) || !nrow(score_df)) write_error_and_exit('No running-score data available')
  score_df$term <- factor(score_df$term, levels = terms)

  peak_df <- do.call(rbind, lapply(split(score_df, score_df$term), function(d) d[which.max(abs(d$runningScore)), , drop = FALSE]))

  title_text <- get_param(params, 'title', 'GSEA pathway enrichment with expression heatmaps')
  subtitle_parts <- vapply(seq_len(nrow(selected)), function(i) {
    sprintf('%s (NES=%s, padj=%s)', selected$term[i], formatC(selected$NES[i], digits = 2, format = 'f'), format_p_value(selected$FDR[i], 2))
  }, character(1))
  subtitle_text <- get_param(params, 'subtitle', paste(subtitle_parts, collapse = '  |  '))

  p_curve <- ggplot(score_df, aes(x = x, y = runningScore, color = term)) +
    annotate('rect', xmin = -Inf, xmax = Inf, ymin = 0, ymax = Inf, fill = '#F8D9D9', alpha = 0.35) +
    annotate('rect', xmin = -Inf, xmax = Inf, ymin = -Inf, ymax = 0, fill = '#DDE4FA', alpha = 0.35) +
    geom_hline(yintercept = 0, color = '#555555', linewidth = 0.4) +
    geom_line(linewidth = num_param(params, 'curve_line_width', 1.05), alpha = 0.95) +
    geom_point(data = peak_df, aes(x = x, y = runningScore, fill = term), shape = 24, size = 2.8, color = '#111111', show.legend = FALSE) +
    scale_color_manual(values = term_colors, name = 'Term') +
    scale_fill_manual(values = term_colors, guide = 'none') +
    labs(title = title_text, subtitle = subtitle_text, x = NULL, y = 'Enrichment Score') +
    theme_classic(base_family = get_param(params, 'font_family', 'sans')) +
    theme(
      axis.text.x = element_blank(),
      axis.ticks.x = element_blank(),
      plot.title = element_text(size = num_param(params, 'title_size', 15), face = 'bold'),
      plot.subtitle = element_text(size = 9, color = '#333333'),
      legend.position = get_param(params, 'legend_position', 'right'),
      panel.border = element_rect(color = '#222222', fill = NA, linewidth = 0.6)
    )

  hit_df <- score_df[score_df$is_hit, , drop = FALSE]
  hit_df$ymin <- as.numeric(factor(hit_df$term, levels = rev(terms))) - 0.38
  hit_df$ymax <- as.numeric(factor(hit_df$term, levels = rev(terms))) + 0.38
  p_hits <- ggplot() +
    geom_linerange(data = hit_df, aes(x = x, ymin = ymin, ymax = ymax, color = term),
                   linewidth = 0.35, alpha = 0.9, show.legend = FALSE) +
    scale_color_manual(values = term_colors) +
    scale_y_continuous(breaks = seq_along(rev(terms)), labels = rev(terms), expand = c(0.05, 0.05)) +
    labs(x = NULL, y = NULL) +
    theme_classic(base_family = get_param(params, 'font_family', 'sans')) +
    theme(
      axis.text.x = element_blank(),
      axis.ticks.x = element_blank(),
      axis.text.y = element_text(size = 8),
      panel.border = element_rect(color = '#222222', fill = NA, linewidth = 0.6),
      plot.margin = margin(2, 8, 2, 8)
    )

  rank_df <- data.frame(x = seq_along(ranks), stat = as.numeric(ranks))
  caps <- stats::quantile(rank_df$stat, c(0.02, 0.98), na.rm = TRUE)
  rank_df$stat_cap <- pmax(pmin(rank_df$stat, caps[2]), caps[1])
  p_rank <- ggplot(rank_df, aes(x = x, y = 1, fill = stat_cap)) +
    geom_tile(height = 0.9, width = 1.02) +
    scale_fill_gradient2(low = '#2D1693', mid = '#F4E1E1', high = '#C90000', midpoint = 0, guide = 'none') +
    labs(x = 'Rank in Ordered Dataset', y = NULL) +
    theme_classic(base_family = get_param(params, 'font_family', 'sans')) +
    theme(
      axis.text.y = element_blank(),
      axis.ticks.y = element_blank(),
      panel.border = element_rect(color = '#222222', fill = NA, linewidth = 0.6),
      plot.margin = margin(2, 8, 6, 8)
    )

  list(curve = p_curve, hits = p_hits, rank = p_rank)
}

save_plot <- function(plot, output_dir, width, height, dpi) {
  if (requireNamespace('svglite', quietly = TRUE)) {
    ggplot2::ggsave(file.path(output_dir, 'result.svg'), plot, width = width, height = height, device = svglite::svglite)
  } else {
    ggplot2::ggsave(file.path(output_dir, 'result.svg'), plot, width = width, height = height)
  }
  ggplot2::ggsave(file.path(output_dir, 'result.pdf'), plot, width = width, height = height)
  ggplot2::ggsave(file.path(output_dir, 'result.png'), plot, width = width, height = height, dpi = dpi)
}

main <- function() {
  if (is.null(output_dir) || !nzchar(output_dir)) write_error_and_exit('Output directory is required')
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  unlink(file.path(output_dir, c('result.svg', 'result.pdf', 'result.png', 'figure.json', 'error.json')), force = TRUE)
  write_log('Starting gsea_pathway_heatmap plugin.')

  if (is.null(params_file) || !file.exists(params_file)) write_error_and_exit('Params file not found', as.character(params_file))
  if (is.null(input_file) || !file.exists(input_file)) write_error_and_exit('Input ranks file not found', as.character(input_file))
  params <- jsonlite::fromJSON(params_file, simplifyVector = FALSE)

  if (is.null(genesets_file)) genesets_file <<- get_param(params, 'genesets_file', NULL)
  if (is.null(expr_file)) expr_file <<- get_param_any(params, c('expr_file', 'expression_file'), NULL)
  if (is.null(enrichment_file)) enrichment_file <<- get_param_any(params, c('enrichment_file', 'fgsea_results_file'), NULL)
  if (is.null(col_annot_file)) col_annot_file <<- get_param_any(params, c('col_annot_file', 'column_annotation_file'), NULL)

  if (is.null(genesets_file) || !file.exists(genesets_file)) {
    write_error_and_exit('Gene-set file is required', as.character(genesets_file), 'Pass --genesets pathways.gmt')
  }
  if (is.null(expr_file) || !file.exists(expr_file)) {
    write_error_and_exit('Expression matrix is required', as.character(expr_file), 'Pass --expr expression.csv')
  }

  rank_df <- read_table_auto(input_file)
  pathways <- read_genesets(genesets_file)
  ranks <- make_ranks(rank_df, params)
  expr_mat <- read_expression_matrix(expr_file, params)
  col_annot <- if (!is.null(col_annot_file) && file.exists(col_annot_file)) read_table_auto(col_annot_file) else NULL

  # Enrichment: prefer precomputed if provided, else run fgsea
  if (!is.null(enrichment_file) && file.exists(enrichment_file)) {
    write_log('Using precomputed enrichment table.')
    enr_raw <- read_table_auto(enrichment_file)
    results <- standardize_results(enr_raw, params)
  } else {
    write_log('Computing FGSEA enrichment.')
    min_size <- num_param(params, 'minSize', 5)
    max_size <- num_param(params, 'maxSize', 500)
    nperm <- num_param(params, 'nperm', 1000)
    res <- suppressWarnings(fgsea::fgsea(
      pathways = pathways,
      stats = ranks,
      minSize = min_size,
      maxSize = max_size,
      nperm = nperm,
      scoreType = get_param(params, 'scoreType', 'std')
    ))
    res <- as.data.frame(res, stringsAsFactors = FALSE)
    if ('leadingEdge' %in% colnames(res)) {
      res$leadingEdge <- vapply(res$leadingEdge, paste, character(1), collapse = ';')
    }
    results <- standardize_results(res, params)
  }

  selected <- select_terms(results, params)
  terms <- selected$term
  write_log(sprintf('Selected terms: %s', paste(terms, collapse = ', ')))

  custom_colors <- as_named_vector(get_param(params, 'term_colors', NULL), NULL)
  term_colors <- default_term_colors(terms)
  if (!is.null(custom_colors)) {
    for (nm in intersect(names(custom_colors), terms)) term_colors[nm] <- as.character(custom_colors[[nm]])
  }

  tracks <- make_gsea_tracks(selected, ranks, pathways, params, term_colors)

  heatmap_list <- list()
  pathway_gene_rows <- list()
  matrix_blocks <- list()
  for (i in seq_along(terms)) {
    term <- terms[i]
    genes <- pathway_genes_for_term(term, selected[i, , drop = FALSE], pathways, ranks, params)
    genes <- intersect(genes, rownames(expr_mat))
    hm <- make_heatmap_plot(term, genes, expr_mat, ranks, term_colors[[term]], params, col_annot)
    heatmap_list[[term]] <- hm$plot
    pathway_gene_rows[[length(pathway_gene_rows) + 1]] <- data.frame(term = term, gene = hm$genes, rank_metric = unname(ranks[hm$genes]), stringsAsFactors = FALSE)
    if (!is.null(hm$matrix) && length(hm$genes) > 0) {
      block <- as.data.frame(hm$matrix, stringsAsFactors = FALSE)
      block$term <- term
      block$gene <- rownames(hm$matrix)
      matrix_blocks[[term]] <- block
    }
  }

  if (!requireNamespace('patchwork', quietly = TRUE)) {
    write_error_and_exit('Package patchwork is required', '', 'install.packages("patchwork")')
  }

  heat_stack <- patchwork::wrap_plots(heatmap_list, ncol = 1, guides = 'collect')
  n_hm <- max(1, length(heatmap_list))
  heights <- as.numeric(unlist(get_param(params, 'layout_heights', c(1.55, 0.42, 0.26, 0.95 * n_hm))))
  if (length(heights) != 4) heights <- c(1.55, 0.42, 0.26, 0.95 * n_hm)
  final_plot <- patchwork::wrap_plots(
    tracks$curve,
    tracks$hits,
    tracks$rank,
    heat_stack,
    ncol = 1,
    heights = heights
  ) & theme(legend.box.margin = margin(0, 0, 0, 0))

  width <- num_param(params, 'width', 11)
  height <- num_param(params, 'height', 9.5)
  dpi <- as.integer(num_param(params, 'dpi', 300))
  save_plot(final_plot, output_dir, width, height, dpi)

  write.csv(results, file.path(output_dir, 'enrichment_results.csv'), row.names = FALSE)
  write.csv(selected, file.path(output_dir, 'selected_terms.csv'), row.names = FALSE)
  pathway_genes_df <- do.call(rbind, pathway_gene_rows)
  write.csv(pathway_genes_df, file.path(output_dir, 'pathway_genes_used.csv'), row.names = FALSE)
  if (length(matrix_blocks) > 0) {
    write.csv(do.call(rbind, matrix_blocks), file.path(output_dir, 'matrix_data_used.csv'), row.names = FALSE)
  }

  figure <- list(
    plugin = 'gsea_pathway_heatmap',
    title = get_param(params, 'title', 'GSEA pathway enrichment with expression heatmaps'),
    selected_terms = terms,
    n_ranks = length(ranks),
    n_samples = ncol(expr_mat),
    outputs = c('result.svg', 'result.pdf', 'result.png', 'figure.json', 'enrichment_results.csv', 'selected_terms.csv', 'pathway_genes_used.csv', 'matrix_data_used.csv', 'run.log')
  )
  writeLines(jsonlite::toJSON(figure, auto_unbox = TRUE, pretty = TRUE), file.path(output_dir, 'figure.json'))
  write_log('Finished successfully.')
}

tryCatch(main(), error = function(e) {
  write_error_and_exit('gsea_pathway_heatmap failed', conditionMessage(e), 'Check ranks/genesets/expression overlap and params.')
})
