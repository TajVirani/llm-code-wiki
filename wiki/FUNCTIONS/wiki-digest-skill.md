
**Summary**: `/wiki-digest` consolidates session-inbox entries and research-doc drops into filed wiki notes via the curator subagent, owning archive-before-write, audit, and source-cleanup lifecycle.
**Tags**: #skill #digest #lifecycle #function #fork #linking
**Created**: 2026-04-30T16:09:00+00:00
**Last Updated**: 2026-05-01T23:14:00+00:00

---

## Content

**Path:** `.claude/skills/wiki-digest/SKILL.md`
**Invocation:** `/wiki-digest [optional-inbox-path]`

**Role.** Consolidates inbox sources into filed wiki notes via the wiki-curator subagent. Owns the *lifecycle* around the curator's writes: source discovery, archive-before-write, post-write link audit, source-file cleanup on success, and the empty-inbox no-op path.

**Fork-mode contract.** The skill frontmatter declares `context: fork` + `agent: wiki-curator`. With `context: fork` there is no separate parent runtime that resumes after the curator finishes — the curator IS the only executor. The skill body intro states this unambiguously and addresses every Step 4–7 instruction in second person at the curator. See [[fork-context-no-parent-runtime|Fork Context No Parent Runtime]] for the failure mode that motivated this wording.

**Step 1 — Source discovery (two source types):**

1. `wiki/inbox/_session.md` — handle-line entries populated by the inbox-update skill.
2. Any `.md` file in the root of `wiki/inbox/` excluding `_session.md` and any underscore-prefixed file — treated as user-dropped free-prose research docs.

The combined no-op guard skips the run only when *both* sources are empty.

**Step 2 — Archive every source BEFORE any note write.** All sources copied into `wiki/inbox/_archive/<TS>-session.md` and `<TS>-research-<filename>.md` with one shared timestamp. The crash-safety guarantee (LIFE-03) requires this happen before any curator write — a curator crash mid-write must leave every input recoverable from the archive.

**Step 3 — Curator inputs.** Emits a delimited research-doc payload (`=== RESEARCH-DOC: <path> === … === END RESEARCH-DOC ===`) alongside the session content, the wiki tree, and `wiki/Rules.md` to the curator. The Rules file is read fresh per Pitfall 12 — never a stale skill-body mirror.

**Step 4 — Curator runs.** The curator emits a source-grouped plan (`## Source: <path>` sub-headings), validates it, applies CREATE / EDIT / SPLIT / OVERRIDE rows, and runs interactive resolution for any CONFLICT-ON-RESEARCH rows.

**Step 5 — Post-write link audit (DIGS-11, D-08).** Greps every `[[basename|Display Title]]` reference, takes the part before `|` as a basename, and verifies a matching `wiki/**/<basename>.md` exists — a file-existence check, NOT an H1 match (Obsidian resolves on filename). Bare `[[X]]` references (no `|`) are surfaced as out-of-contract violations regardless of whether an H1 happens to match. See [[piped-wiki-link-contract|Piped Wiki Link Contract]] for the rationale; both the unresolved-basename and bare-link findings appear under the digest summary's "Unresolved wiki-links" section.

**Step 6a — Reset session inbox** to the empty canonical template once the curator's writes succeeded. The curator performs this Write itself (duplicates curator agent Step 10) — under `context: fork` no other executor exists.

**Step 6b — Tombstone consumed research-doc sources.** For each doc whose concepts were ALL successfully applied, the curator overwrites `wiki/inbox/<name>.md` with a one-line marker pointing to the Step 2b archive. True deletion via `rm` is unavailable because the curator's allowed-tools list omits Bash; the tombstone marker is the Write-based fallback. The user does the final `rm` after seeing the tombstone list. Any unresolved CONFLICT-ON-RESEARCH or apply error preserves the source for retry. The Step 2 archive is the safety net.

**Step 7 — Digest summary.** Grouped by source: inbox entries processed, research docs consumed (with derived-notes list and source-file disposition), notes created/edited, splits, overrides, alerts, conflicts, rule proposals, unresolved wiki-links, topic-index changes.

## Related Notes

- [[wiki-curator-agent|Wiki Curator Agent]]
- [[research-doc-ingestion|Research Doc Ingestion]]
- [[digest-step-6-inbox-reset|Digest Step 6 Inbox Reset]]
- [[fork-context-no-parent-runtime|Fork Context No Parent Runtime]]
- [[piped-wiki-link-contract|Piped Wiki Link Contract]]
