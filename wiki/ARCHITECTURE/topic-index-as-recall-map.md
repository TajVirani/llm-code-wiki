
**Summary**: `wiki/topic-index.md` is a flat greppable bullet list — kebab-case topic, ≤25-word summary, comma-separated paths — used as the recall navigation map.
**Tags**: #recall #index #navigation #architecture
**Created**: 2026-04-30T00:00:00+00:00
**Last Updated**: 2026-04-30T00:00:00+00:00

---

## Content

**Path:** `wiki/topic-index.md`

**Format:** flat greppable bullet list. Each bullet has three parts:

1. Bold topic name in kebab-case (e.g. `**recall-path**`).
2. A ≤25-word summary describing what the topic *covers* (not what each file says individually).
3. A comma-separated list of relative file paths from `wiki/` root.

**Crucial: no `[[wiki-link]]` syntax.** Explicit relative paths so grep returns precise hits during recall. Wiki-links would force the recall agent to title-resolve before it could open the file.

**Maintenance:** auto-rebuilt by the curator's Step 9 at the end of every `/wiki-digest`. Bullets are appended preserving existing summaries unless scope materially expanded; deduped; alphabetized for stable diffs. `Last Updated` is bumped.

**Hard cap: 100 entries.** Beyond that the index stops being a fast pre-filter and becomes a second wiki to navigate. If the cap is approached, split topics or retire stubs.

**Manual edits will be overwritten** on the next digest run — this is intentional. The index is a derived view; ground truth lives in the filed notes.

## Related Notes

- [[Recall Path]]
- [[Wiki Recall Subagent]]
- [[Curator Step 9 Index Update]]
