#!/usr/bin/env bash
# recall-prompt.sh — UserPromptSubmit hook for llm-code-wiki
# Fires on every user prompt; pre-filters for planning intent and injects a
# wiki-recall instruction into the prompt context via stdout.
#
# Mirrors the loop-protection scaffold of inbox-stop.sh: heartbeat log,
# kill switch, per-session+prompt-hash cooldown to prevent double-fire.
set -euo pipefail

# Ensure runtime state dir exists (heartbeat log, cooldown counter, kill switch).
mkdir -p "$CLAUDE_PROJECT_DIR/.claude/inbox"

# ---------------------------------------------------------------------------
# Step 1 — Read stdin (the UserPromptSubmit event JSON from Claude Code)
# ---------------------------------------------------------------------------
INPUT=$(cat)

# ---------------------------------------------------------------------------
# Helper: log_outcome — appends a timestamped outcome line to .hook-log
# ---------------------------------------------------------------------------
log_outcome() {
  local OUTCOME="$1"
  local TS
  TS=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)
  echo "$TS ${SESSION_ID:-unknown} recall:$OUTCOME" >> "$CLAUDE_PROJECT_DIR/.claude/inbox/.hook-log"
}

# ---------------------------------------------------------------------------
# Step 2 — Extract session_id and prompt
# ---------------------------------------------------------------------------
SESSION_ID=$(echo "$INPUT" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | grep -o '"[^"]*"$' | tr -d '"')
if [ -z "${SESSION_ID:-}" ]; then
  SESSION_ID="unknown"
fi

# Prompt extraction: UserPromptSubmit JSON contains a "prompt" field.
# Use python for safe JSON decoding (handles escaped quotes/newlines).
# Fallback to a best-effort grep if python is absent.
PROMPT=""
if command -v python3 >/dev/null 2>&1; then
  PROMPT=$(printf '%s' "$INPUT" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("prompt","") or d.get("user_prompt","") or "")' 2>/dev/null || true)
fi
if [ -z "$PROMPT" ]; then
  # Fallback: extract everything between "prompt":"..." — best effort, may miss edge cases.
  PROMPT=$(printf '%s' "$INPUT" | tr -d '\n' | grep -o '"prompt"[[:space:]]*:[[:space:]]*"[^"]*"' | sed -E 's/^"prompt"[[:space:]]*:[[:space:]]*"(.*)"$/\1/' || true)
fi

# Unconditional heartbeat (mirrors inbox-stop.sh D-04 pattern).
log_outcome "entering"

# ---------------------------------------------------------------------------
# Step 3 — Kill switch guard
# Presence of .recall-disabled disables the hook without editing settings.json.
# ---------------------------------------------------------------------------
if [ -f "$CLAUDE_PROJECT_DIR/.claude/inbox/.recall-disabled" ]; then
  log_outcome "kill-switch"
  exit 0
fi

# ---------------------------------------------------------------------------
# Step 4 — Cooldown guard (prevent double-fire on prompt retries)
# Keyed on session_id + prompt-hash. If we already fired for this exact
# prompt in this session, exit silently.
# ---------------------------------------------------------------------------
PROMPT_HASH=""
if [ -n "$PROMPT" ]; then
  if command -v sha1sum >/dev/null 2>&1; then
    PROMPT_HASH=$(printf '%s' "$PROMPT" | sha1sum | awk '{print $1}')
  elif command -v shasum >/dev/null 2>&1; then
    PROMPT_HASH=$(printf '%s' "$PROMPT" | shasum | awk '{print $1}')
  fi
fi

COOLDOWN_FILE="$CLAUDE_PROJECT_DIR/.claude/inbox/.recall-counter"
COOLDOWN_KEY="${SESSION_ID}:${PROMPT_HASH:-no-hash}"

if [ -n "$PROMPT_HASH" ] && [ -f "$COOLDOWN_FILE" ]; then
  if grep -qxF "$COOLDOWN_KEY" "$COOLDOWN_FILE" 2>/dev/null; then
    log_outcome "cooldown"
    exit 0
  fi
fi

# ---------------------------------------------------------------------------
# Step 5 — Pre-filter: planning-intent keyword match
# Only fire when the prompt looks like a request to plan, design, or modify
# code. Skip pure-conversation prompts.
# ---------------------------------------------------------------------------
if [ -z "$PROMPT" ]; then
  log_outcome "no-prompt"
  exit 0
fi

# Case-insensitive regex. Word-boundary matching via grep -E -i -w-style guards.
# Keywords chosen to cover planning intent without overfiring on conversation.
# NOTE: the injected stdout block must NOT contain these keywords — see Step 7.
if ! printf '%s' "$PROMPT" | grep -Eqi '(\b(plan|design|implement|build|refactor|architect|create|setup|integrate|migrate|introduce|fix|debug|extend|rework|rewrite|scaffold|bootstrap|wire up|hook up)\b|how (should|do|would|can) (we|i|you)|what.{0,20}(approach|strategy|pattern|architecture)|add (a|an|the|support for|feature)|write (a|an|the))'; then
  log_outcome "noop"
  exit 0
fi

# ---------------------------------------------------------------------------
# Step 6 — Skip if the prompt is wiki-only (avoid recursing during digest)
# If the prompt is asking to digest, file notes, or update the wiki itself,
# don't recall — the user is curating, not planning.
# ---------------------------------------------------------------------------
if printf '%s' "$PROMPT" | grep -Eqi '(\b(digest|inbox|curate|file (a |the )?note|wiki/inbox|topic-index)\b|/digest|/recall)'; then
  log_outcome "wiki-only"
  exit 0
fi

# ---------------------------------------------------------------------------
# Step 7 — Emit recall instruction to stdout
# UserPromptSubmit hook: stdout is appended to the prompt context.
# Wording deliberately avoids planning-intent keywords ("plan", "implement"...)
# to ensure the injected text itself can never re-trigger the pre-filter.
# ---------------------------------------------------------------------------
cat <<'EOF'

## Wiki recall

Before responding to the user's request above, consult the project wiki for prior decisions, architecture, and research that bear on this task. Spawn the wiki-recall sub-agent (read-only) and pass it the user's request verbatim. Use only the context the agent returns; ignore irrelevant matches it discards. If the agent reports nothing relevant, proceed without wiki context.
EOF

# Record this prompt as fired so retries don't double-recall.
if [ -n "$PROMPT_HASH" ]; then
  echo "$COOLDOWN_KEY" >> "$COOLDOWN_FILE"
fi

log_outcome "fire"
exit 0
