#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
})

op <- parse_args(OptionParser(option_list = list(
  make_option('--input', type = 'character'),
  make_option('--params', type = 'character'),
  make_option('--output', type = 'character')
)))
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x
out <- op$output %||% getwd()
dir.create(out, recursive = TRUE, showWarnings = FALSE)
fail <- function(message, detail = '', suggestion = 'Check term, ontology, p-value, and count columns in params.json.') {
  writeLines(toJSON(list(error = message, detail = as.character(detail %||% ''), suggestion = suggestion), auto_unbox = TRUE, pretty = TRUE), file.path(out, 'error.json'))
  quit(status = 1)
}
param <- function(p, names, default = NULL) {
  for (name in names) if (!is.null(p[[name]])) return(p[[name]])
  default
}
as_num <- function(x) suppressWarnings(as.numeric(as.character(x)))
find_col <- function(df, requested, aliases, required = TRUE) {
  n <- names(df); low <- tolower(n)
  if (!is.null(requested) && length(requested) && !is.na(requested[1])) {
    hit <- match(tolower(as.character(requested[1])), low)
    if (!is.na(hit)) return(n[hit])
  }
  hit <- match(tolower(aliases), low); hit <- hit[!is.na(hit)]
  if (length(hit)) return(n[hit[1]])
  if (required) fail('Required enrichment column not found', paste(aliases, collapse = ', '))
  NULL
}
read_table <- function(path) {
  if (is.null(path) || !file.exists(path)) fail('Input file not found', as.character(path))
  if (tolower(tools::file_ext(path)) == 'csv') read.csv(path, check.names = FALSE, stringsAsFactors = FALSE) else read.delim(path, check.names = FALSE, stringsAsFactors = FALSE)
}

tryCatch({
  p <- if (!is.null(op$params) && file.exists(op$params)) fromJSON(op$params, simplifyVector = TRUE) else list()
  if (length(p)) {
    for (n in names(p)) if (is.list(p[[n]]) && !is.data.frame(p[[n]]) && !is.null(names(p[[n]]))) {
      for (k in names(p[[n]])) if (is.null(p[[k]])) p[[k]] <- p[[n]][[k]]
    }
  }
  d <- read_table(op$input)
  term_col <- find_col(d, param(p, c('term_column', 'description_column')), c('term', 'description', 'pathway', 'pathway_name', 'id', 'name'))
  category_col <- find_col(d, param(p, c('category_column', 'ontology_column')), c('category', 'ontology', 'ont', 'class', 'source', 'database'))
  raw_col <- find_col(d, param(p, c('pvalue_column', 'p_column')), c('pvalue', 'p_value', 'p.val', 'pval', 'p', 'pvalue_raw'), FALSE)
  adj_col <- find_col(d, param(p, c('adjusted_pvalue_column', 'padj_column', 'fdr_column')), c('adjusted_pvalue', 'adjusted.p.value', 'padj', 'qvalue', 'fdr', 'p.adjust', 'p_adj'), FALSE)
  count_col <- find_col(d, param(p, c('count_column', 'gene_count_column')), c('count', 'gene_count', 'genecount', 'gene.count', 'n_genes', 'size'), TRUE)
  if (is.null(raw_col) && is.null(adj_col)) fail('No p-value column found', 'Provide pvalue_column or adjusted_pvalue_column.')

  significance_column <- tolower(as.character(param(p, 'significance_column', 'auto'))[1])
  use_adj <- significance_column %in% c('adjusted', 'adjusted_pvalue', 'padj', 'fdr', 'qvalue') ||
    (significance_column == 'auto' && is.null(raw_col) && !is.null(adj_col))
  sig_col <- if (use_adj) adj_col else raw_col
  if (is.null(sig_col)) sig_col <- if (!is.null(adj_col)) adj_col else raw_col
  if (is.null(sig_col)) fail('Selected significance column is unavailable')

  normalize_category <- function(x) {
    y <- toupper(trimws(as.character(x)))
    ifelse(grepl('KEGG', y), 'KEGG Pathway',
      ifelse(y %in% c('BP', 'GO:BP') | grepl('BIOLOGICAL PROCESS', y), 'Biological Process',
        ifelse(y %in% c('CC', 'GO:CC') | grepl('CELLULAR COMPONENT', y), 'Cellular Component',
          ifelse(y %in% c('MF', 'GO:MF') | grepl('MOLECULAR FUNCTION', y), 'Molecular Function', NA_character_))))
  }
  z <- data.frame(
    term = trimws(as.character(d[[term_col]])), category = normalize_category(d[[category_col]]),
    p = as_num(d[[sig_col]]), count = as_num(d[[count_col]]), stringsAsFactors = FALSE
  )
  z <- z[nzchar(z$term) & !is.na(z$category) & is.finite(z$p) & z$p > 0 & is.finite(z$count), , drop = FALSE]
  if (!nrow(z)) fail('No valid GO or KEGG rows remain')
  z$significance <- -log10(pmax(z$p, .Machine$double.xmin))
  category_order <- c('Biological Process', 'Cellular Component', 'Molecular Function', 'KEGG Pathway')
  z$category <- factor(z$category, levels = category_order)
  z <- z[order(z$category, -z$significance), , drop = FALSE]
  top_n <- max(0, as.integer(param(p, 'top_n', 5)))
  if (top_n > 0) {
    keep <- ave(z$significance, z$category, FUN = seq_along) <= top_n
    z <- z[keep, , drop = FALSE]
  }
  z$category <- factor(as.character(z$category), levels = category_order)
  z <- z[order(z$category, -z$significance), , drop = FALSE]
  z$row <- rev(seq_len(nrow(z)))

  colors <- c('Biological Process' = '#F4B6B8', 'Cellular Component' = '#A9D6E5', 'Molecular Function' = '#C7B8EA', 'KEGG Pathway' = '#B8D8BA')
  custom <- param(p, c('category_colors', 'ontology_colors'), NULL)
  if (!is.null(custom)) {
    custom <- unlist(custom, use.names = TRUE)
    colors[intersect(names(custom), names(colors))] <- custom[intersect(names(custom), names(colors))]
  }
  max_sig <- max(z$significance, na.rm = TRUE)
  x_breaks <- pretty(c(0, max_sig), n = 5)
  gap <- as.numeric(param(p, 'category_gap', 0.35))
  row_positions <- z$row + cumsum(c(0, diff(as.numeric(z$category)) != 0) * gap)
  z$row <- row_positions
  strip_df <- do.call(rbind, lapply(levels(droplevels(z$category)), function(cat) {
    q <- z[z$category == cat, , drop = FALSE]
    if (!nrow(q)) return(NULL)
    data.frame(category = cat, xmin = -1.55, xmax = -0.85, ymin = min(q$row) - .48, ymax = max(q$row) + .48)
  }))
  pplot <- ggplot(z, aes(y = row)) +
    geom_rect(data = strip_df, aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, fill = category), colour = '#555555', linewidth = .35, inherit.aes = FALSE) +
    geom_text(data = strip_df, aes(x = (xmin + xmax) / 2, y = (ymin + ymax) / 2, label = category), angle = 90, size = as.numeric(param(p, 'category_label_size', 3.3)), colour = '#222222', inherit.aes = FALSE) +
    geom_rect(aes(xmin = 0, xmax = significance, ymin = row - .25, ymax = row + .25, fill = category), colour = NA) +
    geom_point(aes(x = -0.42, size = count, fill = category), shape = 21, colour = '#4D4D4D', stroke = as.numeric(param(p, 'bubble_stroke', .55)), show.legend = c(fill = FALSE, size = TRUE)) +
    geom_text(aes(x = -0.42, label = format(count, trim = TRUE, scientific = FALSE)), size = as.numeric(param(p, 'count_label_size', 3)), colour = '#222222', fontface = 'bold', show.legend = FALSE) +
    geom_text(aes(x = 0.08, label = term), hjust = 0, size = as.numeric(param(p, 'term_label_size', 3.1)), colour = '#222222', show.legend = FALSE) +
    scale_fill_manual(values = colors, drop = FALSE, name = 'Category') +
    scale_size_continuous(range = as.numeric(param(p, 'bubble_size_range', c(5, 12))), name = 'Count', breaks = pretty(z$count, n = 3)) +
    scale_x_continuous(limits = c(-1.85, max_sig + 0.45), breaks = x_breaks, expand = c(0, 0)) +
    scale_y_continuous(NULL, breaks = NULL, expand = expansion(mult = c(.02, .05))) +
    labs(x = if (use_adj) '-log10(adjusted p-value)' else '-log10(p-value)', title = param(p, 'title', 'GO + KEGG Enrichment')) +
    theme_minimal(base_family = param(p, 'font_family', 'sans'), base_size = as.numeric(param(p, 'base_size', 11))) +
    theme(panel.grid.major.y = element_blank(), panel.grid.minor = element_blank(), panel.grid.major.x = element_line(colour = '#E6E6E6', linewidth = .3), axis.text.y = element_blank(), axis.ticks.y = element_blank(), plot.title = element_text(hjust = .5, face = 'bold', colour = '#222222'), axis.text = element_text(colour = '#222222'), axis.title = element_text(colour = '#222222'), plot.background = element_rect(fill = '#FFFFFF', colour = NA), panel.background = element_rect(fill = '#FFFFFF', colour = NA), legend.background = element_rect(fill = '#FFFFFF', colour = NA), legend.text = element_text(colour = '#222222'), legend.title = element_text(face = 'bold', colour = '#222222'), legend.position = param(p, 'legend_position', 'right'), plot.margin = margin(8, 12, 8, 12))

  width <- as.numeric(param(p, 'width', 11)); height <- max(as.numeric(param(p, 'height', 7)), nrow(z) * as.numeric(param(p, 'row_height', .42)) + 1.6)
  ggsave(file.path(out, 'result.svg'), pplot, width = width, height = height, units = 'in')
  ggsave(file.path(out, 'result.pdf'), pplot, width = width, height = height, units = 'in', device = if (capabilities('cairo')) grDevices::cairo_pdf else 'pdf')
  ggsave(file.path(out, 'result.png'), pplot, width = width, height = height, units = 'in', dpi = as.numeric(param(p, 'dpi', 300)))
  writeLines('<html><body>Static render. Use the PNG/SVG/PDF outputs for this plot.</body></html>', file.path(out, 'result.html'))
  write.csv(z, file.path(out, 'selected_rows.csv'), row.names = FALSE)
  writeLines(toJSON(list(figure_type = 'go_kegg_enrichment_bar_bubble', significance_column = sig_col, top_n = top_n, categories = category_order, n_terms = nrow(z), export = list(svg = 'result.svg', pdf = 'result.pdf', png = 'result.png', html = 'result.html')), auto_unbox = TRUE, pretty = TRUE), file.path(out, 'figure.json'))
  writeLines(sprintf('Rendered %d GO/KEGG terms using %s.', nrow(z), sig_col), file.path(out, 'run.log'))
}, error = function(e) fail('Plot rendering failed', conditionMessage(e)))
