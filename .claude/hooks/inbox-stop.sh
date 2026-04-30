#!/usr/bin/env bash
# inbox-stop.sh — Stop hook for llm-code-wiki
# Fires at every assistant turn boundary; decides whether to nudge Claude to update the inbox.
# Implements the loop-protection trifecta (D-01, D-02, D-03), unconditional heartbeat (D-04),
# transcript pre-filter (D-05), and decision:block + reason delivery (D-10).
set -euo pipefail

# Ensure runtime state dir exists (heartbeat log, fire counter, kill switch).
# Idempotent; cheap; required because wiki-install does not pre-create this dir
# and the heartbeat log writes via `>>` which would fail without it.
mkdir -p "$CLAUDE_PROJECT_DIR/.claude/inbox"

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
# Caps at 2 actual fires per minute (session_id + minute boundary). The
# counter is read here and only incremented on the fire paths in Step 8 —
# noops (turncount-pending, brainstorm windows that haven't matured) do not
# consume the cap, so a long brainstorm can still reach the fallback fire.
# ---------------------------------------------------------------------------
TURN_KEY="${SESSION_ID}_$(date +%Y%m%d%H%M)"
COUNTER_FILE="$CLAUDE_PROJECT_DIR/.claude/inbox/.fire-counter"
CURRENT_FIRE_COUNT=0

if [ -f "$COUNTER_FILE" ]; then
  STORED=$(cat "$COUNTER_FILE")
  STORED_KEY=$(echo "$STORED" | awk '{print $1}')
  STORED_COUNT=$(echo "$STORED" | awk '{print $2}')
  if [ "$STORED_KEY" = "$TURN_KEY" ]; then
    CURRENT_FIRE_COUNT="${STORED_COUNT:-0}"
  fi
fi

if [ "$CURRENT_FIRE_COUNT" -ge 2 ]; then
  log_outcome "hard-cap"
  exit 0
fi

# Helper: bump fire counter (call only on actual fire paths).
bump_fire_counter() {
  local NEW_COUNT=$((CURRENT_FIRE_COUNT + 1))
  echo "$TURN_KEY $NEW_COUNT" > "$COUNTER_FILE"
}

# ---------------------------------------------------------------------------
# Step 6 — Brainstorm-only turn counter (D-04b)
# Increment a per-session counter that resets only on artifact-driven captures
# (Step 7 below) or on brainstorm-fallback fires. Used to trigger context-scan
# capture every N turns when no codebase artifacts have been produced.
# Cadence: $LCW_BRAINSTORM_TURNS (default 10).
# ---------------------------------------------------------------------------
N="${LCW_BRAINSTORM_TURNS:-10}"
case "$N" in
  ''|*[!0-9]*) N=10 ;;
esac
[ "$N" -lt 1 ] && N=10

TURN_COUNT_FILE="$CLAUDE_PROJECT_DIR/.claude/inbox/.turn-count"
TURN_COUNT=0
if [ -f "$TURN_COUNT_FILE" ]; then
  STORED_TC=$(cat "$TURN_COUNT_FILE")
  STORED_TC_KEY=$(echo "$STORED_TC" | awk '{print $1}')
  STORED_TC_COUNT=$(echo "$STORED_TC" | awk '{print $2}')
  if [ "$STORED_TC_KEY" = "$SESSION_ID" ]; then
    TURN_COUNT="${STORED_TC_COUNT:-0}"
  fi
fi
TURN_COUNT=$((TURN_COUNT + 1))
echo "$SESSION_ID $TURN_COUNT" > "$TURN_COUNT_FILE"

# ---------------------------------------------------------------------------
# Step 7 — Transcript inspection: detect codebase artifacts (D-05)
# ---------------------------------------------------------------------------
TRANSCRIPT=$(echo "$INPUT" | grep -o '"transcript_path"[[:space:]]*:[[:space:]]*"[^"]*"' | grep -o '"[^"]*"$' | tr -d '"')
HAS_ARTIFACTS=0
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  if grep -q '"name"[[:space:]]*:[[:space:]]*"\(Edit\|Write\|MultiEdit\)"' "$TRANSCRIPT" 2>/dev/null; then
    HAS_ARTIFACTS=1
  fi
fi

# ---------------------------------------------------------------------------
# Step 8 — Branch: normal capture / brainstorm-fallback / pending no-op (D-10)
# ---------------------------------------------------------------------------

if [ "$HAS_ARTIFACTS" -eq 1 ]; then
  # Normal capture — reset brainstorm counter so the next window is fresh.
  echo "$SESSION_ID 0" > "$TURN_COUNT_FILE"
  bump_fire_counter
  REASON="Update wiki/inbox/_session.md per .claude/skills/inbox-update/SKILL.md for this turn's work. Skip if only wiki/* files changed."
  printf '{"decision":"block","reason":"%s"}\n' "$REASON"
  log_outcome "fire turncount-reset-on-artifact"
  exit 0
fi

if [ "$TURN_COUNT" -ge "$N" ]; then
  # Brainstorm-fallback — reset counter and ask Claude to scan recent context.
  echo "$SESSION_ID 0" > "$TURN_COUNT_FILE"
  bump_fire_counter
  REASON="Brainstorm-fallback (no codebase artifacts in last $N turns): review the recent conversation for design decisions, requirements, named patterns, file paths agreed on, or trade-offs resolved that should be recorded in wiki/inbox/_session.md. Follow the Brainstorm-fallback mode section of .claude/skills/inbox-update/SKILL.md. Skip trivial chit-chat."
  printf '{"decision":"block","reason":"%s"}\n' "$REASON"
  log_outcome "turncount-fire $TURN_COUNT/$N"
  exit 0
fi

# Pending no-op — counter incremented, no artifacts, threshold not reached.
log_outcome "turncount-pending $TURN_COUNT/$N"
exit 0
