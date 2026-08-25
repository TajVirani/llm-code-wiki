# Doc template — `design-pattern-doc`

The skill produces docs that follow this spine. Required sections must be present in every doc. Optional sections are included only when content warrants — the skill picks based on agent findings and notes the choice in the plan.

## Required spine

### 1. Top callout / cross-link

A blockquote at the top pointing to related docs (sequence diagrams, ADRs, specs). Two sentences max.

### 2. TL;DR

5–8 bullets. Each bullet states one ground-truth fact about the topic. Not a marketing summary — actual information density. Always include:
- The single highest-value finding (e.g., "the bridge is the only MCP server in this repo today")
- The biggest gap (e.g., "server-side tools are not ingested into the warehouse")
- The principle / contract if one exists (e.g., "one MCP tool file per tool")

### 3. Body

Topic-shaped sections. The skill chooses from these:
- **Workflows** — when there are 2+ distinct paths through the same concept (legacy vs new, sync vs async)
- **Lifecycle phases** — when the topic has stages (init → register → runtime → cleanup)
- **Inventory** — when the topic catalogs entities across directories
- **Contract** — when there is a wire format, an envelope, an API surface
- **Pattern adherence** — when there's a stated principle, list where it's followed and where it isn't

Each body section either has a mermaid diagram (for flow) or an inventory table (for catalog), or both. Plain prose without one or the other usually means the section is too vague.

### 4. Known gaps — NOT IMPLEMENTED

Explicit. Not "future work", not "TODO" — `NOT IMPLEMENTED`. Each gap is its own subsection with:
- **Status: not implemented** (or: stub, deferred)
- Evidence: file paths searched, what was found / not found
- Intended end-state for that piece (1–3 sentences)
- Spec / ADR pointer if one exists for the unbuilt work

### 5. Drift from upstream docs

Table: `{ file, line, claim that's wrong, reality }`. One row per drift finding from the greedy scan. If the skill auto-fixed any of these, mark them. If any are deferred for human review, mark those too.

### 6. Intended end-state

Forward-looking sketch. Always marked as forward-looking — usually with a mermaid graph that uses dashed lines / gray styling for unbuilt pieces. Two paragraphs max. Not a commitment, not a spec — a shape.

### 7. Cross-references

Bulleted links to: related diagrams, the spec the topic was specified in, ADRs that touch the topic, the project's primary architecture overview.

## Optional sections

Included only when content warrants. Skill picks and notes in the plan-preview.

- **The principle** — name and scope a contract (when the topic has one). 2–4 sentences. Goes between TL;DR and body.
- **Bootstrap / mount points** — when the user needs to know "where does this get wired up". File paths + line numbers.
- **Envelope contracts** — when wire formats matter. Reference shared types files, don't re-document the schemas inline.
- **Flow diagrams** — mermaid sequence or graph. Only when there's actual flow worth showing.
- **Code snippets** — 3–10 lines, cited from live code. Only when the snippet is the clearest possible explanation. Never reconstruct from memory.
- **Pattern adherence** — when there's a stated principle and adherence is mixed.

## Style rules (not negotiable)

- ≤4 sentences per paragraph
- Code citations: `path/to/file.ext:line` format
- Mermaid only when there's flow; tables only when there are entities
- No marketing words: "seamless", "powerful", "robust", "comprehensive", "elegant"
- No filler: "Of course", "Certainly", "Note that", "It's important to"
- No emoji unless neighbor docs use them
- "NOT IMPLEMENTED", "STUB", "DEFERRED" — capital-case labels, use them when accurate
- Match the primary architecture doc's tone (named in conventions.md)

## Section update mode (re-runs)

When updating an existing doc:
- Sections #1–#7 (the required spine) are skill-owned. Refresh them with new findings.
- Optional sections are skill-owned only if they match the template names above. Refresh them.
- Any section the skill doesn't recognize (user-added subsections, custom appendices) is preserved verbatim.

The diff in the plan-preview shows: refreshed sections, preserved sections, sections being removed if any.
