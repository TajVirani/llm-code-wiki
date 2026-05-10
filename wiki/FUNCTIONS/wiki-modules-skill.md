
**Summary**: `/wiki-modules` is the sole writer to `wiki/MODULES/` (ADR 0001) — detects clusters via three deterministic signals and dispatches `module-author` subagents in parallel.
**Tags**: #function #skill #wiki #modules #adr-0001
**Created**: 2026-05-06T00:00:00+00:00
**Last Updated**: 2026-05-09T00:00:00+00:00

---

## Content

`/wiki-modules` is the only writer to `wiki/MODULES/` per [ADR 0001](../../docs/adr/0001-modules-ownership-and-detection.md). The curator no longer authors module notes; trigger-7 pre-evaluation has been removed from `/wiki-digest`. The skill both writes and audits in one pass.

### Cluster detection — three deterministic signals

Every signal must hold for a candidate cluster to qualify. No LLM judgment is used in detection.

- **S1 — filename prefix:** ≥3 detail notes share a kebab-case prefix (bootstrap signal — covers freshly seeded wikis where link graphs are still sparse).
- **S2 — single-dominant-tag intersection:** every member of the cluster shares at least one common tag (the "dominant tag"). A cluster that fails S2 is not topically cohesive.
- **S3 — external fan-in:** ≥1 note OUTSIDE the cluster links to ≥2 distinct cluster members. This rules out internal-only echo chambers.

### Parallel `module-author` dispatch

For each qualifying cluster, the skill dispatches one `module-author` Task subagent in parallel. Each subagent runs:

- **Pre-author depth gate:** ≥3 children, sufficient combined word count, ≥2 distinct non-dominant tags, ≥1 trigger-bearing child. Failure aborts the write.
- **Post-author content gate:** Purpose ≥50 words, Boundary lists ≥2 OUT items, Children ≥3 entries spanning ≥2 categories. Failure surfaces as a structured rejection — the file is not written.

On success, the subagent writes `wiki/MODULES/<slug>.md` AND the `### Modules` row in `wiki/topic-index.md`.

### Audit pass

A single run audits every existing module for cluster-still-qualifies, broken child links, deprecated children, and unlinked candidate notes. Output is a structured report.

### Implementation note — no awk

All cluster-detection bash uses `cut`/`sed` plus a `while read` loop instead of `awk`. Claude Code's skill `!`-injection layer expands `$N` references in awk scripts to empty strings before the shell sees them — see [[skill-bash-injection-dollar-n-expansion|Skill Bash Injection $N Expansion]]. An inline implementation comment in the skill body warns future edits not to re-introduce awk.

## Related Notes

- [[modules-category|MODULES Category]]
- [[skill-bash-injection-dollar-n-expansion|Skill Bash Injection $N Expansion]]
- [[wiki-curator-agent|Wiki Curator Agent]]
- [[version-1-3-0-release|Version 1.3.0 Release]]
