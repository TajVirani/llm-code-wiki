
**Summary**: Brainstorm-fallback capture fires every 10 turns by default (override via `LCW_BRAINSTORM_TURNS`), capped at 5 entries per fire, counter resets on real artifact captures.
**Tags**: #decision #brainstorm #hooks #research
**Created**: 2026-04-30T16:09:00+00:00
**Last Updated**: 2026-04-30T16:09:00+00:00

---

## Content

**Decision.** The brainstorm-fallback capture path runs every 10 consecutive code-free turns by default, configurable via the `LCW_BRAINSTORM_TURNS` environment variable.

**Why a fallback at all.** Pure design conversations produce no `Edit` / `Write` / `MultiEdit` artifacts, so the artifact-driven capture path no-ops every turn. Without a fallback, design decisions made in chat fall on the floor — never reaching `_session.md` and therefore never reaching `/wiki-digest`. The fallback closes that gap.

**Counter reset semantics.** The brainstorm counter resets to 0 whenever a *normal artifact-driven capture* fires. Each brainstorm window therefore starts fresh after any code change — avoiding redundant capture immediately after a real fire that already swept the recent state.

**Session keying.** The counter is keyed by `SESSION_ID`. A new session starts the count over automatically. State lives at `.claude/inbox/.turn-count` in the format `SESSION_ID COUNT`.

**Per-fire entry cap.** ≤5 new entries per fallback fire. This avoids overloading `_session.md` during long brainstorm runs where the model could otherwise dump 20+ entries in one sweep and drown out other state.

**Hard-cap interaction.** The Stop hook's hard cap of 2 fires per session+minute (D-03) was refactored to count only *actual fires*, not entry attempts. Without that fix, a long brainstorm in a single minute would consume the cap on noops and never reach the fallback fire.

**Override.** Set `LCW_BRAINSTORM_TURNS=N` in the environment to change the cadence. Non-integer or `<1` values are rejected and the hook falls back to the default of 10.

**Documented in.** `CLAUDE.md` under the "Auto-maintained wiki" section — the user-facing reference for the cadence and override knob.

## Related Notes

- [[inbox-stop-hook|Inbox Stop Hook]]
- [[inbox-update-skill|Inbox Update Skill]]
