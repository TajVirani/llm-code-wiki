# Duplicate Code Detection

## Objective

Find logic that is duplicated between new/modified code and the existing codebase, or between new functions themselves.

## Process

### 1. Extract New Functions and Components

For each changed file:
- Read the full file content
- Identify all function declarations, arrow functions assigned to variables, and React component definitions
- Extract the function signature and body logic (ignore naming differences)

### 2. Cross-Reference Against Existing Code

For each new function/component:
- Identify the core operation (e.g., "filters an array by property X", "formats a date string", "fetches data from endpoint Y")
- Search the codebase for functions with similar:
  - Parameter signatures (same number/types of args)
  - Return types
  - Core logic patterns (loops, conditionals, API calls)
  - Utility operations (string manipulation, array transforms, date formatting)
- Use `Grep` to search for key identifiers, method calls, or patterns from the function body

### 3. Cross-Reference New Functions Against Each Other

Compare all new functions within the PR to find:
- Two functions that do the same thing with different names
- Functions that share >60% of their logic
- Copy-pasted code with minor parameter changes

### 4. Classification

| Severity | Description |
|----------|-------------|
| **HIGH** | Identical logic exists elsewhere — direct duplicate |
| **MEDIUM** | Similar logic with minor variations — candidate for shared utility |
| **LOW** | Overlapping patterns that may benefit from abstraction |

## What to Report

For each finding:
```
- **[SEVERITY]** `path/to/new-file.ts:functionName` (line X)
  Duplicates: `path/to/existing-file.ts:existingFunction` (line Y)
  Reason: [brief description of the shared logic]
  Suggestion: [extract to shared utility / use existing function / parameterize]
```

## What NOT to Flag

- Standard patterns (React hooks setup, basic CRUD operations, import boilerplate)
- Framework-required code (route definitions, schema declarations)
- Type definitions that mirror each other across client/server (these are intentional shared types)
- Test setup/teardown boilerplate
