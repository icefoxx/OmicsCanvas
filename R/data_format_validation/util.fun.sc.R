clusterIdReassignBySim <- function(Seu, clusterIdVar, assay = 'RNA', features = NULL, slot = 'data', method = 'pearson') {
  ckSeu(Seu)
  ckCols(Seu@meta.data, clusterIdVar)
  .features <- features %||% VariableFeatures(Seu)
  .expM <- fetchFeasMeta(Seu, c(.features, clusterIdVar), ident.return = F, assay = assay, slot = slot)
  .expM.agg <- avgPctExp(.expM[, -1 ,], cluster = clusterIdVar)
  .expM.agg.mtx <- as.matrix(.expM.agg$mean[,-1,])
  rownames(.expM.agg.mtx) <- .expM.agg$mean[[clusterIdVar]]
  print_message("Reassigning cluster ID by similarity....")
  .clusterId <- roughCluster(.expM.agg.mtx, D = 1, method = method)
  if (is.null(.clusterId)) {
    print_message("No clusterID had been changed. Return the orignal clusterID.")
    return(Seu)
  }
  .cluster.stat <- table(Seu@meta.data[[clusterIdVar]])
  .cluster.order.intern <- lapply(.clusterId, function(x) {
    .w <- .cluster.stat[x]
    x[order(.w, decreasing = T)]
  })
  .cluster.order.outer <- order(sapply(.clusterId, function(x) sum(.cluster.stat[x])), decreasing = T)
  .trans.tab.orig <- unlist(sapply(.cluster.order.outer, function(x) .cluster.order.intern[[x]]), use.names = F)
  .trans.tab.trans <- 0:(length(.trans.tab.orig)-1)
  .trans.tab <- list(orig = .trans.tab.orig, trans = .trans.tab.trans)
  .cluster.order.out <- insituReplace.char(Seu@meta.data[[clusterIdVar]], .trans.tab)
  .clusterIdVar.out <- paste0(clusterIdVar, '.reassignedBySim')
  Seu@meta.data[[.clusterIdVar.out]] <- .cluster.order.out
  print_message("Cluster ID reassignment is done.")
  return(Seu)
}

normlize.seu <- function(seu, assay, slot, dataNorm) {
  .seu.data.type <- ckDataType(slot(seu[[assay]], name = slot))
  if (.seu.data.type == "unknown") {
    warning(cat("unknown data format for sample\n", sep = ""), immediate. = TRUE)
  }
  if (!is.null(dataNorm)) {
    print_message(stringr::str_glue('Apply {dataNorm} on the sample'))
    if (dataNorm == "LogNormalize") {
      if (.seu.data.type == "countsLogNormal") {
        cat("sample in the seuList has been log-normalized.\n", sep = "")
      } else {
        seu <- Seurat::NormalizeData(object = seu, 
                                     assay = assay, 
                                     normalization.method = dataNorm, 
                                     verbose = FALSE)
      }
    } else if (dataNorm == "TFIDF") {
      seu <- Signac::RunTFIDF(object = seu, assay = assay, verbose = FALSE)
    } 
  } else {
    if (.seu.data.type %in% c("rawCounts", "rawCountsNormalized")){ 
      warning(stringr::str_glue("data is not log-normalized....
                                  User should set the parameter dataNorm to LogNormalize OR other type"), immediate. = TRUE)
    }
  }
  return(seu)
}

ckScDataFormat <- function(obj, supp.format){
  if (is.null(obj)) cli::cli_abort("Input object is NULL.")
  .supp.format <- supp.format
  .c <- sapply(.supp.format, function(x) methods::is(obj, x))
  .c.i <- which(.c)
  if (length(.c.i) == 1) {
    .obj.format <- .supp.format[.c.i]
  } else {
    .cand <- setdiff(.supp.format[.c.i], 'SingleCellExperiment')
    .obj.format <- if (length(.cand) == 1) .cand else 'unknown'
  }
  if (identical(.obj.format, 'unknown')) cli::cli_abort("Unknown or unsupport format for input object")
  return(.obj.format)                
}

seu2cloupe <- function(seu, assay = 'RNA', marker.data = NULL, out.prefix = NULL) {
  ckPacsR('Seurat')
  ckPacsR('loupeR')
  stopifnot(!is.null(out.prefix))
  suppressPackageStartupMessages(library(Seurat))
  suppressPackageStartupMessages(library(loupeR))
  # Set default assay
  DefaultAssay(seu) <- assay
  .cloupe.nm <- paste0(out.prefix, '.loupe')
  .marker.nm <- paste0(out.prefix, '.marker.lst.csv')
  .marker.data.nm <- paste0(out.prefix, '.marker.data.tsv')
  create_loupe_from_seurat(seu, output_name = .cloupe.nm)
  .marker.lst <- as.data.frame(marker.data$df[,c('gene', 'cluster')])
  colnames(.marker.lst) <- c('Name', 'List')
  write.csv(.marker.lst,
    file = .marker.nm,
    quote = FALSE,
    row.names = FALSE
  )
  write.table(marker.data$df, file = .marker.data.nm, sep = '\t', row.names = FALSE, quote = FALSE)
  message("Loupe file and associated data have been successfully created.")
}

rebuildSeu_from_seu <- function(seu, assay = 'RNA', slot = 'counts', orig.ident.keep = TRUE) {
  .seu <- Seurat::CreateSeuratObject(Seurat::GetAssayData(seu, assay = assay, slot = slot))
  if (isTRUE(orig.ident.keep)) {
    .seu$orig.ident <- seu$orig.ident
  }
  return(.seu)
}

fix_louper_barcodes <- function(barcodes, start_suffix = 2) {
  # barcodes: character vector of cell names
  # start_suffix: first numeric suffix to assign to suffix groups, e.g. 2 gives -2, -3, -4...
  
  if (!is.character(barcodes)) {
    stop("barcodes must be a character vector.")
  }
  
  # Extract DNA sequence before the first hyphen
  base <- sub("^([ACGTN]+)-.*$", "\\1", barcodes)
  
  # Extract the entire suffix group after the first hyphen
  # Example: AAAC...-1-1-1-1-5 -> 1-1-1-1-5
  suffix_group <- sub("^[ACGTN]+-", "", barcodes)
  
  # Validate extraction
  if (any(base == barcodes)) {
    bad <- barcodes[base == barcodes]
    stop(
      "Some barcodes do not match expected format. Examples: ",
      paste(head(bad), collapse = ", ")
    )
  }
  
  # Assign each unique suffix group to a clean numeric Louper suffix
  unique_groups <- unique(suffix_group)
  group_map <- setNames(seq(from = start_suffix, length.out = length(unique_groups)), unique_groups)
  
  new_suffix <- group_map[suffix_group]
  
  # Rebuild Louper-compatible barcodes
  new_barcodes <- paste0(base, "-", new_suffix)
  
  # Final validation
  bad <- !grepl("^[ACGTN]+-[0-9]+$", new_barcodes)
  
  if (any(bad)) {
    stop(
      "Some converted barcodes are still invalid. Examples: ",
      paste(head(new_barcodes[bad]), collapse = ", ")
    )
  }
  
  if (anyDuplicated(new_barcodes)) {
    dupes <- unique(new_barcodes[duplicated(new_barcodes)])
    stop(
      "Converted barcodes contain duplicates. Examples: ",
      paste(head(dupes), collapse = ", ")
    )
  }
  
  return(new_barcodes)
}
