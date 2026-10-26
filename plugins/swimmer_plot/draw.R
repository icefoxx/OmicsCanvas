draw_plot <- function(df) {
    id_col <- oc_col(df, "id_column", "subject")
    start_col <- oc_col(df, "start_column", "start")
    end_col <- oc_col(df, "end_column", "end")
    d <- data.frame(subject = as.character(df[[id_col]]), start = oc_numeric(df, start_col), end = oc_numeric(df,
        end_col), group = oc_group(df))
    if (anyNA(d$subject) || any(!nzchar(d$subject)) || anyDuplicated(d$subject))
        stop("Supply one interval per unique subject. Encode additional events in the optional events table.")
    if (any(d$end < d$start))
        stop("Every interval requires end >= start.")
    order <- if (chr("sort_by", "duration") == "duration")
        d$subject[order(d$end - d$start)] else rev(d$subject)
    d$row <- factor(d$subject, levels = order)
    colors <- oc_colors(d$group)
    p <- ggplot(d, aes(y = row, color = group)) + geom_segment(aes(x = start, xend = end, yend = row),
        linewidth = num("bar_width", 3), lineend = "butt") + scale_color_manual(values = colors, name = "") +
        oc_labels("Time", "Subject") + oc_theme()
    if (flag("end_marker_show", TRUE))
        p <- p + geom_point(aes(x = end), shape = 15, size = num("point_size", 2))
    events <- NULL
    if (!is.null(opt$events) && nzchar(opt$events)) {
        events <- read_table(opt$events)
        needed <- c("subject", "time", "event")
        if (length(setdiff(needed, names(events))))
            stop("Events table requires subject, time and event columns.")
        events$time <- oc_numeric(events, "time")
        if (any(!events$subject %in% d$subject))
            stop("An events-table subject has no observation interval.")
        linked <- match(events$subject, d$subject)
        if (any(events$time < d$start[linked] | events$time > d$end[linked]))
            stop("Each event must lie within its subject interval.")
        if (length(unique(events$event)) > 6)
            stop("Use at most six event categories for distinct marker shapes.")
        events$row <- factor(events$subject, levels = order)
        p <- p + geom_point(data = events, aes(x = time, y = row, shape = event), inherit.aes = FALSE,
            color = "#24394A", fill = "#FFFFFF", size = num("event_size", 3)) + scale_shape_manual(values = c(21,
            24, 22, 23, 25, 8), name = "Event")
    }
    oc_result(p, d, list(method = "supplied_intervals_events"), if (!is.null(events))
        list(events_used.csv = events) else list(), "Observed intervals and supplied events; endpoint markers do not imply censoring status")
}
