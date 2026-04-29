<!-- GSD:project-start source:PROJECT.md -->
## Project

**llm-code-wiki**

A skill + hook scaffolding that makes Claude Code auto-maintain an Obsidian-style codebase wiki. A Stop hook nudges Claude to keep a session "inbox" file current as a state-of-the-world mirror of what's been built and decided; a digest sub-agent later reads the inbox and routes entries into properly-filed wiki notes per the wiki's `Rules.md`. Built for solo developers who want code documentation that stays current without manual upkeep.

**Core Value:** Code documentation stays current and coherent without manual upkeep — including correctly pruning entries when code is deleted or superseded within the same session.

### Constraints

- **Tech stack**: Claude Code skill format (markdown + frontmatter) and `settings.json` hook config — no separate runtime
- **Compatibility**: Must respect existing `wiki/Rules.md` without modification
- **Hook semantics**: Stop hook fires once per assistant turn boundary; cannot directly mutate state — must inject a prompt that Claude executes
- **Cost**: Inbox updates run on every turn; the update prompt must be cheap and avoid re-reading the entire inbox where possible
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

- **Stop hook** (not PostToolUse, not SessionEnd) for inbox upkeep nudges — confidence HIGH
- **Skills** (not raw `.claude/commands/`) for both inbox upkeep and digest — confidence HIGH
- **Custom sub-agent** under `.claude/agents/` invoked from a digest skill via `context: fork` — confidence HIGH
- **No JS/Python markdown library** for the digest path — `Read` + `Grep` + `Write` + frontmatter-aware prompting are sufficient, and adding parsers would force a Node/Python install on every consuming repo — confidence HIGH
- **Plain bash script** for the Stop hook backing process (POSIX `sh`, `jq` optional) — confidence HIGH
## Recommended Stack
### Core Technologies
| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Claude Code skill (`SKILL.md` + YAML frontmatter) | Agent Skills open standard, as implemented by current Claude Code | Instruction surface for both in-session inbox upkeep and digest workflow | Skills are the canonical, current way to package Claude playbooks. The docs explicitly state custom commands have been merged into skills (`.claude/commands/foo.md` and `.claude/skills/foo/SKILL.md` are equivalent), and skills add the supporting-files directory + invocation-control frontmatter we need. Skills auto-load by description, can be invoked as `/skill-name`, and can `context: fork` into a sub-agent. |
| Claude Code hook config in `.claude/settings.json` (Stop event, `command` handler) | Current Claude Code hook schema | Fires once after each assistant turn to inject the inbox-update prompt | `Stop` is the only event whose semantic is "the assistant just finished a turn." `PostToolUse` fires per tool call and would re-trigger many times within one logical turn; `SessionEnd` fires only at termination and would lose mid-session updates. A `command`-type hook script reads JSON on stdin and emits JSON on stdout — no daemon, no port. |
| Custom sub-agent in `.claude/agents/digest-router.md` | Current Claude Code subagent schema | Fresh-context worker that reads the inbox and routes entries into filed wiki notes per `Rules.md` | Sub-agents have their own context window and return only a summary, which is exactly the digest contract: "given inbox, produce filed notes, leave main session uncluttered." Sub-agents support `tools:` allowlist, `model:` selection, and `skills:` preload — perfect for handing it `Rules.md` knowledge without polluting the parent session. |
| POSIX shell (`sh`/`bash`) + `jq` (optional) for the Stop hook command | bash 4+, jq 1.6+ | Tiny shim that reads the Stop event JSON, checks `stop_hook_active`, and emits `additionalContext` JSON | Hook commands receive event JSON on stdin and write JSON to stdout. No language runtime is required. `jq` makes JSON manipulation trivial; if absent, a 20-line bash heredoc works. Critically: `bash` is universal on macOS/Linux dev boxes; users on Windows already need WSL or Git Bash for Claude Code anyway. |
| Markdown + YAML frontmatter (Obsidian-flavored) | CommonMark + YAML 1.2 + Obsidian wikilinks | Note storage format on disk | Already locked by `wiki/Rules.md`. The wiki uses Obsidian wikilink syntax `[[Note Title]]` (display-title, not filename) and a fixed-shape header (Summary / Tags / Created / Last Updated / `---` separator / `## Content` / `## Related Notes`). The digest sub-agent must produce this shape exactly. |
### Supporting "Libraries" (really, file conventions)
| "Library" | Purpose | When to Use |
|-----------|---------|-------------|
| Skill `argument-hint` + `arguments:` frontmatter | Declare positional args for `/digest-wiki [path]` style invocations | When the digest skill needs to accept an optional alternative inbox path; otherwise omit. |
| Skill `allowed-tools:` frontmatter | Pre-approve `Read Write Glob Grep` (and nothing else) for the digest skill | Always — pre-approval prevents permission prompts during a digest run, which would defeat the unattended ergonomics. |
| Skill `disable-model-invocation: true` | Block Claude from spontaneously running the digest mid-session | Apply to the digest skill only. The inbox-upkeep skill is the opposite — it should be model-invocable so the Stop hook can request it by name. |
| Skill `context: fork` + `agent: digest-router` | Run the digest skill body as the prompt for a forked sub-agent | Apply to the digest skill so that calling `/digest-wiki` automatically spawns the sub-agent in an isolated context with `digest-router`'s tool restrictions and skill preloads. |
| Sub-agent `skills:` preload (e.g. `wiki-rules`) | Inject `Rules.md` as a preloaded skill so the sub-agent has the contract from turn 1 | The digest router needs `Rules.md` knowledge before it sees the inbox. A `wiki-rules` skill (with `user-invocable: false` and `disable-model-invocation: false`) is the cleanest way to package the Rules contract for preload. |
| Hook `additionalContext` field in `hookSpecificOutput` | Inject the inbox-update prompt into Claude's next turn without sending a user message | This is the documented Stop-hook injection mechanism. We do **not** use top-level `decision: "block"` because that creates a forced-continuation state we'd then have to manage with `stop_hook_active` checks. |
| `${CLAUDE_SKILL_DIR}` substitution | Reference scripts bundled inside the skill directory regardless of cwd | Use when the inbox-upkeep skill's instructions need to point at a helper template (e.g., the canonical entry shape) shipped in the skill folder. |
### Development Tools
| Tool | Purpose | Notes |
|------|---------|-------|
| `claude` CLI in `--add-dir` / direct project mode | Hand-test skills and hooks in this repo against the `wiki/` fixture | Live change detection picks up `.claude/skills/` and `.claude/agents/` edits without restart, but adding a top-level `.claude/skills/` dir that didn't exist at session start requires a restart. Plan first dev session to start *after* skeleton is scaffolded. |
| `/agents` interactive command | Inspect / edit sub-agent definitions, see which scope is winning when names overlap | Useful for the install-into-other-repo flow: confirm `digest-router` from `.claude/agents/` overrides any user-level definition with the same name. |
| `claude agents` CLI subcommand | List agents grouped by source non-interactively | Use in install-verification scripts. |
| Built-in `/init` and `/security-review` skills | Sanity-check the produced project layout before shipping | They're available via the Skill tool by default. |
| `jq` (recommended) | Parse Stop hook stdin JSON in the hook script | Optional — pure bash works for the few fields we need (`stop_hook_active`). |
### Specifically NOT in the stack
| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `gray-matter` / `js-yaml` / `python-frontmatter` | Adds a Node or Python dependency to every repo this scaffolding ships into. The digest sub-agent already has `Read`/`Grep`/`Write`; it can read frontmatter as text and write the canonical template byte-for-byte from a known-shape string. | Treat frontmatter as a fixed-shape text block in the `_templates/note.md` template; have the sub-agent fill in fields by string substitution, not parsing. |
| `remark` / `unified` / `markdown-it` AST pipelines | Same dependency-bloat objection. Also: the digest task is "produce well-formed markdown that matches `Rules.md`," not "parse arbitrary markdown" — the model is the parser. | Prompt-driven generation against the template; rely on `Rules.md` as the schema spec. |
| `obsidian-export` / Dataview / community plugins | Out of scope. We write markdown that Obsidian can *read* — we don't need Obsidian's runtime. | Plain markdown + `[[Title]]` links + the existing template. |
| `PostToolUse` hook for inbox updates | Fires per tool call. A single user request that runs Read → Edit → Bash → Write would trigger 4 inbox updates and produce churn. | `Stop` hook — fires once per assistant turn boundary, which is the unit of "logical work" we want to summarize. (Confidence: HIGH — explicitly aligned with the locked decision in `PROJECT.md`.) |
| `SessionEnd` hook for inbox updates | Fires only when the session terminates. Sessions can run hours and span many features; an end-of-session-only update loses everything mid-session. | `Stop` hook for live updates; the digest is the manual checkpoint. |
| Top-level `decision: "block"` in Stop hook output | Forces Claude to continue, which creates a `stop_hook_active: true` follow-up turn that the hook script must detect to avoid an infinite loop. Documented bug history (anthropics/claude-code#3573, #10205) shows this pattern is loop-prone. | Use `hookSpecificOutput.additionalContext` instead. It injects the upkeep prompt into the *next* user turn without forcing immediate continuation, so there's no loop risk and no `stop_hook_active` state machine to manage. |
| Raw `.claude/commands/foo.md` for the digest entry point | Still works, but skills supersede commands and add the supporting-files directory we want for templates and helper docs. The docs explicitly recommend skills going forward. | `.claude/skills/digest-wiki/SKILL.md` (and the same `/digest-wiki` invocation works). |
| Letting the digest run in the main conversation | Reading the entire wiki + inbox + writing many files would flood the parent context. | `context: fork` → sub-agent. The summary returns; the file-mutation work stays out of the main thread. |
| Embedding wiki rules inline in the digest skill body | Duplicates `wiki/Rules.md`, drifts. Also, sub-agent system prompt + skill body have a token budget; a 200-line rules block bloats every spawn. | Preload a `wiki-rules` skill into the sub-agent via the `skills:` field. Skill content is injected at sub-agent startup and is the documented mechanism for this. |
## Layout (the actual files we ship)
## Concrete Configuration Sketches
### `.claude/settings.json` — Stop hook registration
- Stop hooks have no matcher field — they always fire on every `Stop` event.
- We use `$CLAUDE_PROJECT_DIR` so the script works regardless of where the user invoked Claude from inside the repo.
- A 10-second timeout is generous for the trivial bash work; the actual *inbox edit* happens on Claude's next turn, not inside the hook.
### `.claude/hooks/inbox-upkeep.sh` — the shim
#!/usr/bin/env bash
# Read Stop event JSON from stdin
# If we're in a forced-continuation cycle, do nothing (defensive — we don't use
# decision:"block", but this guards against future config drift).
# Emit additionalContext to nudge Claude on its next turn.
### `.claude/skills/inbox-upkeep/SKILL.md` — in-session skill
# (body: atomic entries, flat structure, self-pruning rules, etc.)
### `.claude/skills/digest-wiki/SKILL.md` — manual digest entry point
### `.claude/agents/digest-router.md` — the sub-agent
### `.claude/skills/wiki-rules/SKILL.md` — the contract carrier
# (body: a verbatim or near-verbatim copy of wiki/Rules.md, kept in sync)
## Alternatives Considered
| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Stop hook with `additionalContext` injection | `UserPromptSubmit` hook that prepends instructions to the user's next message | If we wanted updates *before* Claude reads the user's intent rather than after the model finishes a turn. We don't — the model needs to know what *it* did this turn, which is only available at Stop. |
| Skill with `context: fork` for the digest entry point | Plain skill that calls the sub-agent via the Agent tool from the parent context | If we wanted the parent to keep observing partial progress. We don't — clean isolation is the whole point. |
| Custom `digest-router` sub-agent | Built-in `general-purpose` sub-agent | If we wanted to skip writing an agent file. Downside: no tool allowlist, no skill preload — Rules.md would have to be re-injected each spawn via the skill body, bloating tokens. |
| Sub-agent `skills:` preload for Rules.md | Inline `Rules.md` text in the digest skill body | If `Rules.md` were tiny (<50 lines). It isn't, and it lives in the user's wiki — preloading via a mirrored skill is more honest about the source-of-truth relationship. |
| POSIX bash for the hook shim | Node script (`#!/usr/bin/env node`) | If we needed structured JSON manipulation beyond reading one boolean. We don't, and the bash version doesn't add a runtime dependency on the consumer repo. |
| Manual `/digest-wiki` trigger | Auto-digest at session-end via `SessionEnd` hook | If users wanted hands-off digest. Out of scope per `PROJECT.md`. The manual trigger gives a review checkpoint, which is the explicit design goal. |
## Stack Patterns by Variant
- Drop in the full `.claude/` tree above
- The first `claude` session in that repo will pick up everything (skills are live-watched once the directory exists at session start)
- Merge the `hooks.Stop` array entry rather than replacing the file
- Skills and agents are additive (separate directories) — no merge needed
- Watch for name collisions: if they have a skill named `digest-wiki` already, project scope wins by precedence — install docs must call this out
- The Stop hook still fires when the assistant finishes a plan-mode turn, but the upkeep skill should detect plan-mode (no file changes occurred) and skip the inbox update or write a "planning notes" entry instead. This is a skill-body concern, not a hook-config concern.
- Document a `WIKI_DIR` convention or skill argument; the in-session skill needs to know where to write. v1 assumes `wiki/` at repo root per `PROJECT.md`.
## Version Compatibility
| Component | Required | Notes |
|-----------|----------|-------|
| Claude Code CLI | Recent (skills + sub-agents merged-commands era) | The `.claude/commands/` → `.claude/skills/` merge is documented as "your existing files keep working," but skill features (supporting files, `context: fork`, sub-agent `skills:` preload) require the current generation. |
| Hook schema | Current (supports `hookSpecificOutput.additionalContext`) | Older hook schemas without `additionalContext` would force us into the `decision: "block"` pattern, which has documented loop hazards. |
| Sub-agent schema | Current (supports `skills:` field) | Required for preloading `wiki-rules` into `digest-router`. Without it, we'd have to inline rules into the agent system prompt. |
| Obsidian | N/A on the producing side | We write Obsidian-compatible markdown; Obsidian itself is the consumer's reader. No version constraint on our side. |
## Confidence Assessment
| Area | Confidence | Why |
|------|------------|-----|
| Skill format & frontmatter | HIGH | Verified directly against `code.claude.com/docs/en/skills` (April 2026) — full frontmatter table, `context: fork`, supporting files, invocation-control fields all confirmed. |
| Hook event types & schema | HIGH | Verified directly against `code.claude.com/docs/en/hooks`. Stop event semantics, `command`-type handlers, stdin JSON shape, and `hookSpecificOutput.additionalContext` all confirmed. |
| Stop-hook loop semantics | HIGH | Confirmed via official docs + multiple community sources documenting `stop_hook_active` as the safety-bit that user code must check when using `decision: "block"`. Our chosen pattern (`additionalContext` instead of `block`) sidesteps the loop class entirely; we still defensively check `stop_hook_active` in the shim. |
| Sub-agent format & `skills:` preload | HIGH | Verified directly against `code.claude.com/docs/en/sub-agents`. The `skills:` field, the difference between "sub-agent loads skills" vs "skill forks into sub-agent," and the `context: fork` ↔ `skills:` symmetry are all explicitly documented. |
| Slash-commands path | HIGH | Verified: commands and skills have been merged. `.claude/commands/foo.md` and `.claude/skills/foo/SKILL.md` both produce `/foo`. We pick skills for the supporting-files directory and frontmatter feature set. |
| Obsidian wikilink syntax | HIGH | `[[Title]]` and `[[Title|Display]]` (pipe alias) are standard. `Rules.md` mandates display-title form, no aliases — we follow it. |
| "Don't add a markdown parser" call | MEDIUM-HIGH | Reasoned, not citation-backed: the digest sub-agent has Read/Write/Grep and the canonical template; introducing `gray-matter` etc. only adds dependency burden on every consuming repo. Worth a sanity check during the first digest-correctness phase — if prompt-driven frontmatter generation drifts, we revisit. |
## Sources
- [Claude Code — Skills reference](https://code.claude.com/docs/en/skills) — verified frontmatter fields (`name`, `description`, `disable-model-invocation`, `user-invocable`, `allowed-tools`, `context: fork`, `agent`, `skills`-via-preload-on-subagent), `.claude/skills/` location, supporting-files convention, commands→skills merge, `${CLAUDE_SKILL_DIR}` and `$ARGUMENTS` substitution.
- [Claude Code — Hooks reference](https://code.claude.com/docs/en/hooks) — verified Stop event firing semantics, `command`-type handler stdin JSON (session_id, transcript_path, hook_event_name, etc.), output JSON shape (`continue`, `decision`, `hookSpecificOutput.additionalContext`, `systemMessage`), `$CLAUDE_PROJECT_DIR` env var, settings.json `hooks` schema with `matcher` and `timeout`.
- [Claude Code — Sub-agents reference](https://code.claude.com/docs/en/sub-agents) — verified `.claude/agents/` location, full frontmatter (`name`, `description`, `tools`, `disallowedTools`, `model`, `skills`, `mcpServers`, `hooks`, `permissionMode`, `isolation`, `memory`), Task→Agent rename, `skills:` preload semantics, fork vs named-subagent comparison.
- [GitHub anthropics/claude-code#3573](https://github.com/anthropics/claude-code/issues/3573) — Stop hook infinite-loop hazard when failing with `blocking: true`. Informs the choice to use `additionalContext` over `decision: "block"`.
- [GitHub anthropics/claude-code#10205](https://github.com/anthropics/claude-code/issues/10205) — Hooks-related infinite-loop report; further support for the conservative Stop-hook pattern.
- [Claude Code Stop Hook: Force Task Completion (claudefa.st)](https://claudefa.st/blog/tools/hooks/stop-hook-task-enforcement) — third-party walkthrough of the `stop_hook_active` field's loop-prevention role.
- [Obsidian Help — Aliases / wikilinks](https://help.obsidian.md/Linking+notes+and+files/Aliases) — `[[Note]]` and `[[Note|Display]]` syntax confirmed; `Rules.md` mandates display-title form.
- Project-internal: `/mnt/f/Projects/llm-code-wiki/.planning/PROJECT.md`, `/mnt/f/Projects/llm-code-wiki/wiki/Rules.md`, `/mnt/f/Projects/llm-code-wiki/wiki/_templates/note.md`.
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
