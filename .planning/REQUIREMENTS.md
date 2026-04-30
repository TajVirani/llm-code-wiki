# Requirements: llm-code-wiki

**Defined:** 2026-04-28
**Core Value:** Code documentation stays current and coherent without manual upkeep — including correctly pruning entries when code is deleted or superseded within the same session.

## v1 Requirements

### Capture (in-session inbox upkeep)

- [ ] **CAPT-01**: After each Claude assistant turn, an inbox-update prompt is delivered to Claude via a Stop hook
- [x] **CAPT-02**: An `inbox-update` skill defines how Claude maintains the rolling inbox — atomic flat entries, state-of-the-world semantics, no chronological logging
- [x] **CAPT-03**: Inbox entries use a stable, greppable handle convention so Claude can locate-and-prune by target rather than by prose match
- [x] **CAPT-04**: When code is removed or superseded within a session, the corresponding inbox entry is removed in the same turn — the "1+1-then-deleted" case must produce zero filed notes after digest
- [x] **CAPT-05**: A turn that produced no codebase artifact writes nothing to the inbox; the update prompt is cheap enough to run every turn without ballooning per-turn token cost
- [x] **CAPT-06**: Inbox entries are evidence-grounded — every entry corresponds to an Edit/Write tool call from that turn or an explicit user request (no hallucinated entries)
- [x] **CAPT-07**: The inbox-update skill explicitly frames the inbox as a derived view of the codebase (codebase is ground truth), so Claude does not push back on user code edits citing inbox state

### Digest (consolidation into wiki)

- [ ] **DIGS-01**: A user-invocable `digest` skill / slash command consolidates the current inbox into filed wiki notes
- [ ] **DIGS-02**: Digest spawns a fresh-context sub-agent (with a non-fork fallback path documented) so context isolation is enforced and parent token usage is minimized
- [ ] **DIGS-03**: Digest produces a routing plan first (preview), validates it against `wiki/Rules.md`, and writes only after the plan passes — no destructive writes without preview
- [ ] **DIGS-04**: Digest routes each entry into one of the canonical category folders (`ARCHITECTURE/`, `FUNCTIONS/`, `RESEARCH/`, `SELF/`, `DIAGRAMS/`) per `Rules.md` §2
- [ ] **DIGS-05**: Filed notes conform to the canonical template (`wiki/_templates/note.md`): Summary, Tags, Created, Last Updated, Content, Related Notes
- [ ] **DIGS-06**: Filenames use kebab-case per `Rules.md` §5
- [ ] **DIGS-07**: Summaries are ≤25 words per `Rules.md` §3
- [ ] **DIGS-08**: Notes exceeding 1,000 words are split with cross-links per `Rules.md` §4
- [ ] **DIGS-09**: When an inbox entry covers a concept already filed, digest edits the existing note rather than creating a duplicate
- [ ] **DIGS-10**: Cross-links use Obsidian wiki-link syntax `[[Note Title]]` (display title, not filename) per `Rules.md` §7
- [ ] **DIGS-11**: After write, digest runs a link-validation pass and surfaces any unresolved `[[...]]` references
- [ ] **DIGS-12**: Digest is idempotent — running it on a fresh post-archive inbox produces no changes
- [ ] **DIGS-13**: Digest never modifies `wiki/Rules.md` autonomously; rule-change suggestions surface in the plan for the user to apply manually

### Lifecycle

- [x] **LIFE-01**: One rolling inbox file per project, located at `wiki/inbox/_session.md` (leading-underscore convention parallels `_templates/` and respects `Rules.md` §9)
- [ ] **LIFE-02**: On digest, the inbox is archived (timestamped) before notes are written, then truncated for a fresh start
- [ ] **LIFE-03**: Archive-before-write ordering ensures a crashed mid-write does not lose entries

### Install

- [ ] **INST-01**: A one-command install drops `.claude/skills/`, `.claude/agents/`, and the Stop hook config into a target repo and merges (does not clobber) existing `settings.json`
- [ ] **INST-02**: Install includes a smoke test that triggers a Stop and verifies the hook fired (defends against silent failure)
- [ ] **INST-03**: Install README documents required env vars (e.g., `CLAUDE_CODE_FORK_SUBAGENT=1` if used), known interactions (`disableSkillShellExecution`), anti-features, and the wiki-codebase reconciliation gap

## v2 Requirements

### Differentiators deferred from v1

- **DIFF-01**: Rationale capture — `why:` field on inbox entries; required for `@ DECISION::*` entries; preserved by digest into the filed note's Content (Features D1)
- **DIFF-02**: Per-feature digest scope — digest only entries tagged for the current feature, leave others alone (Features D3)
- **DIFF-03**: Inbox size warnings — soft cap at 30–50 entries with "consider running `/digest`" nudge (Features D4)
- **DIFF-04**: `inbox/last-digest.md` audit artifact — what was filed, what was edited, what was skipped (Features D6)
- **DIFF-05**: Periodic SELF/ context snapshot for fresh-context Claude sessions (Features D7)

### Hardening

- **HARD-01**: Concurrent-session safety — per-session inbox files keyed on session ID, or `wiki/inbox/.lock` write-and-rename protocol (Pitfall 6)
- **HARD-02**: Chunked/clustered digest mode for inboxes with 200+ entries (Pitfall 13)
- **HARD-03**: `/reconcile` skill — walk filed notes, grep codebase for referenced symbols, surface ghost notes per `Rules.md` §8 (Pitfall 14)
- **HARD-04**: `/inbox-status` slash command — entry count, oldest age, sessions represented (Pitfall 17)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Real-time wiki sync as code changes | Hooks can't write files; would require a runtime; mid-stream updates can't see the 1+1-deleted pattern correctly |
| Multi-user / collaborative concerns | Single-developer tooling per PROJECT.md; users sharing wikis use git |
| Web UI / browser viewer | Plain markdown already works in Obsidian, VS Code preview, GitHub |
| Schedule-based auto-digest | Auto-digest mid-feature splits one logical change across multiple notes; scheduled runs happen when no human reviewer is present |
| Backfilling docs from existing code | Different task (batch summarization); orthogonal to capture-while-building |
| Migrating between wiki conventions | Value lies in respecting one fixed contract (Rules.md); users fork to target other conventions |
| Modifying `wiki/Rules.md` autonomously | Rules.md is the contract; digest may *propose* changes, never apply |
| Chronological session log inside the inbox | Breaks self-pruning by construction; the 1+1-deleted case produces two contradictory entries instead of zero |
| In-session note sectioning / pre-routing | Forces categorization decisions when context is partial; sub-agent routes holistically at digest time |
| Semantic-similarity duplicate detection (embeddings) | Requires a runtime; violates no-runtime constraint |
| Auto-commit of digest results | Mixes documentation with version control; conflicts with dry-run preview |
| Modifying source code based on inbox observations | Massive scope creep; this is a documentation tool, not a refactoring agent |

## Traceability

Populated by roadmap creation 2026-04-28. All 26 v1 requirements mapped to phases in `ROADMAP.md`.

| Requirement | Phase | Status |
|-------------|-------|--------|
| CAPT-01 | Phase 3 — Stop Hook Automation | Pending |
| CAPT-02 | Phase 2 — In-Session Inbox Skill | Pending |
| CAPT-03 | Phase 2 — In-Session Inbox Skill | Pending |
| CAPT-04 | Phase 2 — In-Session Inbox Skill (validation gate spans Phases 1+2) | Pending |
| CAPT-05 | Phase 2 — In-Session Inbox Skill | Pending |
| CAPT-06 | Phase 2 — In-Session Inbox Skill | Pending |
| CAPT-07 | Phase 2 — In-Session Inbox Skill | Pending |
| DIGS-01 | Phase 1 — Foundation + Curator | Pending |
| DIGS-02 | Phase 1 — Foundation + Curator | Pending |
| DIGS-03 | Phase 1 — Foundation + Curator | Pending |
| DIGS-04 | Phase 1 — Foundation + Curator | Pending |
| DIGS-05 | Phase 1 — Foundation + Curator | Pending |
| DIGS-06 | Phase 1 — Foundation + Curator | Pending |
| DIGS-07 | Phase 1 — Foundation + Curator | Pending |
| DIGS-08 | Phase 1 — Foundation + Curator | Pending |
| DIGS-09 | Phase 1 — Foundation + Curator | Pending |
| DIGS-10 | Phase 1 — Foundation + Curator | Pending |
| DIGS-11 | Phase 1 — Foundation + Curator | Pending |
| DIGS-12 | Phase 1 — Foundation + Curator | Pending |
| DIGS-13 | Phase 1 — Foundation + Curator | Pending |
| LIFE-01 | Phase 2 — In-Session Inbox Skill | Pending |
| LIFE-02 | Phase 1 — Foundation + Curator | Pending |
| LIFE-03 | Phase 1 — Foundation + Curator | Pending |
| INST-01 | Phase 4 — Install & Distribution | Pending |
| INST-02 | Phase 4 — Install & Distribution | Pending |
| INST-03 | Phase 4 — Install & Distribution | Pending |

**Coverage:**
- v1 requirements: 26 total
- Mapped to phases: 26 ✓
- Unmapped: 0
- Validated: 0 (none yet — Phase 1 not started)

**Phase distribution:**
- Phase 1 — Foundation + Curator: 15 requirements (DIGS-01..13, LIFE-02, LIFE-03)
- Phase 2 — In-Session Inbox Skill: 7 requirements (CAPT-02..07, LIFE-01)
- Phase 3 — Stop Hook Automation: 1 requirement (CAPT-01)
- Phase 4 — Install & Distribution: 3 requirements (INST-01..03)

**Notes:**
- **CAPT-04** is owned by Phase 2 (the inbox-update skill implements pruning) but its acceptance test — the locked "1+1-then-deleted" fixture run — exercises the whole capture+digest loop, so it cannot be marked validated until both Phase 1 (curator) and Phase 2 (skill) have landed. See ROADMAP.md Phase 2 success criterion 3.
- **Phase 3 intentionally owns only one requirement (CAPT-01).** The hook is the riskiest component operationally; isolating it lets breakage be attributed cleanly. Per `research/SUMMARY.md` §"Why this order".

---

*Requirements defined: 2026-04-28*
*Traceability populated: 2026-04-28 after roadmap creation*
