
**Summary**: Anchor explaining why most of `research.md` was rejected and what was kept; the wiki is LLM-recall-primary, not human-Obsidian-primary.
**Tags**: #architecture #wiki #templates #design-decision
**Created**: 2026-05-01T22:45:00+00:00
**Last Updated**: 2026-05-01T22:45:00+00:00

---

## Content

### The mismatch

`research.md` was generated to design a defense-engineering wiki — humans authoring richly-frontmattered notes in Obsidian, with audit/compliance pressure, MOC navigation, Dataview "stale doc" queries, and Diátaxis-mode discipline. Its evidence base (Atlassian "8 hrs/week lost to docs", Stack Overflow "61% spend 30 min/day searching", Spotify Backstage adoption) is about humans reading docs.

llm-code-wiki is a different system. The recall agent reads `topic-index.md`, greps the wiki, returns ≤400 words. It does not have the search-time problem. Notes are auto-captured from artifact deltas, not authored deliberately. The 1,000-word cap and ≤25-word summary are tuned for grep-and-return, not human reading. Importing `research.md` wholesale would invalidate locked decisions in `wiki/Rules.md` (5-category contract, single-template schema, auto-maintained topic-index) and add process artifacts (owner, team, oncall, classification, review_by) that LLM grep does not use.

### What we kept (six templates plus five diagram triggers)

One pattern template plus five diagram templates were imported, all stripped of `research.md`'s frontmatter zoo and fitted to the existing 1,000-word cap:

- `pattern.md` — recurring code patterns with anti-pattern callout.
- `state-diagram.md` — FSM-shaped code with transitions table and code mapping.
- `sequence-flow.md` — time-ordered cross-component messages.
- `flowchart.md` — decision/branch logic.
- `component-diagram.md` — module/component wiring with subgraphs.
- `interaction-overview.md` — high-level flow whose nodes link to child sequence-flow notes.

Five diagram triggers (Rules.md §12) tell the curator when to pick a specialized template instead of falling back to `note.md`: FSM-shaped code, cross-file request path (3+ files), decision branches (≥4 mutually-exclusive), module/component boundary work, orchestration with 3+ named sub-flows. A sixth trigger picks `pattern.md` for recurring patterns.

### What we rejected and why

- **ADRs, RFCs, design concepts, design docs.** Deliberate human authoring path; capture is artifact-delta-driven. Decision capture already flows through brainstorm-fallback every N turns.
- **API docs, runbooks, CI/CD docs, infrastructure docs.** Source-of-truth lives in OpenAPI specs / YAML / Terraform; the LLM reads those directly; humans do not on-call this code.
- **User flows.** UX artifact for design teams.
- **MOCs with Dataview, 12-folder Johnny-Decimal, 15-field frontmatter.** Obsidian-team scaffolding; `topic-index.md` already serves the LLM-recall job.
- **Glossary / domain-vocabulary note.** Deferred. Trigger condition: when the dogfood wiki passes 50 filed notes and the recall agent reports vocabulary collisions, add a single `wiki/ARCHITECTURE/glossary.md`.

### Anchor purpose

This triage exists so the rejection does not get re-litigated. If a future session asks "should we add ADRs?" or "should we add a runbook template?", the answer is in the rejection list above plus the audience decision: LLM recall is primary. If that audience decision changes, the triage gets revisited as a whole.

The new templates live at `wiki/_templates/`. The diagram triggers live at `wiki/Rules.md` §12. The curator's template-selection step is Step 2c (see [[wiki-curator-agent|Wiki Curator Agent]]).

## Related Notes

- [[wiki-curator-agent|Wiki Curator Agent]]
- [[Rules|Wiki Rules]]
- [[topic-index-as-recall-map|Topic Index As Recall Map]]
