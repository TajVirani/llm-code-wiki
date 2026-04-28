# Architecture Research

**Domain:** Claude Code skill + hook scaffolding for auto-maintained codebase wiki
**Researched:** 2026-04-28
**Confidence:** HIGH (mechanics) / MEDIUM (failure-mode estimates)

## Standard Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│  CLAUDE CODE RUNTIME (host process — outside our control)             │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│   user prompt ───► main Claude turn ───► (tool calls: Edit/Write/...)│
│                          │                                            │
│                          │ turn ends ───► STOP HOOK FIRES             │
│                          ▼                                            │
│   ┌──────────────────────────────────────────────────────────────┐   │
│   │  .claude/settings.json :: hooks.Stop                          │   │
│   │  → emits JSON {decision:"block", reason:"<nudge text>"}       │   │
│   │     reason text: "Update the session inbox per the            │   │
│   │     inbox-update skill before stopping."                      │   │
│   └──────────────────────────────────────────────────────────────┘   │
│                          │                                            │
│                          ▼ (block keeps turn alive; reason injected) │
│   main Claude turn (continued)                                        │
│                          │                                            │
│                          ▼                                            │
│   ┌──────────────────────────────────────────────────────────────┐   │
│   │  .claude/skills/inbox-update/SKILL.md                         │   │
│   │  description matches the nudge → Claude loads skill body      │   │
│   │  → reads inbox file, edits atomic entries, prunes stale ones  │   │
│   └──────────────────────────────────────────────────────────────┘   │
│                          │                                            │
│                          ▼ (writes wiki/inbox/_session.md)           │
│   STOP HOOK FIRES AGAIN ─► detects inbox just touched ─► exit 0      │
│   (turn finally ends)                                                 │
│                                                                       │
│   ───────────────────  user invokes /digest manually  ──────────────  │
│                                                                       │
│   ┌──────────────────────────────────────────────────────────────┐   │
│   │  .claude/skills/digest/SKILL.md                               │   │
│   │  context: fork  +  agent: <wiki-curator>                      │   │
│   │  injects current inbox + wiki tree listing as prompt          │   │
│   └──────────────────────────────────────────────────────────────┘   │
│                          │                                            │
│                          ▼ (spawns subagent in fresh context)        │
│   ┌──────────────────────────────────────────────────────────────┐   │
│   │  .claude/agents/wiki-curator.md  (subagent definition)        │   │
│   │  preloads skill: wiki-rules (mirrors wiki/Rules.md)           │   │
│   │  reads inbox + globs wiki/ → routes entries into category     │   │
│   │  folders → writes filed notes → archives inbox → resets it    │   │
│   └──────────────────────────────────────────────────────────────┘   │
│                          │                                            │
└──────────────────────────┼───────────────────────────────────────────┘
                           ▼
┌──────────────────────────────────────────────────────────────────────┐
│  FILESYSTEM (the wiki — persistent state)                             │
├──────────────────────────────────────────────────────────────────────┤
│  wiki/                                                                │
│  ├── Rules.md                  ◄── canonical schema (fixed)           │
│  ├── _templates/note.md        ◄── note schema (fixed)                │
│  ├── inbox/                                                           │
│  │   ├── _session.md           ◄── ROLLING state-of-world (R/W hot)  │
│  │   └── _archive/                                                    │
│  │       └── 2026-04-28T1430-session.md   ◄── digest archive         │
│  ├── ARCHITECTURE/   FUNCTIONS/   RESEARCH/   SELF/   DIAGRAMS/      │
│  │   └── *.md                  ◄── filed notes (digest output)        │
└──────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Owns | Does NOT own |
|-----------|------|--------------|
| **Stop hook** (`.claude/settings.json`) | Detecting "Claude tried to stop"; emitting a `decision:"block"` with a fixed `reason` string that names the inbox-update skill; idempotent — must allow stop on the *second* fire after Claude updates the inbox | Reading or writing the inbox; deciding what goes in it |
| **inbox-update skill** (`.claude/skills/inbox-update/SKILL.md`) | The rules for how Claude amends `_session.md` during a turn: atomic flat entries, state-of-world semantics, self-pruning protocol, entry shape | Triggering itself (the hook does that); routing entries into wiki categories (digest does that) |
| **Inbox file** (`wiki/inbox/_session.md`) | Carrying durable session activity across turns; surviving compaction; being grep-friendly so an entry can be found and pruned without re-reading the whole file | Final categorization; cross-linking to filed notes |
| **digest skill** (`.claude/skills/digest/SKILL.md`) | Being the user-invocable entrypoint (`/digest`); collecting inputs the subagent will need (inbox content, wiki tree, Rules excerpt); spawning the subagent via `context: fork` + `agent: wiki-curator` | Doing the routing itself in the main session (would pollute main context) |
| **wiki-curator subagent** (`.claude/agents/wiki-curator.md`) | Reading the inbox; reading the existing wiki; routing entries into category folders per `wiki/Rules.md`; writing filed notes; archiving the consumed inbox; resetting `_session.md` to an empty header | Inventing categories not in `Rules.md`; modifying `Rules.md` itself |
| **wiki-rules skill** (preloaded into curator) | Mirroring `wiki/Rules.md` as a skill so it's always in the curator's context at startup | Drift: `Rules.md` is the source of truth; the skill should be a thin pointer that re-reads `wiki/Rules.md` on activation |
| **wiki/** filesystem tree | Final, queryable state; obeys `Rules.md` literally | Knowing about the inbox-update protocol — wiki notes are inbox-agnostic |

### Critical Mechanic (verified against current Claude Code docs)

The Stop hook's **`reason` field, when paired with `decision: "block"`, is shown to Claude as system feedback within the current turn and prevents the turn from ending.** Claude sees the text and can act on it. This is the only documented mechanism that lets a hook "inject a prompt" — `additionalContext` is **not** supported on Stop events (it's only on `UserPromptSubmit`, `SessionStart`, `PreToolUse`, `PostToolUse`, `UserPromptExpansion`). This is non-obvious and reshapes the design: the Stop hook does not "call" the skill; it nudges Claude toward the skill, and Claude's own skill-discovery picks it up.

## Recommended Project Structure

```
llm-code-wiki/                           # this repo (the scaffolding source)
├── .claude/
│   ├── settings.json                    # Stop hook config — ships verbatim
│   ├── skills/
│   │   ├── inbox-update/
│   │   │   ├── SKILL.md                 # how-to for amending _session.md
│   │   │   └── entry-shape.md           # supporting reference (loaded on demand)
│   │   ├── digest/
│   │   │   └── SKILL.md                 # /digest entrypoint, context: fork
│   │   └── wiki-rules/
│   │       └── SKILL.md                 # thin pointer to wiki/Rules.md, preloaded into curator
│   └── agents/
│       └── wiki-curator.md              # subagent definition + system prompt
├── wiki/                                # FIXTURE for testing (Traxalytics)
│   ├── Rules.md                         # canonical conventions
│   ├── _templates/note.md
│   ├── inbox/
│   │   ├── _session.md                  # rolling inbox (gitignored? see decision)
│   │   └── _archive/
│   ├── ARCHITECTURE/  FUNCTIONS/  RESEARCH/  SELF/  DIAGRAMS/
│   └── ...
├── install/
│   └── install.sh                       # copies .claude/* into target repo
└── .planning/                           # GSD planning artifacts
```

### Structure Rationale

- **`.claude/` at repo root, not nested under `wiki/`:** the scaffolding is Claude Code config, not wiki content. Keeping them separate means the install script copies one tree, and another repo's existing `wiki/` is untouched.
- **`wiki/inbox/_session.md` (inside the wiki):** see the dedicated decision in §"Inbox file location" below — this is a deliberate, non-default choice.
- **One subagent definition, multiple skills:** the curator is the only subagent. Skills are how we package different *protocols* (in-session inbox upkeep vs. post-hoc digest) addressed to different audiences.
- **`wiki-rules/SKILL.md` as thin pointer:** `wiki/Rules.md` is the fixed contract per `PROJECT.md`. Mirroring its content into a skill body invites drift. The skill body should say "read `wiki/Rules.md` now and obey it literally" — the file path is stable; the content is sourced once per invocation.

## Architectural Patterns

### Pattern 1: Hook-as-Nudge, Not Hook-as-Executor

**What:** The Stop hook does not write to the inbox. It blocks the stop and emits a fixed `reason` string. Claude — still in its tool-using turn — reads the reason, recognizes the inbox-update skill from its description, loads the skill, and does the work using its own Read/Edit tools.

**When to use:** Whenever you need a hook to "make Claude do something" that requires tool use. Hooks run as shell processes outside Claude's permission and tool surface; only Claude can write files in a way that respects the project's permission rules.

**Trade-offs:**
- ✅ Works within Claude Code's actual hook contract (verified)
- ✅ Inbox writes go through Claude's normal Edit tool — auditable, undoable, permission-checked
- ✅ Claude can intelligently *not* update the inbox if the turn was a no-op (e.g., user just asked a question)
- ⚠ Two Stop hook fires per turn that has any work: first to block+nudge, second to allow. The hook must be *idempotent* and detect "did Claude already update the inbox this turn?" to avoid an infinite loop.
- ⚠ Costs one extra short turn-segment per work-bearing turn (Claude calls Edit on the inbox)

**Stop hook idempotency contract:**

```bash
# pseudo-code for the Stop hook command
INBOX=wiki/inbox/_session.md
TRANSCRIPT=$(jq -r .transcript_path)   # provided by Claude Code
LAST_INBOX_EDIT_TIME=$(stat -c %Y "$INBOX" 2>/dev/null || echo 0)
TURN_START_TIME=$(jq -r '.. | .timestamp? // empty' "$TRANSCRIPT" \
                  | tail -50 | head -1 | xargs -I{} date -d {} +%s)

if [ "$LAST_INBOX_EDIT_TIME" -gt "$TURN_START_TIME" ]; then
  exit 0   # Claude already updated this turn — allow stop
fi

jq -n '{decision:"block", reason:"Before stopping, update wiki/inbox/_session.md per the inbox-update skill. If this turn produced no codebase activity worth recording, write nothing and stop again."}'
```

The "write nothing and stop again" escape hatch is critical — it prevents the hook from forcing busy-work on pure-conversation turns.

### Pattern 2: State-of-World Inbox (not Append-Log)

**What:** `_session.md` is a *current-state* document. When Claude creates `parseScores()`, it adds an entry. When Claude later deletes `parseScores()` in the same session, Claude *removes* the entry — not "appends a deletion event."

**When to use:** This is the locked decision per `PROJECT.md`. Use it whenever the consumer (digest sub-agent) only cares about the final state, not the journey. The "1+1 function created then deleted" case becomes trivial: no entry exists, nothing to digest.

**Trade-offs:**
- ✅ Self-pruning is natural — stale entries are removed, not contradicted
- ✅ Digest agent never has to reconcile event ordering
- ✅ Inbox stays bounded in size
- ⚠ Loses the "what was tried and abandoned" signal. Mitigation: a small `## Notable Detours` section at the bottom for explicit "we considered X, rejected because Y" entries, which the digest agent can route to `RESEARCH/` or `SELF/`.
- ⚠ Requires entries to be findable for pruning — drives the schema below.

### Pattern 3: Atomic Flat Entries with Stable Handles

**What:** Every entry is a self-contained block, prefixed by a greppable handle line. No nested sectioning. Order doesn't matter.

**When to use:** For the in-session inbox specifically. Categorization (which category folder?) is deferred to digest, which has full context.

**Trade-offs:**
- ✅ Flat structure means Claude can grep `^@ FUNCTIONS::parseScores` to find an entry to update or prune in O(grep) without reading the full file
- ✅ No "where does this entry go in the inbox" decision during the session — only one decision: does an entry already exist for this handle?
- ⚠ Without a handle convention, pruning requires re-reading the whole inbox. The handle line is the load-bearing piece of the schema.

**Entry shape (concrete proposal):**

```markdown
@ FUNCTIONS::parseScores  •  src/lib/scores.ts  •  #function #parsing
Parses raw box-score JSON into the Skater[] shape used by the projection engine.
Replaces the older inline parsing in `loadGames()`. Handles missing OT-loss column
(some 90s-era data lacks it). Tested against 2003-04 fixture.

@ ARCHITECTURE::scoring-pipeline  •  src/lib/  •  #pipeline #refactor
Three-stage pipeline: parse → normalize → project. Stage boundaries enforced by
type signatures, no shared mutable state.

@ DETOUR::tried-rxjs  •  —  •  #rejected
Tried wrapping the pipeline in RxJS observables for backpressure. Overkill —
the data is bounded (one season ≈ 1300 games). Reverted. Don't re-try.
```

**Schema per entry:**

| Field | Format | Why |
|-------|--------|-----|
| Handle line | `@ <CATEGORY-HINT>::<slug>  •  <path-or-em-dash>  •  <#tags>` | Single-line, anchored at start (`^@ `), greppable. The category hint is *advisory* — digest re-decides. |
| Body | 1-4 short paragraphs, no bullets needed | Atomic; Claude can rewrite the whole entry rather than patch parts |
| Blank line between entries | Required | Greppable blocks; `awk 'BEGIN{RS=""}/^@ FUNCTIONS::parseScores/'` extracts one entry |

**Inbox file shape:**

```markdown
# Session Inbox

**Status**: rolling — current state of session work
**Started**: 2026-04-28T09:00:00Z
**Last touched**: 2026-04-28T14:23:00Z

---

@ FUNCTIONS::parseScores  •  src/lib/scores.ts  •  #function #parsing
[entry body]

@ ARCHITECTURE::scoring-pipeline  •  src/lib/  •  #pipeline
[entry body]

---

## Notable Detours

@ DETOUR::tried-rxjs  •  —  •  #rejected
[entry body]
```

**Pruning protocol (the load-bearing trick):**

When Claude deletes code, the inbox-update skill tells Claude:
1. `Grep ^@ .*::<thing-just-deleted>` against `_session.md`
2. If a match: read just that entry block, decide — remove entirely (created+deleted same session) OR rewrite to reflect the change (e.g., function moved to a new file).
3. Use Edit tool to replace just that block.

This avoids re-reading the whole inbox on every turn — addresses the cost constraint in `PROJECT.md`.

### Pattern 4: Subagent with Curated Inputs, Not Raw Inheritance

**What:** The digest skill uses `context: fork` + `agent: wiki-curator`. The skill body is the *prompt* the curator receives; the skill uses `` !`<command>` `` injection to embed:
- Current `_session.md` content
- A `find wiki -type f -name '*.md' | sort` listing (so curator detects duplicates without globbing)
- The current `wiki/Rules.md` (re-read fresh, not mirrored)

**When to use:** When the subagent needs more than the inbox alone to make correct routing decisions. Per `PROJECT.md`, the requirement is "no session memory required" — meaning the curator must work from the inbox + wiki state alone, with no parent-conversation context.

**Trade-offs:**
- ✅ Curator gets exactly the context it needs, deterministically, without depending on `Explore` to find things
- ✅ `Rules.md` is read at digest time — no drift risk from a stale skill mirror
- ⚠ Bash injection (`!`) runs in the *parent* session before fork, so its file reads count against parent context briefly. For a typical wiki this is fine (<5KB). For a 1000-note wiki, switch to having the curator glob itself.
- ⚠ Forked subagents are gated by `CLAUDE_CODE_FORK_SUBAGENT=1` (experimental as of v2.1.117). Fallback: use a normal named subagent and have the digest skill `cat` the inputs into the @-mention prompt directly.

**Digest skill sketch:**

```yaml
---
name: digest
description: Process the session inbox into filed wiki notes per Rules.md. Run when the user says /digest or asks to "process the inbox" or "file the session notes".
disable-model-invocation: true
context: fork
agent: wiki-curator
allowed-tools: Read Glob Grep Edit Write
---

# Digest the session inbox

## Inputs
- Session inbox content:
!`cat wiki/inbox/_session.md`

- Existing wiki tree:
!`find wiki -type f -name '*.md' -not -path 'wiki/inbox/*' | sort`

- Wiki rules (authoritative):
!`cat wiki/Rules.md`

## Your task
[detailed routing instructions — see curator subagent system prompt for the full protocol]
```

### Pattern 5: Curator Proposes-Then-Applies (with a dry-run gate)

**What:** The curator does *not* immediately rewrite the wiki. It first emits a routing plan as its initial response (filename → destination, splits proposed, archives planned), and only proceeds to Write/Edit calls if the plan validates against `Rules.md` constraints (kebab-case, ≤25-word summaries, ≤1000 words, no template files in category folders).

**When to use:** Always for the curator. Per `Rules.md` §10, "If a user request appears to conflict with these rules, surface the conflict before acting." A digest run that creates 12 notes is exactly when conflicts surface.

**Trade-offs:**
- ✅ Reviewable: the user sees the plan before files are written
- ✅ Idempotent: if the curator crashes mid-run, the plan can be re-applied
- ⚠ Two-phase = more tokens. Acceptable because digest is manual, not per-turn.

**Validation gate (curator's own check before Write):**
- Filename matches `^[a-z0-9][a-z0-9-]*\.md$`
- Summary ≤ 25 words
- Note body ≤ 1000 words (split if exceeded)
- Destination folder ∈ {`ARCHITECTURE`, `FUNCTIONS`, `RESEARCH`, `SELF`, `DIAGRAMS`}
- No write to `wiki/inbox/` or `wiki/_templates/`
- `Related Notes` links use `[[Title]]` form, not paths

## Data Flow

### End-to-End Trace: "Claude writes a function"

```
T0  User: "Add a parseScores function"
                    │
T1  Claude turn:
    ├─ Read src/lib/scores.ts (existing file)
    ├─ Edit src/lib/scores.ts (adds parseScores)
    └─ Replies "Done — added parseScores"
                    │
T2  ▼ STOP HOOK FIRES (1st time)
    Hook reads transcript_path, sees inbox file unchanged this turn
    Returns: {decision:"block", reason:"Update wiki/inbox/_session.md per
              inbox-update skill before stopping..."}
                    │
T3  Claude turn (continued, sees the reason):
    ├─ Recognizes inbox-update skill from its description
    ├─ Loads SKILL.md body (instructions for how to amend _session.md)
    ├─ Grep ^@ FUNCTIONS::parseScores wiki/inbox/_session.md  → no match
    ├─ Read wiki/inbox/_session.md (or just the bottom for append point)
    ├─ Edit wiki/inbox/_session.md → appends new @ entry
    └─ (no further reply — work done)
                    │
T4  ▼ STOP HOOK FIRES (2nd time)
    Hook detects inbox mtime > turn start time → exit 0
                    │
T5  Turn ends. User sees only the original "Done" reply.
                    │
    [later — many turns, possibly multiple sessions]
                    │
T6  User: /digest
                    │
T7  Digest skill renders (bash injection runs):
    - cat wiki/inbox/_session.md
    - find wiki -name '*.md' | sort
    - cat wiki/Rules.md
    Skill body becomes the prompt; fork subagent of type wiki-curator spawns.
                    │
T8  wiki-curator subagent (fresh context):
    ├─ Reads inbox (already in prompt) + wiki tree (already in prompt)
    ├─ For @ FUNCTIONS::parseScores entry:
    │  ├─ Check if FUNCTIONS/parse-scores.md already exists → no
    │  ├─ Check related notes (FUNCTIONS/load-games.md exists)
    │  └─ Plan: Write FUNCTIONS/parse-scores.md, link to load-games
    ├─ Emit plan as first response (user sees it)
    ├─ Validate plan against Rules.md → OK
    ├─ Write wiki/FUNCTIONS/parse-scores.md (full template)
    ├─ Move wiki/inbox/_session.md → wiki/inbox/_archive/2026-04-28T1430-session.md
    ├─ Write wiki/inbox/_session.md with empty header (reset)
    └─ Return summary to main session
```

### Failure Modes (where can each step break?)

| Step | Failure Mode | Detection | Mitigation |
|------|--------------|-----------|------------|
| T2 | Hook script not executable / not in PATH | First Stop produces no nudge; inbox stays empty | Install script `chmod +x`; pin absolute path in `settings.json` |
| T2 | Hook fires on a pure-conversation turn (user asked a question, no code changed) | Inbox gets noise entries like "discussed X" | Skill instructions: "if turn produced no codebase artifact, do not write — stop." Hook accepts the second stop. |
| T2 | Hook's "did inbox change this turn?" check is wrong → infinite block loop | User sees endless "before stopping..." messages | Track turn start via transcript timestamp, not just file mtime; cap at 2 consecutive blocks via session-state file in `.claude/.gsd-state` |
| T3 | Claude doesn't recognize the skill from the reason text | Inbox not updated, second Stop still blocks | Skill `description` must front-load trigger keywords; reason text must name the skill explicitly (`"per the inbox-update skill"`) |
| T3 | Claude updates the inbox but with wrong shape (e.g., uses bullets instead of `@` handles) | Pruning grep fails on next turn | Skill includes a worked example block; entry-shape.md supporting file with concrete schema |
| T3 | Claude prunes an entry it shouldn't (e.g., function was renamed, not deleted) | Information loss in digest | Skill protocol: on rename, *update* the entry (new path on handle line), don't delete |
| T3 | Inbox file doesn't exist on first turn of a fresh repo | Edit fails | inbox-update skill: "if file doesn't exist, create it with the standard header" |
| T7 | Bash injection (`!`) blocked by `disableSkillShellExecution` setting | Curator gets no inputs, returns garbage | Document the required setting in install instructions; add a fallback path where curator uses Read/Glob itself |
| T7 | Wiki tree listing exceeds reasonable size (10k notes) | Token cost spikes | Switch to two-phase: skill ships a tree summary, curator globs subtrees on demand |
| T7 | `wiki/Rules.md` has been edited by user with conflicting rules | Curator's wiki-rules skill body is stale | Always re-read `wiki/Rules.md` at digest time (treat skill body as a pointer, not a copy) |
| T8 | Curator spawned without `CLAUDE_CODE_FORK_SUBAGENT=1` | `/digest` falls back to inline execution, polluting main context | Add a `SessionStart` hook that warns if env var unset; provide named-subagent fallback path |
| T8 | Curator proposes a routing that violates Rules.md | Bad files written | Validation gate before Write (see Pattern 5); fail loudly with the rule violated |
| T8 | Curator crashes mid-run after writing some notes but before archiving inbox | Next digest re-processes already-filed entries → duplicates | Archive inbox *first*, then write notes from the archived copy. On crash, the archive name + a `wiki/inbox/_archive/INPROGRESS` marker lets resume |
| T8 | Two concurrent digests (user runs `/digest` twice) | Race on archive filename, double-write | Curator's first action is to acquire `wiki/inbox/.lock` (write-and-rename); refuse if exists |

## State Management

```
        ┌─────────────────────────────────┐
        │  wiki/inbox/_session.md         │
        │  (rolling state-of-world)       │
        └────────────┬────────────────────┘
                     │  read+amend each turn
                     │  (inbox-update skill)
                     │
        ┌────────────▼────────────────────┐
        │  Claude (main turn)             │
        └────────────┬────────────────────┘
                     │  /digest (manual)
                     │
        ┌────────────▼────────────────────┐
        │  wiki-curator subagent          │
        │  (fork, fresh context)          │
        └────────────┬────────────────────┘
                     │  archive + write
                     │
   ┌─────────────────┼──────────────────┐
   ▼                 ▼                  ▼
wiki/inbox/    wiki/FUNCTIONS/    wiki/inbox/_archive/
_session.md    parse-scores.md    2026-04-28T1430-...
(reset, empty) (filed note)       (consumed inbox)
```

### Key Data Flows

1. **Per-turn inbox amend (hot path):** main Claude, in-session, low-cost grep+edit. Runs every work-bearing turn. Cost: one extra short tool segment.
2. **Per-digest filing (cold path):** subagent, fresh context, manual trigger. Runs rarely. Cost: full subagent spawn + N file writes.
3. **Archive flow:** inbox → timestamped archive happens *before* note writing, so a crash mid-write doesn't lose entries.

## Inbox file location: decision

Two viable options. **Recommendation: `wiki/inbox/_session.md`** (inside the wiki).

| Criterion | `wiki/inbox/_session.md` (inside wiki) | `.claude/inbox/_session.md` (outside) |
|-----------|-------------------------------------|---------------------------------------|
| Convention fit | ✅ Matches `Rules.md` §1: `inbox/` is the staging area | ⚠ Splits "session work" from "wiki" — two places to look |
| Archive locality | ✅ Archives sit next to filed notes; one tree to back up | ⚠ Cross-tree movement on digest |
| `Rules.md` semantics | ⚠ Current `Rules.md` says "raw, unprocessed `.md` notes" — `_session.md` is a session log, not a candidate note. Need to clarify this in the inbox-update skill (the file is *the staging document*, not *a note to be filed*) | ✅ Sidesteps the semantic stretch |
| Greppability for users | ✅ `cd wiki && grep` finds in-flight work alongside filed work | ⚠ Two greps |
| Git ergonomics | ⚠ Inbox churn shows up in wiki diffs every turn — noisy | ✅ Cleaner wiki history |
| Plays with existing wiki migrations | ⚠ Existing wikis using `inbox/` for true inbox notes might collide | ✅ Zero collision |
| Install footprint | ✅ One artifact path | ⚠ Need to create `.claude/inbox/` dir during install |

**Decision:** keep it inside `wiki/inbox/` because the convention fit is the strongest signal — `Rules.md` §6 already calls `inbox/` "the staging area" and §9 marks it as special. The semantic stretch (it's a state-of-world doc, not a note candidate) is resolved by the leading underscore: `_session.md` is conventionally non-content (parallel to `_templates/`), so existing wiki tooling that scans `inbox/*.md` for true inbox notes can ignore underscore-prefixed files.

**Mitigation for git churn:** include `wiki/inbox/_session.md` in `.gitignore` *if* the user wants. Default to tracked (so the history is recoverable). This is a documented install-time choice, not an architectural lock-in.

**Caveat to surface:** the inbox-update skill must instruct Claude to never wiki-link *to* `_session.md` and never reference it from filed notes. Per `Rules.md` §9, things in `inbox/` "should not be linked from filed notes." This rule already covers us; we just need to remind Claude.

## Build Order

Five phases, each with a natural validation checkpoint. Risk decreases left-to-right.

### Phase 1 — Manual digest dry-run (de-risks the curator)
- Hand-author a `wiki/inbox/_session.md` with 5-10 fixture entries
- Build `wiki-curator.md` subagent + `digest` skill
- Build `wiki-rules` skill (thin pointer to `Rules.md`)
- Run `/digest` against the fixture
- **Checkpoint:** does the curator produce notes that pass `Rules.md` validation against the Traxalytics fixture? If no, the rest of the system is moot.
- **Why first:** the curator is the riskiest component (most reasoning, most rules to obey, hardest to validate). A working curator means the inbox schema is *consumable* — drives everything upstream.

### Phase 2 — In-session inbox protocol (de-risks the schema)
- Build `inbox-update` skill with the entry shape
- Manually trigger it (`/inbox-update`) in real coding sessions
- **Checkpoint:** after a multi-turn coding session with manual invocation, can the Phase-1 curator still digest the resulting inbox cleanly? If pruning broke handle uniqueness, fix the schema before automating the trigger.
- **Why second:** validates the schema in real-world conditions before you commit to firing it on every turn. A schema that breaks under hook automation is much harder to debug.

### Phase 3 — Stop hook automation (de-risks the trigger)
- Build the Stop hook with idempotency (turn-start timestamp, second-fire allow)
- Add the no-op escape: "if turn produced no codebase activity, write nothing and stop"
- Add the loop-protection cap (max 2 consecutive blocks per turn)
- **Checkpoint:** run a real coding session start to finish. Does the hook (a) update the inbox on work-bearing turns, (b) skip pure-conversation turns, (c) never loop, (d) cost <10% extra tokens per turn?
- **Why third:** the hook is the most operational risk (infinite loops, runaway cost). Validating the manual flow first means you know any breakage is the hook, not the schema.

### Phase 4 — Install flow (de-risks distribution)
- Build `install/install.sh` that copies `.claude/skills/`, `.claude/agents/`, and merges `.claude/settings.json` Stop hook entry
- Test against a fresh repo with an existing wiki that already has `wiki/Rules.md` and some category folders
- **Checkpoint:** can a second project consume the scaffolding without a single manual file edit? Does the hook fire correctly in the new repo's `.claude/`?
- **Why fourth:** distribution failures cascade — fixing them late means re-running phases 1-3 in a fresh environment.

### Phase 5 — Hardening + edge cases
- Wiki with 1000+ notes: does the digest tree-listing cost balloon?
- `disableSkillShellExecution` enabled: does the fallback path work?
- Concurrent digests: does the lockfile prevent corruption?
- `_session.md` deleted mid-session by user: does the next inbox-update recreate it gracefully?
- Pre-existing `inbox/` with non-underscore real inbox notes: does the curator leave them alone?
- **Checkpoint:** drop the scaffolding into 2-3 real projects of varying wiki sizes; run for a week; collect the entries that ended up in wrong categories and sharpen the curator system prompt.

### Validation Checkpoints (summary)

| After | Validate | Pass criterion |
|-------|----------|----------------|
| Phase 1 | Curator routes fixture inbox correctly | ≥80% of entries land in correct category, 0 Rules.md violations |
| Phase 2 | Inbox schema survives multi-turn use | Phase-1 curator still digests cleanly with no schema-induced errors |
| Phase 3 | Hook fires correctly + cheaply | Per-turn token overhead <10%; 0 infinite loops; 0 inbox writes on no-op turns |
| Phase 4 | Install works in a foreign repo | One-command install; first work-bearing turn updates inbox without manual setup |
| Phase 5 | Real-world durability | 7-day soak in 2+ projects with no manual intervention required |

## Anti-Patterns

### Anti-Pattern 1: Hook writes the inbox directly
**What people do:** Stop hook script edits `_session.md` itself, parsing the transcript JSON to extract what happened.
**Why it's wrong:** Hooks run as shell processes outside Claude's tool/permission surface. They have no semantic understanding ("did this Edit matter? was the file deleted right after?"). They produce mechanical, low-signal entries the digest agent then has to second-guess.
**Do this instead:** Hook nudges; Claude (with all its context) writes. The whole reason inbox entries are useful is that Claude judges what's worth recording.

### Anti-Pattern 2: Mirroring `wiki/Rules.md` into the wiki-rules skill body
**What people do:** Copy Rules.md content into `.claude/skills/wiki-rules/SKILL.md` so it's preloaded into the curator.
**Why it's wrong:** Two sources of truth. When a user edits `Rules.md` (which they're allowed to do — it's their wiki), the skill body silently goes stale. Curator obeys the wrong rules.
**Do this instead:** Skill body is a pointer: "Read `wiki/Rules.md` now. Treat its contents as the authoritative contract for this run." The curator reads fresh every time.

### Anti-Pattern 3: Append-only inbox log
**What people do:** Inbox is a chronological journal; entries are added but never removed; "function deleted" becomes a new entry contradicting an earlier one.
**Why it's wrong:** Pruning fails the locked design decision in `PROJECT.md`. Digest agent has to reconcile event ordering across an unbounded log. The "1+1 created+deleted" case produces two entries instead of zero.
**Do this instead:** State-of-world. Entries are mutable. Stale entries are removed via the handle-grep protocol.

### Anti-Pattern 4: Auto-running digest on a schedule or `SessionEnd`
**What people do:** Auto-trigger digest on `SessionEnd` hook so the user doesn't have to remember.
**Why it's wrong:** Per `PROJECT.md`, "Features rarely end at session boundaries." Auto-digest mid-feature splits one logical change across multiple notes, each with partial information. The digest is also non-trivial (writes many files) — not safe to run unattended.
**Do this instead:** Manual `/digest` only. Document the trigger; trust the user.

### Anti-Pattern 5: Curator inherits parent context (no `context: fork` discipline)
**What people do:** Run digest as a regular skill in the main session, or use a non-forked subagent that sees parent history.
**Why it's wrong:** Defeats the locked requirement "sub-agent has enough context from inbox alone." Curator that sees the parent conversation will rely on it, then break in any session that doesn't include the relevant turns (e.g., next-day digest of yesterday's inbox).
**Do this instead:** `context: fork` with explicit input injection. If the curator can't decide from inbox + wiki tree + Rules.md, that's a schema bug worth fixing — not a context bug to paper over.

### Anti-Pattern 6: Reading the whole inbox on every turn to find an entry to prune
**What people do:** "Just Read the whole file, find the entry, edit."
**Why it's wrong:** Per `PROJECT.md` cost constraint, "the update prompt must be cheap and avoid re-reading the entire inbox where possible." A 50-entry inbox at ~80 tokens each is 4000 tokens read every work-bearing turn.
**Do this instead:** Grep-first protocol. Use the handle line (`^@ <CATEGORY>::<slug>`) to locate the entry, then Read with line-range bounds (or just rewrite the block via Edit's `old_string` matching).

## Integration Points

### External (host = Claude Code runtime)

| Surface | Integration | Notes |
|---------|-------------|-------|
| `.claude/settings.json` :: `hooks.Stop` | Single hook entry, no matcher (Stop has none) | Verified against current docs; install script must merge, not overwrite |
| `.claude/skills/<name>/SKILL.md` | YAML frontmatter + markdown body | Live-watched; changes pick up without restart per current docs |
| `.claude/agents/<name>.md` | YAML frontmatter + system prompt body | Loaded at session start; manual creation requires session restart per docs |
| `CLAUDE_CODE_FORK_SUBAGENT=1` | Env var enabling `context: fork` | Experimental as of v2.1.117; document as a hard prerequisite. Fallback to named subagent if unset. |
| `disableSkillShellExecution` setting | If `true`, breaks `` !`<cmd>` `` injection in digest skill | Document; provide non-injection fallback path |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Stop hook ↔ Claude turn | Hook → Claude: `reason` field (one-way, text only). Claude → Hook: file mtime on inbox (the hook *observes* state, doesn't receive a return value) | Hook is stateless across fires; uses transcript timestamps + filesystem mtime for idempotency |
| inbox-update skill ↔ inbox file | Standard Read/Edit tools | Skill is stateless; the file *is* the state |
| digest skill ↔ curator subagent | Skill body is the prompt; bash injection provides inputs; `agent: wiki-curator` selects the system prompt | Forked subagent has no return channel besides its final message, which surfaces in main session |
| curator ↔ wiki/ filesystem | Read/Glob/Grep for inputs; Write/Edit for outputs; mv (Bash) for archive | All file ops go through Claude's permission system — `allowed-tools` in the curator definition pre-approves them |
| wiki-rules skill ↔ wiki/Rules.md | Skill body re-reads the file at activation | One-way; skill never writes to Rules.md |

## Non-Obvious Complexity Created by Locked Decisions

These follow from `PROJECT.md`'s locked decisions and would not be obvious to someone reading just that doc:

1. **State-of-world inbox + atomic flat entries → handle convention is load-bearing.** Without a stable handle (the `@ CATEGORY::slug` line), self-pruning either requires re-reading the whole file (violates the cost constraint) or relies on Claude's fuzzy memory of what entries exist (unreliable). The handle line isn't decoration — it's the index.

2. **Stop hook (not PostToolUse) → hook must be idempotent and self-detect "already done this turn".** PostToolUse fires per-tool with rich data; Stop fires once per turn boundary with almost no data. The idempotency check must come from outside (transcript timestamp + file mtime), not from hook input. This is a real engineering surface, not config.

3. **Multi-skill split + fork subagent → install footprint is wider than expected.** Three skills (`inbox-update`, `digest`, `wiki-rules`) plus one subagent plus one settings.json hook plus an env-var prerequisite. The install script has to merge into existing `settings.json` (not overwrite) and detect missing env vars. Phase 4 is non-trivial.

4. **Rolling per-project inbox → first-run bootstrapping has edge cases.** If a user adopts the scaffolding mid-project, `_session.md` doesn't exist on the first turn. The inbox-update skill needs an "if-not-exists, create with header" branch. Same applies if the user manually deletes the file or the archive.

5. **Manual `/digest` + state-of-world inbox → "what was tried and abandoned" signal is invisible by default.** The state-of-world model means deleted code leaves no trace. The `## Notable Detours` sub-section in the inbox is the escape valve, but it requires Claude to explicitly choose to record a detour — it's a recall problem, not a representation problem. The inbox-update skill must call this out.

6. **`wiki/inbox/_session.md` lives inside the wiki → must coexist with the existing `Rules.md` semantics for `inbox/`.** The leading underscore convention is the resolution, but the inbox-update skill needs to teach Claude this convention. A naive read of `Rules.md` says "inbox = candidates for filing" — the underscore-prefix carve-out is project-specific knowledge.

## Sources

- Claude Code Hooks documentation (verified 2026-04-28): https://code.claude.com/docs/en/hooks — confirmed Stop hook `decision:"block"` + `reason` mechanic, confirmed `additionalContext` is *not* available for Stop, confirmed exit-code-2 behavior. **HIGH confidence.**
- Claude Code Skills documentation (verified 2026-04-28): https://code.claude.com/docs/en/skills — confirmed SKILL.md format, frontmatter fields (`context: fork`, `agent`, `disable-model-invocation`, `allowed-tools`, `paths`), bash injection syntax (`` !`<cmd>` ``), `disableSkillShellExecution` setting. **HIGH confidence.**
- Claude Code Subagents documentation (verified 2026-04-28): https://code.claude.com/docs/en/sub-agents — confirmed `.claude/agents/` location, fresh-context default, `skills` preload field, `CLAUDE_CODE_FORK_SUBAGENT=1` requirement for fork mode (experimental, v2.1.117+). **HIGH confidence.**
- `wiki/Rules.md` (this repo): canonical convention contract; informs the curator's validation gate, the inbox-location decision, and the wiki-rules skill design. **HIGH confidence (it's the contract).**
- `.planning/PROJECT.md` (this repo): locked decisions. **HIGH confidence.**

Failure-mode estimates (the table in §"Data Flow") combine documented behavior with informed inference about edge cases — flagged **MEDIUM confidence** until validated in Phase 5 soak testing.

---
*Architecture research for: Claude Code skill+hook scaffolding (auto-maintained codebase wiki)*
*Researched: 2026-04-28*
