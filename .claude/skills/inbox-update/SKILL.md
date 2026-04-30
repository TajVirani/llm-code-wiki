---
name: inbox-update
description: Update wiki/inbox/_session.md to reflect the current state of codebase artifacts after this turn. Add new entries, update changed ones, prune deleted ones. No-op if this turn produced no codebase artifact.
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
- `CATEGORY` is one of: `ARCHITECTURE`, `FUNCTIONS`, `RESEARCH`, `SELF`, `DIAGRAMS` (from `wiki/Rules.md §2`)
- `slug` is kebab-case matching the concept name
- `path` is the primary source file path, or `—` for non-file artifacts (decisions, session notes)
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

## Full-sweep trigger (D-02, hybrid pruning)

After the reconcile loop, check whether a full sweep is needed:

```
entry_count=$(grep -c "^@ " wiki/inbox/_session.md 2>/dev/null || echo 0)
```

Trigger a full sweep if EITHER:
- `entry_count` > 50, OR
- The user's most recent prompt invoked or mentioned `/digest` (pre-digest sweep)

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
