---
name: deps-update
description: Update and maintain this repo's bun dependencies with regression validation scaled to each package's blast radius. Use when updating/bumping/upgrading packages, running bun outdated/update, checking for outdated deps, addressing a dependency CVE, or asking "is this package update safe / how do I test this bump".
---

# Dependency updates (bun)

This repo is a **bun** monorepo (not npm). Every package touches a different blast radius, so the
regression proof must scale to what a bad bump would silently break. That scale is the whole point:
a `@types/*` bump needs a build; a `deck.gl` bump needs eyes on the map.

Suite commands, prerequisites, and CI reality live in **athena-validation-and-qa** — this skill decides
*how deep to go*, that skill tells you *how to run it*. Don't duplicate suite details here.

## Workflow

1. **Discover** — `bun outdated --filter='*'`. Bare `bun outdated` reports the **root manifest only** and
   silently hides stale workspace copies; `--filter='*'` traverses every workspace and adds a Workspace column.
   Note current → latest **and every owning workspace**. **Skip debris workspaces**: `apps/agentic-tests/*` and
   the `apps/aircraft-service-*` benchmark variants are not real (see athena-build-and-env). Real targets: root,
   `server`, `client`, `shared`, `apps/agentic-service`, `apps/agentic-service/console`, `apps/weather-service`,
   `packages/vitest-agents`, and the one real `apps/aircraft-service` (kept dependency-light — don't add to it).
2. **Detect drift** — `bun .claude/skills/deps-update/scripts/drift.ts` lists every dep declared in ≥2 real
   workspaces, flagging those pinned at different ranges (`← DRIFT`). Same dep, different version across
   manifests = a bug waiting to happen and a **catalog candidate** (see Catalogs below). Converge drift as part
   of the update, don't leave it.
3. **Classify** — assign each package a **tier** from the scale below (blast radius → how much regression
   proof). Tier is orthogonal to feasibility: it sets *validation depth*, not *whether the bump is easy*.
4. **Assess feasibility** — for each candidate, especially **minor/major** bumps, read the changelog before
   touching anything. Get the source: `bun info <pkg> repository` → its GitHub `/releases` or `CHANGELOG.md`;
   `bun info <pkg> versions` lists what's between current and target. Skim for **breaking changes, required
   codemods, peer-dep bumps, dropped runtime support**. Rate the migration **effort** (this pairs with tier):
   - **trivial** — patch/minor, changelog shows only fixes/additions → bump and validate at tier.
   - **moderate** — deprecations, config or peer-dep changes, a codemod offered → apply the migration steps,
     then validate at tier; if Tier 2+, do the driven check even for a minor.
   - **breaking** — major with removed APIs / behavior changes → **isolate it entirely**, do the changelog's
     migration process, expect source edits, validate at tier + driven check regardless of tier. One per MR.
   Record effort + the changelog link per package; a high-tier + breaking combo is the one to schedule, not
   sneak into a batch.
5. **Batch by effort × tier, target the owning workspace** — batch only **trivial** bumps together (one
   validation pass). Isolate every **moderate/breaking** bump and every **Tier-2/3** bump **one package per
   commit** so a regression is attributable.
   - **`bun update` is NOT recursive** — bare `bun update <pkg>` from root only rewrites the *root* manifest.
     A workspace dep needs `bun update <pkg> --filter=<workspace>` (e.g. `--filter=server`), or `-r` to bump it
     everywhere it appears. Getting this wrong silently leaves workspace copies stale (the classic trap here).
   - **If the dep is in a catalog** (see below), don't touch workspaces at all — bump the single entry in the
     root `catalog`/`catalogs` block and run `bun install`. That's the whole point of catalogs.
   - The repo's `bun run maintain` (= `turbo maintain`) exists but is a **partial tool**: only `server`,
     `client`, `shared` define a `maintain` script and each is `bun update --interactive` — unusable
     non-interactively, and it skips agentic-service, console, vitest-agents, weather-service, aircraft-service.
     Prefer explicit `--filter` updates; reach for `maintain` only in an interactive session on those 3.
6. **Validate** at the tier's bar (below). Every tier starts with the **done-gate**:
   `bun run format:fix && bun run lint && bun run build:single`.
7. **Report** — per package: old→new version, **owning workspace**, tier, effort, changelog link, what you
   ran, result. If the change landed in a coverage gap (see §8 of athena-validation-and-qa), say the driven
   check is the *only* proof.

## The scale

| Tier | Package kind (examples) | What a bad bump breaks | Validation floor (after done-gate) |
|---|---|---|---|
| **0 · Tooling/types** | oxlint, oxfmt, turbo, typescript, `@types/*`, orval, playwright, vitest, git-cliff | build / typecheck only — never ships in runtime | done-gate + `bun run type-check` for **new** errors only (this repo has pre-existing type failures CI swallows — diff against the clean tree before blaming a bump). That's it. |
| **1 · Pure logic** | hono, zod, drizzle-orm, date/geo/math libs, anything in `shared/`, server routes & `server/src/ai/**`, bridge tools | wrong values, broken routes — but **unit-testable** | done-gate + the unit suite(s) for the touched workspace. A `shared/` bump → run **server + client** suites too (both import it; `turbo test` skips shared). |
| **2 · UI / render** | react, react-dom, deck.gl, luma.gl, maplibre, `@tanstack/*`, radix, tailwind | visual + **WebGL/canvas** regressions unit tests can't see | done-gate + `cd client && bun run test` + **driven check**: run the app via `bun run e2e:bootstrap` (port 4055 — never 4044), run `bun run e2e`, and **eyeball the affected UI** (map render especially — no automated canvas harness exists). Screenshot it. |
| **3 · AI / agent behavior** | `@anthropic-ai/sdk`, `ai`, mastra, effect (agentic), embedding/model libs | nondeterministic — a single green run proves nothing | done-gate + agentic L0/L1 (needs Postgres on 5435) + **eval pass-RATE** with N repetitions via `packages/vitest-agents` + Wilson interval; **state N**. Needs `AI_API_TOKEN`. |

Pick the **highest** tier a package qualifies for. A lib used both in `shared/` logic and rendered in the
client is Tier 2. When unsure between two tiers, take the higher one — the cost is one more suite, the cost
of guessing low is a silent regression in a gap with no automated coverage.

## Repo-specific caveats

- **bun refuses too-fresh versions** (`minimumReleaseAge` guard). If `bun add`/`update` rejects a brand-new
  release, that's the policy working — don't force past it without reason. See athena-build-and-env.
- **oxfmt sweeps unrelated files** — after `format:fix`, `git checkout --` anything outside the packages you
  touched. Keep the diff scoped to the dependency change.
- **Never run `build:single` (or `e2e:bootstrap`) against a live app on port 4044** — it rewrites
  `server/static` and recompiles the binary. Bootstrap runs on 4055 for exactly this reason.
- **`apps/aircraft-service*` is deliberately dependency-light** for a planned Go rewrite — don't pull heavier
  deps into it. Most `apps/*` beyond agentic-service/weather have zero tests (§8), so their driven check is the
  only proof.
- **CI is not a safety net** — lint is the only hard gate; unit/typecheck/build jobs are `allow_failure` or
  swallowed. Cite the suite *you* ran, never "CI passed".

## Catalogs — the structural fix for drift

The duplicate-dep problem above (a dep declared in N manifests at N drifting ranges) is what bun **catalogs**
solve: define a version once in the root, reference it everywhere with the `catalog:` protocol. Supported
since bun 1.2.0. **This repo does not use catalogs yet** — ~40 deps are duplicated across ≥2 workspaces and
~15 actively drift (`zod`, `ai`, `react`, `typescript`, `hono`, `better-auth`, `vitest`, `@tanstack/*`).

Root `package.json` (top-level `catalog` / named `catalogs` both work; `workspaces` here is an array so keep
these as sibling top-level keys):

```json
{
  "catalog": { "zod": "^4.4.3", "react": "^19.2.6", "react-dom": "^19.2.6" },
  "catalogs": { "build": { "vite": "^8.1.4", "typescript": "^6.0.3" } }
}
```

Each workspace then references it instead of pinning a range:

```json
{ "dependencies": { "zod": "catalog:" }, "devDependencies": { "vite": "catalog:build" } }
```

Rules and gotchas:
- **Update flow changes**: bump the version in the root catalog + `bun install` — not `bun update --filter`.
- Migrate only deps in **≥2 real workspaces**; leave single-workspace deps and `workspace:*` refs alone.
- `bun outdated`/`bun update` behavior against the `catalog:` protocol is **not documented** — verify against
  a cataloged dep before trusting either, and fall back to editing the catalog entry by hand.
- On `bun publish`, `catalog:` refs are replaced with resolved versions — fine here (nothing is published).

Adopting catalogs is a **repo migration, not a skill action** — do it as its own scoped branch, then this
skill's per-workspace update steps collapse to "edit the catalog, `bun install`" for every cataloged dep.

## Quick reference

```bash
bun outdated --filter='*'                 # discover ALL workspaces (bare `bun outdated` = root only!)
bun outdated --filter=client              # one workspace
bun .claude/skills/deps-update/scripts/drift.ts   # deps in >=2 workspaces + drift flags (--all for non-drift too)
bun info <pkg> repository                 # changelog source → GitHub /releases or CHANGELOG.md
bun info <pkg> versions                   # what versions exist between current and target
bun update <pkg> --filter=<workspace>     # bump a WORKSPACE dep (bare `bun update` only touches root!)
bun update -r <pkg>                        # bump <pkg> in every workspace it appears
bun run format:fix && bun run lint && bun run build:single   # done-gate (every tier)
```
