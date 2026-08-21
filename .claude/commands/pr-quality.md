PR code quality review using parallel sub-agents. Analyzes the current branch diff against main for seven categories of issues.

## Instructions

You are running a PR quality review. Follow these steps exactly:

### Step 1: Gather Context

Run these commands to understand what changed:
```bash
git diff origin/main --name-only --diff-filter=ACMR
```
This gives you the list of new/modified files in this PR. Focus on source files (`.ts`, `.tsx`, `.go`) — ignore config, generated files, `node_modules`, `dist`, `.gen.ts`.

Also run:
```bash
git diff origin/main --stat
git rev-parse --abbrev-ref HEAD
git log origin/main..HEAD --pretty="%s"
```
The branch name and commit subjects feed the doc-conformance agent (spec folder lookup + cited-ADR detection).

### Step 2: Launch 7 Parallel Sub-Agents

Dispatch ALL SEVEN agents simultaneously using the Agent tool. Each agent must receive the full list of changed files from Step 1; agents 5–7 also receive the branch name and commit subjects. Agents self-skip when their scope doesn't apply — a skip is reported, never silent.

**Agent 1: Duplicate Code Detection**
- subagent_type: `Explore`
- Prompt: Use the duplicate detection methodology from `Skill(pr-quality)` module `duplicate-detection`. Provide the agent with the list of changed files. The agent should:
  1. Read each new/modified file to extract new functions and components
  2. Search the broader codebase for similar logic patterns
  3. Compare new functions against each other for internal duplication
  4. Report findings as a structured list

**Agent 2: Orphaned Code Detection**
- subagent_type: `Explore`
- Prompt: Use the orphan detection methodology from `Skill(pr-quality)` module `orphan-detection`. Provide the agent with the list of changed files. The agent should:
  1. Identify all exported functions, components, types, and constants in changed files
  2. Search the codebase for imports/references to each export
  3. Check for dead code left behind by refactors (renamed files show up in git status as R)
  4. Report unreferenced exports

**Agent 3: Complexity Analysis**
- subagent_type: `Explore`
- Prompt: Use the complexity analysis methodology from `Skill(pr-quality)` module `complexity-analysis`. Provide the agent with the list of changed files. The agent should:
  1. Check file line counts (flag >300 lines)
  2. Detect files with multiple component/function exports that should be split
  3. Identify components with co-located helper files that should be in a subfolder
  4. Flag shared logic buried in component directories that should be elevated to `lib/` or `utils/`
  5. Report findings with specific refactoring suggestions

**Agent 4: Seam Conformance**
- subagent_type: `Explore`
- Prompt: Use the seam-conformance methodology from `Skill(pr-quality)` module `seam-conformance`. First read `docs/architecture/surfaces.md` (the load-first concept/seam index) and `.claude/skills/improve-codebase-architecture/LANGUAGE.md` (vocabulary). Provide the agent with the list of changed files. The agent should:
  1. For each surfaced concept, check whether changed code reaches *past* its seam into internals instead of through the sanctioned entry point
  2. Flag new public exports that widen a concept's seam without earning their place (deletion test)
  3. Flag new shallow modules (interface nearly as complex as implementation) and new behaviour that duplicates what an existing surface already provides
  4. Flag substantial new subsystems not registered in `surfaces.md`
  5. Report findings with file:line, the concept/seam involved, and a concrete suggestion (route through the seam / keep private / merge / add surface entry)

**Agent 5: Documentation Conformance**
- subagent_type: `Explore`
- Prompt: Use the doc-conformance methodology from `Skill(pr-quality)` module `doc-conformance`. Provide the agent with the changed-file list, branch name, and commit subjects. The agent should:
  1. Locate the originating spec folder from the branch name (`specs/<branch>/`); no match → report that as a finding and stop
  2. Check spec.md/plan.md/tasks.md against the diff in both directions: doc claims without code, code without doc record, task checkbox state
  3. Check ADRs cited in commits/diff for contradiction
  4. Keyword-sweep `docs/architecture/` and `wiki/` for statements the diff makes false
  5. Report Tier 1 (spec/tasks/ADR mismatches) and Tier 2 (doc drift) separately, plus a one-line open-task inventory

**Agent 6: Legend-State Review**
- subagent_type: `Explore`
- Prompt: Use the legend-state-review methodology from `Skill(pr-quality)` module `legend-state-review`. Provide the agent with the changed-file list. The agent should:
  1. Exit immediately with "not applicable" if no diffed file uses `@legendapp/state`
  2. Refresh the module's baked v3 checklist via context7 (ToolSearch for `query-docs`, library `/websites/legendapp_open-source_state_v3`), falling back to the baked list if unreachable
  3. Read triggered components in full plus their defining stores and sibling state sources
  4. Check v3 API conformance, render-reduction reality, React lifecycle safety, and strict responsibility overlap (any server-derived data in an observable is a finding)
  5. Anchor findings to diffed files; label store-level issues "upstream of this diff"

**Agent 7: Project Pitfalls**
- subagent_type: `Explore`
- Prompt: Use the project-pitfalls methodology from `Skill(pr-quality)` module `project-pitfalls`. Provide the agent with the changed-file list. The agent should:
  1. Determine which checklist sections (A–G) match the diff's file types; list skipped sections explicitly
  2. Run each applicable section's checks against the diff
  3. Report findings with the rule violated and the sanctioned alternative

### Step 3: Consolidate Results

After all 7 agents complete, present a unified report:

```
## PR Quality Review

### Duplicate Code
[Agent 1 findings — list each instance with file paths and line numbers]

### Orphaned Code
[Agent 2 findings — list each unreferenced export with file path]

### Complexity Issues
[Agent 3 findings — list each file with specific issue and suggestion]

### Seam Conformance
[Agent 4 findings — list each violation with file:line, concept/seam, and suggestion]

### Documentation Conformance
[Agent 5 Tier 1 findings, then a "Doc Drift" subsection for Tier 2, then the open-task inventory line]

### Legend-State Review
[Agent 6 findings by check category, or "Not applicable — no Legend-State usage in this diff"]

### Project Pitfalls
[Agent 7 findings, plus the skipped-sections line]

### Summary
- X duplicate patterns found
- Y orphaned exports found
- Z complexity issues found
- W seam violations found
- V doc mismatches (+ D drift notes)
- U legend-state issues found
- T pitfall violations found
```

Only report actual findings. If a category has no issues, say "No issues found" for that section.
