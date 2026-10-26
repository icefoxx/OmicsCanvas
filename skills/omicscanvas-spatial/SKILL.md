---
name: omicscanvas-spatial
description: Choose scientific plots for spatial tissue regions and supplied vector overlays in OmicsCanvas, checking required data roles and interpretation limits.
metadata:
  role: plot_workflow
  layer: scenario
---

# Spatial tissue regions and supplied vector overlays

This is an agent-neutral scenario skill. Use it after `omicscanvas-router` identifies this question. It does not call a model provider or launch other agents.

Use `spatial_region_plot` for supplied polygons or spots with measurements; select `map_mark=spot` only for spot coordinates. Confirm the region/spot identifier, coordinate units, holes/boundaries and registration of any auxiliary image before plotting.

Image coordinates usually use a top-left origin with inverted Y; physical/cartesian coordinates may not. Preserve the declared coordinate convention. Missing measurements and absent regions are different conditions and should not both become zero. A tissue outline is not inferred segmentation.

Use `embedding_vector_plot` for supplied displacement vectors over supplied coordinates. Arrows require units/scaling and are not automatically RNA velocity, migration or causality. Inspect boundary clipping, aspect ratio, color range and legend units at export size.

## Available engines

`spatial_region_plot`, `embedding_vector_plot`.

Use `python -m omicscanvas catalog --workflow spatial` for the current compact list. Read `python -m omicscanvas describe ENGINE` for the chosen contract, schema and Plot Guide; do not load every plugin skill. Then follow `skills/omicscanvas-render/SKILL.md` to plan, validate and render. From another working directory, use an absolute path to `scripts/omicscanvas.py` with the project's Python environment.

If the scientific question or required role remains ambiguous, report the missing information and keep the candidate set open. Do not substitute synthetic data, infer unavailable analyses, or rank visual attractiveness above scientific suitability.
