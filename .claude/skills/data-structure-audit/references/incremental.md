# Incremental Anchoring: Mechanics and Edge Cases

Read this when scope output looks wrong, a state-file merge conflict needs resolving, or the user asks how the anchoring works.

## The model

State file: `.claude/data-structure-audit-state.jsonl`, committed to the repo. One JSON object per line:

```json
{"commit": "<full sha>", "date": "2026-08-25T11:35:51Z"}
```

Semantics: **every commit listed has had all code reachable from it audited.** The file is a *set*, not a pointer. A file needs auditing iff it changed on some path not reachable from any listed commit:

```
changed = git log --name-only --pretty=format: -c HEAD --not <sha1> <sha2> ...
        + git diff --name-only HEAD          (uncommitted)
        + git ls-files --others --exclude-standard   (untracked)
```

`-c` makes merge commits report conflict-resolution files (files differing from all parents); without it, merges report nothing and hand-resolved conflicts would slip through.

Recording appends HEAD and prunes entries that are ancestors of HEAD (subsumed — the new entry excludes strictly more). Non-ancestor entries are kept: they represent parallel branches whose audits become useful after a merge.

## Why a set, not a single pointer

Single-pointer breaks the parallel-branch case: branch A and branch B both run the audit; A merges, then B merges. A pointer holding "B's head" (last writer) would cause `git diff B-head..main` to resurface A's already-audited code — or vice versa. With the set {A-head, B-head}, after both merges both are ancestors of main's HEAD, so `HEAD --not A B` correctly excludes both branches' commits regardless of merge order.

## Scenario walkthroughs

- **Run on a PR branch** → records the PR head. Re-running immediately: empty scope.
- **New commits on the same branch** → scope = files changed in those commits only. Recording prunes the older entry (now an ancestor).
- **Branch off an audited branch** → the child inherits the committed state file; scope on the child = child's new commits only.
- **PR merged to main, run on main** → PR head is now an ancestor of main; only non-PR commits that landed on main since main's own last audit surface. If nothing else landed: empty scope.
- **Two branches audited, merged sequentially** → union of both entries excludes both branch histories. The *merge into main itself* may append duplicate-ish lines from each side — the union merge driver (below) resolves it.
- **Rebase / amend after recording** → the recorded sha no longer exists or isn't an ancestor. The script falls back to `git merge-base HEAD <sha>`; if the sha is gone entirely, the entry is skipped. Consequence: rebased commits get re-checked. Over-checking is the designed failure mode — the invariant is *never under-check*.
- **Shallow clones / CI checkouts** → recorded shas may not exist locally → treated as unusable → possibly `FULL_AUDIT`. Suggest a full-depth fetch (`git fetch --unshallow`) before running in CI.

## State-file merge conflicts

With the union driver configured, git auto-resolves by keeping both sides' lines — which is exactly the correct semantics for a set:

```
# .gitattributes
.claude/data-structure-audit-state.jsonl merge=union
```

Without it, a conflict looks like both sides appended different lines. Resolve by union: keep every line from both sides (dedupe identical lines), no markers. Never resolve by picking one side — that silently discards the other branch's audit record and causes re-checks (annoying) or, if someone "fixes" it by picking the wrong ancestor, stale exclusions.

Duplicate or ancestor-redundant lines are harmless: the exclusion set is idempotent, and the next `record` prunes them.

## Trust boundary

The state file is an honor-system cache, not a security control: anyone can append a sha and suppress checking. If the user wants enforcement (e.g., CI fails when scope is non-empty and no new record was committed), that's a CI job wrapping `audit_scope.sh scope` — offer to write it, but keep it out of this skill's default behavior.

## Manual operations

- **Force a full re-audit**: delete the state file (or run with it moved aside), audit, record fresh.
- **Invalidate one branch's record**: remove its line, commit.
- **Inspect why a file is/isn't in scope**: `git log --oneline HEAD --not $(grep -o '"commit": "[0-9a-f]*"' .claude/data-structure-audit-state.jsonl | grep -o '[0-9a-f]\{40\}') -- <file>` — empty output means every change to the file is reachable from an audited commit.
