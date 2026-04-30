# CAPT-04 Acceptance Report: 1+1-then-deleted fixture

**Plan:** 02-02
**Date:** 2026-04-28
**Verdict:** PASS

---

## Fixture Loop Results

| Turn | Action | Expected | Observed |
|------|--------|----------|----------|
| Turn 1 | Created `tests/fixtures/math.ts` with `add(a,b)`, ran /inbox-update | 1 entry: `^@ FUNCTIONS::add` | 1 entry found |
| Turn 2 | Deleted `tests/fixtures/math.ts`, ran /inbox-update | 0 entries (entry pruned) | 0 entries |
| Digest sim | /digest on empty inbox | zero filed notes for `add`; DIGS-12 no-op | confirmed via skill body analysis |

---

## Grep Outputs

```
# After Turn 1
$ grep -c "^@ " wiki/inbox/_session.md
1
$ grep "^@ FUNCTIONS::add" wiki/inbox/_session.md
@ FUNCTIONS::add  •  tests/fixtures/math.ts  •  #function #math

# After Turn 2
$ grep -c "^@ " wiki/inbox/_session.md
0
$ grep -q "^@ [A-Z]*::add" wiki/inbox/_session.md; echo exit=$?
exit=1   (absent — PASS)
```

---

## Final State Verification

| Check | Command | Result |
|-------|---------|--------|
| Inbox entry count = 0 | `grep -c "^@ " wiki/inbox/_session.md` | 0 — PASS |
| No add entry (any category) | `! grep -q "^@ [A-Z]*::add" wiki/inbox/_session.md` | PASS |
| Fixture file absent | `! test -f tests/fixtures/math.ts` | PASS |
| No ghost note | `! test -f wiki/FUNCTIONS/add.md` | PASS |
| Skill has "derived view" | `grep -q "derived view" .claude/skills/inbox-update/SKILL.md` | PASS |
| Skill has "scratch" | `grep -q "scratch" .claude/skills/inbox-update/SKILL.md` | PASS |
| Skill has "1+1" | `grep -q "1+1" .claude/skills/inbox-update/SKILL.md` | PASS |
| Skill line count ≤ 250 | `wc -l .claude/skills/inbox-update/SKILL.md` | 117 — PASS |
| No Notable Detours section | `! grep -q "^## Notable Detours" .claude/skills/inbox-update/SKILL.md` | PASS |
| No A8 anti-pattern (chronological log) | `! grep -qi "deleted\|removed\|add was" wiki/inbox/_session.md` | PASS |

---

## Digest Simulation

If `/digest` were run now:

1. Reads `wiki/inbox/_session.md` — finds 0 entries (count = 0)
2. Archives empty file to `wiki/inbox/_archive/<timestamp>-session.md` (D-14)
3. Prints: "Inbox is empty (0 entries); idempotent no-op." and exits (DIGS-12)
4. Does NOT create `wiki/FUNCTIONS/add.md` — no entry in inbox, nothing to route

Result: **zero filed notes for `add`** — correct.

---

## CAPT-04 Verdict

**PASS** — The 1+1-then-deleted fixture loop completed correctly:
- After Turn 1: inbox had exactly 1 entry for `@ FUNCTIONS::add` with `tests/fixtures/math.ts` as path
- After Turn 2: inbox had exactly 0 entries — completely clean, no ghost record, no A8 anti-pattern
- Digest simulation: would produce zero filed notes for `add`

All Phase 2 requirements addressed:
- CAPT-02: Atomic flat entries, state-of-world, no chronological log
- CAPT-03: `@ CATEGORY::slug` handle enables grep-prune
- CAPT-04: 1+1-then-deleted fixture PASSES (this plan)
- CAPT-05: No-op guard + 117-line skill
- CAPT-06: Scratch-list evidence-grounding
- CAPT-07: Derived-view framing as first paragraph
- LIFE-01: `wiki/inbox/_session.md` as the established write target
