
**Summary**: Under Claude Code `context: fork`, the skill body becomes the subagent's prompt and no parent runtime resumes after the subagent finishes — lifecycle steps must be owned by the subagent.
**Tags**: #fork #skills #lifecycle #pattern #research
**Created**: 2026-04-30T16:42:00+00:00
**Last Updated**: 2026-04-30T16:42:00+00:00

---

## Content

**Discovery.** With Claude Code's `context: fork` skill frontmatter, the entire skill body is delivered to the forked subagent as its prompt. There is no separate parent runtime that resumes after the subagent finishes. The subagent IS the only executor for the duration of the run.

**Failure mode observed (2026-04-30).** The `wiki-digest` skill body contained the phrase "the skill body owns the LIFECYCLE around the curator's work" near Step 6a (the `wiki/inbox/_session.md` reset). The forked curator interpreted that wording as a hand-off and wrote "will be reset by the skill body" in its summary, then exited without performing the Write. Result: a fully-populated session inbox after a successful digest, and the next digest re-processed every entry.

**Root cause.** Skill bodies authored before fork mode existed often described lifecycle steps in third person ("the skill body archives", "the calling runtime resets", "the parent then deletes"). Under `context: fork` those references resolve to nothing — the subagent reads them and does not perform the action.

**Fix pattern.**

1. Address every step in second person directed at the subagent: "you, the curator, perform…".
2. Explicitly forbid deferring to "the skill body", "the calling runtime", or any external executor. The forbiddance must be in the step text itself, not only in a separate section.
3. Where the agent's `allowed-tools` list is narrower than the skill body's natural toolset — for example the wiki-curator has `Read, Write, Edit, Glob, Grep` but no `Bash` — provide a Write-based fallback (tombstone marker over `rm`, structured file content over shell commands) rather than letting the gap silently drop the step.
4. Duplicate critical lifecycle steps into the agent definition (`.claude/agents/<name>.md`) so the contract holds even if the skill body wording is later edited or shortened.

**Why fork mode is still worth using.** Fresh-context isolation prevents prompt drift and token bloat across a long parent thread. The cost is that lifecycle prose must be authored carefully — every "this happens after the agent returns" is a bug.

**Generalization.** Any Claude Code skill with `context: fork` should be treated as a one-shot subagent prompt, not a procedural script with hand-offs. Audit existing fork-mode skills for third-person lifecycle prose; rewrite as second-person agent responsibilities.

## Related Notes

- [[Wiki Digest Skill]]
- [[Wiki Curator Agent]]
- [[Skill Bash Injection Isolation]]
