---
name: wiki-rules
description: Authoritative wiki conventions. Re-reads wiki/Rules.md at activation. Preloaded into the wiki-curator subagent so the contract is in context from turn 1.
user-invocable: false
disable-model-invocation: false
allowed-tools: Read
---

# Wiki rules contract carrier

This skill does not contain the wiki rules. It POINTS at them. The rules live in `wiki/Rules.md`, which is the only source of truth and which the user is allowed to edit at any time. Treating any other copy as authoritative leads to drift — see research/ARCHITECTURE.md anti-pattern 2.

## What you must do at activation

1. Read `wiki/Rules.md` using your Read tool. Read it in full, not partially.
2. Treat its contents as the authoritative contract for this run. Every routing decision, every filename, every template field, every wiki-link must conform.
3. If `wiki/Rules.md` does not exist, halt and surface the missing-contract condition to the caller. Do not invent rules.

## What you must NOT do

- Do not modify `wiki/Rules.md`. Per DIGS-13 / D-16, the curator may PROPOSE rule changes in its plan output as suggestions for the user to apply manually. It must never edit Rules.md autonomously.
- Do not assume any prior session's view of Rules.md is current. The user may have edited it between digests.
- Do not file notes into `wiki/_templates/` or `wiki/inbox/` (Rules.md §9).

## Why a thin pointer instead of a mirror

Mirroring Rules.md into this skill body would:
- Drift silently when the user edits the real file.
- Bloat every curator spawn with a duplicate copy of a file Read can fetch in one tool call.
- Create two sources of truth, neither of which is unambiguously correct.

Reading fresh costs one tool call per digest run. The cost is trivially worth the correctness guarantee.
