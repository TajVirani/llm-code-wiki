
**Summary**: <one sentence, ≤25 words: what this module is responsible for>
**Tags**: #module #<domain-tag1> #<domain-tag2>
**Created**: <ISO-8601>
**Last Updated**: <ISO-8601>

---

## Content

### Purpose

One paragraph. What this module earns its keep doing — the deletion-test answer.
"If we deleted this module, what complexity reappears across the rest of the system?"

### Boundary

What's IN this module. What's explicitly OUT (and where that lives instead).
Naming what's NOT here is the explicit anti-shallow guard — descriptions that can't fill this section usually fail the deletion test.

### Triggers

Entry points that invoke this module: HTTP endpoints, user actions, cron schedules, queue messages, lifecycle hooks. One bullet per trigger.

### Storage

Tables, queues, files, in-memory state owned by this module. State "stateless" explicitly if applicable.

### Behavior

The dataflow narrative — how a trigger flows through storage to executor to outcome. This is the section that captures end-to-end behavior at module granularity.

### Rules & Invariants

Constraints the module enforces or relies on: idempotency, conflict detection, auth requirements, ordering guarantees, fail-safe defaults.

### Children

Wiki-links into the fine-grained detail notes that document each piece. Group by category with H4 sub-headings; omit empty groups.

#### From ARCHITECTURE
- [[<basename>|<Display Title>]]

#### From FUNCTIONS
- [[<basename>|<Display Title>]]

#### From RESEARCH
- [[<basename>|<Display Title>]]

#### From DIAGRAMS
- [[<basename>|<Display Title>]]

## Related Notes

- [[<sibling-module-slug>|<Sibling Module Title>]]
