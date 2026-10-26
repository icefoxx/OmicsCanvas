#!/usr/bin/env Rscript
# Circular Tree + Embedding — generated from templates/plugin by scripts/new_plugin.py.
# Contract: docs/standards/01_plugin_contract.md. R rules: docs/standards/03_r_implementation.md.
#
#   Rscript plugins/circular_tree_embedding/plot.R --input data.csv --params params.json --output out_dir

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
})

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

opt <- parse_args(OptionParser(option_list = list(
  make_option('--input', type = 'character'),
  make_option('--params', type = 'character'),
  make_option('--output', type = 'character')
)))
out <- opt$output %||% getwd()
dir.create(out, recursive = TRUE, showWarnings = FALSE)
# Never leave outputs of a previous run next to a failed one.
unlink(file.path(out, c('result.svg', 'result.pdf', 'result.png', 'figure.json', 'error.json', 'data_used.csv', 'annotation_used.csv', 'tree_edges_used.csv', 'profiles_used.csv')), force = TRUE)

script_dir <- local({
  f <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[1])
  if (is.na(f)) getwd() else dirname(normalizePath(f))
})
repo_root <- normalizePath(file.path(script_dir, '..', '..'), mustWork = FALSE)

log_msg <- function(...) {
  line <- sprintf('[%s] %s\n', format(Sys.time(), '%F %T'), paste0(...))
  cat(line)
  cat(line, file = file.path(out, 'run.log'), append = TRUE)
}

fail <- function(message, detail = '', suggestion = 'Check the input columns and params.json.') {
  writeLines(toJSON(list(error = message, detail = as.character(detail), suggestion = suggestion),
                    auto_unbox = TRUE, pretty = TRUE), file.path(out, 'error.json'))
  log_msg('ERROR: ', message, ' ', detail)
  quit(save = 'no', status = 1)
}

# ---- parameters: always params[['key']], never params$key (partial matching) ----
params <- if (!is.null(opt$params) && file.exists(opt$params)) fromJSON(opt$params, simplifyVector = FALSE) else list()
param <- function(key, default = NULL) params[[key]] %||% default
num <- function(key, default) {
  v <- suppressWarnings(as.numeric(unlist(param(key)))[1])
  if (length(v) && is.finite(v)) v else default
}
flag <- function(key, default = FALSE) {
  v <- param(key)
  if (is.null(v)) return(default)
  if (is.logical(v)) return(isTRUE(v[[1]]))
  tolower(as.character(v[[1]])) %in% c('true', 't', 'yes', 'y', '1', 'on')
}
chr <- function(key, default = '') {
  v <- unlist(param(key))
  if (is.null(v) || !length(v) || is.na(v[1])) default else as.character(v[1])
}
# Empty text means "use the automatic value" (the UI sends schema defaults such as "").
or_auto <- function(v, auto) if (nzchar(v)) v else auto
chr_vec <- function(key) {
  v <- unlist(param(key), use.names = FALSE)
  if (is.null(v)) character() else trimws(as.character(v))
}

read_table <- function(path) {
  if (is.null(path) || !file.exists(path)) fail('Input file not found', path %||% '')
  ext <- tolower(tools::file_ext(path))
  if (ext %in% c('tsv', 'txt')) read.delim(path, check.names = FALSE, stringsAsFactors = FALSE)
  else read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}

# Column mapping: the mapped name, else the first default that exists (case-insensitive).
find_column <- function(df, key, defaults = character(), required = TRUE) {
  wanted <- c(chr(key, ''), defaults)
  wanted <- wanted[nzchar(wanted)]
  hit <- match(tolower(wanted), tolower(colnames(df)))
  hit <- hit[!is.na(hit)]
  if (length(hit)) return(colnames(df)[hit[1]])
  if (required) fail(sprintf('Column for %s not found', key), paste(wanted, collapse = ', '),
                     sprintf('Set %s to one of: %s', key, paste(colnames(df), collapse = ', ')))
  NULL
}

main <- function() {
  df <- read_table(opt$input)
  x_col <- find_column(df, 'x_column', 'UMAP_1')
  y_col <- find_column(df, 'y_column', 'UMAP_2')
  leaf_col <- find_column(df, 'cluster_column', 'subtype')
  group_col <- find_column(df, 'group_column', 'subclass')
  hierarchy <- chr_vec('hierarchy_columns')
  if (!length(hierarchy)) hierarchy <- c('class', 'subclass')
  hierarchy <- unique(c(hierarchy, leaf_col))
  missing <- setdiff(hierarchy, names(df))
  if (length(missing)) stop(paste('Hierarchy columns not found:', paste(missing, collapse = ', ')))
  if (length(hierarchy) > 5) stop('Use at most five hierarchy levels, including the leaf column.')
  if (!(group_col %in% hierarchy)) stop('Center color annotation must be one of hierarchy_columns or cluster_column so colors correspond to the rings.')
  d <- df
  d[[x_col]] <- suppressWarnings(as.numeric(d[[x_col]]))
  d[[y_col]] <- suppressWarnings(as.numeric(d[[y_col]]))
  valid <- is.finite(d[[x_col]]) & is.finite(d[[y_col]])
  for (col in hierarchy) {
    d[[col]] <- trimws(as.character(d[[col]]))
    valid <- valid & !is.na(d[[col]]) & nzchar(d[[col]])
  }
  dropped <- sum(!valid)
  d <- d[valid, , drop = FALSE]
  log_msg(sprintf('Dropped %d rows with missing coordinates or annotations.', dropped))
  if (!nrow(d)) stop('No usable cells. Supply finite X/Y and nonempty annotations at every hierarchy level.')
  paths <- unique(d[hierarchy])
  if (anyDuplicated(paths[[leaf_col]])) stop('Each leaf must have one unique hierarchy path. Rename repeated leaf labels or correct conflicting parent annotations.')
  # Unique child labels prevent ambiguous links and inconsistent colors across parents.
  for (j in seq_along(hierarchy)) {
    if (j > 1) {
      prefixes <- unique(paths[hierarchy[seq_len(j)]])
      if (anyDuplicated(prefixes[[hierarchy[j]]])) stop(paste('Annotation', hierarchy[j], 'has the same child label under different parents. Use globally unique child labels.'))
    }
  }
  n <- nrow(paths)
  if (n < 2 || n > 150) stop('Use between 2 and 150 leaf groups; filter or aggregate annotations first.')
  tree_mode <- chr('tree_mode', 'annotation')
  if (!(tree_mode %in% c('annotation', 'similarity'))) stop('tree_mode must be annotation or similarity.')
  method <- chr('cluster_method', 'average')
  if (!(method %in% c('average', 'complete', 'single', 'ward.D2'))) stop('Unsupported cluster_method.')
  nodes <- list(); edge_list <- list()
  add_node <- function(id, parent, leaves, depth) {
    nodes[[id]] <<- list(id = id, parent = parent, leaves = leaves, depth = depth)
  }
  profiles <- NULL
  height_max <- NULL
  if (tree_mode == 'annotation') {
    paths <- paths[do.call(order, c(unname(paths[hierarchy]), list(method = 'radix'))), , drop = FALSE]
    leaves <- as.character(paths[[leaf_col]])
    add_node('root', NA_character_, leaves, 0)
    for (j in seq_along(hierarchy)) {
      for (value in unique(paths[[hierarchy[j]]])) {
        idx <- paths[[hierarchy[j]]] == value
        id <- paste0('level', j, ':', value)
        parent <- if (j == 1) 'root' else paste0('level', j - 1, ':', paths[[hierarchy[j - 1]]][which(idx)[1]])
        add_node(id, parent, as.character(paths[[leaf_col]][idx]), j)
      }
    }
    depth_max <- length(hierarchy)
  } else {
    features <- if (is.null(param('feature_columns'))) c('Gene_A', 'Gene_B', 'Gene_C', 'Gene_D') else chr_vec('feature_columns')
    if (length(features) < 2 || length(setdiff(features, names(d)))) stop('Similarity mode needs at least two existing numeric feature_columns.')
    if (any(features %in% c(x_col, y_col))) stop('Do not use embedding coordinates as similarity features; upload expression or other measured features.')
    matrix_in <- vapply(features, function(col) suppressWarnings(as.numeric(d[[col]])), numeric(nrow(d)))
    if (any(!is.finite(matrix_in))) stop('Similarity feature_columns contain missing or nonnumeric values. Clean these features before clustering.')
    profiles <- t(vapply(paths[[leaf_col]], function(leaf) colMeans(matrix_in[d[[leaf_col]] == leaf, , drop = FALSE]), numeric(length(features))))
    colnames(profiles) <- features
    rownames(profiles) <- paths[[leaf_col]]
    used <- profiles
    if (flag('scale_features', TRUE)) {
      spread <- apply(used, 2, sd)
      spread[!is.finite(spread) | spread == 0] <- 1
      used <- sweep(sweep(used, 2, colMeans(used), '-'), 2, spread, '/')
    }
    if (!any(as.numeric(dist(used)) > 0)) stop('All leaf feature profiles are identical. Supply informative feature_columns or use annotation mode.')
    hc <- hclust(dist(used), method = method)
    leaves <- rownames(used)[hc$order]
    paths <- paths[match(leaves, paths[[leaf_col]]), , drop = FALSE]
    height_max <- max(hc$height)
    visit <- function(index, parent = NA_character_) {
      if (index < 0) {
        name <- rownames(used)[-index]
        id <- paste0('leaf:', name)
        add_node(id, parent, name, 1)
        return(name)
      }
      id <- paste0('merge:', index)
      desc <- c(visit(hc$merge[index, 1], id), visit(hc$merge[index, 2], id))
      add_node(id, parent, desc, 1 - hc$height[index] / height_max)
      desc
    }
    visit(n - 1)
    depth_max <- 1
    write.csv(data.frame(leaf = rownames(profiles), profiles, check.names = FALSE), file.path(out, 'profiles_used.csv'), row.names = FALSE)
  }
  # Angles are unwrapped to keep the opening free of connecting branches.
  gap <- min(120, max(3, num('gap_angle', 18))) * pi / 180
  rotation <- num('rotation', 0) * pi / 180
  slot <- (2 * pi - gap) / n
  theta <- -pi / 2 + gap / 2 + slot * (seq_len(n) - .5) + rotation
  names(theta) <- leaves
  spacing <- slot
  center_radius <- min(.72, max(.25, num('embedding_radius', .62)))
  inner <- center_radius + .07
  outer <- 1
  xy <- function(angle, radius) data.frame(x = radius * cos(angle), y = radius * sin(angle))
  segs <- list(); arcs <- list(); edge_export <- list()
  radius_of <- function(node) inner + (outer - inner) * node$depth / depth_max
  for (node in nodes) {
    if (is.na(node$parent)) next
    parent <- nodes[[node$parent]]
    child_angle <- mean(theta[node$leaves])
    parent_angle <- mean(theta[parent$leaves])
    cr <- radius_of(node); pr <- radius_of(parent)
    ends <- rbind(xy(child_angle, pr), xy(child_angle, cr))
    segs[[length(segs) + 1]] <- data.frame(x = ends$x[1], y = ends$y[1], xend = ends$x[2], yend = ends$y[2])
    a <- seq(parent_angle, child_angle, length.out = max(2, ceiling(abs(parent_angle - child_angle) * 80)))
    arcs[[length(arcs) + 1]] <- cbind(xy(a, pr), id = length(arcs) + 1)
    edge_export[[length(edge_export) + 1]] <- data.frame(parent = node$parent, child = node$id, parent_radius = pr, child_radius = cr)
  }
  # Colors inherit the broad class hue; subclasses and leaves vary in luminance.
  color_map <- list()
  palette <- chr('palette', 'Dark 3')
  broad <- sort(unique(paths[[hierarchy[1]]]), method = 'radix')
  base <- grDevices::hcl.colors(max(3, length(broad)), palette)[seq_along(broad)]
  names(base) <- broad
  overrides <- unlist(param('group_colors', list()))
  for (value in broad) {
    key <- paste0(hierarchy[1], ':', value)
    if (key %in% names(overrides)) base[[value]] <- overrides[[key]] else if (value %in% names(overrides)) base[[value]] <- overrides[[value]]
  }
  for (j in seq_along(hierarchy)) {
    col <- hierarchy[j]
    colors <- setNames(character(), character())
    for (value in unique(paths[[col]])) {
      top <- paths[[hierarchy[1]]][match(value, paths[[col]])]
      hex <- base[[top]]
      if (j > 1) {
        siblings <- sort(unique(paths[[col]][paths[[hierarchy[1]]] == top]), method = 'radix')
        blend <- .10 + .35 * (match(value, siblings) - 1) / max(1, length(siblings) - 1)
        rgb <- grDevices::col2rgb(hex) / 255
        hex <- grDevices::rgb(rgb[1] * (1 - blend) + blend, rgb[2] * (1 - blend) + blend, rgb[3] * (1 - blend) + blend)
      }
      key <- paste0(col, ':', value)
      if (key %in% names(overrides)) hex <- overrides[[key]] else if (value %in% names(overrides)) hex <- overrides[[value]]
      tryCatch(grDevices::col2rgb(hex), error = function(e) stop(paste('Invalid group_colors value for', key)))
      colors[[value]] <- hex
    }
    color_map[[col]] <- colors
  }
  # Rings can be disjoint in similarity order; never connect unrelated runs.
  ring_width <- min(.12, max(.015, num('ring_width', .045)))
  rings <- list(); ring_text <- list()
  for (j in seq_along(hierarchy)) {
    col <- hierarchy[j]
    runs <- rle(as.character(paths[[col]]))
    finish <- cumsum(runs$lengths); start <- finish - runs$lengths + 1
    r1 <- 1.035 + (j - 1) * ring_width
    r2 <- r1 + ring_width * .86
    for (k in seq_along(start)) {
      lo <- theta[start[k]] - spacing * .44; hi <- theta[finish[k]] + spacing * .44
      aa <- seq(lo, hi, length.out = max(4, ceiling((hi - lo) * 100)))
      value <- runs$values[k]
      rings[[length(rings) + 1]] <- cbind(rbind(xy(aa, r1), xy(rev(aa), r2)), id = length(rings) + 1, color = color_map[[col]][[value]])
      # Conservative text-width estimate; omit labels that cannot fit.
      ring_size <- num('ring_label_size', 2.3)
      if (col != leaf_col && (hi - lo) * mean(c(r1, r2)) > nchar(value) * ring_size * .011) {
        a <- (hi + lo) / 2
        deg <- (a * 180 / pi + 90) %% 360
        if (deg > 90 && deg < 270) deg <- deg + 180
        ring_text[[length(ring_text) + 1]] <- cbind(xy(a, mean(c(r1, r2))), label = value, angle = deg)
      }
    }
  }
  ring_data <- do.call(rbind, rings)
  label_r <- 1.035 + length(hierarchy) * ring_width + .018
  leaf_size <- min(num('leaf_label_size', 2.5), 100 / n)
  # Reserve enough room for radial labels, including long uploaded leaf names.
  extent <- if (flag('leaf_label_show', TRUE)) label_r + max(nchar(leaves)) * leaf_size * .0105 + .08 else label_r + .03
  coords <- cbind(d[[x_col]], d[[y_col]])
  coords <- sweep(coords, 2, apply(coords, 2, function(z) mean(range(z))), '-')
  radius <- max(sqrt(rowSums(coords ^ 2)))
  if (!is.finite(radius) || radius == 0) radius <- 1
  coords <- coords / radius * center_radius
  points <- data.frame(x = coords[, 1], y = coords[, 2], group = d[[group_col]])
  points$color <- unname(color_map[[group_col]][points$group])
  p <- ggplot()
  if (flag('hull_show', TRUE)) {
    hulls <- lapply(split(points, points$group), function(g) {
      if (nrow(g) < 3) return(NULL)
      g[chull(g$x, g$y), , drop = FALSE]
    })
    hull <- do.call(rbind, hulls)
    if (!is.null(hull)) p <- p + geom_polygon(data = hull, aes(x, y, group = group, fill = color), alpha = num('hull_alpha', .13), linewidth = 0)
  }
  p <- p + geom_point(data = points, aes(x, y, color = color), size = num('point_size', .45), alpha = num('point_alpha', .72)) +
    geom_segment(data = do.call(rbind, segs), aes(x, y, xend = xend, yend = yend), color = chr('tree_color', '#9CAFB0'), linewidth = num('tree_line_width', .32)) +
    geom_path(data = do.call(rbind, arcs), aes(x, y, group = id), color = chr('tree_color', '#9CAFB0'), linewidth = num('tree_line_width', .32)) +
    geom_polygon(data = ring_data, aes(x, y, group = id, fill = color), linewidth = 0)
  if (flag('ring_label_show', TRUE) && length(ring_text)) {
    p <- p + geom_text(data = do.call(rbind, ring_text), aes(x, y, label = label, angle = as.numeric(angle)), size = num('ring_label_size', 2.3), color = '#FFFFFF', family = chr('font_family', 'sans'))
  }
  if (flag('ring_label_show', TRUE)) {
    level_labels <- cbind(xy(rep(-pi / 2 + rotation, length(hierarchy)), 1.035 + (seq_along(hierarchy) - 1) * ring_width + ring_width * .43), label = hierarchy)
    level_size <- min(num('ring_label_size', 2.3), max(1, gap * 45 / max(nchar(hierarchy))))
    p <- p + geom_label(data = level_labels, aes(x, y, label = label), angle = num('rotation', 0), size = level_size, family = chr('font_family', 'sans'), fill = '#52606A', color = '#FFFFFF', label.size = 0, label.padding = grid::unit(.06, 'lines'))
  }
  if (flag('leaf_label_show', TRUE)) {
    leaf_labels <- cbind(xy(theta, label_r), label = leaves, color = unname(color_map[[leaf_col]][leaves]))
    leaf_labels$angle <- (theta * 180 / pi) %% 360
    leaf_labels$hjust <- ifelse(cos(theta) < 0, 1, 0)
    leaf_labels$angle[cos(theta) < 0] <- leaf_labels$angle[cos(theta) < 0] + 180
    p <- p + geom_text(data = leaf_labels, aes(x, y, label = label, color = color, angle = angle, hjust = hjust), size = leaf_size, family = chr('font_family', 'sans'))
  }
  if (flag('label_show', TRUE)) {
    centers <- aggregate(cbind(x, y) ~ group, points, median)
    # Labels repel in the embedding, with bounds that prevent entry into the tree.
    p <- p + ggrepel::geom_label_repel(data = centers, aes(x, y, label = group), size = num('label_size', 2.6), seed = sample.int(.Machine$integer.max, 1), min.segment.length = 0, box.padding = .15, label.padding = .10, label.size = 0, fill = '#FFFFFFCC', max.overlaps = 30, max.time = Inf, max.iter = 2000, xlim = c(-center_radius, center_radius), ylim = c(-center_radius, center_radius), family = chr('font_family', 'sans'))
  }
  info <- sprintf('%s cells  |  %d leaves  |  %s', format(nrow(d), big.mark = ',', trim = TRUE), n, if (tree_mode == 'annotation') 'Annotation topology (not distances)' else paste('Euclidean /', method))
  p <- p + scale_fill_identity() + scale_color_identity() +
    coord_fixed(xlim = c(-extent, extent), ylim = c(-extent, extent), expand = FALSE) +
    labs(title = chr('title', ''), subtitle = or_auto(chr('subtitle', ''), info), caption = chr('caption', '')) +
    theme_void(base_size = num('base_size', 11), base_family = chr('font_family', 'sans')) +
    theme(plot.title = element_text(hjust = 0, face = 'bold'), plot.subtitle = element_text(hjust = 0, color = '#586574'), plot.margin = margin(15, 15, 15, 15), plot.background = element_rect(fill = chr('plot_background', '#FFFFFF'), color = NA))
  width <- num('width', 10); height <- num('height', 10); dpi <- num('dpi', 180)
  if (width < 4 || height < 4 || dpi < 72) stop('Export requires width and height >= 4 inches and dpi >= 72.')
  ggsave(file.path(out, 'result.svg'), p, width = width, height = height)
  ggsave(file.path(out, 'result.pdf'), p, width = width, height = height, device = grDevices::cairo_pdf)
  ggsave(file.path(out, 'result.png'), p, width = width, height = height, dpi = dpi, device = ragg::agg_png)
  d$plot_x <- points$x; d$plot_y <- points$y
  d$plot_color <- points$color
  write.csv(d, file.path(out, 'data_used.csv'), row.names = FALSE)
  write.csv(do.call(rbind, edge_export), file.path(out, 'tree_edges_used.csv'), row.names = FALSE)
  write.csv(data.frame(leaf = leaves, angle = unname(theta), paths, check.names = FALSE), file.path(out, 'annotation_used.csv'), row.names = FALSE)
  figure <- list(plugin = 'circular_tree_embedding', version = '1.0.0', data = list(rows = nrow(d), dropped_rows = dropped, mapping = list(x = x_col, y = y_col, cluster = leaf_col, group = group_col), hierarchy = hierarchy, leaf_order = leaves), tree = list(mode = tree_mode, max_height = height_max, distance = if (tree_mode == 'similarity') 'euclidean' else NULL, linkage = if (tree_mode == 'similarity') method else NULL, scaled = if (tree_mode == 'similarity') flag('scale_features', TRUE) else NULL), colors = lapply(color_map, as.list), layers = c('embedding', 'radial_tree', 'annotation_rings'), export = list(width = width, height = height, dpi = dpi, files = c('result.svg', 'result.pdf', 'result.png', 'data_used.csv', 'annotation_used.csv', 'tree_edges_used.csv', if (tree_mode == 'similarity') 'profiles_used.csv')))
  writeLines(toJSON(figure, auto_unbox = TRUE, pretty = TRUE, null = 'null'), file.path(out, 'figure.json'))
  log_msg(sprintf('Done: %d cells, %d leaves, %s tree.', nrow(d), n, tree_mode))
}
tryCatch(main(), error = function(e) {
  unlink(file.path(out, c('result.svg', 'result.pdf', 'result.png', 'figure.json')), force = TRUE)
  fail('Cannot draw circular tree + embedding', conditionMessage(e), 'Check column mappings, unique leaf hierarchy paths and similarity feature columns.')
})
