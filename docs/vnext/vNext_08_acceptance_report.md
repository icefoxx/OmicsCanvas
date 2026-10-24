# vNext Final Acceptance Report

Date: 2026-08-12  
Framework version: 0.1.0

## Answers (spec §51)

1. **Is every generated figure backed by a machine-readable PlotSpec?**  
   **Not yet for all UI paths.** Figures produced via `vnext.cli render` are. Existing Gallery/Editor jobs still use flat `params.json` only.

2. **Can the same PlotSpec be reproduced without an LLM?**  
   **Yes** for the reference skill (`reproduce` / `render` after validation).

3. **Are scientific validation rules executable rather than only textual?**  
   **Yes** (global + enrichment family + lollipop skill rules in Python).

4. **Are warnings/errors machine testable?**  
   **Yes** (structured JSON; pytest covers `MISSING_SIGNED_EFFECT`).

5. **Is the exact skill and version recorded?**  
   **Yes** in PlotSpec `skill` + bundle manifest / methods text.

6. **Are input checksums recorded?**  
   **Yes** (SHA-256 in bundle).

7. **Can session restore reconstruct plot semantics?**  
   **Not yet** wired into `plot_web` session save/load (still UI/params oriented).

8. **Can a user export a reproduction bundle?**  
   **Yes** via CLI `--bundle` for migrated skills.

9. **How many skills are fully migrated?**  
   **1 / ~45**

10. **How many canonical tests exist?**  
    **4 pytest cases** + CLI roundtrip/validate; R render verified locally for OCT4.

11. **What percentage pass?**  
    **100% of `vnext/tests` (4/4)** locally.

12. **What scientific guardrails are currently implemented?**  
    Empty data; missing mapped columns; non-finite values; raw-p vs FDR labeling; enrichment category/signed-effect; bidirectional effect warning; negative size rejection; stem-to-zero warning.

13. **What reproducibility claims are justified?**  
    Validated PlotSpec → deterministic adapter → R render → bundle with hashes/methods/runtime for the reference skill.

14. **What claims are not yet justified?**  
    System-wide PlotSpec for every figure; session restore; full skill migration; CI R smoke; PlotSpec viewer in UI.

15. **Ready for formal benchmark vs direct LLM plotting?**  
    **Architecture yes for one skill; not system-wide.**

16. **What remains before SCI manuscript preparation?**  
    Migrate more families; wire Studio/Editor to PlotSpec; session/report integration; R-enabled CI; broader scientific rule library; benchmark datasets.

## Conclusion

```text
B. ARCHITECTURE READY, MIGRATION INCOMPLETE
```

Evidence: working PlotSpec + registry + scientific validator + CLI reproduce path for `interactive_enrichment_lollipop`; majority of plugins still on legacy params path; UI session not yet PlotSpec-backed.
