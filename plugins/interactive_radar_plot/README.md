# Interactive Radar Plot

Run `Rscript plugins/interactive_radar_plot/plot.R --input input.csv --params params.json --output output_dir`.

Input can be wide (`metric,Group A,Group B,Group C`) or long (`metric,group,value`). Set column names explicitly for automation. The plugin supports stable group/metric ordering, optional min-max or z-score normalization, radial limits and breaks, named colors, polygon fills, markers, highlights, value labels, title/subtitle/caption, legend and grid controls. Static SVG/PDF/PNG output uses a manual ggplot2 radar; the HTML output uses Plotly `scatterpolar` traces with filled polygons, hover text, legend, selection, zoom/pan, and export controls.

Three examples are included. Run `plugins/interactive_radar_plot/run_all_examples.sh <repo-root>` to produce independent images and reproducible bundles under `examples/`, plus a gallery under `all_examples_gallery/`.
