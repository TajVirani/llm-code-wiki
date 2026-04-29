# Phase 1 Fixture Inbox

**Path**: `tests/fixtures/_session-fixture.md`
**NOT** to be confused with `wiki/inbox/_session.md` (live session state, owned by Phase 2 — see D-10, D-11).

## Sub-cases exercised

| Sub-case | Slug(s) | What it validates | Acceptance |
|----------|---------|-------------------|------------|
| 1. Happy path | caching-layer-overview, compute-replacement-level, age-curve-derivation, session-summary-2026-04-28, vorp-calculation-flow | Routing into 5 canonical categories (DIGS-04) | ≥80% land in correct category folder |
| 2. 1+1-then-deleted (CAPT-04) | (intentionally absent: would-have-been `legacy-helper-removed`) | Curator does not invent entries from absence | 0 filed notes for any slug not in the fixture |
| 3. Ambiguous categorization | auth-boundary-policy | Hybrid override (D-01) — handle says FUNCTIONS, content reads as ARCHITECTURE | Plan surfaces the override; routes to ARCHITECTURE |
| 4. Existing-note conflict | vorp-batch-processing | Same-concept detection (D-04, DIGS-09) | Plan reports EDIT not CREATE for `wiki/FUNCTIONS/vorp-batch-processing.md`; `Last Updated` bumped |
| 5. Split-implication | vorp-batch-processing | 1,000-word split logic + auto-rewrite (DIGS-08, D-05, D-06) | Plan reports split into 3+ notes; backlinks rewritten per surrounding context |

## Acceptance criteria (Phase 1 gate, from CONTEXT.md + ROADMAP.md success criteria)

- [ ] ≥80% of fixture entries land in correct category folder
- [ ] 0 Rules.md violations (filename regex `^[a-z0-9][a-z0-9-]*\.md$`, ≤25-word summary, all template fields present, wiki-link syntax `[[Title]]`)
- [ ] Sub-case 2: digest produces zero filed notes for any slug absent from the fixture (CAPT-04 release blocker validated in Phase 1)
- [ ] Idempotence (DIGS-12): a second digest run on a fresh post-archive empty inbox produces zero changes
- [ ] Archive-before-write (LIFE-02, LIFE-03): a simulated mid-write crash leaves entries recoverable from `wiki/inbox/_archive/<timestamp>-session.md`
- [ ] Aliased links `[[Old|alias]]` rewritten as `[[New|alias]]` (D-07) — verify by introducing one before split test
- [ ] Curator never modifies `wiki/Rules.md` (D-16, DIGS-13)

## How Plan 04 uses this

Plan 04 copies `_session-fixture.md` to `wiki/inbox/_session.md`, runs `/digest`, and verifies the criteria above against the resulting plan + filed notes + archive.

## Why this is in `tests/fixtures/` not `wiki/inbox/`

Per D-10: `wiki/inbox/_session.md` is reserved for live session state. The fixture is checked-in test corpus that must not be mutated by ordinary digest runs.
