#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"
PORTABLE_ROOT="${REPO_ROOT}/sim/portable/questa_package"
ZIP_PATH="${REPO_ROOT}/sim/portable/aces_questa_portable.zip"

rm -rf "${PORTABLE_ROOT}"
mkdir -p "${PORTABLE_ROOT}/questa" "${PORTABLE_ROOT}/quartus_ip" "${PORTABLE_ROOT}/filelists" \
         "${PORTABLE_ROOT}/waves" "${PORTABLE_ROOT}/scripts" "${PORTABLE_ROOT}/rtl" \
         "${PORTABLE_ROOT}/tb" "${PORTABLE_ROOT}/docs" "${PORTABLE_ROOT}/tools"

cp -R "${REPO_ROOT}/rtl/." "${PORTABLE_ROOT}/rtl/"
cp -R "${REPO_ROOT}/tb/." "${PORTABLE_ROOT}/tb/"
cp -R "${REPO_ROOT}/sim/manifest/filelists/." "${PORTABLE_ROOT}/filelists/"
cp -R "${REPO_ROOT}/sim/manifest/waves/." "${PORTABLE_ROOT}/waves/"
cp -R "${REPO_ROOT}/sim/manifest/scripts/." "${PORTABLE_ROOT}/scripts/"
cp -R "${REPO_ROOT}/docs/." "${PORTABLE_ROOT}/docs/"
cp -R "${REPO_ROOT}/tools/." "${PORTABLE_ROOT}/tools/"
cp -R "${REPO_ROOT}/rtl/ip/." "${PORTABLE_ROOT}/quartus_ip/"
cp "${REPO_ROOT}/README.md" "${PORTABLE_ROOT}/README.md"
cp "${REPO_ROOT}/sim/manifest/README.md" "${PORTABLE_ROOT}/questa/README.md"

cat > "${PORTABLE_ROOT}/README.txt" <<'TXT'
ACES portable Questa package
============================

1. Unzip anywhere.
2. On Linux/macOS, run scripts/run_questa.sh <test_name> [mock|real] from the package root.
3. On Windows PowerShell, run .\scripts\run_questa.ps1 <test_name> [mock|real] from the package root.
4. Mock flow is self-contained.
5. Real flow expects any external FFT implementation filelist to be supplied through EXTRA_FILELIST.
TXT

(
  cd "${REPO_ROOT}/sim/portable"
  rm -f "${ZIP_PATH}"
  zip -qr "$(basename "${ZIP_PATH}")" "questa_package"
)

echo "Portable package created at ${ZIP_PATH}"
