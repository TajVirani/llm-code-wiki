
**Summary**: `/wiki-install` slash command bootstraps the auto-wiki system as five Bash blocks — idempotent, template-driven, hook-merging, and stamp-versioned.
**Tags**: #skill #install #bootstrap #function #linking #permissions
**Created**: 2026-04-30T16:09:00+00:00
**Last Updated**: 2026-05-09T14:17:00+00:00

---

## Content

**Path:** `.claude/skills/wiki-install/SKILL.md`
**Invocation:** `/wiki-install`

**Shape.** Five Bash blocks with zero Write/Edit tool calls (down from ~20 mixed prompts). Aborts on any missing required file with a re-run-remote-install pointer rather than falling back to inline content generation.

**Block 1 — Verify and materialize scaffold.** Check the `.claude/` tree (skill files, agents, hook scripts) is present. Create `wiki/`, `wiki/inbox/`, and copy `wiki/_templates/note.md` from the shipped distribution. Materialize `wiki/topic-index.md` from `.claude/skills/wiki-install/templates/topic-index.seed.md` with `<<CREATED_TS>>` / `<<UPDATED_TS>>` placeholders interpolated by `sed` so per-install timestamps differ. The seed ships with the piped form `[[Rules|Wiki Rules]]` (per [[piped-wiki-link-contract|Piped Wiki Link Contract]]) so freshly installed wikis are link-resolvable from turn 1.

**Block 2 — Hook registration + default permissions.** Upserts both Stop and UserPromptSubmit hook entries into `.claude/settings.json` via a single parametrized `jq` filter: idempotent remove-and-re-add. Uses `--arg` so the literal `$CLAUDE_PROJECT_DIR` token survives JSON encoding. Permissions, env vars, MCP servers, and unrelated hooks are preserved.

The same block also seeds three default permissions — `Read`, `Edit`, and `Write` on `wiki/inbox/_session.md` — so the per-turn capture path does not prompt on every Stop-hook fire. **Case A (fresh `settings.json`)** writes the permissions block via heredoc as part of the canonical file. **Cases B/C (existing `settings.json`)** require `jq` and run an `upsert_permission` filter that only adds entries not already present, preserving any user-added permissions. A manual no-`jq` fallback is documented in `SETTINGS-SNIPPET.md`. The default-permissions detail is described as a standalone concept in [[install-default-permissions|Install Default Permissions]].

**Block 5 reports a `(default perms)` summary row** alongside the hook merge result so the user can confirm the permissions seed succeeded.

**Block 3 — `CLAUDE.md` integration.** Appends the canonical `## Auto-maintained wiki` section to `CLAUDE.md` (or creates the file) by reading `.claude/skills/wiki-install/templates/CLAUDE-MD-SECTION.md` directly. This template is the single source of truth shared with `/wiki-update` Step 6 — see [[install-template-files|Install Template Files]].

**Block 4 — Smoke tests + version stamp.** Three checks: Stop hook fires (heartbeat in `.hook-log` for a synthetic session ID), recall hook fires (`recall:fire` log entry plus `Wiki recall` block in stdout), inbox writability. After all three pass, copies `VERSION` to `.claude/llm-code-wiki.version` so `/wiki-update` has a comparison baseline.

**Block 5 — Summary.** Prints a per-step summary read from `/tmp/lcw-install-status.txt`, which Blocks 1–4 append to as they progress.

**Abort discipline.** A missing required template or `.claude/` file aborts with a pointer to re-run remote install rather than falling back to inline content. This prevents drift between installed and shipped scaffolds.

**Progress logging.** Every block prints `[wiki-install] …` progress lines; no block is silent. Re-running after a partial install is safe.

## Related Notes

- [[install-template-files|Install Template Files]]
- [[remote-install-flow|Remote Install Flow]]
- [[wiki-update-skill|Wiki Update Skill]]
- [[update-flow|Update Flow]]
- [[piped-wiki-link-contract|Piped Wiki Link Contract]]
- [[install-default-permissions|Install Default Permissions]]
- [[test-harness|Test Harness]]
