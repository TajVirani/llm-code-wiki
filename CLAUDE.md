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

**Research-doc ingestion:** Drop any `.md` file (research notes, design docs, external references) directly into `wiki/inbox/` — anything other than `_session.md` and underscore-prefixed files. On the next `/wiki-digest`, the curator reads each dropped file in full, decomposes it into one or more concept notes (single-concept docs produce one note; multi-concept docs produce one per concept), routes each to the right category, validates against `wiki/Rules.md`, and applies the same chunking + linking + same-concept-detection logic used for `_session.md` entries. After a successful digest, each consumed research doc is archived to `wiki/inbox/_archive/<TIMESTAMP>-research-<filename>.md` and removed from `wiki/inbox/`. If a research-doc concept collides with an existing read-only `wiki/RESEARCH/` note, the curator surfaces both contents side-by-side and asks for explicit instructions (replace / append / skip / free-form) before any write — research docs do not silently overwrite curated research.

**Brainstorm-fallback (every-N-turns capture):** Pure design conversations produce no Edit/Write/MultiEdit tool calls, so the artifact-driven path no-ops. To prevent decisions from falling on the floor, the Stop hook also tracks a per-session brainstorm counter at `.claude/inbox/.turn-count`. Every `N` consecutive code-free turns (default 10, override via `LCW_BRAINSTORM_TURNS` env var), it fires `inbox-update` in **Brainstorm-fallback mode** with a different `reason` payload — telling Claude to scan the recent conversation for design decisions, named patterns, agreed file paths, and resolved trade-offs, capped at 5 entries per fire. The counter resets to 0 whenever a normal artifact-driven capture fires, so each brainstorm window starts fresh after a code change.

**Read path (recall):** A UserPromptSubmit hook (`recall-prompt.sh`) detects planning-intent prompts and asks Claude to consult the wiki via the `wiki-recall` sub-agent before responding. The agent uses `wiki/topic-index.md` as a navigation map, greps the wiki for keywords, filters for relevance, and returns only the useful context. Run `/wiki-recall <query>` to invoke recall manually.

**Wiki contract:** `wiki/Rules.md` defines all conventions (category folders, filename kebab-case, note template, ≤25-word summaries, 1,000-word note cap, Obsidian wiki-link syntax, `topic-index.md` auto-maintenance). The curator never modifies `wiki/Rules.md` autonomously — rule-change suggestions surface as proposals.

**Orientation layer (MODULES).** `wiki/MODULES/` contains ~6–10 cluster summaries — orienting overviews of major capability areas, each linking down to detail notes in ARCHITECTURE/FUNCTIONS/RESEARCH/DIAGRAMS. The curator gates every MODULES note through a deletion-test (≥5 of 7 inner H2s — `Purpose` + `Boundary` mandatory plus ≥3 of {Triggers, Storage, Behavior, Rules & Invariants, Children}); shallow modules surface as `SHALLOW-MODULE` plan rows instead of being written. Module-cluster shape is detected by trigger 7 (S1 ≥3 wiki-link/basename references; S2 ≥3 of 4 keyword categories — trigger/storage/executor/outcome; S3 ≥2 distinct dominant domain tags; S4 word band 150–1000). The recall agent prefers `### Modules` bullets in `topic-index.md` for orienting queries ("what is", "how does", "overview of") and `### Notes` for narrow ones. Run `/wiki-modules` for a read-only scan of cluster coverage (proposals + audit).

**Quick reference:**
- Inbox: `wiki/inbox/_session.md`
- Modules: `wiki/MODULES/`
- Module audit & synth: run `/wiki-modules` (read-only)
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
