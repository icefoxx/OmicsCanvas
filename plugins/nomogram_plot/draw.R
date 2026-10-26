draw_plot <- function(df) {
    scale_col <- oc_col(df, "group_column", "scale")
    position_col <- oc_col(df, "position_column", "position")
    label_col <- oc_col(df, "label_column", "label")
    d <- data.frame(scale = as.character(df[[scale_col]]), position = oc_numeric(df, position_col, probability = TRUE),
        label = as.character(df[[label_col]]))
    if (anyNA(d$scale) || any(!nzchar(d$scale)) || anyNA(d$label))
        stop("Scale names and tick labels must be nonmissing.")
    scales <- unique(d$scale)
    if (length(scales) > 15)
        stop("Use at most 15 nomogram scales for readability.")
    if (anyDuplicated(d[c("scale", "position")]))
        stop("Tick positions must be unique within each scale.")
    d$y <- match(d$scale, rev(scales))
    ranges <- data.frame(scale = scales, y = match(scales, rev(scales)), xmin = vapply(scales, function(s) min(d$position[d$scale ==
        s]), numeric(1)), xmax = vapply(scales, function(s) max(d$position[d$scale == s]), numeric(1)))
    p <- ggplot() + geom_segment(data = ranges, aes(x = xmin, xend = xmax, y = y, yend = y), color = chr("line_color",
        "#405368"), linewidth = num("line_width", 0.6)) + geom_segment(data = d, aes(x = position, xend = position,
        y = y - 0.055, yend = y + 0.055), color = chr("line_color", "#405368"), linewidth = num("line_width",
        0.6)) + geom_text(data = ranges, aes(x = -0.035, y = y, label = scale), hjust = 1, size = num("label_size",
        2.8), color = "#273B4B", family = chr("font_family", "sans")) + coord_cartesian(xlim = c(-min(0.8,
        max(nchar(scales)) * 0.015), 1.08), ylim = c(0.5, length(scales) + 0.7)) + oc_theme(TRUE)
    if (flag("label_show", TRUE))
        p <- p + geom_text(data = d, aes(position, y - 0.22, label = label), size = num("label_size",
            2.8), family = chr("font_family", "sans"), color = "#405368")
    oc_result(p, d, list(method = "supplied_nomogram_scales", position_units = "0\u20131 relative position on each supplied scale"),
        note = "Supplied point/outcome scales; no regression fitted and no patient risk calculated")
}
