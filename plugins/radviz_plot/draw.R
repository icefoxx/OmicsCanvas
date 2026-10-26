draw_plot <- function(df) {
    features <- chr_vec("feature_columns")
    if (length(features) < 3 || length(features) > 12 || length(setdiff(features, names(df))))
        stop("Choose 3\u201312 existing numeric feature_columns in the desired wheel order.")
    values <- vapply(features, function(col) oc_numeric(df, col), numeric(nrow(df)))
    normalization <- chr("normalization", "row_sum")
    if (normalization == "feature_minmax") {
        lower <- apply(values, 2, min)
        spread <- apply(values, 2, function(x) diff(range(x)))
        spread[spread == 0] <- 1
        values <- sweep(sweep(values, 2, lower, "-"), 2, spread, "/")
    } else if (any(values < 0))
        stop("Row-sum wheel projection requires nonnegative feature weights. Use feature_minmax explicitly if appropriate.")
    valid <- rowSums(values) > 0
    if (any(!valid))
        log_msg(sprintf("Dropped %d rows with zero total wheel weight.", sum(!valid)))
    if (!any(valid))
        stop("All rows have zero total feature weight.")
    values <- values[valid, , drop = FALSE]/rowSums(values[valid, , drop = FALSE])
    angle <- pi/2 - 2 * pi * (seq_along(features) - 1)/length(features)
    vertices <- data.frame(x = cos(angle), y = sin(angle), label = features)
    points <- data.frame(x = as.numeric(values %*% vertices$x), y = as.numeric(values %*% vertices$y),
        group = oc_group(df)[valid])
    p <- ggplot() + geom_polygon(data = vertices, aes(x, y), fill = "#F6F8FA", color = "#BCC7CF", linewidth = num("line_width",
        0.6))
    if (flag("spoke_show", TRUE))
        p <- p + geom_segment(data = vertices, aes(x = 0, y = 0, xend = x, yend = y), color = "#CFD7DE",
            linewidth = num("line_width", 0.6))
    p <- p + geom_point(data = points, aes(x, y, color = group), size = num("point_size", 2), alpha = num("point_alpha",
        0.75)) + scale_color_manual(values = oc_colors(points$group), name = "") + geom_text(data = vertices,
        aes(x * 1.12, y * 1.12, label = label), size = num("label_size", 2.8), family = chr("font_family",
            "sans")) + coord_fixed(xlim = c(-1.4, 1.4), ylim = c(-1.3, 1.3)) + oc_theme(TRUE)
    oc_result(p, points, list(method = "weighted_vertex_projection", feature_order = features, normalization = normalization,
        dropped_zero_weight = sum(!valid)), list(vertices_used.csv = vertices), "Nonnegative normalized weights pull observations toward labeled vertices; no inferred trajectory")
}
