---
name: wiki-code-crawler
description: Crawl the codebase, build a function-level dependency graph, cluster code into concepts, and emit one free-prose research doc per concept into wiki/inbox/<slug>.md. The user runs /wiki-digest afterward to file them per wiki/Rules.md. Use to seed a fresh wiki from an existing codebase, regenerate concept coverage after large refactors, or backfill orphaned subsystems.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Task
---

# Codebase crawler — concepts → research docs in wiki/inbox/

The user invokes `/wiki-code-crawler` to seed `wiki/inbox/` with one free-prose research doc per concept derived from the live codebase. The next `/wiki-digest` decomposes those docs into filed wiki notes per `wiki/Rules.md`.

## Boundary (read this before doing anything)

This skill produces **research-doc drafts only**. It does NOT:

- Load `wiki/Rules.md` — Rules.md is the curator's contract; pre-routing output is intentionally raw.
- Write to `wiki/<CATEGORY>/`, `wiki/_templates/`, `wiki/MODULES/`, `wiki/inbox/_session.md`, or anything under `wiki/inbox/_archive/`.
- Template, slug-normalize, route, conflict-detect, or rewrite backlinks — those are the curator's job (run by `/wiki-digest`) and `/wiki-modules`'s job for the orientation layer.
- Run `/wiki-digest` itself. The user runs that next.

Output destinations: `wiki/inbox/<slug>.md` (drafts) and `_docgen/*` (scratch, kept for resumability).

## Inputs (pre-injected for context)

- Repo top-level layout:
  !`ls -1 2>/dev/null | head -n 40`

- Detected build/manifest files (signals which language toolchains we'll need):
  !`ls -1 package.json go.mod go.sum pyproject.toml setup.py Cargo.toml pom.xml build.gradle Gemfile composer.json requirements.txt 2>/dev/null`

- Existing research docs already in the inbox (will be respected — do not overwrite without reason):
  !`find wiki/inbox -maxdepth 1 -type f -name '*.md' ! -name '_*' 2>/dev/null | sort`

- Prior `_docgen/` artifacts, if any (Phase resumability — skip phases whose outputs already exist and look fresh):
  !`ls -la _docgen 2>/dev/null | sed -E 's/^[[:space:]]+//' || echo "_docgen/ does not exist yet"`

If any pre-injected block is empty (e.g. `disableSkillShellExecution`), recover by running the equivalent Glob/Bash calls yourself — the skill body's substance does not depend on these injections.

## Phase 1 — Discovery (you, the assistant)

1. Map the repo: detect languages and build systems from the manifest files above; list entry points (main/bin, exported APIs, HTTP routes, CLI commands, lambda/handler functions); note the directory taxonomy and obvious module boundaries.
2. Skip dependency dirs and build artifacts: `node_modules/`, `dist/`, `build/`, `.git/`, `vendor/`, `__pycache__/`, `target/`, `.next/`, lock files, and anything else that's clearly generated.
3. Write `_docgen/inventory.json`:

   ```json
   {
     "files": ["..."],
     "languages": ["..."],
     "entry_points": ["..."],
     "public_surface": ["path/file.ext:symbol", "..."]
   }
   ```

   `public_surface` is exported symbols (functions, classes, types, routes) reachable from at least one entry point. Use Phase 5's coverage check to verify nothing was missed.

Tools: Glob/Grep for the scan. Read the few manifest files in full so you understand the toolchain.

## Phase 2 — Graph construction (you, the assistant)

Build a cross-file import + function-call graph. Pick the fastest reliable tool per language:

- **TS/JS** — `ast-grep` if available, else ripgrep on `import`/`export`/`function`/`class` patterns
- **Go** — `go list -deps -json ./...` plus ripgrep for call sites
- **Python** — ripgrep on `^import`, `^from `, `^def `, `^class `, plus a pass for decorator-registered handlers
- **Rust** — `cargo metadata` plus ripgrep on `mod`/`pub fn`/`use`
- **Other** — ripgrep with per-language patterns; record the heuristic in `_docgen/graph.notes.md` so future runs can sharpen it

Always cross-check with ripgrep so you don't miss dynamic call sites (string-built imports, reflection, route registration tables, dependency-injection containers).

Write `_docgen/graph.json`:

```json
{
  "nodes": [{ "id": "path/file.ext:symbol", "kind": "function|class|module|route", "exported": true }],
  "edges": [{ "from": "...", "to": "...", "kind": "import|call|extends|implements|route" }]
}
```

## Phase 3 — Concept clustering (you, the assistant)

Cluster files into concepts using the graph: high internal cohesion (members import/call each other heavily), low external coupling (few cross-cluster edges).

Sizing target: each concept's research doc lands in **200–700 words**. If a cluster naturally exceeds 700 words, pre-split into 2–3 cohesive sub-concepts (e.g. `auth-overview`, `auth-internals`). Smaller, focused docs improve `/wiki-digest`'s same-concept detection and downstream cluster signals for `/wiki-modules`.

Slug rules — these MUST be obeyed (the curator's research-doc discovery uses `find … -name '*.md' ! -name '_*'`):

- Lowercase kebab-case
- MUST NOT start with `_`
- Bare single-concept identifier; no folder prefixes
- Unique within this run

Write `_docgen/concepts.json`:

```json
[{
  "concept": "auth",
  "slug": "auth",
  "files": ["..."],
  "entry_points": ["..."],
  "depends_on_concepts": ["..."],
  "depended_on_by_concepts": ["..."]
}]
```

## Phase 4 — Research-doc authoring (DELEGATE in parallel via Task)

For each concept C, spawn one Task sub-agent. Run in parallel batches of 5–10 concurrent calls (one message containing N Task tool uses).

Use `subagent_type: general-purpose` — the work is read-files-and-write-prose with no specialized contract beyond the prompt below.

**Sub-agent prompt template** — substitute the per-concept fields verbatim:

> You are writing a research doc for the '{C.concept}' concept of this codebase. Your output is ONE free-prose markdown file at `wiki/inbox/{C.slug}.md` that the wiki-curator will later route per `wiki/Rules.md`. You are NOT the curator. Do not load `wiki/Rules.md`. Do not template, categorize, or backlink-rewrite — those are the curator's job.
>
> **SCOPE — read only these files:**
> {C.files}
>
> **ENTRY POINTS:**
> {C.entry_points}
>
> **GRAPH SUBSET (edges originating in or terminating in this concept):**
> {filtered subset of `_docgen/graph.json` — edges where either endpoint is a member of this concept}
>
> **RELATED CONCEPTS (for cross-references):**
> {C.depends_on_concepts and C.depended_on_by_concepts with their slugs}
>
> **OUTPUT format** — free prose, no rigid template (the curator templates during filing):
>
> ```markdown
> # {Title Case Concept Name}
>
> {Opening paragraph: what this concept is, where it lives in the repo (cite paths plainly), what it owns.}
>
> {Body paragraphs: how it works. Trace call paths from the entry points. Describe trigger/input mechanism, what is stored/persisted, what executes/runs, what is produced/emitted. Use this terminology naturally — downstream tooling reads keyword density across those four categories.}
>
> {Cross-references: when you mention a related concept, link it as `[[other-slug|Other Concept Name]]` — the canonical piped form. Do NOT use bare `[[Title]]` form. Use the slug from the RELATED CONCEPTS list above.}
>
> {Closing paragraph: notable design choices, gotchas, or extension points — only if grounded in source.}
>
> Topics: #tag1 #tag2 #tag3
> ```
>
> **CONSTRAINTS:**
> - Length: 200–700 words. If you cannot fit the concept in 700 words, STOP and report back — the parent will re-cluster rather than letting you produce a 1500-word doc.
> - Do not read files outside SCOPE. Single exception: opening one upstream file to confirm a type signature you must reference.
> - Do not invent. If a behavior is not verifiable from source or the graph subset, omit it.
> - File path MUST be `wiki/inbox/{C.slug}.md`. Do NOT write to `wiki/<CATEGORY>/`, `wiki/_templates/`, `wiki/MODULES/`, `wiki/Rules.md`, `wiki/inbox/_session.md`, or any path under `wiki/inbox/_archive/`. Do not start the filename with underscore.
> - The Topics line should have 3–7 hashtag-style topics (e.g. `#auth #oauth #cookies`). These feed the curator's tag-overlap conflict detection and topic-index updates.
>
> Return only the path you wrote.

Collect each subagent's returned path. If a subagent reports back "cannot fit in 700 words" instead of a path, re-cluster that concept into 2–3 sub-concepts in `_docgen/concepts.json` and dispatch fresh subagents for them. Do not let any subagent emit a 1500-word doc.

## Phase 5 — Pre-digest validation (you, the assistant)

1. **Coverage** — every concept in `_docgen/concepts.json` must have a corresponding `wiki/inbox/<slug>.md`. List any missing.
2. **Public-surface coverage** — every symbol in `_docgen/inventory.json.public_surface` should be mentioned in at least one research doc. List orphans, then either reassign each to an existing concept (spawn a follow-up subagent to amend that doc) or create a new concept doc.
3. **Slug discipline** — confirm no research-doc filename begins with `_`.
4. **Path safety** — confirm no writes occurred outside `wiki/inbox/` and `_docgen/`. Run `git status -s wiki/ _docgen/` and verify the diff is bounded to those paths.
5. **Summary table** — print `concept | slug | word count | file count | entry points covered`.
6. Print: "Run `/wiki-digest` to archive these research docs and file them into `wiki/<CATEGORY>/` per Rules.md."

## Operating rules (apply throughout)

- Output destinations: `wiki/inbox/<slug>.md` (research docs only) and `_docgen/*` (scratch artifacts, kept for resumability).
- Never load or reference `wiki/Rules.md` — pre-routing output is intentionally raw.
- Never document a file you haven't read.
- Never invent signatures or call relationships. Everything in a research doc must be traceable to source or the graph subset.
- If two concepts would describe the same symbol, the concept where it is defined wins; siblings link via `[[slug|Title]]`.
- Report progress after each phase: phase name, what was produced, what's next.
- The user runs `/wiki-digest` after this skill completes. Do not invoke it yourself.
- If any pre-existing `wiki/inbox/<slug>.md` would be overwritten by Phase 4, surface the collision in Phase 3's plan and ask before letting subagents proceed — the user may have hand-edited it.

## Resumability

`_docgen/` is scratch but kept on disk so re-runs can pick up. If `_docgen/inventory.json`, `_docgen/graph.json`, and `_docgen/concepts.json` are all present and look fresh (sanity-check timestamps and that the file list still matches the live tree), you may skip Phases 1–3 and re-dispatch Phase 4 only for concepts whose `wiki/inbox/<slug>.md` is missing. Surface the resume decision in your first progress report so the user can override.

## Things this skill does NOT do

- Does NOT file notes — the curator (via `/wiki-digest`) does.
- Does NOT detect MODULES clusters — `/wiki-modules` does, after the curator has filed the detail notes.
- Does NOT write to `wiki/Rules.md`, `wiki/_templates/`, `wiki/MODULES/`, `wiki/<CATEGORY>/`, `wiki/inbox/_session.md`, or `wiki/inbox/_archive/`.
- Does NOT auto-commit anything.
- Does NOT delete `_docgen/` — keep scratch artifacts for the next run; the user can `rm -rf _docgen/` themselves when they're confident.
- Does NOT process files matching `_*` at `wiki/inbox/` — those are reserved (`_session.md`, `_archive/`).
