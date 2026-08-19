# Local copy of SCA util.ck.R helpers needed by VocalnoPlot.R
# Only ckCols is required by volcanoPlot.

ckCols <- function(df, cols, margin = 2, col.return = FALSE, force = FALSE, appFun = '', default = '', ...){
  if (is.null(cols)) stop("Input cols is NULL")
  if (!inherits(df, 'data.frame')) stop("Input df is not a data frame")
  if (margin == 1) df <- t(df)
  .cols.df <- colnames(df)
  .cols <- cols
  if (methods::is(cols, "list")) .cols <- unlist(.cols)
  .ind <- match(.cols, .cols.df)
  .ind.na <- is.na(.ind)
  .message.warning <- NULL
  .cols.missing <- .cols[which(.ind.na)]
  if (any(.ind.na)) {
    .cols.missing <- .cols[which(.ind.na)]
    .message.warning <- stringr::str_glue("Some columns are not found in the data frame: '{paste0(.cols.missing, collapse = ', ')}'\n")
  }
  if (!is.null(.message.warning) & isFALSE(force)) stop(.message.warning, call. = FALSE)
  if (isTRUE(col.return)) {
    if (length(.message.warning) >0 ) message(.message.warning)
    .in.cols.df <- df[, which(.cols.df %in% .cols), drop = FALSE]
    if (is.function(appFun)) {
      if (ncol(.in.cols.df) > 0) {
        for(.c in colnames(.in.cols.df)) {
          .in.cols.df[[.c]] <- appFun(.in.cols.df[[.c]], ...)
        }
      }
    }
    if (isTRUE(force)) {
      if (length(.cols.missing) > 0) {
        for(.c in .cols.missing) {
          .in.cols.df[[.c]] <- default
        }
      }
    }
    if (margin == 1) .in.cols.df <- t(.in.cols.df)
    return(.in.cols.df)
  }
}