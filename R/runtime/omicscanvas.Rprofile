# Startup profile for every OmicsCanvas plugin run (set via R_PROFILE_USER by
# plot_web/server/runner.py and scripts/smoke_plugins.py).
#
# Seeds the RNG so jitter, ggrepel label placement and permutation statistics
# render identically for identical inputs. The seed comes from params.seed
# (exported as OMICSCANVAS_SEED) and is recorded in run provenance.
#
# htmlwidgets::saveWidget(selfcontained = TRUE) needs pandoc. Interactive plugins
# must still finish PNG/PDF when pandoc is missing, so saveWidget falls back to
# a non-selfcontained HTML (then a stub page) instead of aborting the job.
local({
  user_profile <- Sys.getenv("OMICSCANVAS_USER_RPROFILE", path.expand("~/.Rprofile"))
  if (nzchar(user_profile) && file.exists(user_profile)) sys.source(user_profile, envir = globalenv())
  seed <- suppressWarnings(as.integer(Sys.getenv("OMICSCANVAS_SEED", "42")))
  if (is.na(seed)) seed <- 42L
  set.seed(seed)

  pandoc_available <- function() {
    if (nzchar(Sys.which("pandoc"))) return(TRUE)
    rstudio <- Sys.getenv("RSTUDIO_PANDOC", "")
    if (nzchar(rstudio) && (file.exists(rstudio) || file.exists(file.path(rstudio, "pandoc")))) return(TRUE)
    if (requireNamespace("rmarkdown", quietly = TRUE)) {
      return(isTRUE(tryCatch(rmarkdown::pandoc_available(), error = function(e) FALSE)))
    }
    FALSE
  }

  wrap_saveWidget <- function(...) {
    if (!requireNamespace("htmlwidgets", quietly = TRUE)) return(invisible(FALSE))
    ns <- asNamespace("htmlwidgets")
    if (isTRUE(tryCatch(get0(".omicscanvas_wrapped", envir = ns, inherits = FALSE), error = function(e) FALSE))) {
      return(invisible(TRUE))
    }
    orig <- get("saveWidget", envir = ns, inherits = FALSE)
    wrapped <- function(widget, file, selfcontained = TRUE, ...) {
      try_save <- function(sc) orig(widget, file, selfcontained = sc, ...)
      if (isTRUE(selfcontained) && pandoc_available()) {
        ok <- tryCatch({ try_save(TRUE); TRUE }, error = function(e) FALSE)
        if (ok) return(invisible(file))
      }
      ok <- tryCatch({ try_save(FALSE); TRUE }, error = function(e) FALSE)
      if (ok) return(invisible(file))
      writeLines(
        "<html><body><p>Interactive HTML could not be written. See result.png.</p></body></html>",
        file
      )
      invisible(file)
    }
    tryCatch({
      unlockBinding("saveWidget", ns)
      assign("saveWidget", wrapped, envir = ns)
      assign(".omicscanvas_wrapped", TRUE, envir = ns)
      lockBinding("saveWidget", ns)
      TRUE
    }, error = function(e) FALSE)
  }

  setHook(packageEvent("htmlwidgets", "onLoad"), function(...) wrap_saveWidget())
  if ("htmlwidgets" %in% loadedNamespaces()) wrap_saveWidget()
})
