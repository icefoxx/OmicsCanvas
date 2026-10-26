draw_plot <- function(df) {
    label_col <- oc_col(df, "label_column", "label")
    effect_col <- oc_col(df, "effect_column", "effect")
    lower_col <- oc_col(df, "lower_column", "lower")
    upper_col <- oc_col(df, "upper_column", "upper")
    d <- data.frame(label = as.character(df[[label_col]]), effect = oc_numeric(df, effect_col), lower = oc_numeric(df,
        lower_col), upper = oc_numeric(df, upper_col), group = oc_group(df))
    if (anyNA(d$label) || any(!nzchar(d$label)) || anyDuplicated(d$label))
        stop("label_column must contain unique, nonempty row labels.")
    if (any(d$lower > d$effect | d$upper < d$effect))
        stop("Each confidence interval must satisfy lower <= effect <= upper.")
    log_axis <- chr("x_scale", "linear") == "log10"
    if (log_axis && any(c(d$lower, d$upper, d$effect, num("null_value", 1)) <= 0))
        stop("Log10 effect axes require positive effects, confidence bounds and null_value (usually 1 for ratios).")
    d$row <- factor(d$label, levels = rev(unique(d$label)))
    colors <- oc_colors(d$group)
    p <- ggplot(d, aes(effect, row, color = group)) + geom_vline(xintercept = num("null_value", 1), linetype = "dashed",
        color = "#8D9AA2") + geom_segment(aes(x = lower, xend = upper, yend = row), linewidth = num("line_width",
        0.6)) + geom_point(size = num("point_size", 2)) + scale_color_manual(values = colors, name = "") +
        oc_labels(effect_col, "") + oc_theme()
    if (log_axis && !flag('estimate_show', TRUE))
        p <- p + scale_x_log10()
    if (flag("estimate_show", TRUE)) {
        text <- sprintf("%s [%s, %s]", oc_pretty(d$effect), oc_pretty(d$lower), oc_pretty(d$upper))
        p <- p + geom_text(aes(x = upper, label = text), nudge_x = 0, hjust = -0.15, size = num("label_size",
            2.8), show.legend = FALSE) + scale_y_discrete(expand = expansion(add = 0.8)) + theme(plot.margin = margin(12,
            24, 12, 12))
        # Explicit extra range for text is reserved only while estimates are drawn.
        if (log_axis)
            p <- p + scale_x_log10(limits = c(min(d$lower)/1.1, max(d$upper) * (max(d$upper)/min(d$lower))^0.65)) else p <- p + scale_x_continuous(expand = expansion(mult = c(0.08, 0.75)))
    }
    oc_result(p, d, list(method = "supplied_effect_intervals", axis = if (log_axis) "log10" else "linear",
        null_value = num("null_value", 1)), note = "Supplied effect estimates and intervals; no model or meta-analysis fitted")
}
