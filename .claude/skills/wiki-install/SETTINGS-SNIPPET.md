# settings.json — Manual Fallback (Hooks + Default Permissions)

If `jq` is not installed and your project already has a `.claude/settings.json`, you can add the Stop hook, the UserPromptSubmit hook, and the default permissions manually.

## Default permissions to add

The auto-wiki capture path writes to `wiki/inbox/_session.md` after every Claude turn that produces a code change. To avoid a permission prompt on every write, add these to `.permissions.allow`:

```json
{
  "permissions": {
    "allow": [
      "Read(wiki/inbox/_session.md)",
      "Edit(wiki/inbox/_session.md)",
      "Write(wiki/inbox/_session.md)"
    ]
  }
}
```

If you already have `permissions.allow`, append the three entries (skip any that are already there). If you don't have a `permissions` key at all, add the full block alongside `hooks`.

## The hook entry to add

```json
{
  "type": "command",
  "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/inbox-stop.sh",
  "timeout": 10
}
```

## Where to add it

The entry goes inside `.hooks.Stop[0].hooks` — the array of hook commands for the Stop event.

### If your settings.json has no `hooks` key at all

Add the full structure:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/inbox-stop.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

### If your settings.json already has a `hooks.Stop[0].hooks` array

Append the entry to the existing array. Example — if you already have one hook:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "your-existing-hook.sh",
            "timeout": 30
          },
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/inbox-stop.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

## After adding the entry

Re-run `/wiki-install` — the skill will detect the `inbox-stop.sh` entry and skip the settings.json step, then continue with the remaining bootstrap steps.

## Why jq?

`jq` is a command-line JSON processor. Install it via:
- macOS: `brew install jq`
- Ubuntu/Debian: `sudo apt-get install jq`
- Windows (WSL): `sudo apt-get install jq`
- Other: https://jqlang.github.io/jq/download/
