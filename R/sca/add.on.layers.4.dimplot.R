visGraph <- function(graph, loci, edge.color = "black", 
                     edge.alpha = 0.5, edge.size = c(0.5, 5),
                     show.legend = F){
  suppressPackageStartupMessages(library(ggplot2))
  graph <- toDenseMatrix(graph)
  graph[graph == 0] <- NA
  graph[upper.tri(graph)] <- NA
  graph.df <- melt(graph, na.rm = TRUE, stringsAsFactors = FALSE)
  graph.df[, "value"] <- as.numeric(graph.df[, "value"])
  graph.df[, "Var1"] <- as.character(graph.df[, "Var1"])
  graph.df[, "Var2"] <- as.character(graph.df[, "Var2"])
  graph.df[, "x"] <- loci[graph.df[, "Var1"], "x"]
  graph.df[, "y"] <- loci[graph.df[, "Var1"], "y"]
  graph.df[, "xend"] <- loci[graph.df[, "Var2"], "x"]
  graph.df[, "yend"] <- loci[graph.df[, "Var2"], "y"]
  return(list(geom_segment(data = graph.df, 
                           mapping = aes(x = x, y = y, xend = xend, yend = yend, 
                                         linewidth = value), 
                           color = edge.color, alpha = edge.alpha, show.legend = show.legend), 
              scale_linewidth_continuous(range = edge.size))
  )
}

visDense <- function(data, fill = F, density.color = "grey80", 
                     palette = "Greys", palcolor =  NULL){
  suppressPackageStartupMessages(library(ggplot2))
  suppressPackageStartupMessages(library(ggnewscale))
  .density <- NULL
  .dense.color <- paletteCustomize(palette = palette, palcolor = palcolor)
  if (isTRUE(fill)) {
    .dense.color <- palette_scp(palette = palette, palcolor = palcolor)
      .density <- list(stat_density_2d(geom = "raster", 
                                      aes(x = .data[["x"]], y = .data[["y"]], 
                                          fill = after_stat(density)), contour = FALSE, 
                                      inherit.aes = FALSE, show.legend = FALSE), 
                      scale_fill_gradientn(name = "Density", colours = .dense.color), 
                      new_scale_fill())
    } else {
      .density <- geom_density_2d(aes(x = .data[["x"]], 
                                     y = .data[["y"]]), color = density.color, 
                                 inherit.aes = FALSE)
    }
}


