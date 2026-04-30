# llm-code-wiki

## What This Is

A skill + hook scaffolding that makes Claude Code auto-maintain an Obsidian-style codebase wiki. A Stop hook nudges Claude to keep a session "inbox" file current as a state-of-the-world mirror of what's been built and decided; a digest sub-agent later reads the inbox and routes entries into properly-filed wiki notes per the wiki's `Rules.md`. Built for solo developers who want code documentation that stays current without manual upkeep.

## Core Value

Code documentation stays current and coherent without manual upkeep — including correctly pruning entries when code is deleted or superseded within the same session.

## Requirements

### Validated

- ✓ Stop hook triggers an inbox-update prompt after each Claude turn — v1.0 (CAPT-01)
- ✓ In-session skill defines rolling inbox maintenance (atomic flat entries, state-of-world, self-pruning) — v1.0 (CAPT-02..07)
- ✓ Digest skill / slash command spawns curator sub-agent and routes entries per Rules.md — v1.0 (DIGS-01..13)
- ✓ Rolling per-project inbox lifecycle with archive-before-write — v1.0 (LIFE-01..03)
- ✓ Curator routes from inbox alone with no session memory required — v1.0 (DIGS-02 fork + non-fork fallback)
- ✓ Self-pruning works for code artifacts removed mid-session (1+1-then-deleted release blocker) — v1.0 (CAPT-04 validated end-to-end)
- ✓ Bootstrap flow via `/wiki-install` skill — v1.0 (INST-01 reframed, INST-02, INST-03)

### Active

(None — v1.0 shipped. Run `/gsd-new-milestone` to define v1.1 scope.)

### Out of Scope

- Example Traxalytics wiki content — fixture only, not a deliverable
- Real-time sync, web UI, multi-user concerns — single-developer tooling
- Auto-digest on schedule — manual trigger only for v1
- Modifying the existing `wiki/Rules.md` conventions — those are a fixed contract
- Migrating existing wikis or backfilling docs from existing code

## Context

- The repo already contains a sample Obsidian wiki at `wiki/` for a fantasy hockey app (Traxalytics) — used as the test fixture for digest correctness.
- `wiki/Rules.md` defines the canonical conventions: kebab-case filenames, ≤25-word summaries, 1,000-word note cap, category folders (`ARCHITECTURE/`, `FUNCTIONS/`, `RESEARCH/`, `SELF/`, `DIAGRAMS/`), Obsidian wiki-link syntax.
- `wiki/_templates/note.md` is the canonical note schema (Summary, Tags, Created, Last Updated, Content, Related Notes).
- `wiki/inbox/` is currently empty — will host the rolling session inbox file.
- Claude Code hooks (Stop, PostToolUse, SessionEnd) are the integration surface; they can inject system reminders but cannot directly write files — Claude must execute the prompt the hook provides.
- This project produces tooling that ships into *other* projects' `.claude/` directories alongside their own wiki.

## Constraints

- **Tech stack**: Claude Code skill format (markdown + frontmatter) and `settings.json` hook config — no separate runtime
- **Compatibility**: Must respect existing `wiki/Rules.md` without modification
- **Hook semantics**: Stop hook fires once per assistant turn boundary; cannot directly mutate state — must inject a prompt that Claude executes
- **Cost**: Inbox updates run on every turn; the update prompt must be cheap and avoid re-reading the entire inbox where possible

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Inbox = state-of-the-world doc, not chronological log | Pruning is natural — when a function is deleted, its entry is removed; no contradiction between past events | ✓ Good (v1.0 — validated by CAPT-04 release blocker) |
| Atomic, flat entries (no in-session sectioning) | Lowers categorization burden during the session; digest agent routes holistically with full context | ✓ Good (v1.0) |
| Stop hook trigger (not PostToolUse) | One coherent inbox update per logical unit of work; Claude summarizes the turn rather than narrating every tool call | ✓ Good (v1.0 — live smoke test passed) |
| Rolling per-project inbox, manual digest | Features rarely end at session boundaries; explicit digest gives a review checkpoint | ✓ Good (v1.0) |
| Multi-skill split (inbox upkeep + digest) | Different audiences (running Claude vs. fresh sub-agent), different triggers, different instructions | ✓ Good (v1.0) |
| Stop hook injection mechanism = decision:"block" + reason | Smoke test marker NOT visible on next turn (additionalContext silently dropped); docs at code.claude.com/docs/en/hooks whitelist additionalContext for SessionStart/Setup/SubagentStart/UserPromptSubmit/UserPromptExpansion/PreToolUse/PostToolUse/PostToolUseFailure/PostToolBatch — Stop is NOT in this list for synchronous hooks (verified live 2026-04-29). | ✓ Good (Locked 2026-04-29; loop-protection trifecta in v1.0 hook script) |
| Hybrid override routing (curator) | Handle is default; content can override; overrides surfaced in plan. Phase 1 D-01. | ✓ Good (v1.0 fixture validated) |
| Auto-rewrite of `[[Title]]` backlinks on rename/split | Cleanest end-state vs. hub-note pattern; per-link target picked by surrounding context for splits. Phase 1 D-05/D-06. | ✓ Good (v1.0 — preserves aliases per D-07) |
| RESEARCH/ folder is curator-side read-only | Research is grounded source of truth; agents emit ALERT rows on same-concept hits instead of EDIT. Phase 1 D-19. | ⚠️ Revisit (decision captured; curator prompt enforcement deferred — see v1.0 audit tech debt) |
| Scratch-list + reconcile diff-pass (inbox-update) | Cheap per-turn cost (O(things-touched-this-turn)); evidence-grounded entries by construction. Phase 2 D-01. | ✓ Good (v1.0) |
| Hybrid pruning: cheap default + opportunistic full sweep | Most turns pay O(scratch-list); full sweep at >50 entries OR pre-digest catches out-of-band drift. Phase 2 D-02. | ✓ Good (v1.0) |
| `/wiki-install` skill (not bash installer) | Distribution of `.claude/` tree handled upstream (plugin/marketplace/manual); `/wiki-install` does only project-specific bootstrap. Phase 4 D-13. | ✓ Good (v1.0 — INST-01 reframed) |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-29 after v1.0 milestone shipped*
