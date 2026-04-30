
**Summary**: Lifecycle for ingesting user-dropped `.md` research docs from `wiki/inbox/` into filed wiki notes, with interactive conflict resolution against read-only `wiki/RESEARCH/`.
**Tags**: #architecture #digest #ingestion
**Created**: 2026-04-30T16:09:00+00:00
**Last Updated**: 2026-04-30T16:09:00+00:00

---

## Content

**Drop zone.** The user drops any `.md` file (other than `_session.md` and any underscore-prefixed file) into the root of `wiki/inbox/`. Examples: research notes, design docs, external references — any free-prose markdown the user wants treated as a source-of-truth and decomposed into filed wiki notes.

**Lifecycle on the next `/wiki-digest` run:**

1. **Discovery.** The skill body lists `*.md` files in `wiki/inbox/` excluding `_session.md` and underscore-prefixed files.
2. **Archive (before any write).** Each doc is copied to `wiki/inbox/_archive/<TS>-research-<filename>.md` with the same shared timestamp as the session-inbox archive. This is the crash-safety net.
3. **Curator payload.** The skill body emits a delimited block per discovered file (`=== RESEARCH-DOC: <path> === … === END RESEARCH-DOC ===`) and passes the payload to the curator alongside the session-inbox content, the wiki tree, and `wiki/Rules.md`.
4. **Decomposition.** The curator reads each doc in full and applies Rules.md §6: decide single-concept vs multi-concept, draft `{slug, title, category, tags, summary}` per concept, validate against the template, and produce CREATE / EDIT / SPLIT / OVERRIDE rows in a source-grouped plan.
5. **Conflict surfacing.** For any concept that collides with an existing read-only `wiki/RESEARCH/` note, the curator does *not* auto-edit. It emits a `CONFLICT-ON-RESEARCH` row and triggers Step 7a interactive resolution — surfacing both the existing content and the proposed content side-by-side and waiting for explicit user instructions (`replace` / `append` / `skip` / free-form) before any write to `wiki/RESEARCH/`.
6. **Source cleanup.** On success, the skill body deletes the consumed source file from `wiki/inbox/`. Any doc whose concepts had unresolved conflicts (user picked `skip`) or apply errors is preserved for retry.

**Why interactive on RESEARCH/.** RESEARCH/ holds curated domain notes that the curator would otherwise have no signal to safely overwrite. An automated diff-and-merge could silently destroy human-authored derivations. The interactive surface forces a deliberate decision per conflict.

**Documentation surface.** Documented in `CLAUDE.md` (Auto-maintained wiki section), `INSTALL.md` (user-facing usage), and `wiki/Rules.md` §6/§9 (the contract).

## Related Notes

- [[Wiki Digest Skill]]
- [[Wiki Curator Agent]]
- [[Update Flow]]
