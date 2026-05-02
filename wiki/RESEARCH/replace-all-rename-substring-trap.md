
**Summary**: Global `replace_all` rewrites of a slash-command or skill name silently mangle file paths and unrelated identifiers that contain the rename target as a substring.
**Tags**: #refactor #rename #pattern #research
**Created**: 2026-04-30T16:09:00+00:00
**Last Updated**: 2026-04-30T16:09:00+00:00

---

## Content

**Trap.** When renaming a slash command, skill, or symbol via a global `replace_all "/X" → "/wiki-X"` (or any similar substring-level substitution), every occurrence of the target string is rewritten — including occurrences embedded inside file paths, filenames, and unrelated identifiers that merely *contain* the rename target as a substring.

**Concrete instance.** Renaming `/recall` → `/wiki-recall` rewrote `.claude/hooks/recall-prompt.sh` references to `.claude/hooks/wiki-recall-prompt.sh`, even though the script was deliberately *not* renamed — internal scaffolding keeps its original name (the `wiki-` prefix convention applies only to the user-typed surface, not to internal hook scripts). The script path on disk did not change; only the references to it were corrupted.

**Symptom.** The breakage does not surface immediately. It manifests later as either an install-time ABORT ("required file not found") or a runtime path-not-found when the hook tries to invoke the now-mis-referenced script. The root cause is invisible in the rename diff because the diff looks correct — the substitution did exactly what was asked.

**Mitigation.**

1. After any global rename, audit every referenced filesystem path against the actual filesystem. Rough recipe:
   ```bash
   grep -roE '\.claude/[a-z/-]+\.sh' . | awk -F: '{print $2}' | sort -u | xargs -I{} test -f {} || echo "missing: {}"
   ```
2. Before performing the rename, search for `<old>-<word>.<ext>` patterns where `<old>` is the rename target — those filenames will be silently rewritten to `<new>-<word>.<ext>` and almost certainly should not be.
3. Prefer scoped renames (single-file or directory-bounded) over global `replace_all` when the target string is short or generic enough to appear inside other identifiers.

**Why it bites.** Substring-level substitution has no awareness of token boundaries, file-path semantics, or the difference between "a slash command name" and "a fragment of an unrelated path". The tool is doing what was asked; the human's mental model is what was wrong.

## Related Notes

- [[skill-naming-wiki-prefix|Skill Naming Wiki Prefix]]
