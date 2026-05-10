---
name: design-pattern-doc
description: Discover and document a multi-file design pattern in the codebase. Produces a ground-truth doc plus a drift report against existing project documentation. Use when the user asks to document a cross-cutting pattern, subsystem wiring, or how a multi-file feature actually works (e.g. "document how X works", "explain the design of Y", "make me an authoritative doc for Z"). Do NOT use for single-function explanations or one-off chat answers.
---

<what-to-do>

Phase 1 — load conventions. Read `.claude/skills/design-pattern-doc/conventions.md` (this directory). If absent, run the first-run setup at the bottom of this file before continuing.

Phase 2 — anchor read. Read every file in `conventions.md` § Anchor files, plus any file the user has open in the IDE or pointed at in their request. Do not launch agents yet.

Phase 3 — premise check. Sanity-check the user's topic against the anchor reads. If the topic names a subsystem / file / module that does not exist (e.g. user says "python-servers" and the dir doesn't exist), STOP. Post a redirect prompt: *"Topic premise doesn't match: X is not in the codebase. Did you mean Y or Z? Pass --force-anyway to proceed."* Wait.

Phase 4 — decompose. Break the topic into 1–5 orthogonal exploration slices. Each slice gets a non-overlapping prompt. Examples for "tool registration": (a) legacy workflow tool wiring, (b) agentic workflow tool wiring, (c) tool file structure across all locations. Cap at 5. Report the decomposition to the user *before* dispatching.

Phase 5 — parallel exploration. Launch the slices in a single message as parallel `Explore` agents. Each agent gets:
- Full background context (the anchor reads, what other agents are covering, what each agent is *not* responsible for)
- A clear "report findings" instruction (file paths, line numbers, snippets ≤10 lines, distinguish implemented / stubbed / missing)
- An explicit instruction to flag drift between docs and code
- A word cap (≤1500)

Phase 6 — scope clarification (optional). After agent findings come back, if there are 1–3 genuinely ambiguous deliverable decisions (where docs go, what to flag as drift, how to handle gaps), ask them in a *single* `AskUserQuestion` batch. Skip this step entirely if the defaults from `conventions.md` resolve the question. NEVER ask more than 3 clarification questions per invocation.

Phase 7 — drift scan. Greedy scan: read every `.md` under `docs/`, `specs/`, plus `CLAUDE.md` and `README.md`. For each file, check whether it makes claims that contradict the agent findings. Build a structured drift list: `{ file, line, current_text, reality, suggested_fix }`. **This is non-negotiable** — drift detection is the differentiator vs. "just write a doc".

Phase 8 — plan-preview. In normal (non-auto) mode, write a heavy plan: full ground-truth tables from agent findings, deliverables (new doc filename + path), files-to-touch (drift candidates with suggested fixes), verification approach, out-of-scope. Wait for approval. In auto mode, skip the wait — proceed with the plan as-is. In plan mode (harness-imposed), write to the plan file and `ExitPlanMode`.

Phase 9 — write the new doc. Use the spine in [TEMPLATE.md](./TEMPLATE.md). If the doc already exists, update it section-by-section: refresh sections the skill recognizes, leave user-added sections alone. Cite specific file paths with `:line` numbers from the agent findings. Match the style of the project's primary architecture doc (see `conventions.md` § Style notes).

Phase 10 — fix drift. Auto mode: apply every drift fix from Phase 7 directly. Non-auto: ask once "apply N drift fixes?" — yes / pick subset / skip. Each drift fix is a targeted `Edit` to a specific file.

Phase 11 — verification. Two mandatory checks:
1. **Grep verification.** Every file path and `:line` number cited in the new doc must resolve against the live tree. Fix the doc if anything drifted.
2. **Fresh-reader subagent.** Spawn a new subagent (no shared context). Hand it ONLY the new doc. Ask 3–5 questions a confused engineer would ask about this topic ("Where do I add a new X?", "How does Y reach Z?", "What's stubbed vs implemented?"). If the agent can't answer cleanly, fold the gap back into the doc. Repeat until clean.

Optional: build/lint check. If `conventions.md` § Verification commands lists a build or lint command and the user requested it (or auto mode is on), run it to verify mermaid renders / markdown lints.

Phase 12 — completion report. Post a structured summary in chat: deliverables, drift summary (`N found, M auto-fixed, K deferred`), verification result, any out-of-scope items, any decisions handed back to the user.

</what-to-do>

<supporting-info>

## First-run setup (only runs if `conventions.md` is missing)

Don't ask the user to fill out a form. Auto-detect, write a draft, tell the user it's there and they can edit.

1. Look for `docs/architecture/`, `docs/design/`, `docs/architecture-decisions/`, `docs/adr/`, `docs/decisions/`, `docs/diagrams/`. Map each to the right doc-type bucket (design patterns, decisions, diagrams). If none exist, default to `docs/`.
2. Look for `CLAUDE.md`, `README.md`, `docs/architecture/README.md`, `docs/README.md`. The first one or two of those become "anchor files".
3. Sample 3–5 existing `.md` files in the design-patterns location. Extract: kebab-case? Suffix conventions (`-pattern`, `-design`, `-architecture`)? Mermaid usage? Heavy tables? Short paragraphs? Emoji?
4. Look for build/lint commands: `package.json` scripts (`build`, `lint`, `docs:build`), `Taskfile.yml` targets, `Makefile` targets.
5. Write `conventions.md` using the format in [CONVENTIONS-FORMAT.md](./CONVENTIONS-FORMAT.md). Tell the user: *"First run — wrote `conventions.md` to `<path>`. Edit it if I got anything wrong, then re-invoke."*

## Decomposition heuristic

A topic decomposes well into orthogonal slices when it has **distinct surfaces** the user wants captured separately. Look for:
- **Workflow A vs Workflow B** (legacy vs new, sync vs async, internal vs external) → one slice each
- **Tool / artifact / entity inventory** (file pattern across directories) → one slice for "where do these live"
- **Lifecycle phases** (registration, runtime, cleanup) → one slice per phase
- **Producer vs consumer** (API surface, who calls it, what they call it for) → one slice per role

Bad decompositions: slicing by *file* instead of by *concern* (produces overlap), slicing by *line range* (too granular), single agent for cross-cutting topic (loses parallelism).

If you can't articulate what one slice is *not* responsible for in one sentence, the decomposition is wrong — re-slice.

## Drift detection mechanics

For each candidate `.md` file in the greedy scan:
1. Quick grep: does the file mention any entity name, file path, or topic keyword from the agent findings? If no → skip.
2. If yes, read the relevant region. Compare each claim to the agent findings.
3. Classify: **factual error** (claim contradicts code), **stale reference** (file/dir no longer exists), **outdated status** (says "future" but it shipped, or says "in production" but it's a stub), **omission** (silent on something now important).
4. Each finding becomes a `{ file, line, current_text, reality, suggested_fix }` row. Status / category goes in the new doc's Drift section as a table.

## Premise mismatch handling

A premise mismatch is when exploration findings *fundamentally* contradict the user's framing. Examples:
- User: "document the python-servers pattern" — there are no python servers.
- User: "explain how X talks to Y" — there is no Y, or X and Y don't communicate.
- User: "document how we use Z library" — Z is not a dependency.

It is NOT a premise mismatch when:
- Reality is more nuanced than the user expected (still write the doc; that nuance is the value)
- The user's premise is partly right (write the doc, lead with the partial-correction in TL;DR)
- A piece is stubbed but the system is real (write the doc; mark stubs in NOT IMPLEMENTED)

When in doubt, default to writing the doc and surfacing nuance in the TL;DR. Only bail when the topic has *no* mapping to the codebase.

## Tone for the new doc

Match the project's primary architecture doc (named in `conventions.md` § Anchor files). Otherwise default to:
- ≤4-sentence paragraphs
- Inventory tables for entity catalogs
- Mermaid for flows, only when there's a flow worth showing
- Code citations: include file path + line number for every load-bearing claim
- No emoji unless neighbor docs use them
- No marketing prose ("seamless", "robust", "powerful", "comprehensive")
- No filler ("Of course", "Certainly", "Note that")
- "NOT IMPLEMENTED" / "STUB" / "DEFERRED" — load-bearing labels, use them

## What never goes into the new doc

- Explanations of well-known framework behavior (link to upstream docs instead)
- Code examples reconstructed from memory (cite live code or omit)
- Speculative architecture not present in the codebase (the "intended end-state" section is the only place for forward-looking sketches, and it must be marked as such)
- Generic best-practices boilerplate
- Author or model attribution

## Modes

| Mode | Plan-preview | Drift fixes | Verification |
|---|---|---|---|
| Plan mode (harness) | Write plan file, `ExitPlanMode` | After approval | After write |
| Auto mode | Skip preview, post structured plan in chat | Apply automatically | After write |
| Default | Show plan, wait for approval | Ask once before applying | After write |

The fresh-reader subagent runs in *every* mode. The grep verification runs in *every* mode.

## When this skill is wrong

- Single-file walkthroughs ("explain this function") — answer in chat, don't invoke
- Code review — use a code-review skill instead
- API reference docs — use a doc-generator skill instead
- Bug investigations — use the diagnose skill instead
- Decisions where no code exists yet — write an ADR instead (this skill documents reality, not future plans)

</supporting-info>
