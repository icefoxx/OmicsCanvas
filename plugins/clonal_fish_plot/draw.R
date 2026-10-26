draw_plot <- function(df) {
    clone_col <- oc_col(df, "group_column", "clone")
    parent_col <- oc_col(df, "parent_column", "parent")
    time_col <- oc_col(df, "x_column", "time")
    value_col <- oc_col(df, "value_column", "fraction")
    d <- data.frame(clone = as.character(df[[clone_col]]), parent = as.character(df[[parent_col]]), time = oc_numeric(df,
        time_col), fraction = oc_numeric(df, value_col, TRUE))
    if (chr("fraction_unit", "fraction") == "percent")
        d$fraction <- d$fraction/100
    if (any(d$fraction > 1))
        stop("Clone fractions must be in [0,1], or use fraction_unit = percent for percentages.")
    if (anyNA(d$clone) || any(!nzchar(d$clone)) || anyNA(d$parent))
        stop("Clone and parent labels must be nonmissing. Use 0 for a root clone.")
    paths <- unique(d[c("clone", "parent")])
    clones <- unique(paths$clone)
    if (anyDuplicated(paths$clone))
        stop("Each clone must have exactly one parent.")
    if ("0" %in% clones)
        stop("0 is reserved for the virtual root; use another clone identifier.")
    if (any(!paths$parent %in% c("0", clones)))
        stop("Every parent must name an existing clone, or 0 for a root.")
    if (anyDuplicated(d[c("clone", "time")]))
        stop("Supply one fraction per clone and time.")
    depth <- setNames(rep(NA_integer_, length(clones)), clones)
    get_depth <- function(clone, seen = character()) {
        if (clone %in% seen)
            stop("Clone parent relationships contain a cycle.")
        parent <- paths$parent[match(clone, paths$clone)]
        if (parent == "0")
            return(1L)
        1L + get_depth(parent, c(seen, clone))
    }
    for (clone in clones) depth[clone] <- get_depth(clone)
    times <- sort(unique(d$time))
    if (length(times) < 2)
        stop("Supply at least two distinct times.")
    grid <- expand.grid(clone = clones, time = times, stringsAsFactors = FALSE)
    index <- match(paste(grid$clone, grid$time), paste(d$clone, d$time))
    grid$fraction <- d$fraction[index]
    missing <- is.na(index)
    grid$fraction[missing] <- 0
    if (any(missing))
        log_msg(sprintf("%d missing clone/time combinations explicitly filled with zero.", sum(missing)))
    grid$lower <- grid$upper <- NA_real_
    for (time in times) {
        rows <- which(grid$time == time)
        weights <- setNames(grid$fraction[rows], grid$clone[rows])
        children <- function(parent) paths$clone[paths$parent == parent]
        roots <- children("0")
        if (sum(weights[roots]) > 1 + 1e-08)
            stop("Root clone fractions sum above 1 at a time point.")
        place <- function(parent, bottom, available) {
            cs <- children(parent)
            if (!length(cs))
                return(invisible(NULL))
            total <- sum(weights[cs])
            if (total > available + 1e-08)
                stop(paste("Child fractions exceed their inclusive parent fraction for", parent, "at time",
                  time))
            start <- bottom + (available - total)/2
            for (clone in cs) {
                idx <- rows[match(clone, grid$clone[rows])]
                grid$lower[idx] <<- start
                grid$upper[idx] <<- start + weights[clone]
                place(clone, start, weights[clone])
                start <- start + weights[clone]
            }
        }
        place("0", -0.5, 1)
    }
    # Linear interpolation preserves all nesting inequalities between sampled times.
    dense_times <- sort(unique(c(times, seq(min(times), max(times), length.out = 150))))
    curves <- do.call(rbind, lapply(clones[order(depth)], function(clone) {
        g <- grid[grid$clone == clone, ]
        data.frame(time = dense_times, lower = approx(g$time, g$lower, xout = dense_times)$y, upper = approx(g$time,
            g$upper, xout = dense_times)$y, clone = clone)
    }))
    p <- ggplot(curves, aes(time, ymin = lower, ymax = upper, fill = clone, group = clone)) + geom_ribbon(color = "#FFFFFF",
        linewidth = num("line_width", 0.6), alpha = num("fill_alpha", 0.9)) + scale_fill_manual(values = oc_colors(clones),
        name = "Clone") + scale_y_continuous(limits = c(-0.5, 0.5), breaks = NULL) + oc_labels(time_col,
        "Inclusive clone fractions") + oc_theme() + theme(axis.line.y = element_blank(), axis.ticks.y = element_blank())
    if (flag("timepoint_show", TRUE))
        p <- p + geom_vline(xintercept = times, linetype = "dotted", color = "#607080", alpha = 0.4)
    oc_result(p, grid, list(method = "supplied_nested_clone_fractions", nesting = "inclusive parent fractions; linear interpolation",
        units = "fraction"), list(clone_hierarchy_used.csv = paths), "Supplied parent relationships; no clonal evolution inferred from mutations")
}
