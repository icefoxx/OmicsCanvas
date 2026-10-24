
# Check if the path is a file or a folder
#' @param path The path to check
#' @return "file" if the path is a file, "folder" if the path is a folder, NULL if the path does not exist
#' @examples
#' checkPath("path/to/file")
#' checkPath("path/to/folder")
#' checkPath("path/to/nonexistent")
#' @export
#' @author Qiong.Zhang
#' 
ckPath <- function(path) {
  if (file.exists(path)) {  # Check if the path exists
    if (dir.exists(path)) {  # Check if the path is a folder
      return("folder")
    } else {
      return("file")
    }
  } else {
    return(NULL)
  }
}

# check the exsitence of the columns in the data frame and users could modify the values of given column via input appFun
# then return the columns if they exist and needed. 
#
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


ckDataType <- function(data) {
  .isfinite <- all(is.finite(range(data, na.rm = TRUE)))
  if (!isTRUE(.isfinite)) {
    if (is.character(data)) return('character')
    warning("Infinite values found!", immediate. = TRUE)
    return("unknown")
  } else {
    if (inherits(data, 'Matrix') | inherits(data, 'matrix')){
      if (inherits(data, "dgCMatrix")) {
        .isfloat <- any(data@x %% 1 != 0, na.rm = TRUE)
      } else {
        .isfloat <- any(data[, sample(seq_len(ncol(data)), min(ncol(data), 1000))] %% 1 != 0, na.rm = TRUE)
      }
    }
    .isnegative <- any(data < 0)
    .isRowScale <- median(abs(Matrix::rowSums(data))) < 1e-10
    .isColScale <- median(abs(Matrix::colSums(data))) < 1e-10
    .islog <- is.finite(expm1(x = max(data, na.rm = TRUE)))
    if (!.isfloat) {
      return("rawCounts")
    } else {
      if (isTRUE(.islog)) {
        if (isTRUE(.isnegative)) {
          if (.isRowScale) return('rowScaledData')
          if (.isColScale) return('colScaledData')
          return('unknown')
        } else {
          return("countsLogNormal")
        }
      } else {
        if (isFALSE(.isnegative)) return("rawCountsNormalized")
        return('unknown')
      } 
    }
  }
}


#' Check If String is a URL
#' 
#' Uses a regex approach to check if a string is a url.  This approach is faster
#' than \code{\link[RCurl]{url.exists}} but does do the actual verification.
#' 
#' @param x A character string.
#' @return Returns a logical evalution as to whether a string is a url.
#' @keywords url
#' @export
#' @seealso \code{\link[RCurl]{url.exists}}
#' @author Qiong Zhang
#' @examples
#' urls <- c("a", "f/g/h", "www.stjude.org", "https://github.com/icefoxx")
#' is.url(urls)
is.url <-function(x) {
  grepl("www.|http:|https:", x)
}

#' Automatically check whether the version of R packages meets demands and install them if necessary.
#'
#' @param packages Packages to be installed. The package name can be followed by a version number or a github address,e.g., "ggplot2@3.3.0" or "
#' @param sources The source of the packages. Default is \code{c("Bioc", "CRAN", "github", "auto")}
#' @param libloc Where to install the packages.
#' @param force Force installation of packages or NOT. Default is \code{FALSE}.
#' @importFrom utils packageVersion
#' @importFrom pacman requireNamespace
#' @export
#' 
ckPacsR <- function(packages, sources = c('auto'), libloc = .libPaths()[1], forceUpdate = FALSE){
  .devtools.require <- str2lang('suppressPackageStartupMessages(requireNamespace("devtools", quietly = TRUE))')
  .devtools.flag <- eval(.devtools.require)
  if (!.devtools.flag) install.packages("devtools")
  if (!eval(.devtools.require)) stop("Failed to install devtools. Please install it manually before automatical installation.")
  .source.option <- c('Bioc', 'CRAN', 'github', 'auto')
  .run.option <- c('install_version', 'install_version', 'github', 'auto')
  .run.option.2 <- c('p_install_version', 'p_install_version', 'p_install_version_gh', 'auto')
  .packages.n <- length(packages)
  .status_list <- rep(FALSE, .packages.n)
  .sources.n <- length(sources)
  .source_list <- NULL
  if (.sources.n == 1) {
    .source_list <- rep(sources, .packages.n)
  } else if (.packages.n != .sources.n) {
    stop("The length of sources should be the same as the length of packages.")
  } else {
    .source_list <- sources
  }
  .run.lst <- .run.option[match(.source_list, .source.option)]
  .run.lst.2 <- .run.option.2[match(.source_list, .source.option)]
  print_message("Checking package status.....: \"", paste0(packages, collapse = ', '), "\" ...")
  for (i in seq_along(packages)) {
    .pkg <- packages[i]
    .pkg.version <- '0.0.0.0'
    .pkg_name <- NULL
    if (grepl("/", .pkg)) {
      # github pac
      if (.run.lst[i] %in% c('auto', 'github')) {
        .run.lst[i] <- 'install_github'
        if (is.url(.pkg)) .run.lst[i] <- 'install_git'
        .run.lst.2[i] <- 'p_install_version_gh'
      }
      .pkg_name <- strsplit(.pkg, split = "/|@|==", perl = TRUE)[[1]][[2]]
    } else {
      .pkg.candi <- strsplit(.pkg, split = "@|==", perl = TRUE)[[1]]
      .pkg_name <- .pkg.candi[[1]]
      if (.run.lst[i] == 'auto') {
        .run.lst[i] <- 'install_version'
        .run.lst.2[i] <- 'p_install_version'
      }
      if (length(.pkg.candi) > 1) .pkg.version <- .pkg.candi[[2]]
    }
    .pkg.status <- suppressPackageStartupMessages(requireNamespace(.pkg_name, quietly = TRUE))
    if (!.pkg.status || utils::packageVersion(.pkg_name) < package_version(.pkg.version)) {
      print_message("Updating package: \"", .pkg_name, "\" ...")
      .t <- 1
      while (isFALSE(.status_list[i])) {
        tryCatch(expr = {
          if (.t < 2) {
            .f <- get(.run.lst[i], envir = loadNamespace("devtools"))
            .f(.pkg_name, version = .pkg.version, upgrade = F, quiet = T)
          } else {
            .f <- get(.run.lst.2[i], envir = loadNamespace("pcman"))
            .f(.pkg_name, version = .pkg.version)
          }
        }, error = function(e) {
          print_message(paste0(c("Failed to install package: \"", .pkg_name, "\" ... for the ", .t, "th time."), collapse = ""))
        })
        .status_list[i] <- requireNamespace(.pkg_name, quietly = TRUE)
        .t <- .t + 1
        if (.status_list[i] || .t > 3 ) break
      }
    } else {
      .status_list[i] <- TRUE
    }
  }
  .lack.index <- !.status_list
  if (sum(.lack.index) > 0) {
    stop("Failed to install the package(s): ", paste0( packages[.lack.index], collapse = ", "), ". Please install manually.")
  } else {
    print_message("Required packages were installed.")
  }
  return(TRUE)
}

#' Automatically check whether the version of python packages meets demands and install them if necessary.
#'
#' @param packages Packages to be installed. The package name can be followed by a version number or a github address,e.g., "ggplot2@3.3.0" or "
#' @param env The name of the python environment. 
#' @param def  Conda path. Default is \code{"auto"}. Automatically find an appropriate conda env.
#' @param conda Conda path. Default is \code{"auto"}. Automatically find an appropriate conda env.
#' @param force Force package installation OR update. Default is \code{FALSE}.
#' @param pip_alternative Whether to use pip for package installation if conda installation failed.
#' @param pip_para Parameters pass to pip.
#' @param ... Other parameters passed to \code{\link[reticulate]{conda_install}}
#' @author Qiong Zhang
#' 
#' @examples
#' check_Python(packages = c("bbknn", "scanorama"))
#' \dontrun{
#' check_Python(packages = "scvi-tools==0.20.0", envname = "SCP_env", pip_options = "-i https://pypi.tuna.tsinghua.edu.cn/simple")
#' }
#' @export
######unfinish
ckPacsPy <- function(packages, env = NULL, conda = "auto", force = FALSE, pip_alternative = FALSE, pip_options = c(), ...) {
  .env <- getOpt(env, 'SCA_env')
  if (identical(conda, "auto")) {
    .conda <- findConda()
  } else {
    options(reticulate.conda_binary = conda)
    .conda <- findConda()
  }
  env <- env_exist(conda = conda, envname = envname)
  if (isFALSE(env)) {
    warning(envname, " python environment does not exist. Create it with the PrepareEnv function...", immediate. = TRUE)
    PrepareEnv()
  }
  if (isTRUE(force)) {
    pkg_installed <- setNames(rep(FALSE, length(packages)), packages)
    pip_options <- c(pip_options, "--force-reinstall")
  } else {
    pkg_installed <- exist_Python_pkgs(packages = packages, envname = envname, conda = conda)
  }
  if (sum(!pkg_installed) > 0) {
    pkgs_to_install <- names(pkg_installed)[!pkg_installed]
    message("Try to install ", paste0(pkgs_to_install, collapse = ","), " ...")
    if (isTRUE(pip)) {
      pkgs_to_install <- c("pip", pkgs_to_install)
    }
    tryCatch(expr = {
      conda_install(conda = conda, packages = pkgs_to_install, envname = envname, pip = pip, pip_options = pip_options, ...)
    }, error = identity)
  }
  
  pkg_installed <- exist_Python_pkgs(packages = packages, envname = envname, conda = conda)
  if (sum(!pkg_installed) > 0) {
    stop("Failed to install the package(s): ", paste0(names(pkg_installed)[!pkg_installed], collapse = ","), " into the environment \"", envname, "\". Please install manually.")
  } else {
    return(invisible(NULL))
  }
}

