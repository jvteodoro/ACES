#!/usr/bin/env bash

aces_is_wsl() {
  [[ -n "${WSL_DISTRO_NAME:-}" ]] && return 0
  grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null
}

aces_has_windows_powershell() {
  command -v powershell.exe >/dev/null 2>&1
}

aces_ps_single_quote() {
  printf "%s" "${1//\'/\'\'}"
}

aces_should_use_windows_powershell() {
  if [[ "${ACES_USE_WINDOWS_POWERSHELL:-0}" == "1" ]]; then
    aces_has_windows_powershell
    return $?
  fi

  aces_is_wsl && aces_has_windows_powershell
}

aces_run_repo_powershell_script() {
  local repo_root="$1"
  local script_rel_path="$2"
  shift 2

  local ps_command
  ps_command="& './${script_rel_path#./}'"

  local arg
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --switch)
        ps_command+=" -$(aces_ps_single_quote "$2")"
        shift 2
        ;;
      --named-arg)
        ps_command+=" -$(aces_ps_single_quote "$2") '$(aces_ps_single_quote "$3")'"
        shift 3
        ;;
      *)
        arg="$1"
        ps_command+=" '$(aces_ps_single_quote "$arg")'"
        shift
        ;;
    esac
  done

  (
    cd "${repo_root}"
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "${ps_command}"
  )
}
