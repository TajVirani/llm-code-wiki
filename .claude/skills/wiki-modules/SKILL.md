---
name: wiki-modules
description: Manual scan of the wiki to (1) propose MODULES notes for clusters that lack one, and (2) audit existing MODULES notes against the current wiki state. Read-only — outputs a plan, never writes. Use when refreshing the orientation layer or before a major refactor.
allowed-tools: Read, Glob, Grep, Bash
---

# Wiki modules — synth + audit

The user invokes `/wiki-modules` to refresh their understanding of the wiki's orientation layer (`wiki/MODULES/`) without committing to writes. This skill emits two sections in one run:

1. **Synthesize** — proposed MODULES notes for clusters that lack one. Each proposal lists candidate children with deterministic cluster signals. The user decides whether to draft any.
2. **Audit** — existing MODULES notes checked against the current wiki state. Surfaces broken links, deprecated children, unlinked candidates, and scope drift.

Read-only by contract. The skill never writes to `wiki/`. Dispatching changes is the user's job — drop drafts into `wiki/inbox/<slug>.md` for the next `/wiki-digest`, write `@ MODULES::<slug>` handles into `wiki/inbox/_session.md`, or edit module notes manually.

## Inputs

- Existing modules:
  !`find wiki/MODULES -maxdepth 1 -type f -name '*.md' ! -name '_*' 2>/dev/null | sort`

- Detail-note candidates (children pool — every leaf in ARCHITECTURE/FUNCTIONS/RESEARCH/DIAGRAMS):
  !`find wiki/ARCHITECTURE wiki/FUNCTIONS wiki/RESEARCH wiki/DIAGRAMS -type f -name '*.md' ! -name '_*' 2>/dev/null | sort`

- Topic-index for tag/topic context:
  !`cat wiki/topic-index.md 2>/dev/null`

- Domain-tag dominance set (top-10 tag frequency across topic-index — used to filter cluster signals from noise):
  !`grep -oE '#[a-z][a-z0-9-]*' wiki/topic-index.md 2>/dev/null | sort | uniq -c | sort -rn | head -n 10 | sed -E 's/^[[:space:]]+[0-9]+[[:space:]]+//'`

## Cluster detection (deterministic, no embeddings)

Three signals — all bash-evaluable, no semantic similarity (anti-feature A10).

(Implementation note: these blocks deliberately avoid `awk` — Claude Code's `!`-injection layer expands `$N` references in awk scripts to empty strings before the shell sees them, breaking field access (see `wiki/RESEARCH/skill-bash-injection-dollar-n-expansion.md`). All per-line slicing here uses `cut`/`sed`/`grep` + a `while read` loop instead.)

### Signal 1 — Filename prefix

Group detail-note basenames by their first kebab segment. A prefix with ≥3 notes is a candidate cluster.

!`for f in $(find wiki/ARCHITECTURE wiki/FUNCTIONS wiki/RESEARCH wiki/DIAGRAMS -type f -name '*.md' ! -name '_*' 2>/dev/null); do basename "$f" .md | cut -d- -f1; done | sort | uniq -c | sort -rn | sed -E 's/^[[:space:]]+//' | while read -r cnt prefix; do if [ "$cnt" -ge 3 ]; then echo "$cnt $prefix"; fi; done`

For each `prefix` reported above, list its members (the candidate children pool):

!`for f in $(find wiki/ARCHITECTURE wiki/FUNCTIONS wiki/RESEARCH wiki/DIAGRAMS -type f -name '*.md' ! -name '_*' 2>/dev/null); do basename "$f" .md | cut -d- -f1; done | sort | uniq -c | sort -rn | sed -E 's/^[[:space:]]+//' | while read -r cnt prefix; do
  if [ "$cnt" -ge 3 ]; then
    echo "## prefix=$prefix"
    find wiki/ARCHITECTURE wiki/FUNCTIONS wiki/RESEARCH wiki/DIAGRAMS -type f -name "${prefix}-*.md" 2>/dev/null | sort
    echo
  fi
done`

### Signal 2 — Tag overlap (cluster cohesion)

For each prefix-cluster, compute the tag mode and flag any member that shares fewer than 2 tags with the mode (prefix-misfit):

For each prefix-cluster identified by Signal 1, read the `**Tags**:` line of each member, count tag frequencies, and identify the mode (top 2 tags). Members whose own tag list shares 0 or 1 tags with the mode are reported as misfits — the cluster prefix may be misleading and a MODULES proposal should be made cautiously.

You (the assistant running this skill) compute this from the file contents using Read/Grep — bash alone can't reliably tally cross-file tag intersections. For each cluster in Signal 1's output:

1. For each member: `grep -m1 '^\*\*Tags\*\*:' <file>` → extract the `#tag1 #tag2 …` list.
2. Tally tag frequency across the cluster; pick the top-2 most frequent tags as the cluster mode.
3. For each member: count overlap with the mode. <2 overlap → flag as misfit.

Report the cluster mode + misfit list per prefix.

### Signal 3 — Link graph density

For each prefix-cluster, count `[[wiki-link]]` edges between cluster members:

!`for f in $(find wiki/ARCHITECTURE wiki/FUNCTIONS wiki/RESEARCH wiki/DIAGRAMS -type f -name '*.md' ! -name '_*' 2>/dev/null); do basename "$f" .md | cut -d- -f1; done | sort | uniq -c | sort -rn | sed -E 's/^[[:space:]]+//' | while read -r cnt prefix; do
  if [ "$cnt" -ge 3 ]; then
    total=0
    for ff in $(find wiki/ARCHITECTURE wiki/FUNCTIONS wiki/RESEARCH wiki/DIAGRAMS -type f -name "${prefix}-*.md" 2>/dev/null); do
      count=$(grep -oE "\[\[${prefix}-[^]|]*" "$ff" 2>/dev/null | wc -l)
      total=$((total + count))
    done
    echo "prefix=$prefix intra-cluster-link-count=$total"
  fi
done`

High intra-cluster edge density confirms a real cluster. Low density (0–1 edges across ≥3 notes) flags a misleading prefix — the notes happen to share a name root but don't actually reference each other. Skip the proposal in that case.

## Synthesize section — for each clean cluster lacking a MODULES note

For each prefix-cluster passing Signals 1 + 2 + 3 (≥3 members, ≤1 misfit, ≥2 intra-cluster links) AND no existing `wiki/MODULES/<prefix>.md`, emit:

```
## Proposed Module: <cluster-name>

Candidate children (N notes, M intra-cluster links, dominant tags: #x #y):
  - ARCHITECTURE/<file1>.md
  - ARCHITECTURE/<file2>.md
  - FUNCTIONS/<file3>.md
  - …

Misfits (do NOT include as children without review):
  - RESEARCH/<file4>.md (tag overlap: 1 of 2 — shares #x but not #y)

Suggested next step: draft a MODULES note covering this cluster's purpose, boundary,
triggers, storage, behavior, rules, children. Drop the draft into
wiki/inbox/<slug>.md and run /wiki-digest, or write a `@ MODULES::<slug>` handle entry.
```

A cluster name is the prefix slug itself unless the prefix is generic (`auth`, `db`, `api`) — in which case suggest a more specific bare-slug name in the proposal heading.

## Audit section — for each existing wiki/MODULES/<slug>.md

For each existing module note, run four checks:

### Check 1 — Linked children verified

For every `[[basename|…]]` reference inside the module's `### Children` section: confirm `wiki/**/<basename>.md` exists. Tally found vs broken.

### Check 2 — Deprecated children

For every linked child: read the child's `**Tags**:` line. If `#deprecated` is present, flag it.

### Check 3 — Unlinked cluster candidates

For the module's slug, identify notes whose filename starts with `<slug>-` OR whose `**Tags**:` includes `#<slug>`. Any such note NOT linked from the module's Children section is reported as an unlinked candidate. The module may have grown coverage gaps as detail notes were added.

### Check 4 — Scope drift

Compare the module's own `**Tags**:` line to the dominant tags of its linked children. If the children's collective top-2 tags are not a subset of the module's tags, flag scope drift.

Emit per module:

```
## Audit: MODULES/<slug>.md

✓ <N> linked children verified to exist
⚠ <M> children deprecated (tagged #deprecated): <list>
⚠ <K> linked children no longer exist (broken wiki-links): <list>
⚠ <P> notes match the cluster signal but are NOT linked from this module: <list>
⚠ scope drift: cluster's dominant tags are now <#a #b> but module's tags are <#x #y>
```

Suppress checks that pass cleanly (don't emit a `✓` for empty findings — only the Check 1 success line is universal).

## Output format

Emit both sections in one run, in this order:

```
# /wiki-modules — synth + audit

(Generated <ISO-8601 timestamp>; read-only.)

## Synthesize
<one block per proposed cluster, or "No proposals — all detected clusters already have MODULES notes.">

## Audit
<one block per existing module, or "No existing modules to audit.">

## Summary
- Proposals: <N>
- Existing modules audited: <M>
- Broken links found: <K>
- Deprecated children: <P>
- Unlinked candidates: <Q>
- Scope-drift flags: <R>
```

No interactive prompts. Output is purely informational — the user dispatches changes through `/wiki-digest` or manual edits.

## Things this skill does NOT do

- Does NOT write to `wiki/` (no Write/Edit in allowed-tools — Read/Glob/Grep/Bash only).
- Does NOT use embeddings or semantic similarity (anti-feature A10). Cluster detection is filename-prefix + tag-overlap + link-graph only.
- Does NOT propose MODULES notes for prefixes with <3 detail notes, ≥2 misfits, or 0–1 intra-cluster links — those are likely misleading prefixes, not real clusters.
- Does NOT modify `wiki/Rules.md` or anything under `wiki/_templates/`.
- Does NOT auto-fork the curator. The curator runs only on `/wiki-digest`.
