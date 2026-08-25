# Reviewing merge requests

The built-in `/review` and `/security-review` slash commands ship inside the Claude Code binary. They produce review *content* as chat output but know nothing about `glab` — they don't anchor comments to files/lines, don't resolve threads, and don't cast an approval verdict. This file is the bridge: how to turn a review pass (built-in-generated or composed from scratch) into actual GitLab MR discussions, then close out with approve / request-changes / comment-only.

## Workflows

Two entry points:

1. **Reviewing an MR you didn't write.** User says "review !104" or "look at this MR". Pull context → compose review (optionally via `/review` or `/security-review`) → post → verdict.
2. **Reviewing your own draft before flipping it out of draft.** Same mechanics, but the verdict step is usually `glab mr update --ready` instead of `approve`.

## 1. Pull MR context

Fetch everything the reviewer needs in one batch — these are independent, so run them in parallel.

```sh
glab mr view <iid> -O json                  # title, description, state, labels, draft flag, source/target branches
glab mr diff <iid>                          # unified diff (latest version)
glab mr note list <iid> -F json             # existing discussions — read before posting to avoid duplicates
```

Watch out: `glab mr note list` uses `-F json` (the experimental subcommand inherits the `gh`-style flag), but the stable `glab mr view` uses `-O json`. Don't paste one into the other.

If the MR has many revisions and you need to anchor on something other than the current head:

```sh
glab api "projects/<group>%2F<repo>/merge_requests/<iid>/versions"
```

Returns the SHA triple (`base_sha` / `start_sha` / `head_sha`) needed to anchor a comment to a specific revision. The default `glab mr note create --file` targets the latest version, which is what you almost always want.

## 2. Compose the review

### Severity taxonomy

Tag every comment with a severity prefix so the author can triage at a glance:

- **blocking** — must change before merge (correctness bug, security issue, broken contract).
- **suggestion** — worth doing, but author's call (clearer name, better factoring, missing test).
- **nit** — purely stylistic; ignore if pressed for time.
- **question** — not a request, just trying to understand. Resolving without a code change is fine.

Lead each comment body with the severity in bold: `**blocking:** …`, `**nit:** …`. Reviewers without this taxonomy force the author to guess which comments are merge-blockers — that's the most common review-process failure.

### Tone

Customer preference (see memory `feedback_mr_review_tone`): keep comments short, but soften the imperative. "Consider extracting X" beats "Extract X". The author is a teammate; the comment is a suggestion, not a directive — even blocking ones can be phrased as "this needs to change because Y" rather than "change this".

### Pass order

Work top-down by importance so you can stop early if you hit a structural problem:

1. **Does it do what the MR description says?** If summary and diff don't match, that's the first comment — no point reviewing further.
2. **Correctness** — bugs, race conditions, off-by-one, error handling at boundaries, breaking changes to existing contracts.
3. **Security** (run `/security-review` for a dedicated pass on anything touching auth, input handling, secrets, or external surfaces).
4. **Tests** — does the new behaviour have a test? Are existing tests still meaningful or were they neutered to pass?
5. **Readability / naming / structure** — only if the above are clean.
6. **Nits** — last, and skip entirely on a busy day.

## 3. Post the review

### Line-anchored comment (start a new discussion)

```sh
glab mr note create <iid> \
  --file path/to/file.ts \
  --line 42 \
  -m "**blocking:** This dereferences \`user\` before the null-check on line 40. Consider \`user?.id\` or moving the check above."
```

Multi-line range: `--line 10:15` highlights lines 10 through 15.

Comment on a *removed* line (old side of the diff): `--old-line 7` instead of `--line 7`. Don't combine with `--line`.

File-level comment (whole file, no specific line): `--file path/to/file.ts` with no `--line`.

### Top-level MR comment (not anchored to the diff)

```sh
glab mr note create <iid> -m "Overall: this looks like the right approach. A couple of blocking comments inline."
```

Use this for the review summary at the start — the verdict-style note that orients the author before they read inline comments.

### Reply to an existing thread

```sh
glab mr note create <iid> --reply <8+ char discussion id prefix> -m "Right — that addresses my concern."
```

Discussion IDs come from `glab mr note list <iid> -F json` (`.[].id`). An 8-character prefix is enough.

### Resolve / unresolve a thread

```sh
glab mr note resolve <discussion-id-or-prefix> <iid>
glab mr note reopen  <discussion-id-or-prefix> <iid>
```

Either a 40-char hex discussion ID or a note ID works. Reopen if the author "fixed" something but the fix didn't address the root concern.

### Idempotent posting (replay-safe)

`--unique` skips posting if a note with the identical body already exists on the MR. Useful when re-running a `/review` pass after the author pushes a new commit — only the *new* findings post; previously-posted ones get skipped automatically.

```sh
glab mr note create <iid> --file foo.ts --line 42 -m "..." --unique
```

Caveat: `--unique` only checks identical body strings. A reworded comment will post again. Keep severity prefixes consistent so dedup works.

## 4. Verdict

After posting comments, cast the merge verdict. Three options:

```sh
# Approve — green-light the MR. Other approvals may still be required.
glab mr approve <iid>

# Request changes — there isn't a "request changes" verb in glab; the convention is
# to mark the MR as draft, which prevents merge until the author flips it back.
glab mr update <iid> --draft

# Comment-only — leave thoughts, don't approve. No verb needed; just post comments.
```

If you previously approved and now want to walk it back: `glab mr revoke <iid>`.

## 5. Posting a built-in /review output to an MR

The built-in `/review` emits a structured-ish markdown block in chat. Treat it as raw input that needs to be split into discrete comments. Workflow:

1. Run `/review` (or `/security-review`) — get the chat-output review.
2. **Read it critically** — the built-in reviewers don't know this codebase's conventions. Drop comments that don't apply. The point is to use them as a *first draft*, not a transcript.
3. For each finding worth posting, classify severity (blocking / suggestion / nit / question) and rewrite the body in the tone described above.
4. Identify the file+line for each — the built-in usually names them, but verify against the actual diff.
5. Post each as a separate `glab mr note create --file <f> --line <n> -m "..."` invocation. Use `--unique` if there's any chance of replay.
6. Optionally post a top-level summary note that gives the author the gist before they dig into inline comments.
7. Verdict.

Don't paste the entire `/review` output as a single top-level note — that's the failure mode this whole flow exists to prevent. Inline comments per finding are the deliverable.

## Pitfalls

- **`-F json` vs. `-O json`.** Stable subcommands (`glab mr view`, `glab issue view`, `glab issue list`) use `-O json`. The experimental `glab mr note list` uses `-F json`. They're not interchangeable.
- **`--unique` is a literal-body match.** Whitespace differences, edited wording, or appending "(updated)" will defeat it. Keep bodies stable across replays.
- **`--file --line` only targets the latest diff version.** If the author force-pushes mid-review, anchored comments may end up on a different line than intended. Re-fetch the diff before a second pass.
- **Approve operates on the current branch by default** if no `<iid>` is given. When reviewing someone else's MR, always pass the iid explicitly — don't rely on the current checkout.
- **No "request changes" verb.** Setting `--draft` is the GitLab convention, but the author may not realise the draft flag means "reviewer wants changes" vs. "I'm still working on this". Pair it with an explanatory top-level note.
- **Self-approval is project-specific.** Some GitLab projects disallow approving your own MR; the call will return an error rather than silently no-op. Read the project's approval rules before assuming `glab mr approve` works on a draft you authored.
- **`glab mr note` (parent command) without `create` posts a top-level comment.** That's the legacy non-experimental path — it works fine for top-level notes but lacks `--file`/`--line`/`--reply`. Use `glab mr note create` explicitly when in doubt.
