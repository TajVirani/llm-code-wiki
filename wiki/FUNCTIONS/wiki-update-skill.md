
**Summary**: `/wiki-update` slash command pulls upstream scaffold improvements into an existing install — idempotent, manifest-driven, with per-line `overwrite`/`keep` policy and post-fetch hook + CLAUDE.md re-merge.
**Tags**: #skill #update #versioning #lifecycle #function
**Created**: 2026-04-30T16:09:00+00:00
**Last Updated**: 2026-04-30T16:09:00+00:00

---

## Content

**Path:** `.claude/skills/wiki-update/SKILL.md`
**Invocation:** `/wiki-update [optional RAW_BASE]`

**Optional argument.** `RAW_BASE` overrides the default upstream raw URL — useful for forks and feature branches.

**Step 0 — Precondition.** Abort if `.claude/skills/wiki-install/SKILL.md` is missing. That file is the proxy signal for "scaffold installed".

**Step 1 — Version comparison.** Read local `.claude/llm-code-wiki.version` (default `0.0.0` if absent). Fetch upstream `VERSION`. Compare with `sort -V`. Equal-or-newer-local exits as a no-op.

**Step 2 — Changelog slice + confirm.** Fetch `CHANGELOG.md`. Slice sections strictly between local (exclusive) and upstream (inclusive) using awk semver compare. Display the slice. Ask the user `Apply this update? (yes/no)` in plain text — confirmation is conversational, not a tool dialog, so the user can push back before commit.

**Step 3 — Fetch manifest.** `dist-manifest.txt` is fetched fresh.

**Step 4 — Apply manifest per-line policy.**

- **`overwrite`** — `mkdir -p` parent + `curl` upstream → local + `chmod +x` for `.sh` paths.
- **`keep`** — `cmp` local vs an upstream tmp file. When they differ, append the path plus a `github.com` blob diff URL (raw → blob URL conversion via `sed`) to a manual-review list shown in the final summary.

**Step 5 — Re-merge `.claude/settings.json`.** Defensively remove any existing Stop / UserPromptSubmit hook entries whose command field contains `inbox-stop.sh` or `recall-prompt.sh`, then append the canonical entries. Permissions, env vars, MCP servers, and unrelated hooks are preserved. Aborts if `jq` is absent (same constraint as `/wiki-install`). Verifies post-merge that the literal `$CLAUDE_PROJECT_DIR` token survived JSON encoding.

**Step 6 — Refresh `CLAUDE.md`.** Extract the canonical `## Auto-maintained wiki` block from the just-updated `wiki-install/SKILL.md` (between markdown code fences, via `awk`) and replace the section in `CLAUDE.md` (or append if absent). Everything outside the section is preserved untouched.

**Step 7 — Stamp + summary.** Write upstream version to `.claude/llm-code-wiki.version` and print a summary including the manual-review list from Step 4.

**Idempotence.** A same-version re-run exits at Step 1 with "Already up-to-date". A failed update can be re-run safely — the stamp is only bumped after every step succeeds.

## Related Notes

- [[Update Flow]]
- [[Wiki Install Skill]]
- [[Remote Install Flow]]
