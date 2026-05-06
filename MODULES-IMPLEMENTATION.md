# MODULES — Implementation handoff

Hand this to the upstream `llm-code-wiki` maintainer (or any operator with Claude
Code + write access to `.claude/` and `wiki/` in a project that already has the
v1.1.0 scaffold installed). It describes a feature addition that introduces a
sixth wiki category — `MODULES/` — for orienting feature-cluster summaries that
sit *above* the existing fine-grained ARCHITECTURE/FUNCTIONS layer.

The design was settled in a `/grill-with-docs` session against the
`beta-alexandria` project (a documentation-only workspace). All references to
that project below are illustrative — the rollout is repo-agnostic and belongs
in the upstream skill bundle.

## Why this exists

Once a wiki accumulates ~50 ARCHITECTURE/FUNCTIONS notes, an orienting query
("what does Scheduling do?") lands on a leaf note (`scheduler-jobs-pg-boss.md`)
instead of a clustered summary. The wiki has no "earn-your-keep" synthesis layer
above the leaves. MODULES fills that gap: ~6–10 cluster summaries per project,
each describing a capability area's purpose, boundary, triggers, storage,
behavior, and rules — with wiki-links down to the existing leaves.

The design borrows philosophy (deletion test, deep-vs-shallow modules) from
[`mattpocock/skills/skills/engineering/improve-codebase-architecture`](https://github.com/mattpocock/skills/blob/main/skills/engineering/improve-codebase-architecture/SKILL.md)
but does **not** adopt his interface-spec template. MODULES notes are
narrative-led cluster summaries, not interface contracts.

## Audience

Upstream maintainer of `llm-code-wiki` (or equivalent). Assumed familiar with:
- `wiki/Rules.md` as the authoritative contract.
- The `wiki-curator` subagent and its protocol.
- The `wiki-digest` skill, including `disable-model-invocation: true`,
  `context: fork`, bash-injection signal pre-evaluation, and the
  `disableSkillShellExecution` fallback.
- The 5 existing canonical categories (ARCHITECTURE, FUNCTIONS, RESEARCH, SELF,
  DIAGRAMS) and the §12 trigger-template selector pattern (state-diagram,
  sequence-flow, flowchart, component-diagram, interaction-overview, pattern).

## Hard constraints (do not violate)

- Anti-feature **A10** still binds: no embeddings, no semantic similarity. All
  detection signals stay deterministic (filename, lex tokens, tag overlap, link
  count, word count). Bash-evaluable.
- **DIGS-13 / D-16**: curator never modifies `wiki/Rules.md`. All MODULES rule
  additions ship as user-applied amendments (or the upstream `/wiki-update`
  manifest applies them via `overwrite` policy).
- **D-19** RESEARCH/ write-protection unchanged — MODULES does not affect it.
- **LIFE-03 / D-14** archive-before-write unchanged.
- The curator's allowed-tools list (Read, Write, Edit, Glob, Grep) does not
  change. Anything requiring Bash continues to live in the digest skill body.

## Top-level contract

A `MODULES/` category is added with the following distinguishing rules:

1. **Naming**: MODULES slugs are bare cluster names (`scheduling`,
   `controller-reconciliation`, `uploads-pipeline`). Detail-note children in
   ARCHITECTURE/FUNCTIONS/RESEARCH/DIAGRAMS continue to carry kebab prefixes
   (`scheduler-jobs-pg-boss`). A MODULES slug must not equal any existing
   basename in another category.

2. **Same-concept detection** (Rules.md §6 / curator Step 3): MODULES uses a
   **1-of-2** rule (filename + title). Tag overlap is dropped as a signal
   because parent/child relationships structurally share tags. The 2-of-3 rule
   stays for the other five categories.

3. **Routing** is handle-driven (`@ MODULES::<slug>`) plus a new §12 trigger 7
   (module-cluster shape) that can OVERRIDE other handles to MODULES per
   existing 2a discipline. Trigger 7 fires when **all four** of these signals
   match (deterministic, bash-evaluable):

   | Signal | Definition |
   |---|---|
   | **S1 — Synthesis** | Body references ≥3 existing wiki note basenames OR `[[wiki-link]]` titles. |
   | **S2 — Dataflow** | Body contains lexical matches in ≥3 of 4 keyword categories: trigger (`trigger`/`entry`/`input`/`request`/`user picks`/`submits`/`cron`/`scheduled`/`queue`/`event`), storage (`saved to`/`stored in`/`persists`/`database`/`db`/`table`/`queue`/`state`), executor (`runs`/`executes`/`processes`/`reconciles`/`handler`/`worker`/`on a timer`/`loops`), outcome (`produces`/`emits`/`writes`/`notifies`/`returns`/`responds`/`completes`). |
   | **S3 — Cross-subsystem** | Body's `#tags` (or referenced notes' tags) span ≥2 distinct dominant codebase domains. Domains are derived from the existing topic-index — codebase-specific, not hard-coded. |
   | **S4 — Word band** | Body is 150–1000 words. Below = too thin; above = should SPLIT before MODULES routing. |

4. **Deletion-test gate** runs on any entry routed to MODULES (handle, trigger
   7, or OVERRIDE). Body must satisfy **5 of 7** template H2s, with `Purpose`
   and `Boundary` mandatory and ≥3 of {`Triggers`, `Storage`, `Behavior`,
   `Rules & Invariants`, `Children`}. Failures emit `SHALLOW-MODULE` rows
   (surface only, do not write). Threshold lives in the curator prompt and is
   tunable without a Rules.md amendment.

5. **New plan row types** in curator Step 5:
   - `SLUG-COLLISION` — MODULES slug equals an existing basename in another
     category. Surface only; do not auto-route. User decides.
   - `SHALLOW-MODULE` — deletion-test gate failed. Surface only; do not write.

6. **Topic-index** gains a layer split: `### Modules` H3 above the existing flat
   list (renamed `### Notes`). MODULES bullets use `Module: PATH` (singular)
   instead of `Files: PATH1, PATH2`. Combined cap stays ≤100; proposal-based
   `RULES-PROPOSAL` split unchanged when the cap is hit. Children of MODULES
   stay listed in `### Notes` flatly — they are NOT removed.

7. **Recall agent** distinguishes orienting queries (`what is`, `how does`,
   `overview of`, `explain`) from narrow ones; orienting hits prefer
   `### Modules`, narrow fall through to `### Notes`.

## File-by-file change list

Sequencing matters. Apply in the order shown.

### 1. `wiki/Rules.md` amendments

These are user-applied (curator never edits Rules.md). The upstream
`/wiki-update` manifest can ship them via `overwrite` if the project hasn't
diverged.

**§2 — Category folders.** Add a row:

```
| `MODULES/` | Feature-cluster summaries (~6–10 per project). Orienting overviews of capability areas spanning multiple subsystems. Each links down to ARCHITECTURE/FUNCTIONS/RESEARCH/DIAGRAMS detail notes. Gated by the deletion test — if children alone orient a newcomer, the MODULES note is shallow and should not exist. |
```

**§5 — Filenames.** Append a paragraph:

> MODULES slugs are bare single-concept kebab identifiers (`scheduling`, not
> `scheduler-overview`). Detail-note children in other categories carry kebab
> prefixes derived from the module slug or otherwise topical (e.g.
> `scheduler-jobs-pg-boss`). A MODULES slug must not exactly equal any existing
> basename under `wiki/{ARCHITECTURE,FUNCTIONS,RESEARCH,DIAGRAMS,SELF}/**/*.md`.

**New §13 — MODULES same-concept detection.**

> When evaluating same-concept signals for an entry routed to MODULES,
> filename match counts; title match counts; **tag overlap does not count**.
> Tags are inherently shared between a module and its children, so tag overlap
> is structurally expected, not a duplicate signal. 1 signal → EDIT existing
> MODULES note (bump Last Updated). 0 signals → CREATE.
>
> The standard 2-of-3 rule (filename + title + tag overlap) continues to apply
> to ARCHITECTURE, FUNCTIONS, RESEARCH, SELF, DIAGRAMS.

**§11 — Topic-index format.** Amend to permit a single H3 split (`### Modules`,
`### Notes`) inside `## Content`. Bullet rules within each section unchanged
(no nesting, no sub-bullets, alphabetized). MODULES bullets use the form:

```
- **<slug>** — <≤25-word summary>. Module: MODULES/<slug>.md
```

Combined cap stays ≤100. Proposal-based split when cap is hit (curator emits
`RULES-PROPOSAL: split ### Notes by category`); unchanged from current
behavior.

**§12 — Template trigger table.** Add row 7:

| # | Trigger signal in the entry/concept | Template chosen | Suggested route |
|---|---|---|---|
| 7 | Module-cluster shape: all of S1+S2+S3+S4 match (see §13a or curator definition) | `_templates/module.md` | `MODULES/` |

If trigger 7 fires on a non-MODULES handle, emit an OVERRIDE row per existing
2a discipline.

### 2. `wiki/_templates/module.md` (new)

```markdown

**Summary**: <one sentence, ≤25 words: what this module is responsible for>
**Tags**: #module #<domain-tags>
**Created**: <ISO-8601>
**Last Updated**: <ISO-8601>

---

## Content

### Purpose

One paragraph. What this module earns its keep doing — the deletion-test answer.
"If we deleted this module, what complexity reappears across the rest of the system?"

### Boundary

What's IN this module. What's explicitly OUT (and where that lives instead).
Naming what's NOT here is the explicit anti-shallow guard — descriptions that
can't fill this section usually fail the deletion test.

### Triggers

Entry points that invoke this module: HTTP endpoints, user actions, cron
schedules, queue messages, lifecycle hooks. One bullet per trigger.

### Storage

Tables, queues, files, in-memory state owned by this module. State "stateless"
explicitly if applicable.

### Behavior

The dataflow narrative — how a trigger flows through storage to executor to
outcome. This is the section that captures end-to-end behavior at module
granularity.

### Rules & Invariants

Constraints the module enforces or relies on: idempotency, conflict detection,
auth requirements, ordering guarantees, fail-safe defaults.

### Children

Wiki-links into the fine-grained detail notes that document each piece. Group
by category with H4 sub-headings; omit empty groups.

#### From ARCHITECTURE
- [[<basename>|<Display Title>]]

#### From FUNCTIONS
- [[<basename>|<Display Title>]]

#### From RESEARCH
- [[<basename>|<Display Title>]]

#### From DIAGRAMS
- [[<basename>|<Display Title>]]

## Related Notes

- Sibling MODULES notes that this one interacts with (cross-cutting refs).
```

### 3. `wiki/MODULES/` (new directory)

Empty. Populated by digests. Consider shipping a `.gitkeep` or a one-line
`README.md` that links to Rules.md §2 if the project's git ignores empty
directories.

### 4. `.claude/agents/wiki-curator.md` updates

Substantive changes; the curator gains MODULES awareness end-to-end.

- **Step 1 (Read inputs)** — Glob now includes `wiki/MODULES/**/*.md` in the
  duplicate-detection index. No code change needed if the existing glob is
  `wiki/**/*.md` excluding inbox/ and _templates/.

- **Step 2a (Session-inbox routing)** — Add `MODULES` to the canonical
  category list. OVERRIDE language unchanged.

- **Step 2b (Research-doc decomposition)** — Add MODULES to the category-pick
  options for free-prose docs. The curator picks MODULES when the doc body
  passes trigger 7's S1+S2+S3+S4 (same signals; route to MODULES with
  `_templates/module.md`).

- **Step 2c (§12 trigger table)** — Add trigger 7 row. If fired on a
  non-MODULES handle, emit OVERRIDE per 2a.

- **Step 3 (Same-concept detection)** — Branch on category:
  - For routes ∈ {ARCHITECTURE, FUNCTIONS, RESEARCH, SELF, DIAGRAMS}: existing
    2-of-3 rule.
  - For route = MODULES: 1-of-2 rule (filename + title only).
  - **Cross-category collision check (new)**: when route = MODULES, also grep
    `wiki/{ARCHITECTURE,FUNCTIONS,RESEARCH,SELF,DIAGRAMS}/**/<slug>.md`. Any
    match → emit `SLUG-COLLISION` row (surface only, do not auto-route).

- **Step 4 (Splits)** — When a MODULES note exceeds 1000 words, splits stay in
  `MODULES/`. Backlink rewrite rules unchanged.

- **Step 5 (Plan rows)** — Add two new row types to the table:
  - `SLUG-COLLISION` — MODULES slug equals existing basename in another
    category. User decides (rename the slug or merge).
  - `SHALLOW-MODULE` — body fails the deletion-test gate. User authors a
    deeper version manually, or accepts the concept doesn't deserve a MODULES
    note.

- **New step between Step 5 and Step 6 — Deletion-test gate.** For each
  CREATE/EDIT row routed to MODULES, validate body satisfies ≥5 of 7 H2s
  (`Purpose`+`Boundary` mandatory + ≥3 of {`Triggers`, `Storage`, `Behavior`,
  `Rules & Invariants`, `Children`}). Failures convert the row to
  `SHALLOW-MODULE`. The threshold (5/7) lives here in the prompt — tunable
  without Rules.md amendment.

- **Step 6 (Validation)** — Add MODULES to the destination-folder allowlist.
  Validate H4 sub-heading shape in the Children section: `#### From
  <CATEGORY>` where `<CATEGORY>` ∈ the 5 detail categories. Empty groups must
  be omitted (not present with no bullets).

- **Step 9 (topic-index update)** — Branch by category:
  - For MODULES writes: bullet goes under `### Modules` with format
    `- **<slug>** — <summary>. Module: MODULES/<slug>.md`.
  - For other categories: bullet goes under `### Notes` with the existing
    `Files: PATH1, PATH2` format.
  - When `wiki/topic-index.md` predates this rollout (single flat list, no
    H3s), the curator's first MODULES write triggers an in-place restructure:
    insert `### Modules` (empty) and `### Notes` headings around the existing
    bullets. This restructure is one-time and emits a one-line note in the
    digest summary.

### 5. `.claude/skills/wiki-digest/SKILL.md` updates

Add bash-injected signal pre-evaluation in Step 3, so the curator receives
trigger 7 signals computed by shell rather than judged by LLM.

For each session-inbox entry and research-doc concept, inject the following as
labeled prefixes the curator can read:

```bash
# S1 — synthesis: count [[wiki-link]] references and basename mentions
!`<for each entry/concept body>; grep -oE '\[\[[^\]|]+' | sort -u | wc -l`

# S2 — dataflow: count keyword-category matches (≥3 of 4 fires the signal)
!`<for each body>; \
  trig=$(grep -ciE '\b(trigger|entry|input|request|user picks|submits|cron|scheduled|queue|event)\b'); \
  store=$(grep -ciE '\b(saved to|stored in|persists|database|db|table|queue|state)\b'); \
  exec=$(grep -ciE '\b(runs|executes|processes|reconciles|handler|worker|on a timer|loops)\b'); \
  out=$(grep -ciE '\b(produces|emits|writes|notifies|returns|responds|completes)\b'); \
  echo "S2: trig=$trig store=$store exec=$exec out=$out"`

# S3 — cross-subsystem: count distinct domain tags
!`<for each body>; grep -oE '#[a-z][a-z0-9-]*' | sort -u | wc -l`

# S4 — word band
!`<for each body>; wc -w`
```

Implementation details:
- Tag-domain dominance for S3 is computed once per digest from the existing
  `topic-index.md` (e.g., the top-10 tags by frequency across the index). The
  digest skill body computes this before forking the curator.
- The curator's prompt includes a labeled section per entry: `### Trigger 7
  signals: S1=N, S2=[trig=N, store=N, exec=N, out=N], S3=N, S4=N`. The curator
  reads these and applies the all-four rule deterministically. No LLM
  judgment on whether a body "looks like" a module summary.

The `disableSkillShellExecution: true` fallback (W7 extension) extends to
trigger 7: when bash injections produce empty strings, the curator computes
signals itself using its Read/Glob/Grep tools as a degraded path. Document
this in Step 3.

### 6. `.claude/skills/inbox-update/SKILL.md` updates

Smaller change. Two additions:

- **Recognized handle list** — add `MODULES` to the category set. The skill
  accepts `@ MODULES::<slug>` lines in `wiki/inbox/_session.md` without
  treating them as malformed.

- **Heuristic for auto-MODULES handles (optional)** — when a turn touches ≥4
  ARCHITECTURE/FUNCTIONS notes that share ≥2 tags AND the user's message
  reads as a synthesis ("how does X work overall?", "give me an overview of
  X"), the skill MAY write `@ MODULES::<slug>` instead of multiple
  per-artifact handles. This is a soft hint — the curator's trigger 7 still
  validates. If you'd prefer to keep inbox-update strictly artifact-driven
  and let the curator handle all MODULES routing, skip this paragraph.

### 7. `.claude/skills/wiki-modules/SKILL.md` (new)

Manual synth/audit skill. Single slash command `/wiki-modules`. Read-only —
never writes to `wiki/`.

Skill frontmatter (suggested):

```yaml
---
name: wiki-modules
description: Manual scan of the wiki to (1) propose MODULES notes for clusters that lack one, and (2) audit existing MODULES notes against the current wiki state. Read-only — outputs a plan, never writes. Use when refreshing the orientation layer or before a major refactor.
allowed-tools: Read, Glob, Grep, Bash
---
```

Skill body computes:

**Inputs**:
- Glob `wiki/MODULES/*.md` for existing modules.
- Glob `wiki/{ARCHITECTURE,FUNCTIONS,RESEARCH,DIAGRAMS}/**/*.md` for child
  candidates.
- Read `wiki/topic-index.md` for tag/topic context.

**Cluster detection** (deterministic, no embeddings):
- **Signal 1 — Filename prefix**: group notes by their first kebab segment
  (e.g., `scheduler-*`). ≥3 notes = cluster candidate.
- **Signal 2 — Tag overlap**: for each prefix-cluster, compute the shared-tag
  modes. Notes that don't share ≥2 tags with the cluster mode are flagged as
  prefix-misfits.
- **Signal 3 — Link graph density**: count `[[wiki-link]]` edges between
  cluster members. High intra-cluster edge density confirms a real cluster;
  low density flags a misleading prefix.

**Synthesize section output** — for each candidate cluster lacking a MODULES
note:

```
## Proposed Module: <cluster-name>
Candidate children (N notes, M intra-cluster links, dominant tags: #x #y):
  - ARCHITECTURE/<file1>.md
  - ARCHITECTURE/<file2>.md
  - FUNCTIONS/<file3>.md
  - ...
Suggested next step: draft a MODULES note covering this cluster's purpose,
boundary, triggers, storage, behavior, rules. Drop the draft into
wiki/inbox/<slug>.md and run /wiki-digest, or write a `@ MODULES::<slug>`
handle entry.
```

**Audit section output** — for each existing `wiki/MODULES/<slug>.md`:

```
## Audit: MODULES/<slug>.md
✓ <N> linked children verified to exist
⚠ <M> children deprecated (tagged #deprecated): <list>
⚠ <K> linked children no longer exist (broken wiki-links): <list>
⚠ <P> notes match the cluster signal but are NOT linked from this module: <list>
⚠ scope drift: cluster's dominant tags are now <#a #b> but module's tags are <#x #y>
```

The skill emits both sections in one run. No interactive prompts. Output is
purely informational — the user dispatches changes through `/wiki-digest` or
manual edits.

### 8. `.claude/agents/wiki-recall.md` updates

Add a one-paragraph rule near the top of the agent prompt:

> **Topic-index has two sections.** The `### Modules` section lists the ~6–10
> orientation-layer summaries (one bullet per `wiki/MODULES/<slug>.md`). The
> `### Notes` section lists the detail layer (ARCHITECTURE, FUNCTIONS,
> RESEARCH, SELF, DIAGRAMS).
>
> When the user's query is **orienting** (asking what something is, how a
> system works, or for an overview — patterns: "what is", "how does", "how
> do", "overview of", "explain"), search the `### Modules` section first and
> prefer those hits as the primary entry point. Drill into the module's
> Children section for specifics. When the query is **narrow** (asking about
> a specific function, endpoint, file, error, or value), search `### Notes`
> directly. Mixed-intent queries return both.

### 9. `wiki/topic-index.md` one-time restructure

Curator Step 9 handles this on the first MODULES write (see #4 above). If you
prefer to land it as part of the rollout instead, the manual restructure is:

- Insert `### Modules` (with empty bullet list) immediately after the existing
  `## Content` heading and the maintenance HTML comment.
- Insert `### Notes` heading immediately before the first existing bullet.
- Bump `**Last Updated**`.

No bullets move. The H3 split is purely additive.

### 10. `CLAUDE.md` `Auto-maintained wiki` section

Add a sentence and a quick-reference line:

> **Orientation layer.** `wiki/MODULES/` contains ~6–10 cluster summaries —
> orienting overviews of major capability areas, each linking down to the
> detail notes in ARCHITECTURE/FUNCTIONS/RESEARCH/DIAGRAMS. Run
> `/wiki-modules` for a read-only scan of cluster coverage (proposed modules
> + audit of existing ones).
>
> Quick reference:
> - Modules: `wiki/MODULES/`
> - Module audit & synth: run `/wiki-modules`

## Sequencing

1. Apply Rules.md amendments (#1) — the contract must be in place first.
2. Add `_templates/module.md` (#2) and create `wiki/MODULES/` (#3).
3. Restructure `topic-index.md` (#9) — independent of curator changes; can
   land here or be deferred to first-MODULES-write auto-restructure in #4.
4. Update curator (#4) and digest skill (#5) together — they share the
   trigger 7 signal contract.
5. Update inbox-update (#6) and recall agent (#8).
6. Add `/wiki-modules` skill (#7) — independent of all above; can land any
   time after #1.
7. Update CLAUDE.md (#10) last.

## Acceptance criteria

A MODULES rollout is complete when all of:

- [ ] `wiki/Rules.md` §2 lists MODULES; §11 permits `### Modules` / `###
      Notes` H3 split; §12 has trigger 7; §13 (or §5 amendment) defines the
      MODULES same-concept rule and slug naming.
- [ ] `wiki/_templates/module.md` exists with the 7-H2 inner skeleton.
- [ ] `wiki/MODULES/` exists.
- [ ] `wiki/topic-index.md` has `### Modules` and `### Notes` H3s.
- [ ] Running `/wiki-digest` on an inbox containing `@ MODULES::test-mod` (a
      well-formed test entry passing the deletion-test gate) creates
      `wiki/MODULES/test-mod.md` with the module template, adds a `### Modules`
      bullet to topic-index, and routes correctly.
- [ ] Running `/wiki-digest` on a malformed MODULES entry (e.g., body lacks
      Boundary) emits a `SHALLOW-MODULE` plan row and does not write the
      file.
- [ ] Running `/wiki-digest` on a `@ MODULES::scheduling` handle when
      `wiki/ARCHITECTURE/scheduling.md` already exists emits a
      `SLUG-COLLISION` plan row and does not auto-route.
- [ ] Running `/wiki-digest` on an `@ ARCHITECTURE::overview` entry whose
      body matches all four trigger 7 signals emits an OVERRIDE row routing
      to MODULES.
- [ ] Running `/wiki-modules` on a wiki with no MODULES yet outputs a
      Synthesize section listing prefix-clusters and a (empty) Audit section.
- [ ] `/wiki-recall "how does scheduling work"` (with at least one MODULES
      note in place) prefers the MODULES bullet over leaf hits.

## Open micro-decisions for the maintainer

These were flagged but not strictly settled in the design session — defaults
listed:

- **Initial seed MODULES note?** Default: no. The first project to install the
  rollout grows its MODULES inventory organically via inbox handles.

- **Trigger 7 OVERRIDE confirmation prompt?** Default: same as existing 2a
  OVERRIDE — the OVERRIDE row appears in the plan with all four signal values
  shown, and plan-level approval covers it. No separate confirmation.

- **inbox-update auto-MODULES heuristic (#6 second bullet)?** Default: include
  it as a soft hint. If the maintainer prefers the inbox-update skill stay
  strictly artifact-driven, drop the heuristic and rely on the curator's
  trigger 7 to catch mis-handled entries.

- **Deletion-test threshold (5/7)?** Default: 5/7. The curator prompt is the
  only place this lives; tune after the first ~5 MODULES notes ship.

## Reference: design conversation summary

The design was settled across 10 questions in a `/grill-with-docs` session:

1. **Q1 — Definitional**: feature-cluster summaries (not Pocock interface
   contracts).
2. **Q2 — Granularity**: ~6–10 top-level capabilities per project, deletion
   test as gate.
3. **Q3 — Template**: hybrid — outer schema per Rules.md §3, inner 7-H2
   skeleton picked via §12 trigger.
4. **Q4 — Routing**: handle-driven + new §12 trigger 7 (OVERRIDE-capable) +
   deletion-test gate at curator level.
5. **Q5 — Synth/audit skill**: one read-only `/wiki-modules` skill, both
   sections in one run, signals filename-prefix + tag-overlap + link-graph.
6. **Q6 — Naming + same-concept**: bare slugs for MODULES, prefix slugs for
   children, 1-of-2 rule for MODULES, SLUG-COLLISION row.
7. **Q7 — Topic-index**: `### Modules` H3 above `### Notes`, `Module: PATH`
   syntax, cap stays ≤100 combined, proposal-based split unchanged.
8. **Q8 — Trigger signals**: all-four (S1+S2+S3+S4) for trigger 7, 5-of-7
   deletion-test gate.
9. **Q9 — Recall agent**: orienting/narrow query split prefers `### Modules`
   for orienting hits.
10. **Q10 — Children format**: H4 sub-headings `#### From <CATEGORY>`, empty
    groups omitted.

The five canonical decision entries were captured to
`wiki/inbox/_session.md` via the brainstorm-fallback path.
