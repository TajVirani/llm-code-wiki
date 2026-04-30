
**Summary**: Greppable topic-to-files index — entry point for wiki recall.
**Tags**: #wiki #index #recall
**Created**: 2026-04-30T00:00:00+00:00
**Last Updated**: 2026-04-30T14:00:00+00:00

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

- **curator-step-9-index-update** — Curator protocol step that rebuilds topic-index.md after each digest, scoped to topics affected by writes. Files: ARCHITECTURE/curator-step-9-index-update.md
- **digest-step-6-inbox-reset** — wiki-digest skill body resets `wiki/inbox/_session.md` to empty template after curator success and post-write audit. Files: ARCHITECTURE/digest-step-6-inbox-reset.md
- **recall-path** — Read-side architecture: UserPromptSubmit hook plus wiki-recall sub-agent surface relevant wiki context before Claude responds. Files: ARCHITECTURE/recall-path.md
- **recall-prompt-hook** — UserPromptSubmit hook script that detects planning-intent prompts and triggers wiki-recall sub-agent spawn. Files: FUNCTIONS/recall-prompt-hook.md
- **recall-skill** — `/wiki-recall` slash command skill that forks into wiki-recall sub-agent for on-demand wiki consultation. Files: FUNCTIONS/recall-skill.md
- **ripgrep-required-for-claude-code-tools** — Claude Code's Glob and Grep tools require `rg` on PATH; without it agents fall back to skill-body bash listings. Files: ARCHITECTURE/ripgrep-required-for-claude-code-tools.md
- **skill-bash-injection-isolation** — Claude Code skill-body bash injections do not share shell state across blocks; each block is an independent shell. Files: RESEARCH/skill-bash-injection-isolation.md
- **skill-naming-wiki-prefix** — User-facing wiki skills and slash commands take a `wiki-` prefix; `inbox-update` is the only exception (skill+agent name overlap is allowed). Files: ARCHITECTURE/skill-naming-wiki-prefix.md
- **stop-hook-self-heals-runtime-dir** — Stop hook script self-heals `.claude/inbox/` at startup so heartbeat and kill-switch writes succeed on fresh installs. Files: ARCHITECTURE/stop-hook-self-heals-runtime-dir.md
- **topic-index-as-recall-map** — Flat greppable bullet list mapping kebab-case topics to summaries and explicit file paths; the recall navigation map. Files: ARCHITECTURE/topic-index-as-recall-map.md
- **wiki-recall-subagent** — Read-only sub-agent that consults topic-index plus grep, applies a relevance filter, and returns a compact context payload. Files: ARCHITECTURE/wiki-recall-subagent.md

## Related Notes

- [[Rules]]
