
**Summary**: L1 layer of the test harness — file-reference checks, frontmatter validation, and `bash -n` syntax sweeps over hook scripts and skill-body bash blocks.
**Tags**: #testing #static-checks #shell #function

**Created**: 2026-05-09T14:17:00+00:00
**Last Updated**: 2026-05-09T14:17:00+00:00

---

## Content

**Path:** `tests/static.sh`
**Layer:** L1 of the [[test-harness|Test Harness]].

### What it checks

- **File-reference resolution.** Walks `dist-manifest.txt` asserting every `PATH` entry resolves on disk. Detects manifest drift before `/wiki-update` would fetch a 404.
- **Frontmatter on every `SKILL.md` and agent `.md`.** CRLF-tolerant — must start with `---` and contain `name` and `description` fields. Catches malformed YAML before Claude Code's loader does.
- **Hook script syntax.** `bash -n` plus executable-bit check on `inbox-stop.sh` and `recall-prompt.sh`.
- **Skill-body bash blocks.** `bash -n` on every fenced ` ```bash ` block extracted from each `SKILL.md`. Currently 5 blocks in `wiki-install`, 14 in `wiki-update`; other skills emit zero. Catches syntax bugs in scaffold bootstrap blocks before they ship.
- **VERSION semver match.** Local `VERSION` parses as semver.
- **Top-level docs presence.** `CHANGELOG.md`, `INSTALL.md`, `README.md` all exist.
- **Install-template anchors.** `<<CREATED_TS>>` / `<<UPDATED_TS>>` placeholders present in `topic-index.seed.md`; `### Modules` / `### Notes` H3 anchors present; `## Auto-maintained wiki` H2 present in `CLAUDE-MD-SECTION.md`.

### Sources

- `lib/assert.sh` — assertion primitives.
- `lib/extract-bash-blocks.sh` — fenced-block extractor (shared with L3).

### Why this layer matters

L1 is the cheapest possible CI gate — pure shell, no Claude, no fixtures. It catches the failures that would otherwise surface as confusing errors during a real `/wiki-install` or `/wiki-update` run (manifest 404s, broken bash syntax, missing template anchors).

## Related Notes

- [[test-harness|Test Harness]]
- [[test-hooks-layer|Test Hooks Layer]]
- [[test-install-e2e-layer|Test Install E2E Layer]]
- [[dist-manifest|Dist Manifest]]
- [[install-template-files|Install Template Files]]
