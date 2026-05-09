---
name: wiki-modules
description: Sole writer to wiki/MODULES/. Detects deep-abstraction clusters via three signals (filename prefix, single-dominant-tag, external fan-in) and dispatches one module-author subagent per qualifying cluster — in parallel — to author or re-author each module note. Every run re-authors every existing module from current cluster state. Use when refreshing the orientation layer or after material wiki growth.
allowed-tools: Read, Glob, Grep, Bash, Task, Write, Edit
---

# Wiki modules — detect + author

The user invokes `/wiki-modules` to refresh the wiki's orientation layer (`wiki/MODULES/`). This skill is the **sole writer** to `wiki/MODULES/` (per ADR 0001) — the wiki-curator never writes MODULES notes. Every run is idempotent over current cluster state: every existing module is re-authored from scratch, and any new cluster passing the three signals gets a freshly authored module note.

MODULES notes are auto-generated artifacts. Manual edits do not survive a re-author. To improve a module's content, edit its children — the next `/wiki-modules` run synthesizes from them.

## What this skill does

1. **Detect clusters** in the current wiki using three deterministic signals (no embeddings, no semantic similarity — anti-feature A10).
2. **Dispatch a `module-author` subagent in parallel per qualifying cluster**, one Task call per cluster, all in a single message. Each subagent reads its cluster's children, applies pre-author and post-author depth gates, and writes `wiki/MODULES/<slug>.md` plus the matching `### Modules` row in `wiki/topic-index.md`.
3. **Audit** existing MODULES notes against current cluster state — flag stale modules whose clusters no longer pass the three signals, broken child links, deprecated children.
4. **Emit a summary** consolidating each subagent's pass/skip outcome plus the audit findings.

The author phase writes; the audit phase is informational. The skill itself does not write to `wiki/MODULES/` directly — every write goes through a `module-author` subagent so the gates and contract are enforced uniformly.

## Inputs

- Existing modules:
  !`find wiki/MODULES -maxdepth 1 -type f -name '*.md' ! -name '_*' 2>/dev/null | sort`

- Detail-note candidates (children pool — every leaf in ARCHITECTURE/FUNCTIONS/RESEARCH/DIAGRAMS):
  !`find wiki/ARCHITECTURE wiki/FUNCTIONS wiki/RESEARCH wiki/DIAGRAMS -type f -name '*.md' ! -name '_*' 2>/dev/null | sort`

- Topic-index for tag/topic context:
  !`cat wiki/topic-index.md 2>/dev/null`

## Cluster detection (three deterministic signals)

A cluster qualifies for module authoring iff ALL THREE signals pass. The signals are designed to identify **deep abstractions with narrow interfaces and rich implementations** (Ousterhout) — not just notes that share a name root.

(Implementation note: the bash blocks below deliberately avoid `awk` — Claude Code's `!`-injection layer expands `$N` references in awk scripts to empty strings before the shell sees them, breaking field access. See `wiki/RESEARCH/skill-bash-injection-dollar-n-expansion.md`. All per-line slicing here uses `cut`/`sed`/`grep` + a `while read` loop instead.)

### Signal 1 — Filename prefix (bootstrap)

Group detail-note basenames by their first kebab segment. A prefix with ≥3 notes is a candidate cluster. This signal generates the candidate set; it does not, by itself, indicate a real module.

!`for f in $(find wiki/ARCHITECTURE wiki/FUNCTIONS wiki/RESEARCH wiki/DIAGRAMS -type f -name '*.md' ! -name '_*' 2>/dev/null); do basename "$f" .md | cut -d- -f1; done | sort | uniq -c | sort -rn | sed -E 's/^[[:space:]]+//' | while read -r cnt prefix; do if [ "$cnt" -ge 3 ]; then echo "$cnt $prefix"; fi; done`

For each `prefix` reported above, list its members (the candidate children pool):

!`for f in $(find wiki/ARCHITECTURE wiki/FUNCTIONS wiki/RESEARCH wiki/DIAGRAMS -type f -name '*.md' ! -name '_*' 2>/dev/null); do basename "$f" .md | cut -d- -f1; done | sort | uniq -c | sort -rn | sed -E 's/^[[:space:]]+//' | while read -r cnt prefix; do
  if [ "$cnt" -ge 3 ]; then
    echo "## prefix=$prefix"
    find wiki/ARCHITECTURE wiki/FUNCTIONS wiki/RESEARCH wiki/DIAGRAMS -type f -name "${prefix}-*.md" 2>/dev/null | sort
    echo
  fi
done`

### Signal 2 — Single dominant tag (cluster cohesion)

For each prefix-cluster, compute the set of tags shared across all members. The cluster passes Signal 2 iff there exists **at least one tag that every member carries**. This is the "single dominant tag" rule from ADR 0001 — it replaces the prior top-2 mode test.

The intent: a deep abstraction has *one* unifying concept. Members may diverge into specialized topics past that shared concept (one tagged `#auth #oauth`, another `#auth #session`, another `#auth #cookie`) — they all share `#auth`, so they cohere as a module. The prior top-2 test rejected such clusters because the second-most-frequent tag wasn't shared by all members; the new rule admits them because the single-dominant-tag intersection is non-empty.

You (the assistant running this skill) compute this via Read/Grep — bash alone cannot reliably tally cross-file tag intersections. For each cluster from Signal 1:

1. For each member: `grep -m1 '^\*\*Tags\*\*:' <file>` → extract the `#tag1 #tag2 …` list.
2. Compute the set intersection across all members' tag lists.
3. If the intersection is non-empty: Signal 2 passes. Record the dominant tag(s) — every tag in the intersection. The cluster's "dominant tag" used downstream is the first one in the intersection (deterministic order).
4. If the intersection is empty: Signal 2 fails. The cluster does not qualify; do not dispatch a module-author for it.

Report per cluster: `S2: PASS (dominant tags: #x #y)` or `S2: FAIL (no tag is shared by all N members)`.

### Signal 3 — External fan-in concentration (information hiding)

For each prefix-cluster, count the number of **notes outside the cluster** that link to **≥2 distinct cluster members** via piped wiki-links. The cluster passes Signal 3 iff ≥1 external note fans into ≥2 distinct cluster members.

The intent: a module is known to the rest of the system. If nothing outside the cluster references it as a unit (zero external notes link to two or more of its members), the cluster is internally cohesive but invisible — it has no external interface, and a module note synthesizing it would have no audience. The prior intra-cluster-link test (Signal 3 in the legacy form) measured cohesion *inside* the cluster, which rejected clusters whose internal links were sparse but which were heavily referenced from outside.

Compute via Bash — grep for piped wiki-links targeting cluster member basenames, exclude links sourced from inside the cluster itself:

!`for prefix in $(for f in $(find wiki/ARCHITECTURE wiki/FUNCTIONS wiki/RESEARCH wiki/DIAGRAMS -type f -name '*.md' ! -name '_*' 2>/dev/null); do basename "$f" .md | cut -d- -f1; done | sort | uniq -c | sort -rn | sed -E 's/^[[:space:]]+//' | while read -r cnt p; do [ "$cnt" -ge 3 ] && echo "$p"; done); do
  members=$(find wiki/ARCHITECTURE wiki/FUNCTIONS wiki/RESEARCH wiki/DIAGRAMS -type f -name "${prefix}-*.md" 2>/dev/null)
  member_basenames=$(echo "$members" | xargs -n1 basename 2>/dev/null | sed 's/\.md$//')
  external_with_2plus=0
  for ext in $(find wiki -type f -name '*.md' ! -path 'wiki/inbox/*' ! -path 'wiki/_templates/*' ! -path 'wiki/MODULES/*' 2>/dev/null); do
    is_member=$(echo "$members" | grep -Fx "$ext")
    if [ -n "$is_member" ]; then continue; fi
    distinct_targets=0
    for m in $member_basenames; do
      hit=$(grep -cE "\[\[${m}(\||\])" "$ext" 2>/dev/null)
      if [ "$hit" -gt 0 ]; then distinct_targets=$((distinct_targets + 1)); fi
    done
    if [ "$distinct_targets" -ge 2 ]; then external_with_2plus=$((external_with_2plus + 1)); fi
  done
  echo "prefix=$prefix external-fan-in-with-2-plus-distinct-targets=$external_with_2plus"
done`

For each cluster: `S3: PASS (N external notes link to ≥2 cluster members)` if the count is ≥1; `S3: FAIL (no external note fans into ≥2 cluster members)` otherwise.

## Dispatch — module-author subagents in parallel

After computing S1+S2+S3 for every prefix-cluster, build the list of qualifying clusters: those passing all three signals.

For each qualifying cluster, prepare a dispatch payload:

```
slug: <prefix>            # bare kebab single-concept slug; if the prefix is generic
                          # (auth, db, api), pick a more specific bare slug from the
                          # children's collective domain — surface the rename in the
                          # summary so the user can adjust on the next run
candidate_children:
  - <relative path from wiki/, e.g. ARCHITECTURE/scheduler-overview.md>
  - …
existing_module: <wiki/MODULES/<slug>.md if present, else "none">
dominant_tags: <the Signal 2 intersection — typically one tag, possibly more>
```

**Dispatch in parallel.** Send ONE message containing one `Task` tool call per qualifying cluster — all calls in the same message — using the `module-author` subagent. Each subagent receives its single cluster payload as its prompt and runs independently. Parallel dispatch is required: the subagents do not share state and write to disjoint paths (each writes its own `wiki/MODULES/<slug>.md` and updates a single bullet in `wiki/topic-index.md`; serial concurrency on `topic-index.md` is acceptable because each agent reads-then-writes the file once).

Do NOT dispatch more than one subagent per cluster. Do NOT dispatch a subagent for a cluster that failed any of S1/S2/S3.

After all subagents complete, collect their outputs (each emits a structured `## Module authored: <slug>` block on success or `## Pre-author gate failed: <slug>` / `## Post-author gate failed: <slug>` / `## Slug collision: <slug>` on rejection).

## Audit — existing modules vs current cluster state

Independent of the dispatch phase. Run the audit on every existing `wiki/MODULES/<slug>.md` file:

### Check 1 — Cluster still qualifies

For the module's slug, find the matching prefix-cluster in the Signal 1/2/3 output above. If the cluster:
- No longer exists (S1 fails: <3 members with this prefix), OR
- Fails S2 (no shared dominant tag), OR
- Fails S3 (no external fan-in)

Flag the module as `STALE-MODULE` — the cluster that originally justified it has shifted out from under the note. The module file is NOT auto-deleted. Surface the slug, the failing signal(s), and the recommendation: "Consider deleting `wiki/MODULES/<slug>.md` manually, or restructure the children so the cluster qualifies again."

### Check 2 — Linked children verified

Read the module's `### Children` section. For every `[[basename|…]]` reference, confirm `wiki/**/<basename>.md` exists. Tally found vs broken. Broken-link findings are advisory only — the next dispatch will overwrite the file with a fresh Children list, so this check mostly surfaces drift between runs.

### Check 3 — Deprecated children

For every linked child: read its `**Tags**:` line. If `#deprecated` is present, flag it. Same advisory framing as Check 2.

### Check 4 — Unlinked candidates

For the module's slug, identify notes whose filename starts with `<slug>-` OR whose `**Tags**:` includes `#<slug>`. Any such note NOT linked from the module's Children section is reported as an unlinked candidate. Like Check 2/3, the next dispatch fixes this — but surfacing it during the audit phase tells the user whether the cluster is still cohesive enough to warrant a re-author.

Emit per existing module:

```
## Audit: MODULES/<slug>.md

- Cluster signals: S1=<PASS/FAIL>, S2=<PASS/FAIL>, S3=<PASS/FAIL>
  <STALE-MODULE warning if any signal fails>
- ✓ <N> linked children verified to exist
- ⚠ <M> children deprecated: <list>
- ⚠ <K> linked children no longer exist: <list>
- ⚠ <P> notes match the cluster signal but are NOT linked: <list>
```

Suppress checks that pass cleanly. Always show the `Cluster signals:` line so the user can see at a glance whether each existing module's justification still holds.

## Output format

Emit the full run summary in this order:

```
# /wiki-modules — detect + author + audit

(Generated <ISO-8601 timestamp>.)

## Cluster detection

For each prefix from Signal 1, report S1/S2/S3 pass/fail with the deterministic counts.

## Authoring (dispatched module-author subagents)

For each qualifying cluster, the subagent's structured output:
- ## Module authored: <slug> (success block from module-author Step 7)
- ## Pre-author gate failed: <slug> (gate rejection)
- ## Post-author gate failed: <slug> (gate rejection)
- ## Slug collision: <slug> (collision rejection)

## Audit

For each existing wiki/MODULES/<slug>.md, the audit block above.

## Summary
- Clusters detected (S1 pass): <N>
- Clusters qualifying (S1+S2+S3 pass): <K>
- Modules authored (subagent success): <A>
- Modules skipped by pre-author gate: <P1>
- Modules skipped by post-author gate: <P2>
- Modules skipped by slug collision: <P3>
- Existing modules audited: <M>
- Stale modules (cluster signals no longer pass): <S>
- Broken child links found: <B>
- Deprecated children: <D>
- Unlinked candidates: <U>
```

## Things this skill does NOT do

- Does NOT detect clusters via embeddings or semantic similarity (anti-feature A10). Detection is filename-prefix + single-dominant-tag intersection + external-fan-in count only.
- Does NOT author module notes itself. Every authoring write goes through a `module-author` subagent so the pre-author and post-author gates run uniformly. The skill body coordinates dispatch; the subagents own the writes.
- Does NOT modify `wiki/Rules.md` or anything under `wiki/_templates/`.
- Does NOT delete stale module files automatically. A `STALE-MODULE` warning surfaces the slug and the failing signal; the user decides whether to delete or restructure.
- Does NOT touch `wiki/inbox/_session.md` or any research-doc source — those flow through `/wiki-digest`.
- Does NOT update the `### Notes` section of `wiki/topic-index.md` — that section is owned by the wiki-curator's Step 9 during `/wiki-digest`. The module-author subagents update only the `### Modules` section.
- Does NOT re-validate the three signals inside the module-author subagents. The dispatch is the authorization; the subagent trusts its caller.
