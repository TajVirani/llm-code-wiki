# Project Research Summary

**Project:** llm-code-wiki — Claude Code skill + hook scaffolding that auto-maintains an Obsidian-style codebase wiki
**Domain:** AI-driven, auto-maintained documentation (skill + Stop hook + digest sub-agent over a markdown wiki)
**Researched:** 2026-04-28
**Confidence:** HIGH on Claude Code primitives and `Rules.md` semantics; MEDIUM on edge-case behavior pending soak testing; one CRITICAL contradiction must be resolved by Phase 0 (see §Critical Open Questions).

## Executive Summary

This project ships a small, no-runtime bundle of Claude Code primitives — three skills, one sub-agent definition, one Stop hook — that together turn any Claude Code session into a self-maintaining Obsidian wiki. The capture loop is a Stop hook that nudges Claude (the model) to update a single rolling state-of-the-world inbox file (`wiki/inbox/_session.md`); the consolidation loop is a manually invoked digest sub-agent that reads the inbox, the current wiki tree, and `wiki/Rules.md`, and routes entries into properly-filed category notes. The whole product is config + markdown; there is no daemon, no parser library, no embedded process. That's a deliberate design choice — the consumers of this scaffolding are other repos that already run Claude Code, and adding a runtime would defeat the install ergonomics.

Three findings shape every roadmap decision. **First:** the load-bearing build order is *backwards from intuition*. All four researchers independently agree that the curator/digest sub-agent must be built and validated against a hand-authored fixture inbox **before** the inbox-update skill, and the inbox-update skill must be validated under manual invocation **before** the Stop hook is wired up. The hook is the most operationally risky piece (infinite loops, runaway cost, silent failure) and also the *least diagnostic* — its failures look like "no notable changes." Building it first means debugging the schema, the routing, and the trigger simultaneously. **Second:** the user-stated hardest case — code created and deleted within the same session, with no resulting wiki note — is not a single problem but four sub-failure modes (Pitfalls research §2) that all share the same fix: every inbox entry must carry a stable, greppable handle so Claude can match-and-replace by target rather than by prose, and every entry must be framed as state-of-the-world, never as chronological log. The Architecture researcher's proposed entry shape — `@ CATEGORY::slug • path • #tags` — is the candidate convention; validating it against the 1+1 case is a Phase-1/2 release blocker. **Third:** there is one unresolved technical contradiction in the research about the Stop hook's injection mechanism (block+reason vs. additionalContext) that the first plan-phase MUST verify against current docs before any hook code is written.

The risks cluster on the hook side and the trust side. Hook risks: silent failure (Pitfall 4), reentry/infinite loop (Pitfall 3), mis-firing into sub-agent turns (Pitfall 1), and runaway cost on long sessions (Pitfall 5). Trust risks: digest writes junk into the wiki with no preview (Pitfall 11), Claude treats the inbox as authoritative and pushes back on user code edits (Pitfall 7), and hallucinated entries get filed as fact (Pitfall 16). The corresponding mitigations — heartbeat logging, `stop_hook_active` checks, transcript pre-filter for no-op turns, dry-run digest preview, "inbox is a derived view of code" framing in the skill body, evidence-grounded entries verified at digest time — are concrete and cheap relative to their value, but they all need to land before this is shipped to a real wiki the user cares about.

## Verified Facts (load-bearing mechanics we know are true)

These were confirmed by at least one researcher against current Claude Code docs and corroborated by the others. The roadmap can build on them without re-verification.

- **`Stop` and `SubagentStop` are distinct events.** The inbox hook registers on `Stop` only. Registering on both causes the digest sub-agent to thrash the inbox it's emptying.
- **`Stop` hooks have no `matcher` field.** They always fire on every parent assistant-turn boundary.
- **`stop_hook_active` is the loop-prevention bit** in the hook's stdin JSON. Any hook that ever returns `decision:"block"` MUST short-circuit when this is true. There is also a known Claude Code bug class (issue #10205) where even non-blocking hooks can loop — kill switch (`.claude/inbox/.disabled`) and a hard turn-counter cap are required, not optional.
- **Hooks cannot directly write project files in a way that respects user permissions.** The hook surface is a shell process outside Claude's tool/permission system. Pattern: hook nudges; Claude (the model) writes via its normal Edit tool.
- **`CLAUDE_PROJECT_DIR` is provided to hooks.** Use it instead of `pwd`/relative paths.
- **Skills and slash-commands have been merged.** `.claude/skills/foo/SKILL.md` produces `/foo`. Skills are the recommended form going forward (supporting-files dir, frontmatter feature set).
- **`context: fork` + `agent: <name>` is the documented way for a skill to spawn a fresh-context sub-agent** with a curated prompt. The forked sub-agent inherits zero of the parent conversation; the only channel from parent to sub-agent is the skill body (the prompt) and any bash-injection (`` !`<cmd>` ``) that ran in the parent.
- **Sub-agents support a `skills:` preload field** that injects skill bodies into the sub-agent's startup context.
- **`CLAUDE_CODE_FORK_SUBAGENT=1` is required (and experimental as of v2.1.117) for `context: fork`.** Without it, the digest skill must fall back to a non-forked named-subagent invocation. Install instructions must surface this.
- **Adding a top-level `.claude/skills/` directory that didn't exist at session start requires a Claude Code restart** to pick up. Newly-added skill subdirectories under an existing `.claude/skills/` are live-watched. Implication for install flow: warn the user to restart on first install.
- **Bash injection in skill bodies is gated by `disableSkillShellExecution`.** If a consumer sets it true, the digest skill's `` !`cat wiki/inbox/_session.md` `` injection silently produces nothing. The skill needs a Read/Glob fallback path.
- **Obsidian wiki-link resolution is by display title, not filename.** Renaming a note's H1 silently breaks all `[[Title]]` backlinks. Splits and renames require a backlink-update pass.
- **`wiki/Rules.md` is the authoritative contract** (§2 categories, §3 template, §4 1,000-word split, §5 kebab-case, §7 wiki-links, §8 deprecation policy, §9 inbox/templates special status, §10 surface-conflicts-before-acting). The skill and curator must respect it literally and never modify it autonomously.
- **The leading-underscore convention in `wiki/inbox/_session.md`** is the resolution to the semantic stretch of putting a state-of-world doc inside a folder Rules.md describes as a staging area for note candidates. `_templates/` already establishes the precedent.

## Critical Open Questions (must resolve before code is written)

### Q1 — CRITICAL — Stop hook injection mechanism: `additionalContext` vs `decision:"block" + reason`

The researchers disagree, and the disagreement is load-bearing for Phase 1.

- **Stack research (HIGH confidence):** `hookSpecificOutput.additionalContext` is the right mechanism for Stop hooks. It injects context into Claude's *next* turn without forcing immediate continuation, sidestepping the loop class entirely. `decision:"block"` triggers a forced-continuation cycle and a documented bug history (issues #3573, #10205).
- **Architecture research (HIGH confidence):** `additionalContext` is whitelisted **only** for `UserPromptSubmit` / `SessionStart` / `PreToolUse` / `PostToolUse` / `UserPromptExpansion` — **not Stop**. Stop hooks must use `decision:"block"` with a `reason` field that surfaces to Claude as system feedback within the current turn. The whole "hook nudges, Claude writes within the same turn" pattern depends on this.
- **Pitfalls research (HIGH confidence on the loop hazard):** Treats `decision:"block"` + `stop_hook_active` check as the canonical pattern but acknowledges non-blocking injection is preferable when feasible.

These cannot all be true. Two architecturally different products fall out of the resolution:

- **If `additionalContext` is supported on Stop:** the inbox update happens on Claude's *next* turn. Hook is single-fire per turn boundary, no loop class, no idempotency check on Claude's side. The flow becomes "user prompts → Claude responds → Stop hook injects nudge → user prompts again → Claude updates inbox first, then handles new prompt." The user pays a small latency on the next turn, not the current one. The 1+1-then-deleted case still works because the *next* turn still has full context.
- **If `additionalContext` is not supported on Stop and we must use block+reason:** the inbox update happens *within* the current turn (before stop is allowed). The hook becomes two-fire-per-work-turn (block once, allow on second fire). Idempotency relies on transcript timestamps + inbox file mtime (Architecture's pseudo-code). Loop-protection (`stop_hook_active`, kill switch, hard cap) becomes mandatory.

**Resolution requirement before Phase 1 implements anything hook-related:**
- Read the *current* Claude Code Hooks reference at `code.claude.com/docs/en/hooks`, not cached training-data versions.
- Specifically check: which `hookSpecificOutput.hookEventName` values accept `additionalContext`? Does Stop appear in the list?
- Run a one-line smoke test: emit `{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"test"}}` from a Stop hook and observe whether Claude sees "test" on the next turn.
- Pick one mechanism, document the choice in PROJECT.md Key Decisions, and design the rest of Phase 1 around it.
- **Do not silently pick one side based on which researcher seems more confident.** Both are confident; both cite docs.

### Q2 — Inbox file path: `wiki/inbox/_session.md` (recommended) vs alternatives

Architecture research recommends `wiki/inbox/_session.md`. Stack research treats `wiki/inbox/<file>.md` as a pattern. The leading underscore convention (parallel to `_templates/`) resolves the semantic conflict with Rules.md §1's "inbox = note candidates" framing. **Promote from open question to recommendation:** use `wiki/inbox/_session.md`. Phase-1 fixture work will validate.

Sub-decision still open: per-session file (`_session-<session_id>.md`) vs single rolling file. Pitfalls §6 argues per-session is required for concurrent-session safety; Architecture argues single rolling for simplicity. Resolution: start with single-rolling, but design the inbox-update skill so the path is one variable — switching to per-session in Phase 5 should be a one-line skill change, not an architecture change.

### Q3 — Entry handle convention

Architecture proposes `@ CATEGORY::slug • path • #tags` as the handle line, anchored at start (`^@ `) for cheap grep. This is **load-bearing for self-pruning** (Pitfalls §2): without a stable handle, pruning either re-reads the whole inbox (violates cost constraint) or relies on Claude's fuzzy memory (unreliable). **Promote from candidate to recommendation.** Phase 1's fixture inbox uses this shape; Phase 1 validates it against the curator before Phase 2 codifies it in the inbox-update skill.

### Q4 — Rationale capture in inbox entries

Pitfalls §8 argues every decision-class entry must carry a `why:` field or rationale gets dropped at digest time (atomic flat entries lose linking context, sub-agent has no parent context to reconstruct from). Features research treats this as a v2 differentiator (D1). Resolution: include an optional rationale field in the Phase-1 entry schema; require it for entries Claude classifies as decisions (`@ DECISION::*`); leave it blank for function/architecture entries. Cheap to add upfront, expensive to retrofit.

### Q5 — Digest preview/dry-run mode

Features research lists D2 (dry-run) as the "highest user-trust ROI differentiator" but assigns it P2 (post-MVP). Pitfalls research §11 lists "no preview/rollback" as a critical pitfall and flags preview as "core, not optional." **Resolution:** preview mode is core. The digest skill should produce a plan as its first response, validate the plan against Rules.md, and only proceed to Write/Edit calls after the plan passes validation. This is the Architecture researcher's Pattern 5 ("Curator Proposes-Then-Applies"). Cost is small relative to the trust win and the rollback insurance.

## Recommended Build Order (digest-first, NOT hook-first)

All four researchers independently arrived at this ordering. It inverts the natural assumption "build the trigger first." Capture this clearly: the hook is the riskiest piece *and* the least diagnostic — building it first means debugging schema, routing, and trigger simultaneously, with no fixture to test against and no manual fallback.

### Phase 0 — Resolve Q1 + scaffold layout
**Rationale:** Q1's resolution determines Phase 1's hook design. Settle it first.
**Delivers:** Documented choice (block+reason vs additionalContext) in PROJECT.md; empty `.claude/skills/{inbox-update,digest,wiki-rules}/`, `.claude/agents/digest-router.md`, `.claude/settings.json` skeletons; `wiki/inbox/_session.md` placeholder. No behavior yet.
**Avoids:** Designing hooks twice.

### Phase 1 — Curator + manual digest against a hand-authored fixture
**Rationale:** The curator is the riskiest reasoning component (most rules, hardest to validate, most expensive failure mode). A working curator means the inbox schema is *consumable* — it drives every upstream decision. Validating against a hand-authored fixture inbox decouples curator correctness from hook correctness.
**Delivers:**
- `wiki-curator.md` sub-agent (allowed-tools: Read, Write, Edit, Glob, Grep)
- `wiki-rules` skill — thin pointer that re-reads `wiki/Rules.md` at activation (NOT a mirror)
- `digest` skill with `context: fork` (and a non-fork fallback path for `CLAUDE_CODE_FORK_SUBAGENT=0`)
- Pattern 5: curator emits a routing plan first; validates against Rules.md; only then writes
- Hand-authored fixture `_session.md` with 5–10 entries using the candidate `@ CATEGORY::slug • path • #tags` shape, including the 1+1-then-deleted case
- Backlink-aware split logic + post-digest unresolved-link audit
- Rules.md lint pass on every filed note (filename regex, ≤25-word summary, template fields, wiki-link syntax)
- Archive-then-write order: inbox archived to `wiki/inbox/_archive/<timestamp>-session.md` *before* notes are written (so a crash mid-write doesn't lose entries)

**Addresses:** T4, T5, T6, T7, T8, T9, T10, T11, T12, T14, D2 (preview), D5 (link validation), D8 (self-check)
**Avoids:** Pitfall 8 (rationale lost), 9 (duplicates), 10 (cross-link rot on split), 11 (junk/no-preview), 12 (Rules violations)
**Validation gate:** ≥80% of fixture entries land in correct category, 0 Rules.md violations, 1+1-then-deleted case produces zero notes.

### Phase 2 — In-session inbox-upkeep skill (manual invocation)
**Rationale:** Validates the schema in real-world conditions before committing to firing it on every turn. A schema that breaks under hook automation is much harder to debug.
**Delivers:**
- `inbox-update` skill body with the `@ CATEGORY::slug • path • #tags` schema
- "Inbox is a derived view of code, not authoritative" framing as the skill's first sentence (Pitfall 7)
- Worked 1+1-then-deleted example inline in the skill (Pitfall 2 framing)
- Diff-pass protocol: "for each entry, does target still exist? if not, remove. then add new." Not "what changed this turn — append."
- Grep-first prune protocol: `^@ CATEGORY::<slug>` to locate, then Edit the block (Pitfall 5, cost discipline)
- Optional `why:` field; required for `@ DECISION::*` entries (Pitfall 8)
- Evidence-grounded entries: every entry must correspond to an Edit/Write tool call this turn or an explicit user request (Pitfall 16)
- "If turn produced no codebase artifact, write nothing" no-op guidance (Pitfall 15)
- Self-creating: if `_session.md` doesn't exist, create with header (bootstrapping)
- Soft cap at 30–50 entries: skill prompts "consider running `/digest`" (Pitfall 5, 13)
- "Notable Detours" sub-section escape valve for tried-and-abandoned signal

**Addresses:** T2, T3, T15
**Avoids:** Pitfalls 2, 5, 7, 8, 13, 15, 16, 17 (audit via grep on stable handles)
**Validation gate:** after a multi-turn coding session with manual `/inbox-update` invocation, the Phase-1 curator still digests cleanly. Specifically: 1+1-then-deleted produces zero filed notes; no entries reference filing actions; ask-Claude-to-delete-code-with-an-inbox-entry produces no pushback.

### Phase 3 — Stop hook automation
**Rationale:** Hook is the most operationally risky piece (infinite loops, runaway cost, silent failure). Validating Phases 1–2 manually first means any breakage observed here is the hook, not the schema or the curator.
**Delivers:**
- Stop hook script using the mechanism chosen in Q1
- Heartbeat: every fire writes timestamp + session_id + outcome to `.claude/inbox/.hook-log` (Pitfall 4)
- Kill switch: `.claude/inbox/.disabled` short-circuits the hook (Pitfall 3)
- Hard cap: per-turn fire counter exits 0 unconditionally after 2 fires for the same turn (Pitfall 3, defends against issue #10205)
- `stop_hook_active` check at the top of the script (Pitfall 3, mandatory regardless of Q1 resolution)
- Transcript pre-filter: if no Edit/Write/MultiEdit tool calls in the latest turn, exit 0 without nudging (Pitfall 15)
- Idempotency: if inbox mtime > turn-start timestamp, the hook believes Claude already updated this turn; allows stop (applies if Q1 resolves to block+reason)
- `CLAUDE_PROJECT_DIR` for absolute paths (Pitfall 4)
- Explicit timeout (10s for the bash work)
- Registered on `Stop` only, never `SubagentStop` (Pitfall 1)
- Defensive in-prompt guard: "If the only changes this turn were to wiki/* files, do nothing" (Pitfall 1)

**Addresses:** T1
**Avoids:** Pitfalls 1, 3, 4, 15
**Validation gate:** real coding session start-to-finish: hook updates inbox on work-bearing turns, skips pure-conversation turns, never loops, costs <10% extra tokens per turn, heartbeat file shows recent entries.

### Phase 4 — Install flow
**Rationale:** Distribution failures cascade. Fixing them late means re-running Phases 1–3 in a fresh environment.
**Delivers:**
- `install/install.sh`: copies `.claude/skills/`, `.claude/agents/`; merges Stop hook entry into existing `.claude/settings.json` (does NOT overwrite)
- Smoke test: trigger a Stop, verify heartbeat appears, fail loudly if not (Pitfall 4)
- Worktree warning: detect git worktrees and warn about shared `.claude/` (Pitfall 6)
- Documents `CLAUDE_CODE_FORK_SUBAGENT=1` requirement and `disableSkillShellExecution` interaction
- Documents the Q1 resolution and any prerequisites
- Documents the explicit gap: "this system does not currently audit the wiki against the codebase — run `/reconcile` periodically (or accept some drift)" (Pitfall 14)
- README that names anti-features explicitly (no real-time sync, no auto-digest, no backfill, no Rules.md modification) so consumers don't ask

**Addresses:** T13, T14
**Avoids:** Pitfalls 4 (silent failure on install), 6 (worktree collision), distribution drift
**Validation gate:** one-command install in a fresh repo with an existing wiki produces a working setup; first work-bearing turn updates the inbox without manual intervention.

### Phase 5 — Hardening + audit tooling
**Rationale:** Real-world soak surfaces edge cases that fixture testing cannot.
**Delivers:**
- 1000-note wiki performance: tree-listing strategy under load
- Concurrent-session lock: `wiki/inbox/.lock` write-and-rename, refuse if exists; or per-session inbox files
- Chunked/clustered digest mode for 200+ entry inboxes (Pitfall 13)
- `/reconcile` skill: walk filed notes, grep codebase for referenced symbols, surface ghost notes per Rules.md §8 (Pitfall 14)
- `/inbox-status` slash command: entry count, oldest age, sessions represented (Pitfall 17)
- `inbox/last-digest.md` audit artifact (Pitfall 11, 17)
- Soak in 2–3 real projects of varying wiki sizes for a week; collect mis-routed entries; sharpen curator system prompt

**Addresses:** D3 (per-feature scope, optional), D4 (bloat warning), D7 (SELF/ snapshot)
**Avoids:** Pitfalls 6, 13, 14, 17

### Why this order

- **Curator before inbox skill** because the curator is the consumer of the inbox schema. Designing a schema before knowing what the consumer needs produces schemas that don't survive consumption.
- **Inbox skill before hook** because the inbox skill is the prompt that runs every turn. Wiring the hook before the prompt is debugged means every prompt-bug looks like a hook-bug.
- **Hook before install** because the hook is the part most likely to fail silently in a foreign environment. Install validates that a working hook still works elsewhere — there's no point validating an install of something that doesn't work locally.
- **Install before hardening** because hardening is informed by real usage, and real usage requires consumers, and consumers require install.

## Table-Stakes Features (must-have-or-broken)

The product fails its core promise if any of these is missing.

- **T1 Stop-hook trigger after each turn** — the capture loop. Without it, nothing else runs.
- **T2 In-session inbox-upkeep skill** — defines what gets written and how (atomic flat entries, state-of-world, self-pruning rules).
- **T3 Self-pruning of superseded entries within a session** — the 1+1 case is the locked validation criterion. State-of-world semantics make this natural; chronological logs make it impossible.
- **T4 Manually triggered digest skill / slash command** — the consolidation loop. Without it the inbox grows forever.
- **T5 Note routing into category folders** — Rules.md §2 defines five canonical folders. Misrouting = wiki incoherence.
- **T6 Template conformance** — Rules.md §3 mandates the schema. Skipped template = invalid wiki note.
- **T7 Kebab-case filenames** — Rules.md §5. Mismatch breaks greppability.
- **T8 Conflict handling: existing-note detection (edit vs create)** — Rules.md §8. Duplicates are how wikis rot.
- **T9 1,000-word split rule** — Rules.md §4. Skipping produces unreadable mega-notes.
- **T10 Cross-link maintenance with `[[Note Title]]`** — Rules.md §7. Hardcoded paths break on rename.
- **T11 Idempotence of digest** — running twice on the same archived inbox must be a no-op. Achieved via T12 (archive-on-complete).
- **T12 Rolling per-project inbox lifecycle** — one file per project, archived on digest, fresh start after.
- **T13 Installable into another repo** — the product *is* the scaffolding.
- **T14 No-modification of `wiki/Rules.md`** — Rules.md is the contract; the digest agent may *propose* rule changes, never apply them autonomously.
- **T15 Cheap inbox-update prompt** — runs every turn; expensive prompt makes the system unusable.

Plus two safety nets that Pitfalls research promotes from "differentiator" to "table-stakes":

- **D2 (preview-by-default in digest)** — Pitfalls §11 frames this as "core, not optional." Trust insurance against destructive mistakes.
- **D5 (post-digest link validation pass)** — Pitfalls §10 frames cross-link rot as a critical pitfall. Cheap mechanical check; catches the most common Obsidian failure.

## Anti-Features (deliberate non-goals)

- **A1 Real-time wiki sync as code changes.** Hooks can't write files; would require a runtime; mid-stream updates can't see the 1+1-deleted pattern correctly. *Instead:* Stop-hook + manual digest at logical boundaries.
- **A2 Multi-user / collaborative concerns.** Single-developer tooling per PROJECT.md. *Instead:* document the assumption; users running shared wikis use git.
- **A3 Web UI / browser viewer.** Plain markdown already works in Obsidian, VS Code preview, GitHub, `cat`. *Instead:* rely on existing markdown viewers.
- **A4 Schedule-based auto-digest.** Auto-digest mid-feature splits one logical change across multiple notes. Scheduled runs happen when no human reviewer is present — exactly when D2 preview is useless. *Instead:* manual `/digest` + D4 self-monitoring nudge.
- **A5 Backfilling docs from existing code.** Different task (batch summarization, not capture-while-building). *Instead:* users bring or write a starter wiki; we maintain it from there.
- **A6 Migrating between wiki conventions.** The value lies in respecting *one* fixed contract. *Instead:* document Rules.md; users fork to target other conventions.
- **A7 Modifying `wiki/Rules.md`.** Locked PROJECT.md constraint. *Instead:* digest may *propose* rule changes to the user, never edit autonomously.
- **A8 Chronological session log inside the inbox.** Breaks T3 self-pruning by construction. The 1+1-deleted case produces two contradictory entries instead of zero. *Instead:* state-of-the-world. History lives in git.
- **A9 In-session note sectioning / pre-routing.** Forces categorization decisions when context is partial. *Instead:* flat inbox; sub-agent routes holistically at digest time.
- **A10 Semantic-similarity duplicate detection.** Requires embeddings runtime — violates no-runtime constraint. *Instead:* filename + title + tag overlap; surface ambiguous matches in D2 preview.
- **A11 Auto-commit of digest results.** Mixes documentation work with version control work; conflicts with D2 dry-run. *Instead:* digest writes files; user stages and commits.
- **A12 Modifying source code based on inbox observations.** Massive scope creep — the skill is a documentation tool, not a refactoring agent. *Instead:* surface the contradiction in the digest plan; let the user decide.

## Top Pitfalls Flagged with Mitigation Phase

The seventeen pitfalls in PITFALLS.md cluster into five themes. Top-by-severity, with the phase that should mitigate them:

1. **Stop hook reentry / infinite loop (Pitfall 3)** — Phase 0 (Q1 resolution) + Phase 3 (implementation). Mandatory `stop_hook_active` check, kill switch, hard turn-counter cap.
2. **The 1+1-then-deleted case (Pitfall 2)** — Phase 1 fixture (release blocker test); Phase 2 skill design (stable handles, state-of-world framing, diff-pass protocol, evidence requirement); Phase 3 safety net.
3. **Stop hook fires for sub-agents and thrashes the inbox (Pitfall 1)** — Phase 3. Register on `Stop` only; defensive in-prompt guard for wiki-only turns.
4. **Stop hook silent failure (Pitfall 4)** — Phase 3 (heartbeat + `CLAUDE_PROJECT_DIR`); Phase 4 (install smoke test).
5. **Digest writes junk into the wiki with no preview (Pitfall 11)** — Phase 1. Preview-by-default. Two-phase deletion of inbox entries. Digest report as audit artifact.
6. **Inbox treated as authoritative; Claude pushes back on user code edits (Pitfall 7)** — Phase 2. Skill's first sentence: "the inbox is a derived view of the codebase. The codebase is ground truth."
7. **Digest creates duplicates instead of editing (Pitfall 9)** — Phase 1. Mandatory wiki-index pass as the first step in the digest skill.
8. **Cross-link rot on splits (Pitfall 10)** — Phase 1. Pre-split backlink scan; hub-note pattern for splits per Rules.md §8; post-digest unresolved-link audit.
9. **Rules.md violations silently accruing (Pitfall 12)** — Phase 1. Mechanical lint pass on every filed note.
10. **Inbox bloat balloons per-turn cost (Pitfall 5)** — Phase 2 (compact handle format, soft cap at 30–50, transcript-scoped diff).
11. **Concurrent sessions corrupt the inbox (Pitfall 6)** — Phase 5 (per-session inbox files); Phase 4 (worktree warning in install README).
12. **Hook noise on debug/REPL turns (Pitfall 15)** — Phase 3 (transcript pre-filter); Phase 2 (no-op guidance in skill).
13. **Hallucinated entries (Pitfall 16)** — Phase 2 (evidence-grounded entries); Phase 3 (curator verifies target exists before filing).
14. **Wiki diverges from codebase — ghost notes (Pitfall 14)** — Phase 5 or v2 (`/reconcile` skill); Phase 4 (document the gap explicitly in install README).
15. **Sub-agent missing rationale (Pitfall 8)** — Phase 2 (optional `why:` field, required for `@ DECISION::*` entries); Phase 1 (curator preserves `why` in filed notes' Content section).
16. **Feature-scale inbox accumulation (Pitfall 13)** — Phase 2 (threshold prompts at 50/100); Phase 5 (chunked/clustered digest for 200+ entries).
17. **User can't audit (Pitfall 17)** — Phase 2 (stable handles enable `grep target:auth inbox/*.md`); Phase 1 (digest report); Phase 5 (`/inbox-status` slash command).

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack — skill/agent/hook formats | HIGH | All four researchers verified against current docs (April 2026). |
| Stack — Stop hook injection mechanism | LOW (CRITICAL) | Researchers disagree (Q1). Must be resolved before Phase 1. |
| Features — table stakes | HIGH | Driven by Rules.md (locked contract) + PROJECT.md decisions. |
| Features — anti-features | HIGH | Crisp, cited reasoning. Each ties to a specific failure mode. |
| Architecture — component layout | HIGH | Stack and Architecture researchers converge on the same `.claude/{skills,agents,hooks}` + `wiki/inbox/_session.md` shape. |
| Architecture — entry handle convention | MEDIUM | Reasoned proposal, not externally validated. Phase 1 fixture validates. |
| Architecture — inbox file location | HIGH | `wiki/inbox/_session.md` with leading underscore is the recommended resolution. |
| Pitfalls — hook mechanics | HIGH | Verified against official hooks reference + multiple GitHub issues. |
| Pitfalls — inbox-side failure modes | MEDIUM | Reasoned from documented LLM patterns; verified by Phase 1/2 fixtures. |
| Pitfalls — digest-side failure modes | MEDIUM | Comparable systems (AutoDream, claude-mem) validate the failure-mode catalog. |

**Overall confidence:** HIGH on direction, MEDIUM on specifics until Q1 is resolved.

### Gaps to Address

- **Q1 (additionalContext vs block+reason on Stop) — CRITICAL.** Resolve in Phase 0.
- **Q2 (per-session vs single rolling inbox file).** Defer to Phase 5 but design Phase 2 path-as-variable.
- **Q3 (entry handle convention).** Promoted to recommendation; validate in Phase 1 fixture.
- **Q4 (rationale field).** Add as optional in Phase 2 schema, required for `@ DECISION::*`.
- **Q5 (digest preview).** Promoted from differentiator to table-stakes per Pitfalls §11.
- **Wiki↔codebase reconciliation (Pitfall 14).** Not currently in PROJECT.md Active. Either add as Active for Phase 5, or explicitly defer to v2 in PROJECT.md Out of Scope.
- **`CLAUDE_CODE_FORK_SUBAGENT` experimental status.** Design fallback path (Phase 1).
- **`disableSkillShellExecution` interaction.** Document; provide Read/Glob fallback (Phase 1).

## Sources

### Primary (HIGH confidence — official Claude Code docs, verified 2026-04-28)

- Claude Code Skills reference (code.claude.com/docs/en/skills)
- Claude Code Hooks reference (code.claude.com/docs/en/hooks) — *Q1 disagreement is here*
- Claude Code Sub-agents reference (code.claude.com/docs/en/sub-agents)
- Subagents in the SDK (platform.claude.com/docs/en/agent-sdk/subagents)
- GitHub anthropics/claude-code#3573, #10205, #27311, #33049, #8079
- Obsidian Help — Internal Links / Aliases
- /mnt/f/Projects/llm-code-wiki/.planning/PROJECT.md
- /mnt/f/Projects/llm-code-wiki/wiki/Rules.md

### Secondary (MEDIUM confidence — community + comparable systems)

- Claude Code Stop Hook task enforcement (claudefa.st)
- Claude Code AutoDream overview (MindStudio)
- thedotmack/claude-mem (alternative architecture)
- DocuWriter.ai Autopilot (orthogonal scope)
- ADR catalog (rationale-capture pattern)
- Smart Rename — Obsidian Plugin
- kubectl dry-run + diff (preview mental model)

### Tertiary (LOW confidence — directional)

- Cursor AI Resolve Conflicts
- Documentation Drift (gaudion.dev)
- "How I stopped Claude Code from hallucinating" (DEV Community)

---
*Research synthesized: 2026-04-28*
*Ready for roadmap: yes — pending Q1 resolution in Phase 0*
