---
name: wiki-recall
description: Manually surface prior wiki context relevant to a topic or task. Forks into the wiki-recall sub-agent. Use when the recall hook didn't fire (non-planning phrasing) or you want to recall against a specific topic.
disable-model-invocation: true
user-invocable: true
context: fork
agent: wiki-recall
allowed-tools: Read, Glob, Grep
argument-hint: "[optional recall query; defaults to the current conversation context]"
---

# /wiki-recall — Surface relevant wiki context

The user invokes `/wiki-recall` to consult the project wiki on demand — usually because the recall hook didn't fire (the prompt didn't trigger planning-intent keywords) or because they want a focused recall against a specific topic.

This skill's body is the prompt the wiki-recall subagent receives when forked. The agent (defined at `.claude/agents/wiki-recall.md`) owns the navigation, keyword extraction, grep, relevance-filter, and output-format logic. This skill body owns the LIFECYCLE around that work: resolving the recall query and surfacing the agent's return verbatim.

## Resolve the recall query

If `$ARGUMENTS` is non-empty, use it as the recall query. Otherwise the query is "the current conversation context" — the agent should infer the user's working topic from the recent transcript-relevant excerpt the parent thread provides.

## Step 1 — Confirm the wiki exists

Check that `wiki/` and `wiki/Rules.md` exist. If `wiki/` is absent: print "No wiki found at `wiki/`. Run `/wiki-install` first." and exit. If `wiki/Rules.md` is absent: print "Wiki present but `wiki/Rules.md` is missing. Run `/wiki-install` to restore the contract." and exit.

## Step 2 — Pass the query to the wiki-recall agent

Per the frontmatter `context: fork` + `agent: wiki-recall`, this skill body is delivered to a forked wiki-recall subagent in a fresh context. The agent follows its 6-step protocol (defined in `.claude/agents/wiki-recall.md`):

1. Read `wiki/topic-index.md` (navigation map).
2. Extract keywords from the query.
3. Match keywords against the index → primary candidate set.
4. Grep the wiki corpus for additional hits → secondary candidate set.
5. Read top candidates (cap 8) and apply the relevance filter.
6. Return a structured "Recalled wiki context" block (≤400 words).

The agent is read-only — `tools: Read, Glob, Grep`. It cannot write, edit, or modify any file.

## Step 3 — Surface the agent's return

The agent's payload is the entire output of this skill. Do not summarize, paraphrase, or filter further. The parent thread (the user's main session) reads it directly.

If the agent returns "Nothing relevant found", surface that verbatim — it tells the user the wiki has no relevant prior context, which is itself useful information.

## Non-fork fallback

If `CLAUDE_CODE_FORK_SUBAGENT=0` (or unset, depending on Claude Code version), `context: fork` falls back to inline execution and context isolation is lost. The wiki-recall agent's protocol is identical in both cases; only the invocation path changes. The output format is the same.

## Things this skill does NOT do

- Does NOT modify any wiki file — the agent has no write tools.
- Does NOT update `wiki/topic-index.md` — that's the wiki-digest skill's job.
- Does NOT trigger code changes or planning — recall surfaces context only; the parent thread decides what to do with it.
