---
name: wiki-install
description: Bootstrap a project to use the auto-wiki system. Verifies the .claude/ tree is in place, materializes wiki/ scaffolding (inbox, topic-index seed), merges Stop + UserPromptSubmit hooks into .claude/settings.json, appends an Auto-maintained wiki section to CLAUDE.md, runs hook smoke tests, and stamps the installed version. Idempotent — re-running is safe and converges to the canonical state. Run once after the .claude/ tree is in place.
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Edit, Glob, Bash
---

# /wiki-install — Bootstrap the auto-wiki system

Run this skill once after the `.claude/` tree (skills, agents, hooks, install templates) has been copied into the target project (via plugin install, `/wiki-update` from a prior version, or the remote-install manifest fetch in INSTALL.md). It creates the `wiki/` scaffolding, merges hook entries into `.claude/settings.json`, appends a documentation section to `CLAUDE.md`, runs smoke tests, and stamps the installed version.

**Design:** five Bash blocks, zero Write/Edit calls. All static content is sourced from shipped template files under `.claude/skills/wiki-install/templates/` rather than inlined-then-Written, which collapses the install to ~5 permission prompts (down from ~20). Re-runs are idempotent: settings.json is upserted (existing matching hook entries are removed and re-added with canonical content), CLAUDE.md skips when the section is already present, and `wiki/` files use skip-if-exists semantics so user customizations are preserved.

The two **user-meaningful** approval prompts are Block 2 (settings.json merge) and Block 3 (CLAUDE.md append). The other three blocks are mechanical and can be allowlisted via Claude Code's permission system.

## Block 1 — Precondition + scaffold creation

Verifies the required `.claude/` files are present and both hooks are executable, then materializes the `wiki/` scaffolding. Aborts with a clear "re-run remote install" pointer if any required file is missing — there is no inline fallback content (templates ship via `dist-manifest.txt`).

```bash
set -e

STATUS_FILE=/tmp/lcw-install-status.txt
: > "$STATUS_FILE"
record() { printf '%s=%s\n' "$1" "$2" >> "$STATUS_FILE"; }

# --- Precondition: required .claude/ files + executable hooks ---
for f in \
  "$CLAUDE_PROJECT_DIR/.claude/skills/inbox-update/SKILL.md" \
  "$CLAUDE_PROJECT_DIR/.claude/skills/wiki-digest/SKILL.md" \
  "$CLAUDE_PROJECT_DIR/.claude/skills/wiki-recall/SKILL.md" \
  "$CLAUDE_PROJECT_DIR/.claude/skills/wiki-modules/SKILL.md" \
  "$CLAUDE_PROJECT_DIR/.claude/skills/wiki-install/templates/CLAUDE-MD-SECTION.md" \
  "$CLAUDE_PROJECT_DIR/.claude/skills/wiki-install/templates/topic-index.seed.md" \
  "$CLAUDE_PROJECT_DIR/.claude/agents/wiki-curator.md" \
  "$CLAUDE_PROJECT_DIR/.claude/agents/wiki-recall.md" \
  "$CLAUDE_PROJECT_DIR/.claude/hooks/inbox-stop.sh" \
  "$CLAUDE_PROJECT_DIR/.claude/hooks/recall-prompt.sh"; do
  test -f "$f" || { echo "[wiki-install] ABORT: $f not found. Re-run remote install (INSTALL.md) or copy the .claude/ tree."; exit 1; }
done
test -x "$CLAUDE_PROJECT_DIR/.claude/hooks/inbox-stop.sh" || \
  { echo "[wiki-install] ABORT: inbox-stop.sh not executable. Run: chmod +x .claude/hooks/inbox-stop.sh"; exit 1; }
test -x "$CLAUDE_PROJECT_DIR/.claude/hooks/recall-prompt.sh" || \
  { echo "[wiki-install] ABORT: recall-prompt.sh not executable. Run: chmod +x .claude/hooks/recall-prompt.sh"; exit 1; }
echo "[wiki-install] Precondition check passed."

# --- wiki/ ---
if [ -d "$CLAUDE_PROJECT_DIR/wiki" ]; then
  record WIKI_DIR "already existed"
  echo "[wiki-install] wiki/ exists, skipping"
else
  mkdir -p "$CLAUDE_PROJECT_DIR/wiki"
  record WIKI_DIR "created"
  echo "[wiki-install] Created wiki/"
fi

# --- wiki/_templates/note.md (must already exist via manifest fetch) ---
mkdir -p "$CLAUDE_PROJECT_DIR/wiki/_templates"
if [ -f "$CLAUDE_PROJECT_DIR/wiki/_templates/note.md" ]; then
  record NOTE_TPL "already existed"
  echo "[wiki-install] wiki/_templates/note.md exists, skipping (user customization preserved)"
else
  echo "[wiki-install] ABORT: wiki/_templates/note.md missing. Re-run remote install (manifest places this file)."
  exit 1
fi

# --- wiki/Rules.md (must already exist via manifest fetch) ---
if [ -f "$CLAUDE_PROJECT_DIR/wiki/Rules.md" ]; then
  record RULES "already existed"
  echo "[wiki-install] wiki/Rules.md exists, skipping (user contract preserved)"
else
  echo "[wiki-install] ABORT: wiki/Rules.md missing. Re-run remote install (manifest places this file)."
  exit 1
fi

# --- wiki/inbox/ ---
if [ -d "$CLAUDE_PROJECT_DIR/wiki/inbox" ]; then
  record INBOX "already existed"
  echo "[wiki-install] wiki/inbox/ exists, skipping"
else
  mkdir -p "$CLAUDE_PROJECT_DIR/wiki/inbox"
  record INBOX "created"
  echo "[wiki-install] Created wiki/inbox/"
fi

# --- wiki/MODULES/ (orientation layer; populated by digest, never preseeded) ---
if [ -d "$CLAUDE_PROJECT_DIR/wiki/MODULES" ]; then
  record MODULES_DIR "already existed"
  echo "[wiki-install] wiki/MODULES/ exists, skipping"
else
  mkdir -p "$CLAUDE_PROJECT_DIR/wiki/MODULES"
  record MODULES_DIR "created"
  echo "[wiki-install] Created wiki/MODULES/"
fi

# --- wiki/topic-index.md (materialized from shipped seed template) ---
SEED="$CLAUDE_PROJECT_DIR/.claude/skills/wiki-install/templates/topic-index.seed.md"
if [ -f "$CLAUDE_PROJECT_DIR/wiki/topic-index.md" ]; then
  record TOPIC_INDEX "already existed"
  echo "[wiki-install] wiki/topic-index.md exists, skipping (user content preserved)"
else
  TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  sed -e "s|<<CREATED_TS>>|$TS|g" -e "s|<<UPDATED_TS>>|$TS|g" "$SEED" \
    > "$CLAUDE_PROJECT_DIR/wiki/topic-index.md"
  record TOPIC_INDEX "created"
  echo "[wiki-install] Created wiki/topic-index.md from seed template"
fi
```

## Block 2 — settings.json merge (Stop + UserPromptSubmit + default permissions)

Registers both hooks in `.claude/settings.json` and seeds a small default `permissions.allow` set so the auto-wiki write path doesn't prompt the user for every `_session.md` edit. Case A (file absent) writes a fresh canonical structure via heredoc. Case B/C (file present) requires `jq` and runs parametrized `upsert_hook` and `upsert_permission` filters — each removes any existing matching entries and appends the canonical entry, so re-runs converge to a zero-content-diff. The literal `$CLAUDE_PROJECT_DIR` token must survive (B3 verification) — shell expansion would write a hardcoded install-time path that breaks portability.

**Default permissions seeded** (the inbox capture path writes to this file every Stop-hook fire; without these, every turn that produces a code edit would prompt for `_session.md` write approval):
- `Read(wiki/inbox/_session.md)`
- `Edit(wiki/inbox/_session.md)`
- `Write(wiki/inbox/_session.md)`

**This block writes to `.claude/settings.json` — the user's settings-merge approval prompt.**

```bash
set -e
SETTINGS="$CLAUDE_PROJECT_DIR/.claude/settings.json"
STATUS_FILE=/tmp/lcw-install-status.txt
record() { printf '%s=%s\n' "$1" "$2" >> "$STATUS_FILE"; }

# Default permissions seeded on every install (idempotent — already-present entries are skipped)
DEFAULT_PERMS=(
  "Read(wiki/inbox/_session.md)"
  "Edit(wiki/inbox/_session.md)"
  "Write(wiki/inbox/_session.md)"
)

if [ ! -f "$SETTINGS" ]; then
  # Case A: file absent — create fresh with both hooks + default permissions (no jq needed)
  mkdir -p "$(dirname "$SETTINGS")"
  cat > "$SETTINGS" <<'JSON'
{
  "permissions": {
    "allow": [
      "Read(wiki/inbox/_session.md)",
      "Edit(wiki/inbox/_session.md)",
      "Write(wiki/inbox/_session.md)"
    ]
  },
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
JSON
  record SETTINGS_STOP "created"
  record SETTINGS_RECALL "created"
  record SETTINGS_PERMS "created (3 entries)"
  echo "[wiki-install] Created .claude/settings.json with Stop + UserPromptSubmit hook entries and default _session.md permissions."
else
  # Case B/C: file exists — require jq, then upsert each hook + permission idempotently
  if ! command -v jq >/dev/null 2>&1; then
    echo "[wiki-install] ABORT: jq required to merge .claude/settings.json. Install jq, OR apply the manual snippet from .claude/skills/wiki-install/SETTINGS-SNIPPET.md and re-run."
    exit 1
  fi

  # Detect prior state for status reporting before mutating
  if grep -q "inbox-stop.sh" "$SETTINGS"; then STATUS_STOP="re-merged (replaced existing)"; else STATUS_STOP="merged"; fi
  if grep -q "recall-prompt.sh" "$SETTINGS"; then STATUS_RECALL="re-merged (replaced existing)"; else STATUS_RECALL="merged"; fi

  # Helper: upsert one hook entry (event=Stop|UserPromptSubmit, script=basename used in `contains`, cmd=literal command string)
  upsert_hook() {
    local event="$1" script="$2" cmd="$3"
    jq --arg event "$event" --arg script "$script" --arg cmd "$cmd" '
      .hooks //= {}
      | .hooks[$event] //= [{"hooks":[]}]
      | .hooks[$event] |= (
          map(.hooks |= (map(select((.command // "") | contains($script) | not))))
        )
      | (.hooks[$event][0].hooks //= [])
      | .hooks[$event][0].hooks += [{"type":"command","command":$cmd,"timeout":10}]
    ' "$SETTINGS" > /tmp/lcw-settings.json && mv /tmp/lcw-settings.json "$SETTINGS"
  }

  # Helper: upsert one permission string into .permissions.allow (skip if already present — preserves user-added entries)
  upsert_permission() {
    local perm="$1"
    jq --arg perm "$perm" '
      .permissions //= {}
      | .permissions.allow //= []
      | if (.permissions.allow | index($perm)) then . else .permissions.allow += [$perm] end
    ' "$SETTINGS" > /tmp/lcw-settings.json && mv /tmp/lcw-settings.json "$SETTINGS"
  }

  upsert_hook "Stop" "inbox-stop.sh" '"$CLAUDE_PROJECT_DIR"/.claude/hooks/inbox-stop.sh'
  upsert_hook "UserPromptSubmit" "recall-prompt.sh" '"$CLAUDE_PROJECT_DIR"/.claude/hooks/recall-prompt.sh'

  PERMS_ADDED=0
  for perm in "${DEFAULT_PERMS[@]}"; do
    if grep -Fq "$perm" "$SETTINGS"; then continue; fi
    upsert_permission "$perm"
    PERMS_ADDED=$((PERMS_ADDED + 1))
  done

  # B3 verification: literal $CLAUDE_PROJECT_DIR token must survive in both entries.
  # JSON escapes the surrounding quotes (\"$CLAUDE_PROJECT_DIR\"), so use grep -F
  # with the escaped form to byte-match what jq actually wrote.
  if grep -qF '\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/inbox-stop.sh' "$SETTINGS" \
     && grep -qF '\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/recall-prompt.sh' "$SETTINGS"; then
    record SETTINGS_STOP "$STATUS_STOP"
    record SETTINGS_RECALL "$STATUS_RECALL"
    if [ "$PERMS_ADDED" -eq 0 ]; then
      record SETTINGS_PERMS "already present"
    else
      record SETTINGS_PERMS "added $PERMS_ADDED entr$([ "$PERMS_ADDED" -eq 1 ] && echo y || echo ies)"
    fi
    if [ "$PERMS_ADDED" -eq 0 ]; then
      echo "[wiki-install] settings.json: Stop hook $STATUS_STOP; UserPromptSubmit hook $STATUS_RECALL; default permissions already present."
    else
      echo "[wiki-install] settings.json: Stop hook $STATUS_STOP; UserPromptSubmit hook $STATUS_RECALL; added $PERMS_ADDED default permission entr$([ "$PERMS_ADDED" -eq 1 ] && echo y || echo ies)."
    fi
  else
    echo "[wiki-install] ABORT: post-merge verification failed — \$CLAUDE_PROJECT_DIR token missing from settings.json. Restore from backup and re-run."
    exit 1
  fi
fi
```

**No-jq fallback:** if `jq` is unavailable and the user can't install it, follow `.claude/skills/wiki-install/SETTINGS-SNIPPET.md` to apply the merge by hand, then re-run `/wiki-install`.

## Block 3 — CLAUDE.md section append

Appends the canonical "## Auto-maintained wiki" section from `.claude/skills/wiki-install/templates/CLAUDE-MD-SECTION.md`. Three branches: no `CLAUDE.md` → create with section; `CLAUDE.md` exists, section absent → append; `CLAUDE.md` exists, section present → skip. Install-time only ever appends — `/wiki-update` is the path that actively replaces the section.

**This block writes to `CLAUDE.md` — the user's CLAUDE.md-append approval prompt.**

```bash
set -e
CLAUDE_MD="$CLAUDE_PROJECT_DIR/CLAUDE.md"
SECTION_TPL="$CLAUDE_PROJECT_DIR/.claude/skills/wiki-install/templates/CLAUDE-MD-SECTION.md"
STATUS_FILE=/tmp/lcw-install-status.txt
record() { printf '%s=%s\n' "$1" "$2" >> "$STATUS_FILE"; }

if [ ! -f "$SECTION_TPL" ]; then
  echo "[wiki-install] ABORT: canonical CLAUDE.md section template missing at $SECTION_TPL."
  echo "[wiki-install] Re-run remote install (manifest places this file)."
  exit 1
fi

if [ ! -f "$CLAUDE_MD" ]; then
  cat "$SECTION_TPL" > "$CLAUDE_MD"
  record CLAUDE_MD "created"
  echo "[wiki-install] Created CLAUDE.md with Auto-maintained wiki section."
elif grep -q '^## Auto-maintained wiki[[:space:]]*$' "$CLAUDE_MD"; then
  record CLAUDE_MD "section already present"
  echo "[wiki-install] CLAUDE.md already documents auto-wiki, skipping."
else
  printf '\n' >> "$CLAUDE_MD"
  cat "$SECTION_TPL" >> "$CLAUDE_MD"
  record CLAUDE_MD "section appended"
  echo "[wiki-install] Appended Auto-maintained wiki section to CLAUDE.md."
fi
```

## Block 4 — Smoke tests + version stamp

Three smoke tests verify hook execution and inbox writability, then the installed version is stamped. Any FAIL outcome aborts the skill with `exit 1` so the final summary block does not run.

- **Smoke 1 — Stop hook fires:** synthesizes a noop turn (no Edit/Write tool calls) so the hook follows the noop-detection branch. Evidence of execution = heartbeat appended to `.hook-log` (the hook ALWAYS writes this per D-04, even on noop). Replaces an earlier WARN-on-no-decision pattern that produced false-passes when `CLAUDE_PROJECT_DIR` was missing.
- **Smoke 1b — Recall hook fires:** synthesizes a planning-intent prompt and pipes it through the recall hook. Expects `recall:fire` in `.hook-log` and a `Wiki recall` block on stdout.
- **Smoke 2 — Inbox writable:** `touch wiki/inbox/_session.md`.

```bash
set +e  # smoke tests must continue past failures to report all outcomes
STATUS_FILE=/tmp/lcw-install-status.txt
record() { printf '%s=%s\n' "$1" "$2" >> "$STATUS_FILE"; }

export CLAUDE_PROJECT_DIR="$CLAUDE_PROJECT_DIR"

# --- Smoke 1: Stop hook fires (heartbeat-based) ---
TRANSCRIPT=$(mktemp)
printf '{"role":"assistant","content":"hello"}\n' > "$TRANSCRIPT"
RESULT=$(echo "{\"transcript_path\":\"$TRANSCRIPT\",\"session_id\":\"wiki-install-test\",\"stop_hook_active\":false}" \
  | "$CLAUDE_PROJECT_DIR/.claude/hooks/inbox-stop.sh" 2>&1)
EXIT_CODE=$?
rm -f "$TRANSCRIPT"
if [ -f "$CLAUDE_PROJECT_DIR/.claude/inbox/.hook-log" ] && tail -2 "$CLAUDE_PROJECT_DIR/.claude/inbox/.hook-log" | grep -q "wiki-install-test"; then
  record SMOKE_1 "PASS"
  echo "[wiki-install] Smoke 1 PASS: Stop hook fired (heartbeat recorded)."
elif [ $EXIT_CODE -ne 0 ]; then
  record SMOKE_1 "FAIL"
  echo "[wiki-install] Smoke 1 FAIL: Stop hook exit=$EXIT_CODE. Output: $RESULT"
else
  record SMOKE_1 "FAIL"
  echo "[wiki-install] Smoke 1 FAIL: hook ran but no .hook-log heartbeat. Verify hook script integrity."
fi

# --- Smoke 1b: Recall hook fires ---
RECALL_OUT=$(echo '{"session_id":"wiki-install-recall-test","prompt":"plan how to add a new feature"}' \
  | "$CLAUDE_PROJECT_DIR/.claude/hooks/recall-prompt.sh" 2>&1)
RECALL_EXIT=$?
if [ -f "$CLAUDE_PROJECT_DIR/.claude/inbox/.hook-log" ] && tail -5 "$CLAUDE_PROJECT_DIR/.claude/inbox/.hook-log" | grep -q "wiki-install-recall-test recall:fire"; then
  if echo "$RECALL_OUT" | grep -q "Wiki recall"; then
    record SMOKE_1B "PASS"
    echo "[wiki-install] Smoke 1b PASS: recall hook fired and emitted Wiki recall block."
  else
    record SMOKE_1B "WARN"
    echo "[wiki-install] Smoke 1b WARN: hook fired but stdout missing 'Wiki recall' block."
  fi
elif [ $RECALL_EXIT -ne 0 ]; then
  record SMOKE_1B "FAIL"
  echo "[wiki-install] Smoke 1b FAIL: recall hook exit=$RECALL_EXIT. Output: $RECALL_OUT"
else
  record SMOKE_1B "FAIL"
  echo "[wiki-install] Smoke 1b FAIL: hook ran but no recall:fire in .hook-log."
fi

# --- Smoke 2: inbox writable ---
if touch "$CLAUDE_PROJECT_DIR/wiki/inbox/_session.md" 2>/dev/null; then
  record SMOKE_2 "PASS"
  echo "[wiki-install] Smoke 2 PASS: wiki/inbox/_session.md writable."
else
  record SMOKE_2 "FAIL"
  echo "[wiki-install] Smoke 2 FAIL: wiki/inbox/_session.md not writable — check filesystem permissions."
fi

# --- Version stamp ---
if [ -f "$CLAUDE_PROJECT_DIR/VERSION" ]; then
  cp "$CLAUDE_PROJECT_DIR/VERSION" "$CLAUDE_PROJECT_DIR/.claude/llm-code-wiki.version"
  V=$(cat "$CLAUDE_PROJECT_DIR/.claude/llm-code-wiki.version")
  record VERSION_STAMP "$V"
  echo "[wiki-install] Stamped version: $V"
else
  record VERSION_STAMP "unknown — VERSION absent"
  echo "[wiki-install] WARN: VERSION file absent; /wiki-update will treat install as version-unknown."
fi

# Hard-fail on any FAIL outcome from smoke 1/1b/2 (constraint: failures must abort)
if grep -qE '^(SMOKE_1|SMOKE_1B|SMOKE_2)=FAIL$' "$STATUS_FILE"; then
  echo "[wiki-install] ABORT: one or more smoke tests failed. Review messages above."
  exit 1
fi
```

## Block 5 — Final install summary

Reads the per-step status file and prints a single summary block so the user sees the install outcome at a glance regardless of intermediate output.

```bash
STATUS_FILE=/tmp/lcw-install-status.txt
get() { grep "^$1=" "$STATUS_FILE" | head -1 | cut -d= -f2-; }

cat <<EOF
[wiki-install] === Install Summary ===
[wiki-install] wiki/                             — $(get WIKI_DIR)
[wiki-install] wiki/_templates/note.md           — $(get NOTE_TPL)
[wiki-install] wiki/Rules.md                     — $(get RULES)
[wiki-install] wiki/inbox/                       — $(get INBOX)
[wiki-install] wiki/MODULES/                     — $(get MODULES_DIR)
[wiki-install] wiki/topic-index.md               — $(get TOPIC_INDEX)
[wiki-install] settings.json (Stop)              — $(get SETTINGS_STOP)
[wiki-install] settings.json (UserPromptSubmit)  — $(get SETTINGS_RECALL)
[wiki-install] settings.json (default perms)     — $(get SETTINGS_PERMS)
[wiki-install] CLAUDE.md                         — $(get CLAUDE_MD)
[wiki-install] Version stamp                     — $(get VERSION_STAMP)
[wiki-install] Smoke 1  (Stop hook fires)        — $(get SMOKE_1)
[wiki-install] Smoke 1b (Recall hook fires)      — $(get SMOKE_1B)
[wiki-install] Smoke 2  (inbox writable)         — $(get SMOKE_2)
[wiki-install] === Next: edit a file → see Stop hook fire; ask Claude to plan → see recall fire. ===
EOF
rm -f "$STATUS_FILE"
```

## Notes for the executor

- **Tool-call shape:** five `Bash` invocations, zero `Write` and zero `Edit` invocations. The `cat` operations in Blocks 3/5 happen inside Bash — no tool transition. This is the design that drops install permission prompts from ~20 to 5.
- **Status file:** `/tmp/lcw-install-status.txt` carries per-step outcomes across blocks (each Bash invocation is a fresh shell, so shell variables don't survive). The path is fixed; concurrent installs from different projects on the same machine could race on it (acceptable for single-developer tooling — there's no other concurrent-install protection in v1).
- **Idempotence:** re-running on a complete install reports "already existed" / "section already present" / "re-merged (replaced existing)" with a zero-content-diff on settings.json. Smoke tests run again (stateless aside from `.hook-log` heartbeat appends).
- **Backward-compat with old installs:** users who installed via the previous 7-step skill will, on next `/wiki-update`, fetch the new template files and the new SKILL.md. Subsequent `/wiki-install` runs follow the new flow without any migration step.
- **Skill/agent name collisions:** if the target had pre-existing skills named `wiki-install`, `inbox-update`, `wiki-digest`, `wiki-recall`, `wiki-rules`, or agents named `wiki-curator` / `wiki-recall`, they would have been overwritten by the upstream copy step (plugin install, manual copy, marketplace, etc.). The distribution mechanism is responsible for surfacing those collisions. Block 1's precondition check only verifies the required files are present and hooks are executable.
