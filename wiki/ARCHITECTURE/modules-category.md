
**Summary**: MODULES is the sixth canonical category — orienting cluster summaries (~6–10 per project) linking down to detail notes.
**Tags**: #wiki #modules #orientation #architecture
**Created**: 2026-05-06T00:00:00+00:00
**Last Updated**: 2026-05-06T00:00:00+00:00

---

## Content

MODULES is the sixth canonical category defined in Rules.md §2. It holds roughly 6–10 cluster summaries per project — orienting overviews of capability areas that span multiple subsystems. Each MODULES note links down to ARCHITECTURE, FUNCTIONS, RESEARCH, or DIAGRAMS detail notes via H4 `#### From <CATEGORY>` sub-headings inside the body.

**Slug grammar (Rules.md §5):** MODULES slugs are bare single-concept kebab identifiers — `scheduling`, not `scheduler-overview`. Detail-note children in other categories carry kebab prefixes derived from the module slug or otherwise topical (for example `scheduler-jobs-pg-boss`).

**Same-concept detection (Rules.md §13):** MODULES uses a 1-of-2 rule (filename match + title match). Tag overlap is dropped because parent and child notes structurally share tags — counting it as a duplicate signal would generate false positives. The standard 2-of-3 rule (filename + title + tags) continues to apply to ARCHITECTURE, FUNCTIONS, RESEARCH, SELF, and DIAGRAMS.

**Cross-category slug collisions:** If a MODULES slug exactly equals an existing basename under any other category folder (`wiki/{ARCHITECTURE,FUNCTIONS,RESEARCH,SELF,DIAGRAMS}/**/<slug>.md`), the curator emits a `SLUG-COLLISION` plan row. The user decides whether to rename or merge; the curator never auto-routes through a collision.

**Gating:** A MODULES note is shallow if its children alone would orient a newcomer to the cluster. Shallow modules fail the deletion-test gate (≥5 of 7 inner H2s present) and convert to surface-only `SHALLOW-MODULE` plan rows excluded from plan-level approval.

## Related Notes

- [[trigger-7-module-cluster|Trigger 7 Module Cluster]]
- [[deletion-test-gate|Deletion Test Gate]]
- [[topic-index-h3-split|Topic Index H3 Split]]
- [[wiki-modules-skill|Wiki Modules Skill]]
- [[version-1-2-0-release|Version 1.2.0 Release]]
