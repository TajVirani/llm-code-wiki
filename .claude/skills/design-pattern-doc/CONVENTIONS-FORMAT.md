# conventions.md format

Per-project state for `design-pattern-doc`. Auto-populated on first run by the skill; the user can hand-edit at any time. The skill reads this file before every invocation.

## File location

`.claude/skills/design-pattern-doc/conventions.md` — same directory as `SKILL.md`. Per-project (the file is project-local; each repo gets its own).

## Schema

Single markdown file. H2 sections in this order. Skill reads each section by header; missing sections fall back to defaults.

```markdown
# design-pattern-doc — conventions for <project name>

## Doc locations
- design patterns: docs/architecture/
- decisions / ADRs: docs/decisions/
- diagrams: docs/diagrams/

## Anchor files
- CLAUDE.md
- docs/architecture/README.md

## Drift scan globs
- CLAUDE.md
- docs/**/*.md
- specs/**/*.md
- README.md

## Naming conventions
- kebab-case
- common suffixes: -design-pattern, -current-design-pattern, -architecture
- avoid acronym-only names

## Style notes
- match docs/architecture/README.md
- mermaid for flows
- tables for entity catalogs
- ≤4 sentences per paragraph
- no emoji
- no marketing prose

## Verification commands
- build (opt-in): bun run build
- lint (opt-in): bun run lint
- markdown lint (opt-in): (none configured)

## Notes
- Athena uses Hono + React + Bun. Architecture overview is in docs/architecture/README.md and is mermaid-heavy.
- Specs live in specs/<NNN>-<feature-name>/. Many are referenced from architecture docs.
```

## Section meanings

### Doc locations

A bullet list mapping doc-type to directory. Three buckets:
- **design patterns** — where this skill writes its primary output. Required.
- **decisions** — where ADRs live. Optional. Used only for cross-references when an ADR exists for a sub-topic.
- **diagrams** — where sequence/flow diagrams live separately from narrative docs. Optional. Used for cross-references.

### Anchor files

Files the skill must read before launching exploration agents. The first item is the most-load-bearing file (typically `CLAUDE.md` or the architecture README). Order matters — earlier entries weighted more heavily in style matching.

### Drift scan globs

Glob patterns the skill scans for drift candidates. Greedy by default (`docs/**/*.md`, `specs/**/*.md`, `CLAUDE.md`, `README.md`). User can narrow if scans are too expensive (e.g., exclude `specs/_archive/**`).

### Naming conventions

Free-form notes the skill uses when proposing a filename for a new doc. The skill scans existing files in the design-patterns location for patterns; this section captures whatever the skill couldn't auto-detect or that the user explicitly chose.

### Style notes

Free-form. The skill reads these and applies them when writing the new doc. The most important one is "match `<file>`" — the skill samples that file's prose to mimic structure and tone.

### Verification commands

Commands the skill MAY run for opt-in verification. The skill never runs these by default — only when the user passes a `--verify-build` / `--verify-lint` style flag, or auto mode opts in via the user's harness setup. Each command is project-specific (Bun, npm, Make, Task, etc.).

### Notes

Free-form. Anything that didn't fit the structured sections. Useful for user hand-edits.

## First-run behavior

When `conventions.md` is missing, the skill:

1. Creates the file with auto-detected values (locations, anchor files, scan globs, verification commands inferred from `package.json` / `Taskfile.yml` / `Makefile`).
2. Tells the user: *"First run — wrote `conventions.md` to `<path>`. Edit it if I got anything wrong, then re-invoke."*
3. Stops. Does NOT proceed to explore. The user reviews the conventions before the first real run.

This keeps the skill from making bad assumptions on novel projects.

## Update behavior

The skill never silently rewrites `conventions.md`. If during a run the user explicitly answers a scope-clarification question that reveals a wrong convention (e.g., "actually we put architecture docs in `documentation/architecture/`"), the skill amends the file and tells the user it did so.
