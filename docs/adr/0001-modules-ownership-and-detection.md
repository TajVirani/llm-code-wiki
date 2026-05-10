# MODULES ownership and Ousterhout-grounded detection

## Context

The first real-world `/wiki-modules` run on a large codebase surfaced 13 prefix-clusters but proposed only one (`shared`). The skill output itself flagged five clusters as "arguably real modules" that were rejected by Signal 2 (top-2 tag-mode test) and additional clusters with high member-count but zero intra-cluster wiki-links rejected by Signal 3. The dogfood wiki in this repo exhibits the same pattern: the `wiki-*` cluster (curator + digest + install + update + recall-subagent), which is the obvious wiki-maintenance module, would also be rejected. Detection was over-fit to the wrong definition of "module".

## Decision

Adopt John Ousterhout's *A Philosophy of Software Design* definition: a **Module** is a deep abstraction with a narrow interface and a rich implementation, hiding meaningful complexity behind a clear boundary. Detection signals and authoring flow are revised to serve that definition.

**Detection (in `/wiki-modules` skill body):**

- **S1 (unchanged)**: filename prefix ≥3 detail notes — bootstrap candidate generation only.
- **S2 (replaced)**: single-dominant-tag rule. PASS if every cluster member shares one common tag. The previous top-2 mode test rejected legitimate modules whose members specialize past a shared abstraction.
- **S3 (replaced)**: external fan-in concentration. PASS if ≥1 note outside the cluster links to ≥2 distinct cluster members. Information hiding measured by who *references* the module as a unit, not by who is inside it.

**Authoring (new `module-author` subagent):**

- `/wiki-modules` dispatches one `module-author` invocation per cluster passing all three signals.
- The subagent reads every candidate child in full and authors a complete MODULES note (Purpose, Boundary, Triggers, Storage, Behavior, Rules & Invariants, Children).
- A pre-author depth gate (≥3 children, combined word count above threshold, ≥2 distinct dominant tags across children, ≥1 child with trigger/entry-point keywords) prevents authoring against thin material.
- A post-author content gate (Purpose ≥50 words, Boundary lists ≥2 OUT items, Children ≥3 entries grouped under ≥2 categories) prevents shallow output from being committed.

**Ownership:**

- `/wiki-modules` is the sole writer to `wiki/MODULES/`. Every run re-authors every existing module from current cluster state — MODULES notes are idempotent outputs of the wiki, not user-editable content. Manual edits do not survive.
- The curator's Trigger 7 (implicit MODULES upgrade based on body shape during `/wiki-digest`) is removed from `wiki/Rules.md` §12 and from the curator protocol.
- The explicit `@ MODULES::slug` handle in `_session.md` is deprecated; the curator surfaces it as a `MODULES-VIA-DIGEST-DEPRECATED` plan row instead of writing.

## Consequences

- A brand-new module that nothing else in the wiki has cited yet will not auto-detect — accepted, and aligned with the Ousterhout reading that a module is known to the rest of the system.
- MODULES notes must not be hand-edited. The first line of every MODULES note should declare this contract; any user with a thoughtful Purpose paragraph should improve the children instead.
- Cross-prefix capabilities (a module spanning `auth-*` and `session-*`) are not detected by S1's prefix bootstrap. Accepted for now — the dataset showed no real-world examples; revisit if it surfaces.
- The structural ≥5-of-7 H2s deletion-test gate in the curator becomes vestigial for MODULES (curator no longer writes them); the pre/post depth gates in `/wiki-modules` replace it.

## Considered alternatives

- **Relax S2 to dominant-tag share ≥70%** — admitted near-misses but didn't change the fundamental definition. Rejected.
- **Drop S3 entirely** — relied on S1+S2 alone. Admitted generic-prefix collisions like `api-*`. Rejected.
- **Skill stays read-only, emits drafts the user pastes** — preserved the existing contract but kept the auto-docs anti-pattern (user authoring wiki content). Rejected.
- **Multi-path coexistence (curator + skill both write MODULES)** — simpler to ship but creates an overwrite footgun: a user typing a thoughtful module body into the inbox sees their work vanish on next `/wiki-modules`. Rejected.
- **Create-only with manual-edit preservation** — preserved user agency at the cost of a two-class system (auto vs manual modules) and stale auto modules whenever the cluster shifted. Rejected; auto-docs philosophy applies to all MODULES uniformly.
