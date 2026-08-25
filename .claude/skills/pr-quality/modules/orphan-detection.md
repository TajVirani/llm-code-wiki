# Orphaned Code Detection

## Objective

Find functions, components, types, and constants that are exported but never imported or referenced anywhere in the codebase.

## Process

### 1. Inventory Exports from Changed Files

For each changed file, catalog:
- Named exports (`export function`, `export const`, `export type`, `export interface`)
- Default exports (`export default`)
- Re-exports (`export { X } from`)

### 2. Search for References

For each export, search the codebase:
- `Grep` for the exact export name across all source files
- Check for dynamic imports (`import()`)
- Check for barrel file re-exports (`index.ts` files)
- For React components, search for JSX usage (`<ComponentName`)
- For types, search for usage in type annotations and generics

### 3. Check for Rename Orphans

When `git status` shows renamed files (R prefix):
- The old file path may still be imported somewhere — these are broken imports, not orphans
- The new file should have all its exports referenced
- Check if the old filename's exports are now dead code in other files that haven't been updated

### 4. Check for Refactor Orphans

When functions are moved between files:
- The original file may still export a wrapper or re-export that nobody uses
- Helper functions that served the moved code may now be unused
- Types that were only used by the moved code may be orphaned

### 5. Classification

| Severity | Description |
|----------|-------------|
| **HIGH** | Export has zero references anywhere — safe to remove |
| **MEDIUM** | Export only referenced in one place — may be over-exported (could be local) |
| **LOW** | Export referenced but the referencing code is also new/changed — verify chain |

## What to Report

For each finding:
```
- **[SEVERITY]** `path/to/file.ts` exports `functionName` (line X)
  References found: 0
  Suggestion: [remove export / delete function / convert to local]
```

## What NOT to Flag

- Exports from `index.ts` barrel files (these are re-export aggregators)
- Exports from route files (used by the router framework)
- Exports from schema files (used by Drizzle ORM at runtime)
- Server route handler exports (mounted by Hono)
- Type exports from `shared/` (may be used by external consumers)
- Exports with `@public` or `@api` JSDoc tags
