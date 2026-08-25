---
name: wrap-up
description: |
  End-of-session wrap-up for memory persistence, self-improvement, and content capture.

  Triggers: wrap up, close session, end session, wrap things up,
  close out this task, session ending, context pressure 92%

  Use when: Ending a working session, context reaches 92%, or user
  invokes /wrap-up. Runs memory review, self-improvement analysis,
  and publishable content capture.
category: session
---

# Session Wrap-Up

Run three phases in order. Each phase is conversational and inline — no
separate documents. All phases auto-apply without asking; present a
consolidated report at the end.

---

## Phase 1: Remember It

Review what was learned during the session. Decide where each piece of
knowledge belongs in the memory hierarchy:

**Memory placement guide:**

| Destination | What goes here | Example |
|---|---|---|
| **Auto memory** (`~/.claude/projects/.../memory/`) | Debugging insights, patterns discovered, project quirks | "Drizzle migrations need renumbering when branches diverge" |
| **CLAUDE.md** | Permanent project rules, conventions, architecture decisions | "Always use Legend State observables, never Redux" |
| **`.claude/rules/`** | Topic-specific instructions scoped to file types via `paths:` frontmatter | Testing rules scoped to `tests/**` |
| **`CLAUDE.local.md`** | Personal WIP context, local URLs, sandbox credentials, current focus | Local dev server running on port 9090 |

**Decision framework:**
- Is it a permanent project convention? -> CLAUDE.md or `.claude/rules/`
- Is it scoped to specific file types? -> `.claude/rules/` with `paths:` frontmatter
- Is it a pattern or insight Claude discovered? -> Auto memory
- Is it personal/ephemeral context? -> `CLAUDE.local.md`
- Is it duplicating content from another file? -> Use `@import` instead

**Actions:**
1. Review the full conversation for learnings
2. Check existing memory files to avoid duplicates
3. Write or update the appropriate files
4. Report what was saved and where

---

## Phase 2: Review & Apply

Analyze the conversation for self-improvement findings. If the session was
short or routine with nothing notable, say "Nothing to improve" and proceed
to Phase 3.

**Auto-apply all actionable findings immediately** — do not ask for approval
on each one. Apply the changes, then present a summary of what was done.

**Finding categories:**
- **Skill gap** — Things Claude struggled with, got wrong, or needed multiple
  attempts
- **Friction** — Repeated manual steps, things user had to ask for explicitly
  that should have been automatic
- **Knowledge** — Facts about projects, preferences, or setup that Claude
  didn't know but should have
- **Automation** — Repetitive patterns that could become skills, hooks, or
  scripts

**Action types:**
- **CLAUDE.md** — Edit the relevant project or global CLAUDE.md
- **Rules** — Create or update a `.claude/rules/` file
- **Auto memory** — Save an insight for future sessions
- **Skill / Hook** — Document a new skill or hook spec for implementation
- **CLAUDE.local.md** — Create or update per-project local memory

Present a summary after applying, in two sections — applied items first,
then no-action items:

```
Findings (applied):

1. Skill gap: Cost estimates were wrong multiple times
   -> [CLAUDE.md] Added token counting reference table

2. Knowledge: Worker crashes on 429/400 instead of retrying
   -> [Rules] Added error-handling rules for worker

3. Automation: Checking service health after deploy is manual
   -> [Skill] Created post-deploy health check skill spec

---
No action needed:

4. Knowledge: Discovered X works this way
   Already documented in CLAUDE.md
```

---

## Phase 3: Publish It

Review the full conversation for material that could be published. Look for:

- Interesting technical solutions or debugging stories
- Community-relevant announcements or updates
- Educational content (how-tos, tips, lessons learned)
- Project milestones or feature launches

**If publishable material exists:**

Draft the article(s) for the appropriate platform and save to a drafts folder.
Present suggestions with the draft:

```
All wrap-up steps complete. I also found potential content to publish:

1. "Title of Post" — 1-2 sentence description of the content angle.
   Platform: Reddit
   Draft saved to: drafts/Title-Of-Post/Reddit.md
```

Wait for the user to respond. If they approve, post or prepare per platform.
If they decline, the drafts remain for later.

**If no publishable material exists:**

Say "Nothing worth publishing from this session."

**Scheduling considerations:**
- If the session produced multiple publishable items, do not post them all
  at once
- Space posts at least a few hours apart per platform
- If multiple posts are needed, post the most time-sensitive one now and
  present a schedule for the rest

---

## Final Step: Context Management

After all phases complete, ask:

> Would you like me to run /clear-context to hand off to a fresh session?

If yes, invoke `Skill(clear-context)`.
