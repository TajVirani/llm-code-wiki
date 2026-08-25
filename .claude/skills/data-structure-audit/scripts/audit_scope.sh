#!/usr/bin/env bash
# audit_scope.sh — git anchoring for the data-structure-audit skill.
#
#   audit_scope.sh scope    Print files changed since the last audited commit(s),
#                           one per line. Prints FULL_AUDIT if no usable state.
#                           Prints nothing if no code has changed.
#   audit_scope.sh record   Append current HEAD to the state file, pruning
#                           entries subsumed by it (ancestors of HEAD).
#
# State lives in .claude/data-structure-audit-state.jsonl (one JSON object per
# line) and is meant to be COMMITTED, so it travels with branches and merges.
# The audited set is a union: a file only needs checking if it changed on some
# path not reachable from ANY audited commit.
set -euo pipefail

STATE_FILE=".claude/data-structure-audit-state.jsonl"
CMD="${1:-scope}"

extract_shas() {
  # Pull commit shas out of the jsonl without requiring jq.
  grep -o '"commit"[[:space:]]*:[[:space:]]*"[0-9a-f]\{7,40\}"' "$1" 2>/dev/null \
    | grep -o '[0-9a-f]\{7,40\}' || true
}

case "$CMD" in
  scope)
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
      echo "NOT_A_GIT_REPO"
      exit 0
    fi
    cd "$(git rev-parse --show-toplevel)"

    if [[ ! -f "$STATE_FILE" ]]; then
      echo "FULL_AUDIT (no state file — first run)"
      exit 0
    fi

    exclude=()
    while IFS= read -r sha; do
      [[ -n "$sha" ]] || continue
      git cat-file -e "${sha}^{commit}" 2>/dev/null || continue   # rebased away / shallow clone
      if git merge-base --is-ancestor "$sha" HEAD 2>/dev/null; then
        exclude+=("$sha")
      else
        # Audited commit is not an ancestor (rebase/amend/other branch not merged
        # here). Fall back to the common ancestor: may over-check, never under-checks.
        mb="$(git merge-base HEAD "$sha" 2>/dev/null || true)"
        [[ -n "$mb" ]] && exclude+=("$mb")
      fi
    done < <(extract_shas "$STATE_FILE")

    if [[ ${#exclude[@]} -eq 0 ]]; then
      echo "FULL_AUDIT (state file has no commits usable from this HEAD)"
      exit 0
    fi

    {
      # Committed changes not reachable from any audited commit.
      # -c: for merge commits, list files that differ from all parents
      # (i.e., conflict resolutions), instead of skipping merges entirely.
      git log --name-only --pretty=format: -c HEAD --not "${exclude[@]}" 2>/dev/null
      # Uncommitted (staged + unstaged) changes.
      git diff --name-only HEAD 2>/dev/null
      # Untracked files.
      git ls-files --others --exclude-standard
    } | sed '/^$/d' | sort -u | while IFS= read -r f; do
        [[ "$f" == "$STATE_FILE" ]] && continue   # the state file is bookkeeping, not audit input
        [[ -f "$f" ]] && printf '%s\n' "$f"       # drop deleted files
      done
    ;;

  record)
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
      echo "NOT_A_GIT_REPO" >&2
      exit 1
    fi
    cd "$(git rev-parse --show-toplevel)"
    mkdir -p "$(dirname "$STATE_FILE")"
    head_sha="$(git rev-parse HEAD)"

    # Prune entries subsumed by the new record (ancestors of HEAD): the new
    # entry excludes everything they excluded. Keep non-ancestors (parallel
    # branches) — their audits still count after a future merge.
    if [[ -f "$STATE_FILE" ]]; then
      tmp="$(mktemp)"
      while IFS= read -r line; do
        sha="$(printf '%s' "$line" | grep -o '[0-9a-f]\{7,40\}' | head -1 || true)"
        if [[ -n "$sha" ]] \
           && git cat-file -e "${sha}^{commit}" 2>/dev/null \
           && git merge-base --is-ancestor "$sha" "$head_sha" 2>/dev/null; then
          continue
        fi
        printf '%s\n' "$line" >>"$tmp"
      done <"$STATE_FILE"
      mv "$tmp" "$STATE_FILE"
    fi

    printf '{"commit": "%s", "date": "%s"}\n' \
      "$head_sha" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >>"$STATE_FILE"

    if [[ -n "$(git status --porcelain=v1 2>/dev/null | grep -v "^?? " | grep -v "$STATE_FILE" || true)" ]]; then
      echo "WARNING: working tree was dirty. Only HEAD ($head_sha) is recorded;" >&2
      echo "uncommitted changes audited this run will resurface next run once committed." >&2
    fi
    echo "Recorded $head_sha in $STATE_FILE"
    echo "Commit this file with your changes so future runs — and other branches after merge — see it."
    ;;

  *)
    echo "usage: audit_scope.sh [scope|record]" >&2
    exit 1
    ;;
esac
