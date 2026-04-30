# Roadmap: llm-code-wiki

**Project:** llm-code-wiki — Claude Code skill + hook scaffolding that auto-maintains an Obsidian-style codebase wiki
**Created:** 2026-04-28
**Granularity:** coarse (favors fewer, broader phases)
**Build order:** digest-first, hook-last (per all four research streams; see `research/SUMMARY.md` §"Recommended Build Order")

## Core Value

Code documentation stays current and coherent without manual upkeep — including correctly pruning entries when code is deleted or superseded within the same session.

## Phases

- [ ] **Phase 1: Foundation + Curator** — Resolve Q1 (Stop hook injection), scaffold layout, build the digest sub-agent against a hand-authored fixture inbox until it routes cleanly per `wiki/Rules.md`.
- [ ] **Phase 2: In-Session Inbox Skill** — Build the `inbox-update` skill body with stable handles and state-of-world semantics; validate end-to-end against the Phase 1 curator including the 1+1-then-deleted fixture test.
- [ ] **Phase 3: Stop Hook Automation** — Wire the Stop hook so the inbox-update skill fires automatically after each work-bearing turn, with loop protection, heartbeat, and no-op filtering.
- [ ] **Phase 4: Install & Distribution** — One-command install into a target repo with smoke-test verification and README documenting prerequisites, anti-features, and the wiki-codebase reconciliation gap.

## Phase Details

### Phase 1: Foundation + Curator

**Goal**: A user can run `/digest` against a hand-authored fixture inbox and the curator sub-agent produces a routing plan that validates against `wiki/Rules.md`, then writes correctly-templated notes into category folders, archives the inbox before writing, and is idempotent on a fresh post-archive run.

**Depends on**: Nothing (first phase). Must begin by resolving SUMMARY.md Q1 (Stop hook `additionalContext` vs `decision:"block"+reason`) since that decision shapes Phase 3 — but Phase 1 itself touches no hook code, only documents the choice.

**Requirements**: DIGS-01, DIGS-02, DIGS-03, DIGS-04, DIGS-05, DIGS-06, DIGS-07, DIGS-08, DIGS-09, DIGS-10, DIGS-11, DIGS-12, DIGS-13, LIFE-02, LIFE-03

**Success Criteria** (what must be TRUE):
  1. Q1 (Stop hook injection mechanism) is resolved against current Claude Code docs + a smoke test, the chosen mechanism is documented in `PROJECT.md` Key Decisions, and `.claude/{skills,agents}/` plus `wiki/inbox/_session.md` placeholders exist.
  2. Running `/digest` against a hand-authored fixture inbox (5–10 entries using the `@ CATEGORY::slug • path • #tags` shape) produces a preview plan first, validates the plan against `Rules.md` (kebab-case, ≤25-word summaries, ≤1,000-word bodies, canonical category folders, template fields, `[[Title]]` wiki-link form), and only then writes files.
  3. The curator detects when an inbox entry covers an already-filed concept and edits the existing note (bumping `Last Updated`) rather than creating a duplicate; running digest a second time on a fresh post-archive inbox is a no-op.
  4. The inbox is archived to `wiki/inbox/_archive/<timestamp>-session.md` *before* any new notes are written, and a post-write link-validation pass surfaces any unresolved `[[...]]` references in the digest report.
  5. The curator never modifies `wiki/Rules.md`; rule-change suggestions surface in the plan as proposals for the user to apply manually.

**Plans**: 4 plans (3 waves)

Plans:
- [x] 01-01-PLAN.md — Q1 resolution (BLOCKING) + scaffolding + 5-sub-case fixture authoring
- [x] 01-02-PLAN.md — wiki-rules skill (thin pointer) + wiki-curator subagent definition
- [ ] 01-03-PLAN.md — digest skill (orchestration: archive → fork → audit) + non-fork fallback
- [ ] 01-04-PLAN.md — Acceptance gate against fixture (validates all 15 requirements)

---

### Phase 2: In-Session Inbox Skill

**Goal**: A user manually invoking `/inbox-update` after a coding turn produces a `wiki/inbox/_session.md` whose state-of-world entries the Phase 1 curator can digest cleanly, including the locked validation gate: a session that creates and then deletes a function within the same fixture run produces zero filed notes after digest.

**Depends on**: Phase 1 (curator must exist to validate that the inbox schema is consumable; inbox file path `wiki/inbox/_session.md` is established by Phase 1 scaffolding).

**Requirements**: CAPT-02, CAPT-03, CAPT-04, CAPT-05, CAPT-06, CAPT-07, LIFE-01

**Success Criteria** (what must be TRUE):
  1. The `inbox-update` skill body opens with the framing "the inbox is a derived view of the codebase; the codebase is ground truth" (Pitfall 7) and instructs Claude to add, update, or prune atomic flat entries — never append a chronological log.
  2. Entries use the stable handle convention (`@ CATEGORY::slug • path • #tags`) so Claude can locate-and-prune by `^@ CATEGORY::<slug>` grep rather than re-reading the full inbox; entries are evidence-grounded (every entry corresponds to an Edit/Write tool call from the turn or an explicit user request).
  3. **The 1+1-then-deleted fixture test passes end-to-end:** a multi-turn fixture run that creates a function and deletes it in a later turn produces an inbox with zero entries for that function, and a subsequent `/digest` produces zero filed notes for it. (This criterion spans Phases 1 + 2 — it is the locked validation criterion per CAPT-04 and `PROJECT.md`.)
  4. A turn that produced no codebase artifact writes nothing to the inbox; the update prompt is cheap enough to run every turn (compact handle format, grep-first prune protocol, no mandatory full-file rewrite).
  5. When the user asks Claude to delete code that has an inbox entry, Claude does not push back citing the inbox state — the skill's framing prevents the inbox from being treated as authoritative.

**Plans**: 2 plans (2 waves)

Plans:
- [x] 02-01-PLAN.md — inbox-update skill body (all D-01..D-10 decisions) + inbox reset to zero-entry state
- [x] 02-02-PLAN.md — Acceptance gate: 1+1-then-deleted fixture loop (CAPT-04 release blocker)

---

### Phase 3: Stop Hook Automation

**Goal**: A user running a normal Claude Code coding session sees the inbox auto-update on work-bearing turns without any manual invocation, with no infinite loops, no inbox writes on pure-conversation turns, and a heartbeat log proving the hook fired.

**Depends on**: Phase 2 (the schema and skill body must be debugged manually first; otherwise every prompt-bug looks like a hook-bug). Q1 resolution from Phase 1 determines the hook's injection mechanism.

**Requirements**: CAPT-01

**Success Criteria** (what must be TRUE):
  1. After a work-bearing assistant turn (one with Edit/Write/MultiEdit tool calls), the Stop hook nudges Claude to run `/inbox-update` using the Q1-resolved mechanism (`additionalContext` or `decision:"block"`+`reason`), and `wiki/inbox/_session.md` reflects the turn's changes.
  2. After a pure-conversation turn (no Edit/Write tool calls), the hook's transcript pre-filter exits 0 without nudging — no inbox churn, no token spend on no-op narration.
  3. The hook never enters an infinite loop: `stop_hook_active` is checked at the top of the script, a per-turn fire counter caps fires at 2, a `.claude/inbox/.disabled` kill switch short-circuits, and the hook is registered on `Stop` only (never `SubagentStop`) so digest sub-agent turns do not thrash the inbox.
  4. Every hook fire writes timestamp + session_id + outcome to `.claude/inbox/.hook-log`, providing auditable proof of firing and defending against silent failure (Pitfall 4).
  5. End-to-end real coding session: per-turn token overhead is bounded (cheap inbox-update prompt remains cheap under hook automation), and the Phase 1 curator still digests the auto-captured inbox cleanly.

**Plans**: TBD

---

### Phase 4: Install & Distribution

**Goal**: A user with an existing repo containing a `wiki/` directory and `wiki/Rules.md` can run a single install command, restart Claude Code, take their first work-bearing turn in that repo, and see the inbox update without any manual setup or file edits.

**Depends on**: Phase 3 (no point distributing something whose hook does not work locally).

**Requirements**: INST-01, INST-02, INST-03

**Success Criteria** (what must be TRUE):
  1. One install command drops `.claude/skills/`, `.claude/agents/`, and the Stop hook configuration into a target repo; an existing `.claude/settings.json` is *merged* (Stop hook entry added) rather than clobbered, and existing skills/agents with conflicting names are surfaced as warnings, not silently overwritten.
  2. The install runs a smoke test that triggers a Stop event and verifies the hook heartbeat appeared at `.claude/inbox/.hook-log`; if the heartbeat is absent the install fails loudly with a diagnostic message.
  3. The install README documents required environment (`CLAUDE_CODE_FORK_SUBAGENT=1` for digest sub-agent forking with non-fork fallback path), known interactions (`disableSkillShellExecution` breaks the digest skill's bash injection), the Q1 resolution and any first-run restart requirement, and the explicit anti-features (no real-time sync, no auto-digest, no backfill, no `Rules.md` modification, no wiki-codebase reconciliation in v1).
  4. After install in a fresh repo, the first work-bearing turn updates `wiki/inbox/_session.md` correctly without manual intervention, and a subsequent `/digest` files notes per `Rules.md` against the consumer's existing wiki structure.

**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation + Curator | 4/4 | Complete | 2026-04-28 |
| 2. In-Session Inbox Skill | 2/2 | Complete | 2026-04-28 |
| 3. Stop Hook Automation | 0/? | Not started | — |
| 4. Install & Distribution | 0/? | Not started | — |

## Coverage

**v1 Requirements:** 26 total
**Mapped:** 26 / 26 ✓
**Unmapped:** 0

| Category | Count | Phase(s) |
|----------|-------|----------|
| CAPT (Capture) | 7 | Phase 2 (CAPT-02..07), Phase 3 (CAPT-01) |
| DIGS (Digest) | 13 | Phase 1 (all 13) |
| LIFE (Lifecycle) | 3 | Phase 1 (LIFE-02, LIFE-03), Phase 2 (LIFE-01) |
| INST (Install) | 3 | Phase 4 (all 3) |

**Notes on requirement allocation:**
- **CAPT-04 (self-pruning, 1+1-deleted case)** is owned by Phase 2 because the inbox-update skill is what implements pruning, but its acceptance test cannot run until Phase 1's curator exists to digest the result. Phase 2 success criterion 3 makes the cross-phase fixture run explicit.
- **LIFE-01 (`wiki/inbox/_session.md` path)** is owned by Phase 2 (the skill writes there) but the directory placeholder is scaffolded in Phase 1 alongside the rest of the layout.
- **LIFE-02 + LIFE-03 (archive-before-write lifecycle)** are owned by Phase 1 because they are properties of the curator's digest workflow, not the inbox skill.
- **CAPT-01 (Stop hook trigger)** is the *only* Phase 3 requirement on purpose — Phase 3's whole risk is the hook mechanism itself. Bundling more requirements would obscure breakage attribution per the digest-first rationale in SUMMARY.md.

## Build Order Rationale

All four research streams independently converged on **digest-first, hook-last** (see `research/SUMMARY.md` §"Why this order"):

- **Curator before inbox skill** because the curator is the consumer of the inbox schema. Designing a schema before knowing what the consumer needs produces schemas that don't survive consumption.
- **Inbox skill before hook** because the inbox skill is the prompt that runs every turn. Wiring the hook before the prompt is debugged means every prompt-bug looks like a hook-bug.
- **Hook before install** because the hook is the part most likely to fail silently in a foreign environment. Install validates that a working hook still works elsewhere.

The natural intuition (build the trigger first) is wrong here: the hook is both the riskiest piece operationally (infinite loops, runaway cost, silent failure) AND the least diagnostic — its failures look like "no notable changes."

## Open Questions Carrying Into Phase 1

- **Q1 (CRITICAL):** Stop hook injection mechanism — `additionalContext` vs `decision:"block" + reason`. Stack and Architecture researchers disagree; both cite docs. **Must resolve in Phase 1 before any hook code is written**, by reading the *current* `code.claude.com/docs/en/hooks` reference and running a one-line smoke test. Document the choice in `PROJECT.md` Key Decisions.
- **Q2:** Per-session inbox files vs single rolling — defer to v2 hardening, but design Phase 2's path as a single variable so the switch is one-line.
- **Q4:** Optional `why:` field on inbox entries — include in Phase 2 schema, required for `@ DECISION::*` entries.

## Out of Scope for v1

These are deliberately deferred to v2 (see `REQUIREMENTS.md` v2 + `PROJECT.md` Out of Scope):

- Concurrent-session inbox safety (per-session files / lockfile)
- Chunked digest mode for 200+ entry inboxes
- `/reconcile` skill (wiki↔codebase audit) — explicitly documented as a gap in Phase 4 README per INST-03
- `/inbox-status` slash command
- Rationale capture as a first-class differentiator (D1)
- Per-feature digest scope (D3)
- `inbox/last-digest.md` audit artifact (D6)

---

*Roadmap created: 2026-04-28*
*Next: `/gsd-plan-phase 1`*
