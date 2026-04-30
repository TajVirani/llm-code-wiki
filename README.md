# llm-code-wiki

A drop-in `.claude/` scaffold that makes Claude Code auto-maintain an Obsidian-style codebase wiki — without manual upkeep.

A Stop hook nudges Claude to keep a session **inbox** current as a state-of-the-world mirror of what's been built and decided. Run `/digest` at a review checkpoint to consolidate the inbox into properly-filed wiki notes per a project-defined `wiki/Rules.md` contract.

**Built for solo developers** who want code documentation that stays current — including correctly pruning entries when code is deleted or superseded within the same session.

## Quick start

1. Copy this repo's `.claude/` tree into your project.
2. Restart Claude Code in your project.
3. Run `/wiki-install`.
4. Edit a file in a normal Claude turn — watch `wiki/inbox/_session.md` populate.
5. Run `/digest` when you want filed notes under `wiki/`.

Full instructions, prerequisites, and uninstall steps: see [INSTALL.md](./INSTALL.md).

## What's in the box

- `.claude/skills/inbox-update/` — the per-turn inbox-update skill (invoked by the Stop hook)
- `.claude/skills/digest/` — the `/digest` slash command
- `.claude/skills/wiki-rules/` — thin pointer to your project's `wiki/Rules.md`
- `.claude/skills/wiki-install/` — the bootstrap skill (`/wiki-install`)
- `.claude/agents/wiki-curator.md` — the curator sub-agent
- `.claude/hooks/inbox-stop.sh` — the Stop hook script
- `.claude/settings.json` — Stop hook registration
- `wiki/Rules.md` — starter wiki contract (generic — edit to fit your project)
- `wiki/_templates/note.md` — canonical note template
