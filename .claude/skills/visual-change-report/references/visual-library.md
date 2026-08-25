# Visual Library

A catalog of visuals for change reports: when each earns its place, the pattern to copy, and the syntax rules that keep Mermaid from silently failing. The delta color language is fixed across every visual: **green = added, amber = modified, red = removed, gray = unchanged context.**

## Shared Mermaid delta classes

Paste this at the bottom of every flowchart/graph block so coloring is consistent (values match the template's CSS tokens):

```
classDef added fill:#e6f4ec,stroke:#1a7f4b,stroke-width:2px,color:#0c3b23
classDef modified fill:#fdf3e1,stroke:#b87908,stroke-width:2px,color:#4a3103
classDef removed fill:#fbe9eb,stroke:#b3313c,stroke-width:2px,color:#4d151b,stroke-dasharray:5 3
classDef ghost fill:#f1f4f7,stroke:#9aa7b1,color:#5b6770
```

Assign with `class NodeA,NodeB added` lines. Unchanged nodes get `ghost` (or no class).

## Mermaid syntax rules (most report failures come from here)

- Wrap any label containing spaces, parentheses, slashes, dots, or hyphens in double quotes: `A["Order Service (v2)"]`. Parentheses in unquoted labels are the #1 crash.
- Node IDs: letters/digits/underscores only. Never start with a number. `end`, `graph`, `subgraph`, `class`, `style` are reserved — don't use them as IDs.
- One statement per line. No trailing semicolons needed.
- Subgraph titles with spaces need quotes: `subgraph API_Layer["API Layer"]`.
- Sequence diagrams: participant aliases via `participant OS as Order Service` — aliases may contain spaces and must NOT be quoted (quotes render literally). Notes via `Note over OS: text`; avoid colons inside the note text.
- Keep `flowchart LR` for wide/architecture views, `flowchart TD` for pipelines. If a diagram renders cramped, switching direction is the cheapest fix.
- HTML entities in labels break rendering — write `&` as `and`.

---

## 1. Unified architecture delta (the workhorse)

**Question it answers:** "What does the system look like now, and which parts of that picture are new/changed/gone?"

**Use when** structure changed but the overall shape survives — most large PRs. One diagram, delta-colored. Include removed nodes (red, dashed) *in* the after picture so the reader sees what disappeared without flipping between images.

```
flowchart LR
    Client["Web Client"] --> API["API Gateway"]
    API --> Orders["Order Service"]
    Orders --> Bus["Event Bus"]
    Bus --> Notif["Notification Service"]
    Orders -. removed .-> Mailer["Legacy Mailer"]
    Orders --> Pay["Payment Gateway Adapter"]
    class Bus,Notif,Pay added
    class Orders modified
    class Mailer removed
    class Client,API ghost
```

**Budget:** ≤15 nodes. Collapse clusters into one labeled node ("7 report generators") before exceeding it.

## 2. Side-by-side before/after

**Question:** "How different is the shape of this subsystem?"

**Use when** topology genuinely transformed (monolith split, pipeline reordered, layer inserted) — a unified diagram would be a color soup. Render two small diagrams in the template's `.split` grid, ~8 nodes each, identical node names for everything that survived, so the eye can diff them. Skip delta classes on the "before" side; it's all context.

## 3. Sequence diagram delta (workflows and request paths)

**Question:** "How does this operation flow now vs. then?"

**Use when** the change is about *order of operations*: sync→async, new middleware, added retries, a service inserted into a call chain. Before and after as two blocks (sequence diagrams color poorly — the comparison IS the visual). ≤8 participants; elide with `Note over A,B: validation steps unchanged (3 calls)`.

```
sequenceDiagram
    participant C as Checkout
    participant O as Order Service
    participant B as Event Bus
    C->>O: place order
    O->>B: publish OrderPlaced
    B-->>O: ack
    Note over B: consumers pick up async
```

## 4. State / lifecycle diagram

**Question:** "What states can this thing be in now, and which transitions changed?"

**Use when** an entity lifecycle changed (order states, job statuses, feature-flag rollout stages). `stateDiagram-v2`; mark new states/transitions by appending `(new)` to labels — classDefs are unreliable in state diagrams, text markers always render.

## 5. Blast-radius graph

**Question:** "If this change is wrong, what breaks?"

**Use when** changed modules have consumers outside the diff — almost always for the top 2–3 themes. Changed node(s) center, dependents around, edges pointing *from* dependents *to* the change ("X depends on Y"). Unchanged dependents get `ghost` — being gray while attached to a colored center is the whole message. Annotate edges with the coupling: `Reports -- "reads orders table" --> DB`.

```
flowchart TD
    Gateway["Payment Gateway Adapter (changed)"]
    Checkout["Checkout Flow"] --> Gateway
    Refunds["Refund Worker"] --> Gateway
    Recon["Reconciliation Job"] --> Gateway
    class Gateway modified
    class Checkout,Refunds,Recon ghost
```

## 6. Stats: bar charts and composition bars (no chart library)

**Question:** "Where did the churn land, and what kind of change is this?"

Use the template's pure-HTML/CSS patterns — no Chart.js, nothing to break offline:

- `.bars` rows for churn by area (top 6–8 dirs/themes, from the collector's `by_top_dir`). Scale widths against the max value, label with real numbers.
- `.composition` stacked bar for change makeup (source/tests/docs/config/noise, from `by_category`). One glance should answer "is this tested?" and "how much is noise?"

Give raw numbers in labels; never make color the only carrier of a value.

## 7. Tables (underrated)

**Question:** "What exactly is on the changed surface?"

**Use for** enumerable facts where a diagram adds nothing: changed API endpoints/signatures, new/removed config keys and env vars, schema migrations, deleted capabilities, new dependencies. Columns like `Endpoint | Before | After | Consumers affected`. A table with a "Consumers affected" column is a blast-radius analysis in disguise — often the highest-value 20 lines in the report.

## Choosing under pressure

If a theme could support several visuals, pick the one whose *question* the reader would ask first, and fold the rest into prose or the appendix. Two strong visuals beat five weak ones. And if a visual needs a paragraph to explain how to read it, it's the wrong visual.
