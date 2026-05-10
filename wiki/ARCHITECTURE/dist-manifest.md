
**Summary**: Distribution manifest enumerating every file `/wiki-update` and the remote-install fetcher ship from upstream into a consumer project, with per-line `overwrite`/`keep` policy.
**Tags**: #architecture #distribution #wiki-update #scaffold
**Created**: 2026-05-09T00:00:00+00:00
**Last Updated**: 2026-05-09T00:00:00+00:00

---

## Content

`dist-manifest.txt` (at the repo root) is the canonical list of every file the upstream scaffold ships into a consumer project. Both `/wiki-update` and the remote-install fetcher read it line-by-line.

### Line format

```
PATH [POLICY]
```

`POLICY` is optional; when absent it defaults to `overwrite`.

- **`overwrite`** — fetch upstream and replace the local file unconditionally. Used for code the user does not customize: skills, agents, hook scripts, version files.
- **`keep`** — skip if the local file exists; notify the user when upstream differs but do not modify their copy. Used for user-owned seeds the consumer may have customized.

### What is currently listed

- `VERSION` and `CHANGELOG.md`.
- Every `SKILL.md` under `.claude/skills/` plus its template/reference sidecar files.
- Every agent definition under `.claude/agents/`.
- Both hook scripts (`inbox-stop.sh`, `recall-prompt.sh`). These require `chmod +x` after fetch; the fetcher applies the bit.
- User-owned wiki seeds — `wiki/Rules.md`, `wiki/_templates/note.md`, `wiki/_templates/module.md`. All marked `keep` so user customizations survive update.

### What is intentionally NOT listed

- **`.claude/settings.json`** — managed by `/wiki-install` Step 5 and `/wiki-update` Step 5 with a jq-based merge protocol that preserves project-specific hooks, permissions, env vars, and MCP servers.
- **`CLAUDE.md`** — managed by `/wiki-install` Step 6 and `/wiki-update` Step 6 with a section-replacement protocol that only rewrites the `## Auto-maintained wiki` section.
- **`wiki/topic-index.md`** — the curator regenerates this from a seed at install time; updates do not propagate it from upstream.

### Maintenance discipline

When adding a new skill, agent, hook, template, or scaffold component to upstream, **also add its files here in the same change** — otherwise `/wiki-update` will not propagate them to consumers and downstream installations will silently miss the new component. The 1.3.0 release adds `wiki-code-crawler`, `module-author`, and `design-pattern-doc` to the manifest as part of the merge that bumped `VERSION`.

For the end-to-end update mechanism (version compare → changelog slice → manifest fetch → settings/CLAUDE merge), see [[update-flow|Update Flow]].

## Related Notes

- [[update-flow|Update Flow]]
- [[remote-install-flow|Remote Install Flow]]
- [[wiki-update-skill|Wiki Update Skill]]
- [[wiki-install-skill|Wiki Install Skill]]
- [[install-template-files|Install Template Files]]
