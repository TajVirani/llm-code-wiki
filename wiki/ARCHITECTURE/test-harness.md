
**Summary**: Three-layer shell-based test harness verifying scaffolding works without invoking Claude — static checks, hook unit tests, and install-e2e bash-block extraction.
**Tags**: #testing #ci #shell #harness #architecture

**Created**: 2026-05-09T14:17:00+00:00
**Last Updated**: 2026-05-09T14:17:00+00:00

---

## Content

### Purpose

The harness verifies the scaffold's mechanical correctness without putting Claude in the loop. Bash, jq, and standard POSIX tools are sufficient; LLM behavior is intentionally out of scope.

### Entrypoint

`tests/run-all.sh` runs the three layers in sequence and reports per-layer pass/fail.

### Layers

**L1 — Static checks (`tests/static.sh`).** File-reference resolution, frontmatter validity on every `SKILL.md` and agent `.md`, and `bash -n` syntax checks on hook scripts and every fenced ` ```bash ` block extracted from skill bodies. Detail: [[test-static-layer|Test Static Layer]].

**L2 — Hook unit tests (`tests/hooks.sh`).** Drives both hook scripts (`inbox-stop.sh`, `recall-prompt.sh`) with synthetic JSON input, covering kill switches, noop/artifact branches, brainstorm-fallback (uses `LCW_BRAINSTORM_TURNS=3` for speed), and recall planning-intent / cooldown logic. Detail: [[test-hooks-layer|Test Hooks Layer]].

**L3 — Install end-to-end (`tests/install-e2e.sh`).** Extracts the five bash blocks from `wiki-install/SKILL.md` and the two Step-5 blocks from `wiki-update/SKILL.md`, runs them in tmpdir fixtures, and asserts settings.json shape, idempotence, and user-permission preservation. Detail: [[test-install-e2e-layer|Test Install E2E Layer]].

### What is intentionally NOT tested

**Layer 4 — semantic skill behavior.** Whether the curator routes correctly, whether recall finds the right note, whether the digest plan respects Rules.md — all out of scope for the bash harness because they require Claude in the loop. That validation lives in dogfooding and manual review.

### Design principles

- **No Claude in the loop.** Every assertion is a deterministic shell check.
- **Per-test fresh fixtures.** L2 and L3 each use a per-test fresh `CLAUDE_PROJECT_DIR` so `.hook-log`, `.turn-count`, `.fire-counter`, and `.recall-counter` state never leaks between tests.
- **Skip-not-fail on environment gaps.** L3 exits 0 with a skip message if `jq` is missing — the test treats that as an environment issue, not a code regression.
- **Bash-block extraction is a build step.** L1 and L3 both pre-extract fenced bash blocks via `lib/extract-bash-blocks.sh`, so any skill body that gains a new block is automatically covered.

### Shared helpers

- `lib/assert.sh` — assertion primitives used across all three layers.
- `lib/extract-bash-blocks.sh` — fenced-block extractor shared between L1 (syntax checks) and L3 (e2e execution).

## Related Notes

- [[test-static-layer|Test Static Layer]]
- [[test-hooks-layer|Test Hooks Layer]]
- [[test-install-e2e-layer|Test Install E2E Layer]]
- [[wiki-install-skill|Wiki Install Skill]]
- [[wiki-update-skill|Wiki Update Skill]]
