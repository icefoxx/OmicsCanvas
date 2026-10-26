draw_plot <- function(df) {
    mode <- chr("plot_type", "roc")
    input_mode <- chr("input_mode", "predictions")
    if (input_mode == "curve") {
        x <- oc_numeric(df, oc_col(df, "x_column", "x"), probability = mode %in% c("roc", "precision_recall",
            "calibration"))
        y <- oc_numeric(df, oc_col(df, "y_column", "y"), probability = mode %in% c("roc", "precision_recall",
            "calibration"))
        d <- data.frame(x = x, y = y, group = oc_group(df))
        p <- ggplot(d, aes(x, y, color = group)) + geom_path(linewidth = num("line_width", 0.6))
        metrics <- list(input_mode = input_mode, method = "supplied_curve", mode = mode)
    } else {
        outcome_col <- oc_col(df, "outcome_column", "outcome")
        score_col <- oc_col(df, "score_column", "score")
        outcomes <- as.character(df[[outcome_col]])
        if (anyNA(outcomes) || any(!nzchar(outcomes)) || length(unique(outcomes)) != 2)
            stop("outcome_column must contain exactly two nonmissing classes.")
        positive <- or_auto(chr("positive_class"), "1")
        if (!positive %in% outcomes)
            stop("positive_class is not present in outcome_column.")
        raw <- data.frame(score = oc_numeric(df, score_col, probability = mode %in% c("calibration",
            "decision_curve")), outcome = as.integer(outcomes == positive), group = oc_group(df))
        curves <- list()
        metric_rows <- list()
        for (group in sort(unique(raw$group))) {
            g <- raw[raw$group == group, ]
            positives <- sum(g$outcome)
            negatives <- nrow(g) - positives
            if (!positives || !negatives)
                stop(paste("Both outcome classes are required in model/group", group))
            if (mode %in% c("roc", "precision_recall")) {
                g <- g[order(-g$score), ]
                ends <- cumsum(rle(g$score)$lengths)
                tp <- cumsum(g$outcome)[ends]
                fp <- ends - tp
                recall <- c(0, tp/positives)
                fpr <- c(0, fp/negatives)
                precision <- c(1, tp/(tp + fp))
                auc <- sum(diff(fpr) * (head(recall, -1) + tail(recall, -1))/2)
                ap <- sum(diff(recall) * tail(precision, -1))
                curve <- data.frame(x = if (mode == "roc")
                  fpr else recall, y = if (mode == "roc")
                  recall else precision, threshold = c(Inf, g$score[ends]), group = group)
                metric_rows[[group]] <- data.frame(group = group, auc = auc, average_precision = ap,
                  prevalence = positives/nrow(g), n = nrow(g))
            } else if (mode == "calibration") {
                bins <- max(2, as.integer(num("calibration_bins", 8)))
                # Equal-width probability bins keep identical predictions together.
                g$bin <- cut(g$score, breaks = seq(0, 1, length.out = bins + 1), include.lowest = TRUE,
                  labels = FALSE)
                curve <- do.call(rbind, lapply(split(g, g$bin), function(bin) data.frame(x = mean(bin$score),
                  y = mean(bin$outcome), n = nrow(bin), group = group)))
                metric_rows[[group]] <- data.frame(group = group, brier_score = mean((g$score - g$outcome)^2),
                  n = nrow(g))
            } else if (mode == "decision_curve") {
                lo <- num("threshold_min", 0.01)
                hi <- num("threshold_max", 0.8)
                if (lo <= 0 || hi >= 1 || lo >= hi)
                  stop("Decision thresholds require 0 < threshold_min < threshold_max < 1.")
                thresholds <- seq(lo, hi, length.out = 100)
                curve <- data.frame(x = thresholds, y = vapply(thresholds, function(t) {
                  selected <- g$score >= t
                  (sum(selected & g$outcome == 1) - sum(selected & g$outcome == 0) * t/(1 - t))/nrow(g)
                }, numeric(1)), group = group)
                prevalence <- mean(g$outcome)
                # Per-model baselines use exactly the same observations as that model.
                curves[[paste0(group, ": treat all")]] <- data.frame(x = thresholds, y = prevalence -
                  (1 - prevalence) * thresholds/(1 - thresholds), group = paste0(group, ": treat all"))
                metric_rows[[group]] <- data.frame(group = group, prevalence = prevalence, n = nrow(g))
            } else stop("Unknown plot_type.")
            curves[[group]] <- curve
        }
        # Curves carry different optional diagnostic columns; preserve the union.
        columns <- unique(unlist(lapply(curves, names)))
        curves <- lapply(curves, function(curve) {
            for (col in setdiff(columns, names(curve))) curve[[col]] <- NA
            curve[columns]
        })
        d <- do.call(rbind, curves)
        p <- ggplot(d, aes(x, y, color = group))
        if (mode %in% c("roc", "precision_recall"))
            p <- p + geom_path(linewidth = num("line_width", 0.6)) else p <- p + geom_line(linewidth = num("line_width", 0.6))
        if (mode == "calibration")
            p <- p + geom_point(size = num("point_size", 2))
        metrics <- list(input_mode = input_mode, mode = mode, positive_class = positive, score_direction = "higher_is_positive",
            method = "empirical; tied scores grouped; no model fitting")
    }
    if (mode %in% c("roc", "calibration"))
        p <- p + geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "#A6ADB5")
    if (mode == "decision_curve")
        p <- p + geom_hline(yintercept = 0, linetype = "dashed", color = "#667580")
    labels <- switch(mode, roc = c("False positive rate", "True positive rate"), precision_recall = c("Recall",
        "Precision"), calibration = c("Predicted probability", "Observed event proportion"), decision_curve = c("Threshold probability",
        "Net benefit"))
    if (mode != "decision_curve")
        p <- p + coord_cartesian(xlim = c(0, 1), ylim = c(0, 1))
    colors <- oc_colors(d$group)
    legend_labels <- setNames(names(colors), names(colors))
    if (input_mode == "predictions" && flag("metric_show", TRUE) && mode != "decision_curve") {
        performance <- do.call(rbind, metric_rows)
        for (i in seq_len(nrow(performance))) {
            value <- if (mode == "roc") performance$auc[i] else if (mode == "precision_recall") performance$average_precision[i] else performance$brier_score[i]
            label <- if (mode == "roc") "AUC" else if (mode == "precision_recall") "AP" else "Brier"
            legend_labels[performance$group[i]] <- sprintf("%s (%s %.3f)", performance$group[i], label, value)
        }
        metrics$performance <- performance
    }
    display_limits <- lapply(c("x_limits", "y_limits"), function(key) {
        values <- suppressWarnings(as.numeric(unlist(param(key))))
        if (!length(values)) return(NULL)
        if (length(values) != 2 || any(!is.finite(values)) || values[1] >= values[2]) stop(paste(key, "must contain two finite increasing numbers."))
        values
    })
    if (any(vapply(display_limits, length, integer(1)) > 0)) p <- p + coord_cartesian(xlim = display_limits[[1]], ylim = display_limits[[2]])
    metrics$display_limits <- list(x = display_limits[[1]], y = display_limits[[2]])
    p <- p + scale_color_manual(values = colors, labels = legend_labels, name = "") + oc_labels(labels[1], labels[2]) + oc_theme()
    tables <- if (input_mode == "predictions")
        list(metrics_used.csv = do.call(rbind, metric_rows)) else list()
    oc_result(p, d, metrics, tables, if (input_mode == "curve")
        "Supplied curve coordinates; no inference from censored outcomes" else "Evaluation of supplied predictions; no training or automatic score reversal")
}
