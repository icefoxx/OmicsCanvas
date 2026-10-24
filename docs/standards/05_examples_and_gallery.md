# 05 — Examples and gallery

Examples are the plugin's documentation, its regression tests, its gallery cards and the
PlotSpec reproduction benchmark at once.

## Bundle layout

```text
examples/
  index.json                      list of bundles, in gallery order
  <example_id>/
    manifest.json                 id, label, plugin_id, params, inputs, expected, reproduce.command
    params.json                   only the parameters that differ from defaults, plus the mapping
    input/<files>                 small input files (copied, never linked outside the bundle)
    expected/result.png           baseline written by smoke_plugins.py --update-baseline
```

`manifest.json` (template: `templates/plugin/examples/basic/manifest.json`):

```json
{
  "id": "basic",
  "label": "Basic",
  "plugin_id": "my_plot",
  "params": "params.json",
  "inputs": {"input": "input/example_input.csv"},
  "expected": "expected/result.png",
  "reproduce": {"command": "Rscript plugins/my_plot/plot.R --input plugins/my_plot/examples/basic/input/example_input.csv --params plugins/my_plot/examples/basic/params.json --output /tmp/my_plot_basic"}
}
```

`inputs` keys are the input ids from `config.yaml`. `index.json` repeats each bundle's `id`,
`label`, `params`, `inputs`, `expected` (paths relative to `examples/`).

## Which examples

- `basic`: default parameters, typical data — the card users see first.
- One example per major mode (`plot_type`, `input_mode`, facetting, interactive) and one that
  exercises styling (`custom` / `custom_layout`).
- Every example the registry references (`representative_example`) must exist.
- Inputs are small (aim < 1 MB per bundle), synthetic or openly licensed, with realistic column
  names and value ranges. No patient identifiers.

## Naming and text

- Example ids: snake_case, descriptive (`split_highlight`, `dot_summary`).
- Titles describe the content ("Activated and suppressed pathways"), not the tool.
- **No third-party product names** (plotting websites, commercial tools) and **no placeholder
  text** ("Hello world", personal names) in ids, titles, legends, file names or images — rule E003.
- Demos reproducing an external reference figure use the id `CAB_demo` (or `CAB_demo_<n>`) and the
  title/legend text `CAB_demo`.
- Text in example images must be readable: no clipped or overlapping titles, labels or legends.

## Baselines

```bash
python scripts/smoke_plugins.py my_plot --update-baseline   # writes expected/result.png
python scripts/smoke_plugins.py my_plot --compare           # must pass afterwards, twice in a row
```

Update a baseline only after looking at the new image and confirming that the change is intended.
`--update-baseline` rewrites only examples whose image changed. Rendering must be deterministic:
two consecutive `--compare` runs pass (ragg PNG device, seeded RNG — 03).

## Gallery images

```bash
python scripts/sync_gallery.py my_plot            # per-example images (+ montage if one exists)
python scripts/sync_gallery.py my_plot --montage  # also create <plugin>_gallery.png
```

`all_examples_gallery/<example_id>.png` is what the UI shows for each example; it is a copy of
`expected/result.png`. Run `sync_gallery.py` whenever a baseline changes.
