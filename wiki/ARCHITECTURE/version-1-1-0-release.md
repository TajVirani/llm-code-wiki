
**Summary**: Release 1.1.0 ships the bare-to-piped wiki-link contract switch with a deterministic transform recipe and post-sweep audit guidance.
**Tags**: #release #versioning #wiki #linking
**Created**: 2026-05-06T00:00:00+00:00
**Last Updated**: 2026-05-06T00:00:00+00:00

---

## Content

Release 1.1.0 finalizes the piped wiki-link contract switch across the scaffold. CHANGELOG.md's 1.1.0 entry documents the bare-to-piped migration with a deterministic transform recipe: kebab-case basename derivation from the link target, code-block and HTML-comment skip during sweeping, and a post-sweep audit performed by the curator's Step 8 link-existence pass.

Consumers updating from any release prior to 1.1.0 must run the post-sweep audit on their own wikis after `/wiki-update`. `/wiki-update` only refreshes the `.claude/` distribution; it never touches `wiki/` content. The audit is therefore the user's responsibility once the new contract is in place.

The new contract is normative going forward — bare `[[Title]]` links are forbidden because Obsidian's resolver matches against filenames, not H1 titles. See [[piped-wiki-link-contract|Piped Wiki-Link Contract]] for the full rationale and grammar.

## Related Notes

- [[piped-wiki-link-contract|Piped Wiki-Link Contract]]
- [[update-flow|Update Flow]]
- [[wiki-update-skill|Wiki Update Skill]]
