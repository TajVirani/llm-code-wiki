
**Summary**: Session memory for 2026-04-28 — cache abstraction added, age curves rederived, open thread on Redis eviction policy on disconnect.
**Tags**: #self #session-summary
**Created**: 2026-04-29T00:00:00+00:00
**Last Updated**: 2026-04-29T00:00:00+00:00

---

## Content

### What was built

- Added the cache abstraction layer (`src/lib/cache/index.ts`) providing the three-tier caching interface (in-memory LRU, Redis, Postgres materialized views).
- Rederived the per-position age multipliers from a 10-season rolling regression. Results documented in [[Age Curve Derivation]].

### Open thread for next session

The cache layer's eviction policy on Redis disconnect is not yet specified. When Redis becomes unavailable, the current behavior is undefined — the in-memory LRU serves stale data without any notification. A decision is needed:

- Option A: Fail open — continue serving from in-memory LRU with a staleness warning.
- Option B: Fail closed — return errors until Redis reconnects.
- Option C: Circuit-breaker pattern — serve from in-memory LRU for a configurable TTL, then fail closed.

This must be decided before the cache layer is considered production-ready.

## Related Notes

- [[Caching Layer Overview]]
- [[Age Curve Derivation]]
