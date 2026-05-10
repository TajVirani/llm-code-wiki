
**Summary**: Release 1.3.0 ships the modules-ownership refactor (ADR 0001), parallel `module-author` dispatch, `/design-pattern-doc` skill, and the awk skill-injection fix.
**Tags**: #release #versioning #modules #adr-0001
**Created**: 2026-05-09T00:00:00+00:00
**Last Updated**: 2026-05-09T00:00:00+00:00

---

## Content

Repo version is bumped to `1.3.0` (from `1.2.0`) in commit `f23a14a` — a merge of `4e21ece` ("Fixes to Modules logic") into HEAD. Follow-up commit `79b2074` tracks the `wiki-code-crawler` skill, updates `dist-manifest.txt` with all three 1.3.0 components, and tightens `.gitignore`.

### What 1.3.0 captures

- **Modules-ownership refactor (ADR 0001).** `/wiki-modules` is the sole writer to `wiki/MODULES/`. The curator no longer authors module notes; trigger-7 pre-evaluation has been removed from `/wiki-digest`. `@ MODULES::` session-inbox handles surface as `MODULES-VIA-DIGEST-DEPRECATED` plan rows — informational only.
- **Cluster-detection signals rebased.** The four-signal trigger-7 contract is replaced by three deterministic signals owned by `/wiki-modules`: S1 filename prefix (≥3 detail notes), S2 single-dominant-tag intersection across all members, S3 external fan-in (≥1 outside note linking to ≥2 distinct cluster members).
- **New `module-author` subagent** dispatched in parallel by `/wiki-modules` (one per qualifying cluster), with pre-author depth gate and post-author content gate.
- **New `/design-pattern-doc` skill** for authoring pattern documentation (separate intake path from session-inbox and research-doc ingestion).
- **Skill `!`-injection `$N` expansion fix.** All cluster-detection bash uses `cut`/`sed` + `while read` instead of `awk`, because the skill `!`-injection layer expands `$N` references in awk scripts to empty strings before the shell sees them. See [[skill-bash-injection-dollar-n-expansion|Skill Bash Injection $N Expansion]].

### CHANGELOG and migration

`CHANGELOG.md`'s `[1.3.0] — 2026-05-09` section enumerates Added / Changed / Fixed entries. **No manual migration is required** — the curator's deprecation-routing of `@ MODULES::` handles is automatic; existing MODULES notes survive untouched until the next `/wiki-modules` run, which re-authors them from current cluster signals.

The pre-existing `wiki/ARCHITECTURE/trigger-7-module-cluster.md` note now describes a removed mechanism. Per Rules.md §8 it should be deprecated with a pointer to this release note rather than deleted; the curator surfaces this as a RULES-PROPOSAL rather than auto-rewriting it.

## Related Notes

- [[modules-category|MODULES Category]]
- [[wiki-modules-skill|Wiki Modules Skill]]
- [[wiki-digest-skill|Wiki Digest Skill]]
- [[wiki-code-crawler-skill|Wiki Code Crawler Skill]]
- [[skill-bash-injection-dollar-n-expansion|Skill Bash Injection $N Expansion]]
- [[update-flow|Update Flow]]
- [[version-1-2-0-release|Version 1.2.0 Release]]
