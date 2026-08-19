
scale01 <- function(x) {  (x - min(x)) / (max(x) - min(x))}

#' calculate the density for features
#'
#' @param w feature values
#' @param cell.xy cell loci in the reduction
#' @param bias weight value
#' @param cells how many neighbors will be used to smooth values
#' @name calDensity
#' @return density matirx
#' @author Qiong Zhang
#'
calDensity <- function(w, cell.xy, bias, cells) {
  require(ks, quietly = T)
  .wtden <- function(x, y, w, bias = 1) {
    .nx <- length(x)
    .ny <- length(y)
    .nw <- length(w)
    .lims <- c(range(x), range(y))
    .h <- c(ks::hpi(x), ks::hpi(y)) * bias
    .intervals <- ceiling( .nx / cells )
    .gx <- seq.int(.lims[1], .lims[2], length.out = .intervals)
    .gy <- seq.int(.lims[3], .lims[4], length.out = .intervals)
    .ax <- outer(.gx, x, "-") / .h[1]
    .ay <- outer(.gy, y, "-") / .h[2]
    .w <- Matrix::Matrix(rep(w, .intervals), nrow = .intervals, ncol = .nx, byrow = TRUE)
    .z <- Matrix::tcrossprod(dnorm(.ax) * .w, dnorm(.ay) * .w) / (sum(.w) * .h[1] * .h[2])
    return(list(x = .gx, y = .gy, z = .z))
  }
  .dens <- .wtden(x = cell.xy[, 1], y = cell.xy[, 2], w = w / sum(w) * length(w), bias = bias)
  .xy <- cbind(findInterval(cell.xy[, 1], .dens$x), findInterval(cell.xy[, 2], .dens$y))
  return(.dens$z[.xy])
}

#' Plot the density for features and return the density data
#'
#' @param Mat expression matrix
#' @param cell.xy cell loci in the reduction
#' @param features features
#' @param bias weight value
#' @param cells how many neighbors will be used to smooth values
#' @param size dot size
#' @param shape shape of dot
#' @param pal colors
#' @name plotFeatureDen
#' @return density matirx and gglot object
#' @author Qiong Zhang
#'
plotFeatureDen <- function(Mat, cell.xy, features, bias, size, shape, cells, pal, raster, scale01 = F, ...) {
  .dims <- colnames(cell.xy)
  .res <- apply(Mat, 1, calDensity, cell.xy, bias, cells)
  if (nrow(Mat) > 1) {
    .z <- apply(.res, 1, prod)
    .labels <- paste0(paste(features, "+", sep = ""), collapse = " ")
  }else{
    .z <- .res
    .labels <- paste0(features, "+")
  }
  if (isTRUE(scale01)) .z <- scale01(.z)
  .p <- densityPlot(.z, .labels, cell.xy, .dims, size, shape, pal, "Density",...)
  return(list(plot = .p, data = .z))
}


#' Plot the density for features
#'
#' @param z density matrix
#' @param labels title of plot
#' @param cell.xy cell loci in the reduction
#' @param dims names of x and y axis
#' @param size dot size
#' @param shape shape of dot
#' @param pal colors
#' @param legend lengend name
#' @name densityPlot
#' @return density matirx and gglot object
#' @author Qiong Zhang
#'
densityPlot <- function(z, labels, cell.xy, dims, size, shape, pal, legend_name, ...) {
  invisible(require(ggplot2, quietly = T))
  .df.gp <- cbind(cell.xy, z)
  colnames(.df.gp) <- c(dims, legend_name)
  .p <- ggplot(as.data.frame(.df.gp)) +
    aes_string(dims[1], dims[2], color = legend_name) +
    geom_point(shape = shape, size = size) +
    xlab(gsub("_", " ", dims[1])) +
    ylab(gsub("_", " ", dims[2])) +
    ggtitle(labels) +
#    labs(color = guide_legend(legend_name)) +
    theme(
      text = element_text(size = 14),
      panel.background = element_blank(),
      axis.text.x = element_text(color = "black"),
      axis.text.y = element_text(color = "black"),
      axis.line = element_line(size = 0.25),
      strip.background = element_rect(color = "black", fill = "#ffe5cc")
    )
  .p <- .p + scale_color_viridis_c(option = pal, ...)
  ggrastr::rasterise(.p, dpi = 300)
}


#' Plot the density for features
#'
#' @param seu seurat obj
#' @param feature feature for display
#' @param slot which slot
#' @param assay which assay
#' @param bias weight of smooth
#' @param reduction which  reduction used for knn smoothing
#' @param size dot size for plot
#' @param shape shape of dot
#' @param cells cell number for knn
#' @param pal colors
#' @param raster logical: raster dot
#' @name GsDenPlot
#' @return density matirx and gglot object
#' @author Qiong Zhang
#' @export
#'
GsDenPlot <- function(seu, features, slot = "data", assay = "RNA", bias = 1, reduction = NULL, size = 0.5, shape = 16, cells = 25, pal = "turbo", raster = "T", scale01 = F, ...) {
  .reductions <- Seurat::Reductions(seu)
  if ( length(.reductions) == 0 ) stop("reduction missing!")
  if (is.null(reduction)) {
    .reduction <- .reductions[length(.reductions)]
  } else {
    if (reduction %in% .reductions) {
      .reduction <- reduction
    } else {
      stop("Target reduction missing")
    }
  }
  .cell.xy <- Seurat::Embeddings(seu[[.reduction]])[, c(1,2), drop = F]
  .metadata <- seu@meta.data
  if (all(features %in% colnames(.metadata))) {
    .Mat <- .metadata[, features, drop = FALSE]
  }else{
    .Mat <- t(Seurat::FetchData(seu, vars = features, assay = assay, slot = slot))
  }
  plotFeatureDen(.Mat, .cell.xy, features, bias, size, shape, cells, pal, raster, scale01 = scale01, ...)
}


