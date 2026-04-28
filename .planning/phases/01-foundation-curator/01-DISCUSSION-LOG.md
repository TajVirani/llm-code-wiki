# Phase 1: Foundation + Curator - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-28
**Phase:** 01-foundation-curator
**Areas discussed:** Routing trust, Conflict policy, Backlinks, Fixture rigor

---

## Routing trust

| Option | Description | Selected |
|--------|-------------|----------|
| Hybrid override | Handle is default route; curator may override based on content; overrides surfaced in plan | ✓ |
| Trust handle | Curator routes purely by `CATEGORY::` handle. Deterministic but blind to wrong handles | |
| Always re-classify | Curator ignores handle, routes by content. Robust but disagreement with the in-session skill becomes invisible | |

**User's choice:** Hybrid override
**Notes:** Recommended option. Best of both — deterministic when handle and content agree (silent), self-correcting when they disagree (override surfaced in plan). Matches the project's preview-by-default trust model.

---

## Conflict policy

| Option | Description | Selected |
|--------|-------------|----------|
| Surface in plan / Plan lists edits, no per-note | Plan lists every change (creates AND edits); approving plan = approving all of it; no per-note re-confirmation | ✓ |
| Per-note confirmation | Each existing-note edit prompts a separate y/n even within an approved plan | |
| Silent in-place edit | Edits skip the plan entirely; only creates are previewed | |

**User's choice:** Plan lists edits, no per-note
**Notes:** Initial selection ("Silent in-place edit") was disambiguated — the user meant "edits appear in the plan but get no extra ceremony beyond plan approval," which is the same as the recommended option. Confirmed in a follow-up question. Treats DIGS-03's plan-level preview as authorization for everything in the plan.

---

## Backlinks

| Option | Description | Selected |
|--------|-------------|----------|
| Hub-note (Recommended) | Per Rules.md §8 — old note's body becomes a one-line `→ see [[New]]` pointer tagged `#deprecated`; backlinks resolve via the stub | |
| Auto-rewrite | Curator greps the wiki and rewrites all `[[OldTitle]]` occurrences in place | ✓ |
| Surface manually | Curator lists affected backlinks; user fixes by hand | |

**User's choice:** Auto-rewrite
**Notes:** User chose the rigorous-end-state option over the convention-aligned default. Implication captured in CONTEXT.md D-05 / D-06: for splits, the curator must pick the split target per backlink based on surrounding context (sentence + heading). Aliased links `[[OldTitle|alias]]` preserve the alias (D-07). Post-write link-validation (DIGS-11) acts as a safety net for any rewrites the curator missed.

---

## Fixture rigor

| Option | Description | Selected |
|--------|-------------|----------|
| Core cases (Recommended) | Happy path + 1+1-deleted only | |
| Happy path only | 5–10 entries that map cleanly; defer 1+1 validation to Phase 2 | |
| Full coverage | Happy + 1+1-deleted + ambiguous categorization + existing-note conflict + split-implication | ✓ |

**User's choice:** Full coverage
**Notes:** User chose maximum Phase 1 validation rigor. Each fixture sub-case validates a specific Phase 1 decision: 1+1-deleted validates CAPT-04 (release blocker) inside Phase 1 instead of Phase 2; ambiguous categorization exercises D-01 (Hybrid override); existing-note conflict exercises D-03 + D-04; split-implication exercises D-05 + D-06. Implication: fixture must reference real notes from the existing Traxalytics sample wiki for the conflict case to be testable.

---

## Claude's Discretion

The user explicitly deferred to the planner on:
- Curator prompt structure (sections, ordering, examples) — informed by decisions but not specified
- Internal representation of the routing plan
- Exact fixture filenames (within `tests/fixtures/` convention)
- Plan rendering format (markdown table vs checklist vs prose)
- File-existence detection mechanism (Read vs Glob — both work)

## Deferred Ideas

- **Per-feature digest scope** (DIFF-02, v2) — surfaced when discussing fixture rigor; deferred to v2
- **`why:` rationale field** (DIFF-01, v2) — curator will preserve if present, but Phase 1 doesn't require it
- **Concurrent-session safety / inbox locking** (HARD-01, Phase 5) — Phase 1 assumes single-session
- **`inbox/last-digest.md` audit artifact** (DIFF-04, v2) — Phase 1's dry-run plan can be archived but isn't a separate audit file
