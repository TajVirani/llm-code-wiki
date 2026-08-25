# data-structure-audit bundle

Incremental, git-anchored audit of data structures: invalid representable
states, unnecessary complexity, and (evidence-gated) performance. Only
re-checks code that changed since the last recorded run.

## Install (per project)

    cp -r skills/data-structure-audit  <repo>/.claude/skills/
    cp commands/pr-review-data.md      <repo>/.claude/commands/

Or install the skill globally to ~/.claude/skills/ (the command file stays
per-repo, or goes in ~/.claude/commands/ for all repos).

## Invoking

- /pr-review-data            — alias command (optionally: /pr-review-data internal/models)
- /data-structure-audit      — the skill's native slash name
- Auto-triggers on natural-language requests matching its description
  (audit/review types, structs, models, schemas, impossible states, etc.)

## State

The skill records audited commits in .claude/data-structure-audit-state.jsonl
(commit it with your changes) and adds a `merge=union` .gitattributes rule so
parallel branches merge cleanly. Delete the state file to force a full re-audit.
See skills/data-structure-audit/references/incremental.md for mechanics.
