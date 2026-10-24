# OmicsCanvas shims applied on top of the SCA helpers (source after util.plot.R).

# Locate assets/palettes.rds relative to the repo (R/sca -> ../../assets), so
# plugins work from any working directory and on any machine.
omicscanvas_palette_file <- function(helper_dir) {
  candidates <- c(
    file.path(helper_dir, '..', '..', 'assets', 'palettes.rds'),
    file.path(getwd(), 'assets', 'palettes.rds')
  )
  hit <- candidates[file.exists(candidates)]
  if (length(hit) > 0) normalizePath(hit[1]) else candidates[1]
}

# Make paletteCustomize() default to the OmicsCanvas palettes.rds asset.
omicscanvas_patch_palette <- function(helper_dir) {
  old_palette <- get('paletteCustomize', envir = .GlobalEnv)
  palette_file <- omicscanvas_palette_file(helper_dir)
  assign('paletteCustomize', function(..., palettePath = NULL) {
    old_palette(..., palettePath = if (is.null(palettePath)) palette_file else palettePath)
  }, envir = .GlobalEnv)
  invisible(palette_file)
}
