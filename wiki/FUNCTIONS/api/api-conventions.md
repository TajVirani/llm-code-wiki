
**Summary**: Cross-cutting API conventions: base URL, auth model, status codes, error format, query parameters, pagination, and rate limiting.
**Tags**: #functions #api #conventions
**Created**: 2026-04-11T00:00:00+00:00
**Last Updated**: 2026-04-11T00:00:00+00:00

---

## Content

### Base URL

```
http://localhost:8080/api
```

All endpoints return JSON responses unless specified otherwise. Date/time values use ISO 8601. IDs can be numeric (database) or string (Fantrax). File uploads use `multipart/form-data`.

### Authentication

The API **does not require authentication** for frontend requests — see [[Enforced Codebase Rules]]. Fantrax integration does require a valid session cookie, stored via `POST /api/fantrax/auth`; see [[Fantrax Integration]].

### Status codes

| Code | Meaning                                   |
| ---- | ----------------------------------------- |
| 200  | Success                                   |
| 201  | Created                                   |
| 204  | No content (success with no response body) |
| 400  | Bad request (invalid parameters)          |
| 401  | Unauthorized                              |
| 403  | Forbidden                                 |
| 404  | Not found                                 |
| 409  | Conflict (resource already exists)        |
| 500  | Internal server error                     |

### Error format

All error responses share a structure:

```json
{
  "error": "Error message",
  "code": "ERROR_CODE",
  "details": {}
}
```

### Common query parameters

| Parameter    | Type    | Description                                    | Used in                      |
| ------------ | ------- | ---------------------------------------------- | ---------------------------- |
| `season`     | string  | Filter by season (e.g. `2024-25`)              | Players, projections, VORP   |
| `position`   | string  | Filter by position (C, LW, RW, D, G)            | Players                      |
| `team`       | string  | Filter by NHL team                              | Players                      |
| `status`     | string  | Filter by player status (active, injured, ...) | Players                      |
| `search`     | string  | Search player names                             | Players                      |
| `statFilter` | string  | Complex stat filter (e.g. `G>20`)               | Players                      |
| `sessionId`  | string  | CSV import session ID                           | CSV mapping                  |
| `startDate`  | string  | Start date for a date range                     | NHL schedule                 |
| `endDate`    | string  | End date for a date range                       | NHL schedule                 |
| `period`     | integer | Matchup period number                           | Matchups, categories         |

### Pagination

Some endpoints support pagination:

- `page` — page number (1-based).
- `limit` — items per page (default 50, max 100).
- `sort` — sort field.
- `order` — `asc` or `desc`.

### Rate limiting

The API implements rate limiting for expensive operations:

- **Player imports** — capped to prevent DB contention.
- **Fantrax API calls** — respects Fantrax's own limits.
- **Batch VORP calculations** — queued through a worker pool (see [[VORP Batch Adaptive Workers]]).

### Endpoint groups

For the actual endpoint tables, see:

- [[API Endpoints - Fantrax and System]]
- [[API Endpoints - Users and Leagues]]
- [[API Endpoints - Players and Projections]]
- [[API Endpoints - Matchups and Categories]]
- [[API Endpoints - CSV and Layouts]]
- [[VORP API Endpoints]]

## Related Notes

- [[API Reference]]
- [[Enforced Codebase Rules]]
- [[Fantrax Integration]]
- [[VORP API Endpoints]]
