
**Summary**: Every internal wiki-link must use the piped form `[[note-basename|Display Title]]`; bare `[[Title]]` is forbidden because Obsidian resolves on filename, not H1.
**Tags**: #wiki #linking #obsidian #conventions
**Created**: 2026-05-01T23:14:00+00:00
**Last Updated**: 2026-05-01T23:14:00+00:00

---

## Content

**Path:** `wiki/Rules.md` §3 and §7.

**The contract.** Every internal wiki-link inside `wiki/**/*.md` uses the piped form:

```
[[note-basename|Display Title]]
```

- The part **before** `|` is the target file's name without `.md`, in kebab-case per Rules.md §5 (e.g. `wiki-curator-agent`).
- The part **after** `|` is the human-readable display title (e.g. `Wiki Curator Agent`).
- Bare `[[Display Title]]` is explicitly forbidden, regardless of whether an H1 happens to match.
- Folder-prefixed forms like `[[CATEGORY/note-basename|Title]]` are also forbidden — Obsidian resolves bare basenames across the whole vault, and folder prefixes break when notes move between category folders.

**Why piped is mandatory.** Obsidian's default link resolver matches the text inside `[[...]]` against **filenames**, not against H1 titles. Filenames in this wiki are kebab-case (`recall-path.md`); H1 titles are typically Title Case (`Recall Path`). A bare `[[Recall Path]]` therefore does NOT resolve to `recall-path.md` — clicking it creates a brand-new blank note named `Recall Path.md` at the vault root, silently fragmenting the graph.

The piped form sidesteps this by giving the resolver the kebab-case basename directly, while still letting the rendered link show a readable title. It is the only form that survives both Obsidian's resolver and casual human reading.

**Where the contract is enforced.**

1. **Curator Step 6 validation** — every plan row that writes a note checks every `[[...]]` reference in the body against the piped contract. Bare links are surfaced as validation failures and halt the apply step.
2. **Curator Step 4 split-backlink rewrites** — when splitting a note, the curator greps `wiki/**/*.md` for `[[old-slug|...]]` (the canonical form) plus any legacy bare references, and rewrites each to `[[new-slug|Display Title]]`. The display title after `|` is preserved verbatim if the original link had one (D-07); otherwise it is derived from the new split's H1.
3. **Digest Step 5 / curator Step 8 link audit** — the post-write audit takes the part before `|` as a basename and verifies a matching `wiki/**/<basename>.md` exists. Bare `[[X]]` references are surfaced as out-of-contract violations regardless of whether an H1 happens to match.
4. **Shipped install templates** — `topic-index.seed.md` ships with `[[Rules|Wiki Rules]]` so freshly installed wikis are link-resolvable from the first turn.

**Audit recipe.** A simple grep that surfaces bare links is `\[\[[^|\]]+\]\]` (matches `[[X]]` but not `[[X|Y]]`). Any hit inside `wiki/` (excluding `wiki/_templates/`) is a contract violation.

**Migration note.** Pre-contract notes that used bare `[[Title]]` form are rewritten opportunistically — the curator's Step 4 backlink pass already greps for legacy bare references when splitting, and the Step 8 audit surfaces remaining ones for manual cleanup. There is no big-bang migration pass; the audit + per-edit rewrite path drains the legacy population over time.

## Related Notes

- [[wiki-curator-agent|Wiki Curator Agent]]
- [[wiki-digest-skill|Wiki Digest Skill]]
- [[wiki-install-skill|Wiki Install Skill]]
- [[topic-index-as-recall-map|Topic Index As Recall Map]]
