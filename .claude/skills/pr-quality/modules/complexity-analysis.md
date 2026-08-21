# Complexity Analysis

## Objective

Identify overly complex files, components with poor structure, and misplaced shared logic. Suggest refactoring to improve maintainability.

## Checks

### 1. File Size (>300 lines)

For each changed file:
- Count total lines (excluding blank lines and comments)
- Flag files exceeding 300 lines of actual code
- Suggest what can be extracted (helper functions, sub-components, constants)

### 2. Multiple Components Per File

For `.tsx` files:
- Count the number of React component definitions (function components, arrow components)
- A file should contain ONE primary component
- Co-located small components (e.g., a list item used only by the list) are acceptable IF the file stays under 300 lines
- Flag files with 3+ components — these should be split

Detection patterns:
```
export function ComponentName    → exported component
export const ComponentName =     → exported arrow component
function ComponentName(          → local component (PascalCase + JSX return)
const ComponentName =            → local arrow component (PascalCase + JSX return)
```

### 3. Component Co-location

For components with dependent files (hooks, utils, types, styles):
- If a component `Foo.tsx` has `useFoo.ts`, `foo-utils.ts`, `foo-types.ts` in the same flat directory alongside unrelated components:
  - Suggest creating a `foo/` subdirectory with `index.tsx`, `use-foo.ts`, `foo-utils.ts`, `foo-types.ts`
- If the dependent files are only used by that one component, they belong together

Detection: Look for files that share a naming prefix or that are only imported by one component.

### 4. Misplaced Shared Logic

Logic used by 2+ components in different directories should NOT live inside one component's directory:
- Search for utility functions in component directories that are imported by other directories
- These should be elevated to:
  - `lib/` for general utilities
  - `hooks/` for shared hooks
  - `types/` for shared types
  - `utils/` for domain-specific shared logic

Detection: For each function/hook defined in a component directory, `Grep` for imports from other directories.

### 5. Deep Nesting

Flag functions with:
- 4+ levels of indentation (nested if/for/try)
- Callback hell patterns (nested `.then()` chains or nested callbacks)
- Suggest early returns, guard clauses, or extraction into helper functions

## What to Report

For each finding:
```
- **[CHECK]** `path/to/file.tsx` — [issue description]
  Lines: X (threshold: 300)
  Components: Y (threshold: 1 primary + small helpers)
  Suggestion: [specific refactoring action]
```

## What NOT to Flag

- Generated files (`*.gen.ts`, `routeTree.gen.ts`)
- Test files (size limits don't apply to tests)
- Schema files (Drizzle schemas can be long by nature)
- Files in `ui/` directory (shadcn components are vendor code)
- Configuration files
