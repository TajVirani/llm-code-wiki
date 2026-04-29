# llm-code-wiki

## What This Is

A skill + hook scaffolding that makes Claude Code auto-maintain an Obsidian-style codebase wiki. A Stop hook nudges Claude to keep a session "inbox" file current as a state-of-the-world mirror of what's been built and decided; a digest sub-agent later reads the inbox and routes entries into properly-filed wiki notes per the wiki's `Rules.md`. Built for solo developers who want code documentation that stays current without manual upkeep.

## Core Value

Code documentation stays current and coherent without manual upkeep — including correctly pruning entries when code is deleted or superseded within the same session.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Hook config that triggers an inbox-update prompt after each Claude turn
- [ ] In-session skill defining how Claude updates the rolling inbox (atomic entries, flat structure, state-of-the-world semantics, self-pruning)
- [ ] Digest skill / slash command that spawns a sub-agent to convert inbox entries into filed wiki notes per `Rules.md`
- [ ] Inbox file lifecycle: rolling per-project file, archived on digest, fresh start after
- [ ] Sub-agent has enough context from inbox alone to make correct routing decisions (no session memory required)
- [ ] Self-pruning works for code artifacts removed mid-session (the "1+1 function created then deleted" case)
- [ ] Installation flow: skills + hook can be dropped into another repo alongside an existing wiki/ structure

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
| Inbox = state-of-the-world doc, not chronological log | Pruning is natural — when a function is deleted, its entry is removed; no contradiction between past events | — Pending |
| Atomic, flat entries (no in-session sectioning) | Lowers categorization burden during the session; digest agent routes holistically with full context | — Pending |
| Stop hook trigger (not PostToolUse) | One coherent inbox update per logical unit of work; Claude summarizes the turn rather than narrating every tool call | — Pending |
| Rolling per-project inbox, manual digest | Features rarely end at session boundaries; explicit digest gives a review checkpoint | — Pending |
| Multi-skill split (inbox upkeep + digest) | Different audiences (running Claude vs. fresh sub-agent), different triggers, different instructions | — Pending |
| Stop hook injection mechanism = decision:"block" + reason | Smoke test marker NOT visible on next turn (additionalContext silently dropped); docs at code.claude.com/docs/en/hooks whitelist additionalContext for SessionStart/Setup/SubagentStart/UserPromptSubmit/UserPromptExpansion/PreToolUse/PostToolUse/PostToolUseFailure/PostToolBatch — Stop is NOT in this list for synchronous hooks (verified live 2026-04-29). | Locked 2026-04-29 |

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
*Last updated: 2026-04-28 after initialization*
