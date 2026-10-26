draw_plot <- function(df) {
    parent_col <- oc_col(df, "parent_column", "parent")
    child_col <- oc_col(df, "child_column", "child")
    length_col <- oc_col(df, "length_column", "length")
    edges <- data.frame(parent = as.character(df[[parent_col]]), child = as.character(df[[child_col]]),
        length = oc_numeric(df, length_col, TRUE), group = oc_group(df))
    if (anyNA(edges$parent) || anyNA(edges$child) || any(!nzchar(edges$parent)) || any(!nzchar(edges$child)) ||
        anyDuplicated(edges$child) || any(edges$parent == edges$child))
        stop("Tree edges need nonempty labels, one parent per child, and no self-loops.")
    roots <- setdiff(edges$parent, edges$child)
    if (length(roots) != 1)
        stop("Supply one connected rooted tree with exactly one root.")
    nodes <- unique(c(edges$parent, edges$child))
    leaves <- setdiff(edges$child, edges$parent)
    if (length(leaves) < 2 || length(leaves) > 100)
        stop("Use 2\u2013100 terminal leaves.")
    descendants <- list()
    depths <- setNames(rep(NA_real_, length(nodes)), nodes)
    depths[roots] <- 0
    visit <- function(node, seen = character()) {
        if (node %in% seen)
            stop("The tree contains a cycle.")
        children <- edges$child[edges$parent == node]
        if (!length(children)) {
            descendants[[node]] <<- node
            return(node)
        }
        desc <- character()
        for (child in children) {
            depths[child] <<- depths[node] + edges$length[match(child, edges$child)]
            desc <- c(desc, visit(child, c(seen, node)))
        }
        descendants[[node]] <<- desc
        desc
    }
    leaves <- visit(roots)
    if (length(descendants) != length(nodes))
        stop("Tree contains disconnected nodes or a disconnected cycle.")
    positions <- setNames(vapply(nodes, function(node) mean(match(descendants[[node]], leaves)), numeric(1)),
        nodes)
    annotations <- NULL
    if (!is.null(opt$annot) && nzchar(opt$annot)) {
        annotations <- read_table(opt$annot)
        if (!"node" %in% names(annotations) || anyDuplicated(annotations$node))
            stop("Annotation table needs a unique node column, plus optional numeric feature columns.")
        if (length(setdiff(leaves, annotations$node)))
            stop("Annotation table is missing tree leaves.")
    }
    size_col <- oc_col(df, "size_column", "size", FALSE)
    points <- data.frame(node = edges$child, depth = as.numeric(depths[edges$child]), position = as.numeric(positions[edges$child]),
        group = edges$group, size = if (is.null(size_col))
            1 else oc_numeric(df, size_col, TRUE))
    extent <- max(depths)
    if (extent == 0)
        extent <- 1
    colors <- oc_colors(points$group)
    layout <- chr("layout", "rectangular")
    segments <- data.frame(x = depths[edges$parent], xend = depths[edges$child], y = positions[edges$parent],
        yend = positions[edges$child])
    if (layout == "circular") {
        opening <- num("gap_angle", 20) * pi/180
        angles <- setNames(pi/2 + opening/2 + (seq_along(leaves) - 0.5)/length(leaves) * (2 * pi - opening),
            leaves)
        node_angles <- setNames(vapply(nodes, function(node) mean(angles[descendants[[node]]]), numeric(1)),
            nodes)
        paths <- list()
        for (i in seq_len(nrow(edges))) {
            a <- node_angles[edges$parent[i]]
            b <- node_angles[edges$child[i]]
            r0 <- depths[edges$parent[i]]/extent
            r1 <- depths[edges$child[i]]/extent
            theta <- seq(a, b, length.out = max(2, ceiling(abs(b - a) * 70)))
            paths[[i]] <- data.frame(x = c(r0 * cos(theta), r1 * cos(b)), y = c(r0 * sin(theta), r1 *
                sin(b)), id = i)
        }
        points$x <- points$depth/extent * cos(node_angles[points$node])
        points$y <- points$depth/extent * sin(node_angles[points$node])
        label_data <- data.frame(x = 1.08 * cos(angles), y = 1.08 * sin(angles), label = leaves, angle = (angles *
            180/pi)%%360, hjust = ifelse(cos(angles) < 0, 1, 0))
        label_data$angle[cos(angles) < 0] <- label_data$angle[cos(angles) < 0] + 180
        p <- ggplot(do.call(rbind, paths), aes(x, y, group = id)) + geom_path(color = chr("tree_color",
            "#8CA1AE"), linewidth = num("line_width", 0.6)) + geom_point(data = points, aes(x, y, color = group,
            size = size), inherit.aes = FALSE) + scale_color_manual(values = colors, name = "") + scale_size_area(max_size = num("point_size",
            2), guide = "none") + coord_fixed(xlim = c(-1.55, 1.55), ylim = c(-1.55, 1.55)) + oc_theme(TRUE)
        if (flag("label_show", TRUE))
            p <- p + geom_text(data = label_data, aes(x, y, label = label, angle = angle, hjust = hjust),
                inherit.aes = FALSE, size = num("label_size", 2.8), color = "#42596D")
    } else {
        points$x <- points$depth
        points$y <- points$position
        p <- ggplot() + geom_segment(data = segments, aes(x = x, xend = x, y = y, yend = yend), color = chr("tree_color",
            "#8CA1AE"), linewidth = num("line_width", 0.6)) + geom_segment(data = segments, aes(x = x,
            xend = xend, y = yend, yend = yend), color = chr("tree_color", "#8CA1AE"), linewidth = num("line_width",
            0.6)) + geom_point(data = points, aes(x, y, color = group, size = size)) + scale_color_manual(values = colors,
            name = "") + scale_size_area(max_size = num("point_size", 2), guide = "none") + scale_y_continuous(breaks = seq_along(leaves),
            labels = if (flag("label_show", TRUE))
                leaves else NULL, limits = c(0.5, length(leaves) + 0.5), expand = c(0, 0)) + oc_labels("Supplied branch length",
            "") + oc_theme() + theme(axis.line.y = element_blank(), axis.ticks.y = element_blank(), axis.text.y = element_text(size = num("label_size",
            2.8) * 72.27/25.4))
        if (flag("heatmap_show", TRUE) && !is.null(annotations)) {
            features <- chr_vec("feature_columns")
            if (!length(features))
                features <- setdiff(names(annotations), "node")
            if (length(setdiff(features, names(annotations))))
                stop("feature_columns are missing from the annotation table.")
            heat <- do.call(rbind, lapply(features, function(feature) data.frame(feature = feature, node = annotations$node,
                value = oc_numeric(annotations, feature))))
            heat <- heat[heat$node %in% leaves, ]
            heat$y <- match(heat$node, leaves)
            heat$feature <- factor(heat$feature, levels = features)
            hp <- ggplot(heat, aes(feature, y, fill = value)) + geom_tile(width = 0.95, height = 0.95) +
                scale_fill_gradient2(low = "#3C7FA3", mid = "#F4F6F7", high = "#D76874", midpoint = 0,
                  name = "Feature") + scale_y_continuous(limits = c(0.5, length(leaves) + 0.5), expand = c(0,
                0)) + labs(x = NULL, y = NULL) + oc_theme() + theme(axis.text.y = element_blank(), axis.ticks.y = element_blank(),
                axis.line = element_blank(), axis.text.x = element_text(angle = 45, hjust = 1))
            p <- patchwork::wrap_plots(p, hp, nrow = 1, widths = c(3, max(1, length(features) * 0.35)))
        }
    }
    oc_result(p, points, list(method = "supplied_rooted_weighted_tree", root = roots, layout = layout,
        branch_length = "supplied; no tree inferred"), c(list(tree_edges_used.csv = edges), if (!is.null(annotations)) list(annotation_used.csv = annotations) else list()),
        "Supplied tree topology and branch lengths; feature heatmap is available in rectangular layout")
}
