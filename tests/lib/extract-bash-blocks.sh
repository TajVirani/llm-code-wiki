#!/usr/bin/env bash
# tests/lib/extract-bash-blocks.sh — extract fenced ```bash blocks from a markdown file.
# Usage: extract_bash_blocks INPUT_MD OUTPUT_DIR
# Writes one file per block: $OUTPUT_DIR/block-NN.sh (zero-padded, in source order).
# Returns the count of blocks extracted via stdout.

extract_bash_blocks() {
  local input="$1"
  local outdir="$2"
  mkdir -p "$outdir"
  rm -f "$outdir"/block-*.sh
  awk -v outdir="$outdir" '
    BEGIN { count=0 }
    /^```bash$/ { count++; in_block=1; out=sprintf("%s/block-%02d.sh", outdir, count); next }
    /^```$/ && in_block { in_block=0; next }
    in_block { print > out }
    END { print count }
  ' "$input"
}
