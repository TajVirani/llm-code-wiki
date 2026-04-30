
**Summary**: Rules governing how notes are created, split, filed, and linked inside the project wiki.
**Tags**: #wiki #rules #conventions
**Created**: 2026-04-10T00:00:00+00:00
**Last Updated**: 2026-04-29T00:00:00+00:00

---

## Content

These rules govern every interaction with this wiki. When in doubt, follow them literally — do not invent new conventions on the fly.

### 1. Where things live

- **All `.md` files for this wiki belong inside `wiki/`.** Nothing outside this folder is part of the wiki.
- **`inbox/`** holds raw, unprocessed `.md` notes. Anything in `inbox/` is in a "to be filed" state and should not be linked from other notes until it has been converted and moved.
- **`_templates/note.md`** is the canonical template every filed note must follow. Do not modify the template casually — treat it like a schema.
- **Filed notes** live under one of the category folders below. Subfolders inside a category are allowed when a topic naturally groups (e.g. `RESEARCH/some-topic/`, `FUNCTIONS/api/`).

### 2. Category folders

| Folder          | What goes here                                                                                                          |
| --------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `ARCHITECTURE/` | System architecture, project structure, dev workflow, build/deploy, database setup, integration points, enforced rules. |
| `FUNCTIONS/`    | Reference docs for specific functions, endpoints, handlers, services. One concept per note.                             |
| `RESEARCH/`     | Domain math, formulas, algorithms, derivations, design notes that inform implementation but aren't implementation itself. |
| `SELF/`         | AI/agent-facing context: short memory snapshots, session summaries, important notes for future Claude sessions.         |
| `DIAGRAMS/`     | Mermaid / ASCII / PlantUML diagrams of flows, sequences, schemas, dependency graphs.                                    |

If a note doesn't obviously belong in one of these, propose a new top-level folder rather than guessing — and update this Rules file in the same change.

### 3. The template (every filed note)

Every filed note **must** start with the structure from `_templates/note.md`:

```markdown

**Summary**: One sentence describing this note.
**Tags**: #topic1 #topic2
**Created**: ISO-8601 timestamp
**Last Updated**: ISO-8601 timestamp

---

## Content

Main content here.

## Related Notes

- [[Other Note Title]]
```

Rules for filling it in:

- **Summary** is one sentence, ≤ 25 words. It must answer "what is this note about" without reading the body.
- **Tags** are 2–5 lowercase hashtags. Use existing tags before inventing new ones; keep them topical to your project (e.g. `#api`, `#auth`, `#database`, `#frontend`, `#architecture`).
- **Created** never changes after the note is first filed. **Last Updated** changes on every edit.
- **Related Notes** uses Obsidian wiki-link syntax `[[Note Title]]`. Use the *display title* of the linked note, not the filename.

### 4. Length and splitting

- **Hard target: 1,000 words per note.** Keep notes focused on a single concept.
- **If an inbox file exceeds 1,000 words, split it.** Each split becomes its own note with its own template, its own summary, and its own tags. The splits cross-link to each other under "Related Notes."
- **Prefer narrow over comprehensive.** A note titled "Auth Token Refresh Policy" is better than "Authentication" if both can stand alone.
- Code blocks and tables count toward the word target loosely — use judgment, but err on the side of splitting.

### 5. Filenames

- Filenames use **kebab-case** and end in `.md`: `auth-token-refresh.md`, not `Auth_Token_Refresh.md`.
- The filename should match the note's H1/title concept closely enough that it is greppable.
- When splitting one source file into many, prefix splits with the parent topic: `auth-base-flow.md`, `auth-token-refresh.md`, `auth-session-cookies.md`.

### 6. Inbox processing workflow

When converting an inbox file:

1. **Read** the source file in full.
2. **Decide**: single note, or split? Use the 1,000-word rule.
3. For each resulting note: **draft** the template — Summary, Tags, Created, Last Updated, Content, Related Notes.
4. **Rewrite the content** to be focused, self-contained, and free of inbox-era artifacts ("UPDATED", "NEW", session-specific dates) unless those artifacts carry meaning.
5. **Choose a destination folder** from the table in §2. Create subfolders only when justified.
6. **Write** the new file(s) under the destination folder.
7. **Delete** the original from `inbox/`.
8. **Add cross-links** to related existing notes via "Related Notes."

### 7. Linking

- Use Obsidian wiki-links `[[Note Title]]` for internal links.
- Use standard markdown links `[text](url)` for external links.
- Never hard-code paths to other wiki notes — Obsidian resolves titles automatically and paths break on rename.

### 8. Editing existing notes

- Bump the **Last Updated** field on every meaningful edit.
- If an edit substantially changes scope, consider whether the note should be split rather than expanded past 1,000 words.
- Never silently delete a filed note. If it's wrong, edit it. If it's obsolete, replace its body with a one-line pointer to the replacement note and tag it `#deprecated`.

### 9. The `_templates/` and `inbox/` folders are special

- `_templates/` is owned by the schema. Do not file notes there.
- `inbox/` is a staging area. Notes that live in `inbox/` are not part of the wiki proper and should not be linked from filed notes.

### 10. When these rules conflict with a request

If a user request appears to conflict with these rules, surface the conflict before acting. These rules govern how the wiki stays coherent — bending them silently breaks the system.

### 11. The `topic-index.md` file is auto-maintained

`wiki/topic-index.md` is the recall navigation map. It is rebuilt by the curator at the end of every `/digest` run (see §6 Step 8). One bullet per topic, format:

```
- **topic-name** — One-sentence summary (≤25 words). Files: PATH1, PATH2
```

Rules:

- Do not edit by hand — manual edits will be overwritten on the next digest.
- Topic name in **bold**, kebab-case.
- Summary describes what the topic *covers*, not what each individual file says.
- Files are comma-separated relative paths from `wiki/` root. No `[[wiki-link]]` syntax — explicit paths so grep returns precise hits for the recall agent.
- No nesting, no sub-bullets, no extra prose. Split a topic into two if it grows beyond one line.
- Alphabetized by topic name for stable diffs.
- Hard cap: ≤ 100 entries.

The recall agent (`wiki-recall`) reads this file as the entry point for every `/recall` and every UserPromptSubmit-triggered recall. Keeping it small and accurate is what makes recall fast.

## Related Notes

- [[Note Title]]
