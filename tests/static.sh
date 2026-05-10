#!/usr/bin/env bash
# tests/static.sh — L1 static checks.
# Verifies file references resolve, frontmatter is valid, and shell logic
# (hooks + bash blocks inside SKILL.md) passes `bash -n`.
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
# shellcheck source=lib/assert.sh
. "$TESTS_DIR/lib/assert.sh"
# shellcheck source=lib/extract-bash-blocks.sh
. "$TESTS_DIR/lib/extract-bash-blocks.sh"
# shellcheck source=lib/extract-bang-blocks.sh
. "$TESTS_DIR/lib/extract-bang-blocks.sh"

start_layer "L1 static checks"

# ---------------------------------------------------------------------------
# 1. dist-manifest.txt — every PATH line resolves to an existing file
# ---------------------------------------------------------------------------
MANIFEST="$REPO_ROOT/dist-manifest.txt"
expect_file_exists "$MANIFEST" "dist-manifest.txt present at repo root"

if [ -f "$MANIFEST" ]; then
  while IFS= read -r line; do
    # strip leading whitespace, skip blanks/comments
    trimmed="${line#"${line%%[![:space:]]*}"}"
    [ -z "$trimmed" ] && continue
    case "$trimmed" in \#*) continue ;; esac
    # path is the first whitespace-delimited token
    path="${trimmed%%[[:space:]]*}"
    expect_file_exists "$REPO_ROOT/$path" "manifest path exists: $path"
  done < "$MANIFEST"
fi

# ---------------------------------------------------------------------------
# 2. Frontmatter — every SKILL.md and agent .md starts with --- and has name+description
# ---------------------------------------------------------------------------
check_frontmatter() {
  local file="$1" label="$2"
  if [ ! -f "$file" ]; then fail "$label" "missing: $file"; return; fi
  local first_line
  first_line=$(head -1 "$file" | tr -d '\r')
  if [ "$first_line" != "---" ]; then
    fail "$label" "first line is not ---: $first_line"
    return
  fi
  # Frontmatter ends at the second '---' line (CRLF-tolerant)
  local fm_end
  fm_end=$(awk 'NR>1 { sub(/\r$/, "") } NR>1 && /^---[[:space:]]*$/ { print NR; exit }' "$file")
  if [ -z "$fm_end" ]; then
    fail "$label" "no closing --- found"
    return
  fi
  local fm
  fm=$(sed -n "2,$((fm_end - 1))p" "$file")
  if ! printf '%s\n' "$fm" | grep -qE '^name:[[:space:]]'; then
    fail "$label" "frontmatter missing 'name:' field"; return
  fi
  if ! printf '%s\n' "$fm" | grep -qE '^description:[[:space:]]'; then
    fail "$label" "frontmatter missing 'description:' field"; return
  fi
  pass "$label"
}

for f in "$REPO_ROOT"/.claude/skills/*/SKILL.md; do
  rel="${f#$REPO_ROOT/}"
  check_frontmatter "$f" "frontmatter valid: $rel"
done

for f in "$REPO_ROOT"/.claude/agents/*.md; do
  rel="${f#$REPO_ROOT/}"
  check_frontmatter "$f" "frontmatter valid: $rel"
done

# ---------------------------------------------------------------------------
# 3. Hook scripts — bash -n + executable bit
# ---------------------------------------------------------------------------
for hook in "$REPO_ROOT"/.claude/hooks/*.sh; do
  rel="${f#$REPO_ROOT/}"
  rel="${hook#$REPO_ROOT/}"
  if [ -x "$hook" ]; then pass "executable: $rel"; else fail "executable: $rel" "chmod +x missing"; fi
  if bash -n "$hook" 2>/tmp/lcw-bashn.err; then
    pass "bash -n: $rel"
  else
    fail "bash -n: $rel" "$(cat /tmp/lcw-bashn.err)"
  fi
done
rm -f /tmp/lcw-bashn.err

# ---------------------------------------------------------------------------
# 4. Bash blocks inside SKILL.md files — bash -n on each extracted block
# ---------------------------------------------------------------------------
EXTRACT_DIR=$(mktemp -d -t lcw-bash-blocks-XXXXXX)
trap 'rm -rf "$EXTRACT_DIR"' EXIT

for skill in "$REPO_ROOT"/.claude/skills/*/SKILL.md; do
  rel="${skill#$REPO_ROOT/}"
  block_dir="$EXTRACT_DIR/$(basename "$(dirname "$skill")")"
  count=$(extract_bash_blocks "$skill" "$block_dir" | tail -1)
  count="${count:-0}"
  [ "$count" -eq 0 ] && continue
  layer_ok=1
  for blk in "$block_dir"/block-*.sh; do
    [ -f "$blk" ] || continue
    if ! bash -n "$blk" 2>/tmp/lcw-bashn.err; then
      fail "bash -n block in $rel" "block $(basename "$blk"): $(cat /tmp/lcw-bashn.err)"
      layer_ok=0
    fi
  done
  if [ "$layer_ok" = "1" ]; then pass "bash -n on $count block(s) in $rel"; fi
done
rm -f /tmp/lcw-bashn.err

# ---------------------------------------------------------------------------
# 4b. !-injected backtick blocks — bash -n + single-line lint.
# Multi-line `!`-injection blocks are FRAGILE under Claude Code's skill
# harness (the harness can mangle multi-line text in ways `bash -n` on the
# raw source won't catch — see the wiki-modules `done`-mismatch incident
# captured in CHANGELOG 1.3.2). Enforce single-line as a defensive lint.
# ---------------------------------------------------------------------------
for skill in "$REPO_ROOT"/.claude/skills/*/SKILL.md; do
  rel="${skill#$REPO_ROOT/}"
  bang_dir="$EXTRACT_DIR/bang-$(basename "$(dirname "$skill")")"
  bang_count=$(extract_bang_blocks "$skill" "$bang_dir" | tail -1)
  bang_count="${bang_count:-0}"
  [ "$bang_count" -eq 0 ] && continue
  layer_ok=1
  multi=0
  for blk in "$bang_dir"/bang-*.sh; do
    [ -f "$blk" ] || continue
    ln_file="${blk%.sh}.lines"
    range=$(cat "$ln_file" 2>/dev/null)
    start=${range%% *}; end=${range##* }
    if [ -n "$start" ] && [ -n "$end" ] && [ "$start" != "$end" ]; then
      multi=$((multi + 1))
      fail "single-line !-injection in $rel" "$(basename "$blk") spans lines $start–$end ($((end - start + 1)) lines). Multi-line !-injection is fragile under the skill harness; collapse to one line with ; separators."
      layer_ok=0
    fi
    if ! bash -n "$blk" 2>/tmp/lcw-bashn.err; then
      fail "bash -n !-block in $rel" "$(basename "$blk"): $(cat /tmp/lcw-bashn.err)"
      layer_ok=0
    fi
    # Lint: bash ${VAR:-default} default-value syntax around Claude Code skill
    # variables (currently ${ARGUMENTS}) collides with the harness's own
    # preprocessing — see CHANGELOG 1.3.3. The safe pattern is
    # `P="$ARGUMENTS"; P="${P:-default}"`. Reject the fragile form.
    if grep -qE '\$\{ARGUMENTS[:-]' "$blk"; then
      fail "no \${ARGUMENTS:-…} in !-block in $rel" "$(basename "$blk"): the bash default-value syntax around \$ARGUMENTS collides with Claude Code's harness substitution. Use bare \$ARGUMENTS into a regular var, then default that var: \`P=\"\$ARGUMENTS\"; P=\"\${P:-default}\"\`."
      layer_ok=0
    fi
  done
  if [ "$layer_ok" = "1" ]; then
    pass "bash -n + single-line on $bang_count !-block(s) in $rel"
  fi
done
rm -f /tmp/lcw-bashn.err

# ---------------------------------------------------------------------------
# 5. VERSION + CHANGELOG + INSTALL/README sanity
# ---------------------------------------------------------------------------
expect_file_exists "$REPO_ROOT/VERSION" "VERSION present"
if [ -f "$REPO_ROOT/VERSION" ]; then
  v=$(cat "$REPO_ROOT/VERSION")
  if printf '%s' "$v" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+([+-].*)?$'; then
    pass "VERSION is semver: $v"
  else
    fail "VERSION is semver" "got: $v"
  fi
fi
expect_file_exists "$REPO_ROOT/CHANGELOG.md" "CHANGELOG.md present"
expect_file_exists "$REPO_ROOT/INSTALL.md" "INSTALL.md present"
expect_file_exists "$REPO_ROOT/README.md" "README.md present"

# ---------------------------------------------------------------------------
# 6. Templates referenced by wiki-install exist with expected anchors
# ---------------------------------------------------------------------------
SEED="$REPO_ROOT/.claude/skills/wiki-install/templates/topic-index.seed.md"
if [ -f "$SEED" ]; then
  expect_file_contains "$SEED" "<<CREATED_TS>>" "topic-index seed has CREATED_TS placeholder"
  expect_file_contains "$SEED" "<<UPDATED_TS>>" "topic-index seed has UPDATED_TS placeholder"
  expect_file_contains "$SEED" "### Modules" "topic-index seed has ### Modules section"
  expect_file_contains "$SEED" "### Notes" "topic-index seed has ### Notes section"
fi

CMS="$REPO_ROOT/.claude/skills/wiki-install/templates/CLAUDE-MD-SECTION.md"
if [ -f "$CMS" ]; then
  expect_file_contains "$CMS" "## Auto-maintained wiki" "CLAUDE-MD-SECTION starts with canonical H2"
fi

finish_layer
