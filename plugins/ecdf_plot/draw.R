draw_plot <- function(df) {
    value_col <- oc_col(df, "value_column", "value")
    raw <- data.frame(value = oc_numeric(df, value_col), group = oc_group(df))
    curves <- list()
    level <- num("confidence_level", 0.95)
    if (level <= 0 || level >= 1)
        stop("confidence_level must be between 0 and 1.")
    for (group in sort(unique(raw$group))) {
        g <- raw$value[raw$group == group]
        x <- sort(unique(g))
        y <- (stats::ecdf(g))(x)
        epsilon <- sqrt(log(2/(1 - level))/(2 * length(g)))
        curves[[group]] <- data.frame(x = c(min(x), x), y = c(0, y), lower = pmax(0, c(0, y) - epsilon),
            upper = pmin(1, c(0, y) + epsilon), group = group, n = length(g))
    }
    d <- do.call(rbind, curves)
    p <- ggplot(d, aes(x, y, color = group))
    if (flag("confidence_show", FALSE)) {
        ribbon <- do.call(rbind, lapply(split(d, d$group), function(g) {
            idx <- head(rep(seq_len(nrow(g)), each = 2), -1)
            result <- g[idx, , drop = FALSE]
            result$x <- c(g$x[1], rep(g$x[-1], each = 2))
            result
        }))
        p <- p + geom_ribbon(data = ribbon, aes(ymin = lower, ymax = upper, fill = group), alpha = num("confidence_alpha",
            0.14), color = NA)
    }
    p <- p + geom_step(linewidth = num("line_width", 0.6)) + scale_color_manual(values = oc_colors(d$group),
        name = "") + scale_fill_manual(values = oc_colors(d$group), name = "") + oc_labels(value_col,
        "Cumulative proportion") + oc_theme()
    method <- chr("stat_method", "none")
    statistics <- list(method = method, confidence_band = "DKW simultaneous, each group separately",
        confidence_level = level)
    if (method != "none") {
        groups <- unique(raw$group)
        if (length(groups) != 2)
            stop("Choose exactly two groups for the two-sample statistical test, or stat_method = none.")
        a <- raw$value[raw$group == groups[1]]
        b <- raw$value[raw$group == groups[2]]
        tested <- if (method == "wilcoxon")
            wilcox.test(a, b, exact = FALSE) else ks.test(a, b, exact = FALSE)
        statistics$pvalue <- tested$p.value
        p <- p + annotate("text", x = -Inf, y = 0.94, label = paste(method, "p", format.pval(tested$p.value,
            digits = 3, eps = 1e-04)), hjust = -0.05, size = 3)
    }
    oc_result(p, d, statistics, note = sprintf("%d observations; ECDF is P(X \u2264 x); ties retain their full probability mass",
        nrow(raw)))
}
