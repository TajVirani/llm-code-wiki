# Changelog

All notable changes to llm-code-wiki are documented here.
Versions follow [Semantic Versioning](https://semver.org/).

The `Migration` subsection of each release lists anything `/wiki-update` cannot do for you — manual steps a consumer must take when upgrading past that version.

## [1.3.3] — 2026-05-10

### Fixed
- **`/wiki-digest` aborted with `Shell command failed for pattern "!P=\"${ARGUMENTS:-wiki/inbox/_session.md}\"; cat \"$P\" 2>/dev/null"`.** Three `!`-injected backtick blocks in `wiki-digest/SKILL.md` (entry-count, archive-session, cat-session) used `${ARGUMENTS:-wiki/inbox/_session.md}` to default a path. Bash's `${VAR:-default}` syntax around `${ARGUMENTS}` (a Claude-Code-substituted skill variable) collides with the harness's own preprocessing of `${ARGUMENTS}` and causes the harness to reject the command. Fixed by splitting the form into bare `$ARGUMENTS` (which the harness substitutes cleanly) feeding a regular bash variable, then defaulting that: `P="$ARGUMENTS"; P="${P:-wiki/inbox/_session.md}"; …`. Same flavor of harness-fragility as the multi-line `!`-injection bug fixed in 1.3.2 and the awk `$N`-expansion bug fixed in 1.3.0 — bash works fine when run directly, breaks only through the harness.

### Added
- **`tests/static.sh` lints `${ARGUMENTS:-…}` in `!`-injected blocks.** Reject any `!`-block matching `\$\{ARGUMENTS[:-]` and point at the safe pattern. Caught all three occurrences in wiki-digest in CI.

### Changed
- **wiki-digest "Resolve the session inbox path" prose updated** to document the `P="$ARGUMENTS"; P="${P:-default}"` pattern and explain the `${ARGUMENTS:-…}` collision, with a pointer to the `tests/static.sh` lint that enforces it.

### Migration
- **No manual migration required.** Fix activates the moment the new `wiki-digest/SKILL.md` lands via `/wiki-update`. Behavior of `/wiki-digest` is identical otherwise — only the argument-default literal layout changed.

## [1.3.2] — 2026-05-09

### Fixed
- **`/wiki-modules` aborted with `eval: line 13: syntax error near unexpected token \`done'`.** Two of the skill's `!`-injected backtick blocks (the prefix-cluster member listing and the Signal-3 external-fan-in computation) spanned multiple physical lines. Claude Code's skill harness mangles multi-line ` !\`...\` ` blocks — the trailing `done` lands on its own eval line with no matching `do`, and bash rejects it. Both blocks are now collapsed onto single lines using `;` separators; behavior is identical. Same kind of latent harness-fragility bug as the `!`-injection `$N` expansion bug fixed in 1.3.0 (both surface only when the skill actually executes, not from reading the source).

### Added
- **`tests/lib/extract-bang-blocks.sh`** — extracts `!`-injected backtick blocks from a SKILL.md (single-line and multi-line, indent-aware so it doesn't false-positive on mid-prose mentions of ` !`syntax` `).
- **`tests/static.sh` lints `!`-injection blocks** — for every SKILL.md, runs `bash -n` on each extracted block AND rejects any block that spans more than one physical line. The multi-line lint is the defensive rule that would have caught `/wiki-modules` before a user did. Adds 3 PASS lines (one per skill that uses `!`-injection: wiki-code-crawler, wiki-digest, wiki-modules) → L1 grows from 55 → 58 checks.

### Changed
- **`/wiki-modules` implementation note expanded** — the existing "no `awk`" caveat now also documents the "no multi-line `!`-injection" rule, with a pointer to the `tests/static.sh` lint that enforces both.

### Migration
- **No manual migration required.** The fix activates the moment the new `wiki-modules/SKILL.md` lands via `/wiki-update`. Behavior of the cluster-detection signals is unchanged — only the bash literal layout differs.

## [1.3.1] — 2026-05-09

### Added
- **Default permissions seeded into `.claude/settings.json` on install.** `/wiki-install` Block 2 and `/wiki-update` Step 5 now write `Read(wiki/inbox/_session.md)`, `Edit(wiki/inbox/_session.md)`, `Write(wiki/inbox/_session.md)` into `permissions.allow`. Without these, the auto-wiki capture path triggers a permission prompt every Stop-hook fire (i.e. after every code-edit turn). The fresh-create branch (Case A) writes the block via heredoc; the merge branch (Case B/C) runs an `upsert_permission` jq filter that skips entries already present and never removes user-added ones. `/wiki-update` backfills the same three entries on existing installs that pre-date this feature, also without disturbing user-added permissions. Manual no-jq fallback documented in `.claude/skills/wiki-install/SETTINGS-SNIPPET.md`.
- **`tests/` shell-based test harness** — three layers, no Claude needed. `tests/static.sh` (L1) walks `dist-manifest.txt`, validates frontmatter on every SKILL.md and agent .md, runs `bash -n` on hooks plus every fenced ` ```bash ` block in every SKILL.md. `tests/hooks.sh` (L2) unit-tests both hook scripts with synthetic JSON input — covers `stop_hook_active`, kill switches, noop/artifact branches, brainstorm-fallback (uses `LCW_BRAINSTORM_TURNS=3` for speed), recall fire/noop/wiki-only/cooldown. `tests/install-e2e.sh` (L3) extracts the install/update bash blocks and runs them in tmpdir fixtures, asserting `settings.json` shape, idempotence, user-permission preservation, and the wiki-update Step-5 backfill path. `tests/run-all.sh` runs all three; supply layer names to run a subset. L3 skips cleanly when `jq` is missing.
- **`.github/workflows/test.yml`** — runs `tests/run-all.sh` on push to main and on every pull request. Installs `jq` so L3 runs. Keeps the scaffold honest as it evolves.

### Fixed
- **`$CLAUDE_PROJECT_DIR` token verification was always failing on Case B/C of the settings.json merge.** `/wiki-install` Block 2 and `/wiki-update` Step 5 verify post-merge that the literal `$CLAUDE_PROJECT_DIR` token survived (i.e., wasn't shell-expanded into a hardcoded install-time path). The verification used `grep -q '"$CLAUDE_PROJECT_DIR"/...'` but jq writes the JSON value with the inner double-quotes serialized as `\"$CLAUDE_PROJECT_DIR\"`, so the unescaped pattern never matched and the merge aborted. Fixed by switching to `grep -qF '\"$CLAUDE_PROJECT_DIR\"/...'` to byte-match the JSON-escaped form. The L3 install-e2e harness caught this. Same flavor of latent bug as the `!`-injection `$N` expansion bug fixed in 1.3.0 — captured in the new `RESEARCH::jq-json-escape-grep-verification` inbox entry for the next `/wiki-digest` run.

### Migration
- **No manual migration required.** Existing installs gain the three default permission entries on the next `/wiki-update`; the merge skips entries already present, so re-runs converge to a zero-content-diff. The B3 verification fix activates the moment the new `/wiki-update` lands the new `wiki-install/SKILL.md` and `wiki-update/SKILL.md` files.

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
