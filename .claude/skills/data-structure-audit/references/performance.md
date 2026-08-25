# Phase 3 Reference: Performance

**Measure first.** This phase's findings are hypotheses until a benchmark or profile confirms them. Ask for: Go — pprof profiles, `go test -bench` + benchstat results; TS — Chrome/Node CPU + heap profiles, React Profiler traces. If none exist, offer to write a microbenchmark for the top finding rather than recommending blind changes. Exception: the "obvious costs" below may be reported unmeasured, labeled `unverified`.

Structure changes trade readability for speed — only spend that budget on demonstrated hot paths, and never reopen a phase-1 fix to save nanoseconds.

## Obvious costs (reportable without a profile, always labeled unverified)

- Per-item heap allocation inside a hot loop (Go: `&T{}` per element, string concat in loops; TS: object/closure churn per frame or per request).
- `[]*T` where `[]T` works: pointer chasing defeats cache locality and gives the GC N pointers to trace instead of one block.
- A map used as a fixed-field record (known keys) instead of a struct.
- Growing a slice/array in a loop with a knowable final size and no preallocation.
- Deep-cloning a large object graph to change one field on every update.

## Go

**Field ordering / padding.** Structs are padded to alignment; ordering fields large-to-small can shrink them. Run the check instead of eyeballing: `fieldalignment ./...` (from `golang.org/x/tools/go/analysis/passes/fieldalignment`). Only worth reporting for structs allocated in bulk (slices of thousands+); a 40→32 byte win on a config struct is noise. Note the readability cost — grouped-by-meaning fields may be worth more than saved bytes.

**Values vs pointers.**
- `[]T` stores elements contiguously: one allocation, sequential access is cache-friendly, GC scans it cheaply (and skips it entirely if T is pointer-free).
- `[]*T` scatters elements: N+1 allocations, every access a potential cache miss, N pointers for GC to trace.
- Rules of thumb to audit against: pointers are warranted for shared mutable identity, very large structs frequently copied, or "optional" semantics (which phase 1 already frowned on). Uniform data processed in bulk wants values.

**Escape analysis.** `go build -gcflags='-m'` shows what escapes to heap. Common escape causes visible in a structure audit: returning pointers to locals from constructors called per-item, interface conversions in hot loops, closures capturing loop state.

**Interfaces in hot paths.** Storing values in interfaces (incl. `any`) boxes them (allocation for non-pointer types) and prevents inlining. A `[]any` or `[]fmt.Stringer` holding millions of homogeneous items should be a concrete `[]T` or generic.

**Maps.** Great for dynamic keys; costs hashing, bucket overhead, and (Go maps of non-pointer-free types) GC scan time. Audit for: maps with small fixed key sets (→ struct), maps iterated in order-sensitive code (map order is random — correctness bug, not just perf), giant long-lived maps of pointerful values (GC pause contributor; consider index-into-slice: `map[K]int` + `[]T`).

**Strings.** Immutable; every `+` in a loop allocates. Look for `strings.Builder` / preallocated `[]byte` in hot paths, and `[]byte`↔`string` conversion churn at boundaries.

**Preallocation.** `make([]T, 0, n)` when n is known; `slices.Grow` for incremental knowledge. Also check `sync.Pool` for high-frequency short-lived buffers — but only with allocation-profile evidence.

**SoA (struct of arrays).** When a hot loop touches 2 of a struct's 12 fields over millions of elements, splitting those fields into their own slices multiplies cache efficiency. This is the *one* justified form of parallel collections — require it to be wrapped in a type that owns the sync invariant (append/remove go through methods), so phase 1/2 findings don't regress.

## TypeScript / JavaScript

**Shape stability (hidden classes).** Engines optimize objects with consistent shapes. Audit for: objects of the same conceptual type created with different key sets/orders, keys added conditionally after creation, `delete obj.key` (transitions to dictionary mode). Fix: initialize every field at creation (use `null`, not absence), same order, one factory. This is cheap and usually *improves* type clarity — a rare phase-1-aligned perf win.

**Arrays.** Keep element kinds uniform (all numbers, or all same-shaped objects); avoid holes (`arr[1000] = x` on a short array, `delete arr[i]`) — holey arrays deoptimize. For bulk numeric data (geo coords, time series — common in geospatial viz), typed arrays (`Float64Array`) beat `number[]` on memory and iteration, and transfer to workers without copying.

**Map vs object.** `Map` for dynamic key churn (add/remove cycles keep objects out of dictionary mode) and non-string keys; plain objects for fixed-shape records. `Map` iterates in insertion order reliably.

**Immutable-update churn (React).** Spread-cloning a large nested tree on every keystroke = allocation storm + broken memoization (every reference changes). Audit for: state normalized as `{byId: Record<Id, T>, allIds: Id[]}` vs deep trees; update paths that preserve references of untouched branches; stable references for selectors (`useMemo`, or a structural-sharing lib like Immer). Referential stability is both a perf and correctness (stale-memo) concern.

**Serialization shape.** For payloads crossing the network in bulk, arrays-of-arrays or column format can beat arrays-of-objects several-fold in bytes and parse time — worth it only at scale, and hide the columnization behind a decode step so app code sees real objects (or keeps typed arrays end-to-end for numeric data).

**Allocation in render/loop.** New closures, objects, and arrays created per item per frame. In hot lists: hoist constants, memoize row components, avoid inline object props.

## Reporting

For each performance finding include: the structure, the access pattern that makes it hot (with file:line of the loop, not just the type), the proposed layout, expected effect ("removes N allocations per request", "makes scan sequential"), and the benchmark that would confirm it. If you wrote/ran a benchmark, include before/after numbers via benchstat or equivalent; a single run is not evidence.

## What NOT to flag

- Anything off the hot path. Config loading, CLI startup, admin endpoints — readability wins.
- Micro-layout of structs allocated a handful of times.
- Replacing clear code with clever code for unmeasured gains.
- Node/bundler-level concerns (lazy imports, chunking) — out of scope; this audit is data structures.
