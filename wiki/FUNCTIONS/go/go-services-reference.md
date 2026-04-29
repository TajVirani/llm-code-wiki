
**Summary**: Reference for the Go service layer: VORPService, BatchVORPCalculator, VORPCache, CategoryService, and FantraxService.
**Tags**: #functions #go #services
**Created**: 2026-04-11T00:00:00+00:00
**Last Updated**: 2026-04-11T00:00:00+00:00

---

## Content

The service layer owns the business logic. Handlers delegate to services; services delegate to GORM. Every service has a `New*` constructor that takes `*gorm.DB` and (for most) `*zap.SugaredLogger`.

### `vorp.go` — `VORPService`

| Method                       | Parameters                                                                 | Returns                                 |
| ---------------------------- | -------------------------------------------------------------------------- | --------------------------------------- |
| `NewVORPService`             | `db *gorm.DB`, `logger *zap.SugaredLogger`                                 | `*VORPService`                          |
| `StartBatchVORPCalculation`  | `leagueID string`, `seasonID uint`, `userID uint`                          | `*models.VORPCalculationJob, error`     |
| `GetBatchJobStatus`          | `jobID uint`                                                               | `*models.VORPCalculationJob, error`     |
| `CalculateReplacementLevels` | `leagueID string`, `seasonID uint`                                         | `*ReplacementLevels, error`             |
| `GetReplacementLevels`       | `leagueID string`                                                          | `*ReplacementLevels, error`             |
| `calculatePlayerVORP` (priv) | `positions string`, `fantasyPoints float64`, `replacementLevels *ReplacementLevels` | `float64`                       |
| `InvalidateCache`            | `leagueID string`, `seasonID uint`                                         | none                                    |

See [[VORP Implementation Architecture]] and [[VORP Calculation Flow]] for the calculation pipeline, and [[VORP Service Data Structures]] for the struct shapes.

### `vorp_batch.go` — `BatchVORPCalculator`

| Method                    | Parameters                                                           | Returns                             |
| ------------------------- | -------------------------------------------------------------------- | ----------------------------------- |
| `NewBatchVORPCalculator`  | `service *VORPService`, `db *gorm.DB`, `logger *zap.SugaredLogger`   | `*BatchVORPCalculator`              |
| `StartBatchCalculation`   | `leagueID string`, `seasonID uint`, `userID uint`                    | `*models.VORPCalculationJob, error` |
| `GetJobStatus`            | `jobID uint`                                                         | `*models.VORPCalculationJob, error` |
| `processJob` (priv)       | `job *models.VORPCalculationJob`, `workerID int`                     | none                                |

See [[VORP Batch Adaptive Workers]] for the worker pool and panic-safe execution model.

### `vorp_cache.go` — `VORPCache`

| Method                  | Parameters                                                                | Returns                    |
| ----------------------- | ------------------------------------------------------------------------- | -------------------------- |
| `NewVORPCache`          | —                                                                         | `*VORPCache`               |
| `GetReplacementLevels`  | `leagueID string`, `seasonType string`                                    | `*ReplacementLevels, bool` |
| `SetReplacementLevels`  | `leagueID string`, `seasonType string`, `levels *ReplacementLevels`       | none                       |
| `InvalidateAll`         | —                                                                         | none                       |

See [[VORP Cache Strategy]] for TTL, keys, and invalidation rules.

### `category.go` — `CategoryService`

| Method                        | Parameters                                             | Returns                               |
| ----------------------------- | ------------------------------------------------------ | ------------------------------------- |
| `NewCategoryService`          | `db *gorm.DB`                                          | `*CategoryService`                    |
| `GetCategoryStandings`        | `leagueID string`, `periodNumber int`                  | `[]models.CategoryStanding, error`    |
| `GetTeamCategoryStats`        | `leagueID string`, `teamID uint`, `periodNumber int`   | `[]models.TeamCategoryStat, error`    |
| `CalculateCategoryStandings`  | `leagueID string`, `periodNumber int`                  | `error`                               |

See [[Category Leagues Overview]] for what "standings" means and how categories are computed.

### `fantrax.go` — `FantraxService`

| Method              | Parameters                                   | Returns                    |
| ------------------- | -------------------------------------------- | -------------------------- |
| `NewFantraxService` | `db *gorm.DB`, `logger *zap.SugaredLogger`   | `*FantraxService`          |
| `SaveAuthToken`     | `token string`                               | `error`                    |
| `GetAuthToken`      | —                                            | `string, error`            |
| `FetchLeagueData`   | `leagueID string`                            | `*models.League, error`    |

The service is a thin layer over the Fantrax scraping client (see [[Go Fantrax Client Reference]]) plus the token-encryption logic for storing cookies in SQLite.

## Related Notes

- [[Go Entry and Routing]]
- [[Go Handlers - Player and Stats]]
- [[Go Fantrax Client Reference]]
- [[Go Utils and Models Reference]]
- [[VORP Implementation Architecture]]
- [[VORP Calculation Flow]]
- [[VORP Batch Processing]]
- [[VORP Cache Strategy]]
- [[Category Leagues Overview]]
- [[Fantrax Integration]]
