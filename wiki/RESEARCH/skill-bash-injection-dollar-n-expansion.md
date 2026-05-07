
**Summary**: Claude Code's skill `!`-injection layer expands `$N` to empty strings before the shell sees them, even inside single-quoted awk scripts.
**Tags**: #research #claude-code #skill #bash #pitfall
**Created**: 2026-05-06T00:00:00+00:00
**Last Updated**: 2026-05-06T00:00:00+00:00

---

## Content

**Pitfall.** Claude Code's skill-body `!`-injection layer expands shell positional parameters (`$0`, `$1`, …, `$N`) to empty strings before the shell sees the command. The expansion happens at a higher layer than the shell, so single-quote protection that normally works in bash (`awk '... $0 ...'`) is bypassed.

**Symptom.** An awk script that reads `$0` (the input record) silently sees an empty string. Logic such as `slug=$0; sub(/^@ [A-Z]+::/, "", slug)` leaves `slug` empty, and the script emits no useful output. The accompanying error message from Claude Code reads roughly "Shell command failed for pattern …" and shows the awk source with `$N` already stripped — a useful diagnostic clue once you know to look for it.

**Mitigation.** Avoid `$N` entirely in skill `!`-blocks. Two safe patterns:

- **Chunk-then-aggregate.** Use `csplit` to split multi-record input (for example, the session inbox split by `^@ ` handle lines) into per-record temp files, then compute aggregates with `grep`, `wc`, `sed`, `cut`, and `paste` on each chunk. No field access via `$N` is required.
- **External script file.** If awk is unavoidable, write the script to a tempfile and run `awk -f scriptfile.awk` — the injection layer doesn't traverse into the script file's contents.

The wiki-digest skill body's Step 3a session-inbox loop and dominant-tag computation now follow the chunk-then-aggregate pattern.

**Related context.** This is distinct from [[skill-bash-injection-isolation|Skill Bash Injection Isolation]], which describes a different pitfall: bash blocks within a skill body do not share shell state, so each `!`-block is an independent shell. The two pitfalls compose — `$N` is stripped, AND no variable defined in one block is visible in the next.

## Related Notes

- [[skill-bash-injection-isolation|Skill Bash Injection Isolation]]
- [[trigger-7-module-cluster|Trigger 7 Module Cluster]]
- [[wiki-digest-skill|Wiki Digest Skill]]
