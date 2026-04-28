# Phase 1: Foundation + Curator - Context

**Gathered:** 2026-04-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the `/digest` skill that spawns a fresh-context sub-agent (the "curator") which reads `wiki/inbox/_session.md` plus the existing wiki tree plus `wiki/Rules.md`, produces a routing plan, validates the plan against Rules.md, and only then writes correctly-templated category notes. Validates against a hand-authored fixture inbox.

Owns 15 v1 requirements: DIGS-01..13, LIFE-02, LIFE-03. Plus a single non-coding deliverable that gates everything else: resolve Q1 (Stop hook injection mechanism: `additionalContext` vs `decision:"block" + reason`) against current Claude Code docs and a smoke test, then document the choice in PROJECT.md Key Decisions.

Out of scope this phase: the in-session inbox-update skill (Phase 2), the Stop hook itself (Phase 3), the install flow (Phase 4).

</domain>

<decisions>
## Implementation Decisions

### Routing trust (curator's category-routing algorithm)
- **D-01:** **Hybrid override.** The entry's `CATEGORY::` handle is the default route. The curator reads the entry content and may override the route if content strongly disagrees with the handle. Overrides are surfaced as explicit lines in the dry-run plan (e.g., "Entry handle says FUNCTIONS but content reads as ARCHITECTURE — routing to ARCHITECTURE"). Disagreement is visible to the user; agreement is silent.
- **D-02:** No "skip on disagreement" path — curator always picks a route. The override mechanism is for routing decisions, not for refusing to file.

### Conflict policy (existing-note matches per DIGS-09)
- **D-03:** **Plan-level approval, no per-note re-confirmation.** The dry-run plan lists every change — both new-note creates AND existing-note edits — with target note title, type of change (create / edit / split / rename), and a one-line summary. Approving the plan as a whole authorizes every change in it. No additional y/n per existing-note edit.
- **D-04:** Same-concept detection uses filename + title + tag overlap (no semantic similarity / embeddings — that's anti-feature A10).

### Backlinks on rename/split (DIGS-08, DIGS-10, DIGS-11)
- **D-05:** **Auto-rewrite.** When the curator renames or splits a filed note, it greps the entire wiki for `[[OldTitle]]` occurrences and rewrites them in place. The plan reports rewrites as a single line ("rewrite 12 backlinks to [[OldTitle]] → [[NewTitle]]"), not 12 separate lines.
- **D-06:** **For splits, the curator picks the split target per backlink based on surrounding context** (the sentence containing the link, plus the section heading it sits under). This is a curator-prompt judgment call — make the prompt aware that splits can produce per-backlink target decisions.
- **D-07:** Aliased links `[[OldTitle|alias]]` are rewritten as `[[NewTitle|alias]]` (preserve the alias).
- **D-08:** Post-write link-validation pass (DIGS-11) covers both pre-existing dangling links AND any links the curator failed to rewrite. Surface unresolved `[[...]]` references in the digest summary.

### Fixture rigor (Phase 1 acceptance test corpus)
- **D-09:** **Full coverage** — the hand-authored fixture inbox at the start of Phase 1 covers:
  1. **Happy path:** 5–7 entries, one per canonical category (`ARCHITECTURE/`, `FUNCTIONS/`, `RESEARCH/`, `SELF/`, `DIAGRAMS/`), each mapping cleanly to one filed note.
  2. **1+1-then-deleted (CAPT-04 release blocker):** the fixture is the *post-pruning* state — the deleted entry is simply absent. Validation criterion: digest produces zero notes for the deleted target. This validates CAPT-04 in Phase 1 instead of waiting for Phase 2's inbox-update skill.
  3. **Ambiguous categorization:** 1–2 entries where the `CATEGORY::` handle and content disagree, exercising D-01 (Hybrid override) — verify the override is surfaced in the plan.
  4. **Existing-note conflict:** 1–2 entries that should match notes already in the Traxalytics sample wiki (e.g., `wiki/FUNCTIONS/vorp-batch-processing.md`). Verifies D-03 (plan lists the edit) and D-04 (filename+title+tag detection).
  5. **Split-implication case:** 1 entry that pushes a target note past 1,000 words, forcing DIGS-08 split logic + D-05/D-06 backlink rewrite.
- **D-10:** Fixture lives at `tests/fixtures/_session-fixture.md` (or equivalent — planner's call). Not in `wiki/inbox/_session.md` proper, since that path is reserved for live session state.

### Carry-forward decisions (locked elsewhere, restated for the planner)
- **D-11:** Inbox path: `wiki/inbox/_session.md`. Leading-underscore convention parallels `_templates/` and respects Rules.md §9.
- **D-12:** Entry handle convention: `@ CATEGORY::slug • path • #tags`, anchored at start of line for `^@ ` grep. Promoted from candidate to recommendation by research.
- **D-13:** Sub-agent uses `context: fork` (Claude Code skill convention). Document a non-fork fallback path for consumers without `CLAUDE_CODE_FORK_SUBAGENT=1` set.
- **D-14:** Archive-before-write ordering: on digest, the inbox is copied to `wiki/inbox/_archive/<timestamp>-session.md` BEFORE any note-write happens. A crashed mid-write does not lose entries (LIFE-02, LIFE-03).
- **D-15:** Idempotence (DIGS-12): a digest run on a fresh post-archive (empty) inbox produces no changes. Validate this as a Phase 1 success criterion alongside fixture acceptance.
- **D-16:** Curator never modifies `wiki/Rules.md` (DIGS-13). Rule-change suggestions surface as proposals in the plan for the user to apply manually.

### Q1 resolution sub-deliverable
- **D-17:** Phase 1 includes a non-coding sub-task: read the current Claude Code Hooks reference at `code.claude.com/docs/en/hooks` (NOT cached training-data versions) and run a one-line smoke test emitting `{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"test"}}` from a Stop hook. Observe whether Claude sees "test" on the next turn. Document the chosen mechanism in PROJECT.md Key Decisions before any Phase 3 hook code is written.
- **D-18:** Q1 resolution is a Phase 1 success criterion gate — Phase 3 cannot start until it lands.

### Claude's Discretion (planner's call)
- Curator prompt structure (sections, ordering, examples) — informed by D-01 through D-09 but not specified
- Internal data structure for the routing plan (in-memory representation; user sees the rendered plan)
- Exact fixture filenames (within `tests/fixtures/` convention)
- Whether the dry-run plan is a markdown table, a checklist, or prose — pick what reads cleanly for ~10–20 changes
- How the curator detects file-existence for the fixture's existing-note conflict case (Read or Glob — both work)

</decisions>

<specifics>
## Specific Ideas

- The fixture should reference the Traxalytics sample wiki notes that already exist (e.g., `wiki/FUNCTIONS/vorp-batch-processing.md`, `wiki/ARCHITECTURE/postgresql-setup.md`) for the existing-note conflict case. The Traxalytics fixture is a real Obsidian wiki — that's the test corpus.
- The dry-run plan should be scan-able quickly. A user with 8–15 changes shouldn't have to read paragraphs to approve.
- Override surfacing (D-01) shouldn't be alarmist — it's a normal mode of operation, not an error. Phrase like "FUNCTIONS:: → ARCHITECTURE: content reads as system-level boundary, not a function reference."
- Auto-rewrite (D-05) is one-shot in the plan. The user shouldn't see 12 rewrite lines for a rename — they should see one line and trust it.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### The wiki contract (LOCKED)
- `wiki/Rules.md` — The wiki's authoritative contract. Curator must respect literally. §2 categories, §3 template, §4 1,000-word split, §5 kebab-case filenames, §7 wiki-link syntax, §8 deprecation policy, §9 inbox/templates special status, §10 surface-conflicts-before-acting.
- `wiki/_templates/note.md` — The canonical note schema. Every filed note must conform: Summary (≤25 words), Tags, Created, Last Updated, Content, Related Notes.

### Project context
- `.planning/PROJECT.md` — Locked decisions and constraints. The 5 Key Decisions in the table are non-negotiable for this phase.
- `.planning/REQUIREMENTS.md` — All 26 v1 requirements. Phase 1 owns DIGS-01..13, LIFE-02, LIFE-03 (15 reqs).

### Research outputs (read in this order)
- `.planning/research/SUMMARY.md` — START HERE. Synthesizes the four research streams. Contains:
  - Q1 (CRITICAL open question on Stop hook injection mechanism) — must be resolved by D-17 before any hook code
  - Verified Facts section — load-bearing Claude Code mechanics that are settled
  - Recommended Build Order — the digest-first rationale
  - Pitfall-to-phase mapping — which Phase 1 work mitigates which pitfall
- `.planning/research/STACK.md` — Claude Code primitives: skill format, hook schema, sub-agent invocation, `context: fork`, `skills:` preload field
- `.planning/research/ARCHITECTURE.md` — Component boundaries, data flow, inbox schema rationale, Pattern 5 (Curator Proposes-Then-Applies)
- `.planning/research/PITFALLS.md` — 17 failure modes. For Phase 1: pitfalls 8 (rationale), 9 (duplicates), 10 (cross-link rot), 11 (no-preview), 12 (Rules.md violations) are the immediate concerns
- `.planning/research/FEATURES.md` — Table-stakes vs differentiators rationale; T4–T12 are Phase 1 territory

### Test corpus
- `wiki/FUNCTIONS/vorp-batch-processing.md` — Real existing note; fixture's "existing-note conflict" case should target this or a similar real note
- `wiki/FUNCTIONS/`, `wiki/ARCHITECTURE/`, `wiki/RESEARCH/`, `wiki/SELF/`, `wiki/DIAGRAMS/` — sample notes to read for routing-judgment training

### External docs (Q1 resolution)
- `code.claude.com/docs/en/hooks` — current (April 2026) Hooks reference. Read DIRECTLY (not via training memory) for Q1 resolution. Specifically: which `hookSpecificOutput.hookEventName` values accept `additionalContext`? Does Stop appear in the list?
- `code.claude.com/docs/en/skills` — skill format and `context: fork`
- `code.claude.com/docs/en/sub-agents` — sub-agent file format and `skills:` preload

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Sample wiki tree at `wiki/`** — full Obsidian-compatible Traxalytics fixture. Use as the test corpus for Phase 1's fixture-driven validation. Multiple categories populated. Has cross-links and template-conformant notes.
- **`wiki/_templates/note.md`** — canonical note schema for the curator to emit against (string substitution; no markdown parser library).
- **`wiki/Rules.md`** — the contract. Curator's preflight validation reads this directly each digest (NOT a mirrored copy — research's `wiki-rules` skill is a thin pointer that re-reads `wiki/Rules.md` at activation, per anti-pattern guidance).

### Established Patterns
- **No source code exists yet** — this is a greenfield phase. The "established patterns" come from Claude Code conventions (skills/SKILL.md, agents/<name>.md, settings.json hooks block) and from `wiki/Rules.md`.
- **Markdown-only product** — no parser library, no Node/Python install. String substitution against the template handles everything.
- **`disableSkillShellExecution` interaction** — if a consumer enables this setting, bash injection in skill bodies (e.g., `` !`cat wiki/inbox/_session.md` ``) silently produces nothing. Curator skill needs a Read/Glob fallback path.

### Integration Points
- **`/digest` slash command** — entry point. Skill body becomes the curator sub-agent's prompt when `context: fork` is set.
- **`wiki/inbox/_session.md`** — the read-source. May be empty (no-op digest), populated by hand (Phase 1 fixture), or populated by the inbox-update skill (Phase 2+).
- **`wiki/inbox/_archive/<timestamp>-session.md`** — write-target for the archive step (LIFE-02, D-14).
- **`wiki/<CATEGORY>/<kebab-slug>.md`** — write-targets for filed notes. Five canonical categories per Rules.md §2.

</code_context>

<deferred>
## Deferred Ideas

- **Per-feature digest scope** (digest only entries tagged for the current feature) — this is DIFF-02 (v2). Came up implicitly when discussing fixture rigor; not in Phase 1.
- **`why:` rationale field on inbox entries** — DIFF-01 (v2). Curator will be designed to *preserve* a `why:` field if present, but the in-session skill won't *require* it until v2.
- **Concurrent-session safety / inbox locking** — HARD-01 (Phase 5). Phase 1 assumes single-session usage.
- **`inbox/last-digest.md` audit artifact** — DIFF-04 (v2). Phase 1's dry-run plan can be archived alongside the inbox archive (D-14) but isn't a separate audit file.

</deferred>

---

*Phase: 01-foundation-curator*
*Context gathered: 2026-04-28*
