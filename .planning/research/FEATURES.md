# Feature Research

**Domain:** AI-driven, auto-maintained codebase wiki (Claude Code skill + hook scaffolding; Obsidian-style markdown wiki)
**Researched:** 2026-04-28
**Confidence:** MEDIUM-HIGH (HIGH on Claude Code primitives & Obsidian conventions; MEDIUM on emergent patterns from comparable systems like AutoDream and claude-mem; LOW only on novel decisions specific to this project's flat-inbox / state-of-the-world model — those are design choices, not externally validated.)

## Orientation

This project sits at the intersection of three well-trodden domains:

1. **Auto-maintained AI memory / docs** — Claude Code AutoDream, claude-mem, DocuWriter Autopilot, Cursor Rules. These all converge on the same pattern: capture during work, consolidate later, prune stale, resolve contradictions.
2. **Obsidian / PKM conventions** — wiki-link integrity, kebab-case filenames, frontmatter schemas, inbox-then-file workflow (Smart Rename plugin, Foam, the broader Zettelkasten lineage).
3. **Infra-style change preview** — `kubectl --dry-run`, `terraform plan`, `git commit --dry-run`, `ansible --check --diff`. The expected mental model whenever an automated process is about to mutate persistent state.

Treat the existing tools as a feature catalog. The differentiated value of THIS project is **the inbox-as-state-of-the-world model** plus **the no-runtime, pure skill+hook delivery** — categorize features against those two axes, not against AutoDream's design.

## Feature Landscape

### Table Stakes (Required — Missing Any = System is Broken)

These are non-negotiable. The product fails its core promise ("docs stay current and coherent without manual upkeep") if any are absent.

| # | Feature | Why Expected | Complexity | Notes |
|---|---------|--------------|------------|-------|
| T1 | **Stop-hook trigger after each turn** | The capture loop. Without it, the inbox never updates and the rest of the system is dead. Documented as the chosen trigger in PROJECT.md (vs. PostToolUse). | LOW | Single `settings.json` entry. Hook injects a system reminder; Claude executes the inbox-update prompt. Hook itself does not write files. |
| T2 | **In-session inbox-upkeep skill** | Defines what gets written and how. Atomic flat entries, ≤25-word semantics, state-of-the-world framing, no chronology. Without strict rules, inbox drifts into a chat log and digest can't route it. | MEDIUM | Authoring challenge — must be cheap (runs every turn) yet specific enough to constrain Claude's natural verbosity. Avoid full-inbox re-reads where possible. |
| T3 | **Self-pruning of superseded entries WITHIN a session** | The "1+1 function created then deleted" case is explicitly called out in PROJECT.md as a validation criterion. If a function is added then removed in the same session, the inbox must end the session with no entry for it. State-of-the-world semantics make this natural; chronological logs make it impossible. | MEDIUM | Hinges on T2 framing. Test fixture should include this exact case. |
| T4 | **Manually triggered digest skill / slash command** | The other half of the loop. Without it, the inbox grows forever and nothing ever gets filed. Must spawn a sub-agent (per PROJECT.md decision: different audience, fresh context). | MEDIUM | `/wiki-digest` style. Sub-agent reads inbox + Rules.md + existing wiki, produces filed notes. |
| T5 | **Note routing into category folders** | Rules.md §2 defines five canonical folders (`ARCHITECTURE/`, `FUNCTIONS/`, `RESEARCH/`, `SELF/`, `DIAGRAMS/`). Every digested entry must land in exactly one. Misrouting = wiki incoherence. | MEDIUM | Routing is a classification task on each entry. The digest agent has the full inbox + Rules.md as input — sufficient context per PROJECT.md. |
| T6 | **Template conformance for filed notes** | Rules.md §3 mandates Summary / Tags / Created / Last Updated / Content / Related Notes. Notes that skip the template aren't valid wiki notes. | LOW | Sub-agent reads `_templates/note.md` and copies the structure. The hardest field is Summary (≤25 words). |
| T7 | **Kebab-case filename generation** | Rules.md §5 is explicit (`vorp-position-multipliers.md`, not `VORP_Position_Multipliers.md`). Mismatch breaks greppability and consistency. | LOW | Trivial transform. Worth a digest-agent reminder because Claude defaults to title-case. |
| T8 | **Conflict handling: existing-note detection and update vs. create** | If the inbox describes a concept that already has a filed note, the digest must edit (bumping `Last Updated`) rather than create a duplicate. Rules.md §8 forbids silent deletion and requires the `Last Updated` bump. Duplicates are how wikis rot. | MEDIUM-HIGH | Requires a "is there already a note for this?" lookup. Filename-grep + title-grep against the existing wiki gives a cheap first pass; semantic similarity is a much harder, optional improvement. |
| T9 | **1,000-word split rule** | Rules.md §4 mandates splitting any digested note that would exceed 1,000 words. Skipping it produces unreadable mega-notes. | MEDIUM | Word count is mechanical; choosing split boundaries is judgment. Guidance in the digest skill. |
| T10 | **Cross-link maintenance — `[[Note Title]]` not file paths** | Rules.md §7. Hardcoded paths break on rename; Obsidian resolves titles. Every "Related Notes" entry must be a wiki-link to a real existing title. Broken links destroy the navigation graph. | MEDIUM | Sub-agent must enumerate existing wiki titles before writing links. Validate links exist after writing (post-digest sanity check). |
| T11 | **Idempotence of digest** | Running the digest twice on the same archived inbox must not double-write notes, append duplicate sections, or corrupt the `Last Updated` field. Per PROJECT.md, digest archives the inbox on completion → second run finds an empty inbox → no-op. This is the primary idempotence mechanism. | LOW-MEDIUM | "Digest archives then truncates the inbox" is the simplest correct design. Without archive-on-complete, idempotence becomes hard. |
| T12 | **Rolling per-project inbox lifecycle** | Specified in PROJECT.md. One file per project, archived on digest, fresh start after. Without lifecycle, inbox grows unbounded. | LOW | File path convention + archive-on-digest. Archive directory naming suggestion: `wiki/inbox/_archive/YYYY-MM-DD-HHMM.md`. |
| T13 | **Installable into another repo** | Per PROJECT.md: "skills + hook can be dropped into another repo alongside an existing `wiki/` structure." The product IS the scaffolding; if installation is awkward, no one uses it. | MEDIUM | Install path: `.claude/skills/<skill>/SKILL.md` + `.claude/settings.json` hook entry + assumes `wiki/` exists at repo root. Document the contract clearly. |
| T14 | **No-modification of `wiki/Rules.md`** | Per PROJECT.md constraints: Rules.md is a fixed contract. The digest agent must respect it but never rewrite it. Rules.md §2 only allows the digest agent to *propose* a new top-level folder, not silently create one. | LOW | Skill instruction. "If a routing decision needs a new folder, surface it to the user; don't rewrite Rules." |
| T15 | **Cheap inbox updates (cost discipline)** | PROJECT.md explicitly constrains: "the update prompt must be cheap and avoid re-reading the entire inbox where possible." Hooks fire every turn — an expensive prompt makes the system unusable. | MEDIUM | Design the update prompt to either append-and-prune locally, or fetch only the relevant section. Avoid mandatory full-file rewrites every turn. |

### Differentiators (Worth Building Beyond MVP — Align with Core Value)

These are where the project beats raw AutoDream-style memory consolidation. Each one earns its complexity by addressing a real failure mode of the table-stakes loop.

| # | Feature | Value Proposition | Complexity | Notes |
|---|---------|-------------------|------------|-------|
| D1 | **Decision/rationale capture (the "why")** | ADRs (Architecture Decision Records) exist precisely because "what changed" without "why we chose it" is dead documentation. The inbox skill should explicitly prompt Claude to capture rationale when a decision is made — not just describe the artifact. PROJECT.md already models this (Key Decisions table). Routes naturally to `ARCHITECTURE/` or a new `DECISIONS/` folder. | MEDIUM | Cheapest implementation: inbox-skill instruction to flag decision-class entries with a marker (e.g. leading `DECISION:`). Digest agent then routes them as ADRs. Doesn't require a new folder if `ARCHITECTURE/` is acceptable. |
| D2 | **Diff-based digest preview (dry-run mode)** | The single highest-leverage differentiator. `terraform plan` / `kubectl --dry-run --diff` / `git commit --dry-run` are the universal mental model whenever automation is about to mutate persistent state — and a wiki IS persistent state the user cares about. A bad digest run is much worse than no digest run, because it pollutes the wiki with mis-routed or hallucinated notes. Preview before apply prevents that. | MEDIUM | `/wiki-digest --dry-run` (or two slash commands). Sub-agent produces a plan as markdown: "Would create `FUNCTIONS/foo-handler.md`, would edit `ARCHITECTURE/db.md` with this diff …". User says go → re-run without `--dry-run`. Implementation tip: have the dry-run produce the plan file and the apply step consume that plan file deterministically. |
| D3 | **Per-feature digest scope** | "Digest only what's about to ship in this PR / feature; leave unrelated inbox entries for a later session." Without scope, every digest is all-or-nothing, and a half-baked entry blocks filing the rest. Useful for solo devs juggling multiple in-flight features. | MEDIUM-HIGH | Two design options: (a) `--scope <tag>` filter where inbox entries get tagged at write time; (b) interactive selection — sub-agent lists inbox entries and asks which to digest. (a) is cleaner but requires T2 to capture scope tags. (b) is more flexible but interactive. |
| D4 | **Self-monitoring / inbox-bloat warning** | "Warn when inbox grows past N entries / N words without digest." Closes the human-in-the-loop gap: solo devs forget to digest, then the inbox grows so large the digest run becomes scary. A SessionStart hook that injects a system reminder ("Your inbox has 47 entries / 4,200 words — consider running `/wiki-digest`") is cheap and effective. | LOW | SessionStart hook + `wc -w` on the inbox file. No Claude cost when under threshold; a one-line reminder when over. Trivial. |
| D5 | **Digest-time link validation pass** | After the digest writes notes, walk every `[[Wiki Link]]` and verify the target title exists. Surface broken links to the user. Cheap insurance against the most common Obsidian failure mode. | LOW-MEDIUM | Post-write step in the digest agent. Pure mechanical check; no Claude reasoning needed beyond reporting. |
| D6 | **Stale-link repair on detected rename** | When the digest decides to retitle/move an existing note (e.g., split a 1,000-word note), update inbound `[[old title]]` references across the rest of the wiki. Smart Rename plugin does this for Obsidian users; the digest agent should mirror that behavior to avoid orphaning links. | MEDIUM | Search-and-replace across all wiki files when a note's title changes. The Rules.md §8 alternative — leave a one-line pointer at the old title with `#deprecated` — is also acceptable and arguably simpler. Pick one and document it. |
| D7 | **`SELF/` snapshot on digest** | The `SELF/` folder per Rules.md §2 is "AI/agent-facing context: short memory snapshots, session summaries." Each digest run can drop a session summary into `SELF/` automatically — turning the digest itself into a memory-handoff for future sessions. Compounds with Claude Code's existing memory features. | LOW | One-paragraph summary as a side effect of digest. Filename: `SELF/session-YYYY-MM-DD.md`. |
| D8 | **Digest-agent self-check pass** | Before emitting the final plan/files, the sub-agent re-reads its own draft against Rules.md and verifies: kebab-case ✓, ≤25-word summary ✓, 2–5 tags ✓, ≤1,000 words ✓, valid category ✓, `Last Updated` bumped ✓. Catches its own slop without the user having to. | LOW | Checklist baked into the digest skill prompt. No new infra. |

### Anti-Features (Explicitly NOT Building — With Reasoning)

The single most important section. Documenting these prevents scope creep and makes review tractable.

| # | Anti-Feature | Why It Looks Tempting | Why We Don't Build It | What We Do Instead |
|---|--------------|----------------------|----------------------|-------------------|
| A1 | **Real-time wiki sync as code changes** | Feels modern, "live docs!", matches the AutoDream "agent dreams during idle" framing. | (a) PROJECT.md explicit out-of-scope. (b) Hooks can't write files directly — would require a runtime, violating the no-runtime constraint. (c) Real-time updates fight T15 (cheap inbox) — every code change becomes a wiki write. (d) Mid-stream updates can't see the "1+1-then-deleted" pattern correctly; only end-of-turn snapshots can. | Stop-hook + inbox + manual digest. Synchronization happens at logical boundaries, not byte changes. |
| A2 | **Multi-user / collaborative concerns** | Most "wiki" tools assume teams. | PROJECT.md explicit out-of-scope. Single-developer tooling. Multi-user requires conflict resolution, locking, attribution — none of which is needed and all of which would derail the design. | Document the single-user assumption in the install README. Future users running shared wikis are responsible for their own merge discipline (git). |
| A3 | **Web UI / browser viewer** | Wikis "should" have a viewer. | PROJECT.md explicit out-of-scope. The existing wiki is plain markdown — Obsidian, VS Code preview, GitHub render, and cat all already work. Building a viewer duplicates effort and adds runtime. | Rely on existing markdown viewers. The Obsidian-compatible wiki-link syntax is the integration. |
| A4 | **Schedule-based auto-digest** | Cron-style automation feels professional. | PROJECT.md explicit out-of-scope for v1. Scheduled digests run when no human is reviewing — exactly the wrong time to mutate a wiki without preview (D2). Also, "features rarely end at session boundaries" (PROJECT.md decision rationale) — clock-based digests would routinely fire mid-feature and produce incoherent notes. | Manual `/wiki-digest` + D4 self-monitoring nudge. The user decides when a feature is "done enough" to file. |
| A5 | **Backfilling docs from existing code** | Greenfield repos rarely exist; users want "point it at my codebase, generate the wiki." | PROJECT.md explicit out-of-scope. Backfill is a fundamentally different task: it's batch summarization of existing artifacts, not capture-while-building. Tools like DocuWriter.ai already do this; there's no reason to compete on it. The inbox-then-digest model presupposes that work is happening with Claude in the loop. | Users who want a starter wiki write one or use a separate tool. We auto-maintain it from there. |
| A6 | **Migrating between wiki conventions** | Users with existing docs in different formats (Docusaurus, MkDocs, Confluence) will ask. | PROJECT.md explicit out-of-scope. Each format has its own quirks and the project's value lies in respecting *one* fixed contract (Rules.md), not in being a universal converter. | Document Rules.md as the contract. Users migrate to it (or fork the skill to target their own conventions) themselves. |
| A7 | **Modifying `wiki/Rules.md`** | The skill could "improve" the conventions over time. | PROJECT.md explicit constraint. Rules.md is the contract that makes the digest agent's decisions reproducible. If the skill rewrites the rules, behavior becomes unpredictable across sessions. | The digest agent may *propose* rule changes to the user (e.g., "consider adding a `DECISIONS/` folder") but never edits Rules.md autonomously. |
| A8 | **Chronological session log inside the inbox** | The inbox could become a journal: "10:31 added function X; 10:45 deleted function X; 11:02 added function Y". | This breaks T3 self-pruning (the 1+1-then-deleted case). A chronological log preserves contradictions; state-of-the-world semantics dissolve them. PROJECT.md key decision. | Atomic, flat, state-of-the-world entries. The current truth, not the history. History lives in git. |
| A9 | **In-session note sectioning / pre-routing** | The inbox could already organize entries by category: `# ARCHITECTURE`, `# FUNCTIONS`, etc. | Forces categorization decisions during work, when context is partial. Per PROJECT.md key decision: "Atomic, flat entries (no in-session sectioning) — lowers categorization burden during the session; digest agent routes holistically with full context." | Flat inbox; sub-agent routes at digest time with full inbox + existing wiki visible. |
| A10 | **Semantic-similarity duplicate detection in T8** | "Cosine-similarity the inbox entry against existing notes to find conceptual duplicates." | Requires embeddings infrastructure → violates no-runtime constraint. Filename and title grep covers the common case. The remaining gap (synonym duplicates: "auth handler" vs. "login service") is rare enough to handle on a follow-up pass. | T8 uses filename + title + tag overlap. Surface ambiguous matches to the user during the digest review (D2 dry-run). |
| A11 | **Auto-commit of digest results** | Digest writes files → "just commit them too." | Mixes documentation work with version control work. Users have their own commit hygiene; auto-committing surprises them. Also conflicts with D2 (dry-run): a committed change is harder to revert than a staged one. | Digest writes files. User stages and commits. (Optional: post-digest message reminds the user to commit.) |
| A12 | **Modifying existing source code based on inbox observations** | "The inbox said this function was deleted, but the file still has it — let me clean that up." | Massive scope creep. The skill is a documentation tool, not a refactoring agent. Going there means owning correctness of code mutations, which is a different product. | Surface the contradiction in the digest plan; let the user decide. |

## Feature Dependencies

```
T1 (Stop hook)
    └──enables──> T2 (Inbox skill)
                       └──enables──> T3 (Self-pruning) ──depends-on──> A8 (state-of-world, not chronological)
                       └──enables──> T15 (Cheap updates — design constraint on T2)

T4 (Digest skill)
    ├──depends-on──> T2 (inbox must be filable)
    ├──requires──> T5 (Routing) ──depends-on──> Rules.md §2
    ├──requires──> T6 (Template) ──depends-on──> _templates/note.md
    ├──requires──> T7 (Kebab-case)
    ├──requires──> T8 (Conflict handling) ──enables──> D6 (Stale-link repair)
    ├──requires──> T9 (1000-word split)
    ├──requires──> T10 (Wiki-links) ──enables──> D5 (Link validation)
    ├──requires──> T11 (Idempotence) ──depends-on──> T12 (Archive-on-digest)
    └──enables──> D2 (Dry-run preview)
                       └──enables──> D3 (Per-feature scope) — scope filter applied to the plan
                       └──enables──> D8 (Self-check) — runs against the dry-run plan

T13 (Installable) ── depends-on ──> T1, T2, T4, T14 all packaged together

D4 (Self-monitoring) ── enhances ──> T4 (reminds user to run digest)
D7 (SELF snapshot) ── enhances ──> T4 (side effect of digest)
D1 (Rationale capture) ── enhances ──> T2 and T5 (new entry shape, new routing target)

A1 (Real-time sync) ── conflicts with ──> T1, T15 (would replace hook with runtime)
A4 (Scheduled digest) ── conflicts with ──> D2 (preview requires a human reviewer)
A8 (Chronological log) ── conflicts with ──> T3 (would break self-pruning)
A9 (Pre-routing) ── conflicts with ──> T2's flat-entry decision
```

### Dependency Notes

- **T11 (idempotence) hinges on T12 (archive-on-digest):** "archive then truncate" is the cheapest correct design. Without archive, the digest must instead track which entries it has already processed, which requires per-entry IDs and is much harder.
- **D2 (dry-run) is the cleanest extension of T4 once T8 (conflict handling) exists:** the same lookup logic that decides "edit vs. create" produces the diff. Building T8 with a clean separation between "produce plan" and "apply plan" gives D2 nearly for free.
- **D6 (stale-link repair) only matters if T8 ever causes a rename:** if T8's policy is "edit in place, never rename," D6 is unnecessary. Decide T8's rename policy first.
- **D3 (per-feature scope) is structurally awkward without a tag in T2:** if inbox entries are pure-flat-text with no metadata, retrofitting scope filtering means the sub-agent has to infer scope by re-reading. Adding a lightweight scope tag to the inbox-skill conventions early (T2) is much cheaper than retrofitting later.
- **A8 (chronological log) is the load-bearing anti-feature:** if the inbox isn't state-of-the-world, T3 self-pruning becomes architecturally impossible, not just hard. PROJECT.md correctly identifies this as a key decision; deviating from it cascades.

## MVP Definition

### Launch With (v1) — Validates the Core Hypothesis

The hypothesis to validate: **a Stop-hook + inbox-skill + manual-digest loop produces a wiki that stays current with low ongoing cost, including the 1+1-then-deleted case.** Anything not directly serving that hypothesis is post-MVP.

- [x] T1 Stop-hook trigger
- [x] T2 Inbox-upkeep skill
- [x] T3 Self-pruning (validates the key claim)
- [x] T4 Manual digest slash command
- [x] T5 Routing into category folders (correctness baseline)
- [x] T6 Template conformance
- [x] T7 Kebab-case filenames
- [x] T8 Conflict handling — edit vs. create (basic: filename+title grep)
- [x] T9 1,000-word split rule
- [x] T10 Wiki-link cross-references
- [x] T11 Idempotence (via T12 archive-on-digest)
- [x] T12 Inbox lifecycle / archive-on-digest
- [x] T13 Installable into a target repo
- [x] T14 No-modification of Rules.md
- [x] T15 Cheap inbox-update prompt

### Add After Validation (v1.x) — High-Leverage, Low-Cost

Add when v1 validates. These are cheap relative to their value.

- [ ] **D2 Dry-run preview** — highest user-trust ROI; the difference between "I'll try this on a side branch" and "I'll install it on my real wiki." Build immediately after MVP.
- [ ] **D4 Inbox-bloat self-monitoring** — trivial to add, closes a real failure mode (forgotten digests).
- [ ] **D5 Link validation pass** — cheap insurance, catches the most common Obsidian failure.
- [ ] **D8 Digest self-check pass** — pure prompt-engineering, no new infra; raises digest quality.
- [ ] **D7 `SELF/` snapshot on digest** — one extra file per digest, compounds with future Claude sessions.

### Future Consideration (v2+) — Earn Their Complexity

Defer until real usage shows demand.

- [ ] **D1 Decision/rationale capture** — wait to see whether users naturally write decision-class entries; if so, formalize. Low risk to defer.
- [ ] **D3 Per-feature digest scope** — only matters at sustained usage where multiple features are in-flight. Premature for v1.
- [ ] **D6 Stale-link repair on rename** — only needed if T8 develops a rename policy. Defer until T8's behavior is empirically settled.

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| T1 Stop-hook trigger | HIGH | LOW | P1 |
| T2 Inbox-upkeep skill | HIGH | MEDIUM | P1 |
| T3 Self-pruning (1+1-deleted case) | HIGH | MEDIUM | P1 |
| T4 Manual digest skill | HIGH | MEDIUM | P1 |
| T5 Routing into folders | HIGH | MEDIUM | P1 |
| T6 Template conformance | HIGH | LOW | P1 |
| T7 Kebab-case filenames | MEDIUM | LOW | P1 |
| T8 Conflict handling (edit vs. create) | HIGH | MEDIUM-HIGH | P1 |
| T9 1,000-word split rule | MEDIUM | MEDIUM | P1 |
| T10 Wiki-link cross-references | HIGH | MEDIUM | P1 |
| T11 Digest idempotence | HIGH | LOW-MEDIUM | P1 |
| T12 Inbox lifecycle | HIGH | LOW | P1 |
| T13 Installability | HIGH | MEDIUM | P1 |
| T14 No Rules.md modification | MEDIUM | LOW | P1 |
| T15 Cheap inbox-update prompt | HIGH | MEDIUM | P1 |
| D2 Dry-run preview | HIGH | MEDIUM | P2 |
| D4 Inbox-bloat warning | MEDIUM | LOW | P2 |
| D5 Link validation | MEDIUM | LOW-MEDIUM | P2 |
| D8 Digest self-check | MEDIUM | LOW | P2 |
| D7 SELF/ session snapshot | MEDIUM | LOW | P2 |
| D1 Rationale / ADR capture | MEDIUM | MEDIUM | P3 |
| D3 Per-feature digest scope | MEDIUM | MEDIUM-HIGH | P3 |
| D6 Stale-link repair on rename | LOW (until T8 renames) | MEDIUM | P3 |

**Priority key:**
- **P1** — Must have for v1. The system fails its core promise without it.
- **P2** — Add immediately after MVP validates. High value, low cost; user-trust amplifiers.
- **P3** — Defer until real usage demands it. Risk of building the wrong abstraction without empirical signal.

## Comparable Systems Analysis

Comparable systems in the same problem space, with how this project's design relates:

| Feature | Claude Code AutoDream | thedotmack/claude-mem | DocuWriter.ai Autopilot | Cursor Rules / Memory | This Project |
|---------|----------------------|----------------------|------------------------|----------------------|--------------|
| Capture trigger | Background "dream" cycle (24h + 5 sessions) | Auto-captures every session | Detects code changes | Rules loaded per session | Stop hook per turn |
| Storage | CLAUDE.md + auto-memory files | Compressed session memory | Dedicated docs system | `.cursorrules` files | Obsidian markdown wiki (`wiki/`) |
| Pruning | Automatic in dream cycle | Compression + relevance | Auto-suggests updates | Manual rule edits | Self-pruning via state-of-world inbox + digest |
| Conflict resolution | Resolves contradictions during dream | Compression dedup | Manual review | Manual | Filename/title grep + dry-run preview (planned) |
| Cross-links | None (flat memory) | None | Generated docs | None | Obsidian `[[wiki-links]]` (P1) |
| Preview before apply | No (background) | No (auto) | Suggests updates | N/A | D2 dry-run (P2) |
| User-triggered | No | No | Yes for major regen | Yes | Yes (manual digest) |
| Runtime | Embedded in Claude Code | Plugin runtime | Hosted service | None (text files) | None (skill + hook only) |
| Schedule | Idle-time + dual-gate | Per session | On change | N/A | Manual only |

**Where this project is differentiated:**
- **Obsidian-compatible structured wiki output** (vs. flat memory files) — the wiki is also human-readable in any markdown viewer, not just useful as agent context.
- **No-runtime delivery** — pure skill + hook, no plugin install, no embedded process.
- **State-of-the-world inbox** — explicit semantics for self-pruning that AutoDream achieves via background reasoning instead. Cheaper at capture time.
- **Manual digest with planned dry-run** — preserves user agency over a persistent artifact, unlike AutoDream's silent background mutation.

**Where it's intentionally NOT differentiated:**
- Not competing on capture intelligence (AutoDream's consolidation is more sophisticated).
- Not competing on backfill (DocuWriter dominates that niche — A5).
- Not competing on cross-session memory primitives (claude-mem and CLAUDE.md cover those — orthogonal).

## Open Questions for Roadmap

1. **T8 rename policy** — when a 1,000-word split happens or a concept is reframed, does the digest rename existing notes (and trigger D6 repair) or always leave deprecated stubs (Rules.md §8 alternative)? Pick one before designing T8 in detail.
2. **D2 plan format** — is the dry-run output a single markdown file the user reads, or interactive prompts? Affects digest UX significantly.
3. **D1 routing target** — does rationale capture warrant a new `DECISIONS/` folder (which means proposing a Rules.md update — but Rules.md §2 explicitly allows this), or does it route to `ARCHITECTURE/`?
4. **T15 specifics** — what exactly does the inbox-update prompt look like? Append-only with a periodic compaction? Read-modify-write of a relevant section? This is the single biggest cost lever.
5. **T13 install mechanics** — does the install target `~/.claude/skills/` (user-global) or `.claude/skills/` (per-repo)? Different deployment ergonomics.

## Sources

Comparable systems and patterns:

- [Claude Code AutoDream — MindStudio overview](https://www.mindstudio.ai/blog/what-is-claude-code-autodream-memory-consolidation) — staleness pruning, contradiction resolution, dual-gate activation patterns directly comparable to digest design.
- [Claude Code AutoDream — Supalaunch guide](https://supalaunch.com/blog/claude-code-dreams-auto-dream-memory-consolidation-guide)
- [Claude Code AutoDream — claudefa.st](https://claudefa.st/blog/guide/mechanics/auto-dream)
- [thedotmack/claude-mem on GitHub](https://github.com/thedotmack/claude-mem) — alternative architecture (runtime plugin vs. our skill+hook).
- [DocuWriter.ai Autopilot](https://www.docuwriter.ai/) — change-detection and auto-update reference; intentionally orthogonal to our scope (A5).
- [Architectural Decision Records (ADR) catalog](https://adr.github.io/) — D1 rationale-capture pattern.
- [AWS — Master ADRs best practices](https://aws.amazon.com/blogs/architecture/master-architecture-decision-records-adrs-best-practices-for-effective-decision-making/) — ADR storage colocated with code.

Claude Code primitives (HIGH confidence — official docs):

- [Claude Code Hooks Guide](https://code.claude.com/docs/en/hooks-guide) — Stop, PostToolUse, SessionStart, SessionEnd hook mechanics.
- [Claude Code Memory Docs](https://code.claude.com/docs/en/memory) — CLAUDE.md and auto-memory architecture.
- [Claude Code: Hooks, Subagents, Skills — DEV.to walkthrough](https://dev.to/owen_fox/claude-code-hooks-subagents-and-skills-complete-guide-hjm)
- [Anatomy of a Claude Code Session — codewithmukesh](https://codewithmukesh.com/blog/anatomy-claude-code-session/)

Obsidian conventions (HIGH confidence):

- [Obsidian Internal Links — official help](https://help.obsidian.md/links) — wiki-link semantics and rename behavior.
- [Smart Rename plugin](https://www.obsidianstats.com/plugins/smart-rename) — D6 stale-link-repair pattern reference.
- [Obsidian forum — rename creates new link issue](https://forum.obsidian.md/t/i-just-discovered-that-if-i-change-the-name-of-a-link-it-makes-a-new-one-crap/13138) — failure mode that D5 link validation catches.

Dry-run / preview patterns (HIGH confidence — universal infrastructure idiom):

- [kubectl dry-run + diff guide](https://oneuptime.com/blog/post/2026-01-25-kubectl-diff-preview-changes/view) — D2 mental model.
- [Ansible check + diff mode](https://www.ansiblepilot.com/articles/ansible-playbook-dry-run-check-and-diff-mode)
- [git commit --dry-run](https://git-scm.com/docs/git-commit/2.6.7)

Conflict resolution / merge (MEDIUM confidence — directional, not normative):

- [Cursor AI Resolve Conflicts](https://docs.cursor.com/more/ai-merge-conflicts) — comparable AI conflict-handling, primarily for code rather than docs.
- [AI Document Consistency — testmanagement.com](https://www.testmanagement.com/blog/2025/11/ai-document-consistency/) — consequences of conflicting docs in agent context (motivates T8).

Incremental / scope patterns (MEDIUM confidence — directional, broader domain):

- [Eleventy Incremental Builds](https://www.11ty.dev/docs/usage/incremental/) — D3 per-feature scope mental model.
- [TypeScript incremental builds](https://deepwiki.com/microsoft/TypeScript/8-incremental-and-project-builds)

---
*Feature research for: AI-driven, auto-maintained codebase wiki (Claude Code skill + hook scaffolding)*
*Researched: 2026-04-28*
