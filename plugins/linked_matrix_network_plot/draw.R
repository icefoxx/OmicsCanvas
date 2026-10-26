draw_plot <- function(df) {
  row_col <- oc_col(df, 'row_column', 'feature')
  column_col <- oc_col(df, 'column_column', 'condition')
  value_col <- oc_col(df, 'value_column', 'value')
  d <- data.frame(feature = as.character(df[[row_col]]), condition = as.character(df[[column_col]]), value = oc_numeric(df, value_col))
  if (anyNA(d$feature) || anyNA(d$condition) || anyDuplicated(d[c('feature','condition')])) stop('Supply one nonmissing numeric value per feature/condition pair.')
  if (is.null(opt$links) || !nzchar(opt$links)) stop('Supply a links CSV with source, target, weight and optional group. Sources must match matrix features.')
  links <- read_table(opt$links)
  if (!all(c('source','target','weight') %in% names(links))) stop('The links CSV requires source, target and weight columns.')
  links$weight <- oc_numeric(links, 'weight')
  links$group <- oc_group(links, 'edge_group_column', 'group')
  if (anyNA(links$source) || anyNA(links$target) || any(!nzchar(links$source)) || any(!nzchar(links$target))) stop('Link endpoint labels must be nonempty.')
  if (any(!links$source %in% d$feature)) stop('Every link source must match a feature row in the matrix.')
  removed <- sum(links$weight == 0)
  if (removed) log_msg(sprintf('Omitted %d zero-weight links.', removed))
  links <- links[links$weight != 0, , drop = FALSE]
  if (!nrow(links)) stop('No nonzero links remain. Use an ordinary heatmap when no links are supplied.')
  rows <- unique(d$feature); columns <- unique(d$condition)
  if (length(rows) > 80 || length(columns) > 40 || length(unique(links$target)) > 50) stop('Filter to at most 80 rows, 40 columns and 50 target nodes.')
  d$x <- match(d$condition, columns); d$y <- match(d$feature, rev(rows))
  targets <- names(sort(tapply(match(links$source, rev(rows)), links$target, mean)))
  target_y <- setNames(seq(1, max(1,length(rows)), length.out = length(targets)), targets)
  source_x <- length(columns) + .65
  target_x <- source_x + num('node_gap', 4)
  links$x <- source_x; links$y <- match(links$source, rev(rows)); links$xend <- target_x; links$yend <- target_y[links$target]
  source_nodes <- data.frame(x = source_x, y = match(unique(links$source), rev(rows)), label = unique(links$source))
  target_nodes <- data.frame(x = target_x, y = target_y[targets], label = targets)
  p <- ggplot(d, aes(x,y))
  if (chr('matrix_mark', 'heatmap') == 'dot') p <- p + geom_point(aes(fill = value, size = abs(value)), shape = 21, color = '#FFFFFF', stroke = .1) + scale_size_area(max_size = num('dot_size', 5), name = 'Magnitude') else p <- p + geom_tile(aes(fill = value), width = .92, height = .92)
  p <- p + geom_curve(data = links, aes(x,y,xend=xend,yend=yend,color=group,linewidth=abs(weight)), inherit.aes = FALSE, curvature = num('curvature', .12), alpha = num('edge_alpha', .65)) +
    scale_color_manual(values = oc_colors(links$group), name = 'Link class') + scale_linewidth_continuous(range = c(num('line_width', .6)*.4, num('line_width',.6)*2), name = '|Weight|') +
    geom_point(data = rbind(source_nodes,target_nodes), aes(x,y), inherit.aes = FALSE, shape = 21, fill = '#FFFFFF', color = '#4B6071', size = num('point_size', 2)) +
    geom_text(data = target_nodes, aes(x+.15,y,label=label), inherit.aes = FALSE, hjust = 0, size = num('label_size',2.8), family = chr('font_family','sans'), color = '#415A6D') +
    scale_fill_gradient2(low = chr('low_color','#397DA3'), mid = '#F6F6F6', high = chr('high_color','#D16472'), midpoint = 0, name = value_col) +
    scale_x_continuous(breaks = seq_along(columns), labels = columns, limits = c(.4,target_x+max(nchar(targets))*num('label_size',2.8)*.025+1)) +
    scale_y_continuous(breaks = seq_along(rows), labels = rev(rows), expand = expansion(add = .6)) + oc_labels('', '') + oc_theme() + theme(axis.line = element_blank(), axis.ticks = element_blank(), axis.text.x = element_text(angle=45,hjust=1))
  oc_result(p,d,list(method='supplied_matrix_and_relationships',edge_width='absolute supplied weight',target_order='source-row barycenters'),list('links_used.csv'=links),'Supplied weighted relationships; no interaction inference, statistical testing or drug-response model fitted')
}
