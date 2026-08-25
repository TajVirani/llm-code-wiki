---
name: deps-audit
description: Audit this repo's bun dependencies for health — outdated versions, cross-workspace version drift, security advisories, and per-package upgrade feasibility — and produce a prioritized report. Read-only; it recommends, it does not mutate. Use when asked to audit dependencies, check dependency health, find outdated/vulnerable/drifting packages, plan an upgrade sweep, or answer "how far behind are our deps / what should we bump first".
---

# Dependency audit (bun)

The read-only companion to **deps-update**. That skill *performs and validates* one update; this one
*surveys the whole tree* and hands back a ranked plan. **Never mutate here** — no `bun update`, no manifest
edits, no `bun install`. Output is a report; acting on it is a `deps-update` run on its own branch.

This is a **bun** monorepo. All commands run from repo root. Skip debris workspaces (`apps/agentic-tests/*`,
`apps/aircraft-service-*` benchmark variants) — they are not real (see athena-build-and-env).

## What to gather

1. **Outdated** — `bun outdated --filter='*'` (bare `bun outdated` is root-only and hides stale workspace
   copies). Capture current → update → latest and the owning workspace for each.
2. **Drift** — `bun .claude/skills/deps-update/scripts/drift.ts` — deps declared in ≥2 real workspaces, with
   `← DRIFT` on version mismatches. Each drifting dep is a bug risk **and** a catalog candidate.
3. **Security** — `bun audit --audit-level=moderate` (add `--json` to parse). Advisories outrank freshness:
   a vulnerable dep is a "now", however boring the bump.
4. **Tier** — classify each outdated dep by blast radius using the **deps-update scale** (Tier 0 tooling →
   Tier 3 AI behavior). Tier = how much regression proof a bump will cost.
5. **Feasibility** — for anything past a patch, read the changelog: `bun info <pkg> repository` → GitHub
   `/releases` or `CHANGELOG.md`; `bun info <pkg> versions` for the span. Rate effort **trivial / moderate /
   breaking** (definitions in deps-update step 4). Note required codemods, peer-dep bumps, dropped runtime
   support.

## The report

Rank by **risk-to-fix ratio**, most actionable first. Group into:

- **Security — do now**: advisories from `bun audit`, with the fixed version and its tier/effort.
- **Free wins**: trivial-effort, Tier 0–1 patches/minors. Batch these in one `deps-update` pass.
- **Needs a migration branch**: breaking-effort or Tier 2–3 bumps — one per MR, changelog link + a one-line
  migration summary each.
- **Drift / catalog candidates**: every `← DRIFT` dep, with the ranges seen and the version to converge on.
  Recommend the catalog migration (deps-update "Catalogs") when the list is more than a handful.
- **Deferred**: majors held back by `minimumReleaseAge`, or pinned-on-purpose deps — say why.

For each row: package · workspace(s) · current → target · tier · effort · security? · changelog link ·
one-line recommendation. End with a suggested **order of operations** (security → free-wins batch → each
migration branch) and hand off to `deps-update` for execution. Flag anything landing in a coverage gap
(§8 of athena-validation-and-qa) so the reader knows a driven check is the only proof that bump is safe.

## Quick reference

```bash
bun outdated --filter='*'                               # outdated, all workspaces
bun .claude/skills/deps-update/scripts/drift.ts         # cross-workspace drift + catalog candidates
bun audit --audit-level=moderate                        # security advisories (--json to parse)
bun info <pkg> repository ; bun info <pkg> versions     # feasibility: changelog source + version span
```
