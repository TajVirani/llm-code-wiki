# Phase 2: In-Session Inbox Skill - Context

**Gathered:** 2026-04-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the in-session "inbox-update" skill — the prompt Claude follows at end-of-turn to keep `wiki/inbox/_session.md` current. State-of-world semantics, atomic flat entries, self-pruning, evidence-grounded, cheap per-turn cost. Validates against the Phase 1 fixture loop end-to-end (the locked CAPT-04 1+1-then-deleted release blocker — Claude creates a function this turn, deletes it next turn, the inbox correctly contains zero entries for it after both turns).

In Phase 2 the skill is invoked **manually** (slash command or referenced doc — planner's call). Phase 3 will wire the Stop hook to invoke it automatically.

Owns 7 v1 requirements: CAPT-02, CAPT-03, CAPT-04, CAPT-05, CAPT-06, CAPT-07, LIFE-01.

Out of scope this phase: the Stop hook (Phase 3 — gated on Q1 resolution which Phase 1 locked as `decision:"block" + reason`); install flow (Phase 4); concurrent-session safety (HARD-01, Phase 5).

</domain>

<decisions>
## Implementation Decisions

### Diff-pass protocol (how Claude scopes "what changed this turn")
- **D-01:** **Scratch-list + reconcile.** When the inbox-update skill fires at end-of-turn, Claude has fresh memory of every tool call it just made (Edit, Write, Bash output). The skill prompt asks Claude to enumerate from its own turn-context what it touched (files created, modified, deleted; commands run that produced material output; explicit user requests acted on). For each touched thing, ensure the inbox has a current entry — add new, update existing, prune deleted. Cost: O(things-touched-this-turn). The scratch list IS the evidence base — automatically satisfies CAPT-06 evidence grounding for this turn's adds.

### Pruning trigger (when stale entries get removed)
- **D-02:** **Hybrid — cheap default + opportunistic sweep.**
  - **Every turn (cheap path):** prune only entries whose handle paths Claude itself deleted or superseded this turn (drawn from the same scratch-list as D-01). Cost: free — already part of the reconcile loop.
  - **Full sweep (opportunistic):** triggered by EITHER (a) inbox approaching the soft-cap (>50 entries via `grep -c '^@ '`) OR (b) the user is about to invoke `/digest`. Full sweep walks every entry's handle path, runs a Read or Glob check, removes entries whose targets no longer exist. Cost: O(N entries) but bounded by trigger frequency.
  - The cheap path covers the locked CAPT-04 release blocker (1+1-then-deleted is by definition a self-pruning case — Claude is the one who deleted, so the scratch list catches it). The full sweep is for out-of-band drift (user edits a file in their editor, another process moves files, etc.) — caught lazily.

### Notable Detours (where tried-and-abandoned approaches go)
- **D-03:** **Not in the inbox.** The inbox stays pure state-of-the-world per the locked PROJECT.md core decision. Tried-and-abandoned approaches live in git commit messages and the user's own session memory. Phase 2's skill prompt has ONE structural section (entries) plus the standard header — no `## Notable Detours` sub-section, no `@ DETOUR::` category, no sibling `_detours.md` file. Rationale: keeps the skill prompt simple, respects the locked anti-feature A8 (chronological log breaks self-pruning by construction), and avoids tempting Claude to over-document failed approaches into the wiki.

### Skill activation pattern (Phase 2 manual invocation)
- **D-04:** Phase 2 ships the skill as user-invocable (e.g., `/inbox-update` slash command) so it's testable manually before Phase 3 wires the Stop hook. Exact mechanism (slash command frontmatter vs. plain reference doc Claude is told to follow) is **planner's discretion** — the skill BODY is what matters; the activation surface is interchangeable. Phase 3 will reuse the same skill body, invoked via the hook's `decision:"block" + reason` payload.

### Carry-forward decisions (locked elsewhere; restated for the planner)
- **D-05:** Inbox path: `wiki/inbox/_session.md` (LIFE-01, Phase 1 D-11). Leading underscore convention parallels `_templates/`. Phase 1 created the placeholder; Phase 2 keeps writing to it.
- **D-06:** Entry handle convention: `@ CATEGORY::slug • path • #tags`, anchored at start of line for `^@ ` grep (CAPT-03, Phase 1 D-12). The `path` field is the source-of-truth path for self-pruning lookups (used by both the cheap scratch-list match in D-01 and the full sweep in D-02).
- **D-07:** "Inbox is a derived view of the codebase, not authoritative" framing (CAPT-07). The skill prompt's first paragraph must contain this framing so Claude does not push back on user code edits citing the inbox as source-of-truth.
- **D-08:** Cheap per-turn prompt (CAPT-05). The skill body must be short enough that running it every turn (Phase 3) does not balloon per-turn cost. Target: skill body ≤ 200 lines; per-turn additional context (the inbox itself) capped by the soft-cap mechanism in D-02.
- **D-09:** No-op turns write nothing (CAPT-05). If Claude's scratch-list is empty (the turn produced no codebase artifact and no explicit user request to record), the skill returns immediately without re-reading the inbox.
- **D-10:** D-19 from Phase 1 (RESEARCH/ folder is curator-side read-only) does NOT constrain Phase 2. The inbox-update skill is allowed to write `@ RESEARCH::slug` entries when Claude genuinely does new research; the curator at digest time decides routing per its own protocol. Phase 2 doesn't need to know about D-19.

### Claude's Discretion (planner's call)
- The exact wording of the "inbox is a derived view" framing (D-07) — must convey the intent
- Whether the skill is a slash command (`/inbox-update`) or a referenced doc — both work for Phase 2's manual mode
- The exact threshold for the full sweep in D-02 (>50 is the recommendation; ±10 either way is fine)
- How the skill detects pre-digest invocation — could check for `/digest` in the user's most recent prompt, or have the digest skill itself trigger the sweep before forking, or just leave it to the user's intuition (run `/inbox-update` then `/digest`)
- Whether the scratch-list is built from Claude reading its own conversation context (preferred) vs. from a structured input the runtime provides (if Claude Code adds a "tool calls this turn" surface later)
- Internal markdown structure of the skill body (sections, ordering)

</decisions>

<specifics>
## Specific Ideas

- The locked CAPT-04 release blocker test: Claude creates `add(a, b)` in `math.ts` on turn 1; the inbox-update skill records `@ FUNCTIONS::add • math.ts • #function #math`. On turn 2 Claude deletes `add`. The scratch-list reconcile (D-01 + D-02 cheap path) sees the deletion and prunes the entry. After both turns, the inbox contains zero entries for `add`. A digest at this point produces zero filed notes for `add`. This is the test fixture Phase 2 must pass.
- The Phase 1 placeholder at `wiki/inbox/_session.md` currently has the standard header from Phase 1 Plan 02 (or remnants from the Phase 1 acceptance test run). Phase 2 should reset it to the standard zero-entry state at start of work.
- The skill body's first paragraph (D-07) might read: "The inbox at `wiki/inbox/_session.md` is a derived view of what exists in the codebase right now. The codebase is ground truth. If you (Claude) ever find an inbox entry that contradicts what the user just asked you to do, the inbox is wrong — update it, do not push back on the user."
- Worked example for the skill prompt: explicitly include the 1+1-then-deleted case inline. "Turn 1: you wrote `add(a, b)`. You add the entry. Turn 2: the user asks you to remove `add`. You delete it. Your scratch list contains 'deleted math.ts:add'. You find the matching `^@ FUNCTIONS::add ` entry in the inbox and remove it. After this turn, the inbox has zero entries for `add`. Correct."

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### The wiki contract (LOCKED)
- `wiki/Rules.md` — Wiki conventions. Phase 2's skill body doesn't directly enforce Rules.md (the curator does that at digest time), but inbox entries should use the canonical category names from §2 (`ARCHITECTURE`, `FUNCTIONS`, `RESEARCH`, `SELF`, `DIAGRAMS`).

### Project context
- `.planning/PROJECT.md` — Locked decisions (state-of-world, atomic entries, Stop hook trigger, self-pruning) and the Q1 resolution row.
- `.planning/REQUIREMENTS.md` — CAPT-02..07 and LIFE-01 are this phase's territory.

### Phase 1 outputs (the consumers of this phase's work)
- `.planning/phases/01-foundation-curator/01-CONTEXT.md` — Phase 1 decisions D-01..D-19 (especially D-12 entry handle, D-19 RESEARCH/ read-only — curator-side only, doesn't constrain Phase 2).
- `.planning/phases/01-foundation-curator/01-04-SUMMARY.md` — Acceptance gate results; documents the deferred D-19 enforcement gap.
- `.claude/agents/wiki-curator.md` — The curator's protocol. Phase 2's inbox entries must produce content the curator can route correctly.
- `.claude/skills/digest/SKILL.md` — The digest skill body. Phase 2's full-sweep trigger (D-02) needs to coordinate with `/digest` invocation; planner decides exact mechanism.
- `tests/fixtures/_session-fixture.md` — The hand-authored fixture from Phase 1. Phase 2's skill must produce inbox content with the same shape (handle convention, atomic flat entries).

### Research outputs (Phase 2 territory)
- `.planning/research/SUMMARY.md` §"Recommended Build Order / Phase 2" — the schema design and skill body sketch.
- `.planning/research/ARCHITECTURE.md` §"Pattern 3: Atomic Flat Entries with Stable Handles" — the entry shape rationale and worked example.
- `.planning/research/PITFALLS.md` — Phase 2's relevant pitfalls: §2 (1+1-deleted, the four sub-failure modes — load-bearing for D-01/D-02 design), §5 (inbox bloat), §7 (inbox treated as authoritative — addressed by D-07), §8 (rationale lost — Phase 2 doesn't enforce, deferred to v2 DIFF-01), §13 (feature-scale accumulation — addressed by D-02 soft-cap), §15 (no-op turns — addressed by D-09), §16 (hallucinated entries — addressed by D-01 scratch-list).
- `.planning/research/FEATURES.md` §"Table-stakes T2/T3/T15" — Phase 2 deliverable boundaries.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`.claude/agents/wiki-curator.md`** (Phase 1 output) — The curator's 8-step protocol. Phase 2's inbox entries are this agent's input. Reading the curator helps Phase 2 understand what entry shape produces clean digest results.
- **`.claude/skills/digest/SKILL.md`** (Phase 1 output) — Reference for the slash-command frontmatter conventions if Phase 2's skill uses the same form.
- **`wiki/inbox/_session.md`** (Phase 1 placeholder) — The destination file. Phase 2 writes here. Currently in some post-test state — Phase 2 should reset to standard zero-entry state at start.
- **`tests/fixtures/_session-fixture.md`** (Phase 1 fixture) — The shape Phase 2's skill output should match. Useful as a reference for "this is what a populated inbox looks like."

### Established Patterns
- **Markdown-only delivery** — No Node/Python parser dependencies (anti-feature A10). Phase 2's skill is a markdown file with frontmatter; Claude executes its body when invoked.
- **Skill frontmatter format** — `name`, `description`, `allowed-tools`, optionally `disable-model-invocation` and `argument-hint`. Phase 1's wiki-rules and digest skills demonstrate the format.
- **Subagent skill preload** — Phase 1's wiki-curator preloads `wiki-rules`. Phase 2's skill is single-context (no subagent), so no preload concern.

### Integration Points
- **`/inbox-update` skill (or equivalent)** — entry point for Phase 2.
- **`wiki/inbox/_session.md`** — the read+write target.
- **Source-of-truth paths in handles** — entries' `path` fields point at real files in the codebase (Phase 2 doesn't enforce the path's validity at write time, but D-02's full-sweep validates it lazily).
- **Phase 3's hook (future) → this skill** — the Stop hook will inject a prompt that invokes this skill body. The skill body needs to be invocation-mechanism-agnostic.

</code_context>

<deferred>
## Deferred Ideas

- **`why:` rationale field on entries** (DIFF-01, v2) — Phase 2 doesn't require it. Future v2 work will add an optional rationale field, required for `@ DECISION::*` entries.
- **Soft-cap warning UX** (DIFF-03, v2) — Phase 2 implements the soft-cap as a sweep trigger (D-02) but does NOT surface a "consider running /digest" message to the user. v2 adds the user-visible nudge.
- **Concurrent-session safety** (HARD-01, Phase 5) — Phase 2 assumes a single Claude session writing to the inbox at a time. v1+ hardening adds a lockfile or per-session inbox files.
- **Out-of-band reconciliation** (HARD-03 `/reconcile`, Phase 5) — D-02's full sweep catches lazy out-of-band drift, but a thorough audit (walking all filed wiki notes, checking referenced symbols against the codebase) is the dedicated `/reconcile` skill. Phase 2 does not implement it.
- **D-19 enforcement in the curator prompt** (Phase 1 deferred gap) — not a Phase 2 concern; the inbox-update skill writes any category, the curator handles routing. If/when D-19 enforcement is implemented, Phase 2's skill body needs no change.

</deferred>

---

*Phase: 02-in-session-inbox-skill*
*Context gathered: 2026-04-29*
