# Documentation Conformance

## Objective

Verify the diff and its originating documentation agree with each other — the spec/PRD is
complete and accurate to what was built, the code implements what the docs claim, and older
docs elsewhere don't contradict the new work. Report-only: never edit docs or code.

## Locating the documentation

1. **Originating spec (primary).** Branch names follow `NNN-feature-name` matching
   `specs/NNN-feature-name/`. Get the branch (`git rev-parse --abbrev-ref HEAD`) and read the
   matching folder: `spec.md`, `plan.md`, `tasks.md`, plus `data-model.md`, `checklists/`,
   `contracts/` when present.
   - **No matching spec folder** → report "no originating spec/PRD found for branch `<name>`"
     as a Tier 1 finding and stop. Do not guess at another doc.
2. **Cited ADRs (secondary).** Scan branch commit messages (`git log origin/main..HEAD`) and
   the diff itself for ADR references (e.g. `ADR-0020`). Read each cited ADR (ADRs live in
   `apps/agentic-tests/docs/decisions/`). Checked for contradiction only, not completeness.
3. **Wider sweep (tertiary).** Extract the key concepts the diff touches (module names,
   feature nouns, table/field names, tool names). Grep `docs/architecture/` and `wiki/` for
   those concepts and read the hits. Checked for contradiction only.

## Checks

### 1. Doc claims without code (Tier 1)

For each requirement in `spec.md` and each task in `tasks.md` marked complete (`[x]`):
verify the diff (or existing code it builds on) actually contains that behavior. A task
checked off with no corresponding change is a hard finding.

### 2. Code without doc record (Tier 1)

For each substantive behavior in the diff (new endpoint, schema change, new tool, changed
contract): verify the spec/plan/tasks record it. Behavior that contradicts a stated
requirement is a hard finding; behavior the spec is silent on is a finding when it's
load-bearing (schema, API surface, contracts), a note otherwise.

### 3. Task-list state (Tier 1 + inventory)

- Checked-but-absent and implemented-but-unchecked tasks are individual Tier 1 findings.
- Open, unstarted tasks are **not** individual findings — multi-part specs deliver across
  branches. Report them as one inventory line: "N tasks remain open: T12, T15, …".

### 4. Cited-ADR contradiction (Tier 1)

For each cited ADR: does the diff do what the ADR decided? Code that quietly diverges from
an ADR it cites is a hard finding (either the code or the ADR needs amending — say which).

### 5. Doc drift (Tier 2)

Wider-sweep hits in `docs/architecture/` and `wiki/` that state something the diff has now
made false. These are soft findings — "likely stale doc, consider updating" — in their own
report section, never mixed in with Tier 1.

## What to report

Tier 1:
```
- **[DOC-MISMATCH]** `specs/NNN-…/tasks.md:LINE` ↔ `path/to/code.ts:LINE`
  Claim: [what the doc says]
  Reality: [what the diff actually does / doesn't do]
  Suggestion: [update doc / implement task / amend ADR]
```

Tier 2 (separate section):
```
- **[DOC-DRIFT]** `docs/architecture/…:LINE` — "[quoted stale statement]"
  Now: [what the diff changed]
```

Plus the open-task inventory line if any tasks remain open.

## What NOT to flag

- Open, unstarted tasks (inventory line only).
- Spec sections about parts of the system the diff doesn't touch.
- Wiki inbox files (`wiki/inbox/`) — those are raw capture, not curated docs.
- Wording/formatting differences with no behavioral meaning.
