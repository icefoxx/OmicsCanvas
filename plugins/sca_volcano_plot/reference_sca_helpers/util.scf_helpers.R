# Local copy of SCA util.scf.R helpers needed by VocalnoPlot.R
# Only topMarkers.seu is required by avgVolcano / percentVocalno.

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

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
        dplyr::group_by(.data[[selection]], .data[['UpDown']]) %>%
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