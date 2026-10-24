# Startup profile for every OmicsCanvas plugin run (set via R_PROFILE_USER by
# plot_web/server/runner.py and scripts/smoke_plugins.py).
#
# Seeds the RNG so jitter, ggrepel label placement and permutation statistics
# render identically for identical inputs. The seed comes from params.seed
# (exported as OMICSCANVAS_SEED) and is recorded in run provenance.
local({
  user_profile <- Sys.getenv("OMICSCANVAS_USER_RPROFILE", path.expand("~/.Rprofile"))
  if (nzchar(user_profile) && file.exists(user_profile)) sys.source(user_profile, envir = globalenv())
  seed <- suppressWarnings(as.integer(Sys.getenv("OMICSCANVAS_SEED", "42")))
  if (is.na(seed)) seed <- 42L
  set.seed(seed)
})
