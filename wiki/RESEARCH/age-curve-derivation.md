
**Summary**: Per-position age multipliers derived from a 10-season rolling regression of points-per-game versus age, with peak ages and confidence intervals.
**Tags**: #research #math #age-curve
**Created**: 2026-04-29T00:00:00+00:00
**Last Updated**: 2026-04-29T00:00:00+00:00

---

## Content

### Derivation method

Per-position age multipliers were derived from a 10-season rolling regression of points-per-game versus age. The regression was run separately for each position group.

### Peak ages by position

| Position | Peak Age |
|----------|----------|
| Forwards | 27 |
| Defensemen | 29 |
| Goalies | 28 |

### Confidence intervals

The multipliers are point estimates. Confidence intervals widen sharply outside the 22–32 age range. Values for players younger than 22 or older than 32 carry substantially more uncertainty and should be treated as rough guides rather than precise adjustments.

### Interpretation

An age multiplier above 1.0 indicates the player is in or approaching their prime; a multiplier below 1.0 indicates decline. The regression captures the empirical central tendency across the 10-season sample — individual players may deviate significantly from the curve due to injury history, position changes, or exceptional longevity.

### Usage in VORP calculation

These multipliers are applied during the VORP calculation pipeline to adjust raw point projections for age-related trajectory. A player at peak age receives a multiplier near 1.0; a player significantly above or below peak age receives a multiplier less than 1.0.

## Related Notes

- [[VORP Calculation Flow]]
- [[VORP Implementation Architecture]]
