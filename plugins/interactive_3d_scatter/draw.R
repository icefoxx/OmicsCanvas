draw_plot <- function(df) {
    cols <- c(oc_col(df, "x_column", "PC1"), oc_col(df, "y_column", "PC2"), oc_col(df, "z_column", "PC3"))
    d <- data.frame(x = oc_numeric(df, cols[1]), y = oc_numeric(df, cols[2]), z = oc_numeric(df, cols[3]),
        group = oc_group(df))
    if (nrow(d) > 50000)
        stop("Use at most 50,000 observations for the 3D widget; downsample explicitly upstream.")
    colors <- oc_colors(d$group)
    az <- num("azimuth", 40)
    el <- num("elevation", 25)
    matrix <- as.matrix(d[c("x", "y", "z")])
    center <- apply(matrix, 2, function(v) mean(range(v)))
    extent <- max(apply(matrix, 2, function(v) diff(range(v))))
    if (extent == 0)
        extent <- 1
    normalized <- sweep(matrix, 2, center, "-")/extent
    projection <- oc_project(normalized[, 1], normalized[, 2], normalized[, 3], az, el)
    d$plot_x <- projection$px
    d$plot_y <- projection$py
    lower <- apply(normalized, 2, min)
    upper <- apply(normalized, 2, max)
    axis <- lapply(seq_len(3), function(i) {
        end <- lower
        end[i] <- upper[i]
        xy <- oc_project(c(lower[1], end[1]), c(lower[2], end[2]), c(lower[3], end[3]), az, el)
        data.frame(x = xy$px[1], y = xy$py[1], xend = xy$px[2], yend = xy$py[2], label = cols[i])
    })
    axes <- do.call(rbind, axis)
    p <- ggplot(d, aes(plot_x, plot_y, color = group)) + geom_point(size = num("point_size", 2), alpha = num("point_alpha",
        0.75)) + geom_segment(data = axes, aes(x, y, xend = xend, yend = yend), inherit.aes = FALSE,
        color = "#6C7E8E", linewidth = num("line_width", 0.6), arrow = grid::arrow(length = grid::unit(0.07,
            "inches"))) + geom_text(data = axes, aes(xend, yend, label = label), inherit.aes = FALSE,
        size = num("label_size", 2.8), vjust = -0.8, color = "#42566B", family = chr("font_family", "sans")) +
        scale_color_manual(values = colors, name = "") + coord_fixed() + oc_theme(TRUE) + scale_x_continuous(expand = expansion(mult = 0.16)) +
        scale_y_continuous(expand = expansion(mult = 0.16))
    text <- htmltools::htmlEscape(d$group)
    widget <- plotly::plot_ly(d, x = ~x, y = ~y, z = ~z, type = "scatter3d", mode = "markers", color = ~group,
        colors = colors, text = text, hovertemplate = "%{text}<br>x=%{x}<br>y=%{y}<br>z=%{z}<extra></extra>",
        marker = list(size = num("point_size", 2) * 2.5, opacity = num("point_alpha", 0.75)))
    legend_position <- chr("legend_position", "right")
    legend <- switch(legend_position,
        left = list(x = 0, xanchor = "right", y = .5, yanchor = "middle"),
        bottom = list(x = .5, xanchor = "center", y = -.08, yanchor = "top", orientation = "h"),
        top = list(x = .5, xanchor = "center", y = 1.05, yanchor = "bottom", orientation = "h"),
        list(x = 1, xanchor = "left", y = .5, yanchor = "middle"))
    legend$font <- list(size = num("legend_text_size", 9))
    widget <- plotly::layout(widget, legend = legend, margin = list(l = 50, r = 60, b = 50, t = 40), showlegend = flag("legend_show", TRUE), paper_bgcolor = chr("plot_background",
        "#FFFFFF"), font = list(family = chr("font_family", "sans"), size = num("base_size", 11)), scene = list(xaxis = list(title = cols[1]),
        yaxis = list(title = cols[2]), zaxis = list(title = cols[3]), aspectmode = "data", camera = list(eye = list(x = 1.8 *
            cos(az * pi/180), y = 1.8 * sin(az * pi/180), z = 1.8 * tan(el * pi/180)))))
    widget <- plotly::config(widget, displaylogo = FALSE, responsive = TRUE)
    htmlwidgets::saveWidget(widget, file.path(out, "result.html"), selfcontained = TRUE)
    oc_result(p, d, list(method = "supplied_3d_coordinates", static_projection = "orthographic; one isotropic coordinate scale",
        azimuth = az, elevation = el), note = "Supplied coordinates; static orthographic projection and rotatable HTML scene; no PCA fitted")
}
