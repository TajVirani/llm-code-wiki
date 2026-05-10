
**Summary**: L2 layer of the test harness — drives both hook scripts with synthetic JSON, covering kill switches, noop/artifact branches, brainstorm-fallback, and recall cooldown.
**Tags**: #testing #hooks #shell #function

**Created**: 2026-05-09T14:17:00+00:00
**Last Updated**: 2026-05-09T14:17:00+00:00

---

## Content

**Path:** `tests/hooks.sh`
**Layer:** L2 of the [[test-harness|Test Harness]].

### Per-test isolation

Each test gets a fresh `CLAUDE_PROJECT_DIR` fixture so `.hook-log`, `.turn-count`, `.fire-counter`, and `.recall-counter` state never leaks between tests. This is what lets us assert exact log lines and counter transitions without flakiness.

### `inbox-stop` coverage

- **`stop_hook_active` short-circuit** — hook exits early when re-entered during its own decision-block fire.
- **`.disabled` kill switch** — `touch .claude/inbox/.disabled` suppresses all firing.
- **Noop turn** — code-free turn writes a `turncount-pending` log entry and increments the per-session brainstorm counter.
- **Artifact turn** — turn with Edit/Write/MultiEdit emits the canonical `decision:block` JSON and resets the brainstorm counter to 0.
- **Brainstorm-fallback fire after N noop turns** — uses `LCW_BRAINSTORM_TURNS=3` for speed; verifies the `turncount-fire` log entry and the brainstorm-mode payload.
- **Heartbeat `entering` line** — every fire writes a heartbeat row, regardless of branch taken.

### `recall-prompt` coverage

- **`.recall-disabled` kill switch.**
- **Planning-intent fire** — keyword-matching prompt produces a `Wiki recall` block on stdout.
- **Chit-chat noop** — non-planning prompt produces no output.
- **Wiki-only skip** — requires BOTH planning-intent AND wiki-only keyword match to skip; one alone does not.
- **Cooldown** — identical session + prompt-hash retries are suppressed.

### Why this layer matters

The hooks are the trickiest part of the scaffold — they run inside Claude Code's hook lifecycle, can deadlock the editor if they misbehave, and have multiple kill-switch + cadence branches. L2 lets us refactor them with confidence: every branch has a deterministic test that runs in milliseconds.

## Related Notes

- [[test-harness|Test Harness]]
- [[test-static-layer|Test Static Layer]]
- [[test-install-e2e-layer|Test Install E2E Layer]]
- [[inbox-stop-hook|Inbox Stop Hook]]
- [[recall-prompt-hook|Recall Prompt Hook]]
- [[brainstorm-fallback-cadence|Brainstorm Fallback Cadence]]
