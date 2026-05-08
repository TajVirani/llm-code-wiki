# design-pattern-doc — conventions for athena

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
- common suffixes: -design-pattern, -current-design-pattern, -architecture, -redesign
- topic-first (e.g. `mcp-tool-current-design-pattern.md`, not `current-design-pattern-mcp-tool.md`)
- avoid acronym-only names

## Style notes
- match docs/architecture/README.md
- mermaid for flows; tables for entity catalogs
- ≤4 sentences per paragraph
- code citations: `path/to/file.ext:line`
- no emoji
- no marketing prose ("seamless", "powerful", "robust", "comprehensive")
- no filler ("Of course", "Note that", "It's important to")
- "NOT IMPLEMENTED" / "STUB" / "DEFERRED" — capital labels, used when accurate

## Verification commands
- build (opt-in): bun run build
- lint (opt-in): bun run lint
- type-check (opt-in): bun run type-check

## Notes
- Athena is a Bun + Hono + React + Drizzle monorepo. Architecture overview is in `docs/architecture/README.md` and is mermaid-heavy.
- Specs live in `specs/<NNN>-<feature-name>/` and are referenced from architecture docs.
- ADRs live in `docs/decisions/` and use a TL;DR-first style (see `docs/decisions/osm-spatial-mcp-language.md`).
- Sequence diagrams live in `docs/diagrams/` (separate from narrative architecture docs).
- Workspace imports do not resolve when running per-package; always run from repo root via `task dev` / `bun run dev` (see auto-memory).
