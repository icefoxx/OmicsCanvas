# Cross-plugin performance check — 2026-10-24

Read-only performance investigation. No drawing code, parameters or baselines changed.
Inspected 23 successful historical jobs across eight plugins, then reran five plugin
commands twice each, serially, using identical saved inputs/parameters and temporary outputs.

| Plugin | First run (s) | Second run (s) |
|---|---:|---:|
| ternary_plot | 8.292 | 1.601 |
| sca_volcano_plot | 2.730 | 2.090 |
| interactive_violin_plot | 4.344 | 3.611 |
| exp_stat_plot | 7.932 | 4.748 |
| group_heatmap | 12.584 | 8.173 |

All ten commands exited successfully and produced PNGs. Times cover a complete independent
Rscript invocation, excluding HTTP, PlotSpec validation and browser display. First/second
means test order, not a controlled cold-cache/warm-cache experiment. This was not an image
quality regression check.

## Shared execution costs confirmed in code

- Demo and user-data requests both use run_local_job, launching a new subprocess per run.
- There is no render-result cache lookup in those execution paths.
- Plugins generate all standard export formats before returning. The editor waits for the
  complete HTTP response before updating its preview.
- Entering the editor automatically renders a demo/preset instead of first displaying an
  existing example image.
- Group Heatmap calls draw_object separately for PDF, PNG and SVG. Volcano and violin
  helpers also print/grid.draw separately for each device. Reusing a plot object does not
  avoid repeated drawing/layout work.

## Additional differences and limits

SCA wrappers load extra packages and source shared R helpers on each process invocation.
ComplexHeatmap adds layout/legend drawing costs. Volcano and violin save helpers contain
retry paths (up to three attempts), but these timings do not establish that retries occurred.

Plugin-detail generation measured approximately 0.06–0.10 seconds; discovery payload
generation approximately 0.05 seconds. These checks did not expose overhead comparable to
the full R render. Historical PlotSpec write offsets were usually about 0.07–0.60 seconds.
File write timestamps indicate output completion order, not precise per-stage profiler data.

The editor also synchronously loads an external Plotly script in its head. That may affect
initial page loading; external-script latency was not measured and must not be presented
as an established cause of backend Running time.

The common architecture affects every plugin using this runner, but not every plugin has
the same bottleneck. Prioritize unchanged-demo preview reuse, content/version-aware result
caching, and separating lightweight preview from formal exports. Then evaluate persistent
R workers and reuse of prepared data/plot objects. Cache keys must include input contents,
parameters, seed, plugin/shared-code versions and relevant runtime versions.

No exact startup/data-preparation/layout/export percentage is claimed without per-stage
profiling. No performance optimization was implemented in this investigation.
