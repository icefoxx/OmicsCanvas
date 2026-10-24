#!/usr/bin/env Rscript

# GSEA pathway ridge of gene-level log2FC with a left-side NES bubble.
# Runtime matches other GSEA plugins:
#   Rscript plot.R --input ranks.csv --enrichment gsea.csv --params params.json --output out [--genesets pathways.gmt]
#   --input       ranked gene / log2FC table
#   --enrichment  precomputed GSEA result table
#   --genesets    optional GMT or term-gene table

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
  library(scales)
})

option_list <- list(
  make_option(c('--input'), type = 'character', default = NULL,
              help = 'Rank/marker table (gene + log2FC or ranking statistic).'),
  make_option(c('--enrichment'), type = 'character', default = NULL,
              help = 'Precomputed GSEA/FGSEA result table (pathway, NES, p-value).'),
  make_option(c('--genesets'), type = 'character', default = NULL,
              help = 'Optional GMT or term-gene membership file.'),
  make_option(c('--input2'), type = 'character', default = NULL,
              help = 'Compatibility alias for the second table; treated as --enrichment.'),
  make_option(c('--params'), type = 'character', default = NULL, help = 'params.json'),
  make_option(c('--output'), type = 'character', default = NULL, help = 'Output directory')
)
opt <- parse_args(OptionParser(option_list = option_list))
input_file <- opt$input
enrichment_file <- opt$enrichment
genesets_file <- opt$genesets
params_file <- opt$params
output_dir <- opt$output

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

write_log <- function(message) {
  if (is.null(output_dir) || !nzchar(output_dir)) return(invisible())
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  cat(sprintf('[%s] %s\n', format(Sys.time(), '%Y-%m-%d %H:%M:%S'), message),
      file = file.path(output_dir, 'run.log'), append = TRUE)
}

fail <- function(error, detail = '', suggestion = '') {
  if (is.null(output_dir) || !nzchar(output_dir)) output_dir <<- getwd()
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  writeLines(
    toJSON(list(error = error, detail = detail, suggestion = suggestion), auto_unbox = TRUE, pretty = TRUE),
    file.path(output_dir, 'error.json')
  )
  write_log(paste(error, detail))
  quit(status = 1)
}

read_table_auto <- function(path) {
  if (is.null(path) || !file.exists(path)) fail('Input file not found', as.character(path), 'Upload a CSV/TSV/TXT table.')
  ext <- tolower(tools::file_ext(path))
  if (ext %in% c('tsv', 'txt', 'gmt')) {
    return(read.delim(path, check.names = FALSE, stringsAsFactors = FALSE, quote = ''))
  }
  read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}

get_param <- function(params, name, default = NULL) {
  if (!is.null(params[[name]]) && length(params[[name]])) params[[name]] else default
}

get_param_any <- function(params, names, default = NULL) {
  for (name in names) {
    val <- get_param(params, name, NULL)
    if (!is.null(val) && length(val) && !(is.character(val) && !nzchar(as.character(val)[1]))) return(val)
  }
  default
}

as_bool <- function(x, default = FALSE) {
  if (is.null(x) || length(x) == 0) return(default)
  if (is.logical(x)) return(isTRUE(x[1]))
  tolower(as.character(x[1])) %in% c('true', 't', 'yes', 'y', '1', 'on')
}

num_param <- function(params, name, default) {
  y <- suppressWarnings(as.numeric(unlist(get_param(params, name, default)))[1])
  if (is.finite(y)) y else default
}

norm_name <- function(x) gsub('[^a-z0-9]+', '', tolower(as.character(x)))

guess_column <- function(df, candidates, required = TRUE, label = 'column') {
  nms <- names(df)
  nn <- norm_name(nms)
  cand <- unique(unlist(candidates, use.names = FALSE))
  for (c in cand) {
    hit <- which(nn == norm_name(c))
    if (length(hit)) return(nms[hit[1]])
  }
  for (c in cand) {
    hit <- which(grepl(norm_name(c), nn, fixed = TRUE))
    if (length(hit)) return(nms[hit[1]])
  }
  if (required) fail(paste(label, 'not found'), paste(nms, collapse = ', '), paste('Expected one of:', paste(cand, collapse = ', ')))
  NULL
}

parse_gene_string <- function(x) {
  if (is.null(x) || length(x) == 0 || is.na(x[1])) return(character())
  parts <- unlist(strsplit(as.character(x[1]), '[,;/| ]+'))
  unique(parts[nzchar(parts)])
}

read_gmt <- function(path) {
  lines <- readLines(path, warn = FALSE)
  out <- list()
  for (ln in lines) {
    if (!nzchar(trimws(ln)) || startsWith(ln, '#')) next
    bits <- strsplit(ln, '\t', fixed = TRUE)[[1]]
    if (length(bits) < 3) next
    genes <- bits[seq.int(3, length(bits))]
    genes <- genes[nzchar(genes)]
    if (length(genes)) out[[bits[1]]] <- unique(genes)
  }
  out
}

read_term2gene <- function(df, term_col, gene_col) {
  out <- split(as.character(df[[gene_col]]), as.character(df[[term_col]]))
  lapply(out, function(x) unique(x[nzchar(x)]))
}

collapse_duplicate_genes <- function(df, gene_col, value_col, action) {
  action <- tolower(as.character(action)[1])
  if (!any(duplicated(df[[gene_col]]))) {
    write_log('No duplicate gene ids in the log2FC table.')
    return(df)
  }
  write_log(sprintf('Duplicate gene ids found; collapsing with %s.', action))
  if (action == 'error') fail('Duplicate gene ids in log2FC table', '', 'Set duplicate_gene_action to max_abs, mean, or first.')
  split_df <- split(df, df[[gene_col]])
  rows <- lapply(split_df, function(g) {
    if (nrow(g) == 1) return(g[1, , drop = FALSE])
    if (action == 'first') return(g[1, , drop = FALSE])
    vals <- as.numeric(g[[value_col]])
    if (action == 'mean') {
      g <- g[1, , drop = FALSE]
      g[[value_col]] <- mean(vals, na.rm = TRUE)
      return(g)
    }
    # max_abs
    idx <- which.max(abs(vals))
    g[idx, , drop = FALSE]
  })
  do.call(rbind, rows)
}

wrap_label <- function(x, width = 28) {
  vapply(as.character(x), function(s) paste(strwrap(gsub('_', ' ', s), width = width), collapse = '\n'), character(1))
}

if (is.null(output_dir) || !nzchar(output_dir)) fail('Output directory missing')
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
unlink(file.path(output_dir, c('result.svg', 'result.pdf', 'result.png', 'figure.json', 'error.json')), force = TRUE)

if (is.null(params_file) || !file.exists(params_file)) fail('Params file not found')
params <- jsonlite::fromJSON(params_file, simplifyVector = FALSE)
if (!is.list(params)) params <- list()

if (is.null(enrichment_file) || !nzchar(enrichment_file)) {
  enrichment_file <- get_param_any(params, c('enrichment_file', 'input2_file'), opt$input2)
}
if (is.null(genesets_file) || !nzchar(genesets_file)) {
  genesets_file <- get_param(params, 'genesets_file', NULL)
}
if (is.null(input_file) || !file.exists(input_file)) {
  fail('Ranked gene table not found', '', 'Pass --input as the gene log2FC / ranking table, matching other GSEA plugins.')
}
if (is.null(enrichment_file) || !nzchar(as.character(enrichment_file)[1]) || !file.exists(enrichment_file)) {
  fail('GSEA result table not found', as.character(enrichment_file), 'Pass --enrichment as the precomputed GSEA table (pathway, NES, p-value).')
}

stats <- read_table_auto(input_file)
gsea <- read_table_auto(enrichment_file)
write_log(sprintf('Loaded rank table %d x %d and GSEA table %d x %d.', nrow(stats), ncol(stats), nrow(gsea), ncol(gsea)))

term_col <- get_param_any(params, c('term_col', 'pathway_col'), NULL)
if (is.null(term_col) || !nzchar(as.character(term_col)[1])) {
  term_col <- guess_column(gsea, c('pathway', 'term', 'Description', 'description', 'ID', 'id', 'pathway_id', 'geneset', 'gs_name', 'pathwayName'))
} else if (!term_col %in% names(gsea)) fail('term_col not found', term_col)
pathway_col <- term_col
nes_col <- get_param(params, 'nes_col', NULL)
if (is.null(nes_col) || !nzchar(as.character(nes_col)[1])) {
  nes_col <- guess_column(gsea, c('NES', 'nes', 'ES', 'enrichmentScore'))
} else if (!nes_col %in% names(gsea)) fail('nes_col not found', nes_col)
p_col <- get_param_any(params, c('pvalue_col', 'p_col'), NULL)
if (is.null(p_col) || !nzchar(as.character(p_col)[1])) {
  p_col <- guess_column(gsea, c('pvalue', 'pval', 'p.value', 'PValue', 'p_value', 'pval_raw', 'p'), required = FALSE)
}
padj_col <- get_param_any(params, c('fdr_col', 'padj_col'), NULL)
if (is.null(padj_col) || !nzchar(as.character(padj_col)[1])) {
  padj_col <- guess_column(gsea, c('padj', 'FDR', 'fdr', 'FDR q-val', 'qvalue', 'q.value', 'p.adjust', 'adj.P.Val', 'p.adj'), required = FALSE)
}
lead_col <- get_param(params, 'leading_genes_col', NULL)
if (is.null(lead_col) || !nzchar(as.character(lead_col)[1])) {
  lead_col <- guess_column(gsea, c('core_enrichment', 'leadingEdge', 'leading_edge', 'leading_genes', 'Leading edge genes', 'genes'), required = FALSE)
}

gene_col <- get_param(params, 'gene_col', NULL)
if (is.null(gene_col) || !nzchar(as.character(gene_col)[1])) {
  gene_col <- guess_column(stats, c('gene', 'gene_id', 'symbol', 'Gene', 'ID', 'id', 'feature', 'names'))
} else if (!gene_col %in% names(stats)) fail('gene_col not found', gene_col)
stat_col <- get_param_any(params, c('stat_col', 'value_col'), NULL)
if (is.null(stat_col) || !nzchar(as.character(stat_col)[1])) {
  stat_col <- guess_column(stats, c('log2FC', 'log2FoldChange', 'avg_log2FC', 'logFC', 'log2fc', 'stat', 'ranking', 'rank_stat', 'value'))
} else if (!stat_col %in% names(stats)) fail('stat_col not found', stat_col)
value_col <- stat_col

dup_action <- get_param(params, 'duplicate_gene_action', 'max_abs')
stats[[gene_col]] <- as.character(stats[[gene_col]])
stats[[value_col]] <- suppressWarnings(as.numeric(as.character(stats[[value_col]])))
stats <- stats[nzchar(stats[[gene_col]]) & is.finite(stats[[value_col]]), , drop = FALSE]
stats <- collapse_duplicate_genes(stats, gene_col, value_col, dup_action)
rank_map <- stats::setNames(stats[[value_col]], stats[[gene_col]])

# Gene sets
pathways <- list()
if (!is.null(genesets_file) && nzchar(genesets_file) && file.exists(genesets_file)) {
  ext <- tolower(tools::file_ext(genesets_file))
  if (ext == 'gmt') {
    pathways <- read_gmt(genesets_file)
  } else {
    t2g <- read_table_auto(genesets_file)
    tcol <- get_param(params, 'term_col', NULL)
    gcol <- get_param(params, 'term_gene_col', NULL)
    if (is.null(tcol) || !nzchar(as.character(tcol)[1])) tcol <- guess_column(t2g, c('term', 'pathway', 'gs_name', 'id'))
    if (is.null(gcol) || !nzchar(as.character(gcol)[1])) gcol <- guess_column(t2g, c('gene', 'gene_id', 'symbol', 'feature'))
    pathways <- read_term2gene(t2g, tcol, gcol)
  }
  write_log(sprintf('Loaded %d gene sets from %s.', length(pathways), basename(genesets_file)))
}

gsea$pathway <- as.character(gsea[[pathway_col]])
gsea$NES <- suppressWarnings(as.numeric(as.character(gsea[[nes_col]])))
gsea$pvalue <- if (!is.null(p_col) && p_col %in% names(gsea)) suppressWarnings(as.numeric(as.character(gsea[[p_col]]))) else NA_real_
gsea$padj <- if (!is.null(padj_col) && padj_col %in% names(gsea)) suppressWarnings(as.numeric(as.character(gsea[[padj_col]]))) else NA_real_
if (!is.null(lead_col) && lead_col %in% names(gsea)) gsea$leading_genes <- as.character(gsea[[lead_col]]) else gsea$leading_genes <- NA_character_

selected <- get_param_any(params, c('selected_terms', 'selected_pathways'), NULL)
if (is.list(selected)) selected <- unlist(selected, use.names = FALSE)
selected <- as.character(selected %||% character())
top_n <- as.integer(num_param(params, 'top_n_terms', num_param(params, 'top_n', 20)))
if (length(selected)) {
  keep <- gsea[match(selected, gsea$pathway), , drop = FALSE]
  keep <- keep[!is.na(keep$pathway), , drop = FALSE]
} else {
  keep <- gsea[is.finite(gsea$NES), , drop = FALSE]
  keep <- keep[order(-abs(keep$NES), keep$pvalue), , drop = FALSE]
  keep <- head(keep, top_n)
}
if (!nrow(keep)) fail('No pathways to plot', '', 'Check the GSEA table and selected_terms / top_n_terms.')

gene_scope <- tolower(as.character(get_param(params, 'gene_scope', 'all_members'))[1])
min_genes <- as.integer(num_param(params, 'min_genes', 10))
min_frac <- num_param(params, 'min_match_fraction', 0)
order_by <- as.character(get_param(params, 'order_by', 'NES'))[1]
sig_source <- tolower(as.character(get_param(params, 'significance_source', 'pvalue'))[1])

qc_rows <- list()
ridge_rows <- list()
for (i in seq_len(nrow(keep))) {
  term <- keep$pathway[i]
  members <- character()
  if (gene_scope == 'leading_edge') members <- parse_gene_string(keep$leading_genes[i])
  if (length(members) == 0 && term %in% names(pathways)) members <- pathways[[term]]
  if (length(members) == 0) members <- parse_gene_string(keep$leading_genes[i])
  members <- unique(members[nzchar(members)])
  matched <- intersect(members, names(rank_map))
  frac <- if (length(members)) length(matched) / length(members) else 0
  qc_rows[[length(qc_rows) + 1]] <- data.frame(
    pathway = term,
    NES = keep$NES[i],
    pvalue = keep$pvalue[i],
    padj = keep$padj[i],
    n_members = length(members),
    n_matched = length(matched),
    match_fraction = frac,
    mean_log2FC = if (length(matched)) mean(rank_map[matched], na.rm = TRUE) else NA_real_,
    median_log2FC = if (length(matched)) stats::median(rank_map[matched], na.rm = TRUE) else NA_real_,
    included = length(matched) >= min_genes && frac >= min_frac,
    stringsAsFactors = FALSE
  )
  if (length(matched) < min_genes || frac < min_frac) {
    write_log(sprintf('Excluding %s: matched %d / %d genes (min_genes=%d).', term, length(matched), length(members), min_genes))
    next
  }
  ridge_rows[[length(ridge_rows) + 1]] <- data.frame(
    pathway = term,
    gene = matched,
    log2FC = unname(rank_map[matched]),
    NES = keep$NES[i],
    pvalue = keep$pvalue[i],
    padj = keep$padj[i],
    stringsAsFactors = FALSE
  )
}

qc <- do.call(rbind, qc_rows)
if (is.null(qc) || !nrow(qc)) fail('Pathway QC is empty')
ridge <- do.call(rbind, ridge_rows)
if (is.null(ridge) || !nrow(ridge)) {
  fail('No pathways passed matching filters', '', sprintf('Need at least %d genes overlapping the log2FC table per pathway.', min_genes))
}
ridge <- ridge[is.finite(ridge$log2FC), , drop = FALSE]

p_for_fill <- if (sig_source == 'padj') ridge$padj else ridge$pvalue
if (all(!is.finite(p_for_fill))) p_for_fill <- if (sig_source == 'padj') ridge$pvalue else ridge$padj
smallest <- min(p_for_fill[is.finite(p_for_fill) & p_for_fill > 0], na.rm = TRUE)
if (!is.finite(smallest)) smallest <- 1e-300
p_safe <- pmax(p_for_fill, smallest / 10)
p_safe[!is.finite(p_safe)] <- 1
ridge$significance <- -log10(p_safe)
ridge$abs_NES <- abs(ridge$NES)

pw <- unique(ridge[, c('pathway', 'NES', 'pvalue', 'padj', 'significance', 'abs_NES')])
custom_order <- get_param(params, 'pathway_order', NULL)
if (is.list(custom_order)) custom_order <- unlist(custom_order, use.names = FALSE)
ord_key <- tolower(order_by)
if (ord_key %in% c('custom', 'user') && length(custom_order)) {
  pw <- pw[order(match(pw$pathway, custom_order, nomatch = 1e9)), , drop = FALSE]
} else if (ord_key %in% c('abs_nes', 'abs(nes)', '|nes|')) {
  pw <- pw[order(-pw$abs_NES, pw$pvalue), , drop = FALSE]
} else if (ord_key %in% c('pvalue', 'p', 'p-value')) {
  pw <- pw[order(pw$pvalue, -pw$abs_NES), , drop = FALSE]
} else if (ord_key %in% c('padj', 'fdr', 'qvalue')) {
  pw <- pw[order(pw$padj, -pw$abs_NES), , drop = FALSE]
} else {
  # NES descending: positive enrichment at the top
  pw <- pw[order(-pw$NES, pw$pvalue), , drop = FALSE]
}

# ggplot discrete y: first level at bottom → reverse so first-ordered pathway is at top
y_levels <- rev(pw$pathway)
pw$pathway <- factor(pw$pathway, levels = y_levels)
ridge$pathway <- factor(ridge$pathway, levels = y_levels)
pw$label <- wrap_label(as.character(pw$pathway))
label_map <- stats::setNames(pw$label, as.character(pw$pathway))
ridge$label <- unname(label_map[as.character(ridge$pathway)])
pw$label <- factor(pw$label, levels = rev(pw$label))
ridge$label <- factor(ridge$label, levels = levels(pw$label))

xlim <- suppressWarnings(as.numeric(unlist(get_param(params, 'xlim', NULL))))
if (length(xlim) != 2 || any(!is.finite(xlim))) {
  q <- num_param(params, 'xlim_quantile', 0.01)
  rng <- as.numeric(stats::quantile(ridge$log2FC, probs = c(q, 1 - q), na.rm = TRUE, names = FALSE))
  pad <- diff(rng) * 0.08
  if (!is.finite(pad) || pad == 0) pad <- 0.5
  xlim <- c(rng[1] - pad, rng[2] + pad)
}

if (!requireNamespace('ggridges', quietly = TRUE)) fail('Package ggridges is required', '', 'install.packages("ggridges")')
if (!requireNamespace('patchwork', quietly = TRUE)) fail('Package patchwork is required', '', 'install.packages("patchwork")')

sig_title <- if (sig_source == 'padj') '-\u2212log10(adjusted p-value)' else '-\u2212log10(pvalue)'
# Use ASCII hyphen-minus for PDF device safety, with unicode minus when possible
sig_title <- if (sig_source == 'padj') expression(-log[10] * '(adjusted p-value)') else expression(-log[10] * '(pvalue)')
xlab <- as.character(get_param_any(params, c('xlab', 'x_title'), 'log2(Fold Change)'))[1]
title <- as.character(get_param(params, 'title', ''))[1]
subtitle <- as.character(get_param(params, 'subtitle', ''))[1]
base_size <- num_param(params, 'base_size', 11)
font_family <- as.character(get_param(params, 'font_family', 'sans'))[1]
ridge_pal <- c('#5E4FA2', '#9E9AC8', '#FEE08B', '#FDAE61', '#F46D43')
nes_low <- '#2166AC'
nes_mid <- '#F7F7F7'
nes_high <- '#D6604D'
size_breaks <- pretty(pw$abs_NES, n = 4)
size_breaks <- unique(size_breaks[size_breaks > 0])
if (!length(size_breaks)) size_breaks <- pretty(range(pw$abs_NES), n = 3)

base_theme <- theme_classic(base_size = base_size, base_family = font_family) +
  theme(
    panel.grid = element_blank(),
    plot.background = element_rect(fill = '#FFFFFF', color = NA),
    panel.background = element_rect(fill = '#FFFFFF', color = NA),
    legend.position = 'right',
    legend.box = 'vertical',
    legend.title = element_text(size = base_size * 0.9),
    legend.text = element_text(size = base_size * 0.8),
    axis.line = element_line(color = '#333333', linewidth = 0.4)
  )

p_bubble <- ggplot(pw, aes(x = 0, y = label)) +
  geom_point(aes(color = NES, size = abs_NES), stroke = 0.2) +
  scale_color_gradient2(
    name = 'NES',
    low = nes_low, mid = nes_mid, high = nes_high, midpoint = 0,
    guide = guide_colorbar(order = 2, barheight = grid::unit(2.6, 'cm'))
  ) +
  scale_size_continuous(
    name = 'abs(NES)',
    range = c(num_param(params, 'bubble_min_size', 2.4), num_param(params, 'bubble_max_size', 8.5)),
    breaks = size_breaks,
    guide = guide_legend(order = 3, override.aes = list(color = '#444444'))
  ) +
  scale_x_continuous(limits = c(-0.55, 0.55), expand = c(0, 0)) +
  labs(x = NULL, y = NULL) +
  base_theme +
  theme(
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank(),
    axis.line.x = element_blank(),
    axis.text.y = element_text(size = base_size * 0.95, color = '#111111', hjust = 1),
    plot.margin = margin(8, 2, 8, 8)
  )

p_ridge <- ggplot(ridge, aes(x = log2FC, y = label, fill = significance, group = label)) +
  ggridges::geom_density_ridges(
    scale = num_param(params, 'ridge_scale', 1.05),
    rel_min_height = 0.01,
    color = as.character(get_param(params, 'ridge_outline_color', '#111111'))[1],
    linewidth = num_param(params, 'ridge_outline_width', 0.35),
    alpha = num_param(params, 'ridge_alpha', 0.88),
    quantile_lines = FALSE
  ) +
  geom_vline(
    xintercept = 0,
    linetype = 'dashed',
    color = as.character(get_param(params, 'zero_line_color', '#555555'))[1],
    linewidth = num_param(params, 'zero_line_width', 0.45)
  ) +
  scale_fill_gradientn(
    colours = ridge_pal,
    name = if (sig_source == 'padj') expression(-log[10] * '(adjusted p-value)') else expression(-log[10] * '(pvalue)'),
    guide = guide_colorbar(order = 1, barheight = grid::unit(2.6, 'cm'))
  ) +
  coord_cartesian(xlim = xlim, clip = 'off') +
  labs(x = xlab, y = NULL) +
  base_theme +
  theme(
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank(),
    axis.line.y = element_blank(),
    axis.title.x = element_text(size = base_size * 1.05),
    plot.margin = margin(8, 10, 8, 2)
  )

if (nzchar(title) || nzchar(subtitle)) {
  p_bubble <- p_bubble + labs(title = if (nzchar(title)) title else NULL, subtitle = if (nzchar(subtitle)) subtitle else NULL) +
    theme(plot.title = element_text(face = 'bold', size = base_size * 1.25), plot.subtitle = element_text(color = '#555555'))
}

bubble_w <- num_param(params, 'bubble_panel_width', 0.28)
plot <- patchwork::wrap_plots(p_bubble, p_ridge, nrow = 1, widths = c(bubble_w, 1)) +
  patchwork::plot_layout(guides = 'collect') &
  theme(legend.position = as.character(get_param(params, 'legend_position', 'right'))[1])

n_pw <- nrow(pw)
width <- num_param(params, 'width', 9.2)
height <- num_param(params, 'height', max(5.2, 0.42 * n_pw + 2.1))
dpi <- as.integer(num_param(params, 'dpi', 300))

ggplot2::ggsave(file.path(output_dir, 'result.pdf'), plot, width = width, height = height, device = if (capabilities('cairo')) grDevices::cairo_pdf else 'pdf')
ggplot2::ggsave(file.path(output_dir, 'result.svg'), plot, width = width, height = height)
ggplot2::ggsave(file.path(output_dir, 'result.png'), plot, width = width, height = height, dpi = dpi)

write.csv(qc, file.path(output_dir, 'pathway_qc.csv'), row.names = FALSE)
write.csv(ridge, file.path(output_dir, 'plot_data.csv'), row.names = FALSE)

pos <- qc[qc$included & qc$mean_log2FC > 0.5, 'pathway']
neg <- qc[qc$included & qc$mean_log2FC < -0.5, 'pathway']
fig <- list(
  plugin = 'gsea_ridge_nes_plot',
  analysis = list(
    n_pathways = n_pw,
    n_genes = nrow(ridge),
    gene_scope = gene_scope,
    order_by = order_by,
    significance_source = sig_source,
    duplicate_gene_action = dup_action,
    min_genes = min_genes
  ),
  data = list(
    input = 'ranked gene / log2FC table',
    enrichment = 'precomputed GSEA table',
    genesets = if (!is.null(genesets_file) && nzchar(genesets_file)) basename(genesets_file) else 'core_enrichment',
    gene_col = gene_col,
    stat_col = stat_col,
    term_col = term_col,
    nes_col = nes_col
  ),
  style = list(
    xlim = xlim,
    xlab = xlab,
    ridge_fill = 'neglog10 p-value',
    bubble_color = 'NES',
    bubble_size = 'abs(NES)'
  ),
  layers = list('pathway labels', 'NES bubbles', 'log2FC ridgelines', 'x=0 reference'),
  export = list(width = width, height = height, dpi = dpi, formats = c('svg', 'pdf', 'png')),
  pathways_right_shifted = as.character(pos),
  pathways_left_shifted = as.character(neg),
  outputs = c('result.svg', 'result.pdf', 'result.png', 'figure.json', 'pathway_qc.csv', 'plot_data.csv', 'run.log')
)
writeLines(toJSON(fig, auto_unbox = TRUE, pretty = TRUE, null = 'null'), file.path(output_dir, 'figure.json'))
write_log(sprintf('Finished ridge+NES plot for %d pathways.', n_pw))
