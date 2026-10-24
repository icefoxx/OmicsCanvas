classicVlnPlot <- function(seu, features = NULL, assay = 'RNA', slot = "data", 
                           group.by = NULL, keyvar = NULL, valvar = NULL, add.dot = FALSE,
                           add.anno = FALSE, annovar = NULL, add.stat = 'boxplot', 
                           long.var = NULL, xlab = NULL, ylab = NULL, title = NULL, 
                           color.use = NULL, rotate.x = FALSE, plot.legend = FALSE, 
                           psize = 0.5, force = T, plot.title = '',
                           plot.ylab = 'Expression level',plot.y.anno = '', ...) {
  .df <- ckFeas(seu, features = features, assay = assay, slot = slot, 
                group.by = group.by, force = force, return.matrix = TRUE,
                keyvar = keyvar, valvar = valvar, add.anno = add.anno,
                annovar = annovar, format = 'long', long.var = long.var)
  .colnames.df <- colnames(.df)
  if (any(.colnames.df %in% c('group', 'keyvar', 'valvar', 'annovar'))) {
    cli_abort(message = "The column names 'group', 'keyvar', 'valvar', and 'annovar' are reserved and cannot be used as column names in the data frame.")
  }
  .median.quartile <- function(x){
    .out <- quantile(x, probs = c(0.25,0.5,0.75))
    names(.out) <- c("ymin","y","ymax")
    return(.out) 
  }
  .layer.vln <- ggplot(.df, aes(x = !!ensym(keyvar), y = !!ensym(valvar), fill = !!ensym(keyvar))) +
    geom_violin(scale = "width", adjust = 1, trim = TRUE)
  if (!is.null(add.stat)) {
    if (add.stat == 'boxplot') {
      .layer.vln <- .layer.vln + geom_boxplot(width = 0.1, position = position_dodge(0.9), outlier.size = psize)
    } else if (add.stat == 'median') {
      .layer.vln <- .layer.vln + stat_summary(fun.y=median.quartile, geom='point', size = psize) 
    } else {
      cli_abort(message = "The {.code add.stat} parameter must be either 'boxplot' or 'median'.")
    }
  }
  if (isTRUE(add.dot)){
    .layer.vln <- .layer.vln + geom_quasirandom(dodge.width = 0.9, varwidth = TRUE, size = 0.1)
  } 
  .p <- .layer.vln + 
    scale_y_continuous(expand = c(0, 0), position="right", labels = function(x)
      c(rep(x = "", times = length(x)-2), x[length(x) - 1], "")) +
    facet_grid(rows = vars(!!ensym(group.by)), scales = "free") + 
    theme(legend.position = "none", panel.spacing = unit(0, "lines"),
          plot.title = element_text(hjust = 0.5),
          panel.background = element_rect(fill = NA, color = "black"),
          plot.margin = margin(7, 7, 0, 7, "pt"),
          strip.background = element_rect(fill = "white"),
          strip.text = element_text(face = "bold"),
          strip.text.y.right = element_text(angle = 0),
          axis.title.x = element_blank(),
          axis.ticks.x = element_blank(),
          #        axis.text.x = element_blank()) +
          axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1, color = "black")) +
    ggtitle(plot.title) + ylab(plot.ylab) 
  if (isTRUE(add.anno)){
    if (is.data.frame(annovar)){
      .annovar <- annovar
      if (!all(unique(.df[[keyvar]] %in% .annovar[[keyvar]]))){
        cli_abort(message = "The keyvar variable in the input matrix or seu object does not match the key variable in the annotation data frame.")
      }
    } else if (is.vector(annovar) & annovar %in% .colnames.df){
      .annovar <- .df[ ,c(keyvar, annovar), with = FALSE]
    } else {
      cli_abort(message = "The annotation variable must be a data frame or a vector that is a column in the input matrix or seu object.")
    }
    colnames(.annovar) <- c(keyvar, 'annotation')
    if (!is.factor(.annovar[[keyvar]])) .annovar[[keyvar]] <- factor(.annovar[[keyvar]], levels = levels(.df[[keyvar]]))
    if (!is.factor(.annovar[['annotation']])) .annovar[['annotation']] <- factor(.annovar[['annotation']])
    .layer.anno <- ggplot(.annovar, aes(x = !!ensym(keyvar), y = 1, fill = annotation)) + 
      geom_tile() + theme_bw(base_size = 12) +
      scale_y_continuous(expand = c(0, 0)) + 
      ylab(plot.y.anno) + xlab('') +
      guides(fill = guide_legend(direction = "vertical", label.position = "right",
                                 title.theme = element_blank(), keyheight = 0.5, nrow = 2)) +
      theme(legend.position = "bottom",
            legend.justification = "left",
            legend.margin = margin(0,0,0,0),
            legend.box.margin = margin(-10,5,0,0),
            panel.spacing = unit(0, "lines"),
            panel.background = element_blank(),
            panel.border = element_blank(),
            plot.background = element_blank(),
            plot.margin = margin(0, 7, 7, 7, "pt"),
            axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5, color = "black"),
            #        axis.title.y = element_blank(),
            axis.ticks.y = element_blank(),
            axis.text.y = element_blank())
    .p <- .p + theme(axis.text.x = element_blank())
    .p <- .p/.layer.anno + patchwork::plot_layout(heights = c(20, 1))
  }
  return(.p)
}


