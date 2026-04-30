
**Summary**: Wiki-digest Step 6 resets `wiki/inbox/_session.md` to the empty template after curator writes succeed and the post-write link audit passes.
**Tags**: #digest #lifecycle #inbox #architecture

**Created**: 2026-04-30T00:00:00+00:00
**Last Updated**: 2026-04-30T00:00:00+00:00

---

## Content

The `wiki-digest` skill body resets `wiki/inbox/_session.md` to the canonical empty template — header, `Status`, `Purpose`, and a `---` separator — as Step 6 of its lifecycle. The reset runs only after the curator's writes succeed and the post-write link audit completes without unrecoverable errors.

**Why reset:** filed entries no longer belong in the live inbox. The inbox is a derived view of work-not-yet-filed; once entries are archived AND filed into `wiki/<CATEGORY>/` notes, leaving them in the live inbox would cause the next session's `inbox-update` to see stale state and the next `/wiki-digest` to re-process them (idempotent via same-concept detection, but wasteful and noisy).

**Why archive-first:** the Step 2 archive (LIFE-02 / LIFE-03 / D-14) preserves the pre-digest inbox state regardless of what Step 6 does. The reset is a normal-path lifecycle action; the archive is the crash-safety net.

**When the reset is skipped:** if the curator aborts mid-run or the audit reports unrecoverable errors, the live inbox is preserved so the user can retry. The archive still exists either way.

**Lifecycle ordering:** `inbox-update` appends entries → `/wiki-digest` archives, files, and resets → `inbox-update` appends fresh entries from the next turn. Step 6 is the handoff point between the two skills.

## Related Notes

- [[Curator Step 9 Index Update]]
- [[Topic Index As Recall Map]]
