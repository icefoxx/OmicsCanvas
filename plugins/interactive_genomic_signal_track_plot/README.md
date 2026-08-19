# Interactive Genomic Signal Track Plot

Run `Rscript plugins/interactive_genomic_signal_track_plot/plot.R --signal signal.csv --params params.json --output output_dir`.

Signal is long CSV (`track,position,value`) with optional chromosome/sample/dataset columns. Expression is optional long CSV (`track,value` or `track,expression`); features use `start,end,label,type,strand`. Static output is a shared genomic-axis stack with left row labels and an aligned right expression panel. HTML uses Plotly traces with track, position, signal, and expression hover values when Plotly is installed.

Three deterministic examples are included. `run_all_examples.sh` renders them and creates portable bundles using the shared gallery helper.
