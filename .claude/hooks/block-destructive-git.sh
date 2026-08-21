#!/usr/bin/env bash
# block-destructive-git.sh
# PreToolUse hook: blocks destructive git commands before they execute.
# Returns JSON with permissionDecision:"deny" so Claude gets the rejection reason.

set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Nothing to check
if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# ── Destructive git patterns ────────────────────────────────────────────
# Each pattern is checked against the full command string so chained
# commands (&&, ||, ;) are caught too.

BLOCKED=""

# git stash (destructive subcommands — pop, drop, clear, apply, push, save, bare "git stash")
# Allow read-only: git stash list, git stash show
if echo "$COMMAND" | grep -qE '\bgit\s+stash\b'; then
  if ! echo "$COMMAND" | grep -qE '\bgit\s+stash\s+(list|show)\b'; then
    BLOCKED="git stash (destructive variant — only 'git stash list' and 'git stash show' are allowed)"
  fi
fi

# git reset --hard
if echo "$COMMAND" | grep -qE '\bgit\s+reset\s+--hard\b'; then
  BLOCKED="git reset --hard"
fi

# git checkout . / git checkout -- . (discard all working tree changes)
if echo "$COMMAND" | grep -qE '\bgit\s+checkout\s+(--\s+)?\.'; then
  BLOCKED="git checkout . (discard working tree)"
fi

# git restore . / git restore --staged . (discard changes)
if echo "$COMMAND" | grep -qE '\bgit\s+restore\s'; then
  BLOCKED="git restore (discard changes)"
fi

# git clean -f / git clean -fd / git clean -fx (remove untracked files)
if echo "$COMMAND" | grep -qE '\bgit\s+clean\s+-[a-zA-Z]*f'; then
  BLOCKED="git clean -f (remove untracked files)"
fi

# git push --force / git push -f / git push --force-with-lease
if echo "$COMMAND" | grep -qE '\bgit\s+push\s+.*(-f|--force)\b'; then
  BLOCKED="git push --force"
fi

# git branch -D (force delete branch)
if echo "$COMMAND" | grep -qE '\bgit\s+branch\s+-D\b'; then
  BLOCKED="git branch -D (force delete)"
fi

# git rebase (can rewrite history)
if echo "$COMMAND" | grep -qE '\bgit\s+rebase\b'; then
  BLOCKED="git rebase"
fi

# git cherry-pick (can modify working tree unexpectedly)
# Not blocked — usually safe

# ── Decision ────────────────────────────────────────────────────────────

if [[ -n "$BLOCKED" ]]; then
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "BLOCKED: Destructive git command detected: ${BLOCKED}. Destructive git commands are FORBIDDEN. You previously destroyed a week of uncommitted work with git stash pop. NEVER run git stash, git reset --hard, git checkout ., git restore, git clean -f, git push --force, git branch -D, or git rebase. If you need to check something against a clean state, ask the USER to do it or use a worktree."
  }
}
EOF
  exit 0
fi

# Allow non-destructive commands
exit 0
