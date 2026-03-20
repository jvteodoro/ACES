#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <test> [mock|real]" >&2
  exit 2
fi

find_root() {
  local start="$1"
  local dir="$start"
  while [[ "$dir" != "/" ]]; do
    if [[ -d "$dir/rtl" && -d "$dir/tb" ]]; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

TEST_NAME="$1"
FLOW="${2:-mock}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(find_root "$SCRIPT_DIR")"
LOCAL_DIR="${REPO_ROOT}/sim/local/questa/${TEST_NAME}_${FLOW}"
mkdir -p "${LOCAL_DIR}"

export ACES_TEST_NAME="${TEST_NAME}"
export ACES_FLOW="${FLOW}"
export ACES_REPO_ROOT="${REPO_ROOT}"
export ACES_LOCAL_DIR="${LOCAL_DIR}"

cd "${REPO_ROOT}"
vsim -c -do "do ${SCRIPT_DIR}/run_questa.tcl"
