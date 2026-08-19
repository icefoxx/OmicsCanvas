plotdata.prep.seu <- function(seu, features, slot = 'data', assay = "RNA",
                              reduction = NULL, dim = c(1,2),
                              coexp = 'mean', ident.return = T){
  .normalize_feature_name <- function(x) {
    x <- trimws(as.character(x))
    x <- tolower(x)
    gsub("[._\\-[:space:]]+", "", x)
  }
  .resolve_feature_aliases <- function(features, available) {
    .resolved <- features
    .replacements <- character(0)
    .need.match <- which(!features %in% available)
    if (length(.need.match) == 0) {
      return(list(features = .resolved, replacements = .replacements))
    }
    .available.groups <- split(available, .normalize_feature_name(available))
    for (i in .need.match) {
      .candidates <- unique(.available.groups[[.normalize_feature_name(features[i])]])
      if (length(.candidates) == 1) {
        .resolved[i] <- .candidates
        .replacements[features[i]] <- .candidates
      }
    }
    list(features = .resolved, replacements = .replacements)
  }
  .suggest_feature_names <- function(features, available, n = 3) {
    if (length(available) == 0) {
      return(setNames(vector("list", length(features)), features))
    }
    .available.norm <- .normalize_feature_name(available)
    setNames(lapply(features, function(feature) {
      .feature.norm <- .normalize_feature_name(feature)
      .dist <- utils::adist(.feature.norm, .available.norm)
      .ord <- order(.dist[1, ], available)
      head(unique(available[.ord]), n)
    }), features)
  }
  
  if (missing(seu) || nrow(seu@meta.data) == 0) cli::cli_abort("Unavailable meta.data ")
  ckSeu(seu)
  .feas <- features
  if (is.list(features)) .feas <- unlist(features, use.names = F)
  if (!inherits(.feas, "character")) stop("'features' is not a character vectors")
  .features.exp <- rownames(slot(seu[[assay]], name = slot))
  .feature.meta <- colnames(seu@meta.data)
  .allfeatures.raw <- unique(c(.features.exp, .feature.meta))
  .feature.aliases <- .resolve_feature_aliases(.feas, .allfeatures.raw)
  .feas <- .feature.aliases$features
  if (length(.feature.aliases$replacements) > 0) {
    .alias.msg <- paste0(names(.feature.aliases$replacements), " -> ", unname(.feature.aliases$replacements))
    cli::cli_inform("Resolved feature alias(es): {paste(.alias.msg, collapse = ', ')}")
  }
  .cell.all.in.meta <- rownames(seu@meta.data)
  .cell.all.in.exp <- colnames(slot(seu[[assay]], name = slot))
  stopifnot(all(.cell.all.in.exp %in% .cell.all.in.meta))
  .cell.all <- .cell.all.in.meta
  rm(list = c(".cell.all.in.meta", ".cell.all.in.exp"))
  .feas.by.exp <- intersect(.feas, .features.exp)
  .feas.by.meta <- intersect(.feas, .feature.meta)
  .feature.2 <- intersect(.feas.by.exp, .feas.by.meta)
  if (length(.feature.2) > 0) {
    cli::cli_alert('Both exp matrix and metadata have the same feature: {paste0((.feature.2), collapse = ",")}. ')
  }
  .allfeatures <- unique(c(.feas.by.exp, .feas.by.meta))
  .feas.by.ava <- .feas %in% .allfeatures
  .features.miss <- .feas[!.feas.by.ava]
  if (sum(.feas.by.ava) == 0) {
    .feature.suggestions <- .suggest_feature_names(.features.miss, .allfeatures.raw)
    .feature.miss.msg <- vapply(.features.miss, function(feature) {
      .suggestions <- .feature.suggestions[[feature]]
      if (length(.suggestions) > 0) {
        paste0(feature, " (closest: ", paste(.suggestions, collapse = ", "), ")")
      } else {
        feature
      }
    }, character(1))
    cli::cli_abort("Features not found in assay/meta.data: {paste(.feature.miss.msg, collapse = ', ')}")
  } else{
    if (length(.features.miss) > 0) {
      .feature.suggestions <- .suggest_feature_names(.features.miss, .allfeatures.raw)
      .feature.miss.msg <- vapply(.features.miss, function(feature) {
        .suggestions <- .feature.suggestions[[feature]]
        if (length(.suggestions) > 0) {
          paste0(feature, " (closest: ", paste(.suggestions, collapse = ", "), ")")
        } else {
          feature
        }
      }, character(1))
      cli::cli_abort("Feature(s) not found in assay/meta.data: {paste(.feature.miss.msg, collapse = ', ')}")
    }
    .feas <- .feas[.feas.by.ava]
  }
  .df <- fetchFeasMeta(seu, features = .feas, slot = slot, assay = assay, ident.return = ident.return)
  if (!is.null(coexp)) {
    if (length(.feas.by.exp) > 1) {
      .exp.m <- as.matrix(.df[, ...feas.by.exp])
      View(.exp.m)
      .dt <- ckDataType(.exp.m)
      cli::cli_inform("Input data type of expression matrix: ", .dt)
      if (.dt %in% c("rawCounts", "rawCountsNormalized")) {
        .df[["CoExp"]] <- apply(.exp.m, 1, function(x) mmdata(x, m = coexp, model = 1))
      } else if (.dt == "countsLogNormal") {
        .df[["CoExp"]] <- apply(.exp.m, 1, function(x) mmdata(x, m = coexp, model = 2))
      } else {
        stop("Unknown data type.")
      }
    } else {
      .df[["CoExp"]]  <- unlist(.df[, ...feas.by.exp], use.names = F) 
    }
  }
  if (!is.null(reduction)) {
    .reducts <- names(seu@reductions)
    if (! reduction %in% .reducts) cli::cli_abort('Reduction: {reduction} does NOT exist in current Seu obj')
    .xy <- seu@reductions[[reduction]]@cell.embeddings[, dim]
    colnames(.xy) <- c('x', 'y')
    .df <- .xy %>%
      as.data.frame() %>%
      tibble::rownames_to_column(var = 'cell.barcodes.selected') %>%
      dplyr::right_join(.df)
  }
  return(.df)
}
