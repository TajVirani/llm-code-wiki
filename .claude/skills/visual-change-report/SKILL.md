---
name: visual-change-report
description: Build a self-contained HTML report that visually explains how a system changed between two versions of a codebase — before/after architecture diagrams, changed workflow/sequence diagrams, dependency blast-radius graphs, and change-statistics charts, organized by concept rather than by file. Use this whenever the user wants to understand, explain, review, or present a large diff, big PR, merge request, release, or branch ("what changed here?", "explain this 300-file PR", "how did the system change?", "make a change report/summary for this branch", "before and after of the architecture"). Also use when someone needs to walk teammates, reviewers, or leadership through a big refactor, migration, or feature landing — even if they don't say "HTML" or "diagram" explicitly.
---

# Visual Change Report

Turn a large, hard-to-review diff into a single HTML document that explains how the *system* changed — not just which files changed. The report is for an engineer who needs to explain the change to other engineers: enough detail to be credible, organized so nobody drowns.

## Philosophy (read this before doing anything)

A diff is organized physically (by file). Understanding is organized logically (by concept). The whole job of this skill is that translation.

Three principles drive every decision:

1. **Zoom levels, like a map.** Borrow the C4 model's core insight: different questions need different altitudes. The report always moves top-down — system view first (how the boxes-and-arrows picture changed), then subsystem/theme views, then file-level detail only in a collapsed appendix. Never make the reader assemble the big picture from fragments.
2. **The diff understates the change.** Files that *didn't* change can still be affected — they call, import, or depend on things that did. Real reviewers get burned by blast radius, not by the lines they read. Trace and show what depends on the changed pieces.
3. **A detail budget, ruthlessly enforced.** Every extra node on a diagram taxes the reader. Prefer omitting a true-but-minor detail over crowding a visual. The appendix exists precisely so the main narrative doesn't have to be complete.

## Workflow

### Step 0 — Establish the change set

The report covers **the current branch's changes** — everything since it diverged from its base branch:

- head = `HEAD` (the branch currently checked out).
- base = the branch the user names ("against develop", "vs release/2.0"), otherwise the main branch (`origin/main`, `main`, `master`, in that order). Always compare from the **merge-base**, not the branch tip, so unrelated commits that landed on the base branch since divergence don't pollute the report. The bundled script does this automatically.
- The user can also name any explicit range (two tags, a PR, commit SHAs) — use it verbatim.
- If the repo state is ambiguous (detached head, no obvious main branch, dirty tree the user might care about), ask one short question rather than guessing.

### Step 1 — Collect the mechanical facts

Run the bundled collector — don't hand-roll git plumbing:

```bash
python3 scripts/collect_change_data.py --repo /path/to/repo --out change_data.json
# or with explicit refs:
python3 scripts/collect_change_data.py --repo . --base origin/main --head HEAD --out change_data.json
```

It produces JSON with: totals, per-file stats with rename tracking, a category for every file (source / tests / docs / config / generated / vendored / assets), rollups by directory, top files by churn (noise excluded), and the commit subjects in range. Read the JSON; it is the skeleton of the "By the numbers" section and your map for deciding where to read code.

### Step 2 — Build the "before" model from what the repo already says

The user's repo likely already documents the old world — READMEs, `docs/`, architecture pages, ADRs, existing Mermaid/PlantUML diagrams, workflow definitions. Use them; they're the ground truth for the "before" picture and they use the team's own vocabulary, which the report should adopt.

Critical detail: read documentation **at the base ref**, not the working tree — docs at head may already describe the new world:

```bash
git show <base>:docs/architecture.md
git ls-tree -r --name-only <base> | grep -iE '\.(md|mmd|mermaid|puml)$|docs/'
```

If an existing Mermaid diagram describes the system, the report's "before" diagram should visibly descend from it (same node names, same layout instincts), with the "after" diagram as its evolution. Reviewers trust a picture they half-recognize far more than a brand-new invention.

Then skim the actual changed code — prioritize by the collector's churn ranking and by anything that looks architectural (new modules, deleted modules, changed interfaces, changed configs/workflows). You don't need to read all 300 files; you need to read enough to name what happened.

### Step 3 — Cluster changes into themes

Group the change set into **3–7 themes** — logical units like "Payments moved behind a gateway abstraction" or "Notifications became event-driven," never physical units like "changes in src/utils." Each theme gets: a name in plain language, a one-paragraph *what and why*, its own visual, and the list of files it claims.

Apply the noise policy while clustering:

- **Out of the narrative, still in the stats:** lockfiles, generated code, vendored deps, snapshots, pure-formatting churn, mass renames that a rename-detector already paired up. Mention them in one line ("~40 of the 300 files are lockfile/generated churn") so the reader can stop worrying about them — explicitly disarming the scary file count is part of the job.
- **Compressed:** mechanical repetition (the same one-line change in 60 call sites) is one theme bullet with a count, not 60 rows.
- **Never dropped silently:** every file lands in some theme or in the explicitly-labeled noise bucket in the appendix. "Where did file X go?" must always have an answer.

### Step 4 — Trace blast radius for the themes that matter

For the 2–3 most consequential themes, find what *depends on* the changed pieces: grep for imports/calls of changed modules, check whether changed interfaces have consumers outside the diff, note changed configs/schemas/workflows that other systems read. This becomes the blast-radius visual — changed nodes in the center, affected-but-unchanged dependents around them. This section is routinely the most valuable one in the report, because it's the part the diff itself cannot show.

### Step 5 — Choose visuals

Read `references/visual-library.md` and pick per theme. Quick mapping:

| The change is about... | Reach for... |
|---|---|
| Structure (modules, services, boundaries) | Unified architecture-delta diagram; side-by-side before/after only if topology changed a lot |
| A workflow / request path / pipeline | Two sequence (or flow) diagrams: before and after |
| A lifecycle or state machine | State diagram with delta coloring |
| Data model / schema | ER-style diagram or a migration table |
| Scale and composition of the diff | Inline-SVG bar charts and composition bars (from the template) |
| Ripple effects | Blast-radius graph |
| API/config/env surface changes | A table — tables beat diagrams for enumerable facts |

Every visual must answer exactly one question, stated in its caption. If you can't phrase the question, cut the visual.

### Step 6 — Assemble the HTML

Start from `assets/report-template.html` (copy it, then fill the marked slots). It ships with the design system, the delta color language, Mermaid wiring, chart patterns, collapsibles, and print styles. Fill in this order:

1. Header facts (repo, `base → head`, date, headline counts)
2. Executive summary — ≤5 bullets, each one theme, each stating *what* and *why it matters*
3. System view — before/after at the whole-system level
4. One section per theme, biggest concept first
5. By the numbers — churn by area, change composition
6. Blast radius
7. Appendix — full categorized file table inside `<details>`, collapsed by default

Output a **single self-contained file**. Mermaid loads from a CDN (the one external dependency); the template already renders diagram source as readable code blocks if the CDN is unreachable.

**Where the report lands.** The report belongs with the branch's specification, inside the repo, so it can be committed and reviewed alongside it. Find the destination in this order:

1. **The diff tells you.** If the change set itself touches files under a specification directory (a path segment named `spec`, `specs`, `specification`, or `specifications` — e.g. `specs/event-driven-checkout/design.md`), that folder is the branch's spec folder. Write the report there.
2. **The branch name tells you.** Otherwise, list the repo's spec-like directories and look for a subfolder matching the branch's feature slug (branch `feat/event-driven-checkout` → `specs/event-driven-checkout/` or similar fuzzy match).
3. **Ask.** If neither yields a confident match, ask one short question listing the candidates found — don't guess a home for a document meant to be committed, and don't silently drop it in the repo root.

Name it `change-report.html` (stable, so regenerating as the branch evolves overwrites in place and the spec folder always holds the current picture — the header strip inside already records exactly which refs it covers). If the user overrides the destination or the report isn't landing in a spec folder, fall back to `change-report-<base-short>-<head-short>.html` to avoid ambiguity.

### Step 7 — Verify, then deliver

- Validate every diagram with the bundled checker — it parses each Mermaid block with the real Mermaid parser, catching the quoting/reserved-word errors that otherwise render as blank sections:
  ```bash
  npm install mermaid@11 jsdom   # once per environment
  node scripts/validate_mermaid.mjs change-report-<...>.html
  ```
  If installing packages isn't possible, fall back to the manual syntax checklist in the visual library.
- Count nodes: system diagram ≤ ~15 nodes, theme diagrams ≤ ~12, sequence diagrams ≤ ~8 participants. Over budget → merge nodes into a labeled group or push detail to the appendix.
- Confirm every changed file is findable in the appendix, and the appendix row counts reconcile with the header totals.
- Present the file to the user with its in-repo location and a 2–3 sentence summary of the biggest findings — lead with the insight, not the artifact. Mention that the report is sitting in the branch's spec folder uncommitted, so they can review it before committing.

## Detail budget (the anti-overwhelm contract)

- Executive summary: ≤5 bullets, no file paths.
- Main narrative: file paths appear only when a path *is* the point (a new module, a deleted subsystem). Everything else says "the payment layer," not `src/services/payments/gateway_v2/adapter.py`.
- Per theme: one visual, one paragraph of prose, up to 5 supporting bullets. If a theme needs more, it's two themes.
- Numbers get context or get cut: "+4,200 lines, of which 2,900 are generated client code" is information; "+4,200 lines" alone is noise.
- Depth lives behind `<details>` disclosures, never in the reader's default path.

## Visual language (keep it identical everywhere)

One legend, every visual, no exceptions: **green = added, amber = modified, red = removed, gray = unchanged/context.** The template defines these as CSS custom properties and matching Mermaid `classDef`s — use those tokens rather than inventing colors, and never repurpose the delta colors for anything that isn't a delta.

## Pitfalls seen in practice

- **Docs read at head instead of base** → the "before" diagram accidentally shows the "after" world. Always `git show <base>:...`.
- **Mermaid syntax errors** → a blank report section. Follow the quoting rules in the visual library; when in doubt, wrap labels in double quotes.
- **Equating churn with importance.** A 2-line config change can be the headline; 3,000 lines of generated code never is. Rank by consequence.
- **Ignoring deletions.** Removed capability is often the riskiest part of a change and deserves narrative space, not just red numbers.
- **Renames read as add+delete.** The collector pairs them (`old_path`); present them as moves.
- **One mega-diagram of everything.** Two senior engineers should never disagree about what a diagram means. If a picture needs a tour guide, split it by zoom level.
