# vNext Phase 5 — Testing + CI

## Local

```bash
pip install -r vnext/requirements.txt
python -m vnext.cli registry build
pytest -q vnext/tests
```

## CI

`.github/workflows/vnext.yml` runs on changes to `vnext/**` and the reference skill’s `vnext/**`:

- registry build
- pytest
- PlotSpec roundtrip
- OCT4 validate

## Coverage (current)

| Area | Status |
|------|--------|
| Schema round-trip | covered |
| Registry integrity | covered |
| Scientific negative test | covered |
| Full pipeline validate | covered |
| R render smoke | manual CLI (needs R on runner; not yet in GHA) |

**Note:** GitHub Actions does not yet install R; render/reproduce remain local gates until an R-enabled runner is added.
