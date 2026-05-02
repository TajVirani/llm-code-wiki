
**Summary**: The Stop hook script self-heals its runtime directory at startup so heartbeat, fire-counter, and kill-switch writes succeed on a fresh install.
**Tags**: #hook #install #robustness #architecture
**Created**: 2026-04-30T00:00:00+00:00
**Last Updated**: 2026-04-30T00:00:00+00:00

---

## Content

The Stop hook script `.claude/hooks/inbox-stop.sh` runs `mkdir -p .claude/inbox/` at startup. This guarantees that subsequent writes — heartbeat file, fire-counter, kill-switch sentinel — succeed even on a project that has never had the runtime directory created.

Without this self-heal, the `wiki-install` smoke test fails on any project that hasn't had the runtime directory pre-created elsewhere (because `inbox-stop.sh`'s first action would be a write into a nonexistent directory). The mitigation makes the hook resilient to install-order assumptions.

**Why it matters:** the install path is one of the highest-risk surfaces — first-run failures erode trust in the scaffold. A one-line `mkdir -p` removes a class of install-time bugs.

## Related Notes

- [[recall-path|Recall Path]]
