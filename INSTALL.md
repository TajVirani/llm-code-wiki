# llm-code-wiki

Claude Code skill + hook scaffolding that makes Claude auto-maintain an Obsidian-style codebase wiki AND auto-consult it before planning new work. A Stop hook nudges Claude to update a session "inbox" file as a state-of-the-world mirror of what's been built and decided; `/wiki-digest` consolidates the inbox into properly-filed wiki notes per `wiki/Rules.md`. A UserPromptSubmit hook detects planning-intent prompts and asks Claude to recall relevant prior decisions from the wiki before responding.

## What this gives you

- **Capture loop (write):** every Claude turn that edits/writes code triggers an inbox update. Atomic flat entries, state-of-world (not chronological log), self-pruning when code is deleted or superseded.
- **Consolidation loop (file):** `/wiki-digest` spawns a fresh-context curator sub-agent that routes inbox entries into `wiki/<CATEGORY>/` notes (ARCHITECTURE, FUNCTIONS, RESEARCH, SELF, DIAGRAMS), validates against `wiki/Rules.md`, archives the inbox before writing, runs a post-write link-validation pass, and updates `wiki/topic-index.md` (the recall navigation map).
- **Research-doc ingestion (drop + digest):** Drop any `.md` file directly into `wiki/inbox/` — research notes, design docs, external references, anything not named `_session.md` and not underscore-prefixed. On the next `/wiki-digest`, the curator reads each dropped file in full, decomposes it into one or more concept notes (one per distinct concept for multi-concept docs), routes each to the right category, and applies the same conflict-detection / split / linking logic as session-inbox entries. Consumed docs are archived to `wiki/inbox/_archive/<TS>-research-<filename>.md` and removed from `wiki/inbox/` after success. Conflicts with read-only `wiki/RESEARCH/` notes prompt for explicit user instructions (replace / append / skip / free-form) before any write — never silent overwrite.
- **Recall loop (read):** a UserPromptSubmit hook detects planning-intent prompts (plan, design, implement, refactor, etc.) and injects an instruction for Claude to consult the wiki via the `wiki-recall` sub-agent before responding. The agent uses `wiki/topic-index.md` as a navigation map, greps for keywords, filters for relevance, and returns only the useful context. Run `/wiki-recall <query>` to invoke recall manually.
- **One-command bootstrap:** `/wiki-install` creates the wiki/ folder, default Rules.md, default note template, topic-index seed, both hook registrations in settings.json, and CLAUDE.md documentation section — idempotently. Skip + log if anything already exists; never overwrite user content.

## Prerequisites

- **Claude Code** with skills + hooks support (current generation).
- **bash 4+** (macOS ships bash 3 by default; upgrade via `brew install bash` or use the non-fork fallback documented at `.claude/skills/wiki-digest/reference/non-fork-fallback.md`).
- **`jq`** — required only when merging the Stop hook into an existing `.claude/settings.json`. Install via `brew install jq` (macOS), `apt-get install jq` (Ubuntu/Debian/WSL), or [official downloads](https://jqlang.github.io/jq/download/). If `jq` is absent and a merge is needed, `/wiki-install` aborts with a pointer to `.claude/skills/wiki-install/SETTINGS-SNIPPET.md` for the manual fallback.
- **`ripgrep`** (`rg`) — required by Claude Code's `Glob` and `Grep` tools, which the wiki-curator and wiki-recall sub-agents use during `/wiki-digest` and `/wiki-recall`. Install via `brew install ripgrep` (macOS), `apt-get install ripgrep` (Ubuntu/Debian/WSL), or [official downloads](https://github.com/BurntSushi/ripgrep#installation). Without it, agents fall back to the skill body's bash-injected `find` / `grep` listings (correct for digest's tree-listing and post-write audit) but the curator's same-concept conflict detection and the recall agent's keyword grep both degrade to whatever the skill body produces — so install `rg` for full functionality.
- **`CLAUDE_CODE_FORK_SUBAGENT=1`** — environment variable for the `/wiki-digest` sub-agent fork path. Without it, the wiki-digest skill falls back to inline execution per `.claude/skills/wiki-digest/reference/non-fork-fallback.md`. Set via shell profile (`export CLAUDE_CODE_FORK_SUBAGENT=1`).

## Remote install (recommended)

In a target project, start Claude Code and paste this into the prompt:

> Install the llm-code-wiki scaffold from `https://github.com/TajVirani/llm-code-wiki`.
> Follow the "Remote install — for Claude" section of its INSTALL.md exactly.

Claude will fetch the distribution manifest, copy the scaffold files into your project, and run the bootstrap inline. Then restart Claude Code so `/wiki-digest` and `/wiki-recall` register as slash commands. Hooks themselves work without restart.

The full instructions Claude follows are below — you don't need to read them; the line above is enough.

### Remote install — for Claude

You are installing the llm-code-wiki scaffold into the current project (`$CLAUDE_PROJECT_DIR`). Execute these steps in order. Use the Bash tool for `curl` and shell work, and the Write tool when the existing wiki-install steps call for it.

**Important:** the `/wiki-install` slash command is NOT registered yet (Claude Code only registers skills at session startup). Step 5 below has you read the just-fetched `SKILL.md` file and execute its steps directly — that's the supported way to bootstrap on the first run.

1. **Determine the source URL.** Default raw base:
   ```
   RAW_BASE=https://raw.githubusercontent.com/TajVirani/llm-code-wiki/main
   ```
   If the user named a fork (`https://github.com/<OWNER>/<REPO>`) or non-`main` branch, substitute `<OWNER>/<REPO>/<BRANCH>` accordingly.

2. **Fetch the manifest.**
   ```bash
   curl -fsSL "$RAW_BASE/dist-manifest.txt" -o /tmp/lcw-manifest.txt
   test -s /tmp/lcw-manifest.txt || { echo "[lcw-install] ABORT: manifest empty or 404 from $RAW_BASE/dist-manifest.txt"; exit 1; }
   ```

3. **Fetch each listed file.** Iterate over non-blank, non-`#` lines:
   ```bash
   while IFS= read -r path; do
     case "$path" in ''|\#*) continue ;; esac
     dest="$CLAUDE_PROJECT_DIR/$path"
     case "$path" in
       wiki/Rules.md|wiki/_templates/note.md)
         if [ -e "$dest" ]; then
           echo "[lcw-install] skip-if-exists: $path (user content preserved)"
           continue
         fi
         ;;
     esac
     mkdir -p "$(dirname "$dest")"
     curl -fsSL "$RAW_BASE/$path" -o "$dest" \
       && echo "[lcw-install] fetched: $path" \
       || { echo "[lcw-install] ABORT: failed to fetch $path"; exit 1; }
   done < /tmp/lcw-manifest.txt
   ```

4. **Mark hooks executable.**
   ```bash
   chmod +x "$CLAUDE_PROJECT_DIR/.claude/hooks/inbox-stop.sh"
   chmod +x "$CLAUDE_PROJECT_DIR/.claude/hooks/recall-prompt.sh"
   ```

5. **Run the bootstrap inline.** Read `$CLAUDE_PROJECT_DIR/.claude/skills/wiki-install/SKILL.md` and execute its five Bash blocks in order. The skill is template-copy based — there are no Write/Edit tool calls; every block is a single Bash invocation. Notes:
   - Block 1 verifies the manifest fetch placed every required file (including the new `templates/CLAUDE-MD-SECTION.md` and `templates/topic-index.seed.md`), then creates `wiki/`, `wiki/inbox/`, and materializes `wiki/topic-index.md` from the seed template. `wiki/Rules.md` and `wiki/_templates/note.md` will be reported as "already existed" — correct.
   - Block 2 merges the Stop and UserPromptSubmit hook entries into `.claude/settings.json` (this is the user's settings-merge approval prompt).
   - Block 3 appends the "## Auto-maintained wiki" section to `CLAUDE.md` from the canonical template (this is the user's CLAUDE.md-append approval prompt).
   - Block 4 runs three smoke tests (Stop hook fire, recall hook fire, inbox writable) and stamps `.claude/llm-code-wiki.version`. Do NOT skip — they're install verification, and any FAIL aborts the skill.
   - Block 5 prints the install summary block.

6. **Print a final summary.** Combine the manifest fetch results from step 3 with the install summary block printed by Step 7 of the bootstrap. Make it easy for the user to scan what landed where.

7. **Tell the user:**
   > Install complete. Hooks are live (capture + recall fire on the next turn).
   > Restart Claude Code so `/wiki-digest`, `/wiki-recall`, and `/wiki-install` register
   > as slash commands. After restart, edit a file → `wiki/inbox/_session.md` populates.
   > Ask Claude to plan something → recall fires. Run `/wiki-digest` at a review checkpoint.

## Manual install (alternative)

If you'd rather copy the files yourself (e.g., for offline installs, or to vendor a pinned version):

1. **Copy the `.claude/` tree** from this repo into your target project — plugin install, marketplace, manual copy, or symlink. Method is your choice; the `.claude/` directory is the distribution unit. It contains:
   - `.claude/skills/wiki-digest/` — the `/wiki-digest` slash command (filing path)
   - `.claude/skills/wiki-recall/` — the `/wiki-recall` slash command (recall path)
   - `.claude/skills/inbox-update/` — the per-turn inbox update skill
   - `.claude/skills/wiki-rules/` — thin pointer to your project's `wiki/Rules.md`
   - `.claude/skills/wiki-install/` — the bootstrap skill (this file's installer)
   - `.claude/skills/wiki-install/templates/CLAUDE-MD-SECTION.md` — canonical "Auto-maintained wiki" section text (single source of truth, also consumed by `/wiki-update`)
   - `.claude/skills/wiki-install/templates/topic-index.seed.md` — empty topic-index seed materialized by `/wiki-install` Block 1
   - `.claude/agents/wiki-curator.md` — the curator sub-agent (read+write)
   - `.claude/agents/wiki-recall.md` — the recall sub-agent (read-only)
   - `.claude/hooks/inbox-stop.sh` — the Stop hook script (capture path)
   - `.claude/hooks/recall-prompt.sh` — the UserPromptSubmit hook script (recall path)

   Also copy these `wiki/` seed files (skip if you're installing into a project that already has them):
   - `wiki/Rules.md`
   - `wiki/_templates/note.md`

   The authoritative list is `dist-manifest.txt` at the repo root. Do NOT copy any other contents of `wiki/` — those are the source repo's own dogfood notes, not part of the scaffold. `/wiki-install` Block 1 materializes `wiki/topic-index.md` from `.claude/skills/wiki-install/templates/topic-index.seed.md` at install time (interpolating ISO-8601 timestamps).

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
   On a fresh wiki the recall agent will report "Nothing relevant found" — that's expected until `/wiki-digest` files some notes.

6. **When you've done a stretch of work**, run `/wiki-digest` to consolidate the inbox into wiki notes (and refresh `wiki/topic-index.md` for future recall).

## Updating

Once installed, run `/wiki-update` in Claude Code to pull the latest scaffold version from upstream. The command:

- Compares your installed version (`.claude/llm-code-wiki.version`, written by `/wiki-install` at first install) against upstream `VERSION`.
- Shows the changelog entries for any versions strictly between yours and upstream, then asks for explicit confirmation before applying.
- Fetches updated `.claude/` files (skills, agents, hooks) per `dist-manifest.txt`.
- Re-merges your `.claude/settings.json` Stop + UserPromptSubmit hook entries while preserving any other hooks, permissions, env vars, or MCP server entries you've added.
- Refreshes the `## Auto-maintained wiki` section in `CLAUDE.md` (and only that section — anything else in `CLAUDE.md` is preserved).
- **Leaves these alone** so your customizations survive: `wiki/Rules.md`, `wiki/_templates/note.md`, `wiki/topic-index.md`. If upstream changed any of those, you'll see a "manual review recommended" note with a link to the upstream file so you can port what you want by hand.
- Stamps the new version into `.claude/llm-code-wiki.version` only after every step succeeds — a failed update can be safely re-run.

To pull from a fork or branch instead of the default upstream:

```
/wiki-update https://raw.githubusercontent.com/<OWNER>/<REPO>/<BRANCH>
```

Restart Claude Code after `/wiki-update` so any new skills or agents register as slash commands. Hooks themselves work without restart.

If the version comparison shows you're already up-to-date, the command exits without touching any files.

## Usage

- **Inbox file:** `wiki/inbox/_session.md` — the rolling per-project session state. Don't edit by hand; the inbox-update skill maintains it.
- **Research-doc drop zone:** `wiki/inbox/<your-doc>.md` — drop any `.md` you want consumed as wiki source-of-truth here. Filename can be anything except `_session.md` and must not start with `_`. The next `/wiki-digest` will decompose it into filed notes and archive the original.
- **Inbox archive:** `wiki/inbox/_archive/` — pre-digest snapshots of every consumed source. Session snapshots: `<TS>-session.md`. Research-doc snapshots: `<TS>-research-<filename>.md`. Same `<TS>` per digest run so all sources from one run group together.
- **Topic index:** `wiki/topic-index.md` — the recall navigation map. Auto-maintained by `/wiki-digest` (curator Step 9). One bullet per topic with summary and file paths. Don't edit by hand — manual edits will be overwritten on the next digest.
- **`/wiki-digest`** — runs at logical review checkpoints. Consumes BOTH the session inbox AND any research docs in `wiki/inbox/` in one combined plan. Produces a markdown plan grouped by source (preview before write), validates against Rules.md, writes/edits/splits filed notes, then refreshes `wiki/topic-index.md`. Archives every source BEFORE any write (crash-safe). Conflicts between research docs and read-only `wiki/RESEARCH/` notes prompt for explicit user instructions before writing.
- **`/wiki-recall [query]`** — manually consult the wiki for context relevant to a topic or task. Use when the recall hook didn't fire (non-planning phrasing) or when you want a focused recall on a specific topic. With no args, recalls against the current conversation context.
- **`wiki/Rules.md`** — your wiki contract. The curator never modifies it autonomously. Rule-change suggestions surface as proposals in the digest plan.
- **Hook audit log:** `.claude/inbox/.hook-log` — append-only timestamped record of every hook fire. Entries from the Stop hook log the outcome directly (`entering`, `fire`, `noop`, `kill-switch`, etc.). Entries from the recall hook are prefixed with `recall:` (e.g., `recall:fire`, `recall:noop`, `recall:cooldown`).
- **Kill switches:**
  - `touch .claude/inbox/.disabled` — disables the Stop hook (capture path)
  - `touch .claude/inbox/.recall-disabled` — disables the UserPromptSubmit hook (recall path)
  - `rm` either file to re-enable independently

## Anti-features (deliberate non-goals)

- **No real-time wiki sync.** Updates happen at turn boundaries (Stop hook) and on manual `/wiki-digest`, not as code changes mid-stream.
- **No auto-digest.** `/wiki-digest` is manually triggered. Auto-digest mid-feature splits one logical change across multiple notes; `/wiki-digest` mid-feature is your choice.
- **No backfill.** This system maintains a wiki that's already populated or starts empty; it does NOT generate documentation from existing code retroactively.
- **No recall on every prompt.** The UserPromptSubmit hook pre-filters for planning-intent keywords; conversational prompts ("thanks", "what time is it") log `recall:noop` and skip recall. Use `/wiki-recall` for explicit on-demand recall.
- **No `wiki/Rules.md` modification.** The curator never edits the contract. Suggestions surface in plans for you to apply manually.
- **No `wiki/topic-index.md` hand-editing.** The index is auto-maintained by `/wiki-digest`; manual edits get overwritten on the next digest run. If a topic bullet is wrong, edit the underlying note's tags/title and re-run `/wiki-digest`.
- **No semantic-similarity duplicate detection.** Same-concept matching uses filename + title + tag overlap (no embeddings, no runtime). Recall uses keyword + index-bullet matching only — no embeddings.
- **No auto-commit.** The system writes files; you stage and commit them as you see fit.
- **No multi-user / collaborative concerns.** Single-developer tooling. Concurrent sessions writing the same inbox can race (a known gap; see "Concurrent-session safety" below).

## Known interactions

- **`disableSkillShellExecution`:** if a consumer enables this Claude Code setting, the wiki-digest skill's bash injections (`!` `cat ...`) silently produce empty strings. The wiki-curator agent has a fallback (re-globs the wiki tree itself if the input is empty), so digest still works — but cost rises.
- **`CLAUDE_CODE_FORK_SUBAGENT=0` or unset:** the wiki-digest skill cannot truly fork into a fresh-context sub-agent. The non-fork fallback at `.claude/skills/wiki-digest/reference/non-fork-fallback.md` covers this — the curator's protocol runs in the parent session. Correctness-equivalent; loses context isolation.
- **Git worktrees:** the `.claude/` tree is shared across worktrees in the same project. Concurrent sessions in different worktrees can race on `.hook-log` and `.fire-counter`. Acceptable single-developer; a known gap for multi-worktree workflows.
- **Pre-existing skills with our names:** if your project already has `wiki-install`, `inbox-update`, `wiki-digest`, `recall`, `wiki-rules` skills or `wiki-curator` / `wiki-recall` agents, the upstream copy step (plugin install, manual copy) will overwrite them. The `/wiki-install` skill does NOT detect collisions — that's the upstream distribution mechanism's responsibility.
- **`ripgrep` missing:** Claude Code's `Glob` / `Grep` tools fail with `posix_spawn 'rg' ENOENT` when `rg` is not on `$PATH`. Symptom during `/wiki-digest`: the curator's same-concept conflict detection and post-write link audit (when run via the Grep tool) cannot enumerate filed notes — the curator falls back to the skill body's bash-injected `find` and `grep` outputs, which work correctly. Recall via `/wiki-recall` is more impacted: keyword grep across `wiki/` returns nothing useful. Fix: install `ripgrep` (see Prerequisites).

## Known gaps (v1)

- **Wiki ↔ codebase reconciliation.** No `/reconcile` skill — if you delete a function externally (in your editor, not via Claude), the corresponding wiki note becomes a "ghost note." Run periodic manual audits or accept some drift.
- **Concurrent-session safety.** Multiple Claude sessions writing to `wiki/inbox/_session.md` simultaneously can race. Single-developer tooling.

## Uninstall

There's no `/wiki-uninstall` skill in v1. To remove:

1. Delete `.claude/skills/{wiki-digest,wiki-recall,inbox-update,wiki-rules,wiki-install}/`.
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
