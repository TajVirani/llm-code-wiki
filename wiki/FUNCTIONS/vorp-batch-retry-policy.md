
**Summary**: Per-batch retry-with-exponential-backoff policy for transient DB errors in BatchVORPCalculator — up to 3 retries at 100ms, 400ms, 1.6s.
**Tags**: #functions #vorp #batch #concurrency
**Created**: 2026-04-29T00:00:00+00:00
**Last Updated**: 2026-04-29T00:00:00+00:00

---

## Content

Located at `src/lib/vorp/batch.go`.

### Overview

Transient database errors during batch processing now retry automatically rather than immediately failing the job. Each batch gets up to 3 retry attempts before the error is treated as permanent.

### Retry schedule

| Attempt | Delay before retry |
|---------|-------------------|
| 1 (initial) | — |
| 2 | 100ms |
| 3 | 400ms |
| 4 (final) | 1,600ms (1.6s) |

If attempt 4 fails, the batch is marked as failed and the job records the error. The exponential factor is 4× per step.

### What counts as a transient error

Only errors classified as transient by the DB client trigger retries:
- Connection timeout
- Deadlock detected
- Serialization failure (in serializable isolation)
- Temporary connection pool exhaustion

Non-transient errors (e.g., constraint violations, malformed queries) do not retry — they fail immediately on attempt 1.

### Why retry at the batch level, not per-player

Retrying at the batch level (100-player chunk) rather than per-player avoids partial state: either the entire batch upsert succeeds or it is retried as a unit. Per-player retry would risk committing some players' VORP values without others, leaving the job in a partially updated state that is difficult to detect.

### Interaction with the worker pool

Each worker independently applies the retry policy for its assigned batch. Workers do not coordinate retries — a failing batch on worker 3 does not affect worker 7's processing. This means at most `MAX_WORKERS` batches can be in a retry wait state simultaneously.

## Related Notes

- [[VORP Batch Processing]]
- [[VORP Batch Adaptive Workers]]
- [[VORP Batch Failover Handling]]
- [[Enforced Codebase Rules]]
