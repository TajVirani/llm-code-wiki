---
name: wiki-install
description: Bootstrap a project to use the auto-wiki system. Creates wiki/, _templates/note.md, Rules.md, inbox/, merges the Stop hook entry into .claude/settings.json, and appends an Auto-maintained wiki section to CLAUDE.md. Idempotent — skips and logs anything that already exists. Run once after the .claude/ tree is in place.
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Bash
---

# /wiki-install — Bootstrap the auto-wiki system

Run this skill once after the `.claude/` tree (skills, agents, hook) has been copied into the target project. It creates the wiki scaffolding, merges the Stop hook entry into `.claude/settings.json`, and appends a documentation section to `CLAUDE.md`. Every step is idempotent — re-running after a partial install is safe.

## Step 0 — Precondition check

Verify the required `.claude/` files are present and both hooks are executable:

```bash
for f in \
  "$CLAUDE_PROJECT_DIR/.claude/skills/inbox-update/SKILL.md" \
  "$CLAUDE_PROJECT_DIR/.claude/skills/digest/SKILL.md" \
  "$CLAUDE_PROJECT_DIR/.claude/skills/recall/SKILL.md" \
  "$CLAUDE_PROJECT_DIR/.claude/agents/wiki-curator.md" \
  "$CLAUDE_PROJECT_DIR/.claude/agents/wiki-recall.md" \
  "$CLAUDE_PROJECT_DIR/.claude/hooks/inbox-stop.sh" \
  "$CLAUDE_PROJECT_DIR/.claude/hooks/recall-prompt.sh"; do
  test -f "$f" || { echo "[wiki-install] ABORT: $f not found. Copy the .claude/ tree before running /wiki-install."; exit 1; }
done
test -x "$CLAUDE_PROJECT_DIR/.claude/hooks/inbox-stop.sh" || { echo "[wiki-install] ABORT: inbox-stop.sh exists but is not executable. Run: chmod +x .claude/hooks/inbox-stop.sh"; exit 1; }
test -x "$CLAUDE_PROJECT_DIR/.claude/hooks/recall-prompt.sh" || { echo "[wiki-install] ABORT: recall-prompt.sh exists but is not executable. Run: chmod +x .claude/hooks/recall-prompt.sh"; exit 1; }
echo "[wiki-install] Precondition check passed — .claude/ tree is in place."
```

If any file is missing, the skill aborts immediately. This catches the "ran before the plugin was copied" failure mode.

**Note on skill/agent name collisions:** This skill assumes the `.claude/` tree was copied cleanly into the target project. If the target had pre-existing skills with names matching ours (`wiki-install`, `inbox-update`, `digest`, `recall`, `wiki-rules`) or agents named `wiki-curator` / `wiki-recall`, those would have been overwritten by the upstream copy step (plugin install, manual copy, marketplace, etc.). The distribution mechanism is responsible for surfacing those collisions to the user. `/wiki-install`'s precondition check only verifies our required files are present and both hooks are executable — it does NOT detect content drift or naming collisions inherited from the upstream copy.

## Step 1 — wiki/ directory (D-03)

Check whether `wiki/` exists:

```bash
if test -d "$CLAUDE_PROJECT_DIR/wiki"; then
  echo "[wiki-install] wiki/ already exists, skipping"
else
  mkdir -p "$CLAUDE_PROJECT_DIR/wiki"
  echo "[wiki-install] Created wiki/"
fi
```

## Step 2 — wiki/_templates/note.md (D-04)

Check whether the note template exists:

```bash
if test -f "$CLAUDE_PROJECT_DIR/wiki/_templates/note.md"; then
  echo "[wiki-install] wiki/_templates/note.md already exists, skipping (user customization preserved)"
else
  mkdir -p "$CLAUDE_PROJECT_DIR/wiki/_templates"
  echo "[wiki-install] Creating wiki/_templates/note.md..."
fi
```

If the file is absent, use Write to create `wiki/_templates/note.md` with the canonical template content (Read the source from this repo's `wiki/_templates/note.md` first; if unavailable, use the standard shape below):

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

After writing:

```bash
echo "[wiki-install] Created wiki/_templates/note.md"
```

## Step 3 — wiki/Rules.md (D-05)

Check whether `wiki/Rules.md` exists:

```bash
if test -f "$CLAUDE_PROJECT_DIR/wiki/Rules.md"; then
  echo "[wiki-install] wiki/Rules.md already exists, skipping (user contract preserved)"
else
  echo "[wiki-install] Creating wiki/Rules.md..."
fi
```

If absent, Read this repo's `wiki/Rules.md` to get the canonical content, then Write it to `$CLAUDE_PROJECT_DIR/wiki/Rules.md`. After writing:

```bash
echo "[wiki-install] Created wiki/Rules.md"
```

Never overwrite an existing `wiki/Rules.md` — the user may have customized their rules contract.

## Step 4 — wiki/inbox/ directory (D-06)

Check whether the inbox directory exists:

```bash
if test -d "$CLAUDE_PROJECT_DIR/wiki/inbox"; then
  echo "[wiki-install] wiki/inbox/ already exists, skipping"
else
  mkdir -p "$CLAUDE_PROJECT_DIR/wiki/inbox"
  echo "[wiki-install] Created wiki/inbox/"
fi
```

## Step 4b — wiki/topic-index.md (recall navigation map)

Check whether the recall index exists:

```bash
if test -f "$CLAUDE_PROJECT_DIR/wiki/topic-index.md"; then
  echo "[wiki-install] wiki/topic-index.md already exists, skipping (user content preserved)"
else
  echo "[wiki-install] Creating wiki/topic-index.md..."
fi
```

If absent, Read this repo's `wiki/topic-index.md` to get the canonical (empty) seed, then Write it to `$CLAUDE_PROJECT_DIR/wiki/topic-index.md`. The seed contains only the front-matter and an HTML maintenance comment — it is auto-populated by `/digest` (curator Step 9) as notes accumulate.

After writing:

```bash
echo "[wiki-install] Created wiki/topic-index.md"
```

Never overwrite an existing `wiki/topic-index.md` — bullets the user has filed via prior digests would be lost.

## Step 5 — settings.json merge (D-07 three-case logic)

The hook entry to inject is:

```json
{
  "type": "command",
  "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/inbox-stop.sh",
  "timeout": 10
}
```

**Case A — settings.json absent:**

```bash
if test ! -f "$CLAUDE_PROJECT_DIR/.claude/settings.json"; then
  echo "[wiki-install] Creating .claude/settings.json with Stop + UserPromptSubmit hook entries..."
fi
```

Use Write to create `.claude/settings.json` with the full canonical structure (both hooks at once):

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/inbox-stop.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/recall-prompt.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

Then:

```bash
echo "[wiki-install] Created .claude/settings.json with Stop and UserPromptSubmit hook entries"
```

Skip Step 5b below — Case A already registered the recall hook.

**Case B — settings.json present, already has inbox-stop.sh entry:**

```bash
if grep -q "inbox-stop.sh" "$CLAUDE_PROJECT_DIR/.claude/settings.json"; then
  echo "[wiki-install] Stop hook already registered in settings.json, skipping (user hook preserved)"
fi
```

Skip entirely — do not add a duplicate.

**Case C — settings.json present, no inbox-stop.sh entry (merge needed):**

First check for jq:

```bash
if ! command -v jq >/dev/null 2>&1; then
  echo "[wiki-install] ABORT: jq is required to merge the Stop hook entry into your existing .claude/settings.json. Install jq and re-run /wiki-install, OR manually add the hook entry documented in .claude/skills/wiki-install/SETTINGS-SNIPPET.md"
  exit 1
fi
```

If jq is present, merge using `--arg` so the literal `$CLAUDE_PROJECT_DIR` token is preserved in JSON output (NOT shell-expanded). This preserves portability across machines — a hardcoded install-time path would break on every other developer's machine.

If `.hooks.Stop[0].hooks` already exists:

```bash
HOOK_CMD='"$CLAUDE_PROJECT_DIR"/.claude/hooks/inbox-stop.sh'
jq --arg cmd "$HOOK_CMD" '.hooks.Stop[0].hooks += [{"type":"command","command":$cmd,"timeout":10}]' \
  "$CLAUDE_PROJECT_DIR/.claude/settings.json" > /tmp/wiki-install-settings-tmp.json \
  && mv /tmp/wiki-install-settings-tmp.json "$CLAUDE_PROJECT_DIR/.claude/settings.json"
```

If `.hooks.Stop` key is absent (create it):

```bash
HOOK_CMD='"$CLAUDE_PROJECT_DIR"/.claude/hooks/inbox-stop.sh'
jq --arg cmd "$HOOK_CMD" '.hooks = (.hooks // {}) | .hooks.Stop = (.hooks.Stop // [{"hooks":[]}]) | .hooks.Stop[0].hooks += [{"type":"command","command":$cmd,"timeout":10}]' \
  "$CLAUDE_PROJECT_DIR/.claude/settings.json" > /tmp/wiki-install-settings-tmp.json \
  && mv /tmp/wiki-install-settings-tmp.json "$CLAUDE_PROJECT_DIR/.claude/settings.json"
```

**Verify after merge (B3 check):** Confirm the literal token survived — shell expansion would have written a hardcoded path that breaks portability:

```bash
if grep -q '"$CLAUDE_PROJECT_DIR"' "$CLAUDE_PROJECT_DIR/.claude/settings.json"; then
  echo "[wiki-install] Merged Stop hook entry into existing .claude/settings.json"
else
  echo "[wiki-install] ABORT: Post-merge verification failed — settings.json contains a hardcoded path instead of the literal \$CLAUDE_PROJECT_DIR token. Restore your original settings.json from backup and re-run /wiki-install."
  exit 1
fi
```

## Step 5b — settings.json: register UserPromptSubmit hook (recall)

If Case A from Step 5 ran (settings.json was created fresh), skip this step entirely — the recall hook is already registered.

Otherwise the file existed; check whether `recall-prompt.sh` is registered.

**Case B' — already registered:**

```bash
if grep -q "recall-prompt.sh" "$CLAUDE_PROJECT_DIR/.claude/settings.json"; then
  echo "[wiki-install] UserPromptSubmit hook already registered in settings.json, skipping (user hook preserved)"
fi
```

Skip — do not add a duplicate.

**Case C' — needs merge (jq required):**

```bash
if ! command -v jq >/dev/null 2>&1; then
  echo "[wiki-install] ABORT: jq is required to merge the UserPromptSubmit hook entry into your existing .claude/settings.json. Install jq and re-run /wiki-install, OR manually add the hook entry documented in .claude/skills/wiki-install/SETTINGS-SNIPPET.md"
  exit 1
fi
```

If `.hooks.UserPromptSubmit[0].hooks` already exists:

```bash
HOOK_CMD='"$CLAUDE_PROJECT_DIR"/.claude/hooks/recall-prompt.sh'
jq --arg cmd "$HOOK_CMD" '.hooks.UserPromptSubmit[0].hooks += [{"type":"command","command":$cmd,"timeout":10}]' \
  "$CLAUDE_PROJECT_DIR/.claude/settings.json" > /tmp/wiki-install-settings-tmp.json \
  && mv /tmp/wiki-install-settings-tmp.json "$CLAUDE_PROJECT_DIR/.claude/settings.json"
```

If `.hooks.UserPromptSubmit` key is absent (create it):

```bash
HOOK_CMD='"$CLAUDE_PROJECT_DIR"/.claude/hooks/recall-prompt.sh'
jq --arg cmd "$HOOK_CMD" '.hooks = (.hooks // {}) | .hooks.UserPromptSubmit = (.hooks.UserPromptSubmit // [{"hooks":[]}]) | .hooks.UserPromptSubmit[0].hooks += [{"type":"command","command":$cmd,"timeout":10}]' \
  "$CLAUDE_PROJECT_DIR/.claude/settings.json" > /tmp/wiki-install-settings-tmp.json \
  && mv /tmp/wiki-install-settings-tmp.json "$CLAUDE_PROJECT_DIR/.claude/settings.json"
```

**Verify after merge:** confirm the literal `$CLAUDE_PROJECT_DIR` token survived (same B3 check):

```bash
if grep -q '"$CLAUDE_PROJECT_DIR"/.claude/hooks/recall-prompt.sh' "$CLAUDE_PROJECT_DIR/.claude/settings.json"; then
  echo "[wiki-install] Merged UserPromptSubmit hook entry into existing .claude/settings.json"
else
  echo "[wiki-install] ABORT: Post-merge verification failed for UserPromptSubmit hook — settings.json may contain a hardcoded path. Restore your original settings.json from backup and re-run /wiki-install."
  exit 1
fi
```

## Step 6 — CLAUDE.md entry (D-09, D-10)

Check whether the section already exists:

```bash
if grep -q "## Auto-maintained wiki" "$CLAUDE_PROJECT_DIR/CLAUDE.md" 2>/dev/null; then
  echo "[wiki-install] CLAUDE.md already documents auto-wiki, skipping"
fi
```

If `CLAUDE.md` does not exist, create it containing only the section below (create mode). If `CLAUDE.md` exists but the section is absent, append the section (append mode).

The section to write or append:

```markdown

## Auto-maintained wiki

This project uses the llm-code-wiki system to keep a codebase wiki current without manual upkeep, and to recall prior decisions automatically when planning new work.

**Write path (capture):** A Stop hook (`inbox-stop.sh`) fires after each Claude assistant turn and nudges Claude to update `wiki/inbox/_session.md` — a state-of-the-world snapshot of what was built and decided this session. Run `/digest` manually to consolidate the inbox into filed wiki notes under `wiki/`.

**Read path (recall):** A UserPromptSubmit hook (`recall-prompt.sh`) detects planning-intent prompts and asks Claude to consult the wiki via the `wiki-recall` sub-agent before responding. The agent uses `wiki/topic-index.md` as a navigation map, greps the wiki for keywords, filters for relevance, and returns only the useful context. Run `/recall <query>` to invoke recall manually.

**Wiki contract:** `wiki/Rules.md` defines all conventions (category folders, filename kebab-case, note template, ≤25-word summaries, 1,000-word note cap, Obsidian wiki-link syntax, `topic-index.md` auto-maintenance). The curator never modifies `wiki/Rules.md` autonomously — rule-change suggestions surface as proposals.

**Explicit gaps (v1):** No real-time wiki sync, no auto-digest, no backfill from existing code, no wiki↔codebase reconciliation (`/reconcile` is deferred to v2). The inbox captures only what Claude edits in the current session.

**Quick reference:**
- Inbox: `wiki/inbox/_session.md`
- Topic index (recall map): `wiki/topic-index.md` (auto-maintained — do not edit by hand)
- Digest: run `/digest` at a review checkpoint
- Recall: run `/recall <query>` to consult the wiki on demand
- Rules contract: `wiki/Rules.md`
- Hook audit log: `.claude/inbox/.hook-log` (entries prefixed `recall:` are from the recall hook)
- Kill switches:
  - `touch .claude/inbox/.disabled` — disables the Stop hook (capture path)
  - `touch .claude/inbox/.recall-disabled` — disables the UserPromptSubmit hook (recall path)
  - `rm` either file to re-enable
```

After writing or appending:

```bash
echo "[wiki-install] Added Auto-maintained wiki section to CLAUDE.md"
# Or if created from scratch:
# echo "[wiki-install] Created CLAUDE.md with Auto-maintained wiki section"
```

## Step 7 — Smoke test (D-11)

Run three checks to verify the installation.

**Smoke test 1 — Hook executable check (B2 fix):**

The hook script uses `$CLAUDE_PROJECT_DIR` internally. When invoked via a bare bash pipe outside Claude Code, this variable must be exported explicitly — without it the hook fails silently and produces a false-pass. Synthesize a noop turn (no Edit/Write tool calls) so the hook follows the noop-detection branch:

```bash
export CLAUDE_PROJECT_DIR="$CLAUDE_PROJECT_DIR"
TRANSCRIPT=$(mktemp)
printf '{"role":"assistant","content":"hello"}\n' > "$TRANSCRIPT"
RESULT=$(echo "{\"transcript_path\":\"$TRANSCRIPT\",\"session_id\":\"wiki-install-test\",\"stop_hook_active\":false}" \
  | "$CLAUDE_PROJECT_DIR/.claude/hooks/inbox-stop.sh" 2>&1)
EXIT_CODE=$?
rm -f "$TRANSCRIPT"
# Noop-turn behavior: the hook exits 0 silently with empty stdout (no decision field).
# Evidence of execution = heartbeat appended to .hook-log (hook ALWAYS writes this per D-04, even on noop).
if [ -f "$CLAUDE_PROJECT_DIR/.claude/inbox/.hook-log" ] && tail -2 "$CLAUDE_PROJECT_DIR/.claude/inbox/.hook-log" | grep -q "wiki-install-test"; then
  echo "[wiki-install] Smoke test 1 PASS: Stop hook executed (heartbeat recorded for wiki-install-test session)"
elif [ $EXIT_CODE -ne 0 ]; then
  echo "[wiki-install] Smoke test 1 FAIL: Stop hook exited non-zero ($EXIT_CODE). Output: $RESULT"
  echo "[wiki-install] Check that .claude/hooks/inbox-stop.sh is executable and CLAUDE_PROJECT_DIR is set."
else
  echo "[wiki-install] Smoke test 1 FAIL: hook ran but did not write to .hook-log. Verify hook script integrity."
fi
```

Note: The original WARN-on-no-decision pattern produced a false-pass when `CLAUDE_PROJECT_DIR` was missing. This replacement checks heartbeat presence (which the hook ALWAYS writes per D-04, even on noop) and routes hook-run failures to FAIL — satisfying Pitfall 4's silent-failure mitigation.

**Smoke test 1b — Recall hook execution check:**

Synthesize a planning-intent prompt and pipe it through the recall hook. The hook should write a `recall:fire` line to `.hook-log` and emit a stdout block.

```bash
export CLAUDE_PROJECT_DIR="$CLAUDE_PROJECT_DIR"
RECALL_OUT=$(echo '{"session_id":"wiki-install-recall-test","prompt":"plan how to add a new feature"}' \
  | "$CLAUDE_PROJECT_DIR/.claude/hooks/recall-prompt.sh" 2>&1)
RECALL_EXIT=$?
if [ -f "$CLAUDE_PROJECT_DIR/.claude/inbox/.hook-log" ] && tail -5 "$CLAUDE_PROJECT_DIR/.claude/inbox/.hook-log" | grep -q "wiki-install-recall-test recall:fire"; then
  if echo "$RECALL_OUT" | grep -q "Wiki recall"; then
    echo "[wiki-install] Smoke test 1b PASS: UserPromptSubmit hook fired and emitted recall instruction"
  else
    echo "[wiki-install] Smoke test 1b WARN: hook fired but stdout didn't contain expected 'Wiki recall' block"
  fi
elif [ $RECALL_EXIT -ne 0 ]; then
  echo "[wiki-install] Smoke test 1b FAIL: recall hook exited non-zero ($RECALL_EXIT). Output: $RECALL_OUT"
else
  echo "[wiki-install] Smoke test 1b FAIL: hook ran but did not write recall:fire to .hook-log. Verify hook script integrity."
fi
```

**Smoke test 2 — Inbox writability:**

```bash
if touch "$CLAUDE_PROJECT_DIR/wiki/inbox/_session.md" 2>/dev/null; then
  echo "[wiki-install] Smoke test 2 PASS: wiki/inbox/_session.md is writable"
else
  echo "[wiki-install] Smoke test 2 FAIL: wiki/inbox/_session.md is not writable — check permissions"
fi
```

**Smoke test 3 — Install summary:**

Print a summary block listing what was created vs skipped for each deliverable, the smoke test outcomes, and the suggested next step:

```
[wiki-install] === Install Summary ===
[wiki-install] wiki/                            — (created | already existed)
[wiki-install] wiki/_templates/note.md          — (created | already existed)
[wiki-install] wiki/Rules.md                    — (created | already existed)
[wiki-install] wiki/inbox/                      — (created | already existed)
[wiki-install] wiki/topic-index.md              — (created | already existed)
[wiki-install] .claude/settings.json (Stop)     — (created | merged | hook already registered)
[wiki-install] .claude/settings.json (Recall)   — (created | merged | hook already registered)
[wiki-install] CLAUDE.md                        — (created | section appended | section already present)
[wiki-install] Smoke test 1 (Stop hook fires):  — (PASS | FAIL)
[wiki-install] Smoke test 1b (Recall hook):     — (PASS | WARN | FAIL)
[wiki-install] Smoke test 2 (inbox writable):   — (PASS | FAIL)
[wiki-install] === Next step: take a normal Claude turn that edits a file to see the Stop hook fire,
[wiki-install]                and ask Claude to plan something to see the recall hook fire. ===
```

## Logging discipline (D-12)

Every Bash-executed step prints its `[wiki-install] ...` outcome line. Steps that use Read/Write tools are followed by a Bash `echo "[wiki-install] ..."` confirmation so the user sees continuous progress. No step is silent.
