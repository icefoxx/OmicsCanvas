featureTransfer <- function(source.obj, target.seu, features = NULL, 
                            slot = c("data", "counts"), assay = "RNA",
                            force = F) {

  if (!requireNamespace("Seurat", quietly = TRUE)) {
    stop("Seurat package is not installed. Please install it before running this function.")
  }
  library(Matrix)
  .slot <- match.arg(slot)
  if (!inherits(target.seu, "Seurat")) stop("The target.seu must be a Seurat object.")
  
  if (inherits(source.obj, "Seurat")) {
    .source.matrix <- Seurat::GetAssayData(source.obj, slot = .slot, assay = assay)
  } else if (inherits(source.obj, "Matrix") || is.matrix(source.obj)) {
    .source.matrix <- source.obj
  } else {
    stop("The .source.obj must be a Seurat object, a matrix, or a sparse matrix.")
  }
  
  .target.matrix <- Seurat::GetAssayData(target.seu, slot = .slot, assay = assay)
  if (!is.null(features)) {
    if (!all(features %in% rownames(.source.matrix))) {
      stop("Some .features are not present in the .source.matrix.")
    }
    .source.matrix <- .source.matrix[features, , drop = FALSE]
  } else {
    features <- rownames(.source.matrix)
  }
  .missing.features <- setdiff(features, rownames(.target.matrix))
  if (length(.missing.features) > 0) {
    .zero.matrix <- Matrix(0, nrow = length(.missing.features), ncol = ncol(.target.matrix), sparse = TRUE)
    rownames(.zero.matrix) <- .missing.features
    colnames(.zero.matrix) <- colnames(.target.matrix)
    .target.matrix <- rbind(.target.matrix, .zero.matrix)
  }
  
  # Subset cells: retain only cells present in both source and target
  .common.cells <- intersect(colnames(.source.matrix), colnames(.target.matrix))

  if (length(.common.cells) == 0) {
    stop("No overlapping cells found between the .source and .target.")
  }
  if (length(.common.cells) != ncol(.target.matrix)) {
    print(length(.common.cells))
    if (isFALSE(force)) {
      stop("Cells are different between source and target matrix. ")
    }
  }
  .source.matrix <- .source.matrix[, .common.cells, drop = FALSE]
  .target.matrix <- .target.matrix[, .common.cells, drop = FALSE]
  
  # Replace the target matrix with the source matrix for matching features
  .target.matrix[rownames(.source.matrix), ] <- .source.matrix
  # Update the Seurat object with the modified matrix
  Seurat::SetAssayData(
    object = target.seu, 
    slot = .slot, 
    new.data = .target.matrix, 
    assay = assay
  )
  return(target.seu)
}

read10x2Seu <- function(data.dirs, matrix.folder = "filtered_feature_bc_matrix", 
                        outs.folder = "outs", read = T, include.pattern = NULL, 
                        exclude.pattern = NULL) {
  # Check if Seurat is installed
  if (!requireNamespace("Seurat", quietly = TRUE)) {
    stop("Seurat package is not installed. Please install it before running this function.")
  }
  
  # Initialize variables for sanity check
  .sample.names <- c()  # To store sample names
  .valid.dirs <- list()  # To store valid directories
  
  # Sanity check phase
  for (.dir in data.dirs) {
    # Check for possible paths
    .dir <- normalizePath(.dir)
    .dir.sub <- list.dirs(.dir, full.names = T, recursive = F)
    stopifnot(length(.dir.sub) > 0)
    .dir.sub.pos.idx <- rep(T, length(.dir.sub))
    .dir.sub.neg.idx <- rep(F, length(.dir.sub))
    if (!is.null(include.pattern)) {
      if (length(include.pattern) > 1 ) {
        include.pattern <- paste0(include.pattern, collapse = '|')
      }
      .dir.sub.pos.idx <- grepl(include.pattern, .dir.sub) 
    }
    if (!is.null(exclude.pattern)) {
      if (length(include.pattern) > 1 ) {
        exclude.pattern <- paste0(exclude.pattern, collapse = '|')
      }
      .dir.sub.neg.idx <- grepl(exclude.pattern, .dir.sub)
    }
    .dir.sub.idx <- which((.dir.sub.pos.idx - .dir.sub.neg.idx) == 1)
    if (length(.dir.sub.idx) == 0) {
      warning(paste("No valid directories found for the specified matrix folder in:", .dir))
      next
    }
    .dir.sub <- .dir.sub[.dir.sub.idx]
    for (.sample in .dir.sub) {
      .matrix.path <- file.path(.sample, matrix.folder)
      .outs.path <- file.path(.sample, outs.folder, matrix.folder)
      if (dir.exists(.outs.path)) {
        .sample.name <- basename(dirname(dirname(.outs.path)))  
        .matrix.path <- .outs.path
      } else if (dir.exists(.matrix.path)) {
        .sample.name <- basename(dirname(.matrix.path))  
      } else {
        warning(paste(matrix.folder, "not found in:", .dir))
        next
      }
      if (.sample.name %in% .sample.names) {
        stop(paste("Duplicate sample name detected during sanity check:", .sample.name, 
                   "\nPlease ensure each sample has a unique name."))
      }
      .sample.names <- c(.sample.names, .sample.name)
      .valid.dirs[[.sample.name]] <- .matrix.path
    }
  }
  
  # If no valid directories, stop
  if (length(.valid.dirs) == 0) {
    stop("No valid directories found for the specified matrix folder. Please check your input.")
  }
  if (isFALSE(read)) return(.valid.dirs)
  # Reading phase
  .seurat.objects <- list()
  for (.sample.name in names(.valid.dirs)) {
    message(paste("Loading sample:", .sample.name))
    tryCatch({
      .seurat.obj <- Seurat::CreateSeuratObject(counts = Seurat::Read10X(data.dir = .valid.dirs[[.sample.name]]))
      .seurat.obj$orig.ident <- .sample.name
      .seurat.objects[[.sample.name]] <- .seurat.obj
    }, error = function(e) {
      warning(paste("Failed to process sample:", .sample.name, "Error:", e$message))
    })
  }
  return(.seurat.objects)
}


assayMatch <- function(seu, assays, verbose = TRUE, force = F) {
  stopifnot(inherits(x = seu, what = "Seurat"))
  .assay.local <- Assays(object = seu)
  .assay.info <- assays %in% .assay.local
  .assay.missing <- assays[! .assay.info]
  .assay.found <- assays[.assay.info]
  if (length(.assay.found) == 0) {
    if (isTRUE(verbose)) {
      cli_abort(message = "No requested assays found.")
    }
    return(NULL)
  }
  .mes.caller <- if(isTRUE(force)) cli::cli_warn else cli::cli_abort
  if (length(.assay.missing) > 0) {
    if (isTRUE(verbose)){
      .mes <- stringr::str_glue("The following assays were not found: {glueVec(.assay.missing)}.")
      .mes.caller(.mes)
    }
  } else {
    if (isTRUE(verbose)) {
      .mes <- "All assays found"
      cli::cli_inform(.mes)
    }
  }
  return(list(local = .assay.found, miss = .assay.missing))
}

assayVerCheck <- function(seu, assay = NULL){
  stopifnot(inherits(x = seu, what = "Seurat"))
  .assay <- assay %||% DefaultAssay(object = seu)
  .assay.v <- NULL
  if (inherits(x = seu@assays[[.assay]], what = "Assay")) .assay.v <- 'Assay'
  if (inherits(x = seu@assays[[.assay]], what = "Assay5")) .assay.v <- 'Assay5'
  return(.assay.v)
}

assayConvert <- function(seu, assay = 'RNA', target) {
  stopifnot(!is.null(x = assay))
  
  if (any(assay %in% c('SCTassay', 'SCT'))) cli::cli_abort(message = "Cannot convert assay of SCT like.")
  if (!is.null(x = assay)) .assays <- assayMatch(seu, assays = assay,  verbose = TRUE, force = F)
  .assay.v3 <- c("Assay", "assay", "V3", "v3", "3")
  .assay.v5 <- c("Assay5", "assay5", "V5", "v5", "5")
  .target <- as.character(target)
  .target <- match.arg(.target, c(.assay.v3, .assay.v5))
  .assay.v <- assayVerCheck(seu = seu, assay = assay)
  if (.target %in% .assay.v5) {
    if (packageVersion(pkg = 'Seurat') < 5) {
      cli::cli_abort("convert to Assay5 requires Seurat more than v5.0.0.")
    }
    .source <- "Assay"
    .target <- "Assay5"
  } else if (.target %in% .assay.v3) {
    .source <- "Assay5"
    .target <- 'Assay'
  }
  for (i in .assays$local) {
    cli::cli_inform(message = stringr::str_glue("Converting assay {i} from {.source} to {.target}."))
    suppressWarnings(seu[[i]] <- as(seu[[i]], .target))
  }
  cli::cli_inform('Convertion finished')
  return(seu)
}


clusterStat <- function(meta.data, cluster.col = NULL, keyv = NULL, na.rm = TRUE, digits = 2, ...) {
  data.table::setDT(meta.data)
  .meta.data.cols <- colnames(meta.data)
  .cluster.col <- match.arg(cluster.col, .meta.data.cols)
  .keyv.col <- match.arg(keyv, .meta.data.cols)
  .cols <- c(.cluster.col, .keyv.col)
  .meta.data.agg <- meta.data[, .N, by = .cols ]
  .meta.data.agg <- .meta.data.agg[, list(perc = 100*N/sum(N), sample = get(.keyv.col), cells = N), keyby = .cluster.col]
  .format <- paste0(.cluster.col , ' ~  sample')
  data.table::dcast(.meta.data.agg, .format, value.var = c('perc', 'cells'), fun.aggregate = sum)
}

mergeSeus <- function(seu.lst, add.cell.ids = 'auto', project = "SeuratProject") {
  # Check list_seurat is list
  if (!inherits(x = list_seurat, what = "list")) {
    cli_abort(message = "{.code list_seurat} must be environmental variable of class {.val list}")
  }
  
  # Check list_seurat is only composed of Seurat objects
  for (i in 1:length(x = list_seurat)) {
    if (!inherits(x = list_seurat[[i]], what = "Seurat")) {
      cli_abort("One or more of entries in {.code list_seurat} are not objects of class {.val Seurat}")
    }
  }
  
  # Check all barcodes are unique to begin with
  duplicated_barcodes <- list_seurat %>%
    lapply(colnames) %>%
    unlist() %>%
    duplicated() %>%
    any()
  
  if (isTRUE(x = duplicated_barcodes) && is.null(x = add.cell.ids)) {
    cli_abort(message = c("There are overlapping cell barcodes present in the input objects",
                          "i" = "Please rename cells or provide prefixes to {.code add.cell.ids} parameter to make unique.")
    )
  }
  
  # Check right number of suffix/prefix ids are provided
  if (!is.null(x = add.cell.ids) && length(x = add.cell.ids) != length(x = list_seurat)) {
    cli_abort(message = "The number of prefixes in {.code add.cell.ids} must be equal to the number of objects supplied to {.code list_seurat}.")
  }
  
  # Rename cells if provided
  list_seurat <- lapply(1:length(x = list_seurat), function(x) {
    list_seurat[[x]] <- RenameCells(object = list_seurat[[x]], add.cell.id = add.cell.ids[x])
  })
  
  # Merge objects
  merged_object <- reduce(list_seurat, function(x, y) {
    merge(x = x, y = y, merge.data = merge.data, project = project)
  })
}

avgPctExp <- function(dt, threshold = 0, cluster = c('seurat_clusters')) {
  .dt.agg <- dt[, lapply(.SD, function(x) return(c(sum(x > threshold)/length(x), mean(x)))), by = cluster]
  .dt.agg.pct <- .dt.agg[rep(c(T,F), length = .N)]
  .dt.agg.mean <- .dt.agg[rep(c(F, T), length = .N)]
  return(list(pct = .dt.agg.pct, mean = .dt.agg.mean))
}

avg4SeuDE <- function(seu, assay = 'RNA', slot = 'data', seuDE, 
                      geneCol = 'gene', keyv = 'cluster',
                      cluster = c('seurat_clusters', 'orig.ident'), 
                      extend.index = c(2), sep = '&' ) {
  .gene.u <- unique(seuDE[[geneCol]])
  data.table::setDT(seuDE)
  .exp.mtx <- fetchFeasMeta(seu, features = c(cluster, .gene.u), assay = 'RNA', slot = 'data', ident.return = F)
  if ("cell.barcodes.selected" %in% colnames(.exp.mtx)) .exp.mtx <- .exp.mtx[, -'cell.barcodes.selected', with = F]
  .exp.mtx.mean.pct <- avgPctExp(.exp.mtx, cluster = cluster)
  .exp.mtx.mean <- data.table::melt(.exp.mtx.mean.pct$mean, measure.vars = .gene.u,  variable.name = geneCol, value.name = "meanexp")
  .formula <- NULL
  .cluster.extend.non <- cluster[-extend.index]
  .cluster.extend <- cluster[extend.index]
  .tmp.combinations.lst <- lapply(.exp.mtx.mean[, .cluster.extend, with = F], function(x){
      .t <- unique(x)
      if (is.factor(.t)) .t[order(match(.t, levels(.t) ))] else .t 
    })
  if (length(.tmp.combinations.lst) > 1){
    .tmp.combinations <- apply(expand.grid.lst(.tmp.combinations.lst), 1, function(x) paste0(x, collapse = sep) )
  } else {
    .tmp.combinations <- .tmp.combinations.lst[[1]]
  }
  .sample.order <- c(geneCol, .cluster.extend.non, .tmp.combinations)
  if (length(extend.index) == length(cluster)){
    .formula <- paste0(geneCol, ' ~ ', paste(cluster, collapse = ' + '))
  } else {
    .formula <- paste0(paste0(c(geneCol, .cluster.extend.non), collapse = ' + '), ' ~ ', paste0(.cluster.extend, collapse = '+'))
  }
  .exp.mtx.mean.long <- data.table::dcast(.exp.mtx.mean, .formula, value.var = "meanexp", fun.aggregate = mean, sep = '&')
  .exp.mtx.mean.long <- .exp.mtx.mean.long[, .sample.order, with = FALSE]
  data.table::setkeyv(seuDE, c(geneCol, keyv))
  data.table::setkeyv(.exp.mtx.mean.long, c(geneCol, .cluster.extend.non))
  seuDE[.exp.mtx.mean.long, nomatch=0L]
}


parse10XVDJT <- function(samples, maindir, adddir = NULL, samplename = NULL) {
  print_message("Start reading 10x VDJT metrics")
  
  .libtype <- "VDJ T"
  
  .clean_metric_value <- function(x) {
    if (is.factor(x)) x <- as.character(x)
    x <- trimws(x)
    
    .is_pct <- grepl("%$", x)
    .is_num <- grepl("^[0-9,\\.]+%?$", x)
    
    x[.is_num] <- gsub(",", "", x[.is_num])
    x[.is_pct] <- sub("%$", "", x[.is_pct])
    
    suppressWarnings({
      x[.is_num] <- as.numeric(x[.is_num])
    })
    
    return(x)
  }
  
  .safe_metric_wide <- function(df, metric_col, value_col, metrics_keep = NULL) {
    if (!is.null(metrics_keep)) {
      df <- df[df[[metric_col]] %in% metrics_keep, , drop = FALSE]
    }
    
    if (nrow(df) == 0) {
      return(data.frame(check.names = FALSE, stringsAsFactors = FALSE))
    }
    
    df <- df[, c(metric_col, value_col), drop = FALSE]
    df <- df[!duplicated(df[[metric_col]]), , drop = FALSE]
    
    out <- as.data.frame(t(df[[value_col]]), stringsAsFactors = FALSE, check.names = FALSE)
    colnames(out) <- df[[metric_col]]
    
    return(out)
  }
  
  .get_metric_alias <- function(metric_names, alias_list) {
    .hit <- unique(unlist(lapply(alias_list, function(xx) metric_names[metric_names %in% xx])))
    return(.hit)
  }
  
  .qc.data.lst <- pblapply(seq_along(samples), function(x) {
    if (is.null(adddir)) {
      .file.dir <- file.path(maindir, samples[x])
    } else {
      .file.dir <- file.path(maindir, samples[x], adddir, samples[x])
    }
    
    .file <- file.path(.file.dir, "metrics_summary.csv")
    if (!file.exists(.file)) {
      stop(paste0("Cannot find file: ", .file))
    }
    
    .qc.data <- read.csv(
      file = .file,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
    
    .cn <- colnames(.qc.data)
    
    ## ------------------------------------------------------------
    ## Branch 1: cellranger multi style metrics_summary.csv
    ## ------------------------------------------------------------
    if (all(c("Category", "Library Type", "Grouped By", "Metric Name", "Metric Value") %in% .cn)) {
      
      .metric.alias <- list(
        "Cells with productive TRA contig" = c(
          "Cells with productive TRA contig"
        ),
        "Cells with productive TRB contig" = c(
          "Cells with productive TRB contig"
        ),
        "Cells with productive V-J spanning (TRA, TRB) pair" = c(
          "Cells with productive V-J spanning (TRA, TRB) pair"
        ),
        "Cells with productive V-J spanning pair" = c(
          "Cells with productive V-J spanning pair"
        ),
        "Median TRA UMIs per Cell" = c(
          "Median TRA UMIs per Cell"
        ),
        "Median TRB UMIs per Cell" = c(
          "Median TRB UMIs per Cell"
        ),
        "Number of cells with productive V-J spanning pair" = c(
          "Number of cells with productive V-J spanning pair",
          "Number of Cells With Productive V-J Spanning Pair"
        ),
        "Paired clonotype diversity" = c(
          "Paired clonotype diversity"
        )
      )
      
      .all.metric.names <- unique(.qc.data[["Metric Name"]])
      .metrics.term <- unique(unlist(.metric.alias))
      
      .qc.data.lib <- .qc.data %>%
        dplyr::filter(
          .data[["Library Type"]] == .libtype,
          .data[["Category"]] == "Library",
          .data[["Grouped By"]] == "Physical library ID"
        ) %>%
        dplyr::select(all_of(c("Metric Name", "Metric Value"))) %>%
        dplyr::distinct()
      
      .qc.data.lib <- .safe_metric_wide(
        df = .qc.data.lib,
        metric_col = "Metric Name",
        value_col = "Metric Value"
      )
      
      .qc.data.cell <- .qc.data %>%
        dplyr::filter(
          .data[["Library Type"]] == .libtype,
          .data[["Category"]] == "Cells",
          .data[["Metric Name"]] %in% .metrics.term
        ) %>%
        dplyr::select(all_of(c("Metric Name", "Metric Value"))) %>%
        dplyr::distinct()
      
      .qc.data.cell <- .safe_metric_wide(
        df = .qc.data.cell,
        metric_col = "Metric Name",
        value_col = "Metric Value"
      )
      
      .qc.data.vdjt <- cbind(.qc.data.lib, .qc.data.cell)
      
      ## standardize alias columns to canonical names
      for (.nm in names(.metric.alias)) {
        .aliases <- .metric.alias[[.nm]]
        .hit <- intersect(colnames(.qc.data.vdjt), .aliases)
        if (length(.hit) > 0) {
          colnames(.qc.data.vdjt)[match(.hit[1], colnames(.qc.data.vdjt))] <- .nm
          if (length(.hit) > 1) {
            .qc.data.vdjt <- .qc.data.vdjt[, !duplicated(colnames(.qc.data.vdjt)), drop = FALSE]
          }
        }
      }
      
      ## ------------------------------------------------------------
      ## Branch 2: standalone cellranger vdj style metrics_summary.csv
      ## ------------------------------------------------------------
    } else if (all(c("Metric Name", "Metric Value") %in% .cn)) {
      
      .metric.alias <- list(
        "Cells with productive TRA contig" = c(
          "Cells with productive TRA contig"
        ),
        "Cells with productive TRB contig" = c(
          "Cells with productive TRB contig"
        ),
        "Cells with productive V-J spanning pair" = c(
          "Cells with productive V-J spanning pair",
          "Cells with productive V-J spanning (TRA, TRB) pair"
        ),
        "Median TRA UMIs per Cell" = c(
          "Median TRA UMIs per Cell"
        ),
        "Median TRB UMIs per Cell" = c(
          "Median TRB UMIs per Cell"
        ),
        "Number of cells with productive V-J spanning pair" = c(
          "Number of cells with productive V-J spanning pair",
          "Number of Cells With Productive V-J Spanning Pair"
        ),
        "Paired clonotype diversity" = c(
          "Paired clonotype diversity"
        )
      )
      
      .metrics.term <- unique(unlist(.metric.alias))
      
      .qc.data.vdjt <- .qc.data %>%
        dplyr::filter(.data[["Metric Name"]] %in% .metrics.term) %>%
        dplyr::select(all_of(c("Metric Name", "Metric Value"))) %>%
        dplyr::distinct()
      
      .qc.data.vdjt <- .safe_metric_wide(
        df = .qc.data.vdjt,
        metric_col = "Metric Name",
        value_col = "Metric Value"
      )
      
      for (.nm in names(.metric.alias)) {
        .aliases <- .metric.alias[[.nm]]
        .hit <- intersect(colnames(.qc.data.vdjt), .aliases)
        if (length(.hit) > 0) {
          colnames(.qc.data.vdjt)[match(.hit[1], colnames(.qc.data.vdjt))] <- .nm
          if (length(.hit) > 1) {
            .qc.data.vdjt <- .qc.data.vdjt[, !duplicated(colnames(.qc.data.vdjt)), drop = FALSE]
          }
        }
      }
      
    } else {
      stop(
        paste0(
          "Unsupported metrics_summary.csv format in file: ", .file,
          "\nDetected columns: ", paste(.cn, collapse = ", ")
        )
      )
    }
    
    if (ncol(.qc.data.vdjt) > 0) {
      .qc.data.vdjt[] <- lapply(.qc.data.vdjt, .clean_metric_value)
    }
    
    return(.qc.data.vdjt)
  })
  
  .samplename <- if (is.null(samplename)) samples else samplename
  if (length(.samplename) != length(.qc.data.lst)) {
    stop("Length of samplename does not match length of samples")
  }
  
  names(.qc.data.lst) <- .samplename
  
  .qc.metrix <- dplyr::bind_rows(.qc.data.lst, .id = "sample_id")
  colnames(.qc.metrix) <- gsub(pattern = "\\.", replacement = "_", x = colnames(.qc.metrix))
  rownames(.qc.metrix) <- .qc.metrix$sample_id
  
  print_message("Mission completed: parse 10x VDJT metrics")
  return(.qc.metrix)
}

parse10XGEX <- function(samples, maindir, adddir = NULL, samplename = NULL) {
  print_message("Start reading 10x cellranger gene expression metrics")
  
  .libtype <- "Gene Expression"
  
  .clean_metric_value <- function(x) {
    if (is.factor(x)) x <- as.character(x)
    x <- trimws(x)
    
    .is_pct <- grepl("%$", x)
    .is_num <- grepl("^[0-9,\\.]+%?$", x)
    
    x[.is_num] <- gsub(",", "", x[.is_num])
    x[.is_pct] <- sub("%$", "", x[.is_pct])
    
    suppressWarnings({
      x[.is_num] <- as.numeric(x[.is_num])
    })
    
    return(x)
  }
  
  .safe_metric_wide <- function(df, metric_col, value_col, metrics_keep = NULL) {
    if (!is.null(metrics_keep)) {
      df <- df[df[[metric_col]] %in% metrics_keep, , drop = FALSE]
    }
    
    if (nrow(df) == 0) {
      return(data.frame(check.names = FALSE, stringsAsFactors = FALSE))
    }
    
    df <- df[, c(metric_col, value_col), drop = FALSE]
    df <- df[!duplicated(df[[metric_col]]), , drop = FALSE]
    
    out <- as.data.frame(
      t(df[[value_col]]),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
    colnames(out) <- df[[metric_col]]
    
    return(out)
  }
  
  .standardize_alias_cols <- function(df, alias_list) {
    if (ncol(df) == 0) {
      return(df)
    }
    
    for (.nm in names(alias_list)) {
      .aliases <- alias_list[[.nm]]
      .hit <- intersect(colnames(df), .aliases)
      if (length(.hit) > 0) {
        colnames(df)[match(.hit[1], colnames(df))] <- .nm
        if (length(.hit) > 1) {
          df <- df[, !duplicated(colnames(df)), drop = FALSE]
        }
      }
    }
    
    return(df)
  }
  
  .qc.data.lst <- pblapply(seq_along(samples), function(x) {
    if (is.null(adddir)) {
      .file.dir <- file.path(maindir, samples[x])
    } else {
      .file.dir <- file.path(maindir, samples[x], adddir, samples[x])
    }
    
    .file <- file.path(.file.dir, "metrics_summary.csv")
    if (!file.exists(.file)) {
      stop(paste0("Cannot find file: ", .file))
    }
    
    .qc.data <- read.csv(
      file = .file,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
    
    .cn <- colnames(.qc.data)
    
    ## canonical output names
    .trans.table <- c(
      "Reads Mapped to Genome" = "Mapped.to.genome",
      "Reads Mapped Confidently to Genome" = "Confidently.mapped.to.genome",
      "Reads Mapped Confidently to Intergenic Regions" = "Confidently.mapped.to.intergenic.regions",
      "Reads Mapped Confidently to Intronic Regions" = "Confidently.mapped.to.intronic.regions",
      "Reads Mapped Confidently to Exonic Regions" = "Confidently.mapped.to.exonic.regions",
      "Reads Mapped Confidently to Transcriptome" = "Confidently.mapped.to.transcriptome",
      "Reads Mapped Antisense to Gene" = "Confidently.mapped.antisense",
      "Fraction Reads in Cells" = "Confidently.mapped.reads.in.cells",
      "Estimated Number of Cells" = "Estimated.number.of.cells",
      "Mean Reads per Cell" = "Mean.reads.per.cell",
      "Median Genes per Cell" = "Median.genes.per.cell",
      "Number of Reads" = "Number.of.reads",
      "Valid Barcodes" = "Valid.barcodes",
      "Sequencing Saturation" = "Sequencing.saturation",
      "Total Genes Detected" = "Total.genes.detected",
      "Median UMI Counts per Cell" = "Median.UMI.counts.per.cell",
      "Median reads per cell" = "Mean.reads.per.cell",
      "Median genes per cell" = "Median.genes.per.cell",
      "Median UMI counts per cell" = "Median.UMI.counts.per.cell",
      "Total genes detected" = "Total.genes.detected"
    )
    
    .metric.alias <- list(
      "Reads Mapped to Genome" = c(
        "Reads Mapped to Genome"
      ),
      "Reads Mapped Confidently to Genome" = c(
        "Reads Mapped Confidently to Genome"
      ),
      "Reads Mapped Confidently to Intergenic Regions" = c(
        "Reads Mapped Confidently to Intergenic Regions"
      ),
      "Reads Mapped Confidently to Intronic Regions" = c(
        "Reads Mapped Confidently to Intronic Regions"
      ),
      "Reads Mapped Confidently to Exonic Regions" = c(
        "Reads Mapped Confidently to Exonic Regions"
      ),
      "Reads Mapped Confidently to Transcriptome" = c(
        "Reads Mapped Confidently to Transcriptome"
      ),
      "Reads Mapped Antisense to Gene" = c(
        "Reads Mapped Antisense to Gene"
      ),
      "Fraction Reads in Cells" = c(
        "Fraction Reads in Cells"
      ),
      "Estimated Number of Cells" = c(
        "Estimated Number of Cells"
      ),
      "Mean Reads per Cell" = c(
        "Mean Reads per Cell",
        "Median reads per cell"
      ),
      "Median Genes per Cell" = c(
        "Median Genes per Cell",
        "Median genes per cell"
      ),
      "Number of Reads" = c(
        "Number of Reads"
      ),
      "Valid Barcodes" = c(
        "Valid Barcodes"
      ),
      "Sequencing Saturation" = c(
        "Sequencing Saturation"
      ),
      "Total Genes Detected" = c(
        "Total Genes Detected",
        "Total genes detected"
      ),
      "Median UMI Counts per Cell" = c(
        "Median UMI Counts per Cell",
        "Median UMI counts per cell"
      )
    )
    
    .metrics.term <- unique(unlist(.metric.alias))
    
    ## ------------------------------------------------------------
    ## Branch 1: cellranger multi style metrics_summary.csv
    ## ------------------------------------------------------------
    if (all(c("Category", "Library Type", "Grouped By", "Metric Name", "Metric Value") %in% .cn)) {
      
      .qc.data.lib <- .qc.data %>%
        dplyr::filter(
          .data[["Library Type"]] == .libtype,
          .data[["Grouped By"]] == "Physical library ID"
        ) %>%
        dplyr::select(all_of(c("Metric Name", "Metric Value"))) %>%
        dplyr::distinct()
      
      .qc.data.lib <- .safe_metric_wide(
        df = .qc.data.lib,
        metric_col = "Metric Name",
        value_col = "Metric Value"
      )
      
      .qc.data.cell <- .qc.data %>%
        dplyr::filter(
          .data[["Library Type"]] == .libtype,
          .data[["Metric Name"]] %in% .metrics.term
        ) %>%
        dplyr::select(all_of(c("Metric Name", "Metric Value"))) %>%
        dplyr::distinct()
      
      .qc.data.cell <- .safe_metric_wide(
        df = .qc.data.cell,
        metric_col = "Metric Name",
        value_col = "Metric Value"
      )
      
      .qc.data.gex <- cbind(.qc.data.lib, .qc.data.cell)
      .qc.data.gex <- .standardize_alias_cols(.qc.data.gex, .metric.alias)
      
      ## ------------------------------------------------------------
      ## Branch 2: simpler cellranger count / GEX style metrics_summary.csv
      ## ------------------------------------------------------------
    } else if (all(c("Metric Name", "Metric Value") %in% .cn)) {
      
      .qc.data.gex <- .qc.data %>%
        dplyr::filter(.data[["Metric Name"]] %in% .metrics.term) %>%
        dplyr::select(all_of(c("Metric Name", "Metric Value"))) %>%
        dplyr::distinct()
      
      .qc.data.gex <- .safe_metric_wide(
        df = .qc.data.gex,
        metric_col = "Metric Name",
        value_col = "Metric Value"
      )
      .qc.data.gex <- .standardize_alias_cols(.qc.data.gex, .metric.alias)
      
    } else {
      stop(
        paste0(
          "Unsupported metrics_summary.csv format in file: ", .file,
          "\nDetected columns: ", paste(.cn, collapse = ", ")
        )
      )
    }
    
    if (ncol(.qc.data.gex) > 0) {
      .qc.data.gex[] <- lapply(.qc.data.gex, .clean_metric_value)
    }
    
    ## rename to stable output names
    .hit.rename <- intersect(names(.trans.table), colnames(.qc.data.gex))
    if (length(.hit.rename) > 0) {
      colnames(.qc.data.gex)[match(.hit.rename, colnames(.qc.data.gex))] <- .trans.table[.hit.rename]
    }
    
    return(.qc.data.gex)
  })
  
  .samplename <- if (is.null(samplename)) samples else samplename
  if (length(.samplename) != length(.qc.data.lst)) {
    stop("Length of samplename does not match length of samples")
  }
  
  names(.qc.data.lst) <- .samplename
  
  .qc.metrix <- dplyr::bind_rows(.qc.data.lst, .id = "sample_id")
  colnames(.qc.metrix) <- gsub(pattern = "\\.", replacement = "_", x = colnames(.qc.metrix))
  rownames(.qc.metrix) <- .qc.metrix$sample_id
  
  print_message("Mission completed: parse 10x cellranger gene expression metrics")
  return(.qc.metrix)
}

# write the usage and example for this function
#' @title Get the top features from seu format marker detection matrix
#' @description This function is used to get the top features from seu format marker detection matrix
#' @param markers.seu A data frame or list of data frames returned by Seurat FindMarkers function
#' @param features A character vector of features to be added to the top features
#' @param featureCount The number of top features to be selected
#' @param UpDown Logical, whether to select both up and down regulated genes
#' @param selection The selection method, either 'cluster', 'global' or 'all'
#' @param geneColumn The column name of gene in the input data
#' @param threshold The threshold to select significant genes
#' @param rowname2column Logical, whether to convert rownames to column
#' @param genelist Logical, whether to return gene list
#' @param uniq Logical, whether to return unique gene list
#' @param rank.by The ranking method
#' @return A list of data frame and gene list
#' @export
#' @examples
#' 
topMarkers.seu <- function(markers.seu, features = NULL, featureCount = 20,  
                           UpDown = c('Up', 'Down', 'Both'),
                           selection = "cluster",  geneColumn = "gene", 
                           threshold = 0.25, rowname2column = FALSE,
                           genelist = TRUE, splitUD = TRUE, uniq = FALSE,
                           rank.by = "Ranking = sqrt(abs(pct.1 - pct.2)) * abs(avg_log2FC)") {
  suppressPackageStartupMessages(library(rlang))
  suppressPackageStartupMessages(library(dplyr))
  .selection <- match.arg(selection, c('cluster', 'global', 'all'))
  .UpDown <- match.arg(UpDown, c('Up', 'Down', 'Both'))
  .ranking.fun <- function(df, rank.by = rank.by, geneColumn = geneColumn){
    if (! rank.by %in% colnames(df)) {
      message(stringr::str_glue("{rank.by} not found in colnames of input data. Trying expression parsing..."))
    }
    if (!geneColumn %in% colnames(df)) df[[geneColumn]] <- rownames(df)
    .marker.selected <- df %>% 
      dplyr::mutate(!!parse_quo(rank.by, env = caller_env()))
    return(.marker.selected)
  }
  if (is.data.frame(markers.seu)){
    .marker.selected.r <- .ranking.fun(markers.seu, rank.by = rank.by, geneColumn = geneColumn)
  } else if(is.list(markers.seu)){
    .marker.selected.r <- do.call(rbind, lapply(seq_along(markers.seu), function(x){
      .nm <- names(markers.seu[x])
      if (is.null(.nm)) .nm <- x
      .marker.selected <- .ranking.fun(markers.seu[[x]], rank.by = rank.by, geneColumn = geneColumn)
      if (! 'cluster' %in% colnames(.marker.selected)) .marker.selected[['cluster']] <- .nm
      return(.marker.selected)
    }))
  }else {
    stop('Only accept markers returned by Seurat in data.frame OR list format')
  }
  if (!is.null(threshold) & is.numeric(threshold)){
    .marker.selected.r <- .marker.selected.r %>% dplyr::mutate(UpDown = case_when(avg_log2FC > threshold ~ "sigUp", 
                                                                                avg_log2FC < -threshold ~ "sigDown", 
                                                                                TRUE ~ 'Nonsig'))
  } else {
    .marker.selected.r <- .marker.selected.r %>% dplyr::mutate(UpDown = case_when(avg_log2FC > 0 ~ "sigUp", 
                                                                                avg_log2FC < 0 ~ "sigDown", 
                                                                                TRUE ~ 'Nonsig'))
  }
  .gene.list <- NULL
  if (.UpDown == 'Up'){
    .marker.selected.r <- .marker.selected.r %>% dplyr::filter(.data[['UpDown']] == 'sigUp')
  } else if (.UpDown == 'Down') {
    .marker.selected.r <- .marker.selected.r %>% dplyr::filter(.data[['UpDown']] == 'sigDown')
  } else if (.UpDown == 'Both') {
    .marker.selected.r <- .marker.selected.r %>% dplyr::filter(.data[['UpDown']] != 'Nonsig')
  } 
  if (.selection == 'global'){
    .marker.selected <- .marker.selected.r %>%
      dplyr::slice_max(n = featureCount, order_by = .data[[rank.by]]) 
  } else if (.selection == 'cluster'){
      .marker.selected <- .marker.selected.r %>% 
        group_by(c(.data[[selection]]), .data[['UpDown']]) %>%
        dplyr::slice_max(n = featureCount, order_by = .data[[rank.by]]) 
  } else if (.selection == 'all'){
    .marker.selected <- .marker.selected.r %>% dplyr::arrange(rank.by)
  }

  if (!is.null(features)) {
    .marker.add <- .marker.selected.r %>% dplyr::filter(.data[[geneColumn]] %in% features)
    if (nrow(.marker.add) > 0) stop(stringr::str_glue('Features {features} not found in input data'))
    .marker.selected <- rbind(.marker.selected, .marker.add)
  }
  if (isTRUE(rowname2column)) {
    if (!geneColumn %in% colnames(.marker.selected)) {
      .marker.selected <- .marker.selected %>% tibble::rownames_to_column(geneColumn)
    } else {
      .marker.selected[[geneColumn]] <- rownames(.marker.selected)
    }
  }
  if (isTRUE(genelist)) {
    if (selection %in% colnames(.marker.selected)) {
      if (isTRUE(splitUD)) {
        .marker.selected$split_col <- paste0(.marker.selected[[selection]], '_', .marker.selected[['UpDown']], 
                                             '_', featureCount)
      } else {
        .marker.selected$split_col <- paste0(.marker.selected[[selection]], '_', featureCount)
      }
      .gene.list <- split(.marker.selected, .marker.selected$split_col) %>% purrr::map(~.x[['gene']])
    } else {
      .gene.list <- list(.marker.selected[[geneColumn]])
      names(.gene.list) <- selection
    }
  }
  if (isTRUE(uniq)) .gene.list <- lapply(.gene.list, unique)
  return(list(df = .marker.selected, genelist = .gene.list))
}

  
#' Fetch features and metadata
#'
#' This function fetches features and metadata based on the key words.
#'
#' @name fetchFeasMeta
#' @author Qiong Zhang
#' @param seu Seurat object
#' @param features which feature(s)
#' @param keywords A list corresponds to the feature parameter.
#' @param assay target assay in seu object
#' @param slot target slot in assay
#' @return A data table fits the value
#' @export
#'
#'@examples
#' \dontrun{
#' # Load example data and gene sets
#' filter <- list(seurat_annotations = c('Memory CD4 T', 'Naive CD4 T'), CD4 = c('>1', '<1.6'))
#'
#' fetchFeasMeta(seu = pbmc3k.final, features = c("seurat_annotations", 'CD4'), keywords = filter)
#' }
#'
fetchFeasMeta <- function(seu, features, slot = 'data', assay = "RNA", 
                          keywords = NULL, ident.return = T, 
                          format = 'wide', long.var = NULL,
                          long.key = 'feature', long.value = 'Expr'){
  .asn <- Seurat::Assays(seu)
  .assay.n <- length(assay)
  .data.f <- NULL
  if(!all(assay %in% .asn)) stop(stringr::str_glue('{assay} does not exist in {seu}'))
  .seu.meta <- seu@meta.data
  .seu.meta.name <- colnames(.seu.meta)
  .f.i.m.t <- .seu.meta.name %in% features
  if(any(.f.i.m.t)) {
    .f.i.m <- which(.f.i.m.t)
    .f.i.d <- .seu.meta[, .f.i.m, drop = F]
    colnames(.f.i.d) <- .seu.meta.name[.f.i.m]
    .data.f <- data.table::data.table(.f.i.d, keep.rownames = 'cell.barcodes.selected')
  }
  .feas <- setdiff(features, .seu.meta.name)
  if (length(.feas) > 0) {
    if (.assay.n > 1){
      .data.feas <- do.call(cbind, lapply(seq_along(assay), function(x){
        Seurat::DefaultAssay(seu) <- assay[x]
        .d <- Seurat::FetchData(object = seu, vars = .feas, slot = slot)
        .d.n <- paste0(assay[x], '.', colnames(.d))
        colnames(.d) <- .d.n
        return(.d)
      }))
    } else {
      Seurat::DefaultAssay(seu) <- assay

      .data.feas <- Seurat::FetchData(object = seu, vars = .feas, slot = slot)
    }
    if (is.null(.data.f)) {
      .data.f <- data.table::data.table(.data.feas, keep.rownames = 'cell.barcodes.selected')  
    }else {
      .data.f <- cbind(.data.f, .data.feas)
    }
  }
  if (ident.return) .data.f$seu.ident <- Seurat::Idents(seu)
  if (is.null(keywords)) {
    if (format == 'long'){
      if (all(long.var %in% colnames(.data.f))) {
      .data.f <- data.table::melt(.data.f, 
                                  measure.vars = long.var, 
                                  variable.name = long.key, 
                                  value.name = long.value)
      }
    }
    return(.data.f)
  }
  .keywords.col <- names(keywords)
  if (all(.keywords.col %in% features)){
    .filters <- sapply(seq_along(.keywords.col), function(x){
      .n <- .keywords.col[x]
      .v <- unique(keywords[[x]])
      .c <- if (length(.v) == 1) ' == '  else  ' %in% '
      .filter <- NULL
      if (.c == ' %in% ') {
        .filter <- paste0(.n, .c, keywords[x])
      } else {
        .filter <- paste0(.n, .c, 'c("', paste0(.v, collapse = '", "'), '")')
      }
      if(stringr::str_starts(.v[1], '[><=]')) {
        .c <- ' '
        .filter <- paste0(.n, .c, keywords[[x]], collapse = ' & ')
      }
      return(.filter)
    }
    )
    .filters <- paste('(',.filters, ')', collapse = ' & ')
    .data.f <- .data.f[eval(parse(text = .filters))]
    if (format == 'long'){
      if (all(long.var %in% colnames(.data.f))) {
        .data.f <- data.table::melt(.data.f, 
                                    measure.vars = long.var, 
                                    variable.name = long.key, value.name = long.value)
      }
    }
    return(.data.f)
  } else{
    .f.lost <- setdiff(features, .keywords.col)
    stop(stringr::str_glue('Features missing: {.f.lost}'))
  }
}


ckFeas <- function(seu, features, assay = "RNA", slot = 'data', add.anno = FALSE,
                   group.by = NULL, keyvar = NULL, valvar = NULL, annovar = NULL, 
                   force = FALSE, return.matrix = TRUE, format = 'wide', long.var = NULL,
                   long.value = 'Expr', long.key = 'feature'){
  invisible(requireNamespace("cli", quietly = TRUE))
  .meta.var <- NULL
  .ident <- FALSE
  if (inherits(seu, 'Seurat')){
    if (is.null(group.by)) { 
      .ident <- TRUE
    } else {
      .meta.var <- group.by
    }
    .features.inquiry <- c(features, .meta.var)
    if (isTRUE(add.anno)) {
      if (is.null(annovar)) {
        cli_abort(message = "annovar should NOT be NULL when add.anno is TRUE")
      }
    }
    .features.all <- c(rownames(seu), colnames(seu@meta.data))
    .features.available <- intersect(.features.inquiry, .features.all)
    .features.lack <- setdiff(.features.inquiry, .features.all)
    .features.lack.n <- length(.features.lack)
    .features.available.n <- length(x = .features.available)
    if (.features.lack.n > 0 && .features.available.n >0) {
      if (force) {
        cli::cli_inform(message = "{ .features.lack.n} features are not present in the object and will be ignored.")
      } else {
        cli::cli_abort(message = "{ .features.lack.n} features are not present in the object, please check the data or change the parameter {.code force=FALSE} to {.code force=TRUE}.")
      }
    }
    if (isTRUE(return.matrix)) {
      .exp.matrix <- fetchFeasMeta(seu, assay = assay, slot = slot, 
                                   features = .features.available, 
                                   ident.return = .ident, format = format, 
                                   long.var = long.var, long.key = keyvar, long.value = valvar)
      return(.exp.matrix)
    }
  } else if (is.data.frame(seu)){

    if (is.null(group.by) | is.null(keyvar) | is.null(valvar)) {
      cli::cli_abort(message = "group.by, keyvar, and valvar MUST be contained in the colnames of input data.frame") 
    } else {
      .features.inquiry <- c(features, group.by, keyvar, valvar)
      if (isTRUE(add.anno)) {
        if (is.null(annovar)) {
          cli::cli_abort(message = "annovar should NOT be NULL when add.anno is TRUE")
        } else{
          .features.inquiry <- c(.features.inquiry, annovar)
        }
      }
      .features.all <-  colnames(seu)
      .features.available <- intersect(.features.inquiry, .features.all)
      .features.lack <- setdiff(.features.inquiry, .features.all)
      .features.lack.n <- length(.features.lack)
      .features.available.n <- length(x = .features.available)
      if (.features.lack.n > 0 && .features.available.n > 0) {
        if (force) {
          cli_abort::cli_inform(message = "{ .features.lack.n} features are not present in the object and will be ignored.")
        } else {
          cli_abort::cli_abort(message = "{ .features.lack.n} features are not present in the object, please check the data or change the parameter {.code force=FALSE} to {.code force=TRUE}.")
        }
      }
      if (isTRUE(return.matrix)) {
        seu <- data.table::data.table(seu)
        .exp.matrix <- seu[,.features.inquiry, with = F]
        return(.exp.matrix)
      }
    }
  } else {
    cli::cli_abort(message = "Only accept Seurat object or data.frame")
  }
}

runSlingshot <- function(seu, group.by, reduction = NULL, dims = NULL, 
                         start = NULL, end = NULL, prefix = NULL,
                         reverse = FALSE, align.start = FALSE, 
                         show.plot = TRUE, lineage.palette = "Dark2", 
                         seed = 10086, ...) {
  set.seed(seed)
  invisible(requireNamespace("slingshot", quietly = TRUE))
  if (missing(group.by) || is.null(group.by)) cli::cli_abort("Please input available value for parameter group.by")
  .reduction <- DefaultReduction(seu)
  if (!is.null(reduction)) .reduction <- DefaultReduction(seu, pattern = reduction)
  .prefix <- ifelse(is.null(prefix), "", paste0(prefix, "_"))
  if (length(.prefix) > 1) cli::cli_abort("prefix should be a single string")
  .seu.sub <- seu[, !is.na(seu[[group.by, drop = TRUE]])]
  if (is.null(dims)){
    .dims <- 1:2
  } else if (length(dims) == 1) {
    .dims <- c(1:dims)
  } else {
    .dims <- dims[1:2]
  }
  .sl <- slingshot::slingshot(
    data = as.data.frame(.seu.sub[[.reduction]]@cell.embeddings[, .dims]),
    clusterLabels = as.character(.seu.sub[[group.by, drop = TRUE]]),
    start.clus = start, end.clus = end, ...
  )
  seu@tools[[paste("Slingshot", group.by, .reduction, sep = "_")]] <- .sl
  .df <- as.data.frame(slingshot::slingPseudotime(.sl))
  colnames(df) <- paste0(prefix, colnames(df))
  if (isTRUE(reverse)) {
    if (isTRUE(align.start)) {
      .df <- apply(.df, 2, function(x) max(x, na.rm = TRUE) - x)
    } else {
      .df <- max(.df, na.rm = TRUE) - .df
    }
  }
  seu <- Seurat::AddMetaData(seu, metadata = .df)
  seu <- Seurat::AddMetaData(seu, metadata = slingshot::slingBranchID(.sl), col.name = paste0(prefix, "BranchID"))
  
  if (isTRUE(show.plot)) {
    if (ncol(seu[[.reduction]]@cell.embeddings) == 2 || ncol(seu[[.reduction]]@cell.embeddings) > 3) {
      .p <- CellDimPlot(seu, group.by = .group.by, reduction = .reduction, dims = c(1, 2), lineages = .colnames(.df))
      print(p)
    } else if (ncol(seu[[.reduction]]@cell.embeddings) == 3) {
      .p <- CellDimPlot3D(seu, group.by = .group.by, reduction = .reduction, lineages = colnames(.df))
      print(p)
    }
    if (inherits(.p, "ggplot")) print(.p)
  }
  return(seu)
}

runPAGA <- function(seu = NULL, assay_X = "RNA", slot_X = "counts", 
                    assay_layers = c("spliced", "unspliced"), slot_layers = "counts",
                    adata = NULL, group_by = NULL,
                    linear_reduction = NULL, nonlinear_reduction = NULL, basis = NULL,
                    n_pcs = 30, n_neighbors = 30, use_rna_velocity = FALSE, vkey = "stochastic",
                    embedded_with_PAGA = FALSE, paga_layout = "fr", threshold = 0.1, point_size = 20,
                    infer_pseudotime = FALSE, root_group = NULL, root_cell = NULL, n_dcs = 10, n_branchings = 0, min_group_size = 0.01,
                    palette = "Paired", palcolor = NULL,
                    show_plot = TRUE, save = FALSE, dpi = 300, dirpath = "./", fileprefix = "",
                    return_seurat = !is.null(srt)) {
  ckPacsPy("scanpy")
  if (all(is.null(seu), is.null(adata))) stop("Need 'seu' OR 'adata' object.")
  if (is.null(group_by)) {
    stop("'group_by' must be provided.")
  }
  if (is.null(linear_reduction) && is.null(nonlinear_reduction)) {
    stop("'linear_reduction' or 'nonlinear_reduction' must be provided at least one.")
  }
  args <- mget(names(formals()))
  args <- lapply(args, function(x) {
    if (is.numeric(x)) {
      y <- ifelse(grepl("\\.", as.character(x)), as.double(x), as.integer(x))
    } else {
      y <- x
    }
    return(y)
  })
  call.envir <- parent.frame(1)
  args <- lapply(args, function(arg) {
    if (is.symbol(arg)) {
      eval(arg, envir = call.envir)
    } else if (is.call(arg)) {
      eval(arg, envir = call.envir)
    } else {
      arg
    }
  })
  args <- args[!names(args) %in% c("srt", "assay_X", "slot_X", "assay_layers", "slot_layers", "return_seurat", "palette", "palcolor")]
  
  if (!is.null(srt)) {
    args[["adata"]] <- srt_to_adata(
      srt = srt,
      assay_X = assay_X, slot_X = slot_X,
      assay_layers = assay_layers, slot_layers = slot_layers
    )
  }
  groups <- py_to_r_auto(args[["adata"]]$obs)[[group_by]]
  args[["palette"]] <- palette_scp(levels(groups) %||% unique(groups), palette = palette, palcolor = palcolor)
  
  SCP_analysis <- reticulate::import_from_path("SCP_analysis", path = system.file("python", package = "SCP", mustWork = TRUE), convert = TRUE)
  adata <- do.call(SCP_analysis$PAGA, args)
  
  if (isTRUE(return_seurat)) {
    srt_out <- adata_to_srt(adata)
    if (is.null(srt)) {
      return(srt_out)
    } else {
      srt_out1 <- SrtAppend(srt_raw = srt, srt_append = srt_out)
      srt_out2 <- SrtAppend(srt_raw = srt_out1, srt_append = srt_out, pattern = "(paga)|(distances)|(connectivities)|(draw_graph)", overwrite = TRUE, verbose = FALSE)
      return(srt_out2)
    }
  } else {
    return(adata)
  }
}


labelTrans <- function(ref, qry,
                       reduction = "pca",
                       dims = 1:20,
                       meta.col = "seurat_clusters",
                       def.res = 0.2) {
  invisible(requireNamespace("Seurat", quietly = TRUE))
  invisible(requireNamespace("cli", quietly = TRUE))
  
  stopifnot(length(dims) >= 1)
  
  if (missing(reduction) || is.null(reduction) || !is.character(reduction) || length(reduction) != 1) {
    cli::cli_abort("Please input an available value for parameter {.arg reduction}.")
  }
  
  .make_seu <- function(x, project = "obj") {
    if (inherits(x, "Seurat")) {
      return(x)
    }
    
    if (is.matrix(x) || is.data.frame(x)) {
      .seu <- Seurat::CreateSeuratObject(
        counts = x,
        project = project
      )
      
      if (exists("prepSeuList", mode = "function")) {
        .tmp <- prepSeuList(.seu)
        if (!is.null(.tmp$seuList) && length(.tmp$seuList) >= 1) {
          .seu <- .tmp$seuList[[1]]
        }
      }
      
      return(.seu)
    }
    
    cli::cli_abort("Please input Seurat objects, matrices, or data.frames for both {.arg ref} and {.arg qry}.")
  }
  
  .prep_sct_pca <- function(seu, dims, run_cluster = FALSE, def.res = 0.2) {
    if (!"SCT" %in% Seurat::Assays(seu)) {
      seu <- Seurat::SCTransform(seu, verbose = FALSE)
    }
    
    if (!"pca" %in% Seurat::Reductions(seu)) {
      seu <- Seurat::RunPCA(seu, assay = "SCT", verbose = FALSE)
    }
    
    if (isTRUE(run_cluster) && !"seurat_clusters" %in% colnames(seu@meta.data)) {
      seu <- Seurat::FindNeighbors(seu, reduction = "pca", dims = dims, verbose = FALSE)
      seu <- Seurat::FindClusters(seu, resolution = def.res, verbose = FALSE)
    }
    
    return(seu)
  }
  
  .ref <- .make_seu(ref, project = deparse(substitute(ref)))
  .qry <- .make_seu(qry, project = deparse(substitute(qry)))
  
  .ref <- .prep_sct_pca(.ref, dims = dims, run_cluster = TRUE, def.res = def.res)
  .qry <- .prep_sct_pca(.qry, dims = dims, run_cluster = FALSE, def.res = def.res)
  
  .meta.col <- if (meta.col %in% colnames(.ref@meta.data)) {
    meta.col
  } else if ("seurat_clusters" %in% colnames(.ref@meta.data)) {
    "seurat_clusters"
  } else {
    cli::cli_abort(
      "Please input an available value for parameter {.arg meta.col}, or ensure the reference has cluster labels."
    )
  }
  
  if (!reduction %in% Seurat::Reductions(.ref)) {
    cli::cli_abort(
      "Reduction {.val {reduction}} is not available in the reference object. Available reductions: {.val {Seurat::Reductions(.ref)}}"
    )
  }
  
  .anchors <- Seurat::FindTransferAnchors(
    reference = .ref,
    query = .qry,
    normalization.method = "SCT",
    reference.assay = "SCT",
    query.assay = "SCT",
    reference.reduction = reduction,
    recompute.residuals = FALSE,
    dims = dims
  )
  
  .predictions <- Seurat::TransferData(
    anchorset = .anchors,
    refdata = .ref@meta.data[, .meta.col, drop = TRUE],
    dims = dims
  )
  
  .qry <- Seurat::AddMetaData(.qry, metadata = .predictions)
  
  .out <- Seurat::MapQuery(
    anchorset = .anchors,
    reference = .ref,
    query = .qry,
    refdata = setNames(
      list(.ref@meta.data[, .meta.col, drop = TRUE]),
      .meta.col
    ),
    reference.reduction = reduction,
    reduction.model = if ("umap" %in% Seurat::Reductions(.ref)) "umap" else NULL
  )
  
  return(.out)
}
