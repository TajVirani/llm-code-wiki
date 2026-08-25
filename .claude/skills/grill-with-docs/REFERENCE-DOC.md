# The reference doc

A long interview outruns the terminal. By question five the user is scrolling back through prose recaps trying to remember which decisions are settled, what the current question actually depends on, and why you're asking it now. That is the failure this doc prevents: **a single page the user refreshes to see the whole state of the session, with the open question as the loudest thing on it.**

The doc is a mirror, not a memory. It never holds a decision that hasn't been made in conversation, and it never asks a question you haven't asked out loud.

## The file

```
temp/<task>-reference.html
```

One self-contained HTML file. `<task>` is a short kebab-case slug for the subject — `loom-data-reference`, `composition-node`, `parameter-role-binding`.

**Pick the slug once and never change it.** The user opens the file in a browser and leaves the tab there; every regeneration overwrites the same path so a refresh is the entire interaction. A renamed file is a broken tab. `temp/` is gitignored — this is a working surface, not a deliverable.

## Cadence

Create the doc **before you ask the second question**, and regenerate it **after every single question-and-answer exchange** thereafter — no exceptions for small answers, because a small answer still moves the open question, and the open question is the reason the page exists.

Create it immediately, mid-session, whenever the user signals they've lost the thread ("I don't follow", "what are you asking", "show me where we are").

## Regenerate with a fork subagent

Dispatch the `Agent` tool with `subagent_type: "fork"`.

A fork inherits the full conversation, so it already knows every answer given and needs no briefing on the substance — and the tokens spent rewriting a 40KB page land in the fork's context, not in the interview's. That is the whole reason this is affordable after every question.

**Dispatch it in the same turn you ask the next question.** The fork writes while the user reads the terminal. Never hold a question back waiting for a page to render — the interview is the product, the page is the instrument.

Brief the fork tightly, since it can see everything else itself:

- the exact file path to overwrite
- what the last answer settled, and which decision id it becomes
- what the new open question is, and the options and recommendation you're putting to the user
- anything the answer invalidated or superseded

Tell it to rewrite the file whole rather than patch it. Sections carry forward unchanged; a full rewrite keeps the numbering, the ledger, and the queue consistent without diff archaeology.

## Anatomy

Start from [TEMPLATE.html](./TEMPLATE.html) — it carries the palette, the light/dark handling, and one instance of every component below. Copy it whole on first generation, strip what the subject doesn't need, and keep the class names so the page looks identical across regenerations.

Top to bottom, in this order. Sections with nothing in them are omitted, not left empty.

**1 — Masthead.** Subject, and a one-line counter of where the session stands (`Q6 open · D1–D9 decided · 3 gaps`).

**2 — The open question.** The loudest element on the page, above the fold, unmissable. It carries four parts in this order, and the order matters — the user needs to understand the space before they can read a recommendation as anything but an instruction:

- **The question as a headline** — `Q6 — Which store do machine reads go through?` — plus a short paragraph on why it's being asked *now* and which earlier decision forced it.
- **The options, as cards.** Each names the concrete thing it does, in the system's own vocabulary — real table names, real file paths, real field names, real numbers. Each states its cost plainly, and states what it does **not** touch, because scope reassurance is most of what makes an option answerable.
- **Your recommendation**, with the reason, visually distinct from the options.
- **The literal ask** — the one sentence you want answered, phrased exactly as you phrased it in the terminal.

**3 — Just closed.** What the previous answer settled, in a block that reads as resolved. This is the user's confirmation that you heard them correctly, and it's where a misunderstanding gets caught one question after it happens instead of five.

**4 — Decision ledger.** Every decision so far, each with a stable id (`D1`, `D2`, …), the decision, and the reasoning that produced it. **Superseded decisions stay on the page, marked superseded, pointing at what replaced them** — a reversal is itself a finding, and deleting it makes the ledger lie about how the thinking moved.

**5 — Measured system facts.** The load-bearing facts the design rests on, each anchored to something checkable at the cited site: `file.ts:142`, a table name, a trace id, a row count, a measured latency. If a fact on this page can't be cited, it isn't a fact yet — it belongs in gaps.

**6 — Open gaps.** Known unknowns, contradictions between what the user said and what the code does, and anything flagged but not yet resolved.

**7 — Question queue.** What you intend to ask next, in dependency order, explicitly marked as not yet asked. This is what lets the user redirect the interview instead of riding it — they can see a question coming three steps out and tell you it's the wrong one, or answer it early.

Two components earn their place whenever the subject calls for them, and slot in after the facts:

- **A flow diagram**, in pure CSS, whenever the subject is a pipeline or a sequence — stages in a row, with each one badged as unchanged, modified, or new. Reading where a proposed node slots in beats three paragraphs describing it.
- **The user's own words, quoted verbatim**, wherever a decision turned on how they phrased something. It proves you took the constraint as given rather than paraphrasing it into something more convenient.

## Closing the session

When the last question is answered, the page doesn't get deleted — it becomes the record. Flip the top panel from open to closed (green, `.open-now.closed`), and replace the question with what the session produced: the deliverables and where they were written, the decision count, and a **completeness audit** — the gaps you went back and closed before declaring it done. The queue section becomes whatever remains genuinely open, or goes away.

That closed page is what the user keeps, and what a later session reads to pick the thread back up.

## Craft

- **One file.** No build step, no local asset references, no `<script src>` to a path that won't exist. Pure CSS for diagrams and layout. It has to survive being opened straight off disk. A CDN library is acceptable only when a genuine visualisation needs it — never for layout or type.
- **Legible at a glance.** Semantic colour (settled / open / superseded / blocked), monospace for every identifier, generous type for the open question and tight type for the ledger.
- **Never truncate.** Long ledgers and long fact tables go in scrolling containers; they don't get cut to "the top 10". Truncation on this page hides exactly the detail the user opened it to find.
- **Respect the terminal's theme** — dark by default, or handle both via `prefers-color-scheme`.

## Anti-patterns

- **The fork answering the question.** A fork inherits the conversation and can be tempted to write down the "obvious" answer. It regenerates a page; it never resolves a decision. Only the user closes a question.
- **Abstract options.** "Option A: a more flexible approach" is unanswerable and gets rejected. Options are made of the system's real nouns.
- **A page that leads the conversation.** Everything on it must already have been said out loud in the terminal. The doc is the transcript's index, not a parallel channel.
- **Blocking on the render.** If the fork is slow or fails, ask the question anyway and fold the missed update into the next regeneration.
