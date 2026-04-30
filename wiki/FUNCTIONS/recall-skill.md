
**Summary**: The `/wiki-recall` slash command skill forks into the wiki-recall sub-agent and surfaces its return verbatim, for on-demand wiki consultation.
**Tags**: #skill #recall #command
**Created**: 2026-04-30T00:00:00+00:00
**Last Updated**: 2026-04-30T00:00:00+00:00

---

## Content

**Path:** `.claude/skills/wiki-recall/SKILL.md`
**Invocation:** `/wiki-recall [optional query]`

**Behavior:**

- Forks into the `wiki-recall` sub-agent via `context: fork` + `agent: wiki-recall`.
- Accepts an optional query argument; defaults to the current conversation context if no argument is given.
- Surfaces the agent's return verbatim — no rewriting, no summarization on top.

**When to use:**

- The recall hook didn't fire because the prompt phrasing wasn't planning-flavored.
- A focused on-demand recall in the middle of a session ("what did we decide about auth tokens?").
- After the cooldown blocked an automatic recall but the user wants one anyway.

**Why fork:** the recall agent runs in a fresh context so its tool calls don't bloat the parent conversation. The skill body is delivered to the fork as the prompt.

## Related Notes

- [[Recall Path]]
- [[Recall Prompt Hook]]
- [[Wiki Recall Subagent]]
