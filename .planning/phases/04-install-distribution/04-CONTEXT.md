# Phase 4: Install & Distribution - Context

**Gathered:** 2026-04-29
**Status:** Ready for planning
**Mode:** Autonomous smart-discuss with user override (significant scope reframing)

<domain>
## Phase Boundary

Build a `/wiki-install` Claude Code skill that bootstraps a project to use the auto-wiki system. The .claude/ tree (skills/agents/hooks from this repo) is assumed already present in the target project — copied via plugin/marketplace mechanism, manual copy, or symlink — that distribution path is OUT OF SCOPE for this phase.

`/wiki-install` does the project-specific bootstrap:
1. Creates `wiki/` folder if absent
2. Creates `wiki/_templates/note.md` with the default template (sourced from this repo's `wiki/_templates/note.md`)
3. Creates `wiki/Rules.md` with the default rules (sourced from this repo's `wiki/Rules.md`)
4. Merges the Stop hook entry into the project's `.claude/settings.json` (creates settings.json if absent)
5. Adds a documentation entry to the project's `CLAUDE.md` describing the auto-wiki system (so future Claude sessions in that project understand the system)
6. **Idempotent:** if any of (wiki/, _templates/note.md, Rules.md, settings.json hook entry, CLAUDE.md entry) already exists, the skill SKIPS creation and LOGS what it skipped — never overwrites or duplicates

Owns 3 v1 requirements: INST-01, INST-02, INST-03 (with INST-01 reframed per user instruction).

Out of scope this phase:
- Distributing the .claude/ tree (skills, agents, hooks) — that's plugin/marketplace territory, not this skill's job
- Bash installer / curl-pipe-bash distribution mechanism
- Worktree warning (deferred — relevant for distribution, not for /wiki-install's scope)
- npm package, brew formula, etc. — none needed since this is a Claude-Code-native skill

</domain>

<decisions>
## Implementation Decisions

### Skill form
- **D-01:** **`/wiki-install` slash command (skill).** Lives at `.claude/skills/wiki-install/SKILL.md` in this repo (and ships as part of the .claude/ tree to consumers). User invokes `/wiki-install` once after the .claude/ tree is in place.
- **D-02:** Skill is `disable-model-invocation: true` (manual only, never auto-fires) and `user-invocable: true`. Allowed tools: Read, Write, Edit, Glob, Bash (for jq merging if needed). No `context: fork` — this skill runs in the parent context since it does direct file ops.

### Wiki bootstrap (idempotent)
- **D-03:** **Wiki folder.** If `wiki/` does not exist → create it. If exists → log "wiki/ already exists, skipping creation" and continue. The skill never deletes or moves an existing wiki/.
- **D-04:** **`wiki/_templates/note.md`.** If file does not exist → write it from this repo's source content (the canonical template). If exists → log "wiki/_templates/note.md already exists, skipping" and continue (do NOT overwrite even if the contents differ — user customization is sacred).
- **D-05:** **`wiki/Rules.md`.** Same idempotent pattern: create if absent (sourced from this repo's `wiki/Rules.md` content), skip + log if present.
- **D-06:** **`wiki/inbox/`** (the runtime state directory): create if absent (empty); skip + log if present.

### Settings.json merge
- **D-07:** **Merge the Stop hook entry.** The skill needs to add the hook config (per Phase 3's authored `.claude/settings.json` template) to the project's `.claude/settings.json`. Three cases:
  - settings.json absent → create it with the Stop hook entry
  - settings.json present, no Stop hook → merge in the hook entry (using `jq` if available, else careful in-place edit)
  - settings.json present with a Stop hook entry already → log "Stop hook already registered, skipping settings.json modification" — do NOT add a duplicate entry, do NOT replace the existing one (user has their own hook; preservation > our hook)
- **D-08:** If `jq` is not installed AND settings.json has existing content that needs merging, abort with a clear error: "jq required for settings.json merge; install jq and re-run /wiki-install OR manually add the hook entry as documented in `wiki/_templates/SETTINGS-SNIPPET.md`." Provide the snippet path so manual users have a fallback.

### CLAUDE.md entry
- **D-09:** **Add a documentation entry.** The skill writes (or appends) a section to the project's `CLAUDE.md` titled "## Auto-maintained wiki" containing: a one-paragraph description of the system, the canonical wiki path, the Stop-hook trigger, the `/digest` command for consolidation, the location of `wiki/Rules.md` as the contract, and the explicit gaps (D-19 enforcement deferred, wiki↔code reconciliation deferred). This is the project-discoverable handoff so future Claude sessions in that project understand the system.
- **D-10:** **Idempotent CLAUDE.md update.** If the section "## Auto-maintained wiki" already exists in CLAUDE.md → skip + log "CLAUDE.md already documents auto-wiki, skipping". If CLAUDE.md does not exist → create it with the section. If CLAUDE.md exists without the section → append the section.

### Smoke test (INST-02)
- **D-11:** **Post-install verification.** After all bootstrap operations, the skill runs a synthetic smoke test:
  1. Pipe a test stdin JSON to the Stop hook (`{"transcript_path": "/tmp/x", "session_id": "test", "stop_hook_active": false}`) and verify it produces a valid JSON response with `decision` field. (Echoes Phase 3's pipe-stdin smoke pattern.)
  2. Verify the live inbox path: `wiki/inbox/_session.md` is writable.
  3. Print a summary: what was created, what was skipped, smoke-test outcome, suggested next step ("take a normal Claude turn that edits a file to see the hook in action").

### Logging behavior
- **D-12:** **Verbose log to stdout.** Every action (create / skip / merge / abort / smoke-test result) prints one line to stdout in a clear format. No log file — the skill output IS the log. The user sees exactly what happened in their conversation.

### REQUIREMENTS reframing note
- **D-13:** **INST-01 is implicitly reframed.** Original wording: "A one-command install drops `.claude/skills/`, `.claude/agents/`, and the Stop hook config into a target repo and merges (does not clobber) existing `settings.json`." Reframed (per user instruction): the `.claude/` tree distribution comes from plugin/marketplace mechanisms outside this phase's scope. `/wiki-install` covers the "merges (does not clobber) existing settings.json" half plus the wiki/ bootstrap. REQUIREMENTS.md should be updated post-Phase-4 to reflect this — flagged as a documentation gap.

### Claude's Discretion (planner's call)
- The exact wording of the CLAUDE.md "## Auto-maintained wiki" section
- Whether to bundle a `SETTINGS-SNIPPET.md` reference file for the jq-absent fallback
- The precise format of the verbose log lines (D-12)
- Whether the smoke test in D-11 includes a sub-step that checks `.claude/skills/inbox-update/SKILL.md` exists (defensive — fails fast if the .claude/ tree wasn't actually copied) — I lean yes, planner decides

</decisions>

<specifics>
## Specific Ideas

- The skill's first action should be a precondition check: confirm `.claude/skills/inbox-update/SKILL.md`, `.claude/skills/digest/SKILL.md`, `.claude/agents/wiki-curator.md`, and `.claude/hooks/inbox-stop.sh` all exist. If any are missing, abort with a clear message: "The .claude/ tree must be copied in before running /wiki-install. See README.md for distribution instructions." This catches the "user ran wiki-install before copying the plugin" failure mode.
- The CLAUDE.md entry should be brief (under 200 words) — it's discoverability, not a manual. Link to wiki/Rules.md for details.
- The verbose log lines should use a clear prefix like `[wiki-install]` so they're greppable in long conversation logs.

</specifics>

<canonical_refs>
## Canonical References

### What `/wiki-install` references
- `wiki/Rules.md` (THIS REPO) — the default Rules.md content the skill writes to target projects' `wiki/Rules.md` if absent.
- `wiki/_templates/note.md` (THIS REPO) — the default note template.
- `.claude/settings.json` (THIS REPO, Phase 3 deliverable) — the canonical Stop hook entry to merge into target projects' settings.json.
- `.claude/hooks/inbox-stop.sh` (Phase 3 deliverable) — the hook script the skill smoke-tests after install.

### Phase context
- `.planning/PROJECT.md` — Q1 row + locked decisions.
- `.planning/REQUIREMENTS.md` — INST-01..03 (with INST-01 reframing per D-13).
- `.planning/phases/03-stop-hook-automation/03-CONTEXT.md` — Phase 3 settings.json structure (D-07's source).
- `.planning/phases/03-stop-hook-automation/03-01-SUMMARY.md` — what's in `.claude/settings.json`.
- `.planning/research/PITFALLS.md` Pitfall 4 (silent failure on install) + Pitfall 6 (concurrent sessions, deferred).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`.claude/skills/wiki-rules/SKILL.md`** (Phase 1) — frontmatter pattern reference for the new wiki-install skill.
- **`.claude/skills/digest/SKILL.md`** (Phase 1) — slash command frontmatter pattern.
- **`wiki/Rules.md`** (this repo) — the source content for D-05.
- **`wiki/_templates/note.md`** (this repo) — the source content for D-04.
- **`.claude/settings.json`** (Phase 3) — the canonical hook config for D-07.

### Established Patterns
- **No-runtime delivery** — bash + jq for shell ops; Read/Write/Edit/Glob from Claude's tool kit. No Node/Python.
- **Idempotency by file existence check** — the skill's pattern for D-03..D-06 mirrors how Phase 1 Plan 02 created scaffolding and Phase 2 Plan 01 reset the inbox.
- **Verbose-log pattern** — `[wiki-install] ...` prefix for greppability.

### Integration Points
- **Target project's `wiki/`** — write target.
- **Target project's `.claude/settings.json`** — merge target.
- **Target project's `CLAUDE.md`** — append target.
- **Target project's `.claude/skills/inbox-update/`, `.claude/skills/digest/`, `.claude/agents/wiki-curator.md`, `.claude/hooks/inbox-stop.sh`** — precondition reads (must exist before /wiki-install runs).

</code_context>

<deferred>
## Deferred Ideas

- **Distribution of the `.claude/` tree** — out of this phase's scope. Plugin/marketplace mechanism, manual copy, or symlink. Documented in deferred work.
- **Worktree warning** (HARD-01 territory) — `/wiki-install` doesn't detect worktrees. If a user runs the system in a multi-worktree project, the concurrent-session race is a HARD-01 hardening concern.
- **Uninstall mechanism** — no `/wiki-uninstall` skill in v1. Users remove the system manually by deleting `.claude/{skills,agents,hooks}` entries and reverting `settings.json` / `CLAUDE.md`.
- **REQUIREMENTS.md update for INST-01 reframing** — captured in D-13; should be updated post-Phase-4 closure.

</deferred>

---

*Phase: 04-install-distribution*
*Context gathered: 2026-04-29*
