
**Summary**: Two scaffold-internal templates under `.claude/skills/wiki-install/templates/` serve as single sources of truth shared by `/wiki-install` and `/wiki-update`.
**Tags**: #install #templates #architecture #distribution
**Created**: 2026-05-01T22:45:00+00:00
**Last Updated**: 2026-05-01T22:45:00+00:00

---

## Content

**Location.** `.claude/skills/wiki-install/templates/`. These are scaffold-internal templates (distinct from `wiki/_templates/`, which is user-owned schema for filed notes). They eliminate inline content generation in `/wiki-install` and prevent divergence between install-time and update-time content.

**`CLAUDE-MD-SECTION.md`.** Holds the canonical `## Auto-maintained wiki` section appended to a target project's `CLAUDE.md`. Two consumers read it directly:

- `/wiki-install` Block 3 — appends the section on first install.
- `/wiki-update` Step 6 — replaces the section in-place on upgrade.

Treating the file as a shared source of truth replaced the earlier scheme where Step 6 awk-extracted a fenced code block from `wiki-install/SKILL.md` — fragile because reformatting the skill body would silently change the install contract.

**`topic-index.seed.md`.** Holds the empty `wiki/topic-index.md` body with `<<CREATED_TS>>` and `<<UPDATED_TS>>` placeholders. `/wiki-install` Block 1 interpolates the placeholders with the install timestamp via `sed` and writes the result to `wiki/topic-index.md`. Kept as a template rather than shipped directly to `wiki/topic-index.md` for two reasons: per-install timestamps differ, and the distribution manifest's `keep` policy does not have to negotiate user content. After install, `wiki/topic-index.md` is owned by the curator (rebuilt at the end of every `/wiki-digest` run per Rules.md §11).

**Distribution.** Both templates ship via `dist-manifest.txt` with the default `overwrite` policy — they are scaffold internals, not user content, so updates should pull cleanly.

**Why scaffold-internal templates exist.** Inline content generation in skill bodies couples the install behavior to skill-body wording. A reformatting commit on `wiki-install/SKILL.md` would otherwise change what `/wiki-update` writes into `CLAUDE.md`. Externalizing the canonical strings into named template files makes the contract explicit and version-controlled.

## Related Notes

- [[wiki-install-skill|Wiki Install Skill]]
- [[wiki-update-skill|Wiki Update Skill]]
- [[update-flow|Update Flow]]
- [[remote-install-flow|Remote Install Flow]]
