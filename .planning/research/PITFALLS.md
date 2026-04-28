# Pitfalls Research

**Domain:** Claude Code hooks + auto-maintained codebase wiki (skill + Stop hook + digest sub-agent)
**Researched:** 2026-04-28
**Confidence:** HIGH for hook mechanics (verified against official Claude Code hooks reference and known issues); MEDIUM for inbox-side and digest-side pitfalls (extrapolated from documented LLM/auto-doc failure modes plus Claude Code subagent semantics).

This document focuses exclusively on pitfalls specific to this domain: a Stop-hook-driven inbox skill that maintains a state-of-the-world doc which a digest sub-agent later files into an Obsidian-style wiki per the locked `wiki/Rules.md` contract. Generic "LLM hallucinates" advice is excluded unless it has a concrete, project-specific manifestation.

---

## Critical Pitfalls

### Pitfall 1: Stop hook fires for sub-agents and lets the digest agent thrash the inbox

**What goes wrong:**
The user runs `/gsd-digest` (or whatever digest invocation is shipped). The digest sub-agent is spawned via the Task tool. It reads inbox entries, writes them to `wiki/<category>/`, deletes the entries from inbox. When the sub-agent finishes, the Stop hook fires inside the sub-agent's turn boundary and injects "update the inbox to reflect state-of-the-world" — into a sub-agent that has just deliberately emptied the inbox. The sub-agent dutifully adds entries describing what it just did ("Filed inbox entry for `add(a,b)`"), undoing the digest. Worse, if the parent session's Stop hook fires when the sub-agent returns, the parent re-populates entries from sub-agent output it has no firsthand knowledge of.

**Why it happens:**
Per the official Claude Code hooks reference, `SubagentStop` is a separate event from `Stop` and fires when a subagent finishes. However, configuration ergonomics make it easy to assume `Stop` covers everything, and some community documentation conflates the two ("Stop hooks are automatically converted to SubagentStop"). In settings.json, `Stop` does **not** support matchers — it always fires on the parent agent's turn boundary. The risk is the opposite of what users assume: Stop is too narrow (parent only), but a user expecting a single "fires every time anyone finishes" hook will register both `Stop` and `SubagentStop` to be safe and get exactly the thrashing described.

**How to avoid:**
- Register the inbox-update hook **only** on `Stop`, never on `SubagentStop`.
- The digest skill explicitly instructs the sub-agent: "You are not the inbox keeper. Do not write inbox entries. Your job is to file existing entries and delete them."
- Add a defensive check in the hook prompt itself: "If the only changes this turn were to wiki/* files (i.e. you were filing inbox entries), do nothing." This makes the hook idempotent against digest turns even if a misconfiguration causes it to fire.
- Document the configuration explicitly in the install instructions; do not let users blindly copy a "register on every event" config.

**Warning signs:**
- After running digest, inbox is non-empty when it should be empty.
- Inbox entries reference filing actions ("Filed X to FUNCTIONS/") instead of code state.
- Digest run takes far longer than expected because the sub-agent is responding to repeated Stop nudges.

**Phase to address:** Phase 1 (hook scaffolding) — wrong hook registration here cascades into every other phase.

---

### Pitfall 2: The "1+1 case" — pruning fails when code is created and deleted in the same session

**What goes wrong:**
Claude writes `add(a, b)` in turn 3. The Stop hook fires, Claude updates the inbox with an entry like "Added `add(a, b)` helper to math.ts." In turn 7, Claude (or the user) deletes that function. The Stop hook fires again. Claude updates the inbox to reflect the new turn — but the entry it added in turn 3 is still sitting there. The digest sub-agent later files documentation for a function that no longer exists. This is the user's stated hardest problem and it has several distinct failure modes:

**Sub-failure 2a (no stable handle):** The original entry was free-text ("Added a small helper for summing two ints"). Claude in turn 7 cannot match it to the deleted code without re-reading the entire inbox and reasoning about each line. With a long inbox, it misses the match.

**Sub-failure 2b (cost-driven shortcut):** The hook prompt says "update the inbox" not "rewrite the inbox from scratch." Claude appends a new entry "Removed `add`" rather than deleting the old "Added `add`" entry. The inbox now contains contradictory records; the digest agent has to resolve the contradiction.

**Sub-failure 2c (silent partial prune):** Claude finds the old entry but only edits the "what" not the cross-references. Other entries that mentioned `add` (e.g. "tests/math.test.ts covers `add` and `multiply`") are left dangling.

**Sub-failure 2d (state-of-the-world misinterpretation):** Claude believes inbox = chronological log and "Added X then removed X" is a faithful record of the session. It refuses to prune because "that's what happened." This conflicts with PROJECT.md's locked decision that the inbox is state-of-the-world, not a log.

**Why it happens:**
- Claude's default mental model of session notes is chronological/append-only (training data is dominated by chat logs and changelogs).
- Free-text entries lack stable handles. Without a `entry-id` or `target: math.ts:add` marker, identity must be inferred semantically every turn.
- The Stop hook prompt has to be cheap (PROJECT.md constraint), which biases toward "append a delta" over "diff and reconcile."
- LLMs are known to compound hallucinations: once a wrong entry is in the inbox, subsequent turns treat it as ground truth and reinforce it.

**How to avoid:**
- **Mandate stable handles in entry format.** Every entry includes a structured `target:` field naming the artifact (file path + symbol where applicable: `math.ts:add`, `architecture:auth-flow`, `decision:use-postgres`). The skill instructs Claude to match-and-replace by target, not by prose.
- **Frame the inbox skill explicitly as "mirror the codebase," not "log the session."** Use language like "if this artifact no longer exists in the code, the entry must not exist in the inbox." Include a worked example of the 1+1 case in the skill itself so Claude's first encounter with the concept is the right one.
- **Make the Stop prompt force a diff pass, not an append pass.** Rather than "what changed this turn," ask "for each entry currently in the inbox, does its target still exist in the code? If not, remove it. Then add entries for new artifacts." This is more expensive but it is the only way to catch within-session deletions reliably.
- **Add a digest-side sanity check.** Before filing, the digest sub-agent verifies each entry's target actually exists (greps for the symbol, stats the file). If not, drop the entry rather than file it. This is the safety net for when the inbox-side prune fails.
- **Cap inbox size / age** so the diff pass stays cheap. If inbox > N entries, the skill should prompt the user to run digest.

**Warning signs:**
- A digest run produces a `FUNCTIONS/foo.md` for a function `grep` cannot find in the codebase.
- Inbox contains both "Added X" and "Removed X" entries.
- Inbox grows monotonically across turns (no entries ever leave it without a digest).
- Test fixture: deliberately create-then-delete during a session and check inbox is clean before digest.

**Phase to address:** Phase 2 (inbox skill) for entry format and prompt design; Phase 3 (digest skill) for the safety-net verification. The test fixture for this case should land in Phase 2 and be a release blocker.

---

### Pitfall 3: Stop-hook reentry / infinite loop when the inbox update itself triggers a Stop

**What goes wrong:**
The Stop hook fires, injects "update the inbox" as a system reminder, Claude does the update, Claude's turn ends, Stop hook fires again. Naively this repeats forever. There is also a documented Claude Code bug (issue #10205) where simply having a Stop hook registered — even one that does ~60ms of work and exits 0 — can put Claude Code into an infinite loop that requires disabling hooks to escape.

**Why it happens:**
- Per the hooks reference, `Stop` hooks default to allowing Claude to stop unless the hook returns `decision: "block"` or exit code 2. So a well-behaved hook that just injects context and exits 0 should not loop. The reentry risk specifically arises when a hook returns `decision: "block"` to force continuation, which is exactly what "make Claude update the inbox before stopping" looks like.
- The mitigation is the `stop_hook_active` flag in the hook input JSON: when true, Claude is already in a forced-continuation state from a previous block on the same turn boundary. A hook that re-blocks without checking this flag will loop indefinitely.
- Issue #10205 demonstrates a Claude Code bug class where even non-blocking hooks can loop. The cause appears unrelated to user code — it's a Claude Code issue with the hook protocol itself in some cases.

**How to avoid:**
- **Prefer non-blocking injection over `decision: "block"`.** If the hook can simply add a system reminder via stdout (or via the `additionalContext` mechanism for hooks that support it) and exit 0, do that — Claude will see the reminder on the next user turn rather than be force-continued. This is incompatible with "update the inbox before stopping" but is far safer.
- **If blocking is required, always check `stop_hook_active`.** The hook script must read its stdin JSON, check `stop_hook_active`, and exit 0 immediately if true. This is the canonical infinite-loop guard.
- **Hard-cap the hook with a turn counter.** The hook writes a small file (e.g. `.claude/inbox/.hook-counter`) with a turn ID and a count. If the same turn ID has fired the hook >2 times, exit 0 unconditionally. This is belt-and-braces against bugs like #10205.
- **Provide a kill switch.** A `.claude/inbox/.disabled` file (or env var) that the hook checks first and exits 0. Document this in install instructions: "if Claude Code goes into a loop, `touch .claude/inbox/.disabled` and restart."

**Warning signs:**
- Claude Code session "thinking" forever on what should have been a one-shot turn.
- Hook log file shows the same session_id firing the Stop hook many times in a row.
- CPU/network activity continues long after Claude appears to have finished.

**Phase to address:** Phase 1 (hook scaffolding). The kill switch and `stop_hook_active` check must be in v0 of the hook — they are not optional.

---

### Pitfall 4: Stop hook silently fails and the user thinks the system is working

**What goes wrong:**
The hook script has a typo, the python interpreter isn't on PATH, the inbox file path is wrong, the hook command exits with a non-zero status that Claude Code logs but doesn't surface in the chat. The user develops for hours, no inbox entries are written, no digest is ever needed, and the user believes auto-doc is working. The first time they realize is when they run digest and get an empty result.

**Why it happens:**
- Claude Code hooks run as subprocesses; their stderr generally does not flow to the user-visible chat. Per the hooks reference, hooks have separate exit-code semantics: 0 for success, 2 for block, anything else is an error logged but not necessarily surfaced.
- Auto-doc is a "negative space" feature: failure means *nothing happens*, which is indistinguishable from "no notable changes this turn." There is no error the user can see.
- Hook environment differs from user environment (different PATH, different cwd in some cases). Scripts that work when run by hand fail when run by Claude Code.

**How to avoid:**
- **The hook itself should write a heartbeat.** On every fire, write a timestamp + session_id + outcome to `.claude/inbox/.hook-log`. The user (and Claude in a fresh session) can verify "did the hook actually fire on the last N turns."
- **Inbox skill self-checks at session start.** A `SessionStart` hook (or an instruction in the inbox skill itself) checks the heartbeat file: if no recent entries despite the project being active, surface a system reminder "the inbox hook may not be firing — check `.claude/inbox/.hook-log`."
- **Install flow validates the hook end-to-end.** The install command runs a smoke test: trigger a Stop, check that the heartbeat appeared, fail loudly if not.
- **Use absolute paths and `CLAUDE_PROJECT_DIR`.** Hooks have access to `CLAUDE_PROJECT_DIR` per the official reference. Never rely on `pwd` or relative paths in hook commands.
- **Reasonable timeout.** Default Stop hook timeout is 60s for `agent` type; a heavy inbox-update prompt could exceed this on a slow turn. Pin the timeout explicitly.

**Warning signs:**
- Empty inbox after a session with significant code changes.
- `.claude/inbox/.hook-log` has no recent entries (or doesn't exist).
- Digest produces nothing on a project the user knows had real work.

**Phase to address:** Phase 1 (hook scaffolding) — heartbeat and install validation. Phase 4 (installation flow) — smoke test in the install command.

---

### Pitfall 5: Inbox bloat balloons Claude's per-turn cost

**What goes wrong:**
PROJECT.md explicitly flags this as a constraint: "the update prompt must be cheap and avoid re-reading the entire inbox where possible." But a state-of-the-world inbox with stable handles (Pitfall 2's fix) requires reading the inbox to find entries to prune. Across a long session, the inbox grows; every Stop fire re-reads it; latency and token cost grow super-linearly with session length.

**Why it happens:**
- State-of-the-world semantics are inherently O(inbox size) per update because pruning requires a scan.
- Users defer digest ("I'll digest at end of feature"). Features can span days and many sessions. Inbox accumulates.
- Without a cap, there is no forcing function for digest.

**How to avoid:**
- **Soft cap with prompting.** When inbox exceeds N entries (suggest 30-50, tune empirically), the inbox skill adds a system reminder: "Inbox has 50 entries — consider running `/digest` before continuing." The Stop hook prompt itself stays cheap.
- **Hard cap with refusal.** When inbox exceeds 2N, the skill instructs Claude to refuse new appends until digest runs. Aggressive but forces hygiene.
- **Per-turn diff over full re-read.** The Stop hook prompt provides Claude with the *current turn's tool calls* (transcript_path is in the hook input) so Claude can scope the diff: "given these tool calls this turn, which inbox entries are affected?" rather than "scan all entries every turn."
- **Compact format.** Atomic flat entries with structured handles can be one line each. 50 such entries is ~3KB — still cheap to re-read. Avoid prose entries.
- **Archive on session boundary, not just digest.** A `SessionEnd` hook can move stale entries (last-touched > 24h, say) to an `inbox/archive/` for the digest agent to also consider. Keeps the active inbox lean.

**Warning signs:**
- Stop hook latency creeping above ~2s per turn (compare against issue #1530 baselines: hooks adding 20s of latency are documented).
- Inbox file > 100 entries.
- Digest sub-agent timing out or hitting context limits when finally invoked.

**Phase to address:** Phase 2 (inbox skill) — entry format, soft cap, hard cap. Phase 3 (digest) — handle archived entries.

---

### Pitfall 6: Concurrent Claude sessions corrupt the inbox

**What goes wrong:**
Two Claude Code sessions running against the same project (different terminals, both editing different parts of the codebase). Both Stop hooks fire concurrently. Both sessions read the inbox, both compute updates, both write. The later write clobbers the earlier write — entries from one session are lost. This is a documented Claude Code class of issue (e.g. plan files at `.claude/plans/` are known to be overwritten across concurrent sessions; see issue #27311).

**Why it happens:**
- The inbox is a single shared file. There is no locking mechanism in the hook protocol.
- Users running parallel sessions (which is increasingly common — git worktrees workflows, multiple feature branches) hit this immediately.
- Even with worktrees, if both worktrees share the same `.claude/` and inbox path (which they do unless explicitly separated), they collide.

**How to avoid:**
- **Session-scoped inbox files.** Instead of `inbox/inbox.md`, use `inbox/inbox-<session_id>.md`. The session_id is provided in the hook input. Digest agent reads all `inbox-*.md` files. No write contention.
- **Document worktree workflow.** Install instructions explicitly call out: "if you use git worktrees, ensure each worktree has its own `.claude/` or the inbox files will collide." Worktree-aware install can detect and warn.
- **Atomic file writes only.** Write to `inbox/inbox.md.tmp` then rename. Single-writer atomicity per turn prevents partial-write corruption (though not lost-update).
- **Detect conflict via file mtime.** Hook records the inbox mtime when it starts; if mtime changed by the time it's ready to write, abort and retry once. Bounded — accept loss after one retry to avoid loops.

**Warning signs:**
- Inbox entries from one session "disappearing" when a second session is active.
- Inbox file mtime changing without any local activity (another session wrote).
- Git status shows inbox conflicts after pulling changes.

**Phase to address:** Phase 2 (inbox skill) — session-scoped files. Phase 4 (installation) — worktree warning. Acceptable to defer perfect handling: PROJECT.md scopes this as "single-developer tooling," but single developers run parallel sessions all the time.

---

### Pitfall 7: Claude treats the inbox as authoritative and refuses code changes

**What goes wrong:**
Inbox claims `add(a, b)` exists at `math.ts:5`. The user asks Claude to delete `add`. Claude reads the inbox, sees the entry, and pushes back: "But the inbox says `add` is the canonical helper for X — are you sure?" In an extreme case Claude refuses, or worse, "fixes" the code to match the inbox by re-creating a function the user just deleted.

**Why it happens:**
- LLMs anchor on the most authoritative-looking text in their context. A neat structured inbox with timestamps and handles looks more authoritative than a hurried user message.
- The skill that defines inbox semantics will inevitably include language like "the inbox represents the current state" — Claude can interpret this as "the inbox is the source of truth" rather than "the inbox tracks what's in the code."
- Documentation/spec drift is a known LLM pitfall ("How I stopped Claude Code from hallucinating": "store the truth in files, allow Claude to stop guessing"). Auto-doc inverts this — the file becomes a *plausible-but-wrong* truth.

**How to avoid:**
- **Skill language must explicitly invert the priority.** Use phrasing like: "The inbox is a *derived* view of the codebase. The codebase is ground truth. If they disagree, the codebase wins and the inbox is wrong." Make this the first sentence of the inbox skill.
- **No prescriptive entries.** Entries describe *what is*, never *what should be*. Forbid wording like "should," "must," "TODO" in the entry format. A TODO belongs in code comments, not the inbox.
- **The inbox is read by the skill, not the user.** Don't surface the inbox as a doc the user reviews to decide what to keep — that creates the temptation to treat it as authoritative.
- **Pre-tool reminder.** A `PreToolUse` hook on Edit/Write tools can inject "you are editing code — the inbox does not constrain code; it merely reflects code" to defuse the conflict before it arises. (Optional; weigh against per-edit hook latency.)

**Warning signs:**
- Claude pushes back on a deletion citing the inbox.
- Claude re-creates code to match an inbox entry.
- Inbox entries contain words like "should," "needs to," "TODO."

**Phase to address:** Phase 2 (inbox skill) — wording and entry format restrictions. Test fixture: ask Claude to delete code that has an inbox entry and verify no pushback.

---

### Pitfall 8: Sub-agent missing context the parent had (decision rationale lost)

**What goes wrong:**
The parent session decides to use Postgres over SQLite "because we need full-text search later." The inbox entry says `decision: postgres`. The digest sub-agent — per Claude Code's documented context isolation — starts with a fresh context window containing only the inbox content plus its skill instructions. It files the decision into `ARCHITECTURE/database.md` with no rationale, because the inbox was atomic and the rationale wasn't captured. The wiki note becomes "we use Postgres" with no "why," and a future session can't reconstruct the decision.

**Why it happens:**
- Per the official Claude Code subagents docs: "Each subagent runs in its own fresh conversation. The only channel from parent to subagent is the Agent tool's prompt string." The inbox is the only artifact the digest agent sees.
- PROJECT.md key decision: "Atomic, flat entries (no in-session sectioning)" — atomicity is great for routing but bad for preserving context that links entries.
- The Stop hook prompt biases toward terse entries (cost constraint), so rationale gets dropped in favor of facts.

**How to avoid:**
- **Entries include rationale when present.** Format: `target: ... | what: ... | why: ...` with `why` mandatory for decision-type entries. Functions/architecture entries can leave `why` blank but decisions must have it.
- **Digest skill explicitly preserves "why".** Filing instructions: "if the entry has a `why`, that is non-negotiable — it must appear in the filed note's Content section, not just the Summary."
- **Cross-link adjacent entries.** When two entries share context (e.g. "added Postgres dep" and "decision: use Postgres"), the inbox skill can group them with a shared `topic:` tag. Digest agent uses this to file related entries to the same note.
- **Spec-style entries for decisions.** A separate entry type for decisions that is verbose by design (cost the rationale tokens; decisions are rare).

**Warning signs:**
- Filed wiki notes that read like changelog entries with no "why."
- Digest agent has to ask the parent (impossible in subagent isolation) for context.
- A future Claude session reading the wiki cannot answer "why did we pick X?"

**Phase to address:** Phase 2 (inbox skill) — entry format with optional `why` field. Phase 3 (digest skill) — preservation rules.

---

### Pitfall 9: Digest creates duplicate notes instead of updating existing ones

**What goes wrong:**
The wiki already has `FUNCTIONS/auth-handler.md`. A new inbox entry mentions modifications to the auth handler. The digest sub-agent — fresh context, hasn't read the wiki yet — creates `FUNCTIONS/auth-handler-v2.md` or `FUNCTIONS/auth-handler-update.md` instead of editing the existing note. Two notes now describe the same concept, violating `Rules.md` §4 ("One concept per note") and §8 ("If it's wrong, edit it").

**Why it happens:**
- Sub-agent context isolation: the digest agent doesn't automatically know what's already in `wiki/`. It must explicitly grep/read.
- Cost pressure: reading the entire wiki on every digest is expensive, so users may be tempted to skip it.
- LLMs default to creating new artifacts over editing existing ones (training bias toward generation).

**How to avoid:**
- **Mandatory wiki index pass.** First step in digest skill: list all files under `wiki/` (kebab-case names per Rules.md §5 makes this greppable). This is cheap — filenames only, not content.
- **Match-before-create rule.** For each inbox entry, the digest agent must search the file list for related notes. Only if no match exists does it create a new note. The skill can include a worked example.
- **Follow Rules.md §8 literally.** The skill quotes the rule: "Never silently delete a filed note. If it's wrong, edit it." Make this an explicit step in the digest workflow checklist.
- **Detect duplication on dry-run.** A digest preview mode (Pitfall 11) catches duplicates before they are written.

**Warning signs:**
- Wiki has multiple files describing the same function/concept.
- Filenames like `foo-v2`, `foo-new`, `foo-update`.
- `Rules.md` §5 ("filename should match the note's H1 concept closely") violated by suffixed names.

**Phase to address:** Phase 3 (digest skill) — index-and-match workflow.

---

### Pitfall 10: Cross-link rot when notes are split or renamed during digest

**What goes wrong:**
Rules.md §4 mandates splitting notes that exceed 1,000 words. The digest agent splits `vorp-calculation.md` into `vorp-base-formula.md`, `vorp-position-multipliers.md`, etc. Other notes in the wiki link to `[[VORP Calculation]]`. Per Rules.md §7, Obsidian uses display-title resolution, so renaming title (not just filename) breaks the wiki-links. The split also means there is no longer a single "VORP Calculation" note for those links to resolve to. Backlinks rot silently — Obsidian shows them as unresolved but the digest agent doesn't check.

**Why it happens:**
- The digest agent is task-focused (file these entries) and doesn't audit broader wiki state after each operation.
- Obsidian wiki-links are display-title-based; renaming or removing a title breaks all incoming links. This is documented as a long-standing pain point in Obsidian itself (Smart Rename plugin exists specifically for this).
- Rules.md §7 forbids hard-coded paths but doesn't prescribe rename safety because Obsidian-the-app handles it interactively. The digest agent runs non-interactively.

**How to avoid:**
- **Pre-split backlink scan.** Before splitting note X, grep the wiki for `[[X]]` (and aliases). If any exist, the digest skill must update those links to point to the most relevant split, or to a new "hub" note that lists the splits.
- **Hub-note pattern for splits.** When a note is split, leave a one-line hub note at the original title pointing to the splits. Rules.md §8 already prescribes this for deprecation; extend to splits. Existing backlinks remain resolvable.
- **Never rename titles silently.** If digest must rename, it logs the rename in a digest report and runs a backlink-fix pass.
- **Post-digest audit step.** End of digest workflow: grep for unresolved wiki-links (`[[Something]]` where no `something.md` exists in wiki). Surface these in the digest summary so the user can fix.

**Warning signs:**
- Obsidian shows unresolved wiki-links after a digest run.
- A note's "Related Notes" section points to a title that doesn't exist as a note.
- Backlinks panel in Obsidian empties out for a note that used to be heavily linked.

**Phase to address:** Phase 3 (digest skill) — backlink-aware split logic.

---

### Pitfall 11: Digest writes junk into the wiki with no preview/rollback

**What goes wrong:**
Digest runs, writes 12 new files, edits 5 existing files, deletes 12 inbox entries. The user reviews the result and finds that two of the new files are nonsense (the sub-agent misinterpreted an entry), one existing file lost a paragraph it shouldn't have, and the inbox entries are gone — they can't redigest. Recovery requires git revert (if committed) or manual restoration (if not).

**Why it happens:**
- LLMs make plausible-but-wrong filing decisions, especially with ambiguous entries. Hallucination compounds: a slightly wrong file then becomes the basis for the next digest's decisions.
- Digest is destructive (deletes inbox entries on success). No reversibility built in.
- The user has no review checkpoint between "digest started" and "wiki is mutated."

**How to avoid:**
- **Dry-run / preview mode by default.** Digest produces a plan first: "I will create X, edit Y, delete Z entries from inbox." User confirms before execution. PROJECT.md says "explicit digest gives a review checkpoint" — implement that as a literal preview step.
- **Stage to a branch.** Digest writes changes, but in a working state the user can `git diff` before deciding to keep. Inbox entries are only deleted after explicit confirmation (or on the next digest run that sees the wiki note exists).
- **Two-phase deletion.** Phase 1 of digest moves inbox entries to `inbox/processed/<session-id>/` (or appends a `processed: true` marker). Phase 2, run later, deletes them. Until phase 2, redigest is possible.
- **Digest report.** Every digest produces `inbox/last-digest.md` listing what it did. User can audit. Sub-agent treats this as part of its mandatory output.

**Warning signs:**
- User has to revert digest results from git.
- Wiki notes that read as nonsense.
- Inbox entries that were valid but got filed into the wrong category.

**Phase to address:** Phase 3 (digest skill) — preview mode is core, not optional.

---

### Pitfall 12: Digest violates `Rules.md` conventions silently

**What goes wrong:**
The digest sub-agent files a note that violates Rules.md: filename uses snake_case instead of kebab-case (§5), summary is 40 words (§3 caps at 25), creates a new top-level folder without updating Rules.md (§2), uses markdown links instead of wiki-links (§7), or files into `_templates/` (§9). The wiki gradually drifts from the contract that makes it coherent.

**Why it happens:**
- Rules.md is loaded into the digest sub-agent's context but Claude can drop attention on long instruction sets, especially when filing many entries in one digest run.
- LLMs will silently "improve" or "simplify" rules they find tedious (e.g. swap wiki-link for markdown link because the latter is more standard).
- No automated check enforces Rules.md.

**How to avoid:**
- **Lint pass after every filed note.** Each note the digest creates is checked against Rules.md mechanically: filename regex (`^[a-z0-9-]+\.md$`), summary word count (≤25), required template fields present, wiki-link syntax in Related Notes section. Fail = retry the note (max 1 retry, then surface to user).
- **Rules.md is the digest skill's prompt prologue.** Don't *reference* Rules.md — quote it inline at the top of the digest skill so it's always in attention range, not buried in a file the agent has to remember to consult.
- **Test fixture validates conformance.** The example wiki (PROJECT.md mentions a Traxalytics fixture) must include test cases for every Rules.md clause. Digest run against the fixture must produce conforming output.
- **Explicit refusal on §2 ambiguity.** If an entry doesn't fit existing categories, the skill instructs the agent to *halt and ask the user*, not invent a folder. Rules.md §10 already prescribes this.

**Warning signs:**
- Filenames in non-kebab-case appearing in wiki.
- Summary fields exceeding 25 words.
- New top-level folders without a corresponding Rules.md edit.
- Markdown links where wiki-links should be.

**Phase to address:** Phase 3 (digest skill) — lint pass. Phase 4 (test fixture) — Rules.md conformance suite.

---

### Pitfall 13: Inbox accumulates a feature's worth of entries before digest

**What goes wrong:**
User is heads-down for 4 days, never runs digest. Inbox has 200+ entries spanning multiple features, decisions, refactors. When digest finally runs, the sub-agent has to (a) hold all 200 entries in context, (b) reconcile them against existing wiki, (c) produce a coherent filing plan. It hits context limits, makes worse decisions due to attention dilution, takes a long time, and the result is lower quality than several smaller digests would have been.

**Why it happens:**
- PROJECT.md decision: "manual digest" — no forcing function.
- Users defer until "the feature is done." Features rarely end at session boundaries.
- Auto-doc systems share this with documentation drift in general: deferral compounds.

**How to avoid:**
- **Soft prompt at thresholds.** Inbox skill prompts the user (via system reminder Claude can echo) at 30/50/100 entries: "consider running digest." Cheap, non-blocking.
- **Chunked digest mode.** When inbox exceeds N entries, digest works in chunks: file the oldest M entries, leave the rest for the next run. Avoids one giant context-blowing pass.
- **Topic-clustered digest.** Digest groups entries by `target:` prefix (e.g. all `auth-*` entries together) and files cluster by cluster. Cluster-local context is smaller than full-inbox context.
- **Don't aim for auto-digest in v1.** PROJECT.md correctly defers this; the cost of getting it wrong (running while the user is mid-edit) is high.

**Warning signs:**
- Digest runs taking >5 minutes.
- Sub-agent context warnings during digest.
- User reporting "I forgot to digest" repeatedly.

**Phase to address:** Phase 2 (inbox skill) — threshold prompts. Phase 3 (digest) — chunked/clustered mode.

---

### Pitfall 14: Wiki and codebase diverge — deleted source files still have wiki notes

**What goes wrong:**
The user deletes `src/legacy/old-handler.ts`. Inbox-side pruning catches this within the session (Pitfall 2 fix). But the wiki already has a filed note `FUNCTIONS/old-handler.md` from a prior digest. There is no mechanism to prune *the wiki* when source is deleted; only the inbox is reactive. The wiki accumulates ghost notes for code that no longer exists.

**Why it happens:**
- The system is designed for adding/updating notes from the inbox, not for retiring filed notes when source disappears.
- Rules.md §8 says "Never silently delete a filed note" and prescribes deprecation pointers. This is correct policy but requires someone/something to *trigger* the deprecation. Currently nothing does.
- The inbox is session-scoped; the wiki is project-scoped. The lifecycle mismatch creates the gap.

**How to avoid:**
- **Reconciliation skill / command.** A separate skill (e.g. `/reconcile` or `/audit-wiki`) walks `wiki/FUNCTIONS/`, for each note greps the codebase for the referenced symbol or path, and surfaces "this note's target no longer exists" cases. User decides per case whether to deprecate per Rules.md §8.
- **Deprecation as inbox entry type.** When Claude in-session deletes code that has a wiki note (the inbox-side prune knows about it), it adds a `deprecate: <note>` inbox entry. Digest then handles it per Rules.md §8.
- **Document the gap explicitly.** v1 may not solve this. Install instructions should be honest: "This system keeps the inbox in sync with the codebase within a session, and the digest files inbox to wiki. It does not currently audit the wiki against the codebase — run `/reconcile` periodically (or accept some drift)."
- **Out of scope flag.** If reconciliation is deferred to v2, mark explicitly so it doesn't get rediscovered as a surprise.

**Warning signs:**
- Wiki has `FUNCTIONS/foo.md` but `grep -r foo` in codebase returns nothing.
- "Last Updated" timestamps on wiki notes are months old for code that's been heavily refactored.

**Phase to address:** Phase 5 or v2 (reconciliation skill). PROJECT.md does not list this as Active; consider adding or explicitly deferring.

---

### Pitfall 15: Hook fires during git operations, REPL sessions, and noise turns

**What goes wrong:**
The user runs a session purely to debug something — no real code changes, just `cat`/`grep`/asking questions. Stop hook fires every turn, asks Claude to update the inbox, Claude either (a) writes "investigated X, no changes" entries that pollute the inbox, or (b) correctly does nothing but burns tokens deciding to do nothing. Same problem during git-only turns ("commit and push"), interactive REPL/playground turns, or chat-only turns where the user is asking explanatory questions.

**Why it happens:**
- The Stop hook can't tell intent. Every turn is a turn.
- The skill's prompt biases toward action ("update the inbox to reflect the turn"). Claude can over-interpret no-ops as actions.
- Cost compounds: 50 noise turns at 200 tokens each = real money.

**How to avoid:**
- **Skill includes explicit no-op guidance.** "If the turn made no observable change to code or decisions, do nothing." Worked example: a turn that only ran read tools (Read, Grep, Glob) with no Edit/Write should produce no inbox change.
- **Hook can pre-filter via transcript.** The hook input includes `transcript_path`. A lightweight script can grep the transcript for Edit/Write/MultiEdit tool calls in the latest turn and skip the inbox prompt entirely if there were none. This avoids Claude even seeing the prompt on no-op turns.
- **Mode flag for explicit pause.** A `.claude/inbox/.paused` file (or `/inbox-pause` slash command) suspends the hook for a session. User toggles when starting a debug-only session.
- **Don't trigger on non-code turns.** If the user's prompt was a question and the response had no tool calls, exit the hook early.

**Warning signs:**
- Inbox entries like "Investigated X" with no code change.
- Token spend per session disproportionate to code changes.
- User complaining the hook makes chat-only turns slow.

**Phase to address:** Phase 1 (hook scaffolding) — transcript pre-filter and pause mechanism. Phase 2 (inbox skill) — no-op guidance.

---

### Pitfall 16: Claude invents inbox entries (hallucinated code or decisions)

**What goes wrong:**
Claude writes an entry "Refactored auth middleware to use JWT" — but no such refactor happened. Or "Decision: use Redis for caching" with no real decision. The digest agent files documentation for things that don't exist. This is the auto-doc analog of the well-documented Claude hallucination pattern (issue #10628: "hallucinated fake user input mid-response, then compounded error by treating hallucination as real").

**Why it happens:**
- The Stop hook prompt asks Claude to summarize the turn. If Claude misremembers the turn (long context, compaction occurred), it can confabulate plausible-sounding entries.
- LLMs prefer producing output to producing nothing. An empty inbox update feels wrong to the model.
- Once a hallucinated entry is in the inbox, subsequent turns see it and treat it as real (compounding hallucination).

**How to avoid:**
- **Ground entries in tool calls.** The Stop hook injects the actual tool calls from this turn (extracted from transcript_path) as context. The skill instructs: "every entry must correspond to an Edit/Write tool call this turn (for code) or an explicit user request (for decisions)." Free invention is forbidden.
- **Cite evidence in entries.** Entry format includes `evidence: turn-3 Edit math.ts:5` — a pointer to the tool call that justifies the entry. Digest can verify by re-reading the transcript if available.
- **Verify on digest.** Before filing, the digest agent greps the codebase for the entry's target. If absent, the entry is dropped (this is also Pitfall 2's safety net — same mechanism).
- **Audit log for the user.** A simple `cat inbox/inbox-*.md` should let the user spot-check what the system claims happened. Keep entries short and structured so this audit is fast.

**Warning signs:**
- Inbox entries that don't correspond to anything in `git diff`.
- Wiki notes that describe functionality the user can't find in the code.
- Claude in a fresh session "remembering" features that were never built.

**Phase to address:** Phase 2 (inbox skill) — evidence requirement. Phase 3 (digest) — verification before filing.

---

### Pitfall 17: User can't easily audit what the inbox claims happened

**What goes wrong:**
User has a vague feeling the inbox is wrong but can't tell what's right. Entries are atomic and free-text-ish. Cross-referencing 50 entries against actual code is tedious. Trust erodes; user stops believing the wiki is accurate.

**Why it happens:**
- Atomic entries lose narrative context — there's no "what happened this session" view.
- No tooling beyond `cat`/`less` for the inbox.
- No mechanism to ask "show me entries about X."

**How to avoid:**
- **Stable handles enable filtering.** With `target:` fields, a one-liner like `grep target:auth inbox/*.md` produces a focused view.
- **Per-session inbox files.** With session-scoped files (Pitfall 6 fix), `cat inbox/inbox-<latest>.md` is a turn-by-turn record of one session.
- **Digest report as audit artifact.** `inbox/last-digest.md` lists what was filed and where. User reviews this rather than the full inbox.
- **`/inbox-status` slash command (optional).** Reports entry count, oldest entry age, sessions represented, suspected stale handles. Lightweight, helpful.

**Warning signs:**
- User says "I don't trust the wiki anymore."
- User stops running digest.
- User asks Claude in-session "what does my inbox say?" — implying they can't read it themselves.

**Phase to address:** Phase 2 (entry format), Phase 3 (digest report), Phase 5 (audit tooling, possibly v2).

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Single shared `inbox/inbox.md` instead of per-session files | Simpler skill prompt; one file to read | Concurrent-session corruption (Pitfall 6); session attribution lost | Solo single-terminal workflow only — never if user uses worktrees or parallel sessions |
| Free-text entries with no `target:` handle | Lower friction for Claude; smaller entries | Pruning fails (Pitfall 2); audit impossible (Pitfall 17); duplicate filings (Pitfall 9) | Never — handles are the linchpin of the whole system |
| No `stop_hook_active` check in the hook | Slightly simpler script | Infinite loops if blocking is ever used (Pitfall 3) | Never — this is one line of code and the cost of skipping it is catastrophic |
| Skip dry-run / preview in digest | Faster path to v1 | Junk in wiki, no rollback (Pitfall 11); user trust erosion (Pitfall 17) | Never — preview is a 1x dev cost for a permanent UX win |
| No heartbeat / hook log | Less moving parts | Silent failures undetectable (Pitfall 4) | Never — heartbeat is ~3 lines of bash |
| Append-only inbox (chronological) instead of state-of-the-world | Simpler write path; no diff cost | Pruning impossible by construction; PROJECT.md decision violated | Never — PROJECT.md locks this as state-of-the-world |
| Digest does no Rules.md lint | Less code | Wiki drifts from contract (Pitfall 12) | Acceptable in earliest prototype; unacceptable at v1 release |
| Skip wiki index pass in digest | Cheaper digest | Duplicate notes (Pitfall 9) | Never — index is `ls wiki/**/*.md`, trivially cheap |
| Defer reconciliation skill (Pitfall 14) | Smaller v1 scope | Wiki accumulates ghost notes | Acceptable for v1 *if explicitly documented*; unacceptable as silent drift |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| `Stop` hook | Registering on both `Stop` and `SubagentStop` to "be safe" | Register only on `Stop`. SubagentStop is a separate event; conflating them causes Pitfall 1. |
| `SubagentStop` hook | Assuming it fires when a Task-tool sub-agent returns to parent (it does not consistently — see issue #33049) | Treat sub-agent return as out of band; do not rely on `SubagentStop` for state hand-off |
| Hook input JSON | Ignoring `stop_hook_active` flag | Always parse and check; exit 0 immediately if true (Pitfall 3) |
| Hook environment | Assuming user's PATH / cwd | Use `CLAUDE_PROJECT_DIR` and absolute paths (Pitfall 4) |
| Hook timeout | Default `agent` timeout is 60s; default `command` is 600s | Set explicit timeout matching expected workload; pin so behavior is reproducible |
| Obsidian wiki-links | Renaming a note's H1 title without updating backlinks | Use hub-note pattern on splits; grep for inbound links before rename (Pitfall 10) |
| Sub-agent context | Assuming digest agent has parent's session context | All required context goes into the inbox itself; the digest skill prompt is the only other channel (Pitfall 8) |
| `Rules.md` template | Filing a note that's missing required fields (Summary, Tags, Created, Last Updated) | Lint pass after every write; reject + retry (Pitfall 12) |
| Concurrent sessions | Both writing same `inbox/inbox.md` | Per-session inbox files keyed on `session_id` from hook input (Pitfall 6) |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Re-reading full inbox every Stop fire | Per-turn latency creeps up; token cost grows with session length | Per-turn diff using transcript_path; structured handles for cheap match | ~50 entries; visible at ~100 |
| Running heavy lint/test inside Stop hook | Multi-second pause every turn; issue #1530-style 20s latency | Keep Stop hook to inbox-update only; defer heavy work to digest | Immediately on slow projects |
| Digest in one giant pass on a 200-entry inbox | Sub-agent context exhaustion; degraded routing decisions | Threshold prompts; chunked/clustered digest | ~100 entries (varies with context budget) |
| Hook spawns Node/Python interpreter per fire | Cumulative startup latency (issue #1530: 11 hooks → 18s vs 4.8s) | Prefer bash/sh for the hook; reserve interpreters for digest sub-agent | Multiple hooks registered; long sessions |
| No bound on archived inbox files | Disk grows; SessionEnd archive scans slow | LRU cap on `inbox/archive/`; prune oldest beyond N | After many sessions |

## Security / Safety Mistakes

These aren't "security" in the OWASP sense — this is solo-developer tooling — but they are domain-specific safety issues.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Hook script executes with broad shell access on every turn | Bug in hook = corruption of project files; supply-chain risk if installed via curl-pipe-bash | Hook is a small, audited script; install instructions show it before running; no network calls in the hook itself |
| Digest sub-agent has Edit/Write on entire `wiki/` | A misrouting wipes user notes | Two-phase deletion (Pitfall 11); preview mode; git-friendly diffs |
| Inbox file committed to git accidentally | Session-private notes leak; merge conflicts | `.gitignore` `inbox/inbox-*.md` by default in install; archive may be committed but active inbox is not |
| Hook reads files Claude wouldn't normally see (.env, secrets) when summarizing | Secrets land in inbox / wiki | Skill explicitly forbids reading non-source files for the summary; entry format does not have a "raw content" field |
| Unbounded heartbeat / log file | Disk fill on long-lived projects | Rotate hook log at N MB |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Auto-doc is invisible — failures are silent | User doesn't know it's broken until digest is empty | Heartbeat + install smoke test (Pitfall 4) |
| Digest is destructive and surprising | User runs `/digest`, wiki is mutated, user can't easily revert | Preview by default; explicit confirmation (Pitfall 11) |
| Inbox becomes another file the user has to babysit | Defeats the "no manual upkeep" promise | Threshold prompts; per-session files for natural rotation |
| Claude pushes back on user requests because of inbox | Friction; user disables the system | Inbox-is-derived-view framing (Pitfall 7) |
| Rules.md violations accrete invisibly | User loses faith in wiki coherence | Lint + digest report shows conformance (Pitfall 12) |
| No way to say "ignore this turn" | Hook fires on REPL/debug turns, pollutes inbox | `.paused` file / pause command + transcript pre-filter (Pitfall 15) |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Stop hook registered:** Often missing `stop_hook_active` check — verify with intentional block + retry test.
- [ ] **Inbox skill installed:** Often missing the explicit "inbox is derived from code, not authoritative" framing — verify by asking Claude to delete code that has an inbox entry.
- [ ] **Digest skill works:** Often missing wiki index pass — verify by digesting twice in a row and checking for duplicate notes.
- [ ] **Pruning works:** Often missing the 1+1 case — verify with the test fixture: create function, delete function in same session, run digest, check no doc was filed.
- [ ] **Hook is firing:** Often silently broken — verify heartbeat file has recent entries.
- [ ] **Sub-agent gets Rules.md:** Often only references it instead of inlining — verify by checking the digest skill prompt text.
- [ ] **Concurrent sessions don't corrupt inbox:** Often single-file inbox — verify by running two sessions briefly.
- [ ] **Rules.md compliance:** Often skipped lint — verify generated notes against §3, §5 with a simple grep.
- [ ] **Digest is reversible:** Often deletes inbox entries before user confirms — verify by aborting a digest mid-run and checking inbox is intact.
- [ ] **Backlinks survive splits:** Often skipped — verify by deliberately splitting a heavily-linked note and checking inbound `[[X]]` references still resolve (or have been updated).

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Hook in infinite loop (Pitfall 3) | LOW | `touch .claude/inbox/.disabled`, restart Claude Code, investigate logs |
| Inbox corrupted by concurrent sessions (Pitfall 6) | LOW | `git checkout` the inbox or restore from `inbox/archive/`; switch to per-session files |
| Hallucinated entries filed (Pitfalls 11, 16) | MEDIUM | `git revert` the digest commit; redigest with stricter verification; tighten skill prompt |
| Wiki and code diverged (Pitfall 14) | MEDIUM-HIGH | Run reconciliation pass (or manual audit) per Rules.md §8; deprecate ghost notes with pointer |
| Backlinks rotted from splits (Pitfall 10) | MEDIUM | Grep for unresolved `[[X]]`, fix manually; add post-digest audit step going forward |
| Trust eroded — user stopped using digest (Pitfalls 11, 17) | HIGH (social, not technical) | Add preview mode, audit tooling, demonstrate trustworthy run; consider one-off rebuild from scratch |
| Hook silent-failed for days (Pitfall 4) | HIGH | Re-derive inbox from `git log` of the period (Claude can do this in a session); accept some loss; add heartbeat going forward |

## Pitfall-to-Phase Mapping

This assumes a phase structure roughly: Phase 1 = hook scaffolding, Phase 2 = inbox skill, Phase 3 = digest skill, Phase 4 = installation / fixture, Phase 5 = polish / audit tooling. Roadmap should adapt names but keep the ordering.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| 1. Stop hook fires for sub-agents | Phase 1 | Run digest; inbox unchanged after sub-agent finishes |
| 2. 1+1 pruning failure | Phase 2 (skill); Phase 3 (safety net) | **Test fixture: create-and-delete in one session, digest, no doc filed** — release blocker |
| 3. Stop hook reentry / infinite loop | Phase 1 | Force a `decision: block` with `stop_hook_active=true` injected; verify hook exits 0 |
| 4. Hook silent failure | Phase 1 (heartbeat); Phase 4 (install smoke test) | Heartbeat file present and recent after smoke test |
| 5. Inbox bloat balloons cost | Phase 2 | Synthetic 50/100/200-entry inboxes; measure per-turn latency stays bounded |
| 6. Concurrent session corruption | Phase 2 (per-session files); Phase 4 (worktree warning) | Two-session smoke test; inbox files distinct |
| 7. Inbox treated as authoritative | Phase 2 | Test: ask Claude to delete code with inbox entry; no pushback |
| 8. Sub-agent missing rationale | Phase 2 (entry format with `why`); Phase 3 (preservation) | Decision-type entries always have `why`; filed notes preserve it |
| 9. Duplicate notes in wiki | Phase 3 | Digest twice in a row; second digest produces no duplicates |
| 10. Cross-link rot on split | Phase 3 | Force a 1,200-word note split; verify inbound links resolve or were updated |
| 11. Junk into wiki, no preview | Phase 3 | Preview mode is the default invocation; explicit confirmation required |
| 12. Rules.md violations | Phase 3 (lint); Phase 4 (conformance suite) | Lint pass on every filed note; fixture test suite green |
| 13. Feature-scale inbox accumulation | Phase 2 (threshold prompts); Phase 3 (chunked digest) | Threshold reminder fires at 50; chunked digest succeeds on 200-entry input |
| 14. Wiki diverges from codebase | Phase 5 or v2 (reconciliation); Phase 4 (document gap) | `/reconcile` lists ghost notes; install README documents the gap |
| 15. Hook noise on debug/REPL turns | Phase 1 (transcript filter); Phase 2 (no-op guidance) | Read-only turns produce no inbox change |
| 16. Claude invents entries | Phase 2 (evidence requirement); Phase 3 (verify before file) | Synthetic test: prompt Claude with no tool calls; no entries written |
| 17. User can't audit | Phase 2 (handles + per-session files); Phase 3 (digest report); Phase 5 (status command) | User can answer "what changed in session X" with a single grep |

## Sources

Verified primary sources (HIGH confidence):

- [Hooks reference — Claude Code Docs](https://code.claude.com/docs/en/hooks) — Stop / SubagentStop semantics, `stop_hook_active`, exit codes, environment variables, timeouts. Authoritative.
- [Create custom subagents — Claude Code Docs](https://code.claude.com/docs/en/sub-agents) — Sub-agent context isolation model.
- [Subagents in the SDK — Claude API Docs](https://platform.claude.com/docs/en/agent-sdk/subagents) — Confirms isolation; only the prompt string crosses parent→sub-agent boundary.
- [Intercept and control agent behavior with hooks — Claude API Docs](https://platform.claude.com/docs/en/agent-sdk/hooks) — Hook protocol details.
- [Subagent (Agent tool) does not fire Stop hook on completion · Issue #33049 — anthropics/claude-code](https://github.com/anthropics/claude-code/issues/33049) — Confirms Stop ≠ SubagentStop and the inconsistency for the Task tool.
- [Claude Code enters infinite loop when hooks are enabled · Issue #10205 — anthropics/claude-code](https://github.com/anthropics/claude-code/issues/10205) — Documented infinite loop class even with non-blocking hooks.
- [Plan files overwritten across concurrent sessions in same directory · Issue #27311 — anthropics/claude-code](https://github.com/anthropics/claude-code/issues/27311) — Confirms shared-file corruption pattern.
- [`wiki/Rules.md`](../../wiki/Rules.md) — The locked contract the digest agent must respect.
- [`PROJECT.md`](../PROJECT.md) — Locked decisions about state-of-the-world inbox, atomic entries, manual digest.

Supporting / community sources (MEDIUM confidence):

- [Hooks causing ~20s latency on every Claude Code CLI interaction · Issue #1530 — ruvnet/ruflo](https://github.com/ruvnet/ruflo/issues/1530) — Hook-stack latency baseline.
- [Claude Code Stop Hook: Force Task Completion — claudefa.st](https://claudefa.st/blog/tools/hooks/stop-hook-task-enforcement) — Worked `stop_hook_active` example.
- [Avoid the Dangers of Settings Pollution in Subagents, Hooks, and Scripts — egghead.io](https://egghead.io/avoid-the-dangers-of-settings-pollution-in-subagents-hooks-and-scripts~xrecv) — Sub-agent settings inheritance gotchas.
- [Claude Code Worktrees: Parallel Sessions Without Conflicts — claudefa.st](https://claudefa.st/blog/guide/development/worktree-guide) — Concurrent session patterns.
- [What is Documentation Drift and How to Avoid It? — gaudion.dev](https://gaudion.dev/blog/documentation-drift) — Generic doc-drift framing; specialized to this project's failure modes in Pitfall 14.
- [How I stopped Claude Code from hallucinating on Day 4 — DEV Community](https://dev.to/samhath03/how-i-stopped-claude-code-from-hallucinating-on-day-4-the-spec-driven-workflow-3lim) — Spec-as-truth pattern; informed Pitfall 7's framing.
- [Persistent Hallucination and Fabrication in Code Generation · Issue #8079 — anthropics/claude-code](https://github.com/anthropics/claude-code/issues/8079) — Hallucination compounding pattern; Pitfall 16.
- [Preventing Link Rot in my Obsidian Vault — Ben Congdon](https://benjamincongdon.me/blog/2021/09/19/Preventing-Link-Rot-in-my-Obsidian-Vault/) — Wiki-link rename hazards; Pitfall 10.
- [Smart Rename — Obsidian Plugin](https://www.obsidianstats.com/plugins/smart-rename) — Confirms Obsidian's display-title resolution and the rename problem.

---
*Pitfalls research for: Claude Code skill+hook auto-doc system*
*Researched: 2026-04-28*
