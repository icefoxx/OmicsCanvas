draw_plot <- function(df) {
    x_col <- oc_col(df, "x_column", "x")
    y_col <- oc_col(df, "y_column", "y")
    value_col <- oc_col(df, "value_column", "count")
    raw <- data.frame(x = as.character(df[[x_col]]), y = as.character(df[[y_col]]), value = oc_numeric(df,
        value_col, TRUE), group = oc_group(df))
    if (anyNA(raw$x) || anyNA(raw$y) || anyDuplicated(raw[c("x", "y", "group")]))
        stop("Supply one nonmissing count per X/Y/group grid position.")
    if (length(unique(raw$x)) > 15 || length(unique(raw$y)) > 15)
        stop("Use at most 15 \u00d7 15 grid positions per panel.")
    colors <- oc_colors(raw$group)
    az <- num("azimuth", 40)
    el <- num("elevation", 25)
    xl <- unique(raw$x)
    yl <- unique(raw$y)
    polygons <- list()
    text <- list()
    for (group in names(colors)) {
        d <- raw[raw$group == group, ]
        zmax <- if (chr("z_scale", "shared") == "shared")
            max(raw$value) else max(d$value)
        if (zmax == 0)
            zmax <- 1
        # Heights share one scale across facets unless free scaling is explicitly chosen.
        height <- max(length(xl), length(yl)) * 0.8
        d$depth <- match(d$x, xl) * sin(az * pi/180) + match(d$y, yl) * cos(az * pi/180)
        d <- d[order(-d$depth), ]
        for (i in seq_len(nrow(d))) {
            x <- match(d$x[i], xl)
            y <- match(d$y[i], yl)
            z <- d$value[i]/zmax * height
            w <- num("bar_width", 0.72)/2
            vertices <- rbind(c(x - w, y - w, 0), c(x + w, y - w, 0), c(x + w, y + w, 0), c(x - w, y +
                w, 0), c(x - w, y - w, z), c(x + w, y - w, z), c(x + w, y + w, z), c(x - w, y + w, z))
            faces <- list(c(1, 2, 6, 5), c(2, 3, 7, 6), c(5, 6, 7, 8))
            rgb <- grDevices::col2rgb(colors[[group]])/255
            shades <- c(0.72, 0.9, 1)
            for (j in seq_along(faces)) {
                v <- vertices[faces[[j]], , drop = FALSE]
                xy <- oc_project(v[, 1], v[, 2], v[, 3], az, el)
                hex <- grDevices::rgb(rgb[1] * shades[j], rgb[2] * shades[j], rgb[3] * shades[j])
                polygons[[length(polygons) + 1]] <- data.frame(x = xy$px, y = xy$py, id = length(polygons) +
                  1, fill = hex, group = group)
            }
        }
        axis_x <- oc_project(seq_along(xl), rep(0.35, length(xl)), 0, az, el)
        axis_y <- oc_project(rep(0.35, length(yl)), seq_along(yl), 0, az, el)
        text[[length(text) + 1]] <- data.frame(x = c(axis_x$px, axis_y$px), y = c(axis_x$py, axis_y$py),
            label = c(xl, yl), group = group)
    }
    polygons <- do.call(rbind, polygons)
    text <- do.call(rbind, text)
    p <- ggplot(polygons, aes(x, y, group = id, fill = fill)) + geom_polygon(color = "#FFFFFF", linewidth = num("line_width",
        0.6)) + scale_fill_identity() + geom_text(data = text, aes(x, y, label = label), inherit.aes = FALSE,
        color = "#4C6272", size = num("label_size", 2.8), vjust = 1.3) + facet_wrap(~group, ncol = as.integer(num("ncol",
        3))) + coord_fixed() + oc_theme(TRUE) + scale_x_continuous(expand = expansion(mult = 0.12)) +
        scale_y_continuous(expand = expansion(mult = 0.12))
    oc_result(p, raw, list(method = "supplied_grid_heights", height_scale = chr("z_scale", "shared"),
        global_maximum = max(raw$value), azimuth = az, elevation = el), list(projected_faces_used.csv = polygons),
        sprintf("Height encodes %s; maximum %s; %s scale across panels", value_col, oc_pretty(max(raw$value)),
            chr("z_scale", "shared")))
}
