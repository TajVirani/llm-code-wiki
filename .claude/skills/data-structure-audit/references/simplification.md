# Phase 2 Reference: Simplification

Phase 1 asks "can this type lie?" Phase 2 asks "does this type make everyone work too hard?" Evidence is always call sites: a shape is only too complex if you can point at the code paying for it. Cite 3+ sites per finding where possible.

## Smell catalog

**Repeated derivation.** The same computation from a type's fields appears at multiple call sites (`user.first + " " + user.last`, re-filtering the same slice, re-parsing a string field). Fix: a method/helper next to the type, or precompute at parse time. If callers derive it *differently*, upgrade severity — that's divergent business logic.

**Stored derived data.** A field that is a function of other fields (`total` alongside `items`, `count` alongside a slice) and updated by discipline. Two sources of truth, one desync bug away. Fix: compute on read; memoize only with profiling evidence (phase 3's problem). If it must be stored (persisted aggregates), name the single write path that maintains it.

**Denormalized copies.** The same fact embedded in multiple structs (user's name copied into every Order). Fine as a deliberate read-model; a smell when updates must fan out and there's no mechanism ensuring they do. Fix: hold IDs, join at the edge — especially in React state, where the normalized store + selector pattern replaces deep cloned trees.

**Wide struct, narrow consumers.** A 20-field struct where most functions read 2 fields. Symptoms: hard-to-construct test fixtures, unclear dependencies, everything coupled to everything. Fix: split along usage seams, or (Go) accept small interfaces / (TS) accept `Pick<T, ...>` at consumption points.

**God map / bag of any.** `map[string]interface{}`, `Record<string, unknown>`, `metadata` blobs that accumulate load-bearing keys. Grep the key literals: every distinct key accessed in code is an undeclared field. Fix: promote the accessed keys to a typed struct; keep a spillover bag only for genuinely open data.

**Deep access paths.** `a.b.c.d.e` chains repeated everywhere signal the shape mirrors storage or wire format, not usage. Fix: flatten at the parse boundary, or provide accessors at the level callers think.

**Config sprawl.** One mega-config threaded through everything, so every component depends on all settings. Fix: per-component config structs assembled at the composition root.

**Speculative generality.** Type parameters, interfaces, or option fields with exactly one instantiation in the repo. Cost with no payoff. Fix: delete; restore when the second case is real. (Check git history / grep before flagging — the second implementation might live in another service.)

**Unused fields.** Fields written but never read (or only in dead code). Verify with grep, then delete. Serialization boundaries excepted — a field may exist only for a consumer outside the repo; note that instead.

**Temporal call ordering.** APIs where correctness depends on call order the types don't enforce (`Begin` → `Add` → `Finish`). Fix: builder that only yields the usable type at the end, or a function that takes all inputs at once. (Overlaps phase 1 when misuse produces invalid values; here it's about the caller burden even when misuse merely errors.)

## Simplification directions

**Separate the three kinds of data.** Identity (who), state (current facts), derived (computable). Complexity often comes from one struct mixing all three plus infrastructure handles (loggers, DB pools). Domain types should be plain data; effects live elsewhere.

**Make the common construction trivial.** If 90% of call sites pass the same defaults, provide a constructor with those defaults (Go: functional options or a `New` with sensible zero handling; TS: a partial-with-defaults factory). Count constructor call sites to prove it.

**Prefer plain data at rest, behavior at the edges.** Methods that just get/set (anemic ceremony) add nothing — plain fields are fine. Methods earn their place when they enforce invariants or centralize a derivation.

**One collection, one shape.** Replace parallel structures with a single slice of a composed type unless phase 3 evidence says otherwise.

## Simplicity vs. brevity

Simplification is fewer *concepts and sync obligations*, not fewer characters. A discriminated union with 3 variants is longer than `status: string` and much simpler. Never report "made it shorter" as a win; report "removed N sync obligations / M repeated derivations / K impossible call orders."

## What NOT to flag

- Deliberate read models / caches with a clear, single write path.
- Wire/DB structs mirroring an external schema — that's their job; the smell is only when they leak past the boundary.
- Duplication across service boundaries (each service owning its own shape is often correct).
- A little repetition (2 call sites) — the rule of three applies.
