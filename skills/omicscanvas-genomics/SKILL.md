---
name: omicscanvas-genomics
description: Choose scientific plots for genomic, mutation and sequence figures in OmicsCanvas, checking required data roles and interpretation limits.
metadata:
  role: plot_workflow
  layer: scenario
---

# Genomic, mutation and sequence figures

This is an agent-neutral scenario skill. Use it after `omicscanvas-router` identifies this question. It does not call a model provider or launch other agents.

Choose Manhattan/QQ for supplied association probabilities; distinguish p-values from negative-log values and confirm chromosome coordinates/build. Oncoprints need alteration types and gene/sample identifiers, with explicit missing-versus-unaltered semantics.

Protein maps need residue coordinates, variant counts and supplied domains. Sequence alignment displays already aligned sequences; it does not perform alignment. Motif logos require actual weight/frequency information and the documented alphabet. Do not infer domains, gene models, assemblies or sequence provenance from labels.

Circular genome and signal tracks require compatible intervals and coordinate conventions; inspect each auxiliary input declared by `describe`. Validate chromosome lengths and avoid interchanging one-based closed coordinates with zero-based half-open intervals. Clonal fish plots require validated parents and inclusive clone fractions, not unrelated category percentages; the resulting geometry does not infer evolutionary history.

## Available engines

`manhattan_qq_plot`, `oncoprint_plot`, `protein_variant_plot`, `circular_genomic_plot`, `sequence_alignment_plot`, `interactive_motif_logo_plot`, `interactive_genomic_signal_track_plot`, `clonal_fish_plot`.

Use `python -m omicscanvas catalog --workflow genomics` for the current compact list. Read `python -m omicscanvas describe ENGINE` for the chosen contract, schema and Plot Guide; do not load every plugin skill. Then follow `skills/omicscanvas-render/SKILL.md` to plan, validate and render. From another working directory, use an absolute path to `scripts/omicscanvas.py` with the project's Python environment.

If the scientific question or required role remains ambiguous, report the missing information and keep the candidate set open. Do not substitute synthetic data, infer unavailable analyses, or rank visual attractiveness above scientific suitability.
