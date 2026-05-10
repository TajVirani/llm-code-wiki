#!/usr/bin/env bash
# tests/run-all.sh — runs every test layer in sequence.
# Usage: tests/run-all.sh [layer ...]
#   With no args, runs all three layers: static, hooks, install-e2e.
#   With args, runs only the named layers (e.g., `tests/run-all.sh hooks`).
# Exits nonzero if any layer fails.
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -t 1 ]; then
  C_BOLD='\033[1m'; C_GREEN='\033[0;32m'; C_RED='\033[0;31m'; C_RESET='\033[0m'
else
  C_BOLD=''; C_GREEN=''; C_RED=''; C_RESET=''
fi

LAYERS=("$@")
if [ "${#LAYERS[@]}" -eq 0 ]; then
  LAYERS=(static hooks install-e2e)
fi

printf '%bllm-code-wiki test runner%b\n' "$C_BOLD" "$C_RESET"
printf 'layers: %s\n' "${LAYERS[*]}"

failed=()
for layer in "${LAYERS[@]}"; do
  script="$TESTS_DIR/$layer.sh"
  if [ ! -f "$script" ]; then
    printf '%bunknown layer:%b %s\n' "$C_RED" "$C_RESET" "$layer"
    failed+=("$layer")
    continue
  fi
  if bash "$script"; then :; else failed+=("$layer"); fi
done

printf '\n%bSummary%b\n' "$C_BOLD" "$C_RESET"
if [ "${#failed[@]}" -eq 0 ]; then
  printf '%ball layers passed%b\n' "$C_GREEN" "$C_RESET"
  exit 0
else
  printf '%bfailed layers:%b %s\n' "$C_RED" "$C_RESET" "${failed[*]}"
  exit 1
fi
