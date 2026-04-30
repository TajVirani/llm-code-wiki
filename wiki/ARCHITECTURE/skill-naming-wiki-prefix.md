
**Summary**: User-facing wiki skills and slash commands take a `wiki-` prefix; `inbox-update` is the only documented exception.
**Tags**: #skill #convention #naming #architecture
**Created**: 2026-04-30T00:00:00+00:00
**Last Updated**: 2026-04-30T12:00:00+00:00

---

## Content

**Convention:** skills and slash commands that operate on the wiki use a `wiki-` prefix.

**Conformant:**

- `/wiki-install`
- `/wiki-digest`
- `/wiki-recall`
- `wiki-rules` skill

**Documented exceptions:**

- `inbox-update` — invoked only by the Stop hook, has no slash command surface, so the prefix would be noise.

**Skill/agent name overlap is allowed.** The `wiki-recall` skill (folder `.claude/skills/wiki-recall/`) and the `wiki-recall` sub-agent (file `.claude/agents/wiki-recall.md`) share the name string but live in independent registries — there is no collision. The skill's `agent: wiki-recall` frontmatter resolves to the agent file via the agent registry; the slash-command registrar uses the skill's frontmatter `name:`. Both can be `wiki-recall` and Claude Code dispatches correctly.

**Rule of thumb:** if a human types it (slash command) or a curator/agent loads it by name as a wiki-scoped skill, it gets the `wiki-` prefix. Internal-only skills that fire from hooks can omit it.

**Why a prefix at all:** the scaffold is meant to coexist with non-wiki skills in the same `.claude/` directory of a host project. The prefix makes the wiki surface area visually grep-able and prevents accidental name collisions with project-specific skills.

**Rename mechanics (recall → wiki-recall):** the recall skill was renamed to `wiki-recall` via `git mv .claude/skills/recall/ .claude/skills/wiki-recall/`. The skill's `SKILL.md` frontmatter `name:` was updated to `wiki-recall`, and the recall hook's wiki-only filter regex was updated to match `/wiki-recall` (this avoids a recursive recall fire when the user invokes the slash command). The hook script filename — `recall-prompt.sh` — was *not* renamed because it is internal scaffolding rather than a user-typed surface; the `wiki-` prefix rule applies only to the typed surface. The previously-documented "recall is a wiki-prefix exception" is therefore obsolete and removed: only `inbox-update` remains an exception.

## Related Notes

- [[Recall Skill]]
- [[Recall Path]]
