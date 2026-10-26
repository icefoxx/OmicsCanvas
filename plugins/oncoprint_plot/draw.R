draw_plot <- function(df) {
    gene_col <- oc_col(df, "feature_column", "gene")
    sample_col <- oc_col(df, "sample_column", "sample")
    type_col <- oc_col(df, "group_column", "alteration")
    raw <- data.frame(gene = as.character(df[[gene_col]]), sample = as.character(df[[sample_col]]), alteration = as.character(df[[type_col]]))
    if (anyNA(raw$gene) || anyNA(raw$sample) || any(!nzchar(raw$gene)) || any(!nzchar(raw$sample)))
        stop("Gene and sample identifiers must be nonempty.")
    raw$alteration[is.na(raw$alteration) | !nzchar(raw$alteration)] <- "None"
    samples <- unique(raw$sample)
    genes <- unique(raw$gene)
    if (length(samples) > 200 || length(genes) > 100)
        stop("Filter to at most 200 samples and 100 genes for a readable mutation matrix.")
    changed <- unique(raw[!tolower(raw$alteration) %in% c("none", "wildtype", "wt"), ])
    gene_counts <- table(factor(unique(changed[c("gene", "sample")])$gene, levels = genes))
    if (chr("row_order", "frequency") == "frequency")
        genes <- genes[order(-as.numeric(gene_counts), seq_along(genes))]
    colors <- oc_colors(changed$alteration)
    background <- expand.grid(gene = genes, sample = samples, stringsAsFactors = FALSE)
    background$x <- match(background$sample, samples)
    background$y <- match(background$gene, rev(genes))
    tiles <- list()
    for (key in split(changed, interaction(changed$gene, changed$sample, drop = TRUE))) {
        key <- key[order(key$alteration), , drop = FALSE]
        count <- nrow(key)
        x <- match(key$sample[1], samples)
        y <- match(key$gene[1], rev(genes))
        tiles[[length(tiles) + 1]] <- data.frame(xmin = x - 0.44, xmax = x + 0.44, ymin = y - 0.44 +
            (seq_len(count) - 1) * 0.88/count, ymax = y - 0.44 + seq_len(count) * 0.88/count, alteration = key$alteration,
            gene = key$gene, sample = key$sample)
    }
    tiles <- if (length(tiles))
        do.call(rbind, tiles) else data.frame(xmin = numeric(), xmax = numeric(), ymin = numeric(), ymax = numeric(), alteration = character(),
        gene = character(), sample = character())
    p <- ggplot() + geom_tile(data = background, aes(x, y), fill = chr("empty_color", "#EDF0F3"), width = 0.88,
        height = 0.88)
    if (nrow(tiles))
        p <- p + geom_rect(data = tiles, aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, fill = alteration)) +
            scale_fill_manual(values = colors, name = "Alteration")
    p <- p + scale_y_continuous(breaks = seq_along(genes), labels = rev(genes), limits = c(.5, length(genes) + .5), expand = c(0, 0)) +
        scale_x_continuous(breaks = seq_along(samples), labels = if (flag("sample_label_show", FALSE))
            samples else NULL, expand = expansion(add = 0.5)) + oc_labels("Sample", "") + oc_theme() + theme(axis.ticks = element_blank(),
        axis.line = element_blank(), axis.text.x = element_text(angle = 90, hjust = 1))
    counts <- data.frame(gene = genes, altered_samples = as.integer(table(factor(unique(changed[c("gene",
        "sample")])$gene, levels = genes))), total_samples = length(samples))
    counts$fraction <- counts$altered_samples/counts$total_samples
    if (flag("frequency_show", TRUE)) {
        counts$y <- match(counts$gene, rev(genes))
        frequency <- ggplot(counts, aes(fraction, y)) + geom_col(fill = chr("frequency_color",
            "#5D7286"), width = 0.75, orientation = "y") + scale_x_continuous(limits = c(0, 1), breaks = c(0, 0.5, 1)) + scale_y_continuous(limits = c(.5, length(genes) + .5), expand = c(0, 0)) +
            labs(x = "Altered fraction", y = NULL) + oc_theme() + theme(axis.text.y = element_blank(),
            axis.ticks.y = element_blank(), legend.position = "none")
        p <- patchwork::wrap_plots(p, frequency, nrow = 1, widths = c(5, 1.1), guides = "collect")
    }
    oc_result(p, raw, list(method = "supplied_alterations", sample_count = length(samples), gene_count = length(genes),
        multi_hit = "equal-height subdivisions; one distinct alteration type per slice"), list(gene_frequencies_used.csv = counts,
        tiles_used.csv = tiles), "Empty cells denote no supplied alteration; missing sample coverage is not inferred")
}
