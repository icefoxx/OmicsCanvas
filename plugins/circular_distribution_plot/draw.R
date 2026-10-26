draw_plot <- function(df) {
    value_col <- oc_col(df, "value_column", "score")
    metric_col <- oc_col(df, "feature_column", "metric")
    id_col <- oc_col(df, "id_column", "id", FALSE)
    raw <- data.frame(value = oc_numeric(df, value_col), metric = as.character(df[[metric_col]]), group = oc_group(df),
        id = if (is.null(id_col))
            as.character(seq_len(nrow(df))) else as.character(df[[id_col]]))
    if (anyNA(raw$metric) || any(!nzchar(raw$metric)))
        stop("Metric labels must be nonempty.")
    groups <- sort(unique(raw$group))
    colors <- oc_colors(groups)
    if (length(groups) > 8 || length(unique(raw$metric)) > 12)
        stop("Use at most eight rings and 12 metric panels.")
    selected <- chr_vec("highlight_ids")
    angle_span <- 2 * pi - num("gap_angle", 60) * pi/180
    if (angle_span <= pi || angle_span >= 2 * pi)
        stop("gap_angle must be between 0 and 180 degrees.")
    d <- raw
    rings <- list()
    ticks <- list()
    for (metric in unique(raw$metric)) {
        idx <- which(raw$metric == metric)
        limits <- if (chr("range_mode", "free") == "shared")
            range(raw$value) else range(raw$value[idx])
        if (diff(limits) == 0)
            limits <- limits + c(-0.5, 0.5)
        d$angle[idx] <- -pi/2 + (2 * pi - angle_span)/2 + (d$value[idx] - limits[1])/diff(limits) * angle_span
        d$radius[idx] <- 0.55 + match(d$group[idx], groups) * 0.12
        for (group in groups) {
            a <- seq(-pi/2 + (2 * pi - angle_span)/2, 3 * pi/2 - (2 * pi - angle_span)/2, length.out = 180)
            r <- 0.55 + match(group, groups) * 0.12
            rings[[length(rings) + 1]] <- data.frame(x = cos(a) * r, y = sin(a) * r, group = group, metric = metric)
        }
        labels <- pretty(limits, n = 4)
        labels <- labels[labels >= limits[1] & labels <= limits[2]]
        a <- -pi/2 + (2 * pi - angle_span)/2 + (labels - limits[1])/diff(limits) * angle_span
        r <- 0.55 + (length(groups) + 1) * 0.12
        ticks[[length(ticks) + 1]] <- data.frame(x = cos(a) * r, y = sin(a) * r, label = oc_pretty(labels),
            metric = metric)
    }
    d$x <- cos(d$angle) * d$radius
    d$y <- sin(d$angle) * d$radius
    extent <- 0.55 + (length(groups) + 2.2) * 0.12
    p <- ggplot() + geom_path(data = do.call(rbind, rings), aes(x, y, group = group), color = "#DBE2E8",
        linewidth = num("line_width", 0.6)) + geom_point(data = d, aes(x, y, color = group), size = num("point_size",
        2), alpha = num("point_alpha", 0.6)) + scale_color_manual(values = colors, name = "") + geom_text(data = do.call(rbind,
        ticks), aes(x, y, label = label), size = num("label_size", 2.8), color = "#526577") + facet_wrap(~metric,
        ncol = max(1, as.integer(num("ncol", 3)))) + coord_fixed(xlim = c(-extent, extent), ylim = c(-extent,
        extent)) + oc_theme(TRUE)
    if (length(selected)) {
        highlight <- d[d$id %in% selected, ]
        if (!nrow(highlight))
            log_msg("No highlight_ids matched the supplied id column.")
        p <- p + geom_segment(data = highlight, aes(x = 0, y = 0, xend = x, yend = y), color = chr("highlight_color",
            "#D74855"), linewidth = num("line_width", 0.6), arrow = grid::arrow(length = grid::unit(0.07,
            "inches"))) + geom_point(data = highlight, aes(x, y), size = num("point_size", 2) * 1.6,
            color = chr("highlight_color", "#D74855"))
    }
    oc_result(p, d, list(method = "linear_score_to_angle", range_mode = chr("range_mode", "free"), gap_angle = num("gap_angle",
        60), highlights = selected), note = "Angle encodes numeric score; concentric rings encode groups; point count is not an angle or area scale")
}
