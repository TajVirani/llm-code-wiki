# llm-code-wiki

This repo is the **source distribution** for the llm-code-wiki Claude Code scaffold — Stop + UserPromptSubmit hooks + skills + sub-agents that auto-maintain an Obsidian-style codebase wiki AND auto-consult it before planning new work.

If you're working in this repo, you're either developing the scaffold itself or dogfooding it. The scaffold is also installed in this repo (both hooks are registered, `/wiki-digest` and `/wiki-recall` are available, `wiki/` exists as a working wiki, `wiki/topic-index.md` seeds the recall map).

For installation into other projects: see [INSTALL.md](./INSTALL.md).

## Layout

- `.claude/` — the distribution unit (skills, agents, hook script, settings.json)
- `wiki/` — this repo's own wiki (uses the scaffold against itself)
- `INSTALL.md` — install + usage docs for consumers
- `README.md` — quick start

## Auto-maintained wiki

This project uses the llm-code-wiki system to keep a codebase wiki current without manual upkeep, and to recall prior decisions automatically when planning new work.

**Write path (capture):** A Stop hook (`inbox-stop.sh`) fires after each Claude assistant turn and nudges Claude to update `wiki/inbox/_session.md` — a state-of-the-world snapshot of what was built and decided this session. Run `/wiki-digest` manually to consolidate the inbox into filed wiki notes under `wiki/` (and refresh `wiki/topic-index.md` for recall).

**Brainstorm-fallback (every-N-turns capture):** Pure design conversations produce no Edit/Write/MultiEdit tool calls, so the artifact-driven path no-ops. To prevent decisions from falling on the floor, the Stop hook also tracks a per-session brainstorm counter at `.claude/inbox/.turn-count`. Every `N` consecutive code-free turns (default 10, override via `LCW_BRAINSTORM_TURNS` env var), it fires `inbox-update` in **Brainstorm-fallback mode** with a different `reason` payload — telling Claude to scan the recent conversation for design decisions, named patterns, agreed file paths, and resolved trade-offs, capped at 5 entries per fire. The counter resets to 0 whenever a normal artifact-driven capture fires, so each brainstorm window starts fresh after a code change.

**Read path (recall):** A UserPromptSubmit hook (`recall-prompt.sh`) detects planning-intent prompts and asks Claude to consult the wiki via the `wiki-recall` sub-agent before responding. The agent uses `wiki/topic-index.md` as a navigation map, greps the wiki for keywords, filters for relevance, and returns only the useful context. Run `/wiki-recall <query>` to invoke recall manually.

**Wiki contract:** `wiki/Rules.md` defines all conventions (category folders, filename kebab-case, note template, ≤25-word summaries, 1,000-word note cap, Obsidian wiki-link syntax, `topic-index.md` auto-maintenance). The curator never modifies `wiki/Rules.md` autonomously — rule-change suggestions surface as proposals.

**Quick reference:**
- Inbox: `wiki/inbox/_session.md`
- Topic index (recall map): `wiki/topic-index.md` (auto-maintained — do not edit by hand)
- Digest: run `/wiki-digest` at a review checkpoint
- Recall: run `/wiki-recall <query>` to consult the wiki on demand
- Rules contract: `wiki/Rules.md`
- Hook audit log: `.claude/inbox/.hook-log` (`recall:` entries from the recall hook; `turncount-pending`/`turncount-fire` entries from the brainstorm-fallback path)
- Brainstorm counter state: `.claude/inbox/.turn-count` (`SESSION_ID COUNT`; resets on session change or normal capture)
- Brainstorm cadence override: `LCW_BRAINSTORM_TURNS` env var (default 10)
- Kill switches:
  - `touch .claude/inbox/.disabled` — disables the Stop hook (capture path, including brainstorm-fallback)
  - `touch .claude/inbox/.recall-disabled` — disables the UserPromptSubmit hook (recall path)
  - `rm` either file to re-enable
