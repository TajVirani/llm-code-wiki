
**Summary**: Remote-install flow lets Claude fetch the scaffold from a public repo URL using `dist-manifest.txt` as the authoritative path list, without dragging the source repo's dogfood wiki along.
**Tags**: #install #distribution #architecture
**Created**: 2026-04-30T16:09:00+00:00
**Last Updated**: 2026-04-30T16:09:00+00:00

---

## Content

**Goal.** Let a user point Claude at the public repo URL and have the scaffold fetched into the target project — without dragging the source repo's dogfood wiki along.

**`dist-manifest.txt`** at the repo root is the authoritative list of distribution paths. Currently 16 entries: `VERSION`, `CHANGELOG.md`, 8 skill files, 2 agents, 2 hooks, `wiki/Rules.md`, and `wiki/_templates/note.md`.

**Manifest line format.** Whitespace-separated `PATH [POLICY]`. POLICY defaults to `overwrite`. The `keep` policy is used for `wiki/Rules.md` and `wiki/_templates/note.md` so that user customizations are preserved on update.

**Files deliberately excluded from the manifest:**

- `.claude/settings.json` — `/wiki-install` Step 5/5b handles hook registration via JSON merge instead of overwrite, and `/wiki-update` re-runs the same merge. Overwriting would clobber unrelated permissions, env vars, and MCP servers.
- `CLAUDE.md` — its `## Auto-maintained wiki` section is owned by `/wiki-install` Step 6 and refreshed by `/wiki-update` Step 6. The rest of `CLAUDE.md` is project-owned.
- `wiki/topic-index.md` — this repo's copy contains dogfood bullets, not the canonical empty seed. The empty seed is inlined in `wiki-install/SKILL.md` Step 4b instead.

**`INSTALL.md` "Remote install — for Claude" section** gives Claude an executable recipe:

1. Derive raw base URL from the repo URL.
2. Fetch the manifest.
3. Fetch each listed file, with skip-if-exists for the two `keep`-policy seeds.
4. `chmod +x` the hook scripts.
5. Read the just-fetched `wiki-install/SKILL.md` and execute Steps 0–7b directly.

The `/wiki-install` slash command is *not* yet registered at this point — it only registers on the next Claude restart — so executing the skill body inline is the only path. The existing copy-files install path is preserved as "Manual install (alternative)". `README.md` Quick Start leads with the remote one-liner.

**Restart semantics.** Hooks are live immediately after install without a Claude restart; only slash commands require a restart before they appear in the registry.

## Related Notes

- [[Wiki Install Skill]]
- [[Update Flow]]
- [[Wiki Update Skill]]
