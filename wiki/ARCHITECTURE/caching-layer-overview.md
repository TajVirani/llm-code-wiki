
**Summary**: Three-tier caching strategy using in-memory LRU, Redis, and Postgres materialized views with enforced interface boundaries.
**Tags**: #architecture #caching #redis
**Created**: 2026-04-29T00:00:00+00:00
**Last Updated**: 2026-04-29T00:00:00+00:00

---

## Content

The project uses a three-tier caching strategy to balance read latency, cross-process consistency, and analytics performance.

### Tier 1 — In-memory LRU cache

Hot reads are served from an in-process LRU cache. This tier provides the lowest latency for frequently accessed values that do not need to be shared across processes. Eviction is by least-recently-used order.

### Tier 2 — Redis (cross-process sharing)

Redis serves as the shared cache for values that must be consistent across multiple server processes or worker goroutines. Any value that cannot be safely scoped to a single process lifetime lives in Redis.

### Tier 3 — Postgres materialized views (cold analytics)

For cold analytics queries — aggregations, historical reads, or reports that do not require real-time freshness — Postgres materialized views act as a pre-computed cache layer. These are refreshed on a defined schedule rather than on every write.

### Interface boundary enforcement

All caching interactions are mediated through a single interface defined at `src/lib/cache/index.ts`. Feature code never calls Redis directly — it calls the cache interface, which routes to the appropriate tier. This boundary is enforced by convention and code review, not by a compile-time restriction, but the indirection makes tier changes transparent to callers.

### When to use each tier

| Tier | When |
|------|------|
| In-memory LRU | Single-process hot reads; data that changes rarely during a request lifecycle |
| Redis | Cross-process shared state; session data; values invalidated by background jobs |
| Postgres materialized views | Heavy analytics; historical aggregations; data that is expensive to recompute and tolerates staleness |

## Related Notes

- [[VORP Cache Strategy]]
- [[System Architecture Overview]]
