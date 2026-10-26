draw_plot <- function(df) {
    a_col <- oc_col(df, "x_column", "method_a")
    b_col <- oc_col(df, "y_column", "method_b")
    a <- oc_numeric(df, a_col)
    b <- oc_numeric(df, b_col)
    if (length(a) < 3)
        stop("At least three independent paired measurements are required.")
    difference <- a - b
    mode <- chr("difference_mode", "absolute")
    if (mode == "percent") {
        if (any((a + b)/2 == 0))
            stop("Percent differences require nonzero pair means.")
        difference <- 100 * difference/((a + b)/2)
    }
    d <- data.frame(mean = (a + b)/2, difference = difference, group = oc_group(df))
    multiplier <- num("loa_multiplier", 1.96)
    if (multiplier <= 0)
        stop("loa_multiplier must be positive.")
    bias <- mean(d$difference)
    spread <- sd(d$difference)
    limits <- c(bias - multiplier * spread, bias, bias + multiplier * spread)
    p <- ggplot(d, aes(mean, difference, color = group)) + geom_point(size = num("point_size", 2), alpha = num("point_alpha",
        0.75)) + geom_hline(yintercept = limits, linetype = c("dashed", "solid", "dashed"), color = "#7C8794",
        linewidth = num("line_width", 0.6)) + scale_color_manual(values = oc_colors(d$group), name = "") +
        oc_labels(paste("Mean of", a_col, "and", b_col), if (mode == "percent")
            paste0("Difference (%) \u00b7 ", a_col, " \u2212 ", b_col) else paste(a_col, "\u2212", b_col)) + oc_theme()
    if (flag("trend_show", FALSE))
        p <- p + geom_smooth(aes(group = 1), method = "lm", formula = y ~ x, se = FALSE, color = "#313F4D",
            linewidth = num("line_width", 0.6))
    if (flag("label_show", TRUE))
        p <- p + annotate("text", x = Inf, y = limits, label = paste(c("Lower LoA", "Bias", "Upper LoA"),
            oc_pretty(limits)), hjust = 1.05, vjust = -0.4, size = num("label_size", 2.8), color = "#495967") +
            scale_y_continuous(expand = expansion(mult = c(0.1, 0.15)))
    oc_result(p, d, list(method = "bland_altman", difference = "method_a_minus_method_b", mode = mode,
        bias = bias, sd = spread, multiplier = multiplier, lower_loa = limits[1], upper_loa = limits[3]),
        note = sprintf("%d paired observations; limits assume independent, approximately normal differences",
            nrow(d)))
}
