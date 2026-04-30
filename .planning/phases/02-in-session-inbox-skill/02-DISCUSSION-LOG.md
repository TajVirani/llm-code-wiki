# Phase 2: In-Session Inbox Skill - Discussion Log

> **Audit trail only.** Decisions are captured in CONTEXT.md.

**Date:** 2026-04-29
**Phase:** 02-in-session-inbox-skill
**Areas discussed:** Diff-pass protocol, Pruning trigger, Notable Detours

---

## Diff-pass protocol

| Option | Description | Selected |
|--------|-------------|----------|
| Scratch-list + reconcile (Recommended) | Claude enumerates touched files from its own turn-context, then reconciles entry-by-touched-thing | ✓ |
| Full re-read | Claude reads the whole inbox each turn and reasons about each entry vs current code | |
| Git diff scoped | Claude uses git diff to scope changes; updates only entries touching diffed files | |

**User's choice:** Scratch-list + reconcile
**Notes:** Aligned with CAPT-05 (cheap prompt) and CAPT-06 (evidence grounding) — the scratch list IS the evidence. Cost is O(things-touched-this-turn), naturally bounded by what Claude actually did.

---

## Pruning trigger

| Option | Description | Selected |
|--------|-------------|----------|
| Self-pruning only (Recommended) | Prune only entries whose targets Claude itself deleted/superseded this turn | |
| Every turn (full sweep) | Scan all inbox entries against codebase each turn | |
| Hybrid (cheap default + opportunistic sweep) | Self-pruning every turn + full sweep at soft-cap or pre-digest | ✓ |

**User's choice:** Hybrid
**Notes:** Most turns pay the cheap O(scratch-list) cost; opportunistic full sweep catches out-of-band drift when triggered. CAPT-04 release blocker is in the cheap path (1+1-deleted is self-pruning by definition). Out-of-band reconciliation lives in HARD-03 (Phase 5).

---

## Notable Detours

| Option | Description | Selected |
|--------|-------------|----------|
| Not in the inbox (Recommended) | Git log + commit messages cover tried-and-abandoned approaches | ✓ |
| Inbox sub-section | Add `## Notable Detours` to `_session.md` | |
| `DECISION::` handle category | First-class entries; would require new Rules.md category | |
| Separate inbox file | `wiki/inbox/_detours.md` sibling | |

**User's choice:** Not in the inbox
**Notes:** Keeps the inbox pure state-of-world per the locked PROJECT.md core decision and anti-feature A8 (chronological log breaks self-pruning). Phase 2's skill prompt stays simple — single section structure. Detour reasoning stays in git history where it naturally belongs.

---

## Claude's Discretion

The user explicitly deferred to the planner on:
- Exact wording of the "inbox is a derived view of the codebase" framing (D-07)
- Whether the skill ships as `/inbox-update` slash command or a referenced doc
- Exact threshold for the full sweep (>50 is the recommendation; planner can tune)
- Mechanism for detecting pre-digest invocation
- Internal markdown structure of the skill body (sections, ordering)

## Deferred Ideas

- **Rationale field** (DIFF-01, v2) — optional `why:` on entries; required for `@ DECISION::*`
- **Soft-cap warning UX** (DIFF-03, v2) — user-visible "consider running /digest" nudge
- **Concurrent-session safety** (HARD-01, Phase 5) — lockfile or per-session inbox files
- **Out-of-band reconciliation** (HARD-03 `/reconcile`, Phase 5) — thorough wiki↔codebase audit
- **D-19 enforcement** (Phase 1 deferred) — orthogonal to Phase 2; curator-side concern only
