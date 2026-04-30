
**Summary**: `/wiki-install` slash command bootstraps the auto-wiki system in a target project — idempotent, hook-merging, and stamp-versioned.
**Tags**: #skill #install #bootstrap #function
**Created**: 2026-04-30T16:09:00+00:00
**Last Updated**: 2026-04-30T16:09:00+00:00

---

## Content

**Path:** `.claude/skills/wiki-install/SKILL.md`
**Invocation:** `/wiki-install`

**Step 0 — Precondition check.** Verify all required `.claude/` files are present and both hook scripts are executable. Abort with a clear pointer if anything is missing.

**Steps 1–4b — Idempotent scaffold creation.**

- Step 1: create `wiki/`.
- Step 2: write `wiki/_templates/note.md` (skip-if-exists; never overwrites user content).
- Step 3: write `wiki/Rules.md`. Partial-install guard — if absent and the source repo is not accessible, abort with a pointer to `INSTALL.md` "Remote install" or `dist-manifest.txt`.
- Step 4: create `wiki/inbox/`.
- Step 4b: write `wiki/topic-index.md`. The full canonical empty seed is inlined here — front-matter, HTML maintenance comment, and a `Related Notes` link to `[[Rules]]` — because `topic-index.md` is *not* shipped via the distribution manifest.

**Step 5 / 5b — Hook registration.** Merges Stop and UserPromptSubmit hook entries into `.claude/settings.json` using three-case logic:

- **Case A** — file absent → write canonical full structure.
- **Case B** — hook already registered → skip.
- **Case C** — needs merge → use `jq` with `--arg` so the literal `$CLAUDE_PROJECT_DIR` token survives the JSON encoding, then verify post-merge that the token is intact.

**Step 6 — `CLAUDE.md` integration.** Appends an "Auto-maintained wiki" section to `CLAUDE.md` (or creates the file). The markdown code-fenced block at this step is the **canonical source of truth** for the section's content — extracted by `/wiki-update` Step 6 to refresh `CLAUDE.md` without divergence.

**Step 7 — Smoke tests.** Three checks: Stop hook fires (heartbeat in `.hook-log` for synthetic session ID), recall hook fires (`recall:fire` log entry plus `Wiki recall` block in stdout), inbox writability.

**Step 7b — Version stamp.** Copies `VERSION` to `.claude/llm-code-wiki.version` so `/wiki-update` has a baseline to compare against. If `VERSION` is absent (manual install from old checkout), warn and skip; `/wiki-update` then treats the missing stamp as `0.0.0`.

**Progress logging.** Every step prints a `[wiki-install] …` progress line; no step is silent. Re-running after a partial install is safe.

## Related Notes

- [[Remote Install Flow]]
- [[Wiki Update Skill]]
- [[Update Flow]]
