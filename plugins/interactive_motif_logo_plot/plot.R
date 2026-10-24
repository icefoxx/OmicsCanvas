#!/usr/bin/env Rscript

# DNA sequence logos (seqlogo / WebLogo style): stacked, vertically
# stretched A/C/G/T letters. Input is a long or wide PWM.

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
})

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

op <- parse_args(OptionParser(option_list = list(
  make_option('--input', type = 'character'),
  make_option('--params', type = 'character'),
  make_option('--output', type = 'character')
)))
out <- op$output %||% getwd()
dir.create(out, recursive = TRUE, showWarnings = FALSE)
unlink(file.path(out, c(
  'result.svg', 'result.pdf', 'result.png', 'result.html', 'figure.json',
  'motif_data_used.csv', 'selected_rows.csv', 'error.json', 'run.log'
)), force = TRUE)

logmsg <- function(x) {
  line <- sprintf('[%s] %s\n', format(Sys.time(), '%F %T'), x)
  cat(line)
  cat(line, file = file.path(out, 'run.log'), append = TRUE)
}

fail <- function(message, detail = '', suggestion = 'Check input columns and params.json.') {
  writeLines(
    toJSON(list(error = message, detail = detail, suggestion = suggestion), auto_unbox = TRUE, pretty = TRUE),
    file.path(out, 'error.json')
  )
  quit(status = 1)
}

readtab <- function(x) {
  if (tolower(tools::file_ext(x)) %in% c('tsv', 'txt')) {
    read.delim(x, check.names = FALSE, stringsAsFactors = FALSE)
  } else {
    read.csv(x, check.names = FALSE, stringsAsFactors = FALSE)
  }
}

classic_colors <- c(A = '#109649', C = '#255C99', G = '#F9BD31', T = '#D62839')

main <- function() {
  if (is.null(op$input) || !file.exists(op$input)) fail('Input file not found', as.character(op$input))
  p <- if (!is.null(op$params) && file.exists(op$params)) fromJSON(op$params, simplifyVector = FALSE) else list()
  val <- function(n, d = NULL, aliases = character()) {
    x <- p[[n]]
    if (is.null(x)) {
      for (g in names(p)) if (is.list(p[[g]]) && !is.null(p[[g]][[n]])) { x <- p[[g]][[n]]; break }
    }
    if (is.null(x)) for (a in aliases) if (!is.null(p[[a]])) { x <- p[[a]]; break }
    x %||% d
  }
  vec <- function(x) {
    if (is.null(x)) return(character())
    x <- unlist(x, use.names = FALSE)
    if (length(x) == 1 && grepl(',', x, fixed = TRUE)) x <- strsplit(x, ',', fixed = TRUE)[[1]]
    trimws(as.character(x))
  }
  num <- function(n, d = 0) {
    x <- suppressWarnings(as.numeric(unlist(val(n, d))[1]))
    ifelse(is.finite(x), x, d)
  }
  boo <- function(n, d = FALSE) {
    x <- val(n, d)
    if (is.logical(x)) isTRUE(x[1]) else tolower(as.character(x[1])) %in% c('true', 't', 'yes', 'y', '1', 'on')
  }

  d0 <- readtab(op$input)
  cn <- names(d0)
  low <- tolower(cn)
  findcol <- function(x, defaults = character()) {
    h <- match(tolower(c(x, defaults)), low)
    h <- h[!is.na(h)]
    if (length(h)) cn[h[1]] else NULL
  }
  mode <- tolower(as.character(val('input_mode', 'auto')))
  if (!mode %in% c('auto', 'long', 'wide')) fail('Unsupported input_mode', mode)
  motifc <- findcol(val('motif_column', NULL), c('motif', 'motif_name', 'motif_id', 'name'))
  posc <- findcol(val('position_column', NULL), c('position', 'pos', 'index'))
  base_map <- val('base_columns', NULL)
  getbase <- function(b) {
    x <- NULL
    if (is.list(base_map) || !is.null(names(base_map))) x <- base_map[[b]]
    found <- findcol(x, b)
    if (is.null(found)) '' else found
  }
  bcols <- setNames(vapply(c('A', 'C', 'G', 'T'), getbase, character(1)), c('A', 'C', 'G', 'T'))
  long_ok <- !is.null(motifc) && !is.null(posc) && all(nzchar(bcols))
  is_long <- mode == 'long' || (mode == 'auto' && long_ok)
  if (is_long && !long_ok) fail('Long input requires motif, position, A, C, G, and T columns')

  keep <- rep(TRUE, nrow(d0))
  inc <- vec(val('motifs_include'))
  exc <- vec(val('motifs_exclude'))
  if (!is.null(motifc)) {
    if (length(inc)) keep <- as.character(d0[[motifc]]) %in% inc
    if (length(exc)) keep <- keep & !(as.character(d0[[motifc]]) %in% exc)
  }
  d <- d0[keep, , drop = FALSE]
  write.csv(d, file.path(out, 'selected_rows.csv'), row.names = FALSE)

  rows <- list()
  k <- 0
  if (is_long) {
    for (i in seq_len(nrow(d))) {
      for (b in c('A', 'C', 'G', 'T')) {
        k <- k + 1
        rows[[k]] <- data.frame(
          motif = as.character(d[[motifc]][i]),
          position = as.character(d[[posc]][i]),
          base = b,
          raw_weight = suppressWarnings(as.numeric(d[[bcols[[b]]]][i])),
          stringsAsFactors = FALSE
        )
      }
    }
  } else {
    if (is.null(motifc)) motifc <- cn[1]
    pat <- regexec('^(?:position[_-]?)?([ACGT])[_-]?([0-9]+)$', toupper(setdiff(cn, motifc)))
    mm <- regmatches(setdiff(cn, motifc), pat)
    valid <- which(lengths(mm) == 3)
    if (!length(valid)) {
      fail('Wide input has no grouped A/C/G/T columns', 'Expected A1,C1,G1,T1 or A_1,C_1,G_1,T_1')
    }
    groups <- sort(unique(vapply(mm[valid], function(x) x[3], character(1))))
    for (i in seq_len(nrow(d))) {
      for (pos in groups) {
        for (b in c('A', 'C', 'G', 'T')) {
          hit <- which(
            toupper(cn) == paste0(b, pos) |
              toupper(cn) == paste0(b, '_', pos) |
              toupper(cn) == paste0('POSITION_', b, pos) |
              toupper(cn) == paste0('POSITION_', b, '_', pos)
          )
          if (length(hit)) {
            k <- k + 1
            rows[[k]] <- data.frame(
              motif = as.character(d[[motifc]][i]),
              position = pos,
              base = b,
              raw_weight = suppressWarnings(as.numeric(d[[cn[hit[1]]]][i])),
              stringsAsFactors = FALSE
            )
          }
        }
      }
    }
  }

  z <- do.call(rbind, rows)
  z <- z[is.finite(z$raw_weight) & !is.na(z$motif) & nzchar(z$motif), , drop = FALSE]
  if (!nrow(z)) fail('No valid motif weights remain')

  motifs <- unique(z$motif)
  requested <- vec(val('motif_order'))
  if (length(requested)) motifs <- unique(c(requested, motifs))
  motifs <- motifs[motifs %in% unique(z$motif)]
  reverse_pos <- boo('reverse_positions', FALSE)
  positions <- unique(as.character(z$position))
  if (!reverse_pos) {
    positions <- positions[order(suppressWarnings(as.numeric(positions)), positions)]
  } else {
    positions <- rev(positions[order(suppressWarnings(as.numeric(positions)), positions)])
  }
  z$motif <- factor(z$motif, levels = motifs)
  z$position <- factor(as.character(z$position), levels = positions)

  scale_in <- tolower(as.character(val('input_scale', 'weight')))
  norm <- tolower(as.character(val('normalize', 'probability')))
  z$raw_nonnegative <- pmax(0, z$raw_weight)
  z$probability <- ave(z$raw_nonnegative, interaction(z$motif, z$position, drop = TRUE), FUN = function(x) {
    if (norm == 'probability') if (sum(x) > 0) x / sum(x) else rep(0.25, length(x)) else x
  })
  z$probability <- pmin(1, pmax(0, z$probability))
  bg <- unlist(val('background_frequencies', list(A = 0.25, C = 0.25, G = 0.25, T = 0.25)))
  bg <- as.numeric(bg[c('A', 'C', 'G', 'T')])
  if (any(!is.finite(bg)) || sum(bg) <= 0) bg <- rep(0.25, 4)
  bg <- bg / sum(bg)
  names(bg) <- c('A', 'C', 'G', 'T')
  use_ic <- boo('information_content', TRUE)
  info <- tapply(seq_len(nrow(z)), interaction(z$motif, z$position, drop = TRUE), function(ix) {
    pp <- z$probability[ix]
    bb <- bg[z$base[ix]]
    if (use_ic) max(0, min(2, sum(ifelse(pp > 0, pp * log2(pp / bb), 0)))) else 1
  })
  z$information <- as.numeric(info[interaction(z$motif, z$position, drop = TRUE)])
  z$height <- if (use_ic) z$probability * z$information else z$probability
  min_h <- num('min_letter_height', 0)
  z_kept <- z[z$height >= min_h, , drop = FALSE]
  if (!nrow(z_kept)) fail('No letters remain after min_letter_height filtering')
  write.csv(
    z[, c('motif', 'position', 'base', 'raw_weight', 'probability', 'information', 'height')],
    file.path(out, 'motif_data_used.csv'),
    row.names = FALSE
  )

  colors <- classic_colors
  lc <- unlist(val('letter_colors', NULL), use.names = TRUE)
  if (length(lc)) {
    if (is.null(names(lc))) colors <- setNames(rep(lc, length.out = 4), names(colors))
    else colors[intersect(names(lc), names(colors))] <- lc[intersect(names(lc), names(colors))]
  }

  if (!requireNamespace('universalmotif', quietly = TRUE)) {
    fail('universalmotif is required for seqlogo rendering', 'install Bioconductor package universalmotif')
  }

  um_motifs <- lapply(motifs, function(m) {
    pwm <- matrix(0, nrow = 4, ncol = length(positions), dimnames = list(c('A', 'C', 'G', 'T'), as.character(positions)))
    sub <- z[z$motif == m, , drop = FALSE]
    for (po in positions) {
      slice <- sub[as.character(sub$position) == po, , drop = FALSE]
      if (!nrow(slice)) {
        pwm[, po] <- bg
        next
      }
      vals <- setNames(slice$probability, as.character(slice$base))
      pwm[, po] <- unname(vals[c('A', 'C', 'G', 'T')])
      pwm[is.na(pwm[, po]), po] <- 0
      s <- sum(pwm[, po])
      pwm[, po] <- if (s > 0) pwm[, po] / s else bg
    }
    universalmotif::create_motif(
      pwm,
      alphabet = 'DNA',
      type = 'PPM',
      name = as.character(m),
      bkg = bg
    )
  })
  names(um_motifs) <- as.character(motifs)
  nmot <- length(um_motifs)

  title <- as.character(val('title', 'Motif enrichment')[1] %||% 'Motif enrichment')
  xlab <- as.character(val('xlab', 'Position')[1] %||% 'Position')
  ylab_raw <- as.character(val('ylab', '')[1] %||% '')
  ylab <- if (!nzchar(ylab_raw) || identical(ylab_raw, 'Motif')) {
    if (use_ic) 'bits' else 'Probability'
  } else {
    ylab_raw
  }
  pos_labels <- vec(val('position_labels'))
  axis_labels <- if (length(pos_labels) == length(positions)) pos_labels else as.character(positions)

  parse_index <- function(tok) {
    tok <- trimws(as.character(tok %||% ''))
    if (!nzchar(tok)) return(integer())
    if (tok %in% axis_labels) return(which(axis_labels == tok)[1])
    if (tok %in% as.character(positions)) return(match(tok, as.character(positions))[1])
    n <- suppressWarnings(as.integer(tok))
    if (is.finite(n) && n >= 1 && n <= length(axis_labels)) return(n)
    integer()
  }
  expand_range <- function(tok) {
    tok <- trimws(as.character(tok %||% ''))
    if (grepl('^\\d+\\s*[-:]\\s*\\d+$', tok)) {
      parts <- as.integer(unlist(strsplit(tok, '[-:]')))
      if (length(parts) == 2 && all(is.finite(parts))) {
        return(seq(min(parts), max(parts)))
      }
    }
    parse_index(tok)
  }
  hl_color <- as.character(val('highlight_color', '#FFE08A')[1] %||% '#FFE08A')
  hl_alpha <- num('highlight_alpha', 0.38)
  hl_border <- as.character(val('highlight_border_color', '#C47B00')[1] %||% '#C47B00')
  hl_loci_raw <- c(
    unlist(val('highlight_positions', NULL), use.names = FALSE),
    unlist(val('highlight_loci', NULL), use.names = FALSE),
    unlist(val('highlight_pos', NULL), use.names = FALSE)
  )
  hl_loci_raw <- unique(trimws(as.character(hl_loci_raw %||% character())))
  hl_loci_raw <- hl_loci_raw[nzchar(hl_loci_raw)]
  hl_bases_global <- toupper(vec(val('highlight_bases', NULL)))
  hl_bases_global <- hl_bases_global[hl_bases_global %in% c('A', 'C', 'G', 'T')]
  hl_motifs_global <- as.character(vec(val('highlight_motifs', NULL)))
  hl_bands <- data.frame(motif = character(), xmin = numeric(), xmax = numeric(), stringsAsFactors = FALSE)
  hl_boxes <- data.frame(motif = character(), xmin = numeric(), xmax = numeric(), ymin = numeric(), ymax = numeric(), stringsAsFactors = FALSE)
  add_band <- function(motif_name, idx) {
    if (!length(idx) || is.na(idx)) return()
    hl_bands <<- rbind(hl_bands, data.frame(motif = motif_name, xmin = idx - 0.5, xmax = idx + 0.5, stringsAsFactors = FALSE))
  }
  add_box <- function(motif_name, idx, base) {
    if (!length(idx) || is.na(idx) || !nzchar(base)) return()
    pos_id <- as.character(positions[idx])
    slice <- z[as.character(z$motif) == motif_name & as.character(z$position) == pos_id, , drop = FALSE]
    if (!nrow(slice)) return()
    slice <- slice[order(slice$height, slice$base), , drop = FALSE]
    ymin <- c(0, cumsum(slice$height))
    hit <- which(slice$base == base)[1]
    if (!is.finite(hit)) return()
    hl_boxes <<- rbind(hl_boxes, data.frame(
      motif = motif_name,
      xmin = idx - 0.46, xmax = idx + 0.46,
      ymin = ymin[hit], ymax = ymin[hit + 1],
      stringsAsFactors = FALSE
    ))
  }
  for (tok in hl_loci_raw) {
    parts <- trimws(unlist(strsplit(tok, '[:|,]')))
    parts <- parts[nzchar(parts)]
    motif_name <- NA_character_
    pos_toks <- character()
    base_tok <- NA_character_
    if (length(parts) >= 3) {
      motif_name <- parts[1]
      pos_toks <- parts[2]
      base_tok <- toupper(parts[3])
    } else if (length(parts) == 2) {
      if (parts[1] %in% as.character(motifs)) {
        motif_name <- parts[1]
        pos_toks <- parts[2]
      } else if (toupper(parts[2]) %in% c('A', 'C', 'G', 'T')) {
        pos_toks <- parts[1]
        base_tok <- toupper(parts[2])
      } else {
        pos_toks <- parts
      }
    } else if (grepl('^[ACGT]\\d+$', toupper(tok))) {
      base_tok <- substr(toupper(tok), 1, 1)
      pos_toks <- substring(tok, 2)
    } else if (grepl('^\\d+[ACGT]$', toupper(tok))) {
      base_tok <- substr(toupper(tok), nchar(tok), nchar(tok))
      pos_toks <- substring(tok, 1, nchar(tok) - 1)
    } else {
      pos_toks <- tok
    }
    idxs <- unique(unlist(lapply(pos_toks, expand_range)))
    idxs <- idxs[is.finite(idxs) & idxs >= 1 & idxs <= length(axis_labels)]
    target_motifs <- if (!is.na(motif_name) && nzchar(motif_name)) {
      as.character(motif_name)
    } else if (length(hl_motifs_global)) {
      hl_motifs_global
    } else {
      as.character(motifs)
    }
    target_motifs <- target_motifs[target_motifs %in% as.character(motifs)]
    bases <- character()
    if (!is.na(base_tok) && base_tok %in% c('A', 'C', 'G', 'T')) bases <- base_tok
    else if (length(hl_bases_global)) bases <- hl_bases_global
    for (m in target_motifs) {
      for (idx in idxs) {
        add_band(m, idx)
        for (b in bases) add_box(m, idx, b)
      }
    }
  }
  if (!nrow(hl_bands) && length(hl_bases_global)) {
    for (m in if (length(hl_motifs_global)) hl_motifs_global else as.character(motifs)) {
      if (!m %in% as.character(motifs)) next
      for (idx in seq_along(axis_labels)) for (b in hl_bases_global) add_box(m, idx, b)
    }
  }
  if (nrow(hl_bands)) hl_bands <- unique(hl_bands)
  if (nrow(hl_boxes)) hl_boxes <- unique(hl_boxes)
  y_top <- if (use_ic) 2 else 1

  if (!requireNamespace('patchwork', quietly = TRUE)) {
    fail('patchwork is required to stack seqlogos', 'install.packages("patchwork")')
  }
  show_names <- boo('show_motif_labels', TRUE)
  show_pos <- boo('position_ticks', TRUE)
  grid_on <- boo('grid_show', FALSE)
  bg_plot <- as.character(val('plot_background', '#FFFFFF')[1] %||% '#FFFFFF')
  bg_panel <- as.character(val('panel_background', '#FFFFFF')[1] %||% '#FFFFFF')
  grid_col <- as.character(val('grid_color', '#E6E6E6')[1] %||% '#E6E6E6')
  x_angle <- num('position_text_angle', 0)
  logo_theme <- theme(
    plot.background = element_rect(fill = bg_plot, colour = NA),
    panel.background = element_rect(fill = bg_panel, colour = NA),
    panel.grid = if (grid_on) element_line(colour = grid_col) else element_blank(),
    plot.title = element_text(
      size = max(9, num('motif_label_size', 11)),
      colour = as.character(val('motif_label_color', '#222222')[1] %||% '#222222'),
      face = 'plain',
      hjust = 0.5
    ),
    axis.text.x = element_text(angle = x_angle, hjust = if (x_angle > 0) 1 else 0.5),
    legend.position = 'none'
  )
  x_limits <- c(0.5, length(axis_labels) + 0.5)
  panels <- lapply(seq_along(um_motifs), function(i) {
    g <- universalmotif::view_motifs(
      um_motifs[[i]],
      use.type = if (use_ic) 'ICM' else 'PPM',
      tryRC = FALSE,
      colour.scheme = colors,
      show.names = FALSE,
      show.positions = show_pos,
      min.height = max(0.01, min_h),
      text.size = num('base_size', 11) + 2,
      fit.to.height = if (use_ic) NULL else 1
    )
    g <- g +
      scale_x_continuous(
        breaks = seq_along(axis_labels),
        labels = axis_labels,
        limits = x_limits,
        expand = expansion(mult = c(0.02, 0.02))
      ) +
      labs(
        title = if (show_names) as.character(motifs[i]) else NULL,
        x = if (i == nmot) xlab else NULL,
        y = ylab
      ) +
      logo_theme
    mname <- as.character(motifs[i])
    bands <- hl_bands[hl_bands$motif == mname, , drop = FALSE]
    if (nrow(bands)) {
      g <- g + geom_rect(
        data = bands,
        aes(xmin = .data$xmin, xmax = .data$xmax, ymin = 0, ymax = y_top),
        inherit.aes = FALSE,
        fill = hl_color,
        alpha = hl_alpha,
        colour = NA
      )
      g$layers <- c(g$layers[length(g$layers)], g$layers[-length(g$layers)])
    }
    boxes <- hl_boxes[hl_boxes$motif == mname, , drop = FALSE]
    if (nrow(boxes)) {
      g <- g + geom_rect(
        data = boxes,
        aes(xmin = .data$xmin, xmax = .data$xmax, ymin = .data$ymin, ymax = .data$ymax),
        inherit.aes = FALSE,
        fill = NA,
        colour = hl_border,
        linewidth = 0.7
      )
    }
    if (i < nmot) g <- g + theme(axis.text.x = element_blank(), axis.ticks.x = element_blank())
    g
  })
  q <- patchwork::wrap_plots(panels, ncol = 1)
  if (boo('title_show', TRUE) && nzchar(title)) {
    q <- q + patchwork::plot_annotation(
      title = title,
      theme = theme(
        plot.title = element_text(
          size = num('title_size', 16),
          colour = as.character(val('title_color', '#222222')[1] %||% '#222222'),
          face = as.character(val('title_face', 'bold')[1] %||% 'bold'),
          hjust = 0.5
        ),
        plot.background = element_rect(fill = bg_plot, colour = NA)
      )
    )
  }

  w <- num('width', max(8, 1 + length(positions) * num('width_per_position', 0.7)))
  h <- num('height', max(3.2, nmot * num('height_per_motif', 2.4)))
  dpi <- as.integer(num('dpi', 300))
  # Generic appearance parameters not handled by this plugin (R/runtime/omicscanvas_theme.R).
  if (!exists('omicscanvas_apply_theme')) { .oc_f <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[1]); .oc_rt <- file.path(dirname(normalizePath(.oc_f, mustWork = FALSE)), '..', '..', 'R', 'runtime', 'omicscanvas_theme.R'); if (!file.exists(.oc_rt)) .oc_rt <- file.path('R', 'runtime', 'omicscanvas_theme.R'); sys.source(.oc_rt, envir = globalenv()) }; q <- omicscanvas_apply_theme(q, p, only = c('font_family', 'legend_position', 'legend_show'))
  ggsave(file.path(out, 'result.svg'), q, width = w, height = h, units = 'in')
  ggsave(file.path(out, 'result.pdf'), q, width = w, height = h, units = 'in')
  ggsave(file.path(out, 'result.png'), q, width = w, height = h, units = 'in', dpi = dpi)

  if (boo('interactive', TRUE)) {
    if (!requireNamespace('plotly', quietly = TRUE) || !requireNamespace('htmlwidgets', quietly = TRUE)) {
      fail('plotly / htmlwidgets not available')
    }
    pl <- tryCatch(plotly::ggplotly(q, tooltip = 'text'), error = function(e) NULL)
    if (is.null(pl)) {
      writeLines(
        '<html><body><p>Interactive Plotly output could not be built for this seqlogo; see result.png.</p></body></html>',
        file.path(out, 'result.html')
      )
    } else {
      pl <- plotly::config(
        pl,
        displaylogo = FALSE,
        scrollZoom = boo('zoom', TRUE),
        modeBarButtonsToAdd = if (boo('lasso_select', FALSE) || boo('selectable', FALSE)) c('lasso2d', 'select2d') else character()
      )
      htmlwidgets::saveWidget(pl, file.path(out, 'result.html'), selfcontained = TRUE)
    }
  } else {
    writeLines('<html><body><p>Interactive Plotly output is disabled.</p></body></html>', file.path(out, 'result.html'))
  }

  per <- lapply(motifs, function(m) {
    x <- z[z$motif == m, ]
    list(
      n_letters = nrow(x),
      n_positions = length(unique(x$position)),
      total_height = round(sum(x$height), 6),
      max_height = round(if (nrow(x)) max(x$height) else 0, 6)
    )
  })
  names(per) <- motifs
  fig <- list(
    plugin = 'interactive_motif_logo_plot',
    title = title,
    engine = 'seqlogo',
    motifs = as.character(motifs),
    n_motifs = nmot,
    n_positions = length(positions),
    bases = c('A', 'C', 'G', 'T'),
    information_content = use_ic,
    input_scale = scale_in,
    n_letters = nrow(z),
    ranges = list(position = c(1, length(positions)), height = range(z$height)),
    per_motif_summary = per,
    outputs = c('result.svg', 'result.pdf', 'result.png', 'result.html', 'figure.json', 'run.log', 'motif_data_used.csv', 'selected_rows.csv')
  )
  writeLines(toJSON(fig, auto_unbox = TRUE, pretty = TRUE, null = 'null'), file.path(out, 'figure.json'))
  unlink(file.path(out, 'error.json'), force = TRUE)
  logmsg(sprintf('Finished interactive_motif_logo_plot: %d motifs, %d positions, %d letters', nmot, length(positions), nrow(z)))
}

tryCatch(main(), error = function(e) fail('Plot generation failed', conditionMessage(e)))
