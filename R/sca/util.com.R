toUpperX <- function(x, n = 1, force = T){
  invisible(requireNamespace('stringr'))
  .UpperX.nth <- function(string, n) {
    if (n > str_length(string)) {
      if (isFALSE(force)) clin::cli_abort("n is greater than the length of the string")
      return(string)
    }
    .string.before <- str_sub(string, 1, n - 1)
    .nth.letter <- str_to_upper(str_sub(string, n, n))
    .string.after <- str_sub(string, n + 1, str_length(string))
    return(paste0(.string.before, .nth.letter, .string.after))
  }
  sapply(x, .UpperX.nth, n = n)
}

expand.grid.df <- function(...) {
  Reduce(function(...) merge(..., by=NULL), list(...))
}

expand.grid.lst <- function(...) {
  Reduce(function(...) merge(..., by=NULL), ...)
}

#' @title Find common elements for a list of vectors
#' @name findComElem4List
#' @param lst A list of vectors.
#' @param cutoff The cutoff of the frequency of the common elements. Default is 2L.
#' @return A vector of common elements.
#' @author Qiong Zhang
#' @export
#' 
#'
findComElem4List <- function(lst, cutoff = 2L) {
  .outlier.freq <- table(unlist(lst))
  if (is.integer(cutoff)) {
    .cutoff <- cutoff
  }else if (is.double(cutoff)){
    .cutoff <- trunc(.var.n * cutoff)  
  }
  .outlier.index <- names(.outlier.freq)[.outlier.freq >= .cutoff]
  return(.outlier.index)
}

#' Print message
#'
#' @param ... Character string to print
#' @param time Logical to print time
#' @param verbose Logical to print message
#' @name print_message
#' @author Qiong Zhang
print_message <- function(..., time = T, verbose = T){
  if (verbose){
    if (time){
      message(format(Sys.time(), "%a %b %d %X %Y") , ": ",  ...)
    } else {
      message(...)
    }
  }
}


myRand <- function(n = 5000) {
  .a <- do.call(paste0, replicate(5, sample(LETTERS, n, TRUE), FALSE))
  paste0(.a, sprintf("%04d", sample(9999, n, TRUE)), sample(LETTERS, n, TRUE))
}
