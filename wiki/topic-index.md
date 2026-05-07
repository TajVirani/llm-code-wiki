
**Summary**: Greppable topic-to-files index — entry point for wiki recall.
**Tags**: #wiki #index #recall
**Created**: 2026-04-30T00:00:00+00:00
**Last Updated**: 2026-05-06T00:00:00+00:00

---

## Content

<!--
Auto-maintained by `/wiki-digest`. One bullet per topic. Format:
  - **topic** — One sentence (≤25 words) describing what the topic covers. Files: PATH1, PATH2

Rules:
- Topic name in **bold**, kebab-case.
- Summary describes what the topic *covers*, not what each file says.
- Files: comma-separated relative paths from wiki/ root. No [[wiki-link]] syntax — paths are explicit so grep returns precise hits.
- No nesting, sub-bullets, or extra prose. Split a topic into two if it grows beyond one line.
- Alphabetized by topic name for stable diffs.
- Hard cap: ≤100 entries.

Do not edit by hand — bullets that are not the result of a digest run will be overwritten on the next /wiki-digest.
-->

### Modules

### Notes

- **brainstorm-fallback-cadence** — Default 10-turn cadence for brainstorm-fallback capture, override via `LCW_BRAINSTORM_TURNS`, ≤5 entries per fire, counter resets on real captures. Files: RESEARCH/brainstorm-fallback-cadence.md
- **curator-step-9-index-update** — Curator protocol step that rebuilds topic-index.md after each digest, scoped to topics affected by writes. Files: ARCHITECTURE/curator-step-9-index-update.md
- **deletion-test-gate** — Curator Step 5a gate enforcing ≥5 of 7 inner H2s with `Purpose` and `Boundary` mandatory before any MODULES write. Files: ARCHITECTURE/deletion-test-gate.md
- **digest-step-6-inbox-reset** — wiki-digest skill body resets `wiki/inbox/_session.md` to empty template after curator success and post-write audit. Files: ARCHITECTURE/digest-step-6-inbox-reset.md
- **fork-context-no-parent-runtime** — Under Claude Code `context: fork`, the skill body becomes the subagent prompt and no parent runtime resumes; lifecycle steps must be owned by the subagent. Files: RESEARCH/fork-context-no-parent-runtime.md
- **inbox-stop-hook** — Stop hook script orchestrating capture path, loop-protection trifecta D-01/D-02/D-03, and per-session brainstorm counter. Files: FUNCTIONS/inbox-stop-hook.md
- **install-template-files** — Two scaffold-internal templates (`CLAUDE-MD-SECTION.md`, `topic-index.seed.md`) under `.claude/skills/wiki-install/templates/` shared by `/wiki-install` and `/wiki-update`. Files: ARCHITECTURE/install-template-files.md
- **inbox-update-skill** — Skill maintaining `wiki/inbox/_session.md` from artifact ops; adds brainstorm-fallback mode that scans recent conversation for design decisions. Files: FUNCTIONS/inbox-update-skill.md
- **modules-category** — MODULES sixth canonical category — orienting cluster summaries linking down to detail notes; bare kebab slugs; 1-of-2 same-concept rule. Files: ARCHITECTURE/modules-category.md
- **piped-wiki-link-contract** — Mandatory `[[note-basename|Display Title]]` form for all internal wiki-links; bare `[[Title]]` forbidden because Obsidian resolves on filename, not H1. Files: ARCHITECTURE/piped-wiki-link-contract.md
- **recall-path** — Read-side architecture: UserPromptSubmit hook plus wiki-recall sub-agent surface relevant wiki context before Claude responds. Files: ARCHITECTURE/recall-path.md
- **recall-prompt-hook** — UserPromptSubmit hook script that detects planning-intent prompts and triggers wiki-recall sub-agent spawn. Files: FUNCTIONS/recall-prompt-hook.md
- **recall-skill** — `/wiki-recall` slash command skill that forks into wiki-recall sub-agent for on-demand wiki consultation. Files: FUNCTIONS/recall-skill.md
- **remote-install-flow** — Remote-install architecture using `dist-manifest.txt` to fetch the scaffold from a public repo URL without dragging the dogfood wiki along. Files: ARCHITECTURE/remote-install-flow.md
- **replace-all-rename-substring-trap** — Global `replace_all` rewrites silently mangle paths and identifiers that contain the rename target as a substring; mitigations and audit recipe. Files: RESEARCH/replace-all-rename-substring-trap.md
- **research-doc-ingestion** — Lifecycle for ingesting user-dropped `.md` research docs from `wiki/inbox/` with interactive conflict resolution against read-only `wiki/RESEARCH/`. Files: ARCHITECTURE/research-doc-ingestion.md
- **research-md-triage** — Anchor for the audience decision (LLM-recall-primary), six imported templates plus five diagram triggers, and the rejection list (ADRs, runbooks, MOCs, frontmatter zoo). Files: ARCHITECTURE/research-md-triage.md
- **ripgrep-required-for-claude-code-tools** — Claude Code's Glob and Grep tools require `rg` on PATH; without it agents fall back to skill-body bash listings. Files: ARCHITECTURE/ripgrep-required-for-claude-code-tools.md
- **skill-bash-injection-dollar-n-expansion** — Claude Code's skill `!`-injection layer expands `$N` to empty strings before the shell sees them, even inside single-quoted awk scripts. Files: RESEARCH/skill-bash-injection-dollar-n-expansion.md
- **skill-bash-injection-isolation** — Claude Code skill-body bash injections do not share shell state across blocks; each block is an independent shell. Files: RESEARCH/skill-bash-injection-isolation.md
- **skill-naming-wiki-prefix** — User-facing wiki skills and slash commands take a `wiki-` prefix; `inbox-update` is the only exception (skill+agent name overlap is allowed). Files: ARCHITECTURE/skill-naming-wiki-prefix.md
- **stop-hook-self-heals-runtime-dir** — Stop hook script self-heals `.claude/inbox/` at startup so heartbeat and kill-switch writes succeed on fresh installs. Files: ARCHITECTURE/stop-hook-self-heals-runtime-dir.md
- **topic-index-as-recall-map** — Flat greppable bullet list mapping kebab-case topics to summaries and explicit file paths; the recall navigation map. Files: ARCHITECTURE/topic-index-as-recall-map.md
- **topic-index-h3-split** — Two H3 sections inside topic-index `## Content` — `### Modules` for orientation above `### Notes` for detail — combined cap ≤100. Files: ARCHITECTURE/topic-index-h3-split.md
- **trigger-7-module-cluster** — Rules.md §12 row 7 module-cluster shape detection requiring all four signals (S1 links, S2 keywords, S3 domains, S4 word band). Files: ARCHITECTURE/trigger-7-module-cluster.md
- **update-flow** — End-to-end versioning + upstream update mechanism anchored on `VERSION`, `CHANGELOG.md`, and `dist-manifest.txt` per-line `overwrite`/`keep` policy. Files: ARCHITECTURE/update-flow.md
- **version-1-1-0-release** — Release 1.1.0 ships the bare-to-piped wiki-link contract switch with deterministic transform recipe and post-sweep audit. Files: ARCHITECTURE/version-1-1-0-release.md
- **version-1-2-0-release** — Release 1.2.0 ships the MODULES orientation layer with Rules.md amendments, new template, deletion-test gate, and topic-index restructure. Files: ARCHITECTURE/version-1-2-0-release.md
- **wiki-curator-agent** — Curator subagent routing entries into filed notes per Rules.md, with D-19 RESEARCH/ branching and Step 2c specialized-template selection from `wiki/_templates/`. Files: FUNCTIONS/wiki-curator-agent.md
- **wiki-digest-skill** — `/wiki-digest` consolidates session inbox + research docs into filed notes via the curator, owning archive-before-write and source cleanup. Files: FUNCTIONS/wiki-digest-skill.md
- **wiki-install-skill** — `/wiki-install` bootstraps the auto-wiki system as five Bash blocks: scaffold via templates, jq hook merge, CLAUDE.md append, smoke tests, version stamp. Files: FUNCTIONS/wiki-install-skill.md
- **wiki-modules-skill** — Read-only `/wiki-modules` skill proposing MODULES notes for clusters lacking one and auditing existing modules deterministically. Files: FUNCTIONS/wiki-modules-skill.md
- **wiki-recall-subagent** — Read-only sub-agent that consults topic-index plus grep, applies a relevance filter, and returns a compact context payload. Files: ARCHITECTURE/wiki-recall-subagent.md
- **wiki-update-skill** — `/wiki-update` pulls upstream improvements: version compare, changelog slice, manifest-driven fetch, settings.json + CLAUDE.md re-merge from template, version stamp. Files: FUNCTIONS/wiki-update-skill.md

## Related Notes

- [[Rules|Wiki Rules]]
