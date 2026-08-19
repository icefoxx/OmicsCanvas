roughCluster <- function(expM, D = 1, method = 'pearson'){
  suppressPackageStartupMessages(library(apcluster))
  .sim <- c("cosine", "correlation", "jaccard", "ejaccard", "fjaccard", "dice", "edice",
            "hamann", "faith", "simple matching")
  .dis <- c("euclidean", "chisquared", "kullback", "jeffreys", "jensen", "manhattan",
            "maximum", "canberra", "minkowski", "hamming")
  .all.mtd <- c(.sim, .dis, "pearson", "spearman")
  stopifnot(method %in% .all.mtd)
  .method.use <- method
  if (.method.use %in% c("pearson", "spearman")) {
    if (.method.use == 'spearman') expM <- Matrix::t(matrixStats::colRanks(expM, ties.method = 'min'))
    .method.use <- 'correlation'
  }
  .fun.use <- get( if (.method.use %in% .sim) "simil" else "dist", loadNamespace('proxyC'))
  .sim.mat <- .fun.use(expM, margin = D, method = .method.use)
  .sim.mat[is.na(.sim.mat)] <- 0
  .sim.ap <- apcluster(.sim.mat)
  if (length(.sim.ap@clusters) < 2) {
    warning(stringr::str_glue("No cluster is found in the data via {method}. Please check the data or the method used."))
    return(NULL)
  } else {
    return(sapply(.sim.ap@clusters, names))
  }
}

toDenseMatrix <- function(x) {
  if (!inherits(x, "dgCMatrix")) {
    return(as.matrix(x))
  } else {
    .row_pos <- x@i
    .col_pos <- findInterval(seq_along(x@x) - 1, x@p[-1])
    .out <- bayNorm::asMatrix(rp = .row_pos, cp = .col_pos, z = x@x, nrows = x@Dim[1], ncols = x@Dim[2])
    attr(.out, "dimnames") <- list(x@Dimnames[[1]], x@Dimnames[[2]])
    return(.out)
  }
}

normByX.matrix <- function(mat, type = 'column'){
  .type <- match.arg(type, c('column', 'row'))
  if (inherits(mat, 'dgCMatrix')) {
    if (.type == 'column') {
      mat@x <- mat@x / rep.int(Matrix::colSums(mat), diff(mat@p))
      .mat <- mat
    }
    if (.type == 'row') {
      .mat <- Matrix::t(mat)
      .mat@x <- .mat@x / rep.int(Matrix::colSums(.mat), diff(.mat@p))
      .mat <- Matrix::t(.mat)
    }
  } else if (is.matrix(mat)) {
    if (.type == 'row') {
      .mat <- mat / Matrix::rowSums(mat)
    } else if (.type == 'column') {
      .mat <- t(mat)
      .mat <- t(.mat / Matrix::rowSums(.mat))
    }
    .mat[is.na(.mat)] <- 0
  } else {
    cli::cli_abort("The input matrix must be a matrix or a dgCMatrix object.")
  }
  return(.mat)
}


