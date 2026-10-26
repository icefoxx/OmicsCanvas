# Portable layered plotting skills and executable CLI

Date: 2026-10-26. Implementation is repository-local and provider-neutral. No external AI service was invoked or configured.

## Delivered architecture

- **L0**: `skills/omicscanvas-router/SKILL.md` retrieves the compact live catalog, selects relevant scenario guidance and asks for missing scientific information. It coordinates one assistant and does not automatically spawn agents.
- **L1**: nine scenario skills: clinical outcomes, single-cell annotation, differential/enrichment results, expression matrices, relationships/overlap, genomics, spatial data, composition/hierarchies and general distribution/comparison tasks. Membership is curated in `skills/omicscanvas-router/workflows.yaml`; engines can belong to several scenarios.
- **L2**: `skills/omicscanvas-render/SKILL.md` executes a selected contract. `describe ENGINE` exposes the existing schema/config/Plot Guide and links the README. There is no duplicated per-engine skill body or generated registry maintained by hand.
- Existing `specialty-plot-workflows` points to the new leader while remaining available as a specialty reference. Existing plugin authoring instructions remain authoritative for source changes.

The eleven new skill folders use Markdown, YAML frontmatter and shell/JSON examples. They do not depend on a provider SDK, MCP server, native slash command, model credential or running web server. Host assistants must have local file-reading and shell access to execute them. Claude/Grok/OpenCode/Codex native discovery and model behavior were not separately exercised; the explicit skill-file workflow and the local CLI are the supported common interface. No global host configuration was changed.

## CLI implementation

`python -m omicscanvas` and the absolute-path launcher `scripts/omicscanvas.py` support:

| Command | Purpose |
|---|---|
| `doctor` | Runtime and catalog availability; no installation |
| `skills`, `workflows`, `catalog` | Progressive discovery of skills and all 80 engine records |
| `describe ENGINE` | Actual input fields/flags, schema, examples and Plot Guide |
| `profile FILE` | Headers, complete row count and preview |
| `recommend --goal ... --input ...` | Local heuristic candidate retrieval; no model/network call |
| `plan --plugin ...` | Explicit inputs/example, flat JSON params and repeated typed `--set` overrides |
| `validate --plan ...` | Input checksum, contract, parameter, column and vNext validation |
| `render --plan ...` | Full-input snapshots, shared R command builder and existing deterministic adapter |
| `reproduce --bundle-dir ... --compare` | Existing vNext bundle reproduction and pixel comparison |

Plans record input identity/checksums, source mode, semantic PlotSpec, selected scenario membership and validation. `--goal` records intent; actual modes must be parameters. Inputs and synthetic bundles cannot be mixed. Unknown fields/parameters, invalid types/ranges, absent required auxiliary inputs and changed input bytes stop execution. Output directories must be new or empty. Engine-specific scientific errors remain failures and are never replaced by synthetic results.

The CLI records resolved params, PlotSpec, validation, result images, logs, a JSON result and optional reproduction bundle. Direct engine argument arrays and a small explicit seed/runtime environment are saved separately; the caller's complete environment and secrets are not serialized. The executable engines remain R; Python is the common orchestration and validation interface.

Legacy compatibility is explicit: authored JSON arrays retain their real array types rather than the UI normalizer's string-array conversion; the old array-valued `hlines` object/default contract is exposed as an array with a compatibility note. Canonical `input`/`annot` aliases are resolved to declared primary/annotation fields, with the explicit annotation field retaining precedence as in the shared command builder. Alias decisions are recorded in plans. No plugin source, schema, metadata or image baseline was changed.

## Acceptance evidence

| Check | Result |
|---|---|
| New skill structure/frontmatter validation | 11/11 passed; the edited existing specialty skill also passed |
| Workflow membership | All 80 engine IDs are covered; all skill paths exist |
| Canonical plan preflight | 80/80 selected examples valid; this is not a claim that all engines rendered |
| Initial full Python suite | 214 passed, one existing Starlette/httpx deprecation warning |
| Final full suite | **215 passed**, one existing deprecation warning; includes the final renderer-failure regression |
| Shared plugin standards | 80 checked; 0 new violations; 1,571 historical baselined violations |
| Studio registry | Valid, 0 errors; 33 existing warnings |
| vNext registry | Valid, 80 skills, 0 errors/warnings |
| Image regression for four exercised engines | 12/12 passed; no baseline updated |
| Scalar sensitivity for those engines | 83 perturbations, 0 crashes; 5 expected mode-conditional no-effect observations |
| Conditional sensitivity via the new CLI | All 5 visibly change their output in the appropriate mode: calibration bins/points, decision thresholds and linked-matrix dot size |
| Full-data R execution | Survival (12 supplied observations, 6 per cohort), calibration (160 observations), 3D (225 coordinates), linked matrix/network (all declared inputs) |
| Direct R replay | Exit 0; pixel-identical PNG with the recorded runtime/seed environment |
| Reproduction bundle replay | Input/spec/params matched; exit 0; pixel-identical PNG |
| Different caller working directory | Absolute launcher works from an unrelated temporary directory |
| Source protection / failures | Tests cover input mutation, invalid columns/parameters, required auxiliary tables, mixed examples/uploads, reused output directories and renderer scientific failure |
| Visual review | All four retained CLI PNGs and all four PDF exports visually inspected; labels/legends fit and layouts agree |

- [80-engine preflight results](portable_cli_catalog_coverage_2026-10-26.json)
- [Actual shell CLI runs](portable_cli_demo_runs_2026-10-26.json)
- [Direct R and bundle reproduction](portable_cli_reproduction_2026-10-26.json)
- [Conditional parameter checks](portable_cli_mode_checks_2026-10-26.json)
- [Machine-readable gates](portable_cli_gates_2026-10-26.json)

Retained demonstration outputs are under `plot_web/storage/cli_examples/2026-10-26/` (ignored local output, not plugin baselines). The named survival figure uses the repository's synthetic 12-row fixture. Other retained cases are explicitly selected synthetic example bundles. Both PNG and PDF exports were inspected; scientific sample sizes were checked against `figure.json` and relevant count tables. A smaller number of drawn curve records is not statistical input subsampling.

## Practical usage and limits

See [the runnable CLI guide](../cli/README.md) for direct commands, user-data mappings, named colors, multiple inputs and the universal assistant prompt. Begin with the router skill's explicit file path in the selected assistant; its native skill installation can be configured separately.

The CLI does not train models, infer missing results, guarantee correct study design or translate arbitrary natural language directly into an approved analysis. Recommendation is a candidate shortlist. Validate the chosen workflow and inspect output. Existing renderer/package failures and historical image differences elsewhere in the library were not repaired by this CLI work. The full historical image suite was not rerun because no shared renderer/web code changed; selected actual R runs and all Python tests cover the new path. No external-provider or native-host integration success is claimed.
