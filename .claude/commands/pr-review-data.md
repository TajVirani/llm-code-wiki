---
description: Run the incremental data-structure audit on the current branch/PR. Alias for the data-structure-audit skill.
---
# /pr-review-data

Invoke the data-structure-audit skill (.claude/skills/data-structure-audit/SKILL.md) and follow it exactly:

1. Run `bash .claude/skills/data-structure-audit/scripts/audit_scope.sh scope` to determine what changed since the last recorded audit.
2. Audit ONLY the in-scope files, using the skill's three phases and report template.
3. After delivering the report, run `... audit_scope.sh record` and ensure the state file (and `.gitattributes` union driver) is staged for commit, per the skill's Step N.

Scope override from the user: $ARGUMENTS
(If $ARGUMENTS is empty, use the git-derived scope. If the user restricted scope via arguments, do NOT record the run — partial audits must not be marked as complete, per the skill.)
