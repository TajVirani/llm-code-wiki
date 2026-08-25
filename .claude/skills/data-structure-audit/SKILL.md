---
name: data-structure-audit
description: Audit the data structures in a codebase along three axes - representable-but-invalid states, unnecessary complexity, and runtime performance - then propose concrete redesigns with migration paths. Use this skill whenever the user asks to review, audit, critique, or improve types, structs, interfaces, models, schemas, enums, or state shapes; asks whether a data model "can be simplified" or "has problems"; mentions impossible states, boolean flags, optional-field soup, or fields that must stay in sync; or wants a review of memory layout, allocations, or cache behavior of their types. Also use it proactively during any refactor that touches core data models, even if the user doesn't say "audit." The audit is git-anchored and incremental - it records the commits it has audited in a committed state file and, on later runs, only examines code that has changed since, so it also triggers for requests like "audit what changed in this PR/branch" or "re-run the data structure audit."
---

# Data Structure Audit

Audit a codebase's data structures in three phases, in this order:

1. **Invalid states** — can the type represent states that are meaningless or forbidden by the domain? (Correctness. Always run.)
2. **Simplification** — is the shape harder to use, sync, or reason about than the domain requires? (Ergonomics. Always run.)
3. **Performance** — does the layout cost more in allocations, cache misses, or GC pressure than it should? (Only for hot-path types, and only with evidence.)

Correctness beats ergonomics beats performance. Never propose a performance change that reopens an invalid-state hole fixed in phase 1.

## Step 0: Determine the diff scope (git anchoring)

This audit is incremental. It never re-checks code that hasn't changed since the last recorded run. Start every run here:

```bash
bash <skill-path>/scripts/audit_scope.sh scope
```

Interpret the output:

- **`FULL_AUDIT ...`** — no usable state (first run, or state commits unreachable). Tell the user this will be a full audit and confirm before proceeding on a large repo.
- **`NOT_A_GIT_REPO`** — no anchoring possible; fall back to a full (or user-scoped) audit and skip Step N (recording).
- **A list of file paths** — the only files this run may audit. Everything else is already covered by a previous run.
- **Empty output** — nothing has changed since the last audited commit reachable from here. Report exactly that ("no diffed code since last audit at `<sha>`") and stop; do not audit anyway, and do not record a new run unless HEAD advanced.

How the anchoring works (so you can explain it or debug it): the state file `.claude/data-structure-audit-state.jsonl` holds a *set* of audited commits, and changed files are computed as `git log --name-only HEAD --not <every audited commit>` plus uncommitted/untracked files. Using a set rather than a single "last commit" pointer is what makes merges work: after two audited branches merge, both heads are ancestors of HEAD, so neither branch's code resurfaces, regardless of merge order. Rebased-away entries degrade gracefully to their merge-base (may over-check, never under-checks). Full mechanics and edge cases: `references/incremental.md` — read it if scope output looks wrong or a merge conflict on the state file needs resolving.

If the script can't run, replicate its core manually: extract commits from the state file, then `git log --name-only --pretty=format: -c HEAD --not <shas>` and `git diff --name-only HEAD`, filtered to files that still exist.

## Step 0b: Inventory within scope

Within the in-scope files, build the inventory:

- Find type definitions: `grep -n "^type \|^export type\|^export interface\|interface {" <scoped files>`, plus schema files (SQL, protobuf, Zod schemas, JSON Schema) in scope.
- **Changed definitions** get the full three-phase audit.
- **Changed usages of unchanged types**: if scoped code merely *uses* a type defined in an out-of-scope file, don't re-audit the type definition — but do check the new call sites for phase-2 smells (repeated derivation, sync obligations) and for bypassing existing parse boundaries. If a new usage reveals a definition-level flaw, report it, noting the definition itself was out of scope.
- Rank by centrality within scope; note serialization boundaries — boundary types get extra scrutiny ("parse, don't validate").

Present the inventory as a short table (type, file, rough usage count, boundary yes/no, changed-definition vs changed-usage) and confirm before deep-diving, unless the user already pointed at specific files.

## Phase 1: Invalid states

Read `references/invalid-states.md` before starting this phase.

For each in-scope type, do the **state-space math**: multiply out the cardinality of what the type can represent, compare against what the domain allows, and name the difference. A finding is only real if you can exhibit a concrete invalid value the compiler accepts. Example framing:

> `{status: string, approvedAt?: Date, rejectedAt?: Date}` — status has unbounded cardinality × 2 optional dates = states like `{status: "rejected", approvedAt: <set>}` are representable. Domain allows exactly 3 states.

Then propose the tightened shape (discriminated union, sealed interface, newtype, validated constructor) from the reference file's fix catalog.

## Phase 2: Simplification

Read `references/simplification.md` before starting this phase.

Look for shapes that make callers work too hard: repeated derivations at call sites, parallel collections that must be kept in sync by discipline, denormalized copies of the same fact, wide structs consumed narrowly, temporal coupling (must call `Init` before use). Evidence here is call-site based: cite the 3+ places doing the same dance.

## Phase 3: Performance

Read `references/performance.md` before starting this phase.

**Gate this phase.** Ask (or check the repo) for profiles, benchmarks, or at least a stated hot path. If none exist, still note *obvious* structural costs (slice-of-pointers where slice-of-values works, per-item allocation in a tight loop, map used as a fixed-field record) but label them "unverified — benchmark before acting" and offer to write the benchmark. Do not recommend layout changes that hurt readability for unprofiled code.

## Rules of engagement

- **Cite everything.** Every finding names `file:line`. No finding without a concrete code location.
- **Show the invalid value.** For phase 1 findings, write out an actual value that type-checks but is nonsense.
- **Estimate blast radius.** Count call sites the proposed change touches. Distinguish "rename + mechanical fix" from "semantic migration."
- **Propose incremental migrations.** Prefer: add new type → migrate boundary parsing → migrate call sites → delete old shape. Big-bang rewrites only when the user asks.
- **Report, don't rewrite.** Default output is the audit report. Only edit code when the user asks you to apply a finding.
- **Record rejections.** If you considered flagging something and decided it's fine (e.g., a boolean that genuinely has 2 valid states), say so briefly — it saves the next reviewer the same analysis.

## Report format

ALWAYS use this template:

```markdown
# Data Structure Audit: <scope>

## Summary
<3–5 sentences: overall health, the one or two changes with the best payoff/effort ratio>

## Inventory
| Type | File | ~Usages | Boundary | Flagged in |
|------|------|---------|----------|------------|

## Findings

### [CRITICAL|HIGH|MEDIUM|LOW] <Type> — <one-line title> (`path/file.go:123`)
**Problem:** <what's wrong>
**Evidence:** <invalid value that compiles, or call sites, or benchmark>
**Proposed shape:**
<code block: the redesigned type>
**Blast radius:** <N call sites; mechanical vs semantic>
**Migration:** <ordered steps>

## Quick wins
<findings fixable in under an hour>

## Considered and rejected
<things that look like smells but are fine here, one line each>
```

Severity: CRITICAL = invalid state reachable via a real code path today; HIGH = invalid state representable, currently guarded only by discipline/comments; MEDIUM = ergonomic tax with recurring call-site evidence; LOW = style/consistency or unverified performance note.

## Step N: Record the run

After delivering the report (in a git repo), record the run so future runs skip this code:

```bash
bash <skill-path>/scripts/audit_scope.sh record
```

Then:

1. **Ensure the union merge driver is configured** — one-time per repo, prevents merge conflicts when parallel branches both record runs. Check `.gitattributes` for the line below; if absent, add it:
   ```
   .claude/data-structure-audit-state.jsonl merge=union
   ```
2. **Get the state file committed.** It only anchors future runs if it travels with the branch. Stage `.claude/data-structure-audit-state.jsonl` (and `.gitattributes` if changed) with the user's changes, or remind them to.
3. If the script warned about a dirty working tree, tell the user: uncommitted changes were audited but can't be pinned to a commit, so they'll reappear in scope once committed — harmless double-check, not a bug.

Do NOT record if the audit was partial by user choice (e.g., they said "just look at this one file" while other in-scope changes exist) — recording would mark the skipped changes as audited. Record only when everything in scope was actually examined, and say so either way.

## Language coverage

The reference files carry Go and TypeScript sections (the primary targets), plus language-agnostic principles that transfer to Python, Rust, SQL schemas, and protobuf. For other languages, apply the agnostic principles and say which language-specific checks were skipped.
