draw_plot <- function(df) {
    x_col <- oc_col(df, "x_column", "x")
    y_col <- oc_col(df, "y_column", "y")
    vx_col <- oc_col(df, "vx_column", "vx")
    vy_col <- oc_col(df, "vy_column", "vy")
    d <- data.frame(x = oc_numeric(df, x_col), y = oc_numeric(df, y_col), vx = oc_numeric(df, vx_col),
        vy = oc_numeric(df, vy_col), group = oc_group(df))
    factor <- num("vector_scale", 0.8)
    if (factor < 0)
        stop("vector_scale must be nonnegative; use supplied signed vectors to reverse direction.")
    stride <- max(1, as.integer(num("arrow_stride", 4)))
    arrows <- d[seq(1, nrow(d), by = stride), ]
    arrows$xend <- arrows$x + arrows$vx * factor
    arrows$yend <- arrows$y + arrows$vy * factor
    p <- ggplot(d, aes(x, y, color = group)) + geom_point(size = num("point_size", 2), alpha = num("point_alpha",
        0.35)) + geom_segment(data = arrows, aes(xend = xend, yend = yend), linewidth = num("line_width",
        0.6), alpha = num("arrow_alpha", 0.8), arrow = grid::arrow(length = grid::unit(num("arrow_length",
        0.06), "inches"), type = "closed")) + scale_color_manual(values = oc_colors(d$group), name = "") +
        oc_labels(x_col, y_col) + coord_fixed() + oc_theme()
    oc_result(p, d, list(method = "supplied_vectors", vector_scale = factor, arrow_stride = stride),
        list(arrows_used.csv = arrows), "Supplied displacement vectors; no RNA-velocity inference or kinetic model fitted")
}
