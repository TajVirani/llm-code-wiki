# tests/

Shell-based test harness for the llm-code-wiki scaffold. Three layers:

| Layer | Script | What it covers |
|-------|--------|----------------|
| L1 — static | `static.sh` | Manifest paths resolve; SKILL.md + agent .md frontmatter is valid; hook scripts pass `bash -n` and are executable; every fenced ` ```bash ` block in every SKILL.md passes `bash -n`; VERSION/CHANGELOG/INSTALL/README sanity. |
| L2 — hooks | `hooks.sh` | Unit tests for `inbox-stop.sh` and `recall-prompt.sh` — synthetic JSON in, asserts on `.hook-log` lines, stdout shape, and exit codes. Covers stop_hook_active, kill switches, noop turns, artifact turns, brainstorm-fallback, recall fire/noop/wiki-only/cooldown. |
| L3 — install-e2e | `install-e2e.sh` | Runs the `/wiki-install` bash blocks end-to-end in a tmpdir fixture; asserts settings.json shape, CLAUDE.md section, wiki/ scaffolding, version stamp, smoke tests. Plus targeted `wiki-update` Step 5 tests for the permissions-backfill path on a stale-install fixture. |

## Run

```bash
tests/run-all.sh                      # all three layers
tests/run-all.sh static                # one layer
tests/run-all.sh hooks install-e2e     # selected layers
```

Each script is independently runnable: `bash tests/hooks.sh`. Each layer prints PASS/FAIL per check and exits nonzero on any failure.

## Requirements

- `bash` 4+
- `jq` (required for L3 — install-e2e exercises the same jq-based settings.json merge that the real `/wiki-install` uses)
- `python3` (used by `recall-prompt.sh` for safe JSON decoding; the hook has a grep fallback, but L2's recall tests set the hook up to use the python path when available)

## Out of scope

L4 — semantic skill behavior (does the curator route correctly? does recall find the right note? does cluster detection fire on the right shapes?) — is not testable from a shell harness because those behaviors are produced by Claude executing the skill prompts. That layer needs an eval-style harness with a model invocation, not unit tests.
