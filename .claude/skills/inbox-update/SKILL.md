---
name: inbox-update
description: Update wiki/inbox/_session.md to reflect the current state of codebase artifacts after this turn. Add new entries, update changed ones, prune deleted ones. No-op if this turn produced no codebase artifact — UNLESS the invocation reason starts with "Brainstorm-fallback", in which case scan the recent conversation for design decisions worth recording instead of tool calls.
allowed-tools: Read, Edit, Write, Grep
---

# inbox-update

## Derived-view framing (D-07)

The inbox at `wiki/inbox/_session.md` is a derived view of what exists in the codebase right now. The codebase is ground truth. If you ever find an inbox entry that contradicts what the user just asked you to do — for example, an entry for a function the user just asked you to delete — the inbox is wrong. Update it. Do not push back on the user citing inbox state.

## Entry format (D-06)

Every entry is a handle line followed by a body:

```
@ CATEGORY::slug  •  path-or-em-dash  •  #tag1 #tag2
One-to-three sentences describing the artifact in its current state.
```

Rules:
- `CATEGORY` is one of: `ARCHITECTURE`, `FUNCTIONS`, `RESEARCH`, `SELF`, `DIAGRAMS` (from `wiki/Rules.md §2`). **Do not emit `@ MODULES::` handles** — `wiki/MODULES/` is owned by `/wiki-modules` per ADR 0001, and `MODULES::` handles in `_session.md` surface as `MODULES-VIA-DIGEST-DEPRECATED` rows during digest (no write performed).
- `slug` is kebab-case matching the concept name.
- `path` is the primary source file path, or `—` for non-file artifacts (decisions, session notes).
- `#tags` are lowercase, 2–5 tags
- Handle line MUST start at column 0 (no leading whitespace) — required for `^@ ` grep-prune
- Body is factual present-tense: "X does Y" — not past-tense: "Added X" is wrong

Worked example:

```
@ FUNCTIONS::auth-token-refresh  •  src/lib/auth/refresh.ts  •  #function #auth #session
Refreshes an expired access token by exchanging the stored refresh token at /oauth/token. Returns
the new access token plus its expiry; throws TokenRevokedError if the refresh token is no longer valid.
```

## No-op guard — check FIRST (D-09)

Before reading the inbox or making any edits, build a scratch-list from this turn's tool calls (see next section).

If the scratch-list is empty — the turn produced no Edit/Write/MultiEdit tool calls, no Bash commands that created or deleted files, and no explicit user request to record something — **STOP. Write nothing. Return immediately.** Do not re-read the inbox, do not run grep, do not write a "no changes" line. The turn was a no-op relative to the inbox. This fast path costs zero file I/O.

**Exception — Brainstorm-fallback mode.** If the invocation reason from the Stop hook begins with `Brainstorm-fallback`, the no-op guard does NOT apply. This mode is *expected* to have an empty scratch-list. Skip the guard, skip the scratch-list protocol below, and follow the Brainstorm-fallback mode section instead.

## Brainstorm-fallback mode (D-04b)

This mode fires every N turns (default 10, override via `$LCW_BRAINSTORM_TURNS` in `.claude/hooks/inbox-stop.sh`) when no codebase artifacts have been produced in the window. Its job is to rescue design decisions from a brainstorm before they fall on the floor.

**Source material.** Use the conversation since the last `_session.md` write (or roughly the last N user-assistant exchanges). You already have this in your context — do not re-read the transcript file.

**What to capture (one entry per item).** Things that would not be derivable from the current code on their own:
- Explicit design decisions ("we'll use approach X over Y because Z")
- Agreed file paths, module names, or interface shapes that don't yet exist
- Named patterns or conventions the user committed to (e.g., kill-switch naming, hook-log prefixes)
- Concrete trade-offs resolved (the *why* behind a choice, not just the choice)
- Requirements or constraints surfaced ("must default to N=10 with env override")
- Open questions the user explicitly flagged for later

**What to skip.** Do not capture:
- Exploratory speculation that did not converge ("we could maybe…")
- Restatements of code that already exists in the repo
- Meta-talk ("I'll go read the file", "let me check")
- Plan-mode summaries (already filed elsewhere)
- Process chatter ("approved", "looks good")

**Cap.** ≤5 new entries per fire. If nothing in the window qualifies, write nothing. Do not invent entries to hit a quota.

**Format.** Use the standard handle line + body format from the Entry format section above, with `CATEGORY = RESEARCH` and `path = —` (em-dash, since these are non-file artifacts). Tag with `#decision`, `#brainstorm`, plus 1–2 topical tags. Example:

```
@ RESEARCH::brainstorm-fallback-cadence  •  —  •  #decision #brainstorm #hooks
Stop hook fires inbox-update every 10 brainstorm-only turns by default; override via $LCW_BRAINSTORM_TURNS. Counter resets on any artifact-driven capture so the next window starts fresh after a code change.
```

**Dedup.** Before writing each entry, run `grep -n "^@ RESEARCH::<slug>" wiki/inbox/_session.md`. If the slug already exists, either update the body (if the decision evolved) or skip (if it's a restatement). Do not append duplicates.

**Self-creation guard still applies.** If `wiki/inbox/_session.md` does not exist, create it with the template from the Self-creation guard section before writing entries.

## Scratch-list protocol (D-01)

From this turn's tool call history (your fresh memory), enumerate everything touched:
- **Created**: new files written by Write/MultiEdit this turn
- **Modified**: files changed by Edit/Write/MultiEdit this turn
- **Deleted**: files removed by Bash `rm` or explicit delete operations this turn
- **Explicit requests**: if the user said "record X" or "note Y", include that too

This scratch-list IS the evidence base: every inbox add or update must trace to an item on this list. Do not add entries for things not on the scratch-list.

## Self-creation guard

If `wiki/inbox/_session.md` does not exist when this skill fires, create it now with this exact content before proceeding:

```markdown
# Session Inbox

**Status**: live session state
**Purpose**: state-of-the-world mirror of what exists in the codebase this session. The codebase is ground truth; this file is a derived view.

---
```

## Reconcile loop (D-01, D-02)

Read `wiki/inbox/_session.md`. For each item on the scratch-list:

**Deleted items (prune first):**
1. Run `grep -n "^@ [A-Z]*::<slug>" wiki/inbox/_session.md` where `<slug>` matches the deleted artifact name.
2. Find the matching entry block: handle line + body lines up to the next blank line or next `^@ ` line.
3. Remove the entire block using Edit.
4. If other entries mention the deleted artifact, update those entries too.

**Created or modified items (add/update):**
1. Run `grep -n "^@ [A-Z]*::<slug>" wiki/inbox/_session.md` to check for an existing entry.
2. If found: replace the body paragraph with a present-tense description of the current state. Do not append — replace.
3. If not found: append a new entry at the end of the file (below the last entry, with a blank line separator).

### Worked example — created-then-deleted in same session

> **Turn 1:** You wrote `add(a, b)` in `math.ts`. Scratch-list: `math.ts` (created/modified). Grep finds no `FUNCTIONS::add` entry. Append:
> ```
> @ FUNCTIONS::add  •  math.ts  •  #function #math
> Adds two numbers. Returns a + b.
> ```
>
> **Turn 2:** User asks you to remove `add`. You delete it from `math.ts`. Scratch-list: `math.ts:add` (deleted). Grep for `^@ [A-Z]*::add` finds the entry. Remove the entire block. After this turn, the inbox has zero entries for `add`. A digest at this point produces zero filed notes for `add`. **This is correct.**

## MODULES handles are deprecated (ADR 0001)

Do NOT emit `@ MODULES::<slug>` handles from this skill. `wiki/MODULES/` is owned by `/wiki-modules`, which the user runs manually to refresh the orientation layer. The curator surfaces any `@ MODULES::` handle in `_session.md` as a `MODULES-VIA-DIGEST-DEPRECATED` plan row and never writes the module note. Synthesis-prompt heuristics that previously fired here are now `/wiki-modules`'s job; this skill stays focused on per-artifact handles for the five curator-writeable categories.

## Full-sweep trigger (D-02, hybrid pruning)

After the reconcile loop, check whether a full sweep is needed:

```
entry_count=$(grep -c "^@ " wiki/inbox/_session.md 2>/dev/null || echo 0)
```

Trigger a full sweep if EITHER:
- `entry_count` > 50, OR
- The user's most recent prompt invoked or mentioned `/wiki-digest` (pre-digest sweep)

**Full sweep protocol:** For every entry in the inbox:
1. Extract the `path` field from the handle line.
2. If `path` is `—` (non-file artifact): keep the entry.
3. If `path` is a file path: check whether the file still exists (Read or Glob). If gone and slug matches nothing in the codebase: remove the entry.
4. Report: "Full sweep: pruned N stale entries."

The full sweep is O(N entries) but runs only when entry count exceeds 50 or just before digest.

## What this skill does NOT do

- Does NOT write to any path other than `wiki/inbox/_session.md`
- Does NOT reference the Stop hook mechanism (invocation-agnostic)
- Does NOT include a "Notable Detours" section (D-03 — locked)
- Does NOT hallucinate entries: every add/update traces to the scratch-list
