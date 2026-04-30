
**Summary**: Read-only sub-agent that consults the wiki via topic-index plus grep, applies a relevance filter, and returns a compact context payload citing notes by title.
**Tags**: #agent #recall #read-only #architecture
**Created**: 2026-04-30T00:00:00+00:00
**Last Updated**: 2026-04-30T00:00:00+00:00

---

## Content

**Path:** `.claude/agents/wiki-recall.md`
**Tools:** Read, Glob, Grep only — no Write/Edit. The read-only constraint is enforced by tool allowlist, not just by convention.

**Protocol:**

1. Read `wiki/topic-index.md` first as the navigation map.
2. Extract 3–8 keywords from the task.
3. Build a primary candidate set from index bullets whose summary or files match the keywords.
4. Grep `wiki/` for additional hits the index may have missed.
5. Apply a relevance filter — drop superficial overlap, drop notes tagged `#deprecated`, drop superseded or stub notes.
6. Return a ≤400-word summary citing notes by `[[Title]]` so the parent agent can re-read full notes if needed.

**Why read-only:** recall must never mutate the wiki. The wiki is mutated only via the inbox → digest path. Mixing read and write paths in one agent invites accidental writes during a recall.

**Why topic-index first:** grep alone over `wiki/**` is fine for small wikis but degrades as note count grows. The index is a curated, summary-bearing entry point that lets the agent disqualify whole topics fast.

## Related Notes

- [[Recall Path]]
- [[Recall Prompt Hook]]
- [[Recall Skill]]
- [[Topic Index As Recall Map]]
