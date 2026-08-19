# Scientific color palettes

Local catalog for the OmicsCanvas **Theme** picker (plot editor) and AI Studio recommender.

## Sources

| Source | Role |
|--------|------|
| **builtin** | Classic ggsci-style + viridis / Brewer favorites (always offline) |
| **AMFE** | Journal / research cases from [color.amfe.space](https://color.amfe.space) |
| **lcpmgh** | Discrete palettes from [lcpmgh/colors](https://github.com/lcpmgh/colors) (MIT) — ggsci, RColorBrewer, journal cases |

## Files

| Path | Role |
|------|------|
| `unified_color_palettes.json` | **Primary** catalog used by `plot_web` (also under `plot_web/data/`) |
| `amfe_color_palettes.json` | AMFE scrape only |
| `lcpmgh_color_palettes.json` | lcpmgh scrape only |
| `../scripts/fetch_amfe_palettes.py` | Re-fetch AMFE |
| `../scripts/fetch_lcpmgh_colors.py` | Re-fetch lcpmgh CSV |
| `../scripts/build_palette_catalog.py` | Merge → unified catalog |

## Refresh

```bash
python3 scripts/fetch_amfe_palettes.py
python3 scripts/fetch_lcpmgh_colors.py
python3 scripts/build_palette_catalog.py
```

## API (plot_web)

```text
GET  /api/palettes                 # list (+ catalog/family/journal filters)
GET  /api/palettes/meta
GET  /api/palettes/journals
GET  /api/palettes/themes
GET  /api/palettes/{id}
POST /api/palettes/recommend       # {"journal":"Nature","goal":"…","n_groups":6}
```

## Editor usage

Open any plot in the Editor → **theme** tab → browse / recommend by journal → **click a palette** to apply colors and re-render.

## Attribution

- AMFE Color: [color.amfe.space](https://color.amfe.space)
- lcpmgh/colors: [github.com/lcpmgh/colors](https://github.com/lcpmgh/colors) (MIT)
- Classic ggsci-style names (NPG, Lancet, NEJM, …) for scientific figures
