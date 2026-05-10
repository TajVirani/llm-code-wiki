#!/usr/bin/env bash
# tests/install-e2e.sh — L3 install + update E2E.
# Extracts the bash blocks from .claude/skills/wiki-install/SKILL.md and runs
# them in a fresh fixture, then asserts the resulting filesystem state.
# Also targets the wiki-update Step-5 settings.json merge logic for the
# permissions-backfill path.
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
# shellcheck source=lib/assert.sh
. "$TESTS_DIR/lib/assert.sh"
# shellcheck source=lib/extract-bash-blocks.sh
. "$TESTS_DIR/lib/extract-bash-blocks.sh"

start_layer "L3 install/update E2E"

# Pre-flight: jq is required for the merge path. Missing jq is an environment
# issue, not a code regression — skip with a warning and exit 0 so run-all
# doesn't fail in environments without jq. (Real installs/CI must have jq.)
if ! command -v jq >/dev/null 2>&1; then
  printf '  %bSKIP%b  L3 install/update E2E (jq not installed; install via apt/brew and re-run)\n' "$C_YELLOW" "$C_RESET"
  exit 0
fi

# Pre-extract install blocks (5 blocks) and update blocks (14 blocks) once.
INSTALL_BLOCKS_DIR=$(mktemp -d -t lcw-install-blocks-XXXXXX)
UPDATE_BLOCKS_DIR=$(mktemp -d -t lcw-update-blocks-XXXXXX)
trap 'rm -rf "$INSTALL_BLOCKS_DIR" "$UPDATE_BLOCKS_DIR"' EXIT

extract_bash_blocks "$REPO_ROOT/.claude/skills/wiki-install/SKILL.md" "$INSTALL_BLOCKS_DIR" >/dev/null
extract_bash_blocks "$REPO_ROOT/.claude/skills/wiki-update/SKILL.md"  "$UPDATE_BLOCKS_DIR"  >/dev/null

INSTALL_BLOCK_COUNT=$(ls "$INSTALL_BLOCKS_DIR"/block-*.sh 2>/dev/null | wc -l | tr -d ' ')
expect_eq "$INSTALL_BLOCK_COUNT" "5" "wiki-install/SKILL.md has 5 bash blocks"

# ---------------------------------------------------------------------------
# Fixture setup — copies just the .claude/ tree and the wiki seed files
# ---------------------------------------------------------------------------
make_install_fixture() {
  local d
  d=$(mktemp -d -t lcw-install-fixture-XXXXXX)
  mkdir -p "$d/.claude" "$d/wiki/_templates"
  cp -R "$REPO_ROOT/.claude/skills"  "$d/.claude/"
  cp -R "$REPO_ROOT/.claude/agents"  "$d/.claude/"
  cp -R "$REPO_ROOT/.claude/hooks"   "$d/.claude/"
  cp     "$REPO_ROOT/wiki/Rules.md"  "$d/wiki/Rules.md"
  cp     "$REPO_ROOT/wiki/_templates/note.md"   "$d/wiki/_templates/note.md"
  [ -f "$REPO_ROOT/wiki/_templates/module.md" ] && \
    cp "$REPO_ROOT/wiki/_templates/module.md" "$d/wiki/_templates/module.md"
  cp     "$REPO_ROOT/VERSION"        "$d/VERSION"
  echo "$d"
}

# Run wiki-install/SKILL.md Block N in fixture. Returns exit code via $?.
run_install_block() {
  local fixture="$1" n="$2"
  local blk
  blk=$(printf '%s/block-%02d.sh' "$INSTALL_BLOCKS_DIR" "$n")
  CLAUDE_PROJECT_DIR="$fixture" bash "$blk"
}

# Run all 5 install blocks in sequence; bail on first failure
run_install_all() {
  local fixture="$1" out
  for n in 1 2 3 4 5; do
    if ! out=$(run_install_block "$fixture" "$n" 2>&1); then
      LAST_INSTALL_OUT="$out"
      return 1
    fi
    LAST_INSTALL_OUT="$out"
  done
  return 0
}

# ---------------------------------------------------------------------------
# Test A — fresh install on empty fixture
# ---------------------------------------------------------------------------
F=$(make_install_fixture)
if run_install_all "$F"; then
  pass "fresh install: all 5 blocks exit 0"
else
  fail "fresh install: all 5 blocks exit 0" "$LAST_INSTALL_OUT"
fi
expect_file_exists "$F/.claude/settings.json" "fresh install: settings.json created"
expect_file_exists "$F/CLAUDE.md" "fresh install: CLAUDE.md created"
expect_dir_exists  "$F/wiki/inbox" "fresh install: wiki/inbox created"
expect_dir_exists  "$F/wiki/MODULES" "fresh install: wiki/MODULES created"
expect_file_exists "$F/wiki/topic-index.md" "fresh install: wiki/topic-index.md materialized from seed"
expect_file_exists "$F/.claude/llm-code-wiki.version" "fresh install: version stamp written"

# settings.json shape
S="$F/.claude/settings.json"
expect_file_contains "$S" "inbox-stop.sh"   "fresh install: settings.json has Stop hook entry"
expect_file_contains "$S" "recall-prompt.sh" "fresh install: settings.json has UserPromptSubmit entry"
expect_file_contains "$S" "Read(wiki/inbox/_session.md)"  "fresh install: settings.json has Read perm"
expect_file_contains "$S" "Edit(wiki/inbox/_session.md)"  "fresh install: settings.json has Edit perm"
expect_file_contains "$S" "Write(wiki/inbox/_session.md)" "fresh install: settings.json has Write perm"
expect_file_contains "$S" '\"$CLAUDE_PROJECT_DIR\"' "fresh install: \$CLAUDE_PROJECT_DIR token preserved as JSON-escaped \\\"\$CLAUDE_PROJECT_DIR\\\""

# CLAUDE.md content
expect_file_contains "$F/CLAUDE.md" "## Auto-maintained wiki" "fresh install: CLAUDE.md has Auto-maintained wiki section"

# topic-index materialization (placeholders replaced)
expect_file_not_contains "$F/wiki/topic-index.md" "<<CREATED_TS>>" "fresh install: topic-index CREATED_TS placeholder substituted"
expect_file_not_contains "$F/wiki/topic-index.md" "<<UPDATED_TS>>" "fresh install: topic-index UPDATED_TS placeholder substituted"

# Version stamp matches VERSION
if [ -f "$F/.claude/llm-code-wiki.version" ] && [ -f "$F/VERSION" ]; then
  expect_eq "$(cat "$F/.claude/llm-code-wiki.version")" "$(cat "$F/VERSION")" "fresh install: version stamp == VERSION"
fi

FRESH_FIXTURE="$F"   # reuse for Test C below

# ---------------------------------------------------------------------------
# Test B — install over an existing settings.json with a user permission
# Asserts: user perm preserved, hooks added, default perms added, no duplicates.
# ---------------------------------------------------------------------------
F=$(make_install_fixture)
mkdir -p "$F/.claude"
cat > "$F/.claude/settings.json" <<'JSON'
{
  "permissions": {
    "allow": [
      "Bash(npm test)"
    ]
  }
}
JSON
if run_install_all "$F"; then
  pass "install over existing settings.json: all 5 blocks exit 0"
else
  fail "install over existing settings.json: all 5 blocks exit 0" "$LAST_INSTALL_OUT"
fi
S="$F/.claude/settings.json"
expect_file_contains "$S" "Bash(npm test)" "install over existing: user perm preserved"
expect_file_contains "$S" "inbox-stop.sh"   "install over existing: Stop hook added"
expect_file_contains "$S" "Read(wiki/inbox/_session.md)" "install over existing: default Read perm added"
# Verify no duplicate user perm
if [ -f "$S" ]; then
  count=$(grep -c "Bash(npm test)" "$S" || true)
  expect_eq "$count" "1" "install over existing: user perm not duplicated (count=$count)"
fi

# ---------------------------------------------------------------------------
# Test C — idempotent re-install on already-installed fixture
# ---------------------------------------------------------------------------
if [ -d "$FRESH_FIXTURE" ]; then
  S="$FRESH_FIXTURE/.claude/settings.json"
  before_hash=$(jq -S . "$S" | sha1sum | awk '{print $1}')
  if run_install_all "$FRESH_FIXTURE"; then
    pass "re-install: all 5 blocks exit 0"
  else
    fail "re-install: all 5 blocks exit 0" "$LAST_INSTALL_OUT"
  fi
  after_hash=$(jq -S . "$S" | sha1sum | awk '{print $1}')
  expect_eq "$after_hash" "$before_hash" "re-install: settings.json semantically unchanged (same jq -S hash)"
  # Default-perms entries should appear exactly once each
  for perm in "Read(wiki/inbox/_session.md)" "Edit(wiki/inbox/_session.md)" "Write(wiki/inbox/_session.md)"; do
    count=$(grep -c -F "$perm" "$S" || true)
    expect_eq "$count" "1" "re-install: '$perm' appears exactly once (count=$count)"
  done
fi

# ---------------------------------------------------------------------------
# Test D — wiki-update Step 5 backfills perms on a stale install
# Setup: settings.json with hooks but NO default perms (simulating pre-1.3.1 install).
# Extract just the second bash block of Step 5 (the merge logic) and run it.
# ---------------------------------------------------------------------------
# Locate the Step-5 bash blocks. wiki-update/SKILL.md Step 5 starts at
# "## Step 5 — Re-merge .claude/settings.json" and ends at "## Step 6".
# The Step contains two ```bash blocks: (1) jq-required guard, (2) merge logic.
# We extract by section.
STEP5_DIR=$(mktemp -d -t lcw-step5-XXXXXX)
trap 'rm -rf "$INSTALL_BLOCKS_DIR" "$UPDATE_BLOCKS_DIR" "$STEP5_DIR"' EXIT
awk -v outdir="$STEP5_DIR" '
  /^## Step 5/ { in_step=1; next }
  /^## Step 6/ { in_step=0; next }
  in_step && /^```bash$/ { count++; in_block=1; out=sprintf("%s/block-%02d.sh", outdir, count); next }
  in_step && /^```$/ && in_block { in_block=0; next }
  in_step && in_block { print > out }
' "$REPO_ROOT/.claude/skills/wiki-update/SKILL.md"

step5_count=$(ls "$STEP5_DIR"/block-*.sh 2>/dev/null | wc -l | tr -d ' ')
expect_eq "$step5_count" "2" "wiki-update Step 5 has 2 bash blocks (jq guard + merge)"

F=$(make_install_fixture)
mkdir -p "$F/.claude"
cat > "$F/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/inbox-stop.sh", "timeout": 10 }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/recall-prompt.sh", "timeout": 10 }
        ]
      }
    ]
  },
  "permissions": {
    "allow": [
      "Bash(echo hi)"
    ]
  }
}
JSON

# Run Step 5 blocks in order
ok=1
for blk in "$STEP5_DIR"/block-01.sh "$STEP5_DIR"/block-02.sh; do
  if ! out=$(CLAUDE_PROJECT_DIR="$F" bash "$blk" 2>&1); then
    fail "update Step 5: $(basename "$blk") exit 0" "$out"
    ok=0
  fi
done
[ "$ok" = "1" ] && pass "update Step 5: all blocks exit 0"

S="$F/.claude/settings.json"
expect_file_contains "$S" "Read(wiki/inbox/_session.md)"  "update backfill: Read perm added to stale install"
expect_file_contains "$S" "Edit(wiki/inbox/_session.md)"  "update backfill: Edit perm added"
expect_file_contains "$S" "Write(wiki/inbox/_session.md)" "update backfill: Write perm added"
expect_file_contains "$S" "Bash(echo hi)" "update backfill: pre-existing user perm preserved"
expect_file_contains "$S" "inbox-stop.sh"   "update backfill: Stop hook still present"
expect_file_contains "$S" "recall-prompt.sh" "update backfill: UserPromptSubmit hook still present"

# Run Step 5 again — should be a no-op for permissions (no duplicates)
if out=$(CLAUDE_PROJECT_DIR="$F" bash "$STEP5_DIR/block-02.sh" 2>&1); then
  pass "update Step 5: idempotent re-run exits 0"
else
  fail "update Step 5: idempotent re-run exits 0" "$out"
fi
for perm in "Read(wiki/inbox/_session.md)" "Edit(wiki/inbox/_session.md)" "Write(wiki/inbox/_session.md)"; do
  count=$(grep -c -F "$perm" "$S" || true)
  expect_eq "$count" "1" "update backfill: '$perm' appears exactly once after re-run (count=$count)"
done

finish_layer
