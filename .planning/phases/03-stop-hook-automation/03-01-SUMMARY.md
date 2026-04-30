---
phase: 03-stop-hook-automation
plan: "01"
subsystem: hooks
tags: [bash, stop-hook, claude-code, settings-json, loop-protection, heartbeat]

# Dependency graph
requires:
  - phase: 02-in-session-inbox-skill
    provides: ".claude/skills/inbox-update/SKILL.md — the skill the hook references in its reason text"
provides:
  - ".claude/hooks/inbox-stop.sh — Stop hook script with full loop-protection trifecta + heartbeat + transcript pre-filter + decision:block payload"
  - ".claude/settings.json — Stop hook registration (Stop only, not SubagentStop)"
affects: [04-install-distribution]

# Tech tracking
tech-stack:
  added: [bash, POSIX sh, CLAUDE_PROJECT_DIR]
  patterns: [loop-protection trifecta (stop_hook_active + kill-switch + hard-cap), unconditional heartbeat before guards, transcript pre-filter via grep on JSONL, decision:block + reason injection]

key-files:
  created:
    - .claude/hooks/inbox-stop.sh
    - .claude/settings.json
  modified: []

key-decisions:
  - "decision:block + reason is the only injection mechanism on Stop hooks; additionalContext is silently dropped (Q1 locked Phase 1)"
  - "Stop registered only — not SubagentStop — to prevent digest sub-agent from thrashing inbox (D-07, Pitfall 1)"
  - "Heartbeat fires unconditionally before all guards so silent exits are visible in .hook-log (D-04)"
  - "Transcript pre-filter uses grep on JSONL to detect Edit/Write/MultiEdit before deciding to fire (D-05, Pitfall 15)"
  - "Hard cap keyed by session_id + minute boundary (date +%Y%m%d%H%M) persisted to .fire-counter (D-03)"
  - "All paths use $CLAUDE_PROJECT_DIR, never relative paths or pwd (D-12)"

patterns-established:
  - "Pattern: stop_hook_active guard on line 1 of any blocking Stop hook to prevent forced-continuation infinite loops"
  - "Pattern: kill switch via presence of .disabled file — escape hatch without editing settings.json"
  - "Pattern: per-turn fire counter keyed by session_id+minute stored in a single-line flat file"

requirements-completed: [CAPT-01]

# Metrics
duration: ~3min
completed: 2026-04-30
---

# Phase 3 Plan 01: Stop Hook Automation — Script + Registration Summary

**Stop hook bash script authored with the full loop-protection trifecta, heartbeat, transcript pre-filter, and decision:block delivery; registered in settings.json on Stop only.**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-04-30T02:21:37Z
- **Completed:** 2026-04-30T02:25:22Z
- **Tasks:** 2 / 2
- **Files created:** 2

## Accomplishments

- Authored `.claude/hooks/inbox-stop.sh` (108 lines) implementing all seven decisions: D-01 (stop_hook_active), D-02 (kill switch), D-03 (hard cap 2/turn), D-04 (unconditional heartbeat), D-05 (transcript pre-filter), D-06+D-08 (reason text under 200 chars with SKILL.md ref + wiki/* guard), D-10 (decision:block + reason), D-12 (CLAUDE_PROJECT_DIR throughout)
- Created `.claude/settings.json` registering Stop hook via `"$CLAUDE_PROJECT_DIR"/.claude/hooks/inbox-stop.sh` with 10s timeout; no SubagentStop registration
- All 4 pipe-stdin smoke tests passed: stop_hook_active exits 0, kill-switch exits 0, noop (no tool calls) exits 0, work-bearing turn emits `{"decision":"block","reason":"...SKILL.md..."}` with "fire" logged

## Task Commits

1. **Task 1: Author .claude/hooks/inbox-stop.sh** — `92e7692` (feat)
2. **Task 2: Write .claude/settings.json + pipe-stdin smoke tests** — `0d3fd32` (feat)

## Files Created/Modified

- `.claude/hooks/inbox-stop.sh` — Stop hook bash script, 108 lines, executable; loop-protection trifecta + heartbeat + transcript pre-filter + decision:block delivery
- `.claude/settings.json` — Hook registration: hooks.Stop[*].command referencing inbox-stop.sh via $CLAUDE_PROJECT_DIR; timeout:10; no SubagentStop

## Deviations from Plan

None — plan executed exactly as written. The `.claude/hooks/` and `.claude/inbox/` directories were created as prerequisites (not in the plan but implied by file paths; Rule 3 pre-empted).

## Smoke Test Results

| Test | Input | Expected | Actual | Result |
|------|-------|----------|--------|--------|
| T1: stop_hook_active=true | stop_hook_active=true | exit 0, no stdout | exit 0, empty stdout, "stop-hook-active" in log | PASS |
| T2: kill switch | .disabled present | exit 0, no stdout | exit 0, empty stdout, "kill-switch" in log | PASS |
| T3: noop turn | transcript has no tool calls | exit 0, no stdout | exit 0, empty stdout, "noop" in log | PASS |
| T4: work-bearing turn | transcript has Edit tool call | exit 0, decision:block + reason | exit 0, `{"decision":"block","reason":"...SKILL.md..."}`, "fire" in log | PASS |

## Known Stubs

None — no stubbed values or placeholders.

## Threat Flags

No new threat surface beyond what the plan's threat model covers (T-03-01 through T-03-06).

## Self-Check: PASSED

- `.claude/hooks/inbox-stop.sh` exists and is executable: CONFIRMED
- `.claude/settings.json` exists with valid JSON: CONFIRMED
- Task 1 commit `92e7692` exists: CONFIRMED
- Task 2 commit `0d3fd32` exists: CONFIRMED
- All 12 plan verification checks passed (PASS D-01 through PASS D-12, PASS D-07 Stop, PASS D-07 no SubagentStop)
