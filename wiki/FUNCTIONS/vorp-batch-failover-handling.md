
**Summary**: Cross-region replication awareness in BatchVORPCalculator — pauses new batches during primary DB failover and resumes from checkpoint once a healthy primary is confirmed.
**Tags**: #functions #vorp #batch #concurrency
**Created**: 2026-04-29T00:00:00+00:00
**Last Updated**: 2026-04-29T00:00:00+00:00

---

## Content

Located at `src/lib/vorp/batch.go`.

### Overview

When the primary database enters failover (cross-region replication switching), `BatchVORPCalculator` detects the condition and pauses processing of new batches. It resumes automatically once a healthy primary is confirmed via the readiness probe.

### Failover detection

The calculator monitors the database's readiness probe endpoint on a short interval. When the probe reports the primary as unavailable or in failover state:

1. The calculator stops dispatching new batches to workers.
2. Workers that are mid-batch complete their current batch (they already hold a DB transaction or have committed it — aborting mid-batch would be worse than finishing with a potentially stale replica).
3. The calculator enters a waiting loop, polling the readiness probe.

### Resume from checkpoint

When the readiness probe reports a healthy primary:

1. The calculator resumes from the **last committed checkpoint** — the last batch index that was successfully upserted.
2. Batches that were in-flight during the failover are re-processed from the checkpoint, not from the start of the job. This ensures at-most-once semantics for each batch: if a batch was committed before failover, it is not re-run.
3. Progress reported to `/vorp/status/{jobId}` reflects only committed progress, so the client sees a brief pause rather than a reset.

### Why pause rather than route to replica

Read replicas are acceptable for VORP reads, but batch upserts require the primary. Routing writes to a replica during primary failover would either fail (if the replica is read-only) or produce split-brain state. Pausing is safer and simpler.

### Interaction with adaptive workers

During the failover pause, the adaptive worker pool (see [[VORP Batch Adaptive Workers]]) idles at the minimum worker count. It does not scale up in response to a growing queue depth during the pause — the DB connection availability signal will be zero or near-zero while the primary is unavailable.

## Related Notes

- [[VORP Batch Processing]]
- [[VORP Batch Adaptive Workers]]
- [[VORP Batch Retry Policy]]
- [[System Architecture Overview]]
