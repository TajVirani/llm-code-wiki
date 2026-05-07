
**Summary**: Read-only `/wiki-modules` skill that proposes MODULES notes for clusters lacking one and audits existing modules deterministically.
**Tags**: #skill #modules #audit
**Created**: 2026-05-06T00:00:00+00:00
**Last Updated**: 2026-05-06T00:00:00+00:00

---

## Content

`/wiki-modules` is a read-only slash command — it never writes to the wiki. It emits two sections in a single run:

**Synth section** — proposes MODULES notes for clusters lacking one, using three deterministic signals:

- **S1 filename-prefix grouping:** clusters of ≥3 notes sharing a kebab-case prefix.
- **S2 tag-overlap cohesion:** the cluster's mode-tag and any misfit members whose tags diverge from the cluster's dominant tag set.
- **S3 link-graph density:** intra-cluster `[[wiki-link]]` edge count, surfacing tightly-connected groups even when filenames differ.

**Audit section** — checks every existing MODULES note for:

- Broken children (referenced detail notes that no longer exist).
- Deprecated links (children tagged `#deprecated`).
- Unlinked cluster candidates (detail notes that look like they belong but the module doesn't reference them).
- Scope drift (children whose tags no longer overlap with the module's dominant tag set).

Both sections emit in one run. The skill makes no writes and asks no interactive prompts — its output is a report the user reviews and acts on manually (or feeds into a follow-up `/wiki-digest`).

## Related Notes

- [[modules-category|MODULES Category]]
- [[trigger-7-module-cluster|Trigger 7 Module Cluster]]
- [[deletion-test-gate|Deletion Test Gate]]
- [[wiki-curator-agent|Wiki Curator Agent]]
- [[version-1-2-0-release|Version 1.2.0 Release]]
