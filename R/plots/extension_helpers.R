# Common data and drawing helpers for independently authored specialty plot engines.  This module
# does not install dependencies, execute external code, or infer models.
oc_numeric <- function(df, col, nonnegative = FALSE, probability = FALSE) {
    v <- suppressWarnings(as.numeric(df[[col]]))
    if (any(!is.finite(v)))
        stop(sprintf("Column %s contains missing or nonnumeric values. Supply finite numeric values.",
            col))
    if (nonnegative && any(v < 0))
        stop(sprintf("Column %s must be nonnegative.", col))
    if (probability && any(v < 0 | v > 1))
        stop(sprintf("Column %s must contain probabilities between 0 and 1.", col))
    v
}
oc_col <- function(df, key, fallback, required = TRUE) find_column(df, key, fallback, required)
oc_group <- function(df, key = "group_column", fallback = "group") {
    col <- oc_col(df, key, fallback, FALSE)
    if (is.null(col))
        return(rep("All", nrow(df)))
    values <- as.character(df[[col]])
    missing <- is.na(values) | !nzchar(trimws(values))
    if (any(missing))
        log_msg(sprintf("%d missing %s annotations shown as Missing.", sum(missing), col))
    values[missing] <- "Missing"
    values
}
oc_colors <- function(values) {
    levels <- sort(unique(as.character(values)), method = "radix")
    colors <- setNames(grDevices::hcl.colors(max(3, length(levels)), chr("palette", "Set 2"))[seq_along(levels)],
        levels)
    custom <- unlist(param("group_colors", list()))
    if (length(custom))
        colors[intersect(names(custom), levels)] <- custom[intersect(names(custom), levels)]
    for (value in colors) tryCatch(grDevices::col2rgb(value), error = function(e) stop("group_colors contains an invalid color. Use named hexadecimal colors."))
    colors
}
oc_theme <- function(void = FALSE) {
    p <- if (void)
        theme_void(base_size = num("base_size", 11), base_family = chr("font_family", "sans")) else theme_classic(base_size = num("base_size", 11), base_family = chr("font_family", "sans"))
    p + theme(plot.title = element_text(hjust = 0, face = "bold", size = num("title_size", 13)), plot.subtitle = element_text(hjust = 0,
        color = "#617080"), plot.caption = element_text(hjust = 0), plot.margin = margin(12, 14, 12,
        12), legend.text = element_text(size = num("legend_text_size", 9)), legend.position = if (flag("legend_show",
        TRUE))
        chr("legend_position", "right") else "none", plot.background = element_rect(fill = chr("plot_background", "#FFFFFF"), color = NA))
}
oc_labels <- function(x, y) labs(x = or_auto(chr("xlab"), x), y = or_auto(chr("ylab"), y))
oc_result <- function(plot, data, statistics = list(), tables = list(), note = "") list(plot = plot,
    data = data, statistics = statistics, tables = tables, note = note)
oc_circle <- function(cx, cy, radius, id, n = 120) {
    angle <- seq(0, 2 * pi, length.out = n)
    data.frame(x = cx + radius * cos(angle), y = cy + radius * sin(angle), id = id)
}
oc_pretty <- function(v) format(signif(v, 3), trim = TRUE, scientific = FALSE)
oc_seeds <- function() {
    seed <- suppressWarnings(as.integer(Sys.getenv("OMICSCANVAS_SEED", "42")))
    if (is.na(seed))
        seed <- 42L
    seed
}
oc_attach_metadata <- function(statistics, mapping) {
    statistics$mapping <- mapping
    statistics
}
oc_project <- function(x, y, z, azimuth = 40, elevation = 25) {
    a <- azimuth * pi/180
    b <- elevation * pi/180
    data.frame(px = x * cos(a) - y * sin(a), py = (x * sin(a) + y * cos(a)) * sin(b) + z * cos(b))
}

oc_validate_parameters <- function(schema_path) {
  schema <- jsonlite::fromJSON(schema_path, simplifyVector = FALSE)
  for (section in schema) {
    for (key in names(section)) {
      field <- section[[key]]
      value <- params[[key]]
      if (is.null(value)) next
      type <- field[['type']]
      if (identical(type, 'select')) {
        values <- unlist(value, use.names = FALSE)
        if (length(values) != 1 || !as.character(values) %in% unlist(field[['options']])) stop(paste(key, 'must be one of:', paste(unlist(field[['options']]), collapse = ', ')))
      }
      if (type %in% c('number', 'integer')) {
        values <- suppressWarnings(as.numeric(unlist(value, use.names = FALSE)))
        if (length(values) != 1 || !is.finite(values)) stop(paste(key, 'must be one finite number.'))
        if (type == 'integer' && values != round(values)) stop(paste(key, 'must be a whole number.'))
        lower <- field[['min']]; upper <- field[['max']]
        if (!is.null(lower) && values < lower) stop(paste(key, 'must be at least', lower))
        if (!is.null(upper) && values > upper) stop(paste(key, 'must be at most', upper))
      }
    }
  }
}
