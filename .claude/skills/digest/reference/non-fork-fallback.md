# Digest non-fork fallback

**When this applies:** the consumer's Claude Code does not have `CLAUDE_CODE_FORK_SUBAGENT=1` set, OR the local Claude Code version does not support `context: fork` (experimental as of v2.1.117 per research/STACK.md).

**Symptom:** when the user runs `/digest`, the skill body executes in the parent session instead of forking into a fresh context. This pollutes the parent context with the inbox + wiki tree + Rules.md but otherwise still works.

## Procedure

1. The digest skill body's primary path is `context: fork` + `agent: wiki-curator` (the agent named `wiki-curator` per CONTEXT.md D-13). If forking is unavailable, the skill body still runs — the current Claude in the parent session reads the body and executes it.

2. To preserve the curator's behavior without true context isolation, the parent Claude must:
   - Treat the wiki-curator system prompt at `.claude/agents/wiki-curator.md` as authoritative for this run. Read that file fresh at fallback time.
   - Treat the wiki-rules skill body at `.claude/skills/wiki-rules/SKILL.md` as authoritative. Read that file fresh.
   - Follow whatever protocol the curator file defines (its sections are authoritative — this fallback doc does not duplicate them).
   - Continue using the digest skill body's lifecycle steps (archive-before-write, post-write audit).

3. The only LOST property in the fallback path is fresh-context isolation. The curator's protocol is correctness-equivalent across both paths.

## Why fork is preferred

- **Context budget:** forking gives the curator a fresh window. In the parent session, the curator's reading of wiki/Rules.md + inbox + wiki tree adds 5–20 KB to the parent's context for the rest of the session.
- **Determinism:** forked subagent has nothing in context except the skill body, the agent system prompt, and preloaded skills. No accidental influence from the parent's prior turns.
- **Cleanup:** when the fork ends, only the digest summary returns. In the fallback path, the parent session is left with the curator's intermediate work in its context.

None of these affect correctness. They affect ergonomics and cost.

## Detection (optional)

The digest skill body can detect the fallback path by checking the environment variable `CLAUDE_CODE_FORK_SUBAGENT`:

```bash
if [ "${CLAUDE_CODE_FORK_SUBAGENT:-0}" != "1" ]; then
  echo "WARNING: forking unavailable; using fallback path. See .claude/skills/digest/reference/non-fork-fallback.md"
fi
```

The warning is informational only — the digest still proceeds.

## Reference

- D-13 in `.planning/phases/01-foundation-curator/01-CONTEXT.md` (canonical agent name + fallback semantics)
- "Version Compatibility" table in `.planning/research/STACK.md`
- "Failure Modes T8" in `.planning/research/ARCHITECTURE.md`
