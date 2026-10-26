draw_plot <- function(df) {
    time_col <- oc_col(df, "time_column", "time")
    event_col <- oc_col(df, "event_column", "event")
    d <- data.frame(time = oc_numeric(df, time_col, TRUE), event = oc_numeric(df, event_col), group = oc_group(df))
    if (any(!d$event %in% c(0, 1)))
        stop("event_column must use 0 = right-censored and 1 = event. Competing risks and left/interval censoring are not supported.")
    level <- num("confidence_level", 0.95)
    if (level <= 0 || level >= 1)
        stop("confidence_level must be between 0 and 1.")
    colors <- oc_colors(d$group)
    fits <- list()
    curves <- list()
    risks <- list()
    counts <- list()
    times <- pretty(c(0, max(d$time)), n = max(2, num("risk_time_count", 6)))
    times <- times[times >= 0 & times <= max(d$time)]
    landmark <- num("landmark_time", 0)
    if (landmark < 0 || landmark >= max(d$time))
        stop("landmark_time must be nonnegative and earlier than the last observed time.")
    for (group in names(colors)) {
        g <- d[d$group == group, , drop = FALSE]
        # Conditioning on survival beyond the landmark uses subjects still observed then.
        if (landmark > 0)
            g <- g[g$time > landmark, , drop = FALSE]
        if (!nrow(g))
            stop(paste("No observations remain beyond landmark_time for", group))
        fit <- survival::survfit(survival::Surv(time, event) ~ 1, data = g, conf.int = level, conf.type = "log-log")
        fits[[group]] <- fit
        curve <- data.frame(time = c(landmark, fit$time), survival = c(1, fit$surv), lower = c(1, fit$lower),
            upper = c(1, fit$upper), censored = c(0, fit$n.censor), group = group)
        curves[[group]] <- curve
        tt <- times[times >= landmark]
        risks[[group]] <- data.frame(time = tt, at_risk = vapply(tt, function(t) sum(g$time >= t), integer(1)),
            group = group)
        counts[[group]] <- data.frame(group = group, n = nrow(g), events = sum(g$event), censored = sum(g$event ==
            0))
    }
    curves <- do.call(rbind, curves)
    risks <- do.call(rbind, risks)
    step <- chr("curve_type", "survival")
    if (step == "event_probability") {
        curves$survival <- 1 - curves$survival
        lower <- 1 - curves$upper
        curves$upper <- 1 - curves$lower
        curves$lower <- lower
    }
    p <- ggplot(curves, aes(time, survival, color = group, group = group))
    if (flag("confidence_show", TRUE)) {
        # Duplicate event-time rows to make confidence bands stepwise, matching KM.
        ribbons <- do.call(rbind, lapply(split(curves, curves$group), function(g) {
            if (nrow(g) < 2)
                return(g)
            idx <- head(rep(seq_len(nrow(g)), each = 2), -1)
            h <- g[idx, , drop = FALSE]
            h$time <- c(g$time[1], rep(g$time[-1], each = 2))
            h
        }))
        p <- p + geom_ribbon(data = ribbons, aes(ymin = lower, ymax = upper, fill = group), alpha = num("confidence_alpha",
            0.16), color = NA)
    }
    p <- p + geom_step(linewidth = num("line_width", 0.6), direction = "hv")
    if (flag("censor_show", TRUE))
        p <- p + geom_point(data = curves[curves$censored > 0, ], shape = 3, size = num("point_size",
            2))
    method <- chr("stat_method", "none")
    stat <- list(method = method, confidence_level = level, confidence_type = "log-log", landmark_time = landmark,
        outcome = step)
    if (method == "logrank") {
        tested <- d[d$time > landmark, , drop = FALSE]
        if (length(unique(tested$group)) < 2 || sum(tested$event) < 1)
            stop("Log-rank requires at least two groups and at least one observed event.")
        test <- survival::survdiff(survival::Surv(time, event) ~ group, data = tested)
        stat$pvalue <- pchisq(test$chisq, length(test$n) - 1, lower.tail = FALSE)
        p <- p + annotate("text", x = -Inf, y = 0.08, label = paste("Log-rank p", format.pval(stat$pvalue,
            digits = 3, eps = 1e-04)), hjust = -0.05, size = 3)
    }
    p <- p + scale_color_manual(values = colors, name = "") + scale_fill_manual(values = colors, name = "") +
        scale_x_continuous(limits = c(landmark, max(d$time)), breaks = times, expand = expansion(mult = .03)) +
        scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.2)) + oc_labels(time_col, if (step ==
        "survival")
        "Survival probability" else "Event probability (1 \u2212 KM)") + oc_theme()
    if (flag("risk_table_show", TRUE)) {
        risk_p <- ggplot(risks, aes(time, factor(group, levels = rev(names(colors))), label = at_risk,
            color = group)) + geom_text(size = num("risk_text_size", 3)) + scale_color_manual(values = colors, guide = 'none') +
            scale_x_continuous(limits = c(landmark, max(d$time)), breaks = times, expand = expansion(mult = .03)) +
            labs(x = time_col, y = "At risk") + oc_theme() + theme(legend.position = "none", axis.line = element_blank(),
            axis.ticks = element_blank())
        p <- patchwork::wrap_plots(p, risk_p, ncol = 1, heights = c(4, max(0.8, length(colors) * 0.25)))
    }
    oc_result(p, curves, stat, list(risk_table_used.csv = risks, group_counts_used.csv = do.call(rbind,
        counts)), sprintf("%d eligible observations; right-censored Kaplan\u2013Meier%s", sum(vapply(counts, function(g) g$n, numeric(1))), if (landmark >
        0)
        paste0("; conditional on follow-up beyond ", landmark) else ""))
}
