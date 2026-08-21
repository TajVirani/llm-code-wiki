# Legend-State Review

## Objective

Verify Legend-State usage in the diff follows current v3 best practices, actually reduces
renders, is safe against React's component lifecycle, and doesn't overlap responsibilities
with other state systems. Report-only.

## Scope

- **Trigger:** files in the diff that import `@legendapp/state` or consume a legend-state
  store. If none, report "not applicable — no Legend-State usage in this diff" and stop.
- **Read:** each triggered component in full, plus the defining store modules of any
  observables it touches (e.g. `client/src/lib/state.ts`,
  `client/src/components/chat/chat-state.ts`) and sibling state sources in the same
  component (`useState`, TanStack Query hooks, contexts) — for context.
- **Report:** findings anchor to diffed files. Issues discovered in an un-diffed store are
  reported only when they materially affect a diffed component, clearly labeled
  "upstream of this diff".

## Refresh the checklist first

The baked checklist below is current as of 3.0.0-beta.48 (2026-07). Before reviewing:

1. Read the installed version from `client/package.json` (`@legendapp/state`).
2. Query context7 for the Legend-State v3 docs (library id
   `/websites/legendapp_open-source_state_v3`) on: reading state (`useValue`), fine-grained
   reactivity, migration notes, and React API pitfalls.
3. Where fetched docs contradict or extend the baked checklist, the fetched docs win — note
   the correction in the report. If context7 is unreachable, use the baked checklist as-is
   and say so.

## Checks

### 1. v3 API conformance

- `useValue` is the current canonical read hook. `use$` and `useSelector` are deprecated
  aliases slated for removal, and `use$` is incompatible with React Compiler. Existing
  `use$` calls in diffed files are a LOW finding (migration candidate); **new** `use$`/
  `useSelector` introductions are MEDIUM.
- `observer` HOC is an optional perf optimization (merges many `useValue` hooks into one) —
  not required for correctness. Flag `observer` wrapping used as the only reactivity
  mechanism with bare `.get()` reads inside (the old pattern).
- Reactive two-way binding uses `$React.input`-style reactive props, not
  value+onChange re-render loops feeding an observable.

### 2. Render-reduction reality

The point of the library is fine-grained subscriptions. Flag:

- Subscribing to a whole store or broad object (`useValue(state$)`,
  `useValue(state$.playback)`) when only leaf values are used — re-renders on every child
  change. Subscribe to leaves: `useValue(state$.playback.speed)`.
- Selector functions returning fresh objects/arrays each run
  (`useValue(() => ({...}))`) — never equal, so every change re-renders. Return primitives
  or stable references.
- Frequently-updating values rendered inline in an otherwise-static parent — wrap in
  `<Memo>` so the island re-renders without the parent.
- Bare `.get()` at the top of a component (untracked → stale UI, or inside `observer` →
  whole-component tracking where a scoped `useValue` would do).

### 3. React lifecycle safety

- No observable `.set()` in the render body. Writes belong in event handlers, effects, or
  `useObserve` callbacks. (StrictMode double-invokes render; render-time writes double-fire.)
- Reacting to observable changes uses `useObserve`, not `useEffect` with a `.get()` in the
  dependency array — `.get()` in deps does not resubscribe and the effect won't re-run.
- Stale-closure `.get()` snapshots captured in `useCallback`/`useMemo` where the value was
  meant to be reactive.
- Local component state uses `useObservable`, not a module-level `observable()` created per
  component (leaks state across instances).

### 4. Responsibility overlap (strict)

An observable, `useState`, TanStack Query, and context must not hold the same state. Flag:

- The same datum living in an observable **and** `useState`/`useReducer`.
- **Any server-derived data held in an observable, even transiently** (e.g. query results
  synced into a store for rendering). Project rule: TanStack Query owns server cache. Each
  instance is a finding the author must justify or remove.
- A context providing a value an observable already holds.
- Coexistence alone is NOT a finding — most components legitimately use TanStack Query for
  server data and legend-state for UI state side by side.

## Classification

| Severity | Description |
|----------|-------------|
| **HIGH** | Lifecycle hazard or same-state duplication — correctness risk |
| **MEDIUM** | Defeats render reduction, new deprecated API, unjustified server data in observable |
| **LOW** | Pre-existing deprecated alias, missed `Memo` opportunity |

## What to report

```
- **[SEVERITY]** `path/to/file.tsx:LINE` — [what's wrong]
  Check: [conformance / render-reduction / lifecycle / overlap]
  Doc basis: [baked checklist | fetched v3 docs (topic)]
  Suggestion: [concrete fix]
```

Upstream store issues: same format, prefixed `(upstream of this diff)`.

## What NOT to flag

- Coexistence of TanStack Query and legend-state in one component (only same-state overlap).
- Intentionally non-reactive `.get()` reads in event handlers.
- Store architecture choices in un-diffed files that don't affect a diffed component.
- Test files.
