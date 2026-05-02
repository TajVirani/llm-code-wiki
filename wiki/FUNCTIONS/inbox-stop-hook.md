
**Summary**: Stop hook script fired at every assistant turn boundary; orchestrates capture path with loop-protection trifecta and brainstorm-fallback counter.
**Tags**: #hook #capture #brainstorm #function
**Created**: 2026-04-30T16:09:00+00:00
**Last Updated**: 2026-04-30T16:32:00+00:00

---

## Content

**Path:** `.claude/hooks/inbox-stop.sh`
**Trigger:** Stop hook — fires at every assistant turn boundary.

**Loop-protection trifecta:**

- **D-01** — `stop_hook_active` flag check. If Claude Code already has a Stop hook in flight, exit immediately to prevent recursion.
- **D-02** — Kill-switch file `.claude/inbox/.disabled`. If present, exit with a `kill-switch` log line. The user creates this file with `touch .claude/inbox/.disabled` to disable capture.
- **D-03** — Hard cap of 2 actual fires per session+minute, counter at `.claude/inbox/.fire-counter`. Critically, the counter is bumped only on real fires, not on noops — otherwise long brainstorm sessions in a single minute would consume the cap on noop entries and never reach a fallback fire.

**Brainstorm counter state:**

- File: `.claude/inbox/.turn-count`, format `SESSION_ID COUNT`.
- Counter is keyed by session ID; a new session starts the count over automatically.
- N (the cadence) defaults to 10. Override via `LCW_BRAINSTORM_TURNS` env var. Non-integer or `<1` values are rejected and the default is used.

**Step 8 three-way branch:**

1. Artifact present (Edit / Write / MultiEdit detected in this turn's transcript) → fire normal capture, reset brainstorm counter to 0.
2. No artifact AND counter ≥ N → fire brainstorm-fallback with a different `reason` payload, then reset counter to 0.
3. Otherwise → log `turncount-pending COUNT/N` and exit.

**Hook-log outcomes** (written to `.claude/inbox/.hook-log`):

- `entering` — hook started
- `stop-hook-active` — D-01 short-circuit
- `kill-switch` — D-02 short-circuit
- `hard-cap` — D-03 short-circuit
- `fire turncount-reset-on-artifact` — normal capture path
- `turncount-fire COUNT/N` — brainstorm-fallback path fired
- `turncount-pending COUNT/N` — counter incremented, no fire

## Related Notes

- [[inbox-update-skill|Inbox Update Skill]]
- [[brainstorm-fallback-cadence|Brainstorm Fallback Cadence]]
- [[stop-hook-self-heals-runtime-dir|Stop Hook Self Heals Runtime Dir]]
