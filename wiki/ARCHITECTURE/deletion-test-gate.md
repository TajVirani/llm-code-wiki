
**Summary**: Curator Step 5a gate for MODULES routes — body must satisfy ≥5 of 7 inner H2s with `Purpose` and `Boundary` mandatory.
**Tags**: #curator #modules #validation
**Created**: 2026-05-06T00:00:00+00:00
**Last Updated**: 2026-05-06T00:00:00+00:00

---

## Content

The curator's Step 5a deletion-test gate evaluates every CREATE or EDIT row routed to MODULES against the inner H2 skeleton of `_templates/module.md`. The gate is the curator's last line of defense against shallow MODULES notes — overviews whose children alone would orient a newcomer.

**Threshold.** The body must satisfy ≥5 of 7 H2s, with two mandatory anchors and a 3-of-5 floor on the remainder:

- **Mandatory:** `Purpose` AND `Boundary`.
- **At least 3 of:** `Triggers`, `Storage`, `Behavior`, `Rules & Invariants`, `Children`.

**"Satisfies" definition.** A heading satisfies the gate when both conditions hold: (1) the heading is present in the body, and (2) at least one non-placeholder content line exists beneath it. Boilerplate template text (e.g., "describe the module's purpose here") does not count.

**Failure handling.** Failures convert the row to a surface-only `SHALLOW-MODULE` plan row. SHALLOW-MODULE rows are explicitly excluded from D-03 plan-level approval — the user must address them individually rather than rubber-stamping them through a global plan accept.

**Tunability.** The 5-of-7 threshold lives in the curator prompt, not in Rules.md. It can be tuned without amending the rule contract — the rule defers to the curator on the threshold's exact value, only requiring that *some* gate exists.

## Related Notes

- [[modules-category|MODULES Category]]
- [[trigger-7-module-cluster|Trigger 7 Module Cluster]]
- [[wiki-curator-agent|Wiki Curator Agent]]
- [[version-1-2-0-release|Version 1.2.0 Release]]
