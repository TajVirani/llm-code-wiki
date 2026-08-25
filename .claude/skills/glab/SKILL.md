---
name: glab
description: Interact with GitLab via the `glab` CLI — list / view / create / update / comment on issues and merge requests, plus summarize board views. Use when the user wants to work with GitLab issues, MRs, boards, or any task that mentions `glab`, GitLab, or a project hosted on gitlab.com / a self-hosted GitLab. This is the tactical "how to call glab" companion to strategic issue-tracker skills (`to-issues`, `to-prd`, `triage`).

---

# glab

Tactical playbook for the `glab` CLI. The agent composes calls itself — this skill documents which subcommand does what, important flags, and common traps.

For **board summarization** (recap a column-by-column view of a project's board), see [BOARDS.md](./BOARDS.md).

For **MR reviewing** (turn a `/review` or `/security-review` pass into line-anchored GitLab discussions, plus the approve / request-changes / comment-only verdict), see [REVIEW.md](./REVIEW.md).

## See also

- `to-issues` — break a plan into issues using vertical slices (calls into this skill for the actual `glab issue create`).
- `to-prd` — turn current context into a PRD on the issue tracker.
- `triage` — move issues through a state machine via label changes.
- `setup-matt-pocock-skills` — writes the `## Agent skills` block in CLAUDE.md so the strategic skills know to call `glab` (vs. `gh`, vs. local markdown).

## Quick start

```sh
glab repo view             # confirm which project glab is pointed at
glab issue list            # open issues, most recent first
glab mr list               # open MRs
glab issue view 42         # issue body + metadata
glab mr view 104 --comments # MR with discussion
glab mr diff 104           # unified diff
```

If the user names a project that differs from the current repo, scope per-command with `--repo group/project`.

## Issues

```sh
# List / search
glab issue list                                     # open, default sort
glab issue list --closed --per-page=20              # `-c` short form also works
glab issue list --label=Review --label="High Priority"   # AND
glab issue list --search="<query>"                  # title/body substring
glab issue list --assignee=<username>

# View
glab issue view 42
glab issue view 42 --comments
glab issue view 42 -O json                          # parseable; --output json is the long form

# Create — always HEREDOC the description (see Pitfalls)
glab issue create \
  --title "Short imperative title" \
  --description "$(cat <<'EOF'
Multi-line body with markdown.
EOF
)" \
  --label "Label A" --label "Label B"

# Update / comment / close
glab issue update 42 --description "$(cat <<'EOF' ... EOF)"   # full replace
glab issue update 42 --label Foo --unlabel Bar
glab issue note 42 -m "comment body"
glab issue note 42 -m "fixed by !104" && glab issue close 42   # close-with-comment = note then close (no --comment flag)
glab issue reopen 42
```

## Merge requests

```sh
# List / view
glab mr list
glab mr list --merged --per-page=10                 # also: --closed, --all
glab mr view 104 --comments
glab mr view 104 -O json
glab mr diff 104                                    # unified diff

# Create — push the branch first
git push -u origin <branch>
glab mr create \
  --title "<type>(<scope>): <description>" \
  --description "$(cat <<'EOF'
## Summary
...
## Test plan
- [ ] ...
EOF
)" \
  --source-branch <branch> \
  --target-branch main \
  --remove-source-branch    # delete branch on merge

# Update / approve / merge
glab mr update 104 --description "..."              # full replace
glab mr note 104 -m "comment"
glab mr approve 104
glab mr merge 104 --squash --remove-source-branch
glab mr close 104
```

## Discovering project conventions

`glab` is generic; each project layers conventions on top (title suffixes that map to board columns, label vocabularies, MR template sections, branch naming, attribution trailers). Before the first issue/MR on a new project:

1. Read `CLAUDE.md` / `AGENTS.md` for project rules — `setup-matt-pocock-skills` writes the issue-tracker contract there.
2. Skim recent items: `glab issue list --per-page=5` and `glab mr list --per-page=5`, then `view` one or two to pick up title shape, label set, description sections.
3. Check `~/.claude` memory if the user has worked with the project before.
4. If still unsure, ask before creating.

## Pitfalls

- **`glab` ≠ `gh` flag conventions.** Common drift points: JSON output is `-O json` / `--output json` on glab (not `-F json`); state filters are `--closed` / `--opened` / `--merged` / `--all` as standalone bool flags (not `--state=closed`); `glab issue close` has no `--comment` flag (use `glab issue note` then `glab issue close`). When in doubt, `glab <cmd> --help` — every subcommand documents its own flags.
- **Multi-line strings: HEREDOC.** `--description "line1\nline2"` does NOT interpret `\n` — the literal backslash-n lands in the body. Use `"$(cat <<'EOF' … EOF)"` with the **single-quoted** `EOF` to suppress shell interpolation.
- **Label filters are AND, not OR.** `--label=A --label=B` requires both. For OR, run separate queries and merge.
- **`glab api` paths need URL-encoding.** `projects/group/repo` won't work; use `projects/group%2Frepo`.
- **Issue IDs vs. work-item IDs.** Some glab versions print issue links as `/-/work_items/<id>` (the new GitLab work-items system). The numeric ID still works with `glab issue view <id>`.
- **`glab mr create` without a pushed branch fails.** Push first; `-u origin <branch>` also sets upstream tracking.
- **Force-pushing after MR creation is OK** — GitLab updates the diff automatically. Use `--force-with-lease` to guard against overwriting unseen remote commits.
- **`--repo` flag is per-command.** No persistent context across calls. If working across projects in one session, every command needs `--repo` or a `cd`.
