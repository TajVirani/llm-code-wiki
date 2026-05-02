
**Summary**: Skill invoked by the Stop hook to maintain `wiki/inbox/_session.md` as a derived view of codebase state, with a brainstorm-fallback mode.
**Tags**: #skill #capture #brainstorm #function
**Created**: 2026-04-30T16:09:00+00:00
**Last Updated**: 2026-04-30T16:32:00+00:00

---

## Content

**Path:** `.claude/skills/inbox-update/SKILL.md`
**Invoked by:** the `inbox-stop` Stop hook.
**Purpose:** maintain `wiki/inbox/_session.md` as a state-of-the-world derived view of what exists in the codebase this session.

**Default mode (artifact-driven):**

1. Build a scratch list from this turn's `Edit` / `Write` / `MultiEdit` / `Bash` file operations.
2. No-op if the scratch list is empty (D-09 — never write an empty update).
3. Reconcile created / modified / deleted entries against the existing inbox using a `^@ CATEGORY::slug` grep to locate matching handle lines.
4. Trigger a full sweep when entry count exceeds 50, or before a `/wiki-digest` run.

**Brainstorm-fallback mode:**

- Activates when the injected `reason` parameter starts with the literal string `Brainstorm-fallback`.
- Bypasses the no-op guard (the artifact list is empty by definition in this mode).
- Scans the recent conversation (last ~N exchanges) for: explicit design decisions, agreed file paths, named patterns, resolved trade-offs, requirements, open questions.
- Writes ≤5 entries per fire as `RESEARCH::*` handles with `path = —` (no codebase artifact backs them).
- Dedupes by slug — re-emitting the same slug within a session is silently dropped.
- Skips: speculation, restatements of prior turns, meta-talk about the conversation itself, process chatter ("let me check…", "I'll do X").

**Output:** appends or reconciles handle-line entries (`@ CATEGORY::slug  •  path-or-em-dash  •  #tags` followed by a body paragraph) inside `wiki/inbox/_session.md`.

## Related Notes

- [[inbox-stop-hook|Inbox Stop Hook]]
- [[brainstorm-fallback-cadence|Brainstorm Fallback Cadence]]
