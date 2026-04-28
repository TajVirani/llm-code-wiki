# State: llm-code-wiki

**Last Updated:** 2026-04-28

## Project Reference

**Project:** llm-code-wiki — Claude Code skill + hook scaffolding that auto-maintains an Obsidian-style codebase wiki.

**Core Value:** Code documentation stays current and coherent without manual upkeep — including correctly pruning entries when code is deleted or superseded within the same session.

**Current Focus:** Phase 1 — Foundation + Curator. Resolve Q1 (Stop hook injection mechanism), scaffold `.claude/{skills,agents}/` + `wiki/inbox/_session.md` placeholders, then build the digest sub-agent against a hand-authored fixture inbox.

## Current Position

| Field | Value |
|-------|-------|
| **Phase** | 1 — Foundation + Curator |
| **Plan** | (none yet — run `/gsd-plan-phase 1`) |
| **Status** | Not started |
| **Progress** | `[ ░░░░░░░░░░░░░░░░░░░░ ] 0%` |
| **Started** | 2026-04-28 (project initialization) |

## Roadmap At-a-Glance

- [ ] **Phase 1: Foundation + Curator** ← *current*
- [ ] Phase 2: In-Session Inbox Skill
- [ ] Phase 3: Stop Hook Automation
- [ ] Phase 4: Install & Distribution

## Performance Metrics

| Metric | Value |
|--------|-------|
| Phases complete | 0 / 4 |
| Plans complete | 0 / TBD |
| v1 Requirements mapped | 26 / 26 ✓ |
| v1 Requirements validated | 0 / 26 |

## Accumulated Context

### Locked Decisions (from PROJECT.md)

- Inbox is **state-of-the-world**, not chronological log (enables natural pruning).
- **Atomic, flat entries** — no in-session sectioning; digest sub-agent routes holistically.
- **Stop hook** trigger (not PostToolUse, not SessionEnd) — one coherent update per logical turn.
- **Rolling per-project inbox**, manual digest — explicit review checkpoint.
- **Multi-skill split** — separate skills for inbox upkeep, digest, and (preloaded) wiki rules.

### Pending Decisions (must resolve early in Phase 1)

- **Q1 (CRITICAL):** Stop hook injection mechanism. Researchers disagree:
  - Stack research: use `hookSpecificOutput.additionalContext` (non-blocking, no loop class).
  - Architecture research: `additionalContext` is *not* whitelisted for Stop; must use `decision:"block" + reason`.
  - Resolution path: read current `code.claude.com/docs/en/hooks` + run a one-line smoke test before any hook code lands. Document the choice in `PROJECT.md` Key Decisions.

### Promoted Recommendations from Research

- **Inbox path:** `wiki/inbox/_session.md` (leading underscore parallels `_templates/`, resolves the semantic stretch with `Rules.md` §1).
- **Entry handle convention:** `@ CATEGORY::slug • path • #tags` — load-bearing for `^@ CATEGORY::<slug>` grep-prune.
- **Digest preview/dry-run:** promoted from differentiator to table-stakes per Pitfalls §11.
- **Optional `why:` field** on inbox entries (Q4) — required for `@ DECISION::*` entries.

### Active Todos

- (none yet — populated by `/gsd-plan-phase 1`)

### Blockers

- (none)

### Risk Register (top 3 from PITFALLS.md)

1. **Stop hook reentry / infinite loop** (Pitfall 3) — mandatory `stop_hook_active` check, kill switch, hard turn-counter cap. Mitigation lands in Phase 3; Q1 resolution in Phase 1 reduces exposure.
2. **The 1+1-then-deleted case** (Pitfall 2) — locked validation gate. Stable handles + state-of-world framing + diff-pass protocol + curator verification. Owned across Phase 1 (curator safety net) + Phase 2 (skill prevention).
3. **Digest writes junk into the wiki with no preview** (Pitfall 11) — preview-by-default in the curator. Mitigation lands in Phase 1 (Pattern 5: Curator Proposes-Then-Applies).

## Session Continuity

### Last Session Summary

Project initialized 2026-04-28. PROJECT.md, REQUIREMENTS.md (26 v1 requirements across CAPT/DIGS/LIFE/INST), four research deliverables (STACK, FEATURES, ARCHITECTURE, PITFALLS, SUMMARY) authored. Roadmap created with 4 phases reflecting the digest-first build order on which all four researchers converged.

### Next Action

Run `/gsd-plan-phase 1` to decompose Phase 1 (Foundation + Curator) into executable plans. The first plan should resolve Q1; subsequent plans should scaffold the layout and build the curator sub-agent + digest skill against a hand-authored fixture inbox.

### Resume Instructions

If resuming after a context reset:
1. Read `.planning/PROJECT.md` (locked decisions, constraints).
2. Read `.planning/research/SUMMARY.md` §"Critical Open Questions" — Q1 must be resolved before hook code is written.
3. Read `.planning/ROADMAP.md` — current phase + success criteria.
4. Read this file (`STATE.md`) — current position + accumulated context.
5. Continue from `Next Action` above.

---

*State initialized: 2026-04-28 after roadmap creation*
