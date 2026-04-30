# llm-code-wiki

Claude Code skill + hook scaffolding that makes Claude auto-maintain an Obsidian-style codebase wiki AND auto-consult it before planning new work. A Stop hook nudges Claude to update a session "inbox" file as a state-of-the-world mirror of what's been built and decided; `/digest` consolidates the inbox into properly-filed wiki notes per `wiki/Rules.md`. A UserPromptSubmit hook detects planning-intent prompts and asks Claude to recall relevant prior decisions from the wiki before responding.

## What this gives you

- **Capture loop (write):** every Claude turn that edits/writes code triggers an inbox update. Atomic flat entries, state-of-world (not chronological log), self-pruning when code is deleted or superseded.
- **Consolidation loop (file):** `/digest` spawns a fresh-context curator sub-agent that routes inbox entries into `wiki/<CATEGORY>/` notes (ARCHITECTURE, FUNCTIONS, RESEARCH, SELF, DIAGRAMS), validates against `wiki/Rules.md`, archives the inbox before writing, runs a post-write link-validation pass, and updates `wiki/topic-index.md` (the recall navigation map).
- **Recall loop (read):** a UserPromptSubmit hook detects planning-intent prompts (plan, design, implement, refactor, etc.) and injects an instruction for Claude to consult the wiki via the `wiki-recall` sub-agent before responding. The agent uses `wiki/topic-index.md` as a navigation map, greps for keywords, filters for relevance, and returns only the useful context. Run `/recall <query>` to invoke recall manually.
- **One-command bootstrap:** `/wiki-install` creates the wiki/ folder, default Rules.md, default note template, topic-index seed, both hook registrations in settings.json, and CLAUDE.md documentation section — idempotently. Skip + log if anything already exists; never overwrite user content.

## Prerequisites

- **Claude Code** with skills + hooks support (current generation).
- **bash 4+** (macOS ships bash 3 by default; upgrade via `brew install bash` or use the non-fork fallback documented at `.claude/skills/digest/reference/non-fork-fallback.md`).
- **`jq`** — required only when merging the Stop hook into an existing `.claude/settings.json`. Install via `brew install jq` (macOS), `apt-get install jq` (Ubuntu/Debian/WSL), or [official downloads](https://jqlang.github.io/jq/download/). If `jq` is absent and a merge is needed, `/wiki-install` aborts with a pointer to `.claude/skills/wiki-install/SETTINGS-SNIPPET.md` for the manual fallback.
- **`CLAUDE_CODE_FORK_SUBAGENT=1`** — environment variable for the `/digest` sub-agent fork path. Without it, the digest skill falls back to inline execution per `.claude/skills/digest/reference/non-fork-fallback.md`. Set via shell profile (`export CLAUDE_CODE_FORK_SUBAGENT=1`).

## Installation

1. **Copy the `.claude/` tree** from this repo into your target project — plugin install, marketplace, manual copy, or symlink. Method is your choice; the `.claude/` directory is the distribution unit. It contains:
   - `.claude/skills/digest/` — the `/digest` slash command (filing path)
   - `.claude/skills/recall/` — the `/recall` slash command (recall path)
   - `.claude/skills/inbox-update/` — the per-turn inbox update skill
   - `.claude/skills/wiki-rules/` — thin pointer to your project's `wiki/Rules.md`
   - `.claude/skills/wiki-install/` — the bootstrap skill (this file's installer)
   - `.claude/agents/wiki-curator.md` — the curator sub-agent (read+write)
   - `.claude/agents/wiki-recall.md` — the recall sub-agent (read-only)
   - `.claude/hooks/inbox-stop.sh` — the Stop hook script (capture path)
   - `.claude/hooks/recall-prompt.sh` — the UserPromptSubmit hook script (recall path)

2. **Restart Claude Code** in your project directory. New top-level `.claude/skills/` directories require a session restart to register.

3. **Run `/wiki-install`** in Claude Code. The skill performs:
   - Precondition check (verifies the required `.claude/` files exist and both hooks are executable)
   - Creates `wiki/`, `wiki/_templates/note.md`, `wiki/Rules.md`, `wiki/inbox/`, `wiki/topic-index.md` (skipping anything that exists)
   - Merges both hook entries (Stop + UserPromptSubmit) into `.claude/settings.json` (or creates it fresh with both)
   - Appends an "Auto-maintained wiki" section to `CLAUDE.md` (skipping if already present)
   - Runs smoke tests: pipes synthetic stdin through each hook script, verifies the heartbeat / recall:fire log entries appear

4. **Take a normal Claude turn that edits a file** to confirm the Stop hook fires. After the turn, check:
   ```bash
   grep -c "^@ " wiki/inbox/_session.md      # should show ≥1 entry
   tail -5 .claude/inbox/.hook-log            # should show "fire" outcome
   ```

5. **Ask Claude to plan something** to confirm the recall hook fires. After submitting the prompt, check:
   ```bash
   tail -5 .claude/inbox/.hook-log            # should show "recall:fire" outcome
   ```
   On a fresh wiki the recall agent will report "Nothing relevant found" — that's expected until `/digest` files some notes.

6. **When you've done a stretch of work**, run `/digest` to consolidate the inbox into wiki notes (and refresh `wiki/topic-index.md` for future recall).

## Usage

- **Inbox file:** `wiki/inbox/_session.md` — the rolling per-project session state. Don't edit by hand; the inbox-update skill maintains it.
- **Topic index:** `wiki/topic-index.md` — the recall navigation map. Auto-maintained by `/digest` (curator Step 9). One bullet per topic with summary and file paths. Don't edit by hand — manual edits will be overwritten on the next digest.
- **`/digest`** — runs at logical review checkpoints. Produces a markdown plan (preview before write), validates against Rules.md, writes/edits/splits filed notes, then refreshes `wiki/topic-index.md`. Archives the inbox to `wiki/inbox/_archive/<timestamp>-session.md` BEFORE any write (crash-safe).
- **`/recall [query]`** — manually consult the wiki for context relevant to a topic or task. Use when the recall hook didn't fire (non-planning phrasing) or when you want a focused recall on a specific topic. With no args, recalls against the current conversation context.
- **`wiki/Rules.md`** — your wiki contract. The curator never modifies it autonomously. Rule-change suggestions surface as proposals in the digest plan.
- **Hook audit log:** `.claude/inbox/.hook-log` — append-only timestamped record of every hook fire. Entries from the Stop hook log the outcome directly (`entering`, `fire`, `noop`, `kill-switch`, etc.). Entries from the recall hook are prefixed with `recall:` (e.g., `recall:fire`, `recall:noop`, `recall:cooldown`).
- **Kill switches:**
  - `touch .claude/inbox/.disabled` — disables the Stop hook (capture path)
  - `touch .claude/inbox/.recall-disabled` — disables the UserPromptSubmit hook (recall path)
  - `rm` either file to re-enable independently

## Anti-features (deliberate non-goals)

- **No real-time wiki sync.** Updates happen at turn boundaries (Stop hook) and on manual `/digest`, not as code changes mid-stream.
- **No auto-digest.** `/digest` is manually triggered. Auto-digest mid-feature splits one logical change across multiple notes; `/digest` mid-feature is your choice.
- **No backfill.** This system maintains a wiki that's already populated or starts empty; it does NOT generate documentation from existing code retroactively.
- **No recall on every prompt.** The UserPromptSubmit hook pre-filters for planning-intent keywords; conversational prompts ("thanks", "what time is it") log `recall:noop` and skip recall. Use `/recall` for explicit on-demand recall.
- **No `wiki/Rules.md` modification.** The curator never edits the contract. Suggestions surface in plans for you to apply manually.
- **No `wiki/topic-index.md` hand-editing.** The index is auto-maintained by `/digest`; manual edits get overwritten on the next digest run. If a topic bullet is wrong, edit the underlying note's tags/title and re-run `/digest`.
- **No semantic-similarity duplicate detection.** Same-concept matching uses filename + title + tag overlap (no embeddings, no runtime). Recall uses keyword + index-bullet matching only — no embeddings.
- **No auto-commit.** The system writes files; you stage and commit them as you see fit.
- **No multi-user / collaborative concerns.** Single-developer tooling. Concurrent sessions writing the same inbox can race (a known gap; see "Concurrent-session safety" below).

## Known interactions

- **`disableSkillShellExecution`:** if a consumer enables this Claude Code setting, the digest skill's bash injections (`!` `cat ...`) silently produce empty strings. The wiki-curator agent has a fallback (re-globs the wiki tree itself if the input is empty), so digest still works — but cost rises.
- **`CLAUDE_CODE_FORK_SUBAGENT=0` or unset:** the digest skill cannot truly fork into a fresh-context sub-agent. The non-fork fallback at `.claude/skills/digest/reference/non-fork-fallback.md` covers this — the curator's protocol runs in the parent session. Correctness-equivalent; loses context isolation.
- **Git worktrees:** the `.claude/` tree is shared across worktrees in the same project. Concurrent sessions in different worktrees can race on `.hook-log` and `.fire-counter`. Acceptable single-developer; a known gap for multi-worktree workflows.
- **Pre-existing skills with our names:** if your project already has `wiki-install`, `inbox-update`, `digest`, `wiki-rules` skills or a `wiki-curator` agent, the upstream copy step (plugin install, manual copy) will overwrite them. The `/wiki-install` skill does NOT detect collisions — that's the upstream distribution mechanism's responsibility.

## Known gaps (v1)

- **Wiki ↔ codebase reconciliation.** No `/reconcile` skill — if you delete a function externally (in your editor, not via Claude), the corresponding wiki note becomes a "ghost note." Run periodic manual audits or accept some drift.
- **Concurrent-session safety.** Multiple Claude sessions writing to `wiki/inbox/_session.md` simultaneously can race. Single-developer tooling.

## Uninstall

There's no `/wiki-uninstall` skill in v1. To remove:

1. Delete `.claude/skills/{digest,recall,inbox-update,wiki-rules,wiki-install}/`.
2. Delete `.claude/agents/{wiki-curator,wiki-recall}.md`.
3. Delete `.claude/hooks/{inbox-stop,recall-prompt}.sh`.
4. Edit `.claude/settings.json` to remove the `inbox-stop.sh` entry from `hooks.Stop[0].hooks[]` and the `recall-prompt.sh` entry from `hooks.UserPromptSubmit[0].hooks[]`.
5. Delete `.claude/inbox/` (kill switches + heartbeat + counters).
6. Optionally delete or keep `wiki/` (your content, including `topic-index.md`).
7. Edit `CLAUDE.md` to remove the "## Auto-maintained wiki" section.

## Repository layout (this repo)

- `.claude/` — the distribution unit (skills, agents, hook script, settings.json)
- `wiki/` — this repo's own wiki, including the starter `Rules.md` and `_templates/note.md` that `/wiki-install` copies into target projects
- `INSTALL.md` (this file) — install + usage docs
- `README.md` — quick start
- `CLAUDE.md` — project context loaded into every Claude session in this repo

## See also

- `wiki/Rules.md` — the wiki contract this system enforces (your project gets a copy via `/wiki-install`).
- `wiki/_templates/note.md` — the canonical note schema.
- `.claude/skills/wiki-install/SETTINGS-SNIPPET.md` — manual settings.json merge fallback for users without `jq`.
