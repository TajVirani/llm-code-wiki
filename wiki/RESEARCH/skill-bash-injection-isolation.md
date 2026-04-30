
**Summary**: Claude Code `!`-prefixed bash injections in skill bodies do not share shell state across blocks; each block is an independent shell.
**Tags**: #skill #bash #pattern #research
**Created**: 2026-04-30T00:00:00+00:00
**Last Updated**: 2026-04-30T00:00:00+00:00

---

## Content

**Discovery:** Claude Code's `!`-prefixed bash injections in skill bodies do NOT share shell state across blocks. Each `!`...`!` invocation is an independent shell — variables exported in one block are not visible to subsequent blocks.

**Implication:** prose-level descriptions like "set `INBOX_PATH` once at the top of the skill" are documentation-only — they do not affect runtime. Every block that needs a derived value must compute it inline.

**Pattern (used in `wiki-digest`):** resolve the value at the top of every block.

```bash
P="${ARGUMENTS:-wiki/inbox/_session.md}"
```

The `wiki-digest` skill applies this pattern in each of its three bash injections (inbox existence check, archive, post-write audit).

**Anti-pattern:** computing a path once in a leading block and referencing the bare variable name in later blocks. The variable is unset in the second shell and the command silently operates on the wrong path (often `wiki/inbox/_session.md` where the user expected a custom argument path, or vice versa).

**Why this matters:** silent shell isolation is a particularly nasty class of bug because the skill *runs* — it just runs against the wrong inputs. Defensive inline resolution is the only reliable fix until/unless Claude Code documents shared shell state.

## Related Notes

- [[Recall Path]]
