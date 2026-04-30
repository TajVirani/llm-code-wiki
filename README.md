# llm-code-wiki

A drop-in `.claude/` scaffold that makes Claude Code auto-maintain an Obsidian-style codebase wiki AND auto-consult it before planning new work — without manual upkeep.

- A **Stop hook** nudges Claude to keep a session **inbox** current as a state-of-the-world mirror of what's been built and decided. Run `/wiki-digest` at a review checkpoint to consolidate the inbox into properly-filed wiki notes per a project-defined `wiki/Rules.md` contract.
- A **UserPromptSubmit hook** detects planning-intent prompts and asks Claude to consult the wiki via a read-only `wiki-recall` sub-agent before responding. The agent uses `wiki/topic-index.md` as a navigation map, greps the corpus for keywords, filters for relevance, and returns only the useful context. Run `/wiki-recall <query>` for on-demand recall.
- A versioned **update flow** — once installed, run `/wiki-update` to pull upstream scaffold improvements. The command compares your installed version, shows the changelog, fetches updated `.claude/` files, re-merges `.claude/settings.json` without clobbering your other hooks, and leaves `wiki/Rules.md`, `wiki/_templates/`, `wiki/topic-index.md` untouched.

**Built for solo developers** who want code documentation that stays current — including correctly pruning entries when code is deleted or superseded within the same session — and who want prior decisions to surface automatically when planning new work.

## Quick start

1. In your target project, run `claude` and paste:
   > Install the llm-code-wiki scaffold from `https://github.com/TajVirani/llm-code-wiki`.
   > Follow the "Remote install — for Claude" section of its INSTALL.md exactly.

   Claude fetches the distribution manifest, copies the scaffold files, and runs the bootstrap inline.
2. Restart Claude Code so `/wiki-digest` and `/wiki-recall` register as slash commands. (Hooks themselves work without restart.)
3. Edit a file in a normal Claude turn — watch `wiki/inbox/_session.md` populate.
4. Run `/wiki-digest` when you want filed notes under `wiki/` (also refreshes `wiki/topic-index.md`).
5. Ask Claude to plan something — the recall hook will fire and consult the wiki automatically.

Prefer to copy files yourself? See the **Manual install** section in [INSTALL.md](./INSTALL.md). Full prerequisites and uninstall steps are there too.

## What's in the box

- `.claude/skills/inbox-update/` — the per-turn inbox-update skill (invoked by the Stop hook)
- `.claude/skills/wiki-digest/` — the `/wiki-digest` slash command (filing path)
- `.claude/skills/wiki-recall/` — the `/wiki-recall` slash command (recall path)
- `.claude/skills/wiki-rules/` — thin pointer to your project's `wiki/Rules.md`
- `.claude/skills/wiki-install/` — the bootstrap skill (`/wiki-install`)
- `.claude/skills/wiki-update/` — the upstream-update skill (`/wiki-update`)
- `.claude/agents/wiki-curator.md` — the curator sub-agent (read+write)
- `.claude/agents/wiki-recall.md` — the recall sub-agent (read-only)
- `.claude/hooks/inbox-stop.sh` — the Stop hook script (capture path)
- `.claude/hooks/recall-prompt.sh` — the UserPromptSubmit hook script (recall path)
- `.claude/settings.json` — Stop + UserPromptSubmit hook registrations
- `wiki/Rules.md` — starter wiki contract (generic — edit to fit your project)
- `wiki/_templates/note.md` — canonical note template
- `wiki/topic-index.md` — recall navigation map (auto-maintained by `/wiki-digest`)
