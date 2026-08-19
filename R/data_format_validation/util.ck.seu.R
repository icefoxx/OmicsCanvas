detFeas <- function(x, seu, assay = 'RNA', rtn = NULL){
  .input.type <- c('Matrix', 'dgCMatrix', 'data.frame', 'SingleCellExperiment', 'Assay', 'Assay5')
  if (inherits(seu, "Seurat")) {
    .data <- seu[[assay]]
  } else {
    .data <- seu
  }
  .input.type.ck <- sapply(.input.type, function(i) methods::is(.data, i))
  if (any(.input.type.ck)) {
    .data.feas <- rownames(.data)
  } else {
    .data.feas <- .data
  }
  .x.in.seu <- x %in% .data.feas
  if (is.null(rtn)) {
    if ( any(!.x.in.seu)) {
      .feas.ms <- x[!.x.in.seu]
      stop(stringr::str_glue("Input features {.feas.ms} are not in the given object. Please check."))
    }
  } else {
    if (identical(rtn, 'common')) {
      return(x[.x.in.seu])
    } else if (identical(rtn, 'union')) {
      return(union(x = x, y = .data.feas))
    } else if (identical(rtn, 'diff')) {
      return(setdiff(x = x, y = .data.feas))
    }
  }
}

ckLinearReduMethod <- function(x, seu){
  .x <- match(tolower(x), c("pca", "svd", "ica", "nmf", "mds", "glmpca"))
  if (any(!x %in% c("pca", "svd", "ica", "nmf", "mds", "glmpca", Seurat::Reductions(seu)))) {
    stop("'linearRedu' must be one of 'pca', 'svd', 'ica', 'nmf', 'mds', 'glmpca'.")
  }
  return(.x)
}


ckNonLinearReduMethod <- function(x, seu){
  if (any(! x %in% c("umap", "umap-naive", "tsne", "dm", "phate", "pacmap", "trimap", "largevis", "fr"))) {
    stop("'nonlinearRedu' must be one of 'umap', 'tsne', 'dm', 'phate', 'pacmap', 'trimap', 'largevis', 'fr'.")
  }
}

ckClusterMethod <- function(x){
  if (!x %in% c("louvain", "louvain_refined","slm", "leiden")) stop("'clusterMethod' must be one of 'louvain', 'louvain_refined','slm', 'leiden'.")
}

ckNormMethod <- function(x){
  if (!x %in% c("LogNormalize", "SCT", "TFIDF")) {
    stop("'Mormalization method' must be one of: 'LogNormalize', 'SCT', 'TFIDF'")
  }
}

ckHVFtype <- function(x){
  if (!x %in% c("global") && !is.numeric(x) ) {
    stop("'HVFtype' must be one of: 'global' OR ratio of samples containing this HVF")
  }
}


ckSeu <- function(seu) {
  if (!inherits(seu, "Seurat")) stop(stringr::str_glue("Input object is not an object of class: Seurat."))
}