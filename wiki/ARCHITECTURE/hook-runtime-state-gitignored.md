
**Summary**: `.gitignore` excludes every per-machine derived/ephemeral artifact the scaffold produces, so commits never carry runtime state across developers.
**Tags**: #architecture #gitignore #hooks #scaffold
**Created**: 2026-05-09T00:00:00+00:00
**Last Updated**: 2026-05-09T00:00:00+00:00

---

## Content

The scaffold produces several categories of derived state at runtime that must NOT be committed. `.gitignore` enumerates them so working trees stay clean and developers do not accidentally cross-contaminate per-machine state via PRs.

### Categories excluded

- **Hook runtime state** — `.claude/inbox/.hook-log`, `.fire-counter`, `.disabled`, `.recall-counter`, `.recall-disabled`, `.turn-count`. These are heartbeat, counter, and kill-switch files written by `inbox-stop.sh` and `recall-prompt.sh` between turns.
- **Live session inbox** — `wiki/inbox/_session.md`. Regenerated each session by the `inbox-update` skill; not source-of-truth (the codebase is). Per-developer state.
- **Inbox archives** — `wiki/inbox/_archive/`. Per-machine crash-safety net for `/wiki-digest` (Step 2 archives), not the canonical record.
- **Codebase-crawler scratch** — `_docgen/` (inventory.json, graph.json, concepts.json from `/wiki-code-crawler`). Resumability cache, regenerable from the live codebase.
- **macOS metadata** — `.DS_Store` and `**/.DS_Store`.
- **Per-developer settings** — `.claude/settings.local.json`. The committed `.claude/settings.json` is shared; `settings.local.json` overrides it per developer.

### Why this matters

The Stop hook self-heals `.claude/inbox/` at startup (creating it if missing). That self-heal would create a file the developer never asked for; ignoring its outputs by glob keeps the convention "hooks may write freely without producing diff churn."

The same principle applies to `_archive/` — `/wiki-digest` writes there on every run as a recoverability guarantee. Committing those archives across machines would either explode repo size or create merge conflicts on every digest.

The convention complements the [[stop-hook-self-heals-runtime-dir|Stop Hook Self Heals Runtime Dir]] pattern: hooks may freely create/rewrite their state files because nothing they write will end up in a commit.

When adding a new scaffold component that writes runtime state (a new hook, a new skill cache directory), update `.gitignore` in the same change. Otherwise the next developer will see noise in `git status` after running the scaffold once.

## Related Notes

- [[stop-hook-self-heals-runtime-dir|Stop Hook Self Heals Runtime Dir]]
- [[inbox-stop-hook|Inbox Stop Hook]]
- [[recall-prompt-hook|Recall Prompt Hook]]
- [[wiki-digest-skill|Wiki Digest Skill]]
