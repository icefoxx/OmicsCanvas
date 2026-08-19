# ComplexUpset-Inspired Feature Mapping

- Basic intersections map to exclusive intersection counts and a deterministic dot/segment matrix.
- `min_size`, `max_size`, `min_degree`, `max_degree`, and `n_intersections` filter the exported intersection table before drawing.
- `mode` implements exclusive/inclusive intersection and union semantics.
- `intersections=all` enumerates combinations, bounded by degree filters and `n_intersections`.
- Numeric annotations use box, violin, jitter, or point summaries; categorical annotations use stacked or filled bars.
- Queries accept `set` or `intersect` plus color/fill and are reflected in intersection bars.
- Set ordering, sorting, explicit intersection order, ratio panels, labels, colors, and theme controls are deterministic.

## Limitations

The native fallback does not call ComplexUpset and therefore does not reproduce every ComplexUpset ggplot extension. Grouping preserves or repeats requested ordering rather than constructing separate repeated group strips. Plotly HTML is a composed summary view rather than a full linked brushing implementation; static output and CSV exports remain authoritative. Package absence is handled without installation prompts.
