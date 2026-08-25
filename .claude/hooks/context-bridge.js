#!/usr/bin/env node
/**
 * Statusline hook that writes context metrics to a bridge file.
 *
 * Claude Code provides context_window.remaining_percentage natively to the
 * statusline hook. This script writes those metrics to a temp file so the
 * PreToolUse gate hook can read accurate context data instead of guessing
 * from JSONL file sizes.
 *
 * Bridge file: /tmp/claude-ctx-{session_id}.json
 */

const fs = require("fs");
const os = require("os");
const path = require("path");

try {
  let raw = "";
  process.stdin.setEncoding("utf8");
  process.stdin.on("data", (chunk) => (raw += chunk));
  process.stdin.on("end", () => {
    const data = JSON.parse(raw);
    const session = data.session_id || process.env.CLAUDE_SESSION_ID || "";
    const remaining = data.context_window?.remaining_percentage;

    // Build statusline display
    let ctx = "";
    if (remaining != null) {
      const rem = Math.round(remaining);
      const rawUsed = Math.max(0, Math.min(100, 100 - rem));
      // Scale: 80% real usage = 100% displayed (Claude Code enforces 80% cap)
      const used = Math.min(100, Math.round((rawUsed / 80) * 100));
      const filled = Math.floor(used / 10);
      const bar = "\u2588".repeat(filled) + "\u2591".repeat(10 - filled);

      if (used < 63) {
        ctx = ` \x1b[32m${bar} ${used}%\x1b[0m`;
      } else if (used < 81) {
        ctx = ` \x1b[33m${bar} ${used}%\x1b[0m`;
      } else if (used < 95) {
        ctx = ` \x1b[38;5;208m${bar} ${used}%\x1b[0m`;
      } else {
        ctx = ` \x1b[5;31m${bar} ${used}%\x1b[0m`;
      }
    }

    // Write bridge file for the PreToolUse gate hook
    if (session && remaining != null) {
      const bridgePath = path.join(os.tmpdir(), `claude-ctx-${session}.json`);
      const bridgeData = JSON.stringify({
        session_id: session,
        remaining_percentage: remaining,
        timestamp: Math.floor(Date.now() / 1000),
      });
      try {
        fs.writeFileSync(bridgePath, bridgeData);
      } catch (_) {
        // Silent fail — bridge is best-effort
      }
    }

    // Output statusline
    process.stdout.write(ctx);
  });
} catch (_) {
  // Silent fail — never break the statusline
}
