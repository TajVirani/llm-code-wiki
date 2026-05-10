#!/usr/bin/env bash
# tests/lib/assert.sh — shared assertion + reporting helpers.
# Source from each layer script. Tracks PASS/FAIL counts in TEST_PASS / TEST_FAIL.
# Exits the calling script with status 1 if any assertion fails (via finish_layer).

# Color codes (no-op when not a TTY)
if [ -t 1 ]; then
  C_GREEN='\033[0;32m'; C_RED='\033[0;31m'; C_YELLOW='\033[0;33m'; C_DIM='\033[2m'; C_RESET='\033[0m'
else
  C_GREEN=''; C_RED=''; C_YELLOW=''; C_DIM=''; C_RESET=''
fi

TEST_PASS=0
TEST_FAIL=0
TEST_LAYER="${TEST_LAYER:-unnamed}"

start_layer() {
  TEST_LAYER="$1"
  printf '\n%b== %s ==%b\n' "$C_DIM" "$TEST_LAYER" "$C_RESET"
}

pass() {
  TEST_PASS=$((TEST_PASS + 1))
  printf '  %bPASS%b  %s\n' "$C_GREEN" "$C_RESET" "$1"
}

fail() {
  TEST_FAIL=$((TEST_FAIL + 1))
  printf '  %bFAIL%b  %s\n' "$C_RED" "$C_RESET" "$1"
  if [ -n "${2:-}" ]; then
    printf '          %b%s%b\n' "$C_DIM" "$2" "$C_RESET"
  fi
}

# expect_file_exists PATH MSG
expect_file_exists() {
  if [ -f "$1" ]; then pass "$2"; else fail "$2" "missing: $1"; fi
}

# expect_dir_exists PATH MSG
expect_dir_exists() {
  if [ -d "$1" ]; then pass "$2"; else fail "$2" "missing dir: $1"; fi
}

# expect_file_contains FILE NEEDLE MSG
expect_file_contains() {
  if [ ! -f "$1" ]; then fail "$3" "file missing: $1"; return; fi
  if grep -qF -- "$2" "$1"; then pass "$3"; else fail "$3" "needle not found in $1: $2"; fi
}

# expect_file_not_contains FILE NEEDLE MSG
expect_file_not_contains() {
  if [ ! -f "$1" ]; then fail "$3" "file missing: $1"; return; fi
  if grep -qF -- "$2" "$1"; then fail "$3" "unexpected needle in $1: $2"; else pass "$3"; fi
}

# expect_eq ACTUAL EXPECTED MSG
expect_eq() {
  if [ "$1" = "$2" ]; then pass "$3"; else fail "$3" "expected '$2' got '$1'"; fi
}

# expect_cmd_succeeds CMD... MSG
# Pass message as the LAST arg.
expect_cmd_succeeds() {
  local msg="${@: -1}"
  local args=( "${@:1:$#-1}" )
  local out
  if out=$( "${args[@]}" 2>&1 ); then pass "$msg"; else fail "$msg" "$out"; fi
}

# expect_exit_code CMD... EXPECTED_CODE MSG
# Last two args are expected code and message.
expect_exit_code() {
  local n=$#
  local msg="${!n}"
  local code_idx=$((n - 1))
  local expected="${!code_idx}"
  local args=( "${@:1:$((n-2))}" )
  local out actual
  out=$( "${args[@]}" 2>&1 ); actual=$?
  if [ "$actual" = "$expected" ]; then
    pass "$msg"
  else
    fail "$msg" "expected exit $expected got $actual; output: $out"
  fi
}

finish_layer() {
  local total=$((TEST_PASS + TEST_FAIL))
  printf '\n%b%s: %d/%d passed%b' "$C_DIM" "$TEST_LAYER" "$TEST_PASS" "$total" "$C_RESET"
  if [ "$TEST_FAIL" -gt 0 ]; then
    printf ' %b(%d failures)%b\n' "$C_RED" "$TEST_FAIL" "$C_RESET"
    exit 1
  fi
  printf '\n'
}
