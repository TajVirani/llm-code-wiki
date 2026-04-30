#!/usr/bin/env bash
# inbox-stop.sh — Stop hook for llm-code-wiki
# Fires at every assistant turn boundary; decides whether to nudge Claude to update the inbox.
# Implements the loop-protection trifecta (D-01, D-02, D-03), unconditional heartbeat (D-04),
# transcript pre-filter (D-05), and decision:block + reason delivery (D-10).
set -euo pipefail

# ---------------------------------------------------------------------------
# Step 1 — Read stdin (the Stop event JSON from Claude Code)
# ---------------------------------------------------------------------------
INPUT=$(cat)

# ---------------------------------------------------------------------------
# Helper: log_outcome — appends a timestamped outcome line to .hook-log (D-04)
# Called both unconditionally (entering) and on each exit path.
# ---------------------------------------------------------------------------
log_outcome() {
  local OUTCOME="$1"
  local TS
  TS=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)
  echo "$TS ${SESSION_ID:-unknown} $OUTCOME" >> "$CLAUDE_PROJECT_DIR/.claude/inbox/.hook-log"
}

# ---------------------------------------------------------------------------
# Step 2 — Extract session_id (used in heartbeat + fire-counter key)
# ---------------------------------------------------------------------------
SESSION_ID=$(echo "$INPUT" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | grep -o '"[^"]*"$' | tr -d '"')
if [ -z "$SESSION_ID" ]; then
  SESSION_ID="unknown"
fi

# ---------------------------------------------------------------------------
# Step 2 (continued) — Unconditional heartbeat (D-04)
# Writes BEFORE any guards so silent exits are still visible in the log.
# ---------------------------------------------------------------------------
log_outcome "entering"

# ---------------------------------------------------------------------------
# Step 3 — stop_hook_active guard (D-01)
# If Claude is already in a forced-continuation cycle, exit immediately.
# ---------------------------------------------------------------------------
if echo "$INPUT" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  log_outcome "stop-hook-active"
  exit 0
fi

# ---------------------------------------------------------------------------
# Step 4 — Kill switch guard (D-02)
# Presence of .disabled file disables the hook without editing settings.json.
# ---------------------------------------------------------------------------
if [ -f "$CLAUDE_PROJECT_DIR/.claude/inbox/.disabled" ]; then
  log_outcome "kill-switch"
  exit 0
fi

# ---------------------------------------------------------------------------
# Step 5 — Hard cap guard (D-03)
# Tracks fires per "turn" (session_id + minute boundary).
# Caps at 2 fires; resets automatically on a new turn.
# ---------------------------------------------------------------------------
TURN_KEY="${SESSION_ID}_$(date +%Y%m%d%H%M)"
COUNTER_FILE="$CLAUDE_PROJECT_DIR/.claude/inbox/.fire-counter"

if [ -f "$COUNTER_FILE" ]; then
  STORED=$(cat "$COUNTER_FILE")
  STORED_KEY=$(echo "$STORED" | awk '{print $1}')
  STORED_COUNT=$(echo "$STORED" | awk '{print $2}')

  if [ "$STORED_KEY" = "$TURN_KEY" ]; then
    if [ "${STORED_COUNT:-0}" -ge 2 ]; then
      log_outcome "hard-cap"
      exit 0
    else
      NEW_COUNT=$((STORED_COUNT + 1))
      echo "$TURN_KEY $NEW_COUNT" > "$COUNTER_FILE"
    fi
  else
    # New turn — reset counter to 1 (this is the first fire for this turn)
    echo "$TURN_KEY 1" > "$COUNTER_FILE"
  fi
else
  # First ever fire — create counter file
  echo "$TURN_KEY 1" > "$COUNTER_FILE"
fi

# ---------------------------------------------------------------------------
# Step 6 — Transcript pre-filter (D-05)
# If the transcript contains no Edit/Write/MultiEdit tool calls, this turn
# produced no codebase artifacts — silently no-op.
# ---------------------------------------------------------------------------
TRANSCRIPT=$(echo "$INPUT" | grep -o '"transcript_path"[[:space:]]*:[[:space:]]*"[^"]*"' | grep -o '"[^"]*"$' | tr -d '"')

if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  if ! grep -q '"name"[[:space:]]*:[[:space:]]*"\(Edit\|Write\|MultiEdit\)"' "$TRANSCRIPT" 2>/dev/null; then
    log_outcome "noop"
    exit 0
  fi
fi

# ---------------------------------------------------------------------------
# Step 7 — Emit decision:block + reason (D-10)
# The reason text nudges Claude to run the inbox-update skill (D-06).
# "Skip if only wiki/* files changed" guards against digest cascade (D-08).
# Reason is under 200 chars (verified: ~151 chars).
# ---------------------------------------------------------------------------
REASON="Update wiki/inbox/_session.md per .claude/skills/inbox-update/SKILL.md for this turn's work. Skip if only wiki/* files changed."
printf '{"decision":"block","reason":"%s"}\n' "$REASON"
log_outcome "fire"
