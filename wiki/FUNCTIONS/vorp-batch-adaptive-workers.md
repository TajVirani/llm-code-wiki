
**Summary**: Adaptive worker pool sizing for BatchVORPCalculator — scales from 4 to 16 workers based on queue depth and DB connection slots with hysteresis.
**Tags**: #functions #vorp #batch #concurrency #scaling
**Created**: 2026-04-29T00:00:00+00:00
**Last Updated**: 2026-04-29T00:00:00+00:00

---

## Content

Located at `src/lib/vorp/batch.go`.

### Overview

The worker pool now scales dynamically between a minimum of 4 and a maximum of 16 concurrent workers based on two factors:
1. **Queued job depth**: how many batch jobs are waiting to be processed.
2. **Available DB connection slots**: how many database connections are currently free.

### Scaling algorithm

Workers are added or removed on a periodic evaluation cycle. The target worker count is:

```
target = min(
  max(MIN_WORKERS, floor(queued_jobs / JOBS_PER_WORKER)),
  min(MAX_WORKERS, available_db_connections / CONNECTIONS_PER_WORKER)
)
```

Where:
- `MIN_WORKERS = 4`
- `MAX_WORKERS = 16`
- `JOBS_PER_WORKER` and `CONNECTIONS_PER_WORKER` are configured constants.

### Hysteresis band

To prevent worker thrash (rapidly adding and removing workers as load fluctuates), a hysteresis band is applied. Workers are only added when the target exceeds the current count by more than `HYSTERESIS_THRESHOLD`, and only removed when the target falls below the current count by more than `HYSTERESIS_THRESHOLD`.

This means the pool does not react to momentary spikes — only sustained changes in load trigger a resize.

### Why 4–16 range

- **Minimum of 4**: matches the baseline worker count from the original implementation; ensures throughput even at low load.
- **Maximum of 16**: empirically determined cap to avoid saturating the DB connection pool. Exceeding this would cause connection wait latency to dominate over computation time.

## Related Notes

- [[VORP Batch Processing]]
- [[VORP Batch Retry Policy]]
- [[VORP Batch Failover Handling]]
- [[VORP Service Data Structures]]
