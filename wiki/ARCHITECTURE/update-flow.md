
**Summary**: End-to-end versioning + upstream update mechanism for installed scaffolds, anchored on `VERSION`, `CHANGELOG.md`, and `dist-manifest.txt` with per-line `overwrite`/`keep` policy.
**Tags**: #architecture #update #versioning #distribution
**Created**: 2026-04-30T16:09:00+00:00
**Last Updated**: 2026-04-30T16:32:00+00:00

---

## Content

**Source-of-truth version.** Lives in `VERSION` at repo root — a single-line semver (currently `1.0.0`).

**Changelog.** `CHANGELOG.md` follows Keep-a-Changelog format. Each release has a `### Migration` subsection listing manual steps `/wiki-update` cannot perform automatically.

**Install version stamp.** `/wiki-install` Step 7b writes the upstream version into `.claude/llm-code-wiki.version`. `/wiki-update` reads this stamp as the comparison baseline; a missing stamp is treated as `0.0.0`, so manual installs from old checkouts still update cleanly.

**Distribution manifest with policy.** `dist-manifest.txt` is extended with an optional whitespace-separated POLICY column:

- **`overwrite`** (default) — fetch upstream and replace the local file.
- **`keep`** — skip if the local file exists; notify the user when upstream differs but do not modify their copy.

`wiki/Rules.md` and `wiki/_templates/note.md` use `keep` — user customizations are preserved on update.

**Files outside the manifest.** `wiki/topic-index.md` is excluded entirely (the curator regenerates it). `.claude/settings.json` and `CLAUDE.md` are also outside the manifest — they are handled directly by `/wiki-update` Steps 5–6:

- **Step 5** — upserts the two hook entries into `.claude/settings.json` by command-substring match (`inbox-stop.sh`, `recall-prompt.sh`). Unrelated hooks, permissions, env vars, and MCP servers are preserved.
- **Step 6** — replaces only the `## Auto-maintained wiki` section of `CLAUDE.md`, sourcing canonical content from the just-updated `wiki-install/SKILL.md` Step 6 markdown block. This keeps a single source of truth for the section's wording in sync with the rich live install experience.

**Version-stamp ordering.** The local stamp is updated only after every step succeeds. A failed update is therefore safely re-runnable — the next `/wiki-update` run sees the same gap between stamp and upstream and retries.

**Idempotence.** Same-version re-runs exit at Step 1 with "Already up-to-date".

## Related Notes

- [[wiki-update-skill|Wiki Update Skill]]
- [[remote-install-flow|Remote Install Flow]]
- [[wiki-install-skill|Wiki Install Skill]]
