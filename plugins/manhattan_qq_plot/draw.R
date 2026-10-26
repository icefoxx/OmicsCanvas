draw_plot <- function(df) {
    p_col <- oc_col(df, "pvalue_column", "pvalue")
    probabilities <- oc_numeric(df, p_col, probability = TRUE)
    if (any(probabilities <= 0))
        stop("pvalue_column must be in (0,1]. Replace rounded zeros with a justified detection bound; do not use transformed scores.")
    mode <- chr("plot_type", "both")
    labels <- if (!is.null(oc_col(df, "label_column", "label", FALSE)))
        as.character(df[[oc_col(df, "label_column", "label", FALSE)]]) else rep("", nrow(df))
    result <- data.frame(pvalue = probabilities, label = labels)
    threshold <- num("pvalue_threshold", 5e-08)
    if (threshold <= 0 || threshold > 1)
        stop("pvalue_threshold must be in (0,1].")
    plots <- list()
    if (mode != "qq") {
        chr_col <- oc_col(df, "chromosome_column", "chromosome")
        pos_col <- oc_col(df, "position_column", "position")
        result$chromosome <- as.character(df[[chr_col]])
        result$position <- oc_numeric(df, pos_col, TRUE)
        if (anyNA(result$chromosome) || any(!nzchar(result$chromosome)))
            stop("Chromosome labels must be nonempty.")
        chr_levels <- unique(result$chromosome)
        # Preserve supplied chromosome order, including nonhuman contig names.
        lengths <- vapply(chr_levels, function(chrom) max(result$position[result$chromosome == chrom]),
            numeric(1))
        spacer <- max(lengths) * 0.03
        offsets <- c(0, head(cumsum(lengths + spacer), -1))
        names(offsets) <- chr_levels
        result$x <- result$position + offsets[result$chromosome]
        result$y <- -log10(result$pvalue)
        result$band <- factor(match(result$chromosome, chr_levels)%%2)
        p <- ggplot(result, aes(x, y, color = band)) + geom_point(size = num("point_size", 2), alpha = num("point_alpha",
            0.75)) + geom_hline(yintercept = -log10(threshold), linetype = "dashed", color = chr("threshold_color",
            "#D36161"), linewidth = num("line_width", 0.6)) + scale_color_manual(values = oc_colors(levels(result$band)),
            guide = "none") + scale_x_continuous(breaks = offsets + lengths/2, labels = chr_levels) +
            oc_labels("Chromosome", "\u2212log10(p-value)") + oc_theme()
        if (flag("label_show", TRUE)) {
            picked <- result[nzchar(result$label) & !is.na(result$label), , drop = FALSE]
            if (nrow(picked) > 40)
                stop("Use at most 40 nonempty marker labels, or disable label_show.")
            p <- p + ggrepel::geom_text_repel(family = chr("font_family", "sans"), data = picked, aes(label = label),
                size = num("label_size", 2.8), color = "#334453", seed = oc_seeds(), max.time = Inf,
                max.iter = 2000, max.overlaps = 30)
        }
        plots$manhattan <- p
    }
    qq <- data.frame(expected = -log10(ppoints(length(probabilities))), observed = -log10(sort(probabilities)))
    if (mode != "manhattan") {
        plots$qq <- ggplot(qq, aes(expected, observed)) + geom_abline(slope = 1, intercept = 0, color = "#9AA6AF",
            linetype = "dashed") + geom_point(size = num("point_size", 2), color = chr("qq_color", "#466F90"),
            alpha = num("point_alpha", 0.75)) + oc_labels("Expected \u2212log10(p)", "Observed \u2212log10(p)") +
            oc_theme()
    }
    p <- if (length(plots) == 1)
        plots[[1]] else patchwork::wrap_plots(plots, nrow = 1, widths = c(2.5, 1))
    oc_result(p, result, list(method = "supplied_probability_diagnostics", threshold = threshold, qq_positions = "R ppoints"),
        list(qq_used.csv = qq), "Raw probabilities; genomic association testing is performed upstream")
}
