---
name: wiki-update
description: Pull upstream improvements into an existing llm-code-wiki install. Compares the locally-stamped version against upstream VERSION, shows the changelog, fetches updated .claude/ files (skills, agents, hooks), re-merges .claude/settings.json without clobbering user hooks, refreshes the Auto-maintained wiki section in CLAUDE.md, and leaves wiki/Rules.md, wiki/_templates/, wiki/topic-index.md untouched. Idempotent — re-running on the same version is a no-op.
disable-model-invocation: true
user-invocable: true
argument-hint: [optional raw-base URL for a fork or branch]
allowed-tools: Read, Write, Edit, Glob, Bash
---

# /wiki-update — Upgrade an existing install

Run this slash command to pull the latest llm-code-wiki scaffold into a project that previously installed it via `/wiki-install`. Every step is idempotent and read-then-write — re-running on the same upstream version is a no-op.

The optional argument lets you point at a fork or branch:

```
/wiki-update                                              # default upstream
/wiki-update https://raw.githubusercontent.com/<O>/<R>/<B>   # fork or branch
```

If the user passed an argument, treat it as `RAW_BASE` for every `curl` below. Otherwise use the default at Step 0.

## Step 0 — Precondition + RAW_BASE

Verify the scaffold is already installed (proxy check: the `wiki-install` skill exists). If not, abort — `/wiki-update` is for upgrading, not installing.

```bash
test -f "$CLAUDE_PROJECT_DIR/.claude/skills/wiki-install/SKILL.md" || {
  echo "[wiki-update] ABORT: scaffold not installed (no .claude/skills/wiki-install/SKILL.md found)."
  echo "[wiki-update] Run /wiki-install first; /wiki-update only upgrades an existing install."
  exit 1
}
```

Determine `RAW_BASE`:

```bash
RAW_BASE_DEFAULT="https://raw.githubusercontent.com/TajVirani/llm-code-wiki/main"
RAW_BASE="${RAW_BASE:-$RAW_BASE_DEFAULT}"
```

If the user invoked `/wiki-update <URL>`, set `RAW_BASE="<URL>"` before running the bash block. Strip any trailing slash. Print the resolved upstream:

```bash
RAW_BASE="${RAW_BASE%/}"
echo "[wiki-update] Upstream: $RAW_BASE"
```

## Step 1 — Determine local + upstream versions

**Local version:**

```bash
LOCAL_VERSION_FILE="$CLAUDE_PROJECT_DIR/.claude/llm-code-wiki.version"
if [ -f "$LOCAL_VERSION_FILE" ]; then
  LOCAL_VERSION="$(tr -d '[:space:]' < "$LOCAL_VERSION_FILE")"
else
  LOCAL_VERSION="0.0.0"
  echo "[wiki-update] No local version stamp found — treating as 0.0.0 (full update)."
fi
echo "[wiki-update] Local version:    $LOCAL_VERSION"
```

**Upstream version:**

```bash
UPSTREAM_VERSION_FILE=$(mktemp)
if ! curl -fsSL "$RAW_BASE/VERSION" -o "$UPSTREAM_VERSION_FILE"; then
  echo "[wiki-update] ABORT: failed to fetch $RAW_BASE/VERSION (network error or 404)."
  rm -f "$UPSTREAM_VERSION_FILE"
  exit 1
fi
UPSTREAM_VERSION="$(tr -d '[:space:]' < "$UPSTREAM_VERSION_FILE")"
rm -f "$UPSTREAM_VERSION_FILE"
test -n "$UPSTREAM_VERSION" || { echo "[wiki-update] ABORT: upstream VERSION is empty."; exit 1; }
echo "[wiki-update] Upstream version: $UPSTREAM_VERSION"
```

**Compare** with `sort -V`:

```bash
SORTED=$(printf '%s\n%s\n' "$LOCAL_VERSION" "$UPSTREAM_VERSION" | sort -V)
LOWEST=$(echo "$SORTED" | head -n1)

if [ "$LOCAL_VERSION" = "$UPSTREAM_VERSION" ]; then
  echo "[wiki-update] Already up-to-date at $LOCAL_VERSION. Nothing to do."
  exit 0
elif [ "$LOWEST" = "$UPSTREAM_VERSION" ]; then
  echo "[wiki-update] Local $LOCAL_VERSION is newer than upstream $UPSTREAM_VERSION. Nothing to do."
  exit 0
fi
echo "[wiki-update] Update available: $LOCAL_VERSION → $UPSTREAM_VERSION"
```

## Step 2 — Show changelog and confirm

Fetch the changelog and slice out only the sections strictly between the local version (exclusive) and the upstream version (inclusive). The user shouldn't see entries for releases they already have.

```bash
CHANGELOG_FILE=$(mktemp)
if ! curl -fsSL "$RAW_BASE/CHANGELOG.md" -o "$CHANGELOG_FILE"; then
  echo "[wiki-update] WARN: failed to fetch CHANGELOG.md — proceeding without changelog display."
  echo "(no changelog available)" > "$CHANGELOG_FILE"
fi

awk -v local="$LOCAL_VERSION" -v upstream="$UPSTREAM_VERSION" '
  function ver_geq(a, b,   pa, pb, i) {
    n = split(a, pa, /[.]/); split(b, pb, /[.]/)
    for (i = 1; i <= 3; i++) {
      pa[i] = pa[i] + 0; pb[i] = pb[i] + 0
      if (pa[i] > pb[i]) return 1
      if (pa[i] < pb[i]) return 0
    }
    return 1
  }
  /^## \[/ {
    match($0, /\[[0-9]+\.[0-9]+\.[0-9]+\]/)
    v = substr($0, RSTART+1, RLENGTH-2)
    show = (ver_geq(v, local) && v != local && ver_geq(upstream, v))
    in_section = show
    if (show) print
    next
  }
  in_section { print }
' "$CHANGELOG_FILE" > /tmp/lcw-relevant-changelog.md
rm -f "$CHANGELOG_FILE"

echo "[wiki-update] === Changes from $LOCAL_VERSION → $UPSTREAM_VERSION ==="
cat /tmp/lcw-relevant-changelog.md
echo "[wiki-update] === End changelog ==="
```

**Confirmation gate.** Display the changelog above and ask the user in plain text:

> Apply this update? (yes/no)

Wait for the user's reply. If they answer anything other than "yes" / "y" (case-insensitive), print `[wiki-update] Aborted by user.` and exit. Do **not** ask via a tool dialog — keep this as a normal conversational confirmation so the user can also push back ("show me what files would change first") before committing.

## Step 3 — Fetch updated manifest

```bash
MANIFEST_FILE=$(mktemp)
if ! curl -fsSL "$RAW_BASE/dist-manifest.txt" -o "$MANIFEST_FILE"; then
  echo "[wiki-update] ABORT: failed to fetch dist-manifest.txt from $RAW_BASE."
  rm -f "$MANIFEST_FILE"
  exit 1
fi
test -s "$MANIFEST_FILE" || { echo "[wiki-update] ABORT: manifest empty."; rm -f "$MANIFEST_FILE"; exit 1; }
echo "[wiki-update] Fetched manifest: $(grep -cv '^[[:space:]]*#\|^[[:space:]]*$' "$MANIFEST_FILE") entries"
```

## Step 4 — Apply per-file manifest policy

Loop the manifest. Each non-blank, non-`#` line is `PATH [POLICY]` (whitespace-separated; policy defaults to `overwrite`).

```bash
COUNT_OVERWRITE=0
COUNT_KEEP_SAME=0
COUNT_KEEP_DIFFER=0
REVIEW_LIST=$(mktemp)
: > "$REVIEW_LIST"

while IFS= read -r line; do
  case "$line" in ''|\#*) continue ;; esac
  path=$(echo "$line" | awk '{print $1}')
  policy=$(echo "$line" | awk '{print ($2 == "" ? "overwrite" : $2)}')
  dest="$CLAUDE_PROJECT_DIR/$path"

  case "$policy" in
    overwrite)
      mkdir -p "$(dirname "$dest")"
      if curl -fsSL "$RAW_BASE/$path" -o "$dest"; then
        case "$path" in
          .claude/hooks/*.sh) chmod +x "$dest" ;;
        esac
        COUNT_OVERWRITE=$((COUNT_OVERWRITE + 1))
        echo "[wiki-update] overwrote: $path"
      else
        echo "[wiki-update] ABORT: failed to fetch $path"
        rm -f "$REVIEW_LIST" "$MANIFEST_FILE"
        exit 1
      fi
      ;;
    keep)
      if [ ! -e "$dest" ]; then
        # Local file absent — fetch normally (missing seed, not a customization)
        mkdir -p "$(dirname "$dest")"
        curl -fsSL "$RAW_BASE/$path" -o "$dest" \
          && echo "[wiki-update] fetched (was absent): $path" \
          || { echo "[wiki-update] ABORT: failed to fetch $path"; rm -f "$REVIEW_LIST" "$MANIFEST_FILE"; exit 1; }
      else
        TMP_UPSTREAM=$(mktemp)
        if curl -fsSL "$RAW_BASE/$path" -o "$TMP_UPSTREAM"; then
          if cmp -s "$dest" "$TMP_UPSTREAM"; then
            COUNT_KEEP_SAME=$((COUNT_KEEP_SAME + 1))
            echo "[wiki-update] kept (unchanged upstream): $path"
          else
            COUNT_KEEP_DIFFER=$((COUNT_KEEP_DIFFER + 1))
            # Build a github.com diff URL from RAW_BASE: raw.githubusercontent.com/<O>/<R>/<B> → github.com/<O>/<R>/blob/<B>
            DIFF_URL=$(echo "$RAW_BASE" | sed 's|raw\.githubusercontent\.com|github.com|; s|\(github\.com/[^/]*/[^/]*\)/|\1/blob/|')
            echo "$path — upstream changed; review at $DIFF_URL/$path" >> "$REVIEW_LIST"
            echo "[wiki-update] kept (upstream differs — manual review): $path"
          fi
        else
          echo "[wiki-update] WARN: failed to compare $path (curl error). Keeping local copy."
        fi
        rm -f "$TMP_UPSTREAM"
      fi
      ;;
    *)
      echo "[wiki-update] WARN: unknown policy '$policy' for $path — treating as overwrite."
      mkdir -p "$(dirname "$dest")"
      curl -fsSL "$RAW_BASE/$path" -o "$dest" && COUNT_OVERWRITE=$((COUNT_OVERWRITE + 1))
      ;;
  esac
done < "$MANIFEST_FILE"
rm -f "$MANIFEST_FILE"
```

## Step 5 — Re-merge .claude/settings.json (preserve user hooks; backfill default permissions)

The hook entries we own are identified by command-substring: `inbox-stop.sh` (Stop event) and `recall-prompt.sh` (UserPromptSubmit event). For each, we remove any matching entries (defensively: there should be one, but loop in case of duplicates) and append the canonical entry. We also backfill a small default `permissions.allow` set so installs from older versions (which didn't seed these) gain auto-approval for the inbox capture path. Other permissions, env vars, MCP servers, and unrelated hooks are untouched — the permission backfill skips entries already present (whether seeded by us originally or added by the user).

**Default permissions backfilled** (skipped if already present):
- `Read(wiki/inbox/_session.md)`
- `Edit(wiki/inbox/_session.md)`
- `Write(wiki/inbox/_session.md)`

**Require `jq`** — same constraint as `wiki-install` Step 5/5b:

```bash
if ! command -v jq >/dev/null 2>&1; then
  echo "[wiki-update] ABORT: jq is required to re-merge .claude/settings.json hook entries."
  echo "[wiki-update] Install jq and re-run /wiki-update. Alternatively, manually update entries per .claude/skills/wiki-install/SETTINGS-SNIPPET.md."
  exit 1
fi
```

If `.claude/settings.json` is absent (rare for an upgrade — implies a partial install), create it fresh with both hooks (delegate to `wiki-install` Step 5 Case A logic by reading the just-updated `wiki-install/SKILL.md`).

Otherwise re-merge in place:

```bash
SETTINGS="$CLAUDE_PROJECT_DIR/.claude/settings.json"
DEFAULT_PERMS=(
  "Read(wiki/inbox/_session.md)"
  "Edit(wiki/inbox/_session.md)"
  "Write(wiki/inbox/_session.md)"
)

if [ ! -f "$SETTINGS" ]; then
  echo "[wiki-update] WARN: .claude/settings.json missing — creating fresh with both hook entries and default permissions."
  mkdir -p "$(dirname "$SETTINGS")"
  cat > "$SETTINGS" <<'JSON'
{
  "permissions": {
    "allow": [
      "Read(wiki/inbox/_session.md)",
      "Edit(wiki/inbox/_session.md)",
      "Write(wiki/inbox/_session.md)"
    ]
  },
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
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/recall-prompt.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
JSON
  echo "[wiki-update] Created .claude/settings.json with Stop + UserPromptSubmit entries and default _session.md permissions."
else
  # Stop hook upsert
  STOP_CMD='"$CLAUDE_PROJECT_DIR"/.claude/hooks/inbox-stop.sh'
  jq --arg cmd "$STOP_CMD" '
    .hooks //= {}
    | .hooks.Stop //= [{"hooks":[]}]
    | .hooks.Stop |= (
        map(.hooks |= (map(select((.command // "") | contains("inbox-stop.sh") | not))))
      )
    | (.hooks.Stop[0].hooks //= [])
    | .hooks.Stop[0].hooks += [{"type":"command","command":$cmd,"timeout":10}]
  ' "$SETTINGS" > /tmp/lcw-settings.json && mv /tmp/lcw-settings.json "$SETTINGS"

  # UserPromptSubmit hook upsert
  RECALL_CMD='"$CLAUDE_PROJECT_DIR"/.claude/hooks/recall-prompt.sh'
  jq --arg cmd "$RECALL_CMD" '
    .hooks //= {}
    | .hooks.UserPromptSubmit //= [{"hooks":[]}]
    | .hooks.UserPromptSubmit |= (
        map(.hooks |= (map(select((.command // "") | contains("recall-prompt.sh") | not))))
      )
    | (.hooks.UserPromptSubmit[0].hooks //= [])
    | .hooks.UserPromptSubmit[0].hooks += [{"type":"command","command":$cmd,"timeout":10}]
  ' "$SETTINGS" > /tmp/lcw-settings.json && mv /tmp/lcw-settings.json "$SETTINGS"

  # Default-permission backfill — only adds missing entries, never removes user-added ones
  PERMS_ADDED=0
  for perm in "${DEFAULT_PERMS[@]}"; do
    if grep -Fq "$perm" "$SETTINGS"; then continue; fi
    jq --arg perm "$perm" '
      .permissions //= {}
      | .permissions.allow //= []
      | if (.permissions.allow | index($perm)) then . else .permissions.allow += [$perm] end
    ' "$SETTINGS" > /tmp/lcw-settings.json && mv /tmp/lcw-settings.json "$SETTINGS"
    PERMS_ADDED=$((PERMS_ADDED + 1))
  done

  # B3 verification — literal $CLAUDE_PROJECT_DIR token must survive.
  # JSON escapes the surrounding quotes (\"$CLAUDE_PROJECT_DIR\"), so use grep -F
  # with the escaped form to byte-match what jq actually wrote.
  if grep -qF '\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/inbox-stop.sh' "$SETTINGS" \
     && grep -qF '\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/recall-prompt.sh' "$SETTINGS"; then
    if [ "$PERMS_ADDED" -eq 0 ]; then
      echo "[wiki-update] Re-merged .claude/settings.json (Stop + UserPromptSubmit refreshed; default permissions already present)."
    else
      echo "[wiki-update] Re-merged .claude/settings.json (Stop + UserPromptSubmit refreshed; backfilled $PERMS_ADDED default permission entr$([ "$PERMS_ADDED" -eq 1 ] && echo y || echo ies))."
    fi
  else
    echo "[wiki-update] ABORT: post-merge verification failed — settings.json may have lost the literal \$CLAUDE_PROJECT_DIR token. Restore from your VCS and re-run."
    exit 1
  fi
fi
```

## Step 6 — Refresh CLAUDE.md "Auto-maintained wiki" section

The canonical section content lives in the shipped template `.claude/skills/wiki-install/templates/CLAUDE-MD-SECTION.md` — single source of truth shared with `/wiki-install` Block 3. Step 4's manifest fetch placed (or refreshed) it before this step runs.

```bash
SECTION_FILE="$CLAUDE_PROJECT_DIR/.claude/skills/wiki-install/templates/CLAUDE-MD-SECTION.md"
if [ ! -f "$SECTION_FILE" ]; then
  echo "[wiki-update] ABORT: canonical CLAUDE.md section template missing at $SECTION_FILE."
  echo "[wiki-update] Manifest fetch may have failed — re-run /wiki-update or inspect dist-manifest.txt."
  exit 1
fi
```

Apply: replace the existing section in `CLAUDE.md` (header → next H2 boundary), or append if absent.

```bash
CLAUDE_MD="$CLAUDE_PROJECT_DIR/CLAUDE.md"
if [ ! -f "$CLAUDE_MD" ]; then
  # Create CLAUDE.md with just the canonical section
  cat "$SECTION_FILE" > "$CLAUDE_MD"
  echo "[wiki-update] Created CLAUDE.md with Auto-maintained wiki section."
elif grep -q '^## Auto-maintained wiki[[:space:]]*$' "$CLAUDE_MD"; then
  # Replace existing section
  awk -v section_file="$SECTION_FILE" '
    /^## Auto-maintained wiki[[:space:]]*$/ {
      while ((getline line < section_file) > 0) print line
      close(section_file)
      in_section = 1
      next
    }
    in_section && /^## / { in_section = 0 }
    !in_section { print }
  ' "$CLAUDE_MD" > /tmp/lcw-claude-md.tmp && mv /tmp/lcw-claude-md.tmp "$CLAUDE_MD"
  echo "[wiki-update] Refreshed CLAUDE.md Auto-maintained wiki section."
else
  # Append section (with one blank-line separator)
  printf '\n' >> "$CLAUDE_MD"
  cat "$SECTION_FILE" >> "$CLAUDE_MD"
  echo "[wiki-update] Appended Auto-maintained wiki section to CLAUDE.md."
fi
```

## Step 7 — Stamp version + summary

```bash
echo "$UPSTREAM_VERSION" > "$CLAUDE_PROJECT_DIR/.claude/llm-code-wiki.version"

echo "[wiki-update] === Update Summary ==="
echo "[wiki-update] Updated $LOCAL_VERSION → $UPSTREAM_VERSION"
echo "[wiki-update] Files overwritten:           $COUNT_OVERWRITE"
echo "[wiki-update] User-owned files unchanged:  wiki/Rules.md, wiki/_templates/note.md, wiki/topic-index.md"
echo "[wiki-update]   - kept (upstream same):    $COUNT_KEEP_SAME"
echo "[wiki-update]   - kept (upstream differs): $COUNT_KEEP_DIFFER"
echo "[wiki-update] settings.json:               re-merged (Stop + UserPromptSubmit + default permissions backfilled if missing)"
echo "[wiki-update] CLAUDE.md:                   Auto-maintained wiki section refreshed"

if [ -s "$REVIEW_LIST" ]; then
  echo "[wiki-update] Manual review recommended:"
  while IFS= read -r entry; do
    echo "[wiki-update]   - $entry"
  done < "$REVIEW_LIST"
fi
rm -f "$REVIEW_LIST"

echo "[wiki-update] === Next step: restart Claude Code so any new skills/agents register. ==="
```

## Notes for the executor

- **Idempotence:** running `/wiki-update` twice in a row on the same upstream version exits at Step 1 with "Already up-to-date" — no fetches, no merges. Safe.
- **Argument handling:** if the user invokes `/wiki-update <URL>`, set `RAW_BASE="<URL>"` before running Step 0's bash block; otherwise the default applies. The `RAW_BASE="${RAW_BASE%/}"` line trims trailing slashes either way.
- **Diff URL conversion:** the `keep` policy converts `raw.githubusercontent.com/<O>/<R>/<B>` → `github.com/<O>/<R>/blob/<B>` for review links. For non-GitHub raw bases, the URL falls back to the raw URL itself (acceptable — the user can still fetch it).
- **Ordering:** Steps 5 (settings) and 6 (CLAUDE.md) intentionally run **after** Step 4 so they read the just-updated `wiki-install/SKILL.md` for canonical content. Don't reorder.
- **Failure isolation:** any abort in Steps 4–6 leaves the version stamp un-updated, so a re-run will retry. The stamp is updated only at Step 7 after everything succeeds.
- **No smoke tests** here. `/wiki-install` validates hooks at first install; an update preserves them. If a user suspects an upgrade broke their hooks, they can re-run `/wiki-install` (idempotent) for the smoke test pass.
