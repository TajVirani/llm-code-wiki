
**Summary**: Rules.md §12 row 7 — module-cluster shape detection requiring all four signals (S1 links, S2 keywords, S3 domains, S4 word band).
**Tags**: #curator #trigger #modules #signals
**Created**: 2026-05-06T00:00:00+00:00
**Last Updated**: 2026-05-06T00:00:00+00:00

---

## Content

Rules.md §12 row 7 defines module-cluster shape detection by four deterministic signals, all of which must be true for trigger 7 to fire:

- **S1 — Link references:** ≥3 wiki-link or basename references to existing notes in the entry/concept body.
- **S2 — Keyword categories:** ≥3 of 4 keyword categories present: trigger / storage / executor / outcome.
- **S3 — Domain breadth:** referenced or own tags span ≥2 distinct dominant codebase domains. Dominant domains are derived from `topic-index.md` as the top-frequency tags across its bullets.
- **S4 — Word band:** body word count is in [150, 1000].

The wiki-digest skill body's Step 3a pre-evaluates all four signals in bash and emits one labeled block per entry/concept:

```
### Trigger 7 signals: S1=N, S2=[trig=N, store=N, exec=N, out=N], S3=N, S4=N
```

The curator reads the labeled block and applies the all-four rule deterministically — no LLM judgment about whether a body "looks like" a module.

**Bash implementation note:** the signal logic uses `csplit` to chunk the session inbox into per-entry files, then computes signals via `grep`/`wc` on each chunk. The research-doc loop applies the same pattern over each file. There is no `awk` anywhere in the signal logic — see [[skill-bash-injection-dollar-n-expansion|Skill Bash Injection $N Expansion]] for why awk is unsafe here.

**Fallback:** if `disableSkillShellExecution: true` is set, the bash injections produce empty strings. The curator falls back to computing signals itself with Read/Grep on each entry/concept body (W7 extension).

If trigger 7 fires on a non-MODULES handle, the curator emits an OVERRIDE row routing to MODULES per its Step 2c discipline.

## Related Notes

- [[modules-category|MODULES Category]]
- [[deletion-test-gate|Deletion Test Gate]]
- [[skill-bash-injection-dollar-n-expansion|Skill Bash Injection $N Expansion]]
- [[wiki-curator-agent|Wiki Curator Agent]]
- [[version-1-2-0-release|Version 1.2.0 Release]]
