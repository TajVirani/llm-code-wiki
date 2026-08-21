# Seam Conformance

## Objective

Check the diff against Athena's **deep-module / seam** discipline (Ousterhout, *A Philosophy of
Software Design*). The load-first index of concepts and their seams is
[`docs/architecture/surfaces.md`](../../../../docs/architecture/surfaces.md); the vocabulary
(module, interface, seam, depth, deletion test) is
[`improve-codebase-architecture/LANGUAGE.md`](../../improve-codebase-architecture/LANGUAGE.md).
Read the surface index first — it tells you where each concept's seam is.

The other three modules find *shallowness smells* (size, duplication, orphans). This module
finds *seam violations*: code that reaches around a concept's interface, widens it without
cause, or adds shallow new modules.

## Checks

### 1. Reaching past a seam

For each concept in `surfaces.md`, its **Seam** is the only sanctioned entry point. Flag new
imports in the diff that reach *past* the seam into the concept's internals.

Detection:
- For each surfaced concept with a barrel or accessor seam (e.g. `server/src/channels`),
  `Grep` the changed files for imports of files *inside* the code root that bypass the barrel
  (e.g. `from ".../channels/flight-pipeline"` instead of `from ".../channels"`).
- Flag reads/writes of a subsystem's internals where a documented accessor exists (e.g. new
  code constructing a `FlightStore` directly instead of going through `mainChannel.flights`).

Report: the file:line, which seam was bypassed, and the sanctioned entry point to use instead.

### 2. Widening a surface without cause

Flag new **public** exports added to a surfaced concept's seam (new export in a barrel
`index.ts`, new public method on an accessor, new route on a mounted service).

For each, apply the **deletion test**: would callers lose real leverage without it, or is it a
pass-through that exposes an internal? A new export that only forwards to one internal is
interface widening — recommend keeping it private or folding it into an existing entry point.

Report: the new export, and whether it earns its place at the seam or should stay internal.

### 3. Shallow new modules

Flag new modules whose **interface is nearly as complex as their implementation** — the
classic shallow module. Signals: a new file/function that mostly forwards arguments to one
other module; a new "manager/helper/util" wrapper with one caller; a new export whose body is
a thin pass-through.

Apply the deletion test: if deleting the module makes complexity *vanish* (rather than
reappear across N callers), it wasn't hiding anything.

Report: the module, why it reads as shallow, and what it should merge into.

### 4. Duplicating behaviour already behind a surface

Flag new code that re-implements something an existing surfaced concept already provides
(e.g. new adapter-polling logic when the Adapter pool exists; new result-caching when the
Handle store exists). This is duplicate-detection framed at the *concept* level — the fix is
to route through the existing seam, not to copy the behaviour.

Report: the new code, the existing surface that already does this, and its seam.

### 5. New concept without a surface entry

If the diff introduces a substantial new subsystem (a new directory of cooperating modules, a
new service, a new mounted endpoint) that is **not** registered in `surfaces.md`, flag it.

Report: the new concept and a proposed one-line surface entry (name, seam, code root). New
subsystems must be added to the surface index in the same PR, or they are invisible to
seam-based navigation.

## What to report

For each finding:
```
- **[SEAM]** `path/to/file.ts:LINE` — [what the violation is]
  Concept: [surfaced concept name, or "unindexed"]
  Seam: [the sanctioned entry point]
  Suggestion: [route through the seam / keep private / merge / add surface entry]
```

## What NOT to flag

- Imports *within* a concept's own code root (internals may freely use each other).
- Test files reaching into internals for white-box testing — but prefer testing through the
  seam (the interface is the test surface).
- Generated files, `ui/` shadcn components, config, schema files.
- A concept that genuinely has no seam yet because it's a single deep file — don't invent a
  barrel for a one-file module.
