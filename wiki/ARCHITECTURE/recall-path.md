
**Summary**: The recall path mirrors the capture path: a UserPromptSubmit hook plus wiki-recall sub-agent surface relevant wiki context before Claude responds to planning prompts.
**Tags**: #recall #hook #architecture #agent
**Created**: 2026-04-30T00:00:00+00:00
**Last Updated**: 2026-04-30T00:00:00+00:00

---

## Content

A UserPromptSubmit hook detects planning-intent prompts and asks Claude to consult the wiki via the `wiki-recall` sub-agent before responding. The agent uses `wiki/topic-index.md` as a navigation map, greps for keywords, applies a relevance filter, and returns a compact context payload.

`/wiki-recall` is the manual equivalent — invoked when the hook didn't fire (non-planning phrasing) or for focused on-demand recall.

**Symmetry with capture:** the capture path is Stop hook → inbox → `/wiki-digest` → filed notes. The recall path is the read-side mirror: UserPromptSubmit hook → topic-index lookup → sub-agent grep+filter → context payload returned to Claude. Both paths use a hook to nudge Claude at the right lifecycle moment plus a focused sub-agent to do the work in a fresh context.

**Why both directions:** capture-only would let the wiki accumulate without ever paying back. The recall path is what makes the wiki worth maintaining — it surfaces prior decisions exactly when the model is about to make a related decision.

## Related Notes

- [[recall-prompt-hook|Recall Prompt Hook]]
- [[wiki-recall-subagent|Wiki Recall Subagent]]
- [[recall-skill|Recall Skill]]
- [[topic-index-as-recall-map|Topic Index As Recall Map]]
