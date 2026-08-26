# OmicsCanvas vNext

Skill-constrained, reproducible visualization framework.

```text
User / AI intent
    → PlotSpec (constrained)
    → schema + registry + scientific validation
    → deterministic adapter → R renderer
    → figure + provenance bundle
```

## Quick start

```bash
pip install -r vnext/requirements.txt
python -m vnext.cli registry build
python -m vnext.cli validate \
  --spec plugins/interactive_enrichment_lollipop/vnext/examples/oct4_expected_spec.json \
  --input plugins/interactive_enrichment_lollipop/examples/oct4_enrichment/input/example_input.csv
python -m vnext.cli render \
  --spec plugins/interactive_enrichment_lollipop/vnext/examples/oct4_expected_spec.json \
  --input plugins/interactive_enrichment_lollipop/examples/oct4_enrichment/input/example_input.csv \
  --output /tmp/vnext_out --bundle
```

## Design rule

The LLM may populate a PlotSpec. After validation it must not control rendering logic or scientific repairs.
