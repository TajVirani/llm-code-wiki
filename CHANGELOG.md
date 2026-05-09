# Changelog

All notable changes to llm-code-wiki are documented here.
Versions follow [Semantic Versioning](https://semver.org/).

The `Migration` subsection of each release lists anything `/wiki-update` cannot do for you — manual steps a consumer must take when upgrading past that version.

## [1.3.0] — 2026-05-09

### Added
- **`docs/adr/0001-modules-ownership-and-detection.md`** — formal ADR codifying that `/wiki-modules` is the sole writer to `wiki/MODULES/`. The wiki-curator no longer writes MODULES notes; `@ MODULES::<slug>` handles in `_session.md` surface as `MODULES-VIA-DIGEST-DEPRECATED` plan rows during digest with no write performed.
- **`module-author` subagent** (`.claude/agents/module-author.md`) — dispatched in parallel by `/wiki-modules`, one per qualifying cluster. Reads its cluster's children, applies pre-author and post-author depth gates, and writes `wiki/MODULES/<slug>.md` plus the matching `### Modules` row in `wiki/topic-index.md`.
- **`/design-pattern-doc` skill** — discover and document a multi-file design pattern in the codebase. Produces a ground-truth doc plus a drift report against existing project documentation. Use for cross-cutting patterns and subsystem wiring.

### Changed
- **`/wiki-modules` cluster-detection signals rebased per ADR 0001** — three deterministic signals: S1 filename prefix ≥3 notes (bootstrap), S2 single-dominant-tag intersection across all members (replaces the prior top-2 mode test — admits clusters whose members diverge into specialized topics past one shared concept), S3 external fan-in: ≥1 note outside the cluster links to ≥2 distinct cluster members (replaces the prior intra-cluster-link density test — measures whether the cluster has an external interface, not just internal cohesion).
- **`/wiki-digest` no longer pre-computes module-cluster signals.** Trigger 7 (Rules.md §12 row 7) was removed from the digest pipeline. `/wiki-modules` owns the orientation layer end-to-end. The wiki-digest skill body is leaner: input gathering for the curator, archive-then-write, post-write link audit, lifecycle cleanup.
- **`wiki-curator` write surface narrowed.** Curator never writes `wiki/MODULES/<slug>.md` and never modifies `wiki/Rules.md` or `wiki/_templates/`. Path-safety denylist: `wiki/Rules.md`, `wiki/_templates/**`, `wiki/MODULES/**`.

### Fixed
- **`!`-injection `$N` expansion bug.** Claude Code's skill `!`-injection layer expands `$N` references in awk scripts to empty strings before the shell sees them, breaking field access. All cluster-detection bash blocks in `/wiki-modules` now use `cut`/`sed` + a `while read` loop instead of `awk`. An inline implementation note in the skill body warns future edits not to re-introduce awk; the underlying bug is documented at `wiki/RESEARCH/skill-bash-injection-dollar-n-expansion.md`.

### Migration
- **No manual migration required.** Existing `wiki/MODULES/` notes from previous versions remain valid. The next `/wiki-modules` run audits each existing module against current cluster signals and re-authors qualifying clusters from scratch (failed-gate clusters surface as `STALE-MODULE` warnings — files are NOT auto-deleted).
- **If you previously relied on `/wiki-digest` to auto-create module notes via the trigger-7 pre-evaluation:** that path is gone. Run `/wiki-modules` manually to refresh the orientation layer.

## [1.2.0] — 2026-05-06

### Added
- **`MODULES/` orientation layer** — sixth wiki category for ~6–10 cluster summaries per project that link down to the existing ARCHITECTURE/FUNCTIONS/RESEARCH/DIAGRAMS detail layer. Module slugs are bare single-concept kebab identifiers (`scheduling`, not `scheduler-overview`). Updates Rules.md §2 (category table), §5 (slug rules + cross-category collision), §11 (`### Modules` / `### Notes` H3 split in topic-index, ≤100 combined cap), §12 (new trigger 7 row — module-cluster shape), and adds new §13 (1-of-2 same-concept rule for MODULES — tag overlap dropped because parent/child relationships structurally share tags).
- **New `_templates/module.md`** — 7-H2 inner skeleton: Purpose, Boundary, Triggers, Storage, Behavior, Rules & Invariants, Children. Children groups detail-note links by H4 sub-headings (`#### From ARCHITECTURE`, etc.).
- **Curator deletion-test gate (Step 5a)** — every CREATE/EDIT routed to MODULES must satisfy ≥5 of 7 inner H2s with `Purpose` + `Boundary` mandatory. Failures convert to surface-only `SHALLOW-MODULE` rows (no write). Threshold lives in the curator prompt — tunable without amending Rules.md.
- **Curator trigger 7** — module-cluster detection from four deterministic signals (S1 ≥3 wiki-link/basename references; S2 ≥3 of 4 keyword categories — trigger/storage/executor/outcome; S3 ≥2 distinct dominant domain tags; S4 word band 150–1000). Pre-evaluated by `wiki-digest` skill body in bash and emitted as labeled prompt sections (`### Trigger 7 signals: S1=N, S2=…, S3=N, S4=N`) so the curator applies the all-four rule deterministically. Fork fallback path computes signals via Read/Grep when `disableSkillShellExecution: true`.
- **New `SLUG-COLLISION` plan row** — surface-only when a MODULES slug equals an existing basename in another category; user decides whether to rename or merge.
- **`/wiki-modules` slash command** (`.claude/skills/wiki-modules/SKILL.md`) — read-only manual scan that proposes MODULES notes for clusters lacking one (filename-prefix + tag-overlap + link-graph signals) AND audits existing MODULES notes for broken children, deprecated links, unlinked candidates, and scope drift. Emits both sections in one run.
- **Recall agent orienting/narrow query split** — orienting prompts ("what is", "how does", "overview of", "explain") prefer `### Modules` bullets; narrow prompts (specific function, endpoint, error, value) hit `### Notes` directly; mixed-intent returns both.
- **Optional MODULES auto-handle in `inbox-update`** — soft hint that emits `@ MODULES::<slug>` when a turn touches ≥4 ARCHITECTURE/FUNCTIONS notes sharing ≥2 tags AND the user's message reads as synthesis. The curator's trigger 7 still validates; auto-handles that don't earn the route are dropped as `SHALLOW-MODULE`.
- **Topic-index H3 split** — `### Modules` (orientation, `Module: MODULES/<slug>.md` form) above `### Notes` (detail, `Files: PATH1, PATH2` form). The curator's Step 9 performs a one-time additive restructure on the first MODULES write for indexes that predate this rollout.
- **Install scaffolding** — `wiki-install` Block 1 now creates `wiki/MODULES/`; precondition list includes the new `wiki-modules` skill.

### Migration
- **Existing wikis automatically restructure on first MODULES write.** No manual action required — the curator's Step 9 detects the absence of `### Modules` and inserts `### Modules` (empty) and `### Notes` headings around the existing flat bullet list, preserving order. Surfaces a one-line note in the digest summary.
- **Optional pre-migration restructure** — to land the H3 split before any MODULES note is written, manually insert `### Modules\n\n### Notes` headings around the existing bullets in `wiki/topic-index.md` (or copy `wiki/topic-index.seed.md` as a template). Otherwise, the first `/wiki-digest` that creates a MODULES note will do the restructure for you.
- **No content moves.** Children of MODULES notes stay listed in `### Notes` flatly — they are NOT removed when a parent module is added. The MODULES note is purely additive orientation.

## [1.1.0] — 2026-05-01

### Changed
- **Wiki-link contract switched to piped form `[[note-basename|Display Title]]`.** Bare `[[Title]]` is now forbidden because Obsidian's default resolver matches against filenames (kebab-case per Rules.md §5), not H1 titles — bare links to kebab-case files did not resolve and clicking them created blank notes at the vault root. Updates Rules.md §3 + §7, all 7 templates in `wiki/_templates/`, the wiki-curator agent (validation, split-backlink rewrite using slug-keyed grep, post-write audit becomes file-existence check on basename), the wiki-recall agent output format, the wiki-digest audit description, and the install-skill `topic-index.seed.md`.

### Migration
- **Existing wikis must rewrite inbound links from bare to piped form.** Run a deterministic transform: for every `[[X]]` (no pipe) in `wiki/**/*.md`, compute basename = X.lower().replace(' ', '-'); if a file with that basename exists in the wiki, replace with `[[basename|X]]`. Skip code blocks and HTML comments. Audit afterward: every `[[Y|Z]]` must have a matching `wiki/**/<Y>.md`. The new curator's Step 8 audit will surface any remaining bare links as contract violations.

## [1.0.0] — 2026-04-30

### Added
- Initial public release.
- `/wiki-install`, `/wiki-digest`, `/wiki-recall`, `/wiki-update` slash commands.
- Stop hook (`inbox-stop.sh`) — capture path; nudges Claude to update `wiki/inbox/_session.md` after every assistant turn.
- UserPromptSubmit hook (`recall-prompt.sh`) — recall path; injects wiki-recall instruction on planning-intent prompts.
- Brainstorm-fallback every-N-turns capture for design conversations with no code edits (`LCW_BRAINSTORM_TURNS` env var, default 10).
- Distribution manifest (`dist-manifest.txt`) with optional per-line update policy column (`overwrite` default, `keep` for user-owned wiki seeds).
- Version stamping: `/wiki-install` writes upstream `VERSION` to `.claude/llm-code-wiki.version` so `/wiki-update` can compare.

### Migration
- (none — first release)
