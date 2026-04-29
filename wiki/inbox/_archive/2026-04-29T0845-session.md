# Session Inbox (FIXTURE)

**Status**: hand-authored test corpus — NOT live session state
**Purpose**: Phase 1 acceptance gate for the digest sub-agent (per .planning/phases/01-foundation-curator/01-CONTEXT.md D-09)

---

@ ARCHITECTURE::caching-layer-overview  •  src/lib/cache/  •  #architecture #caching #redis
Three-tier caching strategy: in-memory LRU for hot reads, Redis for cross-process sharing,
Postgres materialized views for cold analytics. Boundaries enforced by interface in
src/lib/cache/index.ts; no direct Redis calls from feature code.

@ FUNCTIONS::compute-replacement-level  •  src/lib/vorp/replacement.ts  •  #function #vorp #math
Computes the replacement-level threshold for a given position by sorting all eligible
players descending and taking the value at index = league_size * roster_slots[position].
Returns NaN if the eligible pool is smaller than the slot count (caller must handle).

@ RESEARCH::age-curve-derivation  •  —  •  #research #math #age-curve
Derived the per-position age multipliers from a 10-season rolling regression of points-per-game
vs. age. Forwards peak at 27, defensemen at 29, goalies at 28. Multipliers are point estimates;
confidence intervals widen sharply outside ages 22-32.

@ SELF::session-summary-2026-04-28  •  —  •  #self #session-summary
Spent the session adding the cache abstraction and rederiving age curves. Open thread:
the cache layer's eviction policy on Redis disconnect is not yet specified — will need
a decision next session.

@ DIAGRAMS::vorp-calculation-flow  •  —  •  #diagram #vorp #flow
Mermaid sequence: client POST /vorp/calculate → VORPService.Compute → BatchVORPCalculator
(if league-wide) → cache write → response. Single-player path bypasses the batch calculator.
Documented as a swim-lane in the diagram body.

@ FUNCTIONS::auth-boundary-policy  •  src/auth/  •  #auth #boundary
Defines the trust boundary between the public API surface and internal services: every
request crosses the auth middleware exactly once, services never re-authenticate the
same principal, and inter-service calls carry a signed service token rather than a user
session. This is a system-level invariant about HOW services compose, not a single
function's behavior.

@ FUNCTIONS::vorp-batch-processing  •  src/lib/vorp/batch.go  •  #functions #vorp #batch #concurrency #scaling
Extended BatchVORPCalculator with three new behaviors not in the existing wiki note:
(1) adaptive worker pool sizing — workers scale from 4 to 16 based on queued job depth and
available DB connection slots, with a hysteresis band to avoid thrash; (2) per-batch
retry-with-backoff — transient DB errors retry up to 3 times with exponential backoff
(100ms, 400ms, 1.6s) before failing the batch; (3) cross-region replication awareness —
when the primary DB is in failover, the calculator pauses new batches and resumes from
the last checkpoint once a healthy primary is confirmed via the readiness probe. Each of
these adds roughly 250 words of explanation to the existing note's Content section,
pushing the combined body well past the 1,000-word cap from Rules.md §4. The split should
produce: vorp-batch-processing.md (kept, slimmed), vorp-batch-adaptive-workers.md (new),
vorp-batch-retry-policy.md (new), vorp-batch-failover-handling.md (new). Backlinks from
other notes that mention "VORP Batch Processing" in a worker-sizing context should be
rewritten to point to the new adaptive-workers note; backlinks in a retry/error context
should point to the new retry-policy note (per D-06 per-backlink target picking based on
surrounding context).
