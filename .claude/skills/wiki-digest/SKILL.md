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

This skill's body IS the prompt the wiki-curator subagent receives when forked. With `context: fork` there is no separate "parent" runtime that resumes after the curator finishes — the curator IS the only executor. Every step below is something **you, the curator, perform**, in order. Steps 1–3 are input-gathering bash injections that have already been evaluated and embedded into your prompt by the time you read this; Steps 4–7 are your responsibilities (routing, applying writes, post-write audit, lifecycle cleanup, summary). Anywhere you see "skill body" below, read it as "you" — there is nobody else.

The curator's broader protocol (routing details, template enforcement, same-concept detection, split logic, backlink rewriting, RESEARCH/ write-protection branches, and Step 10 inbox reset) is defined at `.claude/agents/wiki-curator.md`. That agent definition and this skill body together describe the full digest behavior; in case of any wording overlap, the agent definition is authoritative.

## Resolve the session inbox path

The session inbox path resolves at runtime as `${ARGUMENTS:-wiki/inbox/_session.md}` — if `$ARGUMENTS` is non-empty (the user passed an alternative inbox path), use it; otherwise default to `wiki/inbox/_session.md`, the live session state populated by the inbox-update skill. Each bash injection below resolves this inline (Claude Code's `!` injections don't share shell state across blocks, so the variable must be set inside each block).

The research-doc discovery always scans `wiki/inbox/` regardless of `$ARGUMENTS` — research docs live alongside the canonical session inbox, not at fixture paths.

## Step 1 — Confirm sources exist and inspect them

### 1a. Session inbox

Read the resolved session inbox path. If the file does not exist: note "No session inbox found at <path>" and continue to 1b (a missing session inbox is not fatal — research docs may still be present).

Count the entry handle lines:
!`P="${ARGUMENTS:-wiki/inbox/_session.md}"; grep -cE '^@ (ARCHITECTURE|FUNCTIONS|RESEARCH|SELF|DIAGRAMS|MODULES)::' "$P" 2>/dev/null || echo 0`

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

(Trigger 7 signal pre-evaluation removed per ADR 0001. The curator no longer routes entries to `wiki/MODULES/`; `/wiki-modules` owns module-cluster detection and authoring. `@ MODULES::` session-inbox handles, if present, surface as `MODULES-VIA-DIGEST-DEPRECATED` plan rows in the curator's output — no signal computation needed.)

If `disableSkillShellExecution` is set on this Claude Code instance, the bash injections above produce empty strings. In that case, the curator must Read each input itself using its Read/Glob tools — including globbing `wiki/inbox/*.md` (excluding `_session.md` and underscore-prefixed files) to recover the research-doc list as a degraded path. The curator's prompt covers this fallback (W7 extension).

## Step 4 — Curator runs (this is where the fork happens)

Per the frontmatter `context: fork` + `agent: wiki-curator`, this skill body is delivered to a forked wiki-curator subagent in a fresh context. The curator follows its protocol (defined in `.claude/agents/wiki-curator.md`), producing:

1. A markdown plan listing every CREATE / EDIT / SPLIT / OVERRIDE / RULES-PROPOSAL / ALERT / CONFLICT-ON-RESEARCH / MODULES-VIA-DIGEST-DEPRECATED row, grouped by source (session inbox vs each research-doc filename).
2. A validation result against Rules.md.
3. Interactive resolution for any CONFLICT-ON-RESEARCH rows (Step 7a in the curator) — for each research-doc concept that collides with an existing `wiki/RESEARCH/` note, the curator surfaces both the existing content and the proposed content and waits for the user's instructions before any write to `wiki/RESEARCH/`.
4. The applied changes (writes / edits to `wiki/<CATEGORY>/<slug>.md`).
5. An updated `wiki/topic-index.md` — the curator's Step 9 rebuilds the recall navigation map for any topics affected by this digest's writes (new entries appended, deprecated paths removed, alphabetized bullets, `Last Updated` bumped).

Per D-03: approving the plan as a whole authorizes every CREATE / EDIT / SPLIT / OVERRIDE row. CONFLICT-ON-RESEARCH rows are explicitly NOT covered by plan-level approval — they require per-conflict instructions in Step 7a.

Restated reminders to the curator (these are also in its system prompt — listed here for redundancy because skill bodies can be fork-injected and prompt context drift is real):

- **Two source types:** the curator now handles BOTH handle-line entries from the session inbox AND free-prose research docs from `wiki/inbox/*.md` (excluding `_session.md` and underscore-prefixed files). Free-prose docs require the curator to derive {slug, title, category, tags, summary} per concept by applying Rules.md §6 (read in full → decide single or multi-concept → draft template).
- **DIGS-08 + D-05 + D-06 + D-07 (splits + backlinks):** When splitting a note, grep `wiki/**/*.md` for inbound links to the old slug — `[[old-slug|...]]` (the canonical piped form per Rules.md §7) plus any legacy bare `[[Old Title]]` references. For EACH inbound link, choose the most relevant split target based on the surrounding sentence and the section heading the link sits under. Rewrite in place to `[[new-slug|Display Title]]`. The display title (the part after `|`) is preserved verbatim if the original link had one (D-07); otherwise derive it from the new split's H1. Report as ONE summary line in the plan.
- **DIGS-09 + D-04 (existing-note conflict):** Same-concept detection by filename + title + tag overlap. NEVER use embeddings (anti-feature A10). 2+ matching signals → EDIT existing note (bump Last Updated). 0–1 → CREATE new.
- **D-19 RESEARCH/ write-protection branches by source:** Session-inbox handle-line entries that hit `wiki/RESEARCH/` still emit ALERT rows (read-only path preserved). Research-doc concepts that hit `wiki/RESEARCH/` emit CONFLICT-ON-RESEARCH rows and trigger Step 7a interactive resolution — any write to `wiki/RESEARCH/` is authorized by the user's typed instructions, never by automatic plan approval.
- **DIGS-13 + D-16:** Curator NEVER writes to `wiki/Rules.md`. Rule-change suggestions surface as RULES-PROPOSAL rows for the user to apply manually.
- **Path safety:** Every write target must be under `wiki/`. Denylist: `wiki/Rules.md`, `wiki/_templates/**`, `wiki/MODULES/**` (the orientation layer is owned by `/wiki-modules` per ADR 0001). Reject any plan row violating this.
- **MODULES handle deprecation (ADR 0001):** `@ MODULES::<slug>` session-inbox handles surface as `MODULES-VIA-DIGEST-DEPRECATED` plan rows. The curator never writes to `wiki/MODULES/`. Direct the user to `/wiki-modules` for orientation-layer authoring.

## Step 5 — Post-write link audit (DIGS-11, D-08)

After the curator finishes applying its plan, run a link-validation pass:

!`grep -roE '\[\[[^\]]+\]\]' wiki --include='*.md' | grep -v 'wiki/inbox/_archive' | sort -u`

For each unique `[[basename|Display Title]]` reference, take the part BEFORE `|` (the basename) and verify that `wiki/**/<basename>.md` exists — Obsidian resolves on filename, not H1, so the audit is a file-existence check (Rules.md §7). For any bare `[[X]]` references (no `|`), surface them as contract violations in the digest summary regardless of whether an H1 matches: bare links are out of contract under Rules.md §7 and will not resolve in Obsidian for kebab-case files. Surface both unresolved basenames and bare-link violations under a single section "Unresolved wiki-links".

Per D-08: this audit covers BOTH pre-existing dangling links AND any links the curator failed to rewrite during a split. It is the safety net.

## Step 6 — Cleanup (you, the curator, perform these)

After your writes from Step 4–5 succeeded and the post-write audit completed, clean up both source types yourself. **There is no separate runtime that performs these steps after you finish.** Skipping them leaves the next digest re-processing already-filed entries. Treat 6a and 6b as part of your protocol, not as a hand-off to anyone else.

### 6a. Reset the session inbox

Reset `wiki/inbox/_session.md` to the empty canonical template. The inbox is a derived view of work-not-yet-filed; once those entries are archived AND filed into `wiki/<CATEGORY>/` notes, they no longer belong in the live inbox. This duplicates curator agent Step 10 — both wordings describe the same action, performed by you.

Use the **Write** tool to overwrite `wiki/inbox/_session.md` with exactly:

```markdown
# Session Inbox

**Status**: live session state
**Purpose**: state-of-the-world mirror of what exists in the codebase this session. The codebase is ground truth; this file is a derived view.

---
```

This matches the canonical template that the `inbox-update` skill creates on first use (see its "Self-creation guard" section). Do not skip this step on success-path runs — the user has reported the missing reset as a bug.

### 6b. Delete consumed research-doc source files

For each research doc whose concepts were ALL successfully APPLIED in your plan, delete the source file at `wiki/inbox/<name>.md`. The Step 2b archive is the crash-safety net.

Apply per-doc:
- All concepts APPLIED (CREATE/EDIT/SPLIT/OVERRIDE rows applied successfully) → delete `wiki/inbox/<name>.md`.
- ANY unresolved CONFLICT-ON-RESEARCH (Step 7a "skip" or no instruction) → preserve the source file so the user can retry.
- Any apply error → preserve.

**Tooling note:** the curator's allowed-tools list (Read, Write, Edit, Glob, Grep) does not include Bash, so true file deletion via `rm` is not directly available to you. Use the **Write** tool to overwrite the file with a one-line tombstone marker so the next digest's discovery (which uses `find … -name '*.md' ! -name '_*'`) still picks it up but the user can see it was processed:

```
> Consumed by /wiki-digest at <ISO-8601>; archived at wiki/inbox/_archive/<TS>-research-<name>.md. Safe to delete manually.
```

Log each tombstone: `tombstoned wiki/inbox/<name>.md`; preserved-on-skip / preserved-on-error otherwise. Surface the tombstone list in the digest summary so the user can do a final `rm` themselves if they want a clean inbox.

(If your tools are extended in a future revision to include Bash, this step can be replaced with `rm` directly. The tombstone fallback is the current correct behavior.)

### 6c. Skip rule

**Skip BOTH 6a and 6b** ONLY if any earlier step (curator routing, validation, apply, audit) reported unrecoverable errors. The archives in Step 2 are the crash-safety net; the resets and tombstones here are normal-path lifecycle actions that depend on success. Skipping is loud — surface "Live inbox: preserved — Step <N> reported errors, see above" in the digest summary.

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
- Does NOT preserve research-doc source files unmodified in `wiki/inbox/<name>.md` after a successful digest of that file's concepts. Step 6b tombstones each fully-applied research doc with a one-line marker so the user can do a final `rm` themselves (the curator lacks Bash, so true deletion is left to the user). The Step 2b archive is the safety net for the original content. Files with unresolved CONFLICT-ON-RESEARCH rows or apply errors are preserved unchanged for retry.
- Does NOT reset the live inbox or tombstone research-doc sources if any earlier step reported unrecoverable errors. In failure cases both source types are preserved so the user can retry; the Step 2 archives are always the crash-safety net.
- Does NOT process files matching `_*` (underscore-prefixed) at `wiki/inbox/` — these are reserved (`_session.md`, `_archive/`, etc.) and are skipped during research-doc discovery.
