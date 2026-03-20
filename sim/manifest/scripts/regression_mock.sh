#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TESTS=(
  i2s_rx_adapter_24
  sample_width_adapter_24_to_18
  i2s_stimulus_manager
  i2s_stimulus_manager_rom
  sample_bridge_and_ingest
  aces
  aces_stimulus_manager
  top_level_test
)
for test_name in "${TESTS[@]}"; do
  echo "=== Running ${test_name} (mock) ==="
  "${SCRIPT_DIR}/run_questa.sh" "${test_name}" mock
  echo
 done
