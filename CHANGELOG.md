# Changelog

All notable changes to llm-code-wiki are documented here.
Versions follow [Semantic Versioning](https://semver.org/).

The `Migration` subsection of each release lists anything `/wiki-update` cannot do for you — manual steps a consumer must take when upgrading past that version.

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
