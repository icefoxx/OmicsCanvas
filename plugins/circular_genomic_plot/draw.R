draw_plot <- function(df) {
    chr_col <- oc_col(df, "chromosome_column", "chromosome")
    start_col <- oc_col(df, "start_column", "start")
    end_col <- oc_col(df, "end_column", "end")
    value_col <- oc_col(df, "value_column", "value")
    d <- data.frame(chromosome = as.character(df[[chr_col]]), start = oc_numeric(df, start_col, TRUE),
        end = oc_numeric(df, end_col, TRUE), value = oc_numeric(df, value_col), track = oc_group(df,
            "group_column", "track"))
    if (anyNA(d$chromosome) || any(!nzchar(d$chromosome)) || any(d$end < d$start))
        stop("Chromosome labels must be nonempty and intervals require 0 <= start <= end.")
    chromosomes <- unique(d$chromosome)
    tracks <- unique(d$track)
    if (length(chromosomes) > 50 || length(tracks) > 8)
        stop("Use at most 50 chromosomes and eight tracks.")
    lengths <- setNames(vapply(chromosomes, function(chrom) max(d$end[d$chromosome == chrom]), numeric(1)),
        chromosomes)
    supplied_lengths <- FALSE
    if (!is.null(opt$chromosomes) && nzchar(opt$chromosomes)) {
        lengths_table <- read_table(opt$chromosomes)
        if (!all(c("chromosome", "length") %in% names(lengths_table)) || anyDuplicated(lengths_table$chromosome))
            stop("Chromosome table requires unique chromosome labels and numeric length.")
        numeric_lengths <- oc_numeric(lengths_table, "length", TRUE)
        if (any(!chromosomes %in% lengths_table$chromosome))
            stop("Chromosome length table is missing a chromosome from the interval table.")
        lengths <- setNames(numeric_lengths[match(chromosomes, lengths_table$chromosome)], chromosomes)
        supplied_lengths <- TRUE
    }
    if (any(lengths <= 0) || any(d$end > lengths[d$chromosome]))
        stop("Chromosome lengths must be positive and cover all interval endpoints.")
    gap <- num("gap_angle", 2) * pi/180
    if (gap <= 0 || gap * length(chromosomes) >= pi)
        stop("Reduce gap_angle so all chromosome gaps together occupy less than 180 degrees.")
    spans <- lengths/sum(lengths) * (2 * pi - gap * length(chromosomes))
    origins <- c(0, head(cumsum(spans + gap), -1)) + pi/2
    names(origins) <- names(spans) <- chromosomes
    angle <- function(chromosome, position) origins[chromosome] + position/lengths[chromosome] * spans[chromosome]
    xy <- function(a, r) data.frame(x = cos(a) * r, y = sin(a) * r)
    links <- NULL
    if (!is.null(opt$links) && nzchar(opt$links)) {
        links <- read_table(opt$links)
        if (!all(c("source_chr", "source_pos", "target_chr", "target_pos") %in% names(links)))
            stop("Links table requires source_chr, source_pos, target_chr and target_pos.")
        links$source_pos <- oc_numeric(links, "source_pos", TRUE)
        links$target_pos <- oc_numeric(links, "target_pos", TRUE)
        if (any(!links$source_chr %in% chromosomes) || any(!links$target_chr %in% chromosomes))
            stop("Link chromosomes must exist in the interval table.")
        if (any(links$source_pos > lengths[links$source_chr] | links$target_pos > lengths[links$target_chr]))
            stop("Link positions exceed their chromosome lengths.")
    }
    layout <- chr("layout", "circular")
    type <- chr("track_type", "heatmap")
    if (layout == "linear") {
        d$x <- match(d$chromosome, chromosomes)
        # Track offsets share chromosome coordinates without mixing position units.
        d$x <- d$x + (match(d$track, tracks) - (length(tracks) + 1)/2) * 0.65/length(tracks)
        p <- ggplot(d) + geom_rect(aes(xmin = x - 0.28/length(tracks), xmax = x + 0.28/length(tracks),
            ymin = start, ymax = end, fill = value), color = NA) + scale_x_continuous(breaks = seq_along(chromosomes),
            labels = chromosomes) + oc_labels("Chromosome", "Genomic coordinate") + oc_theme()
        if (flag("link_show", TRUE) && !is.null(links)) {
            links$x <- match(links$source_chr, chromosomes)
            links$xend <- match(links$target_chr, chromosomes)
            p <- p + geom_curve(data = links, aes(x = x, xend = xend, y = source_pos, yend = target_pos),
                inherit.aes = FALSE, color = chr("link_color", "#627D96"), linewidth = num("line_width",
                  0.6), curvature = 0.15, alpha = num("link_alpha", 0.4))
        }
    } else {
        chr_colors <- oc_colors(chromosomes)
        p <- ggplot()
        chromosome_labels <- list()
        for (chrom in chromosomes) {
            a <- seq(origins[chrom], origins[chrom] + spans[chrom], length.out = max(6, ceiling(spans[chrom] *
                100)))
            wedge <- rbind(xy(a, 1), xy(rev(a), 1.06))
            p <- p + geom_polygon(data = wedge, aes(x, y), fill = chr_colors[[chrom]], color = NA)
            chromosome_labels[[chrom]] <- cbind(xy(origins[chrom] + spans[chrom]/2, 1.14), label = chrom)
        }
        track_width <- 0.72/length(tracks)
        polygons <- list()
        points <- list()
        for (i in seq_len(nrow(d))) {
            a <- seq(angle(d$chromosome[i], d$start[i]), angle(d$chromosome[i], d$end[i]), length.out = 8)
            ti <- match(d$track[i], tracks)
            bottom <- 0.2 + (ti - 1) * track_width
            values <- d$value[d$track == d$track[i]]
            limits <- range(c(0, values))
            span <- diff(limits)
            if (!span)
                span <- 1
            if (type == "heatmap") {
                lo <- bottom
                hi <- bottom + track_width * 0.88
            } else {
                lo <- bottom + (0 - limits[1])/span * track_width * 0.88
                hi <- bottom + (d$value[i] - limits[1])/span * track_width * 0.88
            }
            polygons[[i]] <- cbind(rbind(xy(a, lo), xy(rev(a), hi)), id = i, value = d$value[i])
            points[[i]] <- cbind(xy(mean(a), hi), value = d$value[i])
        }
        if (type == "point")
            p <- p + geom_point(data = do.call(rbind, points), aes(x, y, fill = value), shape = 21, color = '#FFFFFF', stroke = .1,
                size = num("point_size", 2)) else p <- p + geom_polygon(data = do.call(rbind, polygons), aes(x, y, group = id, fill = value),
            color = NA)
        p <- p + geom_text(data = do.call(rbind, chromosome_labels), aes(x, y, label = label), size = num("label_size",
            2.8), family = chr("font_family", "sans"), color = "#4A6071") + coord_fixed(xlim = c(-1.32,
            1.32), ylim = c(-1.32, 1.32)) + oc_theme(TRUE)
        if (flag("link_show", TRUE) && !is.null(links)) {
            paths <- list()
            for (i in seq_len(nrow(links))) {
                a <- xy(angle(links$source_chr[i], links$source_pos[i]), 0.19)
                b <- xy(angle(links$target_chr[i], links$target_pos[i]), 0.19)
                t <- seq(0, 1, length.out = 40)
                paths[[i]] <- data.frame(x = (1 - t)^2 * a$x + t^2 * b$x, y = (1 - t)^2 * a$y + t^2 *
                  b$y, id = i)
            }
            if (length(paths))
                p <- p + geom_path(data = do.call(rbind, paths), aes(x, y, group = id), color = chr("link_color",
                  "#627D96"), linewidth = num("line_width", 0.6), alpha = num("link_alpha", 0.4))
        }
    }
    p <- p + scale_fill_gradient2(low = chr("low_color", "#397DA3"), mid = "#F4F6F7", high = chr("high_color",
        "#CD5865"), midpoint = 0, name = or_auto(chr("legend_title"), value_col))
    oc_result(p, d, list(method = "supplied_genomic_intervals", coordinate_convention = "0-based, half-open intervals; no automatic conversion",
        layout = layout, track_type = type, lengths_supplied = supplied_lengths), c(list(chromosome_lengths_used.csv = data.frame(chromosome = names(lengths),
        length = as.numeric(lengths))), if (!is.null(links)) list(links_used.csv = links) else list()),
        if (supplied_lengths)
            paste0("Supplied chromosome lengths; tracks (inner to outer / left to right): ", paste(tracks, collapse = " / ")) else "Chromosome extents inferred from maximum supplied interval ends; not a complete genome assembly")
}
