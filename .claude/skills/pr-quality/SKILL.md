---
name: pr-quality
description: |
  PR code quality review dispatching parallel sub-agents for duplicate detection,
  orphan detection, complexity analysis, seam conformance, documentation conformance,
  Legend-State usage review, and recurring project pitfalls against the branch diff.

  Triggers: pr quality, code review, duplicate code, orphaned code, complexity review, pr cleanup

  Use when: before merging a PR, after completing feature work, code cleanup passes
  DO NOT use when: mid-feature development, single-file changes, non-code PRs
category: code-quality
tags: [pr-review, duplicates, orphans, complexity, refactoring, documentation, legend-state]
tools: [Agent, Bash, Grep, Glob, Read]
modules:
  - duplicate-detection
  - orphan-detection
  - complexity-analysis
  - seam-conformance
  - doc-conformance
  - legend-state-review
  - project-pitfalls
progressive_loading: true
estimated_tokens: 700
version: 1.1.0
---

# PR Quality Review

Parallel code quality analysis for PR branches. Dispatches seven independent sub-agents to analyze the diff against `origin/main`. All seven run every time; agents whose scope doesn't apply self-skip cheaply and say so (a silent skip reads as "checked and clean").

## Workflow

```
git diff origin/main → changed files + branch name + commit subjects
         ↓
 ┌────┬────┬────┬────┬────┬────┐
 ↓    ↓    ↓    ↓    ↓    ↓    ↓
Dupe Orph Cmplx Seam Docs LgSt Pitf
 ↓    ↓    ↓    ↓    ↓    ↓    ↓
 └────┴────┴────┴────┴────┴────┘
         ↓
  Consolidated Report
```

## Scope Rules

- **Only analyze source files**: `.ts`, `.tsx`, `.go`
- **Skip**: `node_modules`, `dist`, `build`, `.gen.ts`, `*.test.*`, `*.spec.*`, config files
- **New code focus**: Duplicate detection compares new functions against the existing codebase and against each other
- **Whole-file scope**: Orphan, complexity, and Legend-State checks examine the full file, not just the diff hunks
- **Context reads beyond the diff**: doc-conformance reads the branch's `specs/` folder, cited ADRs, and sweeps `docs/architecture/` + `wiki/`; legend-state-review reads defining stores and sibling state sources — but findings always anchor to the diff
- **Self-skips**: no spec folder → doc agent reports it and stops; no `@legendapp/state` in the diff → legend-state agent reports "not applicable"; pitfalls agent runs only the sections matching the diff's file types and lists skipped sections

## Analysis Modules

See `modules/duplicate-detection.md` for duplicate code methodology.
See `modules/orphan-detection.md` for orphaned code methodology.
See `modules/complexity-analysis.md` for complexity analysis methodology.
See `modules/seam-conformance.md` for deep-module / seam conformance against `docs/architecture/surfaces.md`.
See `modules/doc-conformance.md` for spec/PRD ↔ code conformance and doc-drift detection (two-tier severity).
See `modules/legend-state-review.md` for Legend-State v3 best-practice, render-reduction, lifecycle, and overlap checks (baked checklist + live context7 refresh).
See `modules/project-pitfalls.md` for recurring fix patterns mined from this repo's history (RPC/Query discipline, shared/-first utilities, style anti-patterns, backend pitfalls, event propagation, icon shim, patch alignment).

## Report Format

Each agent returns structured findings. The orchestrator consolidates them into a single report with seven sections, counts, and actionable suggestions.

Findings without file paths and line numbers are not actionable — always include them.
