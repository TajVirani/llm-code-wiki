# Phase 3: Stop Hook Automation - Context

**Gathered:** 2026-04-29
**Status:** Ready for planning
**Mode:** Autonomous smart-discuss (batch proposals, all accepted)

<domain>
## Phase Boundary

Wire a Claude Code Stop hook that auto-fires the inbox-update skill at every assistant-turn boundary. Per Q1 (locked Phase 1): use `decision:"block" + reason` with the loop-protection trifecta. The hook delivers a short `reason` payload telling Claude to update `wiki/inbox/_session.md` per the inbox-update skill body authored in Phase 2. Validates against a real coding session — no infinite loops, no thrashing on subagent stops, no-op turns are silent, heartbeat log proves firing, costs <10% extra tokens per turn.

Owns 1 v1 requirement: CAPT-01.

Out of scope this phase: install flow (Phase 4 — packaging the hook for other repos); concurrent-session safety (HARD-01, Phase 5).

</domain>

<decisions>
## Implementation Decisions

### Loop protection (mandatory trifecta per Pitfall 3)
- **D-01:** **`stop_hook_active` check** — the hook script's first non-trivial action is to parse stdin JSON for `stop_hook_active: true`; if present, exit 0 immediately. Defends against forced-continuation cycles when `decision:"block"` is returned.
- **D-02:** **Kill switch at `.claude/inbox/.disabled`** — if the file exists, the hook exits 0 silently. Lets the user disable the hook without editing settings.json. Touched/removed via `touch .claude/inbox/.disabled` / `rm .claude/inbox/.disabled`.
- **D-03:** **Hard cap of 2 fires per turn** — the hook tracks fire count for the current turn (using a small file at `.claude/inbox/.fire-counter` keyed by transcript turn ID or similar). After the second fire for the same turn, exit 0 unconditionally. Defends against issue #10205 (non-blocking infinite loops).

### Heartbeat (Pitfall 4 mitigation)
- **D-04:** **Append-only log at `.claude/inbox/.hook-log`** — every hook fire writes one line: `<ISO-8601 timestamp> <session_id> <outcome>` where outcome is one of `fire`, `noop`, `kill-switch`, `hard-cap`, `error`. Unconditional — heartbeat fires before any other logic so silent failures are visible. Periodic rotation (>1MB → archive to `.hook-log.<date>`) is planner's call.

### Transcript pre-filter (Pitfall 15 mitigation)
- **D-05:** **No-op detection by tool-call presence** — the hook reads `transcript_path` from stdin JSON, scans the latest assistant turn for `Edit`/`Write`/`MultiEdit` tool calls. If none found, the turn produced no codebase artifact; exit 0 with `noop` heartbeat. Saves cost on pure-conversation turns.

### Hook prompt (the `reason` text payload)
- **D-06:** **Short, skill-pointing.** The reason text is approximately: "Update wiki/inbox/_session.md per .claude/skills/inbox-update/SKILL.md for this turn's work. Skip if only wiki/* files changed." Length target: <200 chars to honor CAPT-05 (cheap prompt). The actual update logic lives in the inbox-update skill (Phase 2's deliverable); the hook just nudges.

### Event registration
- **D-07:** **`Stop` ONLY, NOT `SubagentStop`.** Settings.json registers exactly one hook on the `Stop` event. SubagentStop is excluded — per Pitfall 1, the curator's digest sub-agent would otherwise thrash the inbox it's emptying.

### Defensive in-prompt guard
- **D-08:** **"Skip if only wiki/* files changed."** Inlined in D-06's reason text. Defends against the curator's wiki/ writes (during /digest) triggering an inbox-update cascade. The inbox-update skill itself has the same guard (Phase 2, D-09 no-op turns); this is belt-and-braces.

### Acceptance fixture
- **D-09:** **Real coding-session smoke test** — across one session: (a) write a small function, observe the hook fires and inbox-update appends the entry; (b) delete the function, observe the hook fires again and inbox-update prunes; (c) take a few pure-conversation turns, observe no fires (noop heartbeat); (d) verify `.claude/inbox/.hook-log` accumulates entries; (e) confirm no infinite loops (no >2 fires for the same turn). Acceptance test is human-verified — the hook's primary failure mode is silent breakage, which an automated check can mistake for "no work to do."

### Carry-forward (locked elsewhere; restated for the planner)
- **D-10:** Hook injection mechanism = `decision:"block" + reason` (Q1 locked Phase 1, PROJECT.md Key Decisions). Do NOT use `additionalContext` on Stop hooks (verified empirically; not whitelisted for sync Stop events).
- **D-11:** Hook script is a shell command in `settings.json` `hooks.Stop[*].command`. Receives stdin JSON with `transcript_path`, `session_id`, `stop_hook_active`, etc. Emits stdout JSON with `decision: "block"` and `reason: "..."`. The shell script is the integration surface; the inbox-update skill is invoked by Claude *because* of the reason text, not directly by the hook.
- **D-12:** Use `CLAUDE_PROJECT_DIR` (provided to hooks) instead of `pwd`/relative paths.

### Claude's Discretion (planner's call)
- The exact hook script language (bash vs node; bash is preferred — no runtime dependency, A10 anti-feature)
- The exact mechanism for tracking fire-count per turn (D-03) — counter file with timestamp boundary, transcript-turn-ID keying, etc. Whatever's cheap and reliable
- The exact `reason` text wording (D-06) — must convey the intent in <200 chars
- Heartbeat log rotation policy (D-04)
- Whether the hook config in settings.json includes `timeout: 10` or relies on Claude Code's default
- Where the kill-switch file's existence is checked (immediately after `stop_hook_active`, before transcript read, to keep cost minimal)

</decisions>

<specifics>
## Specific Ideas

- The hook is a small bash script — probably 30-60 lines. Path: `.claude/hooks/inbox-stop.sh` (or similar; planner's call). Settings.json references it via shell command.
- Q1 evidence (Phase 1 PROJECT.md Key Decisions row) names the smoke test that confirmed `additionalContext` is silently dropped on synchronous Stop. Phase 3 doesn't need to re-litigate.
- The hook's payload (`decision: "block"` + `reason`) tells Claude to update the inbox before allowing stop. The inbox-update skill (Phase 2, `.claude/skills/inbox-update/SKILL.md`) is where the actual update logic lives — the hook just nudges Claude to invoke it.
- Settings.json edit is the user-visible install touchpoint. Phase 4 (install) handles merging into an existing settings.json without clobbering.

</specifics>

<canonical_refs>
## Canonical References

### The Q1 mechanism (LOCKED Phase 1)
- `.planning/PROJECT.md` Key Decisions row "Stop hook injection mechanism = decision:\"block\" + reason" — locked 2026-04-29 with smoke-test evidence.
- `code.claude.com/docs/en/hooks` — the source-of-truth reference for hook output schema. Verify against current docs at planning time, not training memory.

### Phase 1 + 2 outputs (the consumers/companions of Phase 3's hook)
- `.claude/skills/inbox-update/SKILL.md` (Phase 2 deliverable) — the skill the hook invokes via reason text. The hook's reason text REFERENCES this skill; doesn't duplicate it.
- `.claude/skills/digest/SKILL.md` (Phase 1 deliverable) — the digest skill. Its sub-agent must NOT trigger this hook. Hook registration on `Stop` only (D-07) handles this.
- `.claude/agents/wiki-curator.md` (Phase 1 deliverable) — the curator. Same — must not trigger this hook (SubagentStop is excluded).

### Project context
- `.planning/PROJECT.md` — locked decisions, especially Stop hook decision (D-10).
- `.planning/REQUIREMENTS.md` — CAPT-01 is this phase's only requirement.
- `.planning/phases/02-in-session-inbox-skill/02-CONTEXT.md` — Phase 2's D-09 no-op-turn behavior; Phase 3's D-08 mirrors it.

### Pitfalls (the failure modes Phase 3 must mitigate)
- `.planning/research/PITFALLS.md` Pitfall 1 (Stop vs SubagentStop) — addressed by D-07
- `.planning/research/PITFALLS.md` Pitfall 3 (loop hazard / `stop_hook_active`) — addressed by D-01 + D-02 + D-03
- `.planning/research/PITFALLS.md` Pitfall 4 (silent failure) — addressed by D-04 heartbeat
- `.planning/research/PITFALLS.md` Pitfall 15 (debug/REPL noise) — addressed by D-05 transcript pre-filter

### External references
- GitHub issues anthropics/claude-code#3573, #10205 — documented infinite-loop classes; D-01..D-03 trifecta defends against both
- GitHub issue #33049 — Stop does not fire when Task-tool subagent returns to parent (relevant for D-07 reasoning)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`.claude/skills/inbox-update/SKILL.md`** (Phase 2) — the skill the hook nudges Claude to invoke. The hook's reason text points at this skill by path.
- **Phase 1 skills/agents in `.claude/`** — establish the existing layout the hook script's path conventions should match.

### Established Patterns
- **No-runtime delivery** — the hook is a bash script (no Node, no Python). A10 anti-feature: no parser dependencies. Bash + `jq` (or `node -e` one-liners as last resort) for stdin JSON parsing.
- **Skill-as-instruction** — the hook doesn't directly write the inbox; it delivers a `reason` text that Claude follows. Same pattern as Phase 1's digest skill body delivering instructions to the curator.

### Integration Points
- **Settings.json `hooks.Stop[*]`** — the registration point. Phase 4 (install) handles merging into existing settings.json.
- **`.claude/hooks/inbox-stop.sh`** (or equivalent path) — the hook script.
- **`.claude/inbox/.disabled`** — kill switch.
- **`.claude/inbox/.hook-log`** — heartbeat.
- **`.claude/inbox/.fire-counter`** — per-turn fire counter.
- **`wiki/inbox/_session.md`** — the eventual write target (via the skill, not the hook directly).

</code_context>

<deferred>
## Deferred Ideas

- **Concurrent-session safety** (HARD-01, Phase 5) — multiple Claude sessions firing the hook concurrently could race on the fire-counter file or hook-log. Phase 3 assumes single-session.
- **Heartbeat log rotation** (operational hardening, Phase 5) — auto-archive when `.hook-log` grows past N MB.
- **Hook performance benchmarking** — empirical "<10% extra tokens per turn" verification is a single-session observation, not a benchmarking suite. v2 if the cost becomes a concern.
- **D-19 enforcement** (Phase 1 deferred) — orthogonal to Phase 3.

</deferred>

---

*Phase: 03-stop-hook-automation*
*Context gathered: 2026-04-29*
