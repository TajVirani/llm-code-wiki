
**Summary**: How BatchVORPCalculator processes large VORP recalculations with a worker pool, chunked batches, and panic-safe error recovery.
**Tags**: #functions #vorp #batch #concurrency
**Created**: 2026-04-11T00:00:00+00:00
**Last Updated**: 2026-04-29T00:00:00+00:00

---

## Content

For full-league recalculations, VORP runs as a background batch job managed by `BatchVORPCalculator`. The job is persisted, progress is reported via `/vorp/status/{jobId}`, and the worker pool is sized for good throughput without swamping the DB.

Three additional behaviors were added 2026-04-28 — each is documented in a dedicated note:
- Adaptive worker pool sizing: see [[VORP Batch Adaptive Workers]]
- Per-batch retry-with-backoff: see [[VORP Batch Retry Policy]]
- Cross-region replication awareness: see [[VORP Batch Failover Handling]]

### Job lifecycle

```
Client POST /vorp/batch
       │
       ▼
VORPService.StartBatchVORPCalculation
       │
       ▼ creates DB row
VORPCalculationJob { Status: "pending" }
       │
       ▼
BatchVORPCalculator.StartBatchCalculation
       │
       ▼
Worker pool picks up job
       │
       ▼
For each batch (100 players):
  ├─ calculate VORP concurrently
  ├─ upsert to vorp_calculations (source_type='stats')
  └─ update progress every 10%
       │
       ▼
Status = "completed", cache invalidated
```

### Worker pool settings (baseline)

- **Worker count**: 4 concurrent workers (baseline; see [[VORP Batch Adaptive Workers]] for adaptive sizing).
- **Batch size**: 100 players per batch.
- **Progress updates**: every 10% completion (not every batch, to avoid DB thrash).
- **Memory**: chunked processing avoids loading an entire league's players at once.

### Panic-safe worker loop

Each worker recovers from panics so a single bad player does not kill the whole job:

```go
func (b *BatchVORPCalculator) processJob(job *models.VORPCalculationJob, workerID int) {
    defer func() {
        if r := recover(); r != nil {
            errorMsg := fmt.Sprintf("Worker %d panic: %v", workerID, r)
            b.failJob(job, errorMsg)
        }
    }()

    b.logger.Infof("Worker %d starting job %d for league %s", workerID, job.ID, job.LeagueID)

    job.Status = "processing"
    job.StartedAt = time.Now()
    b.db.Save(job)

    err := b.processBatch(job, workerID)
    if err != nil {
        b.failJob(job, fmt.Sprintf("Processing failed: %v", err))
        return
    }

    job.Status = "completed"
    job.CompletedAt = time.Now()
    job.Progress = 1.0
    b.db.Save(job)
}
```

### Per-player error wrapping

Individual VORP calculations wrap errors with context rather than using custom error types (see [[Enforced Codebase Rules]]):

```go
func (s *VORPService) calculateVORPWithErrorHandling(player PlayerForVORP) (float64, error) {
    defer func() {
        if r := recover(); r != nil {
            s.logger.Errorf("VORP calculation panic for player %d: %v", player.ID, r)
        }
    }()

    vorp, err := s.calculatePlayerVORPInternal(player)
    if err != nil {
        return 0, fmt.Errorf("failed to calculate VORP for player %d: %w", player.ID, err)
    }
    return vorp, nil
}
```

### Performance characteristics

- **Throughput**: 4 workers × 100-player batches sustains full-league recalculations in seconds rather than minutes.
- **DB pressure**: bulk upserts keep transaction count low.
- **Cache interaction**: on job completion, `VORPCache.InvalidateAll` is called to drop stale entries (see [[VORP Cache Strategy]]).
- **Progress visibility**: the `/vorp/status/{jobId}` endpoint reads the persisted `Progress` field and returns it to the client for UI display.

### When to use batch vs synchronous

- **Synchronous** (`/vorp/calculate`): small leagues, single-player recalcs, or when the user is waiting on an interactive flow.
- **Batch** (`/vorp/batch`): full-league recalculations, settings changes that affect all players, seasonal rollover.

## Related Notes

- [[VORP Batch Adaptive Workers]]
- [[VORP Batch Retry Policy]]
- [[VORP Batch Failover Handling]]
- [[VORP API Endpoints]]
- [[VORP Service Data Structures]]
- [[VORP Cache Strategy]]
- [[VORP Calculation Flow]]
- [[Enforced Codebase Rules]]
