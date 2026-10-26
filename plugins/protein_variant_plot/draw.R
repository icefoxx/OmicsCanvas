draw_plot <- function(df) {
    position_col <- oc_col(df, "position_column", "position")
    value_col <- oc_col(df, "value_column", "count")
    label_col <- oc_col(df, "label_column", "variant", FALSE)
    d <- data.frame(position = oc_numeric(df, position_col, TRUE), count = oc_numeric(df, value_col,
        TRUE), group = oc_group(df), label = if (is.null(label_col))
        "" else as.character(df[[label_col]]))
    length <- num("protein_length", 0)
    domains <- NULL
    if (!is.null(opt$domains) && nzchar(opt$domains)) {
        domains <- read_table(opt$domains)
        if (any(!c("start", "end", "domain") %in% names(domains)))
            stop("Domains table requires start, end and domain columns.")
        domains$start <- oc_numeric(domains, "start", TRUE)
        domains$end <- oc_numeric(domains, "end", TRUE)
        if (any(domains$end < domains$start))
            stop("Domain end coordinates must be >= start coordinates.")
    }
    if (length <= 0)
        length <- max(c(d$position, if (!is.null(domains)) domains$end)) * 1.05
    if (any(d$position > length) || (!is.null(domains) && any(domains$end > length)))
        stop("protein_length is shorter than supplied positions or domains.")
    if (any(d$position < 1))
        stop("Protein positions use 1-based residue coordinates.")
    band <- max(1, max(d$count)) * 0.12
    p <- ggplot(d, aes(position, count, color = group)) + geom_segment(aes(xend = position, y = 0, yend = count),
        linewidth = num("line_width", 0.6)) + geom_point(size = num("point_size", 2)) + geom_segment(aes(x = 0,
        xend = length, y = 0, yend = 0), inherit.aes = FALSE, color = "#697884", linewidth = 1) + scale_color_manual(values = oc_colors(d$group),
        name = "")
    if (!is.null(domains) && flag("domain_show", TRUE)) {
        domains$ymin <- -band * 1.8
        domains$ymax <- -band * 0.45
        p <- p + geom_rect(data = domains, aes(xmin = start, xmax = end, ymin = ymin, ymax = ymax, fill = domain),
            inherit.aes = FALSE, color = "#FFFFFF") + scale_fill_manual(values = oc_colors(domains$domain),
            name = "Domain")
    }
    if (flag("label_show", TRUE))
        p <- p + ggrepel::geom_text_repel(family = chr("font_family", "sans"), aes(label = label), size = num("label_size",
            2.8), seed = oc_seeds(), max.time = Inf, max.iter = 2000, max.overlaps = 30, show.legend = FALSE)
    p <- p + coord_cartesian(xlim = c(0, length)) + oc_labels("Protein residue position (1-based)", value_col) +
        oc_theme()
    oc_result(p, d, list(method = "supplied_variant_positions", protein_length = length), if (!is.null(domains))
        list(domains_used.csv = domains) else list(), "Variant counts and optional domains; no variant annotation or pathogenicity inference")
}
