
**Summary**: topic-index.md uses two H3 sections inside `## Content` — `### Modules` for orientation, `### Notes` for detail — combined cap ≤100.
**Tags**: #topic-index #recall #modules
**Created**: 2026-05-06T00:00:00+00:00
**Last Updated**: 2026-05-06T00:00:00+00:00

---

## Content

`wiki/topic-index.md` now uses two H3 sections inside its `## Content` block:

- **`### Modules`** — orientation layer. One bullet per `wiki/MODULES/<slug>.md` file. Bullet form: `- **<slug>** — One-sentence summary (≤25 words). Module: MODULES/<slug>.md` (singular `Module:` because each module is one file).
- **`### Notes`** — detail layer. Every other category (ARCHITECTURE, FUNCTIONS, RESEARCH, SELF, DIAGRAMS). Bullet form: `- **topic-name** — One-sentence summary (≤25 words). Files: PATH1, PATH2`.

`### Modules` sits above `### Notes`. Children of MODULES stay listed flatly in `### Notes` and are never removed when a parent module note is added — the two layers serve different recall queries and do not deduplicate against each other.

**Combined cap:** ≤100 entries across both sections. When the cap is hit, the curator emits a `RULES-PROPOSAL` row suggesting a further split (e.g., split `### Notes` by category) — never auto-splits.

**Restructure path.** Curator Step 9 detects pre-rollout indexes — those without a `### Modules` heading — and performs a one-time additive restructure on the first MODULES write. Existing bullets stay in their original order under `### Notes`; no content moves; the new `### Modules` heading is inserted above with its first module bullet. The restructure is idempotent — subsequent runs see the heading and skip the restructure.

**Recall agent integration.** The recall agent prefers `### Modules` for orienting queries ("what is", "how does", "overview of") and `### Notes` for narrow ones (specific function names, error messages, file paths). The split lets recall return module-shaped context for orientation queries without dragging in every detail note.

## Related Notes

- [[topic-index-as-recall-map|Topic Index as Recall Map]]
- [[modules-category|MODULES Category]]
- [[recall-path|Recall Path]]
- [[wiki-recall-subagent|Wiki Recall Subagent]]
- [[version-1-2-0-release|Version 1.2.0 Release]]
