#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=sim/manifest/scripts/windows_powershell_bridge.sh
source "${SCRIPT_DIR}/windows_powershell_bridge.sh"

if [[ $# -lt 1 || $# -gt 3 ]]; then
  echo "Usage: $0 <test> [mock|real] [gui]" >&2
  echo "  Ex.: $0 top_level_test real gui   # usa ROM/IP/FFT reais e abre GUI" >&2
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
FLOW="mock"
GUI=0
shift

for arg in "$@"; do
  case "$arg" in
    mock|real)
      FLOW="$arg"
      ;;
    gui)
      GUI=1
      ;;
    *)
      echo "Unknown option: $arg" >&2
      echo "Usage: $0 <test> [mock|real] [gui]" >&2
      exit 2
      ;;
  esac
done

REPO_ROOT="$(find_root "$SCRIPT_DIR")"
LOCAL_DIR="${REPO_ROOT}/sim/local/questa/${TEST_NAME}_${FLOW}"
mkdir -p "${LOCAL_DIR}"

export ACES_TEST_NAME="${TEST_NAME}"
export ACES_FLOW="${FLOW}"
export ACES_REPO_ROOT="${REPO_ROOT}"
export ACES_LOCAL_DIR="${LOCAL_DIR}"
export ACES_GUI="${GUI}"

cd "${REPO_ROOT}"
if command -v vsim >/dev/null 2>&1; then
  vsim_args=(-do "do ${SCRIPT_DIR}/run_questa.tcl")
  if [[ "${GUI}" -eq 0 ]]; then
    vsim_args=(-c "${vsim_args[@]}")
  fi
  vsim "${vsim_args[@]}"
elif aces_should_use_windows_powershell; then
  echo "Info: 'vsim' nao esta no PATH do Linux; encaminhando para run_questa.ps1 via powershell.exe." >&2
  ps_args=("${TEST_NAME}" "${FLOW}")
  if [[ "${GUI}" -eq 1 ]]; then
    ps_args+=(--switch Gui)
  fi
  aces_run_repo_powershell_script "${REPO_ROOT}" "sim/manifest/scripts/run_questa.ps1" "${ps_args[@]}"
else
  echo "Error: 'vsim' nao foi encontrado no Linux e o fallback via powershell.exe nao esta disponivel." >&2
  echo "Execute o script PowerShell no Windows ou use WSL com interop habilitado." >&2
  exit 127
fi
