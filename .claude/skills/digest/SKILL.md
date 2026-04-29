---
name: digest
description: Process the rolling session inbox at wiki/inbox/_session.md (or a fixture path) into filed wiki notes per wiki/Rules.md. Archives the inbox before any note write, then forks into the wiki-curator subagent for routing. Run manually as a review checkpoint. Never modifies wiki/Rules.md.
disable-model-invocation: true
context: fork
agent: wiki-curator
allowed-tools: Read, Glob, Grep, Bash
argument-hint: "[optional inbox path; defaults to wiki/inbox/_session.md]"
---

# Digest the session inbox

The user invokes `/digest` after a stretch of work and wants the rolling inbox at `wiki/inbox/_session.md` (or a fixture, e.g. `tests/fixtures/_session-fixture.md` for Phase 1 acceptance) consolidated into properly-filed wiki notes per `wiki/Rules.md`.

This skill's body is the prompt the wiki-curator subagent receives when forked. The curator (defined at `.claude/agents/wiki-curator.md`) owns the routing, template, conflict-detection, split, and backlink-rewrite logic. This skill body owns the LIFECYCLE around the curator's work: archive-before-write, post-write link audit, and the empty-inbox no-op path.

## Resolve the inbox path

If `$ARGUMENTS` is non-empty, use it as the inbox path. Otherwise default to `wiki/inbox/_session.md`. Common values:
- `wiki/inbox/_session.md` (live session state, populated by Phase 2's inbox-update skill)
- `tests/fixtures/_session-fixture.md` (Phase 1 hand-authored fixture for acceptance testing)

## Step 1 — Confirm the inbox exists and inspect it

Read the resolved inbox path. If the file does not exist: print "No inbox found at <path>; nothing to digest." and exit. This is not an error.

Count the entry handle lines:
!`grep -cE '^@ (ARCHITECTURE|FUNCTIONS|RESEARCH|SELF|DIAGRAMS)::' "$INBOX_PATH" || echo 0`

If the count is zero, this digest is a no-op (DIGS-12 idempotence). Still archive the empty file in Step 2 (D-14: archive THEN write, with no exception). After archiving, print "Inbox is empty (0 entries); idempotent no-op." and exit.

## Step 2 — Archive the inbox BEFORE any note write (LIFE-02, LIFE-03, D-14)

Compute a timestamp: ISO-8601 with no colons (filesystem-safe). Example: `2026-04-28T1430-session.md`.

Create the archive directory if it does not exist:
!`mkdir -p wiki/inbox/_archive`

Copy the inbox to the archive:
!`cp "$INBOX_PATH" "wiki/inbox/_archive/$(date +%Y-%m-%dT%H%M)-session.md"`

Verify the copy succeeded by re-reading the archive file. If it failed, ABORT — do not proceed to writes. The crash-safety guarantee depends on the archive existing before any new note write.

Why this ordering: per LIFE-03, a curator crash mid-write would otherwise lose entries. Archive-first ensures every entry the curator was about to file is recoverable from the archive.

## Step 3 — Gather inputs for the curator

The curator needs: (a) the inbox content, (b) the existing wiki tree, (c) wiki/Rules.md (loaded by the wiki-rules skill the curator preloads — but provide it inline as a defense against `disableSkillShellExecution` interactions).

Inputs:

- Inbox content:
  !`cat "$INBOX_PATH"`

- Existing wiki tree (excluding inbox/ and _templates/):
  !`find wiki -type f -name '*.md' -not -path 'wiki/inbox/*' -not -path 'wiki/_templates/*' | sort`

- Wiki rules (authoritative — re-read fresh per Pitfall 12, NOT a stale skill-body mirror):
  !`cat wiki/Rules.md`

If `disableSkillShellExecution` is set on this Claude Code instance, the bash injections above produce empty strings. In that case, the curator must Read each input itself using its Read/Glob tools. The curator's prompt covers this fallback.

## Step 4 — Curator runs (this is where the fork happens)

Per the frontmatter `context: fork` + `agent: wiki-curator`, this skill body is delivered to a forked wiki-curator subagent in a fresh context. The curator follows its 8-step protocol (defined in `.claude/agents/wiki-curator.md`), producing:

1. A markdown plan listing every CREATE / EDIT / SPLIT / OVERRIDE / RULES-PROPOSAL row.
2. A validation result against Rules.md.
3. The applied changes (writes / edits to `wiki/<CATEGORY>/<slug>.md`).

Per D-03: approving the plan as a whole authorizes every row. The curator does NOT prompt for per-row confirmation.

Restated reminders to the curator (these are also in its system prompt — listed here for redundancy because skill bodies can be fork-injected and prompt context drift is real):

- **DIGS-08 + D-05 + D-06 + D-07 (splits + backlinks):** When splitting a note, grep `wiki/**/*.md` for inbound `[[OldTitle]]` and `[[OldTitle|alias]]` references. For EACH inbound link, choose the most relevant split target based on the surrounding sentence and the section heading the link sits under. Rewrite in place. Aliased links preserve the alias: `[[OldTitle|alias]]` becomes `[[NewTitle|alias]]`. Report as ONE summary line in the plan.
- **DIGS-09 + D-04 (existing-note conflict):** Same-concept detection by filename + title + tag overlap. NEVER use embeddings (anti-feature A10). 2+ matching signals → EDIT existing note (bump Last Updated). 0–1 → CREATE new.
- **DIGS-13 + D-16:** Curator NEVER writes to `wiki/Rules.md`. Rule-change suggestions surface as RULES-PROPOSAL rows for the user to apply manually.
- **Path safety:** Every write target must be under `wiki/`. Denylist: `wiki/Rules.md`, `wiki/_templates/**`. Reject any plan row violating this.

## Step 5 — Post-write link audit (DIGS-11, D-08)

After the curator finishes applying its plan, run a link-validation pass:

!`grep -roE '\[\[[^\]]+\]\]' wiki --include='*.md' | grep -v 'wiki/inbox/_archive' | sort -u`

For each unique `[[X]]` reference (or `[[X|alias]]` — strip the `|alias` part), verify a note exists with H1 matching X. Cheap heuristic: glob `wiki/**/*.md` and check whether any file's first non-frontmatter heading is `# X` (case-insensitive). Surface unresolved references in the digest summary as a section "Unresolved wiki-links".

Per D-08: this audit covers BOTH pre-existing dangling links AND any links the curator failed to rewrite during a split. It is the safety net.

## Step 6 — Emit the digest summary

Final output to the user:

```
## Digest Summary

**Inbox archived to:** wiki/inbox/_archive/<TIMESTAMP>-session.md
**Entries processed:** <N>
**Notes created:** <list>
**Notes edited:** <list>
**Splits performed:** <list with backlink rewrite counts>
**Overrides applied:** <list of FUNCTIONS→ARCHITECTURE etc. with reasons>
**Rule-change proposals (NOT applied — for user to consider):** <list>
**Unresolved wiki-links:** <list, or "none">
```

## Non-fork fallback (D-13)

If the user's environment has `CLAUDE_CODE_FORK_SUBAGENT=0` (or unset, depending on Claude Code version), `context: fork` falls back to inline execution and the fork isolation is lost. The procedure for invoking wiki-curator without forking is documented at `.claude/skills/digest/reference/non-fork-fallback.md`. The curator's protocol is identical; only the invocation path changes.

## Things this skill does NOT do

- Does NOT route, template, or detect duplicates itself — that's the curator's job.
- Does NOT modify `wiki/Rules.md` (DIGS-13).
- Does NOT auto-commit anything (anti-feature A11).
- Does NOT write to `wiki/inbox/_session.md` after digest — Phase 2's inbox-update skill owns that. This skill leaves the live inbox path untouched after archiving (the curator may truncate it as part of LIFE-02 lifecycle reset, but content writing belongs to Phase 2).
