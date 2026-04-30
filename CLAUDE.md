# llm-code-wiki

This repo is the **source distribution** for the llm-code-wiki Claude Code scaffold — a Stop hook + skills + sub-agent that auto-maintain an Obsidian-style codebase wiki.

If you're working in this repo, you're either developing the scaffold itself or dogfooding it. The scaffold is also installed in this repo (Stop hook is registered, `/digest` is available, `wiki/` exists as a working wiki).

For installation into other projects: see [INSTALL.md](./INSTALL.md).

## Layout

- `.claude/` — the distribution unit (skills, agents, hook script, settings.json)
- `wiki/` — this repo's own wiki (uses the scaffold against itself)
- `INSTALL.md` — install + usage docs for consumers
- `README.md` — quick start

## Auto-maintained wiki

This project uses the llm-code-wiki system to keep a codebase wiki current without manual upkeep.

**How it works:** A Stop hook (`inbox-stop.sh`) fires after each Claude assistant turn and nudges Claude to update `wiki/inbox/_session.md` — a state-of-the-world snapshot of what was built and decided this session. Run `/digest` manually to consolidate the inbox into filed wiki notes under `wiki/`.

**Wiki contract:** `wiki/Rules.md` defines all conventions (category folders, filename kebab-case, note template, ≤25-word summaries, 1,000-word note cap, Obsidian wiki-link syntax). The curator never modifies `wiki/Rules.md` autonomously — rule-change suggestions surface as proposals.

**Quick reference:**
- Inbox: `wiki/inbox/_session.md`
- Digest: run `/digest` at a review checkpoint
- Rules contract: `wiki/Rules.md`
- Hook audit log: `.claude/inbox/.hook-log`
- Kill switch: `touch .claude/inbox/.disabled` (disables the Stop hook; `rm` to re-enable)
