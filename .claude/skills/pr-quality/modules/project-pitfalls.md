# Project Pitfalls

## Objective

Check the diff against recurring fix patterns mined from this repo's history — issues that
have each required at least one dedicated fix PR before. Static checklist; run only the
sections whose file types appear in the diff.

## Checks

### A. RPC/Query discipline — when the diff touches `client/`

- Hand-written `fetch("/api/v1/…")` against a v1 JSON endpoint instead of `athenaApi`
  (`@/lib/api`). Allowed exceptions: multipart file uploads (`c.req.parseBody()` endpoints)
  and calls to a different service base URL (e.g. weather-service).
- `useEffect` + `useState` fetch-and-cache where `useQuery`/`useMutation` should own
  caching, dedup, and invalidation.

### B. shared/-first utilities — any new pure utility function

Before accepting a new pure utility (canonical JSON, hashing, digests, unit/geo
conversion, formatting), grep `shared/src/` for an existing implementation.
`canonicalJSONStringify` was duplicated three times before dedup; conversions belong behind
`shared/units` (`convertUnits`/`convertGeoDegrees`), never hand-rolled factors.

### C. Style anti-patterns — when the diff touches `client/`

- **Boolean decomposition of state enums:** deriving `isPlaying`/`isPaused`/`isRecording`
  booleans from one status field. Use `status === "playing"` or a discriminated variable.
- **Ternary-chain class strings** assigned to variables instead of `cn()` inline on
  `className` (lookup-object-into-`cn()` is fine for mutually exclusive states).
- **Generic `utils.ts`** for component-scoped helpers — prefix with the component name
  (`recording-bar-utils.ts`); bare `utils.ts` is reserved for `/lib/`.

### D. Backend pitfalls — when the diff touches server-side TS

- **Raw `required[]` trust:** reading a JSON-schema `required` array directly instead of the
  helpers in `shared/src/tool-schema.ts` / `lib/tool-schema-reads.ts` (optional-param leak).
- **Bare `.refine` for either-or** schema constraints instead of the shared helpers.
- **AGE/postgres.js:** any AGE query without `SET LOCAL search_path` (bare `SET` hits
  ag_catalog shadow tables); `= ANY(sql.array(...))` instead of `IN sql(list)` or a
  `::type[]` cast.
- **Drizzle single-row reads:** endpoints returning one object must destructure
  `const [row] = await db.select()…` — `.select()` always returns arrays.

### E. Event propagation guards — when the diff adds DOM listeners

- New `document`/`window`-level listeners or drag-drop handlers must be scoped or guarded so
  they don't leak into other panels (page-wide file drops landed in the chat composer twice).
- Leaflet containers: `L.DomEvent.disableClickPropagation` blocks React 18 synthetic events
  (root-delegated). It must stay conditional to `.leaflet-container`; child elements needing
  React events use native `addEventListener` via refs.

### F. Icon shim conformance — when the diff touches `client/`

Any `from "lucide-react"` import is a finding — icons come from the `@/lib/icons` shim
(a whole stragglers-hotfix branch was needed last time). Cheap: grep the diff for it.

### G. Patch alignment — when the diff touches `package.json`/`bun.lock`

Each `patchedDependencies` key in root `package.json` must match the version the lockfile
actually resolves. A patch keyed to an older version silently stops applying on dep bumps.

## What to report

```
- **[PITFALL-X]** `path/to/file.ts:LINE` — [what recurred]
  Rule: [one-line statement of the convention]
  Suggestion: [the sanctioned alternative]
```

Skipped sections: list them in one line ("sections D, G skipped — no matching files in
diff"). Silent skips read as "checked and clean".

## What NOT to flag

- The documented exceptions in section A (file uploads, other-service calls).
- Pre-existing violations in unchanged lines of a diffed file — note them at most once,
  clearly labeled pre-existing.
- Generated files, `ui/` shadcn components, test fixtures.
