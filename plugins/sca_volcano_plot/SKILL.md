# SCA Volcano Plot

Use `plot_kind: volcano` for custom regions and point groups. Region definitions can be JSON in `region_annotations` or CSV/TSV via `region_annotations_file`; relative files resolve from the params file directory first. Coordinates accept numbers, `-threshold`, `threshold`, `x_min`, `x_max`, `y_min`, `y_max`, `-Inf`, `Inf`, and `threshold_y`.

`avg_volcano` and `percent_volcano` remain on the SCA reference renderer. Volcano point-group colors take precedence over ordinary gradient/DE rendering, and region rectangles are drawn before points by default.

Run `plugins/sca_volcano_plot/run_all_examples.sh /Users/qzhang10/Documents/OmicsCanvas` to regenerate bundles and gallery assets. A successful run must produce SVG, PDF, PNG, figure metadata, and the run log.
