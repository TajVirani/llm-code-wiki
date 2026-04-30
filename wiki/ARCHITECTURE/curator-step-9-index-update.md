
**Summary**: Curator Step 9 rebuilds `wiki/topic-index.md` after the post-write link audit so recall sees the digest's new, edited, split, and deprecated notes.
**Tags**: #curator #digest #index #architecture
**Created**: 2026-04-30T00:00:00+00:00
**Last Updated**: 2026-04-30T00:00:00+00:00

---

## Content

The `wiki-curator` protocol has a Step 9 that runs *after* the post-write link audit (Step 8) and *only* on topics affected by the current digest's writes.

**Behavior:**

- New CREATE → append a bullet for the topic.
- EDIT touching scope → update the existing bullet's summary if scope materially expanded; otherwise leave the summary untouched and just refresh the file list.
- SPLIT → replace the parent topic bullet with bullets for each split, paths updated.
- Deprecated note → remove its path from the bullet (or remove the whole bullet if no paths remain).
- Dedupe and alphabetize for stable diffs.
- Bump `Last Updated`.

**Why last:** Step 9 runs after the link audit so it sees the post-rewrite state of the wiki. Running earlier would index stale titles that the split-backlink rewrite would invalidate.

**Why scoped:** only topics affected by this digest are touched. A whole-wiki rebuild every digest would churn the index even when nothing changed and would fight against the "preserve existing summaries" rule.

## Related Notes

- [[Topic Index As Recall Map]]
- [[Recall Path]]
