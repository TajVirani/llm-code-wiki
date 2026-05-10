#!/usr/bin/env bash
# tests/hooks.sh — L2 hook unit tests.
# Each test runs in a fresh fixture dir with CLAUDE_PROJECT_DIR set, so per-session
# state files (.hook-log, .turn-count, .fire-counter, .recall-counter) don't leak
# between tests.
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
# shellcheck source=lib/assert.sh
. "$TESTS_DIR/lib/assert.sh"

start_layer "L2 hook unit tests"

INBOX_STOP="$REPO_ROOT/.claude/hooks/inbox-stop.sh"
RECALL="$REPO_ROOT/.claude/hooks/recall-prompt.sh"

if [ ! -x "$INBOX_STOP" ]; then fail "inbox-stop.sh executable" "$INBOX_STOP not executable"; finish_layer; fi
if [ ! -x "$RECALL" ]; then fail "recall-prompt.sh executable" "$RECALL not executable"; finish_layer; fi

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------
make_fixture() {
  local d
  d=$(mktemp -d -t lcw-hook-XXXXXX)
  mkdir -p "$d/.claude/inbox" "$d/wiki/inbox"
  echo "$d"
}

# Build a fake transcript file. Args: PATH, ARTIFACT (yes|no)
make_transcript() {
  local path="$1" artifact="$2"
  if [ "$artifact" = "yes" ]; then
    cat > "$path" <<'JSON'
{"role":"assistant","content":[{"type":"tool_use","name":"Edit","input":{"file_path":"/tmp/foo"}}]}
JSON
  else
    cat > "$path" <<'JSON'
{"role":"assistant","content":[{"type":"text","text":"hello world"}]}
JSON
  fi
}

# Run inbox-stop.sh with a synthesized JSON event. Args: FIXTURE, SESSION_ID, ARTIFACT (yes|no), STOP_HOOK_ACTIVE (true|false)
# Returns: stdout in $LAST_STDOUT, exit code in $LAST_EXIT.
run_inbox_stop() {
  local fixture="$1" sid="$2" artifact="$3" sha="${4:-false}"
  local transcript="$fixture/transcript.json"
  make_transcript "$transcript" "$artifact"
  local payload
  payload=$(printf '{"transcript_path":"%s","session_id":"%s","stop_hook_active":%s}' "$transcript" "$sid" "$sha")
  LAST_STDOUT=$(CLAUDE_PROJECT_DIR="$fixture" printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$fixture" "$INBOX_STOP" 2>&1)
  LAST_EXIT=$?
}

# Run recall-prompt.sh with a synthesized JSON event. Args: FIXTURE, SESSION_ID, PROMPT
run_recall() {
  local fixture="$1" sid="$2" prompt="$3"
  # JSON-escape the prompt's quotes/backslashes minimally
  local esc
  esc=$(printf '%s' "$prompt" | sed 's/\\/\\\\/g; s/"/\\"/g')
  local payload
  payload=$(printf '{"session_id":"%s","prompt":"%s"}' "$sid" "$esc")
  LAST_STDOUT=$(CLAUDE_PROJECT_DIR="$fixture" printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$fixture" "$RECALL" 2>&1)
  LAST_EXIT=$?
}

assert_log_contains() {
  local fixture="$1" needle="$2" msg="$3"
  local log="$fixture/.claude/inbox/.hook-log"
  if [ ! -f "$log" ]; then fail "$msg" ".hook-log not created"; return; fi
  if grep -qF -- "$needle" "$log"; then pass "$msg"; else fail "$msg" "no '$needle' in: $(tail -3 "$log")"; fi
}

# ---------------------------------------------------------------------------
# inbox-stop.sh — Test 1: stop_hook_active=true short-circuits
# ---------------------------------------------------------------------------
F=$(make_fixture)
run_inbox_stop "$F" "test-stopactive" "no" "true"
expect_eq "$LAST_EXIT" "0" "inbox-stop: stop_hook_active=true exits 0"
assert_log_contains "$F" "stop-hook-active" "inbox-stop: stop_hook_active logs 'stop-hook-active'"
expect_eq "$LAST_STDOUT" "" "inbox-stop: stop_hook_active produces no stdout"

# ---------------------------------------------------------------------------
# inbox-stop.sh — Test 2: kill switch
# ---------------------------------------------------------------------------
F=$(make_fixture)
touch "$F/.claude/inbox/.disabled"
run_inbox_stop "$F" "test-killswitch" "yes" "false"
expect_eq "$LAST_EXIT" "0" "inbox-stop: kill switch exits 0"
assert_log_contains "$F" "kill-switch" "inbox-stop: kill switch logs 'kill-switch'"
expect_eq "$LAST_STDOUT" "" "inbox-stop: kill switch produces no stdout (no decision)"

# ---------------------------------------------------------------------------
# inbox-stop.sh — Test 3: noop turn (no artifacts) → turncount-pending
# ---------------------------------------------------------------------------
F=$(make_fixture)
run_inbox_stop "$F" "test-noop" "no" "false"
expect_eq "$LAST_EXIT" "0" "inbox-stop: noop turn exits 0"
assert_log_contains "$F" "turncount-pending 1/" "inbox-stop: noop turn logs turncount-pending 1/N"
expect_eq "$LAST_STDOUT" "" "inbox-stop: noop turn produces no stdout"

# ---------------------------------------------------------------------------
# inbox-stop.sh — Test 4: artifact turn → fires + resets turn counter
# ---------------------------------------------------------------------------
F=$(make_fixture)
run_inbox_stop "$F" "test-artifact" "yes" "false"
expect_eq "$LAST_EXIT" "0" "inbox-stop: artifact turn exits 0"
assert_log_contains "$F" "fire turncount-reset-on-artifact" "inbox-stop: artifact turn logs fire turncount-reset-on-artifact"
if printf '%s' "$LAST_STDOUT" | grep -q '"decision":"block"'; then
  pass "inbox-stop: artifact turn emits decision:block JSON"
else
  fail "inbox-stop: artifact turn emits decision:block JSON" "got: $LAST_STDOUT"
fi
# Counter should be reset to 0 after artifact fire
if [ -f "$F/.claude/inbox/.turn-count" ]; then
  tc=$(awk '{print $2}' "$F/.claude/inbox/.turn-count")
  expect_eq "$tc" "0" "inbox-stop: artifact turn resets brainstorm counter to 0"
fi

# ---------------------------------------------------------------------------
# inbox-stop.sh — Test 5: brainstorm fallback fires after N noop turns
# Use LCW_BRAINSTORM_TURNS=3 to keep the test fast.
# ---------------------------------------------------------------------------
F=$(make_fixture)
SID="test-brainstorm"
export LCW_BRAINSTORM_TURNS=3
for i in 1 2; do
  run_inbox_stop "$F" "$SID" "no" "false"
done
# Third noop should trigger the brainstorm fire
run_inbox_stop "$F" "$SID" "no" "false"
expect_eq "$LAST_EXIT" "0" "inbox-stop: brainstorm-fallback exits 0"
assert_log_contains "$F" "turncount-fire 3/3" "inbox-stop: brainstorm-fallback logs turncount-fire N/N"
if printf '%s' "$LAST_STDOUT" | grep -q "Brainstorm-fallback"; then
  pass "inbox-stop: brainstorm-fallback emits Brainstorm-fallback reason"
else
  fail "inbox-stop: brainstorm-fallback emits Brainstorm-fallback reason" "got: $LAST_STDOUT"
fi
unset LCW_BRAINSTORM_TURNS

# ---------------------------------------------------------------------------
# inbox-stop.sh — Test 6: heartbeat — every fire writes 'entering'
# ---------------------------------------------------------------------------
F=$(make_fixture)
run_inbox_stop "$F" "test-heartbeat" "no" "false"
assert_log_contains "$F" "test-heartbeat entering" "inbox-stop: heartbeat 'entering' present in log"

# ---------------------------------------------------------------------------
# recall-prompt.sh — Test 1: kill switch
# ---------------------------------------------------------------------------
F=$(make_fixture)
touch "$F/.claude/inbox/.recall-disabled"
run_recall "$F" "test-recall-kill" "plan how to add foo"
expect_eq "$LAST_EXIT" "0" "recall: kill switch exits 0"
assert_log_contains "$F" "recall:kill-switch" "recall: kill switch logs recall:kill-switch"
expect_eq "$LAST_STDOUT" "" "recall: kill switch produces no stdout"

# ---------------------------------------------------------------------------
# recall-prompt.sh — Test 2: planning prompt fires
# ---------------------------------------------------------------------------
F=$(make_fixture)
run_recall "$F" "test-recall-fire" "plan how to add a permissions feature"
expect_eq "$LAST_EXIT" "0" "recall: planning prompt exits 0"
assert_log_contains "$F" "recall:fire" "recall: planning prompt logs recall:fire"
if printf '%s' "$LAST_STDOUT" | grep -q "Wiki recall"; then
  pass "recall: planning prompt emits Wiki recall block"
else
  fail "recall: planning prompt emits Wiki recall block" "got: $LAST_STDOUT"
fi

# ---------------------------------------------------------------------------
# recall-prompt.sh — Test 3: chit-chat skipped
# ---------------------------------------------------------------------------
F=$(make_fixture)
run_recall "$F" "test-recall-noop" "hello there how are you"
expect_eq "$LAST_EXIT" "0" "recall: chit-chat exits 0"
assert_log_contains "$F" "recall:noop" "recall: chit-chat logs recall:noop"
expect_eq "$LAST_STDOUT" "" "recall: chit-chat produces no stdout"

# ---------------------------------------------------------------------------
# recall-prompt.sh — Test 4: wiki-only prompt skipped
# ---------------------------------------------------------------------------
F=$(make_fixture)
# Must hit BOTH the planning-intent regex (plan|design|implement|...) AND the
# wiki-only regex (digest|inbox|curate|...). "design how to digest the inbox"
# matches "design" → passes the planning pre-filter, then "digest"/"inbox" →
# triggers the wiki-only skip.
run_recall "$F" "test-recall-wikionly" "design how to digest the inbox better"
expect_eq "$LAST_EXIT" "0" "recall: wiki-only exits 0"
assert_log_contains "$F" "recall:wiki-only" "recall: wiki-only logs recall:wiki-only"
expect_eq "$LAST_STDOUT" "" "recall: wiki-only produces no stdout"

# ---------------------------------------------------------------------------
# recall-prompt.sh — Test 5: cooldown — same prompt twice in same session = 2nd is silenced
# ---------------------------------------------------------------------------
F=$(make_fixture)
SID="test-recall-cooldown"
PROMPT="implement a new caching layer"
run_recall "$F" "$SID" "$PROMPT"
expect_eq "$LAST_EXIT" "0" "recall: first fire of cooldown test exits 0"
assert_log_contains "$F" "recall:fire" "recall: first fire logs recall:fire"
run_recall "$F" "$SID" "$PROMPT"
expect_eq "$LAST_EXIT" "0" "recall: second identical fire exits 0"
assert_log_contains "$F" "recall:cooldown" "recall: second identical fire logs recall:cooldown"

finish_layer
