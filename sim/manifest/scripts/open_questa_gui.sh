#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <filelist> <top_module>" >&2
  echo "Example: $0 sim/manifest/filelists/mock_integration_top_level_test.f tb_top_level_test_real" >&2
  exit 2
fi

FILELIST="$1"
TOP_MODULE="$2"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"
RUN_DIR="${REPO_ROOT}/sim/local/questa/gui_${TOP_MODULE}"
mkdir -p "${RUN_DIR}"
cd "${RUN_DIR}"

vlib work
vmap work work
vlog -sv -f "${REPO_ROOT}/${FILELIST}"
vsim "work.${TOP_MODULE}"
