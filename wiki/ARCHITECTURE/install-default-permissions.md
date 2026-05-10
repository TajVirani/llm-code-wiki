
**Summary**: Default `_session.md` Read/Edit/Write permissions seeded by `/wiki-install` and backfilled by `/wiki-update` so the per-turn capture path runs without prompting.
**Tags**: #permissions #install #ux #settings #architecture

**Created**: 2026-05-09T14:17:00+00:00
**Last Updated**: 2026-05-09T14:17:00+00:00

---

## Content

### What is seeded

Three canonical permission entries are written into `.claude/settings.json` on install and backfilled on update:

- `Read(wiki/inbox/_session.md)`
- `Edit(wiki/inbox/_session.md)`
- `Write(wiki/inbox/_session.md)`

### Why

The inbox capture path writes `wiki/inbox/_session.md` after every code-edit turn (driven by the Stop hook + `inbox-update` skill). Without these defaults pre-approved, every Stop-hook fire would prompt the user for write approval — a prompt-storm that breaks the "auto-maintained" promise of the scaffold. Pre-seeding them is the difference between a capture path that runs silently in the background and one that interrupts every turn.

### Who writes them

- **`/wiki-install`** Block 2 seeds all three on first install. Case A (no existing `settings.json`) writes the permissions block via heredoc as part of the canonical file. Cases B/C (existing `settings.json`) require `jq` and run an `upsert_permission` filter that skips entries already present.
- **`/wiki-update`** Step 5 **backfills** the same three entries for installs that pre-date the default-permissions feature. The backfill upserts each canonical entry only if not already present.

Both writers share the same `upsert_permission` jq filter — never remove or rewrite user-added permissions; only add missing canonical entries.

### Idempotence

Re-running either skill converges to zero diff. Entries are matched literally (Allow/Read/Edit/Write tuples) before upsert, so a second run sees them already present and skips. This is the same idempotence discipline applied to hook entries in the same step.

### User-permission preservation

The upsert filter never touches permissions outside the three canonical entries. A user who has added their own `Allow` rules — for example, `Bash(npm test)` or domain-specific Read permissions — keeps those untouched across install + update cycles. The L3 install-e2e harness layer ([[test-install-e2e-layer|Test Install E2E Layer]]) explicitly verifies this property by inserting a synthetic user permission before re-running and asserting it survives.

### Manual no-`jq` fallback

A no-`jq` fallback recipe is documented in `.claude/skills/wiki-install/SETTINGS-SNIPPET.md` for environments where `jq` is unavailable. The fallback is a hand-edit instruction, not an automated path.

## Related Notes

- [[wiki-install-skill|Wiki Install Skill]]
- [[wiki-update-skill|Wiki Update Skill]]
- [[test-install-e2e-layer|Test Install E2E Layer]]
- [[update-flow|Update Flow]]
