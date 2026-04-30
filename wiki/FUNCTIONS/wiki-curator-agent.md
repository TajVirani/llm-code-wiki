
**Summary**: Curator subagent consumed by `/wiki-digest`; routes session-inbox handle entries and research-doc free prose into filed wiki notes per Rules.md, with D-19 RESEARCH/ write-protection branching by source.
**Tags**: #agent #digest #routing #function
**Created**: 2026-04-30T16:09:00+00:00
**Last Updated**: 2026-04-30T16:09:00+00:00

---

## Content

**Path:** `.claude/agents/wiki-curator.md`
**Invoked by:** `/wiki-digest` skill body via `context: fork` + `agent: wiki-curator`.

**Role.** Routes both session-inbox handle-line entries AND research-doc free-prose markdown into filed wiki notes per `wiki/Rules.md`.

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

**Boundary with the digest skill body.** The curator does not delete research-doc source files; that lifecycle action is owned by `/wiki-digest` Step 6b. The curator does not modify `wiki/Rules.md`; rule-change suggestions surface as `RULES-PROPOSAL` rows for manual application.

## Related Notes

- [[Wiki Digest Skill]]
- [[Research Doc Ingestion]]
- [[Curator Step 9 Index Update]]
