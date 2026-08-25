# Board summarization

GitLab boards are project-scoped (sometimes group-scoped). Each board has ordered **lists** (columns), and each list is tied to a **label** — an issue is in that column iff it carries the label. To summarize a board, you walk its lists and aggregate the issues per label.

## 1. Find the board

```sh
# URL-encode the namespace slash with %2F.
glab api "projects/<group>%2F<project>/boards"
```

Returns a JSON array of boards, each with:
- `name` — display name (e.g. "Development", "Planning 2.0")
- `lists` — ordered array of `{ id, label: { name, color }, position }`

The board's column order = the order of `lists`. Some boards hide the implicit Backlog / Closed columns; those entries appear with `hide_backlog_list: true` / `hide_closed_list: true` at the board level — re-add them to the recap when present.

If the user names a board ("the Planning 2.0 board"), match case-insensitively against `name`. If they don't specify, list boards and ask which one.

## 2. Pull issues per column

For each list, query issues with that label. The fastest path:

```sh
glab issue list --label="<label-name>" --per-page=100 -O json
```

`-O json` (or `--output json`) returns parseable rows with `iid` (issue number), `title`, `labels`, `assignees`, `state`, `web_url`. Be aware:
- An issue can carry multiple board labels and show in multiple columns. Many boards use mutually-exclusive labels by convention; verify before deduping.
- `--per-page=100` is the cap. Boards with > 100 issues per column need `--page=2`, `--page=3`, etc. (glab doesn't auto-paginate.)
- For closed columns, add `--closed`. Default is open-only. Some projects keep "Done" issues *open* with a Done label rather than closing — count both `--label=Done` and `--label=Done --closed` to be safe.

## 3. Two output flavors

The skill defaults to **recap**. Switch to **dump** when the user asks for a file, snapshot, or handoff artifact.

### Recap (default)

Print a column-by-column summary in the chat. Format:

```
**<Board name>** — <total open across columns> open

  Critical (3)
    • #142  Auth service 500s under load — @alex
    • #137  Drop legacy /v1 endpoint — @sam
    • #133  Patch leaked secret in CI — @sam

  In Progress (2)
    • #145  Per-client validate-and-replay  — @jfay
    • #144  Temporal queries fix            — @jfay

  Review (5)  +2 more not shown
    • #146  …
    …

  Backlog (28)  — 28 items, run `glab issue list --label=Backlog` to inspect
```

Heuristics:
- Show every issue for short columns (≤ 5).
- For longer columns: top 3–5 by recency or by a priority label if one exists, then `… +N more not shown`.
- Default to summarizing only **open** issues. Mention Done/Closed columns by count unless the user asks for content.
- Highlight Critical / Blocked columns first regardless of board order — they're the user's likely interest.

### Dump (file artifact)

Write a markdown table or JSON file. Triggers: user names a file path, says "snapshot", "dump", "export", "save", or asks for handoff material.

Default file name: `BOARD-<board-slug>-<YYYY-MM-DD>.md` in the repo root unless the user names a path.

Suggested markdown shape (one section per column, full issue list, no truncation):

```md
# <Board name> — snapshot <YYYY-MM-DD>

## <Column 1> (N)
| # | Title | Assignee | Labels |
|---|---|---|---|
| [42](https://…) | … | @alex | label-a, label-b |
…

## <Column 2> (N)
…
```

For JSON output (when the user wants programmatic consumption): one top-level array of columns; each column has `name`, `label`, `count`, `issues: [{ iid, title, web_url, assignees, labels, state }]`.

## 4. Common gotchas

- **Boards aren't always project-scoped.** A group-level board lives at `groups/<group>/boards`. If `projects/...%2F.../boards` returns nothing or 404, try the group endpoint.
- **Hidden columns drift.** `hide_backlog_list` / `hide_closed_list` mean the column exists conceptually but isn't shown. Recap should still account for the issues that would have lived there (issues with no list label end up in implicit Backlog).
- **Closed column counts grow forever.** Don't fetch closed issues without `--closed` and a sensible cap; a year-old project will return thousands.
- **The label that names a list isn't necessarily the only label on its issues.** When showing an issue in column X, don't list "X" in the label column of the dump — it's redundant noise. Filter out the list-label before displaying.
- **Cross-column duplication.** If two columns share an issue (multiple board labels on one issue), call it out in the recap so the user notices the inconsistency rather than counting twice silently.

## 5. Worked example

```sh
# 1. Find the board.
$ glab api "projects/mygroup%2Fmyrepo/boards"
[ ... "name": "Planning 2.0", "lists": [
    { "label": { "name": "Backlog" } },
    { "label": { "name": "High Priority" } },
    { "label": { "name": "In Progress" } },
    { "label": { "name": "Review" } },
    { "label": { "name": "Done" } }
  ] ...
]

# 2. Walk the lists.
$ for label in "High Priority" "In Progress" "Review"; do
    safe=$(echo "$label" | tr ' ' '_')   # spaces are awkward in filenames
    glab issue list --label="$label" --per-page=100 -O json > "/tmp/board-$safe.json"
  done

# 3. Render the recap from the JSON files (in-context, no script needed).
```

For a richer programmatic walk, `glab api "projects/<id>/boards/<board_id>/lists/<list_id>/issues"` returns each list's issues directly without re-querying by label — useful when label names contain spaces or other shell-awkward characters.
