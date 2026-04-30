---
name: wiki-digest
description: Process the rolling session inbox at wiki/inbox/_session.md (or a fixture path) AND any user-dropped research-doc .md files in wiki/inbox/ into filed wiki notes per wiki/Rules.md. Archives every consumed source before any note write, then forks into the wiki-curator subagent for routing. Run manually as a review checkpoint. Never modifies wiki/Rules.md.
disable-model-invocation: true
context: fork
agent: wiki-curator
allowed-tools: Read, Glob, Grep, Bash
argument-hint: "[optional inbox path; defaults to wiki/inbox/_session.md]"
---

# Digest the session inbox + any research docs

The user invokes `/wiki-digest` after a stretch of work and wants two source types consolidated into properly-filed wiki notes per `wiki/Rules.md`:

1. **The session inbox** at `wiki/inbox/_session.md` (or an alternative inbox path passed as an argument) — handle-line entries (`@ CATEGORY::slug …`) populated by the inbox-update skill.
2. **Research docs** — any `.md` file the user has dropped into the root of `wiki/inbox/` other than `_session.md` and any underscore-prefixed file. These are free-prose markdown documents (research notes, design docs, external references) the user wants treated as source-of-truth and decomposed into filed wiki notes.

This skill's body is the prompt the wiki-curator subagent receives when forked. The curator (defined at `.claude/agents/wiki-curator.md`) owns the routing, template, conflict-detection, split, and backlink-rewrite logic for BOTH source types. This skill body owns the LIFECYCLE around the curator's work: archive-before-write (covers both sources), post-write link audit, source-file deletion on success, and the empty-inbox no-op path.

## Resolve the session inbox path

The session inbox path resolves at runtime as `${ARGUMENTS:-wiki/inbox/_session.md}` — if `$ARGUMENTS` is non-empty (the user passed an alternative inbox path), use it; otherwise default to `wiki/inbox/_session.md`, the live session state populated by the inbox-update skill. Each bash injection below resolves this inline (Claude Code's `!` injections don't share shell state across blocks, so the variable must be set inside each block).

The research-doc discovery always scans `wiki/inbox/` regardless of `$ARGUMENTS` — research docs live alongside the canonical session inbox, not at fixture paths.

## Step 1 — Confirm sources exist and inspect them

### 1a. Session inbox

Read the resolved session inbox path. If the file does not exist: note "No session inbox found at <path>" and continue to 1b (a missing session inbox is not fatal — research docs may still be present).

Count the entry handle lines:
!`P="${ARGUMENTS:-wiki/inbox/_session.md}"; grep -cE '^@ (ARCHITECTURE|FUNCTIONS|RESEARCH|SELF|DIAGRAMS)::' "$P" 2>/dev/null || echo 0`

### 1b. Research docs

List `.md` files in the root of `wiki/inbox/` excluding `_session.md` and any underscore-prefixed file (so `_archive/`, `_session.md`, `_session.md.bak` etc. are skipped):
!`find wiki/inbox -maxdepth 1 -type f -name '*.md' ! -name '_*' 2>/dev/null | sort`

Count them:
!`find wiki/inbox -maxdepth 1 -type f -name '*.md' ! -name '_*' 2>/dev/null | wc -l`

### 1c. Combined no-op guard

If BOTH the session-entry count is zero AND the research-doc count is zero, this digest is a no-op (DIGS-12 idempotence). Still archive the empty session file in Step 2 (D-14: archive THEN write, with no exception). After archiving, print "Both sources empty (0 session entries, 0 research docs); idempotent no-op." and exit.

If either source has content, proceed.

## Step 2 — Archive every source BEFORE any note write (LIFE-02, LIFE-03, D-14)

Compute a single shared timestamp for this digest run: ISO-8601 with no colons (filesystem-safe). Example: `2026-04-28T1430`. Every archived source from this run shares this timestamp prefix so they group together in `wiki/inbox/_archive/` listings.

Create the archive directory if it does not exist:
!`mkdir -p wiki/inbox/_archive`

### 2a. Archive the session inbox

Copy the session inbox to `wiki/inbox/_archive/<TS>-session.md`:
!`P="${ARGUMENTS:-wiki/inbox/_session.md}"; TS=$(date +%Y-%m-%dT%H%M); cp "$P" "wiki/inbox/_archive/${TS}-session.md" && echo "archived session inbox to wiki/inbox/_archive/${TS}-session.md"`

### 2b. Archive each research doc

For each research doc discovered in Step 1b, copy it to `wiki/inbox/_archive/<TS>-research-<filename>`:
!`TS=$(date +%Y-%m-%dT%H%M); for f in $(find wiki/inbox -maxdepth 1 -type f -name '*.md' ! -name '_*' 2>/dev/null); do base=$(basename "$f"); cp "$f" "wiki/inbox/_archive/${TS}-research-${base}" && echo "archived $f to wiki/inbox/_archive/${TS}-research-${base}"; done`

### 2c. Verify

Re-read each archive file (session + every research doc copy) to confirm the writes succeeded. If any verification fails, ABORT — do not proceed to writes. The crash-safety guarantee depends on every source being archived before any new note write.

Why this ordering: per LIFE-03, a curator crash mid-write would otherwise lose entries. Archive-first ensures every entry/concept the curator was about to file is recoverable from the archive — even when sources are spread across `_session.md` and N research docs.

## Step 3 — Gather inputs for the curator

The curator needs: (a) the session inbox content, (b) the research-doc payload (one delimited block per discovered file), (c) the existing wiki tree, (d) wiki/Rules.md (loaded by the wiki-rules skill the curator preloads — but provide it inline as a defense against `disableSkillShellExecution` interactions).

Inputs:

- Session inbox content:
  !`P="${ARGUMENTS:-wiki/inbox/_session.md}"; cat "$P" 2>/dev/null`

- Research-doc payload — for each `.md` file in `wiki/inbox/` (excluding `_session.md` and underscore-prefixed files), emit a delimited block the curator can iterate by:
  !`for f in $(find wiki/inbox -maxdepth 1 -type f -name '*.md' ! -name '_*' 2>/dev/null | sort); do echo "=== RESEARCH-DOC: $f ==="; cat "$f"; echo; echo "=== END RESEARCH-DOC ==="; echo; done`

- Existing wiki tree (excluding inbox/ and _templates/):
  !`find wiki -type f -name '*.md' -not -path 'wiki/inbox/*' -not -path 'wiki/_templates/*' | sort`

- Wiki rules (authoritative — re-read fresh per Pitfall 12, NOT a stale skill-body mirror):
  !`cat wiki/Rules.md`

If `disableSkillShellExecution` is set on this Claude Code instance, the bash injections above produce empty strings. In that case, the curator must Read each input itself using its Read/Glob tools — including globbing `wiki/inbox/*.md` (excluding `_session.md` and underscore-prefixed files) to recover the research-doc list. The curator's prompt covers this fallback (W7 extension).

## Step 4 — Curator runs (this is where the fork happens)

Per the frontmatter `context: fork` + `agent: wiki-curator`, this skill body is delivered to a forked wiki-curator subagent in a fresh context. The curator follows its protocol (defined in `.claude/agents/wiki-curator.md`), producing:

1. A markdown plan listing every CREATE / EDIT / SPLIT / OVERRIDE / RULES-PROPOSAL / ALERT / CONFLICT-ON-RESEARCH row, grouped by source (session inbox vs each research-doc filename).
2. A validation result against Rules.md.
3. Interactive resolution for any CONFLICT-ON-RESEARCH rows (Step 7a in the curator) — for each research-doc concept that collides with an existing `wiki/RESEARCH/` note, the curator surfaces both the existing content and the proposed content and waits for the user's instructions before any write to `wiki/RESEARCH/`.
4. The applied changes (writes / edits to `wiki/<CATEGORY>/<slug>.md`).
5. An updated `wiki/topic-index.md` — the curator's Step 9 rebuilds the recall navigation map for any topics affected by this digest's writes (new entries appended, deprecated paths removed, alphabetized bullets, `Last Updated` bumped).

Per D-03: approving the plan as a whole authorizes every CREATE / EDIT / SPLIT / OVERRIDE row. CONFLICT-ON-RESEARCH rows are explicitly NOT covered by plan-level approval — they require per-conflict instructions in Step 7a.

Restated reminders to the curator (these are also in its system prompt — listed here for redundancy because skill bodies can be fork-injected and prompt context drift is real):

- **Two source types:** the curator now handles BOTH handle-line entries from the session inbox AND free-prose research docs from `wiki/inbox/*.md` (excluding `_session.md` and underscore-prefixed files). Free-prose docs require the curator to derive {slug, title, category, tags, summary} per concept by applying Rules.md §6 (read in full → decide single or multi-concept → draft template).
- **DIGS-08 + D-05 + D-06 + D-07 (splits + backlinks):** When splitting a note, grep `wiki/**/*.md` for inbound `[[OldTitle]]` and `[[OldTitle|alias]]` references. For EACH inbound link, choose the most relevant split target based on the surrounding sentence and the section heading the link sits under. Rewrite in place. Aliased links preserve the alias: `[[OldTitle|alias]]` becomes `[[NewTitle|alias]]`. Report as ONE summary line in the plan.
- **DIGS-09 + D-04 (existing-note conflict):** Same-concept detection by filename + title + tag overlap. NEVER use embeddings (anti-feature A10). 2+ matching signals → EDIT existing note (bump Last Updated). 0–1 → CREATE new.
- **D-19 RESEARCH/ write-protection branches by source:** Session-inbox handle-line entries that hit `wiki/RESEARCH/` still emit ALERT rows (read-only path preserved). Research-doc concepts that hit `wiki/RESEARCH/` emit CONFLICT-ON-RESEARCH rows and trigger Step 7a interactive resolution — any write to `wiki/RESEARCH/` is authorized by the user's typed instructions, never by automatic plan approval.
- **DIGS-13 + D-16:** Curator NEVER writes to `wiki/Rules.md`. Rule-change suggestions surface as RULES-PROPOSAL rows for the user to apply manually.
- **Path safety:** Every write target must be under `wiki/`. Denylist: `wiki/Rules.md`, `wiki/_templates/**`. Reject any plan row violating this.

## Step 5 — Post-write link audit (DIGS-11, D-08)

After the curator finishes applying its plan, run a link-validation pass:

!`grep -roE '\[\[[^\]]+\]\]' wiki --include='*.md' | grep -v 'wiki/inbox/_archive' | sort -u`

For each unique `[[X]]` reference (or `[[X|alias]]` — strip the `|alias` part), verify a note exists with H1 matching X. Cheap heuristic: glob `wiki/**/*.md` and check whether any file's first non-frontmatter heading is `# X` (case-insensitive). Surface unresolved references in the digest summary as a section "Unresolved wiki-links".

Per D-08: this audit covers BOTH pre-existing dangling links AND any links the curator failed to rewrite during a split. It is the safety net.

## Step 6 — Reset the live inbox and delete consumed research docs

After the curator's writes succeeded and the post-write audit completed, clean up both source types.

### 6a. Reset the session inbox

Reset `wiki/inbox/_session.md` to the empty canonical template. The inbox is a derived view of work-not-yet-filed; once those entries are archived AND filed into `wiki/<CATEGORY>/` notes, they no longer belong in the live inbox. Without this reset, the next session's `inbox-update` would see stale entries that already correspond to filed notes, and the next `/wiki-digest` would re-process them (idempotent via same-concept detection, but wasteful and noisy).

Use Write to overwrite `wiki/inbox/_session.md` with exactly:

```markdown
# Session Inbox

**Status**: live session state
**Purpose**: state-of-the-world mirror of what exists in the codebase this session. The codebase is ground truth; this file is a derived view.

---
```

This matches the canonical template that the `inbox-update` skill creates on first use (see its "Self-creation guard" section).

### 6b. Delete consumed research-doc source files

For each research doc the curator surfaced in its plan, delete the source file at `wiki/inbox/<name>.md` ONLY IF every concept derived from that file was successfully applied. The Step 2 archive is the crash-safety net.

Specifically:
- A research doc whose concepts all resulted in CREATE / EDIT / SPLIT / OVERRIDE rows that were applied → `rm wiki/inbox/<name>.md`.
- A research doc that produced ANY unresolved CONFLICT-ON-RESEARCH (user picked "skip" in Step 7a, or did not provide instructions) → DO NOT delete the source file. The user may want to retry with different instructions; the unresolved concept must remain reachable.
- A research doc whose plan rows failed validation or apply → DO NOT delete the source file.

Use the Bash tool to perform deletes after reading the curator's plan-application result. Log each delete: `rm wiki/inbox/<name>.md` succeeded; preserved-on-skip / preserved-on-error otherwise.

### 6c. Skip rule

**Skip BOTH 6a and 6b** ONLY if the curator aborted mid-run or the post-write audit surfaced unrecoverable errors — in that case the user needs both sources preserved to retry. The archives in Step 2 are the crash-safety net; the resets and deletes here are normal-path lifecycle actions that depend on success.

## Step 7 — Emit the digest summary

Final output to the user:

```
## Digest Summary

**Session inbox archived to:** wiki/inbox/_archive/<TS>-session.md
**Session entries processed:** <N>

**Research docs consumed:** <count>
<for each research doc>
- wiki/inbox/<name>.md → wiki/inbox/_archive/<TS>-research-<name>.md
  - Derived notes: <list of CREATE/EDIT/SPLIT slugs>
  - Source file: deleted (or: preserved — unresolved CONFLICT-ON-RESEARCH / preserved — apply error)
</for>

**Notes created:** <list, grouped by source>
**Notes edited:** <list, grouped by source>
**Splits performed:** <list with backlink rewrite counts>
**Overrides applied:** <list of FUNCTIONS→ARCHITECTURE etc. with reasons>
**ALERT (session-inbox vs read-only RESEARCH/, no write):** <list, or "none">
**CONFLICT-ON-RESEARCH (research-doc vs read-only RESEARCH/, resolution applied):** <list with chosen resolution per row, or "none">
**Rule-change proposals (NOT applied — for user to consider):** <list>
**Unresolved wiki-links:** <list, or "none">
**Topic-index updated:** <list of topic bullets added/edited, or "no change">
**Live session inbox:** reset to empty template (or: "preserved — curator/audit reported errors, see above")
```

## Non-fork fallback (D-13)

If the user's environment has `CLAUDE_CODE_FORK_SUBAGENT=0` (or unset, depending on Claude Code version), `context: fork` falls back to inline execution and the fork isolation is lost. The procedure for invoking wiki-curator without forking is documented at `.claude/skills/wiki-digest/reference/non-fork-fallback.md`. The curator's protocol is identical; only the invocation path changes.

## Things this skill does NOT do

- Does NOT route, template, or detect duplicates itself — that's the curator's job.
- Does NOT modify `wiki/Rules.md` (DIGS-13).
- Does NOT auto-commit anything (anti-feature A11).
- Does NOT preserve filed entries in `wiki/inbox/_session.md` after a successful digest. Step 6a resets the live inbox to its empty template once the curator's writes succeeded and the post-write audit passed. Subsequent edits/writes to `_session.md` belong to the `inbox-update` skill (the lifecycle is: inbox-update appends → /wiki-digest archives + files + resets → inbox-update appends fresh entries from the next turn).
- Does NOT preserve research-doc source files in `wiki/inbox/<name>.md` after a successful digest of that file's concepts. Step 6b deletes each fully-applied research doc from the inbox root (the Step 2b archive is the safety net). Files with unresolved CONFLICT-ON-RESEARCH rows or apply errors are preserved for retry.
- Does NOT reset the live inbox or delete research-doc sources if the curator aborted mid-run or the audit surfaced unrecoverable errors. In failure cases both source types are preserved so the user can retry; the Step 2 archives are always the crash-safety net.
- Does NOT process files matching `_*` (underscore-prefixed) at `wiki/inbox/` — these are reserved (`_session.md`, `_archive/`, etc.) and are skipped during research-doc discovery.
