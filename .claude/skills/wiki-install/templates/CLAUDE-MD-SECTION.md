## Auto-maintained wiki

This project uses the llm-code-wiki system to keep a codebase wiki current without manual upkeep, and to recall prior decisions automatically when planning new work.

**Write path (capture):** A Stop hook (`inbox-stop.sh`) fires after each Claude assistant turn and nudges Claude to update `wiki/inbox/_session.md` — a state-of-the-world snapshot of what was built and decided this session. Run `/wiki-digest` manually to consolidate the inbox into filed wiki notes under `wiki/` (and refresh `wiki/topic-index.md` for recall).

**Research-doc ingestion:** Drop any `.md` file (research notes, design docs, external references) directly into `wiki/inbox/` — anything other than `_session.md` and underscore-prefixed files. On the next `/wiki-digest`, the curator reads each dropped file in full, decomposes it into one or more concept notes, routes each to the right category, and applies the same chunking + linking + same-concept-detection logic used for `_session.md` entries. Consumed docs are archived to `wiki/inbox/_archive/<TS>-research-<filename>.md` and removed from `wiki/inbox/`. Conflicts with existing read-only `wiki/RESEARCH/` notes prompt for explicit instructions before any write — research docs do not silently overwrite curated research.

**Brainstorm-fallback (every-N-turns capture):** Pure design conversations produce no Edit/Write/MultiEdit tool calls, so the artifact-driven path no-ops. To prevent decisions from falling on the floor, the Stop hook also tracks a per-session brainstorm counter at `.claude/inbox/.turn-count`. Every `N` consecutive code-free turns (default 10, override via `LCW_BRAINSTORM_TURNS` env var), it fires `inbox-update` in **Brainstorm-fallback mode** — telling Claude to scan the recent conversation for design decisions, named patterns, agreed file paths, and resolved trade-offs, capped at 5 entries per fire. The counter resets to 0 whenever a normal artifact-driven capture fires.

**Read path (recall):** A UserPromptSubmit hook (`recall-prompt.sh`) detects planning-intent prompts and asks Claude to consult the wiki via the `wiki-recall` sub-agent before responding. The agent uses `wiki/topic-index.md` as a navigation map, greps the wiki for keywords, filters for relevance, and returns only the useful context. Run `/wiki-recall <query>` to invoke recall manually.

**Wiki contract:** `wiki/Rules.md` defines all conventions (category folders, filename kebab-case, note template, ≤25-word summaries, 1,000-word note cap, Obsidian wiki-link syntax, `topic-index.md` auto-maintenance). The curator never modifies `wiki/Rules.md` autonomously — rule-change suggestions surface as proposals.

**Orientation layer (MODULES).** `wiki/MODULES/` holds ~6–10 cluster summaries — orienting overviews of major capability areas that link down to detail notes in ARCHITECTURE/FUNCTIONS/RESEARCH/DIAGRAMS. **`/wiki-modules` is the sole writer to `wiki/MODULES/`.** Modules are auto-generated artifacts — manual edits do not survive a re-author. To improve a module's content, edit its children; the next `/wiki-modules` run synthesizes from them. Cluster detection uses three deterministic signals (filename prefix, single-dominant-tag, external fan-in); qualifying clusters are dispatched in parallel to a `module-author` subagent that runs pre-author and post-author depth gates before writing. The recall agent prefers `### Modules` bullets in `topic-index.md` for orienting queries ("what is", "how does", "overview of") and `### Notes` for narrow ones. Run `/wiki-modules` to refresh the orientation layer (it both writes and audits in one pass).

**Explicit gaps (v1):** No real-time wiki sync, no auto-digest, no backfill from existing code, no wiki↔codebase reconciliation (`/reconcile` is deferred to v2). The inbox captures only what Claude edits in the current session.

**Quick reference:**
- Inbox: `wiki/inbox/_session.md`
- Modules: `wiki/MODULES/`
- Module author + audit: run `/wiki-modules` (sole writer to `wiki/MODULES/`; re-authors all qualifying modules and audits existing ones)
- Research-doc drop zone: `wiki/inbox/<your-doc>.md` (any `.md` not named `_session.md` or starting with `_`)
- Inbox archive: `wiki/inbox/_archive/<TS>-session.md` and `<TS>-research-<filename>.md`
- Topic index (recall map): `wiki/topic-index.md` (auto-maintained — do not edit by hand; H3 split: `### Modules` orientation, `### Notes` detail)
- Digest: run `/wiki-digest` at a review checkpoint (consumes both session inbox and any research docs)
- Recall: run `/wiki-recall <query>` to consult the wiki on demand
- Update: run `/wiki-update` to pull upstream improvements (compares `.claude/llm-code-wiki.version` against upstream `VERSION`, shows changelog, refreshes `.claude/` while leaving `wiki/Rules.md`, `wiki/_templates/`, `wiki/topic-index.md` alone)
- Rules contract: `wiki/Rules.md`
- Hook audit log: `.claude/inbox/.hook-log` (`recall:` entries from the recall hook; `turncount-pending`/`turncount-fire` entries from the brainstorm-fallback path)
- Brainstorm counter state: `.claude/inbox/.turn-count` (`SESSION_ID COUNT`; resets on session change or normal capture)
- Brainstorm cadence override: `LCW_BRAINSTORM_TURNS` env var (default 10)
- Kill switches:
  - `touch .claude/inbox/.disabled` — disables the Stop hook (capture path, including brainstorm-fallback)
  - `touch .claude/inbox/.recall-disabled` — disables the UserPromptSubmit hook (recall path)
  - `rm` either file to re-enable
