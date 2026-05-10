#!/usr/bin/env bash
# tests/lib/extract-bang-blocks.sh — extract Claude Code `!`-injected backtick
# blocks from a SKILL.md.
#
# A block opens at `!` immediately followed by a backtick at the start of a
# line (after optional indent), and closes at the next backtick (which may be
# on the same line or many lines later). The "start of line + indent" rule
# matches the real Claude Code convention and avoids false-positive matches
# on mid-prose mentions of "!`syntax`-style descriptions".
#
# Usage: extract_bang_blocks INPUT_MD OUTPUT_DIR
#   - Writes one file per block: $OUTPUT_DIR/bang-NN.sh (zero-padded order).
#   - Also writes $OUTPUT_DIR/bang-NN.lines containing "<start_line> <end_line>"
#     so callers can detect single-line vs multi-line blocks.
# Returns the count of blocks extracted via stdout.

extract_bang_blocks() {
  local input="$1"
  local outdir="$2"
  mkdir -p "$outdir"
  rm -f "$outdir"/bang-*.sh "$outdir"/bang-*.lines

  awk -v outdir="$outdir" '
    BEGIN { in_block = 0; count = 0; current = ""; start_line = 0 }
    {
      if (in_block) {
        ix = index($0, "`")
        if (ix == 0) {
          current = current $0 "\n"
        } else {
          current = current substr($0, 1, ix - 1)
          count++
          sh = sprintf("%s/bang-%02d.sh", outdir, count)
          ln = sprintf("%s/bang-%02d.lines", outdir, count)
          printf "%s", current > sh
          close(sh)
          printf "%d %d\n", start_line, NR > ln
          close(ln)
          in_block = 0
          current = ""
        }
      } else {
        if (match($0, /^[[:space:]]*!`/)) {
          start_line = NR
          rest = substr($0, RSTART + RLENGTH)
          ix = index(rest, "`")
          if (ix > 0) {
            current = substr(rest, 1, ix - 1)
            count++
            sh = sprintf("%s/bang-%02d.sh", outdir, count)
            ln = sprintf("%s/bang-%02d.lines", outdir, count)
            printf "%s", current > sh
            close(sh)
            printf "%d %d\n", start_line, NR > ln
            close(ln)
            current = ""
          } else {
            in_block = 1
            current = rest "\n"
          }
        }
      }
    }
    END { print count }
  ' "$input"
}
