
**Summary**: UserPromptSubmit hook that pre-filters prompts for planning intent and emits a stdout block instructing Claude to spawn the wiki-recall sub-agent.
**Tags**: #hook #recall #script
**Created**: 2026-04-30T00:00:00+00:00
**Last Updated**: 2026-04-30T00:00:00+00:00

---

## Content

**Path:** `.claude/hooks/recall-prompt.sh`
**Trigger:** UserPromptSubmit

**Behavior:**

1. Pre-filters prompts for planning-intent keywords (plan, design, implement, refactor, etc.).
2. Skips wiki-only prompts (digest, `/wiki-recall`, inbox) to avoid recursion / no-op fires.
3. Respects a kill switch at `.claude/inbox/.recall-disabled`.
4. Applies a session+prompt-hash cooldown to prevent double-fire on the same prompt within one session.
5. On match, emits a stdout block instructing Claude to spawn the wiki-recall sub-agent.

**Why filter aggressively:** firing the hook on every prompt would cost a sub-agent spawn per turn. The keyword filter + cooldown keeps recall cheap — recall only happens when it's likely to pay off.

**Kill switch convention** matches the Stop hook's `.claude/inbox/.disabled` sentinel: a `touch` disables, `rm` re-enables. No restart required.

## Related Notes

- [[Recall Path]]
- [[Wiki Recall Subagent]]
- [[Recall Skill]]
