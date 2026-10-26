draw_plot <- function(df) {
    x_col <- oc_col(df, "x_column", "x")
    y_col <- oc_col(df, "y_column", "y")
    region_col <- oc_col(df, "group_column", "region")
    value_col <- oc_col(df, "value_column", "value")
    part_col <- oc_col(df, "part_column", "part", FALSE)
    d <- data.frame(x = oc_numeric(df, x_col), y = oc_numeric(df, y_col), region = as.character(df[[region_col]]),
        value = oc_numeric(df, value_col), part = if (is.null(part_col))
            "1" else as.character(df[[part_col]]))
    if (anyNA(d$region) || any(!nzchar(d$region)) || anyNA(d$part))
        stop("Region and polygon-part identifiers must be nonempty.")
    spots <- chr("map_mark", "polygon") == "spot"
    if (!spots) for (region in unique(d$region)) if (length(unique(d$value[d$region == region])) != 1)
        stop("Each region must have one numeric value repeated for its vertices.")
    if (!spots) for (part in split(d, interaction(d$region, d$part, drop = TRUE))) if (nrow(unique(part[c("x", "y")])) <
        3)
        stop("Each polygon part needs at least three distinct ordered vertices.")
    p <- ggplot()
    if (!is.null(opt$image) && nzchar(opt$image)) {
        if (!flag("invert_y", FALSE))
            stop("For a PNG tissue background set invert_y = true and use image pixel coordinates (origin at top left).")
        image <- png::readPNG(opt$image)
        p <- p + annotation_custom(grid::rasterGrob(image, interpolate = TRUE), xmin = 0, xmax = dim(image)[2],
            ymin = 0, ymax = dim(image)[1])
    }
    if (spots) p <- p + geom_point(data = d, aes(x, y, fill = value), shape = 21, color = chr("border_color", "#FFFFFF"), stroke = num("line_width", 0.6), size = num("point_size", 2.5), alpha = num("fill_alpha", 0.85))
    else p <- p + geom_polygon(data = d, aes(x, y, group = region, subgroup = interaction(region, part), fill = value),
        rule = "evenodd", color = chr("border_color", "#FFFFFF"), linewidth = num("line_width", 0.6),
        alpha = num("fill_alpha", 0.85))
    p <- p + scale_fill_gradient(low = chr("low_color", "#EAF1F5"), high = chr("high_color",
        "#315D86"), name = or_auto(chr("legend_title"), value_col)) + coord_fixed() + oc_theme(TRUE)
    if (flag("invert_y", FALSE))
        p <- p + scale_y_reverse()
    if (flag("label_show", FALSE)) {
        centers <- aggregate(cbind(x, y) ~ region, d, mean)
        p <- p + ggrepel::geom_label_repel(family = chr("font_family", "sans"), data = centers, aes(x,
            y, label = region), inherit.aes = FALSE, size = num("label_size", 2.8), seed = oc_seeds(),
            max.time = Inf, max.iter = 2000, max.overlaps = 30, fill = "#FFFFFFCC", label.size = 0)
    }
    oc_result(p, d, list(method = if (spots) "supplied_spatial_spots" else "supplied_ordered_polygon_vertices", fill_rule = "evenodd", invert_y = flag("invert_y",
        FALSE)), note = "Supplied region geometry and measurements; no tissue segmentation or anatomical atlas inference")
}
