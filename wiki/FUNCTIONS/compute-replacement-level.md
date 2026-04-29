
**Summary**: Computes the replacement-level VORP threshold for a position by ranking eligible players and selecting the value at the last roster slot index.
**Tags**: #function #vorp #math
**Created**: 2026-04-29T00:00:00+00:00
**Last Updated**: 2026-04-29T00:00:00+00:00

---

## Content

Located at `src/lib/vorp/replacement.ts`.

### Purpose

Replacement level is the value produced by a freely-available player — the baseline against which VORP is measured. This function computes that threshold for a given position.

### Algorithm

1. Filter all players to those eligible at the target position.
2. Sort the eligible pool descending by the relevant value metric.
3. The replacement-level threshold is the value at index `league_size × roster_slots[position]`.

```typescript
// Pseudocode
function computeReplacementLevel(position: string, players: Player[]): number {
  const eligible = players.filter(p => p.eligiblePositions.includes(position));
  eligible.sort((a, b) => b.value - a.value);
  const cutoffIndex = leagueSize * rosterSlots[position];
  if (eligible.length < cutoffIndex) return NaN;
  return eligible[cutoffIndex].value;
}
```

### NaN return

If the eligible pool is smaller than `cutoffIndex` (e.g., a position with very few eligible players in a deep league), the function returns `NaN`. **Callers must handle this case** — `NaN` is a deliberate sentinel, not an error. Downstream VORP calculations must check for it before arithmetic.

### Why index-based (not percentile-based)

The cutoff index `league_size × roster_slots[position]` directly models the actual roster construction in a fantasy league: every team fills exactly `roster_slots[position]` spots at this position. The player just beyond the last required slot is the replacement player.

## Related Notes

- [[VORP Service Data Structures]]
- [[VORP API Endpoints]]
- [[VORP Batch Processing]]
