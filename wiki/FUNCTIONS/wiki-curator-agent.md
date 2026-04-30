
**Summary**: Curator subagent consumed by `/wiki-digest`; routes session-inbox handle entries and research-doc free prose into filed wiki notes per Rules.md, with D-19 RESEARCH/ write-protection branching by source.
**Tags**: #agent #digest #routing #function #fork
**Created**: 2026-04-30T16:09:00+00:00
**Last Updated**: 2026-04-30T16:42:00+00:00

---

## Content

**Path:** `.claude/agents/wiki-curator.md`
**Invoked by:** `/wiki-digest` skill body via `context: fork` + `agent: wiki-curator`.
**Allowed tools:** `Read, Write, Edit, Glob, Grep` (no Bash — true `rm` of source files unavailable; lifecycle steps that would otherwise need shell use Write-based fallbacks).

**Role.** Routes both session-inbox handle-line entries AND research-doc free-prose markdown into filed wiki notes per `wiki/Rules.md`. Under `context: fork` the curator is the only executor; lifecycle steps that older docs described as "the skill body owns" are now owned by the curator itself (see [[Fork Context No Parent Runtime]]).

**Research-doc decomposition.** For research docs, applies Rules.md §6 to derive `{slug, title, category, tags, summary}` per concept:

- Single-concept doc → 1 note.
- Multi-concept doc → N notes (one per distinct concept).

Each derived concept becomes a virtual entry that joins the same routing pipeline as session-inbox entries.

**Same-concept detection.** Filename + title + tag overlap (2+ matching signals → EDIT existing; 0–1 → CREATE new). Never embeddings — that is anti-feature A10.

**D-19 RESEARCH/ write-protection branches by source:**

- **Session-inbox handle-line entry** that hits an existing `wiki/RESEARCH/` note → emit an `ALERT` row. The curator routes the entry to the handle's original category and never writes into RESEARCH/. The user reconciles manually.
- **Research-doc concept** that hits an existing `wiki/RESEARCH/` note → emit a `CONFLICT-ON-RESEARCH` row and defer to Step 7a interactive resolution. The user picks `replace` / `append` / `skip` / free-form per conflict before any write to `wiki/RESEARCH/`.
- **Brand-new RESEARCH/ note** (no same-concept hit) → CREATE proceeds normally. RESEARCH/ is read-only for *modifications*, not for first-time writes.

**Plan structure.** Rows grouped by source under `## Source: <path>` sub-headings. Plan-level approval (D-03) covers `CREATE` / `EDIT` / `SPLIT` / `OVERRIDE` rows only — `CONFLICT-ON-RESEARCH` is explicitly excluded and requires per-conflict typed instructions.

**Step 10 — Session-inbox reset.** After Steps 7/7a/8/9 succeed, the curator overwrites `wiki/inbox/_session.md` with the canonical empty template. Explicitly forbidden to defer this "to the skill body" — under `context: fork` no skill body exists outside the curator's prompt.

**Step 11 — Research-doc source tombstone.** For each research doc whose concepts were ALL applied, the curator overwrites `wiki/inbox/<name>.md` with a one-line tombstone pointing to the Step 2b archive. The Bash gap (no `rm`) is closed by Write. Files with unresolved CONFLICT-ON-RESEARCH or apply errors are preserved unchanged. The user performs the final `rm` after seeing the tombstone list in the digest summary.

**Boundary with the digest skill body.** The skill body's bash injections handle Step 1 source counting, Step 2 archiving, and Step 5 link-audit grep. Everything else — routing, validation, writes, lifecycle resets, tombstones, summary emission — is the curator's responsibility. Rule-change suggestions surface as `RULES-PROPOSAL` rows for manual application; the curator never modifies `wiki/Rules.md`.

## Related Notes

- [[Wiki Digest Skill]]
- [[Research Doc Ingestion]]
- [[Curator Step 9 Index Update]]
- [[Fork Context No Parent Runtime]]
