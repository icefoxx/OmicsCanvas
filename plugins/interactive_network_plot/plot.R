#!/usr/bin/env Rscript
# Interactive Network Plot — edge-list or membership graph with preset layouts
# and a draggable visNetwork HTML view.
#
#   Rscript plugins/interactive_network_plot/plot.R \
#     --input edges.csv --params params.json --output out_dir [--nodes nodes.csv]

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
  library(igraph)
  library(ggraph)
  library(visNetwork)
  library(htmlwidgets)
})

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

opt <- parse_args(OptionParser(option_list = list(
  make_option('--input', type = 'character'),
  make_option('--params', type = 'character'),
  make_option('--output', type = 'character'),
  make_option('--nodes', type = 'character', default = NULL)
)))
out <- opt$output %||% getwd()
dir.create(out, recursive = TRUE, showWarnings = FALSE)
unlink(file.path(out, c(
  'result.svg', 'result.pdf', 'result.png', 'result.html', 'figure.json', 'error.json',
  'nodes_used.csv', 'edges_used.csv', 'selected_nodes.csv', 'positions.csv'
)), force = TRUE)

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
or_auto <- function(v, auto) if (nzchar(v)) v else auto
chr_vec <- function(key) {
  v <- unlist(param(key), use.names = FALSE)
  if (is.null(v)) return(character())
  v <- trimws(as.character(v))
  if (length(v) == 1L && grepl(',', v, fixed = TRUE)) v <- trimws(strsplit(v, ',', fixed = TRUE)[[1]])
  v[nzchar(v)]
}

read_table <- function(path) {
  if (is.null(path) || !file.exists(path)) fail('Input file not found', path %||% '')
  ext <- tolower(tools::file_ext(path))
  if (ext %in% c('tsv', 'txt')) read.delim(path, check.names = FALSE, stringsAsFactors = FALSE)
  else read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}
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
rescale <- function(x, to) {
  x <- suppressWarnings(as.numeric(x))
  r <- range(x, na.rm = TRUE)
  if (!length(x) || !is.finite(r[1]) || r[1] == r[2]) return(rep(mean(to), length(x)))
  to[1] + (x - r[1]) / (r[2] - r[1]) * (to[2] - to[1])
}
named_colors <- function(custom, levels_use) {
  pal <- c('#4477AA', '#EE6677', '#228833', '#CCBB44', '#66CCEE', '#AA3377', '#BBBBBB')
  cols <- setNames(rep(pal, length.out = length(levels_use)), levels_use)
  z <- unlist(custom)
  if (length(z)) {
    if (is.null(names(z))) {
      n <- min(length(z), length(cols))
      cols[seq_len(n)] <- as.character(z[seq_len(n)])
    } else {
      hit <- intersect(names(z), levels_use)
      cols[hit] <- as.character(z[hit])
    }
  }
  cols
}
sort_index <- function(idx, sort_by, degree, size, label) {
  if (!length(idx)) return(idx)
  key <- switch(sort_by,
    degree = -degree[idx],
    size = -size[idx],
    label = label[idx],
    idx
  )
  if (identical(sort_by, 'none') || is.null(key)) idx else idx[order(key, label[idx], na.last = TRUE)]
}
angle_seq <- function(k) {
  if (k <= 0) numeric()
  -pi / 2 + 2 * pi * (seq_len(k) - 1) / k
}
layout_circle_xy <- function(n, sort_by, radius = 1) {
  xy <- cbind(rep(0, nrow(n)), rep(0, nrow(n)))
  idx <- sort_index(seq_len(nrow(n)), sort_by, n$degree, n$size, n$label)
  ang <- angle_seq(length(idx))
  xy[idx, 1] <- radius * cos(ang)
  xy[idx, 2] <- radius * sin(ang)
  xy
}
layout_concentric_xy <- function(n, sort_by, ring_gap, group_levels) {
  xy <- cbind(rep(0, nrow(n)), rep(0, nrow(n)))
  groups <- group_levels[group_levels %in% n$group]
  if (!length(groups)) groups <- unique(n$group)
  for (i in seq_along(groups)) {
    idx <- which(n$group == groups[i])
    idx <- sort_index(idx, sort_by, n$degree, n$size, n$label)
    r <- ring_gap * (0.45 + (i - 1))
    ang <- angle_seq(length(idx))
    xy[idx, 1] <- r * cos(ang)
    xy[idx, 2] <- r * sin(ang)
  }
  leftover <- which(!n$group %in% groups)
  if (length(leftover)) {
    r <- ring_gap * (0.45 + length(groups))
    ang <- angle_seq(length(leftover))
    xy[leftover, 1] <- r * cos(ang)
    xy[leftover, 2] <- r * sin(ang)
  }
  xy
}
layout_radial_xy <- function(n, e, sort_by, ring_gap) {
  groups <- n$id[n$type == 'Group']
  if (!length(groups)) return(layout_concentric_xy(n, sort_by, ring_gap, unique(n$group)))
  groups <- n$id[sort_index(which(n$type == 'Group'), sort_by, n$degree, n$size, n$label)]
  n_g <- length(groups)
  g_ang <- setNames(angle_seq(n_g), groups)
  xy <- cbind(rep(0, nrow(n)), rep(0, nrow(n)))
  r_in <- ring_gap * 0.5
  r_out <- ring_gap * 2.7
  for (g in groups) {
    i <- match(g, n$id)
    xy[i, ] <- c(r_in * cos(g_ang[[g]]), r_in * sin(g_ang[[g]]))
  }
  members <- n$id[n$type == 'Member']
  membership <- lapply(members, function(m) unique(e$from[e$to == m | e$from == m]))
  membership <- lapply(membership, function(gs) gs[gs %in% groups])
  names(membership) <- members
  exclusive <- list()
  shared <- character()
  for (g in groups) exclusive[[g]] <- character()
  for (m in members) {
    gs <- membership[[m]]
    if (length(gs) == 1L) exclusive[[gs]] <- c(exclusive[[gs]], m)
    else shared <- c(shared, m)
  }
  sector <- 2 * pi / max(n_g, 1)
  for (g in groups) {
    mems <- exclusive[[g]]
    mems <- mems[order(n$label[match(mems, n$id)])]
    k <- length(mems)
    if (!k) next
    off <- if (k == 1L) 0 else seq(-sector * 0.35, sector * 0.35, length.out = k)
    for (j in seq_len(k)) {
      ang <- g_ang[[g]] + off[j]
      i <- match(mems[j], n$id)
      xy[i, ] <- c(r_out * cos(ang), r_out * sin(ang))
    }
  }
  for (m in unique(shared)) {
    gs <- membership[[m]]
    angs <- unname(g_ang[gs])
    ang <- if (!length(angs)) 0 else atan2(mean(sin(angs)), mean(cos(angs)))
    i <- match(m, n$id)
    xy[i, ] <- c(r_out * 0.92 * cos(ang), r_out * 0.92 * sin(ang))
  }
  other <- which(is.na(xy[, 1]) | (xy[, 1] == 0 & xy[, 2] == 0 & !n$id %in% groups))
  other <- other[n$type[other] != 'Group']
  if (length(other)) {
    ang <- angle_seq(length(other))
    xy[other, 1] <- r_out * cos(ang)
    xy[other, 2] <- r_out * sin(ang)
  }
  xy
}
gradient_hex <- function(x, low = '#2166AC', mid = '#F7F7F7', high = '#B2182B') {
  t <- rescale(x, c(0, 1))
  ramp <- grDevices::colorRamp(c(low, mid, high), space = 'Lab')
  rgb <- ramp(t)
  grDevices::rgb(rgb[, 1], rgb[, 2], rgb[, 3], maxColorValue = 255)
}

main <- function() {
  df <- read_table(opt$input)
  mode <- tolower(chr('input_mode', 'edge_list'))
  if (mode %in% c('network_venn', 'network-venn')) mode <- 'membership'
  if (!mode %in% c('edge_list', 'membership')) mode <- 'edge_list'

  if (mode == 'membership') {
    gc <- find_column(df, 'group_column', c('group', 'set', 'source', 'from'))
    ec <- find_column(df, 'node_id_column', c('element', 'member', 'node', 'target', 'to'))
    wc <- find_column(df, 'weight_column', c('weight'), required = FALSE)
    groups <- unique(as.character(df[[gc]]))
    members <- unique(as.character(df[[ec]]))
    n <- data.frame(
      id = c(groups, members),
      label = c(groups, members),
      group = c(groups, rep('Member', length(members))),
      type = c(rep('Group', length(groups)), rep('Member', length(members))),
      stringsAsFactors = FALSE
    )
    n <- n[!duplicated(n$id), , drop = FALSE]
    e <- data.frame(
      from = as.character(df[[gc]]),
      to = as.character(df[[ec]]),
      weight = if (is.null(wc)) 1 else suppressWarnings(as.numeric(df[[wc]])),
      edge_group = as.character(df[[gc]]),
      stringsAsFactors = FALSE
    )
  } else {
    sc <- find_column(df, 'source_column', c('source', 'from'))
    tc <- find_column(df, 'target_column', c('target', 'to'))
    wc <- find_column(df, 'weight_column', c('weight'), required = FALSE)
    eg <- find_column(df, 'edge_group_column', c('edge_group'), required = FALSE)
    ids <- unique(c(as.character(df[[sc]]), as.character(df[[tc]])))
    n <- data.frame(id = ids, label = ids, group = 'Network', type = 'Node', stringsAsFactors = FALSE)
    e <- data.frame(
      from = as.character(df[[sc]]),
      to = as.character(df[[tc]]),
      weight = if (is.null(wc)) 1 else suppressWarnings(as.numeric(df[[wc]])),
      edge_group = if (is.null(eg)) 'Edges' else as.character(df[[eg]]),
      stringsAsFactors = FALSE
    )
  }
  e$weight[!is.finite(e$weight)] <- 1

  if (!is.null(opt$nodes) && nzchar(opt$nodes)) {
    z <- read_table(opt$nodes)
    idc <- find_column(z, 'node_id_column', c('id', 'node_id', 'name'))
    ix <- match(n$id, as.character(z[[idc]]))
    for (k in intersect(names(z), c('label', 'group', 'type', 'size', 'color', 'x', 'y', 'highlight', 'tooltip'))) {
      n[[k]] <- z[[k]][ix]
    }
  }

  n$label <- as.character(n$label)
  n$label[is.na(n$label) | !nzchar(n$label)] <- n$id
  n$group <- as.character(n$group)
  n$group[is.na(n$group) | !nzchar(n$group)] <- if (mode == 'membership') 'Member' else 'Network'
  n$type <- as.character(n$type)
  n$type[is.na(n$type) | !nzchar(n$type)] <- 'Node'

  inc <- chr_vec('nodes_include')
  exc <- chr_vec('nodes_exclude')
  if (length(inc)) n <- n[n$id %in% inc, , drop = FALSE]
  if (length(exc)) n <- n[!n$id %in% exc, , drop = FALSE]
  e <- e[e$from %in% n$id & e$to %in% n$id, , drop = FALSE]
  if (!nrow(n)) fail('No nodes left after filtering')

  n$degree <- as.numeric(tabulate(match(c(e$from, e$to), n$id), nbins = nrow(n)))
  size_by <- chr('node_size_by', 'degree')
  size_min <- num('node_size_min', 13)
  size_max <- num('node_size_max', 38)
  size_const <- num('node_size', 18)
  if (size_by == 'size_column' && 'size' %in% names(n) && any(is.finite(suppressWarnings(as.numeric(n$size))))) {
    n$vis_size <- rescale(n$size, c(size_min, size_max))
  } else if (size_by == 'constant') {
    n$vis_size <- if (mode == 'membership') ifelse(n$type == 'Group', size_max, size_min) else size_const
  } else {
    n$vis_size <- rescale(n$degree, c(size_min, size_max))
  }
  n$draw_size <- n$vis_size / 4
  n$size <- n$vis_size

  hl <- union(chr_vec('highlight_nodes'), chr_vec('selected_nodes'))
  if ('highlight' %in% names(n)) {
    hv <- n$highlight
    if (is.logical(hv)) n$highlight <- hv %in% TRUE
    else n$highlight <- tolower(as.character(hv)) %in% c('true', 't', 'yes', 'y', '1')
  } else {
    n$highlight <- FALSE
  }
  if (length(hl)) n$highlight <- n$highlight | n$id %in% hl

  group_levels <- unique(c(chr_vec('group_order'), n$group))
  group_levels <- group_levels[group_levels %in% n$group]
  n$group <- factor(n$group, levels = group_levels)
  cm <- named_colors(param('group_colors', param('node_colors', list())), group_levels)
  color_mode <- chr('node_color_mode', 'group')
  n$fill_value <- n$degree
  if (color_mode == 'gradient') {
    n$color <- gradient_hex(n$fill_value)
  } else {
    n$color <- unname(cm[as.character(n$group)])
    n$color[is.na(n$color)] <- '#4477AA'
  }
  n$title <- paste0('<b>', n$label, '</b><br>Group: ', n$group, '<br>Degree: ', n$degree)
  if ('tooltip' %in% names(n)) {
    tip <- as.character(n$tooltip)
    n$title[!is.na(tip) & nzchar(tip)] <- tip[!is.na(tip) & nzchar(tip)]
  }

  directed <- flag('directed', FALSE)
  verts <- n
  names(verts)[names(verts) == 'id'] <- 'name'
  g <- graph_from_data_frame(e, directed = directed, vertices = verts)

  algo <- tolower(chr('layout_algorithm', 'fr'))
  sort_by <- chr('layout_sort', 'none')
  ring_gap <- num('ring_gap', 1)
  if (!is.finite(ring_gap) || ring_gap <= 0) ring_gap <- 1

  has_xy <- all(c('x', 'y') %in% names(n)) && any(is.finite(suppressWarnings(as.numeric(n$x)))) &&
    any(is.finite(suppressWarnings(as.numeric(n$y))))
  if (algo == 'manual' && !has_xy) {
    log_msg('layout_algorithm=manual but x/y missing; using fr')
    algo <- 'fr'
  }

  xy <- if (algo == 'circle') {
    layout_circle_xy(n, sort_by)
  } else if (algo == 'concentric') {
    layout_concentric_xy(n, sort_by, ring_gap, group_levels)
  } else if (algo == 'radial') {
    layout_radial_xy(n, e, sort_by, ring_gap)
  } else if (algo == 'kk') {
    layout_with_kk(g)
  } else if (algo == 'hierarchical') {
    layout_as_tree(g)
  } else if (algo == 'stress') {
    if (requireNamespace('graphlayouts', quietly = TRUE)) graphlayouts::layout_with_stress(g)
    else layout_with_mds(g)
  } else if (algo == 'manual' && has_xy) {
    cbind(suppressWarnings(as.numeric(n$x)), suppressWarnings(as.numeric(n$y)))
  } else {
    layout_with_fr(g)
  }
  xy[!is.finite(xy)] <- 0
  n$lx <- xy[, 1]
  n$ly <- xy[, 2]
  V(g)$x <- n$lx
  V(g)$y <- n$ly

  write.csv(n, file.path(out, 'nodes_used.csv'), row.names = FALSE)
  write.csv(e, file.path(out, 'edges_used.csv'), row.names = FALSE)
  if (any(n$highlight)) write.csv(n[n$highlight, , drop = FALSE], file.path(out, 'selected_nodes.csv'), row.names = FALSE)
  if (flag('save_positions', FALSE)) {
    write.csv(data.frame(id = n$id, x = n$lx, y = n$ly), file.path(out, 'positions.csv'), row.names = FALSE)
  }

  edge_weighted <- flag('edge_weighted', TRUE)
  edge_style <- chr('edge_style', 'link')
  edge_alpha <- num('edge_alpha', 0.65)
  edge_color <- chr('edge_color', '#718096')
  wmin <- num('edge_width_min', 0.4)
  wmax <- num('edge_width_max', 3)
  arr <- if (directed) arrow(length = unit(2.4, 'mm'), type = 'closed') else NULL
  cap <- circle(3.2, 'mm')

  p <- ggraph(g, layout = 'manual', x = n$lx, y = n$ly)
  if (nrow(e)) {
    if (edge_style == 'arc') {
      if (edge_weighted) {
        p <- p + geom_edge_arc(aes(width = weight), alpha = edge_alpha, colour = edge_color,
                               strength = 0.35, arrow = arr, end_cap = cap, start_cap = cap)
      } else {
        p <- p + geom_edge_arc(alpha = edge_alpha, colour = edge_color, width = wmin,
                               strength = 0.35, arrow = arr, end_cap = cap, start_cap = cap)
      }
    } else {
      if (edge_weighted) {
        p <- p + geom_edge_link(aes(width = weight), alpha = edge_alpha, colour = edge_color,
                                arrow = arr, end_cap = cap, start_cap = cap)
      } else {
        p <- p + geom_edge_link(alpha = edge_alpha, colour = edge_color, width = wmin,
                                arrow = arr, end_cap = cap, start_cap = cap)
      }
    }
    if (edge_weighted) p <- p + scale_edge_width(range = c(wmin, wmax), name = 'Weight')
  }

  types <- unique(as.character(n$type))
  shp <- setNames(rep(21, length(types)), types)
  if ('Group' %in% types) shp[['Group']] <- 22
  if ('Member' %in% types) shp[['Member']] <- 21
  stroke_col <- chr('node_stroke_color', '#FFFFFF')
  node_alpha <- num('node_alpha', 1)
  node_stroke <- num('node_stroke', 0.8)
  if (color_mode == 'gradient') {
    p <- p + geom_node_point(
      aes(size = draw_size, fill = fill_value, shape = type),
      colour = stroke_col, stroke = node_stroke, alpha = node_alpha
    ) + scale_fill_gradient2(
      low = '#2166AC', mid = '#F7F7F7', high = '#B2182B',
      midpoint = mean(range(n$fill_value)), name = 'Degree'
    )
  } else {
    p <- p + geom_node_point(
      aes(size = draw_size, fill = group, shape = type),
      colour = stroke_col, stroke = node_stroke, alpha = node_alpha
    ) + scale_fill_manual(values = cm, name = 'Group')
  }
  p <- p + scale_shape_manual(values = shp, name = 'Type') + scale_size_identity()

  if (flag('label_show', TRUE)) {
    p <- p + geom_node_text(
      aes(label = label), repel = TRUE, size = num('label_size', 3.2),
      colour = chr('label_color', '#222222'), max.overlaps = 40, seed = 1
    )
  }

  title <- chr('title', '')
  pad <- 0.18 * max(diff(range(n$lx)), diff(range(n$ly)), 1)
  p <- p +
    coord_fixed(
      xlim = range(n$lx) + c(-pad, pad),
      ylim = range(n$ly) + c(-pad, pad),
      clip = 'on'
    ) +
    labs(title = title, x = NULL, y = NULL) +
    theme_void(base_size = num('base_size', 11), base_family = chr('font_family', 'sans')) +
    theme(
      plot.background = element_rect(fill = chr('plot_background', 'white'), colour = NA),
      panel.background = element_rect(fill = chr('panel_background', 'white'), colour = NA),
      legend.position = if (flag('legend_show', TRUE)) chr('legend_position', 'right') else 'none',
      plot.margin = margin(12, 12, 12, 12)
    ) +
    guides(
      fill = if (color_mode == 'gradient') {
        guide_colourbar()
      } else {
        guide_legend(override.aes = list(shape = 21, size = 4))
      },
      shape = if (length(types) > 1) guide_legend(override.aes = list(size = 4, fill = 'grey60')) else 'none',
      edge_width = if (edge_weighted && nrow(e)) guide_legend() else 'none'
    )
  if (any(n$highlight)) {
    hl_df <- n[n$highlight, , drop = FALSE]
    p <- p + geom_point(
      data = hl_df, aes(x = lx, y = ly), inherit.aes = FALSE,
      shape = 21, size = hl_df$draw_size + 1.6, fill = NA,
      colour = chr('highlight_color', '#D4A017'), stroke = 1.2
    )
  }

  source(file.path(repo_root, 'R', 'runtime', 'omicscanvas_theme.R'), local = TRUE)
  p <- omicscanvas_apply_theme(p, params, only = c(
    'title_size', 'title_color', 'title_face', 'title_hjust',
    'legend_text_size', 'legend_title_size', 'legend_key_size', 'legend_position', 'legend_show',
    'margin', 'grid_show', 'grid_color', 'panel_border_show', 'panel_border_color', 'panel_border_width'
  ))

  width <- num('width', 9)
  height <- num('height', 7)
  dpi <- num('dpi', 300)
  ggsave(file.path(out, 'result.svg'), p, width = width, height = height)
  ggsave(file.path(out, 'result.pdf'), p, width = width, height = height, device = grDevices::cairo_pdf)
  ggsave(file.path(out, 'result.png'), p, width = width, height = height, dpi = dpi, device = ragg::agg_png)

  if (flag('interactive', TRUE)) {
    span <- max(diff(range(n$lx)), diff(range(n$ly)), 1e-6)
    vn <- data.frame(
      id = n$id, label = n$label, title = n$title, value = n$vis_size,
      color = n$color,
      shape = ifelse(n$type == 'Group', 'box', 'dot'),
      stringsAsFactors = FALSE
    )
    if (!flag('physics_enabled', FALSE)) {
      vn$x <- (n$lx - mean(n$lx)) / span * 650
      vn$y <- -(n$ly - mean(n$ly)) / span * 650
    }
    ve <- data.frame(
      from = e$from, to = e$to,
      width = if (nrow(e)) { if (edge_weighted) rescale(e$weight, c(1, 8)) else rep(2, nrow(e)) } else numeric(),
      title = if (nrow(e)) e$edge_group else character(),
      stringsAsFactors = FALSE
    )
    vn$fixed <- FALSE
    v <- visNetwork(vn, ve, main = title, height = paste0(num('html_height', 700), 'px'))
    v <- visNodes(v, font = list(size = 16), borderWidth = 1, fixed = FALSE)
    v <- visEdges(
      v, color = list(color = edge_color, opacity = edge_alpha),
      arrows = if (directed) 'to' else '',
      smooth = isTRUE(edge_style == 'arc')
    )
    v <- visOptions(v, highlightNearest = flag('highlight_neighborhood', TRUE), selectedBy = NULL)
    v <- visInteraction(
      v,
      dragNodes = flag('drag_nodes', TRUE),
      dragView = TRUE,
      zoomView = flag('zoom_view', TRUE),
      navigationButtons = flag('navigation_buttons', TRUE),
      hover = flag('tooltip_show', TRUE),
      selectable = flag('selectable', TRUE)
    )
    phys <- flag('physics_enabled', FALSE)
    v <- visPhysics(
      v,
      enabled = phys,
      stabilization = list(enabled = phys && flag('stabilize', TRUE))
    )
    html_path <- file.path(out, 'result.html')
    tryCatch(
      saveWidget(v, html_path, selfcontained = TRUE),
      error = function(err) {
        log_msg('HTML widget failed: ', conditionMessage(err))
        writeLines(
          '<html><body><p>Interactive HTML could not be written. See result.png.</p></body></html>',
          html_path
        )
      }
    )
  }

  figure <- list(
    plugin = 'interactive_network_plot', version = '1.1.0',
    input_mode = mode, layout_algorithm = algo,
    node_count = nrow(n), edge_count = nrow(e),
    positions_saved = flag('save_positions', FALSE),
    drag_nodes = flag('drag_nodes', TRUE),
    outputs = list(
      svg = 'result.svg', pdf = 'result.pdf', png = 'result.png', html = 'result.html',
      nodes = 'nodes_used.csv', edges = 'edges_used.csv', log = 'run.log'
    )
  )
  writeLines(toJSON(figure, auto_unbox = TRUE, pretty = TRUE, null = 'null'), file.path(out, 'figure.json'))
  log_msg(sprintf('Done: %d nodes, %d edges, layout=%s', nrow(n), nrow(e), algo))
}

tryCatch(main(), error = function(e) fail('Plot generation failed', conditionMessage(e)))
