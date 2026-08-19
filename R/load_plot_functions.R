# ------------------------------------------------------------
# OmicsCanvas Plot Function Loader
# Usage: source("R/load_plot_functions.R")
#   Optional: source_omicscanvas_plot_functions(root = "<abs path>")
# When sourced, the project root is auto-detected from this file's location.
# ------------------------------------------------------------

if (!exists("%||%", envir = .GlobalEnv, inherits = FALSE)) {
  `%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x
}

# Compute project root from this file's own path when sourced.
.detect_omicscanvas_root <- function() {
  frames <- sys.frames()
  for (i in seq_along(frames)) {
    of <- frames[[i]]$ofile
    if (!is.null(of)) {
      return(dirname(dirname(normalizePath(of))))
    }
  }
  getwd()
}

# Default root: computed once when this file is loaded.
.omicscanvas_root <- .detect_omicscanvas_root()
options(omicscanvas.root = .omicscanvas_root)

source_omicscanvas_plot_functions <- function(root = .omicscanvas_root) {
  files <- c(
    file.path(root, "R/data_format_validation/util.ck.R"),
    file.path(root, "R/data_format_validation/util.ck.seu.R"),
    file.path(root, "R/data_format_validation/util.mat.R"),
    file.path(root, "R/data_format_validation/util.fun.sc.R"),
    file.path(root, "R/data_format_validation/util.scf.R"),
    file.path(root, "R/data_format_validation/plotdata.prep.seu.R"),
    file.path(root, "R/basic_plots/util.plot.R"),
    file.path(root, "R/basic_plots/graphical.funs.R"),
    file.path(root, "R/basic_plots/common.plots.R"),
    file.path(root, "R/basic_plots/add.on.layers.4.dimplot.R"),
    file.path(root, "R/basic_plots/statPlot.R"),
    file.path(root, "R/basic_plots/DotPlot.R"),
    file.path(root, "R/basic_plots/VocalnoPlot.R"),
    file.path(root, "R/basic_plots/violinPlot.R"),
    file.path(root, "R/basic_plots/GsDenPlot.R"),
    file.path(root, "R/advanced_plots/expStatPlot.R"),
    file.path(root, "R/advanced_plots/advDimPlot.R"),
    file.path(root, "R/advanced_plots/advFeaPlot.R"),
    file.path(root, "R/advanced_plots/GroupHeatmap.R"),
    file.path(root, "R/advanced_plots/lineagePlot.R")
  )

  missing <- files[!file.exists(files)]
  if (length(missing) > 0) {
    stop("Missing OmicsCanvas R function files: ", paste(missing, collapse = ", "))
  }

  invisible(lapply(files, source))
}
