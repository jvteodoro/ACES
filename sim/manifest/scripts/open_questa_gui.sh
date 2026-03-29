#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=sim/manifest/scripts/windows_powershell_bridge.sh
source "${SCRIPT_DIR}/windows_powershell_bridge.sh"

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <filelist> <top_module>" >&2
  echo "Example: $0 sim/manifest/filelists/mock_integration_top_level_test.f tb_top_level_test" >&2
  exit 2
fi

FILELIST="$1"
TOP_MODULE="$2"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"
RUN_DIR="${REPO_ROOT}/sim/local/questa/gui_${TOP_MODULE}"
mkdir -p "${RUN_DIR}"

if command -v vsim >/dev/null 2>&1; then
  cd "${RUN_DIR}"
  vlib work
  vmap work work
  vlog -sv -f "${REPO_ROOT}/${FILELIST}"
  vsim "work.${TOP_MODULE}"
elif aces_should_use_windows_powershell; then
  echo "Info: ferramentas Questa GUI nao estao no PATH do Linux; encaminhando para open_questa_gui.ps1 via powershell.exe." >&2
  aces_run_repo_powershell_script "${REPO_ROOT}" "sim/manifest/scripts/open_questa_gui.ps1" "${FILELIST}" "${TOP_MODULE}"
else
  echo "Error: 'vsim' nao foi encontrado no Linux e o fallback via powershell.exe nao esta disponivel." >&2
  echo "Execute o script PowerShell no Windows ou use WSL com interop habilitado." >&2
  exit 127
fi
