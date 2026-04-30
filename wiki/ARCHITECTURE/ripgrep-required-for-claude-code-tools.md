
**Summary**: Claude Code's Glob and Grep tools wrap ripgrep and fail with `posix_spawn 'rg' ENOENT` when `rg` is not on `$PATH`; install ripgrep as an environment prerequisite.
**Tags**: #prerequisite #ripgrep #tooling #architecture

**Created**: 2026-04-30T00:00:00+00:00
**Last Updated**: 2026-04-30T00:00:00+00:00

---

## Content

Claude Code's `Glob` and `Grep` tools shell out to `ripgrep` (`rg`) under the hood. When `rg` is not on `$PATH`, both tools fail with `posix_spawn 'rg' ENOENT`. This is documented as an environment prerequisite in `INSTALL.md` (Prerequisites + Known interactions sections).

**Symptom during `/wiki-digest`:** the curator's same-concept conflict detection and post-write link audit lose access to filed-note enumeration via tool calls. Mitigation: the `wiki-digest` skill body's bash-injected `find` and `grep` inputs are independent of `rg` and continue to work, so the curator can still see the wiki tree even when its own Glob/Grep are broken.

**Symptom during `/wiki-recall`:** keyword grep across `wiki/` returns nothing useful. The recall agent has no fallback path here — its protocol depends on Glob/Grep — so on a host without `rg`, recall produces empty results.

**Fix:** install ripgrep at the OS level. On Debian/Ubuntu/WSL: `apt-get install ripgrep`. macOS: `brew install ripgrep`. Windows native: `winget install BurntSushi.ripgrep.MSVC` or scoop.

**Why this is ARCHITECTURE, not RESEARCH:** the dependency is an environmental/install-time prerequisite of the scaffold's read and write paths. It informs project setup and dev workflow, which Rules.md §2 places under ARCHITECTURE. RESEARCH is reserved for domain math, formulas, derivations, and algorithm design notes.

## Related Notes

- [[Recall Path]]
- [[Stop Hook Self Heals Runtime Dir]]
- [[Skill Bash Injection Isolation]]
