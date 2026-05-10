# llm-code-wiki

The auto-maintained Obsidian-style wiki scaffold for Claude Code projects: capture-on-stop hooks, recall-on-prompt hooks, a curator subagent, and a small skill set that together keep a categorized wiki current and queryable without manual upkeep.

## Language

**Module** (capital-M, MODULES note):
A deep abstraction in the Ousterhout sense — narrow interface, rich implementation, hiding meaningful complexity behind a clear boundary. Operationally, a MODULES note is the orienting summary someone reads first to understand a major capability, with `wiki/{ARCHITECTURE,FUNCTIONS,RESEARCH,DIAGRAMS}/` notes as its implementation. The deletion test is the canonical check: removing the module should make complexity reappear elsewhere.
_Avoid_: package, subsystem, feature-cluster (in detection contexts — see Flagged ambiguities), folder.

**Detail note**:
A single-concept note in `ARCHITECTURE/`, `FUNCTIONS/`, `RESEARCH/`, `DIAGRAMS/`, or `SELF/`. The implementation layer beneath modules. Bound by the 1,000-word cap and one-concept rule.
_Avoid_: leaf note, child (used only inside a Module's `### Children` section).

**Cluster** (cluster signal, cluster candidate):
A mechanically-detected group of detail notes that *might* indicate a module. Distinct from a module — a cluster is evidence, not the thing itself. Filename-prefix groups, link-graph components, and tag-mode groups are all clusters.
_Avoid_: module (until promoted), prefix family (too narrow — clusters can span prefixes).

**Deletion test**:
Ousterhout's check for module depth, applied here both semantically (Purpose section: "if we deleted this module, what complexity reappears?") and structurally (Step 5a gate: ≥5 of 7 H2s, with Purpose+Boundary mandatory). The structural form is a proxy for the semantic form — agreement between them is the goal, divergence is a known failure mode.
_Avoid_: shallow check, gate (the gate is one form of the test, not the only one).

**Shallow module**:
A candidate whose body fails the deletion test — the description doesn't fill the inner H2s, or removing the module would leave external complexity unchanged. Currently surfaced as a `SHALLOW-MODULE` plan row by the curator. The structural-vs-semantic mismatch (a body can satisfy 5/7 H2s while still being shallow in the Ousterhout sense, or vice versa) is the open hazard.
_Avoid_: thin module, weak module.

## Relationships

- A **Module** has 1 MODULES note and 3+ **Detail notes** as children
- A **Cluster** is a *candidate* for becoming a **Module** — promotion requires passing the **Deletion test**
- The `/wiki-modules` skill detects **Clusters** (read-only, proposes only)
- The `/wiki-digest` curator promotes drafts to **Modules** through the Deletion test gate
- A **Detail note** can belong to 0 or 1 **Module** (currently — multi-module membership is unspecified)

## Flagged ambiguities

- **"Module" was being detected as "filename-prefix family with shared top-2 tag mode"** — resolved. A Module is an Ousterhout deep abstraction; clusters are mechanical evidence pointing at possible modules. Detection now uses: S1 prefix-bootstrap (≥3 members, unchanged), S2 single-dominant-tag (every member shares one common tag), S3 external-fan-in concentration (≥1 external note links to ≥2 distinct cluster members). Plus a pre-author depth gate and post-author content gate around an LLM-authoring step.

- **Two creation paths into wiki/MODULES/** — resolved. `/wiki-modules` is the sole writer. The curator's Trigger 7 (implicit MODULES upgrade in `/wiki-digest`) and explicit `@ MODULES::slug` handle paths are deprecated; any such handle surfaces as a `MODULES-VIA-DIGEST-DEPRECATED` plan row. This makes MODULES notes idempotent outputs of cluster state, never user-edited content.

- **Wiki-Rules.md §2 says "feature-cluster summaries"** — open. Phrasing predates the Ousterhout reframe and collapses Module and Cluster into one term. Amend §2, §12 (Trigger 7), and §13 (1-of-2 rule) in the same change that ships the new `/wiki-modules` and `module-author` subagent.
