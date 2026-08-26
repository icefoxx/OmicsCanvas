# vNext Phase 4 — Provenance + Reproduction

## Bundle contents (`reproduction_bundle/`)

| Artifact | Purpose |
|----------|---------|
| `plotspec.json` | machine-readable specification |
| `manifest.json` | hashes + file index |
| `input/` | copied table + checksum |
| `methods.txt` | template methods from PlotSpec (not LLM-invented) |
| `runtime.json` | Python/R/platform versions |
| `validation.json` | structured errors/warnings |
| `figures/` | svg/pdf/png/html when render succeeds |
| `REPRODUCE.md` | CLI instructions |

## Commands

```bash
python3 -m vnext.cli render --spec ... --input ... --output OUT --bundle
python3 -m vnext.cli reproduce --bundle-dir OUT/reproduction_bundle --output OUT2
```

## Hashes

- Input SHA-256
- PlotSpec hash (canonical JSON, excluding volatile `created_at` / embedded hash)
