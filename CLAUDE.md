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

**Codebase crawl (bootstrap / backfill):** Run `/wiki-code-crawler` to seed `wiki/inbox/` from the live codebase. The skill maps the repo, builds a function-level import + call graph, clusters the code into concepts (200–700 words each), and emits one free-prose research doc per concept at `wiki/inbox/<slug>.md` — in parallel via `Task` subagents (`general-purpose`). Scratch artifacts (`_docgen/inventory.json`, `graph.json`, `concepts.json`) are kept on disk for resumability and gitignored. The crawler does NOT load `wiki/Rules.md`, does NOT touch `wiki/<CATEGORY>/`, `wiki/MODULES/`, `wiki/_templates/`, or `_session.md`/`_archive/`, and does NOT invoke `/wiki-digest` itself — its output is the input to the curator. Use it when seeding a fresh wiki from an existing codebase or backfilling concept coverage after a large refactor; for incremental session-by-session capture, the Stop-hook + `/wiki-digest` loop is the lighter path.

**Brainstorm-fallback (every-N-turns capture):** Pure design conversations produce no Edit/Write/MultiEdit tool calls, so the artifact-driven path no-ops. To prevent decisions from falling on the floor, the Stop hook also tracks a per-session brainstorm counter at `.claude/inbox/.turn-count`. Every `N` consecutive code-free turns (default 10, override via `LCW_BRAINSTORM_TURNS` env var), it fires `inbox-update` in **Brainstorm-fallback mode** with a different `reason` payload — telling Claude to scan the recent conversation for design decisions, named patterns, agreed file paths, and resolved trade-offs, capped at 5 entries per fire. The counter resets to 0 whenever a normal artifact-driven capture fires, so each brainstorm window starts fresh after a code change.

**Read path (recall):** A UserPromptSubmit hook (`recall-prompt.sh`) detects planning-intent prompts and asks Claude to consult the wiki via the `wiki-recall` sub-agent before responding. The agent uses `wiki/topic-index.md` as a navigation map, greps the wiki for keywords, filters for relevance, and returns only the useful context. Run `/wiki-recall <query>` to invoke recall manually.

**Wiki contract:** `wiki/Rules.md` defines all conventions (category folders, filename kebab-case, note template, ≤25-word summaries, 1,000-word note cap, Obsidian wiki-link syntax, `topic-index.md` auto-maintenance). The curator never modifies `wiki/Rules.md` autonomously — rule-change suggestions surface as proposals.

**Orientation layer (MODULES).** `wiki/MODULES/` contains ~6–10 cluster summaries — orienting overviews of major capability areas, each linking down to detail notes in ARCHITECTURE/FUNCTIONS/RESEARCH/DIAGRAMS. **`/wiki-modules` is the sole writer to `wiki/MODULES/` (per [ADR 0001](docs/adr/0001-modules-ownership-and-detection.md)).** Modules are auto-generated artifacts — manual edits do not survive a re-author. To improve a module's content, edit its children; the next `/wiki-modules` run synthesizes from them. Cluster detection uses three deterministic signals: **S1** filename prefix ≥3 detail notes (bootstrap); **S2** single-dominant-tag — every cluster member shares at least one common tag; **S3** external fan-in — ≥1 note outside the cluster links to ≥2 distinct cluster members. Clusters passing all three signals get one `module-author` subagent dispatched in parallel; each runs a pre-author depth gate (≥3 children, combined word count, ≥2 distinct non-dominant tags, ≥1 trigger-bearing child) and a post-author content gate (Purpose ≥50 words, Boundary lists ≥2 OUT items, Children ≥3 entries across ≥2 categories) before writing. Failed gates surface as structured rejections; the file is not written. The recall agent prefers `### Modules` bullets in `topic-index.md` for orienting queries ("what is", "how does", "overview of") and `### Notes` for narrow ones. Run `/wiki-modules` to refresh the orientation layer — it both writes and audits in one pass.

**Quick reference:**
- Inbox: `wiki/inbox/_session.md`
- Modules: `wiki/MODULES/`
- Module author + audit: run `/wiki-modules` (sole writer to `wiki/MODULES/`; re-authors all qualifying modules and audits existing ones)
- Research-doc drop zone: `wiki/inbox/<your-doc>.md` (any `.md` not named `_session.md` or starting with `_`)
- Codebase crawl: run `/wiki-code-crawler` to seed `wiki/inbox/` from live source (one research doc per concept; scratch in `_docgen/`)
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
