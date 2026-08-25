# Phase 1 Reference: Invalid States

The core question for every type: **how many values can it represent, and how many does the domain allow?** The gap is where bugs live. Every finding must exhibit a concrete gap value.

## Smell catalog

**Boolean blindness.** N boolean flags = 2^N representable states; the domain rarely allows all of them. `{isActive, isDeleted, isPending}` = 8 states, probably 3 valid. Fix: one sum type.

**Status enum + parallel nullable fields.** `status` plus `approvedAt?`, `rejectedAt?`, `error?` where each field is only meaningful for one status. The classic. Fix: discriminated union carrying per-state data.

**Null/undefined/zero overloading.** One sentinel meaning several things: "not loaded yet" vs "loaded, absent" vs "error". Fix: explicit states (`NotAsked | Loading | Loaded<T> | Failed`), not a nullable field plus a comment.

**Primitive obsession.** `string` for email/UUID/currency-code, `int` for cents-vs-dollars, `float64` for money. Two symptoms: values swap silently at call sites (`func Transfer(from, to string)`), and validation is re-done (or forgotten) everywhere. Fix: newtypes with validated constructors.

**Parallel collections.** `names []string` + `ages []int` indexed together, or two maps keyed the same, kept in sync by discipline. Fix: one collection of one composed type. (Exception: deliberate SoA for performance — but then hide the parallelism behind one API, see phase 3.)

**Optional-required-by-state.** Fields marked optional because they're absent in *some* lifecycle stage, making them effectively untyped in the stage where they're required. Fix: one type per lifecycle stage (`DraftOrder` vs `PlacedOrder`), or a union.

**Stringly-typed enums.** `kind: string` compared against literals scattered through the code. Fix: closed enum / literal union; grep for the comparison sites to find undocumented variants.

**Invariants in comments.** `// items must be sorted`, `// len(a) == len(b)`, `// call Init first`. Comments are hopes. Fix: enforce in a constructor, or restructure so the invariant can't be violated.

**Temporal coupling.** Types that are invalid between `New()` and `Init()`/`Connect()`. Fix: constructor returns a fully-valid value or an error; no two-phase init.

**Collections that can't be empty / can't have duplicates — but are typed as plain slices.** If code panics or misbehaves on empty, the type should say non-empty.

## Fix patterns

### Parse, don't validate (all languages)

Validate once at the boundary and produce a *different, narrower type* as proof. Downstream code accepts only the narrow type, so validity can't be forgotten — it's carried by the type system.

```
raw input (wide type) → parse() → domain type (narrow) | error
```

If validation returns `bool` and the same wide type flows onward, that's validation, not parsing — flag it.

### TypeScript

**Discriminated unions + exhaustiveness.**

```ts
type Payment =
  | { status: "pending" }
  | { status: "approved"; approvedAt: Date; approvedBy: UserId }
  | { status: "rejected"; rejectedAt: Date; reason: string };

function render(p: Payment) {
  switch (p.status) {
    case "pending": /* ... */ break;
    case "approved": /* ... */ break;
    case "rejected": /* ... */ break;
    default: { const _exhaustive: never = p; return _exhaustive; }
  }
}
```

The `never` default turns "someone added a variant" into a compile error. When auditing, check whether existing switches over the discriminant have exhaustiveness enforcement; if not, that's a MEDIUM finding on its own.

**Branded types** for primitive obsession:

```ts
type UserId = string & { readonly __brand: "UserId" };
const UserId = (s: string): UserId => {
  if (!/^usr_[a-z0-9]{12}$/.test(s)) throw new Error(`invalid UserId: ${s}`);
  return s as UserId;
};
```

**Boundary parsing.** At API/DB/config boundaries, look for a schema library (Zod, Valibot, TypeBox, `@hono/zod-validator` in Hono apps). If raw `JSON.parse` output or `as` casts flow into domain code, that's HIGH: the wire shape is trusted, not parsed. The schema's inferred type should *be* the domain type or parse into it.

**Also check:** `readonly` on fields mutated nowhere; `satisfies` instead of widening annotations; `interface` merging surprises on public types; enums vs literal unions (prefer literal unions unless the enum is deliberate).

### Go

Go lacks sum types; the audit is about which encoding the code chose and whether it leaks.

**Sealed interface** (variants are structs; unexported method closes the set):

```go
type PaymentStatus interface{ isPaymentStatus() }

type Pending struct{}
type Approved struct {
    At time.Time
    By UserID
}
type Rejected struct {
    At     time.Time
    Reason string
}

func (Pending) isPaymentStatus()  {}
func (Approved) isPaymentStatus() {}
func (Rejected) isPaymentStatus() {}
```

Type switches over it won't be compiler-exhaustive — recommend `gocritic`/`exhaustive`-style linting or a `default: panic` in tests.

**Defined types + iota** for closed enums; check for a `String()` method and for validation at parse points (`ParseStatus(s string) (Status, error)`). An enum whose zero value is a valid-but-wrong state (e.g., `StatusActive = iota`) is a finding — make the zero value `StatusUnknown` or the safest state.

**Zero-value audit.** For every exported struct, ask: is `var x T` valid? Go conjures zero values everywhere (map misses, channel receives, `make([]T, n)`, unmarshal targets). If the zero value violates invariants, either make it valid ("make the zero value useful") or unexport fields and force a constructor:

```go
type Money struct { amount int64; currency Currency } // unexported: zero & literal construction blocked outside package

func NewMoney(amount int64, c Currency) (Money, error) { ... }
```

**Newtypes.** `type UserID string`, `type Cents int64`. Nearly free, kills argument-swap bugs. Check conversion sites: a cast `UserID(anyString)` scattered around defeats it — conversions should happen at parse boundaries only.

**Pointer-as-optional.** `*string` fields meaning "absent" invite nil derefs and confuse "absent" with "empty". Sometimes forced by JSON/SQL; if so, confine pointers to the wire struct and parse into a domain struct without them.

**nil vs empty slice/map** carrying meaning ("not fetched" vs "fetched, none") is an invisible invariant — flag it; encode the distinction explicitly.

**JSON boundary.** `json.Unmarshal` into the domain struct directly = trusting the wire. Look for a decode-then-validate step producing the domain type; absence at a public API boundary is HIGH.

## What NOT to flag

- Two booleans that are genuinely independent (2×2, all 4 valid).
- Wide types in test fixtures/internal tooling where the cost of tightening exceeds the risk.
- Codegen output (protobuf, sqlc) — flag the *absence of a parse layer on top*, not the generated shape itself.
- Idiomatic `(T, error)` returns in Go — that IS the sum type encoding; don't demand Result wrappers.
