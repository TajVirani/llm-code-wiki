
**Summary**: Release 1.2.0 ships the MODULES orientation layer with Rules.md amendments, new template, deletion-test gate, and automatic topic-index restructure.
**Tags**: #release #versioning #modules
**Created**: 2026-05-06T00:00:00+00:00
**Last Updated**: 2026-05-06T00:00:00+00:00

---

## Content

Release 1.2.0 introduces the MODULES sixth canonical category. The VERSION file reads `1.2.0`. CHANGELOG.md's 1.2.0 entry enumerates the changes:

- Rules.md amendments: §2 (MODULES table row), §5 (slug grammar + cross-category collision rule), §11 (`### Modules`/`### Notes` H3 split inside topic-index), §12 (trigger 7 four-signal contract), §13 (MODULES same-concept 1-of-2 detection rule).
- New template `_templates/module.md` with the seven inner H2s the deletion-test checks.
- Curator deletion-test gate enforcing ≥5 of 7 inner H2s with `Purpose` and `Boundary` mandatory.
- Trigger 7 signal contract pre-evaluated by the wiki-digest skill body.
- New `/wiki-modules` read-only skill (synth + audit).
- Recall agent split into orienting vs narrow paths keyed off the `### Modules` H3.
- Optional inbox-update auto-handle for module entries.
- Topic-index H3 restructure performed automatically on first MODULES write.

Migration is automatic: the first MODULES write triggers the topic-index H3 restructure — no consumer action required.

## Related Notes

- [[modules-category|MODULES Category]]
- [[trigger-7-module-cluster|Trigger 7 Module Cluster]]
- [[deletion-test-gate|Deletion Test Gate]]
- [[topic-index-h3-split|Topic Index H3 Split]]
- [[wiki-modules-skill|Wiki Modules Skill]]
- [[update-flow|Update Flow]]
