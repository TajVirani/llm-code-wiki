
**Summary**: `/wiki-code-crawler` crawls a codebase, builds an import+call graph, clusters source into 200–700-word concepts, and emits one research doc per concept for `/wiki-digest`.
**Tags**: #function #skill #wiki #crawler #bootstrap
**Created**: 2026-05-09T00:00:00+00:00
**Last Updated**: 2026-05-09T00:00:00+00:00

---

## Content

**Path:** `.claude/skills/wiki-code-crawler/SKILL.md`
**Invocation:** `/wiki-code-crawler`

**Role.** Bootstraps `wiki/inbox/` from the live codebase by emitting one free-prose research doc per detected concept. The output is the input to `/wiki-digest`; the crawler itself never files a wiki note.

### Phases

1. **Inventory** — walks the source tree producing `_docgen/inventory.json` (file → symbols, language, line counts).
2. **Graph** — builds a function-level import + call graph at `_docgen/graph.json`.
3. **Cluster** — partitions the graph into concept clusters of 200–700 words each at `_docgen/concepts.json`. The word band keeps each concept under the Rules.md §4 1,000-word note cap with headroom for the curator to expand.
4. **Author** — dispatches one `general-purpose` Task subagent per concept in parallel batches of 5–10. Each subagent emits one research doc at `wiki/inbox/<slug>.md` for the next `/wiki-digest` to file.

### Sub-agent prompt contract

The author-phase prompt enforces:

- The canonical piped wiki-link form `[[other-slug|Other]]` only — bare `[[X]]` is rejected (see [[piped-wiki-link-contract|Piped Wiki Link Contract]]).
- Word band 200–700 with re-cluster fallback when a doc does not fit.
- Write-path safety — no writes to `wiki/<CATEGORY>/`, `wiki/MODULES/`, `wiki/_templates/`, `wiki/Rules.md`, `wiki/inbox/_session.md`, or `wiki/inbox/_archive/`.

### Resumability

Phase 1–3 outputs are kept on disk under `_docgen/` (gitignored). Re-runs skip those phases when the JSONs are present and fresh, so the expensive graph-building work is amortized across iterations. The `_docgen/` directory is added to `.gitignore` (see [[hook-runtime-state-gitignored|Hook Runtime State Gitignored]]).

### Boundaries

- The crawler does NOT load `wiki/Rules.md`. It is upstream of the curator.
- It does NOT touch `wiki/<CATEGORY>/`, `wiki/MODULES/`, `wiki/_templates/`, `_session.md`, or `_archive/`.
- It does NOT invoke `/wiki-digest` itself — the user runs digest manually after reviewing the dropped research docs.

### When to use

The Stop-hook + `/wiki-digest` loop is the lighter incremental path for session-by-session capture. Use `/wiki-code-crawler` when:

- Seeding a fresh wiki from a pre-existing codebase that has no coverage.
- Backfilling concept coverage after a large refactor that moved or renamed many symbols.

The crawler complements the two existing intake paths (Stop-hook `_session.md` capture + user-dropped research-doc `.md` files) by handling the bootstrap/backfill case.

## Related Notes

- [[wiki-digest-skill|Wiki Digest Skill]]
- [[wiki-curator-agent|Wiki Curator Agent]]
- [[research-doc-ingestion|Research Doc Ingestion]]
- [[hook-runtime-state-gitignored|Hook Runtime State Gitignored]]
- [[piped-wiki-link-contract|Piped Wiki Link Contract]]
