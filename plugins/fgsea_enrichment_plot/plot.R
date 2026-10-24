#!/usr/bin/env Rscript

# BioFigureAI Plot Plugin: FGSEA Enrichment Plot
# ------------------------------------------------------------
# Runtime contract:
#   Rscript plot.R --input input.csv --params params.json --output output_dir
# Optional:
#   Rscript plot.R --input ranks.csv --genesets pathways.gmt --params params.json --output output_dir
#
# Purpose:
#   Draw highly customizable fgsea/GSEA summary plots from precomputed result
#   tables, or calculate fgsea from a rank/marker table and gene sets, then
#   draw running enrichment plots with selected/top gene labels.

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
  library(ggrepel)
  library(fgsea)
  library(svglite)
})

option_list <- list(
  make_option(c('--input'), type = 'character', default = NULL,
              help = 'Input CSV/TSV/TXT. Either precomputed fgsea table or rank/marker table.'),
  make_option(c('--genesets'), type = 'character', default = NULL,
              help = 'Optional GMT/CSV/TSV gene-set file. Can also be params$genesets_file.'),
  make_option(c('--params'), type = 'character', default = NULL,
              help = 'Path to params.json.'),
  make_option(c('--output'), type = 'character', default = NULL,
              help = 'Output directory.')
)

opt <- parse_args(OptionParser(option_list = option_list))
input_file <- opt$input
genesets_file <- opt$genesets
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
  x
}

num_param <- function(params, name, default) {
  value <- get_param(params, name, default)
  value <- suppressWarnings(as.numeric(value[1]))
  if (is.na(value)) default else value
}

find_column <- function(df, candidates, required = TRUE, purpose = NULL) {
  cn <- colnames(df)
  cn_lower <- tolower(cn)
  cand_lower <- tolower(candidates)
  idx <- match(cand_lower, cn_lower)
  idx <- idx[!is.na(idx)]
  if (length(idx) > 0) return(cn[idx[1]])
  if (required) {
    write_error_and_exit(
      'Required input column not found',
      paste('Candidates:', paste(candidates, collapse = ', ')),
      paste('Check params for', ifelse(is.null(purpose), 'column mapping.', purpose))
    )
  }
  NULL
}

normalize_terms <- function(x) {
  x <- trimws(as.character(x))
  x[nzchar(x)]
}

parse_gene_string <- function(x) {
  if (is.null(x) || length(x) == 0 || is.na(x[1])) return(character())
  x <- as.character(x[1])
  x <- gsub('[\\[\\]\"]', '', x)
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

detect_mode <- function(df, params) {
  requested <- tolower(as.character(get_param(params, 'input_mode', get_param(params, 'mode', 'auto')))[1])
  if (requested %in% c('precomputed', 'summary', 'result_table')) return('precomputed')
  if (requested %in% c('compute', 'rank', 'marker', 'run_fgsea')) return('compute')
  cn <- tolower(colnames(df))
  has_result <- any(cn %in% c('pathway', 'term', 'description')) && any(cn %in% c('nes', 'normalized enrichment score'))
  if (has_result) 'precomputed' else 'compute'
}

make_ranks <- function(df, params) {
  gene_col <- get_param_any(params, c('gene_col', 'gene_column'), find_column(df, c('gene', 'Gene', 'gene_symbol', 'symbol', 'feature'), TRUE, 'rank gene column'))
  stat_col <- get_param_any(params, c('stat_col', 'stat_column', 'rank_column'), find_column(df, c('avg_log2FC', 'log2FC', 'stat', 'score', 't', 'waldStat'), TRUE, 'rank statistic column'))
  comparison_col <- get_param_any(params, c('comparison_col', 'comparison_column'), find_column(df, c('comparison', 'contrast', 'cluster', 'group'), FALSE))
  selected_comparison <- get_param(params, 'selected_comparison', NULL)

  rank_df <- df
  if (!is.null(comparison_col) && !is.null(selected_comparison)) {
    rank_df <- rank_df[as.character(rank_df[[comparison_col]]) == as.character(selected_comparison), , drop = FALSE]
  }
  if (nrow(rank_df) == 0) write_error_and_exit('No rows remain for selected comparison', '', 'Check selected_comparison.')

  stat <- suppressWarnings(as.numeric(rank_df[[stat_col]]))
  genes <- as.character(rank_df[[gene_col]])
  keep <- !is.na(stat) & !is.na(genes) & nzchar(genes)
  stat <- stat[keep]
  genes <- genes[keep]
  if (length(stat) < 2) write_error_and_exit('Rank table has fewer than two valid genes')
  agg <- tapply(stat, genes, mean, na.rm = TRUE)
  stats <- sort(as.numeric(agg), decreasing = TRUE)
  names(stats) <- names(agg)[order(as.numeric(agg), decreasing = TRUE)]
  stats
}

run_fgsea_if_needed <- function(df, params, mode) {
  if (mode == 'precomputed') return(list(results = df, ranks = NULL, pathways = NULL, mode = mode))
  gs_file <- genesets_file
  if (is.null(gs_file)) gs_file <- get_param(params, 'genesets_file', NULL)
  pathways <- read_genesets(gs_file)
  stats <- make_ranks(df, params)
  min_size <- num_param(params, 'minSize', num_param(params, 'min_size', 10))
  max_size <- num_param(params, 'maxSize', num_param(params, 'max_size', 500))
  nperm <- num_param(params, 'nperm', 1000)
  exponent <- num_param(params, 'exponent', 1)
  method <- tolower(as.character(get_param(params, 'fgsea_method', 'standard'))[1])
  if (method %in% c('multilevel', 'fgseaMultilevel', 'precise') && 'fgseaMultilevel' %in% getNamespaceExports('fgsea')) {
    res <- suppressWarnings(fgsea::fgseaMultilevel(
      pathways = pathways,
      stats = stats,
      minSize = min_size,
      maxSize = max_size,
      scoreType = get_param(params, 'scoreType', 'std'),
      gseaParam = exponent
    ))
  } else {
    res <- suppressWarnings(fgsea::fgsea(
      pathways = pathways,
      stats = stats,
      minSize = min_size,
      maxSize = max_size,
      nperm = nperm,
      scoreType = get_param(params, 'scoreType', 'std'),
      gseaParam = exponent
    ))
  }
  res <- as.data.frame(res, stringsAsFactors = FALSE)
  if ('leadingEdge' %in% colnames(res)) {
    res$leadingEdge <- vapply(res$leadingEdge, paste, character(1), collapse = ';')
  }
  list(results = res, ranks = stats, pathways = pathways, mode = mode)
}

standardize_results <- function(df, params) {
  term_col <- get_param_any(params, c('term_col', 'term_column', 'pathway_col'), find_column(df, c('pathway', 'term', 'Term', 'Description', 'ID'), TRUE, 'term/pathway column'))
  nes_col <- get_param_any(params, c('nes_col', 'nes_column'), find_column(df, c('NES', 'nes', 'signed NES'), FALSE))
  es_col <- get_param_any(params, c('es_col', 'es_column'), find_column(df, c('ES', 'es', 'enrichmentScore'), FALSE))
  p_col <- get_param_any(params, c('p_col', 'p_column'), find_column(df, c('pval', 'pvalue', 'NOM p-val', 'NOM pval', 'p.value'), FALSE))
  fdr_col <- get_param_any(params, c('fdr_col', 'fdr_column', 'q_col'), find_column(df, c('padj', 'FDR q-val', 'FDR qval', 'qval', 'qvalue', 'FDR'), FALSE))
  gene_col <- get_param_any(params, c('leading_genes_col', 'leading_edge_col'), find_column(df, c('leadingEdge', 'Leading edge genes', 'leading edge genes', 'core_enrichment', 'CoreGene'), FALSE))

  out <- data.frame(term = as.character(df[[term_col]]), stringsAsFactors = FALSE)
  out$NES <- if (!is.null(nes_col)) suppressWarnings(as.numeric(df[[nes_col]])) else NA_real_
  out$ES <- if (!is.null(es_col)) suppressWarnings(as.numeric(df[[es_col]])) else NA_real_
  out$pvalue <- if (!is.null(p_col)) suppressWarnings(as.numeric(df[[p_col]])) else NA_real_
  out$FDR <- if (!is.null(fdr_col)) suppressWarnings(as.numeric(df[[fdr_col]])) else NA_real_
  out$leading_genes <- if (!is.null(gene_col)) as.character(df[[gene_col]]) else ''
  count_col <- get_param(params, 'dot_summary_count_column', NULL)
  if (is.null(count_col)) count_col <- find_column(df, c('Count', 'count', 'size', 'gene_count'), FALSE)
  out$Count <- if (!is.null(count_col)) suppressWarnings(as.numeric(df[[count_col]])) else vapply(out$leading_genes, function(x) length(parse_gene_string(x)), numeric(1))
  out$direction <- ifelse(!is.na(out$NES) & out$NES < 0, 'negative', 'positive')
  log10_cap <- num_param(params, 'max_log10_value', 10)
  value_floor <- 10 ^ (-log10_cap)
  out$signed_log10_fdr <- -log10(pmax(out$FDR, value_floor)) * ifelse(out$direction == 'negative', -1, 1)
  out$signed_log10_p <- -log10(pmax(out$pvalue, value_floor)) * ifelse(out$direction == 'negative', -1, 1)
  out$neg_log10_fdr <- -log10(pmax(out$FDR, value_floor))
  out$neg_log10_p <- -log10(pmax(out$pvalue, value_floor))
  out$p.adjust <- out$FDR
  out$significance <- ifelse(!is.na(out$FDR) & out$FDR <= num_param(params, 'fdr_cutoff', 0.05), 'significant', 'not significant')
  out$label_text <- vapply(out$leading_genes, function(x) paste(head(parse_gene_string(x), num_param(params, 'leading_gene_label_n', 4)), collapse = ', '), character(1))
  out
}

stats_label <- function(params, key, default) {
  labels <- as_named_vector(get_param(params, 'stats_labels', NULL), NULL)
  if (!is.null(labels) && key %in% names(labels)) as.character(labels[[key]]) else default
}

add_stats_block <- function(plot, selected, terms, params) {
  if (!as_bool(get_param(params, 'stats_show', FALSE), FALSE) || nrow(selected) == 0) return(plot)
  columns <- tolower(as_string_vector(get_param(params, 'stats_columns', c('NES', 'pvalue', 'padj'))))
  rows <- head(selected[selected$term %in% terms, , drop = FALSE], num_param(params, 'stats_rows', length(terms)))
  if (nrow(rows) == 0) return(plot)
  value_for <- function(row, key) {
    if (key == 'nes') return(ifelse(is.na(row$NES), 'NA', formatC(row$NES, digits = num_param(params, 'stats_digits', 3), format = 'f')))
    if (key %in% c('pvalue', 'p', 'pval')) return(format_p_value(row$pvalue, num_param(params, 'stats_digits', 3)))
    format_p_value(row$FDR, num_param(params, 'stats_digits', 3))
  }
  headers <- vapply(columns, function(x) stats_label(params, x, switch(x, nes = 'NES', pvalue = 'PValue', padj = 'Adjusted PValue', x)), character(1))
  lines <- vapply(seq_len(nrow(rows)), function(i) paste(c(rows$term[i], vapply(columns, function(x) value_for(rows[i, , drop = FALSE], x), character(1))), collapse = '  '), character(1))
  label <- paste(c(paste(c('Term', headers), collapse = '  '), lines), collapse = '\n')
  pos <- tolower(as.character(get_param(params, 'stats_position', 'top_right'))[1])
  hjust <- if (grepl('left', pos)) 0 else 1
  vjust <- if (grepl('top', pos)) 1.05 else -0.1
  plot + annotate('label', x = if (hjust == 0) -Inf else Inf, y = if (vjust > 0) Inf else -Inf,
                  label = label, hjust = hjust, vjust = vjust,
                  size = num_param(params, 'stats_text_size', 3),
                  color = get_param(params, 'stats_text_color', '#222222'),
                  fill = get_param(params, 'stats_background', 'white'),
                  label.size = if (as_bool(get_param(params, 'stats_border', TRUE), TRUE)) .3 else 0,
                  alpha = num_param(params, 'stats_table_alpha', 0.92))
}

make_dot_summary_plot <- function(selected, params) {
  x_col <- get_param(params, 'dot_summary_x', 'NES'); if (!x_col %in% names(selected)) x_col <- 'NES'
  color_col <- get_param(params, 'dot_summary_color', 'p.adjust'); if (!color_col %in% names(selected)) color_col <- 'FDR'
  size_col <- get_param(params, 'dot_summary_size', 'Count'); if (!size_col %in% names(selected)) size_col <- 'Count'
  d <- selected
  d$dot_x <- suppressWarnings(as.numeric(d[[x_col]])); d$dot_color <- suppressWarnings(as.numeric(d[[color_col]])); d$dot_size <- suppressWarnings(as.numeric(d[[size_col]]))
  d$dot_size[is.na(d$dot_size)] <- 0; d$dot_color[is.na(d$dot_color)] <- 1
  sign_col <- get_param(params, 'dot_summary_sign_column', 'direction'); if (!sign_col %in% names(d)) sign_col <- 'direction'
  d$dot_sign <- ifelse(as.character(d[[sign_col]]) %in% c('negative', 'down', 'suppressed', 'inhibited'), get_param(params, 'dot_summary_negative_label', 'Suppressed'), get_param(params, 'dot_summary_positive_label', 'Activated'))
  order_mode <- tolower(as.character(get_param(params, 'dot_summary_order', 'x'))[1])
  d <- d[order(if (order_mode %in% c('count', 'size')) -d$dot_size else if (order_mode %in% c('padj', 'p.adjust', 'fdr')) d$dot_color else d$dot_x, na.last = TRUE), , drop = FALSE]
  top_n <- num_param(params, 'dot_summary_top_n', 0); if (top_n > 0) d <- head(d, top_n)
  d$term_plot <- factor(d$term, levels = rev(unique(d$term)))
  split_mode <- tolower(as.character(get_param(params, 'dot_summary_split', 'none'))[1])
  p <- ggplot(d, aes(x = dot_x, y = term_plot))
  if (as_bool(get_param(params, 'dot_summary_segment_show', TRUE), TRUE)) p <- p + geom_segment(aes(x = 0, xend = dot_x, yend = term_plot), color = get_param(params, 'dot_summary_segment_color', '#BDBDBD'), linewidth = .55)
  p <- p + geom_vline(xintercept = 0, linetype = 'dashed', color = '#777777', linewidth = .4) +
    geom_point(aes(size = dot_size, color = dot_color), shape = num_param(params, 'dot_summary_point_shape', 19), alpha = num_param(params, 'dot_summary_point_alpha', .9)) +
    scale_size_continuous(name = get_param(params, 'dot_summary_size', 'Count')) +
    scale_color_gradientn(colors = as_string_vector(get_param(params, 'dot_summary_palette', c('#2166AC', '#F7F7F7', '#B2182B'))), limits = get_param(params, 'dot_summary_limits', NULL), name = get_param(params, 'dot_summary_color', 'p.adjust')) +
    labs(title = get_param(params, 'title', 'FGSEA enriched terms'), x = get_param(params, 'dot_summary_xlab', 'NES'), y = get_param(params, 'dot_summary_ylab', NULL)) +
    theme_classic(base_family = get_param(params, 'font_family', 'sans')) +
    theme(legend.position = get_param(params, 'dot_summary_legend_position', 'right'), axis.text.y = element_text(size = num_param(params, 'dot_summary_label_size', 9)))
  # Sign facets are stacked vertically so every facet keeps its own full-width term axis.
  if (split_mode == 'sign' && as_bool(get_param(params, 'dot_summary_facet', TRUE), TRUE)) p <- p + facet_grid(rows = vars(dot_sign), scales = 'free_y', space = 'free_y')
  if (as_bool(get_param(params, 'dot_summary_label_show', FALSE), FALSE)) {
    # In-panel labels replace the y-axis text: placed on the outward side of each point, with the
    # x range widened by the estimated label width so text stays inside the panel.
    label_size <- num_param(params, 'dot_summary_label_size', 3)
    nudge <- num_param(params, 'dot_summary_label_nudge_x', .05)
    d$label_hjust <- ifelse(d$dot_x < 0, 1, 0)
    span <- max(diff(range(c(0, d$dot_x), na.rm = TRUE)), 1e-6)
    panel_in <- max(2, num_param(params, 'width', 10) * 0.55)
    text_in <- function(lab) if (length(lab)) max(nchar(lab)) * label_size * 0.7 / 25.4 else 0
    # Both sides share the panel: total = span + left + right, and each side's share of the
    # panel width equals its label width share, so total = span / (1 - (tl + tr) / panel_in).
    tl <- text_in(d$term[d$dot_x < 0]); tr <- text_in(d$term[d$dot_x >= 0])
    frac <- min(0.75, (tl + tr) / panel_in)
    total <- span / (1 - frac)
    left <- if (tl + tr > 0) total * frac * tl / (tl + tr) else 0
    right <- if (tl + tr > 0) total * frac * tr / (tl + tr) else 0
    p <- p +
      geom_text(data = d, aes(x = dot_x + ifelse(dot_x < 0, -1, 1) * nudge * span, label = term, hjust = label_hjust),
                color = get_param(params, 'dot_summary_label_color', '#222222'), size = label_size) +
      scale_x_continuous(expand = expansion(mult = 0.04, add = c(left, right))) +
      theme(axis.text.y = element_blank(), axis.ticks.y = element_blank())
  }
  p
}

panel_placeholder <- function(title, detail) {
  ggplot() + annotate('text', x = 0, y = 1, label = paste(title, detail, sep = '\n'), size = 4, color = '#666666') + xlim(-1, 1) + ylim(0, 2) + theme_void()
}

select_terms <- function(res, params) {
  include <- normalize_terms(as_string_vector(get_param_any(params, c('selected_terms', 'terms_include', 'highlight_terms'), NULL)))
  exclude <- normalize_terms(as_string_vector(get_param(params, 'terms_exclude', NULL)))
  out <- res
  if (length(include) > 0) out <- out[out$term %in% include, , drop = FALSE]
  if (length(exclude) > 0) out <- out[!out$term %in% exclude, , drop = FALSE]
  if (length(include) == 0) {
    top_n <- num_param(params, 'top_n_terms', 20)
    metric <- get_param(params, 'sort_by', 'FDR')
    if (metric %in% colnames(out)) {
      if (metric %in% c('FDR', 'pvalue')) out <- out[order(out[[metric]], -abs(out$NES), na.last = TRUE), , drop = FALSE]
      else out <- out[order(-abs(out[[metric]]), na.last = TRUE), , drop = FALSE]
    } else {
      out <- out[order(-abs(out$NES), na.last = TRUE), , drop = FALSE]
    }
    out <- head(out, top_n)
  }
  if (nrow(out) == 0) write_error_and_exit('No terms selected for plotting', '', 'Check selected_terms/top_n_terms/terms_exclude.')
  out
}

palette_values <- function(n, scheme = 'direction') {
  if (scheme == 'direction') return(c(positive = '#D84B39', negative = '#3B6FB6', `not significant` = '#BDBDBD'))
  base <- c('#4E79A7', '#F28E2B', '#E15759', '#76B7B2', '#59A14F', '#EDC948', '#B07AA1', '#FF9DA7')
  rep(base, length.out = n)
}

format_p_value <- function(x, digits = 3) {
  if (is.null(x) || length(x) == 0 || is.na(x[1])) return('NA')
  formatC(as.numeric(x[1]), digits = digits, format = 'e')
}

sig_stars <- function(x) {
  if (is.null(x) || length(x) == 0 || is.na(x[1])) return('ns')
  x <- as.numeric(x[1])
  if (x < 1e-4) return('****')
  if (x < 1e-3) return('***')
  if (x < 1e-2) return('**')
  if (x < 5e-2) return('*')
  'ns'
}

is_multi_group_plot <- function(params) {
  pt <- tolower(as.character(get_param(params, 'plot_type', ''))[1])
  pt %in% c('multi_group', 'multigroup', 'grouped_gsea', 'multi_condition', 'group_running', 'multi_group_running')
}

default_group_colors <- function(groups) {
  base <- c('#C2185B', '#90CAF9', '#111111', '#2CA02C', '#FF7F0E', '#9467BD')
  setNames(rep(base, length.out = length(groups)), groups)
}

split_ranks_by_group <- function(df, params) {
  gene_col <- get_param_any(params, c('gene_col', 'gene_column'), find_column(df, c('gene', 'Gene', 'gene_symbol', 'symbol', 'feature'), TRUE, 'rank gene column'))
  group_col <- get_param_any(params, c('group_col', 'group_column', 'condition_col', 'comparison_col'), find_column(df, c('group', 'Group', 'condition', 'comparison', 'contrast'), FALSE))
  selected_groups <- as_string_vector(get_param_any(params, c('selected_groups', 'groups', 'group_order'), NULL))
  ranks_list <- list()

  build_one <- function(d, stat_name) {
    stat <- suppressWarnings(as.numeric(d[[stat_name]]))
    genes <- as.character(d[[gene_col]])
    keep <- !is.na(stat) & !is.na(genes) & nzchar(genes)
    agg <- tapply(stat[keep], genes[keep], mean, na.rm = TRUE)
    if (length(agg) < 2) return(NULL)
    stats <- sort(as.numeric(agg), decreasing = TRUE)
    names(stats) <- names(agg)[order(as.numeric(agg), decreasing = TRUE)]
    stats
  }

  if (!is.null(group_col) && group_col %in% colnames(df)) {
    stat_col <- get_param_any(params, c('stat_col', 'stat_column', 'rank_column'), find_column(df, c('avg_log2FC', 'log2FC', 'stat', 'score', 't', 'waldStat'), TRUE, 'rank statistic column'))
    groups <- as.character(df[[group_col]])
    levels_g <- unique(groups[nzchar(groups) & !is.na(groups)])
    if (length(selected_groups) > 0) levels_g <- intersect(selected_groups, levels_g)
    if (length(levels_g) < 2) write_error_and_exit('multi_group requires at least two groups', paste('Found:', paste(levels_g, collapse = ', ')), 'Provide a group/comparison column with >= 2 levels.')
    for (g in levels_g) {
      one <- build_one(df[groups == g, , drop = FALSE], stat_col)
      if (!is.null(one)) ranks_list[[g]] <- one
    }
  } else {
    numeric_cols <- names(df)[vapply(df, function(x) is.numeric(x) || all(is.finite(suppressWarnings(as.numeric(as.character(x))))), logical(1))]
    numeric_cols <- setdiff(numeric_cols, gene_col)
    if (length(selected_groups) > 0) numeric_cols <- intersect(selected_groups, numeric_cols)
    if (length(numeric_cols) < 2) {
      write_error_and_exit(
        'multi_group needs a group column or multiple rank-statistic columns',
        paste('Columns:', paste(colnames(df), collapse = ', ')),
        'Use long format (gene, group, stat) or wide format (gene + one numeric column per group).'
      )
    }
    for (g in numeric_cols) {
      tmp <- df[, c(gene_col, g), drop = FALSE]
      names(tmp)[2] <- 'stat'
      one <- build_one(tmp, 'stat')
      if (!is.null(one)) ranks_list[[g]] <- one
    }
  }
  ranks_list <- ranks_list[lengths(ranks_list) >= 2]
  if (length(ranks_list) < 2) write_error_and_exit('Could not build two independent ranked lists', '', 'Check group column values and statistic columns.')
  ranks_list
}

make_multi_group_plot <- function(ranks_list, pathways, params) {
  terms <- as_string_vector(get_param_any(params, c('selected_terms', 'selected_term', 'pathway', 'term'), NULL))
  if (length(terms) == 0) {
    if (length(pathways) == 0) write_error_and_exit('No pathway selected', '', 'Set selected_terms to one gene-set name.')
    terms <- names(pathways)[1]
  }
  term <- terms[1]
  if (!term %in% names(pathways)) {
    write_error_and_exit('Selected pathway not found in genesets', term, paste('Available:', paste(head(names(pathways), 12), collapse = ', ')))
  }
  gene_set <- pathways[[term]]
  groups <- names(ranks_list)
  custom_colors <- as_named_vector(get_param_any(params, c('group_colors', 'curve_colors', 'term_colors'), NULL), NULL)
  colors <- default_group_colors(groups)
  if (!is.null(custom_colors)) {
    for (nm in intersect(names(custom_colors), groups)) colors[nm] <- as.character(custom_colors[[nm]])
  }
  exponent <- num_param(params, 'exponent', 1)

  score_df <- do.call(rbind, lapply(groups, function(g) {
    d <- gsea_scores(ranks_list[[g]], gene_set, exponent)
    d$group <- g
    d
  }))
  score_df$group <- factor(score_df$group, levels = groups)

  title_text <- get_param(params, 'title', gsub('_', ' ', term))
  p_curve <- ggplot(score_df, aes(x = x, y = runningScore, color = group)) +
    geom_hline(yintercept = 0, linetype = 'dashed', color = '#111111', linewidth = 0.55) +
    geom_line(linewidth = num_param(params, 'curve_line_width', 0.9), alpha = 0.95) +
    scale_color_manual(values = colors, name = get_param(params, 'legend_title', NULL)) +
    labs(title = title_text, x = NULL, y = get_param(params, 'ylab', 'Enrichment Score')) +
    theme_classic(base_family = get_param(params, 'font_family', 'sans')) +
    theme(
      plot.title = element_text(hjust = 0.5, size = num_param(params, 'title_size', 16), face = 'plain'),
      axis.text.x = element_blank(),
      axis.ticks.x = element_blank(),
      axis.title.y = element_text(size = 12),
      legend.position = get_param(params, 'legend_position', 'right'),
      legend.title = if (is.null(get_param(params, 'legend_title', NULL))) element_blank() else element_text(),
      panel.border = element_blank()
    )

  n_g <- length(groups)
  hit_df <- score_df[score_df$is_hit, , drop = FALSE]
  band_df <- data.frame(
    group = factor(groups, levels = groups),
    ymin = seq_len(n_g) - 0.42,
    ymax = seq_len(n_g) + 0.42,
    stringsAsFactors = FALSE
  )
  hit_df$ymin <- as.numeric(factor(hit_df$group, levels = groups)) - 0.42
  hit_df$ymax <- as.numeric(factor(hit_df$group, levels = groups)) + 0.42
  p_hits <- ggplot() +
    geom_rect(
      data = band_df,
      aes(xmin = 0.5, xmax = max(score_df$x, na.rm = TRUE) + 0.5, ymin = ymin, ymax = ymax, fill = group),
      inherit.aes = FALSE,
      color = NA
    ) +
    geom_linerange(
      data = hit_df,
      aes(x = x, ymin = ymin, ymax = ymax),
      color = 'white',
      linewidth = num_param(params, 'hit_line_width', 0.35),
      alpha = num_param(params, 'hit_alpha', 0.95)
    ) +
    scale_fill_manual(values = colors, guide = 'none') +
    scale_y_reverse(breaks = seq_len(n_g), labels = groups, expand = c(0.04, 0.04)) +
    labs(x = NULL, y = NULL) +
    theme_classic(base_family = get_param(params, 'font_family', 'sans')) +
    theme(
      axis.text.x = element_blank(),
      axis.ticks = element_blank(),
      axis.text.y = element_blank(),
      axis.line = element_blank(),
      panel.border = element_blank(),
      plot.margin = margin(2, 8, 2, 8)
    )

  # Shared rank-direction strip: mean statistic at each rank index across groups.
  max_n <- max(vapply(ranks_list, length, integer(1)))
  metric_mat <- vapply(ranks_list, function(r) {
    v <- as.numeric(r)
    if (length(v) < max_n) v <- c(v, rep(tail(v, 1), max_n - length(v)))
    v[seq_len(max_n)]
  }, numeric(max_n))
  if (is.null(dim(metric_mat))) metric_mat <- matrix(metric_mat, ncol = 1)
  rank_df <- data.frame(x = seq_len(max_n), stat = rowMeans(metric_mat, na.rm = TRUE))
  caps <- stats::quantile(rank_df$stat, c(0.02, 0.98), na.rm = TRUE)
  rank_df$stat_cap <- pmax(pmin(rank_df$stat, caps[2]), caps[1])
  p_rank <- ggplot(rank_df, aes(x = x, y = 1, fill = stat_cap)) +
    geom_tile(height = 0.9, width = 1.02, show.legend = FALSE) +
    scale_fill_gradient2(
      low = get_param(params, 'rank_band_negative_color', '#1565C0'),
      mid = get_param(params, 'rank_band_mid_color', '#F5F5F5'),
      high = get_param(params, 'rank_band_positive_color', '#C62828'),
      midpoint = 0
    ) +
    annotate('text', x = max_n * 0.08, y = 1, label = get_param(params, 'positive_label', 'Up regulated'),
             color = 'white', size = 3.2, fontface = 'plain') +
    annotate('text', x = max_n * 0.92, y = 1, label = get_param(params, 'negative_label', 'Down regulated'),
             color = 'white', size = 3.2, fontface = 'plain') +
    labs(x = get_param(params, 'xlab', 'Rank in Ordered Dataset'), y = NULL) +
    theme_classic(base_family = get_param(params, 'font_family', 'sans')) +
    theme(
      axis.text.y = element_blank(),
      axis.ticks.y = element_blank(),
      axis.line.y = element_blank(),
      axis.title.x = element_text(size = 13),
      plot.margin = margin(2, 8, 8, 8)
    )

  if (!requireNamespace('patchwork', quietly = TRUE)) write_error_and_exit('Package patchwork is required')
  rug_h <- num_param(params, 'hit_rug_height', 0.16) * n_g
  heights <- as.numeric(unlist(get_param(params, 'rel_heights', c(1.35, rug_h, 0.22))))
  if (length(heights) != 3) heights <- c(1.35, max(0.28, rug_h), 0.22)
  patchwork::wrap_plots(p_curve, p_hits, p_rank, ncol = 1, heights = heights)
}

make_enrichment_ridge_plot <- function(selected, ranks, pathways, params) {
  if (is.null(ranks) || is.null(pathways)) {
    write_error_and_exit('Ridge plot requires rank stats and gene sets', '', 'Use compute mode with --genesets and a gene + log2FC table.')
  }
  if (nrow(selected) == 0) write_error_and_exit('No terms selected for ridge plot')
  gene_mode <- tolower(as.character(get_param(params, 'ridge_gene_mode', 'all_members'))[1])
  min_genes <- num_param(params, 'ridge_min_genes', 8)
  rows <- list()
  for (i in seq_len(nrow(selected))) {
    term <- selected$term[i]
    members <- character()
    if (gene_mode == 'leading_edge') members <- parse_gene_string(selected$leading_genes[i])
    if (length(members) == 0 && term %in% names(pathways)) members <- pathways[[term]]
    members <- intersect(unique(members), names(ranks))
    if (length(members) < min_genes) next
    pval <- selected$pvalue[i]
    if (is.na(pval)) pval <- selected$FDR[i]
    if (is.na(pval)) pval <- 1
    rows[[length(rows) + 1]] <- data.frame(
      term = term,
      gene = members,
      log2FC = as.numeric(ranks[members]),
      pvalue = pval,
      NES = selected$NES[i],
      stringsAsFactors = FALSE
    )
  }
  gene_df <- do.call(rbind, rows)
  if (is.null(gene_df) || nrow(gene_df) == 0) {
    write_error_and_exit('No pathway genes overlap the ranked list', '', 'Check gene IDs in ranks vs GMT.')
  }
  gene_df <- gene_df[is.finite(gene_df$log2FC), , drop = FALSE]
  log10_cap <- num_param(params, 'max_log10_value', 6)
  gene_df$neglog10p <- pmin(-log10(pmax(gene_df$pvalue, 10 ^ (-log10_cap))), log10_cap)

  order_by <- tolower(as.character(get_param(params, 'ridge_order', get_param(params, 'sort_by', 'pvalue')))[1])
  term_meta <- unique(gene_df[, c('term', 'pvalue', 'NES', 'neglog10p')])
  if (order_by %in% c('nes', 'NES')) {
    term_meta <- term_meta[order(term_meta$NES, na.last = TRUE), , drop = FALSE]
  } else if (order_by %in% c('user', 'given', 'selected')) {
    term_meta <- term_meta[match(intersect(selected$term, term_meta$term), term_meta$term), , drop = FALSE]
  } else {
    term_meta <- term_meta[order(-term_meta$neglog10p, term_meta$pvalue, na.last = TRUE), , drop = FALSE]
  }
  term_levels <- rev(term_meta$term)
  label_map <- stats::setNames(gsub('_', ' ', term_levels), term_levels)
  gene_df$term <- factor(gene_df$term, levels = term_levels, labels = unname(label_map[term_levels]))
  fill_map <- stats::setNames(term_meta$neglog10p, unname(label_map[term_meta$term]))
  gene_df$fill_value <- unname(fill_map[as.character(gene_df$term)])

  xlim <- as.numeric(unlist(get_param(params, 'ridge_xlim', NULL)))
  if (length(xlim) != 2 || any(!is.finite(xlim))) {
    xmax <- max(abs(range(gene_df$log2FC, na.rm = TRUE)), 1)
    xlim <- c(-xmax, xmax) * num_param(params, 'ridge_xlim_expand', 1.05)
  }

  pal <- as_string_vector(get_param(params, 'ridge_palette', c('#0D0887', '#6A00A8', '#B12A90', '#E16462', '#FCA636', '#F0F921')))
  if (length(pal) < 2) pal <- c('#0D0887', '#B12A90', '#F0F921')
  rug_color <- get_param(params, 'ridge_rug_color', '#E53935')
  scale_h <- num_param(params, 'ridge_scale', 1.15)
  rel_min <- num_param(params, 'ridge_rel_min_height', 0.01)

  if (!requireNamespace('ggridges', quietly = TRUE)) {
    write_error_and_exit('Package ggridges is required for ridge plots', '', 'install.packages("ggridges")')
  }

  p <- ggplot(gene_df, aes(x = log2FC, y = term, fill = fill_value, group = term)) +
    ggridges::geom_density_ridges(
      scale = scale_h,
      rel_min_height = rel_min,
      color = get_param(params, 'ridge_outline_color', '#111111'),
      linewidth = num_param(params, 'ridge_outline_width', 0.35),
      alpha = num_param(params, 'ridge_alpha', 0.95)
    ) +
    geom_segment(
      data = gene_df,
      aes(x = log2FC, xend = log2FC, y = as.numeric(term) - 0.12, yend = as.numeric(term) - 0.02),
      color = rug_color,
      linewidth = num_param(params, 'ridge_rug_width', 0.28),
      alpha = num_param(params, 'ridge_rug_alpha', 0.85),
      inherit.aes = FALSE
    ) +
    scale_fill_gradientn(
      colours = pal,
      name = get_param(params, 'ridge_legend_title', '-log10(pvalue)'),
      limits = c(min(gene_df$fill_value, na.rm = TRUE), max(gene_df$fill_value, na.rm = TRUE))
    ) +
    coord_cartesian(xlim = xlim, clip = 'off') +
    labs(
      title = get_param(params, 'title', NULL),
      x = get_param(params, 'xlab', 'log2FoldChange'),
      y = NULL
    ) +
    theme_classic(base_family = get_param(params, 'font_family', 'sans')) +
    theme(
      axis.text.y = element_text(size = num_param(params, 'ridge_term_size', 10), color = '#222222'),
      axis.text.x = element_text(size = 10),
      axis.title.x = element_text(size = 12),
      legend.position = get_param(params, 'legend_position', 'right'),
      plot.title = element_text(hjust = 0.5, size = num_param(params, 'title_size', 14)),
      panel.grid.major.x = if (as_bool(get_param(params, 'ridge_show_grid', FALSE), FALSE)) element_line(color = '#E0E0E0') else element_blank(),
      panel.grid.major.y = element_blank()
    )
  if (as_bool(get_param(params, 'ridge_vline0', TRUE), TRUE)) {
    p <- p + geom_vline(xintercept = 0, color = '#888888', linewidth = 0.3, linetype = 'dotted')
  }
  p
}

pretty_term_label <- function(x, wrap = 22) {
  lab <- gsub('_', ' ', as.character(x))
  vapply(lab, function(s) paste(strwrap(s, width = wrap), collapse = '\n'), character(1))
}

make_gene_pathway_sankey_plot <- function(selected, ranks, pathways, params) {
  if (!requireNamespace('ggforce', quietly = TRUE)) {
    write_error_and_exit('Package ggforce is required for gene-pathway Sankey', '', 'install.packages("ggforce")')
  }
  if (is.null(pathways) || length(pathways) == 0) {
    write_error_and_exit('Gene-pathway Sankey requires gene sets', '', 'Provide --genesets and compute/precomputed enrichment.')
  }
  max_terms <- num_param(params, 'sankey_max_terms', num_param(params, 'top_n_terms', 5))
  max_genes <- num_param(params, 'sankey_max_genes', 22)
  gene_mode <- tolower(as.character(get_param(params, 'sankey_gene_mode', 'leading_edge'))[1])
  terms <- head(selected$term, max_terms)
  selected <- selected[match(terms, selected$term), , drop = FALSE]

  edges <- list()
  for (i in seq_len(nrow(selected))) {
    term <- selected$term[i]
    members <- character()
    if (gene_mode != 'all_members') members <- parse_gene_string(selected$leading_genes[i])
    if (length(members) == 0 && term %in% names(pathways)) members <- pathways[[term]]
    if (!is.null(ranks)) members <- intersect(members, names(ranks))
    if (length(members) == 0) next
    edges[[length(edges) + 1]] <- data.frame(gene = members, term = term, stringsAsFactors = FALSE)
  }
  edge_df <- do.call(rbind, edges)
  if (is.null(edge_df) || nrow(edge_df) == 0) {
    write_error_and_exit('No gene-pathway membership for Sankey', '', 'Check leading-edge genes and GMT overlap.')
  }
  if (!is.null(ranks)) {
    edge_df$score <- abs(unname(ranks[edge_df$gene]))
    edge_df$score[is.na(edge_df$score)] <- 0
  } else {
    edge_df$score <- 1
  }
  gene_rank <- tapply(edge_df$score, edge_df$gene, max)
  keep_genes <- names(sort(gene_rank, decreasing = TRUE))
  keep_genes <- head(keep_genes, max_genes)
  edge_df <- edge_df[edge_df$gene %in% keep_genes, , drop = FALSE]
  terms <- intersect(terms, unique(edge_df$term))
  selected <- selected[selected$term %in% terms, , drop = FALSE]
  genes <- keep_genes[keep_genes %in% edge_df$gene]
  nG <- length(genes)
  nT <- length(terms)
  if (nG < 2 || nT < 1) write_error_and_exit('Sankey needs at least two genes and one term')

  gene_y <- stats::setNames((nG:1 - 0.5) / nG, genes)
  term_y <- stats::setNames((nT:1 - 0.5) / nT, terms)
  term_h <- min(0.16, 0.72 / nT)

  universe_n <- if (!is.null(ranks)) length(ranks) else length(unique(edge_df$gene))
  term_stats <- lapply(seq_len(nrow(selected)), function(i) {
    term <- selected$term[i]
    k <- sum(edge_df$term == term)
    size <- if (term %in% names(pathways)) max(length(pathways[[term]]), k) else k
    pval <- selected$pvalue[i]
    if (is.na(pval)) pval <- selected$FDR[i]
    if (is.na(pval)) pval <- 1
    data.frame(
      term = term,
      y = unname(term_y[term]),
      neglog10p = -log10(pmax(pval, 1e-16)),
      gene_ratio = k / max(universe_n, 1),
      term_ratio = k / max(size, 1),
      stringsAsFactors = FALSE
    )
  })
  term_stats <- do.call(rbind, term_stats)
  term_stats$term <- factor(term_stats$term, levels = rev(terms))

  gene_cols <- grDevices::hcl.colors(max(nG, 8), palette = 'Dark 3')
  if (nG > length(gene_cols)) gene_cols <- grDevices::hcl.colors(nG, palette = 'Set 2')
  gene_fill <- stats::setNames(gene_cols[seq_len(nG)], genes)
  term_fill <- as_named_vector(get_param(params, 'term_colors', NULL), NULL)
  if (is.null(term_fill) || length(intersect(names(term_fill), terms)) == 0) {
    term_fill <- stats::setNames(grDevices::hcl.colors(max(nT, 3), palette = 'Warm'), terms)
  } else {
    fallback <- stats::setNames(grDevices::hcl.colors(max(nT, 3), palette = 'Warm'), terms)
    for (tm in terms) if (!tm %in% names(term_fill)) term_fill[[tm]] <- fallback[[tm]]
    term_fill <- term_fill[terms]
  }

  bezier_df <- do.call(rbind, lapply(seq_len(nrow(edge_df)), function(i) {
    g <- edge_df$gene[i]
    tm <- edge_df$term[i]
    gy <- unname(gene_y[g])
    ty <- unname(term_y[tm])
    data.frame(
      x = c(0.16, 0.38, 0.58, 0.76),
      y = c(gy, gy, ty, ty),
      group = paste(g, tm, i, sep = '|'),
      term = tm,
      stringsAsFactors = FALSE
    )
  }))

  gene_df <- data.frame(gene = genes, y = unname(gene_y[genes]), stringsAsFactors = FALSE)
  term_df <- data.frame(
    term = terms,
    label = pretty_term_label(terms),
    y = unname(term_y[terms]),
    stringsAsFactors = FALSE
  )

  link_col <- get_param(params, 'sankey_link_color', '#C9C9C9')
  bubble_pal <- as_string_vector(get_param(params, 'sankey_bubble_palette', c('#440154', '#31688E', '#35B779', '#FDE725')))
  pmin <- min(term_stats$neglog10p, na.rm = TRUE)
  pmax <- max(term_stats$neglog10p, na.rm = TRUE)
  if (!is.finite(pmin) || !is.finite(pmax) || pmax <= pmin) {
    pmin <- 0
    pmax <- 1
  }
  x0 <- 1.72
  x1 <- 2.38
  term_stats$x_bub <- x0 + (x1 - x0) * (term_stats$neglog10p - pmin) / (pmax - pmin)
  axis_breaks <- pretty(c(pmin, pmax), n = 4)
  axis_breaks <- axis_breaks[axis_breaks >= pmin * 0.98 & axis_breaks <= pmax * 1.02]
  if (length(axis_breaks) < 2) axis_breaks <- c(pmin, pmax)
  axis_x <- x0 + (x1 - x0) * (axis_breaks - pmin) / (pmax - pmin)
  axis_df <- data.frame(x = axis_x, label = format(axis_breaks, digits = 3), stringsAsFactors = FALSE)

  p <- ggplot() +
    ggforce::geom_bezier(
      data = bezier_df,
      aes(x = x, y = y, group = group),
      color = link_col,
      alpha = num_param(params, 'sankey_link_alpha', 0.45),
      linewidth = num_param(params, 'sankey_link_width', 1.05)
    ) +
    geom_rect(
      data = gene_df,
      aes(xmin = 0.02, xmax = 0.07, ymin = y - 0.016, ymax = y + 0.016, fill = gene),
      color = NA
    ) +
    geom_text(
      data = gene_df,
      aes(x = 0.0, y = y, label = gene),
      hjust = 1,
      size = num_param(params, 'sankey_gene_size', 2.7),
      color = '#222222'
    ) +
    geom_text(
      data = term_df,
      aes(x = 0.80, y = y, label = label),
      hjust = 0,
      size = num_param(params, 'sankey_term_size', 3.1),
      color = '#222222'
    ) +
    geom_rect(
      data = term_df,
      aes(xmin = 1.28, xmax = 1.48, ymin = y - term_h / 2, ymax = y + term_h / 2, fill = term),
      color = NA
    ) +
    geom_point(
      data = term_stats,
      aes(x = x_bub, y = y, size = term_ratio, color = gene_ratio),
      alpha = 0.95
    ) +
    geom_segment(x = x0, xend = x1, y = -0.045, yend = -0.045, linewidth = 0.35, color = '#222222') +
    geom_segment(data = axis_df, aes(x = x, xend = x), y = -0.045, yend = -0.06, linewidth = 0.35, color = '#222222', inherit.aes = FALSE) +
    geom_text(data = axis_df, aes(x = x, label = label), y = -0.085, size = 2.7, color = '#222222', inherit.aes = FALSE) +
    annotate('text', x = (x0 + x1) / 2, y = -0.125, label = get_param(params, 'sankey_bubble_xlab', '-log10(pvalue)'), size = 3.2) +
    scale_fill_manual(values = c(gene_fill, term_fill), guide = 'none') +
    scale_color_gradientn(colours = bubble_pal, name = 'gene_ratio') +
    scale_size_continuous(name = 'term_ratio', range = c(4.5, 12)) +
    coord_cartesian(xlim = c(-0.38, 2.62), ylim = c(-0.16, 1.04), clip = 'off') +
    theme_void() +
    theme(
      legend.position = 'right',
      plot.margin = margin(10, 12, 16, 36)
    )
  p
}

make_summary_plot <- function(selected, params) {
  x_col <- get_param(params, 'x_column', 'NES')
  if (!x_col %in% colnames(selected)) x_col <- 'NES'
  y_order <- selected$term[order(selected[[x_col]], na.last = TRUE)]
  selected$term_plot <- factor(selected$term, levels = y_order)
  color_mode <- get_param(params, 'color_mode', 'direction')
  size_col <- get_param(params, 'size_column', 'neg_log10_fdr')
  if (!size_col %in% colnames(selected)) size_col <- 'neg_log10_p'
  colors <- as_named_vector(get_param(params, 'colors', NULL), default = NULL)
  if (is.null(colors)) colors <- palette_values(3, color_mode)

  point_shape <- num_param(params, 'point_shape', 21)
  p <- ggplot(selected, aes(x = .data[[x_col]], y = term_plot)) +
    geom_vline(xintercept = 0, color = get_param(params, 'zero_line_color', '#444444'),
               linewidth = num_param(params, 'zero_line_width', 0.45),
               linetype = get_param(params, 'zero_line_type', 'dashed')) +
    geom_segment(aes(x = 0, xend = .data[[x_col]], yend = term_plot),
                 color = get_param(params, 'stem_color', '#BDBDBD'),
                 linewidth = num_param(params, 'stem_width', 0.55),
                 alpha = num_param(params, 'stem_alpha', 0.8)) +
    geom_point(aes(fill = direction, size = .data[[size_col]]),
               shape = point_shape,
               color = get_param(params, 'point_border_color', '#222222'),
               stroke = num_param(params, 'point_border_width', 0.3),
               alpha = num_param(params, 'point_alpha', 0.88)) +
    scale_fill_manual(values = colors, name = get_param(params, 'color_legend_name', 'Direction')) +
    scale_size_continuous(name = get_param(params, 'size_legend_title', '-log10(FDR)'),
                          range = c(num_param(params, 'min_point_size', 2.2), num_param(params, 'max_point_size', 7.5))) +
    scale_x_continuous(expand = expansion(mult = c(0.08, 0.22))) +
    coord_cartesian(clip = 'off') +
    labs(
      title = if (as_bool(get_param(params, 'title_show', TRUE), TRUE)) get_param(params, 'title', 'FGSEA enrichment summary') else NULL,
      x = get_param(params, 'x_title', x_col),
      y = get_param(params, 'y_title', NULL)
    ) +
    theme_classic(base_family = get_param(params, 'font_family', 'sans')) +
    theme(
      plot.title = element_text(size = num_param(params, 'title_size', 16),
                                face = ifelse(as_bool(get_param(params, 'title_bold', TRUE), TRUE), 'bold', 'plain'),
                                color = get_param(params, 'title_color', '#222222'),
                                hjust = num_param(params, 'title_hjust', 0.5)),
      axis.title = element_text(size = num_param(params, 'axis_title_size', 12), color = get_param(params, 'axis_title_color', '#222222')),
      axis.text.x = element_text(size = num_param(params, 'x_axis_text_size', 10), color = get_param(params, 'axis_text_color', '#222222')),
      axis.text.y = element_text(size = num_param(params, 'term_label_size', 9), color = get_param(params, 'term_label_color', '#222222')),
      legend.position = get_param(params, 'legend_position', 'right'),
      legend.title = element_text(size = num_param(params, 'legend_title_size', 10)),
      legend.text = element_text(size = num_param(params, 'legend_text_size', 9)),
      panel.grid.major.y = if (as_bool(get_param(params, 'show_y_grid', TRUE), TRUE)) element_line(color = get_param(params, 'grid_color', '#ECECEC')) else element_blank(),
      plot.margin = margin(
        num_param(params, 'plot_margin_top', 10),
        num_param(params, 'plot_margin_right', 40),
        num_param(params, 'plot_margin_bottom', 10),
        num_param(params, 'plot_margin_left', 10)
      )
    )

  if (as_bool(get_param(params, 'show_leading_gene_labels', TRUE), TRUE)) {
    label_terms <- selected
    selected_label_terms <- as_string_vector(get_param(params, 'label_terms', NULL))
    if (length(selected_label_terms) > 0) label_terms <- label_terms[label_terms$term %in% selected_label_terms, , drop = FALSE]
    else label_terms <- head(label_terms[order(-abs(label_terms[[x_col]]), na.last = TRUE), , drop = FALSE], num_param(params, 'label_top_n_terms', 8))
    label_terms <- label_terms[nzchar(label_terms$label_text), , drop = FALSE]
    if (nrow(label_terms) > 0) {
      label_placement <- tolower(as.character(get_param(params, 'label_placement', 'side'))[1])
      if (label_placement %in% c('side', 'side_column', 'column')) {
        x_values <- selected[[x_col]]
        x_span <- diff(range(x_values, na.rm = TRUE))
        if (!is.finite(x_span) || x_span == 0) x_span <- 1
        label_pad <- num_param(params, 'label_side_padding', 0.18) * x_span
        label_wrap_width <- num_param(params, 'label_wrap_width', 0)
        if (label_wrap_width > 0) {
          label_terms$label_text <- vapply(label_terms$label_text, function(x) {
            paste(strwrap(x, width = label_wrap_width), collapse = '\n')
          }, character(1))
        }
        label_side <- tolower(as.character(get_param(params, 'label_side', 'auto'))[1])
        if (label_side == 'right') {
          label_terms$label_x <- max(x_values, na.rm = TRUE) + label_pad
          label_terms$label_hjust <- 0
        } else if (label_side == 'left') {
          label_terms$label_x <- min(x_values, na.rm = TRUE) - label_pad
          label_terms$label_hjust <- 1
        } else {
          label_terms$label_x <- ifelse(
            label_terms[[x_col]] >= 0,
            max(x_values, na.rm = TRUE) + label_pad,
            min(x_values, na.rm = TRUE) - label_pad
          )
          label_terms$label_hjust <- ifelse(label_terms[[x_col]] >= 0, 0, 1)
        }
        p <- p +
          expand_limits(x = c(min(label_terms$label_x, na.rm = TRUE), max(label_terms$label_x, na.rm = TRUE))) +
          geom_segment(
            data = label_terms,
            aes(x = .data[[x_col]], xend = label_x, y = term_plot, yend = term_plot),
            inherit.aes = FALSE,
            color = get_param(params, 'label_line_color', '#777777'),
            linewidth = num_param(params, 'label_line_width', 0.35),
            linetype = get_param(params, 'label_line_type', 'solid'),
            alpha = num_param(params, 'label_line_alpha', 0.75)
          ) +
          geom_text(
            data = label_terms,
            aes(x = label_x, y = term_plot, label = label_text, hjust = label_hjust),
            inherit.aes = FALSE,
            size = num_param(params, 'label_size', 3.1),
            color = get_param(params, 'label_color', '#222222'),
            family = get_param(params, 'font_family', 'sans')
          )
      } else {
        nudge_base <- num_param(params, 'label_nudge_x', 0.85)
        label_nudge_x <- ifelse(label_terms[[x_col]] >= 0, nudge_base, -nudge_base)
        p <- p + geom_text_repel(
          data = label_terms,
          aes(label = label_text),
          size = num_param(params, 'label_size', 3.1),
          color = get_param(params, 'label_color', '#222222'),
          segment.color = get_param(params, 'label_line_color', '#777777'),
          segment.size = num_param(params, 'label_line_width', 0.35),
          max.overlaps = num_param(params, 'label_max_overlaps', 100),
          min.segment.length = 0,
          nudge_x = label_nudge_x,
          box.padding = num_param(params, 'label_box_padding', 0.35),
          point.padding = num_param(params, 'label_point_padding', 0.35),
          show.legend = FALSE
        )
      }
    }
  }

  p
}

gsea_scores <- function(gene_list, gene_set, exponent = 1) {
  gene_names <- names(gene_list)
  gene_set <- intersect(gene_set, gene_names)
  n <- length(gene_list)
  nh <- length(gene_set)
  if (nh == 0 || nh == n) write_error_and_exit('Invalid pathway overlap for running plot', '', 'Selected term has no usable overlap or contains all ranked genes.')
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

make_running_plot <- function(selected, ranks, pathways, params) {
  if (is.null(params[['selected_genes']]) && !is.null(params[['selected_gene_labels']])) params[['selected_genes']] <- params[['selected_gene_labels']]
  if (is.null(params[['label_size']]) && !is.null(params[['selected_gene_label_size']])) params[['label_size']] <- params[['selected_gene_label_size']]
  if (is.null(params[['label_color']]) && !is.null(params[['selected_gene_label_color']])) params[['label_color']] <- params[['selected_gene_label_color']]
  if (is.null(params[['label_nudge_x']]) && !is.null(params[['selected_gene_label_nudge_x']])) params[['label_nudge_x']] <- params[['selected_gene_label_nudge_x']]
  if (is.null(params[['label_nudge_y']]) && !is.null(params[['selected_gene_label_nudge_y']])) params[['label_nudge_y']] <- params[['selected_gene_label_nudge_y']]
  if (is.null(params[['label_arrow']]) && !is.null(params[['selected_gene_label_arrow']])) params[['label_arrow']] <- params[['selected_gene_label_arrow']]
  if (is.null(params[['label_line_color']]) && !is.null(params[['selected_gene_label_arrow_color']])) params[['label_line_color']] <- params[['selected_gene_label_arrow_color']]
  if (is.null(params[['label_line_width']]) && !is.null(params[['selected_gene_label_arrow_width']])) params[['label_line_width']] <- params[['selected_gene_label_arrow_width']]
  if (is.null(params[['show_peak_label']]) && !is.null(params[['peak_label_show']])) params[['show_peak_label']] <- params[['peak_label_show']]
  if (is.null(params[['show_zero_cross']]) && !is.null(params[['zero_line_show']])) params[['show_zero_cross']] <- params[['zero_line_show']]
  if (is.null(params[['rug_show']]) && !is.null(params[['hit_rug_show']])) params[['rug_show']] <- params[['hit_rug_show']]
  if (is.null(ranks) || is.null(pathways)) {
    write_error_and_exit('Running plot requires rank stats and pathways', '', 'Use compute mode with genesets_file/--genesets.')
  }
  terms <- selected$term
  max_terms <- num_param(params, 'running_max_terms', 4)
  terms <- head(terms, max_terms)
  exponent <- num_param(params, 'exponent', 1)
  colors <- palette_values(length(terms), 'terms')
  names(colors) <- terms
  custom_curve_colors <- as_named_vector(get_param(params, 'curve_colors', NULL), default = NULL)
  if (!is.null(custom_curve_colors)) {
    for (nm in intersect(names(custom_curve_colors), terms)) colors[nm] <- custom_curve_colors[[nm]]
  } else if (length(terms) == 1) {
    colors[1] <- get_param(params, 'curve_color', '#63B33E')
  }

  score_df <- do.call(rbind, lapply(terms, function(term) {
    if (!term %in% names(pathways)) return(NULL)
    d <- gsea_scores(ranks, pathways[[term]], exponent)
    d$term <- term
    d
  }))
  if (is.null(score_df) || nrow(score_df) == 0) write_error_and_exit('No running-score data available')
  if (as_bool(get_param(params, 'curve_start_at_zero', TRUE), TRUE)) {
    zero_rows <- do.call(rbind, lapply(terms, function(term) {
      data.frame(x = 0, runningScore = 0, is_hit = FALSE, gene = '', rank_metric = NA_real_, term = term, stringsAsFactors = FALSE)
    }))
    score_df <- rbind(zero_rows, score_df)
  }

  selected_meta <- selected[match(terms, selected$term), , drop = FALSE]
  score_df$term <- factor(score_df$term, levels = terms)
  single_term <- length(terms) == 1
  title_text <- get_param(params, 'title', ifelse(single_term, terms[1], 'GSEA running enrichment'))
  subtitle_text <- get_param(params, 'subtitle', NULL)
  if (is.null(subtitle_text) && single_term) {
    fdr_value <- selected_meta$FDR[1]
    p_value <- selected_meta$pvalue[1]
    p_display <- if (!is.na(fdr_value)) paste0('p.adjust=', format_p_value(fdr_value, num_param(params, 'pvalue_digits', 3))) else paste0('p=', format_p_value(p_value, num_param(params, 'pvalue_digits', 3)))
    subtitle_text <- paste0('(NES=', round(selected_meta$NES[1], num_param(params, 'nes_digits', 3)), ', ', p_display, ', ', sig_stars(ifelse(!is.na(fdr_value), fdr_value, p_value)), ')')
  }

  peak_df <- do.call(rbind, lapply(split(score_df, score_df$term), function(d) {
    idx <- which.max(abs(d$runningScore))
    d[idx, , drop = FALSE]
  }))
  peak_df$NES <- selected_meta$NES[match(as.character(peak_df$term), selected_meta$term)]
  peak_df$peak_direction <- ifelse(peak_df$runningScore >= 0, 'positive', 'negative')

  label_genes <- as_string_vector(get_param_any(params, c('selected_genes', 'features_label', 'label_genes'), NULL))
  top_x <- num_param(params, 'label_top_x_genes', 0)
  hit_df <- score_df[score_df$is_hit, , drop = FALSE]
  if (!as_bool(get_param(params, 'rug_show', TRUE), TRUE)) hit_df <- hit_df[0, , drop = FALSE]
  label_df <- hit_df[hit_df$gene %in% label_genes, , drop = FALSE]
  if (top_x > 0) {
    top_df <- do.call(rbind, lapply(split(hit_df, hit_df$term), function(d) {
      d <- d[order(-abs(d$runningScore)), , drop = FALSE]
      head(d, top_x)
    }))
    label_df <- unique(rbind(label_df, top_df))
  }

  upper_curve_style <- tolower(as.character(get_param_any(params, c('upper_curve_style', 'running_upper_style', 'running_style'), 'normal'))[1])
  gradient_upper <- upper_curve_style %in% c('gradient', 'gradient_curve', 'colored_curve', 'rank_gradient')
  score_df$rank_score <- suppressWarnings(as.numeric(score_df$rank_metric))
  score_df$rank_score[is.na(score_df$rank_score)] <- 0
  score_df$rank_score_cap <- pmax(
    pmin(score_df$rank_score, stats::quantile(score_df$rank_score, num_param(params, 'gradient_upper_quantile', 0.98), na.rm = TRUE)),
    stats::quantile(score_df$rank_score, num_param(params, 'gradient_lower_quantile', 0.02), na.rm = TRUE)
  )
  segment_df <- do.call(rbind, lapply(split(score_df, score_df$term), function(d) {
    d <- d[order(d$x), , drop = FALSE]
    if (nrow(d) < 2) return(NULL)
    out <- d[-nrow(d), , drop = FALSE]
    out$xend <- d$x[-1]
    out$yend <- d$runningScore[-1]
    out$segment_score <- d$rank_score_cap[-1]
    out
  }))
  hit_df <- score_df[score_df$is_hit, , drop = FALSE]
  label_df <- label_df[, intersect(names(label_df), names(score_df)), drop = FALSE]
  if (nrow(label_df) > 0) {
    label_df <- merge(
      label_df[, c('term', 'gene'), drop = FALSE],
      score_df,
      by = c('term', 'gene'),
      all.x = TRUE,
      sort = FALSE
    )
  }

  p1 <- ggplot(score_df, aes(x = x, y = runningScore)) +
    annotate('rect', xmin = -Inf, xmax = Inf, ymin = 0, ymax = Inf, fill = get_param(params, 'positive_bg_color', '#F8D9D9'), alpha = num_param(params, 'bg_alpha', 0.45)) +
    annotate('rect', xmin = -Inf, xmax = Inf, ymin = -Inf, ymax = 0, fill = get_param(params, 'negative_bg_color', '#DDE4FA'), alpha = num_param(params, 'bg_alpha', 0.45)) +
    geom_hline(yintercept = 0, color = get_param(params, 'zero_line_color', '#555555'), linewidth = num_param(params, 'zero_line_width', 0.45)) +
    labs(title = if (as_bool(get_param(params, 'title_show', TRUE), TRUE)) title_text else NULL,
         subtitle = if (as_bool(get_param(params, 'subtitle_show', TRUE), TRUE)) subtitle_text else NULL,
         x = NULL, y = get_param(params, 'running_y_title', 'Enrichment Score')) +
    theme_classic(base_family = get_param(params, 'font_family', 'sans')) +
    theme(
      axis.text.x = element_blank(),
      axis.ticks.x = element_blank(),
      plot.title = element_text(size = num_param(params, 'title_size', 18), face = get_param(params, 'title_fontface', 'plain'), hjust = num_param(params, 'title_hjust', 0)),
      plot.subtitle = element_text(size = num_param(params, 'subtitle_size', 12), face = get_param(params, 'subtitle_fontface', 'italic'), hjust = num_param(params, 'subtitle_hjust', 0)),
      legend.position = if (single_term) get_param(params, 'legend_position', 'none') else get_param(params, 'legend_position', 'right'),
      panel.border = element_rect(color = get_param(params, 'panel_border_color', '#222222'), fill = NA, linewidth = num_param(params, 'panel_border_width', 0.7)),
      panel.grid.major = if (as_bool(get_param(params, 'running_show_grid', TRUE), TRUE)) element_line(color = get_param(params, 'grid_color', '#E2E2E2'), linetype = get_param(params, 'grid_line_type', 'dashed')) else element_blank(),
      panel.grid.minor = if (as_bool(get_param(params, 'running_show_minor_grid', TRUE), TRUE)) element_line(color = get_param(params, 'minor_grid_color', '#EEEEEE'), linetype = get_param(params, 'minor_grid_line_type', 'dashed')) else element_blank()
    )

  if (gradient_upper) {
    p1 <- p1 +
      geom_linerange(
        data = hit_df,
        aes(x = x, ymin = 0, ymax = runningScore, color = rank_score_cap),
        linewidth = num_param(params, 'gradient_hit_line_width', 0.42),
        alpha = num_param(params, 'gradient_hit_alpha', 0.85),
        inherit.aes = FALSE
      ) +
      geom_segment(
        data = segment_df,
        aes(x = x, y = runningScore, xend = xend, yend = yend, color = segment_score),
        linewidth = num_param(params, 'gradient_curve_line_width', num_param(params, 'curve_line_width', 1.15)),
        lineend = get_param(params, 'gradient_curve_lineend', 'round'),
        alpha = num_param(params, 'gradient_curve_alpha', num_param(params, 'curve_alpha', 0.95)),
        inherit.aes = FALSE
      ) +
      scale_color_gradientn(
        colors = as_string_vector(get_param(params, 'gradient_colors', c('#7B00FF', '#55D6FF', '#70FF62', '#D3C800', '#FF0000'))),
        name = get_param(params, 'gradient_legend_title', 'Rank Score'),
        limits = if (as_bool(get_param(params, 'gradient_use_fixed_limits', FALSE), FALSE)) c(num_param(params, 'gradient_min', -1), num_param(params, 'gradient_max', 1)) else NULL,
        guide = guide_colorbar(
          title.position = get_param(params, 'gradient_legend_title_position', 'top'),
          barheight = grid::unit(num_param(params, 'gradient_legend_bar_height_cm', 2.0), 'cm'),
          barwidth = grid::unit(num_param(params, 'gradient_legend_bar_width_cm', 0.35), 'cm')
        )
      )
    if (as_bool(get_param(params, 'show_gradient_curve_points', FALSE), FALSE)) {
      p1 <- p1 +
        geom_point(
          data = score_df,
          aes(x = x, y = runningScore, color = rank_score_cap),
          size = num_param(params, 'gradient_curve_point_size', 0.75),
          alpha = num_param(params, 'gradient_curve_point_alpha', 0.9),
          inherit.aes = FALSE,
          show.legend = FALSE
        )
    }
  } else {
    p1 <- p1 +
      geom_line(aes(color = term), linewidth = num_param(params, 'curve_line_width', 1.0), alpha = num_param(params, 'curve_alpha', 0.9)) +
      scale_color_manual(values = colors, name = get_param(params, 'legend_name', 'Term'))
  }

  if (as_bool(get_param(params, 'show_peak_guides', TRUE), TRUE)) {
    p1 <- p1 +
      geom_segment(data = peak_df, aes(x = x, xend = x, y = 0, yend = runningScore),
                   inherit.aes = FALSE,
                   color = get_param(params, 'peak_guide_color', '#111111'),
                   linewidth = num_param(params, 'peak_guide_width', 0.45),
                   linetype = get_param(params, 'peak_guide_type', 'dashed')) +
      geom_segment(data = peak_df, aes(x = 1, xend = x, y = runningScore, yend = runningScore),
                   inherit.aes = FALSE,
                   color = get_param(params, 'peak_guide_color', '#111111'),
                   linewidth = num_param(params, 'peak_guide_width', 0.45),
                   linetype = get_param(params, 'peak_guide_type', 'dashed'))
  }

  if (as_bool(get_param(params, 'show_peak_marker', TRUE), TRUE)) {
    if (gradient_upper) {
      p1 <- p1 +
        geom_point(data = peak_df,
                   aes(x = x, y = runningScore, shape = peak_direction),
                   inherit.aes = FALSE,
                   size = num_param(params, 'peak_marker_size', 3.4),
                   stroke = num_param(params, 'peak_marker_stroke', 0.45),
                   fill = get_param(params, 'peak_marker_fill', '#FF0000'),
                   color = get_param(params, 'peak_marker_border_color', '#111111'),
                   show.legend = FALSE) +
        scale_shape_manual(values = c(positive = num_param(params, 'peak_positive_shape', 24), negative = num_param(params, 'peak_negative_shape', 25)), guide = 'none')
    } else {
      p1 <- p1 +
        geom_point(data = peak_df,
                   aes(x = x, y = runningScore, fill = term, shape = peak_direction),
                   inherit.aes = FALSE,
                   size = num_param(params, 'peak_marker_size', 3.4),
                   stroke = num_param(params, 'peak_marker_stroke', 0.45),
                   color = get_param(params, 'peak_marker_border_color', '#111111'),
                   show.legend = FALSE) +
        scale_fill_manual(values = colors, guide = 'none') +
        scale_shape_manual(values = c(positive = num_param(params, 'peak_positive_shape', 24), negative = num_param(params, 'peak_negative_shape', 25)), guide = 'none')
    }
  }

  if (as_bool(get_param(params, 'show_peak_label', FALSE), FALSE)) {
    p1 <- p1 +
      annotate(
        'text',
        x = peak_df$x,
        y = peak_df$runningScore,
        label = get_param(params, 'peak_label', paste0('peak rnk=', peak_df$x)),
        hjust = num_param(params, 'peak_label_hjust', -0.1),
        vjust = num_param(params, 'peak_label_vjust', -0.6),
        size = num_param(params, 'peak_label_size', 3.2),
        color = get_param(params, 'peak_label_color', '#111111'),
        fontface = get_param(params, 'peak_label_fontface', 'plain')
      )
  }

  if (nrow(label_df) > 0 && as_bool(get_param(params, 'label_show', TRUE), TRUE)) {
    p1 <- p1 +
      geom_point(data = label_df, aes(x = x, y = runningScore), color = get_param(params, 'selected_gene_point_color', '#111111'), size = num_param(params, 'selected_gene_point_size', 1.8), inherit.aes = FALSE)
    if (gradient_upper) {
      p1 <- p1 +
        geom_text_repel(
          data = label_df,
          aes(x = x, y = runningScore, label = gene),
          inherit.aes = FALSE,
          size = num_param(params, 'label_size', 3.2),
          color = get_param(params, 'label_color', '#111111'),
          fontface = get_param(params, 'label_fontface', 'plain'),
          segment.color = get_param(params, 'label_line_color', '#555555'),
          segment.size = num_param(params, 'label_line_width', 0.35),
          max.overlaps = num_param(params, 'label_max_overlaps', 100),
          min.segment.length = 0,
          show.legend = FALSE
        )
    } else {
      p1 <- p1 +
        geom_text_repel(
          data = label_df,
          aes(x = x, y = runningScore, label = gene, color = term),
          size = num_param(params, 'label_size', 3.2),
          segment.color = get_param(params, 'label_line_color', '#555555'),
          segment.size = num_param(params, 'label_line_width', 0.35),
          max.overlaps = num_param(params, 'label_max_overlaps', 100),
          min.segment.length = 0,
          show.legend = FALSE
        )
    }
  }

  hit_df$ymin <- as.numeric(factor(hit_df$term, levels = rev(terms))) - 0.42
  hit_df$ymax <- as.numeric(factor(hit_df$term, levels = rev(terms))) + 0.42
  rank_df <- data.frame(x = seq_along(ranks), stat = as.numeric(ranks))
  rank_df$stat_cap <- pmax(pmin(rank_df$stat, stats::quantile(rank_df$stat, num_param(params, 'rank_color_upper_quantile', 0.98), na.rm = TRUE)), stats::quantile(rank_df$stat, num_param(params, 'rank_color_lower_quantile', 0.02), na.rm = TRUE))
  band_df <- rank_df
  band_df$ymin <- -0.55
  band_df$ymax <- -0.18

  p2 <- ggplot() +
    geom_tile(data = band_df, aes(x = x, y = (ymin + ymax) / 2, fill = stat_cap),
              height = diff(range(c(band_df$ymin, band_df$ymax))), width = 1.05, alpha = num_param(params, 'rank_color_band_alpha', 0.96)) +
    scale_fill_gradient2(
      low = get_param(params, 'rank_band_negative_color', '#2D1693'),
      mid = get_param(params, 'rank_band_mid_color', '#F4E1E1'),
      high = get_param(params, 'rank_band_positive_color', '#C90000'),
      midpoint = 0,
      guide = 'none'
    ) +
    scale_color_manual(values = colors, guide = 'none') +
    scale_y_continuous(NULL, breaks = seq_along(rev(terms)), labels = if (as_bool(get_param(params, 'show_hit_term_axis', !single_term), !single_term)) rev(terms) else NULL, expand = c(0.02, 0.02)) +
    coord_cartesian(clip = 'off') +
    labs(x = NULL, y = NULL) +
    theme_classic(base_family = get_param(params, 'font_family', 'sans')) +
    theme(
      axis.text.x = element_blank(),
      axis.ticks.x = element_blank(),
      axis.text.y = element_text(size = num_param(params, 'hit_term_size', 8)),
      panel.border = element_rect(color = get_param(params, 'panel_border_color', '#222222'), fill = NA, linewidth = num_param(params, 'panel_border_width', 0.7)),
      legend.position = 'none',
      plot.margin = margin(5, num_param(params, 'hit_plot_margin_right', 42), 5, 5)
    )
  p2 <- p2 + geom_linerange(data = hit_df, aes(x = x, ymin = ymin, ymax = ymax, color = term),
                            alpha = num_param(params, 'hit_alpha', 0.9),
                            linewidth = num_param(params, 'hit_line_width', 0.42))
  if (single_term && as_bool(get_param(params, 'show_hit_side_label', TRUE), TRUE)) {
    p2 <- p2 + annotate('text',
                        x = Inf, y = max(hit_df$ymax, na.rm = TRUE),
                        label = get_param(params, 'hit_side_label', terms[1]),
                        angle = num_param(params, 'hit_side_label_angle', -90),
                        hjust = num_param(params, 'hit_side_label_hjust', 0.5),
                        vjust = num_param(params, 'hit_side_label_vjust', -0.35),
                        size = num_param(params, 'hit_side_label_size', 3.4),
                        color = get_param(params, 'hit_side_label_color', '#222222'))
  }

  zero_cross <- which.min(abs(rank_df$stat))
  p3 <- ggplot(rank_df, aes(x = x, y = stat)) +
    geom_col(aes(fill = stat >= 0), width = 1, alpha = num_param(params, 'rank_area_alpha', 0.85), show.legend = FALSE) +
    scale_fill_manual(values = c(`TRUE` = get_param(params, 'rank_positive_color', '#4A4A4A'), `FALSE` = get_param(params, 'rank_negative_color', '#4A4A4A'))) +
    geom_hline(yintercept = 0, color = get_param(params, 'zero_line_color', '#555555')) +
    labs(x = get_param(params, 'rank_x_title', 'Rank in Ordered Dataset'), y = get_param(params, 'rank_y_title', 'Ranked List Metric')) +
    theme_classic(base_family = get_param(params, 'font_family', 'sans')) +
    theme(
      panel.border = element_rect(color = get_param(params, 'panel_border_color', '#222222'), fill = NA, linewidth = num_param(params, 'panel_border_width', 0.7)),
      panel.grid.major = if (as_bool(get_param(params, 'rank_show_grid', TRUE), TRUE)) element_line(color = get_param(params, 'grid_color', '#E2E2E2'), linetype = get_param(params, 'grid_line_type', 'dashed')) else element_blank(),
      panel.grid.minor = if (as_bool(get_param(params, 'rank_show_minor_grid', TRUE), TRUE)) element_line(color = get_param(params, 'minor_grid_color', '#EEEEEE'), linetype = get_param(params, 'minor_grid_line_type', 'dashed')) else element_blank()
    )
  if (as_bool(get_param(params, 'show_zero_cross', TRUE), TRUE)) {
    p3 <- p3 +
      geom_vline(xintercept = zero_cross,
                 color = get_param(params, 'zero_cross_line_color', '#111111'),
                 linewidth = num_param(params, 'zero_cross_line_width', 0.45),
                 linetype = get_param(params, 'zero_cross_line_type', 'dashed')) +
      annotate('text', x = zero_cross, y = 0,
               label = paste0(get_param(params, 'zero_cross_label_prefix', 'Zero cross at '), zero_cross),
               vjust = num_param(params, 'zero_cross_label_vjust', 1.35),
               hjust = num_param(params, 'zero_cross_label_hjust', 0.5),
               size = num_param(params, 'zero_cross_label_size', 3.4),
               color = get_param(params, 'zero_cross_label_color', '#111111'))
  }
  if (as_bool(get_param(params, 'show_correlation_labels', TRUE), TRUE)) {
    p3 <- p3 +
      annotate('text', x = -Inf, y = Inf,
               label = get_param(params, 'positive_label', 'Positively correlated'),
               hjust = -0.03, vjust = 1.2,
               size = num_param(params, 'correlation_label_size', 3.5),
               color = get_param(params, 'positive_label_color', '#D7191C')) +
      annotate('text', x = Inf, y = -Inf,
               label = get_param(params, 'negative_label', 'Negatively correlated'),
               hjust = 1.03, vjust = -0.4,
               size = num_param(params, 'correlation_label_size', 3.5),
               color = get_param(params, 'negative_label_color', '#3C298C'))
  }

  p1 <- add_stats_block(p1, selected_meta, terms, params)
  heights <- get_param(params, 'rel_heights', list(1.4, 0.45, 0.95))
  heights <- as.numeric(unlist(heights))
  if (length(heights) != 3) heights <- c(1.4, 0.35, 0.8)
  if (requireNamespace('patchwork', quietly = TRUE)) patchwork::wrap_plots(list(p1, p2, p3), ncol = 1, heights = heights) else p1
}

# Compact per-term panels matching the stacked GSEA reference layout.
make_faceted_running_plot <- function(selected, ranks, pathways, params) {
  if (is.null(ranks) || is.null(pathways)) write_error_and_exit('Faceted running plot requires rank stats and pathways')
  terms <- head(selected$term, num_param(params, 'running_max_terms', 5))
  exponent <- num_param(params, 'exponent', 1)
  score_df <- do.call(rbind, lapply(terms, function(term) {
    if (!term %in% names(pathways)) return(NULL)
    d <- gsea_scores(ranks, pathways[[term]], exponent)
    d$term <- term
    d
  }))
  if (is.null(score_df) || !nrow(score_df)) write_error_and_exit('No running-score data available')
  score_df$term <- factor(score_df$term, levels = terms)
  colors <- palette_values(length(terms), 'terms')
  names(colors) <- terms
  custom <- as_named_vector(get_param(params, 'term_colors', NULL), NULL)
  if (!is.null(custom)) colors[names(custom)] <- custom[names(custom)]
  p <- ggplot(score_df, aes(x = x, y = runningScore)) +
    geom_hline(yintercept = 0, colour = get_param(params, 'zero_line_color', '#222222'), linewidth = 0.45) +
    geom_line(aes(colour = term), linewidth = num_param(params, 'curve_line_width', 1.1), show.legend = FALSE) +
    geom_linerange(data = score_df[score_df$is_hit, , drop = FALSE], aes(x = x, ymin = 0, ymax = runningScore, colour = term), linewidth = num_param(params, 'hit_line_width', 0.65), alpha = 0.9, show.legend = FALSE) +
    facet_grid(term ~ ., scales = 'free_y', switch = 'y') +
    scale_colour_manual(values = colors) +
    labs(x = get_param(params, 'xlab', 'Rank in Ordered Dataset'), y = get_param(params, 'ylab', 'Running Enrichment Score'), title = get_param(params, 'title', 'GSEA running enrichment')) +
    theme_classic(base_family = get_param(params, 'font_family', 'sans')) +
    theme(
      strip.placement = 'outside', strip.background = element_rect(fill = get_param(params, 'facet_strip_fill', '#F2F2F2'), colour = '#222222'),
      strip.text.y.left = element_text(angle = 0, hjust = 0, size = num_param(params, 'facet_label_size', 9)),
      panel.spacing = grid::unit(num_param(params, 'facet_gap', 0.08), 'lines'),
      panel.border = element_rect(fill = NA, colour = get_param(params, 'panel_border_color', '#222222'), linewidth = 0.55),
      plot.title = element_text(size = num_param(params, 'title_size', 16), hjust = num_param(params, 'title_hjust', 0.5)),
      panel.grid.major = element_line(colour = get_param(params, 'grid_color', '#E5E5E5'), linetype = get_param(params, 'grid_line_type', 'dashed')),
      panel.grid.minor = element_blank()
    )
  p
}

make_gradient_curve_plot <- function(selected, ranks, pathways, params) {
  if (is.null(params[['selected_genes']]) && !is.null(params[['selected_gene_labels']])) params[['selected_genes']] <- params[['selected_gene_labels']]
  if (is.null(params[['label_size']]) && !is.null(params[['selected_gene_label_size']])) params[['label_size']] <- params[['selected_gene_label_size']]
  if (is.null(params[['label_color']]) && !is.null(params[['selected_gene_label_color']])) params[['label_color']] <- params[['selected_gene_label_color']]
  if (is.null(params[['label_nudge_x']]) && !is.null(params[['selected_gene_label_nudge_x']])) params[['label_nudge_x']] <- params[['selected_gene_label_nudge_x']]
  if (is.null(params[['label_nudge_y']]) && !is.null(params[['selected_gene_label_nudge_y']])) params[['label_nudge_y']] <- params[['selected_gene_label_nudge_y']]
  if (is.null(params[['label_arrow']]) && !is.null(params[['selected_gene_label_arrow']])) params[['label_arrow']] <- params[['selected_gene_label_arrow']]
  if (is.null(params[['label_line_color']]) && !is.null(params[['selected_gene_label_arrow_color']])) params[['label_line_color']] <- params[['selected_gene_label_arrow_color']]
  if (is.null(params[['label_line_width']]) && !is.null(params[['selected_gene_label_arrow_width']])) params[['label_line_width']] <- params[['selected_gene_label_arrow_width']]
  if (is.null(params[['show_peak_label']]) && !is.null(params[['peak_label_show']])) params[['show_peak_label']] <- params[['peak_label_show']]
  if (is.null(ranks) || is.null(pathways)) {
    write_error_and_exit('Gradient curve plot requires rank stats and pathways', '', 'Use compute mode with genesets_file/--genesets.')
  }
  term <- selected$term[1]
  if (!term %in% names(pathways)) write_error_and_exit('Selected term not found in pathways', term, 'Check selected_terms and genesets_file.')
  exponent <- num_param(params, 'exponent', 1)
  score_df <- gsea_scores(ranks, pathways[[term]], exponent)
  if (as_bool(get_param(params, 'curve_start_at_zero', TRUE), TRUE)) {
    score_df <- rbind(
      data.frame(x = 0, runningScore = 0, is_hit = FALSE, gene = '', rank_metric = NA_real_, stringsAsFactors = FALSE),
      score_df
    )
  }
  score_df$rank_score <- suppressWarnings(as.numeric(score_df$rank_metric))
  score_df$rank_score[is.na(score_df$rank_score)] <- 0
  score_df$rank_score_cap <- pmax(
    pmin(score_df$rank_score, stats::quantile(score_df$rank_score, num_param(params, 'gradient_upper_quantile', 0.98), na.rm = TRUE)),
    stats::quantile(score_df$rank_score, num_param(params, 'gradient_lower_quantile', 0.02), na.rm = TRUE)
  )
  segment_df <- score_df[-nrow(score_df), , drop = FALSE]
  segment_df$xend <- score_df$x[-1]
  segment_df$yend <- score_df$runningScore[-1]
  segment_df$segment_score <- score_df$rank_score_cap[-1]

  hit_df <- score_df[score_df$is_hit, , drop = FALSE]
  selected_meta <- selected[match(term, selected$term), , drop = FALSE]
  peak_idx <- which.max(abs(score_df$runningScore))
  peak_df <- score_df[peak_idx, , drop = FALSE]

  fdr_value <- selected_meta$FDR[1]
  p_value <- selected_meta$pvalue[1]
  p_label <- if (!is.na(p_value)) paste0('P-value=', format_p_value(p_value, num_param(params, 'pvalue_digits', 3))) else 'P-value=NA'
  fdr_label <- if (!is.na(fdr_value)) paste0('FDR=', format_p_value(fdr_value, num_param(params, 'pvalue_digits', 3))) else 'FDR=NA'
  subtitle_text <- get_param(params, 'subtitle', paste0(
    get_param(params, 'gradient_subtitle_prefix', 'Enrichment '),
    '(NES=', round(selected_meta$NES[1], num_param(params, 'nes_digits', 3)), ', ',
    p_label, ', ', fdr_label, ')\n',
    'peak(rnk=', peak_df$x, '), Leading targets(n=', nrow(hit_df), ', out of ', length(pathways[[term]]), ')'
  ))

  label_genes <- as_string_vector(get_param_any(params, c('selected_genes', 'features_label', 'label_genes'), NULL))
  top_x <- num_param(params, 'label_top_x_genes', 0)
  label_df <- hit_df[hit_df$gene %in% label_genes, , drop = FALSE]
  if (top_x > 0) {
    top_df <- hit_df[order(-abs(hit_df$runningScore)), , drop = FALSE]
    label_df <- unique(rbind(label_df, head(top_df, top_x)))
  }
  if (as_bool(get_param(params, 'label_all_hits', FALSE), FALSE)) label_df <- hit_df

  axis_arrow <- as_bool(get_param(params, 'axis_arrow', TRUE), TRUE)
  axis_line <- if (axis_arrow) {
    element_line(
      arrow = grid::arrow(length = grid::unit(num_param(params, 'axis_arrow_length_mm', 4), 'mm'), type = 'open'),
      color = get_param(params, 'axis_line_color', '#111111'),
      linewidth = num_param(params, 'axis_line_width', 0.75)
    )
  } else {
    element_line(color = get_param(params, 'axis_line_color', '#111111'), linewidth = num_param(params, 'axis_line_width', 0.75))
  }

  p <- ggplot() +
    geom_hline(yintercept = 0, color = get_param(params, 'zero_line_color', '#BDBDBD'), linewidth = num_param(params, 'zero_line_width', 0.65)) +
    geom_linerange(
      data = hit_df,
      aes(x = x, ymin = 0, ymax = runningScore, color = rank_score_cap),
      linewidth = num_param(params, 'gradient_hit_line_width', 0.45),
      alpha = num_param(params, 'gradient_hit_alpha', 0.85)
    ) +
    geom_segment(
      data = segment_df,
      aes(x = x, y = runningScore, xend = xend, yend = yend, color = segment_score),
      linewidth = num_param(params, 'gradient_curve_line_width', 1.2),
      lineend = get_param(params, 'gradient_curve_lineend', 'round'),
      alpha = num_param(params, 'gradient_curve_alpha', 0.95)
    ) +
    geom_point(
      data = hit_df,
      aes(x = x, y = runningScore, color = rank_score_cap),
      size = num_param(params, 'gradient_hit_point_size', 1.1),
      alpha = num_param(params, 'gradient_hit_point_alpha', 0.85),
      show.legend = FALSE
    ) +
    scale_color_gradientn(
      colors = as_string_vector(get_param(params, 'gradient_colors', c('#7B00FF', '#55D6FF', '#70FF62', '#D3C800', '#FF0000'))),
      name = get_param(params, 'gradient_legend_title', 'Rank Score'),
      limits = if (as_bool(get_param(params, 'gradient_use_fixed_limits', FALSE), FALSE)) c(num_param(params, 'gradient_min', -1), num_param(params, 'gradient_max', 1)) else NULL,
      guide = guide_colorbar(
        title.position = get_param(params, 'gradient_legend_title_position', 'top'),
        barheight = grid::unit(num_param(params, 'gradient_legend_bar_height_cm', 2.0), 'cm'),
        barwidth = grid::unit(num_param(params, 'gradient_legend_bar_width_cm', 0.35), 'cm')
      )
    ) +
    labs(
      title = if (as_bool(get_param(params, 'title_show', TRUE), TRUE)) get_param(params, 'title', term) else NULL,
      subtitle = if (as_bool(get_param(params, 'subtitle_show', TRUE), TRUE)) subtitle_text else NULL,
      x = get_param(params, 'gradient_x_title', 'Target ranks at the leading edge'),
      y = get_param(params, 'gradient_y_title', 'Running enrichment score')
    ) +
    theme_classic(base_family = get_param(params, 'font_family', 'sans')) +
    theme(
      plot.title = element_text(size = num_param(params, 'title_size', 17), face = get_param(params, 'title_fontface', 'plain'), hjust = num_param(params, 'title_hjust', 0.5)),
      plot.subtitle = element_text(size = num_param(params, 'subtitle_size', 11), hjust = num_param(params, 'subtitle_hjust', 0.5), lineheight = num_param(params, 'subtitle_lineheight', 0.95)),
      axis.title = element_text(size = num_param(params, 'axis_title_size', 13), color = get_param(params, 'axis_title_color', '#111111')),
      axis.text = element_text(size = num_param(params, 'axis_text_size', 10), color = get_param(params, 'axis_text_color', '#555555')),
      axis.line = axis_line,
      panel.grid.major = if (as_bool(get_param(params, 'gradient_show_grid', FALSE), FALSE)) element_line(color = get_param(params, 'grid_color', '#E5E5E5')) else element_blank(),
      panel.grid.minor = element_blank(),
      panel.border = if (as_bool(get_param(params, 'gradient_panel_border', FALSE), FALSE)) element_rect(fill = NA, color = get_param(params, 'panel_border_color', '#222222'), linewidth = num_param(params, 'panel_border_width', 0.7)) else element_blank(),
      legend.position = get_param(params, 'legend_position', 'right'),
      legend.title = element_text(size = num_param(params, 'legend_title_size', 12), face = get_param(params, 'legend_title_fontface', 'italic')),
      legend.text = element_text(size = num_param(params, 'legend_text_size', 10)),
      plot.margin = margin(
        num_param(params, 'plot_margin_top', 10),
        num_param(params, 'plot_margin_right', 18),
        num_param(params, 'plot_margin_bottom', 10),
        num_param(params, 'plot_margin_left', 10)
      )
    ) +
    coord_cartesian(clip = 'off')

  if (as_bool(get_param(params, 'show_gradient_curve_points', FALSE), FALSE)) {
    p <- p +
      geom_point(
        data = score_df,
        aes(x = x, y = runningScore, color = rank_score_cap),
        size = num_param(params, 'gradient_curve_point_size', 0.9),
        alpha = num_param(params, 'gradient_curve_point_alpha', 0.9),
        show.legend = FALSE
      )
  }

  if (as_bool(get_param(params, 'show_peak_marker', TRUE), TRUE)) {
    p <- p +
      geom_point(
        data = peak_df,
        aes(x = x, y = runningScore),
        shape = num_param(params, 'peak_marker_shape', 21),
        fill = get_param(params, 'peak_marker_fill', '#FF0000'),
        color = get_param(params, 'peak_marker_border_color', '#FF0000'),
        size = num_param(params, 'peak_marker_size', 2.3),
        stroke = num_param(params, 'peak_marker_stroke', 0.4),
        inherit.aes = FALSE
      )
  }

  if (as_bool(get_param(params, 'show_peak_label', FALSE), FALSE)) {
    p <- p +
      annotate(
        'text',
        x = peak_df$x,
        y = peak_df$runningScore,
        label = get_param(params, 'peak_label', paste0('peak rnk=', peak_df$x)),
        hjust = num_param(params, 'peak_label_hjust', -0.1),
        vjust = num_param(params, 'peak_label_vjust', -0.6),
        size = num_param(params, 'peak_label_size', 3.2),
        color = get_param(params, 'peak_label_color', '#111111'),
        fontface = get_param(params, 'peak_label_fontface', 'plain')
      )
  }

  if (nrow(label_df) > 0 && as_bool(get_param(params, 'label_show', TRUE), TRUE)) {
    p <- p +
      ggrepel::geom_text_repel(
        data = label_df,
        aes(x = x, y = runningScore, label = gene),
        inherit.aes = FALSE,
        size = num_param(params, 'label_size', 3.2),
        color = get_param(params, 'label_color', '#111111'),
        fontface = get_param(params, 'label_fontface', 'italic'),
        segment.color = get_param(params, 'label_line_color', '#BDBDBD'),
        segment.size = num_param(params, 'label_line_width', 0.35),
        segment.alpha = num_param(params, 'label_line_alpha', 0.9),
        arrow = if (as_bool(get_param(params, 'label_arrow', TRUE), TRUE)) grid::arrow(length = grid::unit(num_param(params, 'label_arrow_length_mm', 2.2), 'mm'), type = 'closed') else NULL,
        box.padding = num_param(params, 'label_box_padding', 0.28),
        point.padding = num_param(params, 'label_point_padding', 0.15),
        force = num_param(params, 'label_force', 1.8),
        max.overlaps = num_param(params, 'label_max_overlaps', 100),
        min.segment.length = 0,
        show.legend = FALSE
      )
  }

  p
}

# Modern single-panel renderer.  This definition intentionally follows the
# legacy renderer above so old parameter files continue to work while the
# frontend can use the stable gradient_curve parameter group.
make_gradient_curve_plot <- function(selected, ranks, pathways, params) {
  if (is.null(params[['selected_genes']]) && !is.null(params[['selected_gene_labels']])) params[['selected_genes']] <- params[['selected_gene_labels']]
  if (is.null(params[['label_size']]) && !is.null(params[['selected_gene_label_size']])) params[['label_size']] <- params[['selected_gene_label_size']]
  if (is.null(params[['label_color']]) && !is.null(params[['selected_gene_label_color']])) params[['label_color']] <- params[['selected_gene_label_color']]
  if (is.null(params[['label_nudge_x']]) && !is.null(params[['selected_gene_label_nudge_x']])) params[['label_nudge_x']] <- params[['selected_gene_label_nudge_x']]
  if (is.null(params[['label_nudge_y']]) && !is.null(params[['selected_gene_label_nudge_y']])) params[['label_nudge_y']] <- params[['selected_gene_label_nudge_y']]
  if (is.null(params[['label_arrow']]) && !is.null(params[['selected_gene_label_arrow']])) params[['label_arrow']] <- params[['selected_gene_label_arrow']]
  if (is.null(params[['label_line_color']]) && !is.null(params[['selected_gene_label_arrow_color']])) params[['label_line_color']] <- params[['selected_gene_label_arrow_color']]
  if (is.null(params[['label_line_width']]) && !is.null(params[['selected_gene_label_arrow_width']])) params[['label_line_width']] <- params[['selected_gene_label_arrow_width']]
  if (is.null(params[['show_peak_label']]) && !is.null(params[['peak_label_show']])) params[['show_peak_label']] <- params[['peak_label_show']]
  if (is.null(ranks) || is.null(pathways)) {
    write_error_and_exit('Gradient curve plot requires rank stats and pathways', '', 'Use compute mode with genesets_file/--genesets.')
  }
  terms <- as_string_vector(get_param(params, 'selected_terms', selected$term))
  terms <- intersect(terms, names(pathways))
  if (length(terms) == 0) terms <- intersect(selected$term, names(pathways))
  terms <- head(terms, num_param(params, 'running_max_terms', num_param(params, 'top_n_terms', 6)))
  if (length(terms) == 0) write_error_and_exit('Selected terms are absent from the gene-set file', '', 'Check selected_terms and genesets_file.')
  exponent <- num_param(params, 'exponent', 1)
  score_df <- do.call(rbind, lapply(terms, function(term) {
    d <- gsea_scores(ranks, pathways[[term]], exponent)
    d$term <- term
    d
  }))
  score_df$term <- factor(score_df$term, levels = terms)
  score_df$rank_score <- score_df$rank_metric
  score_df$rank_score[is.na(score_df$rank_score)] <- 0
  score_df$term_color <- as.character(score_df$term)
  custom <- as_named_vector(get_param_any(params, c('term_colors', 'pathway_colors', 'curve_colors'), NULL), NULL)
  palette <- c('#2F6DB0', '#D84A3A', '#3A9D5D', '#8A58A8', '#E38D26', '#159A9C', '#C04D87', '#667085')
  colors <- setNames(rep(palette, length.out = length(terms)), terms)
  if (!is.null(custom)) colors[names(custom)[names(custom) %in% terms]] <- as.character(custom[names(custom)[names(custom) %in% terms]])
  if (length(terms) == 1 && !is.null(get_param(params, 'curve_color', NULL))) colors[terms] <- get_param(params, 'curve_color', colors[terms])

  segment_df <- do.call(rbind, lapply(split(score_df, score_df$term), function(d) {
    d <- d[order(d$x), , drop = FALSE]
    if (nrow(d) < 2) return(NULL)
    out <- d[-nrow(d), , drop = FALSE]
    out$xend <- d$x[-1]; out$yend <- d$runningScore[-1]
    out
  }))
  hit_df <- score_df[score_df$is_hit, , drop = FALSE]
  if (!as_bool(get_param(params, 'rug_show', TRUE), TRUE)) hit_df <- hit_df[0, , drop = FALSE]
  selected_meta <- selected[match(terms, selected$term), , drop = FALSE]
  peak_df <- do.call(rbind, lapply(split(score_df, score_df$term), function(d) d[which.max(abs(d$runningScore)), , drop = FALSE]))
  peak_df$term <- factor(as.character(peak_df$term), levels = terms)
  label_genes <- as_string_vector(get_param(params, 'selected_genes', NULL))
  label_df <- hit_df[hit_df$gene %in% label_genes, , drop = FALSE]
  if (num_param(params, 'label_top_x_genes', 0) > 0) {
    top_hits <- do.call(rbind, lapply(split(hit_df, hit_df$term), function(d) head(d[order(-abs(d$runningScore)), , drop = FALSE], num_param(params, 'label_top_x_genes', 0))))
    label_df <- unique(rbind(label_df, top_hits))
  }
  if (as_bool(get_param(params, 'label_all_hits', FALSE), FALSE)) label_df <- hit_df

  style <- tolower(as.character(get_param_any(params, c('curve_style', 'running_style'), 'multi_term'))[1])
  gradient_mode <- style %in% c('gradient', 'rank_gradient') && length(terms) == 1
  if (gradient_mode) {
    lo <- stats::quantile(score_df$rank_score, num_param(params, 'gradient_lower_quantile', .02), na.rm = TRUE)
    hi <- stats::quantile(score_df$rank_score, num_param(params, 'gradient_upper_quantile', .98), na.rm = TRUE)
    score_df$rank_score <- pmax(pmin(score_df$rank_score, hi), lo)
    segment_df$segment_score <- score_df$rank_score[match(segment_df$xend, score_df$x)]
    hit_df$segment_score <- score_df$rank_score[match(hit_df$x, score_df$x)]
  }
  y_min <- min(score_df$runningScore, na.rm = TRUE); y_max <- max(score_df$runningScore, na.rm = TRUE)
  span <- max(y_max - y_min, .1)
  rug_y <- num_param(params, 'rug_y', y_min - .10 * span)
  rug_height <- num_param(params, 'rug_height', .08 * span)
  curve_width <- num_param(params, 'curve_line_width', 1.15)
  p <- ggplot() +
    geom_hline(yintercept = 0, color = get_param_any(params, c('zero_line_color', 'zero_cross_color'), '#BDBDBD'), linewidth = num_param(params, 'zero_line_width', num_param(params, 'zero_cross_width', .45)), linetype = get_param_any(params, c('zero_line_linetype', 'zero_cross_linetype'), 'dashed'))
  if (gradient_mode) {
    p <- p + geom_segment(data = segment_df, aes(x = x, y = runningScore, xend = xend, yend = yend, color = segment_score), linewidth = curve_width, alpha = num_param(params, 'curve_alpha', .95), lineend = get_param(params, 'curve_lineend', 'round')) +
      geom_linerange(data = hit_df, aes(x = x, ymin = rug_y, ymax = rug_y + rug_height, color = segment_score), linewidth = num_param(params, 'rug_width', .8), alpha = num_param(params, 'rug_alpha', .9)) +
      scale_color_gradientn(colors = as_string_vector(get_param(params, 'gradient_colors', c('#3B4CC0', '#FDE725', '#B40426'))), name = get_param(params, 'gradient_legend_title', 'Rank score'))
  } else {
    p <- p + geom_segment(data = segment_df, aes(x = x, y = runningScore, xend = xend, yend = yend, color = term), linewidth = curve_width, alpha = num_param(params, 'curve_alpha', .95), linetype = get_param(params, 'curve_linetype', 'solid'), lineend = get_param(params, 'curve_lineend', 'round')) +
      geom_linerange(data = hit_df, aes(x = x, ymin = rug_y, ymax = rug_y + rug_height, color = term), linewidth = num_param(params, 'rug_width', .8), alpha = num_param(params, 'rug_alpha', .9)) +
      scale_color_manual(values = colors, breaks = get_param(params, 'legend_order', terms), name = get_param(params, 'legend_title', get_param(params, 'gradient_legend_title', 'Pathway')))
  }
  p <- p +
    labs(title = if (as_bool(get_param(params, 'title_show', TRUE), TRUE)) get_param(params, 'title', ifelse(length(terms) == 1, terms[1], 'GSEA running enrichment')) else NULL,
         subtitle = if (as_bool(get_param(params, 'subtitle_show', TRUE), TRUE)) get_param(params, 'subtitle', NULL) else NULL,
         caption = if (as_bool(get_param(params, 'caption_show', FALSE), FALSE)) get_param(params, 'caption', NULL) else NULL,
         x = if (as_bool(get_param(params, 'x_title_show', TRUE), TRUE)) get_param_any(params, c('xlab', 'x_title', 'gradient_x_title'), 'Rank in Ordered Dataset') else NULL,
         y = if (as_bool(get_param(params, 'y_title_show', TRUE), TRUE)) get_param_any(params, c('ylab', 'y_title', 'gradient_y_title'), 'Enrichment Score') else NULL) +
    coord_cartesian(clip = 'off') +
    scale_x_continuous(limits = get_param(params, 'x_limits', NULL), breaks = get_param(params, 'x_breaks', waiver()), labels = get_param(params, 'x_labels', waiver()), expand = expansion(mult = c(.01, .03))) +
    scale_y_continuous(limits = get_param(params, 'y_limits', c(rug_y - rug_height * .4, y_max + .08 * span)), breaks = get_param(params, 'y_breaks', waiver()), labels = get_param(params, 'y_labels', waiver()), expand = expansion(mult = c(0, .04))) +
    theme_classic(base_family = get_param(params, 'font_family', 'sans'), base_size = num_param(params, 'base_size', num_param(params, 'font_size', 11))) +
    theme(plot.background = element_rect(fill = get_param(params, 'plot_background', get_param(params, 'background_color', 'white')), color = NA), panel.background = element_rect(fill = get_param(params, 'panel_background', 'white'), color = NA),
          plot.title = element_text(size = num_param(params, 'title_size', 16), color = get_param(params, 'title_color', '#222222'), face = get_param(params, 'title_face', 'plain'), hjust = num_param(params, 'title_hjust', .5)),
          plot.subtitle = element_text(size = num_param(params, 'subtitle_size', 11), color = get_param(params, 'subtitle_color', '#555555'), hjust = num_param(params, 'subtitle_hjust', .5)),
          plot.caption = element_text(size = num_param(params, 'caption_size', 9), color = get_param(params, 'caption_color', '#555555'), hjust = num_param(params, 'caption_hjust', 0)),
          axis.title = element_text(size = num_param(params, 'x_axis_title_size', 12), color = get_param(params, 'font_color', '#222222')), axis.text = element_text(size = num_param(params, 'x_axis_text_size', 10), color = get_param(params, 'x_axis_text_color', '#555555')), axis.text.x = element_text(angle = num_param(params, 'x_axis_text_angle', 0)),
          axis.line = if (as_bool(get_param(params, 'axis_line_show', TRUE), TRUE)) element_line(color = get_param(params, 'axis_line_color', '#222222'), linewidth = num_param(params, 'axis_line_width', .55)) else element_blank(),
          axis.ticks = if (as_bool(get_param(params, 'axis_ticks_show', TRUE), TRUE)) element_line(color = get_param(params, 'axis_ticks_color', '#222222'), linewidth = num_param(params, 'axis_ticks_width', .4)) else element_blank(),
          panel.grid.major = if (as_bool(get_param(params, 'grid_show', get_param(params, 'gradient_show_grid', TRUE)), TRUE)) element_line(color = get_param(params, 'grid_major_color', '#D9D9D9'), linetype = get_param(params, 'grid_linetype', 'dotted'), linewidth = num_param(params, 'grid_width', .35)) else element_blank(), panel.grid.minor = element_blank(),
          panel.border = if (as_bool(get_param(params, 'panel_border_show', FALSE), FALSE)) element_rect(fill = NA, color = get_param(params, 'panel_border_color', '#222222'), linewidth = num_param(params, 'panel_border_width', .6)) else element_blank(),
          legend.position = if (as_bool(get_param(params, 'legend_show', length(terms) > 1), length(terms) > 1)) get_param(params, 'legend_position', 'right') else 'none', legend.direction = get_param(params, 'legend_direction', 'vertical'), legend.title = element_text(size = num_param(params, 'legend_title_size', 10)), legend.text = element_text(size = num_param(params, 'legend_text_size', 9)), legend.key.size = grid::unit(num_param(params, 'legend_key_size', 0.8), 'lines'), plot.margin = margin(num_param(params, 'plot_margin_top', 10), num_param(params, 'plot_margin_right', 15), num_param(params, 'plot_margin_bottom', 10), num_param(params, 'plot_margin_left', 10)))
  if (nrow(peak_df) > 0 && as_bool(get_param(params, 'show_peak_marker', TRUE), TRUE)) {
    if (gradient_mode) p <- p + geom_point(data = peak_df, aes(x = x, y = runningScore), color = get_param(params, 'peak_marker_border_color', '#222222'), shape = num_param(params, 'peak_marker_shape', 21), fill = get_param(params, 'peak_marker_fill', 'white'), size = num_param(params, 'peak_marker_size', 2.5), stroke = num_param(params, 'peak_marker_border_width', .5), inherit.aes = FALSE, show.legend = FALSE)
    else p <- p + geom_point(data = peak_df, aes(x = x, y = runningScore, color = term), shape = num_param(params, 'peak_marker_shape', 21), fill = get_param(params, 'peak_marker_fill', 'white'), size = num_param(params, 'peak_marker_size', 2.5), stroke = num_param(params, 'peak_marker_border_width', .5), show.legend = FALSE)
  }
  if (as_bool(get_param(params, 'label_show', TRUE), TRUE) && nrow(label_df) > 0) p <- p + ggrepel::geom_text_repel(data = label_df, aes(x = x, y = runningScore, label = gene), inherit.aes = FALSE, size = num_param(params, 'label_size', 3), color = get_param(params, 'label_color', '#222222'), fontface = get_param(params, 'label_fontface', 'plain'), nudge_x = num_param(params, 'label_nudge_x', 0), nudge_y = num_param(params, 'label_nudge_y', 0), segment.color = get_param(params, 'label_arrow_color', get_param(params, 'label_line_color', '#777777')), segment.size = num_param(params, 'label_arrow_width', num_param(params, 'label_line_width', .35)), max.overlaps = num_param(params, 'label_max_overlaps', 100), min.segment.length = 0, arrow = if (as_bool(get_param(params, 'label_arrow', FALSE), FALSE)) grid::arrow(length = grid::unit(2, 'mm')) else NULL, show.legend = FALSE)
  add_stats_block(p, selected_meta, terms, params)
}

make_composite_plot <- function(selected, ranks, pathways, params) {
  layout <- tolower(as.character(get_param(params, 'composite_layout', '2x2'))[1])
  available <- !is.null(ranks) && !is.null(pathways)
  classic <- params; classic$running_style <- 'classic'; classic$upper_curve_style <- 'normal'; classic$selected_terms <- head(selected$term, 1)
  gradient <- params; gradient$curve_style <- 'gradient'; gradient$running_style <- 'gradient'; gradient$selected_terms <- head(selected$term, 1)
  multi <- params; multi$curve_style <- 'multi_term'; multi$running_style <- 'multi_term'
  panels <- list(if (available) make_running_plot(selected, ranks, pathways, classic) else panel_placeholder('Running curve', 'Ranks/pathways unavailable'), if (available) make_gradient_curve_plot(selected, ranks, pathways, gradient) else panel_placeholder('Gradient curve', 'Ranks/pathways unavailable'), if (available) make_gradient_curve_plot(selected, ranks, pathways, multi) else panel_placeholder('Multi-term running', 'Ranks/pathways unavailable'), make_dot_summary_plot(selected, params))
  labels <- as_string_vector(get_param(params, 'composite_panel_labels', c('A', 'B', 'C', 'D')))
  titles <- as_string_vector(get_param(params, 'composite_panel_titles', c('Classic running', 'Rank-gradient running', 'Multi-term running', 'Enrichment summary')))
  panels <- Map(function(p, label, title) p + labs(title = paste(label, title, sep = '  ')), panels, rep(labels, length.out = 4), rep(titles, length.out = 4))
  if (!requireNamespace('patchwork', quietly = TRUE)) return(panels[[1]])
  guides <- if (as_bool(get_param(params, 'composite_shared_legend', TRUE), TRUE)) 'collect' else 'keep'
  if (layout %in% c('vertical', 'v')) patchwork::wrap_plots(panels, ncol = 1, guides = guides) else if (layout %in% c('horizontal', 'h')) patchwork::wrap_plots(panels, nrow = 1, guides = guides) else patchwork::wrap_plots(panels, ncol = 2, guides = guides)
}

write_result_html <- function(plot, output_dir, figure) {
  html_file <- file.path(output_dir, 'result.html')
  interactive <- FALSE
  if (requireNamespace('plotly', quietly = TRUE) && requireNamespace('htmlwidgets', quietly = TRUE) && inherits(plot, 'ggplot')) interactive <- isTRUE(tryCatch({ htmlwidgets::saveWidget(plotly::ggplotly(plot), html_file, selfcontained = TRUE); TRUE }, error = function(e) FALSE))
  if (!interactive) writeLines(c('<!doctype html><meta charset="utf-8"><title>FGSEA enrichment plot</title>', '<h1>FGSEA enrichment plot</h1>', '<p>Interactive Plotly output is unavailable; see the static exports.</p>', '<p><a href="result.png">PNG</a> | <a href="result.svg">SVG</a> | <a href="result.pdf">PDF</a></p>', paste0('<pre>', jsonlite::toJSON(figure, auto_unbox = TRUE, pretty = TRUE), '</pre>')), html_file)
  interactive
}

save_plot <- function(plot, output_dir, width, height, dpi) {
  svglite::svglite(file.path(output_dir, 'result.svg'), width = width, height = height)
  print(plot)
  dev.off()
  grDevices::cairo_pdf(file.path(output_dir, 'result.pdf'), width = width, height = height)
  print(plot)
  dev.off()
  (if (requireNamespace('ragg', quietly = TRUE)) ragg::agg_png else function(...) grDevices::png(..., type = 'cairo'))(file.path(output_dir, 'result.png'), width = width, height = height, units = 'in', res = dpi)
  print(plot)
  dev.off()
}

save_panel_png <- function(plot, path, width, height, dpi) {
  (if (requireNamespace('ragg', quietly = TRUE)) ragg::agg_png else function(...) grDevices::png(..., type = 'cairo'))(path, width = width, height = height, units = 'in', res = dpi)
  print(plot)
  dev.off()
}

main <- function() {
  if (is.null(output_dir)) write_error_and_exit('Missing --output argument')
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  old_outputs <- file.path(output_dir, c('error.json', 'result.svg', 'result.pdf', 'result.png', 'result.html', 'figure.json', 'enrichment_results.csv', 'selected_terms.csv', 'selected_genes.csv', 'run.log'))
  old_outputs <- old_outputs[file.exists(old_outputs)]
  if (length(old_outputs) > 0) unlink(old_outputs)
  write_log('Starting FGSEA enrichment plot plugin.')

  params <- list()
  if (!is.null(params_file) && file.exists(params_file)) {
    params <- jsonlite::fromJSON(params_file, simplifyVector = FALSE)
  }
  df <- read_table_auto(input_file)
  plot_type <- tolower(as.character(get_param(params, 'plot_type', 'auto'))[1])
  if (is_multi_group_plot(params) || plot_type %in% c('multi_group', 'multigroup', 'grouped_gsea', 'multi_condition', 'group_running')) {
    gs_file <- genesets_file
    if (is.null(gs_file)) gs_file <- get_param(params, 'genesets_file', NULL)
    pathways <- read_genesets(gs_file)
    ranks_list <- split_ranks_by_group(df, params)
    plot <- make_multi_group_plot(ranks_list, pathways, params)
    width <- num_param(params, 'width', 8.2)
    height <- num_param(params, 'height', 6.4)
    dpi <- num_param(params, 'dpi', 300)
    save_plot(plot, output_dir, width, height, dpi)
    term <- as_string_vector(get_param_any(params, c('selected_terms', 'selected_term', 'pathway', 'term'), names(pathways)[1]))[1]
    enr_rows <- lapply(names(ranks_list), function(g) {
      data.frame(group = g, term = term, n_genes = length(ranks_list[[g]]), stringsAsFactors = FALSE)
    })
    write.csv(do.call(rbind, enr_rows), file.path(output_dir, 'enrichment_results.csv'), row.names = FALSE)
    write.csv(data.frame(term = term, stringsAsFactors = FALSE), file.path(output_dir, 'selected_terms.csv'), row.names = FALSE)
    write.csv(data.frame(term = character(), gene = character()), file.path(output_dir, 'selected_genes.csv'), row.names = FALSE)
    figure <- list(
      plot_type = 'fgsea_enrichment_plot',
      visual_mode = 'multi_group',
      selected_terms = term,
      groups = names(ranks_list),
      outputs = list(svg = 'result.svg', pdf = 'result.pdf', png = 'result.png', results = 'enrichment_results.csv', html = 'result.html', log = 'run.log')
    )
    writeLines(jsonlite::toJSON(figure, auto_unbox = TRUE, pretty = TRUE), file.path(output_dir, 'figure.json'))
    write_result_html(plot, output_dir, figure)
    write_log('Completed multi-group GSEA running plot.')
    return(invisible(TRUE))
  }
  mode <- detect_mode(df, params)
  fg <- run_fgsea_if_needed(df, params, mode)
  results <- standardize_results(fg$results, params)
  selected <- select_terms(results, params)

  write.csv(results, file.path(output_dir, 'enrichment_results.csv'), row.names = FALSE)
  write.csv(selected, file.path(output_dir, 'selected_terms.csv'), row.names = FALSE)
  selected_genes <- do.call(rbind, lapply(seq_len(nrow(selected)), function(i) {
    genes <- parse_gene_string(selected$leading_genes[i])
    if (length(genes) == 0) return(NULL)
    data.frame(term = selected$term[i], gene = genes, stringsAsFactors = FALSE)
  }))
  if (is.null(selected_genes)) selected_genes <- data.frame(term = character(), gene = character())
  write.csv(selected_genes, file.path(output_dir, 'selected_genes.csv'), row.names = FALSE)

  plot_type <- tolower(as.character(get_param(params, 'plot_type', ifelse(mode == 'compute', 'running', 'summary')))[1])
  if (plot_type %in% c('faceted_running', 'facet_running', 'stacked_running')) {
    plot <- make_faceted_running_plot(selected, fg$ranks, fg$pathways, params)
  } else if (plot_type %in% c('classic_tracks', 'tracked_running')) {
    plot <- make_running_plot(selected, fg$ranks, fg$pathways, params)
  } else if (plot_type %in% c('grouped_curves', 'multi_curve', 'gsea_grouped')) {
    params[['curve_style']] <- 'multi_term'
    plot <- make_gradient_curve_plot(selected, fg$ranks, fg$pathways, params)
  } else if (plot_type == 'composite') {
    plot <- make_composite_plot(selected, fg$ranks, fg$pathways, params)
  } else if (plot_type %in% c('dot_summary', 'summary_dot', 'lollipop_summary')) {
    plot <- make_dot_summary_plot(selected, params)
  } else if (plot_type %in% c('ridge', 'ridges', 'enrichment_ridge', 'gsea_ridge', 'ridgeplot')) {
    plot <- make_enrichment_ridge_plot(selected, fg$ranks, fg$pathways, params)
  } else if (plot_type %in% c('gene_sankey', 'sankey', 'cnet_sankey', 'gene_pathway_sankey', 'alluvial_bubble')) {
    if (is.null(fg$ranks) || is.null(fg$pathways)) {
      gs_file <- genesets_file
      if (is.null(gs_file)) gs_file <- get_param(params, 'genesets_file', NULL)
      if (!is.null(gs_file) && file.exists(gs_file)) fg$pathways <- read_genesets(gs_file)
      if (is.null(fg$ranks)) {
        rank_try <- tryCatch(make_ranks(df, params), error = function(e) NULL)
        fg$ranks <- rank_try
      }
    }
    plot <- make_gene_pathway_sankey_plot(selected, fg$ranks, fg$pathways, params)
  } else if (plot_type %in% c('gradient_curve', 'gradient_only', 'single_gradient', 'leading_edge_curve', 'running_multi_panel')) {
    plot <- make_gradient_curve_plot(selected, fg$ranks, fg$pathways, params)
  } else if (plot_type %in% c('running', 'curve', 'gsea')) {
    running_style <- tolower(as.character(get_param(params, 'running_style', 'classic'))[1])
    if (running_style %in% c('gradient_only', 'single_gradient', 'standalone_gradient')) {
      plot <- make_gradient_curve_plot(selected, fg$ranks, fg$pathways, params)
    } else {
      plot <- make_running_plot(selected, fg$ranks, fg$pathways, params)
    }
  } else {
    plot <- make_summary_plot(selected, params)
  }
  width <- num_param(params, if (plot_type == 'composite') 'composite_width' else 'width', ifelse(plot_type == 'composite', 12, ifelse(plot_type %in% c('ridge', 'ridges', 'enrichment_ridge', 'gsea_ridge', 'ridgeplot'), 8.0, ifelse(plot_type %in% c('running', 'curve', 'gsea'), 8.2, 8.5))))
  height <- num_param(params, if (plot_type == 'composite') 'composite_height' else 'height', ifelse(plot_type == 'composite', 10, ifelse(plot_type %in% c('ridge', 'ridges', 'enrichment_ridge', 'gsea_ridge', 'ridgeplot'), max(5.5, 0.55 * max(1, nrow(selected)) + 1.6), ifelse(plot_type %in% c('running', 'curve', 'gsea'), 7.0, 6.2))))
  dpi <- num_param(params, 'dpi', 300)
  save_plot(plot, output_dir, width, height, dpi)
  if (plot_type == 'composite' && as_bool(get_param(params, 'composite_export_panels', FALSE), FALSE)) {
    if (!is.null(fg$ranks) && !is.null(fg$pathways)) {
      pclassic <- params; pclassic$selected_terms <- head(selected$term, 1); pclassic$running_style <- 'classic'; pclassic$upper_curve_style <- 'normal'
      pgradient <- params; pgradient$selected_terms <- head(selected$term, 1); pgradient$curve_style <- 'gradient'; pgradient$running_style <- 'gradient'
      pmulti <- params; pmulti$curve_style <- 'multi_term'; pmulti$running_style <- 'multi_term'
      panel_plots <- list(make_running_plot(selected, fg$ranks, fg$pathways, pclassic), make_gradient_curve_plot(selected, fg$ranks, fg$pathways, pgradient), make_gradient_curve_plot(selected, fg$ranks, fg$pathways, pmulti))
    } else panel_plots <- list(panel_placeholder('Running panels', 'Ranks/pathways unavailable'))
    panel_plots[[4]] <- make_dot_summary_plot(selected, params)
    for (i in seq_along(panel_plots)) save_panel_png(panel_plots[[i]], file.path(output_dir, paste0('panel_', i, '.png')), width / 2, height / 2, dpi)
  }

  figure <- list(
    plot_type = 'fgsea_enrichment_plot',
    input_file = normalizePath(input_file, mustWork = FALSE),
    input_mode = mode,
    visual_mode = plot_type,
    selected_terms = selected$term,
    term_count = nrow(results),
    selected_term_count = nrow(selected),
    panels = list(rendered = if (plot_type == 'composite') c('classic_running', 'gradient_running', 'multi_term_running', 'dot_summary') else c('primary'), available = list(running_classic = !is.null(fg$ranks) && !is.null(fg$pathways), running_gradient = !is.null(fg$ranks) && !is.null(fg$pathways), running_multi = !is.null(fg$ranks) && !is.null(fg$pathways), dot_summary = TRUE), composite_layout = if (plot_type == 'composite') get_param(params, 'composite_layout', '2x2') else NULL),
    term_colors = get_param_any(params, c('term_colors', 'curve_colors'), NULL),
    stats_fields = as_string_vector(get_param(params, 'stats_columns', c('NES', 'pvalue', 'padj'))),
    dot_summary_mapping = list(x = get_param(params, 'dot_summary_x', 'NES'), size = get_param(params, 'dot_summary_size', 'Count'), color = get_param(params, 'dot_summary_color', 'p.adjust'), split = get_param(params, 'dot_summary_split', 'none')),
    style = list(
      title = get_param(params, 'title', ifelse(plot_type == 'summary', 'FGSEA enrichment summary', 'GSEA running enrichment')),
      color_mode = get_param(params, 'color_mode', 'direction'),
      upper_curve_style = get_param_any(params, c('upper_curve_style', 'running_upper_style', 'running_style'), 'normal'),
      label_top_x_genes = num_param(params, 'label_top_x_genes', 0),
      label_top_n_terms = num_param(params, 'label_top_n_terms', 8)
    ),
    outputs = list(
      svg = 'result.svg',
      pdf = 'result.pdf',
      png = 'result.png',
      results = 'enrichment_results.csv',
      selected_terms = 'selected_terms.csv',
      selected_genes = 'selected_genes.csv',
      html = 'result.html',
      log = 'run.log'
    )
  )
  writeLines(jsonlite::toJSON(figure, auto_unbox = TRUE, pretty = TRUE), file.path(output_dir, 'figure.json'))
  write_result_html(plot, output_dir, figure)
  write_log('Completed FGSEA enrichment plot plugin.')
}

tryCatch(main(), error = function(e) {
  write_error_and_exit('FGSEA enrichment plot failed', conditionMessage(e), 'Check input columns, gene-set file, selected terms, and params.json.')
})
