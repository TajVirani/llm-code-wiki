# glab — Claude Code skill

A tactical playbook for driving [GitLab](https://gitlab.com) through the [`glab`](https://gitlab.com/gitlab-org/cli) CLI from inside Claude Code. Covers issues (list / view / create / update / comment / close), merge requests (same), board summarization (column-by-column recap or structured dump), and MR reviewing (line-anchored discussions, severity-tagged comments, verdict). Composes cleanly with the strategic issue-tracker skills like `to-issues`, `to-prd`, and `triage`, and bridges the built-in `/review` / `/security-review` slash commands to actual GitLab MR discussions — those decide *what* to write; this one knows *how* to call glab to actually post it.

## Install

Drop the `glab/` directory into your Claude Code skills root:

```sh
# Per-user (every Claude Code session sees it)
mkdir -p ~/.claude/skills
cp -r glab ~/.claude/skills/

# OR per-project (only when working in this repo)
mkdir -p <project>/.claude/skills
cp -r glab <project>/.claude/skills/
```

Open a new Claude Code session — the skill registers automatically and shows up in the available-skills list. No restart of the CLI, no plugin install command, no registry round-trip.

## Prerequisites

- `glab` CLI installed locally. Install: `brew install glab` (macOS), `sudo apt install glab` (Debian/Ubuntu), or grab a binary from the [glab releases page](https://gitlab.com/gitlab-org/cli/-/releases).
- Authenticated against your GitLab instance: `glab auth login`. Defaults to `gitlab.com`; pass `--hostname=<your-gitlab>` for self-hosted.
- A repo with a GitLab `origin` remote, or pass `--repo <group>/<project>` per-command.

Verify with `glab repo view` from a GitLab-backed working directory — should print the project metadata.

## What's inside

- [`SKILL.md`](./SKILL.md) — what Claude reads. The full CLI reference: issues, merge requests, project-conventions discovery, common pitfalls.
- [`BOARDS.md`](./BOARDS.md) — board summarization workflow. Walks the GitLab board API, two output flavors (chat recap vs. file dump), gotchas around hidden columns and group-level boards.
- [`REVIEW.md`](./REVIEW.md) — MR reviewing workflow. Bridges the built-in `/review` and `/security-review` chat output to line-anchored `glab mr note create` discussions, with a severity taxonomy, replay-safe posting, and the approve / request-changes / comment-only verdict.

## How to know it loaded

After installing, ask Claude something like "summarize the Planning 2.0 board" or "list open MRs" inside any Claude Code session. If the skill loaded, Claude will use the glab CLI directly; if it didn't, you'll likely get generic answers about GitLab without concrete commands.

You can also confirm by asking Claude to list available skills — `glab` should appear with its description.

## Related skills

- `to-issues` — break a plan/spec/PRD into independently-grabbable issues. Hands off to `glab` for the actual `glab issue create` call when the project is on GitLab.
- `to-prd` — turn current conversation context into a PRD on the issue tracker.
- `triage` — move issues through a state machine via label changes.
- `setup-matt-pocock-skills` — writes a CLAUDE.md / AGENTS.md block that tells the strategic skills above which CLI to use. Run this once per repo if those skills don't already know it's a GitLab project.

## License

MIT.
